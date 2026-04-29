using JetGo.Application.Messaging.Notifications;

namespace JetGo.Application.Contracts.Messaging;

public interface INotificationEventPublisher
{
    Task PublishAsync(NotificationRequestedMessage message, CancellationToken cancellationToken = default);
}
