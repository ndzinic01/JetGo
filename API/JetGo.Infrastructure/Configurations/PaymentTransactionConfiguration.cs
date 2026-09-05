using JetGo.Domain.Entities;
using JetGo.Domain.Enums;
using JetGo.Infrastructure.Configurations.Common;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace JetGo.Infrastructure.Configurations;

public sealed class PaymentTransactionConfiguration : AuditableEntityConfiguration<PaymentTransaction>
{
    protected override void ConfigureEntity(EntityTypeBuilder<PaymentTransaction> builder)
    {
        builder.ToTable("PaymentTransactions");

        builder.Property(x => x.Type).HasConversion<int>();
        builder.Property(x => x.Status).HasConversion<int>();
        builder.Property(x => x.Provider).IsRequired().HasMaxLength(50);
        builder.Property(x => x.ProviderReference).HasMaxLength(200);
        builder.Property(x => x.RelatedProviderReference).HasMaxLength(200);
        builder.Property(x => x.Amount).HasPrecision(18, 2);
        builder.Property(x => x.Currency).IsRequired().HasMaxLength(3);
        builder.Property(x => x.Note).HasMaxLength(500);

        builder.HasIndex(x => x.PaymentId);
        builder.HasIndex(x => x.ProviderReference);

        builder.HasOne(x => x.Payment)
            .WithMany(x => x.Transactions)
            .HasForeignKey(x => x.PaymentId)
            .OnDelete(DeleteBehavior.Cascade);
    }
}
