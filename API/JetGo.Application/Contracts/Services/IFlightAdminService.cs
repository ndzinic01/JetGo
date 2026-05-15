using JetGo.Application.DTOs.Common;
using JetGo.Application.DTOs.Flights;
using JetGo.Application.Requests.Flights;

namespace JetGo.Application.Contracts.Services;

public interface IFlightAdminService
{
    Task<PagedResponseDto<FlightListItemDto>> GetPagedAsync(FlightSearchRequest request, CancellationToken cancellationToken = default);

    Task<FlightDetailsDto> GetByIdAsync(int id, CancellationToken cancellationToken = default);

    Task<FlightDetailsDto> CreateAsync(UpsertFlightRequest request, CancellationToken cancellationToken = default);

    Task<FlightDetailsDto> UpdateAsync(int id, UpsertFlightRequest request, CancellationToken cancellationToken = default);

    Task DeleteAsync(int id, CancellationToken cancellationToken = default);
}
