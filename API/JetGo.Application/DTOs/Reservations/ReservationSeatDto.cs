namespace JetGo.Application.DTOs.Reservations;

public sealed class ReservationSeatDto
{
    public int FlightSeatId { get; init; }

    public string SeatNumber { get; init; } = string.Empty;

    public decimal Price { get; init; }
}
