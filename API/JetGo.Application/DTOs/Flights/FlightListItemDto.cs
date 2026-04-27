using JetGo.Application.DTOs.Common;
using JetGo.Domain.Enums;

namespace JetGo.Application.DTOs.Flights;

public sealed class FlightListItemDto
{
    public int Id { get; init; }

    public string FlightNumber { get; init; } = string.Empty;

    public string RouteCode { get; init; } = string.Empty;

    public AirlineSummaryDto Airline { get; init; } = new();

    public AirportSummaryDto DepartureAirport { get; init; } = new();

    public AirportSummaryDto ArrivalAirport { get; init; } = new();

    public DateTime DepartureAtUtc { get; init; }

    public DateTime ArrivalAtUtc { get; init; }

    public int DurationMinutes { get; init; }

    public decimal BasePrice { get; init; }

    public string Currency { get; init; } = "BAM";

    public int AvailableSeats { get; init; }

    public int TotalSeats { get; init; }

    public FlightStatus Status { get; init; }
}
