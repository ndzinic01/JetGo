using JetGo.Application.Contracts.Services;
using JetGo.Application.DTOs.Common;
using JetGo.Application.DTOs.Destinations;
using JetGo.Application.Exceptions;
using JetGo.Application.Requests.Destinations;
using JetGo.Domain.Enums;
using JetGo.Infrastructure.Persistence;
using JetGo.Infrastructure.Services.Common;
using Microsoft.EntityFrameworkCore;

namespace JetGo.Infrastructure.Services;

public sealed class DestinationService : IDestinationService
{
    private readonly JetGoDbContext _dbContext;

    public DestinationService(JetGoDbContext dbContext)
    {
        _dbContext = dbContext;
    }

    public async Task<PagedResponseDto<DestinationListItemDto>> GetPagedAsync(DestinationSearchRequest request, CancellationToken cancellationToken = default)
    {
        var query = BuildQuery(request);
        var totalCount = await query.CountAsync(cancellationToken);
        var nowUtc = DateTime.UtcNow;

        var items = await query
            .OrderBy(x => x.DepartureAirport.City.Name)
            .ThenBy(x => x.ArrivalAirport.City.Name)
            .ThenBy(x => x.RouteCode)
            .Skip((request.Page - 1) * request.PageSize)
            .Take(request.PageSize)
            .Select(x => new DestinationListItemDto
            {
                Id = x.Id,
                RouteCode = x.RouteCode,
                IsActive = x.IsActive,
                DepartureAirport = new AirportSummaryDto
                {
                    Id = x.DepartureAirport.Id,
                    Name = x.DepartureAirport.Name,
                    IataCode = x.DepartureAirport.IataCode,
                    CityName = x.DepartureAirport.City.Name,
                    CountryName = x.DepartureAirport.City.Country.Name
                },
                ArrivalAirport = new AirportSummaryDto
                {
                    Id = x.ArrivalAirport.Id,
                    Name = x.ArrivalAirport.Name,
                    IataCode = x.ArrivalAirport.IataCode,
                    CityName = x.ArrivalAirport.City.Name,
                    CountryName = x.ArrivalAirport.City.Country.Name
                },
                UpcomingFlightsCount = x.Flights.Count(f => f.DepartureAtUtc >= nowUtc && f.Status == FlightStatus.Scheduled),
                LowestBasePrice = x.Flights
                    .Where(f => f.DepartureAtUtc >= nowUtc && f.Status == FlightStatus.Scheduled)
                    .Select(f => (decimal?)f.BasePrice)
                    .Min(),
                NextDepartureAtUtc = x.Flights
                    .Where(f => f.DepartureAtUtc >= nowUtc && f.Status == FlightStatus.Scheduled)
                    .Select(f => (DateTime?)f.DepartureAtUtc)
                    .Min()
            })
            .ToListAsync(cancellationToken);

        return PagedResponseBuilder.Build(items, request.Page, request.PageSize, totalCount);
    }

    public async Task<DestinationDetailsDto> GetByIdAsync(int id, CancellationToken cancellationToken = default)
    {
        var nowUtc = DateTime.UtcNow;

        var destination = await _dbContext.Destinations
            .AsNoTracking()
            .Where(x => x.Id == id)
            .Select(x => new DestinationDetailsDto
            {
                Id = x.Id,
                RouteCode = x.RouteCode,
                IsActive = x.IsActive,
                DepartureAirport = new AirportSummaryDto
                {
                    Id = x.DepartureAirport.Id,
                    Name = x.DepartureAirport.Name,
                    IataCode = x.DepartureAirport.IataCode,
                    CityName = x.DepartureAirport.City.Name,
                    CountryName = x.DepartureAirport.City.Country.Name
                },
                ArrivalAirport = new AirportSummaryDto
                {
                    Id = x.ArrivalAirport.Id,
                    Name = x.ArrivalAirport.Name,
                    IataCode = x.ArrivalAirport.IataCode,
                    CityName = x.ArrivalAirport.City.Name,
                    CountryName = x.ArrivalAirport.City.Country.Name
                },
                TotalFlightsCount = x.Flights.Count(),
                UpcomingFlightsCount = x.Flights.Count(f => f.DepartureAtUtc >= nowUtc && f.Status == FlightStatus.Scheduled),
                LowestBasePrice = x.Flights
                    .Where(f => f.DepartureAtUtc >= nowUtc && f.Status == FlightStatus.Scheduled)
                    .Select(f => (decimal?)f.BasePrice)
                    .Min(),
                NextDepartureAtUtc = x.Flights
                    .Where(f => f.DepartureAtUtc >= nowUtc && f.Status == FlightStatus.Scheduled)
                    .Select(f => (DateTime?)f.DepartureAtUtc)
                    .Min()
            })
            .SingleOrDefaultAsync(cancellationToken);

        return destination ?? throw new NotFoundException($"Destinacija sa ID vrijednoscu {id} nije pronadjena.");
    }

    private IQueryable<JetGo.Domain.Entities.Destination> BuildQuery(DestinationSearchRequest request)
    {
        var query = _dbContext.Destinations.AsNoTracking().AsQueryable();

        if (request.DepartureAirportId.HasValue)
        {
            query = query.Where(x => x.DepartureAirportId == request.DepartureAirportId.Value);
        }

        if (request.ArrivalAirportId.HasValue)
        {
            query = query.Where(x => x.ArrivalAirportId == request.ArrivalAirportId.Value);
        }

        if (request.IsActive.HasValue)
        {
            query = query.Where(x => x.IsActive == request.IsActive.Value);
        }

        if (!string.IsNullOrWhiteSpace(request.SearchText))
        {
            var searchText = request.SearchText.Trim();

            query = query.Where(x =>
                x.RouteCode.Contains(searchText) ||
                x.DepartureAirport.Name.Contains(searchText) ||
                x.DepartureAirport.IataCode.Contains(searchText) ||
                x.DepartureAirport.City.Name.Contains(searchText) ||
                x.ArrivalAirport.Name.Contains(searchText) ||
                x.ArrivalAirport.IataCode.Contains(searchText) ||
                x.ArrivalAirport.City.Name.Contains(searchText));
        }

        return query;
    }
}
