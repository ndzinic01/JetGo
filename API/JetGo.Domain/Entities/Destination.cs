using JetGo.Domain.Common;

namespace JetGo.Domain.Entities;

public sealed class Destination : AuditableEntity
{
    public int DepartureAirportId { get; set; }

    public Airport DepartureAirport { get; set; } = null!;

    public int ArrivalAirportId { get; set; }

    public Airport ArrivalAirport { get; set; } = null!;

    public string RouteCode { get; set; } = string.Empty;

    public bool IsActive { get; set; } = true;

    public ICollection<Flight> Flights { get; set; } = new List<Flight>();
}
