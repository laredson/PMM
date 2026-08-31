# Palworld Manager Merger 1.3.0 RC28

Build ID: `PMM-v1.3.0-RC28-VALIDATION-RUNTIME-FIX`

RC28 is a focused PowerShell/data correction over RC27. Packaged native executables, managed runtime, mappings, merge behavior, Fix Lab recipes, themes and sounds remain unchanged.

## Corrected from executed RC27 evidence

- Exact merge validation now derives a complete 64-character lowercase SHA-256 build ID. RC27 incorrectly reused the 24-character UI/cache identifier while its validation store correctly required 64 characters, so every Validate action failed with `Invalid build ID`.
- AIIO now normalizes canonical `deployment-state.json` schema 3 (`SourceMods`, `Patch`, `Deployed`) into its path-free deployment snapshot. It also continues to read a legacy `ManagedFiles` snapshot defensively.
- AIIO candidate refresh initializes a real array before its conditional query, preserving zero, one and many records under Windows PowerShell 5.1 StrictMode.
- The validation-result dialog now uses structured choice records in a separately initialized array, preventing the same enumeration rule from corrupting its buttons after the original ID error is removed.

The captured RC27 merge PAK was hash-valid and matched its schema-9 manifest. RC28 can validate that existing build; no rebuild is required.

## Preserved contracts

- RC22 effective compatibility-patch reuse;
- RC23 singleton guards;
- RC24 Fix Lab/deployed-merge ownership;
- RC25 responsive layout and Gura preflight;
- RC26 official/user themes, immediate 100% and exact semantic compatibility rule;
- RC27 local-first AIIO, untrusted ZIP boundary, persistent sessions, diagnostics, recovery, validation evidence and theme editor.

Cross-platform validation is in `Development/Tests/rc28_validation_runtime_regression_model.py`; the Windows PowerShell 5.1 contract is in `rc28_validation_runtime_regression.ps1`. Windows/WPF and Palworld acceptance remain required.
