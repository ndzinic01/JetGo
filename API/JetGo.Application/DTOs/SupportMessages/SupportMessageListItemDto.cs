namespace JetGo.Application.DTOs.SupportMessages;

public sealed class SupportMessageListItemDto
{
    public int Id { get; init; }

    public string Subject { get; init; } = string.Empty;

    public string MessagePreview { get; init; } = string.Empty;

    public bool IsReplied { get; init; }

    public DateTime CreatedAtUtc { get; init; }

    public DateTime? RepliedAtUtc { get; init; }

    public string CustomerName { get; init; } = string.Empty;

    public string CustomerEmail { get; init; } = string.Empty;
}
