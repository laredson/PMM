# Palworld Manager Merger 1.3.0 RC29

Build ID: `PMM-v1.3.0-RC29-AIHELP-FEEDBACK-UI-FIX`

RC29 is an editable PowerShell/XAML/data correction over the user's executed RC28. Packaged native executables, managed runtime, mappings, merge algorithms, Fix Lab recipes, official themes and sounds remain unchanged.

## Corrected from executed RC28 evidence

- AIIO background completions no longer dereference WPF controls through the script scope of a `GetNewClosure()` dynamic module. The callback captures only stable IDs and invokes a named UI helper in the main Bootstrap scope. This fixes the real `SelectedValue` completion failure.
- Preparing a diagnostic reuses its existing active session. A non-Draft session is opened without generating another request. Repeated automatic errors reuse one fingerprinted case and increment its occurrence count.
- Known RC28 UI-only diagnostics for the callback failure and false validation-feedback selection are preserved but migrated to `ResolvedByUpgrade`, so they no longer demand attention.
- The main AI & Help badge ignores ordinary exact validation and `WaitingForAI`. It represents only returned candidates/data/decisions, attention-eligible errors, interrupted operations or current Unsupported assets.
- The exact-merge validation dialog is DPI-aware and uses larger 188 x 58 buttons with a larger readable surface.
- Validation feedback selects its exact saved/deployed merge inside the Feedback tab instead of depending on a transient Mods & Merge row selection.

## AI & Help surface

- Help and AI repair include short descriptions of their distinct roles.
- Feedback creates inspectable `PMM_USER_FEEDBACK_V1` JSON for general comments, PMM issues, an exact merge/validation or Knowledge/CKL. Existing exact `PMM_BUILD_VALIDATION_V1` events can also be exported.
- Sharing is manual. The future `PMM_FEEDBACK_TRANSPORT_V1` boundary is visible but disabled; RC29 has no endpoint or automatic upload.
- AI-specific behavior and Game Reference controls are under AI & Help > Settings instead of the global Settings page.

## UI behavior

- Header order is Detect/status, game/mod folders plus optional Play, then AUTO controls.
- A completed Deploy highlights Play as ready but never opens an “action required” prompt for it.
- Theme application refreshes selected DataGrid/ListBox visuals after the resource swap, removing stale unreadable selected-row colors.
- Localized display separators are ASCII-safe under Windows PowerShell 5.1, preventing the observed mojibake.

## Preserved contracts

The complete RC22–RC28 chain remains in force: effective patch reuse, zero/one/many collection guards, Fix Lab/deployed-merge ownership, responsive 900 x 600 layout, Gura package preflight, official/user theme separation, immediate confirmed 100%, exact FasterMounts/RushRoar semantics, full SHA-256 validation identity and canonical schema-3 deployment snapshots.

Cross-platform validation is in `Development/Tests/rc29_aihelp_feedback_ui_model.py`; the Windows PowerShell contract is in `rc29_aihelp_feedback_ui_regression.ps1`. WPF and Palworld acceptance remain mandatory.
