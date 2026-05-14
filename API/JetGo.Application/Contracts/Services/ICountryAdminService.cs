using JetGo.Application.DTOs.Common;
using JetGo.Application.DTOs.Countries;
using JetGo.Application.Requests.Countries;

namespace JetGo.Application.Contracts.Services;

public interface ICountryAdminService
{
    Task<PagedResponseDto<CountryListItemDto>> GetPagedAsync(CountrySearchRequest request, CancellationToken cancellationToken = default);

    Task<CountryDetailsDto> GetByIdAsync(int id, CancellationToken cancellationToken = default);

    Task<CountryDetailsDto> CreateAsync(UpsertCountryRequest request, CancellationToken cancellationToken = default);

    Task<CountryDetailsDto> UpdateAsync(int id, UpsertCountryRequest request, CancellationToken cancellationToken = default);

    Task DeleteAsync(int id, CancellationToken cancellationToken = default);
}
