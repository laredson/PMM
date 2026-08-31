# Palworld Manager Merger 1.3.0 RC30

Build ID: `PMM-v1.3.0-RC30-LEAN-AI-VALIDATION-FLOW`

RC30 is an editable PowerShell/XAML/data correction over the user's executed RC29. Packaged native executables, managed runtime, mappings, merge algorithms, Fix Lab recipes, official themes and sounds remain unchanged.

## Responsiveness and idle work

- Child `SelectionChanged` events from ComboBox/ListBox controls no longer bubble into the main or AI tab navigation handlers. The Feedback merge selector therefore remains open and keeps its selected exact merge.
- Exact merge validation no longer calls the global `Refresh-UI` path. It updates the affected patch row, action buttons and feedback identity only.
- The permanent 500 ms dispatcher-delay diagnostic is removed.
- The external `~mods` metadata heartbeat runs every 60 seconds only while PMM is active, not minimized and not processing a job. It does not hash the whole mod library.
- AI & Help refreshes only the selected subtab. Theme application is skipped when the active scheme did not change.
- Analyze, Build, AIIO and Game Reference progress timers exist only while their supervised worker is running; the smooth-progress timer stops when no animation remains.

## Validation and feedback

- Both first-time and repeat validation use a 1040 x 360 DPI-aware dialog with 230 x 76 answer buttons.
- PASS/PASS_RECONFIRMED opens a second large prompt asking whether the user wants to contribute tested Knowledge.
- Accepting that prompt opens `AI & Help > Feedback & Knowledge`, selects the exact merge and prepares a merge-validation comment. Nothing is uploaded automatically.
- Local validation and ordinary user-created cases do not raise the main AI & Help badge. Errors, Unsupported assets, interrupted work and returned actionable AI data still do.

## Simplified AI & Help

The public surface is reduced to five focused views:

1. **AI assistance** — select an existing case and see that exact subject on the right, or press New case, choose the failing PMM feature, describe it and save locally/create its safe AI ZIP.
2. **AI reception** — receive a routed `PMM_AI_RESPONSE_V2` ZIP or a recognized standalone theme response. Returned data remains staged/inactive.
3. **Feedback & Knowledge** — exact merge validation, general/CKL comments, Knowledge and local storage/recovery.
4. **Color scheme editor** — local drafts, preview, install/export and offline AI theme exchange.
5. **Settings** — AI-only behavior.

Vanilla Game Reference is again present in normal Settings. A standalone theme response can be received without a prior visible case, but it opens only as an uninstalled draft. Exact cooked solutions remain bound to their exact case/hash/topology.

## Theme editor correction

Dynamic theme rows now copy back only fields the user actually edited. This prevents presentation/rebinding notifications under Windows PowerShell 5.1 from corrupting an untouched PMM Crystal clone and producing false low-contrast errors.

## Preserved contracts

The complete RC22–RC29 chain remains in force: effective patch reuse, singleton collection guards, Fix Lab/deployed-merge ownership, responsive 900 x 600 layout, Gura package preflight, official/user theme separation, immediate confirmed 100%, exact deterministic validation identity, canonical deployment snapshots, local-first AI trust boundaries and the narrowly proven FasterMounts/RushRoar semantic rule.

Cross-platform validation is in `Development/Tests/rc30_lean_ai_validation_model.py`. Windows PowerShell 5.1, WPF and Palworld acceptance remain mandatory.
