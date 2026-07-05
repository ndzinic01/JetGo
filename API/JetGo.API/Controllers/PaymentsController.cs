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
    public ContentResult PayPalReturn(
        [FromQuery] string? token,
        [FromQuery] string? payerId,
        [FromQuery] string? PayerID,
        [FromQuery] int? reservationId)
    {
        var payerValue = string.IsNullOrWhiteSpace(payerId) ? PayerID : payerId;
        var appReturnUrl = BuildJetGoAppLink("paypal-return", token, payerValue, reservationId);
        var html = """
            <!DOCTYPE html>
            <html lang="bs">
            <head>
                <meta charset="utf-8" />
                <title>JetGo PayPal povratak</title>
                <style>
                    body { font-family: Arial, sans-serif; padding: 32px; background: #f7fafc; color: #0f172a; }
                    .card { max-width: 720px; margin: 0 auto; background: white; border: 1px solid #dbe2ea; border-radius: 8px; padding: 24px; }
                    .actions { margin-top: 24px; display: flex; gap: 12px; flex-wrap: wrap; }
                    .button { display: inline-block; background: #0f766e; color: white; text-decoration: none; padding: 12px 18px; border-radius: 999px; font-weight: 700; }
                    .button.secondary { background: #e2e8f0; color: #0f172a; }
                    p.note { color: #475569; }
                    code { background: #f1f5f9; padding: 2px 6px; border-radius: 4px; }
                </style>
            </head>
            <body>
                <div class="card">
                    <h1>PayPal odobrenje je zaprimljeno</h1>
                    <p>Placanje je odobreno na PayPal strani i sada se mozete vratiti u JetGo aplikaciju.</p>
                    <p><strong>Order token:</strong> <code>__TOKEN__</code></p>
                    <p><strong>Payer ID:</strong> <code>__PAYER__</code></p>
                    <p class="note">Kada se vratite u aplikaciju, dovrsite posljednji korak potvrde placanja.</p>
                    <div class="actions">
                        <a class="button" href="__APP_RETURN_URL__">Vrati se u JetGo aplikaciju</a>
                        <a class="button secondary" href="javascript:history.back()">Nazad</a>
                    </div>
                </div>
            </body>
            </html>
            """
            .Replace("__TOKEN__", System.Net.WebUtility.HtmlEncode(token ?? string.Empty))
            .Replace("__PAYER__", System.Net.WebUtility.HtmlEncode(payerValue ?? string.Empty))
            .Replace("__APP_RETURN_URL__", System.Net.WebUtility.HtmlEncode(appReturnUrl));

        return Content(html, "text/html");
    }

    [AllowAnonymous]
    [HttpGet("paypal/cancel")]
    public ContentResult PayPalCancel([FromQuery] string? token, [FromQuery] int? reservationId)
    {
        var appCancelUrl = BuildJetGoAppLink("paypal-cancel", token, null, reservationId);
        var html = """
            <!DOCTYPE html>
            <html lang="bs">
            <head>
                <meta charset="utf-8" />
                <title>JetGo PayPal prekid</title>
                <style>
                    body { font-family: Arial, sans-serif; padding: 32px; background: #f7fafc; color: #0f172a; }
                    .card { max-width: 720px; margin: 0 auto; background: white; border: 1px solid #dbe2ea; border-radius: 8px; padding: 24px; }
                    .actions { margin-top: 24px; display: flex; gap: 12px; flex-wrap: wrap; }
                    .button { display: inline-block; background: #0f766e; color: white; text-decoration: none; padding: 12px 18px; border-radius: 999px; font-weight: 700; }
                    .button.secondary { background: #e2e8f0; color: #0f172a; }
                    code { background: #f1f5f9; padding: 2px 6px; border-radius: 4px; }
                </style>
            </head>
            <body>
                <div class="card">
                    <h1>PayPal placanje je prekinuto</h1>
                    <p>Korisnik je prekinuo PayPal korak prije zavrsetka odobrenja.</p>
                    <p><strong>Order token:</strong> <code>__TOKEN__</code></p>
                    <p>Možete se vratiti u JetGo i pokusati placanje ponovo.</p>
                    <div class="actions">
                        <a class="button" href="__APP_CANCEL_URL__">Vrati se u JetGo aplikaciju</a>
                        <a class="button secondary" href="javascript:history.back()">Nazad</a>
                    </div>
                </div>
            </body>
            </html>
            """
            .Replace("__TOKEN__", System.Net.WebUtility.HtmlEncode(token ?? string.Empty))
            .Replace("__APP_CANCEL_URL__", System.Net.WebUtility.HtmlEncode(appCancelUrl));

        return Content(html, "text/html");
    }

    private static string BuildJetGoAppLink(string host, string? token, string? payerId, int? reservationId)
    {
        var queryParameters = new List<string>();

        if (!string.IsNullOrWhiteSpace(token))
        {
            queryParameters.Add($"token={Uri.EscapeDataString(token)}");
        }

        if (!string.IsNullOrWhiteSpace(payerId))
        {
            queryParameters.Add($"payerId={Uri.EscapeDataString(payerId)}");
        }

        if (reservationId.HasValue)
        {
            queryParameters.Add($"reservationId={reservationId.Value}");
        }

        var query = queryParameters.Count > 0
            ? $"?{string.Join("&", queryParameters)}"
            : string.Empty;

        return $"jetgo://{host}{query}";
    }
}
