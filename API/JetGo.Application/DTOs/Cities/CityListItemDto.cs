namespace JetGo.Application.DTOs.Cities;

public sealed class CityListItemDto
{
    public int Id { get; init; }

    public string Name { get; init; } = string.Empty;

    public int CountryId { get; init; }

    public string CountryName { get; init; } = string.Empty;

    public string CountryIsoCode { get; init; } = string.Empty;

    public int AirportsCount { get; init; }
}
