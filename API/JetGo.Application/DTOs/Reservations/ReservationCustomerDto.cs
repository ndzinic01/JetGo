namespace JetGo.Application.DTOs.Reservations;

public sealed class ReservationCustomerDto
{
    public string UserId { get; init; } = string.Empty;

    public string Username { get; init; } = string.Empty;

    public string FullName { get; init; } = string.Empty;

    public string Email { get; init; } = string.Empty;
}
