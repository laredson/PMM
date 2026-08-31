# PMM context snapshot — 2026-08-31 04:01

## Current authority

- Product: **Palworld Manager Merger**
- Creator: **laredson**
- Stable branch: `main`
- Stable commit: `9886c4fcb58654c81894f429a60bba5a704af6de`
- Active development branch: `1.3.1-mod-creation`
- Accepted development baseline: `d487fc6d434f7972da0d390e5bf406c38e45f37d`
- Runnable application authority inside the development branch: `PMM/`

## User acceptance recorded

The maintainer tested the current 1.3.1 build on Windows and confirmed that it starts and works correctly for the checked areas. The following recent fixes are visibly present and were reported working:

- `World Save` tab naming.
- PMM Crystal is actually active at startup.
- The revised New Mod Project dialog/fixes are present.
- `Open latest handoff` behavior is present.

This acceptance establishes `d487fc6` as the working baseline for the next changes. Do not revert the two 1.3.1 commits unless new evidence requires it.

## Scope boundary

The branch contains the first standalone mod-creation preview, but mod creation is not considered finished. A created standalone PAK remains `UNPROVEN` until tested in Palworld.

The immediate plan is to finish small release-polish items first, then create an intermediate publication-quality 1.3.1 candidate, and only after that move to the larger AIIO/Game Reference redesign in a separate chat/work phase.
