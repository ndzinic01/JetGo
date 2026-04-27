using JetGo.Application.Constants;
using JetGo.Application.Contracts.Services;
using JetGo.Application.DTOs.Common;
using JetGo.Application.DTOs.News;
using JetGo.Application.Requests.News;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace JetGo.API.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public sealed class NewsController : ControllerBase
{
    private readonly INewsService _newsService;

    public NewsController(INewsService newsService)
    {
        _newsService = newsService;
    }

    [HttpGet]
    [ProducesResponseType(typeof(PagedResponseDto<NewsArticleListItemDto>), StatusCodes.Status200OK)]
    public async Task<ActionResult<PagedResponseDto<NewsArticleListItemDto>>> GetPublished([FromQuery] NewsSearchRequest request, CancellationToken cancellationToken)
    {
        var response = await _newsService.GetPublishedPagedAsync(request, cancellationToken);
        return Ok(response);
    }

    [HttpGet("admin")]
    [Authorize(Roles = RoleNames.Admin)]
    [ProducesResponseType(typeof(PagedResponseDto<NewsArticleListItemDto>), StatusCodes.Status200OK)]
    public async Task<ActionResult<PagedResponseDto<NewsArticleListItemDto>>> GetAdmin([FromQuery] NewsSearchRequest request, CancellationToken cancellationToken)
    {
        var response = await _newsService.GetAdminPagedAsync(request, cancellationToken);
        return Ok(response);
    }

    [HttpGet("{id:int}")]
    [ProducesResponseType(typeof(NewsArticleDetailsDto), StatusCodes.Status200OK)]
    public async Task<ActionResult<NewsArticleDetailsDto>> GetById(int id, CancellationToken cancellationToken)
    {
        var response = await _newsService.GetByIdAsync(id, User.IsInRole(RoleNames.Admin), cancellationToken);
        return Ok(response);
    }

    [HttpPost]
    [Authorize(Roles = RoleNames.Admin)]
    [ProducesResponseType(typeof(NewsArticleDetailsDto), StatusCodes.Status200OK)]
    public async Task<ActionResult<NewsArticleDetailsDto>> Create([FromBody] UpsertNewsArticleRequest request, CancellationToken cancellationToken)
    {
        var response = await _newsService.CreateAsync(request, cancellationToken);
        return Ok(response);
    }

    [HttpPut("{id:int}")]
    [Authorize(Roles = RoleNames.Admin)]
    [ProducesResponseType(typeof(NewsArticleDetailsDto), StatusCodes.Status200OK)]
    public async Task<ActionResult<NewsArticleDetailsDto>> Update(int id, [FromBody] UpsertNewsArticleRequest request, CancellationToken cancellationToken)
    {
        var response = await _newsService.UpdateAsync(id, request, cancellationToken);
        return Ok(response);
    }
}
