using JetGo.Application.DTOs.Auth;
using JetGo.Application.Requests.Auth;

namespace JetGo.Application.Contracts.Services;

public interface IAuthService
{
    Task<AuthResponseDto> LoginAsync(LoginRequest request, CancellationToken cancellationToken = default);

    Task<AuthResponseDto> RegisterAsync(RegisterRequest request, CancellationToken cancellationToken = default);

    Task LogoutAsync(CancellationToken cancellationToken = default);

    Task<AuthenticatedUserDto> GetCurrentUserAsync(CancellationToken cancellationToken = default);

    Task<PasswordResetResponseDto> RequestPasswordResetAsync(RequestPasswordResetRequest request, CancellationToken cancellationToken = default);

    Task ResetPasswordAsync(ResetPasswordRequest request, CancellationToken cancellationToken = default);
}
