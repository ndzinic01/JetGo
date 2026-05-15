using JetGo.Application.DTOs.Common;
using JetGo.Application.DTOs.Destinations;
using JetGo.Application.Requests.Destinations;

namespace JetGo.Application.Contracts.Services;

public interface IDestinationAdminService
{
    Task<PagedResponseDto<DestinationListItemDto>> GetPagedAsync(DestinationSearchRequest request, CancellationToken cancellationToken = default);

    Task<DestinationDetailsDto> GetByIdAsync(int id, CancellationToken cancellationToken = default);

    Task<DestinationDetailsDto> CreateAsync(UpsertDestinationRequest request, CancellationToken cancellationToken = default);

    Task<DestinationDetailsDto> UpdateAsync(int id, UpsertDestinationRequest request, CancellationToken cancellationToken = default);

    Task DeleteAsync(int id, CancellationToken cancellationToken = default);
}
