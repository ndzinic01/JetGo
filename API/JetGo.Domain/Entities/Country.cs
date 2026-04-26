using JetGo.Domain.Common;

namespace JetGo.Domain.Entities;

public sealed class Country : AuditableEntity
{
    public string Name { get; set; } = string.Empty;

    public string IsoCode { get; set; } = string.Empty;

    public ICollection<City> Cities { get; set; } = new List<City>();
}
