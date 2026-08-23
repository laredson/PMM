namespace PMM.Core;

public enum BinaryProviderStatus
{
    BinarySafe,
    NeedsAdapter
}

public sealed record BinaryPartAnalysis(
    string Part,
    string Status,
    int? VanillaSize,
    int ProviderSize,
    string? VanillaSha256,
    string ProviderSha256,
    int ChangedBytes,
    int ChangedRangeCount,
    IReadOnlyDictionary<int, int> RangeHistogram);

public sealed record BinaryProviderAnalysis(
    string Provider,
    BinaryProviderStatus Status,
    string Reason,
    IReadOnlyList<BinaryPartAnalysis> Parts);

public sealed record BinaryConflict(
    string Part,
    int Offset,
    byte Vanilla,
    IReadOnlyDictionary<string, byte> RequestedValues);

public sealed record BinaryMergeResult(
    AssetFamily Output,
    IReadOnlyList<BinaryProviderAnalysis> Providers,
    IReadOnlyList<BinaryConflict> Conflicts,
    int PatchedByteCount);

public static class BinaryRangeMergeAdapter
{
    public static BinaryProviderAnalysis AnalyzeProvider(
        AssetFamily vanilla,
        AssetFamily provider,
        string providerName)
    {
        var parts = new List<BinaryPartAnalysis>();
        var reasons = new List<string>();
        var allExtensions = vanilla.Parts.Keys
            .Union(provider.Parts.Keys, StringComparer.OrdinalIgnoreCase)
            .OrderBy(x => x, StringComparer.OrdinalIgnoreCase)
            .ToList();

        var uassetIdentityProven = false;
        foreach (var extension in allExtensions)
        {
            var hasVanilla = vanilla.Parts.TryGetValue(extension, out var vanillaBytes);
            var hasProvider = provider.Parts.TryGetValue(extension, out var providerBytes);

            if (!hasProvider)
            {
                reasons.Add($"provider missing {extension}");
                parts.Add(new BinaryPartAnalysis(
                    extension,
                    "MISSING",
                    hasVanilla ? vanillaBytes!.Length : null,
                    0,
                    hasVanilla ? Hashing.Sha256(vanillaBytes!) : null,
                    string.Empty,
                    0,
                    0,
                    new Dictionary<int, int>()));
                continue;
            }

            if (!hasVanilla)
            {
                reasons.Add($"provider adds {extension}");
                parts.Add(new BinaryPartAnalysis(
                    extension,
                    "ADDED",
                    null,
                    providerBytes!.Length,
                    null,
                    Hashing.Sha256(providerBytes),
                    0,
                    0,
                    new Dictionary<int, int>()));
                continue;
            }

            if (vanillaBytes!.Length != providerBytes!.Length)
            {
                reasons.Add($"{extension} size differs ({vanillaBytes.Length} -> {providerBytes.Length})");
                parts.Add(new BinaryPartAnalysis(
                    extension,
                    "SIZE_CHANGED",
                    vanillaBytes.Length,
                    providerBytes.Length,
                    Hashing.Sha256(vanillaBytes),
                    Hashing.Sha256(providerBytes),
                    0,
                    0,
                    new Dictionary<int, int>()));
                continue;
            }

            var ranges = ByteRanges.ChangedRanges(vanillaBytes, providerBytes);
            var changedBytes = ranges.Sum(r => r.Length);
            var status = ranges.Count == 0 ? "IDENTICAL" : "BYTE_DELTA";
            parts.Add(new BinaryPartAnalysis(
                extension,
                status,
                vanillaBytes.Length,
                providerBytes.Length,
                Hashing.Sha256(vanillaBytes),
                Hashing.Sha256(providerBytes),
                changedBytes,
                ranges.Count,
                ByteRanges.LengthHistogram(ranges)));

            if (extension.Equals(".uasset", StringComparison.OrdinalIgnoreCase))
            {
                uassetIdentityProven = ranges.Count == 0;
                if (!uassetIdentityProven)
                    reasons.Add($".uasset differs in {changedBytes} bytes/{ranges.Count} ranges");
            }
        }

        if (!uassetIdentityProven)
            reasons.Add("current Vanilla layout was not proven by byte-identical .uasset");

        return reasons.Count == 0
            ? new BinaryProviderAnalysis(
                providerName,
                BinaryProviderStatus.BinarySafe,
                "current Vanilla layout proven; all sidecars have identical topology and size",
                parts)
            : new BinaryProviderAnalysis(
                providerName,
                BinaryProviderStatus.NeedsAdapter,
                string.Join("; ", reasons.Distinct(StringComparer.Ordinal)),
                parts);
    }

    public static BinaryMergeResult Plan(
        AssetFamily vanilla,
        IReadOnlyList<(string Name, AssetFamily Family)> providers)
    {
        if (providers.Count == 0)
            throw new ArgumentException("At least one provider is required.", nameof(providers));

        var analyses = providers
            .Select(p => AnalyzeProvider(vanilla, p.Family, p.Name))
            .ToList();
        var unsafeProviders = analyses
            .Where(p => p.Status != BinaryProviderStatus.BinarySafe)
            .ToList();
        if (unsafeProviders.Count > 0)
        {
            throw new InvalidDataException(
                "Binary merge refused: " +
                string.Join(" | ", unsafeProviders.Select(p => $"{p.Provider}: {p.Reason}")));
        }

        var output = vanilla.Parts.ToDictionary(
            pair => pair.Key,
            pair => pair.Value.ToArray(),
            StringComparer.OrdinalIgnoreCase);
        var conflicts = new List<BinaryConflict>();
        var patchedBytes = 0;

        foreach (var (extension, vanillaBytes) in vanilla.Parts)
        {
            if (extension.Equals(".uasset", StringComparison.OrdinalIgnoreCase))
                continue;

            var requested = new Dictionary<int, Dictionary<string, byte>>();
            foreach (var provider in providers)
            {
                var providerBytes = provider.Family.Require(extension);
                for (var offset = 0; offset < vanillaBytes.Length; offset++)
                {
                    if (providerBytes[offset] == vanillaBytes[offset])
                        continue;

                    if (!requested.TryGetValue(offset, out var byProvider))
                    {
                        byProvider = new Dictionary<string, byte>(StringComparer.Ordinal);
                        requested[offset] = byProvider;
                    }
                    byProvider[provider.Name] = providerBytes[offset];
                }
            }

            foreach (var (offset, byProvider) in requested.OrderBy(x => x.Key))
            {
                var distinct = byProvider.Values.Distinct().ToArray();
                if (distinct.Length > 1)
                {
                    conflicts.Add(new BinaryConflict(
                        extension,
                        offset,
                        vanillaBytes[offset],
                        new Dictionary<string, byte>(byProvider, StringComparer.Ordinal)));
                    continue;
                }

                output[extension][offset] = distinct[0];
                patchedBytes++;
            }
        }

        return new BinaryMergeResult(
            new AssetFamily(vanilla.LogicalPathWithoutExtension, output),
            analyses,
            conflicts,
            patchedBytes);
    }

    public static BinaryMergeResult Merge(
        AssetFamily vanilla,
        IReadOnlyList<(string Name, AssetFamily Family)> providers,
        IReadOnlyDictionary<string, string>? resolutions = null)
    {
        var plan = Plan(vanilla, providers);
        if (plan.Conflicts.Count == 0)
            return plan;

        if (resolutions is null)
        {
            var first = plan.Conflicts[0];
            throw new InvalidDataException(
                $"Binary merge found {plan.Conflicts.Count} conflicting byte offsets. " +
                $"First: {first.Part}@{first.Offset} -> " +
                string.Join(", ", first.RequestedValues.Select(x => $"{x.Key}=0x{x.Value:x2}")));
        }

        var output = plan.Output.Parts.ToDictionary(
            x => x.Key,
            x => x.Value.ToArray(),
            StringComparer.OrdinalIgnoreCase);
        var patchedBytes = plan.PatchedByteCount;
        var unresolved = new List<string>();

        foreach (var conflict in plan.Conflicts)
        {
            var key = ConflictKey(conflict.Part, conflict.Offset);
            if (!resolutions.TryGetValue(key, out var choice) || string.IsNullOrWhiteSpace(choice))
            {
                unresolved.Add(key);
                continue;
            }

            byte desired;
            if (string.Equals(choice, "Vanilla", StringComparison.Ordinal))
            {
                desired = conflict.Vanilla;
            }
            else if (TryParseCustomByte(choice, out var custom))
            {
                desired = custom;
            }
            else if (!conflict.RequestedValues.TryGetValue(choice, out desired))
            {
                throw new InvalidDataException($"Binary resolution {key} names an invalid provider/value: {choice}");
            }

            output[conflict.Part][conflict.Offset] = desired;
            if (desired != conflict.Vanilla)
                patchedBytes++;
        }

        if (unresolved.Count > 0)
            throw new InvalidDataException($"Binary merge has {unresolved.Count} unresolved overlapping byte(s). First: {unresolved[0]}");

        return new BinaryMergeResult(
            new AssetFamily(vanilla.LogicalPathWithoutExtension, output),
            plan.Providers,
            Array.Empty<BinaryConflict>(),
            patchedBytes);
    }

    private static bool TryParseCustomByte(string choice, out byte value)
    {
        value = 0;
        const string prefix = "Custom:";
        if (!choice.StartsWith(prefix, StringComparison.Ordinal))
            return false;
        var raw = choice[prefix.Length..].Trim();
        if (raw.Length >= 2 && raw[0] == '"' && raw[^1] == '"')
            raw = raw[1..^1].Trim();
        if (raw.StartsWith("0x", StringComparison.OrdinalIgnoreCase))
            return byte.TryParse(raw[2..], System.Globalization.NumberStyles.HexNumber, System.Globalization.CultureInfo.InvariantCulture, out value);
        return byte.TryParse(raw, System.Globalization.NumberStyles.Integer, System.Globalization.CultureInfo.InvariantCulture, out value);
    }

    public static string ConflictKey(string part, int offset)
        => $"{part}@{offset}";

}
