using JetGo.Domain.Common;
using JetGo.Domain.Enums;

namespace JetGo.Domain.Entities;

public sealed class ReservationPassenger : BaseEntity
{
    public int ReservationId { get; set; }

    public Reservation Reservation { get; set; } = null!;

    public string SeatNumber { get; set; } = string.Empty;

    public string FirstName { get; set; } = string.Empty;

    public string LastName { get; set; } = string.Empty;

    public PassengerGender Gender { get; set; }

    public string PassportNumber { get; set; } = string.Empty;
}
