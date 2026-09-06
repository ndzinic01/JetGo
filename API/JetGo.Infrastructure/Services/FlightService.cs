using System.Security.Claims;
using JetGo.Application.Constants;
using JetGo.Application.Contracts.Services;
using JetGo.Application.DTOs.Common;
using JetGo.Application.DTOs.Flights;
using JetGo.Application.Exceptions;
using JetGo.Application.Requests.Flights;
using JetGo.Domain.Entities;
using JetGo.Infrastructure.Persistence;
using JetGo.Infrastructure.Services.Common;
using Microsoft.AspNetCore.Http;
using Microsoft.EntityFrameworkCore;

namespace JetGo.Infrastructure.Services;

public sealed class FlightService : IFlightService
{
    private readonly JetGoDbContext _dbContext;
    private readonly IHttpContextAccessor _httpContextAccessor;
    private readonly ReservationStatusSyncService _reservationStatusSyncService;

    public FlightService(
        JetGoDbContext dbContext,
        IHttpContextAccessor httpContextAccessor,
        ReservationStatusSyncService reservationStatusSyncService)
    {
        _dbContext = dbContext;
        _httpContextAccessor = httpContextAccessor;
        _reservationStatusSyncService = reservationStatusSyncService;
    }

    public async Task<PagedResponseDto<FlightListItemDto>> GetPagedAsync(FlightSearchRequest request, CancellationToken cancellationToken = default)
    {
        ValidateRequest(request);

        var nowUtc = DateTime.UtcNow;
        await _reservationStatusSyncService.SyncCompletedReservationsAsync(nowUtc, cancellationToken);
        var query = BuildQuery(request);
        var totalCount = await query.CountAsync(cancellationToken);

        var items = await query
            .OrderBy(x => x.DepartureAtUtc)
            .ThenBy(x => x.FlightNumber)
            .Skip((request.Page - 1) * request.PageSize)
            .Take(request.PageSize)
            .Select(x => new FlightListItemDto
            {
                Id = x.Id,
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
                Status = x.Status == Domain.Enums.FlightStatus.Cancelled
                    ? x.Status
                    : x.ArrivalAtUtc <= nowUtc
                        ? Domain.Enums.FlightStatus.Completed
                        : x.Status,
                CanReserve = x.Airline.IsActive &&
                    x.Destination.IsActive &&
                    (x.Status == Domain.Enums.FlightStatus.Scheduled || x.Status == Domain.Enums.FlightStatus.Delayed) &&
                    x.DepartureAtUtc > nowUtc &&
                    x.ArrivalAtUtc > nowUtc &&
                    x.AvailableSeats > 0,
                UnavailableReason = null
            })
            .ToListAsync(cancellationToken);

        await TrackSearchHistoryAsync(request, cancellationToken);

        return PagedResponseBuilder.Build(items, request.Page, request.PageSize, totalCount);
    }

    public async Task<FlightDetailsDto> GetByIdAsync(int id, CancellationToken cancellationToken = default)
    {
        var nowUtc = DateTime.UtcNow;
        await _reservationStatusSyncService.SyncCompletedReservationsAsync(nowUtc, cancellationToken);

        var flight = await _dbContext.Flights
            .AsNoTracking()
            .Include(x => x.Airline)
            .Include(x => x.Destination)
                .ThenInclude(x => x.DepartureAirport)
                    .ThenInclude(x => x.City)
                        .ThenInclude(x => x.Country)
            .Include(x => x.Destination)
                .ThenInclude(x => x.ArrivalAirport)
                    .ThenInclude(x => x.City)
                        .ThenInclude(x => x.Country)
            .Include(x => x.Seats)
            .SingleOrDefaultAsync(x => x.Id == id, cancellationToken);

        return flight is null
            ? throw new NotFoundException($"Let sa ID vrijednoscu {id} nije pronadjen.")
            : MapFlightDetails(flight, nowUtc);
    }

    private static FlightDetailsDto MapFlightDetails(Flight flight, DateTime nowUtc)
    {
        var seats = flight.Seats
            .OrderBy(x => x.SeatNumber)
            .ToArray();
        var availableSeatNumbers = seats
            .Where(x => !x.IsReserved)
            .Select(x => x.SeatNumber)
            .ToArray();
        var availability = FlightLifecycleService.GetReservationAvailability(flight, nowUtc);

        return new FlightDetailsDto
        {
            Id = flight.Id,
            DestinationId = flight.DestinationId,
            FlightNumber = flight.FlightNumber,
            RouteCode = flight.Destination.RouteCode,
            DestinationImageUrl = flight.Destination.ImageUrl,
            Airline = new AirlineSummaryDto
            {
                Id = flight.Airline.Id,
                Name = flight.Airline.Name,
                Code = flight.Airline.Code,
                LogoUrl = flight.Airline.LogoUrl
            },
            DepartureAirport = new AirportSummaryDto
            {
                Id = flight.Destination.DepartureAirport.Id,
                Name = flight.Destination.DepartureAirport.Name,
                IataCode = flight.Destination.DepartureAirport.IataCode,
                CityName = flight.Destination.DepartureAirport.City.Name,
                CountryName = flight.Destination.DepartureAirport.City.Country.Name
            },
            ArrivalAirport = new AirportSummaryDto
            {
                Id = flight.Destination.ArrivalAirport.Id,
                Name = flight.Destination.ArrivalAirport.Name,
                IataCode = flight.Destination.ArrivalAirport.IataCode,
                CityName = flight.Destination.ArrivalAirport.City.Name,
                CountryName = flight.Destination.ArrivalAirport.City.Country.Name
            },
            DepartureAtUtc = flight.DepartureAtUtc,
            ArrivalAtUtc = flight.ArrivalAtUtc,
            DurationMinutes = (int)Math.Round((flight.ArrivalAtUtc - flight.DepartureAtUtc).TotalMinutes),
            BasePrice = flight.BasePrice,
            AdditionalBaggageUnitPrice = ReservationPricingConstants.AdditionalBaggagePricePerPiece,
            AvailableSeats = availableSeatNumbers.Length,
            TotalSeats = seats.Length,
            ReservedSeats = seats.Length - availableSeatNumbers.Length,
            Status = FlightLifecycleService.GetEffectiveStatus(flight.Status, flight.ArrivalAtUtc, nowUtc),
            CanReserve = availability.IsAllowed,
            UnavailableReason = availability.Reason,
            SeatNumbers = seats
                .Select(x => x.SeatNumber)
                .ToArray(),
            AvailableSeatNumbers = availableSeatNumbers
        };
    }

    private IQueryable<JetGo.Domain.Entities.Flight> BuildQuery(FlightSearchRequest request)
    {
        var nowUtc = DateTime.UtcNow;
        var query = _dbContext.Flights.AsNoTracking().AsQueryable();

        if (!request.Status.HasValue)
        {
            query = query.Where(x =>
                x.Airline.IsActive &&
                x.Destination.IsActive &&
                (x.Status == Domain.Enums.FlightStatus.Scheduled || x.Status == Domain.Enums.FlightStatus.Delayed) &&
                x.DepartureAtUtc > nowUtc &&
                x.ArrivalAtUtc > nowUtc &&
                x.AvailableSeats > 0);
        }

        if (request.DepartureAirportId.HasValue)
        {
            query = query.Where(x => x.Destination.DepartureAirportId == request.DepartureAirportId.Value);
        }

        if (request.ArrivalAirportId.HasValue)
        {
            query = query.Where(x => x.Destination.ArrivalAirportId == request.ArrivalAirportId.Value);
        }

        if (request.AirlineId.HasValue)
        {
            query = query.Where(x => x.AirlineId == request.AirlineId.Value);
        }

        if (!string.IsNullOrWhiteSpace(request.AirlineCode))
        {
            var airlineCode = request.AirlineCode.Trim();

            query = query.Where(x =>
                x.Airline.Code.Contains(airlineCode) ||
                x.Airline.Name.Contains(airlineCode));
        }
        if (request.DepartureFromUtc.HasValue)
        {
            query = query.Where(x => x.DepartureAtUtc >= request.DepartureFromUtc.Value);
        }

        if (request.DepartureToUtc.HasValue)
        {
            query = query.Where(x => x.DepartureAtUtc <= request.DepartureToUtc.Value);
        }

        if (request.MinPrice.HasValue)
        {
            query = query.Where(x => x.BasePrice >= request.MinPrice.Value);
        }

        if (request.MaxPrice.HasValue)
        {
            query = query.Where(x => x.BasePrice <= request.MaxPrice.Value);
        }

        if (request.Status.HasValue)
        {
            query = request.Status.Value switch
            {
                Domain.Enums.FlightStatus.Completed => query.Where(x =>
                    x.Status == Domain.Enums.FlightStatus.Completed ||
                    (x.Status != Domain.Enums.FlightStatus.Cancelled && x.ArrivalAtUtc <= nowUtc)),
                Domain.Enums.FlightStatus.Cancelled => query.Where(x => x.Status == Domain.Enums.FlightStatus.Cancelled),
                Domain.Enums.FlightStatus.Delayed => query.Where(x =>
                    x.Airline.IsActive &&
                    x.Destination.IsActive &&
                    x.Status == Domain.Enums.FlightStatus.Delayed &&
                    x.DepartureAtUtc > nowUtc &&
                    x.ArrivalAtUtc > nowUtc &&
                    x.AvailableSeats > 0),
                _ => query.Where(x =>
                    x.Airline.IsActive &&
                    x.Destination.IsActive &&
                    x.Status == Domain.Enums.FlightStatus.Scheduled &&
                    x.DepartureAtUtc > nowUtc &&
                    x.ArrivalAtUtc > nowUtc &&
                    x.AvailableSeats > 0)
            };
        }

        if (!string.IsNullOrWhiteSpace(request.SearchText))
        {
            var searchText = request.SearchText.Trim();

            query = query.Where(x =>
                x.FlightNumber.Contains(searchText) ||
                x.Destination.RouteCode.Contains(searchText) ||
                x.Airline.Name.Contains(searchText) ||
                x.Airline.Code.Contains(searchText) ||
                x.Destination.DepartureAirport.Name.Contains(searchText) ||
                x.Destination.DepartureAirport.IataCode.Contains(searchText) ||
                x.Destination.DepartureAirport.City.Name.Contains(searchText) ||
                x.Destination.ArrivalAirport.Name.Contains(searchText) ||
                x.Destination.ArrivalAirport.IataCode.Contains(searchText) ||
                x.Destination.ArrivalAirport.City.Name.Contains(searchText));
        }

        if (!string.IsNullOrWhiteSpace(request.DepartureSearchText))
        {
            var departureSearchText = request.DepartureSearchText.Trim();

            query = query.Where(x =>
                x.Destination.DepartureAirport.Name.Contains(departureSearchText) ||
                x.Destination.DepartureAirport.IataCode.Contains(departureSearchText) ||
                x.Destination.DepartureAirport.City.Name.Contains(departureSearchText));
        }

        if (!string.IsNullOrWhiteSpace(request.ArrivalSearchText))
        {
            var arrivalSearchText = request.ArrivalSearchText.Trim();

            query = query.Where(x =>
                x.Destination.ArrivalAirport.Name.Contains(arrivalSearchText) ||
                x.Destination.ArrivalAirport.IataCode.Contains(arrivalSearchText) ||
                x.Destination.ArrivalAirport.City.Name.Contains(arrivalSearchText));
        }
        return query;
    }

    private static void ValidateRequest(FlightSearchRequest request)
    {
        if (request.DepartureFromUtc.HasValue && request.DepartureToUtc.HasValue && request.DepartureFromUtc > request.DepartureToUtc)
        {
            throw new ValidationException(
                "Raspon datuma polaska nije validan.",
                new Dictionary<string, string[]>
                {
                    ["departureToUtc"] = ["Datum 'DepartureToUtc' mora biti veci ili jednak datumu 'DepartureFromUtc'."]
                });
        }

        if (request.MinPrice.HasValue && request.MaxPrice.HasValue && request.MinPrice > request.MaxPrice)
        {
            throw new ValidationException(
                "Raspon cijena nije validan.",
                new Dictionary<string, string[]>
                {
                    ["maxPrice"] = ["Maksimalna cijena mora biti veca ili jednaka minimalnoj cijeni."]
                });
        }
    }

    private async Task TrackSearchHistoryAsync(FlightSearchRequest request, CancellationToken cancellationToken)
    {
        if (request.Page != 1 || !HasRecommendationRelevantFilters(request))
        {
            return;
        }

        var userId = TryGetCurrentUserId();

        if (string.IsNullOrWhiteSpace(userId))
        {
            return;
        }

        var searchHistory = await BuildSearchHistoryAsync(userId, request, cancellationToken);

        if (searchHistory is null)
        {
            return;
        }

        await _dbContext.SearchHistories.AddAsync(searchHistory, cancellationToken);
        await _dbContext.SaveChangesAsync(cancellationToken);
    }

    private async Task<SearchHistory?> BuildSearchHistoryAsync(string userId, FlightSearchRequest request, CancellationToken cancellationToken)
    {
        int? destinationId = null;
        var searchTerms = new List<string>();

        if (!string.IsNullOrWhiteSpace(request.SearchText))
        {
            searchTerms.Add(request.SearchText.Trim());
        }

        if (!string.IsNullOrWhiteSpace(request.DepartureSearchText))
        {
            searchTerms.Add(request.DepartureSearchText.Trim());
        }

        if (!string.IsNullOrWhiteSpace(request.ArrivalSearchText))
        {
            searchTerms.Add(request.ArrivalSearchText.Trim());
        }

        if (!string.IsNullOrWhiteSpace(request.AirlineCode))
        {
            searchTerms.Add(request.AirlineCode.Trim());
        }

        string? searchTerm = searchTerms.Count == 0
            ? null
            : string.Join(' ', searchTerms);
        if (request.DepartureAirportId.HasValue && request.ArrivalAirportId.HasValue)
        {
            var destinationData = await _dbContext.Destinations
                .AsNoTracking()
                .Where(x =>
                    x.DepartureAirportId == request.DepartureAirportId.Value &&
                    x.ArrivalAirportId == request.ArrivalAirportId.Value)
                .Select(x => new
                {
                    x.Id,
                    x.RouteCode
                })
                .SingleOrDefaultAsync(cancellationToken);

            if (destinationData is not null)
            {
                destinationId = destinationData.Id;
                searchTerm = string.IsNullOrWhiteSpace(searchTerm)
                    ? destinationData.RouteCode
                    : $"{destinationData.RouteCode} {searchTerm}";
            }
        }

        if (string.IsNullOrWhiteSpace(searchTerm) && request.DepartureAirportId.HasValue)
        {
            searchTerm = await _dbContext.Airports
                .AsNoTracking()
                .Where(x => x.Id == request.DepartureAirportId.Value)
                .Select(x => x.IataCode)
                .SingleOrDefaultAsync(cancellationToken);
        }

        if (string.IsNullOrWhiteSpace(searchTerm) && request.ArrivalAirportId.HasValue)
        {
            searchTerm = await _dbContext.Airports
                .AsNoTracking()
                .Where(x => x.Id == request.ArrivalAirportId.Value)
                .Select(x => x.IataCode)
                .SingleOrDefaultAsync(cancellationToken);
        }

        if (string.IsNullOrWhiteSpace(searchTerm) && request.AirlineId.HasValue)
        {
            searchTerm = await _dbContext.Airlines
                .AsNoTracking()
                .Where(x => x.Id == request.AirlineId.Value)
                .Select(x => x.Code)
                .SingleOrDefaultAsync(cancellationToken);
        }

        if (string.IsNullOrWhiteSpace(searchTerm))
        {
            return null;
        }

        return new SearchHistory
        {
            UserId = userId,
            SearchTerm = Truncate(searchTerm.Trim(), 200),
            DestinationId = destinationId
        };
    }

    private string? TryGetCurrentUserId()
    {
        var httpContext = _httpContextAccessor.HttpContext;

        if (httpContext is null)
        {
            return null;
        }

        return httpContext.User.FindFirstValue(ClaimTypes.NameIdentifier);
    }

    private static bool HasRecommendationRelevantFilters(FlightSearchRequest request)
    {
        return !string.IsNullOrWhiteSpace(request.SearchText) ||
               !string.IsNullOrWhiteSpace(request.DepartureSearchText) ||
               !string.IsNullOrWhiteSpace(request.ArrivalSearchText) ||
               !string.IsNullOrWhiteSpace(request.AirlineCode) ||
               request.DepartureAirportId.HasValue ||
               request.ArrivalAirportId.HasValue ||
               request.AirlineId.HasValue;
    }

    private static string Truncate(string value, int maxLength)
    {
        return value.Length <= maxLength
            ? value
            : value[..maxLength];
    }
}
