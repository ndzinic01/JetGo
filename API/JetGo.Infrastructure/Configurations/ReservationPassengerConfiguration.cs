using JetGo.Domain.Entities;
using JetGo.Infrastructure.Configurations.Common;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace JetGo.Infrastructure.Configurations;

public sealed class ReservationPassengerConfiguration : BaseEntityConfiguration<ReservationPassenger>
{
    public override void Configure(EntityTypeBuilder<ReservationPassenger> builder)
    {
        base.Configure(builder);

        builder.ToTable("ReservationPassengers");

        builder.Property(x => x.SeatNumber).IsRequired().HasMaxLength(10);
        builder.Property(x => x.FirstName).IsRequired().HasMaxLength(50);
        builder.Property(x => x.LastName).IsRequired().HasMaxLength(50);
        builder.Property(x => x.Gender).HasConversion<int>();
        builder.Property(x => x.PassportNumber).IsRequired().HasMaxLength(20);

        builder.HasIndex(x => x.ReservationId);
        builder.HasIndex(x => new { x.ReservationId, x.SeatNumber }).IsUnique();

        builder.HasOne(x => x.Reservation)
            .WithMany(x => x.Passengers)
            .HasForeignKey(x => x.ReservationId)
            .OnDelete(DeleteBehavior.Cascade);
    }
}
