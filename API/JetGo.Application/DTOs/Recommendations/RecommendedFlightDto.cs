using JetGo.Application.DTOs.Common;
using JetGo.Domain.Enums;

namespace JetGo.Application.DTOs.Recommendations;

public sealed class RecommendedFlightDto
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

    public int RecommendationScore { get; init; }

    public int ExactRouteSearchCount { get; init; }

    public int KeywordSearchCount { get; init; }

    public int MatchingReservationCount { get; init; }

    public int PopularityCount { get; init; }

    public IReadOnlyCollection<string> AppliedSignals { get; init; } = Array.Empty<string>();

    public string RecommendationReason { get; init; } = string.Empty;
}
