using JetGo.Domain.Common;
using JetGo.Domain.Enums;

namespace JetGo.Domain.Entities;

public sealed class Notification : AuditableEntity
{
    public string UserId { get; set; } = string.Empty;

    public string Title { get; set; } = string.Empty;

    public string Body { get; set; } = string.Empty;

    public NotificationStatus Status { get; set; } = NotificationStatus.Unread;

    public DateTime? ReadAtUtc { get; set; }
}
