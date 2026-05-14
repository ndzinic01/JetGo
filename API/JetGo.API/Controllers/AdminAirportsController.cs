using JetGo.Application.Constants;
using JetGo.Application.Contracts.Services;
using JetGo.Application.DTOs.Airports;
using JetGo.Application.DTOs.Common;
using JetGo.Application.Requests.Airports;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace JetGo.API.Controllers;

[ApiController]
[Route("api/admin/airports")]
[Authorize(Roles = RoleNames.Admin)]
public sealed class AdminAirportsController : ControllerBase
{
    private readonly IAirportAdminService _airportAdminService;

    public AdminAirportsController(IAirportAdminService airportAdminService)
    {
        _airportAdminService = airportAdminService;
    }

    [HttpGet]
    [ProducesResponseType(typeof(PagedResponseDto<AirportListItemDto>), StatusCodes.Status200OK)]
    public async Task<ActionResult<PagedResponseDto<AirportListItemDto>>> GetPaged([FromQuery] AirportSearchRequest request, CancellationToken cancellationToken)
    {
        var response = await _airportAdminService.GetPagedAsync(request, cancellationToken);
        return Ok(response);
    }

    [HttpGet("{id:int}")]
    [ProducesResponseType(typeof(AirportDetailsDto), StatusCodes.Status200OK)]
    public async Task<ActionResult<AirportDetailsDto>> GetById(int id, CancellationToken cancellationToken)
    {
        var response = await _airportAdminService.GetByIdAsync(id, cancellationToken);
        return Ok(response);
    }

    [HttpPost]
    [ProducesResponseType(typeof(AirportDetailsDto), StatusCodes.Status200OK)]
    public async Task<ActionResult<AirportDetailsDto>> Create([FromBody] UpsertAirportRequest request, CancellationToken cancellationToken)
    {
        var response = await _airportAdminService.CreateAsync(request, cancellationToken);
        return Ok(response);
    }

    [HttpPut("{id:int}")]
    [ProducesResponseType(typeof(AirportDetailsDto), StatusCodes.Status200OK)]
    public async Task<ActionResult<AirportDetailsDto>> Update(int id, [FromBody] UpsertAirportRequest request, CancellationToken cancellationToken)
    {
        var response = await _airportAdminService.UpdateAsync(id, request, cancellationToken);
        return Ok(response);
    }

    [HttpDelete("{id:int}")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    public async Task<IActionResult> Delete(int id, CancellationToken cancellationToken)
    {
        await _airportAdminService.DeleteAsync(id, cancellationToken);
        return NoContent();
    }
}
