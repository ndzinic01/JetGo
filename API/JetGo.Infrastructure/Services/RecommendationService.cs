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
    private const int MaxRecentSearchSignals = 500;
    private const int MaxSimilarUsers = 10;
    private const double MinimumSimilarity = 0.05;
    private const double ReservationSignalWeight = 6;
    private const double SearchSignalWeight = 2;

    private readonly JetGoDbContext _dbContext;
    private readonly IHttpContextAccessor _httpContextAccessor;
    private readonly ReservationStatusSyncService _reservationStatusSyncService;

    public RecommendationService(
        JetGoDbContext dbContext,
        IHttpContextAccessor httpContextAccessor,
        ReservationStatusSyncService reservationStatusSyncService)
    {
        _dbContext = dbContext;
        _httpContextAccessor = httpContextAccessor;
        _reservationStatusSyncService = reservationStatusSyncService;
    }

    public async Task<PagedResponseDto<RecommendedFlightDto>> GetRecommendedFlightsAsync(
        FlightRecommendationRequest request,
        CancellationToken cancellationToken = default)
    {
        var currentUserId = GetRequiredCurrentUserId();
        var nowUtc = DateTime.UtcNow;
        await _reservationStatusSyncService.SyncCompletedReservationsAsync(nowUtc, cancellationToken);

        var reservationSignals = await _dbContext.Reservations
            .AsNoTracking()
            .Where(x => x.Status == ReservationStatus.Confirmed || x.Status == ReservationStatus.Completed)
            .Select(x => new UserBehaviorSignal
            {
                UserId = x.UserId,
                DestinationId = x.Flight.DestinationId,
                DepartureAirportId = x.Flight.Destination.DepartureAirportId,
                ArrivalAirportId = x.Flight.Destination.ArrivalAirportId,
                AirlineId = x.Flight.AirlineId,
                SearchTerm = x.Flight.Destination.RouteCode,
                Weight = ReservationSignalWeight,
                IsReservation = true
            })
            .ToListAsync(cancellationToken);

        var searchSignals = await _dbContext.SearchHistories
            .AsNoTracking()
            .OrderByDescending(x => x.CreatedAtUtc)
            .Take(MaxRecentSearchSignals)
            .Select(x => new UserBehaviorSignal
            {
                UserId = x.UserId,
                DestinationId = x.DestinationId,
                DepartureAirportId = x.DepartureAirportId,
                ArrivalAirportId = x.ArrivalAirportId,
                AirlineId = x.AirlineId,
                SearchTerm = x.SearchTerm,
                Weight = SearchSignalWeight,
                IsReservation = false
            })
            .ToListAsync(cancellationToken);

        var profiles = BuildUserProfiles(reservationSignals.Concat(searchSignals));
        var currentProfile = profiles.GetValueOrDefault(currentUserId) ?? new UserPreferenceProfile(currentUserId);
        var currentSearchSignals = searchSignals
            .Where(x => x.UserId == currentUserId)
            .ToArray();
        var currentReservedDestinationIds = await _dbContext.Reservations
            .AsNoTracking()
            .Where(x => x.UserId == currentUserId && x.Status != ReservationStatus.Cancelled)
            .Select(x => x.Flight.DestinationId)
            .Distinct()
            .ToArrayAsync(cancellationToken);

        var similarUsers = profiles.Values
            .Where(x => x.UserId != currentUserId)
            .Select(x => new SimilarUser(
                x.UserId,
                CalculateCosineSimilarity(currentProfile.Features, x.Features),
                x))
            .Where(x => x.Similarity >= MinimumSimilarity)
            .OrderByDescending(x => x.Similarity)
            .Take(MaxSimilarUsers)
            .ToArray();

        var similarUserIds = similarUsers
            .Select(x => x.UserId)
            .ToHashSet(StringComparer.Ordinal);

        var similarReservationCounts = reservationSignals
            .Where(x => x.IsReservation && x.DestinationId.HasValue && similarUserIds.Contains(x.UserId))
            .GroupBy(x => x.DestinationId!.Value)
            .ToDictionary(x => x.Key, x => x.Count());

        var popularityCounts = reservationSignals
            .Where(x => x.IsReservation && x.DestinationId.HasValue)
            .GroupBy(x => x.DestinationId!.Value)
            .ToDictionary(x => x.Key, x => x.Count());

        var candidates = await _dbContext.Flights
            .AsNoTracking()
            .Where(x =>
                x.Airline.IsActive &&
                x.Destination.IsActive &&
                (x.Status == FlightStatus.Scheduled || x.Status == FlightStatus.Delayed) &&
                x.DepartureAtUtc > nowUtc &&
                x.ArrivalAtUtc > nowUtc &&
                x.AvailableSeats > 0 &&
                !currentReservedDestinationIds.Contains(x.DestinationId) &&
                !x.Reservations.Any(r => r.UserId == currentUserId && r.Status != ReservationStatus.Cancelled))
            .Select(x => new RecommendationCandidate
            {
                Id = x.Id,
                DestinationId = x.DestinationId,
                FlightNumber = x.FlightNumber,
                RouteCode = x.Destination.RouteCode,
                DestinationImageUrl = x.Destination.ImageUrl,
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

        var scoredRecommendations = candidates
            .Select(candidate => BuildScoredRecommendation(
                candidate,
                currentSearchSignals,
                similarUsers,
                similarReservationCounts.GetValueOrDefault(candidate.DestinationId),
                popularityCounts.GetValueOrDefault(candidate.DestinationId)))
            .ToArray();

        var hasCollaborativeRecommendations = scoredRecommendations.Any(x => x.CollaborativeScore > 0);
        var recommendedFlights = scoredRecommendations
            .Where(x => !hasCollaborativeRecommendations || x.CollaborativeScore > 0)
            .OrderByDescending(x => x.Flight.RecommendationScore)
            .ThenByDescending(x => x.Flight.MatchingReservationCount)
            .ThenByDescending(x => x.Flight.ExactRouteSearchCount)
            .ThenByDescending(x => x.Flight.KeywordSearchCount)
            .ThenByDescending(x => x.Flight.PopularityCount)
            .ThenBy(x => x.Flight.DepartureAtUtc)
            .ThenBy(x => x.Flight.BasePrice)
            .Select(x => x.Flight)
            .ToArray();

        var totalCount = recommendedFlights.Length;
        var items = recommendedFlights
            .Skip((request.Page - 1) * request.PageSize)
            .Take(request.PageSize)
            .ToArray();

        return PagedResponseBuilder.Build(items, request.Page, request.PageSize, totalCount);
    }

    private static ScoredRecommendation BuildScoredRecommendation(
        RecommendationCandidate candidate,
        IReadOnlyCollection<UserBehaviorSignal> currentSearchSignals,
        IReadOnlyCollection<SimilarUser> similarUsers,
        int similarReservationCount,
        int popularityCount)
    {
        var similarMatches = similarUsers
            .Select(x => new SimilarUserCandidateMatch(
                x.UserId,
                x.Similarity,
                CalculateCandidateInterest(x.Profile, candidate)))
            .Where(x => x.InterestScore > 0)
            .ToArray();

        var collaborativeScore = similarMatches.Sum(x => x.Similarity * x.InterestScore);
        var structuredSearchCount = CountCurrentStructuredSearchMatches(candidate, currentSearchSignals);
        var tokenSearchCount = CountCurrentTokenSearchMatches(candidate, currentSearchSignals);
        var recommendationScore = BuildRecommendationScore(
            collaborativeScore,
            structuredSearchCount,
            tokenSearchCount,
            similarReservationCount,
            popularityCount);
        var similarUserCount = similarMatches.Length;

        var flight = new RecommendedFlightDto
        {
            Id = candidate.Id,
            FlightNumber = candidate.FlightNumber,
            RouteCode = candidate.RouteCode,
            DestinationImageUrl = candidate.DestinationImageUrl,
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
            ExactRouteSearchCount = structuredSearchCount,
            KeywordSearchCount = tokenSearchCount,
            MatchingReservationCount = similarReservationCount,
            PopularityCount = popularityCount,
            AppliedSignals = BuildAppliedSignals(
                similarUserCount,
                similarReservationCount,
                structuredSearchCount,
                tokenSearchCount,
                collaborativeScore,
                popularityCount),
            RecommendationReason = BuildRecommendationReason(
                candidate.RouteCode,
                similarUserCount,
                similarReservationCount,
                structuredSearchCount,
                tokenSearchCount,
                collaborativeScore,
                popularityCount)
        };

        return new ScoredRecommendation(flight, collaborativeScore);
    }

    private static Dictionary<string, UserPreferenceProfile> BuildUserProfiles(IEnumerable<UserBehaviorSignal> signals)
    {
        var profiles = new Dictionary<string, UserPreferenceProfile>(StringComparer.Ordinal);

        foreach (var signal in signals)
        {
            if (string.IsNullOrWhiteSpace(signal.UserId))
            {
                continue;
            }

            if (!profiles.TryGetValue(signal.UserId, out var profile))
            {
                profile = new UserPreferenceProfile(signal.UserId);
                profiles.Add(signal.UserId, profile);
            }

            AddSignalToProfile(profile, signal);
        }

        return profiles;
    }

    private static void AddSignalToProfile(UserPreferenceProfile profile, UserBehaviorSignal signal)
    {
        var weight = signal.Weight;
        var destinationWeight = signal.IsReservation ? weight : weight * 1.5;
        var routeAirportWeight = signal.IsReservation ? weight * 0.7 : weight;
        var airlineWeight = signal.IsReservation ? weight * 0.45 : weight * 0.8;
        var tokenWeight = signal.IsReservation ? weight * 0.15 : weight * 0.35;

        if (signal.DestinationId.HasValue)
        {
            profile.Add(DestinationFeature(signal.DestinationId.Value), destinationWeight);
        }

        if (signal.DepartureAirportId.HasValue)
        {
            profile.Add(DepartureAirportFeature(signal.DepartureAirportId.Value), routeAirportWeight);
        }

        if (signal.ArrivalAirportId.HasValue)
        {
            profile.Add(ArrivalAirportFeature(signal.ArrivalAirportId.Value), routeAirportWeight);
        }

        if (signal.AirlineId.HasValue)
        {
            profile.Add(AirlineFeature(signal.AirlineId.Value), airlineWeight);
        }

        foreach (var token in Tokenize(signal.SearchTerm))
        {
            profile.Add(TokenFeature(token), tokenWeight);
        }
    }

    private static int BuildRecommendationScore(
        double collaborativeScore,
        int structuredSearchCount,
        int tokenSearchCount,
        int similarReservationCount,
        int popularityCount)
    {
        if (collaborativeScore > 0)
        {
            return (int)Math.Round(collaborativeScore * 100) +
                   similarReservationCount * 4 +
                   structuredSearchCount * 2 +
                   tokenSearchCount +
                   popularityCount;
        }

        return popularityCount * 10 + structuredSearchCount * 2 + tokenSearchCount;
    }

    private static double CalculateCosineSimilarity(
        IReadOnlyDictionary<string, double> left,
        IReadOnlyDictionary<string, double> right)
    {
        if (left.Count == 0 || right.Count == 0)
        {
            return 0;
        }

        var dotProduct = 0d;
        var smaller = left.Count <= right.Count ? left : right;
        var larger = left.Count <= right.Count ? right : left;

        foreach (var feature in smaller)
        {
            if (larger.TryGetValue(feature.Key, out var otherValue))
            {
                dotProduct += feature.Value * otherValue;
            }
        }

        if (dotProduct <= 0)
        {
            return 0;
        }

        var leftMagnitude = Math.Sqrt(left.Values.Sum(x => x * x));
        var rightMagnitude = Math.Sqrt(right.Values.Sum(x => x * x));

        return leftMagnitude == 0 || rightMagnitude == 0
            ? 0
            : dotProduct / (leftMagnitude * rightMagnitude);
    }

    private static double CalculateCandidateInterest(UserPreferenceProfile profile, RecommendationCandidate candidate)
    {
        var score = 0d;
        score += profile.Get(DestinationFeature(candidate.DestinationId));
        score += profile.Get(ArrivalAirportFeature(candidate.ArrivalAirport.Id)) * 0.75;
        score += profile.Get(DepartureAirportFeature(candidate.DepartureAirport.Id)) * 0.35;
        score += profile.Get(AirlineFeature(candidate.Airline.Id)) * 0.45;

        foreach (var token in BuildCandidateTokens(candidate))
        {
            score += profile.Get(TokenFeature(token)) * 0.1;
        }

        return score;
    }

    private static int CountCurrentStructuredSearchMatches(
        RecommendationCandidate candidate,
        IReadOnlyCollection<UserBehaviorSignal> currentSearchSignals)
    {
        return currentSearchSignals.Count(x =>
            (x.DestinationId.HasValue && x.DestinationId.Value == candidate.DestinationId) ||
            (x.DepartureAirportId.HasValue && x.DepartureAirportId.Value == candidate.DepartureAirport.Id) ||
            (x.ArrivalAirportId.HasValue && x.ArrivalAirportId.Value == candidate.ArrivalAirport.Id) ||
            (x.AirlineId.HasValue && x.AirlineId.Value == candidate.Airline.Id));
    }

    private static int CountCurrentTokenSearchMatches(
        RecommendationCandidate candidate,
        IReadOnlyCollection<UserBehaviorSignal> currentSearchSignals)
    {
        var candidateTokens = BuildCandidateTokens(candidate).ToHashSet(StringComparer.Ordinal);

        return currentSearchSignals.Sum(x => Tokenize(x.SearchTerm).Count(candidateTokens.Contains));
    }

    private static string[] BuildCandidateTokens(RecommendationCandidate candidate)
    {
        return Tokenize(string.Join(
            ' ',
            candidate.RouteCode,
            candidate.FlightNumber,
            candidate.Airline.Name,
            candidate.Airline.Code,
            candidate.DepartureAirport.IataCode,
            candidate.DepartureAirport.CityName,
            candidate.ArrivalAirport.IataCode,
            candidate.ArrivalAirport.CityName));
    }

    private static string[] BuildAppliedSignals(
        int similarUserCount,
        int similarReservationCount,
        int structuredSearchCount,
        int tokenSearchCount,
        double collaborativeScore,
        int popularityCount)
    {
        var appliedSignals = new List<string>();

        if (collaborativeScore > 0 && similarUserCount > 0)
        {
            appliedSignals.Add("SimilarUsers");
        }

        if (similarReservationCount > 0)
        {
            appliedSignals.Add("SimilarUserReservations");
        }

        if (structuredSearchCount > 0)
        {
            appliedSignals.Add("StructuredSearch");
        }

        if (tokenSearchCount > 0)
        {
            appliedSignals.Add("TokenizedSearch");
        }

        if (popularityCount > 0 && collaborativeScore <= 0)
        {
            appliedSignals.Add("PopularityFallback");
        }

        if (appliedSignals.Count == 0)
        {
            appliedSignals.Add("FallbackUpcomingAvailability");
        }

        return appliedSignals.ToArray();
    }

    private static string BuildRecommendationReason(
        string routeCode,
        int similarUserCount,
        int similarReservationCount,
        int structuredSearchCount,
        int tokenSearchCount,
        double collaborativeScore,
        int popularityCount)
    {
        if (collaborativeScore > 0)
        {
            var reasons = new List<string>
            {
                $"korisnici sa slicnim pretragama i rezervacijama imaju interes za rutu {routeCode}"
            };

            if (similarUserCount > 0)
            {
                reasons.Add($"pronadjeno je {similarUserCount} slicnih korisnika");
            }

            if (similarReservationCount > 0)
            {
                reasons.Add($"slicni korisnici imaju {similarReservationCount} potvrdjenih rezervacija na ovoj ruti");
            }

            if (structuredSearchCount > 0 || tokenSearchCount > 0)
            {
                reasons.Add("vase prethodne pretrage pomazu u pronalasku slicnih korisnika");
            }

            return $"Preporuceno jer {string.Join(", ", reasons)}.";
        }

        if (popularityCount > 0)
        {
            return $"Preporuceno kao popularna buduca opcija jer jos nema dovoljno slicnih korisnika, a ruta {routeCode} ima {popularityCount} potvrdjenih rezervacija.";
        }

        return "Preporuceno kao naredna dostupna opcija jer jos nema dovoljno historije za pronalazak slicnih korisnika.";
    }

    private static string[] Tokenize(string value)
    {
        if (string.IsNullOrWhiteSpace(value))
        {
            return Array.Empty<string>();
        }

        return value
            .Split(SearchTokenSeparators, StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries)
            .Select(NormalizeTerm)
            .Where(x => x.Length >= 2)
            .Distinct(StringComparer.Ordinal)
            .ToArray();
    }

    private static string NormalizeTerm(string value)
    {
        return value.Trim().ToUpperInvariant();
    }

    private static string DestinationFeature(int id) => $"destination:{id}";

    private static string DepartureAirportFeature(int id) => $"departure-airport:{id}";

    private static string ArrivalAirportFeature(int id) => $"arrival-airport:{id}";

    private static string AirlineFeature(int id) => $"airline:{id}";

    private static string TokenFeature(string token) => $"token:{token}";

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

    private static readonly char[] SearchTokenSeparators =
    {
        ' ', ',', ';', '.', ':', '|', '/', '\\', '-', '_', '(', ')', '[', ']', '{', '}'
    };

    private sealed class UserBehaviorSignal
    {
        public string UserId { get; init; } = string.Empty;

        public int? DestinationId { get; init; }

        public int? DepartureAirportId { get; init; }

        public int? ArrivalAirportId { get; init; }

        public int? AirlineId { get; init; }

        public string SearchTerm { get; init; } = string.Empty;

        public double Weight { get; init; }

        public bool IsReservation { get; init; }
    }

    private sealed class UserPreferenceProfile
    {
        public UserPreferenceProfile(string userId)
        {
            UserId = userId;
        }

        public string UserId { get; }

        public Dictionary<string, double> Features { get; } = new(StringComparer.Ordinal);

        public void Add(string feature, double weight)
        {
            Features[feature] = Features.GetValueOrDefault(feature) + weight;
        }

        public double Get(string feature)
        {
            return Features.GetValueOrDefault(feature);
        }
    }

    private sealed record SimilarUser(string UserId, double Similarity, UserPreferenceProfile Profile);

    private sealed record SimilarUserCandidateMatch(string UserId, double Similarity, double InterestScore);

    private sealed record ScoredRecommendation(RecommendedFlightDto Flight, double CollaborativeScore);

    private sealed class RecommendationCandidate
    {
        public int Id { get; init; }

        public int DestinationId { get; init; }

        public string FlightNumber { get; init; } = string.Empty;

        public string RouteCode { get; init; } = string.Empty;

        public string? DestinationImageUrl { get; init; }

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
