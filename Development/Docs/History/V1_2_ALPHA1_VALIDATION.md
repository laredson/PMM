# PMM v1.2 Alpha 1 validation target

This alpha is intentionally an architectural step.

## Must pass

- `PMM.exe doctor --json` reports the build and required files.
- `PMM.exe security status --json` reports PowerShell availability/language mode without requiring FullLanguage.
- `PMM.exe probe` completes through the generic Runner.
- `Start.cmd` launches the existing PMM UI on a normal FullLanguage machine.
- PMM Host remains alive until the Runner/UI exits and records session evidence.
- A failed startup creates `AI_HANDOFFS/AI_HANDOFF_<reason>_<session>.zip`.
- Existing v1.1.1 FIX4 behavior remains intact: repak timeout/Smart Log/HeaderPath hardening and package-choice rule for Nexus #4935.

## Explicit non-goal of Alpha 1

Full PMM operation under PowerShell ConstrainedLanguage is **not yet implemented**. The Host is CLM-independent, but the existing UI/Core scripts still use WPF, Add-Type, generic .NET collections and other restricted language features. Do not publish Alpha 1 as a completed FullLanguage fix.
