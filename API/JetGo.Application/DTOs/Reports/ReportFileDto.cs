namespace JetGo.Application.DTOs.Reports;

public sealed class ReportFileDto
{
    public string FileName { get; init; } = string.Empty;

    public string ContentType { get; init; } = "application/pdf";

    public byte[] Content { get; init; } = Array.Empty<byte>();
}
