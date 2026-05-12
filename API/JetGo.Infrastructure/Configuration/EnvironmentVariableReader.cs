using System.Globalization;

namespace JetGo.Infrastructure.Configuration;

public static class EnvironmentVariableReader
{
    public static string GetRequired(string variableName)
    {
        var value = Environment.GetEnvironmentVariable(variableName);

        if (string.IsNullOrWhiteSpace(value))
        {
            throw new InvalidOperationException($"Environment variable '{variableName}' is required.");
        }

        return value;
    }

    public static int GetRequiredInt(string variableName)
    {
        var rawValue = GetRequired(variableName);

        if (!int.TryParse(rawValue, out var parsedValue) || parsedValue <= 0)
        {
            throw new InvalidOperationException($"Environment variable '{variableName}' must be a positive integer.");
        }

        return parsedValue;
    }

    public static string? GetOptional(string variableName)
    {
        var value = Environment.GetEnvironmentVariable(variableName);
        return string.IsNullOrWhiteSpace(value) ? null : value;
    }

    public static decimal GetOptionalDecimal(string variableName, decimal defaultValue)
    {
        var rawValue = GetOptional(variableName);

        if (string.IsNullOrWhiteSpace(rawValue))
        {
            return defaultValue;
        }

        if (!decimal.TryParse(rawValue, NumberStyles.Number, CultureInfo.InvariantCulture, out var parsedValue) || parsedValue <= 0)
        {
            throw new InvalidOperationException($"Environment variable '{variableName}' must be a positive decimal number.");
        }

        return parsedValue;
    }
}
