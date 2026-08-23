using System.Globalization;
using System.Text;
using System.Text.Json;

namespace PMM.Core.Semantic;

public static class JsonCanonicalizer
{
    public static string Canonicalize(JsonElement element)
    {
        using var stream = new MemoryStream();
        using (var writer = new Utf8JsonWriter(stream, new JsonWriterOptions { Indented = false }))
        {
            WriteCanonical(writer, element);
        }
        return Encoding.UTF8.GetString(stream.ToArray());
    }

    private static void WriteCanonical(Utf8JsonWriter writer, JsonElement element)
    {
        switch (element.ValueKind)
        {
            case JsonValueKind.Object:
                writer.WriteStartObject();
                foreach (var property in element.EnumerateObject()
                             .Where(p => !p.NameEquals("$type"))
                             .OrderBy(p => p.Name, StringComparer.Ordinal))
                {
                    writer.WritePropertyName(property.Name);
                    WriteCanonical(writer, property.Value);
                }
                writer.WriteEndObject();
                break;

            case JsonValueKind.Array:
                writer.WriteStartArray();
                foreach (var item in element.EnumerateArray())
                    WriteCanonical(writer, item);
                writer.WriteEndArray();
                break;

            case JsonValueKind.String:
                writer.WriteStringValue(element.GetString());
                break;

            case JsonValueKind.Number:
                WriteNormalizedNumber(writer, element);
                break;

            case JsonValueKind.True:
                writer.WriteBooleanValue(true);
                break;

            case JsonValueKind.False:
                writer.WriteBooleanValue(false);
                break;

            case JsonValueKind.Null:
            case JsonValueKind.Undefined:
                writer.WriteNullValue();
                break;

            default:
                throw new InvalidDataException($"Unsupported JSON value kind: {element.ValueKind}");
        }
    }

    private static void WriteNormalizedNumber(Utf8JsonWriter writer, JsonElement element)
    {
        if (element.TryGetInt64(out var integer))
        {
            writer.WriteNumberValue(integer);
            return;
        }

        if (element.TryGetDecimal(out var decimalValue))
        {
            var normalized = decimalValue.ToString("G29", CultureInfo.InvariantCulture);
            writer.WriteRawValue(normalized, skipInputValidation: false);
            return;
        }

        var doubleValue = element.GetDouble();
        var text = doubleValue.ToString("R", CultureInfo.InvariantCulture);
        writer.WriteRawValue(text, skipInputValidation: false);
    }
}
