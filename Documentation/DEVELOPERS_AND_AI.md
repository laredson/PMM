# Developer and AI Reference

## Who this document is for

- developers maintaining/forking PMM;
- modders investigating an Unsupported case;
- AI agents assisting with PMM development or a manual merge;
- maintainers reviewing community Knowledge contributions.

## AI-assisted origin

PMM was developed by laredson with extensive GPT assistance across 50+ hours of hands-on investigation and testing in the v1.0 release line.

Treat this as an engineering fact, not a guarantee that AI output is correct. The project architecture intentionally separates speculative understanding from permission to write.

## Hard architecture rules

Do not regress these:

1. No generic production `UAsset.Write()` merger.
2. Unsupported is not a user whole-file winner decision.
3. PMM overlays never re-enter the source graph.
4. Import/Build do not normally mutate Palworld; Deploy is the synchronization boundary.
5. Semantic caches must represent the complete cooked family, not `.uasset` alone.
6. Mod names/descriptions/comments/Knowledge never authorize an automatic write.
7. Do not silently deploy a saved patch against changed source hashes/mappings.
8. Preserve the union of independent changes after resolving a local conflict.

## Validation vocabulary

Use exact language:

- **Runtime-proven:** tested in Palworld.
- **Fixture/golden-proven:** output/structure/hashes proven against captured data but not necessarily re-run in game.
- **Static-only:** code/package/source checks.
- **Experimental manual solution:** exact-case structural/provenance checks passed; gameplay unproven.

Never upgrade one category to another without evidence.

## Current adapter stack

### BinaryRangeMerge-v2
Same compatible cooked layout; merge disjoint Vanilla-relative byte deltas, deduplicate same values, conflict on different values at the same byte.

### StaticItemDataAssetAdapter/v0.4.0
Current-layout cooked base plus supported fixed-size stale-layout semantic intent transfer. Includes explicit behavior-rule extension where separately proven.

### SupersetAnchor-v1
Preserve a larger real cooked provider only when every requested byte from smaller providers is already contained.

### DataTableScalarTransfer-v2
Transfer supported scalar row/property changes into a real cooked DataTable anchor with byte preconditions.

### ContainedDeltaSuperset-v1
For variable-size Blueprint families where one real provider can be proven to contain every other provider's Vanilla-relative executable changes plus compatible metadata/bookkeeping. Output is the real anchor unchanged.

### RelocatableDelta-v2
For relatively small variable-size families. Uses an anchor, alignment and relocation validation to transplant disjoint hunks; same-topology variants can become local value conflicts.

## Semantic Lab

Semantic Lab is read-only/evidence-only.

Current direction:

```text
read-only Kismet parse
 -> normalized PMM Blueprint IR
 -> functions/basic blocks/expressions
 -> control/data/effect graph
 -> Vanilla-to-provider semantic diffs
 -> dependency-closed change capsules
 -> structural composition proof
 -> human-readable explanation
```

Human descriptions and AI interpretation may label/explain likely behavior. They do not make an unsafe graph safe.

## AI_HANDOFF contract

When PMM cannot prove a composition, the handoff should give an external solver everything needed for the exact case. The solver should return only the declared manual-solution schema and cooked family.

The solver should:

- preserve unrelated provider behavior;
- explain the intended composition;
- avoid touching unrelated assets;
- use exact case files, not downloaded substitutes;
- retain all required cooked sidecars;
- not fake hashes/case IDs;
- state uncertainty clearly.

PMM validates provenance/topology/hashes/readability, then the user must test gameplay.

## Good AI prompt template

```text
You are helping resolve one exact Palworld Manager Merger Unsupported case.
Read README_FOR_HUMAN_OR_AI.md, case.json, global context, semantic evidence,
Knowledge and all supplied cooked/provider files before proposing changes.

Goal: preserve the union of independent gameplay changes from all providers.
Do not choose a whole-mod winner unless the supplied evidence proves the changes
are mutually exclusive. Do not modify unrelated assets.

Return only a ZIP following PMM_MANUAL_SOLUTION_V1. Explain your reasoning in
notes, but do not invent successful validation: PMM and Palworld runtime testing
will validate the result.
```

## Growing Knowledge safely

Prefer contributions that teach a structural rule:

Bad:

```text
if filename == CoolMod_P.pak: accept
```

Good:

```text
if one real cooked provider strictly contains every secondary executable delta
and compatible metadata under the exact containment proof: use it as anchor
```

## Source transparency and forks

PMM's own PowerShell/WPF/C# source and Knowledge files are included and released under the MIT License in the root `LICENSE` file. Forks and redistributed modifications must retain the copyright/license notice as required by MIT; third-party dependencies keep their own licenses.

## Release engineering

Before every release:

- run static JSON/XAML/control-name checks;
- run Windows PowerShell parsing and `SmokeTest.ps1`;
- run PMMCore self-test;
- preserve mappings/core versions intentionally;
- rebuild checksums after edits;
- run at least the current regression fixture in Analyze/Build/Deploy;
- classify runtime evidence honestly.
