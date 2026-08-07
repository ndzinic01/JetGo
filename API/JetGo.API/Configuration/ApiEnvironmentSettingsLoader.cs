using JetGo.Application.Configuration;
using JetGo.Infrastructure.Configuration;

namespace JetGo.API.Configuration;

internal static class ApiEnvironmentSettingsLoader
{
    public static ApiEnvironmentSettings Load()
    {
        return new ApiEnvironmentSettings
        {
            ConnectionString = EnvironmentVariableReader.GetRequired("JETGO_CONNECTION_STRING"),
            Jwt = new JwtSettings
            {
                Issuer = EnvironmentVariableReader.GetRequired("JETGO_JWT_ISSUER"),
                Audience = EnvironmentVariableReader.GetRequired("JETGO_JWT_AUDIENCE"),
                Key = EnvironmentVariableReader.GetRequired("JETGO_JWT_KEY"),
                ExpiryMinutes = EnvironmentVariableReader.GetRequiredInt("JETGO_JWT_EXPIRY_MINUTES")
            },
            RabbitMq = new RabbitMqSettings
            {
                Host = EnvironmentVariableReader.GetRequired("JETGO_RABBITMQ_HOST"),
                Port = EnvironmentVariableReader.GetRequiredInt("JETGO_RABBITMQ_PORT"),
                UserName = EnvironmentVariableReader.GetRequired("JETGO_RABBITMQ_USERNAME"),
                Password = EnvironmentVariableReader.GetRequired("JETGO_RABBITMQ_PASSWORD"),
                VirtualHost = EnvironmentVariableReader.GetRequired("JETGO_RABBITMQ_VIRTUAL_HOST"),
                NotificationsQueueName = EnvironmentVariableReader.GetRequired("JETGO_RABBITMQ_NOTIFICATIONS_QUEUE")
            },
            PayPal = new PayPalSettings
            {
                BaseUrl = EnvironmentVariableReader.GetOptional("JETGO_PAYPAL_BASE_URL") ?? "https://api-m.sandbox.paypal.com",
                ClientId = EnvironmentVariableReader.GetOptional("JETGO_PAYPAL_CLIENT_ID") ?? string.Empty,
                ClientSecret = EnvironmentVariableReader.GetOptional("JETGO_PAYPAL_CLIENT_SECRET") ?? string.Empty,
                ReturnUrl = EnvironmentVariableReader.GetOptional("JETGO_PAYPAL_RETURN_URL") ?? string.Empty,
                CancelUrl = EnvironmentVariableReader.GetOptional("JETGO_PAYPAL_CANCEL_URL") ?? string.Empty,
                CurrencyCode = EnvironmentVariableReader.GetOptional("JETGO_PAYPAL_CURRENCY_CODE") ?? "EUR",
                BamToCurrencyRate = EnvironmentVariableReader.GetOptionalDecimal("JETGO_PAYPAL_BAM_TO_CURRENCY_RATE", 1.95583m)
            },
            Smtp = new SmtpSettings
            {
                Host = EnvironmentVariableReader.GetOptional("JETGO_SMTP_HOST") ?? "localhost",
                Port = EnvironmentVariableReader.GetOptionalInt("JETGO_SMTP_PORT", 1025),
                UserName = EnvironmentVariableReader.GetOptional("JETGO_SMTP_USERNAME"),
                Password = EnvironmentVariableReader.GetOptional("JETGO_SMTP_PASSWORD"),
                UseSsl = EnvironmentVariableReader.GetOptionalBool("JETGO_SMTP_USE_SSL", false),
                FromEmail = EnvironmentVariableReader.GetOptional("JETGO_SMTP_FROM_EMAIL") ?? "no-reply@jetgo.local",
                FromName = EnvironmentVariableReader.GetOptional("JETGO_SMTP_FROM_NAME") ?? "JetGo"
            }
        };
    }
}
