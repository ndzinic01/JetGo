using JetGo.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;

namespace JetGo.Infrastructure;

public static class DependencyInjection
{
    public static IServiceCollection AddJetGoInfrastructure(this IServiceCollection services, string connectionString)
    {
        services.AddDbContext<JetGoDbContext>(options =>
            options.UseSqlServer(connectionString, sqlOptions => sqlOptions.EnableRetryOnFailure()));

        return services;
    }
}
