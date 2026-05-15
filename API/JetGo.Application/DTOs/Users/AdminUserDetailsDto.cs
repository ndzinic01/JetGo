namespace JetGo.Application.DTOs.Users;

public sealed class AdminUserDetailsDto
{
    public string UserId { get; init; } = string.Empty;

    public string Username { get; init; } = string.Empty;

    public string FirstName { get; init; } = string.Empty;

    public string LastName { get; init; } = string.Empty;

    public string FullName { get; init; } = string.Empty;

    public string Email { get; init; } = string.Empty;

    public string? PhoneNumber { get; init; }

    public string? ImageUrl { get; init; }

    public bool IsActive { get; init; }

    public DateTimeOffset? LockoutEndUtc { get; init; }

    public IReadOnlyCollection<string> Roles { get; init; } = Array.Empty<string>();

    public int ReservationsCount { get; init; }

    public int PaymentsCount { get; init; }

    public int SupportMessagesCount { get; init; }

    public int SearchHistoryCount { get; init; }

    public int UnreadNotificationsCount { get; init; }

    public DateTime? CreatedAtUtc { get; init; }

    public DateTime? UpdatedAtUtc { get; init; }
}
