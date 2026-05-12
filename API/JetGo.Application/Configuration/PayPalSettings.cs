namespace JetGo.Application.Configuration;

public sealed class PayPalSettings
{
    public string BaseUrl { get; init; } = "https://api-m.sandbox.paypal.com";

    public string ClientId { get; init; } = string.Empty;

    public string ClientSecret { get; init; } = string.Empty;

    public string CurrencyCode { get; init; } = "EUR";

    public decimal BamToCurrencyRate { get; init; } = 1.95583m;

    public bool IsConfigured =>
        !string.IsNullOrWhiteSpace(ClientId) &&
        !string.IsNullOrWhiteSpace(ClientSecret);
}
