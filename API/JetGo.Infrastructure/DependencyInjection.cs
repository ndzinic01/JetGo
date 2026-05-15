using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Text;
using JetGo.Application.Configuration;
using JetGo.Application.Constants;
using JetGo.Application.Contracts.Messaging;
using JetGo.Application.Contracts.Services;
using JetGo.Infrastructure.Messaging;
using JetGo.Infrastructure.Identity;
using JetGo.Infrastructure.Payments;
using JetGo.Infrastructure.Persistence;
using JetGo.Infrastructure.Seed;
using JetGo.Infrastructure.Services;
using Microsoft.AspNetCore.DataProtection;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.IdentityModel.Tokens;

namespace JetGo.Infrastructure;

public static class DependencyInjection
{
    public static IServiceCollection AddJetGoInfrastructure(
        this IServiceCollection services,
        string connectionString,
        JwtSettings jwtSettings,
        RabbitMqSettings rabbitMqSettings,
        PayPalSettings payPalSettings,
        bool includeWebSecurity = true)
    {
        services.AddSingleton(jwtSettings);
        services.AddSingleton(rabbitMqSettings);
        services.AddSingleton(payPalSettings);
        services.AddMemoryCache();

        services.AddDbContext<JetGoDbContext>(options =>
            options.UseSqlServer(connectionString, sqlOptions => sqlOptions.EnableRetryOnFailure()));

        services.AddIdentityCore<AppUser>(options =>
            {
                options.User.RequireUniqueEmail = true;
                options.Password.RequireDigit = false;
                options.Password.RequireLowercase = false;
                options.Password.RequireNonAlphanumeric = false;
                options.Password.RequireUppercase = false;
                options.Password.RequiredLength = 4;
            })
            .AddRoles<IdentityRole>()
            .AddEntityFrameworkStores<JetGoDbContext>()
            .AddSignInManager()
            .AddDefaultTokenProviders();

        services.Configure<DataProtectionTokenProviderOptions>(options =>
        {
            options.TokenLifespan = TimeSpan.FromMinutes(15);
        });

        if (includeWebSecurity)
        {
            var signingKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(jwtSettings.Key));

            services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
                .AddJwtBearer(options =>
                {
                    options.RequireHttpsMetadata = false;
                    options.SaveToken = false;
                    options.TokenValidationParameters = new TokenValidationParameters
                    {
                        ValidateIssuer = true,
                        ValidateAudience = true,
                        ValidateLifetime = true,
                        ValidateIssuerSigningKey = true,
                        ValidIssuer = jwtSettings.Issuer,
                        ValidAudience = jwtSettings.Audience,
                        IssuerSigningKey = signingKey,
                        ClockSkew = TimeSpan.Zero
                    };

                    options.Events = new JwtBearerEvents
                    {
                        OnTokenValidated = async context =>
                        {
                            var userId = context.Principal?.FindFirstValue(ClaimTypes.NameIdentifier);
                            var jwtId = context.Principal?.FindFirst(JwtRegisteredClaimNames.Jti)?.Value;
                            var securityStamp = context.Principal?.FindFirst(JwtClaimTypes.SecurityStamp)?.Value;

                            if (string.IsNullOrWhiteSpace(userId) || string.IsNullOrWhiteSpace(jwtId) || string.IsNullOrWhiteSpace(securityStamp))
                            {
                                context.Fail("Token ne sadrzi potrebne sigurnosne podatke.");
                                return;
                            }

                            var dbContext = context.HttpContext.RequestServices.GetRequiredService<JetGoDbContext>();
                            var isRevoked = await dbContext.RevokedTokens
                                .AsNoTracking()
                                .AnyAsync(
                                    x => x.JwtId == jwtId && x.ExpiresAtUtc > DateTime.UtcNow,
                                    context.HttpContext.RequestAborted);

                            if (isRevoked)
                            {
                                context.Fail("Token je opozvan.");
                                return;
                            }

                            var user = await dbContext.Users
                                .AsNoTracking()
                                .SingleOrDefaultAsync(x => x.Id == userId, context.HttpContext.RequestAborted);

                            if (user is null)
                            {
                                context.Fail("Korisnik za dati token vise ne postoji.");
                                return;
                            }

                            if (user.LockoutEnd.HasValue && user.LockoutEnd > DateTimeOffset.UtcNow)
                            {
                                context.Fail("Korisnicki nalog nije aktivan.");
                                return;
                            }

                            if (!string.Equals(user.SecurityStamp, securityStamp, StringComparison.Ordinal))
                            {
                                context.Fail("Token vise nije vazeci za trenutni sigurnosni kontekst korisnika.");
                            }
                        }
                    };
                });

            services.AddAuthorization();
        }

        services.AddHttpContextAccessor();
        services.AddHttpClient<PayPalCheckoutClient>(client =>
        {
            client.BaseAddress = new Uri(payPalSettings.BaseUrl);
        });
        services.AddSingleton<IRabbitMqPersistentConnection, RabbitMqPersistentConnection>();
        services.AddScoped<INotificationEventPublisher, RabbitMqNotificationEventPublisher>();
        services.AddScoped<JwtTokenGenerator>();
        services.AddScoped<IAuthService, AuthService>();
        services.AddScoped<IProfileService, ProfileService>();
        services.AddScoped<ICountryAdminService, CountryAdminService>();
        services.AddScoped<ICityAdminService, CityAdminService>();
        services.AddScoped<IAirportAdminService, AirportAdminService>();
        services.AddScoped<IAirlineAdminService, AirlineAdminService>();
        services.AddScoped<IDestinationAdminService, DestinationAdminService>();
        services.AddScoped<IFlightAdminService, FlightAdminService>();
        services.AddScoped<IAdminUserService, AdminUserService>();
        services.AddScoped<IDestinationService, DestinationService>();
        services.AddScoped<IFlightService, FlightService>();
        services.AddScoped<IRecommendationService, RecommendationService>();
        services.AddScoped<IReportService, ReportService>();
        services.AddScoped<INotificationService, NotificationService>();
        services.AddScoped<INewsService, NewsService>();
        services.AddScoped<IPaymentService, PaymentService>();
        services.AddScoped<ISupportMessageService, SupportMessageService>();
        services.AddScoped<ReservationStateMachine>();
        services.AddScoped<IReservationService, ReservationService>();
        services.AddScoped<IdentityDataSeeder>();

        return services;
    }

    public static IServiceCollection AddJetGoWorkerInfrastructure(
        this IServiceCollection services,
        string connectionString,
        RabbitMqSettings rabbitMqSettings)
    {
        services.AddSingleton(rabbitMqSettings);

        services.AddDbContext<JetGoDbContext>(options =>
            options.UseSqlServer(connectionString, sqlOptions => sqlOptions.EnableRetryOnFailure()));

        services.AddSingleton<IRabbitMqPersistentConnection, RabbitMqPersistentConnection>();

        return services;
    }
}
