using JetGo.Domain.Enums;

namespace JetGo.Application.DTOs.Payments;

public sealed class PaymentDetailsDto
{
    public int Id { get; init; }

    public int ReservationId { get; init; }

    public string ReservationCode { get; init; } = string.Empty;

    public string FlightNumber { get; init; } = string.Empty;

    public string RouteCode { get; init; } = string.Empty;

    public string Provider { get; init; } = string.Empty;

    public string? ProviderReference { get; init; }

    public decimal Amount { get; init; }

    public string Currency { get; init; } = "BAM";

    public PaymentStatus Status { get; init; }

    public bool IsPaid { get; init; }

    public DateTime CreatedAtUtc { get; init; }

    public DateTime? UpdatedAtUtc { get; init; }

    public DateTime? PaidAtUtc { get; init; }

    public DateTime? RefundedAtUtc { get; init; }

    public string? StatusReason { get; init; }

    public bool CanBeConfirmed { get; init; }

    public bool CanBeRefunded { get; init; }

    public PaymentCustomerDto Customer { get; init; } = new();
}
