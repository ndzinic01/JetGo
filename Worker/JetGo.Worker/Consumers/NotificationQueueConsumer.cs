using System.Text;
using System.Text.Json;
using JetGo.Application.Configuration;
using JetGo.Application.Messaging.Notifications;
using JetGo.Domain.Entities;
using JetGo.Domain.Enums;
using JetGo.Infrastructure.Messaging;
using JetGo.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using RabbitMQ.Client;
using RabbitMQ.Client.Events;

namespace JetGo.Worker.Consumers;

public sealed class NotificationQueueConsumer : BackgroundService
{
    private static readonly JsonSerializerOptions SerializerOptions = new(JsonSerializerDefaults.Web);

    private readonly IRabbitMqPersistentConnection _persistentConnection;
    private readonly RabbitMqSettings _settings;
    private readonly IServiceScopeFactory _serviceScopeFactory;
    private readonly ILogger<NotificationQueueConsumer> _logger;
    private IModel? _channel;

    public NotificationQueueConsumer(
        IRabbitMqPersistentConnection persistentConnection,
        RabbitMqSettings settings,
        IServiceScopeFactory serviceScopeFactory,
        ILogger<NotificationQueueConsumer> logger)
    {
        _persistentConnection = persistentConnection;
        _settings = settings;
        _serviceScopeFactory = serviceScopeFactory;
        _logger = logger;
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        _channel = _persistentConnection.GetConnection().CreateModel();
        _channel.QueueDeclare(
            queue: _settings.NotificationsQueueName,
            durable: true,
            exclusive: false,
            autoDelete: false,
            arguments: null);
        _channel.BasicQos(0, 1, false);

        var consumer = new AsyncEventingBasicConsumer(_channel);
        consumer.Received += async (_, eventArgs) =>
        {
            var payload = Encoding.UTF8.GetString(eventArgs.Body.ToArray());

            try
            {
                await ProcessWithRetryAsync(payload, stoppingToken);
                _channel.BasicAck(eventArgs.DeliveryTag, false);
            }
            catch (Exception exception)
            {
                _logger.LogError(
                    exception,
                    "Notification worker failed to process message with delivery tag {DeliveryTag}.",
                    eventArgs.DeliveryTag);

                if (_channel.IsOpen)
                {
                    _channel.BasicNack(eventArgs.DeliveryTag, false, requeue: false);
                }
            }
        };

        _channel.BasicConsume(
            queue: _settings.NotificationsQueueName,
            autoAck: false,
            consumer: consumer);

        _logger.LogInformation(
            "Notification worker is listening on queue {QueueName}.",
            _settings.NotificationsQueueName);

        await Task.Delay(Timeout.Infinite, stoppingToken);
    }

    public override void Dispose()
    {
        _channel?.Dispose();
        base.Dispose();
    }

    private async Task ProcessWithRetryAsync(string payload, CancellationToken cancellationToken)
    {
        var retryDelays = new[]
        {
            TimeSpan.Zero,
            TimeSpan.FromSeconds(1),
            TimeSpan.FromSeconds(2),
            TimeSpan.FromSeconds(4)
        };

        Exception? lastException = null;

        for (var attempt = 0; attempt < retryDelays.Length; attempt++)
        {
            cancellationToken.ThrowIfCancellationRequested();

            if (retryDelays[attempt] > TimeSpan.Zero)
            {
                await Task.Delay(retryDelays[attempt], cancellationToken);
            }

            try
            {
                await ProcessMessageAsync(payload, cancellationToken);
                return;
            }
            catch (Exception exception)
            {
                lastException = exception;

                _logger.LogWarning(
                    exception,
                    "Notification worker attempt {Attempt} failed.",
                    attempt + 1);
            }
        }

        throw lastException ?? new InvalidOperationException("Notification worker failed without a concrete exception.");
    }

    private async Task ProcessMessageAsync(string payload, CancellationToken cancellationToken)
    {
        var message = JsonSerializer.Deserialize<NotificationRequestedMessage>(payload, SerializerOptions)
            ?? throw new InvalidOperationException("Notification queue message payload is invalid.");

        await using var scope = _serviceScopeFactory.CreateAsyncScope();
        var dbContext = scope.ServiceProvider.GetRequiredService<JetGoDbContext>();

        var userExists = await dbContext.Users
            .AsNoTracking()
            .AnyAsync(x => x.Id == message.UserId, cancellationToken);

        if (!userExists)
        {
            throw new InvalidOperationException($"User '{message.UserId}' referenced by notification event does not exist.");
        }

        var createdAtUtc = message.OccurredAtUtc.Kind == DateTimeKind.Unspecified
            ? DateTime.SpecifyKind(message.OccurredAtUtc, DateTimeKind.Utc)
            : message.OccurredAtUtc.ToUniversalTime();

        await dbContext.Notifications.AddAsync(new Notification
        {
            UserId = message.UserId,
            Title = message.Title,
            Body = message.Body,
            Status = NotificationStatus.Unread,
            CreatedAtUtc = createdAtUtc
        }, cancellationToken);

        await dbContext.SaveChangesAsync(cancellationToken);

        _logger.LogInformation(
            "Notification event {EventId} stored for user {UserId}.",
            message.EventId,
            message.UserId);
    }
}
