namespace JetGo.Application.DTOs.News;

public sealed class NewsArticleDetailsDto
{
    public int Id { get; init; }

    public string Title { get; init; } = string.Empty;

    public string Content { get; init; } = string.Empty;

    public string ImageUrl { get; init; } = string.Empty;

    public bool IsPublished { get; init; }

    public DateTime PublishedAtUtc { get; init; }

    public DateTime CreatedAtUtc { get; init; }
}
