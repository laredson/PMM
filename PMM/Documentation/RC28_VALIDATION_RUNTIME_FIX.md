# PMM 1.3.0 RC28 — validation/runtime fix

Build: `PMM-v1.3.0-RC28-VALIDATION-RUNTIME-FIX`

RC28 repairs three execution failures found with a real RC27 workspace while preserving its merge and AIIO behavior.

1. **Validate merge:** deterministic build IDs are now complete lowercase SHA-256 values. The selected PAK and schema-9 manifest are not changed or rebuilt.
2. **AI & Help deployment context:** PMM reads canonical schema-3 deployment state (`SourceMods`, `Patch`, `Deployed`) and converts it to a sanitized AIIO snapshot. Suppressed source alternatives are excluded.
3. **AIIO candidate list:** zero, one and many candidates remain arrays under Windows PowerShell 5.1 StrictMode, avoiding the `.Count` failure seen during refresh.
4. **Validation dialog:** result buttons are built from structured records in an explicit array, so PowerShell cannot flatten the choices after the build-ID check succeeds.

RC28 retains the complete RC22–RC27 correction chain, the 13 official theme choices and separate user themes, immediate confirmed 100% progress, equal responsive header halves, Fix Lab isolation and the local-first manual-ZIP AIIO trust boundary.

AI content remains untrusted data. PMM does not log into a provider, upload automatically, execute returned code, apply a fix, build, deploy, restore, promote Knowledge or publish without an explicit user action.
