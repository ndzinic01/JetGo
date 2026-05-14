using JetGo.Application.Contracts.Services;
using JetGo.Application.DTOs.Airports;
using JetGo.Application.DTOs.Common;
using JetGo.Application.Exceptions;
using JetGo.Application.Requests.Airports;
using JetGo.Domain.Entities;
using JetGo.Infrastructure.Persistence;
using JetGo.Infrastructure.Services.Common;
using Microsoft.EntityFrameworkCore;

namespace JetGo.Infrastructure.Services;

public sealed class AirportAdminService : IAirportAdminService
{
    private readonly JetGoDbContext _dbContext;

    public AirportAdminService(JetGoDbContext dbContext)
    {
        _dbContext = dbContext;
    }

    public async Task<PagedResponseDto<AirportListItemDto>> GetPagedAsync(AirportSearchRequest request, CancellationToken cancellationToken = default)
    {
        var query = _dbContext.Airports.AsNoTracking().AsQueryable();

        if (request.CountryId.HasValue)
        {
            query = query.Where(x => x.City.CountryId == request.CountryId.Value);
        }

        if (request.CityId.HasValue)
        {
            query = query.Where(x => x.CityId == request.CityId.Value);
        }

        if (!string.IsNullOrWhiteSpace(request.SearchText))
        {
            var searchText = request.SearchText.Trim();
            query = query.Where(x =>
                x.Name.Contains(searchText) ||
                x.IataCode.Contains(searchText) ||
                x.City.Name.Contains(searchText) ||
                x.City.Country.Name.Contains(searchText));
        }

        var totalCount = await query.CountAsync(cancellationToken);

        var items = await query
            .OrderBy(x => x.City.Country.Name)
            .ThenBy(x => x.City.Name)
            .ThenBy(x => x.Name)
            .Skip((request.Page - 1) * request.PageSize)
            .Take(request.PageSize)
            .Select(x => new AirportListItemDto
            {
                Id = x.Id,
                Name = x.Name,
                IataCode = x.IataCode,
                CityId = x.CityId,
                CityName = x.City.Name,
                CountryId = x.City.CountryId,
                CountryName = x.City.Country.Name,
                Latitude = x.Latitude,
                Longitude = x.Longitude,
                RelatedDestinationsCount = x.DepartureDestinations.Count + x.ArrivalDestinations.Count
            })
            .ToListAsync(cancellationToken);

        return PagedResponseBuilder.Build(items, request.Page, request.PageSize, totalCount);
    }

    public async Task<AirportDetailsDto> GetByIdAsync(int id, CancellationToken cancellationToken = default)
    {
        var airport = await _dbContext.Airports
            .AsNoTracking()
            .Where(x => x.Id == id)
            .Select(x => new AirportDetailsDto
            {
                Id = x.Id,
                Name = x.Name,
                IataCode = x.IataCode,
                CityId = x.CityId,
                CityName = x.City.Name,
                CountryId = x.City.CountryId,
                CountryName = x.City.Country.Name,
                Latitude = x.Latitude,
                Longitude = x.Longitude,
                DepartureDestinationsCount = x.DepartureDestinations.Count,
                ArrivalDestinationsCount = x.ArrivalDestinations.Count,
                CreatedAtUtc = x.CreatedAtUtc,
                UpdatedAtUtc = x.UpdatedAtUtc
            })
            .SingleOrDefaultAsync(cancellationToken);

        return airport ?? throw new NotFoundException($"Aerodrom sa ID vrijednoscu {id} nije pronadjen.");
    }

    public async Task<AirportDetailsDto> CreateAsync(UpsertAirportRequest request, CancellationToken cancellationToken = default)
    {
        await EnsureCityExistsAsync(request.CityId, cancellationToken);

        var normalizedName = NormalizeRequired(request.Name, "name", "Naziv aerodroma je obavezan.");
        var normalizedIataCode = NormalizeIataCode(request.IataCode);

        await EnsureUniqueAsync(normalizedIataCode, null, cancellationToken);

        var airport = new Airport
        {
            CityId = request.CityId,
            Name = normalizedName,
            IataCode = normalizedIataCode,
            Latitude = request.Latitude,
            Longitude = request.Longitude
        };

        await _dbContext.Airports.AddAsync(airport, cancellationToken);
        await _dbContext.SaveChangesAsync(cancellationToken);

        return await GetByIdAsync(airport.Id, cancellationToken);
    }

    public async Task<AirportDetailsDto> UpdateAsync(int id, UpsertAirportRequest request, CancellationToken cancellationToken = default)
    {
        var airport = await _dbContext.Airports.SingleOrDefaultAsync(x => x.Id == id, cancellationToken);

        if (airport is null)
        {
            throw new NotFoundException($"Aerodrom sa ID vrijednoscu {id} nije pronadjen.");
        }

        await EnsureCityExistsAsync(request.CityId, cancellationToken);

        var normalizedName = NormalizeRequired(request.Name, "name", "Naziv aerodroma je obavezan.");
        var normalizedIataCode = NormalizeIataCode(request.IataCode);

        await EnsureUniqueAsync(normalizedIataCode, id, cancellationToken);

        airport.CityId = request.CityId;
        airport.Name = normalizedName;
        airport.IataCode = normalizedIataCode;
        airport.Latitude = request.Latitude;
        airport.Longitude = request.Longitude;
        airport.UpdatedAtUtc = DateTime.UtcNow;

        await _dbContext.SaveChangesAsync(cancellationToken);

        return await GetByIdAsync(airport.Id, cancellationToken);
    }

    public async Task DeleteAsync(int id, CancellationToken cancellationToken = default)
    {
        var airport = await _dbContext.Airports.SingleOrDefaultAsync(x => x.Id == id, cancellationToken);

        if (airport is null)
        {
            throw new NotFoundException($"Aerodrom sa ID vrijednoscu {id} nije pronadjen.");
        }

        var isUsed = await _dbContext.Destinations.AnyAsync(
            x => x.DepartureAirportId == id || x.ArrivalAirportId == id,
            cancellationToken);

        if (isUsed)
        {
            throw new ConflictException("Brisanje aerodroma nije moguce jer postoje destinacije koje koriste ovaj aerodrom.");
        }

        _dbContext.Airports.Remove(airport);
        await _dbContext.SaveChangesAsync(cancellationToken);
    }

    private async Task EnsureCityExistsAsync(int cityId, CancellationToken cancellationToken)
    {
        var cityExists = await _dbContext.Cities.AnyAsync(x => x.Id == cityId, cancellationToken);

        if (!cityExists)
        {
            throw new ValidationException(
                "Odabrani grad ne postoji.",
                new Dictionary<string, string[]>
                {
                    ["cityId"] = ["Odabrani grad ne postoji."]
                });
        }
    }

    private async Task EnsureUniqueAsync(string iataCode, int? currentId, CancellationToken cancellationToken)
    {
        var exists = await _dbContext.Airports.AnyAsync(
            x => x.IataCode == iataCode && (!currentId.HasValue || x.Id != currentId.Value),
            cancellationToken);

        if (exists)
        {
            throw new ConflictException("Aerodrom sa istim IATA kodom vec postoji.");
        }
    }

    private static string NormalizeIataCode(string iataCode)
    {
        var normalizedIataCode = NormalizeRequired(iataCode, "iataCode", "IATA kod je obavezan.").ToUpperInvariant();

        if (normalizedIataCode.Length != 3)
        {
            throw new ValidationException(
                "IATA kod mora sadrzavati tacno 3 karaktera.",
                new Dictionary<string, string[]>
                {
                    ["iataCode"] = ["IATA kod mora sadrzavati tacno 3 karaktera."]
                });
        }

        return normalizedIataCode;
    }

    private static string NormalizeRequired(string? value, string fieldName, string message)
    {
        if (string.IsNullOrWhiteSpace(value))
        {
            throw new ValidationException(
                message,
                new Dictionary<string, string[]>
                {
                    [fieldName] = [message]
                });
        }

        return value.Trim();
    }
}
