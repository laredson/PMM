using System.Globalization;
using System.Reflection;
using System.Text.Json;
using UAssetAPI;
using UAssetAPI.ExportTypes;
using UAssetAPI.PropertyTypes.Objects;
using UAssetAPI.UnrealTypes;
using UAssetAPI.Unversioned;

namespace PMM.AssetReader;

internal static class Program
{
    private static readonly JsonSerializerOptions JsonOptions = new() { WriteIndented = true };

    public static int Main(string[] args)
    {
        try
        {
            if (args.Length == 0)
                return Usage(1);
            if (args[0] is "-h" or "--help")
                return Usage(0);

            return args[0] switch
            {
                "export-json" => ExportJson(args[1..]),
                "export-datatable" => ExportDataTable(args[1..]),
                "probe" => Probe(args[1..]),
                "self-test-deps" => SelfTestDependencies(),
                _ => Usage(1)
            };
        }
        catch (Exception ex)
        {
            Console.Error.WriteLine(ex);
            return 2;
        }
    }

    private static int Usage(int exitCode)
    {
        Console.WriteLine("PMM.AssetReader v0.2 - read-only UAssetAPI bridge");
        Console.WriteLine("  export-json --asset <file.uasset> --output <file.json> --mappings <Mappings.usmap> --engine <UE5_1>");
        Console.WriteLine("  export-datatable --asset <file.uasset> --output <file.json> --mappings <Mappings.usmap> --engine <UE5_1>");
        Console.WriteLine("  probe --asset <file.uasset> --mappings <Mappings.usmap> --engine <UE5_1>");
        Console.WriteLine("  self-test-deps");
        return exitCode;
    }

    private static int SelfTestDependencies()
    {
        var loaded = new List<string>();
        foreach (var name in new[] { "UAssetAPI", "Newtonsoft.Json", "ZstdSharp" })
        {
            var assembly = Assembly.Load(new AssemblyName(name));
            loaded.Add($"{assembly.GetName().Name} {assembly.GetName().Version}");
        }

        Console.WriteLine(JsonSerializer.Serialize(new { status = "OK", loaded }, JsonOptions));
        return 0;
    }

    private static int ExportJson(string[] args)
    {
        var parsed = Args.Parse(args);
        var assetPath = parsed.Require("--asset");
        var outputPath = parsed.Require("--output");
        var mappings = parsed.Require("--mappings");
        var version = ParseEngine(parsed.Require("--engine"));
        var asset = Load(assetPath, mappings, version);
        Directory.CreateDirectory(Path.GetDirectoryName(Path.GetFullPath(outputPath))!);
        File.WriteAllText(outputPath, asset.SerializeJson());
        Console.WriteLine(JsonSerializer.Serialize(new
        {
            status = "OK",
            engine = version.ToString(),
            asset = Path.GetFullPath(assetPath),
            output = Path.GetFullPath(outputPath)
        }));
        return 0;
    }

    private static int ExportDataTable(string[] args)
    {
        var parsed = Args.Parse(args);
        var assetPath = parsed.Require("--asset");
        var outputPath = parsed.Require("--output");
        var mappings = parsed.Require("--mappings");
        var version = ParseEngine(parsed.Require("--engine"));
        var asset = Load(assetPath, mappings, version);
        var tableExport = asset.Exports.OfType<DataTableExport>().SingleOrDefault()
            ?? throw new InvalidDataException("Asset does not contain exactly one DataTableExport.");
        if (tableExport.Table is null)
            throw new InvalidDataException("DataTableExport has no table payload.");

        var serialBase = asset.UseSeparateBulkDataFiles && asset.Exports.Count > 0
            ? asset.Exports[0].SerialOffset
            : 0L;

        var rows = new List<object>();
        foreach (var row in tableExport.Table.Data)
        {
            var properties = new List<object>();
            foreach (var property in row.Value)
            {
                var value = ReadScalarValue(property);
                properties.Add(new
                {
                    name = property.Name.Value.Value,
                    type = property.PropertyType.Value,
                    offset = property.Offset - serialBase,
                    valueKind = value.Kind,
                    value = value.Value,
                    supportedScalar = value.Supported
                });
            }

            rows.Add(new
            {
                id = row.Name.Value.Value,
                properties
            });
        }

        var result = new
        {
            schema = 1,
            kind = "DataTable",
            engine = version.ToString(),
            asset = Path.GetFullPath(assetPath),
            useSeparateBulkDataFiles = asset.UseSeparateBulkDataFiles,
            uassetBytes = new FileInfo(assetPath).Length,
            exportSerialOffset = tableExport.SerialOffset,
            rows
        };
        Directory.CreateDirectory(Path.GetDirectoryName(Path.GetFullPath(outputPath))!);
        File.WriteAllText(outputPath, JsonSerializer.Serialize(result, JsonOptions));
        Console.WriteLine(JsonSerializer.Serialize(new
        {
            status = "OK",
            kind = "DataTable",
            rows = tableExport.Table.Data.Count,
            output = Path.GetFullPath(outputPath)
        }));
        return 0;
    }

    private static (bool Supported, string Kind, object? Value) ReadScalarValue(PropertyData property)
    {
        var valueProperty = property.GetType().GetProperty("Value", BindingFlags.Public | BindingFlags.Instance);
        if (valueProperty is null)
            return (false, "none", null);

        var value = valueProperty.GetValue(property);
        if (value is null)
            return (false, "null", null);

        return value switch
        {
            // BoolPropertyData can be encoded in unversioned headers/zero masks rather than
            // as a standalone value byte. Keep it visible to the semantic map, but do not
            // let the byte-patch adapter write it without a dedicated encoding adapter.
            bool x => (false, "bool", x),
            byte x => (true, "u8", x),
            sbyte x => (true, "i8", x),
            short x => (true, "i16", x),
            ushort x => (true, "u16", x),
            int x => (true, "i32", x),
            uint x => (true, "u32", x),
            long x => (true, "i64", x),
            ulong x => (true, "u64", x),
            float x => (true, "f32", x),
            double x => (true, "f64", x),
            decimal x => (false, "decimal", x.ToString(CultureInfo.InvariantCulture)),
            string x => (false, "string", x),
            Enum x => (false, "enum", x.ToString()),
            _ => (false, value.GetType().FullName ?? value.GetType().Name, Convert.ToString(value, CultureInfo.InvariantCulture))
        };
    }

    private static int Probe(string[] args)
    {
        var parsed = Args.Parse(args);
        var assetPath = parsed.Require("--asset");
        var mappings = parsed.Require("--mappings");
        var version = ParseEngine(parsed.Require("--engine"));
        var asset = Load(assetPath, mappings, version);
        var json = asset.SerializeJson();
        using var document = JsonDocument.Parse(json);
        var exports = document.RootElement.TryGetProperty("Exports", out var e) && e.ValueKind == JsonValueKind.Array
            ? e.GetArrayLength()
            : 0;
        Console.WriteLine(JsonSerializer.Serialize(new
        {
            status = "OK",
            engine = version.ToString(),
            exports,
            jsonBytes = System.Text.Encoding.UTF8.GetByteCount(json)
        }, JsonOptions));
        return 0;
    }

    private static UAsset Load(string assetPath, string mappingsPath, EngineVersion version)
    {
        if (!File.Exists(assetPath))
            throw new FileNotFoundException("Cooked .uasset not found.", assetPath);
        if (!File.Exists(mappingsPath))
            throw new FileNotFoundException("Mappings.usmap not found.", mappingsPath);
        var mappings = new Usmap(mappingsPath);
        return new UAsset(assetPath, version, mappings);
    }

    private static EngineVersion ParseEngine(string value)
        => value.ToUpperInvariant() switch
        {
            "UE5_1" or "VER_UE5_1" => EngineVersion.VER_UE5_1,
            _ => throw new ArgumentException($"Unsupported engine profile in Palworld Manager Merger v1.1: {value}. The current proven Palworld fixture uses UE5_1.")
        };

    private sealed class Args
    {
        private readonly Dictionary<string, string> _values = new(StringComparer.Ordinal);

        public static Args Parse(string[] args)
        {
            var result = new Args();
            for (var i = 0; i < args.Length; i++)
            {
                var key = args[i];
                if (!key.StartsWith("--", StringComparison.Ordinal) || i + 1 >= args.Length)
                    throw new ArgumentException($"Invalid argument sequence near: {key}");
                result._values[key] = args[++i];
            }
            return result;
        }

        public string Require(string key)
            => _values.TryGetValue(key, out var value) && !string.IsNullOrWhiteSpace(value)
                ? value
                : throw new ArgumentException($"Missing required option: {key}");
    }
}
