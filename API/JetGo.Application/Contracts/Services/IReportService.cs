using JetGo.Application.DTOs.Reports;
using JetGo.Application.Requests.Reports;

namespace JetGo.Application.Contracts.Services;

public interface IReportService
{
    Task<ReportFileDto> GenerateReservationsReportAsync(
        ReservationReportRequest request,
        CancellationToken cancellationToken = default);

    Task<ReportFileDto> GeneratePaymentsReportAsync(
        PaymentReportRequest request,
        CancellationToken cancellationToken = default);
}
