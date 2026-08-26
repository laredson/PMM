using System.Buffers.Binary;
using System.Globalization;
using System.Text.Json;

namespace PMM.Core.Semantic;

public enum StaticItemBehaviorRule
{
    None,
    NoSpoilAllCurrentPositiveRows
}

public static class StaticItemDataAssetAdapter
{
    public const string AdapterId = "StaticItemDataAssetAdapter/v0.4.0";

    public static IReadOnlyList<SemanticIntent> PromoteBehaviorRule(
        SemanticDocument current,
        StaticItemBehaviorRule rule)
    {
        if (rule == StaticItemBehaviorRule.None)
            return Array.Empty<SemanticIntent>();

        if (rule != StaticItemBehaviorRule.NoSpoilAllCurrentPositiveRows)
            throw new ArgumentOutOfRangeException(nameof(rule), rule, "Unsupported behavior rule.");

        using var zeroDocument = JsonDocument.Parse("0");
        var zero = zeroDocument.RootElement.Clone();
        var result = new List<SemanticIntent>();

        foreach (var row in current.Rows.Values.OrderBy(x => x.Id, StringComparer.Ordinal))
        {
            if (!row.Properties.TryGetValue("CorruptionFactor", out var property))
                continue;
            if (!TryReadDouble(property.Value, out var value) || value <= 0)
                continue;

            var desired = new SemanticProperty(
                property.Name,
                property.TypeName,
                zero,
                JsonCanonicalizer.Canonicalize(zero));
            result.Add(new SemanticIntent(
                row.Id,
                "CorruptionFactor",
                property.TypeName,
                desired,
                ["policy:no-spoil-current"],
                "explicit behavior rule: set every current positive CorruptionFactor to zero"));
        }

        return result;
    }

    public static SemanticPatchPlan CreatePlan(
        SemanticDocument current,
        byte[] currentUasset,
        byte[] currentUexp,
        byte[] cookedBaseUasset,
        byte[] cookedBaseUexp,
        IEnumerable<SemanticIntent> sourceIntents,
        StaticItemBehaviorRule behaviorRule = StaticItemBehaviorRule.None)
    {
        if (!currentUasset.AsSpan().SequenceEqual(cookedBaseUasset))
        {
            throw new InvalidDataException(
                "StaticItemDataAssetAdapter requires a cooked base whose .uasset exactly matches current Vanilla layout.");
        }
        if (currentUexp.Length != cookedBaseUexp.Length)
        {
            throw new InvalidDataException(
                "StaticItemDataAssetAdapter requires a cooked base .uexp with the current Vanilla size.");
        }

        var combined = MergeIntentSets(sourceIntents, PromoteBehaviorRule(current, behaviorRule));
        var patches = new List<SemanticBytePatch>();
        var unsupported = new List<UnsupportedIntent>();
        var conflicts = new List<PatchConflict>();

        foreach (var intent in combined.OrderBy(x => x.SemanticPath, StringComparer.Ordinal))
        {
            try
            {
                var patch = EncodeIntent(
                    current,
                    currentUasset,
                    currentUexp,
                    cookedBaseUexp,
                    intent);
                if (patch is not null)
                    patches.Add(patch);
            }
            catch (UnsupportedIntentException ex)
            {
                unsupported.Add(new UnsupportedIntent(
                    intent.SemanticPath,
                    intent.PropertyType,
                    ex.Message,
                    intent.SourceProviders));
            }
            catch (BaseConflictException ex)
            {
                conflicts.Add(new PatchConflict(
                    intent.SemanticPath,
                    ex.Message,
                    intent.SourceProviders));
            }
        }

        DetectPatchOverlaps(patches, conflicts);
        return new SemanticPatchPlan(AdapterId, patches, unsupported, conflicts);
    }

    public static SemanticPatchApplyResult Apply(byte[] cookedBaseUexp, SemanticPatchPlan plan)
    {
        if (plan.Unsupported.Count > 0)
            throw new InvalidDataException($"Patch plan has {plan.Unsupported.Count} unsupported semantic intent(s).");
        if (plan.Conflicts.Count > 0)
            throw new InvalidDataException($"Patch plan has {plan.Conflicts.Count} conflict(s).");

        var output = cookedBaseUexp.ToArray();
        foreach (var patch in plan.Patches.OrderBy(x => x.Offset))
        {
            if (patch.Offset < 0 || patch.Offset + patch.Expected.Length > output.Length)
                throw new InvalidDataException($"Patch is outside .uexp: {patch.SemanticPath}@{patch.Offset}");

            var destination = output.AsSpan(patch.Offset, patch.Expected.Length);
            if (destination.SequenceEqual(patch.Replacement))
                continue;
            if (!destination.SequenceEqual(patch.Expected))
            {
                throw new InvalidDataException(
                    $"Patch precondition failed at {patch.SemanticPath}@{patch.Offset}. " +
                    $"Expected {patch.ExpectedHex}, found {Convert.ToHexString(destination).ToLowerInvariant()}.");
            }
            patch.Replacement.AsSpan().CopyTo(destination);
        }

        var changedRanges = ByteRanges.ChangedRanges(cookedBaseUexp, output);
        ValidateAllowList(cookedBaseUexp, output, plan.Patches);
        return new SemanticPatchApplyResult(
            output,
            plan.Patches,
            Hashing.Sha256(cookedBaseUexp),
            Hashing.Sha256(output),
            changedRanges.Sum(x => x.Length),
            changedRanges);
    }

    private static IReadOnlyList<SemanticIntent> MergeIntentSets(
        IEnumerable<SemanticIntent> sourceIntents,
        IEnumerable<SemanticIntent> policyIntents)
    {
        var merged = new Dictionary<string, SemanticIntent>(StringComparer.Ordinal);
        foreach (var intent in sourceIntents.Concat(policyIntents))
        {
            if (!merged.TryGetValue(intent.SemanticPath, out var existing))
            {
                merged[intent.SemanticPath] = intent;
                continue;
            }

            if (!string.Equals(
                    existing.Desired.CanonicalValue,
                    intent.Desired.CanonicalValue,
                    StringComparison.Ordinal))
            {
                // Explicit source/user intent wins over an inferred behavior
                // policy on the same leaf. This is essential for the PMM
                // conflict model: the user resolves one parameter, while the
                // broad behavior rule continues to apply to all other rows.
                var incomingIsPolicy = intent.SourceProviders.All(x => x.StartsWith("policy:", StringComparison.Ordinal));
                var existingIsPolicy = existing.SourceProviders.All(x => x.StartsWith("policy:", StringComparison.Ordinal));
                if (incomingIsPolicy && !existingIsPolicy)
                    continue;
                if (existingIsPolicy && !incomingIsPolicy)
                {
                    merged[intent.SemanticPath] = intent;
                    continue;
                }

                throw new InvalidDataException(
                    $"Conflicting semantic intents for {intent.SemanticPath}: " +
                    $"{existing.Desired.CanonicalValue} vs {intent.Desired.CanonicalValue}");
            }

            merged[intent.SemanticPath] = existing with
            {
                SourceProviders = existing.SourceProviders
                    .Concat(intent.SourceProviders)
                    .Distinct(StringComparer.Ordinal)
                    .OrderBy(x => x, StringComparer.Ordinal)
                    .ToArray(),
                Reason = existing.Reason + " | " + intent.Reason
            };
        }
        return merged.Values.ToArray();
    }

    private static SemanticBytePatch? EncodeIntent(
        SemanticDocument current,
        byte[] currentUasset,
        byte[] currentUexp,
        byte[] cookedBaseUexp,
        SemanticIntent intent)
    {
        var row = current.RequireRow(intent.RowId);
        var currentProperty = row.RequireProperty(intent.PropertyName);
        if (string.Equals(
                currentProperty.CanonicalValue,
                intent.Desired.CanonicalValue,
                StringComparison.Ordinal))
        {
            return null;
        }

        if (IsFloatProperty(currentProperty.TypeName) && IsFloatProperty(intent.PropertyType))
        {
            var currentBytes = EncodeFloat32(currentProperty.Value);
            var desiredBytes = EncodeFloat32(intent.Desired.Value);
            var offset = LocateUniqueInRow(currentUexp, currentUasset.Length, row, currentBytes, intent.SemanticPath);
            return BuildCheckedPatch(
                cookedBaseUexp,
                intent,
                offset,
                currentBytes,
                desiredBytes,
                "fixed-size FloatProperty located uniquely inside current row serialization");
        }

        if (IsIntProperty(currentProperty.TypeName) && IsIntProperty(intent.PropertyType))
        {
            var currentBytes = EncodeInt32(currentProperty.Value);
            var desiredBytes = EncodeInt32(intent.Desired.Value);
            var offset = LocateUniqueInRow(currentUexp, currentUasset.Length, row, currentBytes, intent.SemanticPath);
            return BuildCheckedPatch(
                cookedBaseUexp,
                intent,
                offset,
                currentBytes,
                desiredBytes,
                "fixed-size IntProperty located uniquely inside current row serialization");
        }

        if (IsSoftObjectProperty(currentProperty.TypeName) && IsSoftObjectProperty(intent.PropertyType))
        {
            var currentValue = ReadTopLevelAssetPath(currentProperty.Value, intent.SemanticPath);
            var desiredValue = ReadTopLevelAssetPath(intent.Desired.Value, intent.SemanticPath);
            if (!string.Equals(currentValue.SubPathString, desiredValue.SubPathString, StringComparison.Ordinal))
            {
                throw new UnsupportedIntentException(
                    "SoftObjectPath SubPathString change is not supported by the fixed-size v0.4.0 encoder.");
            }

            var currentBytes = EncodeTopLevelAssetPath(current.NameMap, currentValue, intent.SemanticPath);
            var desiredBytes = EncodeTopLevelAssetPath(current.NameMap, desiredValue, intent.SemanticPath);
            var offset = LocateUniqueInRow(currentUexp, currentUasset.Length, row, currentBytes, intent.SemanticPath);
            return BuildCheckedPatch(
                cookedBaseUexp,
                intent,
                offset,
                currentBytes,
                desiredBytes,
                "fixed-size FTopLevelAssetPath encoded with current target NameMap");
        }

        throw new UnsupportedIntentException(
            $"Property type is not in the v0.4.0 fixed-size encoder allow-list: {currentProperty.TypeName}");
    }

    private static SemanticBytePatch? BuildCheckedPatch(
        byte[] cookedBaseUexp,
        SemanticIntent intent,
        int offset,
        byte[] expectedCurrent,
        byte[] replacement,
        string encodingReason)
    {
        var baseBytes = cookedBaseUexp.AsSpan(offset, expectedCurrent.Length);
        if (baseBytes.SequenceEqual(replacement))
            return null;
        if (!baseBytes.SequenceEqual(expectedCurrent))
        {
            throw new BaseConflictException(
                "The selected cooked base already changes the target bytes to a third value. " +
                $"Current={Convert.ToHexString(expectedCurrent).ToLowerInvariant()}, " +
                $"Base={Convert.ToHexString(baseBytes).ToLowerInvariant()}, " +
                $"Desired={Convert.ToHexString(replacement).ToLowerInvariant()}.");
        }

        return new SemanticBytePatch(
            intent.SemanticPath,
            ".uexp",
            offset,
            expectedCurrent,
            replacement,
            intent.SourceProviders,
            intent.Reason + " | " + encodingReason);
    }

    private static int LocateUniqueInRow(
        byte[] currentUexp,
        int uassetSize,
        SemanticRow row,
        byte[] pattern,
        string semanticPath)
    {
        var rowStartLong = row.SerialOffset - uassetSize;
        var rowEndLong = rowStartLong + row.SerialSize;
        if (rowStartLong < 0 || rowEndLong > currentUexp.Length || rowEndLong < rowStartLong)
        {
            throw new UnsupportedIntentException(
                $"Row serialization range is outside current .uexp for {semanticPath}: " +
                $"start={rowStartLong}, end={rowEndLong}, uexp={currentUexp.Length}.");
        }

        var rowStart = checked((int)rowStartLong);
        var rowLength = checked((int)row.SerialSize);
        var rowBytes = currentUexp.AsSpan(rowStart, rowLength);
        var matches = FindAll(rowBytes, pattern);
        if (matches.Count != 1)
        {
            throw new UnsupportedIntentException(
                $"Current property bytes are not uniquely locatable inside row serialization for {semanticPath}. " +
                $"Matches={matches.Count}. A PropertyData.Offset-enabled reader is required.");
        }

        return rowStart + matches[0];
    }

    private static List<int> FindAll(ReadOnlySpan<byte> haystack, ReadOnlySpan<byte> needle)
    {
        var result = new List<int>();
        if (needle.Length == 0 || needle.Length > haystack.Length)
            return result;

        for (var i = 0; i <= haystack.Length - needle.Length; i++)
        {
            if (haystack.Slice(i, needle.Length).SequenceEqual(needle))
                result.Add(i);
        }
        return result;
    }

    private static byte[] EncodeFloat32(JsonElement value)
    {
        if (!TryReadDouble(value, out var number))
            throw new UnsupportedIntentException("FloatProperty semantic value is not numeric.");
        if (number < -float.MaxValue || number > float.MaxValue)
            throw new UnsupportedIntentException("FloatProperty value is outside Float32 range.");

        var bytes = new byte[4];
        BinaryPrimitives.WriteInt32LittleEndian(bytes, BitConverter.SingleToInt32Bits((float)number));
        return bytes;
    }

    private static byte[] EncodeInt32(JsonElement value)
    {
        if (!TryReadInt64(value, out var number))
            throw new UnsupportedIntentException("IntProperty semantic value is not an integer.");
        if (number < int.MinValue || number > int.MaxValue)
            throw new UnsupportedIntentException("IntProperty value is outside Int32 range.");

        var bytes = new byte[4];
        BinaryPrimitives.WriteInt32LittleEndian(bytes, checked((int)number));
        return bytes;
    }

    private sealed record SoftObjectLeaf(string PackageName, string AssetName, string? SubPathString);

    private static SoftObjectLeaf ReadTopLevelAssetPath(JsonElement value, string path)
    {
        try
        {
            var assetPath = value.GetProperty("AssetPath");
            var packageName = assetPath.GetProperty("PackageName").GetString()
                ?? throw new InvalidDataException("PackageName is null.");
            var assetName = assetPath.GetProperty("AssetName").GetString()
                ?? throw new InvalidDataException("AssetName is null.");
            string? subPath = null;
            if (value.TryGetProperty("SubPathString", out var subPathToken) &&
                subPathToken.ValueKind != JsonValueKind.Null)
            {
                subPath = subPathToken.GetString();
            }
            return new SoftObjectLeaf(packageName, assetName, subPath);
        }
        catch (Exception ex) when (ex is KeyNotFoundException or InvalidOperationException or InvalidDataException)
        {
            throw new UnsupportedIntentException($"Unsupported SoftObjectProperty shape for {path}: {ex.Message}");
        }
    }

    private static byte[] EncodeTopLevelAssetPath(
        IReadOnlyList<string> nameMap,
        SoftObjectLeaf value,
        string semanticPath)
    {
        var packageIndex = IndexOf(nameMap, value.PackageName);
        var assetIndex = IndexOf(nameMap, value.AssetName);
        if (packageIndex < 0 || assetIndex < 0)
        {
            throw new UnsupportedIntentException(
                $"Desired SoftObjectProperty for {semanticPath} requires a NameMap entry not already present in current target. " +
                $"PackageFound={packageIndex >= 0}; AssetFound={assetIndex >= 0}.");
        }

        var bytes = new byte[16];
        BinaryPrimitives.WriteInt32LittleEndian(bytes.AsSpan(0, 4), packageIndex);
        BinaryPrimitives.WriteInt32LittleEndian(bytes.AsSpan(4, 4), 0);
        BinaryPrimitives.WriteInt32LittleEndian(bytes.AsSpan(8, 4), assetIndex);
        BinaryPrimitives.WriteInt32LittleEndian(bytes.AsSpan(12, 4), 0);
        return bytes;
    }

    private static int IndexOf(IReadOnlyList<string> values, string target)
    {
        for (var i = 0; i < values.Count; i++)
        {
            if (string.Equals(values[i], target, StringComparison.Ordinal))
                return i;
        }
        return -1;
    }

    private static bool IsFloatProperty(string typeName)
        => typeName.Contains("FloatPropertyData", StringComparison.Ordinal);

    private static bool IsIntProperty(string typeName)
        => typeName.Contains("IntPropertyData", StringComparison.Ordinal);

    private static bool IsSoftObjectProperty(string typeName)
        => typeName.Contains("SoftObjectPropertyData", StringComparison.Ordinal);

    private static bool TryReadDouble(JsonElement value, out double number)
    {
        if (value.ValueKind == JsonValueKind.Number && value.TryGetDouble(out number))
            return true;
        if (value.ValueKind == JsonValueKind.String &&
            double.TryParse(value.GetString(), NumberStyles.Float, CultureInfo.InvariantCulture, out number))
            return true;
        number = 0;
        return false;
    }

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

    private static void DetectPatchOverlaps(
        IReadOnlyList<SemanticBytePatch> patches,
        ICollection<PatchConflict> conflicts)
    {
        for (var i = 0; i < patches.Count; i++)
        {
            var a = patches[i];
            var aRange = new ByteRange(a.Offset, a.Offset + a.Length);
            for (var j = i + 1; j < patches.Count; j++)
            {
                var b = patches[j];
                var bRange = new ByteRange(b.Offset, b.Offset + b.Length);
                if (!aRange.Overlaps(bRange))
                    continue;

                var start = Math.Max(a.Offset, b.Offset);
                var end = Math.Min(a.Offset + a.Length, b.Offset + b.Length);
                var equal = true;
                for (var offset = start; offset < end; offset++)
                {
                    if (a.Replacement[offset - a.Offset] != b.Replacement[offset - b.Offset])
                    {
                        equal = false;
                        break;
                    }
                }

                if (!equal)
                {
                    conflicts.Add(new PatchConflict(
                        a.SemanticPath + " <> " + b.SemanticPath,
                        $"encoded patches overlap with different desired bytes at [{start},{end})",
                        a.Sources.Concat(b.Sources).Distinct(StringComparer.Ordinal).ToArray()));
                }
            }
        }
    }

    private static void ValidateAllowList(
        byte[] before,
        byte[] after,
        IReadOnlyList<SemanticBytePatch> patches)
    {
        if (before.Length != after.Length)
            throw new InvalidDataException("Patch changed .uexp length.");

        var allowed = new bool[before.Length];
        foreach (var patch in patches)
        {
            for (var i = patch.Offset; i < patch.Offset + patch.Length; i++)
                allowed[i] = true;
        }

        for (var i = 0; i < before.Length; i++)
        {
            if (before[i] != after[i] && !allowed[i])
                throw new InvalidDataException($"Output changed an unplanned byte at .uexp offset {i}.");
        }

        foreach (var patch in patches)
        {
            if (!after.AsSpan(patch.Offset, patch.Length).SequenceEqual(patch.Replacement))
                throw new InvalidDataException($"Output does not contain planned replacement for {patch.SemanticPath}.");
        }
    }

    private sealed class UnsupportedIntentException(string message) : Exception(message);
    private sealed class BaseConflictException(string message) : Exception(message);
}
