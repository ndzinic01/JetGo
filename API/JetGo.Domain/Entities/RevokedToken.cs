using JetGo.Domain.Common;

namespace JetGo.Domain.Entities;

public sealed class RevokedToken : AuditableEntity
{
    public string JwtId { get; set; } = string.Empty;

    public string UserId { get; set; } = string.Empty;

    public DateTime ExpiresAtUtc { get; set; }

    public string? Reason { get; set; }
}
