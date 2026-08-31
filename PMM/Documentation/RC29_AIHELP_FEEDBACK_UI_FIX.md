# PMM 1.3.0 RC29 - AI & Help feedback and UI fix

Build: `PMM-v1.3.0-RC29-AIHELP-FEEDBACK-UI-FIX`

RC29 closes the first executed AIIO/UI acceptance findings without changing merge semantics or packaged engines.

## User-visible changes

- The exact-merge validation window is larger, DPI-aware and uses readable buttons.
- Detect/status stays first in the header, folders and optional Play are below it, and AUTO controls are last.
- Play is highlighted after a successful Deploy but is never presented as a required action.
- Help, AI repair, Feedback, Knowledge, color-scheme editor and AI Settings have distinct views and concise purpose text.
- Feedback can create a local, inspectable file for general comments, a PMM issue, an exact merge/validation or Knowledge/CKL. Online upload is visibly unavailable in this release.
- AI behavior and Game Reference controls are in AI & Help > Settings.
- Dark-theme selected rows repaint immediately after a scheme change.

## AIIO correctness

The RC28 `SelectedValue` error was not produced by AIIO preparation itself. The worker successfully created its request ZIP; the delayed WPF completion callback then ran inside the dynamic module created by `GetNewClosure()`, where `$Script:` no longer meant Bootstrap's UI scope. RC29 callbacks capture stable IDs only and call named UI functions.

Each diagnostic now has at most one active AIIO session. Preparing a session that already left Draft does not generate another request. Identical automatic UI errors reuse one open fingerprinted case. The known RC28 false cases are preserved as evidence and marked resolved during migration.

Ordinary validation and `WaitingForAI` do not raise the main badge. A badge indicates an Unsupported asset, real attention-eligible error, interrupted operation, returned candidate, requested data or required user decision.

## Trust boundary

`PMM_USER_FEEDBACK_V1` and exact validation exports remain local files for manual sharing. `PMM_FEEDBACK_TRANSPORT_V1` is only a future adapter name; no implementation, provider login, endpoint, background upload or implicit consent exists. Returned AI content remains untrusted data and cannot execute code, Apply Fix, Build, Deploy or publish Knowledge.
