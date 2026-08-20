namespace PMM.Core;

public sealed record BinaryHunk(int BaseStart, int BaseLength, byte[] Replacement)
{
    public int BaseEnd => BaseStart + BaseLength;
    public int NetLengthDelta => Replacement.Length - BaseLength;
}

public sealed record RelocatableProviderReport(
    string Provider,
    int UexpNetDelta,
    int UexpHunks,
    int UassetRelocationHunks,
    string Status,
    string Reason);

public sealed record RelocatableConflict(
    string Part,
    int Offset,
    IReadOnlyDictionary<string, byte> RequestedValues,
    bool SupportsVanilla,
    bool SupportsCustom,
    string VanillaMeaning)
{
    public string Key => $"{Part}@{Offset}";
}

public sealed record RelocatableMergeResult(
    AssetFamily Output,
    string BaseProvider,
    IReadOnlyList<RelocatableProviderReport> Providers,
    IReadOnlyList<RelocatableConflict> Conflicts,
    int AppliedHunks);

public static class RelocatableDeltaAdapter
{
    public const string AdapterId = "RelocatableDelta-v2";
    private const int MaximumDiffPartBytes = 64 * 1024;
    private const int MaximumEditDistance = 4096;

    public static RelocatableMergeResult Merge(
        AssetFamily vanilla,
        IReadOnlyList<(string Name, AssetFamily Family)> providers,
        IReadOnlyDictionary<string, string>? resolutions = null)
    {
        if (providers.Count < 2)
            throw new ArgumentException("Relocatable merge requires at least two providers.", nameof(providers));
        if (!vanilla.Parts.ContainsKey(".uasset") || !vanilla.Parts.ContainsKey(".uexp"))
            throw new InvalidDataException("Relocatable merge currently requires .uasset + .uexp.");

        var anchor = providers
            .OrderByDescending(x => x.Family.Parts.Sum(part => part.Value.Length))
            .ThenBy(x => x.Name, StringComparer.Ordinal)
            .First();

        var variants = providers
            .Where(x => IsAnchorVariant(anchor.Family, x.Family))
            .OrderBy(x => x.Name, StringComparer.Ordinal)
            .ToArray();

        var outputParts = anchor.Family.Parts.ToDictionary(
            x => x.Key,
            x => x.Value.ToArray(),
            StringComparer.OrdinalIgnoreCase);
        var reports = new List<RelocatableProviderReport>();
        var applied = 0;

        var conflicts = CollectVariantConflicts(variants);
        if (conflicts.Count > 0 && resolutions is not null)
        {
            var vanillaSelected = conflicts
                .Where(conflict => resolutions.TryGetValue(conflict.Key, out var choice) &&
                    string.Equals(choice, "Vanilla", StringComparison.Ordinal))
                .ToArray();

            if (vanillaSelected.Length > 0)
            {
                if (vanillaSelected.Length != conflicts.Count || conflicts.Any(x => !x.SupportsVanilla))
                    throw new InvalidDataException(
                        "Vanilla can only be selected for a relocatable variant set when every conflict in that set is a proven single alternative cluster.");

                return MergeWithoutVariants(vanilla, providers, variants);
            }

            ApplyVariantResolutions(outputParts, conflicts, resolutions, ref applied);
            conflicts = new List<RelocatableConflict>();
        }

        foreach (var variant in variants)
        {
            if (string.Equals(variant.Name, anchor.Name, StringComparison.Ordinal))
            {
                reports.Add(new RelocatableProviderReport(
                    variant.Name, 0, 0, 0, "BASE", "Largest cooked provider selected as anchor."));
                continue;
            }

            var differingBytes = CountVariantDifferenceBytes(anchor.Family, variant.Family);
            reports.Add(new RelocatableProviderReport(
                variant.Name,
                0,
                differingBytes,
                0,
                differingBytes == 0 ? "IDENTICAL_VARIANT" : "ANCHOR_VARIANT",
                differingBytes == 0
                    ? "Provider is byte-identical to the selected structural anchor."
                    : "Provider shares the anchor layout exactly; differing bytes are exposed as true conflicts instead of discarding either variant."));
        }

        foreach (var provider in providers)
        {
            if (variants.Any(x => string.Equals(x.Name, provider.Name, StringComparison.Ordinal)))
                continue;

            var report = ApplySecondary(vanilla, provider.Name, provider.Family, outputParts, ref applied);
            reports.Add(report);
        }

        return new RelocatableMergeResult(
            new AssetFamily(vanilla.LogicalPathWithoutExtension, outputParts),
            anchor.Name,
            reports,
            conflicts,
            applied);
    }

    private static bool IsAnchorVariant(AssetFamily anchor, AssetFamily candidate)
    {
        if (!anchor.Parts.Keys.ToHashSet(StringComparer.OrdinalIgnoreCase)
            .SetEquals(candidate.Parts.Keys))
            return false;

        foreach (var part in anchor.Parts)
        {
            if (!candidate.Parts.TryGetValue(part.Key, out var other) || part.Value.Length != other.Length)
                return false;
        }

        return anchor.Require(".uasset").SequenceEqual(candidate.Require(".uasset"));
    }

    private static List<RelocatableConflict> CollectVariantConflicts(
        IReadOnlyList<(string Name, AssetFamily Family)> variants)
    {
        var conflicts = new List<RelocatableConflict>();
        if (variants.Count < 2)
            return conflicts;

        foreach (var part in variants[0].Family.Parts.Keys.OrderBy(x => x, StringComparer.OrdinalIgnoreCase))
        {
            if (part.Equals(".uasset", StringComparison.OrdinalIgnoreCase))
                continue;

            var first = variants[0].Family.Require(part);
            for (var offset = 0; offset < first.Length; offset++)
            {
                var values = new Dictionary<string, byte>(StringComparer.Ordinal);
                foreach (var variant in variants)
                    values[variant.Name] = variant.Family.Require(part)[offset];

                if (values.Values.Distinct().Count() > 1)
                    conflicts.Add(new RelocatableConflict(
                        part,
                        offset,
                        values,
                        SupportsVanilla: false,
                        SupportsCustom: true,
                        VanillaMeaning: "Installed Vanilla / no variant override"));
            }
        }

        // A single differing byte across otherwise identical structural variants
        // is the proven quasi-duplicate case (for example two editions of the
        // same mod that only request a different scalar value). In that specific
        // shape PMM can safely offer "Vanilla" by dropping the whole variant
        // cluster and then composing every independent provider on installed
        // Vanilla instead. Multiple independent variant conflicts are kept
        // provider/custom-only until a semantic adapter can separate them.
        if (conflicts.Count == 1)
        {
            var only = conflicts[0];
            conflicts[0] = only with { SupportsVanilla = true };
        }
        return conflicts;
    }

    private static int CountVariantDifferenceBytes(AssetFamily anchor, AssetFamily variant)
    {
        var count = 0;
        foreach (var part in anchor.Parts)
        {
            if (part.Key.Equals(".uasset", StringComparison.OrdinalIgnoreCase))
                continue;
            var other = variant.Require(part.Key);
            for (var i = 0; i < part.Value.Length; i++)
                if (part.Value[i] != other[i]) count++;
        }
        return count;
    }

    private static void ApplyVariantResolutions(
        Dictionary<string, byte[]> outputParts,
        IReadOnlyList<RelocatableConflict> conflicts,
        IReadOnlyDictionary<string, string> resolutions,
        ref int applied)
    {
        var unresolved = new List<string>();
        foreach (var conflict in conflicts)
        {
            if (!resolutions.TryGetValue(conflict.Key, out var choice) || string.IsNullOrWhiteSpace(choice))
            {
                unresolved.Add(conflict.Key);
                continue;
            }
            byte desired;
            if (TryParseCustomByte(choice, out var custom))
            {
                if (!conflict.SupportsCustom)
                    throw new InvalidDataException($"Relocatable resolution {conflict.Key} does not support a custom value.");
                desired = custom;
            }
            else if (!conflict.RequestedValues.TryGetValue(choice, out desired))
            {
                throw new InvalidDataException($"Relocatable resolution {conflict.Key} names an invalid provider/value: {choice}");
            }

            var bytes = outputParts[conflict.Part];
            if (bytes[conflict.Offset] != desired)
            {
                bytes[conflict.Offset] = desired;
                applied++;
            }
        }

        if (unresolved.Count > 0)
            throw new InvalidDataException($"Relocatable merge has {unresolved.Count} unresolved anchor-variant byte conflict(s). First: {unresolved[0]}");
    }

    private static RelocatableMergeResult MergeWithoutVariants(
        AssetFamily vanilla,
        IReadOnlyList<(string Name, AssetFamily Family)> providers,
        IReadOnlyList<(string Name, AssetFamily Family)> variants)
    {
        var outputParts = vanilla.Parts.ToDictionary(
            x => x.Key,
            x => x.Value.ToArray(),
            StringComparer.OrdinalIgnoreCase);
        var reports = new List<RelocatableProviderReport>();
        var applied = 0;

        foreach (var variant in variants)
        {
            reports.Add(new RelocatableProviderReport(
                variant.Name,
                0,
                0,
                0,
                "VANILLA_SELECTED",
                "Variant alternative was not applied because Vanilla was selected for its only true conflict."));
        }

        foreach (var provider in providers)
        {
            if (variants.Any(x => string.Equals(x.Name, provider.Name, StringComparison.Ordinal)))
                continue;
            reports.Add(ApplySecondary(vanilla, provider.Name, provider.Family, outputParts, ref applied));
        }

        return new RelocatableMergeResult(
            new AssetFamily(vanilla.LogicalPathWithoutExtension, outputParts),
            "Vanilla",
            reports,
            Array.Empty<RelocatableConflict>(),
            applied);
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

    private static RelocatableProviderReport ApplySecondary(
        AssetFamily vanilla,
        string providerName,
        AssetFamily provider,
        Dictionary<string, byte[]> outputParts,
        ref int applied)
    {
        var vanillaUasset = vanilla.Require(".uasset");
        var vanillaUexp = vanilla.Require(".uexp");
        var providerUasset = provider.Require(".uasset");
        var providerUexp = provider.Require(".uexp");
        var currentUasset = outputParts[".uasset"];
        var currentUexp = outputParts[".uexp"];

        if (vanillaUasset.Length != providerUasset.Length)
            throw new InvalidDataException($"{providerName}: secondary .uasset changes size; it cannot be transplanted onto the selected anchor.");
        if (vanillaUasset.Length > MaximumDiffPartBytes || vanillaUexp.Length > MaximumDiffPartBytes ||
            currentUasset.Length > MaximumDiffPartBytes || currentUexp.Length > MaximumDiffPartBytes)
            throw new InvalidDataException($"{providerName}: relocatable adapter size guard exceeded.");

        var uexpDelta = providerUexp.Length - vanillaUexp.Length;
        var secondaryUexpHunks = ByteDiff.CreateHunks(vanillaUexp, providerUexp, MaximumEditDistance);
        var metadataHunks = ByteDiff.CreateHunks(vanillaUasset, providerUasset, MaximumEditDistance);

        foreach (var hunk in metadataHunks)
        {
            if (hunk.BaseLength != hunk.Replacement.Length || hunk.BaseLength is < 1 or > 4)
                throw new InvalidDataException($"{providerName}: .uasset contains a non-relocation structural hunk.");
            var oldValue = ReadUnsigned(vanillaUasset.AsSpan(hunk.BaseStart, hunk.BaseLength));
            var newValue = ReadUnsigned(hunk.Replacement);
            if (newValue - oldValue != uexpDelta)
                throw new InvalidDataException(
                    $"{providerName}: .uasset hunk is not a pure sidecar relocation delta (expected {uexpDelta}, got {newValue - oldValue}).");
        }

        var uexpAlignment = ByteDiff.CreateHunks(vanillaUexp, currentUexp, MaximumEditDistance);
        var mappedUexp = new List<(int Start, int Length, byte[] Replacement)>();
        foreach (var hunk in secondaryUexpHunks)
        {
            if (OverlapsChangedRegion(hunk, uexpAlignment))
                throw new InvalidDataException($"{providerName}: .uexp hunk overlaps an anchor edit at Vanilla offset {hunk.BaseStart}.");
            var start = MapBoundary(hunk.BaseStart, uexpAlignment);
            var end = MapBoundary(hunk.BaseEnd, uexpAlignment);
            if (end - start != hunk.BaseLength)
                throw new InvalidDataException($"{providerName}: .uexp hunk maps through a resized anchor region.");
            if (hunk.BaseLength > 0 && !currentUexp.AsSpan(start, hunk.BaseLength).SequenceEqual(vanillaUexp.AsSpan(hunk.BaseStart, hunk.BaseLength)))
                throw new InvalidDataException($"{providerName}: anchor bytes no longer match Vanilla at mapped .uexp hunk.");
            mappedUexp.Add((start, hunk.BaseLength, hunk.Replacement));
        }
        foreach (var hunk in mappedUexp.OrderByDescending(x => x.Start))
        {
            currentUexp = ReplaceRange(currentUexp, hunk.Start, hunk.Length, hunk.Replacement);
            applied++;
        }
        outputParts[".uexp"] = currentUexp;

        if (metadataHunks.Count > 0)
        {
            var uassetAlignment = ByteDiff.CreateHunks(vanillaUasset, currentUasset, MaximumEditDistance);
            foreach (var hunk in metadataHunks)
            {
                var start = MapCoordinate(hunk.BaseStart, uassetAlignment);
                var currentValue = ReadUnsigned(currentUasset.AsSpan(start, hunk.BaseLength));
                var adjusted = checked(currentValue + uexpDelta);
                var max = hunk.BaseLength == 4 ? uint.MaxValue : (1L << (hunk.BaseLength * 8)) - 1L;
                if (adjusted < 0 || adjusted > max)
                    throw new InvalidDataException($"{providerName}: relocation arithmetic overflows {hunk.BaseLength} byte(s).");
                WriteUnsigned(currentUasset.AsSpan(start, hunk.BaseLength), adjusted);
                applied++;
            }
            outputParts[".uasset"] = currentUasset;
        }

        foreach (var part in provider.Parts.Keys)
        {
            if (part.Equals(".uasset", StringComparison.OrdinalIgnoreCase) || part.Equals(".uexp", StringComparison.OrdinalIgnoreCase))
                continue;
            if (!vanilla.Parts.TryGetValue(part, out var vanillaPart) || !provider.Parts.TryGetValue(part, out var providerPart))
                throw new InvalidDataException($"{providerName}: unsupported sidecar topology change: {part}.");
            if (!vanillaPart.SequenceEqual(providerPart))
                throw new InvalidDataException($"{providerName}: non-identical {part} is not supported by relocatable adapter.");
        }

        return new RelocatableProviderReport(
            providerName,
            uexpDelta,
            secondaryUexpHunks.Count,
            metadataHunks.Count,
            "MERGED",
            "Disjoint .uexp hunks transplanted; .uasset relocation metadata composed arithmetically.");
    }

    private static bool OverlapsChangedRegion(BinaryHunk candidate, IReadOnlyList<BinaryHunk> anchorHunks)
    {
        foreach (var anchor in anchorHunks)
        {
            if (candidate.BaseLength == 0)
            {
                if (anchor.BaseLength == 0 && anchor.BaseStart == candidate.BaseStart) return true;
                if (candidate.BaseStart > anchor.BaseStart && candidate.BaseStart < anchor.BaseEnd) return true;
                continue;
            }
            if (anchor.BaseLength == 0)
            {
                if (anchor.BaseStart > candidate.BaseStart && anchor.BaseStart < candidate.BaseEnd) return true;
                continue;
            }
            if (candidate.BaseStart < anchor.BaseEnd && anchor.BaseStart < candidate.BaseEnd) return true;
        }
        return false;
    }

    private static int MapBoundary(int basePosition, IReadOnlyList<BinaryHunk> hunks)
    {
        var shift = 0;
        foreach (var hunk in hunks.OrderBy(x => x.BaseStart))
        {
            if (basePosition < hunk.BaseStart) break;
            if (basePosition == hunk.BaseStart) return hunk.BaseStart + shift;
            if (basePosition >= hunk.BaseEnd)
            {
                shift += hunk.NetLengthDelta;
                continue;
            }
            if (hunk.BaseLength == hunk.Replacement.Length)
                return hunk.BaseStart + shift + (basePosition - hunk.BaseStart);
            throw new InvalidDataException($"Cannot map Vanilla boundary {basePosition} through resized anchor hunk {hunk.BaseStart}..{hunk.BaseEnd}.");
        }
        return checked(basePosition + shift);
    }

    private static int MapCoordinate(int basePosition, IReadOnlyList<BinaryHunk> hunks)
    {
        var shift = 0;
        foreach (var hunk in hunks.OrderBy(x => x.BaseStart))
        {
            if (basePosition < hunk.BaseStart) break;
            if (basePosition >= hunk.BaseEnd)
            {
                shift += hunk.NetLengthDelta;
                continue;
            }
            if (hunk.BaseLength == hunk.Replacement.Length)
                return checked(hunk.BaseStart + shift + (basePosition - hunk.BaseStart));
            throw new InvalidDataException($"Cannot map Vanilla coordinate {basePosition} inside resized anchor hunk.");
        }
        return checked(basePosition + shift);
    }

    private static byte[] ReplaceRange(byte[] source, int start, int length, byte[] replacement)
    {
        var output = new byte[checked(source.Length - length + replacement.Length)];
        Buffer.BlockCopy(source, 0, output, 0, start);
        Buffer.BlockCopy(replacement, 0, output, start, replacement.Length);
        Buffer.BlockCopy(source, start + length, output, start + replacement.Length, source.Length - start - length);
        return output;
    }

    private static long ReadUnsigned(ReadOnlySpan<byte> bytes)
    {
        long value = 0;
        for (var i = 0; i < bytes.Length; i++) value |= (long)bytes[i] << (8 * i);
        return value;
    }

    private static void WriteUnsigned(Span<byte> bytes, long value)
    {
        for (var i = 0; i < bytes.Length; i++) bytes[i] = (byte)((value >> (8 * i)) & 0xff);
    }
}

public static class ByteDiff
{
    private enum EditKind { Equal, Delete, Insert }
    private sealed record Edit(EditKind Kind, byte Value);

    public static IReadOnlyList<BinaryHunk> CreateHunks(byte[] source, byte[] target, int maximumEditDistance)
    {
        var edits = Myers(source, target, maximumEditDistance);
        var hunks = new List<BinaryHunk>();
        var sourceIndex = 0;
        var inHunk = false;
        var hunkStart = 0;
        var deleted = 0;
        var replacement = new List<byte>();

        void Flush()
        {
            if (!inHunk) return;
            hunks.Add(new BinaryHunk(hunkStart, deleted, replacement.ToArray()));
            inHunk = false;
            deleted = 0;
            replacement.Clear();
        }

        foreach (var edit in edits)
        {
            if (edit.Kind == EditKind.Equal)
            {
                Flush();
                sourceIndex++;
                continue;
            }
            if (!inHunk)
            {
                inHunk = true;
                hunkStart = sourceIndex;
            }
            if (edit.Kind == EditKind.Delete)
            {
                deleted++;
                sourceIndex++;
            }
            else
            {
                replacement.Add(edit.Value);
            }
        }
        Flush();
        return hunks;
    }

    private static IReadOnlyList<Edit> Myers(byte[] a, byte[] b, int maximumEditDistance)
    {
        var n = a.Length;
        var m = b.Length;
        var max = n + m;
        var offset = max + 1;
        var v = Enumerable.Repeat(-1, 2 * max + 3).ToArray();
        v[offset + 1] = 0;
        var trace = new List<int[]>();

        for (var d = 0; d <= max; d++)
        {
            if (d > maximumEditDistance)
                throw new InvalidDataException($"Binary edit distance exceeds relocatable safety limit ({maximumEditDistance}).");
            trace.Add((int[])v.Clone());
            for (var k = -d; k <= d; k += 2)
            {
                int x;
                if (k == -d || (k != d && v[offset + k - 1] < v[offset + k + 1]))
                    x = Math.Max(0, v[offset + k + 1]);
                else
                    x = Math.Max(0, v[offset + k - 1]) + 1;
                var y = x - k;
                while (x < n && y < m && x >= 0 && y >= 0 && a[x] == b[y])
                {
                    x++;
                    y++;
                }
                v[offset + k] = x;
                if (x >= n && y >= m)
                    return Backtrack(a, b, trace, offset);
            }
        }
        throw new InvalidDataException("Binary diff failed to converge.");
    }

    private static IReadOnlyList<Edit> Backtrack(byte[] a, byte[] b, IReadOnlyList<int[]> trace, int offset)
    {
        var edits = new List<Edit>();
        var x = a.Length;
        var y = b.Length;

        for (var d = trace.Count - 1; d >= 0; d--)
        {
            var v = trace[d];
            var k = x - y;
            int previousK;
            if (k == -d || (k != d && v[offset + k - 1] < v[offset + k + 1]))
                previousK = k + 1;
            else
                previousK = k - 1;
            var previousX = Math.Max(0, v[offset + previousK]);
            var previousY = previousX - previousK;

            while (x > previousX && y > previousY)
            {
                edits.Add(new Edit(EditKind.Equal, a[x - 1]));
                x--;
                y--;
            }
            if (d == 0) break;
            if (x == previousX)
            {
                edits.Add(new Edit(EditKind.Insert, b[y - 1]));
                y--;
            }
            else
            {
                edits.Add(new Edit(EditKind.Delete, a[x - 1]));
                x--;
            }
        }
        edits.Reverse();
        return edits;
    }
}
