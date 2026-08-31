# AIIO continuation handoff - RC29

RC29 keeps the RC27/RC28 local-first AIIO architecture and fixes the real Windows callback/session findings in the submitted executed RC28 Workspace.

## Scope rule for delayed callbacks

`GetNewClosure()` creates a dynamic module. In a delayed completion scriptblock its `$Script:` scope is not the main Bootstrap script scope. Every background AIIO completion therefore captures only immutable IDs/flags and calls one of these named main-scope helpers:

- `Complete-PMMAIIOPrepareUi`
- `Complete-PMMAIIOImportResponseUi`
- `Complete-PMMAIIOPendingDataUi`
- `Complete-PMMAIIOUseCandidateUi`
- `Complete-PMMAIIOCandidateAnalyzeUi`

Do not move WPF control access back into a closure.

## Diagnostic and attention rules

- `Register-PMMAutomaticErrorCase` fingerprints the type/title/message and increments an existing open case.
- `Get-PMMAIIOSessionForDiagnostic` reuses the diagnostic's active session.
- A session that is not Draft must not be prepared again.
- `WaitingForAI` is expected and does not set the main badge.
- The main badge is reserved for returned candidates/data/decisions, attention-eligible errors, interrupted operations and current Unsupported assets.
- Known RC28 `SelectedValue` and false merge-selection diagnostics migrate to `ResolvedByUpgrade`; their files are not deleted.

## Feedback protocols

- exact runtime validation: `PMM_BUILD_VALIDATION_V1`;
- manual comment: `PMM_USER_FEEDBACK_V1`;
- future disabled adapter boundary: `PMM_FEEDBACK_TRANSPORT_V1`.

The Feedback tab may bind a comment/export to an exact saved/deployed merge or Knowledge summary. Files are inspectable JSON in `Workspace\Validation\Feedback`. Sharing remains a user action outside PMM. Upload is not connected.

All earlier trust boundaries remain non-negotiable: no provider login, automatic upload, returned-code execution, implicit candidate activation, Apply Fix, Build, Deploy, Restore, Knowledge promotion or publication.

Continue from repository `Development/AI/AI_CONTINUE_HERE.md`, then `Development/AI/AIIO_1_3_0_HANDOFF.md`. Exact public identity remains **Palworld Manager Merger**, creator **laredson**.
