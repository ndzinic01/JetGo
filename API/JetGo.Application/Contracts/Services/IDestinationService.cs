using JetGo.Application.DTOs.Common;
using JetGo.Application.DTOs.Destinations;
using JetGo.Application.Requests.Destinations;

namespace JetGo.Application.Contracts.Services;

public interface IDestinationService
{
    Task<PagedResponseDto<DestinationListItemDto>> GetPagedAsync(DestinationSearchRequest request, CancellationToken cancellationToken = default);

    Task<DestinationDetailsDto> GetByIdAsync(int id, CancellationToken cancellationToken = default);
}
