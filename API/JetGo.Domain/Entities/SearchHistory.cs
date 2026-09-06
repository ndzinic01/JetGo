using JetGo.Domain.Common;

namespace JetGo.Domain.Entities;

public sealed class SearchHistory : AuditableEntity
{
    public string UserId { get; set; } = string.Empty;

    public string SearchTerm { get; set; } = string.Empty;

    public int? DestinationId { get; set; }

    public Destination? Destination { get; set; }

    public int? DepartureAirportId { get; set; }

    public Airport? DepartureAirport { get; set; }

    public int? ArrivalAirportId { get; set; }

    public Airport? ArrivalAirport { get; set; }

    public int? AirlineId { get; set; }

    public Airline? Airline { get; set; }
}
