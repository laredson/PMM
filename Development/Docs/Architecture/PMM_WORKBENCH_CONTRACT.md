# PMM 1.3.2 repair contract

Baseline: `c849942a42e8c8a58d7cc2840017bcf4afaf42b6`. Branch: `1.3.2`. Updated 2026-09-12.

The user's repair request is the scope. The Jugar/Crear redesign remains parked on `1.4.0-ReUI`. This branch retains the 1.3.1 workspaces and selectively integrates shared case/persistence services with the existing UI.

- Cases own stable identity, immutable evidence and history. Successful Analyze registers one local case per unsupported asset/provider set without AI dispatch or navigation. Identical evidence is idempotent. User objectives, supporting families and source/transport choices survive refresh.
- ZIP, MCP and client changes preserve identity. Responses and pending actions bind an evidence revision. Legacy sessions/ZIPs remain readable through compatibility adapters. Imported knowledge/work orders are inert and cannot approve or execute themselves.
- Imports and builds stage files. Deployment is the game-mutation boundary. Full cooked-family and source hashes, selected mappings and current Vanilla establish applicability. Extraction freshness, semantic readability, structural merge proof and game runtime evidence are distinct.
- DataTable anchors must retain current rows/properties. A schema-evolution transfer is allowed only for an exact bundled rule that proves historical baseline and source intent while preserving current cooked data. A historical runtime result does not prove the new game build.
- Persist atomically and recover interrupted case/reference publication. Heavy work remains outside WPF. Windows PowerShell 5.1, English/Spanish and keyboard use remain required. The case service declares dependencies; this release requires restart. No live reload is claimed.
- Keep Host/Runtime small. Packaged native changes need demonstrated source parity. AssetReader remains read-only; PMMCore and other native binaries are preserved. Large native diagnostics remain complete in an associated file instead of per-line main-log writes.
- Never ship Workspace, saves, original game/mod content, local mappings, logs or credentials. Preserve pre-existing research/user files and the separate redesign branch.
- The user performs game launch/mod isolation. Do not launch Palworld or alter the installed mod set for these tests.

See [shared state](../../AI/WORKBENCH_STATE.md) and [repair validation](../Validation/PMM_1_3_2_REPAIR_VALIDATION.md) for implemented behavior and unresolved work.
