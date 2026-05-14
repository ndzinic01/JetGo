using JetGo.Application.DTOs.Cities;
using JetGo.Application.DTOs.Common;
using JetGo.Application.Requests.Cities;

namespace JetGo.Application.Contracts.Services;

public interface ICityAdminService
{
    Task<PagedResponseDto<CityListItemDto>> GetPagedAsync(CitySearchRequest request, CancellationToken cancellationToken = default);

    Task<CityDetailsDto> GetByIdAsync(int id, CancellationToken cancellationToken = default);

    Task<CityDetailsDto> CreateAsync(UpsertCityRequest request, CancellationToken cancellationToken = default);

    Task<CityDetailsDto> UpdateAsync(int id, UpsertCityRequest request, CancellationToken cancellationToken = default);

    Task DeleteAsync(int id, CancellationToken cancellationToken = default);
}
