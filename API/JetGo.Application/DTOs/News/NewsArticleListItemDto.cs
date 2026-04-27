namespace JetGo.Application.DTOs.News;

public sealed class NewsArticleListItemDto
{
    public int Id { get; init; }

    public string Title { get; init; } = string.Empty;

    public string ImageUrl { get; init; } = string.Empty;

    public bool IsPublished { get; init; }

    public DateTime PublishedAtUtc { get; init; }
}
