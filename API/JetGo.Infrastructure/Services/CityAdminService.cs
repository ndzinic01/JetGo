using JetGo.Application.Contracts.Services;
using JetGo.Application.DTOs.Cities;
using JetGo.Application.DTOs.Common;
using JetGo.Application.Exceptions;
using JetGo.Application.Requests.Cities;
using JetGo.Domain.Entities;
using JetGo.Infrastructure.Persistence;
using JetGo.Infrastructure.Services.Common;
using Microsoft.EntityFrameworkCore;

namespace JetGo.Infrastructure.Services;

public sealed class CityAdminService : ICityAdminService
{
    private readonly JetGoDbContext _dbContext;

    public CityAdminService(JetGoDbContext dbContext)
    {
        _dbContext = dbContext;
    }

    public async Task<PagedResponseDto<CityListItemDto>> GetPagedAsync(CitySearchRequest request, CancellationToken cancellationToken = default)
    {
        var query = _dbContext.Cities.AsNoTracking().AsQueryable();

        if (request.CountryId.HasValue)
        {
            query = query.Where(x => x.CountryId == request.CountryId.Value);
        }

        if (!string.IsNullOrWhiteSpace(request.SearchText))
        {
            var searchText = request.SearchText.Trim();
            query = query.Where(x => x.Name.Contains(searchText) || x.Country.Name.Contains(searchText) || x.Country.IsoCode.Contains(searchText));
        }

        var totalCount = await query.CountAsync(cancellationToken);

        var items = await query
            .OrderBy(x => x.Country.Name)
            .ThenBy(x => x.Name)
            .Skip((request.Page - 1) * request.PageSize)
            .Take(request.PageSize)
            .Select(x => new CityListItemDto
            {
                Id = x.Id,
                Name = x.Name,
                CountryId = x.CountryId,
                CountryName = x.Country.Name,
                CountryIsoCode = x.Country.IsoCode,
                AirportsCount = x.Airports.Count
            })
            .ToListAsync(cancellationToken);

        return PagedResponseBuilder.Build(items, request.Page, request.PageSize, totalCount);
    }

    public async Task<CityDetailsDto> GetByIdAsync(int id, CancellationToken cancellationToken = default)
    {
        var city = await _dbContext.Cities
            .AsNoTracking()
            .Where(x => x.Id == id)
            .Select(x => new CityDetailsDto
            {
                Id = x.Id,
                Name = x.Name,
                CountryId = x.CountryId,
                CountryName = x.Country.Name,
                CountryIsoCode = x.Country.IsoCode,
                AirportsCount = x.Airports.Count,
                CreatedAtUtc = x.CreatedAtUtc,
                UpdatedAtUtc = x.UpdatedAtUtc
            })
            .SingleOrDefaultAsync(cancellationToken);

        return city ?? throw new NotFoundException($"Grad sa ID vrijednoscu {id} nije pronadjen.");
    }

    public async Task<CityDetailsDto> CreateAsync(UpsertCityRequest request, CancellationToken cancellationToken = default)
    {
        await EnsureCountryExistsAsync(request.CountryId, cancellationToken);

        var normalizedName = NormalizeRequired(request.Name, "name", "Naziv grada je obavezan.");
        await EnsureUniqueAsync(request.CountryId, normalizedName, null, cancellationToken);

        var city = new City
        {
            CountryId = request.CountryId,
            Name = normalizedName
        };

        await _dbContext.Cities.AddAsync(city, cancellationToken);
        await _dbContext.SaveChangesAsync(cancellationToken);

        return await GetByIdAsync(city.Id, cancellationToken);
    }

    public async Task<CityDetailsDto> UpdateAsync(int id, UpsertCityRequest request, CancellationToken cancellationToken = default)
    {
        var city = await _dbContext.Cities.SingleOrDefaultAsync(x => x.Id == id, cancellationToken);

        if (city is null)
        {
            throw new NotFoundException($"Grad sa ID vrijednoscu {id} nije pronadjen.");
        }

        await EnsureCountryExistsAsync(request.CountryId, cancellationToken);

        var normalizedName = NormalizeRequired(request.Name, "name", "Naziv grada je obavezan.");
        await EnsureUniqueAsync(request.CountryId, normalizedName, id, cancellationToken);

        city.CountryId = request.CountryId;
        city.Name = normalizedName;
        city.UpdatedAtUtc = DateTime.UtcNow;

        await _dbContext.SaveChangesAsync(cancellationToken);

        return await GetByIdAsync(city.Id, cancellationToken);
    }

    public async Task DeleteAsync(int id, CancellationToken cancellationToken = default)
    {
        var city = await _dbContext.Cities.SingleOrDefaultAsync(x => x.Id == id, cancellationToken);

        if (city is null)
        {
            throw new NotFoundException($"Grad sa ID vrijednoscu {id} nije pronadjen.");
        }

        var hasAirports = await _dbContext.Airports.AnyAsync(x => x.CityId == id, cancellationToken);

        if (hasAirports)
        {
            throw new ConflictException("Brisanje grada nije moguce jer postoje aerodromi povezani sa ovim gradom.");
        }

        _dbContext.Cities.Remove(city);
        await _dbContext.SaveChangesAsync(cancellationToken);
    }

    private async Task EnsureCountryExistsAsync(int countryId, CancellationToken cancellationToken)
    {
        var countryExists = await _dbContext.Countries.AnyAsync(x => x.Id == countryId, cancellationToken);

        if (!countryExists)
        {
            throw new ValidationException(
                "Odabrana drzava ne postoji.",
                new Dictionary<string, string[]>
                {
                    ["countryId"] = ["Odabrana drzava ne postoji."]
                });
        }
    }

    private async Task EnsureUniqueAsync(int countryId, string name, int? currentId, CancellationToken cancellationToken)
    {
        var exists = await _dbContext.Cities.AnyAsync(
            x => x.CountryId == countryId && x.Name == name && (!currentId.HasValue || x.Id != currentId.Value),
            cancellationToken);

        if (exists)
        {
            throw new ConflictException("Grad sa istim nazivom vec postoji u odabranoj drzavi.");
        }
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
