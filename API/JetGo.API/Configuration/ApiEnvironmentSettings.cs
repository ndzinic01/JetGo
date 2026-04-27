using JetGo.Application.Configuration;

namespace JetGo.API.Configuration;

internal sealed class ApiEnvironmentSettings
{
    public string ConnectionString { get; init; } = string.Empty;

    public JwtSettings Jwt { get; init; } = new();
}
