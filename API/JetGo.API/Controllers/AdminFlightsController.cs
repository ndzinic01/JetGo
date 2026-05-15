using JetGo.Application.Constants;
using JetGo.Application.Contracts.Services;
using JetGo.Application.DTOs.Common;
using JetGo.Application.DTOs.Flights;
using JetGo.Application.Requests.Flights;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace JetGo.API.Controllers;

[ApiController]
[Route("api/admin/flights")]
[Authorize(Roles = RoleNames.Admin)]
public sealed class AdminFlightsController : ControllerBase
{
    private readonly IFlightAdminService _flightAdminService;

    public AdminFlightsController(IFlightAdminService flightAdminService)
    {
        _flightAdminService = flightAdminService;
    }

    [HttpGet]
    [ProducesResponseType(typeof(PagedResponseDto<FlightListItemDto>), StatusCodes.Status200OK)]
    public async Task<ActionResult<PagedResponseDto<FlightListItemDto>>> GetPaged([FromQuery] FlightSearchRequest request, CancellationToken cancellationToken)
    {
        var response = await _flightAdminService.GetPagedAsync(request, cancellationToken);
        return Ok(response);
    }

    [HttpGet("{id:int}")]
    [ProducesResponseType(typeof(FlightDetailsDto), StatusCodes.Status200OK)]
    public async Task<ActionResult<FlightDetailsDto>> GetById(int id, CancellationToken cancellationToken)
    {
        var response = await _flightAdminService.GetByIdAsync(id, cancellationToken);
        return Ok(response);
    }

    [HttpPost]
    [ProducesResponseType(typeof(FlightDetailsDto), StatusCodes.Status200OK)]
    public async Task<ActionResult<FlightDetailsDto>> Create([FromBody] UpsertFlightRequest request, CancellationToken cancellationToken)
    {
        var response = await _flightAdminService.CreateAsync(request, cancellationToken);
        return Ok(response);
    }

    [HttpPut("{id:int}")]
    [ProducesResponseType(typeof(FlightDetailsDto), StatusCodes.Status200OK)]
    public async Task<ActionResult<FlightDetailsDto>> Update(int id, [FromBody] UpsertFlightRequest request, CancellationToken cancellationToken)
    {
        var response = await _flightAdminService.UpdateAsync(id, request, cancellationToken);
        return Ok(response);
    }

    [HttpDelete("{id:int}")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    public async Task<IActionResult> Delete(int id, CancellationToken cancellationToken)
    {
        await _flightAdminService.DeleteAsync(id, cancellationToken);
        return NoContent();
    }
}
