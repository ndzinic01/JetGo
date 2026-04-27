namespace JetGo.Application.DTOs.Common;

public sealed class AirportSummaryDto
{
    public int Id { get; init; }

    public string Name { get; init; } = string.Empty;

    public string IataCode { get; init; } = string.Empty;

    public string CityName { get; init; } = string.Empty;

    public string CountryName { get; init; } = string.Empty;
}
