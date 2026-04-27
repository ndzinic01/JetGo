using JetGo.Application.DTOs.Common;
using JetGo.Application.DTOs.Notifications;
using JetGo.Application.Requests.Notifications;

namespace JetGo.Application.Contracts.Services;

public interface INotificationService
{
    Task<PagedResponseDto<NotificationListItemDto>> GetMineAsync(NotificationSearchRequest request, CancellationToken cancellationToken = default);

    Task<NotificationSummaryDto> GetSummaryAsync(CancellationToken cancellationToken = default);

    Task MarkAsReadAsync(int id, CancellationToken cancellationToken = default);

    Task MarkAllAsReadAsync(CancellationToken cancellationToken = default);
}
