using System.Security.Claims;
using JetGo.Application.Constants;
using JetGo.Application.Contracts.Services;
using JetGo.Application.DTOs.Common;
using JetGo.Application.DTOs.Users;
using JetGo.Application.Exceptions;
using JetGo.Application.Requests.Users;
using JetGo.Domain.Entities;
using JetGo.Infrastructure.Identity;
using JetGo.Infrastructure.Persistence;
using JetGo.Infrastructure.Services.Common;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;

namespace JetGo.Infrastructure.Services;

public sealed class AdminUserService : IAdminUserService
{
    private static readonly string[] SupportedRoles = [RoleNames.Admin, RoleNames.User];

    private readonly UserManager<AppUser> _userManager;
    private readonly JetGoDbContext _dbContext;
    private readonly IHttpContextAccessor _httpContextAccessor;
    private readonly ILogger<AdminUserService> _logger;

    public AdminUserService(
        UserManager<AppUser> userManager,
        JetGoDbContext dbContext,
        IHttpContextAccessor httpContextAccessor,
        ILogger<AdminUserService> logger)
    {
        _userManager = userManager;
        _dbContext = dbContext;
        _httpContextAccessor = httpContextAccessor;
        _logger = logger;
    }

    public async Task<PagedResponseDto<AdminUserListItemDto>> GetPagedAsync(AdminUserSearchRequest request, CancellationToken cancellationToken = default)
    {
        var query =
            from user in _userManager.Users.AsNoTracking()
            join profile in _dbContext.UserProfiles.AsNoTracking() on user.Id equals profile.UserId into profiles
            from profile in profiles.DefaultIfEmpty()
            select new
            {
                user.Id,
                Username = user.UserName,
                user.Email,
                user.PhoneNumber,
                user.LockoutEnd,
                Profile = profile,
                ReservationsCount = _dbContext.Reservations.Count(r => r.UserId == user.Id),
                PaymentsCount = _dbContext.Payments.Count(p => p.Reservation.UserId == user.Id)
            };

        if (request.IsActive.HasValue)
        {
            if (request.IsActive.Value)
            {
                query = query.Where(x => !x.LockoutEnd.HasValue || x.LockoutEnd <= DateTimeOffset.UtcNow);
            }
            else
            {
                query = query.Where(x => x.LockoutEnd.HasValue && x.LockoutEnd > DateTimeOffset.UtcNow);
            }
        }

        if (!string.IsNullOrWhiteSpace(request.SearchText))
        {
            var searchText = request.SearchText.Trim();
            query = query.Where(x =>
                (x.Username ?? string.Empty).Contains(searchText) ||
                (x.Email ?? string.Empty).Contains(searchText) ||
                (x.PhoneNumber ?? string.Empty).Contains(searchText) ||
                (x.Profile != null && (
                    x.Profile.FirstName.Contains(searchText) ||
                    x.Profile.LastName.Contains(searchText) ||
                    x.Profile.Email.Contains(searchText))));
        }

        if (!string.IsNullOrWhiteSpace(request.RoleName))
        {
            var normalizedRole = request.RoleName.Trim();
            query = query.Where(x =>
                _dbContext.UserRoles.Any(ur =>
                    ur.UserId == x.Id &&
                    _dbContext.Roles.Any(r => r.Id == ur.RoleId && r.Name == normalizedRole)));
        }

        var totalCount = await query.CountAsync(cancellationToken);

        var pageItems = await query
            .OrderBy(x => x.Profile != null ? x.Profile.FirstName : string.Empty)
            .ThenBy(x => x.Profile != null ? x.Profile.LastName : string.Empty)
            .ThenBy(x => x.Username)
            .Skip((request.Page - 1) * request.PageSize)
            .Take(request.PageSize)
            .ToListAsync(cancellationToken);

        var userIds = pageItems.Select(x => x.Id).ToArray();
        var rolesByUserId = await GetRolesByUserIdsAsync(userIds, cancellationToken);

        var items = pageItems.Select(x =>
        {
            var firstName = x.Profile?.FirstName ?? string.Empty;
            var lastName = x.Profile?.LastName ?? string.Empty;

            return new AdminUserListItemDto
            {
                UserId = x.Id,
                Username = x.Username ?? string.Empty,
                FirstName = firstName,
                LastName = lastName,
                FullName = BuildFullName(firstName, lastName),
                Email = x.Profile?.Email ?? x.Email ?? string.Empty,
                PhoneNumber = x.Profile?.PhoneNumber ?? x.PhoneNumber,
                IsActive = !x.LockoutEnd.HasValue || x.LockoutEnd <= DateTimeOffset.UtcNow,
                Roles = rolesByUserId.TryGetValue(x.Id, out var roles) ? roles : Array.Empty<string>(),
                ReservationsCount = x.ReservationsCount,
                PaymentsCount = x.PaymentsCount,
                CreatedAtUtc = x.Profile?.CreatedAtUtc
            };
        }).ToList();

        return PagedResponseBuilder.Build(items, request.Page, request.PageSize, totalCount);
    }

    public async Task<AdminUserDetailsDto> GetByIdAsync(string userId, CancellationToken cancellationToken = default)
    {
        var userData = await (
            from user in _userManager.Users.AsNoTracking()
            join profile in _dbContext.UserProfiles.AsNoTracking() on user.Id equals profile.UserId into profiles
            from profile in profiles.DefaultIfEmpty()
            where user.Id == userId
            select new
            {
                User = user,
                Profile = profile,
                ReservationsCount = _dbContext.Reservations.Count(r => r.UserId == user.Id),
                PaymentsCount = _dbContext.Payments.Count(p => p.Reservation.UserId == user.Id),
                SupportMessagesCount = _dbContext.SupportMessages.Count(s => s.UserId == user.Id),
                SearchHistoryCount = _dbContext.SearchHistories.Count(s => s.UserId == user.Id),
                UnreadNotificationsCount = _dbContext.Notifications.Count(n => n.UserId == user.Id && n.Status == Domain.Enums.NotificationStatus.Unread)
            })
            .SingleOrDefaultAsync(cancellationToken);

        if (userData is null)
        {
            throw new NotFoundException("Korisnik nije pronadjen.");
        }

        var rolesByUserId = await GetRolesByUserIdsAsync([userId], cancellationToken);
        var roles = rolesByUserId.TryGetValue(userId, out var userRoles) ? userRoles : Array.Empty<string>();
        var firstName = userData.Profile?.FirstName ?? string.Empty;
        var lastName = userData.Profile?.LastName ?? string.Empty;

        return new AdminUserDetailsDto
        {
            UserId = userData.User.Id,
            Username = userData.User.UserName ?? string.Empty,
            FirstName = firstName,
            LastName = lastName,
            FullName = BuildFullName(firstName, lastName),
            Email = userData.Profile?.Email ?? userData.User.Email ?? string.Empty,
            PhoneNumber = userData.Profile?.PhoneNumber ?? userData.User.PhoneNumber,
            ImageUrl = userData.Profile?.ImageUrl,
            IsActive = !userData.User.LockoutEnd.HasValue || userData.User.LockoutEnd <= DateTimeOffset.UtcNow,
            LockoutEndUtc = userData.User.LockoutEnd,
            Roles = roles,
            ReservationsCount = userData.ReservationsCount,
            PaymentsCount = userData.PaymentsCount,
            SupportMessagesCount = userData.SupportMessagesCount,
            SearchHistoryCount = userData.SearchHistoryCount,
            UnreadNotificationsCount = userData.UnreadNotificationsCount,
            CreatedAtUtc = userData.Profile?.CreatedAtUtc,
            UpdatedAtUtc = userData.Profile?.UpdatedAtUtc
        };
    }

    public async Task<AdminUserDetailsDto> UpdateAsync(string userId, UpdateAdminUserRequest request, CancellationToken cancellationToken = default)
    {
        var user = await _userManager.Users.SingleOrDefaultAsync(x => x.Id == userId, cancellationToken);

        if (user is null)
        {
            throw new NotFoundException("Korisnik nije pronadjen.");
        }

        var normalizedEmail = request.Email.Trim().ToLowerInvariant();
        var targetRoles = NormalizeRoles(request.Roles);

        var existingUserByEmail = await _userManager.FindByEmailAsync(normalizedEmail);

        if (existingUserByEmail is not null && existingUserByEmail.Id != user.Id)
        {
            throw new ConflictException($"Email adresa '{normalizedEmail}' je vec registrovana.");
        }

        var currentUserId = GetCurrentUserId();

        if (currentUserId == userId && !targetRoles.Contains(RoleNames.Admin, StringComparer.Ordinal))
        {
            throw new ForbiddenException("Ne mozete ukloniti vlastitu Admin rolu.");
        }

        var profile = await EnsureUserProfileAsync(user.Id, cancellationToken);

        var executionStrategy = _dbContext.Database.CreateExecutionStrategy();

        return await executionStrategy.ExecuteAsync(async () =>
        {
            await using var transaction = await _dbContext.Database.BeginTransactionAsync(cancellationToken);

            user.Email = normalizedEmail;
            user.PhoneNumber = string.IsNullOrWhiteSpace(request.PhoneNumber) ? null : request.PhoneNumber.Trim();

            var updateUserResult = await _userManager.UpdateAsync(user);

            if (!updateUserResult.Succeeded)
            {
                throw CreateValidationException(updateUserResult.Errors);
            }

            profile.FirstName = request.FirstName.Trim();
            profile.LastName = request.LastName.Trim();
            profile.Email = normalizedEmail;
            profile.PhoneNumber = string.IsNullOrWhiteSpace(request.PhoneNumber) ? null : request.PhoneNumber.Trim();
            profile.ImageUrl = string.IsNullOrWhiteSpace(request.ImageUrl) ? null : request.ImageUrl.Trim();
            profile.UpdatedAtUtc = DateTime.UtcNow;

            var currentRoles = await _userManager.GetRolesAsync(user);
            var rolesToRemove = currentRoles.Where(x => !targetRoles.Contains(x, StringComparer.Ordinal)).ToArray();
            var rolesToAdd = targetRoles.Where(x => !currentRoles.Contains(x, StringComparer.Ordinal)).ToArray();

            if (rolesToRemove.Length > 0)
            {
                var removeRolesResult = await _userManager.RemoveFromRolesAsync(user, rolesToRemove);

                if (!removeRolesResult.Succeeded)
                {
                    throw CreateValidationException(removeRolesResult.Errors);
                }
            }

            if (rolesToAdd.Length > 0)
            {
                var addRolesResult = await _userManager.AddToRolesAsync(user, rolesToAdd);

                if (!addRolesResult.Succeeded)
                {
                    throw CreateValidationException(addRolesResult.Errors);
                }
            }

            if (rolesToAdd.Length > 0 || rolesToRemove.Length > 0)
            {
                var securityStampResult = await _userManager.UpdateSecurityStampAsync(user);

                if (!securityStampResult.Succeeded)
                {
                    throw CreateValidationException(securityStampResult.Errors);
                }
            }

            await _dbContext.SaveChangesAsync(cancellationToken);
            await transaction.CommitAsync(cancellationToken);

            _logger.LogInformation("Admin updated user profile and roles for user {UserId}.", user.Id);

            return await GetByIdAsync(user.Id, cancellationToken);
        });
    }

    public async Task<AdminUserDetailsDto> UpdateActivationAsync(string userId, UpdateAdminUserActivationRequest request, CancellationToken cancellationToken = default)
    {
        var user = await _userManager.Users.SingleOrDefaultAsync(x => x.Id == userId, cancellationToken);

        if (user is null)
        {
            throw new NotFoundException("Korisnik nije pronadjen.");
        }

        var currentUserId = GetCurrentUserId();

        if (currentUserId == userId && !request.IsActive)
        {
            throw new ForbiddenException("Ne mozete deaktivirati vlastiti korisnicki nalog.");
        }

        user.LockoutEnabled = true;
        user.LockoutEnd = request.IsActive ? null : DateTimeOffset.UtcNow.AddYears(100);

        var result = await _userManager.UpdateAsync(user);

        if (!result.Succeeded)
        {
            throw CreateValidationException(result.Errors);
        }

        var securityStampResult = await _userManager.UpdateSecurityStampAsync(user);

        if (!securityStampResult.Succeeded)
        {
            throw CreateValidationException(securityStampResult.Errors);
        }

        _logger.LogInformation("Admin changed activation status for user {UserId} to {IsActive}.", user.Id, request.IsActive);

        return await GetByIdAsync(user.Id, cancellationToken);
    }

    public async Task ResetPasswordAsync(string userId, AdminResetUserPasswordRequest request, CancellationToken cancellationToken = default)
    {
        var user = await _userManager.Users.SingleOrDefaultAsync(x => x.Id == userId, cancellationToken);

        if (user is null)
        {
            throw new NotFoundException("Korisnik nije pronadjen.");
        }

        var token = await _userManager.GeneratePasswordResetTokenAsync(user);
        var resetResult = await _userManager.ResetPasswordAsync(user, token, request.NewPassword);

        if (!resetResult.Succeeded)
        {
            throw CreateValidationException(resetResult.Errors);
        }

        _logger.LogInformation("Admin reset password for user {UserId}.", user.Id);
    }

    private async Task<UserProfile> EnsureUserProfileAsync(string userId, CancellationToken cancellationToken)
    {
        var profile = await _dbContext.UserProfiles.SingleOrDefaultAsync(x => x.UserId == userId, cancellationToken);

        if (profile is not null)
        {
            return profile;
        }

        profile = new UserProfile
        {
            UserId = userId
        };

        await _dbContext.UserProfiles.AddAsync(profile, cancellationToken);
        return profile;
    }

    private async Task<Dictionary<string, string[]>> GetRolesByUserIdsAsync(IReadOnlyCollection<string> userIds, CancellationToken cancellationToken)
    {
        if (userIds.Count == 0)
        {
            return new Dictionary<string, string[]>();
        }

        var roles = await (
            from userRole in _dbContext.UserRoles.AsNoTracking()
            join role in _dbContext.Roles.AsNoTracking() on userRole.RoleId equals role.Id
            where userIds.Contains(userRole.UserId)
            select new
            {
                userRole.UserId,
                RoleName = role.Name ?? string.Empty
            })
            .ToListAsync(cancellationToken);

        return roles
            .GroupBy(x => x.UserId)
            .ToDictionary(
                g => g.Key,
                g => g.Select(x => x.RoleName).Distinct().OrderBy(x => x).ToArray());
    }

    private static string[] NormalizeRoles(IEnumerable<string> roles)
    {
        var normalizedRoles = roles
            .Where(x => !string.IsNullOrWhiteSpace(x))
            .Select(x => x.Trim())
            .Distinct(StringComparer.Ordinal)
            .ToArray();

        if (normalizedRoles.Length == 0)
        {
            throw new ValidationException(
                "Korisnik mora imati barem jednu rolu.",
                new Dictionary<string, string[]>
                {
                    ["roles"] = ["Korisnik mora imati barem jednu rolu."]
                });
        }

        var invalidRoles = normalizedRoles
            .Where(x => !SupportedRoles.Contains(x, StringComparer.Ordinal))
            .ToArray();

        if (invalidRoles.Length > 0)
        {
            throw new ValidationException(
                "Jedna ili vise rola nisu podrzane.",
                new Dictionary<string, string[]>
                {
                    ["roles"] = [$"Podrzane role su: {string.Join(", ", SupportedRoles)}."]
                });
        }

        return normalizedRoles;
    }

    private string GetCurrentUserId()
    {
        var httpContext = _httpContextAccessor.HttpContext ?? throw new UnauthorizedException("Prijava je obavezna za ovu akciju.");
        var userId = httpContext.User.FindFirstValue(ClaimTypes.NameIdentifier);

        if (string.IsNullOrWhiteSpace(userId))
        {
            throw new UnauthorizedException("Nije moguce odrediti trenutnog korisnika.");
        }

        return userId;
    }

    private static string BuildFullName(string firstName, string lastName)
    {
        var fullName = $"{firstName} {lastName}".Trim();
        return string.IsNullOrWhiteSpace(fullName) ? "Nije definisano" : fullName;
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
                ["user"] = errorMessages
            });
    }
}
