using JetGo.Domain.Common;

namespace JetGo.Domain.Entities;

public sealed class ReservationItem : BaseEntity
{
    public int ReservationId { get; set; }

    public Reservation Reservation { get; set; } = null!;

    public int FlightSeatId { get; set; }

    public FlightSeat FlightSeat { get; set; } = null!;

    public decimal Price { get; set; }
}
