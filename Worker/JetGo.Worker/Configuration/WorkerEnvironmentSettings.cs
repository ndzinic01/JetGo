using JetGo.Application.Configuration;

namespace JetGo.Worker.Configuration;

internal sealed class WorkerEnvironmentSettings
{
    public string ConnectionString { get; init; } = string.Empty;

    public RabbitMqSettings RabbitMq { get; init; } = new();
}
