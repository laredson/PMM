using System.Text.Json;
using PMM.Core;
using PMM.Core.Semantic;

namespace PMM.Cli;

internal static class Program
{
    private const string CoreVersion = "0.9.0";
    private static readonly JsonSerializerOptions JsonOptions = new() { WriteIndented = true };

    public static int Main(string[] args)
    {
        try
        {
            if (args.Length == 0)
                return Usage(1);
            if (args[0] is "--version" or "version")
            {
                Console.WriteLine(CoreVersion);
                return 0;
            }
            if (args[0] == "self-test")
                return RunSelfTest();
            if (args[0] is "-h" or "--help")
                return Usage(0);

            return args[0] switch
            {
                "binary-analyze" => RunBinaryAnalyze(args[1..]),
                "binary-plan" => RunBinaryPlan(args[1..]),
                "binary-merge" => RunBinaryMerge(args[1..]),
                "superset-merge" => RunSupersetMerge(args[1..]),
                "contained-superset-merge" => RunContainedSupersetMerge(args[1..]),
                "relocatable-merge" => RunRelocatableMerge(args[1..]),
                "staticitem-merge" => RunStaticItemMerge(args[1..]),
                "datatable-merge" => RunDataTableMerge(args[1..]),
                _ => Usage(1)
            };
        }
        catch (Exception ex)
        {
            Console.Error.WriteLine(ex);
            return 2;
        }
    }

    private static int RunSelfTest()
    {
        // Regression gate for the N-provider quasi-duplicate contract used by
        // MultiJump Double / Triple / Quad. All variants share one cooked
        // layout and disagree on exactly one .uexp byte. A fourth provider
        // such as Fly may still be composed independently by the relocatable
        // adapter in the real fixture.
        const string logicalPath = "Pal/Content/Test/BP_PlayerBase";
        var vanilla = new AssetFamily(
            logicalPath,
            new Dictionary<string, byte[]>(StringComparer.OrdinalIgnoreCase)
            {
                [".uasset"] = [0x10, 0x20, 0x30, 0x40],
                [".uexp"] = [0xAA, 0x01, 0xBB, 0xCC]
            });

        AssetFamily Variant(byte requestedJumpCount)
            => new(
                logicalPath,
                new Dictionary<string, byte[]>(StringComparer.OrdinalIgnoreCase)
                {
                    [".uasset"] = [0x10, 0x20, 0x30, 0x40],
                    [".uexp"] = [0xAA, requestedJumpCount, 0xBB, 0xCC]
                });

        var providers = new[]
        {
            (Name: "Double", Family: Variant(2)),
            (Name: "Triple", Family: Variant(3)),
            (Name: "Quad", Family: Variant(4))
        };

        var planned = RelocatableDeltaAdapter.Merge(vanilla, providers);
        if (planned.Conflicts.Count != 1)
            throw new InvalidDataException($"N-provider self-test expected one conflict, got {planned.Conflicts.Count}.");

        var conflict = planned.Conflicts[0];
        if (!conflict.SupportsVanilla || !conflict.SupportsCustom ||
            conflict.RequestedValues.Count != 3 ||
            !conflict.RequestedValues.TryGetValue("Double", out var doubleValue) || doubleValue != 2 ||
            !conflict.RequestedValues.TryGetValue("Triple", out var tripleValue) || tripleValue != 3 ||
            !conflict.RequestedValues.TryGetValue("Quad", out var quadValue) || quadValue != 4)
        {
            throw new InvalidDataException("N-provider self-test did not expose Double/Triple/Quad as one value-level conflict.");
        }

        var resolved = RelocatableDeltaAdapter.Merge(
            vanilla,
            providers,
            new Dictionary<string, string>(StringComparer.Ordinal) { [conflict.Key] = "Triple" });
        if (resolved.Conflicts.Count != 0 || resolved.Output.Require(".uexp")[1] != 3)
            throw new InvalidDataException("N-provider self-test failed to resolve the shared value to Triple=3.");

        var custom = RelocatableDeltaAdapter.Merge(
            vanilla,
            providers,
            new Dictionary<string, string>(StringComparer.Ordinal) { [conflict.Key] = "Custom:5" });
        if (custom.Conflicts.Count != 0 || custom.Output.Require(".uexp")[1] != 5)
            throw new InvalidDataException("N-provider self-test failed to encode Custom=5.");

        const string duplicateRowsJson = "{\"kind\":\"DataTable\",\"asset\":\"synthetic\",\"rows\":[{\"id\":\"RAID_NightLady_Dark\",\"properties\":[]},{\"id\":\"RAID_NightLady_Dark\",\"properties\":[]}]}";
        var duplicateMap = DataTableMap.Parse(duplicateRowsJson);
        if (duplicateMap.Rows.Count != 2 ||
            !duplicateMap.Rows.ContainsKey("RAID_NightLady_Dark#1") ||
            !duplicateMap.Rows.ContainsKey("RAID_NightLady_Dark#2"))
        {
            throw new InvalidDataException("DataTable duplicate-row self-test failed to preserve occurrence-qualified identities.");
        }

        Console.WriteLine($"PMMCORE_SELFTEST_OK {CoreVersion}");
        Console.WriteLine("PMMCORE_SELFTEST_NPROVIDER_OK Double=2 Triple=3 Quad=4 Custom=5");
        Console.WriteLine("PMMCORE_SELFTEST_DATATABLE_DUPLICATES_OK RAID_NightLady_Dark#1 RAID_NightLady_Dark#2");
        return 0;
    }

    private static int Usage(int exitCode)
    {
        Console.WriteLine($"PMMCore v{CoreVersion}");
        Console.WriteLine();
        Console.WriteLine("Commands:");
        Console.WriteLine("  self-test");
        Console.WriteLine("  binary-analyze --vanilla-root <dir> --asset <logical/path> --provider <Name=dir> [--provider ...]");
        Console.WriteLine("  binary-plan --vanilla-root <dir> --asset <logical/path> --provider <Name=dir> [--provider ...] --report <file>");
        Console.WriteLine("  binary-merge --vanilla-root <dir> --asset <logical/path> --provider <Name=dir> [--provider ...] [--resolutions <file>] --out-root <dir>");
        Console.WriteLine("  superset-merge --vanilla-root <dir> --asset <logical/path> --provider <Name=dir> [--provider ...] --out-root <dir> --report <file>");
        Console.WriteLine("  contained-superset-merge --vanilla-root <dir> --asset <logical/path> --provider <Name=dir> [--provider ...] --out-root <dir> --report <file>");
        Console.WriteLine("  relocatable-merge --vanilla-root <dir> --asset <logical/path> --provider <Name=dir> [--provider ...] [--resolutions <file>] --out-root <dir> --report <file>");
        Console.WriteLine("  staticitem-merge --current-json <file> --current-uasset <file> --current-uexp <file> --base-uasset <file> --base-uexp <file> --stale-provider <Name=json> [--stale-provider ...] [--resolutions <file>] --behavior <auto|none|no-spoil-current> --out-uasset <file> --out-uexp <file> --report <file>");
        Console.WriteLine("  datatable-merge --vanilla-map <file> --base-provider <Name> --base-map <file> --base-uasset <file> --base-uexp <file> --provider-map <Name=file> [--provider-map ...] [--resolutions <file>] --out-uasset <file> --out-uexp <file> --report <file>");
        return exitCode;
    }

    private static int RunBinaryAnalyze(string[] args)
    {
        var parsed = CliArgs.Parse(args);
        var vanillaRoot = parsed.RequireSingle("--vanilla-root");
        var asset = parsed.RequireSingle("--asset");
        var providers = ParseProviders(parsed.RequireMany("--provider"));
        var vanilla = AssetFamily.FromDirectory(vanillaRoot, asset);

        var analyses = providers
            .Select(provider => BinaryRangeMergeAdapter.AnalyzeProvider(
                vanilla,
                AssetFamily.FromDirectory(provider.Root, asset),
                provider.Name))
            .ToArray();

        Console.WriteLine(JsonSerializer.Serialize(analyses, JsonOptions));
        return analyses.All(x => x.Status == BinaryProviderStatus.BinarySafe) ? 0 : 4;
    }


    private static int RunBinaryPlan(string[] args)
    {
        var parsed = CliArgs.Parse(args);
        var vanillaRoot = parsed.RequireSingle("--vanilla-root");
        var asset = parsed.RequireSingle("--asset");
        var reportPath = parsed.RequireSingle("--report");
        var providers = ParseProviders(parsed.RequireMany("--provider"));
        var vanilla = AssetFamily.FromDirectory(vanillaRoot, asset);
        var providerFamilies = providers
            .Select(provider => (provider.Name, Family: AssetFamily.FromDirectory(provider.Root, asset)))
            .ToArray();
        var result = BinaryRangeMergeAdapter.Plan(vanilla, providerFamilies);
        var report = new
        {
            schema = 1,
            adapter = "BinaryRangeMerge-v2",
            status = result.Conflicts.Count == 0 ? "OK" : "CONFLICT",
            patchedBytes = result.PatchedByteCount,
            conflicts = result.Conflicts.Select(x => new
            {
                key = BinaryRangeMergeAdapter.ConflictKey(x.Part, x.Offset),
                part = x.Part,
                offset = x.Offset,
                vanilla = x.Vanilla,
                requestedValues = x.RequestedValues
            }),
            providers = result.Providers
        };
        WriteJson(reportPath, report);
        Console.WriteLine(JsonSerializer.Serialize(report, JsonOptions));
        return result.Conflicts.Count == 0 ? 0 : 5;
    }

    private static int RunBinaryMerge(string[] args)
    {
        var parsed = CliArgs.Parse(args);
        var vanillaRoot = parsed.RequireSingle("--vanilla-root");
        var asset = parsed.RequireSingle("--asset");
        var outRoot = parsed.RequireSingle("--out-root");
        var providers = ParseProviders(parsed.RequireMany("--provider"));
        var vanilla = AssetFamily.FromDirectory(vanillaRoot, asset);
        var providerFamilies = providers
            .Select(provider => (
                provider.Name,
                Family: AssetFamily.FromDirectory(provider.Root, asset)))
            .ToArray();

        IReadOnlyDictionary<string, string>? resolutions = null;
        var resolutionPath = parsed.OptionalSingle("--resolutions");
        if (!string.IsNullOrWhiteSpace(resolutionPath))
        {
            resolutions = JsonSerializer.Deserialize<Dictionary<string, string>>(File.ReadAllText(resolutionPath!))
                ?? new Dictionary<string, string>(StringComparer.Ordinal);
        }

        var result = BinaryRangeMergeAdapter.Merge(vanilla, providerFamilies, resolutions);
        result.Output.WriteToDirectory(outRoot);
        Console.WriteLine(JsonSerializer.Serialize(new
        {
            status = "OK",
            asset = result.Output.LogicalPathWithoutExtension,
            patchedBytes = result.PatchedByteCount,
            providers = result.Providers,
            outputs = result.Output.Parts.ToDictionary(
                x => x.Key,
                x => new { size = x.Value.Length, sha256 = Hashing.Sha256(x.Value) })
        }, JsonOptions));
        return 0;
    }


    private static int RunSupersetMerge(string[] args)
    {
        var parsed = CliArgs.Parse(args);
        var vanillaRoot = parsed.RequireSingle("--vanilla-root");
        var asset = parsed.RequireSingle("--asset");
        var outRoot = parsed.RequireSingle("--out-root");
        var reportPath = parsed.RequireSingle("--report");
        var providers = ParseProviders(parsed.RequireMany("--provider"));
        var vanilla = AssetFamily.FromDirectory(vanillaRoot, asset);
        var families = providers
            .Select(provider => (provider.Name, Family: AssetFamily.FromDirectory(provider.Root, asset)))
            .ToArray();

        try
        {
            var result = SupersetAnchorAdapter.Merge(vanilla, families);
            result.Output.WriteToDirectory(outRoot);
            var report = new
            {
                schema = 1,
                adapter = SupersetAnchorAdapter.AdapterId,
                status = "OK",
                asset = result.Output.LogicalPathWithoutExtension,
                baseProvider = result.BaseProvider,
                requestedBytes = result.RequestedBytes,
                residualAnchorBytes = result.ResidualAnchorBytes,
                providers = result.Providers,
                outputs = result.Output.Parts.ToDictionary(
                    x => x.Key,
                    x => new { size = x.Value.Length, sha256 = Hashing.Sha256(x.Value) })
            };
            WriteJson(reportPath, report);
            Console.WriteLine(JsonSerializer.Serialize(report, JsonOptions));
            return 0;
        }
        catch (InvalidDataException ex)
        {
            var report = new
            {
                schema = 1,
                adapter = SupersetAnchorAdapter.AdapterId,
                status = "UNSUPPORTED",
                reason = ex.Message
            };
            WriteJson(reportPath, report);
            Console.WriteLine(JsonSerializer.Serialize(report, JsonOptions));
            return 5;
        }
    }


    private static int RunContainedSupersetMerge(string[] args)
    {
        var parsed = CliArgs.Parse(args);
        var vanillaRoot = parsed.RequireSingle("--vanilla-root");
        var asset = parsed.RequireSingle("--asset");
        var outRoot = parsed.RequireSingle("--out-root");
        var reportPath = parsed.RequireSingle("--report");
        var providers = ParseProviders(parsed.RequireMany("--provider"));
        var vanilla = AssetFamily.FromDirectory(vanillaRoot, asset);
        var families = providers
            .Select(provider => (provider.Name, Family: AssetFamily.FromDirectory(provider.Root, asset)))
            .ToArray();

        try
        {
            var result = ContainedDeltaSupersetAdapter.Merge(vanilla, families);
            result.Output.WriteToDirectory(outRoot);
            var report = new
            {
                schema = 1,
                adapter = ContainedDeltaSupersetAdapter.AdapterId,
                status = "OK",
                asset = result.Output.LogicalPathWithoutExtension,
                baseProvider = result.BaseProvider,
                provenUexpHunks = result.ProvenUexpHunks,
                provenMetadataInsertions = result.ProvenMetadataInsertions,
                provenMetadataFields = result.ProvenMetadataFields,
                providers = result.Providers,
                outputs = result.Output.Parts.ToDictionary(
                    x => x.Key,
                    x => new { size = x.Value.Length, sha256 = Hashing.Sha256(x.Value) })
            };
            WriteJson(reportPath, report);
            Console.WriteLine(JsonSerializer.Serialize(report, JsonOptions));
            return 0;
        }
        catch (InvalidDataException ex)
        {
            var report = new
            {
                schema = 1,
                adapter = ContainedDeltaSupersetAdapter.AdapterId,
                status = "UNSUPPORTED",
                reason = ex.Message
            };
            WriteJson(reportPath, report);
            Console.WriteLine(JsonSerializer.Serialize(report, JsonOptions));
            return 5;
        }
    }


    private static int RunRelocatableMerge(string[] args)
    {
        var parsed = CliArgs.Parse(args);
        var vanillaRoot = parsed.RequireSingle("--vanilla-root");
        var asset = parsed.RequireSingle("--asset");
        var outRoot = parsed.RequireSingle("--out-root");
        var reportPath = parsed.RequireSingle("--report");
        var providers = ParseProviders(parsed.RequireMany("--provider"));
        var vanilla = AssetFamily.FromDirectory(vanillaRoot, asset);
        var families = providers
            .Select(provider => (provider.Name, Family: AssetFamily.FromDirectory(provider.Root, asset)))
            .ToArray();

        IReadOnlyDictionary<string, string>? resolutions = null;
        var resolutionPath = parsed.OptionalSingle("--resolutions");
        if (!string.IsNullOrWhiteSpace(resolutionPath))
        {
            resolutions = JsonSerializer.Deserialize<Dictionary<string, string>>(File.ReadAllText(resolutionPath!))
                ?? new Dictionary<string, string>(StringComparer.Ordinal);
        }

        try
        {
            var result = RelocatableDeltaAdapter.Merge(vanilla, families, resolutions);
            var hasConflicts = result.Conflicts.Count > 0;
            if (!hasConflicts)
                result.Output.WriteToDirectory(outRoot);

            var report = new
            {
                schema = 2,
                adapter = RelocatableDeltaAdapter.AdapterId,
                status = hasConflicts ? "CONFLICT" : "OK",
                asset = result.Output.LogicalPathWithoutExtension,
                baseProvider = result.BaseProvider,
                appliedHunks = result.AppliedHunks,
                conflicts = result.Conflicts.Select(x => new
                {
                    key = x.Key,
                    part = x.Part,
                    offset = x.Offset,
                    supportsVanilla = x.SupportsVanilla,
                    supportsCustom = x.SupportsCustom,
                    vanillaMeaning = x.VanillaMeaning,
                    requestedValues = x.RequestedValues
                }),
                providers = result.Providers,
                outputs = hasConflicts
                    ? null
                    : result.Output.Parts.ToDictionary(
                        x => x.Key,
                        x => new { size = x.Value.Length, sha256 = Hashing.Sha256(x.Value) })
            };
            WriteJson(reportPath, report);
            Console.WriteLine(JsonSerializer.Serialize(report, JsonOptions));
            return hasConflicts ? 5 : 0;
        }
        catch (InvalidDataException ex)
        {
            var report = new
            {
                schema = 2,
                adapter = RelocatableDeltaAdapter.AdapterId,
                status = "UNSUPPORTED",
                reason = ex.Message
            };
            WriteJson(reportPath, report);
            Console.WriteLine(JsonSerializer.Serialize(report, JsonOptions));
            return 5;
        }
    }

    private static int RunStaticItemMerge(string[] args)
    {
        var parsed = CliArgs.Parse(args);
        var currentJsonPath = parsed.RequireSingle("--current-json");
        var currentUassetPath = parsed.RequireSingle("--current-uasset");
        var currentUexpPath = parsed.RequireSingle("--current-uexp");
        var baseUassetPath = parsed.RequireSingle("--base-uasset");
        var baseUexpPath = parsed.RequireSingle("--base-uexp");
        var stale = ParseProviders(parsed.RequireMany("--stale-provider"));
        var behaviorText = parsed.OptionalSingle("--behavior") ?? "auto";
        var outUasset = parsed.RequireSingle("--out-uasset");
        var outUexp = parsed.RequireSingle("--out-uexp");
        var reportPath = parsed.RequireSingle("--report");

        if (stale.Count < 2)
            throw new InvalidDataException("Static-item stale-baseline inference requires at least two providers in the same baseline group.");

        IReadOnlyDictionary<string, string>? resolutions = null;
        var resolutionPath = parsed.OptionalSingle("--resolutions");
        if (!string.IsNullOrWhiteSpace(resolutionPath))
        {
            resolutions = JsonSerializer.Deserialize<Dictionary<string, string>>(File.ReadAllText(resolutionPath!))
                ?? new Dictionary<string, string>(StringComparer.Ordinal);
        }

        var current = SemanticDocument.Parse(File.ReadAllBytes(currentJsonPath));
        var staleProviders = stale
            .Select(x => new SemanticProvider(x.Name, SemanticDocument.Parse(File.ReadAllBytes(x.Root))))
            .ToArray();
        var inference = SemanticIntentInference.Infer(current, staleProviders);
        var suggestion = StaticItemBehaviorRuleDetector.Detect(current, staleProviders, inference);
        var behavior = ParseBehavior(behaviorText, suggestion);

        var resolvedIntents = inference.Intents.ToList();
        var unresolvedAmbiguities = new List<SemanticAmbiguity>();
        foreach (var ambiguity in inference.Ambiguities)
        {
            var path = $"Rows[{ambiguity.RowId}].{ambiguity.PropertyName}";
            if (resolutions is null || !resolutions.TryGetValue(path, out var choice) || string.IsNullOrWhiteSpace(choice))
            {
                unresolvedAmbiguities.Add(ambiguity);
                continue;
            }

            if (string.Equals(choice, "Vanilla", StringComparison.Ordinal))
                continue;

            var currentProperty = current.RequireRow(ambiguity.RowId).RequireProperty(ambiguity.PropertyName);
            SemanticProperty desired;
            IReadOnlyList<string> sources;
            if (choice.StartsWith("Custom:", StringComparison.Ordinal))
            {
                if (!SupportsStaticCustomValue(currentProperty.TypeName))
                    throw new InvalidDataException($"Static-item resolution {path} does not support Custom for {currentProperty.TypeName}.");
                desired = CreateStaticCustomProperty(currentProperty, choice["Custom:".Length..], path);
                sources = ["Custom"];
            }
            else
            {
                var selected = staleProviders.FirstOrDefault(x => string.Equals(x.Name, choice, StringComparison.Ordinal));
                if (selected is null)
                    throw new InvalidDataException($"Static-item resolution {path} names an invalid provider/value: {choice}");
                desired = selected.Document.RequireRow(ambiguity.RowId).RequireProperty(ambiguity.PropertyName);
                sources = [selected.Name];
            }

            resolvedIntents.Add(new SemanticIntent(
                ambiguity.RowId,
                ambiguity.PropertyName,
                desired.TypeName,
                desired,
                sources,
                "explicit user resolution for conflicting stale-provider values"));
        }

        var currentUasset = File.ReadAllBytes(currentUassetPath);
        var currentUexp = File.ReadAllBytes(currentUexpPath);
        var baseUasset = File.ReadAllBytes(baseUassetPath);
        var baseUexp = File.ReadAllBytes(baseUexpPath);

        var plan = StaticItemDataAssetAdapter.CreatePlan(
            current,
            currentUasset,
            currentUexp,
            baseUasset,
            baseUexp,
            resolvedIntents,
            behavior);

        var conflictProjection = unresolvedAmbiguities.Select(ambiguity =>
        {
            var currentProperty = current.RequireRow(ambiguity.RowId).RequireProperty(ambiguity.PropertyName);
            return new
            {
                path = $"Rows[{ambiguity.RowId}].{ambiguity.PropertyName}",
                rowId = ambiguity.RowId,
                propertyName = ambiguity.PropertyName,
                propertyType = currentProperty.TypeName,
                vanilla = currentProperty.Value,
                providers = staleProviders.ToDictionary(
                    x => x.Name,
                    x => x.Document.RequireRow(ambiguity.RowId).RequireProperty(ambiguity.PropertyName).Value,
                    StringComparer.Ordinal),
                supportsVanilla = true,
                supportsCustom = SupportsStaticCustomValue(currentProperty.TypeName),
                reason = ambiguity.Reason
            };
        }).ToArray();

        var report = new
        {
            schema = 2,
            adapter = StaticItemDataAssetAdapter.AdapterId,
            behaviorRequested = behaviorText,
            behaviorApplied = behavior.ToString(),
            behaviorSuggestion = suggestion,
            inference = new
            {
                intents = inference.Intents.Count,
                ambiguities = conflictProjection,
                shapeObservations = inference.ShapeObservations,
                driftLeaves = inference.DriftLeafCount
            },
            plan = new
            {
                patches = plan.Patches.Select(x => new
                {
                    path = x.SemanticPath,
                    part = x.Part,
                    offset = x.Offset,
                    length = x.Length,
                    expectedHex = x.ExpectedHex,
                    replacementHex = x.ReplacementHex,
                    sources = x.Sources,
                    reason = x.Reason
                }),
                unsupported = plan.Unsupported,
                conflicts = plan.Conflicts
            },
            inputs = new
            {
                currentUassetSha256 = Hashing.Sha256(currentUasset),
                currentUexpSha256 = Hashing.Sha256(currentUexp),
                baseUassetSha256 = Hashing.Sha256(baseUasset),
                baseUexpSha256 = Hashing.Sha256(baseUexp)
            }
        };
        WriteJson(reportPath, report);

        if (unresolvedAmbiguities.Count > 0 ||
            inference.ShapeObservations.Count > 0 ||
            plan.Unsupported.Count > 0 ||
            plan.Conflicts.Count > 0)
        {
            Console.WriteLine(JsonSerializer.Serialize(report, JsonOptions));
            return 5;
        }

        var applied = StaticItemDataAssetAdapter.Apply(baseUexp, plan);
        Directory.CreateDirectory(Path.GetDirectoryName(Path.GetFullPath(outUasset))!);
        Directory.CreateDirectory(Path.GetDirectoryName(Path.GetFullPath(outUexp))!);
        File.WriteAllBytes(outUasset, baseUasset);
        File.WriteAllBytes(outUexp, applied.Output);

        var finalReport = new
        {
            schema = 2,
            adapter = StaticItemDataAssetAdapter.AdapterId,
            status = "OK",
            behaviorRequested = behaviorText,
            behaviorApplied = behavior.ToString(),
            behaviorSuggestion = suggestion,
            inference = new
            {
                intents = inference.Intents.Count,
                ambiguities = 0,
                shapeObservations = inference.ShapeObservations.Count,
                driftLeaves = inference.DriftLeafCount
            },
            patches = plan.Patches.Count,
            changedBytes = applied.ChangedByteCount,
            outputUassetSha256 = Hashing.Sha256(baseUasset),
            outputUexpSha256 = applied.OutputSha256,
            patchPlan = plan.Patches.Select(x => new
            {
                path = x.SemanticPath,
                part = x.Part,
                offset = x.Offset,
                length = x.Length,
                sources = x.Sources,
                reason = x.Reason
            })
        };
        WriteJson(reportPath, finalReport);
        Console.WriteLine(JsonSerializer.Serialize(finalReport, JsonOptions));
        return 0;
    }


    private static int RunDataTableMerge(string[] args)
    {
        var parsed = CliArgs.Parse(args);
        var vanillaMapPath = parsed.RequireSingle("--vanilla-map");
        var baseProvider = parsed.RequireSingle("--base-provider");
        var baseMapPath = parsed.RequireSingle("--base-map");
        var baseUassetPath = parsed.RequireSingle("--base-uasset");
        var baseUexpPath = parsed.RequireSingle("--base-uexp");
        var outUasset = parsed.RequireSingle("--out-uasset");
        var outUexp = parsed.RequireSingle("--out-uexp");
        var reportPath = parsed.RequireSingle("--report");
        var providerMaps = ParseProviders(parsed.RequireMany("--provider-map"));

        var vanilla = DataTableMap.Parse(File.ReadAllBytes(vanillaMapPath));
        var providers = providerMaps
            .Select(x => new DataTableProvider(x.Name, DataTableMap.Parse(File.ReadAllBytes(x.Root))))
            .ToArray();
        var baseMap = DataTableMap.Parse(File.ReadAllBytes(baseMapPath));
        var mapMatch = providers.FirstOrDefault(x => string.Equals(x.Name, baseProvider, StringComparison.Ordinal));
        if (mapMatch is null)
            throw new InvalidDataException($"Base provider is not present in --provider-map: {baseProvider}");
        if (!string.Equals(mapMatch.Map.Asset, baseMap.Asset, StringComparison.OrdinalIgnoreCase) &&
            !string.IsNullOrWhiteSpace(mapMatch.Map.Asset) && !string.IsNullOrWhiteSpace(baseMap.Asset))
            throw new InvalidDataException("--base-map does not match the named base provider map.");

        IReadOnlyDictionary<string, string>? resolutions = null;
        var resolutionPath = parsed.OptionalSingle("--resolutions");
        if (!string.IsNullOrWhiteSpace(resolutionPath))
        {
            resolutions = JsonSerializer.Deserialize<Dictionary<string, string>>(File.ReadAllText(resolutionPath!))
                ?? new Dictionary<string, string>(StringComparer.Ordinal);
        }

        var baseUasset = File.ReadAllBytes(baseUassetPath);
        var baseUexp = File.ReadAllBytes(baseUexpPath);
        var plan = DataTableMergeAdapter.CreatePlan(vanilla, providers, baseProvider, baseUexp, resolutions);

        var report = new
        {
            schema = 1,
            adapter = DataTableMergeAdapter.AdapterId,
            baseProvider,
            patches = plan.Patches.Select(x => new
            {
                path = x.Path,
                offset = x.Offset,
                length = x.Expected.Length,
                sources = x.Sources
            }),
            conflicts = plan.Conflicts,
            unsupported = plan.Unsupported
        };
        WriteJson(reportPath, report);

        if (plan.Conflicts.Count > 0 || plan.Unsupported.Count > 0)
        {
            Console.WriteLine(JsonSerializer.Serialize(report, JsonOptions));
            return 5;
        }

        var applied = DataTableMergeAdapter.Apply(baseUexp, plan);
        Directory.CreateDirectory(Path.GetDirectoryName(Path.GetFullPath(outUasset))!);
        Directory.CreateDirectory(Path.GetDirectoryName(Path.GetFullPath(outUexp))!);
        File.WriteAllBytes(outUasset, baseUasset);
        File.WriteAllBytes(outUexp, applied.Output);

        var finalReport = new
        {
            schema = 1,
            adapter = DataTableMergeAdapter.AdapterId,
            status = "OK",
            baseProvider,
            patches = plan.Patches.Count,
            changedBytes = applied.ChangedBytes,
            outputUassetSha256 = Hashing.Sha256(baseUasset),
            outputUexpSha256 = applied.Sha256
        };
        WriteJson(reportPath, finalReport);
        Console.WriteLine(JsonSerializer.Serialize(finalReport, JsonOptions));
        return 0;
    }

    private static bool SupportsStaticCustomValue(string typeName)
        => typeName.Contains("FloatPropertyData", StringComparison.Ordinal) ||
           typeName.Contains("IntPropertyData", StringComparison.Ordinal);

    private static SemanticProperty CreateStaticCustomProperty(
        SemanticProperty template,
        string rawValue,
        string path)
    {
        var raw = rawValue.Trim();
        if (raw.Length >= 2 && raw[0] == '"' && raw[^1] == '"')
            raw = raw[1..^1].Trim();

        JsonElement value;
        try
        {
            if (template.TypeName.Contains("IntPropertyData", StringComparison.Ordinal))
            {
                value = JsonSerializer.SerializeToElement(int.Parse(
                    raw,
                    System.Globalization.NumberStyles.Integer,
                    System.Globalization.CultureInfo.InvariantCulture));
            }
            else if (template.TypeName.Contains("FloatPropertyData", StringComparison.Ordinal))
            {
                value = JsonSerializer.SerializeToElement(float.Parse(
                    raw,
                    System.Globalization.NumberStyles.Float,
                    System.Globalization.CultureInfo.InvariantCulture));
            }
            else
            {
                throw new InvalidDataException($"Custom value is not supported for {template.TypeName} at {path}.");
            }
        }
        catch (Exception ex) when (ex is FormatException or OverflowException)
        {
            throw new InvalidDataException($"Custom value for {path} is invalid: {raw}", ex);
        }

        var normalized = SemanticValueNormalizer.Normalize(template.TypeName, value);
        return new SemanticProperty(
            template.Name,
            template.TypeName,
            normalized,
            JsonCanonicalizer.Canonicalize(normalized));
    }

    private static StaticItemBehaviorRule ParseBehavior(
        string text,
        StaticItemBehaviorRuleSuggestion suggestion)
        => text.ToLowerInvariant() switch
        {
            "auto" => suggestion.Suggested ? suggestion.Rule : StaticItemBehaviorRule.None,
            "none" => StaticItemBehaviorRule.None,
            "no-spoil-current" => StaticItemBehaviorRule.NoSpoilAllCurrentPositiveRows,
            _ => throw new ArgumentException($"Unknown --behavior value: {text}")
        };

    private static void WriteJson<T>(string path, T value)
    {
        Directory.CreateDirectory(Path.GetDirectoryName(Path.GetFullPath(path))!);
        File.WriteAllText(path, JsonSerializer.Serialize(value, JsonOptions));
    }

    private static IReadOnlyList<(string Name, string Root)> ParseProviders(IReadOnlyList<string> values)
    {
        var result = new List<(string Name, string Root)>();
        foreach (var value in values)
        {
            var separator = value.IndexOf('=');
            if (separator <= 0 || separator == value.Length - 1)
                throw new ArgumentException("Provider arguments must use Name=path syntax.");
            result.Add((value[..separator], value[(separator + 1)..]));
        }
        return result;
    }

    private sealed class CliArgs
    {
        private readonly Dictionary<string, List<string>> _values = new(StringComparer.Ordinal);

        public static CliArgs Parse(string[] args)
        {
            var parsed = new CliArgs();
            for (var i = 0; i < args.Length; i++)
            {
                var key = args[i];
                if (!key.StartsWith("--", StringComparison.Ordinal))
                    throw new ArgumentException($"Unexpected argument: {key}");
                if (i + 1 >= args.Length)
                    throw new ArgumentException($"Missing value for {key}");
                var value = args[++i];
                if (!parsed._values.TryGetValue(key, out var list))
                {
                    list = new List<string>();
                    parsed._values[key] = list;
                }
                list.Add(value);
            }
            return parsed;
        }

        public string RequireSingle(string name)
        {
            var values = RequireMany(name);
            if (values.Count != 1)
                throw new ArgumentException($"Expected exactly one {name}; got {values.Count}.");
            return values[0];
        }

        public string? OptionalSingle(string name)
        {
            if (!_values.TryGetValue(name, out var values) || values.Count == 0)
                return null;
            if (values.Count != 1)
                throw new ArgumentException($"Expected at most one {name}; got {values.Count}.");
            return values[0];
        }

        public IReadOnlyList<string> RequireMany(string name)
        {
            if (!_values.TryGetValue(name, out var values) || values.Count == 0)
                throw new ArgumentException($"Missing required option: {name}");
            return values;
        }
    }
}
