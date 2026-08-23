namespace PMM.Core;

public sealed record SupersetProviderReport(
    string Provider,
    int RequestedBytes,
    string Status,
    string Reason);

public sealed record SupersetAnchorResult(
    AssetFamily Output,
    string BaseProvider,
    IReadOnlyList<SupersetProviderReport> Providers,
    int RequestedBytes,
    int ResidualAnchorBytes);

/// <summary>
/// Recognizes the important "large anchor already contains the smaller mod's
/// changes" case without rewriting either asset. This is deliberately strict:
/// every secondary provider must be current-layout relative to Vanilla, every
/// byte it changes must already exist at the same coordinate/value in the
/// selected largest anchor, and the anchor may have only a small amount of
/// unexplained coordinate drift inside the old sidecar span.
/// </summary>
public static class SupersetAnchorAdapter
{
    public const string AdapterId = "SupersetAnchor-v1";
    private const int MaximumResidualPercent = 1;
    private const int MinimumResidualAllowance = 64;
    private const int MaximumResidualRun = 16;

    public static SupersetAnchorResult Merge(
        AssetFamily vanilla,
        IReadOnlyList<(string Name, AssetFamily Family)> providers)
    {
        if (providers.Count < 2)
            throw new ArgumentException("Superset-anchor merge requires at least two providers.", nameof(providers));

        var anchor = providers
            .OrderByDescending(x => x.Family.Parts.Sum(p => p.Value.Length))
            .ThenBy(x => x.Name, StringComparer.Ordinal)
            .First();
        var secondaries = providers
            .Where(x => !string.Equals(x.Name, anchor.Name, StringComparison.Ordinal))
            .ToArray();

        var reports = new List<SupersetProviderReport>
        {
            new(anchor.Name, 0, "BASE", "Largest cooked provider selected as anchor.")
        };
        var explainedByPart = new Dictionary<string, HashSet<int>>(StringComparer.OrdinalIgnoreCase);
        var totalRequested = 0;

        foreach (var secondary in secondaries)
        {
            // The smaller provider must itself be on the installed Vanilla layout.
            var analysis = BinaryRangeMergeAdapter.AnalyzeProvider(vanilla, secondary.Family, secondary.Name);
            if (analysis.Status != BinaryProviderStatus.BinarySafe)
                throw new InvalidDataException($"{secondary.Name}: not a current-layout secondary ({analysis.Reason}).");

            var requested = 0;
            foreach (var (part, vanillaBytes) in vanilla.Parts)
            {
                if (part.Equals(".uasset", StringComparison.OrdinalIgnoreCase))
                    continue; // BinarySafe already proved it identical to Vanilla.

                var secondaryBytes = secondary.Family.Require(part);
                if (!anchor.Family.Parts.TryGetValue(part, out var anchorBytes) || anchorBytes.Length < vanillaBytes.Length)
                    throw new InvalidDataException($"{secondary.Name}: anchor cannot cover Vanilla coordinate span for {part}.");

                if (!explainedByPart.TryGetValue(part, out var explained))
                {
                    explained = new HashSet<int>();
                    explainedByPart[part] = explained;
                }

                for (var offset = 0; offset < vanillaBytes.Length; offset++)
                {
                    if (secondaryBytes[offset] == vanillaBytes[offset])
                        continue;
                    requested++;
                    totalRequested++;
                    if (anchorBytes[offset] != secondaryBytes[offset])
                        throw new InvalidDataException(
                            $"{secondary.Name}: anchor does not contain requested {part} byte at offset {offset}.");
                    explained.Add(offset);
                }
            }

            reports.Add(new SupersetProviderReport(
                secondary.Name,
                requested,
                "SUBSUMED",
                "Every current-layout byte requested by this provider is already present in the selected anchor."));
        }

        if (totalRequested == 0)
            throw new InvalidDataException("Secondary providers contain no byte delta to prove as subsumed.");

        // Guard against a hidden insertion/deletion shifting the whole old coordinate
        // space. After excluding all known secondary requests, a structurally shifted
        // anchor would leave a large/continuous residual difference across the old
        // Vanilla span. Small anchor-owned scalar/header edits are permitted.
        var residualTotal = 0;
        foreach (var (part, vanillaBytes) in vanilla.Parts)
        {
            if (part.Equals(".uasset", StringComparison.OrdinalIgnoreCase))
                continue;
            if (!anchor.Family.Parts.TryGetValue(part, out var anchorBytes) || anchorBytes.Length < vanillaBytes.Length)
                throw new InvalidDataException($"Anchor cannot cover Vanilla coordinate span for {part}.");
            explainedByPart.TryGetValue(part, out var explained);
            explained ??= new HashSet<int>();

            var residual = 0;
            var run = 0;
            var maxRun = 0;
            for (var offset = 0; offset < vanillaBytes.Length; offset++)
            {
                var differs = anchorBytes[offset] != vanillaBytes[offset] && !explained.Contains(offset);
                if (differs)
                {
                    residual++;
                    run++;
                    maxRun = Math.Max(maxRun, run);
                }
                else
                {
                    run = 0;
                }
            }

            var allowance = Math.Max(MinimumResidualAllowance, vanillaBytes.Length * MaximumResidualPercent / 100);
            if (residual > allowance || maxRun > MaximumResidualRun)
                throw new InvalidDataException(
                    $"Anchor coordinate continuity is not proven for {part}: residual={residual}/{allowance}, maxRun={maxRun}/{MaximumResidualRun}.");
            residualTotal += residual;
        }

        return new SupersetAnchorResult(
            anchor.Family.Clone(),
            anchor.Name,
            reports,
            totalRequested,
            residualTotal);
    }
}
