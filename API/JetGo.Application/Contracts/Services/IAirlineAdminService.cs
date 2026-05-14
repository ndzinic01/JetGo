using JetGo.Application.DTOs.Airlines;
using JetGo.Application.DTOs.Common;
using JetGo.Application.Requests.Airlines;

namespace JetGo.Application.Contracts.Services;

public interface IAirlineAdminService
{
    Task<PagedResponseDto<AirlineListItemDto>> GetPagedAsync(AirlineSearchRequest request, CancellationToken cancellationToken = default);

    Task<AirlineDetailsDto> GetByIdAsync(int id, CancellationToken cancellationToken = default);

    Task<AirlineDetailsDto> CreateAsync(UpsertAirlineRequest request, CancellationToken cancellationToken = default);

    Task<AirlineDetailsDto> UpdateAsync(int id, UpsertAirlineRequest request, CancellationToken cancellationToken = default);

    Task DeleteAsync(int id, CancellationToken cancellationToken = default);
}
