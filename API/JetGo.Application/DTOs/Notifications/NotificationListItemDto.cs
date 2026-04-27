using JetGo.Domain.Enums;

namespace JetGo.Application.DTOs.Notifications;

public sealed class NotificationListItemDto
{
    public int Id { get; init; }

    public string Title { get; init; } = string.Empty;

    public string Body { get; init; } = string.Empty;

    public NotificationStatus Status { get; init; }

    public DateTime CreatedAtUtc { get; init; }

    public DateTime? ReadAtUtc { get; init; }
}
