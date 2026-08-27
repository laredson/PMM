# PMM Analyze–Merge internals

## Purpose and scope

This document explains, step by step, how Palworld Manager Merger (PMM) discovers shared mod content, analyzes compatibility, creates a deterministic merge plan, rebuilds compatible cooked asset families, packs the resulting compatibility overlay, and deploys it together with the original source mods.

The document is intentionally version-neutral in its filename and role. Its verified implementation baseline is the PMM 1.2.1 Guided Flow stable tree, commit `683a46df474c5f576e0bf5543d070da0dab7478a`. Future changes should update this document whenever they alter the Analyze, conflict-resolution, Build, packaging, Knowledge, AIIO, or Deploy contracts.

The most important invariant is:

> PMM does not normally combine every source mod into one autonomous megapak. It keeps the original source mods installed and builds a minimal compatibility overlay containing only the shared cooked assets that must be reconciled.

A normal deployed result therefore looks like:

```text
Mod_A.pak
Mod_B.pak
Mod_C.pak
zzzzzzzzzz_PMM_Merge_<timestamp>_P.pak
```

The source PAKs continue to provide their exclusive assets and dependencies. The PMM overlay replaces only the logical asset paths for which PMM produced a proven combined result.

---

## 1. Product model

```text
PMM source-mod library
        |
        | Analyze
        v
Index every source PAK and group logical files/assets
        |
        v
Find paths supplied by more than one active provider
        |
        v
Extract exact Vanilla + provider asset families
        |
        v
Try conservative merge proofs/adapters
        |
        +--> automatic proven composition
        +--> smallest true conflict requiring a choice
        +--> exact runtime-proven Knowledge recipe
        +--> accepted exact-case experimental solution
        +--> Unsupported blocker
        v
State/merge-plan.json
        |
        | Build
        v
Re-extract original inputs and repeat every proof
        |
        v
PatchRoot/Pal/Content/...
        |
        v
repak pack --version V11
        |
        v
One managed PMM compatibility overlay + manifest
        |
        | Deploy
        v
Original active source mods + selected PMM overlay in Palworld ~mods
```

Analyze is a planning and evidence phase. Build is the write phase. Deploy is a separate transactional installation phase.

---

## 2. Terminology

### Source mod

An original user-provided `.pak` stored in PMM's source library. A PMM-generated compatibility patch is never treated as a source provider.

### Provider

A source mod that contains a particular logical file or Unreal asset family.

### Logical path

The path exposed by the PAK index, for example:

```text
Pal/Content/Pal/DataTable/Character/DT_PalMonsterParameter_Common.uasset
```

Logical identity is path-based and case-normalized for grouping, while exact entry spelling returned by `repak list` is retained for extraction.

### Asset family

One Unreal cooked object represented as a grouped family:

```text
Foo.uasset
Foo.uexp
Foo.ubulk
```

The `.uasset` header is required. `.uexp` and `.ubulk` are optional sidecars. PMM treats the family as one logical merge unit so it never intentionally emits an orphan sidecar.

### Vanilla/current

The installed Palworld cooked family extracted from the game's PAK set. It is the common reference from which provider changes are measured.

### Adapter

A conservative proof and construction strategy. An adapter may patch copied bytes under explicit preconditions or preserve a real cooked provider unchanged after proving that it already contains the required changes. Production adapters do not use whole-asset winner selection as a generic fallback.

### Merge plan

`State/merge-plan.json`, the durable Analyze result describing exact inputs, adapter modes, conflict rows, source order, mappings identity, Vanilla identity, and deployment suppressions.

### Compatibility overlay

The PMM-generated PAK containing only reconciled override assets. Its manifest records exact inputs, output hashes, decisions, and evidence.

---

## 3. Source identity and priority

PMM reads every active source PAK from its own library and creates a record containing at least:

```text
Name
Path
Size
SHA-256
Enabled state
Priority
```

The PAK SHA-256 is the authoritative source identity. Two files with the same filename but different bytes are different providers/builds.

To avoid repeatedly hashing every PAK during UI refreshes, the hash cache key includes:

```text
full path + file size + LastWriteTimeUtc
```

Replacing or modifying a PAK therefore invalidates its cached identity naturally.

Priority is stored as a persistent low-to-high order. It is not permission to discard an entire lower-priority asset. PMM first preserves every compatible change. Priority is used only as the default winner when a supported adapter proves that multiple providers request different values for the same smallest conflict identity.

A manual or custom user choice overrides that priority-derived default.

---

## 4. Package-choice processing happens before asset analysis

Some mod downloads include mutually exclusive variants, for example:

```text
Normal.pak
Fast.pak
VeryFast.pak
```

Those alternatives must not be treated as independent providers and merged together.

Before shared-asset analysis, PMM evaluates package-choice rules. When a required package decision is unresolved:

1. Analyze writes a temporary decision-bearing plan.
2. Analyze stops before byte/semantic merge work.
3. The user selects one valid package variant.
4. Analyze must run again.
5. Non-selected alternatives are suppressed from the effective analysis and deployment set.

This protects the merge engine from attempting to reconcile editions that the mod author intended to be mutually exclusive.

---

## 5. PAK indexing

PMM invokes `repak list` for source PAKs and the installed Vanilla PAK set. The result is the internal logical file index.

The index cache key also includes path, size, and timestamp. This is especially important for `Pal-Windows.pak`: PMM can index that large file once per process rather than once per shared asset.

The PAK service is intentionally policy-free. It lists, extracts, packs, and validates. Merge policy remains in the merge engine and PMMCore adapters.

---

## 6. Grouping files and Unreal families

PMM walks every active source PAK entry and normalizes path separators.

For `.uasset`, `.uexp`, and `.ubulk`, it removes the final extension and groups all related sidecars under a single logical `.uasset` identity:

```text
Pal/.../Foo.uasset
Pal/.../Foo.uexp
Pal/.../Foo.ubulk
```

becomes:

```text
Asset = Pal/.../Foo.uasset
Kind  = AssetFamily
```

Files outside that Unreal family set are grouped as ordinary files:

```text
Kind = File
```

Backup-looking cooked entries such as `.uasset.bak` are ignored.

For every group PMM records which active mods provide it, ordered by configured priority and name.

---

## 7. Shared-asset discovery

Only groups with more than one effective provider require compatibility analysis.

Example:

```text
BP_Boar.uasset
    -> RushRoar.pak

DT_PalMonsterParameter_Common.uasset
    -> RushRoar.pak
    -> FasterMounts.pak
```

`BP_Boar` is exclusive to one source mod and remains supplied by that original PAK. `DT_PalMonsterParameter_Common` is shared and enters the merge pipeline.

This is why the final overlay is normally much smaller than the combined source mods: unique assets are never copied into the overlay merely to make it self-contained.

---

## 8. Exact extraction and bounded temporary storage

For each shared group PMM extracts only the exact required entry family:

```text
repak get <provider.pak> Pal/.../Foo.uasset
repak get <provider.pak> Pal/.../Foo.uexp
repak get <provider.pak> Pal/.../Foo.ubulk
```

PMM does not normally unpack every source PAK.

Exact extraction avoids earlier classes of error involving mount points, strip prefixes, path guessing, and unnecessary disk use. It also writes through a safe path resolver that rejects traversal, absolute/device paths, invalid Windows components, control characters, and any path escaping the staging root.

Analyze uses a per-session transaction root and a separate temporary directory for each shared group. After an asset has been analyzed and its durable metadata/evidence has been published, that group's cooked scratch data is deleted immediately. Therefore Analyze disk use is bounded approximately by the largest individual active case rather than the sum of all shared assets.

---

## 9. Vanilla as the common baseline

PMM searches the installed game PAK set for the same logical path and extracts the current Vanilla family.

The comparison is not simply:

```text
Mod A <-> Mod B
```

It is:

```text
Vanilla -> Mod A
Vanilla -> Mod B
Vanilla -> Mod C
```

Conceptually:

```text
Delta A = Mod A - Vanilla
Delta B = Mod B - Vanilla
Result  = Vanilla + compatible Delta A + compatible Delta B
```

Vanilla provides the common coordinate and semantic baseline needed to distinguish a provider's intended edit from unchanged game content.

When no matching Vanilla asset exists and differing providers cannot be proven compatible by another exact contract, PMM does not invent a baseline or silently select one provider. The case becomes Unsupported or requires an external/manual exact-case workflow.

PMM stores a quick Vanilla PAK-set signature using filenames, sizes, and timestamps to invalidate stale plans efficiently. Exact family SHA-256 validation is performed where stronger proof is required, including manual-solution and Knowledge workflows.

---

## 10. Identical fast path

After provider extraction PMM compares all family parts.

When every provider contains the same cooked family, the group is recorded as:

```text
Mode = Identical
```

No compatibility copy is needed. The original source deployment already supplies equivalent bytes.

For ordinary shared non-Unreal files, identical hashes receive the same treatment.

---

## 11. Adapter routing order

When providers differ, PMM tries the available production proofs from conservative/simple to specialized.

The verified routing order is:

| Order | Mode/adapter | Purpose |
|---:|---|---|
| 1 | Binary range | Merge independent fixed-coordinate deltas on the current Vanilla layout. |
| 2 | Runtime-proven Knowledge recipe | Reuse a precisely pinned real provider family for one exact fixture already proven in game. |
| 3 | Static item semantic transfer | Recover supported intent from same-baseline stale `DA_StaticItemDataAsset` providers and apply fixed-size patches to a current cooked base. |
| 4 | Superset anchor | Prove that one real cooked provider already contains every byte requested by current-layout secondaries. |
| 5 | DataTable scalar transfer | Merge supported row/property scalar changes into a real cooked DataTable base. |
| 6 | Contained-delta superset | Prove that one variable-size UE5.1 cooked package structurally contains every secondary executable delta and compatible metadata growth. |
| 7 | Relocatable delta | Transplant disjoint variable-size `.uexp` hunks and compose proven `.uasset` relocation bookkeeping. |
| 8 | Unsupported | No safe production proof accepted the family. Build is blocked. |

The result of a failed adapter is not automatically "highest-priority whole file wins." The next adapter is tried, and if none can prove safety the case remains unsupported.

---

## 12. Binary range merge

### Preconditions

A provider is binary-safe only when PMM proves the current Vanilla layout:

1. Required family topology matches.
2. Provider and Vanilla part sizes match.
3. The provider `.uasset` is byte-identical to Vanilla.
4. Sidecars occupy the same coordinate space.

### Planning

PMM starts with a copy of Vanilla. For every non-`.uasset` part, it compares each provider byte against Vanilla.

Example:

```text
Vanilla: 10 20 30 40 50
Mod A:   10 99 30 40 50
Mod B:   10 20 30 77 50
```

Requests:

```text
A: offset 1 -> 99
B: offset 3 -> 77
```

Result:

```text
10 99 30 77 50
```

If multiple providers request the same non-Vanilla byte at one offset, the request is compatible and written once.

If they request different values at the same offset, PMM records a `BinaryConflict` row. Every non-conflicting byte remains preserved in the planned output.

A binary conflict can expose:

```text
Vanilla
Provider A
Provider B
Custom byte
```

Build later reruns the binary merge using the selected resolution tokens.

---

## 13. Runtime-proven Knowledge recipes

Knowledge recipes are a narrow exact-fixture fallback, not broad semantic permission.

A production recipe is accepted only when all relevant identities match, including:

```text
logical asset path
UE5_1 engine profile
Mappings.usmap SHA-256
complete provider PAK SHA-256 set
Vanilla family topology, size, and SHA-256
provider family topology, size, and SHA-256
runtime-proven production status
pinned output family identity
```

The recipe does not contain redistributed cooked game assets. It identifies a real provider family already present in the exact current source set and proven to be the correct output for that fixture.

Any changed game, mappings, mod PAK, provider set, topology, size, or family hash makes the recipe inapplicable. PMM then returns to ordinary adapters or Unsupported.

### Concrete known-fixture example

The stable baseline includes an exact recipe for the combination of RushRoar Leather Drop v2 and a specific FasterMounts build on `DT_PalMonsterParameter_Common`.

RushRoar enables the Rushoar ranch suitability. FasterMounts already contains that requested suitability inside a broader work-suitability expansion. The exact FasterMounts cooked family was runtime-proven to satisfy both behaviors for the pinned inputs, so PMM can reuse it for that exact fixture while RushRoar's exclusive Blueprint assets remain supplied by the RushRoar source PAK.

This demonstrates the intended learning path:

```text
external/manual solution
    -> exact structural and hash validation
    -> runtime user validation
    -> narrowly pinned production recipe
```

A future general adapter may replace a recipe only after the structural pattern itself is understood and proven.

---

## 14. Static item semantic transfer

`DA_StaticItemDataAsset` has a specialized path for combinations involving stale cooked layouts.

PMM classifies providers as:

```text
current-layout providers
stale-layout providers
```

Current-layout providers are first composed into a current cooked base through the binary adapter.

For stale providers, PMM requires at least two providers sharing one exact stale `.uasset` baseline. This is necessary because a single old provider does not reveal which differences are intentional mod edits and which are ordinary drift between old and installed game versions.

### Semantic intent inference

AssetReader exports a read-only semantic representation of rows and properties. PMM compares same-baseline stale siblings with the current target.

Typical inference rules include:

- One sibling matches current while another differs: the differing value is candidate intent.
- A strict stale-provider majority agrees and one outlier differs: the majority is treated as stale baseline and the outlier as candidate intent.
- Providers disagree without a current match or strict majority: ambiguity/conflict.
- Structural row/property additions or deletions are recorded explicitly rather than ignored.

### Fixed-size application

Supported intents are encoded as checked patches into a real current cooked base. Supported property classes are deliberately limited to representations that can be located and rewritten safely, such as selected fixed-size numeric properties and selected soft object paths whose required names already exist.

Before writing PMM verifies:

1. The target property bytes are uniquely locatable in the expected row serialization.
2. The cooked base still contains the exact expected bytes.
3. Replacement length is unchanged.
4. Patches do not overlap incompatibly.
5. The resulting output differs when patches are reported.

Unsupported shapes, ambiguous semantics, multiple stale baselines, insufficient same-baseline evidence, or failed byte preconditions reject the transfer safely.

---

## 15. Superset anchor

For DataTables PMM first attempts a stronger no-rewrite proof before semantic scalar transfer.

It chooses the largest real cooked provider as a candidate anchor and asks whether every current-layout secondary request already exists in that anchor at the same Vanilla coordinate and value.

Example:

```text
Small provider:
  Speed = 2

Large provider:
  Speed = 2
  Health = 500
  WorkSuitability = 10
```

If every byte requested by the small provider is already present in the large provider, PMM may preserve the large provider unchanged.

The proof also guards against hidden coordinate drift. After excluding explained secondary requests, the old Vanilla span may contain only a tightly bounded residual difference. Large or continuous unexplained changes reject the anchor.

This mode is a proven inclusion relationship, not "largest file wins."

---

## 16. DataTable scalar transfer

If the DataTable superset proof fails, AssetReader exports a semantic map for Vanilla and every provider.

PMM chooses the largest cooked provider as the real base because it best preserves its structural additions. The adapter then visits Vanilla rows/properties plus relevant secondary additions and asks what information must be transferred into that base.

### Compatible example

```text
Mod A:
Rows[Boar].MovementSpeed = 180

Mod B:
Rows[Boar].WorkSuitability_MonsterFarm = 1
```

The two scalar properties are independent and can both be retained.

### True conflict example

```text
Mod A:
Rows[Boar].MovementSpeed = 180

Mod B:
Rows[Boar].MovementSpeed = 300
```

PMM creates one `DataTableConflict` for:

```text
Rows[Boar].MovementSpeed
```

It does not discard unrelated changes elsewhere in the table.

### Supported write model

The adapter applies fixed-size scalar replacements to the base `.uexp` using semantic offsets and byte preconditions. It validates type/kind compatibility, equal encoding length, offset locality, and patch overlap.

### Unsupported structural cases

Examples include:

- A secondary adds a row absent from both Vanilla and the chosen base.
- Providers disagree on a newly added row/property with no Vanilla baseline.
- The base deletes a Vanilla row/property that a secondary modifies.
- A secondary requests a structural deletion that scalar transfer cannot encode.
- A property is not a supported fixed-size scalar.
- Type or scalar representation changes.
- The expected encoded bytes cannot be uniquely located.

Those cases remain Unsupported rather than being approximated.

---

## 17. Contained-delta superset

This adapter targets certain variable-size UE5.1 separated `.uasset + .uexp` cooked packages, including compatible Blueprint/Kismet families.

Size is only an ordering heuristic. PMM tries every provider as a prospective anchor until one proves that it contains all others.

The proof requires, among other conditions:

1. Every secondary Vanilla-relative `.uexp` edit hunk occurs exactly in the anchor.
2. Vanilla NameMap bytes remain an exact prefix of the secondary.
3. Secondary NameMap additions are prefix-contained by the anchor.
4. The same prefix relationship holds for the ImportMap.
5. Export-map topology is unchanged.
6. Differences in export metadata are limited to generated serial size/offset bookkeeping.
7. Export payload chains and `.uexp` lengths are coherent.
8. DependsMap, Asset Registry, and PreloadDependencies remain compatible with the proof.
9. Other sidecars are either Vanilla-identical or anchor-identical.
10. Package-summary differences are limited to mechanically derived fields permitted by the proven growth.

On success, the output is the real anchor family unchanged. PMM does not reserialize the Blueprint.

On failure, the adapter reports why no provider is a proven contained superset and routing continues to the relocatable adapter.

---

## 18. Relocatable delta

This is the generic advanced path for small variable-size families where no provider completely contains the others, but independent `.uexp` hunks and relocation bookkeeping can still be composed.

PMM selects a structural anchor, normally the largest family. Providers with identical topology and identical `.uasset` bytes are treated as anchor variants. Different values within such variants become true conflict rows instead of silently choosing one edition.

For each non-variant secondary provider PMM:

1. Computes Vanilla-relative `.uexp` edit hunks.
2. Computes how the anchor changed the Vanilla coordinate space.
3. Rejects secondary hunks that overlap anchor-changed regions.
4. Maps each Vanilla coordinate into the anchor's current coordinate space.
5. Verifies the mapped destination still contains the expected Vanilla bytes.
6. Applies disjoint hunks.
7. Inspects `.uasset` differences.
8. Requires each metadata hunk to be a small fixed-width value.
9. Proves that its arithmetic difference equals the secondary `.uexp` net length change.
10. Adjusts the corresponding current anchor metadata value with overflow checks.

Unsupported sidecar topology changes, non-relocation `.uasset` edits, overlapping regions, ambiguous mapping, or failed preconditions reject the provider set.

This adapter composes verified relocations; it does not guess arbitrary Unreal package structure.

---

## 19. Shared non-Unreal files

When multiple mods provide the same ordinary file:

- Byte-identical files become `Identical`.
- Differing files become `Unsupported` unless a format-aware adapter exists.

PMM does not call whole-file priority selection a merge. A future JSON, INI, CSV, Lua, or other format adapter must understand that format and preserve compatible edits explicitly.

---

## 20. Conflict model

PMM tries to expose disagreement at the smallest proven identity:

```text
binary byte offset
DataTable row/property path
StaticItem semantic property
relocatable structural variant byte
package-choice alternative
```

Each conflict row contains a stable decision identity, asset identity, property/offset, Vanilla value where meaningful, provider options, competing provider names, available choices, selected choice, custom value, status, and resolution origin.

The decision ID is derived from the asset, conflict path, and exact provider signature. This allows explicit manual choices to survive a new Analyze only when the underlying case remains the same.

### Priority-derived selection

If the user has not made a preserved explicit choice, PMM selects the highest-priority provider among the actual competing providers when that provider is a valid option.

The row records:

```text
ResolutionOrigin = Priority
```

A direct user selection records a manual origin and overrides subsequent priority defaults for the same exact decision identity.

### Custom values

Some adapters support `Custom`. Build serializes the custom token only when the adapter can validate and encode it safely. An empty custom value leaves the decision unresolved and blocks Build.

---

## 21. Analyze outputs

Analyze does not create the final compatibility PAK.

Its principal durable outputs are:

```text
State/merge-plan.json
State/last-scan.json
Workspace/Review/<case metadata and reports>
```

The merge plan records the contract required to reproduce the result, including:

```text
plan schema
PMMCore engine identity
engine profile
Mappings.usmap SHA-256
creation time
source-library signature
Vanilla PAK-set signature
full merge-order signature
effective output-changing order signature
source mod names, hashes, sizes, priorities
effective source set after package suppressions
asset modes and providers
conflict/decision rows
deployment suppressions
current-patch status when applicable
```

Analyze publishes durable metadata and review evidence, then deletes its temporary cooked extraction data.

### Current-patch short circuit

When a managed PMM patch already proves the exact active source set, mappings, relevant order identity, and output identity, Analyze may record that the set is already reconciled rather than rebuilding an equivalent plan.

---

## 22. Plan staleness and Build gating

Before Build, PMM refuses stale or incomplete plans.

It verifies at least:

```text
plan exists
plan schema matches
PMMCore identity matches
engine profile matches
active source signature matches
Vanilla PAK-set signature matches
merge-order signature matches
Mappings.usmap exists and matches
current set is not already satisfied by the exact selected patch
no Unsupported assets remain
all decisions are resolved
all Custom decisions have values
```

Changing an active source PAK, game PAK, mappings file, source priority, package selection, or required decision invalidates the previous Build authorization.

Unsupported is a hard blocker because PMM must not present a partially reconciled overlay as a complete compatibility result.

---

## 23. Build replays the proofs

Build does not trust a cooked output left behind by Analyze.

For every planned output asset it:

1. Re-extracts the exact provider family from the active source PAKs.
2. Re-extracts the current Vanilla family.
3. Revalidates the selected recipe or adapter.
4. Reapplies stored resolution rows where required.
5. Writes the result under a fresh temporary `PatchRoot`.

If an adapter no longer validates, Build stops and requires Analyze again.

This replay protects against files changing between Analyze and Build and keeps the plan as reproducible authorization rather than a cache of blindly trusted cooked bytes.

---

## 24. What enters PatchRoot

Output-producing modes include:

```text
BinaryAuto
BinaryConflict after resolution
StaticItemAuto
StaticItemConflict after resolution
SupersetAuto
DataTableAuto
DataTableConflict after resolution
ContainedSupersetAuto
RelocatableAuto
RelocatableConflict after resolution
KnownRecipeAuto
accepted ManualSolutionExperimental
```

The following do not enter the compatibility overlay:

```text
Identical
PackageChoice
Unsupported
assets supplied by only one source mod
```

If PatchRoot remains empty, PMM reports that no compatibility overlay is required because the shared content is identical or otherwise needs no rewritten override.

Before packing, PMM verifies that every generated `.uexp` has its corresponding `.uasset` header.

---

## 25. PAK construction and validation

PMM packs the temporary root with:

```text
repak pack <PatchRoot> <OutputPak> --version V11
```

The output name uses PMM's reserved late-loading namespace:

```text
zzzzzzzzzz_PMM_Merge_<timestamp>_P.pak
```

The repeated `z` prefix is intended to make the PMM overlay load after ordinary source PAK names so its reconciled logical paths override the conflicting provider copies.

After packing PMM verifies:

1. The expected output file exists.
2. `repak info` reports PAK version V11.
3. `repak list` can index the generated PAK.
4. The PAK contains entries.
5. No `.uexp` entry is orphaned from its `.uasset` header.

Because repak's current output is uncompressed, PMM deliberately keeps the compatibility overlay minimal.

---

## 26. Build manifest and output evidence

Beside the PAK, Build writes:

```text
<output>.pak.manifest.json
```

The manifest records information such as:

```text
schema and engine identity
creation time
output filename, size, and SHA-256
overlay policy: keep source mods installed
source-library and Vanilla signatures
merge order and effective order
Mappings.usmap SHA-256
patched mods
patched assets and modes
deployment suppressions
manual experimental runtime status
decisions and decision signature
per-asset output part size and SHA-256
patch-content signature
```

The output evidence identifies the exact `.uasset`, `.uexp`, and `.ubulk` bytes produced for every reconciled family. This distinguishes two patches built from the same source set but different legitimate conflict choices.

Build leaves the output in PMM's managed build library. It does not modify Palworld until Deploy.

Older current outputs are moved into retained patch history according to the saved-patch lifecycle.

---

## 27. Deploy model

Deploy synchronizes the desired managed state into Palworld's `~mods` folder:

```text
active source PAKs not suppressed
selected compatibility overlay, when required
selected overlay manifest
removal of obsolete PMM-managed copies
```

It does not assume that any same-name file in the game folder belongs to PMM. Unknown same-name hashes block overwrite or deletion.

### Transaction phases

1. Recompute deployment context after Palworld is closed.
2. Stage every desired copy on the same volume as `~mods`.
3. Verify every staged SHA-256.
4. Back up every existing file that may be removed or replaced.
5. Record transaction metadata.
6. Commit managed removals and same-volume moves.
7. Verify hashes in their final destination.
8. Write deployment state and clear completed removals.
9. Retain bounded rollback backups.

If commit has begun and a failure occurs, PMM attempts to remove partial current files and restore every verified backup. Incomplete rollback retains recovery metadata and warns the user not to launch the game.

The final deployed model is still:

```text
original source mods + one selected PMM compatibility overlay
```

---

## 28. Worked example

Source Mod A contains:

```text
Pal/.../X.uasset
Pal/.../X.uexp
Pal/.../A_Exclusive.uasset
Pal/.../A_Exclusive.uexp
```

Source Mod B contains:

```text
Pal/.../X.uasset
Pal/.../X.uexp
Pal/.../B_Exclusive.uasset
Pal/.../B_Exclusive.uexp
```

Both providers modify `X`, so PMM analyzes and rebuilds that family.

The PMM overlay contains only:

```text
Pal/.../X.uasset
Pal/.../X.uexp
```

Deployment contains:

```text
Mod_A.pak
Mod_B.pak
PMM_Overlay.pak
```

At runtime:

```text
A_Exclusive comes from Mod A
B_Exclusive comes from Mod B
X comes from the PMM overlay
```

The complete mod setup is integrated even though the overlay itself does not physically contain every source asset.

---

## 29. AIIO and manual exact-case solutions

Analyze and external-AI packaging are separate operations.

Analyze publishes case metadata under Review but does not automatically create a handoff ZIP or copy complete source PAKs.

When the user explicitly requests an AI handoff, AIIO re-extracts only the exact unsupported files/families from current Vanilla and involved providers. It includes logical paths, hashes, case identities, reports, mappings identity, and instructions needed by an external solver.

A returned cooked solution must follow the manual-solution contract, including:

```text
solution.json
cooked/<exact selected asset family>
```

PMM validates:

1. Safe archive paths and size limits.
2. Exact case ID and asset identity.
3. Case ID recomputation from pinned inputs.
4. Current provider PAK names and SHA-256 values.
5. Current mappings identity.
6. Re-extracted Vanilla/provider topology, size, and SHA-256.
7. Exact returned family topology with no unrelated cooked files.
8. Read-only AssetReader probe.
9. Output size and SHA-256 pinning.
10. Explicit user acceptance of experimental runtime risk.

An accepted manual solution enters the plan as:

```text
ManualSolutionExperimental
RuntimeStatus = UNPROVEN
```

It does not automatically become general PMM knowledge.

After successful gameplay validation, maintainers may promote it as:

- an exact hash-pinned production recipe for the same fixture; or
- a new general adapter, if a reusable structural proof has been implemented and tested.

---

## 30. Reader/writer safety boundary

AssetReader and UAssetAPI are used for read-only semantic and offset inspection.

Production merge writing follows two safe patterns:

1. Patch copied cooked bytes only when exact preconditions, representation, and destination are proven.
2. Preserve a real cooked provider unchanged only when a structural inclusion proof demonstrates that it already contains the required changes.

PMM does not use `UAsset.Write()` as a generic production serializer for arbitrary cooked Palworld assets.

This boundary avoids accidental loss of unknown package data, name/import/export metadata, Kismet structure, or game-version-specific fields.

---

## 31. What PMM deliberately does not do

PMM does not normally:

1. Unpack and repack all source mods into one autonomous megapak.
2. Select the highest-priority whole asset whenever a merge adapter fails.
3. Concatenate `.uasset` or `.uexp` files.
4. Treat Blueprints as text files.
5. Assume that the largest provider is semantically correct.
6. Accept a Knowledge recipe based only on filename or prose description.
7. Ignore an unsupported shared asset and continue as if the setup were fully compatible.
8. Convert an untested external-AI result directly into stable global behavior.
9. Redistribute complete Vanilla or third-party cooked assets through Knowledge metadata.
10. Modify Palworld during Analyze or Build.

These refusals are part of the product's correctness model, not missing convenience behavior.

---

## 32. Failure classes

PMM distinguishes several important failure categories.

### Infrastructure failure

Examples: missing PMMCore, missing mappings, AssetReader dependency failure, repak failure, unreadable PAK, unexpected adapter process error.

The operation stops because the engine cannot make a trustworthy decision.

### Unsupported structure

The tools work, but no adapter can prove a correct merge for the observed package shape. Build is blocked and Review/AIIO can expose the case.

### True conflict

The adapter has already proven that compatible changes can be retained but providers request different values for the same smallest identity. The user or priority system resolves only that identity.

### Stale plan

Inputs, game, mappings, priority, schema, or engine identity changed after Analyze. PMM requires Analyze again.

### Deployment identity conflict

A same-name game-folder file does not match a PMM-managed hash. PMM refuses to overwrite or delete it automatically.

---

## 33. Main implementation map

### PowerShell orchestration

- `PMM/Modules/Merge/MergeEngine.ps1`
  - engine readiness
  - grouping
  - Analyze routing
  - conflict rows
  - merge-plan persistence
  - Build replay
  - patch evidence and manifest
- `PMM/Modules/Merge/PakService.ps1`
  - `repak list/get/pack/info`
  - safe exact extraction
  - PAK/family verification
- `PMM/Modules/Library/LibraryService.ps1`
  - source library identity and priority
  - patch selection
  - deployment planning and transaction
- `PMM/Modules/CKL/KnowledgeRecipeService.ps1`
  - CKL lookup
  - exact production-recipe validation
- AIIO/manual-solution services
  - review case identity
  - handoff packaging
  - returned-solution validation

### PMMCore adapters

- `Development/Source/PMMCore/src/PMM.Core/BinaryRangeMergeAdapter.cs`
- `Development/Source/PMMCore/src/PMM.Core/SupersetAnchorAdapter.cs`
- `Development/Source/PMMCore/src/PMM.Core/ContainedDeltaSupersetAdapter.cs`
- `Development/Source/PMMCore/src/PMM.Core/RelocatableDeltaAdapter.cs`
- `Development/Source/PMMCore/src/PMM.Core/Semantic/DataTableMergeAdapter.cs`
- `Development/Source/PMMCore/src/PMM.Core/Semantic/StaticItemDataAssetAdapter.cs`
- `Development/Source/PMMCore/src/PMM.Core/Semantic/SemanticIntentInference.cs`

The packaged runtime assemblies under `PMM/Engine/` are the executable counterparts of the source snapshots.

---

## 34. Maintainer checklist when changing Analyze–Merge

A change to this pipeline should answer all of the following:

- Does source identity remain hash-pinned?
- Does the plan invalidate when every output-relevant input changes?
- Does the adapter preserve independent changes from all providers?
- Are conflicts exposed at the smallest proven identity?
- Can the adapter reject unsupported structures without falling back to whole-file priority?
- Are all writes guarded by exact byte/structure preconditions?
- Does Build replay the proof from original current inputs?
- Can the output contain orphan sidecars?
- Does the manifest identify exact output bytes and decisions?
- Does the patch remain an overlay while source mods stay installed?
- Can Deploy distinguish PMM-managed files from unknown same-name files?
- Can a failed Deploy roll back verified managed changes?
- Are temporary cooked assets cleaned after Analyze/Build/AIIO?
- Does Knowledge remain exact and runtime-status-aware?
- Does an external/manual solution remain experimental until explicitly validated?
- Have architecture documentation, tests, and validation contracts been updated?

---

## 35. Concise technical summary

```text
Analyze:
  discover -> extract -> compare against Vanilla -> prove -> plan

Resolution:
  choose only genuinely incompatible values

Build:
  revalidate -> re-extract -> repeat merge proofs -> pack overlay

Deploy:
  install active source mods + selected overlay with hash verification and rollback
```

The core design principle is:

> PMM creates the minimum proven override content required for the original mods to coexist. It does not claim that placing every source file into one archive is equivalent to a safe semantic merge.
