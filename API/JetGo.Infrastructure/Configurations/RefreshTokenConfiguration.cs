using JetGo.Domain.Entities;
using JetGo.Infrastructure.Configurations.Common;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace JetGo.Infrastructure.Configurations;

public sealed class RefreshTokenConfiguration : AuditableEntityConfiguration<RefreshToken>
{
    protected override void ConfigureEntity(EntityTypeBuilder<RefreshToken> builder)
    {
        builder.ToTable("RefreshTokens");

        builder.Property(x => x.UserId).IsRequired().HasMaxLength(450);
        builder.Property(x => x.Token).IsRequired().HasMaxLength(500);

        builder.HasIndex(x => x.Token).IsUnique();
    }
}
