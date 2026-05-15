using JetGo.Application.Constants;
using JetGo.Application.Contracts.Services;
using JetGo.Application.DTOs.Common;
using JetGo.Application.DTOs.Destinations;
using JetGo.Application.Requests.Destinations;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace JetGo.API.Controllers;

[ApiController]
[Route("api/admin/destinations")]
[Authorize(Roles = RoleNames.Admin)]
public sealed class AdminDestinationsController : ControllerBase
{
    private readonly IDestinationAdminService _destinationAdminService;

    public AdminDestinationsController(IDestinationAdminService destinationAdminService)
    {
        _destinationAdminService = destinationAdminService;
    }

    [HttpGet]
    [ProducesResponseType(typeof(PagedResponseDto<DestinationListItemDto>), StatusCodes.Status200OK)]
    public async Task<ActionResult<PagedResponseDto<DestinationListItemDto>>> GetPaged([FromQuery] DestinationSearchRequest request, CancellationToken cancellationToken)
    {
        var response = await _destinationAdminService.GetPagedAsync(request, cancellationToken);
        return Ok(response);
    }

    [HttpGet("{id:int}")]
    [ProducesResponseType(typeof(DestinationDetailsDto), StatusCodes.Status200OK)]
    public async Task<ActionResult<DestinationDetailsDto>> GetById(int id, CancellationToken cancellationToken)
    {
        var response = await _destinationAdminService.GetByIdAsync(id, cancellationToken);
        return Ok(response);
    }

    [HttpPost]
    [ProducesResponseType(typeof(DestinationDetailsDto), StatusCodes.Status200OK)]
    public async Task<ActionResult<DestinationDetailsDto>> Create([FromBody] UpsertDestinationRequest request, CancellationToken cancellationToken)
    {
        var response = await _destinationAdminService.CreateAsync(request, cancellationToken);
        return Ok(response);
    }

    [HttpPut("{id:int}")]
    [ProducesResponseType(typeof(DestinationDetailsDto), StatusCodes.Status200OK)]
    public async Task<ActionResult<DestinationDetailsDto>> Update(int id, [FromBody] UpsertDestinationRequest request, CancellationToken cancellationToken)
    {
        var response = await _destinationAdminService.UpdateAsync(id, request, cancellationToken);
        return Ok(response);
    }

    [HttpDelete("{id:int}")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    public async Task<IActionResult> Delete(int id, CancellationToken cancellationToken)
    {
        await _destinationAdminService.DeleteAsync(id, cancellationToken);
        return NoContent();
    }
}
