using JetGo.Application.Constants;
using JetGo.Application.Contracts.Services;
using JetGo.Application.DTOs.Common;
using JetGo.Application.DTOs.Reservations;
using JetGo.Application.Requests.Reservations;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace JetGo.API.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public sealed class ReservationsController : ControllerBase
{
    private readonly IReservationService _reservationService;

    public ReservationsController(IReservationService reservationService)
    {
        _reservationService = reservationService;
    }

    [HttpPost]
    [ProducesResponseType(typeof(ReservationDetailsDto), StatusCodes.Status200OK)]
    public async Task<ActionResult<ReservationDetailsDto>> Create([FromBody] CreateReservationRequest request, CancellationToken cancellationToken)
    {
        var response = await _reservationService.CreateAsync(request, cancellationToken);
        return Ok(response);
    }

    [HttpGet("my")]
    [ProducesResponseType(typeof(PagedResponseDto<ReservationListItemDto>), StatusCodes.Status200OK)]
    public async Task<ActionResult<PagedResponseDto<ReservationListItemDto>>> GetMine([FromQuery] ReservationSearchRequest request, CancellationToken cancellationToken)
    {
        var response = await _reservationService.GetMineAsync(request, cancellationToken);
        return Ok(response);
    }

    [HttpGet]
    [Authorize(Roles = RoleNames.Admin)]
    [ProducesResponseType(typeof(PagedResponseDto<ReservationListItemDto>), StatusCodes.Status200OK)]
    public async Task<ActionResult<PagedResponseDto<ReservationListItemDto>>> GetAll([FromQuery] ReservationSearchRequest request, CancellationToken cancellationToken)
    {
        var response = await _reservationService.GetAdminPagedAsync(request, cancellationToken);
        return Ok(response);
    }

    [HttpGet("{id:int}")]
    [ProducesResponseType(typeof(ReservationDetailsDto), StatusCodes.Status200OK)]
    public async Task<ActionResult<ReservationDetailsDto>> GetById(int id, CancellationToken cancellationToken)
    {
        var response = await _reservationService.GetByIdAsync(id, cancellationToken);
        return Ok(response);
    }

    [HttpPost("{id:int}/confirm")]
    [Authorize(Roles = RoleNames.Admin)]
    [ProducesResponseType(typeof(ReservationDetailsDto), StatusCodes.Status200OK)]
    public async Task<ActionResult<ReservationDetailsDto>> Confirm(int id, [FromBody] UpdateReservationStatusRequest request, CancellationToken cancellationToken)
    {
        var response = await _reservationService.ConfirmAsync(id, request, cancellationToken);
        return Ok(response);
    }

    [HttpPost("{id:int}/cancel")]
    [ProducesResponseType(typeof(ReservationDetailsDto), StatusCodes.Status200OK)]
    public async Task<ActionResult<ReservationDetailsDto>> Cancel(int id, [FromBody] UpdateReservationStatusRequest request, CancellationToken cancellationToken)
    {
        var response = await _reservationService.CancelAsync(id, request, cancellationToken);
        return Ok(response);
    }

    [HttpPost("{id:int}/complete")]
    [Authorize(Roles = RoleNames.Admin)]
    [ProducesResponseType(typeof(ReservationDetailsDto), StatusCodes.Status200OK)]
    public async Task<ActionResult<ReservationDetailsDto>> Complete(int id, [FromBody] UpdateReservationStatusRequest request, CancellationToken cancellationToken)
    {
        var response = await _reservationService.CompleteAsync(id, request, cancellationToken);
        return Ok(response);
    }
}
