# Host S02A - source candidate, not installed

**Classification: RECONSTRUCTION_NOT_ORIGINAL_RECOVERED.**
This candidate is not the source recovered from the historical splash hash.
It is an auditable reconstruction based on the available Host snapshot, the
shipped WPF startup-state contract and names embedded in the original binary.
It is not approved to replace `PMM/PMM.exe`.

## What is preserved and what is new

`main.go` retains the snapshot's routes, native version 1.2.1, diagnostics,
child supervision, environment variables, exit codes and handoff packaging.
The changes to that file are recorded in `evidence/main-vs-snapshot.patch`.
The original `Development/Source/Host/` directory is not changed.

New files implement a six-step startup presentation, bounded session-state
reads, strict decimal HWND parsing, an isolated Win32 message loop and a
best-effort foreground handoff BEFORE destroying the splash. Only `start`
creates the auxiliary window. `doctor`, `security` and script routes do not.
The visible product version is read from VERSION.txt, not the native protocol
version. Existing catalogs/UI are not modified; the candidate's new English
status labels require a later localization decision before public release.

The Win32 thread owns and destroys its controls. Cross-goroutine state is
mutex-protected. Splash failure must not stop supervision. Unknown/partial
state writes never assert readiness; the initial WPF frame is not readiness.
Closing the splash is not a cancellation command for the child.

## Build, strictly outside the package

From the repository root, with Python 3.9+ and Go 1.23.2 already installed:

```text
python -B Development/Reliability/NativeCandidates/Host/build.py --out ../PMM-Host-S02A
```

The output directory must be NEW and outside the checkout. No fetch, installer,
toolchain download or PMM execution occurs. The build pins the original Host,
icon and existing PEIcon build helper. It copies the candidate sources into the
output directory, cross-compiles windows/amd64, applies the existing icon build
helper ONLY to the newly generated candidate and records hashes/commands.
The legacy icon helper is retained for comparison, not presented as the future
resource/signing solution. No newly generated binary is installed or committed.
`COMPLETE.txt` marks a successful build; incomplete output is not usable.

Go 1.23.2 is pinned here to compare with the existing binary, not as a claim
that it is the best toolchain for a future public release.

Expected S02A candidate SHA-256:
`62fc4b234ea145c6e3dadcc51366c0ebbca109f7b5a11dcb17deda32e927257f`.
Two builds in separate output directories on the recorded Linux/amd64 Go
1.23.2 environment produced exactly these same bytes. Cross-host reproducibility
has NOT been verified. Build-report.json contains all compiler-input hashes.

## Checks and limitations

`evidence/build-report.json`: actual static PE data, source hashes and commands.
`evidence/go-model-tests.txt`: five pure-state tests, including 16 HWND subcases.
`evidence/python-tool-tests.txt`: nine synthetic inspector/output-guard tests.
`evidence/repeat-build.json`: second build and byte-equality result.

The Go tests ran on Linux and excluded Win32 files; they do not test the message
loop, focus, taskbar behavior, graphics, process supervision or PowerShell.
The original and candidate `.text` hashes DIFFER. No functional equivalence,
malware verdict, Authenticode validation or Windows execution is claimed.

Intentionally unresolved for 02B/05 and subsequent hardening:

- Original splash source, exact geometry/fonts/timing and pixel parity are not recovered.
- Original behavior on errors, fast UI close and shutdown still needs comparison.
- HWND is read from a local session file; it is not authenticated IPC. IsWindow
  does not prove process ancestry. Review origin validation before promotion.
- Foreground activation is best effort. If the user changes focus away from the
  splash, the candidate does not take it back. No input simulation, queue
  attachment, TOPMOST or foreground-lock changes are used.
- The snapshot's PowerShell selection, ExecutionPolicy Bypass fallback, hidden
  CLI startup, missing security-probe timeout and stream-drain behavior remain.
  Keeping them for the baseline comparison is NOT antivirus hardening approval.
- No changes to Runtime, FixLab, dependency repair, WPF, translations or `PMM/`.

Do not copy the candidate over the shipped executable. Next: 02B, a reproducible
contract/implementation comparison and an explicit Windows acceptance checklist.

## Primary platform references used

- https://go.dev/wiki/LockOSThread
- https://pkg.go.dev/runtime#LockOSThread
- https://learn.microsoft.com/en-us/windows/win32/winmsg/wm-close
- https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-setforegroundwindow

Windows may decline a foreground request; a successful compilation cannot prove
that a splash or handoff will work on the user's desktop.
