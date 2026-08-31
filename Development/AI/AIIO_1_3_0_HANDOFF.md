# PMM 1.3.0 — AIIO / AI & Help implementation handoff

**Project:** Palworld Manager Merger  
**Creator:** `laredson`  
**Baseline:** RC29, build `PMM-v1.3.0-RC29-AIHELP-FEEDBACK-UI-FIX`  
**Authority:** runnable `PMM/` tree plus the packaged RC29 binaries

## What RC27 implemented and RC29 preserves

AIIO is no longer merely a proposed module. RC27 exposes it through the top-level **AI & Help** tab and keeps the WPF layer thin over these services:

| Service | Responsibility |
|---|---|
| `Modules/AIIO/AIIO.ps1` | Exact Unsupported cases and bounded source handoffs |
| `AIIO.SessionService.ps1` | Persistent sessions, capabilities, history and incremental bundles |
| `AIIO.DiagnosticService.ps1` | Local diagnostic cases and sanitized evidence |
| `AIIO.ResponseService.ps1` | Strict response validation, requested data and staged candidates |
| `AIIO.ArtifactService.ps1` | Artifact inventory and conservative cleanup classification |
| `AIIO.ValidationService.ps1` | Deterministic build IDs, immutable local evidence and feedback files |
| `Operations/OperationJournal.ps1` | Recoverable operation state |
| `Saves/SaveActivityService.ps1` | Metadata-only save activity evidence |
| `Theme/ThemeEditorService.ps1` | Local V1/V2 editor, image assets and offline theme exchange |

Heavy preparation, requested-data packaging, response import, candidate activation and recursive artifact inventory run through `Modules/Operations/OperationWorker.ps1`. UI handlers render state and collect explicit decisions.

## Protocols

- session: `PMM_AIIO_SESSION_V2`;
- initial/incremental request: `PMM_AI_HANDOFF_BUNDLE_V2`;
- response: `PMM_AI_RESPONSE_V2`;
- capability registry: `PMM_CAPABILITY_REGISTRY_V1`;
- staged candidate: `PMM_AIIO_CANDIDATE_RECORD_V1`;
- deterministic local evidence: `PMM_BUILD_VALIDATION_V1`;
- inspectable manual comments: `PMM_USER_FEEDBACK_V1`;
- disabled future feedback adapter boundary: `PMM_FEEDBACK_TRANSPORT_V1`;
- color-scheme image pack: `PMM_COLOR_SCHEME_V2` inside `PMM_THEME_PACK_V1`.

RC29 transport remains manual local ZIP only. Feedback is inspectable local JSON and manual sharing only. Session exports distinguish Vanilla from every provider and never include whole source PAKs. Returned archives are untrusted data and pass Windows-safe path, case-insensitive duplicate, ADS/device-name, symlink, size, extension, nested-archive and schema checks before a candidate can be committed to staging.

## Authority levels

- Level A may read or extract only an exact allowlisted PMM/current-case target.
- Level B may create or stage data but cannot activate it.
- Level C remains an explicit user action at the moment it matters.

Only one candidate form can enter the current Merge path: an exact `PMM_MANUAL_SOLUTION_V1` cooked family bound to one still-current Unsupported case. The user must press **Use candidate**. PMM then imports it as experimental/unproven and forces Analyze. It never triggers Build or Deploy.

Full PAK candidates may be retained for personal compatibility inspection but are not activated in RC29. Declarative recipes, development patches and other response types remain staged until their own native validators/executors exist.

## Forbidden shortcuts

Do not add any of these without a separately reviewed design:

- automatic upload or provider login;
- credential discovery/export;
- executing returned PowerShell, Python, JavaScript, EXE, DLL or shell commands;
- automatic Apply Fix, Restore, Build, Deploy, Knowledge promotion or publication;
- a startup consent wizard or reset-installation-identity button;
- writing outside PMM's explicit roots;
- weakening candidate identity from exact hashes/topology to filenames;
- treating AI confidence as runtime proof.

The installation validation identity is a random secret protected with Windows DPAPI CurrentUser. It is not a hardware/account fingerprint and has no reset UI in RC29. Feedback remains a locally inspectable JSON file; no endpoint is present.

## RC29 UI/session correction

Background completion scriptblocks created with `GetNewClosure()` must capture only immutable IDs and call a named UI helper. Never dereference WPF controls through `$Script:` from such a closure: its dynamic-module script scope is not the main Bootstrap scope under Windows PowerShell 5.1.

Automatic UI errors use a stable fingerprint and increment one open diagnostic. Preparing a diagnostic reuses its existing non-archived AIIO session; a non-Draft session is opened but never re-prepared. `WaitingForAI` and ordinary local validation are normal states and do not raise the main AI & Help badge. The badge is reserved for a returned candidate/data/user decision, an open attention-eligible error, an interrupted operation or a current Unsupported asset.

## Existing PMM contracts to preserve

1. Analyze plan schema 18 and build-manifest schema 9.
2. Effective patch reuse only after complete shared-topology, provider/hash, adapter, decision/automatic-resolution, mappings, Vanilla, recipe/rule and priority evidence matches.
3. Exact FasterMounts/RushRoar automatic resolution only for its pinned asset, property, provider set and canonical 10/1 values.
4. Gura complete outputs are mutually exclusive and are resolved before expensive asset enumeration.
5. Zero/one/many collections remain arrays under Windows PowerShell 5.1 StrictMode.
6. Fix Lab Apply/Restore, source-mod operations and AI & Help never alter a deployed PMM compatibility patch. Only Deploy/No compatibility patch, UNDEPLOY and Delete merge may do so.
7. Confirmed progress at 100% is immediate; interpolation is presentation-only and never exceeds proven progress.

## Themes

Settings follows the sound architecture: eleven hash-pinned release JSON schemes plus Night/Light appear under Official PMM schemes; installed definitions under `Workspace/Themes` appear in a separate bordered user collection with Add/Open-folder actions. Official IDs cannot be shadowed.

The editor exists only in AI & Help. Every palette and ColorFlow brush has a required fallback color plus optional local PNG/JPEG image. V2 packs keep assets local, hash-bound and size/dimension constrained. Offline AI theme responses become drafts; they are never installed automatically.

## Next engineering work

RC29 first needs the full Windows checklist in `PMM/Documentation/TEST_THIS_BUILD_RC29.txt`. After acceptance:

1. add malicious/positive ZIP fixtures for every response and theme boundary;
2. reconcile `Development/Source` with the packaged Host/Runtime before replacing binaries;
3. design optional provider/feedback adapters as transport-only components with explicit scope and consent, leaving the current session/capability/validation core unchanged;
4. keep the RC29 PowerShell 5.1 callback, zero/one/many and diagnostic/session reuse fixtures in every release gate.

When this document conflicts with an older RC or 1.2.x handoff, the RC29 runtime and this document win. The separate continuity package retains older documents only as historical evidence.
