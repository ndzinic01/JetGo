using JetGo.Application.Constants;
using JetGo.Application.Contracts.Services;
using JetGo.Application.DTOs.Common;
using JetGo.Application.DTOs.SupportMessages;
using JetGo.Application.Requests.SupportMessages;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace JetGo.API.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public sealed class SupportMessagesController : ControllerBase
{
    private readonly ISupportMessageService _supportMessageService;

    public SupportMessagesController(ISupportMessageService supportMessageService)
    {
        _supportMessageService = supportMessageService;
    }

    [HttpPost]
    [ProducesResponseType(typeof(SupportMessageDetailsDto), StatusCodes.Status200OK)]
    public async Task<ActionResult<SupportMessageDetailsDto>> Create([FromBody] CreateSupportMessageRequest request, CancellationToken cancellationToken)
    {
        var response = await _supportMessageService.CreateAsync(request, cancellationToken);
        return Ok(response);
    }

    [HttpGet("my")]
    [ProducesResponseType(typeof(PagedResponseDto<SupportMessageListItemDto>), StatusCodes.Status200OK)]
    public async Task<ActionResult<PagedResponseDto<SupportMessageListItemDto>>> GetMine([FromQuery] SupportMessageSearchRequest request, CancellationToken cancellationToken)
    {
        var response = await _supportMessageService.GetMineAsync(request, cancellationToken);
        return Ok(response);
    }

    [HttpGet]
    [Authorize(Roles = RoleNames.Admin)]
    [ProducesResponseType(typeof(PagedResponseDto<SupportMessageListItemDto>), StatusCodes.Status200OK)]
    public async Task<ActionResult<PagedResponseDto<SupportMessageListItemDto>>> GetAdmin([FromQuery] SupportMessageSearchRequest request, CancellationToken cancellationToken)
    {
        var response = await _supportMessageService.GetAdminPagedAsync(request, cancellationToken);
        return Ok(response);
    }

    [HttpGet("{id:int}")]
    [ProducesResponseType(typeof(SupportMessageDetailsDto), StatusCodes.Status200OK)]
    public async Task<ActionResult<SupportMessageDetailsDto>> GetById(int id, CancellationToken cancellationToken)
    {
        var response = await _supportMessageService.GetByIdAsync(id, cancellationToken);
        return Ok(response);
    }

    [HttpPost("{id:int}/reply")]
    [Authorize(Roles = RoleNames.Admin)]
    [ProducesResponseType(typeof(SupportMessageDetailsDto), StatusCodes.Status200OK)]
    public async Task<ActionResult<SupportMessageDetailsDto>> Reply(int id, [FromBody] ReplyToSupportMessageRequest request, CancellationToken cancellationToken)
    {
        var response = await _supportMessageService.ReplyAsync(id, request, cancellationToken);
        return Ok(response);
    }
}
