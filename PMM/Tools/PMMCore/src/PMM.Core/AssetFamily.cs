namespace PMM.Core;

public sealed class AssetFamily
{
    private static readonly string[] KnownExtensions = [".uasset", ".uexp", ".ubulk"];

    public AssetFamily(string logicalPathWithoutExtension, IReadOnlyDictionary<string, byte[]> parts)
    {
        LogicalPathWithoutExtension = logicalPathWithoutExtension.Replace('\\', '/');
        Parts = parts.ToDictionary(x => x.Key, x => x.Value, StringComparer.OrdinalIgnoreCase);
    }

    public string LogicalPathWithoutExtension { get; }
    public IReadOnlyDictionary<string, byte[]> Parts { get; }

    public byte[] Require(string extension)
        => Parts.TryGetValue(extension, out var data)
            ? data
            : throw new InvalidDataException($"Asset family is missing {extension}: {LogicalPathWithoutExtension}");

    public AssetFamily Clone()
        => new(
            LogicalPathWithoutExtension,
            Parts.ToDictionary(
                x => x.Key,
                x => x.Value.ToArray(),
                StringComparer.OrdinalIgnoreCase));

    public static AssetFamily FromDirectory(string root, string logicalPath)
    {
        var normalized = logicalPath.Replace('\\', '/');
        foreach (var extension in KnownExtensions)
        {
            if (normalized.EndsWith(extension, StringComparison.OrdinalIgnoreCase))
            {
                normalized = normalized[..^extension.Length];
                break;
            }
        }

        var parts = new Dictionary<string, byte[]>(StringComparer.OrdinalIgnoreCase);
        foreach (var extension in KnownExtensions)
        {
            var relative = (normalized + extension).Replace('/', Path.DirectorySeparatorChar);
            var path = Path.Combine(root, relative);
            if (File.Exists(path))
                parts[extension] = File.ReadAllBytes(path);
        }

        if (parts.Count == 0)
            throw new FileNotFoundException($"No cooked asset parts found for {normalized} under {root}.");

        return new AssetFamily(normalized, parts);
    }

    public void WriteToDirectory(string root)
    {
        foreach (var (extension, bytes) in Parts)
        {
            var relative = (LogicalPathWithoutExtension + extension).Replace('/', Path.DirectorySeparatorChar);
            var path = Path.Combine(root, relative);
            Directory.CreateDirectory(Path.GetDirectoryName(path)!);
            File.WriteAllBytes(path, bytes);
        }
    }
}
