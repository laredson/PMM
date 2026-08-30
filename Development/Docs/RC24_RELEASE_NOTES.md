# Palworld Manager Merger 1.3.0 RC24

Build ID: `PMM-v1.3.0-RC24-UI-FIXLAB-DEPLOYMENT-ISOLATION`

RC24 is a focused PowerShell/XAML correction over RC23. No merge adapter, manifest schema, cache schema, recipe, native executable or managed binary changed.

## Real RC23 evidence

The supplied RC23 Workspace contains a committed Fix Lab transaction at `20260829_224602_6209239d`. Its `GameBackups` records include the deployed merge PAK and sidecar in addition to Gura v5. This directly proves that Deploy Fix removed the current compatibility merge. The earlier Restore log also states that it retired stale overlays.

The supplied window captures identify a separate layout failure. The title used the only star-sized header column while the right action grid required at least 650 DIPs. When that star column approached zero, the wrapping subtitle created an extremely tall Auto row and hid the tab workspace below it.

## Implementation delta

- Header title column: fixed 245 DIPs; action grid: stretch with a reduced safe minimum; Detect surface stretches; action buttons may wrap.
- Fix Lab: `Queue-PMMFixLabUiRefresh` schedules tab/Advanced hydration at dispatcher `ContextIdle`; cached navigation interval is sixty seconds.
- Dashboard: one backup snapshot and one candidate discovery; ignored hashes are read once per discovery, not once per mod; the attention subset is derived from the shared snapshot.
- UI: `Refresh Fix Lab` moved from the collapsed Advanced card to the always-visible header.
- Fix Lab Deploy/Restore: no reserved merge-namespace enumeration, backup or removal.
- Source delete: removes only the exact managed source; preserves the deployed merge PAK/sidecar, Patch state, deployment timestamp and selected merge while clearing source-set freshness.
- User-facing confirmations and documentation now describe the same ownership rule.

## Regression assets

- `Development/Tests/rc24_ui_fixlab_ownership_regression.ps1`
- `Development/Tests/rc24_ui_fixlab_ownership_model.py`
- `Development/Docs/Validation/RC24_STATIC_VALIDATION.md`

The RC23 singleton regression remains active and must continue to pass.
