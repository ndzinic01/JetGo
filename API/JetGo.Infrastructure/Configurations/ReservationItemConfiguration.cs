using JetGo.Domain.Entities;
using JetGo.Infrastructure.Configurations.Common;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace JetGo.Infrastructure.Configurations;

public sealed class ReservationItemConfiguration : BaseEntityConfiguration<ReservationItem>
{
    public override void Configure(EntityTypeBuilder<ReservationItem> builder)
    {
        base.Configure(builder);

        builder.ToTable("ReservationItems");

        builder.Property(x => x.Price).HasPrecision(18, 2);

        builder.HasOne(x => x.Reservation)
            .WithMany(x => x.Items)
            .HasForeignKey(x => x.ReservationId)
            .OnDelete(DeleteBehavior.Cascade);

        builder.HasOne(x => x.FlightSeat)
            .WithMany()
            .HasForeignKey(x => x.FlightSeatId)
            .OnDelete(DeleteBehavior.Restrict);
    }
}
