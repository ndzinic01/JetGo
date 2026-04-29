namespace JetGo.Application.Configuration;

public sealed class RabbitMqSettings
{
    public string Host { get; init; } = string.Empty;

    public int Port { get; init; }

    public string UserName { get; init; } = string.Empty;

    public string Password { get; init; } = string.Empty;

    public string VirtualHost { get; init; } = "/";

    public string NotificationsQueueName { get; init; } = string.Empty;
}
