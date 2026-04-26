using JetGo.Domain.Entities;
using JetGo.Infrastructure.Configurations.Common;
using JetGo.Infrastructure.Seed;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace JetGo.Infrastructure.Configurations;

public sealed class CityConfiguration : AuditableEntityConfiguration<City>
{
    protected override void ConfigureEntity(EntityTypeBuilder<City> builder)
    {
        builder.ToTable("Cities");

        builder.Property(x => x.Name).IsRequired().HasMaxLength(100);

        builder.HasIndex(x => new { x.CountryId, x.Name }).IsUnique();

        builder.HasOne(x => x.Country)
            .WithMany(x => x.Cities)
            .HasForeignKey(x => x.CountryId)
            .OnDelete(DeleteBehavior.Restrict);

        builder.HasMany(x => x.Airports)
            .WithOne(x => x.City)
            .HasForeignKey(x => x.CityId)
            .OnDelete(DeleteBehavior.Restrict);

        builder.HasData(JetGoSeedData.Cities);
    }
}
