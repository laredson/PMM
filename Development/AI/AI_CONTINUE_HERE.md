# PMM 1.3.0 RC27 — continue here

The runnable `PMM/` directory is the authority for RC27. It is an AIIO local-first candidate built directly on RC26 and preserves the complete RC22–RC26 regression chain. Never replace it with either RC20 runtime or rebuild its packaged Host/Runtime binaries from the older native-source snapshot without first proving source parity.

Read in this order:

1. `Development/AI/CURRENT_STATE.md`
2. `Development/AI/AIIO_1_3_0_HANDOFF.md`
3. `PMM/Documentation/AIIO_HANDOFF_RC27.md`
4. `Development/Docs/RC27_RELEASE_NOTES.md`
5. The separate RC27 continuation package, beginning with `READ_FIRST_RC27.md` and the Master Handoff.

## Implemented in RC27

- visible **AI & Help** tab with Help, AI repair, Knowledge/recovery and color-scheme editor views;
- persistent `PMM_AIIO_SESSION_V2` sessions and exact Unsupported-case continuity;
- supervised background preparation, incremental-data fulfillment, response import, candidate activation and artifact inventory;
- strict manual ZIP request/response boundary with safe paths, size limits, duplicate/symlink/executable/nested-archive rejection and parse-all-before-commit staging;
- explicit activation only for a current exact `PMM_MANUAL_SOLUTION_V1`; activation forces Analyze and cannot Build or Deploy;
- local diagnostics, save-activity evidence, operation journal, artifact registry/cleanup review, immutable deterministic build-validation events and inspectable feedback JSON;
- theme editor in AI & Help only, with a color and optional local PNG/JPEG image for every palette/ColorFlow brush, V1/V2 export and offline AI theme exchange;
- eleven hash-pinned JSON schemes plus Night/Light as official choices, separate from user schemes;
- equal responsive header halves, enlarged logo/title and immediate confirmed 100% progress.

## Non-negotiable boundary

AI content is untrusted data. RC27 has no provider login, remote upload, returned-code execution, startup consent prompt, identity-reset UI, automatic Apply Fix, automatic Build/Deploy or automatic publication. A future provider adapter must remain outside the session/capability/validation core and preserve those explicit action gates.

Fix Lab and AI & Help have no authority over a deployed compatibility merge. Only the Compatibility patches panel may change it through Deploy with the selected patch or No compatibility patch, UNDEPLOY, or Delete merge.

Preserve schema-18 plan proofs, schema-9 build manifests, exact effective-patch reuse, Windows PowerShell zero/one/many collection guards, Gura package preflight and the narrowly proven FasterMounts/RushRoar path/provider/value rule. Never generalize it into “larger value wins.”

## Next gate

Run `PMM/Documentation/TEST_THIS_BUILD_RC27.txt` on Windows before public promotion. Static validation is not a substitute for WPF, Windows PowerShell 5.1, audio, repak/PMMCore, Palworld deployment and in-game validation.
