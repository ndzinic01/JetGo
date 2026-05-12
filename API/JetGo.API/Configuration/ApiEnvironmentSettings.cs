using JetGo.Application.Configuration;

namespace JetGo.API.Configuration;

internal sealed class ApiEnvironmentSettings
{
    public string ConnectionString { get; init; } = string.Empty;

    public JwtSettings Jwt { get; init; } = new();

    public RabbitMqSettings RabbitMq { get; init; } = new();

    public PayPalSettings PayPal { get; init; } = new();
}
