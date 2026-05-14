using JetGo.Application.Constants;
using JetGo.Application.Contracts.Services;
using JetGo.Application.DTOs.Common;
using JetGo.Application.DTOs.Countries;
using JetGo.Application.Requests.Countries;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace JetGo.API.Controllers;

[ApiController]
[Route("api/admin/countries")]
[Authorize(Roles = RoleNames.Admin)]
public sealed class AdminCountriesController : ControllerBase
{
    private readonly ICountryAdminService _countryAdminService;

    public AdminCountriesController(ICountryAdminService countryAdminService)
    {
        _countryAdminService = countryAdminService;
    }

    [HttpGet]
    [ProducesResponseType(typeof(PagedResponseDto<CountryListItemDto>), StatusCodes.Status200OK)]
    public async Task<ActionResult<PagedResponseDto<CountryListItemDto>>> GetPaged([FromQuery] CountrySearchRequest request, CancellationToken cancellationToken)
    {
        var response = await _countryAdminService.GetPagedAsync(request, cancellationToken);
        return Ok(response);
    }

    [HttpGet("{id:int}")]
    [ProducesResponseType(typeof(CountryDetailsDto), StatusCodes.Status200OK)]
    public async Task<ActionResult<CountryDetailsDto>> GetById(int id, CancellationToken cancellationToken)
    {
        var response = await _countryAdminService.GetByIdAsync(id, cancellationToken);
        return Ok(response);
    }

    [HttpPost]
    [ProducesResponseType(typeof(CountryDetailsDto), StatusCodes.Status200OK)]
    public async Task<ActionResult<CountryDetailsDto>> Create([FromBody] UpsertCountryRequest request, CancellationToken cancellationToken)
    {
        var response = await _countryAdminService.CreateAsync(request, cancellationToken);
        return Ok(response);
    }

    [HttpPut("{id:int}")]
    [ProducesResponseType(typeof(CountryDetailsDto), StatusCodes.Status200OK)]
    public async Task<ActionResult<CountryDetailsDto>> Update(int id, [FromBody] UpsertCountryRequest request, CancellationToken cancellationToken)
    {
        var response = await _countryAdminService.UpdateAsync(id, request, cancellationToken);
        return Ok(response);
    }

    [HttpDelete("{id:int}")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    public async Task<IActionResult> Delete(int id, CancellationToken cancellationToken)
    {
        await _countryAdminService.DeleteAsync(id, cancellationToken);
        return NoContent();
    }
}
