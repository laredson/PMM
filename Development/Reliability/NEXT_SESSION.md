# NEXT SESSION - PMM v1.5.0.2

## Required environment

Use a network-capable **Windows** local clone or another environment that can:
- access GitHub;
- run Go 1.23.2;
- execute the built Windows PMM candidate;
- observe the WPF/splash behavior.

Do not repeat NF02 architecture research or the distributed PowerShell
PMMRuntime pre-inventory.

## 1. Exact NF01-L

1. fetch + checkout `v1.5.0.2`;
2. fast-forward only;
3. require clean tree;
4. generate `.pmm-index`;
5. recompute SHA-256 of current PMM.exe / PMMRuntime.exe / PMMFixLab.exe;
6. compare exhaustive local process/Bypass search with NF01 findings.

Close NF01-L if no critical contradiction appears.

## 2. Exact NF02A V2 build

Run:

```text
python Development/Source/PMM/build.py --out <new-dir-outside-repo>
```

Require `PMM_NF02A_UNIFIED_BUILD_V2` and all tests/cross-compiles/PE checks PASS.

## 3. Disposable Windows acceptance stage

Run:

```text
python Development/Tools/nf02a_windows_stage.py \
  --candidate <build>/PMMUnified-candidate.exe \
  --build-report <build>/build-report.json \
  --out <new-dir-outside-repo> \
  --run-diagnostics
```

Require:
- candidate hash matches build report;
- five Runtime routes rewritten;
- all five automated diagnostics exit 0.

Then complete manual gate:
- normal start;
- splash -> WPF foreground;
- clean close;
- Host-session evidence;
- forced Runtime-child failure -> Host survives and records it;
- no unexpected console.

## 4. If NF02A passes: first package integration

In the same prompt if possible:
- replace repository PMM.exe with the exact accepted candidate;
- rewrite distributed native routes to `PMM.exe runtime ...`;
- update VERSION/BUILD_ID/RELEASE_MANIFEST/SHA256SUMS atomically;
- retain PMMRuntime.exe;
- rerun diagnostics/regression on integrated package.

## 5. Begin NF02B immediately after accepted integration

Use `NF02B_PREINVENTORY.md` as the starting map and the guarded migration tool:

```text
python Development/Tools/nf02b_migrate.py --root . --report <preview-report>
```

The dry-run must report exactly 18 command migrations across the 14 known edited
files. After the accepted NF02A candidate is integrated and all five native
routes are already `PMM.exe runtime ...`, apply with the accepted candidate
hash:

```text
python Development/Tools/nf02b_migrate.py \
  --root . \
  --apply \
  --accepted-candidate-sha256 <accepted-hash> \
  --report <applied-report>
```

The tool refuses apply on candidate-hash mismatch, route drift, callsite-count
drift or missing retained PMMRuntime.exe. It preserves Library's cancelable
external-process argument contract and UTF-8 BOM choice.

Then run the exact local repository grep and classify any missed
non-PowerShell/config callers.

Do not delete PMMRuntime.exe until the post-migration zero-active-caller proof passes.

One coherent commit for the prompt; `[skip ci]`; no Actions unless explicitly requested.
