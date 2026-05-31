using JetGo.Domain.Enums;

namespace JetGo.Application.DTOs.Payments;

public sealed class PayPalPaymentDebugDto
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

    public string PayPalOrderId { get; init; } = string.Empty;

    public string PayPalOrderStatus { get; init; } = string.Empty;

    public string? ApprovalUrl { get; init; }

    public IReadOnlyCollection<PayPalDebugLinkDto> Links { get; init; } = Array.Empty<PayPalDebugLinkDto>();

    public IReadOnlyCollection<PayPalDebugCaptureDto> Captures { get; init; } = Array.Empty<PayPalDebugCaptureDto>();
}
