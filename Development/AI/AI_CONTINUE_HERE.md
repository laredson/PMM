# PMM 1.3.1 Mod Creation preview — continue here

The runnable `PMM/` directory is the authority for this branch. It starts from
GitHub `main` commit `9886c4fcb58654c81894f429a60bba5a704af6de` (published
v1.3.0 Stable plus its four post-release corrections) and adds the isolated
AIIO standalone-mod creation path. Never replace its packaged Host/Runtime
binaries from the older native-source snapshot without first proving source
parity.

Read in this order:

1. `Development/AI/CURRENT_STATE.md`
2. `Development/Docs/PMM_1_3_1_MOD_CREATION.md`
3. `PMM/Documentation/MOD_CREATION_AIIO.md`
4. `Development/AI/AIIO_1_3_0_HANDOFF.md` for the inherited AIIO base
5. `PMM/Documentation/AIIO_HANDOFF_RC30.md` for historical RC30 detail.

## 1.3.1 branch delta

- `CREATE_MOD` has a visible **New mod project...** entry point and persistent
  manual request/response exchange;
- capability set `PMM_CAPABILITIES_V2` adds focused Game Reference query plus
  exact/bounded current-Vanilla family extraction;
- `PMM_MOD_CREATION_CANDIDATE_V1` is staged as hostile data and binds the exact
  session, Game Reference, source-family and output hashes;
- the explicit `AIIOModBuild` worker revalidates, probes and packs a standalone
  PAK without deploying, publishing or promoting it;
- every created PAK contains inert `PMM/Metadata/created-with-pmm.json`, and the
  UI requires the public sentence `This mod was created with PMM assistance.`;
- every result remains runtime `UNPROVEN` until an exact Palworld test.

## AIIO implemented in RC27 and simplified for this release in RC30

- visible **AI & Help** tab with Help, AI repair, Knowledge/recovery and color-scheme editor views;
- persistent `PMM_AIIO_SESSION_V2` sessions and exact Unsupported-case continuity;
- supervised background preparation, incremental-data fulfillment, response import, candidate activation and artifact inventory;
- strict manual ZIP request/response boundary with safe paths, size limits, duplicate/symlink/executable/nested-archive rejection and parse-all-before-commit staging;
- explicit activation only for a current exact `PMM_MANUAL_SOLUTION_V1`; activation forces Analyze and cannot Build or Deploy;
- local diagnostics, save-activity evidence, operation journal, artifact registry/cleanup review, immutable deterministic build-validation events and inspectable feedback JSON;
- theme editor in AI & Help only, with a color and optional local PNG/JPEG image for every palette/ColorFlow brush, V1/V2 export and offline AI theme exchange;
- eleven hash-pinned JSON schemes plus Night/Light as official choices, separate from user schemes;
- equal responsive header halves, enlarged logo/title and immediate confirmed 100% progress.

RC28 added three runtime corrections proven by an executed RC27 workspace: deterministic validation IDs are complete lowercase SHA-256 values; canonical deployment-state schema 3 is normalized into AIIO's path-free snapshot; and candidate refresh always retains a real array for zero, one or many records under Windows PowerShell 5.1 StrictMode.

RC29 fixes the executed RC28 findings: delayed callbacks no longer access WPF controls through a closure-local `$Script:` scope; repeated errors reuse one automatic case; diagnostics reuse one active session; known RC28 UI-only cases are resolved during migration; WaitingForAI and ordinary validation do not raise the main badge; and the new Feedback view exports exact validation, Knowledge/CKL or general comments as inspectable local data. `PMM_FEEDBACK_TRANSPORT_V1` is only a disabled future boundary.

RC30 fixes the executed RC29 findings: routed child selection no longer rebuilds tabs or resets the Feedback merge selector; exact validation updates only its row and can offer direct tested-Knowledge feedback; the permanent 500 ms UI diagnostic timer is removed; the external metadata heartbeat is gated and reduced to 60 seconds; AI assistance shows the selected case or an explicit new-case form; AI reception routes responses and recognized standalone theme drafts; and Vanilla Game Reference is restored to normal Settings.

## Non-negotiable boundary

AI content is untrusted data. RC30 has no provider login, remote upload, returned-code execution, startup consent prompt, identity-reset UI, automatic Apply Fix, automatic Build/Deploy or automatic publication. A future provider adapter must remain outside the session/capability/validation core and preserve those explicit action gates.

Fix Lab and AI & Help have no authority over a deployed compatibility merge. Only the Compatibility patches panel may change it through Deploy with the selected patch or No compatibility patch, UNDEPLOY, or Delete merge.

Preserve schema-18 plan proofs, schema-9 build manifests, exact effective-patch reuse, Windows PowerShell zero/one/many collection guards, Gura package preflight and the narrowly proven FasterMounts/RushRoar path/provider/value rule. Never generalize it into “larger value wins.”

## Next gate

Run `PMM/Documentation/TEST_THIS_BUILD_1_3_1_MOD_CREATION.txt` on Windows before
promoting this branch. Static validation is not a substitute for WPF, Windows
PowerShell 5.1, repak/AssetReader or an in-game Palworld test.
