using JetGo.Domain.Entities;
using JetGo.Domain.Enums;
using JetGo.Infrastructure.Configurations.Common;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace JetGo.Infrastructure.Configurations;

public sealed class FlightConfiguration : AuditableEntityConfiguration<Flight>
{
    protected override void ConfigureEntity(EntityTypeBuilder<Flight> builder)
    {
        builder.ToTable("Flights", tableBuilder =>
        {
            tableBuilder.HasCheckConstraint("CK_Flights_ArrivalAfterDeparture", "[ArrivalAtUtc] > [DepartureAtUtc]");
            tableBuilder.HasCheckConstraint("CK_Flights_SeatsPositive", "[TotalSeats] >= 0 AND [AvailableSeats] >= 0");
        });

        builder.Property(x => x.FlightNumber).IsRequired().HasMaxLength(20);
        builder.Property(x => x.DepartureAtUtc).IsRequired();
        builder.Property(x => x.ArrivalAtUtc).IsRequired();
        builder.Property(x => x.BasePrice).HasPrecision(18, 2);
        builder.Property(x => x.Status).HasConversion<int>();

        builder.HasIndex(x => x.FlightNumber).IsUnique();

        builder.HasOne(x => x.Airline)
            .WithMany(x => x.Flights)
            .HasForeignKey(x => x.AirlineId)
            .OnDelete(DeleteBehavior.Restrict);

        builder.HasOne(x => x.Destination)
            .WithMany(x => x.Flights)
            .HasForeignKey(x => x.DestinationId)
            .OnDelete(DeleteBehavior.Restrict);

        builder.HasMany(x => x.Seats)
            .WithOne(x => x.Flight)
            .HasForeignKey(x => x.FlightId)
            .OnDelete(DeleteBehavior.Cascade);

        builder.HasMany(x => x.Reservations)
            .WithOne(x => x.Flight)
            .HasForeignKey(x => x.FlightId)
            .OnDelete(DeleteBehavior.Restrict);
    }
}
