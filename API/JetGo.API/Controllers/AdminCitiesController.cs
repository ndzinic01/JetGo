using JetGo.Application.Constants;
using JetGo.Application.Contracts.Services;
using JetGo.Application.DTOs.Cities;
using JetGo.Application.DTOs.Common;
using JetGo.Application.Requests.Cities;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace JetGo.API.Controllers;

[ApiController]
[Route("api/admin/cities")]
[Authorize(Roles = RoleNames.Admin)]
public sealed class AdminCitiesController : ControllerBase
{
    private readonly ICityAdminService _cityAdminService;

    public AdminCitiesController(ICityAdminService cityAdminService)
    {
        _cityAdminService = cityAdminService;
    }

    [HttpGet]
    [ProducesResponseType(typeof(PagedResponseDto<CityListItemDto>), StatusCodes.Status200OK)]
    public async Task<ActionResult<PagedResponseDto<CityListItemDto>>> GetPaged([FromQuery] CitySearchRequest request, CancellationToken cancellationToken)
    {
        var response = await _cityAdminService.GetPagedAsync(request, cancellationToken);
        return Ok(response);
    }

    [HttpGet("{id:int}")]
    [ProducesResponseType(typeof(CityDetailsDto), StatusCodes.Status200OK)]
    public async Task<ActionResult<CityDetailsDto>> GetById(int id, CancellationToken cancellationToken)
    {
        var response = await _cityAdminService.GetByIdAsync(id, cancellationToken);
        return Ok(response);
    }

    [HttpPost]
    [ProducesResponseType(typeof(CityDetailsDto), StatusCodes.Status200OK)]
    public async Task<ActionResult<CityDetailsDto>> Create([FromBody] UpsertCityRequest request, CancellationToken cancellationToken)
    {
        var response = await _cityAdminService.CreateAsync(request, cancellationToken);
        return Ok(response);
    }

    [HttpPut("{id:int}")]
    [ProducesResponseType(typeof(CityDetailsDto), StatusCodes.Status200OK)]
    public async Task<ActionResult<CityDetailsDto>> Update(int id, [FromBody] UpsertCityRequest request, CancellationToken cancellationToken)
    {
        var response = await _cityAdminService.UpdateAsync(id, request, cancellationToken);
        return Ok(response);
    }

    [HttpDelete("{id:int}")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    public async Task<IActionResult> Delete(int id, CancellationToken cancellationToken)
    {
        await _cityAdminService.DeleteAsync(id, cancellationToken);
        return NoContent();
    }
}
