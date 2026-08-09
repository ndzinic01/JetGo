namespace JetGo.Application.Configuration;

public sealed class SmtpSettings
{
    public string Host { get; init; } = string.Empty;

    public int Port { get; init; }

    public string? UserName { get; init; }

    public string? Password { get; init; }

    public bool UseSsl { get; init; }

    public string FromEmail { get; init; } = string.Empty;

    public string FromName { get; init; } = string.Empty;

    public bool IsConfigured =>
        !string.IsNullOrWhiteSpace(Host) &&
        Port > 0 &&
        !string.IsNullOrWhiteSpace(FromEmail);
}
