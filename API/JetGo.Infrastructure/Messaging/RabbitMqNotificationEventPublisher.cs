using System.Text;
using System.Text.Json;
using JetGo.Application.Configuration;
using JetGo.Application.Contracts.Messaging;
using JetGo.Application.Messaging.Notifications;
using Microsoft.Extensions.Logging;
using RabbitMQ.Client;

namespace JetGo.Infrastructure.Messaging;

public sealed class RabbitMqNotificationEventPublisher : INotificationEventPublisher
{
    private static readonly JsonSerializerOptions SerializerOptions = new(JsonSerializerDefaults.Web);

    private readonly IRabbitMqPersistentConnection _persistentConnection;
    private readonly RabbitMqSettings _settings;
    private readonly ILogger<RabbitMqNotificationEventPublisher> _logger;

    public RabbitMqNotificationEventPublisher(
        IRabbitMqPersistentConnection persistentConnection,
        RabbitMqSettings settings,
        ILogger<RabbitMqNotificationEventPublisher> logger)
    {
        _persistentConnection = persistentConnection;
        _settings = settings;
        _logger = logger;
    }

    public Task PublishAsync(NotificationRequestedMessage message, CancellationToken cancellationToken = default)
    {
        cancellationToken.ThrowIfCancellationRequested();

        var connection = _persistentConnection.GetConnection();
        using var channel = connection.CreateModel();

        channel.QueueDeclare(
            queue: _settings.NotificationsQueueName,
            durable: true,
            exclusive: false,
            autoDelete: false,
            arguments: null);

        var body = JsonSerializer.SerializeToUtf8Bytes(message, SerializerOptions);
        var properties = channel.CreateBasicProperties();
        properties.Persistent = true;
        properties.MessageId = message.EventId.ToString("N");
        properties.Timestamp = new AmqpTimestamp(new DateTimeOffset(message.OccurredAtUtc).ToUnixTimeSeconds());
        properties.ContentType = "application/json";

        channel.BasicPublish(
            exchange: string.Empty,
            routingKey: _settings.NotificationsQueueName,
            basicProperties: properties,
            body: body);

        _logger.LogInformation(
            "Notification event {EventId} published to queue {QueueName} for user {UserId}.",
            message.EventId,
            _settings.NotificationsQueueName,
            message.UserId);

        return Task.CompletedTask;
    }
}
