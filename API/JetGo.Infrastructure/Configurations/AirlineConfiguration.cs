using JetGo.Domain.Entities;
using JetGo.Infrastructure.Configurations.Common;
using JetGo.Infrastructure.Seed;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace JetGo.Infrastructure.Configurations;

public sealed class AirlineConfiguration : AuditableEntityConfiguration<Airline>
{
    protected override void ConfigureEntity(EntityTypeBuilder<Airline> builder)
    {
        builder.ToTable("Airlines");

        builder.Property(x => x.Name).IsRequired().HasMaxLength(150);
        builder.Property(x => x.Code).IsRequired().HasMaxLength(10);
        builder.Property(x => x.LogoUrl).HasMaxLength(500);

        builder.HasIndex(x => x.Name).IsUnique();
        builder.HasIndex(x => x.Code).IsUnique();

        builder.HasData(JetGoSeedData.Airlines);
    }
}
