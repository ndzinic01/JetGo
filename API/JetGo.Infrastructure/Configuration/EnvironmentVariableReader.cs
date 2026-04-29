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
}
