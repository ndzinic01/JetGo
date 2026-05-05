using System.Security.Claims;
using JetGo.Application.Contracts.Services;
using JetGo.Application.DTOs.Common;
using JetGo.Application.DTOs.Recommendations;
using JetGo.Application.Exceptions;
using JetGo.Application.Requests.Recommendations;
using JetGo.Domain.Enums;
using JetGo.Infrastructure.Persistence;
using JetGo.Infrastructure.Services.Common;
using Microsoft.AspNetCore.Http;
using Microsoft.EntityFrameworkCore;

namespace JetGo.Infrastructure.Services;

public sealed class RecommendationService : IRecommendationService
{
    private readonly JetGoDbContext _dbContext;
    private readonly IHttpContextAccessor _httpContextAccessor;

    public RecommendationService(JetGoDbContext dbContext, IHttpContextAccessor httpContextAccessor)
    {
        _dbContext = dbContext;
        _httpContextAccessor = httpContextAccessor;
    }

    public async Task<PagedResponseDto<RecommendedFlightDto>> GetRecommendedFlightsAsync(
        FlightRecommendationRequest request,
        CancellationToken cancellationToken = default)
    {
        var currentUserId = GetRequiredCurrentUserId();
        var recentSearches = await _dbContext.SearchHistories
            .AsNoTracking()
            .Where(x => x.UserId == currentUserId)
            .OrderByDescending(x => x.CreatedAtUtc)
            .Take(100)
            .Select(x => new SearchSignal
            {
                DestinationId = x.DestinationId,
                SearchTerm = x.SearchTerm
            })
            .ToListAsync(cancellationToken);

        var exactRouteSearchCounts = recentSearches
            .Where(x => x.DestinationId.HasValue)
            .GroupBy(x => x.DestinationId!.Value)
            .ToDictionary(x => x.Key, x => x.Count());

        var keywordTerms = recentSearches
            .Where(x => !x.DestinationId.HasValue)
            .Select(x => NormalizeTerm(x.SearchTerm))
            .Where(x => !string.IsNullOrWhiteSpace(x))
            .ToArray();

        var reservationCounts = await _dbContext.Reservations
            .AsNoTracking()
            .Where(x => x.UserId == currentUserId && x.Status != ReservationStatus.Cancelled)
            .GroupBy(x => x.Flight.DestinationId)
            .Select(x => new CountByDestination
            {
                DestinationId = x.Key,
                Count = x.Count()
            })
            .ToDictionaryAsync(x => x.DestinationId, x => x.Count, cancellationToken);

        var popularityCounts = await _dbContext.Reservations
            .AsNoTracking()
            .Where(x => x.Status == ReservationStatus.Confirmed || x.Status == ReservationStatus.Completed)
            .GroupBy(x => x.Flight.DestinationId)
            .Select(x => new CountByDestination
            {
                DestinationId = x.Key,
                Count = x.Count()
            })
            .ToDictionaryAsync(x => x.DestinationId, x => x.Count, cancellationToken);

        var candidates = await _dbContext.Flights
            .AsNoTracking()
            .Where(x =>
                x.Status == FlightStatus.Scheduled &&
                x.DepartureAtUtc > DateTime.UtcNow &&
                x.AvailableSeats > 0 &&
                !x.Reservations.Any(r => r.UserId == currentUserId && r.Status != ReservationStatus.Cancelled))
            .Select(x => new RecommendationCandidate
            {
                Id = x.Id,
                DestinationId = x.DestinationId,
                FlightNumber = x.FlightNumber,
                RouteCode = x.Destination.RouteCode,
                Airline = new AirlineSummaryDto
                {
                    Id = x.Airline.Id,
                    Name = x.Airline.Name,
                    Code = x.Airline.Code,
                    LogoUrl = x.Airline.LogoUrl
                },
                DepartureAirport = new AirportSummaryDto
                {
                    Id = x.Destination.DepartureAirport.Id,
                    Name = x.Destination.DepartureAirport.Name,
                    IataCode = x.Destination.DepartureAirport.IataCode,
                    CityName = x.Destination.DepartureAirport.City.Name,
                    CountryName = x.Destination.DepartureAirport.City.Country.Name
                },
                ArrivalAirport = new AirportSummaryDto
                {
                    Id = x.Destination.ArrivalAirport.Id,
                    Name = x.Destination.ArrivalAirport.Name,
                    IataCode = x.Destination.ArrivalAirport.IataCode,
                    CityName = x.Destination.ArrivalAirport.City.Name,
                    CountryName = x.Destination.ArrivalAirport.City.Country.Name
                },
                DepartureAtUtc = x.DepartureAtUtc,
                ArrivalAtUtc = x.ArrivalAtUtc,
                DurationMinutes = EF.Functions.DateDiffMinute(x.DepartureAtUtc, x.ArrivalAtUtc),
                BasePrice = x.BasePrice,
                AvailableSeats = x.AvailableSeats,
                TotalSeats = x.TotalSeats,
                Status = x.Status
            })
            .ToListAsync(cancellationToken);

        var recommendedFlights = candidates
            .Select(candidate => BuildRecommendedFlightDto(
                candidate,
                exactRouteSearchCounts,
                keywordTerms,
                reservationCounts,
                popularityCounts))
            .OrderByDescending(x => x.RecommendationScore)
            .ThenByDescending(x => x.ExactRouteSearchCount)
            .ThenByDescending(x => x.KeywordSearchCount)
            .ThenByDescending(x => x.MatchingReservationCount)
            .ThenByDescending(x => x.PopularityCount)
            .ThenBy(x => x.DepartureAtUtc)
            .ThenBy(x => x.BasePrice)
            .ToArray();

        var totalCount = recommendedFlights.Length;
        var items = recommendedFlights
            .Skip((request.Page - 1) * request.PageSize)
            .Take(request.PageSize)
            .ToArray();

        return PagedResponseBuilder.Build(items, request.Page, request.PageSize, totalCount);
    }

    private static RecommendedFlightDto BuildRecommendedFlightDto(
        RecommendationCandidate candidate,
        IReadOnlyDictionary<int, int> exactRouteSearchCounts,
        IReadOnlyCollection<string> keywordTerms,
        IReadOnlyDictionary<int, int> reservationCounts,
        IReadOnlyDictionary<int, int> popularityCounts)
    {
        var exactRouteSearchCount = exactRouteSearchCounts.GetValueOrDefault(candidate.DestinationId);
        var keywordSearchCount = CountMatchingKeywords(candidate, keywordTerms);
        var reservationCount = reservationCounts.GetValueOrDefault(candidate.DestinationId);
        var popularityCount = popularityCounts.GetValueOrDefault(candidate.DestinationId);

        var recommendationScore =
            exactRouteSearchCount * 5 +
            keywordSearchCount * 3 +
            reservationCount * 6 +
            popularityCount * 2;

        var appliedSignals = BuildAppliedSignals(
            exactRouteSearchCount,
            keywordSearchCount,
            reservationCount,
            popularityCount);

        return new RecommendedFlightDto
        {
            Id = candidate.Id,
            FlightNumber = candidate.FlightNumber,
            RouteCode = candidate.RouteCode,
            Airline = candidate.Airline,
            DepartureAirport = candidate.DepartureAirport,
            ArrivalAirport = candidate.ArrivalAirport,
            DepartureAtUtc = candidate.DepartureAtUtc,
            ArrivalAtUtc = candidate.ArrivalAtUtc,
            DurationMinutes = candidate.DurationMinutes,
            BasePrice = candidate.BasePrice,
            AvailableSeats = candidate.AvailableSeats,
            TotalSeats = candidate.TotalSeats,
            Status = candidate.Status,
            RecommendationScore = recommendationScore,
            ExactRouteSearchCount = exactRouteSearchCount,
            KeywordSearchCount = keywordSearchCount,
            MatchingReservationCount = reservationCount,
            PopularityCount = popularityCount,
            AppliedSignals = appliedSignals,
            RecommendationReason = BuildRecommendationReason(
                candidate.RouteCode,
                exactRouteSearchCount,
                keywordSearchCount,
                reservationCount,
                popularityCount)
        };
    }

    private static int CountMatchingKeywords(RecommendationCandidate candidate, IReadOnlyCollection<string> keywordTerms)
    {
        if (keywordTerms.Count == 0)
        {
            return 0;
        }

        var searchDocument = NormalizeTerm(string.Join(
            " ",
            candidate.RouteCode,
            candidate.FlightNumber,
            candidate.Airline.Name,
            candidate.Airline.Code,
            candidate.DepartureAirport.IataCode,
            candidate.DepartureAirport.CityName,
            candidate.ArrivalAirport.IataCode,
            candidate.ArrivalAirport.CityName));

        return keywordTerms.Count(searchTerm => searchDocument.Contains(searchTerm, StringComparison.OrdinalIgnoreCase));
    }

    private static string[] BuildAppliedSignals(
        int exactRouteSearchCount,
        int keywordSearchCount,
        int reservationCount,
        int popularityCount)
    {
        var appliedSignals = new List<string>();

        if (exactRouteSearchCount > 0)
        {
            appliedSignals.Add("ExactRouteSearch");
        }

        if (keywordSearchCount > 0)
        {
            appliedSignals.Add("KeywordSearch");
        }

        if (reservationCount > 0)
        {
            appliedSignals.Add("ReservationHistory");
        }

        if (popularityCount > 0)
        {
            appliedSignals.Add("GlobalPopularity");
        }

        if (appliedSignals.Count == 0)
        {
            appliedSignals.Add("FallbackUpcomingAvailability");
        }

        return appliedSignals.ToArray();
    }

    private static string BuildRecommendationReason(
        string routeCode,
        int exactRouteSearchCount,
        int keywordSearchCount,
        int reservationCount,
        int popularityCount)
    {
        var reasons = new List<string>();

        if (exactRouteSearchCount > 0)
        {
            reasons.Add($"rutu {routeCode} ste pretrazivali {exactRouteSearchCount} puta");
        }

        if (keywordSearchCount > 0)
        {
            reasons.Add($"imate {keywordSearchCount} pretraga sa pojmovima povezanim sa ovim letom");
        }

        if (reservationCount > 0)
        {
            reasons.Add($"vec imate {reservationCount} aktivnih ili prethodnih rezervacija na istoj ruti");
        }

        if (popularityCount > 0)
        {
            reasons.Add($"ruta trenutno ima {popularityCount} potvrdjenih rezervacija medju korisnicima");
        }

        if (reasons.Count == 0)
        {
            return "Preporuceno kao naredna dostupna opcija jer jos nema dovoljno licne historije za precizniju preporuku.";
        }

        if (reasons.Count == 1)
        {
            return $"Preporuceno jer {reasons[0]}.";
        }

        return $"Preporuceno jer {string.Join(", ", reasons.Take(reasons.Count - 1))} i {reasons[^1]}.";
    }

    private static string NormalizeTerm(string value)
    {
        return value.Trim().ToUpperInvariant();
    }

    private string GetRequiredCurrentUserId()
    {
        var httpContext = _httpContextAccessor.HttpContext ?? throw new UnauthorizedException("Prijava je obavezna za ovu akciju.");
        var userId = httpContext.User.FindFirstValue(ClaimTypes.NameIdentifier);

        if (string.IsNullOrWhiteSpace(userId))
        {
            throw new UnauthorizedException("Nije moguce odrediti trenutnog korisnika.");
        }

        return userId;
    }

    private sealed class SearchSignal
    {
        public int? DestinationId { get; init; }

        public string SearchTerm { get; init; } = string.Empty;
    }

    private sealed class CountByDestination
    {
        public int DestinationId { get; init; }

        public int Count { get; init; }
    }

    private sealed class RecommendationCandidate
    {
        public int Id { get; init; }

        public int DestinationId { get; init; }

        public string FlightNumber { get; init; } = string.Empty;

        public string RouteCode { get; init; } = string.Empty;

        public AirlineSummaryDto Airline { get; init; } = new();

        public AirportSummaryDto DepartureAirport { get; init; } = new();

        public AirportSummaryDto ArrivalAirport { get; init; } = new();

        public DateTime DepartureAtUtc { get; init; }

        public DateTime ArrivalAtUtc { get; init; }

        public int DurationMinutes { get; init; }

        public decimal BasePrice { get; init; }

        public int AvailableSeats { get; init; }

        public int TotalSeats { get; init; }

        public FlightStatus Status { get; init; }
    }
}
