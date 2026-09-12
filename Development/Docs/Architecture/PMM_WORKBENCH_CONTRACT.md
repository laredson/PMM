# PMM workbench contract (current)

Status: local implementation, validated in isolated Windows fixtures; real-game validation remains pending. Baseline c849942. User-approved architecture: Jugar / Crear / local knowledge. Older version-specific handoffs describe historical behavior and must not override this document.

## Product boundaries
Jugar applies known exact compatible solutions using one Auto/ColorFlow state machine. Crear owns research, repair, new-mod cases and their editor/AI/external-tool workflows. A case is independent of transport. An Unsupported analysis result creates a case only after successful publication, without navigation or AI dispatch. Imported/generated experimental solutions require explicit review and deployment.

## Module boundaries
Native Host/Runtime supervise startup/processes; editable scripts/resources own UI and orchestration. Native readers/writers keep versioned specialized interfaces. Module manifests declare dependencies/capabilities/contract/reload policy. A load validates the entire dependency graph before activation. Reload validates scripts before replacing functions, queues changes while operations run and preserves the prior active version on failure. Hot-reloadable modules contain pure top-level function definitions only: no initialization or subscriptions. Presentation/legacy initialization is declared Restart, so it cannot register handlers twice. Native/contract changes request restart.

## Persistence and identity
Atomic JSON writes use a same-volume temporary file and recoverable backup. Deployment records durable Prepared/Committing/Committed/Rollback phases before destructive steps; pending recovery blocks new deployment. Exact case revisions bind full inputs/order/mappings/Vanilla. Logical conflict identity is stable across evidence revisions. Legacy IDs and user text/history are retained.

## Knowledge and observation
Technical validity, automatic observation, user feedback, reviewer approval and current applicability are separate dimensions. Silence remains pending. Process uptime is observed execution, not proof of gameplay. No crash detected is not behavioral success. User feedback appears once after at least ten observed minutes; multiple candidates are grouped. Changes of inputs invalidate applicability, not history. This version uses local import/export only. Contributions exclude private paths, credentials, chats, saves and proprietary source bytes and import as pending.

## UI contract
Stable Jugar/Crear navigation; library, saves and history in Jugar; all case types, resources, tools and knowledge in Crear. Context actions support multi-selection and keyboard equivalents. Preserve draft/search/selection/scroll on navigation. Artwork belongs in headers; work surfaces remain legible. Preserve ColorFlow violet/blue/amber/green/turquoise with textual labels. High contrast uses system colors; reduce motion honors Windows animation settings.

## Delivery evidence
Source parity and game compatibility cannot be inferred from UI tests. Native binaries remain unchanged until separately reconciled. Shipping excludes Workspace and private fixtures. Every adapter lists tested capabilities and unavailable prerequisites; no general authoring claim from a single scalar test.

## Recorded decisions (implemented)

- **D001 — compatibility envelope:** keep AICASE IDs and readable V3 case files; ContractVersion 4 adds immutable evidence and publication visibility. A completed batch marker publishes Analyze results; partial batches cannot replace visible evidence. Adapters preserve old-response revisions.
- **D002 — conservative reload:** 39 declared module nodes. New domain service functions are replaceable while idle; legacy initialization, UI and loader scripts require a controlled restart. The manifest records this limitation instead of promising unsafe reload of side effects. Existing transport preview wrappers remain initial-load compatibility adapters.
- **D003 — explicit local trial:** generated activation requires a short-lived, one-use proof minted after actual input/provenance validation, then explicit user confirmation. A named human review or popularity alone never enables a candidate. Worker result consumption is serialized before modal callbacks.
- **D004 — truthful observation:** observation uses the selected executable path and exact committed deployment. Time beyond polling coverage and suspensions is excluded. No validated gameplay detector is shipped, so played is not asserted. Crash-report coverage is installation-local and is recorded.
- **D005 — source authority:** native binaries retain their hashes and version. Old source snapshots are not rebuild authority. Only editable PowerShell/Python/resources and their tests were changed; each optional native adapter still requires its own real input/output validation.
- **D006 — local exchange:** pending imports remain inert; no remote receiver, Git credentials, anonymous upload service or background publishing is part of this implementation. Reviewer approval in local Knowledge does not automatically compile a new production CKL recipe. Existing approved exact-match CKL recipes remain the Auto source.

Read [the current implementation state](../../AI/WORKBENCH_STATE.md) for exact test commands and remaining validation, and [the user guide](../../../PMM/Documentation/WORKBENCH.md) for the actual UI. Version-specific documents outside these current links are historical context, not proof of execution or permission to overwrite current contracts.