# AIIO continuation handoff — PMM 1.3.0 RC24

Use `AIIO_HANDOFF_RC23.md` and `AIIO_HANDOFF_RC22.md` for the complete inherited AIIO, merge-proof and Windows PowerShell contracts. RC24 adds three boundaries that future **AI & Help** work must preserve.

## Current authority

- version: **1.3.0 RC24**;
- build ID: `PMM-v1.3.0-RC24-UI-FIXLAB-DEPLOYMENT-ISOLATION`;
- code authority: the complete RC24 `PMM/` tree in the Git-root-ready package;
- schemas remain Analyze plan 17 and build manifest 9;
- packaged native/managed binaries remain the unchanged RC21 authority.

## 1. Deployment ownership

AIIO/Fix Lab/source-library actions do not own the compatibility patch deployed in Palworld `~mods`. They may change source mods, clear Analyze freshness and recommend a new Analyze/Deploy, but must preserve the deployed merge PAK, sidecar, deployment Patch record and saved-patch selection.

Only the existing Compatibility patches lifecycle may change it: Deploy with a selected patch or `No compatibility patch`, UNDEPLOY, or Delete merge. Do not add an AI response/import/repair path that silently removes the current merge.

## 2. Responsive layout

Do not place a wrapping text/title column in a star slot that can be starved by adjacent auto/min-width action columns. RC24 reserves a stable header title width and allows actions to stretch/wrap. New AI & Help cards must remain usable at minimum window size and across normal Windows DPI transitions.

## 3. UI refresh boundary

Navigation events must be presentation-only. RC24 queues Fix Lab hydration at dispatcher idle, reuses a sixty-second cached dashboard and exposes an explicit Refresh button. AI & Help should follow the same model:

- paint the selected tab/card first;
- collect filesystem/hash/manifest state in a worker or a bounded shared snapshot;
- bind results afterward;
- coalesce duplicate refresh requests;
- provide a visible on-demand refresh when external state may change.

Do not perform recursive job scans, provider hashing, archive inspection, Game Reference validation or handoff generation directly inside tab selection or collapse/expand handlers.

## Inherited safety contracts

- Never create AI handoffs automatically during Analyze.
- Never include whole source PAKs in a standard AIIO bundle.
- Preserve provider/Vanilla provenance and exact hashes.
- Treat imported AI responses as data, not executable scripts.
- Keep zero/one/many PowerShell collections as actual arrays when they are counted/indexed.
- Preserve RC22 effective-conflict patch reuse proof; filenames or a patched-mod subset are insufficient.
- Do not call RC24 runtime-proven until its Windows checklist in `RC24_RELEASE_CANDIDATE.md` passes.
