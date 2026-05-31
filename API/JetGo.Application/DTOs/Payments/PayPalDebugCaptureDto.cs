namespace JetGo.Application.DTOs.Payments;

public sealed class PayPalDebugCaptureDto
{
    public string Id { get; init; } = string.Empty;

    public string Status { get; init; } = string.Empty;

    public decimal Amount { get; init; }

    public string Currency { get; init; } = string.Empty;

    public DateTime? CreateTimeUtc { get; init; }
}
