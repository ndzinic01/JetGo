using JetGo.Application.DTOs.Reports;
using JetGo.Application.Requests.Reports;

namespace JetGo.Application.Contracts.Services;

public interface IReportService
{
    Task<ReportFileDto> GenerateSalesReportAsync(
        ReportPeriodRequest request,
        CancellationToken cancellationToken = default);

    Task<ReportFileDto> GenerateOccupancyReportAsync(
        ReportPeriodRequest request,
        CancellationToken cancellationToken = default);

    Task<ReportFileDto> GenerateFinancialReportAsync(
        ReportPeriodRequest request,
        CancellationToken cancellationToken = default);

    Task<ReportFileDto> GenerateUsersReportAsync(
        ReportPeriodRequest request,
        CancellationToken cancellationToken = default);

    Task<ReportFileDto> GenerateReservationsReportAsync(
        ReservationReportRequest request,
        CancellationToken cancellationToken = default);

    Task<ReportFileDto> GeneratePaymentsReportAsync(
        PaymentReportRequest request,
        CancellationToken cancellationToken = default);
}
