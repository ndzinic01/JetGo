using JetGo.Application.Contracts.Services;
using JetGo.Application.DTOs.Airlines;
using JetGo.Application.DTOs.Common;
using JetGo.Application.Exceptions;
using JetGo.Application.Requests.Airlines;
using JetGo.Domain.Entities;
using JetGo.Infrastructure.Persistence;
using JetGo.Infrastructure.Services.Common;
using Microsoft.EntityFrameworkCore;

namespace JetGo.Infrastructure.Services;

public sealed class AirlineAdminService : IAirlineAdminService
{
    private readonly JetGoDbContext _dbContext;

    public AirlineAdminService(JetGoDbContext dbContext)
    {
        _dbContext = dbContext;
    }

    public async Task<PagedResponseDto<AirlineListItemDto>> GetPagedAsync(AirlineSearchRequest request, CancellationToken cancellationToken = default)
    {
        var query = _dbContext.Airlines.AsNoTracking().AsQueryable();

        if (request.IsActive.HasValue)
        {
            query = query.Where(x => x.IsActive == request.IsActive.Value);
        }

        if (!string.IsNullOrWhiteSpace(request.SearchText))
        {
            var searchText = request.SearchText.Trim();
            query = query.Where(x => x.Name.Contains(searchText) || x.Code.Contains(searchText));
        }

        var totalCount = await query.CountAsync(cancellationToken);

        var items = await query
            .OrderBy(x => x.Name)
            .ThenBy(x => x.Code)
            .Skip((request.Page - 1) * request.PageSize)
            .Take(request.PageSize)
            .Select(x => new AirlineListItemDto
            {
                Id = x.Id,
                Name = x.Name,
                Code = x.Code,
                LogoUrl = x.LogoUrl,
                IsActive = x.IsActive,
                FlightsCount = x.Flights.Count
            })
            .ToListAsync(cancellationToken);

        return PagedResponseBuilder.Build(items, request.Page, request.PageSize, totalCount);
    }

    public async Task<AirlineDetailsDto> GetByIdAsync(int id, CancellationToken cancellationToken = default)
    {
        var airline = await _dbContext.Airlines
            .AsNoTracking()
            .Where(x => x.Id == id)
            .Select(x => new AirlineDetailsDto
            {
                Id = x.Id,
                Name = x.Name,
                Code = x.Code,
                LogoUrl = x.LogoUrl,
                IsActive = x.IsActive,
                FlightsCount = x.Flights.Count,
                CreatedAtUtc = x.CreatedAtUtc,
                UpdatedAtUtc = x.UpdatedAtUtc
            })
            .SingleOrDefaultAsync(cancellationToken);

        return airline ?? throw new NotFoundException($"Aviokompanija sa ID vrijednoscu {id} nije pronadjena.");
    }

    public async Task<AirlineDetailsDto> CreateAsync(UpsertAirlineRequest request, CancellationToken cancellationToken = default)
    {
        var normalizedName = NormalizeRequired(request.Name, "name", "Naziv aviokompanije je obavezan.");
        var normalizedCode = NormalizeRequired(request.Code, "code", "Kod aviokompanije je obavezan.").ToUpperInvariant();
        var normalizedLogoUrl = NormalizeOptional(request.LogoUrl);

        await EnsureUniqueAsync(normalizedName, normalizedCode, null, cancellationToken);

        var airline = new Airline
        {
            Name = normalizedName,
            Code = normalizedCode,
            LogoUrl = normalizedLogoUrl,
            IsActive = request.IsActive
        };

        await _dbContext.Airlines.AddAsync(airline, cancellationToken);
        await _dbContext.SaveChangesAsync(cancellationToken);

        return await GetByIdAsync(airline.Id, cancellationToken);
    }

    public async Task<AirlineDetailsDto> UpdateAsync(int id, UpsertAirlineRequest request, CancellationToken cancellationToken = default)
    {
        var airline = await _dbContext.Airlines.SingleOrDefaultAsync(x => x.Id == id, cancellationToken);

        if (airline is null)
        {
            throw new NotFoundException($"Aviokompanija sa ID vrijednoscu {id} nije pronadjena.");
        }

        var normalizedName = NormalizeRequired(request.Name, "name", "Naziv aviokompanije je obavezan.");
        var normalizedCode = NormalizeRequired(request.Code, "code", "Kod aviokompanije je obavezan.").ToUpperInvariant();
        var normalizedLogoUrl = NormalizeOptional(request.LogoUrl);

        await EnsureUniqueAsync(normalizedName, normalizedCode, id, cancellationToken);

        airline.Name = normalizedName;
        airline.Code = normalizedCode;
        airline.LogoUrl = normalizedLogoUrl;
        airline.IsActive = request.IsActive;
        airline.UpdatedAtUtc = DateTime.UtcNow;

        await _dbContext.SaveChangesAsync(cancellationToken);

        return await GetByIdAsync(airline.Id, cancellationToken);
    }

    public async Task DeleteAsync(int id, CancellationToken cancellationToken = default)
    {
        var airline = await _dbContext.Airlines.SingleOrDefaultAsync(x => x.Id == id, cancellationToken);

        if (airline is null)
        {
            throw new NotFoundException($"Aviokompanija sa ID vrijednoscu {id} nije pronadjena.");
        }

        var hasFlights = await _dbContext.Flights.AnyAsync(x => x.AirlineId == id, cancellationToken);

        if (hasFlights)
        {
            throw new ConflictException("Brisanje aviokompanije nije moguce jer postoje letovi povezani sa ovom aviokompanijom.");
        }

        _dbContext.Airlines.Remove(airline);
        await _dbContext.SaveChangesAsync(cancellationToken);
    }

    private async Task EnsureUniqueAsync(string name, string code, int? currentId, CancellationToken cancellationToken)
    {
        var hasName = await _dbContext.Airlines.AnyAsync(
            x => x.Name == name && (!currentId.HasValue || x.Id != currentId.Value),
            cancellationToken);

        if (hasName)
        {
            throw new ConflictException("Aviokompanija sa istim nazivom vec postoji.");
        }

        var hasCode = await _dbContext.Airlines.AnyAsync(
            x => x.Code == code && (!currentId.HasValue || x.Id != currentId.Value),
            cancellationToken);

        if (hasCode)
        {
            throw new ConflictException("Aviokompanija sa istim kodom vec postoji.");
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

    private static string? NormalizeOptional(string? value)
    {
        if (string.IsNullOrWhiteSpace(value))
        {
            return null;
        }

        return value.Trim();
    }
}
