using JetGo.Application.DTOs.Airports;
using JetGo.Application.DTOs.Common;
using JetGo.Application.Requests.Airports;

namespace JetGo.Application.Contracts.Services;

public interface IAirportAdminService
{
    Task<PagedResponseDto<AirportListItemDto>> GetPagedAsync(AirportSearchRequest request, CancellationToken cancellationToken = default);

    Task<AirportDetailsDto> GetByIdAsync(int id, CancellationToken cancellationToken = default);

    Task<AirportDetailsDto> CreateAsync(UpsertAirportRequest request, CancellationToken cancellationToken = default);

    Task<AirportDetailsDto> UpdateAsync(int id, UpsertAirportRequest request, CancellationToken cancellationToken = default);

    Task DeleteAsync(int id, CancellationToken cancellationToken = default);
}
