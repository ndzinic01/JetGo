using JetGo.Application.Constants;
using JetGo.Application.Contracts.Services;
using JetGo.Application.Requests.Reports;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace JetGo.API.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize(Roles = RoleNames.Admin)]
public sealed class ReportsController : ControllerBase
{
    private readonly IReportService _reportService;

    public ReportsController(IReportService reportService)
    {
        _reportService = reportService;
    }

    [HttpGet("reservations.pdf")]
    [Produces("application/pdf")]
    public async Task<IActionResult> GetReservationsReport(
        [FromQuery] ReservationReportRequest request,
        CancellationToken cancellationToken)
    {
        var report = await _reportService.GenerateReservationsReportAsync(request, cancellationToken);
        return File(report.Content, report.ContentType, report.FileName);
    }

    [HttpGet("payments.pdf")]
    [Produces("application/pdf")]
    public async Task<IActionResult> GetPaymentsReport(
        [FromQuery] PaymentReportRequest request,
        CancellationToken cancellationToken)
    {
        var report = await _reportService.GeneratePaymentsReportAsync(request, cancellationToken);
        return File(report.Content, report.ContentType, report.FileName);
    }
}
