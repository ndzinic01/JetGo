using JetGo.Application.Constants;
using JetGo.Application.Contracts.Services;
using JetGo.Application.DTOs.Common;
using JetGo.Application.DTOs.Users;
using JetGo.Application.Requests.Users;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace JetGo.API.Controllers;

[ApiController]
[Route("api/admin/users")]
[Authorize(Roles = RoleNames.Admin)]
public sealed class AdminUsersController : ControllerBase
{
    private readonly IAdminUserService _adminUserService;

    public AdminUsersController(IAdminUserService adminUserService)
    {
        _adminUserService = adminUserService;
    }

    [HttpGet]
    [ProducesResponseType(typeof(PagedResponseDto<AdminUserListItemDto>), StatusCodes.Status200OK)]
    public async Task<ActionResult<PagedResponseDto<AdminUserListItemDto>>> GetPaged([FromQuery] AdminUserSearchRequest request, CancellationToken cancellationToken)
    {
        var response = await _adminUserService.GetPagedAsync(request, cancellationToken);
        return Ok(response);
    }

    [HttpGet("{userId}")]
    [ProducesResponseType(typeof(AdminUserDetailsDto), StatusCodes.Status200OK)]
    public async Task<ActionResult<AdminUserDetailsDto>> GetById(string userId, CancellationToken cancellationToken)
    {
        var response = await _adminUserService.GetByIdAsync(userId, cancellationToken);
        return Ok(response);
    }

    [HttpPut("{userId}")]
    [ProducesResponseType(typeof(AdminUserDetailsDto), StatusCodes.Status200OK)]
    public async Task<ActionResult<AdminUserDetailsDto>> Update(string userId, [FromBody] UpdateAdminUserRequest request, CancellationToken cancellationToken)
    {
        var response = await _adminUserService.UpdateAsync(userId, request, cancellationToken);
        return Ok(response);
    }

    [HttpPost("{userId}/activation")]
    [ProducesResponseType(typeof(AdminUserDetailsDto), StatusCodes.Status200OK)]
    public async Task<ActionResult<AdminUserDetailsDto>> UpdateActivation(string userId, [FromBody] UpdateAdminUserActivationRequest request, CancellationToken cancellationToken)
    {
        var response = await _adminUserService.UpdateActivationAsync(userId, request, cancellationToken);
        return Ok(response);
    }

    [HttpPost("{userId}/reset-password")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    public async Task<IActionResult> ResetPassword(string userId, [FromBody] AdminResetUserPasswordRequest request, CancellationToken cancellationToken)
    {
        await _adminUserService.ResetPasswordAsync(userId, request, cancellationToken);
        return NoContent();
    }
}
