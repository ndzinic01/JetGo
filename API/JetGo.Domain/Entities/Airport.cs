using JetGo.Domain.Common;

namespace JetGo.Domain.Entities;

public sealed class Airport : AuditableEntity
{
    public int CityId { get; set; }

    public City City { get; set; } = null!;

    public string Name { get; set; } = string.Empty;

    public string IataCode { get; set; } = string.Empty;

    public decimal? Latitude { get; set; }

    public decimal? Longitude { get; set; }

    public ICollection<Destination> DepartureDestinations { get; set; } = new List<Destination>();

    public ICollection<Destination> ArrivalDestinations { get; set; } = new List<Destination>();
}
