# PMM 1.2 runtime layers

```text
PMM.exe (PMMH)
  stable Host / supervisor / emergency handoff
        |
        v
PMMRuntime.exe (PMMRT)
  evolvable native capabilities; source in Runtime/
        |
        +--> external Knowledge/*.json (authoritative)
        +--> external UI/*.xaml (authoritative presentation while WPF migration continues)
        +--> bundled repak / PMMCore / AssetReader / mappings
        |
        v
PowerShell orchestration
  only where it is safe/appropriate; final 1.2 user runtime must not depend on FullLanguage
```

Design rule: compile behavior that needs restricted .NET/native capabilities; keep knowledge, configuration, localization and other frequently edited policy/data external. PMMCKL and future PMMFLKL remain external and versioned rather than baked into an executable.

`PMM.exe` should change rarely. `PMMRuntime.exe` is intentionally replaceable and recompilable as capabilities evolve.

---

# Palworld Manager Merger v1.1 architecture

## Product invariant

For every shared cooked asset, PMM attempts to preserve the union of compatible
changes from Vanilla + N source providers. Whole-file winner selection is not a
normal merge fallback.

Plan states:

- `*Auto`: exact current inputs passed a production composition proof;
- `*Conflict`: compatible changes are already preserved, but a smallest proven
  value/property/byte disagreement needs a decision;
- `ManualSolutionExperimental`: an exact-case cooked replacement passed PMM's
  provenance/structural validation but gameplay semantics remain unproven;
- `Identical`: providers contain the same cooked family;
- `Unsupported`: no safe production proof or accepted exact manual solution;
  Build is blocked.

## State model

```text
source PAK library (Mods/)                         Palworld (~mods)
          |                                                ^
          | Analyze                                        |
          v                                                | DEPLOY only
Data/merge-plan.json                                       |
          |                                                |
          | Build                                          |
          v                                                |
Builds/Current/ONE compatibility overlay ------------------+
```

PMM-generated patches are managed outputs and never source providers.

PMM does not use MegaMerge. Original source mods remain independent; `Builds/Current` contains only the managed compatibility overlay required for reconciled assets.

## Merge priority contract

The source library has a persistent `OrderLowToHigh` stored in `Data/mod-priorities.json`. The first source applies earlier/lower priority; the last applies later/higher priority. `MergeOrderSignature` preserves the full order for reproducibility, while `EffectiveMergeOrderSignature` narrows saved-patch invalidation to order changes that actually change a priority-resolved conflict winner.

Priority is deliberately **not** a whole-asset load-order fallback. PMM still computes Vanilla-relative intent from every provider and preserves the union of disjoint changes. When a supported adapter proves that two providers request different values for the same semantic property/structural value/byte, the highest-priority competing provider becomes the default conflict resolution. A user selection changes `ResolutionOrigin` to `Manual` and overrides the priority default. Unsupported structures remain blocked.

Reordering keeps the previous plan only as decision history, invalidates it for Build, and requires Analyze again. Saved patches with the same source hashes but another/legacy order remain explicit rollback artifacts; they are never silently auto-selected as the current output.

## Analyze/build routing

```text
active source PAKs
  -> group exact logical cooked families
  -> extract Vanilla + N providers
  -> safe production adapters, from conservative/simple to specialized
  -> evidence-only Semantic Lab / review artifacts
  -> plan + true-conflict rows
  -> optional exact-case manual solution only if safe adapters still fail
  -> Build re-extracts original inputs and re-runs proofs
  -> ONE global patch root
  -> repak + index/family verification
  -> Builds/Current + manifest
  -> explicit Deploy
```

A manual solution for one family is a node in the global plan, not a second PMM
load-order patch. This matters when one source mod (for example FlyMode) also
participates in other shared assets handled by other adapters.

## Adapter stack

### BinaryRangeMerge-v2

Same current cooked layout. Independent Vanilla-relative byte deltas combine;
different values at the same proven byte become `BinaryConflict` rows.

### StaticItemDataAssetAdapter/v0.4.0

Read-only semantic inspection plus fixed-size byte transfer into a real current
`DA_StaticItemDataAsset` cooked base. Handles the proven Fly/Food/Stack/Early
Aquatic family without full UAsset reserialization.

### SupersetAnchor-v1

Keeps a larger real cooked provider unchanged only when it proves all secondary
requested bytes are already present.

### DataTableScalarTransfer-v2

Uses a real cooked DataTable anchor; transfers supported scalar row/property
changes with byte preconditions and creates value conflicts only for the same
semantic identity.

### ContainedDeltaSuperset-v1 — introduced in preview32, runtime-proven Fly+Wing

Purpose: solve a conservative class of variable-size Blueprint/Kismet packages
where one real cooked provider already contains every smaller provider change.

Properties:

1. N-provider: every provider is tried as a candidate anchor, ordered only by
   size as a heuristic.
2. No mod/asset-name special cases.
3. Requires current proven Palworld UE5.1 separated `.uasset + .uexp` profile.
4. Every secondary Vanilla-relative `.uexp` hunk must occur exactly at the same
   Vanilla coordinates/value in the anchor.
5. Vanilla NameMap/import-map bytes must remain exact prefixes; a secondary's
   additions, if any, must be prefix-contained by the anchor.
6. Export-map topology must be unchanged; only generated SerialSize/SerialOffset
   bookkeeping may differ.
7. Export payload chains and total `.uexp` serial sizes must be coherent.
8. DependsMap, AssetRegistry and PreloadDependencies must remain compatible with
   the proof.
9. Other cooked sidecars must be Vanilla-identical or anchor-identical.
10. Output is `anchor.Family.Clone()` — the real cooked provider bytes unchanged.

First fixture: `BP_WingGlider` from FlyMode +
WingPackNoWingCells_VisibleOnlyWhileFlying. The exact Fly executable hunks are
subsumed by Wing and the output is Wing's real cooked family. The manual global
overlay using this relationship was runtime-tested successfully on 2026-08-16.

This adapter is a structural proof. Human descriptions like "shows wings only
while flying" do not authorize it.

### RelocatableDelta-v2

For small variable-size families where no contained-superset proof exists. Uses
a structural anchor, supports same-topology anchor variants as value conflicts,
and transplants disjoint Vanilla-relative hunks through proven alignment and
relocation arithmetic.

## Semantic Lab boundary

`Core/SemanticLab.ps1` is deliberately separate from the write/authorization
path.

Semantic Lab v0.1 can:

- collect printable symbol evidence from exact cooked families;
- map symbols to generic effect hints;
- attach exact fixture / known behavior context;
- group heuristic, non-selectable change-capsule candidates.

It cannot yet prove arbitrary Kismet control flow or infer safe dependency
closure. Every capsule is `HEURISTIC_ONLY`, `Selectable=false`.

Planned evolution:

```text
UAssetAPI read-only Kismet parse
      -> normalized PMM Blueprint IR
      -> functions/basic blocks/expressions
      -> control-flow and data/effect graph
      -> Vanilla -> provider semantic diffs
      -> dependency-closed change capsules
      -> structural composition proof
      -> human-friendly behavior explanation
```

Interpretation and author comments can label/explain the graph, but the final
safe-merge permission must come from verifiable structure/dependencies.

## AI/human handoff and manual solution contract

For an Unsupported family, Analyze emits `Data/Review/<asset-id>/` plus a ready
`AI_HANDOFF_<caseId>.zip` containing:

- exact `case.json` hash manifest;
- Vanilla/provider cooked parts;
- source PAKs involved in the case;
- PMMCore report and Semantic Lab evidence;
- knowledge base;
- README, optional context notes, and return template.

The current return mode is `replacement-cooked-family` under schema
`PMM_MANUAL_SOLUTION_V1`.

Import validation includes:

1. safe ZIP paths (no absolute/traversal entries);
2. exact caseId and asset;
3. caseId recomputation from pinned inputs;
4. current review cooked bytes still match recorded size/SHA-256;
5. exact provider PAK name+SHA-256 still active;
6. exact asset-family topology and no unrelated cooked files;
7. read-only AssetReader probe;
8. output SHA-256 pinning in `Data/ManualSolutions/<caseId>`.

A validated solution is still marked `UNPROVEN` at runtime and requires explicit
user risk acceptance. Build rechecks stored hashes and AssetReader probe.

## UI/lifecycle

RC34 separates source mods from PMM patches and exposes the saved patch history. Source mods have direct On
toggles. Analysis and Resolution panels are collapsible; unresolved decisions
auto-open Resolution. Unsupported auto-opens its review panel. Build/Deploy are
fixed at the bottom.

`Remerge`/`Rebuild from scratch` were removed. Analyze always creates the current
plan; Build always produces a new current patch and archives the previous one as
needed.

## Reader/writer boundary

`Tools/AssetReader` may parse/read cooked assets. Production merging must not use
`UAsset.Write()` as a generic writer. PMMCore writers either patch copied bytes
with preconditions or preserve a proven real cooked anchor unchanged.

## Deployment

Deploy is unchanged from preview30/31 transactional hardening:

- identity-aware managed removals;
- unknown same-name PAK collision block;
- same-volume staging and SHA verification;
- backup of managed targets;
- commit and post-commit verification;
- caught-error rollback attempt and retained recovery data.

## Versions

- plan schema: 15
- PMMCore: 0.9.0
- end-user .NET Runtime: exact 8.0.30 win-x64; an existing exact host is reused, otherwise Setup downloads the pinned Microsoft runtime archive, verifies SHA-512, and installs it portably under Tools/dotnet
- developer-only .NET SDK contract: 8.0.424
- UAssetAPI: 1.1.0
- mappings: bundled SHA recorded in plans/manifests

## RC34 saved-patch selection model

`Builds/Current` is the locally promoted overlay. `Builds/Previous` is retained
history. The UI enumerates both plus the deployed copy and de-duplicates by patch
filename.

A saved patch has two distinct identities:

- **source-set compatible**: output hash is valid and exact active source
  signature + mappings match. This is sufficient for an intentional rollback;
- **current-decision match**: source-set compatible plus its stored decision
  signature equals the decisions currently shown by Analyze. This tells Build
  whether it needs to create another output, but does not invalidate older
  rollback variants.

Deploy always uses the selected patch manifest's own `DeploymentSuppressions`.
After a successful transactional Deploy, PMM promotes that saved patch to
`Builds/Current` and archives the previous Current output. Patches whose source
set/mappings differ stay visible but their radio selector is disabled.


## v1.1 runtime-proven recipe fallback

`Core/KnowledgeRecipeService.ps1` is a strict production fallback for successful community/manual solutions. It does not trust names or natural-language intent. A recipe must match the current mappings hash, Vanilla family topology/hash/size, exact complete provider PAK hash set, each provider family topology/hash/size, and a runtime-proven output provider family. Build repeats the same validation before copying that real provider family into the overlay. Any mismatch returns control to ordinary adapters/Unsupported.

`DataTableMap` now occurrence-qualifies duplicate Unreal row IDs instead of collapsing or rejecting them. This allows semantic inspection of tables such as `DT_PalMonsterParameter_Common` while still exposing duplicate-count/order changes as structural differences.


## Background UI execution

Long-running operations are isolated from WPF:

```text
WPF UI
  |
  +-- Core/OperationWorker.ps1   -> Analyze / Build
  |
  +-- Core/GameReferenceWorker.ps1 -> Game Reference
  |
  +-- atomic progress.json / result.json
```

The workers execute the existing Core service functions. They do not contain an alternative merge engine.

Deploy remains a transactional foreground boundary because it changes the managed game deployment state; Analyze/Build/Game Reference are the primary long-running worker operations in v1.1.
