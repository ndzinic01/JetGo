using JetGo.Domain.Common;
using JetGo.Domain.Enums;

namespace JetGo.Domain.Entities;

public sealed class Flight : AuditableEntity
{
    public int AirlineId { get; set; }

    public Airline Airline { get; set; } = null!;

    public int DestinationId { get; set; }

    public Destination Destination { get; set; } = null!;

    public string FlightNumber { get; set; } = string.Empty;

    public DateTime DepartureAtUtc { get; set; }

    public DateTime ArrivalAtUtc { get; set; }

    public decimal BasePrice { get; set; }

    public int TotalSeats { get; set; }

    public int AvailableSeats { get; set; }

    public FlightStatus Status { get; set; } = FlightStatus.Scheduled;

    public ICollection<FlightSeat> Seats { get; set; } = new List<FlightSeat>();

    public ICollection<Reservation> Reservations { get; set; } = new List<Reservation>();
}
