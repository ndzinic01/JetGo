using JetGo.Domain.Entities;
using JetGo.Infrastructure.Configurations.Common;
using JetGo.Infrastructure.Seed;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace JetGo.Infrastructure.Configurations;

public sealed class DestinationConfiguration : AuditableEntityConfiguration<Destination>
{
    protected override void ConfigureEntity(EntityTypeBuilder<Destination> builder)
    {
        builder.ToTable("Destinations", tableBuilder =>
        {
            tableBuilder.HasCheckConstraint("CK_Destinations_DifferentAirports", "[DepartureAirportId] <> [ArrivalAirportId]");
        });

        builder.Property(x => x.RouteCode).IsRequired().HasMaxLength(20);

        builder.HasIndex(x => x.RouteCode).IsUnique();

        builder.HasOne(x => x.DepartureAirport)
            .WithMany(x => x.DepartureDestinations)
            .HasForeignKey(x => x.DepartureAirportId)
            .OnDelete(DeleteBehavior.Restrict);

        builder.HasOne(x => x.ArrivalAirport)
            .WithMany(x => x.ArrivalDestinations)
            .HasForeignKey(x => x.ArrivalAirportId)
            .OnDelete(DeleteBehavior.Restrict);

        builder.HasMany(x => x.Flights)
            .WithOne(x => x.Destination)
            .HasForeignKey(x => x.DestinationId)
            .OnDelete(DeleteBehavior.Restrict);

        builder.HasData(JetGoSeedData.Destinations);
    }
}
