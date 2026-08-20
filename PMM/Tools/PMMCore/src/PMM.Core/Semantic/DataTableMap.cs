using System.Text.Json;

namespace PMM.Core.Semantic;

public sealed record DataTableScalar(
    string Kind,
    JsonElement Value,
    string Canonical)
{
    public static DataTableScalar From(string kind, JsonElement value)
    {
        var clone = value.Clone();
        return new DataTableScalar(kind, clone, JsonCanonicalizer.Canonicalize(clone));
    }
}

public sealed record DataTableProperty(
    string Name,
    string Type,
    long Offset,
    bool SupportedScalar,
    DataTableScalar Scalar);

public sealed class DataTableRowMap
{
    /// <summary>
    /// Stable merge key. Unique rows keep their Unreal row ID. Duplicate row IDs
    /// are occurrence-qualified as "RowId#1", "RowId#2", ... in source order.
    /// </summary>
    public required string Id { get; init; }
    public required string SourceId { get; init; }
    public required int Occurrence { get; init; }
    public required IReadOnlyDictionary<string, DataTableProperty> Properties { get; init; }
}

public sealed class DataTableMap
{
    public required string Asset { get; init; }
    public required IReadOnlyDictionary<string, DataTableRowMap> Rows { get; init; }

    public static DataTableMap Parse(string json)
    {
        using var doc = JsonDocument.Parse(json);
        return Parse(doc.RootElement);
    }

    public static DataTableMap Parse(ReadOnlyMemory<byte> json)
    {
        using var doc = JsonDocument.Parse(json);
        return Parse(doc.RootElement);
    }

    private static DataTableMap Parse(JsonElement root)
    {
        if (!root.TryGetProperty("kind", out var kind) || kind.GetString() != "DataTable")
            throw new InvalidDataException("Semantic map is not a DataTable map.");

        var rowTokens = root.GetProperty("rows").EnumerateArray()
            .Select(x => x.Clone())
            .ToArray();

        var totalBySourceId = new Dictionary<string, int>(StringComparer.Ordinal);
        foreach (var rowToken in rowTokens)
        {
            var sourceId = rowToken.GetProperty("id").GetString() ?? string.Empty;
            if (string.IsNullOrWhiteSpace(sourceId))
                throw new InvalidDataException("DataTable row has an empty ID.");
            totalBySourceId[sourceId] = totalBySourceId.TryGetValue(sourceId, out var count) ? count + 1 : 1;
        }

        var occurrenceBySourceId = new Dictionary<string, int>(StringComparer.Ordinal);
        var rows = new Dictionary<string, DataTableRowMap>(StringComparer.Ordinal);
        foreach (var rowToken in rowTokens)
        {
            var sourceId = rowToken.GetProperty("id").GetString() ?? string.Empty;
            var occurrence = occurrenceBySourceId.TryGetValue(sourceId, out var seen) ? seen + 1 : 1;
            occurrenceBySourceId[sourceId] = occurrence;

            // Unreal DataTables occasionally contain duplicate row names. Rejecting the
            // whole semantic map made otherwise-mergeable tables Unsupported. Preserve
            // every occurrence and align duplicate groups deterministically by source
            // order. If another provider changes the duplicate count/order, the normal
            // row/property comparison sees a structural difference instead of silently
            // collapsing two rows into one.
            var key = totalBySourceId[sourceId] == 1
                ? sourceId
                : $"{sourceId}#{occurrence}";

            if (rows.ContainsKey(key))
                throw new InvalidDataException($"DataTable generated duplicate merge key: {key}");

            var properties = new Dictionary<string, DataTableProperty>(StringComparer.Ordinal);
            foreach (var propToken in rowToken.GetProperty("properties").EnumerateArray())
            {
                var name = propToken.GetProperty("name").GetString() ?? string.Empty;
                var type = propToken.GetProperty("type").GetString() ?? string.Empty;
                var offset = propToken.GetProperty("offset").GetInt64();
                var supported = propToken.GetProperty("supportedScalar").GetBoolean();
                var valueKind = propToken.GetProperty("valueKind").GetString() ?? string.Empty;
                var value = propToken.GetProperty("value");
                properties[name] = new DataTableProperty(
                    name,
                    type,
                    offset,
                    supported,
                    DataTableScalar.From(valueKind, value));
            }

            rows.Add(key, new DataTableRowMap
            {
                Id = key,
                SourceId = sourceId,
                Occurrence = occurrence,
                Properties = properties
            });
        }

        return new DataTableMap
        {
            Asset = root.TryGetProperty("asset", out var asset) ? asset.GetString() ?? string.Empty : string.Empty,
            Rows = rows
        };
    }
}
