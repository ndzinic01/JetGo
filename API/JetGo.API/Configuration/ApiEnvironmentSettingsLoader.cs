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
                BaseUrl = EnvironmentVariableReader.GetRequired("JETGO_PAYPAL_BASE_URL"),
                ClientId = EnvironmentVariableReader.GetRequired("JETGO_PAYPAL_CLIENT_ID"),
                ClientSecret = EnvironmentVariableReader.GetRequired("JETGO_PAYPAL_CLIENT_SECRET"),
                ReturnUrl = EnvironmentVariableReader.GetRequired("JETGO_PAYPAL_RETURN_URL"),
                CancelUrl = EnvironmentVariableReader.GetRequired("JETGO_PAYPAL_CANCEL_URL"),
                CurrencyCode = EnvironmentVariableReader.GetRequired("JETGO_PAYPAL_CURRENCY_CODE"),
                BamToCurrencyRate = EnvironmentVariableReader.GetRequiredDecimal("JETGO_PAYPAL_BAM_TO_CURRENCY_RATE")
            },
            Smtp = new SmtpSettings
            {
                Host = EnvironmentVariableReader.GetRequired("JETGO_SMTP_HOST"),
                Port = EnvironmentVariableReader.GetRequiredInt("JETGO_SMTP_PORT"),
                UserName = EnvironmentVariableReader.GetOptional("JETGO_SMTP_USERNAME"),
                Password = EnvironmentVariableReader.GetOptional("JETGO_SMTP_PASSWORD"),
                UseSsl = EnvironmentVariableReader.GetRequiredBool("JETGO_SMTP_USE_SSL"),
                FromEmail = EnvironmentVariableReader.GetRequired("JETGO_SMTP_FROM_EMAIL"),
                FromName = EnvironmentVariableReader.GetRequired("JETGO_SMTP_FROM_NAME")
            }
        };
    }
}
