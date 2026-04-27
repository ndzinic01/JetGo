using JetGo.Infrastructure.Configuration;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Design;

namespace JetGo.Infrastructure.Persistence;

public sealed class JetGoDbContextFactory : IDesignTimeDbContextFactory<JetGoDbContext>
{
    public JetGoDbContext CreateDbContext(string[] args)
    {
        DotEnvLoader.LoadNearest(Directory.GetCurrentDirectory());

        var connectionString = Environment.GetEnvironmentVariable("JETGO_CONNECTION_STRING");

        if (string.IsNullOrWhiteSpace(connectionString))
        {
            throw new InvalidOperationException("Environment variable 'JETGO_CONNECTION_STRING' was not found.");
        }

        var optionsBuilder = new DbContextOptionsBuilder<JetGoDbContext>();
        optionsBuilder.UseSqlServer(connectionString, sqlOptions => sqlOptions.EnableRetryOnFailure());

        return new JetGoDbContext(optionsBuilder.Options);
    }
}
