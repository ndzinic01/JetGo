using JetGo.Domain.Common;

namespace JetGo.Domain.Entities;

public sealed class RefreshToken : AuditableEntity
{
    public string UserId { get; set; } = string.Empty;

    public string Token { get; set; } = string.Empty;

    public DateTime ExpiresAtUtc { get; set; }

    public bool IsRevoked { get; set; }
}
