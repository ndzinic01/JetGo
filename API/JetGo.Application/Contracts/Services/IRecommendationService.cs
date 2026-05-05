using JetGo.Application.DTOs.Common;
using JetGo.Application.DTOs.Recommendations;
using JetGo.Application.Requests.Recommendations;

namespace JetGo.Application.Contracts.Services;

public interface IRecommendationService
{
    Task<PagedResponseDto<RecommendedFlightDto>> GetRecommendedFlightsAsync(
        FlightRecommendationRequest request,
        CancellationToken cancellationToken = default);
}
