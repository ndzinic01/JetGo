using JetGo.Domain.Entities;
using JetGo.Infrastructure.Configurations.Common;
using JetGo.Infrastructure.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace JetGo.Infrastructure.Configurations;

public sealed class SupportMessageConfiguration : AuditableEntityConfiguration<SupportMessage>
{
    protected override void ConfigureEntity(EntityTypeBuilder<SupportMessage> builder)
    {
        builder.ToTable("SupportMessages");

        builder.Property(x => x.UserId).IsRequired().HasMaxLength(450);
        builder.Property(x => x.Subject).IsRequired().HasMaxLength(200);
        builder.Property(x => x.Message).IsRequired().HasMaxLength(4000);
        builder.Property(x => x.AdminReply).HasMaxLength(4000);

        builder.HasOne<AppUser>()
            .WithMany(x => x.SupportMessages)
            .HasForeignKey(x => x.UserId)
            .OnDelete(DeleteBehavior.Cascade);
    }
}
