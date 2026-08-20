namespace PMM.Core.Semantic;

public sealed record SemanticProvider(string Name, SemanticDocument Document);

public sealed record SemanticIntent(
    string RowId,
    string PropertyName,
    string PropertyType,
    SemanticProperty Desired,
    IReadOnlyList<string> SourceProviders,
    string Reason)
{
    public string SemanticPath => $"Rows[{RowId}].{PropertyName}";
}

public sealed record SemanticAmbiguity(
    string RowId,
    string PropertyName,
    string CurrentCanonical,
    IReadOnlyDictionary<string, string> ProviderCanonicals,
    string Reason);

public enum SemanticShapeObservationKind
{
    CurrentOnlyRow,
    ProviderOnlyRow,
    CurrentOnlyProperty,
    ProviderOnlyProperty
}

public sealed record SemanticShapeObservation(
    SemanticShapeObservationKind Kind,
    string Provider,
    string RowId,
    string? PropertyName,
    string Reason)
{
    public string SemanticPath => PropertyName is null
        ? $"Rows[{RowId}]"
        : $"Rows[{RowId}].{PropertyName}";
}

public sealed record SemanticInferenceResult(
    IReadOnlyList<SemanticIntent> Intents,
    IReadOnlyList<SemanticAmbiguity> Ambiguities,
    IReadOnlyList<SemanticShapeObservation> ShapeObservations,
    int DriftLeafCount);

public static class SemanticIntentInference
{
    public static SemanticInferenceResult Infer(
        SemanticDocument current,
        IReadOnlyList<SemanticProvider> staleProviders)
    {
        if (staleProviders.Count < 2)
        {
            throw new ArgumentException(
                "Stale-baseline inference requires at least two providers so baseline drift can be separated from provider intent.",
                nameof(staleProviders));
        }

        var duplicateProvider = staleProviders
            .GroupBy(x => x.Name, StringComparer.Ordinal)
            .FirstOrDefault(group => group.Count() > 1);
        if (duplicateProvider is not null)
        {
            throw new ArgumentException(
                $"Provider names must be unique. Duplicate: {duplicateProvider.Key}",
                nameof(staleProviders));
        }

        var intents = new List<SemanticIntent>();
        var ambiguities = new List<SemanticAmbiguity>();
        var shapeObservations = ObserveShapeDifferences(current, staleProviders);
        var driftLeaves = 0;

        var commonRows = current.Rows.Keys.AsEnumerable();
        foreach (var provider in staleProviders)
            commonRows = commonRows.Intersect(provider.Document.Rows.Keys, StringComparer.Ordinal);

        foreach (var rowId in commonRows.OrderBy(x => x, StringComparer.Ordinal))
        {
            var currentRow = current.Rows[rowId];
            var providerRows = staleProviders
                .Select(p => (p.Name, Row: p.Document.Rows[rowId]))
                .ToArray();

            var commonProperties = currentRow.Properties.Keys.AsEnumerable();
            foreach (var providerRow in providerRows)
            {
                commonProperties = commonProperties.Intersect(
                    providerRow.Row.Properties.Keys,
                    StringComparer.Ordinal);
            }

            foreach (var propertyName in commonProperties.OrderBy(x => x, StringComparer.Ordinal))
            {
                var currentProperty = currentRow.Properties[propertyName];
                var byCanonical = providerRows
                    .GroupBy(
                        x => x.Row.Properties[propertyName].CanonicalValue,
                        StringComparer.Ordinal)
                    .ToDictionary(
                        group => group.Key,
                        group => group.ToArray(),
                        StringComparer.Ordinal);

                if (byCanonical.Count == 1)
                {
                    if (!byCanonical.ContainsKey(currentProperty.CanonicalValue))
                        driftLeaves++;
                    continue;
                }

                if (byCanonical.TryGetValue(currentProperty.CanonicalValue, out _))
                {
                    var nonCurrent = byCanonical
                        .Where(x => !string.Equals(
                            x.Key,
                            currentProperty.CanonicalValue,
                            StringComparison.Ordinal))
                        .ToArray();
                    if (nonCurrent.Length == 1)
                    {
                        AddIntent(
                            intents,
                            rowId,
                            propertyName,
                            nonCurrent[0].Value,
                            "provider value differs while sibling provider matches current value");
                    }
                    else
                    {
                        ambiguities.Add(CreateAmbiguity(
                            rowId,
                            propertyName,
                            currentProperty,
                            providerRows,
                            "multiple different non-current provider values"));
                    }
                    continue;
                }

                var majority = byCanonical
                    .OrderByDescending(x => x.Value.Length)
                    .ThenBy(x => x.Key, StringComparer.Ordinal)
                    .First();
                if (majority.Value.Length > staleProviders.Count / 2)
                {
                    var outliers = byCanonical
                        .Where(x => !string.Equals(x.Key, majority.Key, StringComparison.Ordinal))
                        .ToArray();
                    if (outliers.Length == 1)
                    {
                        AddIntent(
                            intents,
                            rowId,
                            propertyName,
                            outliers[0].Value,
                            "strict provider majority treated as stale baseline; outlier treated as intended edit");
                    }
                    else
                    {
                        ambiguities.Add(CreateAmbiguity(
                            rowId,
                            propertyName,
                            currentProperty,
                            providerRows,
                            "strict stale-baseline majority exists but outliers disagree"));
                    }
                }
                else
                {
                    ambiguities.Add(CreateAmbiguity(
                        rowId,
                        propertyName,
                        currentProperty,
                        providerRows,
                        "providers disagree and none matches current; no strict baseline majority"));
                }
            }
        }

        return new SemanticInferenceResult(
            intents,
            ambiguities,
            shapeObservations,
            driftLeaves);
    }

    private static IReadOnlyList<SemanticShapeObservation> ObserveShapeDifferences(
        SemanticDocument current,
        IReadOnlyList<SemanticProvider> providers)
    {
        var observations = new List<SemanticShapeObservation>();

        foreach (var provider in providers.OrderBy(x => x.Name, StringComparer.Ordinal))
        {
            foreach (var rowId in current.Rows.Keys
                         .Except(provider.Document.Rows.Keys, StringComparer.Ordinal)
                         .OrderBy(x => x, StringComparer.Ordinal))
            {
                observations.Add(new SemanticShapeObservation(
                    SemanticShapeObservationKind.CurrentOnlyRow,
                    provider.Name,
                    rowId,
                    null,
                    "row exists in current target but not in this provider baseline"));
            }

            foreach (var rowId in provider.Document.Rows.Keys
                         .Except(current.Rows.Keys, StringComparer.Ordinal)
                         .OrderBy(x => x, StringComparer.Ordinal))
            {
                observations.Add(new SemanticShapeObservation(
                    SemanticShapeObservationKind.ProviderOnlyRow,
                    provider.Name,
                    rowId,
                    null,
                    "row exists in provider baseline but not in current target"));
            }

            foreach (var rowId in current.Rows.Keys
                         .Intersect(provider.Document.Rows.Keys, StringComparer.Ordinal)
                         .OrderBy(x => x, StringComparer.Ordinal))
            {
                var currentRow = current.Rows[rowId];
                var providerRow = provider.Document.Rows[rowId];

                foreach (var propertyName in currentRow.Properties.Keys
                             .Except(providerRow.Properties.Keys, StringComparer.Ordinal)
                             .OrderBy(x => x, StringComparer.Ordinal))
                {
                    observations.Add(new SemanticShapeObservation(
                        SemanticShapeObservationKind.CurrentOnlyProperty,
                        provider.Name,
                        rowId,
                        propertyName,
                        "property exists in current target but not in this provider baseline"));
                }

                foreach (var propertyName in providerRow.Properties.Keys
                             .Except(currentRow.Properties.Keys, StringComparer.Ordinal)
                             .OrderBy(x => x, StringComparer.Ordinal))
                {
                    observations.Add(new SemanticShapeObservation(
                        SemanticShapeObservationKind.ProviderOnlyProperty,
                        provider.Name,
                        rowId,
                        propertyName,
                        "property exists in provider baseline but not in current target"));
                }
            }
        }

        return observations;
    }

    private static void AddIntent(
        ICollection<SemanticIntent> intents,
        string rowId,
        string propertyName,
        IReadOnlyList<(string Name, SemanticRow Row)> sourceRows,
        string reason)
    {
        var desired = sourceRows[0].Row.Properties[propertyName];
        intents.Add(new SemanticIntent(
            rowId,
            propertyName,
            desired.TypeName,
            desired,
            sourceRows.Select(x => x.Name).OrderBy(x => x, StringComparer.Ordinal).ToArray(),
            reason));
    }

    private static SemanticAmbiguity CreateAmbiguity(
        string rowId,
        string propertyName,
        SemanticProperty current,
        IReadOnlyList<(string Name, SemanticRow Row)> providers,
        string reason)
        => new(
            rowId,
            propertyName,
            current.CanonicalValue,
            providers.ToDictionary(
                x => x.Name,
                x => x.Row.Properties[propertyName].CanonicalValue,
                StringComparer.Ordinal),
            reason);
}
