using JetGo.Application.Constants;
using JetGo.Application.Contracts.Services;
using JetGo.Application.DTOs.Common;
using JetGo.Application.DTOs.Payments;
using JetGo.Application.Requests.Payments;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace JetGo.API.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public sealed class PaymentsController : ControllerBase
{
    private readonly IPaymentService _paymentService;

    public PaymentsController(IPaymentService paymentService)
    {
        _paymentService = paymentService;
    }

    [HttpPost("reservations/{reservationId:int}/initialize")]
    [ProducesResponseType(typeof(PaymentDetailsDto), StatusCodes.Status200OK)]
    public async Task<ActionResult<PaymentDetailsDto>> Initialize(int reservationId, CancellationToken cancellationToken)
    {
        var response = await _paymentService.InitializeAsync(reservationId, cancellationToken);
        return Ok(response);
    }

    [HttpGet("my")]
    [ProducesResponseType(typeof(PagedResponseDto<PaymentListItemDto>), StatusCodes.Status200OK)]
    public async Task<ActionResult<PagedResponseDto<PaymentListItemDto>>> GetMine([FromQuery] PaymentSearchRequest request, CancellationToken cancellationToken)
    {
        var response = await _paymentService.GetMineAsync(request, cancellationToken);
        return Ok(response);
    }

    [HttpGet]
    [Authorize(Roles = RoleNames.Admin)]
    [ProducesResponseType(typeof(PagedResponseDto<PaymentListItemDto>), StatusCodes.Status200OK)]
    public async Task<ActionResult<PagedResponseDto<PaymentListItemDto>>> GetAdmin([FromQuery] PaymentSearchRequest request, CancellationToken cancellationToken)
    {
        var response = await _paymentService.GetAdminPagedAsync(request, cancellationToken);
        return Ok(response);
    }

    [HttpGet("{id:int}")]
    [ProducesResponseType(typeof(PaymentDetailsDto), StatusCodes.Status200OK)]
    public async Task<ActionResult<PaymentDetailsDto>> GetById(int id, CancellationToken cancellationToken)
    {
        var response = await _paymentService.GetByIdAsync(id, cancellationToken);
        return Ok(response);
    }

    [HttpPost("{id:int}/confirm")]
    [Authorize(Roles = RoleNames.Admin)]
    [ProducesResponseType(typeof(PaymentDetailsDto), StatusCodes.Status200OK)]
    public async Task<ActionResult<PaymentDetailsDto>> Confirm(int id, [FromBody] ConfirmPaymentRequest request, CancellationToken cancellationToken)
    {
        var response = await _paymentService.ConfirmAsync(id, request, cancellationToken);
        return Ok(response);
    }

    [HttpPost("{id:int}/refund")]
    [Authorize(Roles = RoleNames.Admin)]
    [ProducesResponseType(typeof(PaymentDetailsDto), StatusCodes.Status200OK)]
    public async Task<ActionResult<PaymentDetailsDto>> Refund(int id, [FromBody] RefundPaymentRequest request, CancellationToken cancellationToken)
    {
        var response = await _paymentService.RefundAsync(id, request, cancellationToken);
        return Ok(response);
    }
}
