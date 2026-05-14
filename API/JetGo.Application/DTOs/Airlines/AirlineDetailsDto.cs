namespace JetGo.Application.DTOs.Airlines;

public sealed class AirlineDetailsDto
{
    public int Id { get; init; }

    public string Name { get; init; } = string.Empty;

    public string Code { get; init; } = string.Empty;

    public string? LogoUrl { get; init; }

    public bool IsActive { get; init; }

    public int FlightsCount { get; init; }

    public DateTime CreatedAtUtc { get; init; }

    public DateTime? UpdatedAtUtc { get; init; }
}
