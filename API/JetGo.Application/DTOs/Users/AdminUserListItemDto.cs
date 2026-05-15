namespace JetGo.Application.DTOs.Users;

public sealed class AdminUserListItemDto
{
    public string UserId { get; init; } = string.Empty;

    public string Username { get; init; } = string.Empty;

    public string FirstName { get; init; } = string.Empty;

    public string LastName { get; init; } = string.Empty;

    public string FullName { get; init; } = string.Empty;

    public string Email { get; init; } = string.Empty;

    public string? PhoneNumber { get; init; }

    public bool IsActive { get; init; }

    public IReadOnlyCollection<string> Roles { get; init; } = Array.Empty<string>();

    public int ReservationsCount { get; init; }

    public int PaymentsCount { get; init; }

    public DateTime? CreatedAtUtc { get; init; }
}
