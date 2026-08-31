# AIIO continuation handoff - RC30

RC30 keeps the RC27–RC29 local-first AIIO protocols and simplifies the visible workflow without weakening any trust boundary.

## Public workflow

- **AI assistance** owns existing diagnostic cases and explicit new-case creation. Selecting a row renders that exact case on the right. New case asks for a PMM feature, title, description and optional bounded log summary; the user may save it locally or create its safe manual ZIP directly.
- **AI reception** owns returned content. A standard `PMM_AI_RESPONSE_V2` routes by embedded `sessionId`. A recognized `PMM_THEME_AI_RESPONSE_V1` may arrive without a prior visible case but becomes only an uninstalled theme draft. Exact standalone cooked solutions still require their current exact case.
- **Feedback & Knowledge** owns `PMM_USER_FEEDBACK_V1`, exact `PMM_BUILD_VALIDATION_V1` exports, Knowledge/CKL comments and local artifact inventory.
- **Color scheme editor** and **AI Settings** remain local-only.

## Refresh and attention rules

- Never rebuild an ItemsSource because a child selector's routed `SelectionChanged` reached a parent TabControl.
- Do not call `Refresh-UI` after immutable validation. Update only the selected patch row, buttons and feedback identity.
- Ordinary validation, `WaitingForAI` and user-created cases are not main-tab attention. The badge is reserved for current Unsupported, automatic PMM errors, interrupted work or returned actionable data.
- AI subtab navigation refreshes only the selected surface.

## Performance contract

There is no permanent UI-responsiveness polling timer. The external `~mods` metadata fingerprint is checked at most once per 60 seconds while the active window is visible and no worker is running. Operation progress polling is lifetime-bound to its child process. Keep future provider transports and periodic synchronization disabled by default unless they can preserve an effectively idle PMM.

## Non-negotiable trust boundary

No provider login, remote upload, returned-code execution, implicit candidate activation, automatic Apply Fix, Build, Deploy, Restore, Knowledge promotion or publication exists in RC30. Returned archives remain untrusted data. Fix Lab and AI & Help have no authority over the deployed compatibility merge.

Continue from repository `Development/AI/AI_CONTINUE_HERE.md`, then `Development/AI/AIIO_1_3_0_HANDOFF.md`. Exact public identity remains **Palworld Manager Merger**, creator **laredson**.
