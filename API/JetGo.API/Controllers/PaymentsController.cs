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

    [HttpGet("{id:int}/debug-paypal")]
    [Authorize(Roles = RoleNames.Admin)]
    [ProducesResponseType(typeof(PayPalPaymentDebugDto), StatusCodes.Status200OK)]
    public async Task<ActionResult<PayPalPaymentDebugDto>> DebugPayPal(
        int id,
        [FromQuery] string? callbackToken,
        CancellationToken cancellationToken)
    {
        var response = await _paymentService.GetPayPalDebugSnapshotAsync(id, callbackToken, cancellationToken);
        return Ok(response);
    }

    [HttpPost("{id:int}/confirm")]
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

    [AllowAnonymous]
    [HttpGet("paypal/return")]
    public ContentResult PayPalReturn([FromQuery] string? token, [FromQuery] string? payerId, [FromQuery] string? PayerID)
    {
        var payerValue = string.IsNullOrWhiteSpace(payerId) ? PayerID : payerId;
        var html = """
            <!DOCTYPE html>
            <html lang="en">
            <head>
                <meta charset="utf-8" />
                <title>JetGo PayPal Return</title>
                <style>
                    body { font-family: Arial, sans-serif; padding: 32px; background: #f7fafc; color: #0f172a; }
                    .card { max-width: 720px; margin: 0 auto; background: white; border: 1px solid #dbe2ea; border-radius: 8px; padding: 24px; }
                    code { background: #f1f5f9; padding: 2px 6px; border-radius: 4px; }
                </style>
            </head>
            <body>
                <div class="card">
                    <h1>PayPal approval received</h1>
                    <p>The buyer approval flow returned to JetGo.</p>
                    <p><strong>Order token:</strong> <code>__TOKEN__</code></p>
                    <p><strong>Payer ID:</strong> <code>__PAYER__</code></p>
                    <p>Return to Swagger or the mobile app and call the payment confirm endpoint for this payment.</p>
                </div>
            </body>
            </html>
            """
            .Replace("__TOKEN__", System.Net.WebUtility.HtmlEncode(token ?? string.Empty))
            .Replace("__PAYER__", System.Net.WebUtility.HtmlEncode(payerValue ?? string.Empty));

        return Content(html, "text/html");
    }

    [AllowAnonymous]
    [HttpGet("paypal/cancel")]
    public ContentResult PayPalCancel([FromQuery] string? token)
    {
        var html = """
            <!DOCTYPE html>
            <html lang="en">
            <head>
                <meta charset="utf-8" />
                <title>JetGo PayPal Cancel</title>
                <style>
                    body { font-family: Arial, sans-serif; padding: 32px; background: #f7fafc; color: #0f172a; }
                    .card { max-width: 720px; margin: 0 auto; background: white; border: 1px solid #dbe2ea; border-radius: 8px; padding: 24px; }
                    code { background: #f1f5f9; padding: 2px 6px; border-radius: 4px; }
                </style>
            </head>
            <body>
                <div class="card">
                    <h1>PayPal approval cancelled</h1>
                    <p>The buyer cancelled the PayPal flow before approval was completed.</p>
                    <p><strong>Order token:</strong> <code>__TOKEN__</code></p>
                    <p>You can return to JetGo and try the payment again.</p>
                </div>
            </body>
            </html>
            """
            .Replace("__TOKEN__", System.Net.WebUtility.HtmlEncode(token ?? string.Empty));

        return Content(html, "text/html");
    }
}
