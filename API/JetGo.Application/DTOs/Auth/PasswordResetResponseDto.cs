namespace JetGo.Application.DTOs.Auth;

public sealed class PasswordResetResponseDto
{
    public string Message { get; init; } = string.Empty;

    public string? DebugResetToken { get; init; }

    public DateTime? ExpiresAtUtc { get; init; }
}
