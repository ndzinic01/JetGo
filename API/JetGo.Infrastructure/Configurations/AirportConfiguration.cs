using JetGo.Domain.Entities;
using JetGo.Infrastructure.Configurations.Common;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace JetGo.Infrastructure.Configurations;

public sealed class AirportConfiguration : AuditableEntityConfiguration<Airport>
{
    protected override void ConfigureEntity(EntityTypeBuilder<Airport> builder)
    {
        builder.ToTable("Airports");

        builder.Property(x => x.Name).IsRequired().HasMaxLength(150);
        builder.Property(x => x.IataCode).IsRequired().HasMaxLength(3);
        builder.Property(x => x.Latitude).HasPrecision(9, 6);
        builder.Property(x => x.Longitude).HasPrecision(9, 6);

        builder.HasIndex(x => x.IataCode).IsUnique();

        builder.HasOne(x => x.City)
            .WithMany(x => x.Airports)
            .HasForeignKey(x => x.CityId)
            .OnDelete(DeleteBehavior.Restrict);

        builder.HasMany(x => x.DepartureDestinations)
            .WithOne(x => x.DepartureAirport)
            .HasForeignKey(x => x.DepartureAirportId)
            .OnDelete(DeleteBehavior.Restrict);

        builder.HasMany(x => x.ArrivalDestinations)
            .WithOne(x => x.ArrivalAirport)
            .HasForeignKey(x => x.ArrivalAirportId)
            .OnDelete(DeleteBehavior.Restrict);
    }
}
