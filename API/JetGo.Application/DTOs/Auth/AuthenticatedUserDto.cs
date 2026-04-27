namespace JetGo.Application.DTOs.Auth;

public sealed class AuthenticatedUserDto
{
    public string UserId { get; init; } = string.Empty;

    public string Username { get; init; } = string.Empty;

    public string Email { get; init; } = string.Empty;

    public string FirstName { get; init; } = string.Empty;

    public string LastName { get; init; } = string.Empty;

    public string? PhoneNumber { get; init; }

    public IReadOnlyCollection<string> Roles { get; init; } = Array.Empty<string>();
}
