using JetGo.Application.Contracts.Services;
using JetGo.Application.DTOs.Common;
using JetGo.Application.DTOs.Flights;
using JetGo.Application.Exceptions;
using JetGo.Application.Requests.Flights;
using JetGo.Infrastructure.Persistence;
using JetGo.Infrastructure.Services.Common;
using Microsoft.EntityFrameworkCore;

namespace JetGo.Infrastructure.Services;

public sealed class FlightService : IFlightService
{
    private readonly JetGoDbContext _dbContext;

    public FlightService(JetGoDbContext dbContext)
    {
        _dbContext = dbContext;
    }

    public async Task<PagedResponseDto<FlightListItemDto>> GetPagedAsync(FlightSearchRequest request, CancellationToken cancellationToken = default)
    {
        ValidateRequest(request);

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

        return PagedResponseBuilder.Build(items, request.Page, request.PageSize, totalCount);
    }

    public async Task<FlightDetailsDto> GetByIdAsync(int id, CancellationToken cancellationToken = default)
    {
        var flight = await _dbContext.Flights
            .AsNoTracking()
            .Where(x => x.Id == id)
            .Select(x => new FlightDetailsDto
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
                ReservedSeats = x.TotalSeats - x.AvailableSeats,
                Status = x.Status,
                AvailableSeatNumbers = x.Seats
                    .Where(s => !s.IsReserved)
                    .OrderBy(s => s.SeatNumber)
                    .Select(s => s.SeatNumber)
                    .ToArray()
            })
            .SingleOrDefaultAsync(cancellationToken);

        return flight ?? throw new NotFoundException($"Let sa ID vrijednoscu {id} nije pronadjen.");
    }

    private IQueryable<JetGo.Domain.Entities.Flight> BuildQuery(FlightSearchRequest request)
    {
        var query = _dbContext.Flights.AsNoTracking().AsQueryable();

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
            query = query.Where(x => x.Status == request.Status.Value);
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
}
