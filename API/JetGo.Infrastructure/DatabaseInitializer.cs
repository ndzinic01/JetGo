using JetGo.Infrastructure.Persistence;
using JetGo.Infrastructure.Seed;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;

namespace JetGo.Infrastructure;

public static class DatabaseInitializer
{
    public static async Task InitializeDatabaseAsync(this IServiceProvider serviceProvider, CancellationToken cancellationToken = default)
    {
        using var scope = serviceProvider.CreateScope();

        var dbContext = scope.ServiceProvider.GetRequiredService<JetGoDbContext>();
        await dbContext.Database.MigrateAsync(cancellationToken);

        var identityDataSeeder = scope.ServiceProvider.GetRequiredService<IdentityDataSeeder>();
        await identityDataSeeder.SeedAsync(cancellationToken);
    }
}
