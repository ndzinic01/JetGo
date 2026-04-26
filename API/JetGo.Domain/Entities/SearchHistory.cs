using JetGo.Domain.Common;

namespace JetGo.Domain.Entities;

public sealed class SearchHistory : AuditableEntity
{
    public string UserId { get; set; } = string.Empty;

    public string SearchTerm { get; set; } = string.Empty;

    public int? DestinationId { get; set; }

    public Destination? Destination { get; set; }
}
