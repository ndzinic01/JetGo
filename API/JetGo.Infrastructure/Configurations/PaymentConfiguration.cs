using JetGo.Domain.Entities;
using JetGo.Domain.Enums;
using JetGo.Infrastructure.Configurations.Common;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace JetGo.Infrastructure.Configurations;

public sealed class PaymentConfiguration : AuditableEntityConfiguration<Payment>
{
    protected override void ConfigureEntity(EntityTypeBuilder<Payment> builder)
    {
        builder.ToTable("Payments");

        builder.Property(x => x.Provider).IsRequired().HasMaxLength(50);
        builder.Property(x => x.ProviderReference).HasMaxLength(200);
        builder.Property(x => x.Amount).HasPrecision(18, 2);
        builder.Property(x => x.Currency).IsRequired().HasMaxLength(3);
        builder.Property(x => x.Status).HasConversion<int>();

        builder.HasIndex(x => x.ReservationId).IsUnique();

        builder.HasOne(x => x.Reservation)
            .WithOne(x => x.Payment)
            .HasForeignKey<Payment>(x => x.ReservationId)
            .OnDelete(DeleteBehavior.Cascade);
    }
}
