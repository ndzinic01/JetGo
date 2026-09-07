using JetGo.Domain.Enums;

namespace JetGo.Application.DTOs.Reservations;

public sealed class ReservationPassengerDto
{
    public string SeatNumber { get; init; } = string.Empty;

    public string FirstName { get; init; } = string.Empty;

    public string LastName { get; init; } = string.Empty;

    public PassengerGender Gender { get; init; }

    public string PassportNumber { get; init; } = string.Empty;
}
