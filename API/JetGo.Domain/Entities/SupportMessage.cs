using JetGo.Domain.Common;

namespace JetGo.Domain.Entities;

public sealed class SupportMessage : AuditableEntity
{
    public string UserId { get; set; } = string.Empty;

    public string Subject { get; set; } = string.Empty;

    public string Message { get; set; } = string.Empty;

    public string? AdminReply { get; set; }

    public DateTime? RepliedAtUtc { get; set; }
}
