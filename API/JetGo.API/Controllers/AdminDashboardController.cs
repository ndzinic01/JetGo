using JetGo.Application.Constants;
using JetGo.Application.Contracts.Services;
using JetGo.Application.DTOs.AdminDashboard;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace JetGo.API.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize(Roles = RoleNames.Admin)]
public sealed class AdminDashboardController : ControllerBase
{
    private readonly IAdminDashboardService _adminDashboardService;

    public AdminDashboardController(IAdminDashboardService adminDashboardService)
    {
        _adminDashboardService = adminDashboardService;
    }

    [HttpGet("summary")]
    [ProducesResponseType(typeof(AdminDashboardSummaryDto), StatusCodes.Status200OK)]
    public async Task<ActionResult<AdminDashboardSummaryDto>> GetSummary(CancellationToken cancellationToken)
    {
        var response = await _adminDashboardService.GetSummaryAsync(cancellationToken);
        return Ok(response);
    }
}
