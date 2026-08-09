namespace JetGo.Application.Configuration;

public sealed class CorsSettings
{
    public IReadOnlyCollection<string> AllowedOrigins { get; init; } = Array.Empty<string>();
}
