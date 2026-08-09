using JetGo.Domain.Enums;

namespace JetGo.Application.DTOs.Payments;

public sealed class PayPalPaymentVerificationDto
{
    public int PaymentId { get; init; }

    public int ReservationId { get; init; }

    public string ReservationCode { get; init; } = string.Empty;

    public string FlightNumber { get; init; } = string.Empty;

    public string StoredProviderReference { get; init; } = string.Empty;

    public string? CallbackToken { get; init; }

    public bool CallbackTokenMatchesStoredReference { get; init; }

    public PaymentStatus PaymentStatus { get; init; }

    public ReservationStatus ReservationStatus { get; init; }

    public string PayPalResourceType { get; init; } = "Order";

    public string PayPalOrderId { get; init; } = string.Empty;

    public string PayPalOrderStatus { get; init; } = string.Empty;

    public string? ApprovalUrl { get; init; }

    public string? VerificationNote { get; init; }

    public IReadOnlyCollection<PayPalVerificationLinkDto> Links { get; init; } = Array.Empty<PayPalVerificationLinkDto>();

    public IReadOnlyCollection<PayPalVerificationCaptureDto> Captures { get; init; } = Array.Empty<PayPalVerificationCaptureDto>();
}
