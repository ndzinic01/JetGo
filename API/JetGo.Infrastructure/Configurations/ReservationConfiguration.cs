using JetGo.Domain.Entities;
using JetGo.Domain.Enums;
using JetGo.Infrastructure.Configurations.Common;
using JetGo.Infrastructure.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace JetGo.Infrastructure.Configurations;

public sealed class ReservationConfiguration : AuditableEntityConfiguration<Reservation>
{
    protected override void ConfigureEntity(EntityTypeBuilder<Reservation> builder)
    {
        builder.ToTable("Reservations");

        builder.Property(x => x.UserId).IsRequired().HasMaxLength(450);
        builder.Property(x => x.Currency).IsRequired().HasMaxLength(3);
        builder.Property(x => x.TotalAmount).HasPrecision(18, 2);
        builder.Property(x => x.Status).HasConversion<int>();

        builder.HasOne<AppUser>()
            .WithMany(x => x.Reservations)
            .HasForeignKey(x => x.UserId)
            .OnDelete(DeleteBehavior.Restrict);

        builder.HasOne(x => x.Flight)
            .WithMany(x => x.Reservations)
            .HasForeignKey(x => x.FlightId)
            .OnDelete(DeleteBehavior.Restrict);

        builder.HasMany(x => x.Items)
            .WithOne(x => x.Reservation)
            .HasForeignKey(x => x.ReservationId)
            .OnDelete(DeleteBehavior.Cascade);

        builder.HasOne(x => x.Payment)
            .WithOne(x => x.Reservation)
            .HasForeignKey<Payment>(x => x.ReservationId)
            .OnDelete(DeleteBehavior.Cascade);
    }
}
