# Palworld Manager Merger 1.3.0 RC30

Build: `PMM-v1.3.0-RC30-LEAN-AI-VALIDATION-FLOW`

RC30 corrects the executed RC29 findings while preserving the complete RC22–RC29 compatibility, Fix Lab, theme, progress and local-first AIIO contracts.

Key changes:

- Feedback merge selection no longer resets because child selector events are ignored by parent tab handlers.
- Validate merge updates only the selected row and uses larger controls for both first and repeat validation.
- A successful validation can open exact manual Knowledge feedback directly.
- Idle UI polling is removed; the remaining external-mod metadata heartbeat is low-frequency and gated.
- AI & Help is reduced to AI assistance, AI reception, Feedback & Knowledge, color-scheme editor and AI Settings.
- Existing-case details and explicit new-case creation are separate; a new case can create its safe AI ZIP directly.
- Standard responses route by embedded session identity. Recognized standalone theme responses open only as uninstalled drafts.
- Vanilla Game Reference is present in normal Settings.
- Untouched theme fields are not rewritten during dynamic editor refresh, preventing false PMM Crystal contrast errors.

Remote upload, provider login, returned-code execution and automatic candidate activation/Apply Fix/Build/Deploy remain disabled. Follow `TEST_THIS_BUILD_RC30.txt` before public release.
