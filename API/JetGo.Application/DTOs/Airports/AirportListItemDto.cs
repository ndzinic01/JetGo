namespace JetGo.Application.DTOs.Airports;

public sealed class AirportListItemDto
{
    public int Id { get; init; }

    public string Name { get; init; } = string.Empty;

    public string IataCode { get; init; } = string.Empty;

    public int CityId { get; init; }

    public string CityName { get; init; } = string.Empty;

    public int CountryId { get; init; }

    public string CountryName { get; init; } = string.Empty;

    public decimal? Latitude { get; init; }

    public decimal? Longitude { get; init; }

    public int RelatedDestinationsCount { get; init; }
}
