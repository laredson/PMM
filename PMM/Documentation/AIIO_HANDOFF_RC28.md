# AIIO continuation handoff — RC28

RC28 keeps the RC27 local-first AIIO architecture and corrects its first real Windows-runtime findings.

- `AIIO.ValidationService.ps1` owns a dedicated full SHA-256 helper for deterministic build and manifest identities. Do not substitute the intentionally truncated `Get-PMMStableTextId`, which remains appropriate only for compact internal/cache IDs.
- `AIIO.SessionService.ps1` treats `LibraryService.ps1` deployment schema 3 as canonical and normalizes it at the AIIO boundary. Preserve defensive support for a legacy `ManagedFiles` object.
- `Refresh-PMMAIIOCandidates` must initialize `$rows=@()` and assign the conditional query separately. Do not collapse it back into `$rows=if(...)` under Windows PowerShell 5.1 StrictMode.
- `Show-PMMBuildValidationDialog` follows the same rule and stores structured `{ Result, Label }` records rather than nested positional arrays.

Current protocols remain `PMM_AIIO_SESSION_V2`, `PMM_AI_HANDOFF_BUNDLE_V2`, `PMM_AI_RESPONSE_V2`, `PMM_CAPABILITY_REGISTRY_V1`, `PMM_AIIO_CANDIDATE_RECORD_V1` and `PMM_BUILD_VALIDATION_V1`.

Transport remains user-mediated local ZIP. Returned content is data, never code. No provider login, automatic upload, arbitrary command execution, implicit candidate activation, Apply Fix, Build, Deploy, Restore, Knowledge promotion or publication is authorized.

Continue from repository `Development/AI/AI_CONTINUE_HERE.md`, then `Development/AI/AIIO_1_3_0_HANDOFF.md`. Exact public identity remains **Palworld Manager Merger**, creator **laredson**.
