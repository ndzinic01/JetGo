using JetGo.Domain.Entities;
using JetGo.Infrastructure.Configurations.Common;
using JetGo.Infrastructure.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace JetGo.Infrastructure.Configurations;

public sealed class RevokedTokenConfiguration : AuditableEntityConfiguration<RevokedToken>
{
    protected override void ConfigureEntity(EntityTypeBuilder<RevokedToken> builder)
    {
        builder.ToTable("RevokedTokens");

        builder.Property(x => x.JwtId).IsRequired().HasMaxLength(100);
        builder.Property(x => x.UserId).IsRequired().HasMaxLength(450);
        builder.Property(x => x.Reason).HasMaxLength(200);

        builder.HasIndex(x => x.JwtId).IsUnique();

        builder.HasOne<AppUser>()
            .WithMany(x => x.RevokedTokens)
            .HasForeignKey(x => x.UserId)
            .OnDelete(DeleteBehavior.Cascade);
    }
}
