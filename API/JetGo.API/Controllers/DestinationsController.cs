using JetGo.Application.Contracts.Services;
using JetGo.Application.DTOs.Common;
using JetGo.Application.DTOs.Destinations;
using JetGo.Application.Requests.Destinations;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace JetGo.API.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public sealed class DestinationsController : ControllerBase
{
    private readonly IDestinationService _destinationService;

    public DestinationsController(IDestinationService destinationService)
    {
        _destinationService = destinationService;
    }

    [HttpGet]
    [ProducesResponseType(typeof(PagedResponseDto<DestinationListItemDto>), StatusCodes.Status200OK)]
    public async Task<ActionResult<PagedResponseDto<DestinationListItemDto>>> Get([FromQuery] DestinationSearchRequest request, CancellationToken cancellationToken)
    {
        var response = await _destinationService.GetPagedAsync(request, cancellationToken);
        return Ok(response);
    }

    [HttpGet("{id:int}")]
    [ProducesResponseType(typeof(DestinationDetailsDto), StatusCodes.Status200OK)]
    public async Task<ActionResult<DestinationDetailsDto>> GetById(int id, CancellationToken cancellationToken)
    {
        var response = await _destinationService.GetByIdAsync(id, cancellationToken);
        return Ok(response);
    }
}
