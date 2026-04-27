using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using JetGo.Application.Constants;
using JetGo.Application.Contracts.Services;
using JetGo.Application.DTOs.Auth;
using JetGo.Application.Exceptions;
using JetGo.Application.Requests.Auth;
using JetGo.Domain.Entities;
using JetGo.Infrastructure.Identity;
using JetGo.Infrastructure.Persistence;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;

namespace JetGo.Infrastructure.Services;

public sealed class AuthService : IAuthService
{
    private readonly UserManager<AppUser> _userManager;
    private readonly JetGoDbContext _dbContext;
    private readonly IHttpContextAccessor _httpContextAccessor;
    private readonly JwtTokenGenerator _jwtTokenGenerator;
    private readonly ILogger<AuthService> _logger;

    public AuthService(
        UserManager<AppUser> userManager,
        JetGoDbContext dbContext,
        IHttpContextAccessor httpContextAccessor,
        JwtTokenGenerator jwtTokenGenerator,
        ILogger<AuthService> logger)
    {
        _userManager = userManager;
        _dbContext = dbContext;
        _httpContextAccessor = httpContextAccessor;
        _jwtTokenGenerator = jwtTokenGenerator;
        _logger = logger;
    }

    public async Task<AuthResponseDto> LoginAsync(LoginRequest request, CancellationToken cancellationToken = default)
    {
        var normalizedUsername = request.Username.Trim();
        var user = await _userManager.FindByNameAsync(normalizedUsername);

        if (user is null || !await _userManager.CheckPasswordAsync(user, request.Password))
        {
            throw new UnauthorizedException("Korisnicko ime ili lozinka nisu ispravni.");
        }

        return await BuildAuthResponseAsync(user, cancellationToken);
    }

    public async Task<AuthResponseDto> RegisterAsync(RegisterRequest request, CancellationToken cancellationToken = default)
    {
        var normalizedUsername = request.Username.Trim();
        var normalizedEmail = request.Email.Trim().ToLowerInvariant();

        if (await _userManager.FindByNameAsync(normalizedUsername) is not null)
        {
            throw new ConflictException($"Korisnicko ime '{normalizedUsername}' je vec zauzeto.");
        }

        var existingUserByEmail = await _userManager.FindByEmailAsync(normalizedEmail);

        if (existingUserByEmail is not null)
        {
            throw new ConflictException($"Email adresa '{normalizedEmail}' je vec registrovana.");
        }

        var user = new AppUser
        {
            UserName = normalizedUsername,
            Email = normalizedEmail,
            PhoneNumber = request.PhoneNumber?.Trim(),
            EmailConfirmed = true
        };

        var executionStrategy = _dbContext.Database.CreateExecutionStrategy();

        return await executionStrategy.ExecuteAsync(async () =>
        {
            await using var transaction = await _dbContext.Database.BeginTransactionAsync(cancellationToken);

            var createResult = await _userManager.CreateAsync(user, request.Password);

            if (!createResult.Succeeded)
            {
                throw CreateValidationException(createResult.Errors);
            }

            var addToRoleResult = await _userManager.AddToRoleAsync(user, RoleNames.User);

            if (!addToRoleResult.Succeeded)
            {
                throw CreateValidationException(addToRoleResult.Errors);
            }

            var userProfile = new UserProfile
            {
                UserId = user.Id,
                FirstName = request.FirstName.Trim(),
                LastName = request.LastName.Trim(),
                Email = normalizedEmail,
                PhoneNumber = request.PhoneNumber?.Trim()
            };

            await _dbContext.UserProfiles.AddAsync(userProfile, cancellationToken);
            await _dbContext.SaveChangesAsync(cancellationToken);
            await transaction.CommitAsync(cancellationToken);

            _logger.LogInformation("Registered new user {Username}.", normalizedUsername);

            return await BuildAuthResponseAsync(user, cancellationToken);
        });
    }

    public async Task LogoutAsync(CancellationToken cancellationToken = default)
    {
        var httpContext = _httpContextAccessor.HttpContext ?? throw new UnauthorizedException("Prijava je obavezna za ovu akciju.");
        var principal = httpContext.User;
        var userId = principal.FindFirstValue(ClaimTypes.NameIdentifier);
        var jwtId = principal.FindFirstValue(JwtRegisteredClaimNames.Jti);
        var expiresAtClaim = principal.FindFirstValue(JwtRegisteredClaimNames.Exp);

        if (string.IsNullOrWhiteSpace(userId) || string.IsNullOrWhiteSpace(jwtId) || string.IsNullOrWhiteSpace(expiresAtClaim))
        {
            throw new UnauthorizedException("Token ne sadrzi potrebne podatke za odjavu.");
        }

        if (!long.TryParse(expiresAtClaim, out var expirationUnixTime))
        {
            throw new UnauthorizedException("Token ne sadrzi validno vrijeme isteka.");
        }

        var existingRevocation = await _dbContext.RevokedTokens
            .SingleOrDefaultAsync(x => x.JwtId == jwtId, cancellationToken);

        if (existingRevocation is null)
        {
            await _dbContext.RevokedTokens.AddAsync(new RevokedToken
            {
                JwtId = jwtId,
                UserId = userId,
                ExpiresAtUtc = DateTimeOffset.FromUnixTimeSeconds(expirationUnixTime).UtcDateTime,
                Reason = "UserLogout"
            }, cancellationToken);

            await _dbContext.SaveChangesAsync(cancellationToken);
        }

        _logger.LogInformation("User {UserId} logged out and token {JwtId} was revoked.", userId, jwtId);
    }

    public async Task<AuthenticatedUserDto> GetCurrentUserAsync(CancellationToken cancellationToken = default)
    {
        var user = await GetCurrentUserEntityAsync(cancellationToken);
        return await BuildUserDtoAsync(user, cancellationToken);
    }

    private async Task<AuthResponseDto> BuildAuthResponseAsync(AppUser user, CancellationToken cancellationToken)
    {
        var roles = (await _userManager.GetRolesAsync(user)).ToArray();
        var tokenResult = _jwtTokenGenerator.Generate(user, roles);
        var userDto = await BuildUserDtoAsync(user, cancellationToken, roles);

        return new AuthResponseDto
        {
            AccessToken = tokenResult.AccessToken,
            ExpiresAtUtc = tokenResult.ExpiresAtUtc,
            User = userDto
        };
    }

    private async Task<AuthenticatedUserDto> BuildUserDtoAsync(
        AppUser user,
        CancellationToken cancellationToken,
        IReadOnlyCollection<string>? roles = null)
    {
        var userProfile = await _dbContext.UserProfiles
            .AsNoTracking()
            .SingleOrDefaultAsync(x => x.UserId == user.Id, cancellationToken);

        var userRoles = roles ?? (await _userManager.GetRolesAsync(user)).ToArray();

        return new AuthenticatedUserDto
        {
            UserId = user.Id,
            Username = user.UserName ?? string.Empty,
            Email = userProfile?.Email ?? user.Email ?? string.Empty,
            FirstName = userProfile?.FirstName ?? string.Empty,
            LastName = userProfile?.LastName ?? string.Empty,
            PhoneNumber = userProfile?.PhoneNumber ?? user.PhoneNumber,
            Roles = userRoles.ToArray()
        };
    }

    private async Task<AppUser> GetCurrentUserEntityAsync(CancellationToken cancellationToken)
    {
        var httpContext = _httpContextAccessor.HttpContext ?? throw new UnauthorizedException("Prijava je obavezna za ovu akciju.");
        var userId = httpContext.User.FindFirstValue(ClaimTypes.NameIdentifier);

        if (string.IsNullOrWhiteSpace(userId))
        {
            throw new UnauthorizedException("Nije moguce odrediti trenutnog korisnika.");
        }

        var user = await _userManager.Users
            .SingleOrDefaultAsync(x => x.Id == userId, cancellationToken);

        return user ?? throw new NotFoundException("Korisnik nije pronadjen.");
    }

    private static ValidationException CreateValidationException(IEnumerable<IdentityError> errors)
    {
        var errorMessages = errors
            .Select(error => error.Description)
            .Distinct()
            .ToArray();

        return new ValidationException(
            "Korisnicki podaci nisu validni.",
            new Dictionary<string, string[]>
            {
                ["auth"] = errorMessages
            });
    }
}
