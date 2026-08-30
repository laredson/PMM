# PMM 1.3.0 -> AIIO / AI & Help handoff

**Project:** Palworld Manager Merger (PMM)  
**Author:** `laredson` (always lowercase)  
**Canonical branch:** `1.3.0final`  
**Continuation baseline:** PMM 1.3.0 RC20, built directly over the user-tested RC19.

## Read first

Do not restart this project from the older 1.2.x handoffs. The supplied/current 1.3.0 application tree is authoritative. RC19 was runtime-tested by the user. RC20 is intentionally narrow: final header/detection/settings UX, a terminal Ready-to-play ColorFlow state, the public `3 beeps` sound label, and conservative persistent repeat-Analyze caches.

The next major feature is **AIIO**, presented to users primarily through a future **AI & Help** tab. AIIO should orchestrate existing PMM services rather than replace them.

## Product and workflow contract

PMM is a local Palworld mod manager, compatibility analyzer/overlay builder and Fix Lab repair platform. It keeps source mods separate and builds a compatibility overlay only for shared assets that require reconciliation.

The workflow state machine is:

`Detect (only if needed) -> Import -> [Fix Lab: Game Reference -> human variant choice -> Repair -> Deploy Fix] -> Analyze -> Build Merge when required -> Deploy -> Play optional`

After successful current deployment, ColorFlow ends on Start Palworld with `Ready to play / Everything is ready to play`. AUTO launches the game only when `Run Palworld after Deploy` is enabled.

Long operations must stay outside the WPF dispatcher. The UI must remain usable while Analyze, Build, Game Reference, Fix Lab Repair/validation, deployment preparation, or handoff generation runs.

## Runtime architecture

```text
PMM.exe
  -> Engine/PMMRuntime.exe
       -> WPF/PowerShell UI
       -> Modules/Operations/OperationWorker.ps1 for long work
       -> Engine/PMMFixLab.exe for native Fix Lab operations where applicable
       -> PMMCore / AssetReader / repak / portable .NET
```

Do not move expensive filesystem/hash/extraction/analysis loops back into UI event handlers.

## Services AIIO must reuse

### `Modules/AIIO/AIIO.ps1`

Already provides the real foundations for AI handoffs: bundle IDs/de-duplication, estimates, disk-space limits, current Unsupported/review cases, exact provider/vanilla extraction, metadata export, CKL context, ZIP verification, `Find-PMMAIHandoffForCaseId`, and `New-PMMAIHandoffBundle`.

Provider A, provider B and vanilla must remain distinguishable. Never flatten them into one ambiguous cooked folder.

### `Modules/CKL/`

Contains semantic knowledge, production recipe matching and tested contribution packaging. Knowledge is evidence; it is not permission to invent an automatic writer. Community/tested contribution UI should be absorbed into AI & Help while these services remain the backend.

### `Modules/GameReference/`

Game Reference is a local reusable reference built from the user's own Pal-Windows.pak and is not shipped publicly. AIIO should support an iterative loop: an AI can request exact additional current families, PMM expands/retains the appropriate reference locally, and a follow-up handoff includes only what is needed. Do not immediately delete historical/current reference data that may be reused; future Settings should expose retained reference versions and manual cleanup.

### `Modules/FixLab/FixLabService.ps1`, recipes, `Engine/PMMFixLab.exe`

Fix Lab is now a real local recipe/executor path. Case 001 established the reusable design: compare historical source/current structure; reconstruct against current providers rather than requiring identical SHA; use declarative/local repair primitives; preserve backups/revert; separate Repair from Deploy Fix; preserve human cosmetic/behavior choices; then return to normal Analyze. Do not regress this into copying a prebuilt golden PAK.

The `_P` naming convention is part of known Palworld/Fix Lab output handling where required.

### `Modules/Merge/MergeEngine.ps1` and `PakService.ps1`

RC20 adds conservative persistent repeat-Analyze caches:

- `Workspace/Cache/PakIndexesV1`: persists repak entry listings across worker processes; identity is path + length + LastWriteTimeUtc.
- `Workspace/Cache/AnalyzeGroupsV1`: caches only deterministic decision-free automatic shared-asset results when PMM build, mappings, vanilla quick signature, asset key/kind and provider name/hash/priority inputs are unchanged.

Unsupported/manual/AI solution paths, human decisions, and `KnownRecipeAuto` are deliberately not cached. Preserve that safety boundary; if future AI knowledge can change a result, add a knowledge-version identity or keep that route uncached.

### Library/deployment and Saves

Use the existing LibraryService and SaveService. AIIO must not create a second source of truth for active/disabled mods, priorities, merge patch lifecycle, pending removals, deployment transactions, rollback, backups or save backups.

## AI & Help recommended UI

Use progressive cards/sections rather than a developer dump:

1. **Help / diagnosis** — explain current PMM state and recommended next action, open logs/folders, create compact support diagnostics.
2. **AI repair / unsupported merge** — list AI-review cases, estimate/create exact handoffs, import a strictly validated AI response.
3. **Fix Lab AI extension** — for unsupported legacy mods, package source inventory/current reference comparison and accept declarative recipe proposals only.
4. **Knowledge / community** — move/present the existing Open Knowledge library, AI review cases, tested contribution creation and contribution folder here.
5. **Documentation** — searchable help, build ID, release notes and diagnostics.

## AI response safety direction

An AI response must be data-first and reproducible, e.g. `manifest.json`, `solution.json`, notes, declarative recipe/patch data, exact input expectations and output validation expectations.

Bind every response to exact case IDs, source hashes/family inventories, mappings identity, relevant Game Reference/current-provider identity, PMM schema/runtime version and required engine primitives. Reject stale/mismatched responses before writes.

Do **not** define an AI response as `run this PowerShell/Python/EXE from a ZIP`. The safe model is: **AI decides/plans; PMM validates and executes supported local primitives.** If a primitive does not exist, AIIO should report an engine capability gap.

## Future historical/current repair loop

The long-term target is:

1. user imports a legacy/broken mod;
2. PMM identifies historical source/provider structure where possible;
3. PMM retains/builds historical/current references available to the user;
4. PMM compares families/imports/exports/data/Blueprint structure;
5. a known recipe can repair locally and offline;
6. otherwise AIIO packages the exact historical/current evidence;
7. a successful new solution can later be promoted into CKL only after validation.

This is why Game Reference/version retention should become a managed library rather than ephemeral scratch space.

## UI and behavior rules

- responsive grids/splitters/collapsible cards; no fixed-window assumptions;
- dark-mode selected rows/tabs/combos must stay legible;
- ColorFlow colors remain visually dominant over themes;
- normal flow should avoid blocking confirmation dialogs;
- sound defaults: Auto = Microwave finish, Semiauto = OK, Manual = Good, Attention = Short alert, Error = 3 beeps;
- manually clicking Play is not a processing-completion sound event;
- library selection handlers should not perform repeated heavy validation; stage changes and apply where appropriate.

RC20 header: transparent PMM logo; PALWORLD / MANAGER / MERGER in three lines; subtitle; a single detection/status button that is disabled once a valid installation is known; AUTO controls and game/mod folder/Play actions.

Settings: Apply changes is separated at the upper-right of Interface and Restore defaults resets UI/ColorFlow/sound preferences without erasing game path, language or the mod library.

## Repository/release hygiene

Public layout remains conceptually:

```text
.github/
Development/
PMM/
.gitattributes
.gitignore
LICENSE
README.md
```

`PMM/Workspace/` is local runtime state and must not be committed. Public releases must not contain user logs/saves, third-party PAKs, UCAS/UTOC, extracted vanilla assets or `oo2core_9_win64.dll`.

Before a public release: keep default/EN/ES XAML `x:Name` contracts identical; parse JSON; regenerate `PMM/Resources/Metadata/SHA256SUMS.txt`; verify ZIP CRC and extracted bytes; preserve licenses/notices; and do not call a new RC runtime-tested until it has actually run on Windows.

## First AIIO development steps

1. Start from `1.3.0final` and the supplied complete PMM 1.3.0 package.
2. Windows-smoke-test the RC20 delta over the user-tested RC19: startup/detection, Import/Analyze, known Fix Lab path, Build/Deploy, Ready-to-play ColorFlow, Settings Apply/Restore and second Analyze caching.
3. Freeze 1.3.0 behavior.
4. Inventory existing AIIO/CKL/GameReference/FixLab functions before adding services.
5. Add AI & Help as a thin UI over those services.
6. Define the AI response manifest/schema and strict validator before importing AI solutions.
7. Then add iterative Game Reference requests and recipe-authoring assistance.

When this document conflicts with an older 1.2.x AI handoff, the current 1.3.0 source/runtime plus this document wins.
