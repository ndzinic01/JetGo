using JetGo.Application.Contracts.Services;
using JetGo.Application.DTOs.Common;
using JetGo.Application.DTOs.Countries;
using JetGo.Application.Exceptions;
using JetGo.Application.Requests.Countries;
using JetGo.Domain.Entities;
using JetGo.Infrastructure.Persistence;
using JetGo.Infrastructure.Services.Common;
using Microsoft.EntityFrameworkCore;

namespace JetGo.Infrastructure.Services;

public sealed class CountryAdminService : ICountryAdminService
{
    private readonly JetGoDbContext _dbContext;

    public CountryAdminService(JetGoDbContext dbContext)
    {
        _dbContext = dbContext;
    }

    public async Task<PagedResponseDto<CountryListItemDto>> GetPagedAsync(CountrySearchRequest request, CancellationToken cancellationToken = default)
    {
        var query = _dbContext.Countries.AsNoTracking().AsQueryable();

        if (!string.IsNullOrWhiteSpace(request.SearchText))
        {
            var searchText = request.SearchText.Trim();
            query = query.Where(x => x.Name.Contains(searchText) || x.IsoCode.Contains(searchText));
        }

        var totalCount = await query.CountAsync(cancellationToken);

        var items = await query
            .OrderBy(x => x.Name)
            .ThenBy(x => x.IsoCode)
            .Skip((request.Page - 1) * request.PageSize)
            .Take(request.PageSize)
            .Select(x => new CountryListItemDto
            {
                Id = x.Id,
                Name = x.Name,
                IsoCode = x.IsoCode,
                CitiesCount = x.Cities.Count
            })
            .ToListAsync(cancellationToken);

        return PagedResponseBuilder.Build(items, request.Page, request.PageSize, totalCount);
    }

    public async Task<CountryDetailsDto> GetByIdAsync(int id, CancellationToken cancellationToken = default)
    {
        var country = await _dbContext.Countries
            .AsNoTracking()
            .Where(x => x.Id == id)
            .Select(x => new CountryDetailsDto
            {
                Id = x.Id,
                Name = x.Name,
                IsoCode = x.IsoCode,
                CitiesCount = x.Cities.Count,
                CreatedAtUtc = x.CreatedAtUtc,
                UpdatedAtUtc = x.UpdatedAtUtc
            })
            .SingleOrDefaultAsync(cancellationToken);

        return country ?? throw new NotFoundException($"Drzava sa ID vrijednoscu {id} nije pronadjena.");
    }

    public async Task<CountryDetailsDto> CreateAsync(UpsertCountryRequest request, CancellationToken cancellationToken = default)
    {
        var normalizedName = NormalizeRequired(request.Name, "name", "Naziv drzave je obavezan.");
        var normalizedIsoCode = NormalizeCountryCode(request.IsoCode);

        await EnsureUniqueAsync(normalizedName, normalizedIsoCode, null, cancellationToken);

        var country = new Country
        {
            Name = normalizedName,
            IsoCode = normalizedIsoCode
        };

        await _dbContext.Countries.AddAsync(country, cancellationToken);
        await _dbContext.SaveChangesAsync(cancellationToken);

        return await GetByIdAsync(country.Id, cancellationToken);
    }

    public async Task<CountryDetailsDto> UpdateAsync(int id, UpsertCountryRequest request, CancellationToken cancellationToken = default)
    {
        var country = await _dbContext.Countries.SingleOrDefaultAsync(x => x.Id == id, cancellationToken);

        if (country is null)
        {
            throw new NotFoundException($"Drzava sa ID vrijednoscu {id} nije pronadjena.");
        }

        var normalizedName = NormalizeRequired(request.Name, "name", "Naziv drzave je obavezan.");
        var normalizedIsoCode = NormalizeCountryCode(request.IsoCode);

        await EnsureUniqueAsync(normalizedName, normalizedIsoCode, id, cancellationToken);

        country.Name = normalizedName;
        country.IsoCode = normalizedIsoCode;
        country.UpdatedAtUtc = DateTime.UtcNow;

        await _dbContext.SaveChangesAsync(cancellationToken);

        return await GetByIdAsync(country.Id, cancellationToken);
    }

    public async Task DeleteAsync(int id, CancellationToken cancellationToken = default)
    {
        var country = await _dbContext.Countries.SingleOrDefaultAsync(x => x.Id == id, cancellationToken);

        if (country is null)
        {
            throw new NotFoundException($"Drzava sa ID vrijednoscu {id} nije pronadjena.");
        }

        var hasCities = await _dbContext.Cities.AnyAsync(x => x.CountryId == id, cancellationToken);

        if (hasCities)
        {
            throw new ConflictException("Brisanje drzave nije moguce jer postoje gradovi koji su povezani sa ovom drzavom.");
        }

        _dbContext.Countries.Remove(country);
        await _dbContext.SaveChangesAsync(cancellationToken);
    }

    private async Task EnsureUniqueAsync(string name, string isoCode, int? currentId, CancellationToken cancellationToken)
    {
        var hasName = await _dbContext.Countries.AnyAsync(
            x => x.Name == name && (!currentId.HasValue || x.Id != currentId.Value),
            cancellationToken);

        if (hasName)
        {
            throw new ConflictException("Drzava sa istim nazivom vec postoji.");
        }

        var hasIsoCode = await _dbContext.Countries.AnyAsync(
            x => x.IsoCode == isoCode && (!currentId.HasValue || x.Id != currentId.Value),
            cancellationToken);

        if (hasIsoCode)
        {
            throw new ConflictException("Drzava sa istim ISO kodom vec postoji.");
        }
    }

    private static string NormalizeCountryCode(string isoCode)
    {
        var normalizedIsoCode = NormalizeRequired(isoCode, "isoCode", "ISO kod drzave je obavezan.").ToUpperInvariant();

        if (normalizedIsoCode.Length != 2)
        {
            throw new ValidationException(
                "ISO kod drzave mora sadrzavati tacno 2 karaktera.",
                new Dictionary<string, string[]>
                {
                    ["isoCode"] = ["ISO kod drzave mora sadrzavati tacno 2 karaktera."]
                });
        }

        return normalizedIsoCode;
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
