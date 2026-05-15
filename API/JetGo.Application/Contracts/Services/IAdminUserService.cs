using JetGo.Application.DTOs.Common;
using JetGo.Application.DTOs.Users;
using JetGo.Application.Requests.Users;

namespace JetGo.Application.Contracts.Services;

public interface IAdminUserService
{
    Task<PagedResponseDto<AdminUserListItemDto>> GetPagedAsync(AdminUserSearchRequest request, CancellationToken cancellationToken = default);

    Task<AdminUserDetailsDto> GetByIdAsync(string userId, CancellationToken cancellationToken = default);

    Task<AdminUserDetailsDto> UpdateAsync(string userId, UpdateAdminUserRequest request, CancellationToken cancellationToken = default);

    Task<AdminUserDetailsDto> UpdateActivationAsync(string userId, UpdateAdminUserActivationRequest request, CancellationToken cancellationToken = default);

    Task ResetPasswordAsync(string userId, AdminResetUserPasswordRequest request, CancellationToken cancellationToken = default);
}
