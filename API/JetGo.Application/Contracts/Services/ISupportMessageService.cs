using JetGo.Application.DTOs.Common;
using JetGo.Application.DTOs.SupportMessages;
using JetGo.Application.Requests.SupportMessages;

namespace JetGo.Application.Contracts.Services;

public interface ISupportMessageService
{
    Task<SupportMessageDetailsDto> CreateAsync(CreateSupportMessageRequest request, CancellationToken cancellationToken = default);

    Task<PagedResponseDto<SupportMessageListItemDto>> GetMineAsync(SupportMessageSearchRequest request, CancellationToken cancellationToken = default);

    Task<PagedResponseDto<SupportMessageListItemDto>> GetAdminPagedAsync(SupportMessageSearchRequest request, CancellationToken cancellationToken = default);

    Task<SupportMessageDetailsDto> GetByIdAsync(int id, CancellationToken cancellationToken = default);

    Task<SupportMessageDetailsDto> ReplyAsync(int id, ReplyToSupportMessageRequest request, CancellationToken cancellationToken = default);
}
