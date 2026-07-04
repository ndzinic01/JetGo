using JetGo.Application.DTOs.AdminDashboard;

namespace JetGo.Application.Contracts.Services;

public interface IAdminDashboardService
{
    Task<AdminDashboardSummaryDto> GetSummaryAsync(CancellationToken cancellationToken = default);
}
