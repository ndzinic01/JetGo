namespace JetGo.Application.Messaging.Notifications;

public sealed class NotificationRequestedMessage
{
    public Guid EventId { get; init; } = Guid.NewGuid();

    public string UserId { get; init; } = string.Empty;

    public string Title { get; init; } = string.Empty;

    public string Body { get; init; } = string.Empty;

    public DateTime OccurredAtUtc { get; init; } = DateTime.UtcNow;
}
