# PalModMerger preview32 — engineering review

## Decision

Preview32 does **not** try to solve arbitrary Blueprint semantics with an AI guess.
It separates three layers:

1. **safe production proof** — determines whether Build may happen automatically;
2. **Semantic Lab evidence** — explains likely behavior and grows reusable
   knowledge without authorizing bytes;
3. **exact-case human/AI solution contract** — lets a reviewer return a cooked
   solution under explicit experimental risk, which PMM validates structurally
   and integrates into the same global overlay.

This keeps the path open toward code-level reasoning without giving a language
model or mod description authority over package integrity.

## Fly + Wing result

Real fixture:

- Fly PAK SHA-256:
  `8c9d74c5fbc220e4e0cbfef7952a73db53ff130bd7770761caa81e4e4e7bf080`
- Wing PAK SHA-256:
  `d3cc879ff2747cdfaf7544054fe5d6ce9ee5af083b6f6d0d6bd10efc464a3914`

`BP_WingGlider`:

| | Vanilla | Fly | Wing |
|---|---:|---:|---:|
| `.uasset` bytes | 11004 | 11031 | 11334 |
| `.uexp` bytes | 8656 | 8655 | 8808 |
| Vanilla-relative `.uexp` hunks | — | 12 | 17 |

All 12 Fly executable hunks occur exactly in Wing. Fly's 27-byte appended
metadata beginning at the same Vanilla insertion point is prefix-contained in
Wing's larger metadata growth. Package/export/dependency bookkeeping passes the
strict current-UE5.1 structural profile in the mirror gate.

Therefore preview32 can safely route this exact family as:

`ContainedSupersetAuto -> Wing real cooked family unchanged`

This is a **generic relationship proof**, not a `if Fly && Wing` exception.

The Python mirror also rejects deliberate mutations outside the proof:

- secondary byte not present in anchor;
- non-generated export metadata mutation;
- DependsMap mutation;
- non-prefix NameMap change;
- invalid export serial offset.

## Interaction with existing Fly merges

Nothing about the new adapter replaces Fly globally. It solves only the
`BP_WingGlider` family. In the same plan/build:

- `BP_PlayerBase` remains under the existing Relocatable path with MultiJump;
- `DA_StaticItemDataAsset` remains under StaticItem with Food/Stack/Early Aquatic;
- BreedFarm and PlayerStatus keep their existing adapters;
- all results go into **one final PMM overlay**.

Expected first Analyze with Wing + prior Triple-only set:

`Shared 6 | Auto 5 | Decisions 0 | Unsupported 0 | Experimental 0 | Identical 1`

With Quad re-enabled:

`Shared 6 | Auto 4 | Decisions 1 | Unsupported 0 | Experimental 0 | Identical 1`

The one decision should still be Triple vs Quad.

## Semantic Lab v0.1

This preview ships the module boundary and data model, not fake omniscience.
It records symbol diffs, generic effect hints, exact fixture knowledge and
`HEURISTIC_ONLY` non-selectable change-capsule candidates.

The next stages are intended to add read-only Kismet extraction, normalized PMM
Blueprint IR, CFG/effect analysis, and dependency-closed capsules. Only after a
capsule's dependencies can be proven should the UI allow a user to include or
exclude it independently.

## AI_HANDOFF

An Unsupported asset now gets a ready-to-send `AI_HANDOFF_<caseId>.zip`. The
user should not have to assemble or compress the evidence manually.

It contains exact cooked families, source PAKs, PMM reports, semantic evidence,
knowledge, instructions, optional context notes and a return-template.

A returned ZIP uses `PMM_MANUAL_SOLUTION_V1`. Before import PMM checks:

- safe ZIP paths;
- recomputed exact caseId;
- exact review input size/SHA-256;
- exact active provider PAK hashes;
- exact target asset/topology only;
- read-only AssetReader parse;
- output SHA-256 pinning.

The accepted solution remains `RuntimeStatus=UNPROVEN` and the UI explicitly
warns that gameplay semantics are not proven. Build revalidates the stored
solution and inserts it into the same global overlay.

## UI/lifecycle changes

- mod On checkboxes;
- compatibility patches separated from source mods;
- truly collapsible Analysis and Resolution panels;
- draggable/persisted Analysis-vs-Resolution share when both are expanded;
- unresolved decisions auto-open/highlight Resolution;
- Unsupported auto-opens, ranks provider-disable options and offers
  `Disable selected mod & Analyze`;
- AI handoff locate/import actions;
- fixed bottom Build/Deploy/Restore;
- Remerge/Rebuild removed.

The patch panel is deliberately not a free radio selector for stale patches.
PMM only considers a patch deployable when its source signature matches the
active set; selecting an arbitrary old patch would recreate a load-order state
PMM cannot prove.

## Preserved proven components

Byte-identical to preview31:

- `Core/LibraryService.ps1` (including preview30 transactional Deploy)
- `Core/SaveService.ps1`
- `Mappings/Mappings.usmap`
- BinaryRangeMerge adapter
- StaticItem adapter
- SupersetAnchor adapter
- DataTable adapter
- RelocatableDelta adapter

PMMCore version changed to 0.8.0 only because a new production adapter/CLI
contract was added.

## Validation completed here

- XAML/JSON/project XML parse checks: PASS
- 74 UI control names match all three XAML variants: PASS
- edited PowerShell delimiter/quote structural scan: PASS
- PMMCore C# delimiter structural scan: PASS
- real Fly+Wing Python structural mirror: PASS
- five negative contained-superset mutation gates: PASS
- synthetic three-provider routing plumbing: PASS
- internal SHA256SUMS: 78/78 PASS
- final ZIP integrity test: PASS

## Validation not possible in this environment

- Windows PowerShell parser/SmokeTest execution
- .NET 8 compile/run of PMMCore 0.8.0
- WPF visual render
- Palworld runtime

Those are the next user acceptance gate. Do not call Fly+Wing runtime-proven
until the actual preview32 overlay passes in game.
