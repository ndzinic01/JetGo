using JetGo.Application.Constants;
using JetGo.Domain.Entities;
using JetGo.Infrastructure.Identity;
using JetGo.Infrastructure.Persistence;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;

namespace JetGo.Infrastructure.Seed;

public sealed class IdentityDataSeeder
{
    private const string DefaultPassword = "test";
    private readonly RoleManager<IdentityRole> _roleManager;
    private readonly UserManager<AppUser> _userManager;
    private readonly JetGoDbContext _dbContext;
    private readonly ILogger<IdentityDataSeeder> _logger;

    public IdentityDataSeeder(
        RoleManager<IdentityRole> roleManager,
        UserManager<AppUser> userManager,
        JetGoDbContext dbContext,
        ILogger<IdentityDataSeeder> logger)
    {
        _roleManager = roleManager;
        _userManager = userManager;
        _dbContext = dbContext;
        _logger = logger;
    }

    public async Task SeedAsync(CancellationToken cancellationToken = default)
    {
        await EnsureRoleAsync(RoleNames.Admin);
        await EnsureRoleAsync(RoleNames.User);

        await EnsureUserAsync(
            username: "desktop",
            roleName: RoleNames.Admin,
            firstName: "Desktop",
            lastName: "Admin",
            email: "desktop@jetgo.local",
            phoneNumber: "+38761000001",
            cancellationToken);

        await EnsureUserAsync(
            username: "mobile",
            roleName: RoleNames.User,
            firstName: "Mobile",
            lastName: "User",
            email: "mobile@jetgo.local",
            phoneNumber: "+38761000002",
            cancellationToken);
    }

    private async Task EnsureRoleAsync(string roleName)
    {
        if (await _roleManager.RoleExistsAsync(roleName))
        {
            return;
        }

        var result = await _roleManager.CreateAsync(new IdentityRole(roleName));

        if (!result.Succeeded)
        {
            var errors = string.Join(", ", result.Errors.Select(error => error.Description));
            throw new InvalidOperationException($"Seed role '{roleName}' could not be created. Details: {errors}");
        }
    }

    private async Task EnsureUserAsync(
        string username,
        string roleName,
        string firstName,
        string lastName,
        string email,
        string phoneNumber,
        CancellationToken cancellationToken)
    {
        var user = await _userManager.FindByNameAsync(username);

        if (user is null)
        {
            user = new AppUser
            {
                UserName = username,
                Email = email,
                PhoneNumber = phoneNumber,
                EmailConfirmed = true
            };

            var createResult = await _userManager.CreateAsync(user, DefaultPassword);

            if (!createResult.Succeeded)
            {
                var errors = string.Join(", ", createResult.Errors.Select(error => error.Description));
                throw new InvalidOperationException($"Seed user '{username}' could not be created. Details: {errors}");
            }

            _logger.LogInformation("Created seed user {Username}.", username);
        }

        var isInRole = await _userManager.IsInRoleAsync(user, roleName);

        if (!isInRole)
        {
            var addToRoleResult = await _userManager.AddToRoleAsync(user, roleName);

            if (!addToRoleResult.Succeeded)
            {
                var errors = string.Join(", ", addToRoleResult.Errors.Select(error => error.Description));
                throw new InvalidOperationException($"Seed user '{username}' could not be added to role '{roleName}'. Details: {errors}");
            }
        }

        var userProfile = await _dbContext.UserProfiles
            .SingleOrDefaultAsync(x => x.UserId == user.Id, cancellationToken);

        if (userProfile is null)
        {
            userProfile = new UserProfile
            {
                UserId = user.Id,
                FirstName = firstName,
                LastName = lastName,
                Email = email,
                PhoneNumber = phoneNumber
            };

            await _dbContext.UserProfiles.AddAsync(userProfile, cancellationToken);
        }
        else
        {
            userProfile.FirstName = firstName;
            userProfile.LastName = lastName;
            userProfile.Email = email;
            userProfile.PhoneNumber = phoneNumber;
            userProfile.UpdatedAtUtc = DateTime.UtcNow;
        }

        await _dbContext.SaveChangesAsync(cancellationToken);
    }
}
