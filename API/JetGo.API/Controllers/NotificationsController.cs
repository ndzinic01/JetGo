using JetGo.Application.Contracts.Services;
using JetGo.Application.DTOs.Common;
using JetGo.Application.DTOs.Notifications;
using JetGo.Application.Requests.Notifications;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace JetGo.API.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public sealed class NotificationsController : ControllerBase
{
    private readonly INotificationService _notificationService;

    public NotificationsController(INotificationService notificationService)
    {
        _notificationService = notificationService;
    }

    [HttpGet]
    [ProducesResponseType(typeof(PagedResponseDto<NotificationListItemDto>), StatusCodes.Status200OK)]
    public async Task<ActionResult<PagedResponseDto<NotificationListItemDto>>> Get([FromQuery] NotificationSearchRequest request, CancellationToken cancellationToken)
    {
        var response = await _notificationService.GetMineAsync(request, cancellationToken);
        return Ok(response);
    }

    [HttpGet("summary")]
    [ProducesResponseType(typeof(NotificationSummaryDto), StatusCodes.Status200OK)]
    public async Task<ActionResult<NotificationSummaryDto>> GetSummary(CancellationToken cancellationToken)
    {
        var response = await _notificationService.GetSummaryAsync(cancellationToken);
        return Ok(response);
    }

    [HttpPost("{id:int}/read")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    public async Task<IActionResult> MarkAsRead(int id, CancellationToken cancellationToken)
    {
        await _notificationService.MarkAsReadAsync(id, cancellationToken);
        return NoContent();
    }

    [HttpPost("read-all")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    public async Task<IActionResult> MarkAllAsRead(CancellationToken cancellationToken)
    {
        await _notificationService.MarkAllAsReadAsync(cancellationToken);
        return NoContent();
    }
}
