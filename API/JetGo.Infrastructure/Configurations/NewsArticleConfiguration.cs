using JetGo.Domain.Entities;
using JetGo.Infrastructure.Configurations.Common;
using JetGo.Infrastructure.Seed;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace JetGo.Infrastructure.Configurations;

public sealed class NewsArticleConfiguration : AuditableEntityConfiguration<NewsArticle>
{
    protected override void ConfigureEntity(EntityTypeBuilder<NewsArticle> builder)
    {
        builder.ToTable("NewsArticles");

        builder.Property(x => x.Title).IsRequired().HasMaxLength(200);
        builder.Property(x => x.Content).IsRequired().HasMaxLength(4000);
        builder.Property(x => x.ImageUrl).IsRequired().HasMaxLength(500);
        builder.Property(x => x.PublishedAtUtc).IsRequired();

        builder.HasData(JetGoSeedData.NewsArticles);
    }
}
