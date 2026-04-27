namespace JetGo.Application.DTOs.Notifications;

public sealed class NotificationSummaryDto
{
    public int TotalCount { get; init; }

    public int UnreadCount { get; init; }

    public DateTime? LatestCreatedAtUtc { get; init; }
}
