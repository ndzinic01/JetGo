namespace JetGo.Application.Configuration;

public sealed class SmtpSettings
{
    public string Host { get; init; } = "localhost";

    public int Port { get; init; } = 1025;

    public string? UserName { get; init; }

    public string? Password { get; init; }

    public bool UseSsl { get; init; }

    public string FromEmail { get; init; } = "no-reply@jetgo.local";

    public string FromName { get; init; } = "JetGo";

    public bool IsConfigured =>
        !string.IsNullOrWhiteSpace(Host) &&
        Port > 0 &&
        !string.IsNullOrWhiteSpace(FromEmail);
}
