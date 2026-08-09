namespace JetGo.Application.DTOs.Payments;

public sealed class PayPalVerificationLinkDto
{
    public string Rel { get; init; } = string.Empty;

    public string Method { get; init; } = string.Empty;

    public string Href { get; init; } = string.Empty;
}
