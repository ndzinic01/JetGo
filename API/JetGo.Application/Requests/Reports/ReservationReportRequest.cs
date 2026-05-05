using JetGo.Domain.Enums;

namespace JetGo.Application.Requests.Reports;

public sealed class ReservationReportRequest
{
    public ReservationStatus? Status { get; init; }

    public DateTime? CreatedFromUtc { get; init; }

    public DateTime? CreatedToUtc { get; init; }
}
