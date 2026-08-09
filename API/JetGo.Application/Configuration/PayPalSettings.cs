namespace JetGo.Application.Configuration;

public sealed class PayPalSettings
{
    public string BaseUrl { get; init; } = string.Empty;

    public string ClientId { get; init; } = string.Empty;

    public string ClientSecret { get; init; } = string.Empty;

    public string ReturnUrl { get; init; } = string.Empty;

    public string CancelUrl { get; init; } = string.Empty;

    public string CurrencyCode { get; init; } = string.Empty;

    public decimal BamToCurrencyRate { get; init; }

    public bool IsConfigured =>
        !string.IsNullOrWhiteSpace(ClientId) &&
        !string.IsNullOrWhiteSpace(ClientSecret) &&
        !string.IsNullOrWhiteSpace(ReturnUrl) &&
        !string.IsNullOrWhiteSpace(CancelUrl);
}
