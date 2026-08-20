using System.Text.Json;

namespace PMM.Core.Semantic;

public sealed record StaticItemBehaviorRuleSuggestion(
    StaticItemBehaviorRule Rule,
    bool Suggested,
    string Reason,
    int LegacyPositiveRows,
    int CoveredLegacyRows,
    int CurrentPositiveRows,
    int CurrentExtensionRows);

public static class StaticItemBehaviorRuleDetector
{
    public static StaticItemBehaviorRuleSuggestion Detect(
        SemanticDocument current,
        IReadOnlyList<SemanticProvider> staleProviders,
        SemanticInferenceResult inference)
    {
        if (staleProviders.Count < 2)
            return None("At least two providers from the same stale baseline are required for rule inference.");

        var zeroIntents = inference.Intents
            .Where(x => string.Equals(x.PropertyName, "CorruptionFactor", StringComparison.Ordinal))
            .Where(x => IsNumericZero(x.Desired.Value))
            .Select(x => x.RowId)
            .ToHashSet(StringComparer.Ordinal);

        if (zeroIntents.Count == 0)
            return None("No inferred CorruptionFactor -> 0 edits were found.");

        var commonRows = staleProviders[0].Document.Rows.Keys.AsEnumerable();
        foreach (var provider in staleProviders.Skip(1))
            commonRows = commonRows.Intersect(provider.Document.Rows.Keys, StringComparer.Ordinal);

        var legacyPositive = new HashSet<string>(StringComparer.Ordinal);
        foreach (var rowId in commonRows)
        {
            var values = new List<double>();
            var complete = true;
            foreach (var provider in staleProviders)
            {
                if (!provider.Document.Rows[rowId].Properties.TryGetValue("CorruptionFactor", out var property) ||
                    !TryReadDouble(property.Value, out var value))
                {
                    complete = false;
                    break;
                }
                values.Add(value);
            }

            if (!complete)
                continue;

            if (values.Any(x => x > 0))
                legacyPositive.Add(rowId);
        }

        var covered = legacyPositive.Count(row => zeroIntents.Contains(row));
        var currentPositive = current.Rows.Values.Count(row =>
            row.Properties.TryGetValue("CorruptionFactor", out var property) &&
            TryReadDouble(property.Value, out var value) && value > 0);
        var extensionRows = current.Rows.Values.Count(row =>
            row.Properties.TryGetValue("CorruptionFactor", out var property) &&
            TryReadDouble(property.Value, out var value) && value > 0 &&
            !zeroIntents.Contains(row.Id));

        // A behavior mod can lag a few rows behind the game/item table. Requiring
        // literal 100% coverage would reproduce the old file rather than the
        // behavior (the proven fixture is 120/123). Promotion is deliberately
        // limited to a large, near-global zeroing pattern: >=95% coverage, at
        // least 10 affected rows, and no more than a small 5%/3-row gap.
        var uncovered = legacyPositive.Count - covered;
        var coverage = legacyPositive.Count == 0 ? 0d : (double)covered / legacyPositive.Count;
        var allowedGap = Math.Max(3, (int)Math.Ceiling(legacyPositive.Count * 0.05));
        var suggested = legacyPositive.Count >= 10 && coverage >= 0.95 && uncovered <= allowedGap;
        var reason = suggested
            ? $"Observed CorruptionFactor -> 0 edits cover {covered}/{legacyPositive.Count} ({coverage:P1}) legacy positive rows, a near-global behavior pattern; extend it to {extensionRows} current positive row(s) outside the observed edit set."
            : $"Observed zero edits cover {covered}/{legacyPositive.Count} legacy positive CorruptionFactor rows; near-global no-spoil behavior was not inferred.";

        return new StaticItemBehaviorRuleSuggestion(
            suggested ? StaticItemBehaviorRule.NoSpoilAllCurrentPositiveRows : StaticItemBehaviorRule.None,
            suggested,
            reason,
            legacyPositive.Count,
            covered,
            currentPositive,
            suggested ? extensionRows : 0);
    }

    private static StaticItemBehaviorRuleSuggestion None(string reason)
        => new(StaticItemBehaviorRule.None, false, reason, 0, 0, 0, 0);

    private static bool IsNumericZero(JsonElement value)
        => TryReadDouble(value, out var number) && Math.Abs(number) <= double.Epsilon;

    private static bool TryReadDouble(JsonElement value, out double result)
    {
        if (value.ValueKind == JsonValueKind.Number && value.TryGetDouble(out result))
            return true;
        if (value.ValueKind == JsonValueKind.String)
        {
            var text = value.GetString();
            if (double.TryParse(
                    text,
                    System.Globalization.NumberStyles.Float,
                    System.Globalization.CultureInfo.InvariantCulture,
                    out result))
                return true;
        }
        result = default;
        return false;
    }
}
