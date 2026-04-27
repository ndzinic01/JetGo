using JetGo.Application.Contracts.Services;
using JetGo.Application.DTOs.Common;
using JetGo.Application.DTOs.Flights;
using JetGo.Application.Requests.Flights;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace JetGo.API.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public sealed class FlightsController : ControllerBase
{
    private readonly IFlightService _flightService;

    public FlightsController(IFlightService flightService)
    {
        _flightService = flightService;
    }

    [HttpGet]
    [ProducesResponseType(typeof(PagedResponseDto<FlightListItemDto>), StatusCodes.Status200OK)]
    public async Task<ActionResult<PagedResponseDto<FlightListItemDto>>> Get([FromQuery] FlightSearchRequest request, CancellationToken cancellationToken)
    {
        var response = await _flightService.GetPagedAsync(request, cancellationToken);
        return Ok(response);
    }

    [HttpGet("{id:int}")]
    [ProducesResponseType(typeof(FlightDetailsDto), StatusCodes.Status200OK)]
    public async Task<ActionResult<FlightDetailsDto>> GetById(int id, CancellationToken cancellationToken)
    {
        var response = await _flightService.GetByIdAsync(id, cancellationToken);
        return Ok(response);
    }
}
