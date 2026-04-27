namespace JetGo.Infrastructure.Configuration;

public static class DotEnvLoader
{
    public static string? LoadNearest(string startingDirectory, string fileName = ".env", bool overrideExisting = false)
    {
        var filePath = FindNearestFile(startingDirectory, fileName);

        if (filePath is null)
        {
            return null;
        }

        foreach (var rawLine in File.ReadAllLines(filePath))
        {
            var line = rawLine.Trim();

            if (string.IsNullOrWhiteSpace(line) || line.StartsWith('#'))
            {
                continue;
            }

            if (line.StartsWith("export ", StringComparison.OrdinalIgnoreCase))
            {
                line = line["export ".Length..].Trim();
            }

            var separatorIndex = line.IndexOf('=');

            if (separatorIndex <= 0)
            {
                continue;
            }

            var key = line[..separatorIndex].Trim();
            var value = line[(separatorIndex + 1)..].Trim();

            if (string.IsNullOrWhiteSpace(key))
            {
                continue;
            }

            value = TrimWrappingQuotes(value);

            if (!overrideExisting && !string.IsNullOrWhiteSpace(Environment.GetEnvironmentVariable(key)))
            {
                continue;
            }

            Environment.SetEnvironmentVariable(key, value);
        }

        return filePath;
    }

    private static string? FindNearestFile(string startingDirectory, string fileName)
    {
        var directory = new DirectoryInfo(Path.GetFullPath(startingDirectory));

        while (directory is not null)
        {
            var candidatePath = Path.Combine(directory.FullName, fileName);

            if (File.Exists(candidatePath))
            {
                return candidatePath;
            }

            directory = directory.Parent;
        }

        return null;
    }

    private static string TrimWrappingQuotes(string value)
    {
        if (value.Length >= 2)
        {
            var first = value[0];
            var last = value[^1];

            if ((first == '"' && last == '"') || (first == '\'' && last == '\''))
            {
                return value[1..^1];
            }
        }

        return value;
    }
}
