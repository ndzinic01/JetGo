using JetGo.Application.Contracts.Services;
using JetGo.Application.DTOs.Common;
using JetGo.Application.DTOs.Recommendations;
using JetGo.Application.Requests.Recommendations;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace JetGo.API.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public sealed class RecommendationsController : ControllerBase
{
    private readonly IRecommendationService _recommendationService;

    public RecommendationsController(IRecommendationService recommendationService)
    {
        _recommendationService = recommendationService;
    }

    [HttpGet("flights")]
    [ProducesResponseType(typeof(PagedResponseDto<RecommendedFlightDto>), StatusCodes.Status200OK)]
    public async Task<ActionResult<PagedResponseDto<RecommendedFlightDto>>> GetFlights(
        [FromQuery] FlightRecommendationRequest request,
        CancellationToken cancellationToken)
    {
        var response = await _recommendationService.GetRecommendedFlightsAsync(request, cancellationToken);
        return Ok(response);
    }
}
