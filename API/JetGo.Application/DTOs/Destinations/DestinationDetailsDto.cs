using JetGo.Application.DTOs.Common;

namespace JetGo.Application.DTOs.Destinations;

public sealed class DestinationDetailsDto
{
    public int Id { get; init; }

    public string RouteCode { get; init; } = string.Empty;

    public bool IsActive { get; init; }

    public AirportSummaryDto DepartureAirport { get; init; } = new();

    public AirportSummaryDto ArrivalAirport { get; init; } = new();

    public int TotalFlightsCount { get; init; }

    public int UpcomingFlightsCount { get; init; }

    public decimal? LowestBasePrice { get; init; }

    public DateTime? NextDepartureAtUtc { get; init; }
}
