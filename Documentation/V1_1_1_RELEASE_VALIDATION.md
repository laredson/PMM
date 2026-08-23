# Palworld Manager Merger v1.1.1 — focused validation

This checklist covers only the maintenance changes relative to public v1.1. Baseline merge behavior is covered by `V1_1_RELEASE_VALIDATION.md`.

## 1. Launch / identity

1. Extract the release to a clean folder.
2. Run `Start.cmd`.
3. Confirm the window/title reports **v1.1.1** and dependency verification succeeds.
4. Open Settings and confirm the log section identifies `Logs\PalModMerger.log` as the support file.

## 2. Normal Analyze regression

1. Import a representative multi-mod set already known to work on v1.1.
2. Run Analyze.
3. Confirm Analyze completes and the normal conflict/unsupported results remain consistent with v1.1.
4. Build/Deploy a known-safe case if desired; this release does not intentionally change merge semantics.

## 3. Exact-extraction timeout path

If the previously reported Hunter001 asset/mod combination is available, retry it. An individual `repak get` must never hold Analyze indefinitely. A genuinely stuck exact extraction should terminate after about 180 seconds and leave `repak get TIMEOUT` with PAK/entry context in the log. No partial extracted output should be accepted as success.

## 4. Smart Log behavior

Normal entries should resemble:

```text
[2026-08-22 13:00:00.123] [UI] [SESSION START] Palworld Manager Merger v1.1.1 | session=... | pid=...
[2026-08-22 13:00:00.200] [UI] Application initialized.
```

For a deliberately repeated identical `Write-PMMLog` event, confirm:

- the full message is written once;
- repeat checkpoints include `xN total`, `first=...`, and `last=...`;
- a checkpoint appears at x2, powers-of-ten milestones, or after about five seconds of continued repetition;
- when a different message arrives, any unreported repeat count is finalized with `REPEAT END`;
- closing the normal UI produces `SESSION END` with duration;
- a force-killed process may lack `SESSION END`, which is intentional diagnostic evidence;
- no `Logs\Archive` ZIP rotation is created by the final logger;
- distinct child-process output is preserved rather than truncated by logger policy.

## 5. Release boundary

Confirm there is no Fix Lab UI/runtime implementation in v1.1.1. Fix Lab remains the next separate development phase.

## FIX4 startup and validation workflow

The public launcher and maintainer validation are intentionally separate.

- End users run `Start.cmd`. It performs conditional dependency verification/repair and launches PMM. It does **not** run the source-contract smoke suite.
- Maintainers run `RUN_VALIDATION.cmd` before publishing. That command executes `SmokeTest.ps1` explicitly.
- Smoke-test output is persisted to `Logs/Validation.log` so validation failures survive a closed console window.
- A non-zero exit from the PMM application itself returns to `Start.cmd`, which displays the support-log path `Logs\PalModMerger.log`.

This separation is deliberate: source/XAML/release-contract assertions are publication QA, not a runtime prerequisite for an end user.
