# AIIO continuation handoff — RC27

RC27 implements the local-first AIIO foundation described by the project handoff. The runtime source of truth is `Modules\AIIO`, with `OperationJournal.ps1`, `SaveActivityService.ps1` and `ThemeEditorService.ps1` as adjacent services.

Current protocol:

- session `PMM_AIIO_SESSION_V2`;
- request bundle `PMM_AI_HANDOFF_BUNDLE_V2`;
- response `PMM_AI_RESPONSE_V2`;
- capability registry `PMM_CAPABILITY_REGISTRY_V1`;
- candidate record `PMM_AIIO_CANDIDATE_RECORD_V1`;
- deterministic validation event `PMM_BUILD_VALIDATION_V1`.

The only transport in RC27 is user-mediated ZIP. Future provider adapters must sit outside the session/capability/validation core, preserve the same data contracts, display their exact scope and never gain implicit Level C authority. Do not add automatic upload, credential extraction, arbitrary tool execution, returned-code execution, deployment, publishing or Knowledge promotion.

Next implementation priorities after Windows acceptance:

1. Add contract tests in a Windows/PowerShell 5.1 runner for zero/one/many session, request and candidate collections.
2. Add fixture ZIPs for every archive rejection and exact-candidate positive path.
3. Reconcile the native PMMRuntime source snapshot before replacing the packaged launcher/runtime binaries.
4. Consider optional provider transports only after a separate consent, credential and security design is approved.

RC27 already routes session preparation, incremental-data preparation, response import, candidate activation/validation and the recursive artifact-inventory scan through the supervised operation worker. Keep the WPF dispatcher limited to presentation and explicit user decisions.

Exact public identity remains **Palworld Manager Merger**, creator **laredson**.
