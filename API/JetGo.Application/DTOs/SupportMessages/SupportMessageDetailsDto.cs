namespace JetGo.Application.DTOs.SupportMessages;

public sealed class SupportMessageDetailsDto
{
    public int Id { get; init; }

    public string Subject { get; init; } = string.Empty;

    public string Message { get; init; } = string.Empty;

    public string? AdminReply { get; init; }

    public bool IsReplied { get; init; }

    public DateTime CreatedAtUtc { get; init; }

    public DateTime? UpdatedAtUtc { get; init; }

    public DateTime? RepliedAtUtc { get; init; }

    public SupportMessageCustomerDto Customer { get; init; } = new();
}
