using JetGo.Domain.Entities;
using JetGo.Infrastructure.Configurations.Common;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace JetGo.Infrastructure.Configurations;

public sealed class FlightSeatConfiguration : BaseEntityConfiguration<FlightSeat>
{
    public override void Configure(EntityTypeBuilder<FlightSeat> builder)
    {
        base.Configure(builder);

        builder.ToTable("FlightSeats");

        builder.Property(x => x.SeatNumber).IsRequired().HasMaxLength(10);

        builder.HasIndex(x => new { x.FlightId, x.SeatNumber }).IsUnique();

        builder.HasOne(x => x.Flight)
            .WithMany(x => x.Seats)
            .HasForeignKey(x => x.FlightId)
            .OnDelete(DeleteBehavior.Cascade);
    }
}
