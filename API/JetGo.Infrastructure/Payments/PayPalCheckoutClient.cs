using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text;
using System.Text.Json;
using JetGo.Application.Configuration;
using JetGo.Application.Exceptions;
using Microsoft.Extensions.Caching.Memory;
using Microsoft.Extensions.Logging;

namespace JetGo.Infrastructure.Payments;

public sealed class PayPalCheckoutClient
{
    private const string AccessTokenCacheKey = "paypal.access-token";
    private static readonly JsonSerializerOptions JsonSerializerOptions = new(JsonSerializerDefaults.Web)
    {
        PropertyNamingPolicy = JsonNamingPolicy.SnakeCaseLower
    };

    private readonly HttpClient _httpClient;
    private readonly IMemoryCache _memoryCache;
    private readonly PayPalSettings _settings;
    private readonly ILogger<PayPalCheckoutClient> _logger;

    public PayPalCheckoutClient(
        HttpClient httpClient,
        IMemoryCache memoryCache,
        PayPalSettings settings,
        ILogger<PayPalCheckoutClient> logger)
    {
        _httpClient = httpClient;
        _memoryCache = memoryCache;
        _settings = settings;
        _logger = logger;
    }

    public async Task<PayPalOrderResponse> CreateOrderAsync(
        decimal amount,
        string currencyCode,
        string reservationCode,
        string description,
        CancellationToken cancellationToken)
    {
        var accessToken = await GetAccessTokenAsync(cancellationToken);
        using var request = new HttpRequestMessage(HttpMethod.Post, "/v2/checkout/orders");
        request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", accessToken);
        request.Headers.Add("PayPal-Request-Id", $"create-{reservationCode}-{Guid.NewGuid():N}"[..45]);
        request.Content = JsonContent.Create(new
        {
            intent = "CAPTURE",
            payment_source = new
            {
                paypal = new
                {
                    experience_context = new
                    {
                        user_action = "PAY_NOW",
                        shipping_preference = "NO_SHIPPING",
                        brand_name = "JetGo"
                    }
                }
            },
            purchase_units = new[]
            {
                new
                {
                    reference_id = reservationCode,
                    description,
                    amount = new
                    {
                        currency_code = currencyCode,
                        value = amount.ToString("0.00", System.Globalization.CultureInfo.InvariantCulture)
                    }
                }
            }
        });

        using var response = await _httpClient.SendAsync(request, cancellationToken);
        var payload = await response.Content.ReadAsStringAsync(cancellationToken);

        if (!response.IsSuccessStatusCode)
        {
            throw CreateProviderException("Kreiranje PayPal narudzbe nije uspjelo.", payload);
        }

        var order = JsonSerializer.Deserialize<PayPalOrderResponse>(payload, JsonSerializerOptions)
            ?? throw new ValidationException("PayPal odgovor nije validan.", new Dictionary<string, string[]>
            {
                ["payment"] = ["PayPal nije vratio validan odgovor za kreiranje narudzbe."]
            });

        return order;
    }

    public async Task<PayPalOrderResponse> GetOrderAsync(string orderId, CancellationToken cancellationToken)
    {
        var accessToken = await GetAccessTokenAsync(cancellationToken);
        using var request = new HttpRequestMessage(HttpMethod.Get, $"/v2/checkout/orders/{orderId}");
        request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", accessToken);

        using var response = await _httpClient.SendAsync(request, cancellationToken);
        var payload = await response.Content.ReadAsStringAsync(cancellationToken);

        if (!response.IsSuccessStatusCode)
        {
            throw CreateProviderException("Dohvat PayPal narudzbe nije uspio.", payload);
        }

        return JsonSerializer.Deserialize<PayPalOrderResponse>(payload, JsonSerializerOptions)
            ?? throw new ValidationException("PayPal odgovor nije validan.", new Dictionary<string, string[]>
            {
                ["payment"] = ["PayPal nije vratio validan odgovor za dohvat narudzbe."]
            });
    }

    public async Task<PayPalOrderResponse> CaptureOrderAsync(string orderId, string reservationCode, CancellationToken cancellationToken)
    {
        var accessToken = await GetAccessTokenAsync(cancellationToken);
        using var request = new HttpRequestMessage(HttpMethod.Post, $"/v2/checkout/orders/{orderId}/capture");
        request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", accessToken);
        request.Headers.Add("PayPal-Request-Id", $"capture-{reservationCode}-{Guid.NewGuid():N}"[..46]);
        request.Content = JsonContent.Create(new { });

        using var response = await _httpClient.SendAsync(request, cancellationToken);
        var payload = await response.Content.ReadAsStringAsync(cancellationToken);

        if (!response.IsSuccessStatusCode)
        {
            throw CreateProviderException("PayPal capture nije uspio.", payload);
        }

        return JsonSerializer.Deserialize<PayPalOrderResponse>(payload, JsonSerializerOptions)
            ?? throw new ValidationException("PayPal odgovor nije validan.", new Dictionary<string, string[]>
            {
                ["payment"] = ["PayPal nije vratio validan odgovor za capture narudzbe."]
            });
    }

    public async Task<PayPalRefundResponse> RefundCaptureAsync(
        string captureId,
        decimal amount,
        string currencyCode,
        string reservationCode,
        CancellationToken cancellationToken)
    {
        var accessToken = await GetAccessTokenAsync(cancellationToken);
        using var request = new HttpRequestMessage(HttpMethod.Post, $"/v2/payments/captures/{captureId}/refund");
        request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", accessToken);
        request.Headers.Add("PayPal-Request-Id", $"refund-{reservationCode}-{Guid.NewGuid():N}"[..45]);
        request.Content = JsonContent.Create(new
        {
            amount = new
            {
                currency_code = currencyCode,
                value = amount.ToString("0.00", System.Globalization.CultureInfo.InvariantCulture)
            }
        });

        using var response = await _httpClient.SendAsync(request, cancellationToken);
        var payload = await response.Content.ReadAsStringAsync(cancellationToken);

        if (!response.IsSuccessStatusCode)
        {
            throw CreateProviderException("PayPal refund nije uspio.", payload);
        }

        return JsonSerializer.Deserialize<PayPalRefundResponse>(payload, JsonSerializerOptions)
            ?? throw new ValidationException("PayPal odgovor nije validan.", new Dictionary<string, string[]>
            {
                ["payment"] = ["PayPal nije vratio validan odgovor za refund."]
            });
    }

    private async Task<string> GetAccessTokenAsync(CancellationToken cancellationToken)
    {
        if (_memoryCache.TryGetValue<string>(AccessTokenCacheKey, out var cachedAccessToken) &&
            !string.IsNullOrWhiteSpace(cachedAccessToken))
        {
            return cachedAccessToken;
        }

        using var request = new HttpRequestMessage(HttpMethod.Post, "/v1/oauth2/token");
        request.Headers.Accept.Add(new MediaTypeWithQualityHeaderValue("application/json"));
        request.Headers.Authorization = new AuthenticationHeaderValue(
            "Basic",
            Convert.ToBase64String(Encoding.UTF8.GetBytes($"{_settings.ClientId}:{_settings.ClientSecret}")));
        request.Content = new FormUrlEncodedContent(new Dictionary<string, string>
        {
            ["grant_type"] = "client_credentials"
        });

        using var response = await _httpClient.SendAsync(request, cancellationToken);
        var payload = await response.Content.ReadAsStringAsync(cancellationToken);

        if (!response.IsSuccessStatusCode)
        {
            throw CreateProviderException("PayPal OAuth autentifikacija nije uspjela.", payload);
        }

        var tokenResponse = JsonSerializer.Deserialize<PayPalAccessTokenResponse>(payload, JsonSerializerOptions)
            ?? throw new ValidationException("PayPal odgovor nije validan.", new Dictionary<string, string[]>
            {
                ["payment"] = ["PayPal nije vratio validan access token odgovor."]
            });

        var expiration = TimeSpan.FromSeconds(Math.Max(tokenResponse.ExpiresIn - 60, 60));
        _memoryCache.Set(AccessTokenCacheKey, tokenResponse.AccessToken, expiration);

        _logger.LogInformation("PayPal access token cached for approximately {Minutes} minutes.", Math.Round(expiration.TotalMinutes, 2));

        return tokenResponse.AccessToken;
    }

    private ValidationException CreateProviderException(string message, string? payload)
    {
        _logger.LogWarning("PayPal provider call failed. Message: {Message}. Payload: {Payload}", message, payload);

        return new ValidationException(
            message,
            new Dictionary<string, string[]>
            {
                ["payment"] = [string.IsNullOrWhiteSpace(payload) ? message : payload]
            });
    }

    public sealed class PayPalOrderResponse
    {
        public string Id { get; init; } = string.Empty;

        public string Status { get; init; } = string.Empty;

        public PayPalLink[] Links { get; init; } = [];

        public PayPalPurchaseUnit[] PurchaseUnits { get; init; } = [];
    }

    public sealed class PayPalRefundResponse
    {
        public string Id { get; init; } = string.Empty;

        public string Status { get; init; } = string.Empty;

        public PayPalMoney Amount { get; init; } = new();

        public DateTime? CreateTime { get; init; }
    }

    public sealed class PayPalLink
    {
        public string Href { get; init; } = string.Empty;

        public string Rel { get; init; } = string.Empty;

        public string Method { get; init; } = string.Empty;
    }

    public sealed class PayPalPurchaseUnit
    {
        public PayPalPayments? Payments { get; init; }
    }

    public sealed class PayPalPayments
    {
        public PayPalCapture[] Captures { get; init; } = [];
    }

    public sealed class PayPalCapture
    {
        public string Id { get; init; } = string.Empty;

        public string Status { get; init; } = string.Empty;

        public PayPalMoney Amount { get; init; } = new();

        public DateTime? CreateTime { get; init; }
    }

    public sealed class PayPalMoney
    {
        public string CurrencyCode { get; init; } = string.Empty;

        public string Value { get; init; } = string.Empty;
    }

    private sealed class PayPalAccessTokenResponse
    {
        public string AccessToken { get; init; } = string.Empty;

        public int ExpiresIn { get; init; }
    }
}
