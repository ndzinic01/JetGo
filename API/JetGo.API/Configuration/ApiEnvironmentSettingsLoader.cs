using JetGo.Application.Configuration;

namespace JetGo.API.Configuration;

internal static class ApiEnvironmentSettingsLoader
{
    public static ApiEnvironmentSettings Load()
    {
        return new ApiEnvironmentSettings
        {
            ConnectionString = GetRequired("JETGO_CONNECTION_STRING"),
            Jwt = new JwtSettings
            {
                Issuer = GetRequired("JETGO_JWT_ISSUER"),
                Audience = GetRequired("JETGO_JWT_AUDIENCE"),
                Key = GetRequired("JETGO_JWT_KEY"),
                ExpiryMinutes = GetRequiredInt("JETGO_JWT_EXPIRY_MINUTES")
            }
        };
    }

    private static string GetRequired(string variableName)
    {
        var value = Environment.GetEnvironmentVariable(variableName);

        if (string.IsNullOrWhiteSpace(value))
        {
            throw new InvalidOperationException($"Environment variable '{variableName}' is required.");
        }

        return value;
    }

    private static int GetRequiredInt(string variableName)
    {
        var rawValue = GetRequired(variableName);

        if (!int.TryParse(rawValue, out var parsedValue) || parsedValue <= 0)
        {
            throw new InvalidOperationException($"Environment variable '{variableName}' must be a positive integer.");
        }

        return parsedValue;
    }
}
