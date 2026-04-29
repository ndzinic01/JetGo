using JetGo.Domain.Common;
using JetGo.Domain.Enums;

namespace JetGo.Domain.Entities;

public sealed class Payment : AuditableEntity
{
    public int ReservationId { get; set; }

    public Reservation Reservation { get; set; } = null!;

    public string Provider { get; set; } = "PayPal";

    public string? ProviderReference { get; set; }

    public decimal Amount { get; set; }

    public string Currency { get; set; } = "BAM";

    public PaymentStatus Status { get; set; } = PaymentStatus.Pending;

    public DateTime? PaidAtUtc { get; set; }

    public DateTime? RefundedAtUtc { get; set; }

    public string? StatusReason { get; set; }
}
