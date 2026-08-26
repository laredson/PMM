using System.Buffers.Binary;
using System.Text.Json;

namespace PMM.Core.Semantic;

public sealed record DataTableProvider(string Name, DataTableMap Map);

public sealed record DataTableConflictValue(string Kind, JsonElement Value, string Canonical);

public sealed record DataTableConflict(
    string Path,
    string RowId,
    string PropertyName,
    DataTableConflictValue Vanilla,
    IReadOnlyDictionary<string, DataTableConflictValue> Providers,
    string Reason);

public sealed record DataTableUnsupported(string Path, string Reason);

public sealed record DataTableBytePatch(
    string Path,
    int Offset,
    byte[] Expected,
    byte[] Replacement,
    IReadOnlyList<string> Sources);

public sealed record DataTableMergePlan(
    IReadOnlyList<DataTableBytePatch> Patches,
    IReadOnlyList<DataTableConflict> Conflicts,
    IReadOnlyList<DataTableUnsupported> Unsupported);

public sealed record DataTableApplyResult(byte[] Output, int ChangedBytes, string Sha256);

public static class DataTableMergeAdapter
{
    public const string AdapterId = "DataTableScalarTransfer-v2";

    public static DataTableMergePlan CreatePlan(
        DataTableMap vanilla,
        IReadOnlyList<DataTableProvider> providers,
        string baseProviderName,
        byte[] baseUexp,
        IReadOnlyDictionary<string, string>? resolutions = null)
    {
        if (providers.Count < 2)
            throw new ArgumentException("DataTable merge requires at least two providers.", nameof(providers));

        var baseProvider = providers.FirstOrDefault(x => string.Equals(x.Name, baseProviderName, StringComparison.Ordinal))
            ?? throw new InvalidDataException($"Base DataTable provider not found: {baseProviderName}");
        var secondaryProviders = providers
            .Where(x => !string.Equals(x.Name, baseProviderName, StringComparison.Ordinal))
            .ToArray();

        var patches = new List<DataTableBytePatch>();
        var conflicts = new List<DataTableConflict>();
        var unsupported = new List<DataTableUnsupported>();

        // Base-only structural additions are intentionally not enumerated here: the
        // selected cooked base already preserves them. We only need to visit Vanilla
        // rows plus rows introduced by a secondary provider, because those are the
        // places where information may need to be transferred into the base.
        var rowIds = vanilla.Rows.Keys
            .Union(secondaryProviders.SelectMany(x => x.Map.Rows.Keys), StringComparer.Ordinal)
            .OrderBy(x => x, StringComparer.Ordinal)
            .ToArray();

        foreach (var rowId in rowIds)
        {
            var hasVanillaRow = vanilla.Rows.TryGetValue(rowId, out var vanillaRow);
            var hasBaseRow = baseProvider.Map.Rows.TryGetValue(rowId, out var baseRow);

            if (!hasVanillaRow)
            {
                // A row added only by the chosen base is already preserved and needs no
                // patch. If a secondary also adds the row, accept it only when it is
                // semantically identical to the base; otherwise there is no Vanilla
                // baseline from which PMM could prove which addition should win.
                var secondariesWithRow = secondaryProviders
                    .Where(x => x.Map.Rows.TryGetValue(rowId, out _))
                    .ToArray();
                if (secondariesWithRow.Length == 0)
                    continue;
                if (!hasBaseRow)
                {
                    unsupported.Add(new DataTableUnsupported(
                        $"Rows[{rowId}]",
                        "A secondary provider adds a row that is absent from both installed Vanilla and the selected cooked base."));
                    continue;
                }
                if (secondariesWithRow.All(x => RowsEquivalent(baseRow!, x.Map.Rows[rowId])))
                    continue;

                unsupported.Add(new DataTableUnsupported(
                    $"Rows[{rowId}]",
                    "Providers disagree on a newly added row that has no installed-Vanilla baseline."));
                continue;
            }

            if (!hasBaseRow)
            {
                // The base structurally deletes this Vanilla row. Keep that deletion only
                // if no secondary provider also modifies the row. A scalar patch cannot
                // resurrect a deleted cooked row safely.
                var changedSecondary = secondaryProviders.FirstOrDefault(x =>
                    x.Map.Rows.TryGetValue(rowId, out var row) && !RowsEquivalent(vanillaRow!, row));
                if (changedSecondary is not null)
                {
                    unsupported.Add(new DataTableUnsupported(
                        $"Rows[{rowId}]",
                        $"Selected cooked base deletes this Vanilla row while {changedSecondary.Name} changes it."));
                }
                continue;
            }

            // As with rows, properties added only by the chosen base are already in the
            // cooked anchor. Secondary-added properties are inspected because they may
            // represent information that would otherwise be lost.
            var propertyNames = vanillaRow!.Properties.Keys
                .Union(
                    secondaryProviders
                        .Where(x => x.Map.Rows.ContainsKey(rowId))
                        .SelectMany(x => x.Map.Rows[rowId].Properties.Keys),
                    StringComparer.Ordinal)
                .OrderBy(x => x, StringComparer.Ordinal)
                .ToArray();

            foreach (var propertyName in propertyNames)
            {
                var path = $"Rows[{rowId}].{propertyName}";
                var hasVanillaProperty = vanillaRow.Properties.TryGetValue(propertyName, out var vanillaProperty);
                var hasBaseProperty = baseRow!.Properties.TryGetValue(propertyName, out var baseProperty);

                if (!hasVanillaProperty)
                {
                    var secondaryWithProperty = secondaryProviders
                        .Where(x => x.Map.Rows.TryGetValue(rowId, out var row) && row.Properties.ContainsKey(propertyName))
                        .ToArray();
                    if (secondaryWithProperty.Length == 0)
                        continue;
                    if (!hasBaseProperty)
                    {
                        unsupported.Add(new DataTableUnsupported(
                            path,
                            "A secondary provider adds a property that is absent from installed Vanilla and the selected cooked base."));
                        continue;
                    }
                    if (secondaryWithProperty.All(x => PropertiesEquivalent(baseProperty!, x.Map.Rows[rowId].Properties[propertyName])))
                        continue;

                    unsupported.Add(new DataTableUnsupported(
                        path,
                        "Providers disagree on a newly added property that has no installed-Vanilla baseline."));
                    continue;
                }

                if (!hasBaseProperty)
                {
                    var changedSecondary = secondaryProviders.FirstOrDefault(x =>
                        x.Map.Rows.TryGetValue(rowId, out var row) &&
                        row.Properties.TryGetValue(propertyName, out var prop) &&
                        !PropertiesEquivalent(vanillaProperty!, prop));
                    if (changedSecondary is not null)
                    {
                        unsupported.Add(new DataTableUnsupported(
                            path,
                            $"Selected cooked base deletes this Vanilla property while {changedSecondary.Name} changes it."));
                    }
                    continue;
                }

                var changed = new List<(string Name, DataTableProperty Property)>();
                var structuralDelete = false;
                foreach (var provider in providers)
                {
                    if (!provider.Map.Rows.TryGetValue(rowId, out var providerRow) ||
                        !providerRow.Properties.TryGetValue(propertyName, out var providerProperty))
                    {
                        // If the base has the property, a missing secondary property is a
                        // structural deletion request. We do not silently discard it.
                        if (!string.Equals(provider.Name, baseProviderName, StringComparison.Ordinal))
                        {
                            unsupported.Add(new DataTableUnsupported(
                                path,
                                $"Provider {provider.Name} deletes this Vanilla property; fixed-size scalar transfer cannot encode the deletion."));
                            structuralDelete = true;
                        }
                        continue;
                    }

                    if (!PropertiesEquivalent(providerProperty, vanillaProperty!))
                        changed.Add((provider.Name, providerProperty));
                }

                if (structuralDelete || changed.Count == 0)
                    continue;

                DataTableProperty desired;
                IReadOnlyList<string> sources;
                var distinct = changed
                    .GroupBy(x => PropertySignature(x.Property), StringComparer.Ordinal)
                    .ToArray();
                if (distinct.Length > 1)
                {
                    if (resolutions is null || !resolutions.TryGetValue(path, out var sourceChoice))
                    {
                        conflicts.Add(new DataTableConflict(
                            path,
                            rowId,
                            propertyName,
                            ToConflictValue(vanillaProperty!),
                            changed.ToDictionary(x => x.Name, x => ToConflictValue(x.Property), StringComparer.Ordinal),
                            "Multiple mods change the same DataTable property to different values."));
                        continue;
                    }

                    if (string.Equals(sourceChoice, "Vanilla", StringComparison.Ordinal))
                    {
                        desired = vanillaProperty!;
                        sources = ["Vanilla"];
                    }
                    else if (sourceChoice.StartsWith("Custom:", StringComparison.Ordinal))
                    {
                        desired = CreateCustomProperty(vanillaProperty!, sourceChoice["Custom:".Length..], path);
                        sources = ["Custom"];
                    }
                    else
                    {
                        var selected = changed.FirstOrDefault(x => string.Equals(x.Name, sourceChoice, StringComparison.Ordinal));
                        if (selected.Property is null)
                            throw new InvalidDataException($"Resolution for {path} names a provider that does not change the property: {sourceChoice}");
                        desired = selected.Property;
                        sources = [selected.Name];
                    }
                }
                else
                {
                    desired = distinct[0].First().Property;
                    sources = distinct[0].Select(x => x.Name).OrderBy(x => x, StringComparer.Ordinal).ToArray();
                }

                if (PropertiesEquivalent(baseProperty!, desired))
                    continue;

                if (!baseProperty!.SupportedScalar || !desired.SupportedScalar)
                {
                    unsupported.Add(new DataTableUnsupported(path, $"Property is not a supported fixed-size scalar ({baseProperty.Type})."));
                    continue;
                }
                if (!string.Equals(baseProperty.Type, desired.Type, StringComparison.Ordinal) ||
                    !string.Equals(baseProperty.Scalar.Kind, desired.Scalar.Kind, StringComparison.Ordinal))
                {
                    unsupported.Add(new DataTableUnsupported(
                        path,
                        $"Scalar representation changes from {baseProperty.Type}/{baseProperty.Scalar.Kind} to {desired.Type}/{desired.Scalar.Kind}."));
                    continue;
                }

                var expected = Encode(baseProperty.Scalar, path);
                var replacement = Encode(desired.Scalar, path);
                if (expected.Length != replacement.Length)
                {
                    unsupported.Add(new DataTableUnsupported(path, "Encoded scalar length changes."));
                    continue;
                }

                try
                {
                    var offset = LocateAtOrNearOffset(baseUexp, checked((int)baseProperty.Offset), expected, path);
                    patches.Add(new DataTableBytePatch(path, offset, expected, replacement, sources));
                }
                catch (InvalidDataException ex)
                {
                    unsupported.Add(new DataTableUnsupported(path, ex.Message));
                }
            }
        }

        DetectPatchOverlaps(patches, unsupported);
        return new DataTableMergePlan(patches, conflicts, unsupported);
    }

    public static DataTableApplyResult Apply(byte[] baseUexp, DataTableMergePlan plan)
    {
        if (plan.Conflicts.Count > 0 || plan.Unsupported.Count > 0)
            throw new InvalidDataException("DataTable merge plan is not executable until conflicts/unsupported leaves are resolved.");

        var output = baseUexp.ToArray();
        var changed = 0;
        foreach (var patch in plan.Patches.OrderBy(x => x.Offset))
        {
            if (patch.Offset < 0 || patch.Offset + patch.Expected.Length > output.Length)
                throw new InvalidDataException($"Patch is outside .uexp: {patch.Path}@{patch.Offset}");
            var target = output.AsSpan(patch.Offset, patch.Expected.Length);
            if (target.SequenceEqual(patch.Replacement))
                continue;
            if (!target.SequenceEqual(patch.Expected))
                throw new InvalidDataException($"Patch precondition failed: {patch.Path}@{patch.Offset}");
            for (var i = 0; i < patch.Expected.Length; i++)
                if (patch.Expected[i] != patch.Replacement[i]) changed++;
            patch.Replacement.CopyTo(target);
        }
        return new DataTableApplyResult(output, changed, Hashing.Sha256(output));
    }

    private static string PropertySignature(DataTableProperty property)
        => string.Concat(property.Type, "\u001f", property.Scalar.Kind, "\u001f", property.Scalar.Canonical);

    private static bool PropertiesEquivalent(DataTableProperty left, DataTableProperty right)
        => string.Equals(PropertySignature(left), PropertySignature(right), StringComparison.Ordinal);

    private static bool RowsEquivalent(DataTableRowMap left, DataTableRowMap right)
    {
        if (left.Properties.Count != right.Properties.Count)
            return false;
        foreach (var (name, property) in left.Properties)
        {
            if (!right.Properties.TryGetValue(name, out var other) || !PropertiesEquivalent(property, other))
                return false;
        }
        return true;
    }

    private static DataTableConflictValue ToConflictValue(DataTableProperty property)
        => new(property.Scalar.Kind, property.Scalar.Value.Clone(), property.Scalar.Canonical);

    private static DataTableProperty CreateCustomProperty(DataTableProperty template, string rawValue, string path)
    {
        if (!template.SupportedScalar)
            throw new InvalidDataException($"Custom value is not supported for non-scalar property {path}.");

        var raw = rawValue.Trim();
        if (raw.Length >= 2 && raw[0] == '"' && raw[^1] == '"')
            raw = raw[1..^1].Trim();

        JsonElement value;
        try
        {
            value = template.Scalar.Kind switch
            {
                "u8" => JsonSerializer.SerializeToElement(byte.Parse(raw, System.Globalization.NumberStyles.Integer, System.Globalization.CultureInfo.InvariantCulture)),
                "i8" => JsonSerializer.SerializeToElement(sbyte.Parse(raw, System.Globalization.NumberStyles.Integer, System.Globalization.CultureInfo.InvariantCulture)),
                "i16" => JsonSerializer.SerializeToElement(short.Parse(raw, System.Globalization.NumberStyles.Integer, System.Globalization.CultureInfo.InvariantCulture)),
                "u16" => JsonSerializer.SerializeToElement(ushort.Parse(raw, System.Globalization.NumberStyles.Integer, System.Globalization.CultureInfo.InvariantCulture)),
                "i32" => JsonSerializer.SerializeToElement(int.Parse(raw, System.Globalization.NumberStyles.Integer, System.Globalization.CultureInfo.InvariantCulture)),
                "u32" => JsonSerializer.SerializeToElement(uint.Parse(raw, System.Globalization.NumberStyles.Integer, System.Globalization.CultureInfo.InvariantCulture)),
                "i64" => JsonSerializer.SerializeToElement(long.Parse(raw, System.Globalization.NumberStyles.Integer, System.Globalization.CultureInfo.InvariantCulture)),
                "u64" => JsonSerializer.SerializeToElement(ulong.Parse(raw, System.Globalization.NumberStyles.Integer, System.Globalization.CultureInfo.InvariantCulture)),
                "f32" => JsonSerializer.SerializeToElement(float.Parse(raw, System.Globalization.NumberStyles.Float, System.Globalization.CultureInfo.InvariantCulture)),
                "f64" => JsonSerializer.SerializeToElement(double.Parse(raw, System.Globalization.NumberStyles.Float, System.Globalization.CultureInfo.InvariantCulture)),
                _ => throw new InvalidDataException($"Custom value is not supported for scalar kind {template.Scalar.Kind}.")
            };
        }
        catch (Exception ex) when (ex is FormatException or OverflowException)
        {
            throw new InvalidDataException($"Custom value for {path} is invalid for {template.Scalar.Kind}: {raw}", ex);
        }

        return template with { Scalar = DataTableScalar.From(template.Scalar.Kind, value) };
    }

    private static byte[] Encode(DataTableScalar scalar, string path)
    {
        try
        {
            return scalar.Kind switch
            {
                "u8" => [scalar.Value.GetByte()],
                "i8" => [unchecked((byte)scalar.Value.GetSByte())],
                "i16" => WriteInt16(scalar.Value.GetInt16()),
                "u16" => WriteUInt16(scalar.Value.GetUInt16()),
                "i32" => WriteInt32(scalar.Value.GetInt32()),
                "u32" => WriteUInt32(scalar.Value.GetUInt32()),
                "i64" => WriteInt64(scalar.Value.GetInt64()),
                "u64" => WriteUInt64(scalar.Value.GetUInt64()),
                "f32" => WriteSingle(scalar.Value.GetSingle()),
                "f64" => WriteDouble(scalar.Value.GetDouble()),
                _ => throw new InvalidDataException($"Unsupported scalar kind: {scalar.Kind}")
            };
        }
        catch (Exception ex) when (ex is InvalidOperationException or FormatException or OverflowException)
        {
            throw new InvalidDataException($"Cannot encode {path} as {scalar.Kind}: {ex.Message}", ex);
        }
    }

    private static int LocateAtOrNearOffset(byte[] bytes, int reportedOffset, byte[] expected, string path)
    {
        if (reportedOffset >= 0 && reportedOffset + expected.Length <= bytes.Length &&
            bytes.AsSpan(reportedOffset, expected.Length).SequenceEqual(expected))
            return reportedOffset;

        var start = Math.Max(0, reportedOffset - 32);
        var end = Math.Min(bytes.Length - expected.Length, reportedOffset + 32);
        var matches = new List<int>();
        for (var i = start; i <= end; i++)
            if (bytes.AsSpan(i, expected.Length).SequenceEqual(expected)) matches.Add(i);
        if (matches.Count == 1)
            return matches[0];

        throw new InvalidDataException(
            $"Reported PropertyData.Offset cannot be validated. Offset={reportedOffset}, nearbyMatches={matches.Count}.");
    }

    private static void DetectPatchOverlaps(IReadOnlyList<DataTableBytePatch> patches, ICollection<DataTableUnsupported> unsupported)
    {
        for (var i = 0; i < patches.Count; i++)
        {
            var a = patches[i];
            for (var j = i + 1; j < patches.Count; j++)
            {
                var b = patches[j];
                if (a.Offset + a.Expected.Length <= b.Offset || b.Offset + b.Expected.Length <= a.Offset)
                    continue;
                if (a.Offset == b.Offset && a.Expected.SequenceEqual(b.Expected) && a.Replacement.SequenceEqual(b.Replacement))
                    continue;
                unsupported.Add(new DataTableUnsupported(a.Path, $"Encoded patch overlaps {b.Path}."));
            }
        }
    }

    private static byte[] WriteInt16(short value) { var b = new byte[2]; BinaryPrimitives.WriteInt16LittleEndian(b, value); return b; }
    private static byte[] WriteUInt16(ushort value) { var b = new byte[2]; BinaryPrimitives.WriteUInt16LittleEndian(b, value); return b; }
    private static byte[] WriteInt32(int value) { var b = new byte[4]; BinaryPrimitives.WriteInt32LittleEndian(b, value); return b; }
    private static byte[] WriteUInt32(uint value) { var b = new byte[4]; BinaryPrimitives.WriteUInt32LittleEndian(b, value); return b; }
    private static byte[] WriteInt64(long value) { var b = new byte[8]; BinaryPrimitives.WriteInt64LittleEndian(b, value); return b; }
    private static byte[] WriteUInt64(ulong value) { var b = new byte[8]; BinaryPrimitives.WriteUInt64LittleEndian(b, value); return b; }
    private static byte[] WriteSingle(float value) { var b = new byte[4]; BinaryPrimitives.WriteInt32LittleEndian(b, BitConverter.SingleToInt32Bits(value)); return b; }
    private static byte[] WriteDouble(double value) { var b = new byte[8]; BinaryPrimitives.WriteInt64LittleEndian(b, BitConverter.DoubleToInt64Bits(value)); return b; }
}
