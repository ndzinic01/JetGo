using JetGo.Domain.Common;

namespace JetGo.Domain.Entities;

public sealed class NewsArticle : AuditableEntity
{
    public string Title { get; set; } = string.Empty;

    public string Content { get; set; } = string.Empty;

    public string ImageUrl { get; set; } = string.Empty;

    public bool IsPublished { get; set; } = true;

    public DateTime PublishedAtUtc { get; set; }
}
