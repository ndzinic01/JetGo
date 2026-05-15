using JetGo.Application.Contracts.Services;
using JetGo.Application.DTOs.Common;
using JetGo.Application.DTOs.Destinations;
using JetGo.Application.Exceptions;
using JetGo.Application.Requests.Destinations;
using JetGo.Domain.Entities;
using JetGo.Domain.Enums;
using JetGo.Infrastructure.Persistence;
using JetGo.Infrastructure.Services.Common;
using Microsoft.EntityFrameworkCore;

namespace JetGo.Infrastructure.Services;

public sealed class DestinationAdminService : IDestinationAdminService
{
    private readonly JetGoDbContext _dbContext;

    public DestinationAdminService(JetGoDbContext dbContext)
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

    public async Task<DestinationDetailsDto> CreateAsync(UpsertDestinationRequest request, CancellationToken cancellationToken = default)
    {
        var airportData = await ResolveAirportsAsync(request.DepartureAirportId, request.ArrivalAirportId, cancellationToken);
        await EnsureUniqueAsync(request.DepartureAirportId, request.ArrivalAirportId, null, cancellationToken);

        var destination = new Destination
        {
            DepartureAirportId = request.DepartureAirportId,
            ArrivalAirportId = request.ArrivalAirportId,
            RouteCode = $"{airportData.DepartureIataCode}-{airportData.ArrivalIataCode}",
            IsActive = request.IsActive
        };

        await _dbContext.Destinations.AddAsync(destination, cancellationToken);
        await _dbContext.SaveChangesAsync(cancellationToken);

        return await GetByIdAsync(destination.Id, cancellationToken);
    }

    public async Task<DestinationDetailsDto> UpdateAsync(int id, UpsertDestinationRequest request, CancellationToken cancellationToken = default)
    {
        var destination = await _dbContext.Destinations
            .Include(x => x.Flights)
            .SingleOrDefaultAsync(x => x.Id == id, cancellationToken);

        if (destination is null)
        {
            throw new NotFoundException($"Destinacija sa ID vrijednoscu {id} nije pronadjena.");
        }

        var airportData = await ResolveAirportsAsync(request.DepartureAirportId, request.ArrivalAirportId, cancellationToken);
        await EnsureUniqueAsync(request.DepartureAirportId, request.ArrivalAirportId, id, cancellationToken);

        var hasFlights = destination.Flights.Count > 0;
        var routeChanged = destination.DepartureAirportId != request.DepartureAirportId || destination.ArrivalAirportId != request.ArrivalAirportId;

        if (hasFlights && routeChanged)
        {
            throw new ConflictException("Promjena polaznog ili dolaznog aerodroma nije moguca jer vec postoje letovi povezani sa ovom destinacijom.");
        }

        destination.DepartureAirportId = request.DepartureAirportId;
        destination.ArrivalAirportId = request.ArrivalAirportId;
        destination.RouteCode = $"{airportData.DepartureIataCode}-{airportData.ArrivalIataCode}";
        destination.IsActive = request.IsActive;
        destination.UpdatedAtUtc = DateTime.UtcNow;

        await _dbContext.SaveChangesAsync(cancellationToken);

        return await GetByIdAsync(destination.Id, cancellationToken);
    }

    public async Task DeleteAsync(int id, CancellationToken cancellationToken = default)
    {
        var destination = await _dbContext.Destinations.SingleOrDefaultAsync(x => x.Id == id, cancellationToken);

        if (destination is null)
        {
            throw new NotFoundException($"Destinacija sa ID vrijednoscu {id} nije pronadjena.");
        }

        var hasFlights = await _dbContext.Flights.AnyAsync(x => x.DestinationId == id, cancellationToken);

        if (hasFlights)
        {
            throw new ConflictException("Brisanje destinacije nije moguce jer postoje letovi povezani sa ovom destinacijom.");
        }

        _dbContext.Destinations.Remove(destination);
        await _dbContext.SaveChangesAsync(cancellationToken);
    }

    private IQueryable<Destination> BuildQuery(DestinationSearchRequest request)
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

    private async Task<(string DepartureIataCode, string ArrivalIataCode)> ResolveAirportsAsync(int departureAirportId, int arrivalAirportId, CancellationToken cancellationToken)
    {
        if (departureAirportId == arrivalAirportId)
        {
            throw new ValidationException(
                "Polazni i dolazni aerodrom ne mogu biti isti.",
                new Dictionary<string, string[]>
                {
                    ["arrivalAirportId"] = ["Polazni i dolazni aerodrom ne mogu biti isti."]
                });
        }

        var airports = await _dbContext.Airports
            .AsNoTracking()
            .Where(x => x.Id == departureAirportId || x.Id == arrivalAirportId)
            .Select(x => new { x.Id, x.IataCode })
            .ToListAsync(cancellationToken);

        var departureAirport = airports.SingleOrDefault(x => x.Id == departureAirportId);
        var arrivalAirport = airports.SingleOrDefault(x => x.Id == arrivalAirportId);

        if (departureAirport is null)
        {
            throw new ValidationException(
                "Odabrani polazni aerodrom ne postoji.",
                new Dictionary<string, string[]>
                {
                    ["departureAirportId"] = ["Odabrani polazni aerodrom ne postoji."]
                });
        }

        if (arrivalAirport is null)
        {
            throw new ValidationException(
                "Odabrani dolazni aerodrom ne postoji.",
                new Dictionary<string, string[]>
                {
                    ["arrivalAirportId"] = ["Odabrani dolazni aerodrom ne postoji."]
                });
        }

        return (departureAirport.IataCode, arrivalAirport.IataCode);
    }

    private async Task EnsureUniqueAsync(int departureAirportId, int arrivalAirportId, int? currentId, CancellationToken cancellationToken)
    {
        var exists = await _dbContext.Destinations.AnyAsync(
            x => x.DepartureAirportId == departureAirportId &&
                 x.ArrivalAirportId == arrivalAirportId &&
                 (!currentId.HasValue || x.Id != currentId.Value),
            cancellationToken);

        if (exists)
        {
            throw new ConflictException("Destinacija sa istom rutom vec postoji.");
        }
    }
}
