# NF02 package integration sequence

NF02 package integration is intentionally split so a Windows acceptance failure
cannot strand the distributed package.

## NF02A-1 - candidate acceptance

Build exact source with `Development/Source/PMM/build.py`.

Create a disposable package with:

```text
python Development/Tools/nf02a_windows_stage.py \
  --candidate <build>/PMMUnified-candidate.exe \
  --build-report <build>/build-report.json \
  --out <new-dir-outside-repo> \
  --run-diagnostics
```

The staging tool:
- copies PMM/ outside the repository;
- replaces only staged PMM.exe;
- rewrites staged Runtime routes to `PMM.exe runtime ...`;
- retains PMMRuntime.exe and PMMFixLab.exe;
- records hashes and diagnostic results.

Then complete the manual UI/crash-isolation checks in `NF02A_ACCEPTANCE.md`.

## NF02A-2 - first package integration

Only after NF02A Windows acceptance passes:

- replace repository `PMM/PMM.exe` with the exact accepted candidate;
- rewrite distributed native routes to `PMM.exe runtime ...`;
- update VERSION/BUILD_ID/RELEASE_MANIFEST/SHA256SUMS atomically;
- retain PMMRuntime.exe for rollback/direct-call compatibility;
- run the same diagnostics and primary application regression.

## NF02B - direct-call migration

Follow `NF02B_RUNTIME_CALLSITE_MIGRATION.md`.

Migrate all active direct PMMRuntime callers.

## NF02C - remove legacy Runtime executable

Only after NF02B proves zero active distributed direct callers:

- remove PMMRuntime.exe;
- remove its package checksum/inventory record;
- run clean-install/update regression;
- verify Host/Runtime crash isolation still uses two PMM.exe OS processes.

FixLab remains a separate later migration.
