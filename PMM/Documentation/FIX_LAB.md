# Fix Lab

Fix Lab repairs explicitly supported legacy mods using only local inputs:

- the exact source PAK already owned/imported by the user;
- the user's Current Game Reference, extracted from the installed game;
- a compact reviewed CKL recipe;
- the native `PMMFixLab.exe` recipe engine.

It does not download or bundle pre-repaired third-party PAKs.

## Case 001: Gawr Gura v5

Accepted exact source PAKs:

- Gawr Gura v5 Normal;
- Gawr Gura v5 FullReplacement.

Either source independently supports all five outputs:

1. Original Full Replacement / 3 skins;
2. Normal Gura locked;
3. Red / Evil Gura locked;
4. Hooded Gura locked;
5. Hair 2 / panties / 3 skins.

The engine reconstructs the selected output locally, writes PAK v11, reopens it, verifies every entry byte-for-byte, validates required/forbidden paths, and then registers it under **Built outputs**.

Exact equality with a historical SHA-256 is useful regression evidence for a captured Game Reference, but it is not a universal requirement. A newer game version may produce different bytes while still passing the recipe's structural and runtime requirements.

## Output classes

- **Runtime proven**: the exact variant has prior in-game acceptance evidence.
- **Experimental repair**: complete and structurally validated, but still needs in-game acceptance.
- **Engine test**: validates internal primitives only and cannot be deployed.

Deployable Fix Lab outputs do not require a second warning confirmation. Built outputs show an evidence-based confidence level instead: runtime-proven repairs are VERY HIGH, structurally validated deployable repairs are HIGH, and engine-test milestones remain non-deployable.

## Workflow

```text
Import legacy mod
 -> Fix Lab recognizes an exact source signature
 -> build/extend Current Game Reference when required
 -> choose one output variant
 -> Repair in the background processing worker
 -> select the validated Built output
 -> Apply Fix transaction
 -> Analyze the updated mod list
 -> Build compatibility overlay when needed
 -> Deploy
 -> Play optionally
```

The WPF interface remains navigable while **Repair** runs. Another Workspace-mutating processing operation is rejected until the shared engine slot is free.

## Safety

- source PAKs are snapshotted and never modified in place;
- recipe input hashes and every transformation base are verified;
- output paths and transformation ranges are bounded;
- PAK readback is independent of the writer;
- Apply Fix validates hashes, archives the recognized legacy source, backs up only affected source/repair files, commits transactionally, and attempts rollback on failure;
- Fix Lab never removes, replaces, backs up or rewrites a deployed PMM compatibility merge or its sidecar; only the Compatibility patches panel owns that lifecycle;
- unknown or changed inputs stop with an evidence report instead of forcing a guess.


## Unified ColorFlow / AUTO contract (PMM 1.3.0 RC6)

Fix Lab no longer owns a parallel workflow. ColorFlow and AUTO query the same application workflow state:

```text
Detect (only if installation is unresolved)
-> Import
-> if an exact Fix Lab case exists:
     Current Game Reference if required
     -> choose output (only user choice when several outputs exist)
     -> Repair
     -> Apply Fix
-> Analyze
-> Build Merge
-> Deploy
-> Palworld optional
```

When the Palworld installation is already valid, the header Detect/status action remains visible but disabled. Detection/change controls remain in Settings. AUTO builds a required Current Game Reference without a confirmation modal. After a successful Apply Fix, the live repair warning is resolved even though the archived donor remains available for future variant builds.

Case 001 runtime evidence now includes **Normal - Locked** (`normal_locked`) after the 2026-08-27 in-game test confirmed the `_P.pak` output loads correctly and includes the repaired pelvis. Red/Evil and Hooded remain structural/experimental until separately accepted in-game.
## Reference build and output choice

For a supported case that requires Current Game Reference, PMM starts/builds the reference before Repair. When the recipe exposes more than one output, the output decision is independent of that background work: while Game Reference is being created, ColorFlow marks **Choose output** as the human action required. If the user chooses during the build, AUTO continues directly to Repair when the reference becomes ready. If no choice has been made when the reference finishes, AUTO stays waiting on **Choose output** instead of discarding the automatic run.

The source card also exposes **Ignore this legacy mod** and **Delete this mod**. Ignore is keyed to the exact source hash and allows Analyze/AUTO to continue with the unfixed source at the user's responsibility. Delete uses the same transactional delete operation as Imported Mods: it removes the PMM-library copy and the exact matching PAK from Palworld `~mods`, while preserving any deployed PMM compatibility merge and sidecar until the user changes them explicitly in Compatibility patches.

Opening Fix Lab or expanding Advanced no longer performs its dashboard scan inside the navigation event. WPF paints the selected/expanded view first, then a queued refresh uses one shared discovery snapshot. Cached state is reused for sixty seconds, and **Refresh Fix Lab** in the header provides the explicit on-demand path.

## AUTO + Game Reference concurrency (RC13)

When an exact Fix Lab case requires Current Game Reference, AUTO raises the exact **Settings Build / refresh Game Reference command** that is already runtime-proven in the manual path. This prerequisite kick occurs before the one-time Fix Lab presentation, so the worker is already starting/running when the user sees the output choice. AUTO presents the detected Fix Lab case by navigating to the tab **once per repair case/run**. That initial presentation exposes the recipe/output choice. After it happens, the watchdog never forces the tab again, so the user can freely move to Settings or elsewhere while the existing shared progress state continues to update both Settings and Fix Lab.

For multi-output recipes, AUTO is allowed to evaluate the Fix Lab human-choice state while Game Reference is running; the Game Reference worker blocks processing operations but no longer blocks `FixLabOpen`, `FixLabChooseVariant`, or `FixLabWaitReference`. If the user chooses before the reference finishes, AUTO waits and continues to Repair immediately after completion. If the reference finishes first, the action-required state remains on the output choice.

A Game Reference started manually does not break an already-active AUTO chain. Completion explicitly re-enters the unified workflow after the Game Reference process has been cleared. With SemiAUTO, starting Game Reference manually arms the normal continuation pipeline.

Successful informational completions are non-modal. PMM reserves modal dialogs for errors and explicit decisions. Completion audio is user-configurable (none/bell/microwave/crystal/custom plus volume); manual steps sound once, while an automatic chain suppresses intermediate sounds and sounds once at terminal success.
