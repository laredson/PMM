# AIIO handoff — PMM 1.3.0 RC17 → AI & Help

> Historical RC17 reference. For continuation use `AIIO_HANDOFF_RC24.md`; RC24 preserves the later header, Detect, Settings, Play-ready UI, saved-patch reuse, Semiauto and Windows PowerShell compatibility contracts, and adds the Fix Lab/deployed-merge ownership boundary.

## Purpose

This document is the continuation contract for the AIIO / AI & Help work after PMM 1.3.0 stabilizes. Do not redesign the proven merge/fix/deploy core unless a test proves it necessary.

## Product identity

- Application: **Palworld Manager Merger (PMM)**.
- Creator: **laredson**.
- Current line at this handoff: **1.3.0 RC17**.
- Windows portable WPF/XAML UI driven by PowerShell; long processing is intentionally delegated to worker processes.
- Public builds must never ship user Workspace data, game PAK/UCAS/UTOC files, Gura test assets, or a proprietary Oodle DLL.

## Stable workflow contract

ColorFlow and AUTO share the same conceptual flow:

`Detect if needed → Import → [Fix Lab if needed: Game Reference dependency → choose output if needed → Repair → Deploy Fix] → Analyze → Build merge → Deploy → optional Play`

Key rules:
- Detect is hidden once a valid Palworld install is confirmed.
- Game Reference is a dependency, not a normal always-visible workflow step.
- Fix Lab may ask for a human output choice while Game Reference is building.
- `Auto ON` means a user-started workflow action continues automatically.
- `AUTO` is a one-shot run from the current state and does not toggle Auto ON.
- `Run Palworld after Deploy` controls the optional final Play step.
- Destructive or identity-sensitive operations use hash checks and transaction/rollback logic.

## Fix Lab

Case 001 currently supports legacy Gawr Gura v5 reconstruction through compact local recipes. Repaired deployable outputs must end in `_P.pak`.

Confidence is metadata, not a warning popup:
- runtime proven → very high confidence;
- structurally validated / known research output reproduced → high confidence;
- `DeployAllowed=false` is the actual blocker.

Fix Lab supports:
- build/current Game Reference;
- multiple variants;
- local out-of-process Repair;
- Deploy Fix;
- archived original source;
- Restore original mod to PMM library + Palworld `~mods`;
- Ignore exact legacy source hash;
- Delete legacy source using the same delete-everywhere contract as the main library.

## Main mod / merge lifecycle

- Deleting a source mod removes the exact hash from PMM and `~mods` but preserves any deployed compatibility merge until the user changes it explicitly in Compatibility patches.
- Saved compatibility patches have explicit Deploy / Undeploy / Validate / Delete semantics.
- Archive merge was intentionally removed.
- Delete merge removes the PMM build/metadata/validation and the exact deployed copy if present.
- External PMM merge files are recognized as deployment state; they must not silently resurrect a deleted internal build.

## Saves

RC17 introduces two collapsible panes on the right:
- Selected save.
- PMM backups made.

Backups are listed per world from `Workspace\Saves\Backups\<world id>`. A selected backup shows creation time, ZIP size, expanded content size, file count, and simple size/file-count delta versus the current world. Restore creates a safety backup first.

## Themes and completion audio

RC17 makes **Night** the default for new installs.

Settings now has two independent libraries:
- Color scheme radio list.
- Completion sound radio list.

Color schemes:
- built-in Night + Light;
- imported `PMM_COLOR_SCHEME_V1` JSON copied into `Workspace\Themes`;
- base Light/Night plus palette overrides;
- optional per-state ColorFlow colors;
- AIIO is explicitly allowed to generate or edit compatible scheme JSON files later.

Completion sounds:
- built-in none / bell / microwave / crystal;
- imported WAV/MP3/WMA copied into `Workspace\Sounds`;
- global volume 0–100%, default 50%.

See `Documentation/COLOR_SCHEMES_AND_SOUNDS.md` and `PMM_COLOR_SCHEME_EXAMPLE.json`.

## Existing AIIO module

Entrypoint: `Modules/AIIO/AIIO.ps1`.

Current AIIO responsibility is bounded Unsupported-case handoff packaging. Important safety contracts already present:
- Analyze is separate from AIIO.
- AIIO only packages exact current Unsupported review cases.
- Never include whole source PAKs.
- Extract exact provider/Vanilla file families only.
- Keep provider and Vanilla evidence separate.
- Validate case schema, provider hashes, input hashes and current plan identity.
- Use bounded raw/compressed budgets and safe temporary staging.

Do not remove these safeguards when creating the user-facing AI & Help tab.

## Merge knowledge & community handoff → AI & Help

The Settings section currently called **Merge knowledge & community handoff** contains capabilities that should migrate into the future **AI & Help** tab:
- Open Knowledge library.
- Open AI review cases.
- Create tested contribution.
- Open contribution folder.

Planned UI organization:
1. **Ask AI / Repair & compatibility help** — create/import AIIO handoffs and AI responses.
2. **Current unsupported cases** — explain what Analyze could not solve and package evidence.
3. **Knowledge** — bundled CKL / recipes / runtime-proven cases.
4. **Community contributions** — package tested solutions for maintainer review.
5. **Customization assistance** — optionally let AI generate `PMM_COLOR_SCHEME_V1` themes; later AI could generate safe UI presets without modifying core code.
6. **Diagnostics / Help** — logs, dependency status, troubleshooting and handoff creation when PMM itself fails.

When the AI & Help tab is ready, move these controls rather than duplicating their implementations. Prefer one service function per action with multiple UI entry points only when necessary.

## Architecture rules for the AI & Help implementation

- Keep WPF UI responsive; no PAK extraction or AIIO packaging on the dispatcher thread.
- Reuse existing workers and progress callbacks.
- Never let a presentation refresh convert a successful processing result into a failed operation.
- Avoid modal success/info dialogs. Use status text, persistent cards, ColorFlow and completion sound. Modal dialogs are for destructive confirmation, real errors, or unavoidable human decisions.
- Keep UI state and processing state separate.
- Preserve exact-hash provenance in all AI-generated or community-generated solutions.
- Do not mark something runtime-proven based only on structural equality or historical hash equality.

## Files most relevant to AIIO work

- `Modules/AIIO/AIIO.ps1`
- `Modules/Bootstrap/Start-PalModMerger.ps1`
- `Modules/Merge/*`
- `Modules/Library/LibraryService.ps1`
- `Modules/FixLab/FixLabService.ps1`
- `Modules/GameReference/*`
- `Modules/Shared/Paths.ps1`
- `Resources/UI/MainWindow*.xaml`
- `CKL/README.md`
- `Documentation/AI_HANDOFF_AND_KNOWLEDGE.md`
- `Documentation/COMMUNITY_KNOWLEDGE_WORKFLOW.md`
- `Documentation/GAME_REFERENCE_AND_COMMUNITY_CONTRIBUTIONS.md`
- `Documentation/MANUAL_SOLUTION_CONTRACT.md`
- `Documentation/FIX_LAB.md`

## 1.3.0 freeze guidance

Before starting major AI & Help work, freeze a known-good 1.3.0 release branch/tag. AIIO development should happen on a new branch so the stable manager/merge/fix workflow remains recoverable. The stable branch should contain no developer Workspace or test game assets.
