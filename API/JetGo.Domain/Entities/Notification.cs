using JetGo.Domain.Common;
using JetGo.Domain.Enums;

namespace JetGo.Domain.Entities;

public sealed class Notification : AuditableEntity
{
    public string UserId { get; set; } = string.Empty;

    public NotificationType Type { get; set; } = NotificationType.System;

    public string Title { get; set; } = string.Empty;

    public string Body { get; set; } = string.Empty;

    public NotificationStatus Status { get; set; } = NotificationStatus.Unread;

    public DateTime? ReadAtUtc { get; set; }

    public int? FlightId { get; set; }

    public string? FlightNumber { get; set; }

    public int? ReservationId { get; set; }

    public string? ReservationCode { get; set; }
}
