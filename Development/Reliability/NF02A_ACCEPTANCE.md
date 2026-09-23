# NF02A Windows acceptance

Candidate: `PMMUnified-candidate.exe`
Package replacement: **NOT YET ALLOWED**

The candidate must be tested beside a complete current PMM package so external Modules/Resources/CKL/Engine dependencies are present.

## Static/build gate

Required:
- `go test ./internal/dispatch`
- `go test ./internal/runtime`
- `go test ./internal/supervision`
- `go test ./internal/uibridge`
- Windows Host test compile
- windows/amd64 candidate build
- offline build settings
- output outside repository

## Windows behavior gate

Run candidate from PMM package root/staging copy:

1. `PMMUnified-candidate.exe doctor --json`
2. `PMMUnified-candidate.exe security status --json`
3. `PMMUnified-candidate.exe runtime self-test`
4. `PMMUnified-candidate.exe runtime doctor`
5. `PMMUnified-candidate.exe runtime security`
6. normal double-click/start
7. verify native splash appears
8. verify WPF UI becomes foreground owner
9. close UI normally
10. verify Host session/result files
11. induce a Runtime-child failure in a disposable staging copy and verify Host records it instead of crashing with the child
12. verify no unexpected console window

## Preservation gate

No behavior change is expected yet for:
- dependency-repair policy;
- ExecutionPolicy Bypass;
- OperationWorker;
- GameReference worker;
- FixLab;
- Updates;
- localization.

Those belong to later phases.

## Integration gate

Only after the Windows behavior gate passes:
- replace packaged PMM.exe with the accepted unified candidate;
- update routes/doctor/package metadata as required;
- keep PMMRuntime.exe for one integration step if rollback safety requires it;
- then prove no runtime route still consumes it before removal.

FixLab remains separate.


---

## Current evidence status - 2026-09-23

A connector-backed reconstruction of the canonical NF02A source has reached the Windows gate:

- Go 1.23.2 offline compile: PASS;
- dispatcher tests: PASS;
- Runtime/Supervision/UIBridge compile on Linux: PASS;
- Host windows/amd64 test binary compile: PASS;
- Runtime windows/amd64 compile: PASS;
- unified windows/amd64 GUI executable build: PASS;
- PE format/subsystem inspection: PASS.

Evidence:
`NF02A_BUILD_EVIDENCE.json`

This is **not yet the exact-clone static/build gate**, because the execution container could not clone GitHub and therefore did not execute the complete migrated test set from an exact checkout.

The next network-capable environment should run the canonical `build.py` once. If it passes, proceed directly to the Windows behavior gate above.
