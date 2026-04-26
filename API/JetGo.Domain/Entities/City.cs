using JetGo.Domain.Common;

namespace JetGo.Domain.Entities;

public sealed class City : AuditableEntity
{

    public int CountryId { get; set; }

    public Country Country { get; set; } = null!;

    public string Name { get; set; } = string.Empty;

    public ICollection<Airport> Airports { get; set; } = new List<Airport>();
}
