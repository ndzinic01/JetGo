using JetGo.Domain.Entities;
using JetGo.Infrastructure.Configurations.Common;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace JetGo.Infrastructure.Configurations;

public sealed class SearchHistoryConfiguration : AuditableEntityConfiguration<SearchHistory>
{
    protected override void ConfigureEntity(EntityTypeBuilder<SearchHistory> builder)
    {
        builder.ToTable("SearchHistories");

        builder.Property(x => x.UserId).IsRequired().HasMaxLength(450);
        builder.Property(x => x.SearchTerm).IsRequired().HasMaxLength(200);

        builder.HasOne(x => x.Destination)
            .WithMany()
            .HasForeignKey(x => x.DestinationId)
            .OnDelete(DeleteBehavior.SetNull);
    }
}
