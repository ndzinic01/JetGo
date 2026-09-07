using JetGo.Domain.Enums;

namespace JetGo.Application.DTOs.Notifications;

public sealed class AdminNotificationListItemDto
{
    public NotificationType Type { get; init; }

    public string Title { get; init; } = string.Empty;

    public string Body { get; init; } = string.Empty;

    public NotificationStatus Status { get; init; }

    public DateTime CreatedAtUtc { get; init; }

    public DateTime? ReadAtUtc { get; init; }

    public string? FlightNumber { get; init; }

    public string? ReservationCode { get; init; }

    public string RecipientName { get; init; } = string.Empty;

    public string RecipientEmail { get; init; } = string.Empty;
}
