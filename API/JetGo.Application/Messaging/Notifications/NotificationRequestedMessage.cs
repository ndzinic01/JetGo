using JetGo.Domain.Enums;

namespace JetGo.Application.Messaging.Notifications;

public sealed class NotificationRequestedMessage
{
    public Guid EventId { get; init; } = Guid.NewGuid();

    public string UserId { get; init; } = string.Empty;

    public NotificationType Type { get; init; } = NotificationType.System;

    public string Title { get; init; } = string.Empty;

    public string Body { get; init; } = string.Empty;

    public DateTime OccurredAtUtc { get; init; } = DateTime.UtcNow;

    public int? FlightId { get; init; }

    public string? FlightNumber { get; init; }

    public int? ReservationId { get; init; }

    public string? ReservationCode { get; init; }
}
