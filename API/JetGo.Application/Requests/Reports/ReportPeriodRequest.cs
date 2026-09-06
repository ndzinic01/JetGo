namespace JetGo.Application.Requests.Reports;

public sealed class ReportPeriodRequest
{
    public DateTime? FromUtc { get; init; }

    public DateTime? ToUtc { get; init; }
}
