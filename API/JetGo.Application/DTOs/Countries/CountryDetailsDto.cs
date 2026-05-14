namespace JetGo.Application.DTOs.Countries;

public sealed class CountryDetailsDto
{
    public int Id { get; init; }

    public string Name { get; init; } = string.Empty;

    public string IsoCode { get; init; } = string.Empty;

    public int CitiesCount { get; init; }

    public DateTime CreatedAtUtc { get; init; }

    public DateTime? UpdatedAtUtc { get; init; }
}
