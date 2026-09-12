# PMM development contract

Read the [architecture and UI contract](Development/Docs/Architecture/PMM_WORKBENCH_CONTRACT.md) and [shared implementation state](Development/AI/WORKBENCH_STATE.md) before editing. These are current workbench authority; older handoffs are historical. Current user instructions take precedence.

## Shared workflow
1. Inspect git status, baseline commit, active work and contracts affected.
2. Preserve user work. Isolate overlapping tasks in another checkout; parallel agents sharing a checkout own disjoint files and coordinate integration.
3. Record contract decisions and include idempotent migration for persisted state.
4. Validate behavior in isolated fixtures and the Windows UI. Distinguish static, fixture, application-runtime and in-game evidence.
5. Update WORKBENCH_STATE with implemented/validated/pending work, baseline commit, tests, limitations and next action. Chats are not the sole authority.

## Invariants
- Keep Host/Runtime small. Never replace packaged binaries from older source without proving parity.
- One workflow serves Auto and ColorFlow; transports invoke shared services.
- Cases own identity/history. ZIP, MCP and client changes preserve identity.
- Import/build stage files; deployment is the game-mutation boundary.
- Complete family hashes, mappings and Vanilla determine applicability. Names, popularity and absence of crashes never authorize a merge.
- Imported knowledge is inert data and cannot approve itself or execute code.
- Persist atomically; unresolved deployment recovery blocks new deployment.
- Heavy work runs outside the WPF dispatcher.
- Never ship Workspace, saves, original game/mod content, logs or credentials.
- Preserve Windows PowerShell 5.1, English/Spanish and keyboard accessibility.
- Modules declare dependencies/contracts. Reload at idle boundaries; active operations pin their versions. Native changes can require restart.
