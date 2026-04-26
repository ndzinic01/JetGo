using JetGo.Domain.Entities;
using JetGo.Infrastructure.Configurations.Common;
using JetGo.Infrastructure.Seed;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace JetGo.Infrastructure.Configurations;

public sealed class CountryConfiguration : AuditableEntityConfiguration<Country>
{
    protected override void ConfigureEntity(EntityTypeBuilder<Country> builder)
    {
        builder.ToTable("Countries");

        builder.Property(x => x.Name).IsRequired().HasMaxLength(100);
        builder.Property(x => x.IsoCode).IsRequired().HasMaxLength(2);

        builder.HasIndex(x => x.Name).IsUnique();
        builder.HasIndex(x => x.IsoCode).IsUnique();

        builder.HasMany(x => x.Cities)
            .WithOne(x => x.Country)
            .HasForeignKey(x => x.CountryId)
            .OnDelete(DeleteBehavior.Restrict);

        builder.HasData(JetGoSeedData.Countries);
    }
}
