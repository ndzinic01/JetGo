namespace JetGo.Application.DTOs.Common;

public sealed class AirlineSummaryDto
{
    public int Id { get; init; }

    public string Name { get; init; } = string.Empty;

    public string Code { get; init; } = string.Empty;

    public string? LogoUrl { get; init; }
}
