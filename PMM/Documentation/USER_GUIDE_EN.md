# Palworld Manager Merger v1.1 — User Guide

## What PMM does

PMM is both a Palworld PAK mod manager and a compatibility merger. It keeps a local mod library, analyzes assets shared by multiple mods, builds one compatibility overlay, and explicitly deploys the selected source mods + optional overlay to Palworld.

## Normal workflow

1. Run `Start.cmd`. The public package includes the pinned PMM tools and verifies them before launch. PMM requires .NET Runtime 8.0.30; if that exact runtime is not already available, Setup downloads the pinned Microsoft win-x64 runtime once, verifies its SHA-512 and installs it portably inside the PMM folder. PMM does not compile itself on an end-user PC. repak may also obtain its Oodle runtime later when a PAK requires it.
2. Detect/select the Steam Palworld installation.
3. Import PAK/ZIP/7Z/RAR files, or import the current game `~mods` folder.
4. Use the **On** checkboxes to enable/disable source mods. Disabled PAKs are kept in PMM's library.
5. Arrange merge priority if needed: **top applies earlier / lower priority; bottom applies later / higher priority**.
6. Click **Analyze**.
7. Review **Analysis plan**. Automatic rows require no action.
8. If **Resolution & Review** opens with `DECISION REQUIRED`, choose the desired value/provider only for the real overlapping change.
9. If **Blocked shared assets** reports Unsupported, either disable an involved mod and Analyze again or use **HAND TO AI / MODDER** for the advanced workflow.
10. Click **BUILD MERGE**. Build is local; it does not deploy to the game.
11. Select the desired saved patch in **Compatibility patches** and click **DEPLOY**.

## Manager-only mode

Select **No compatibility patch** to deploy active source mods without any PMM compatibility overlay. Analyze is optional. If a PMM overlay is currently deployed, manager-only Deploy removes that managed overlay while keeping saved patches in PMM's library.

## Saved patches

PMM may keep several patches built from the same exact source hashes + mappings, for example different choices from a conflict. Compatible patches have radio buttons. Select one and Deploy it without rebuilding. A patch built from another source set remains visible but is not selectable for the current set.

## Source mods and priority

- **Import** copies mods into PMM's library. Newly discovered source PAKs are appended at the bottom/highest priority until you move them.
- Drag a source row to insert it before/after another mod, or type its final 1-based position directly in **Order**. The list is always normalized to `1..N`; out-of-range numbers clamp to the first/last position and the intervening mods shift automatically.
- **Earlier / lower priority** and **Later / higher priority** remain available for one-step moves.
- Priority is field-level conflict precedence, not a whole-file winner: independent changes are union-merged, and only a real overlapping value defaults to the lower-listed provider.
- Manual choices in **Resolution & Review** override priority. Unsupported structures are never forced through by priority.
- Changing priority requires Analyze again before a new Build. Existing same-source patches stay available only as explicit rollback outputs if their order differs.
- Uncheck **On** to disable/back up a mod without deleting it.
- Re-check it to reactivate it.
- **Delete from library** removes the local managed copy and records the managed removal for the next Deploy.
- Deploy does not blindly delete unrelated PAKs PMM has never managed.

## Saves

The **Saves** tab can create world backups and restore a selected backup. PMM creates a safety backup before replacing a world during restore. Keep independent backups for important worlds as well.

## What Unsupported means

Unsupported means PMM cannot currently prove a safe composition for that exact shared cooked asset. It does **not** automatically mean the mods are fundamentally incompatible. You can disable a provider or use the advanced AI/modder handoff described in `AI_HANDOFF_AND_KNOWLEDGE.md`.

## Logs and troubleshooting

Start with `Documentation/TROUBLESHOOTING.md` and `Logs/PalModMerger.log`. Include the PMM version, exact error text and relevant AI_HANDOFF/review case when reporting a compatibility problem.

## Vanilla Game Reference and richer AI handoffs

In **Settings**, use **Build / refresh Game Reference** once after selecting Palworld.
PMM reads your installed `Pal-Windows.pak`, performs a fast bulk extraction into its own
`Data/GameReference` cache, and never modifies the game. When Palworld/mappings/reference
scope changes, PMM marks the cache Stale.

When you later use **HAND TO AI / MODDER**, PMM includes only a bounded relevant subset
of that Vanilla reference plus focused provider context. A fresh AI can therefore inspect
related game examples without needing your previous chat history.

After PMM accepts an AI/manual solution and you have actually tested it successfully in
Palworld, Settings -> **Create tested contribution...** creates one evidence ZIP that can
be sent to the PMM maintainer/community review. Only confirm PASS for the exact solution
you tested.


## Long operations in v1.1 Clean

Analyze, Build, and Game Reference run in child worker processes. Their progress bars are polled by the WPF UI, so the main window should remain movable and usable while the heavy operation runs. Do not start a second Analyze/Build until the current worker completes.

The original source mods are never consolidated into a MegaMerge. Build creates only PMM's compatibility patch.
