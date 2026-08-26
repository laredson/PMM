using System.Text.Json;

namespace PMM.Core.Semantic;

public sealed record SemanticProperty(
    string Name,
    string TypeName,
    JsonElement Value,
    string CanonicalValue);

public sealed class SemanticRow
{
    public required string Id { get; init; }
    public required int ExportIndex { get; init; }
    public required long SerialOffset { get; init; }
    public required long SerialSize { get; init; }
    public required IReadOnlyDictionary<string, SemanticProperty> Properties { get; init; }

    public SemanticProperty RequireProperty(string name)
        => Properties.TryGetValue(name, out var property)
            ? property
            : throw new InvalidDataException($"Row {Id} is missing semantic property {name}.");
}

public sealed class SemanticDocument
{
    public required IReadOnlyList<string> NameMap { get; init; }
    public required IReadOnlyDictionary<string, SemanticRow> Rows { get; init; }

    public SemanticRow RequireRow(string id)
        => Rows.TryGetValue(id, out var row)
            ? row
            : throw new InvalidDataException($"Semantic row not found: {id}");

    public static SemanticDocument Parse(string json)
    {
        using var document = JsonDocument.Parse(json);
        return Parse(document.RootElement);
    }

    public static SemanticDocument Parse(ReadOnlyMemory<byte> utf8Json)
    {
        using var document = JsonDocument.Parse(utf8Json);
        return Parse(document.RootElement);
    }

    private static SemanticDocument Parse(JsonElement root)
    {
        var nameMap = root.GetProperty("NameMap")
            .EnumerateArray()
            .Select(x => x.GetString() ?? string.Empty)
            .ToArray();

        var rows = new Dictionary<string, SemanticRow>(StringComparer.Ordinal);
        var exportIndex = 0;
        foreach (var export in root.GetProperty("Exports").EnumerateArray())
        {
            if (!export.TryGetProperty("Data", out var data) || data.ValueKind != JsonValueKind.Array)
            {
                exportIndex++;
                continue;
            }

            string? id = null;
            var properties = new Dictionary<string, SemanticProperty>(StringComparer.Ordinal);
            foreach (var property in data.EnumerateArray())
            {
                if (!property.TryGetProperty("Name", out var nameToken) || nameToken.ValueKind != JsonValueKind.String)
                    continue;

                var name = nameToken.GetString() ?? string.Empty;
                if (!property.TryGetProperty("Value", out var value))
                    continue;

                var typeName = property.TryGetProperty("$type", out var typeToken)
                    ? typeToken.GetString() ?? string.Empty
                    : string.Empty;
                var normalizedValue = SemanticValueNormalizer.Normalize(typeName, value);
                properties[name] = new SemanticProperty(
                    name,
                    typeName,
                    normalizedValue,
                    JsonCanonicalizer.Canonicalize(normalizedValue));

                if (name == "ID" && normalizedValue.ValueKind == JsonValueKind.String)
                    id = normalizedValue.GetString();
            }

            if (!string.IsNullOrWhiteSpace(id))
            {
                if (!rows.TryAdd(id, new SemanticRow
                    {
                        Id = id,
                        ExportIndex = exportIndex,
                        SerialOffset = export.TryGetProperty("SerialOffset", out var offset) ? offset.GetInt64() : 0,
                        SerialSize = export.TryGetProperty("SerialSize", out var size) ? size.GetInt64() : 0,
                        Properties = properties
                    }))
                {
                    throw new InvalidDataException($"Duplicate semantic row ID: {id}");
                }
            }

            exportIndex++;
        }

        return new SemanticDocument
        {
            NameMap = nameMap,
            Rows = rows
        };
    }
}
