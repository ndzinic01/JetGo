using System.Security.Claims;
using JetGo.Application.Contracts.Services;
using JetGo.Application.DTOs.Profile;
using JetGo.Application.Exceptions;
using JetGo.Application.Requests.Profile;
using JetGo.Domain.Entities;
using JetGo.Infrastructure.Identity;
using JetGo.Infrastructure.Persistence;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;

namespace JetGo.Infrastructure.Services;

public sealed class ProfileService : IProfileService
{
    private readonly UserManager<AppUser> _userManager;
    private readonly JetGoDbContext _dbContext;
    private readonly IHttpContextAccessor _httpContextAccessor;
    private readonly ILogger<ProfileService> _logger;

    public ProfileService(
        UserManager<AppUser> userManager,
        JetGoDbContext dbContext,
        IHttpContextAccessor httpContextAccessor,
        ILogger<ProfileService> logger)
    {
        _userManager = userManager;
        _dbContext = dbContext;
        _httpContextAccessor = httpContextAccessor;
        _logger = logger;
    }

    public async Task<ProfileDto> GetMyProfileAsync(CancellationToken cancellationToken = default)
    {
        var user = await GetCurrentUserAsync(cancellationToken);
        return await BuildProfileDtoAsync(user, cancellationToken);
    }

    public async Task<ProfileDto> UpdateMyProfileAsync(UpdateMyProfileRequest request, CancellationToken cancellationToken = default)
    {
        var user = await GetCurrentUserAsync(cancellationToken);
        var normalizedEmail = request.Email.Trim().ToLowerInvariant();

        var existingUserByEmail = await _userManager.FindByEmailAsync(normalizedEmail);

        if (existingUserByEmail is not null && existingUserByEmail.Id != user.Id)
        {
            throw new ConflictException($"Email adresa '{normalizedEmail}' je vec registrovana.");
        }

        var userProfile = await _dbContext.UserProfiles
            .SingleOrDefaultAsync(x => x.UserId == user.Id, cancellationToken);

        if (userProfile is null)
        {
            userProfile = new UserProfile
            {
                UserId = user.Id
            };

            await _dbContext.UserProfiles.AddAsync(userProfile, cancellationToken);
        }

        var executionStrategy = _dbContext.Database.CreateExecutionStrategy();

        return await executionStrategy.ExecuteAsync(async () =>
        {
            await using var transaction = await _dbContext.Database.BeginTransactionAsync(cancellationToken);

            user.Email = normalizedEmail;
            user.PhoneNumber = request.PhoneNumber?.Trim();

            var updateUserResult = await _userManager.UpdateAsync(user);

            if (!updateUserResult.Succeeded)
            {
                throw CreateValidationException(updateUserResult.Errors);
            }

            userProfile.FirstName = request.FirstName.Trim();
            userProfile.LastName = request.LastName.Trim();
            userProfile.Email = normalizedEmail;
            userProfile.PhoneNumber = request.PhoneNumber?.Trim();
            userProfile.ImageUrl = string.IsNullOrWhiteSpace(request.ImageUrl) ? null : request.ImageUrl.Trim();
            userProfile.UpdatedAtUtc = DateTime.UtcNow;

            await _dbContext.SaveChangesAsync(cancellationToken);
            await transaction.CommitAsync(cancellationToken);

            _logger.LogInformation("Profile updated for user {UserId}.", user.Id);

            return await BuildProfileDtoAsync(user, cancellationToken);
        });
    }

    public async Task ChangePasswordAsync(ChangePasswordRequest request, CancellationToken cancellationToken = default)
    {
        var user = await GetCurrentUserAsync(cancellationToken);
        var changePasswordResult = await _userManager.ChangePasswordAsync(user, request.CurrentPassword, request.NewPassword);

        if (!changePasswordResult.Succeeded)
        {
            throw CreateValidationException(changePasswordResult.Errors);
        }

        _logger.LogInformation("Password changed for user {UserId}.", user.Id);
    }

    private async Task<AppUser> GetCurrentUserAsync(CancellationToken cancellationToken)
    {
        var httpContext = _httpContextAccessor.HttpContext ?? throw new UnauthorizedException("Prijava je obavezna za ovu akciju.");
        var userId = httpContext.User.FindFirstValue(ClaimTypes.NameIdentifier);

        if (string.IsNullOrWhiteSpace(userId))
        {
            throw new UnauthorizedException("Nije moguce odrediti trenutnog korisnika.");
        }

        var user = await _userManager.Users.SingleOrDefaultAsync(x => x.Id == userId, cancellationToken);
        return user ?? throw new NotFoundException("Korisnik nije pronadjen.");
    }

    private async Task<ProfileDto> BuildProfileDtoAsync(AppUser user, CancellationToken cancellationToken)
    {
        var userProfile = await _dbContext.UserProfiles
            .AsNoTracking()
            .SingleOrDefaultAsync(x => x.UserId == user.Id, cancellationToken);
        var roles = await _userManager.GetRolesAsync(user);

        return new ProfileDto
        {
            UserId = user.Id,
            Username = user.UserName ?? string.Empty,
            FirstName = userProfile?.FirstName ?? string.Empty,
            LastName = userProfile?.LastName ?? string.Empty,
            Email = userProfile?.Email ?? user.Email ?? string.Empty,
            PhoneNumber = userProfile?.PhoneNumber ?? user.PhoneNumber,
            ImageUrl = userProfile?.ImageUrl,
            Roles = roles.ToArray()
        };
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
                ["profile"] = errorMessages
            });
    }
}
