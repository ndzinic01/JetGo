namespace JetGo.Application.DTOs.Auth;

public sealed class AuthResponseDto
{
    public string TokenType { get; init; } = "Bearer";

    public string AccessToken { get; init; } = string.Empty;

    public DateTime ExpiresAtUtc { get; init; }

    public AuthenticatedUserDto User { get; init; } = new();
}
