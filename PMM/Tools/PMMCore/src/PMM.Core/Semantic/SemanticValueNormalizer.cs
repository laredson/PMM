using System.Globalization;
using System.Text.Json;

namespace PMM.Core.Semantic;

/// <summary>
/// Normalizes semantic leaf values without rewriting cooked assets.
/// This exists because UAssetAPI JSON may represent some numeric values as
/// strings (for example "+0") while another provider or a PMM policy may use
/// a JSON number (for example 0). Those representations are different JSON,
/// but for a FloatPropertyData they describe the same Float32 value.
/// </summary>
public static class SemanticValueNormalizer
{
    public static JsonElement Normalize(string typeName, JsonElement value)
    {
        if (IsFloatProperty(typeName) && TryReadFiniteDouble(value, out var number))
        {
            if (number < -float.MaxValue || number > float.MaxValue)
                return value.Clone();

            var single = (float)number;
            if (!float.IsFinite(single))
                return value.Clone();

            // Collapse +0 / -0 / "+0" / "0.0" to one deterministic semantic value.
            if (single == 0f)
                single = 0f;

            return JsonSerializer.SerializeToElement(single);
        }

        if (IsIntProperty(typeName) && TryReadInt64(value, out var integer))
            return JsonSerializer.SerializeToElement(integer);

        return value.Clone();
    }

    public static string Canonicalize(string typeName, JsonElement value)
    {
        var normalized = Normalize(typeName, value);
        return JsonCanonicalizer.Canonicalize(normalized);
    }

    private static bool IsFloatProperty(string typeName)
        => typeName.Contains("FloatPropertyData", StringComparison.Ordinal);

    private static bool IsIntProperty(string typeName)
        => typeName.Contains("IntPropertyData", StringComparison.Ordinal);

    private static bool TryReadInt64(JsonElement value, out long number)
    {
        if (value.ValueKind == JsonValueKind.Number && value.TryGetInt64(out number))
            return true;
        if (value.ValueKind == JsonValueKind.String &&
            long.TryParse(value.GetString(), NumberStyles.Integer, CultureInfo.InvariantCulture, out number))
            return true;
        number = 0;
        return false;
    }

    private static bool TryReadFiniteDouble(JsonElement value, out double number)
    {
        if (value.ValueKind == JsonValueKind.Number && value.TryGetDouble(out number))
            return double.IsFinite(number);

        if (value.ValueKind == JsonValueKind.String &&
            double.TryParse(
                value.GetString(),
                NumberStyles.Float,
                CultureInfo.InvariantCulture,
                out number))
        {
            return double.IsFinite(number);
        }

        number = 0;
        return false;
    }
}
