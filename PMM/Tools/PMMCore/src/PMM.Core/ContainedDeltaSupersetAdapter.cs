using System.Buffers.Binary;
using System.Text;

namespace PMM.Core;

public sealed record ContainedDeltaProviderReport(
    string Provider,
    int UexpHunks,
    int MetadataInsertions,
    int MetadataFields,
    string Status,
    string Reason);

public sealed record ContainedDeltaSupersetResult(
    AssetFamily Output,
    string BaseProvider,
    IReadOnlyList<ContainedDeltaProviderReport> Providers,
    int ProvenUexpHunks,
    int ProvenMetadataInsertions,
    int ProvenMetadataFields);

/// <summary>
/// Proves the conservative "larger cooked provider already contains the smaller
/// provider" case for the current Palworld UE5.1 separated .uasset + .uexp
/// package layout.
///
/// This adapter never reserializes an Unreal asset. It returns one real cooked
/// provider unchanged, and only when all of the following are proven:
///
///  * every secondary Vanilla-relative .uexp edit hunk occurs byte-for-byte at
///    the same Vanilla coordinates in the anchor;
///  * the secondary name map is Vanilla plus an appended prefix that also
///    prefixes the anchor name map;
///  * the secondary import map is Vanilla plus an appended prefix that also
///    prefixes the anchor import map;
///  * export-map semantic metadata is identical after normalizing only the
///    generated SerialSize/SerialOffset bookkeeping fields;
///  * each provider has a coherent export payload chain matching its .uexp;
///  * dependency, asset-registry and preload-dependency sections are identical;
///  * the package summary is identical after normalizing only fields that are
///    mechanically derived from the proven name/import growth or cooked sizes.
///
/// The package-layout parser is intentionally strict. It recognizes the
/// unversioned UE5.1 traditional package summary used by current Palworld and
/// rejects other layouts rather than guessing. This gives PMM a generic safe
/// contained-Blueprint proof without hard-coding asset or mod names.
/// </summary>
public static class ContainedDeltaSupersetAdapter
{
    public const string AdapterId = "ContainedDeltaSuperset-v1";
    private const int MaximumDiffPartBytes = 64 * 1024;
    private const int MaximumEditDistance = 4096;

    public static ContainedDeltaSupersetResult Merge(
        AssetFamily vanilla,
        IReadOnlyList<(string Name, AssetFamily Family)> providers)
    {
        if (providers.Count < 2)
            throw new ArgumentException("Contained-delta superset merge requires at least two providers.", nameof(providers));
        if (!vanilla.Parts.ContainsKey(".uasset") || !vanilla.Parts.ContainsKey(".uexp"))
            throw new InvalidDataException("Contained-delta superset currently requires .uasset + .uexp.");

        GuardPartSizes(vanilla, "Vanilla");
        var vanillaLayout = PalworldUe51PackageLayout.Parse(
            vanilla.Require(".uasset"), vanilla.Require(".uexp"), "Vanilla");

        // Size is only a useful ordering heuristic.  We try every real provider
        // as the prospective anchor and accept the first one that strictly
        // proves it contains every other provider.  This keeps the adapter N-way
        // and avoids assuming that the largest file is necessarily the semantic
        // superset.
        var candidates = providers
            .OrderByDescending(x => x.Family.Parts.Sum(part => part.Value.Length))
            .ThenBy(x => x.Name, StringComparer.Ordinal)
            .ToArray();
        var rejected = new List<string>();

        foreach (var anchor in candidates)
        {
            try
            {
                return MergeWithAnchor(vanilla, vanillaLayout, providers, anchor);
            }
            catch (InvalidDataException ex)
            {
                rejected.Add($"{anchor.Name}: {ex.Message}");
            }
        }

        var detail = string.Join(" | ", rejected.Take(6));
        throw new InvalidDataException(
            "No provider is a proven contained cooked-delta superset of every other provider." +
            (detail.Length == 0 ? string.Empty : " Candidates: " + detail));
    }

    private static ContainedDeltaSupersetResult MergeWithAnchor(
        AssetFamily vanilla,
        PalworldUe51PackageLayout vanillaLayout,
        IReadOnlyList<(string Name, AssetFamily Family)> providers,
        (string Name, AssetFamily Family) anchor)
    {
        RequireSameTopology(vanilla, anchor.Family, anchor.Name);
        GuardPartSizes(anchor.Family, anchor.Name);
        var anchorLayout = PalworldUe51PackageLayout.Parse(
            anchor.Family.Require(".uasset"), anchor.Family.Require(".uexp"), anchor.Name);

        ProveMetadataSuperset(vanillaLayout, anchorLayout, anchorLayout, anchor.Name, anchor.Name);

        var anchorUexpHunks = ByteDiff.CreateHunks(
            vanilla.Require(".uexp"), anchor.Family.Require(".uexp"), MaximumEditDistance);
        if (anchorUexpHunks.Count == 0)
            throw new InvalidDataException("candidate anchor contains no executable .uexp delta relative to Vanilla.");

        var anchorMetadataInsertions = CountMetadataGrowth(vanillaLayout, anchorLayout);
        var anchorMetadataFields = CountGeneratedFieldDifferences(vanillaLayout, anchorLayout);
        var reports = new List<ContainedDeltaProviderReport>
        {
            new(
                anchor.Name,
                anchorUexpHunks.Count,
                anchorMetadataInsertions,
                anchorMetadataFields,
                "BASE",
                "Real cooked provider is a valid UE5.1 contained-delta anchor with coherent .uexp/export bookkeeping.")
        };

        var provenUexp = 0;
        var provenInsertions = 0;
        var provenMetadataFields = 0;
        var secondaryCount = 0;

        foreach (var secondary in providers)
        {
            if (string.Equals(secondary.Name, anchor.Name, StringComparison.Ordinal))
                continue;

            secondaryCount++;
            RequireSameTopology(vanilla, secondary.Family, secondary.Name);
            GuardPartSizes(secondary.Family, secondary.Name);

            foreach (var part in vanilla.Parts.Keys)
            {
                if (part.Equals(".uasset", StringComparison.OrdinalIgnoreCase) ||
                    part.Equals(".uexp", StringComparison.OrdinalIgnoreCase))
                    continue;

                var vanillaPart = vanilla.Require(part);
                var secondaryPart = secondary.Family.Require(part);
                var anchorPart = anchor.Family.Require(part);
                if (!secondaryPart.SequenceEqual(vanillaPart) && !secondaryPart.SequenceEqual(anchorPart))
                    throw new InvalidDataException(
                        $"{secondary.Name}: non-identical {part} is neither Vanilla nor byte-identical to the anchor.");
            }

            var secondaryUexpHunks = ByteDiff.CreateHunks(
                vanilla.Require(".uexp"), secondary.Family.Require(".uexp"), MaximumEditDistance);
            if (secondaryUexpHunks.Count == 0)
            {
                if (FamilyEquals(vanilla, secondary.Family))
                {
                    reports.Add(new ContainedDeltaProviderReport(
                        secondary.Name, 0, 0, 0, "VANILLA_NOOP",
                        "Provider family is byte-identical to Vanilla for this asset and therefore adds no competing change."));
                    continue;
                }

                throw new InvalidDataException(
                    $"{secondary.Name}: no executable .uexp delta exists, but the cooked family is not byte-identical to Vanilla.");
            }

            foreach (var hunk in secondaryUexpHunks)
            {
                if (!anchorUexpHunks.Any(candidate => ExactHunk(candidate, hunk)))
                    throw new InvalidDataException(
                        $"{secondary.Name}: executable .uexp hunk at Vanilla offset {hunk.BaseStart} is not present exactly in the anchor.");
                provenUexp++;
            }

            var secondaryLayout = PalworldUe51PackageLayout.Parse(
                secondary.Family.Require(".uasset"), secondary.Family.Require(".uexp"), secondary.Name);

            ProveMetadataSuperset(vanillaLayout, secondaryLayout, anchorLayout, secondary.Name, anchor.Name);

            var metadataInsertions = CountMetadataGrowth(vanillaLayout, secondaryLayout);
            var metadataFields = CountGeneratedFieldDifferences(vanillaLayout, secondaryLayout);
            provenInsertions += metadataInsertions;
            provenMetadataFields += metadataFields;

            reports.Add(new ContainedDeltaProviderReport(
                secondary.Name,
                secondaryUexpHunks.Count,
                metadataInsertions,
                metadataFields,
                "SUBSUMED",
                "Every executable .uexp hunk is present exactly in the anchor; name/import maps are prefix-contained; normalized export metadata and unchanged package sections prove the secondary cooked package is structurally subsumed."));
        }

        if (secondaryCount == 0 || provenUexp == 0)
            throw new InvalidDataException("No non-trivial secondary provider delta was proven as contained.");

        return new ContainedDeltaSupersetResult(
            anchor.Family.Clone(),
            anchor.Name,
            reports,
            provenUexp,
            provenInsertions,
            provenMetadataFields);
    }

    private static void ProveMetadataSuperset(
        PalworldUe51PackageLayout vanilla,
        PalworldUe51PackageLayout candidate,
        PalworldUe51PackageLayout anchor,
        string candidateName,
        string anchorName)
    {
        if (candidate.ExportCount != vanilla.ExportCount || anchor.ExportCount != vanilla.ExportCount)
            throw new InvalidDataException(
                $"{candidateName}: contained-delta proof does not permit adding/removing export-map entries.");

        if (candidate.NameOffset != vanilla.NameOffset || anchor.NameOffset != vanilla.NameOffset)
            throw new InvalidDataException(
                $"{candidateName}: name-map start moved; current additive package proof requires the Vanilla name-map prefix to stay in place.");

        RequirePrefix(vanilla.NameMapBytes, candidate.NameMapBytes,
            $"{candidateName}: name map does not preserve Vanilla as an exact prefix.");
        RequirePrefix(candidate.NameMapBytes, anchor.NameMapBytes,
            $"{candidateName}: name-map additions are not prefix-contained in anchor {anchorName}.");

        RequirePrefix(vanilla.ImportMapBytes, candidate.ImportMapBytes,
            $"{candidateName}: import map does not preserve Vanilla as an exact prefix.");
        RequirePrefix(candidate.ImportMapBytes, anchor.ImportMapBytes,
            $"{candidateName}: import-map additions are not prefix-contained in anchor {anchorName}.");

        if (candidate.NameCount < vanilla.NameCount || anchor.NameCount < candidate.NameCount)
            throw new InvalidDataException($"{candidateName}: name-count growth is not monotonic through the anchor.");
        if (candidate.ImportCount < vanilla.ImportCount || anchor.ImportCount < candidate.ImportCount)
            throw new InvalidDataException($"{candidateName}: import-count growth is not monotonic through the anchor.");

        if (candidate.NamesReferencedFromExportDataCount < vanilla.NamesReferencedFromExportDataCount ||
            anchor.NamesReferencedFromExportDataCount < candidate.NamesReferencedFromExportDataCount)
            throw new InvalidDataException(
                $"{candidateName}: names-referenced count is not monotonic through the anchor.");
        if (candidate.NamesReferencedFromExportDataCount > candidate.NameCount ||
            anchor.NamesReferencedFromExportDataCount > anchor.NameCount)
            throw new InvalidDataException(
                $"{candidateName}: names-referenced count exceeds the package name count.");


        if (!candidate.NormalizedHeader.SequenceEqual(vanilla.NormalizedHeader))
            throw new InvalidDataException(
                $"{candidateName}: package summary changes include fields outside the proven generated count/offset bookkeeping set.");
        if (!anchor.NormalizedHeader.SequenceEqual(vanilla.NormalizedHeader))
            throw new InvalidDataException(
                $"{anchorName}: anchor package summary changes include fields outside the proven generated count/offset bookkeeping set.");

        if (candidate.NormalizedExportMap.Count != vanilla.NormalizedExportMap.Count ||
            anchor.NormalizedExportMap.Count != vanilla.NormalizedExportMap.Count)
            throw new InvalidDataException($"{candidateName}: export-map topology differs from Vanilla.");

        for (var i = 0; i < vanilla.NormalizedExportMap.Count; i++)
        {
            if (!candidate.NormalizedExportMap[i].SequenceEqual(vanilla.NormalizedExportMap[i]))
                throw new InvalidDataException(
                    $"{candidateName}: export {i} changes metadata outside generated SerialSize/SerialOffset bookkeeping.");
            if (!anchor.NormalizedExportMap[i].SequenceEqual(vanilla.NormalizedExportMap[i]))
                throw new InvalidDataException(
                    $"{anchorName}: export {i} changes metadata outside generated SerialSize/SerialOffset bookkeeping.");
        }

        RequireEqualSection(vanilla.DependsBytes, candidate.DependsBytes, candidateName, "DependsMap");
        RequireEqualSection(candidate.DependsBytes, anchor.DependsBytes, anchorName, "DependsMap");
        RequireEqualSection(vanilla.AssetRegistryBytes, candidate.AssetRegistryBytes, candidateName, "AssetRegistry");
        RequireEqualSection(candidate.AssetRegistryBytes, anchor.AssetRegistryBytes, anchorName, "AssetRegistry");
        RequireEqualSection(vanilla.PreloadDependencyBytes, candidate.PreloadDependencyBytes, candidateName, "PreloadDependencies");
        RequireEqualSection(candidate.PreloadDependencyBytes, anchor.PreloadDependencyBytes, anchorName, "PreloadDependencies");
    }

    private static int CountMetadataGrowth(PalworldUe51PackageLayout vanilla, PalworldUe51PackageLayout provider)
    {
        var count = 0;
        if (provider.NameMapBytes.Length > vanilla.NameMapBytes.Length) count++;
        if (provider.ImportMapBytes.Length > vanilla.ImportMapBytes.Length) count++;
        return count;
    }

    private static int CountGeneratedFieldDifferences(PalworldUe51PackageLayout vanilla, PalworldUe51PackageLayout provider)
    {
        var count = 0;
        foreach (var range in vanilla.GeneratedHeaderFields)
        {
            if (!vanilla.Uasset.AsSpan(range.Offset, range.Length)
                .SequenceEqual(provider.Uasset.AsSpan(range.Offset, range.Length)))
                count++;
        }

        for (var i = 0; i < vanilla.ExportCount; i++)
        {
            var vanillaExport = vanilla.ExportEntries[i];
            var providerExport = provider.ExportEntries[i];
            if (vanillaExport.SerialSize != providerExport.SerialSize) count++;
            if (vanillaExport.SerialOffset != providerExport.SerialOffset) count++;
        }
        return count;
    }

    private static void RequirePrefix(byte[] prefix, byte[] value, string message)
    {
        if (!value.AsSpan().StartsWith(prefix))
            throw new InvalidDataException(message);
    }

    private static void RequireEqualSection(byte[] expected, byte[] actual, string providerName, string section)
    {
        if (!actual.SequenceEqual(expected))
            throw new InvalidDataException($"{providerName}: {section} changed; this adapter only accepts prefix-contained name/import metadata and contained bytecode changes.");
    }

    private static bool FamilyEquals(AssetFamily left, AssetFamily right)
    {
        if (!left.Parts.Keys.ToHashSet(StringComparer.OrdinalIgnoreCase)
            .SetEquals(right.Parts.Keys))
            return false;
        foreach (var part in left.Parts.Keys)
        {
            if (!right.Parts.TryGetValue(part, out var bytes) ||
                !left.Require(part).AsSpan().SequenceEqual(bytes))
                return false;
        }
        return true;
    }

    private static void RequireSameTopology(AssetFamily vanilla, AssetFamily family, string providerName)
    {
        if (!vanilla.Parts.Keys.ToHashSet(StringComparer.OrdinalIgnoreCase)
            .SetEquals(family.Parts.Keys))
            throw new InvalidDataException($"{providerName}: cooked sidecar topology differs from Vanilla.");
    }

    private static void GuardPartSizes(AssetFamily family, string providerName)
    {
        foreach (var part in new[] { ".uasset", ".uexp" })
        {
            if (family.Require(part).Length > MaximumDiffPartBytes)
                throw new InvalidDataException($"{providerName}: contained-delta size guard exceeded for {part}.");
        }
    }

    private static bool ExactHunk(BinaryHunk left, BinaryHunk right)
        => left.BaseStart == right.BaseStart &&
           left.BaseLength == right.BaseLength &&
           left.Replacement.AsSpan().SequenceEqual(right.Replacement);

    private sealed record ByteRangeInfo(int Offset, int Length);
    private sealed record ExportEntryInfo(long SerialSize, long SerialOffset);

    private sealed class PalworldUe51PackageLayout
    {
        private const uint UassetMagic = 0x9E2A83C1;
        private const int ExportMapEntrySize = 96;
        private const int ExportSerialSizeOffset = 28;
        private const int ExportSerialOffsetOffset = 36;
        private const int ImportMapEntrySize = 32;
        private const int UexpTrailerBytes = 4;

        public required byte[] Uasset { get; init; }
        public required int NameCount { get; init; }
        public required int NameOffset { get; init; }
        public required int ImportCount { get; init; }
        public required int ImportOffset { get; init; }
        public required int ExportCount { get; init; }
        public required int ExportOffset { get; init; }
        public required int NamesReferencedFromExportDataCount { get; init; }
        public required byte[] NameMapBytes { get; init; }
        public required byte[] ImportMapBytes { get; init; }
        public required IReadOnlyList<byte[]> NormalizedExportMap { get; init; }
        public required IReadOnlyList<ExportEntryInfo> ExportEntries { get; init; }
        public required byte[] DependsBytes { get; init; }
        public required byte[] AssetRegistryBytes { get; init; }
        public required byte[] PreloadDependencyBytes { get; init; }
        public required byte[] NormalizedHeader { get; init; }
        public required IReadOnlyList<ByteRangeInfo> GeneratedHeaderFields { get; init; }

        public static PalworldUe51PackageLayout Parse(byte[] uasset, byte[] uexp, string label)
        {
            var cursor = new Cursor(uasset, label);
            if (cursor.ReadUInt32("magic") != UassetMagic)
                throw new InvalidDataException($"{label}: .uasset magic mismatch.");
            if (cursor.ReadInt32("legacy file version") != -8)
                throw new InvalidDataException($"{label}: contained-delta package proof only supports the current Palworld UE5.1 legacy version -8 layout.");
            if (cursor.ReadInt32("legacy UE3 version") != 0 ||
                cursor.ReadInt32("serialized UE4 version") != 0 ||
                cursor.ReadInt32("serialized UE5 version") != 0 ||
                cursor.ReadInt32("licensee version") != 0)
                throw new InvalidDataException($"{label}: contained-delta proof expects Palworld's unversioned UE5.1 package header.");
            if (cursor.ReadInt32("custom version count") != 0)
                throw new InvalidDataException($"{label}: custom-version container is not empty; package layout is outside the conservative profile.");

            var generatedFields = new List<ByteRangeInfo>();
            var sectionSixPos = cursor.Position;
            var sectionSixOffset = cursor.ReadInt32("section-six offset");
            generatedFields.Add(new(sectionSixPos, 4));

            _ = cursor.ReadFString("folder name");
            _ = cursor.ReadUInt32("package flags");

            var nameCountPos = cursor.Position;
            var nameCount = cursor.ReadInt32("name count");
            generatedFields.Add(new(nameCountPos, 4));
            var nameOffset = cursor.ReadInt32("name offset");

            var softObjectPathCount = cursor.ReadInt32("soft object path count");
            var softObjectPathOffsetPos = cursor.Position;
            var softObjectPathOffset = cursor.ReadInt32("soft object path offset");
            generatedFields.Add(new(softObjectPathOffsetPos, 4));

            var gatherableCount = cursor.ReadInt32("gatherable text count");
            var gatherableOffsetPos = cursor.Position;
            var gatherableOffset = cursor.ReadInt32("gatherable text offset");
            generatedFields.Add(new(gatherableOffsetPos, 4));

            var exportCount = cursor.ReadInt32("export count");
            var exportOffsetPos = cursor.Position;
            var exportOffset = cursor.ReadInt32("export offset");
            generatedFields.Add(new(exportOffsetPos, 4));

            var importCountPos = cursor.Position;
            var importCount = cursor.ReadInt32("import count");
            generatedFields.Add(new(importCountPos, 4));
            var importOffsetPos = cursor.Position;
            var importOffset = cursor.ReadInt32("import offset");
            generatedFields.Add(new(importOffsetPos, 4));

            var dependsOffsetPos = cursor.Position;
            var dependsOffset = cursor.ReadInt32("depends offset");
            generatedFields.Add(new(dependsOffsetPos, 4));

            var softPackageReferenceCount = cursor.ReadInt32("soft package reference count");
            var softPackageReferenceOffsetPos = cursor.Position;
            var softPackageReferenceOffset = cursor.ReadInt32("soft package reference offset");
            generatedFields.Add(new(softPackageReferenceOffsetPos, 4));

            var searchableNamesOffsetPos = cursor.Position;
            var searchableNamesOffset = cursor.ReadInt32("searchable names offset");
            generatedFields.Add(new(searchableNamesOffsetPos, 4));
            var thumbnailOffsetPos = cursor.Position;
            var thumbnailOffset = cursor.ReadInt32("thumbnail table offset");
            generatedFields.Add(new(thumbnailOffsetPos, 4));

            cursor.Skip(16, "package guid");

            var generationCount = cursor.ReadInt32("generation count");
            if (generationCount < 0 || generationCount > 1024)
                throw new InvalidDataException($"{label}: unreasonable generation count {generationCount}.");
            for (var i = 0; i < generationCount; i++)
            {
                var generationExportCount = cursor.ReadInt32($"generation {i} export count");
                if (generationExportCount != exportCount)
                    throw new InvalidDataException($"{label}: generation {i} export count does not match package export count.");
                var generationNameCountPos = cursor.Position;
                var generationNameCount = cursor.ReadInt32($"generation {i} name count");
                if (generationNameCount != nameCount)
                    throw new InvalidDataException($"{label}: generation {i} name count does not match package name count.");
                generatedFields.Add(new(generationNameCountPos, 4));
            }

            cursor.Skip(2 + 2 + 2 + 4, "recorded engine version");
            _ = cursor.ReadFString("recorded engine branch");
            cursor.Skip(2 + 2 + 2 + 4, "compatible engine version");
            _ = cursor.ReadFString("compatible engine branch");

            _ = cursor.ReadInt32("compression flags");
            if (cursor.ReadInt32("compressed chunk count") != 0)
                throw new InvalidDataException($"{label}: compressed chunk table is outside the conservative contained-delta profile.");
            _ = cursor.ReadUInt32("package source");

            var additionalPackages = cursor.ReadInt32("additional packages to cook count");
            if (additionalPackages < 0 || additionalPackages > 4096)
                throw new InvalidDataException($"{label}: unreasonable additional-package count {additionalPackages}.");
            for (var i = 0; i < additionalPackages; i++)
                _ = cursor.ReadFString($"additional package {i}");

            var assetRegistryOffsetPos = cursor.Position;
            var assetRegistryDataOffset = cursor.ReadInt32("asset registry data offset");
            generatedFields.Add(new(assetRegistryOffsetPos, 4));

            var bulkDataStartPos = cursor.Position;
            var bulkDataStartOffset = cursor.ReadInt64("bulk data start offset");
            generatedFields.Add(new(bulkDataStartPos, 8));

            var worldTileOffsetPos = cursor.Position;
            var worldTileOffset = cursor.ReadInt32("world tile info offset");
            generatedFields.Add(new(worldTileOffsetPos, 4));

            var chunkIdCount = cursor.ReadInt32("chunk id count");
            if (chunkIdCount < 0 || chunkIdCount > 4096)
                throw new InvalidDataException($"{label}: unreasonable chunk-id count {chunkIdCount}.");
            cursor.Skip(checked(chunkIdCount * 4), "chunk ids");

            _ = cursor.ReadInt32("preload dependency count");
            var preloadDependencyOffsetPos = cursor.Position;
            var preloadDependencyOffset = cursor.ReadInt32("preload dependency offset");
            generatedFields.Add(new(preloadDependencyOffsetPos, 4));

            var namesReferencedPos = cursor.Position;
            var namesReferencedFromExportDataCount = cursor.ReadInt32("names referenced from export data count");
            generatedFields.Add(new(namesReferencedPos, 4));

            var payloadTocOffsetPos = cursor.Position;
            var payloadTocOffset = cursor.ReadInt64("payload TOC offset");
            generatedFields.Add(new(payloadTocOffsetPos, 8));

            if (cursor.Position != nameOffset)
                throw new InvalidDataException(
                    $"{label}: parsed UE5.1 package summary ended at {cursor.Position}, but NameOffset is {nameOffset}; layout is not the proven profile.");

            if (softObjectPathCount != 0 || gatherableCount != 0 || softPackageReferenceCount != 0)
                throw new InvalidDataException(
                    $"{label}: contained-delta proof currently requires empty soft-object, gatherable-text and soft-package-reference tables.");

            if (softObjectPathOffset != importOffset)
                throw new InvalidDataException(
                    $"{label}: empty soft-object-path table offset does not track the import-map start in the proven profile.");
            if (gatherableOffset != 0 || softPackageReferenceOffset != 0 ||
                searchableNamesOffset != 0 || thumbnailOffset != 0 || worldTileOffset != 0 ||
                payloadTocOffset != -1)
                throw new InvalidDataException(
                    $"{label}: optional package offsets differ from the conservative Palworld UE5.1 profile.");
            if (namesReferencedFromExportDataCount < 0 || namesReferencedFromExportDataCount > nameCount)
                throw new InvalidDataException(
                    $"{label}: names-referenced count is outside 0..NameCount.");

            if (sectionSixOffset != uasset.Length)
                throw new InvalidDataException(
                    $"{label}: section-six offset {sectionSixOffset} does not equal separated .uasset length {uasset.Length}.");
            if (bulkDataStartOffset != (long)uasset.Length + uexp.Length - UexpTrailerBytes)
                throw new InvalidDataException(
                    $"{label}: bulk-data start offset is not coherent with .uasset + .uexp export payload sizes.");

            RequireOrdered(label, nameOffset, importOffset, exportOffset, dependsOffset, assetRegistryDataOffset, preloadDependencyOffset, uasset.Length);

            var nameMapBytes = Slice(uasset, nameOffset, importOffset, label, "name map");
            var importMapBytes = Slice(uasset, importOffset, exportOffset, label, "import map");
            if (importCount == 0)
            {
                if (importMapBytes.Length != 0)
                    throw new InvalidDataException($"{label}: non-empty import-map bytes with zero import count.");
            }
            else if (importMapBytes.Length != checked(importCount * ImportMapEntrySize))
            {
                throw new InvalidDataException(
                    $"{label}: import map length {importMapBytes.Length} is not {importCount} x {ImportMapEntrySize}; layout is outside the proven UE5.1 profile.");
            }

            if (dependsOffset - exportOffset != checked(exportCount * ExportMapEntrySize))
                throw new InvalidDataException(
                    $"{label}: export map is not {exportCount} x {ExportMapEntrySize} bytes in the proven UE5.1 layout.");

            var normalizedExportMap = new List<byte[]>(exportCount);
            var exportEntries = new List<ExportEntryInfo>(exportCount);
            long expectedSerialOffset = uasset.Length;
            long serialTotal = 0;
            for (var i = 0; i < exportCount; i++)
            {
                var start = exportOffset + i * ExportMapEntrySize;
                var record = uasset.AsSpan(start, ExportMapEntrySize).ToArray();
                var serialSize = BinaryPrimitives.ReadInt64LittleEndian(record.AsSpan(ExportSerialSizeOffset, 8));
                var serialOffset = BinaryPrimitives.ReadInt64LittleEndian(record.AsSpan(ExportSerialOffsetOffset, 8));
                if (serialSize < 0)
                    throw new InvalidDataException($"{label}: export {i} has negative serial size.");
                if (serialOffset != expectedSerialOffset)
                    throw new InvalidDataException(
                        $"{label}: export {i} serial offset {serialOffset} is not the coherent chained offset {expectedSerialOffset}.");

                expectedSerialOffset = checked(expectedSerialOffset + serialSize);
                serialTotal = checked(serialTotal + serialSize);
                exportEntries.Add(new(serialSize, serialOffset));

                record.AsSpan(ExportSerialSizeOffset, 8).Clear();
                record.AsSpan(ExportSerialOffsetOffset, 8).Clear();
                normalizedExportMap.Add(record);
            }

            if (serialTotal != uexp.Length - UexpTrailerBytes)
                throw new InvalidDataException(
                    $"{label}: export serial sizes total {serialTotal}, expected .uexp payload {uexp.Length - UexpTrailerBytes}.");

            var normalizedHeader = uasset.AsSpan(0, nameOffset).ToArray();
            foreach (var range in generatedFields)
                normalizedHeader.AsSpan(range.Offset, range.Length).Clear();

            return new PalworldUe51PackageLayout
            {
                Uasset = uasset,
                NameCount = nameCount,
                NameOffset = nameOffset,
                ImportCount = importCount,
                ImportOffset = importOffset,
                ExportCount = exportCount,
                ExportOffset = exportOffset,
                NamesReferencedFromExportDataCount = namesReferencedFromExportDataCount,
                NameMapBytes = nameMapBytes,
                ImportMapBytes = importMapBytes,
                NormalizedExportMap = normalizedExportMap,
                ExportEntries = exportEntries,
                DependsBytes = Slice(uasset, dependsOffset, assetRegistryDataOffset, label, "DependsMap"),
                AssetRegistryBytes = Slice(uasset, assetRegistryDataOffset, preloadDependencyOffset, label, "AssetRegistry"),
                PreloadDependencyBytes = Slice(uasset, preloadDependencyOffset, uasset.Length, label, "PreloadDependencies"),
                NormalizedHeader = normalizedHeader,
                GeneratedHeaderFields = generatedFields
            };
        }

        private static byte[] Slice(byte[] data, int start, int end, string label, string section)
        {
            if (start < 0 || end < start || end > data.Length)
                throw new InvalidDataException($"{label}: invalid {section} range {start}..{end} for {data.Length}-byte .uasset.");
            return data.AsSpan(start, end - start).ToArray();
        }

        private static void RequireOrdered(string label, params int[] offsets)
        {
            for (var i = 1; i < offsets.Length; i++)
            {
                if (offsets[i] < offsets[i - 1])
                    throw new InvalidDataException(
                        $"{label}: package map offsets are not monotonic at {offsets[i - 1]} -> {offsets[i]}.");
            }
        }

        private sealed class Cursor
        {
            private readonly byte[] _data;
            private readonly string _label;
            public int Position { get; private set; }

            public Cursor(byte[] data, string label)
            {
                _data = data;
                _label = label;
            }

            public int ReadInt32(string field)
            {
                Ensure(4, field);
                var value = BinaryPrimitives.ReadInt32LittleEndian(_data.AsSpan(Position, 4));
                Position += 4;
                return value;
            }

            public uint ReadUInt32(string field)
            {
                Ensure(4, field);
                var value = BinaryPrimitives.ReadUInt32LittleEndian(_data.AsSpan(Position, 4));
                Position += 4;
                return value;
            }

            public long ReadInt64(string field)
            {
                Ensure(8, field);
                var value = BinaryPrimitives.ReadInt64LittleEndian(_data.AsSpan(Position, 8));
                Position += 8;
                return value;
            }

            public string ReadFString(string field)
            {
                var length = ReadInt32($"{field} length");
                if (length == 0) return string.Empty;
                if (length == int.MinValue)
                    throw new InvalidDataException($"{_label}: invalid FString length for {field}.");

                var isUtf16 = length < 0;
                var charCount = Math.Abs(length);
                var byteCount = checked(charCount * (isUtf16 ? 2 : 1));
                Ensure(byteCount, field);
                var bytes = _data.AsSpan(Position, byteCount);
                Position += byteCount;

                if (isUtf16)
                {
                    var textBytes = bytes;
                    if (textBytes.Length >= 2 && textBytes[^2] == 0 && textBytes[^1] == 0)
                        textBytes = textBytes[..^2];
                    return Encoding.Unicode.GetString(textBytes);
                }

                if (bytes.Length >= 1 && bytes[^1] == 0)
                    bytes = bytes[..^1];
                return Encoding.UTF8.GetString(bytes);
            }

            public void Skip(int bytes, string field)
            {
                Ensure(bytes, field);
                Position += bytes;
            }

            private void Ensure(int bytes, string field)
            {
                if (bytes < 0 || Position < 0 || Position > _data.Length - bytes)
                    throw new InvalidDataException(
                        $"{_label}: truncated package while reading {field} at offset {Position}.");
            }
        }
    }
}
