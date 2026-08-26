# Palworld Manager Merger v1.1 developer guide

## Do not regress the architecture

1. Do not use `UAsset.Write()` as a generic production merger.
2. Do not turn `Unsupported` into a whole-file/mod winner choice.
3. Do not let PMM-generated overlays re-enter the source graph.
4. Do not let Import or Build mutate Palworld; Deploy is the boundary.
5. Do not key semantic cache identity by `.uasset` alone.
6. Do not use mod names/descriptions/knowledge entries as authorization.
7. Do not silently deploy an old patch against a changed active source set.
8. Do not reintroduce MegaMerge. PMM preserves source mods and builds only a compatibility patch.
9. Do not run long Analyze/Build/Game Reference work on the WPF UI thread; use the worker/progress-file pattern.

## Current version contracts

- application: v1.1
- PMMCore: 0.9.0
- plan schema: 15
- engine profile: current proven Palworld UE5.1 separated package profile
- end-user .NET Runtime: exact 8.0.30 win-x64; Setup reuses an exact host or downloads/verifies the pinned portable runtime when required
- developer-only .NET SDK contract: 8.0.424
- UAssetAPI: 1.1.0 read-only production boundary

## Adapter selection

Analyze extracts exact Vanilla + provider cooked families and tries conservative
production adapters. The current stack includes `ContainedDeltaSuperset-v1` before the more
permissive/complex relocatable path for variable-size families.

A contained-superset success means one **real provider family** strictly contains
every other provider's exact executable changes plus compatible package metadata.
The output is that provider unchanged. Never add Fly/Wing or asset-name branches
to the adapter.

When adding a new proof:

- derive it from a real failing fixture;
- write negative mutation tests for every safety assumption;
- keep Analyze/Build proof symmetric;
- preserve real cooked bytes whenever possible;
- record structural vs runtime validation separately.

## Fly + Wing acceptance fixture

See `Knowledge/known-fixtures.json` (`fly-wing-bp-wingglider-20260816`) and `Documentation/RUNTIME_PROVEN_COMPATIBILITY.md`.

Key expectation:

`BP_WingGlider -> ContainedSupersetAuto -> Wing cooked family unchanged`

The adapter must remain N-way. Additional providers are accepted only if one real provider proves containment of all others; never add a provider-name special case.

## Semantic Lab

`Core/SemanticLab.ps1` is read-only/evidence-only. It may create labels, behavior
hints and heuristic change-capsule candidates, but it may not make Build-safe
decisions.

Future Kismet work belongs here first:

- read-only Kismet extraction;
- normalized PMM Blueprint IR;
- CFG/effect analysis;
- dependency-closed change capsules;
- then a separate production composition proof.

## Manual / AI solutions

`PMM_MANUAL_SOLUTION_V1` is an exact-case escape hatch for Unsupported assets.
See `Docs/MANUAL_SOLUTION_CONTRACT.md`.

Important distinction:

- `PMM_VALIDATED_MANUAL_SOLUTION_V1` means case/provenance/topology/hashes/reader
  checks passed;
- it does **not** mean gameplay semantics are proven.

Manual solutions are stored under `Data/ManualSolutions/<caseId>`, marked
`RuntimeStatus=UNPROVEN`, and built into the same global overlay. Safe automatic
adapters always have priority.

## UI rules

- source mods and PMM patches are different collections;
- the patch panel shows Current + Previous + deployed history; exactly one exact-source-set patch may be selected for Deploy;
- old conflict decisions from the SAME source hashes + mappings are valid rollback variants and must use their own manifest suppressions;
- patches from other source hashes/mappings remain visible but non-selectable;
- source enable/disable invalidates Analyze state;
- Analysis and Resolution are collapsible, but Build/Deploy controls stay fixed;
- new unresolved decisions auto-open Resolution;
- Unsupported auto-opens review/remediation tools;
- disabling an Unsupported provider is a structural least-impact suggestion, not
  a gameplay preference prediction;
- no Remerge/Rebuild duplicate actions: use Analyze -> Build -> Deploy.

## Regression checklist

Before shipping a preview:

- existing runtime/golden StaticItem behavior remains intact;
- MultiJump Triple/Quad remains one value-level conflict with Fly preserved;
- BreedFarm relocatable fixture remains routed;
- PlayerStatus superset fixture remains routed;
- Fly+Wing contained-superset mirror positive and negative gates pass;
- Mappings unchanged unless explicitly intended;
- SaveService and transactional Deploy remain unchanged unless the preview is
  specifically modifying them;
- XAML parses and every control name referenced by Start-PalModMerger exists;
- no stale PMMCore/schema/version strings;
- rebuild `SHA256SUMS.txt` after all edits.

On Windows, run `SmokeTest.ps1`, then actual Analyze/Build/Deploy. Static Linux
checks do not replace a PowerShell parser, .NET build, WPF render or Palworld
runtime test.


## Promoting a successful AI_HANDOFF in v1.1

Prefer a stronger generic adapter when the structural rule can be proven. If the only safe evidence is an exact runtime-tested solution, add a sanitized fixture plus a `Knowledge/production-recipes.json` entry. The recipe must pin all inputs and reuse an already-present provider family; do not ship cooked solution assets. Add a SmokeTest regression and require a new in-game validation before release.

## Game Reference subsystem

`Core/GameReferenceService.ps1` owns the locally generated Vanilla reference cache and
AI_HANDOFF reference selection. It may read/copy/index exact cooked bytes but must not
call Build/production recipe authorization. Keep the cache identity pinned to source PAK
size/timestamp, mappings SHA and scope version.

For performance, the large roots are extracted in one `repak unpack` invocation. The
2026-08-17 supplied research capture validates 7,134 selected cooked files / 3,565
families / ~66.8 MiB raw under scope `PMM_GAME_REFERENCE_SCOPE_V1`.

## Community contribution subsystem

`Core/KnowledgeContributionService.ps1` creates portable tested evidence. Do not add code
there that writes `Knowledge/production-recipes.json` or changes Analyze/Build policy.
Promotion belongs to reviewed release engineering (or a future explicitly trusted,
signed Knowledge-pack pipeline).


## Clean v1.1 background-operation contract

`Core/OperationWorker.ps1` owns heavy Analyze/Build work in a child PowerShell process.
`Core/GameReferenceWorker.ps1` does the same for Game Reference.

The WPF process:
- saves any UI-owned state before starting a worker;
- creates a per-job directory under `Cache`;
- starts the child process;
- polls atomic JSON progress with a `DispatcherTimer`;
- refreshes UI state only after the worker writes a success/failure result;
- kills its child worker when the PMM window closes.

Do not move merge logic into the UI worker wrappers. The workers call the same Core functions as the proven synchronous path.

## Saved-patch reuse

Keep two different ideas separate:

1. **Full source identity** — physical saved-patch reuse still requires the exact source hashes/mappings contract.
2. **Effective order identity** — changing positions that do not change a priority-derived conflict winner must not invalidate a patch merely because the complete list order differs.

`EffectiveMergeOrderSignature` and `PatchContentSignature` document this behavior.

## Community development

The public repository is intended for forks and pull requests. See `CONTRIBUTING.md`, `SECURITY.md`, and `Documentation/GIT_SETUP.md`.

v1.1 contribution upload/download remains manual. Remote Knowledge channels and self-update manifests are design documents only; do not silently add network execution to the stable v1.1 runtime.
