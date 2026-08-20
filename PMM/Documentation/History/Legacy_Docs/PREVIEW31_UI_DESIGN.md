# Preview31 UI design notes

## Goal

Make PMM explain its compatibility plan at a glance without changing the proven
merge semantics. The user should be able to answer three questions immediately:

1. Which shared assets did PMM find?
2. Which mods participate in each one, and what will PMM do with it?
3. Is any action required before Build/Deploy?

## Layout

The Mods & Merge tab is split into two user-resizable work areas:

- **Mod library** on the left: import, Analyze, filter, source/disabled/patch list,
  enable/disable/delete controls.
- **Compatibility workspace** on the right: Analysis Plan, True Conflicts,
  Unsupported assets, and Build/Deploy lifecycle controls.

The main vertical divider, Analysis/Conflict horizontal divider, and conflict
asset/details divider are draggable. Their positions, plus the main window size,
are persisted in `Data/config.json`. Settings includes **Reset workspace layout**.

## Analysis Plan

The old one-line summary is replaced by five counters and an asset table.

Each asset row displays:

- result: automatic, decision required/resolved, unsupported, or identical;
- asset filename;
- adapter family;
- exact provider mods participating in the shared asset;
- changed-path/decision count when available.

Selecting an asset exposes its full cooked path and adapter reason. A scope line
lists the mods whose shared changes are reconciled by the compatibility overlay
and explicitly states that unique-only mods remain normal source PAKs.

## Lifecycle controls

The obsolete one-choice Strategy selector is removed. `ConflictGroups` remains
an internal fixed production contract.

Deployment process settings live next to Build/Deploy:

- Close Palworld before Deploy;
- Force close if graceful shutdown times out.

Blocked shared assets stays collapsed when the count is zero and expands automatically
when Analyze produces Unsupported entries.

Build, Deploy, Remerge, Rebuild from scratch and Restore/remove merges use a
single horizontal action row. Progress appears underneath only when active.

## Non-goals

Preview31 does not add adapters, alter conflict semantics, modify PMMCore 0.7.1,
or change the deploy transaction algorithm. It is a presentation/workspace pass.
