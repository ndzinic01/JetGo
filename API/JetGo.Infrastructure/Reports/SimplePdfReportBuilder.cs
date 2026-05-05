using System.Text;

namespace JetGo.Infrastructure.Reports;

internal static class SimplePdfReportBuilder
{
    private const int PageWidth = 595;
    private const int PageHeight = 842;
    private const int LinesPerPage = 48;

    public static byte[] Build(string title, IReadOnlyCollection<string> lines)
    {
        var allLines = new List<string>(lines.Count + 1)
        {
            title
        };

        allLines.AddRange(lines);

        var pages = ChunkLines(allLines, LinesPerPage);
        var objects = new List<string>();

        objects.Add("<< /Type /Catalog /Pages 2 0 R >>");

        var pageObjectIds = new List<int>();
        var contentObjectIds = new List<int>();
        var fontObjectId = 3 + (pages.Count * 2);

        for (var index = 0; index < pages.Count; index++)
        {
            var pageObjectId = 3 + (index * 2);
            var contentObjectId = pageObjectId + 1;

            pageObjectIds.Add(pageObjectId);
            contentObjectIds.Add(contentObjectId);
        }

        var kids = string.Join(" ", pageObjectIds.Select(id => $"{id} 0 R"));
        objects.Add($"<< /Type /Pages /Kids [{kids}] /Count {pages.Count} >>");

        for (var index = 0; index < pages.Count; index++)
        {
            var content = BuildPageContent(pages[index]);
            var contentBytes = Encoding.ASCII.GetBytes(content);

            objects.Add(
                $"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 {PageWidth} {PageHeight}] /Resources << /Font << /F1 {fontObjectId} 0 R >> >> /Contents {contentObjectIds[index]} 0 R >>");

            objects.Add($"<< /Length {contentBytes.Length} >>\nstream\n{content}\nendstream");
        }

        objects.Add("<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>");

        return BuildPdf(objects);
    }

    private static string BuildPageContent(IReadOnlyList<string> lines)
    {
        var builder = new StringBuilder();
        builder.AppendLine("BT");
        builder.AppendLine("/F1 18 Tf");
        builder.AppendLine("50 800 Td");
        builder.AppendLine($"({Escape(lines[0])}) Tj");
        builder.AppendLine("0 -24 Td");
        builder.AppendLine("/F1 10 Tf");

        for (var index = 1; index < lines.Count; index++)
        {
            builder.AppendLine($"({Escape(lines[index])}) Tj");
            builder.AppendLine("0 -14 Td");
        }

        builder.AppendLine("ET");
        return builder.ToString().TrimEnd();
    }

    private static byte[] BuildPdf(IReadOnlyList<string> objects)
    {
        var builder = new StringBuilder();
        builder.Append("%PDF-1.4\n");

        var offsets = new List<int> { 0 };

        for (var index = 0; index < objects.Count; index++)
        {
            offsets.Add(builder.Length);
            builder.Append($"{index + 1} 0 obj\n");
            builder.Append(objects[index]);
            builder.Append("\nendobj\n");
        }

        var xrefOffset = builder.Length;
        builder.Append($"xref\n0 {objects.Count + 1}\n");
        builder.Append("0000000000 65535 f \n");

        foreach (var offset in offsets.Skip(1))
        {
            builder.Append($"{offset:D10} 00000 n \n");
        }

        builder.Append("trailer\n");
        builder.Append($"<< /Size {objects.Count + 1} /Root 1 0 R >>\n");
        builder.Append("startxref\n");
        builder.Append($"{xrefOffset}\n");
        builder.Append("%%EOF");

        return Encoding.ASCII.GetBytes(builder.ToString());
    }

    private static List<List<string>> ChunkLines(IReadOnlyList<string> lines, int pageSize)
    {
        var pages = new List<List<string>>();

        for (var index = 0; index < lines.Count; index += pageSize)
        {
            pages.Add(lines.Skip(index).Take(pageSize).ToList());
        }

        return pages;
    }

    private static string Escape(string value)
    {
        return value
            .Replace("\\", "\\\\", StringComparison.Ordinal)
            .Replace("(", "\\(", StringComparison.Ordinal)
            .Replace(")", "\\)", StringComparison.Ordinal);
    }
}
