# RC29 static validation record

Candidate: `PMM-v1.3.0-RC29-AIHELP-FEEDBACK-UI-FIX`  
Date: 2026-08-30

## Proven in the build environment

- All delayed AIIO completion closures capture IDs and call named main-scope UI helpers; none accesses `LstAIIOSessions` or `LstAIHelpDiagnostics` through closure-local `$Script:` state.
- Repeated automatic errors are fingerprinted, diagnostics reuse one active session and known RC28 presentation-only cases have an explicit migration path.
- Badge logic excludes `WaitingForAI` and ordinary validation while retaining Unsupported, real error, interrupted-operation and returned-response attention states.
- `PMM_USER_FEEDBACK_V1` is local/manual, contains no PAK/save/log payload and declares remote upload unavailable.
- Default, English and Spanish XAML parse with 280 unique `x:Name` controls and exact control-set parity. The header ordering, AI & Help views, disabled upload boundary and AI Settings placement are structurally verified.
- Selected-row theme resources, optional Play readiness and the enlarged validation-dialog dimensions are present.
- All inherited RC23–RC28 cross-platform regression models pass.
- Application JSON parses; runtime binaries remain byte-identical to RC28; no runtime Workspace, user PAK, save, log, Game Reference data or Oodle DLL is shipped.
- Internal and outer SHA-256 inventories, ZIP CRC, safe member names, clean extraction and byte-for-byte package comparisons are required for the final artifacts.

## Still requires Windows

This environment does not provide Windows PowerShell 5.1, WPF, Steam or Palworld. Run `PMM/Documentation/TEST_THIS_BUILD_RC29.txt` before publication. In particular, verify the executed RC28 Workspace migration, DPI/layout, the real validation modal, no duplicate diagnostic/session after Prepare for AI, immediate dark-theme row repaint and optional Play readiness after Deploy.
