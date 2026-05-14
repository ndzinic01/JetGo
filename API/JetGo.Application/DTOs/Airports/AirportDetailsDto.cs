namespace JetGo.Application.DTOs.Airports;

public sealed class AirportDetailsDto
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

    public int DepartureDestinationsCount { get; init; }

    public int ArrivalDestinationsCount { get; init; }

    public DateTime CreatedAtUtc { get; init; }

    public DateTime? UpdatedAtUtc { get; init; }
}
