using JetGo.Application.Constants;
using JetGo.Application.Contracts.Services;
using JetGo.Application.DTOs.Airlines;
using JetGo.Application.DTOs.Common;
using JetGo.Application.Requests.Airlines;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace JetGo.API.Controllers;

[ApiController]
[Route("api/admin/airlines")]
[Authorize(Roles = RoleNames.Admin)]
public sealed class AdminAirlinesController : ControllerBase
{
    private readonly IAirlineAdminService _airlineAdminService;

    public AdminAirlinesController(IAirlineAdminService airlineAdminService)
    {
        _airlineAdminService = airlineAdminService;
    }

    [HttpGet]
    [ProducesResponseType(typeof(PagedResponseDto<AirlineListItemDto>), StatusCodes.Status200OK)]
    public async Task<ActionResult<PagedResponseDto<AirlineListItemDto>>> GetPaged([FromQuery] AirlineSearchRequest request, CancellationToken cancellationToken)
    {
        var response = await _airlineAdminService.GetPagedAsync(request, cancellationToken);
        return Ok(response);
    }

    [HttpGet("{id:int}")]
    [ProducesResponseType(typeof(AirlineDetailsDto), StatusCodes.Status200OK)]
    public async Task<ActionResult<AirlineDetailsDto>> GetById(int id, CancellationToken cancellationToken)
    {
        var response = await _airlineAdminService.GetByIdAsync(id, cancellationToken);
        return Ok(response);
    }

    [HttpPost]
    [ProducesResponseType(typeof(AirlineDetailsDto), StatusCodes.Status200OK)]
    public async Task<ActionResult<AirlineDetailsDto>> Create([FromBody] UpsertAirlineRequest request, CancellationToken cancellationToken)
    {
        var response = await _airlineAdminService.CreateAsync(request, cancellationToken);
        return Ok(response);
    }

    [HttpPut("{id:int}")]
    [ProducesResponseType(typeof(AirlineDetailsDto), StatusCodes.Status200OK)]
    public async Task<ActionResult<AirlineDetailsDto>> Update(int id, [FromBody] UpsertAirlineRequest request, CancellationToken cancellationToken)
    {
        var response = await _airlineAdminService.UpdateAsync(id, request, cancellationToken);
        return Ok(response);
    }

    [HttpDelete("{id:int}")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    public async Task<IActionResult> Delete(int id, CancellationToken cancellationToken)
    {
        await _airlineAdminService.DeleteAsync(id, cancellationToken);
        return NoContent();
    }
}
