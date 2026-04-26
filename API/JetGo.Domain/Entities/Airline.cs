using JetGo.Domain.Common;

namespace JetGo.Domain.Entities;

public sealed class Airline : AuditableEntity
{
    public string Name { get; set; } = string.Empty;

    public string Code { get; set; } = string.Empty;

    public string? LogoUrl { get; set; }

    public bool IsActive { get; set; } = true;

    public ICollection<Flight> Flights { get; set; } = new List<Flight>();
}
