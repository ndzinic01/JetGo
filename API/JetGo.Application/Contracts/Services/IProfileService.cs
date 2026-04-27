using JetGo.Application.DTOs.Profile;
using JetGo.Application.Requests.Profile;

namespace JetGo.Application.Contracts.Services;

public interface IProfileService
{
    Task<ProfileDto> GetMyProfileAsync(CancellationToken cancellationToken = default);

    Task<ProfileDto> UpdateMyProfileAsync(UpdateMyProfileRequest request, CancellationToken cancellationToken = default);

    Task ChangePasswordAsync(ChangePasswordRequest request, CancellationToken cancellationToken = default);
}
