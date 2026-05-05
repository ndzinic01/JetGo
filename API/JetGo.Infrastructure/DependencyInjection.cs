using System.IdentityModel.Tokens.Jwt;
using System.Text;
using JetGo.Application.Configuration;
using JetGo.Application.Contracts.Messaging;
using JetGo.Application.Contracts.Services;
using JetGo.Infrastructure.Messaging;
using JetGo.Infrastructure.Identity;
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
        bool includeWebSecurity = true)
    {
        services.AddSingleton(jwtSettings);
        services.AddSingleton(rabbitMqSettings);

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
                            var jwtId = context.Principal?.FindFirst(JwtRegisteredClaimNames.Jti)?.Value;

                            if (string.IsNullOrWhiteSpace(jwtId))
                            {
                                context.Fail("Token ne sadrzi JTI identifikator.");
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
                            }
                        }
                    };
                });

            services.AddAuthorization();
        }

        services.AddHttpContextAccessor();
        services.AddSingleton<IRabbitMqPersistentConnection, RabbitMqPersistentConnection>();
        services.AddScoped<INotificationEventPublisher, RabbitMqNotificationEventPublisher>();
        services.AddScoped<JwtTokenGenerator>();
        services.AddScoped<IAuthService, AuthService>();
        services.AddScoped<IProfileService, ProfileService>();
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
