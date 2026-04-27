using JetGo.Application.DTOs.Common;
using JetGo.Application.DTOs.Flights;
using JetGo.Application.Requests.Flights;

namespace JetGo.Application.Contracts.Services;

public interface IFlightService
{
    Task<PagedResponseDto<FlightListItemDto>> GetPagedAsync(FlightSearchRequest request, CancellationToken cancellationToken = default);

    Task<FlightDetailsDto> GetByIdAsync(int id, CancellationToken cancellationToken = default);
}
