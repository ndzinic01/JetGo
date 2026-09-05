using JetGo.Domain.Common;
using JetGo.Domain.Enums;

namespace JetGo.Domain.Entities;

public sealed class PaymentTransaction : AuditableEntity
{
    public int PaymentId { get; set; }

    public Payment Payment { get; set; } = null!;

    public PaymentTransactionType Type { get; set; }

    public PaymentTransactionStatus Status { get; set; } = PaymentTransactionStatus.Pending;

    public string Provider { get; set; } = "PayPal";

    public string? ProviderReference { get; set; }

    public string? RelatedProviderReference { get; set; }

    public decimal Amount { get; set; }

    public string Currency { get; set; } = "BAM";

    public DateTime? CompletedAtUtc { get; set; }

    public string? Note { get; set; }
}
