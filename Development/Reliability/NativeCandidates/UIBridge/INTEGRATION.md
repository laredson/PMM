# UIBridge integration - S02C-2B

Implemented in the isolated Host/Runtime candidates, NOT in packaged PMM/.
Input remote commit: 318666ca8beb828529b49d7ce245c0652b616d28.
Windows transport/GUI acceptance is NOT_RUN. See SESSION02C2B_FINDINGS.md.

## Source map

| Caller | Integration |
| --- | --- |
| Host main.go / bridge_windows.go | Server before controlled Runtime Start; capture hook before Wait; Accept / NewAuthenticatedGate; server loop; revocation on exit |
| Host splash_windows.go | One Gate/generation notification slot; TryHandoff on splash thread; no stored raw HWND; foreground-respecting callback |
| Host splash_state.go | progressOnlyView strips readiness/window authorization from all file hints |
| Runtime main.go / bridge_windows.go | withRuntimeUIBridge before long UI/start work; OS launching parent, Dial, HELLO; locator scrub before descendants |
| Runtime bridge.go | Single WPF reservation; fresh UI state directory; capture before Wait; REGISTER/ACK then readiness; bounded cleanup; native ownership |
| Runtime native_shell_windows.go | Actual native HWND ready notification; copied button arguments; immediate close revocation |
| Supervision process.go | Capture hook before starting Cmd.Wait, without changing output_complete / limits |
| UIBridge client.go | Serialized exchanges, heartbeat, generation retirement and ServeGate ACK commit |
| UIBridge environment.go / hint.go | Controlled locator environment, strict single-record hints, fresh per-UI directory |

## Invariants

Production authentication always goes through Accept/Dial and NewAuthenticatedGate.
NewGate is used only by synthetic tests. Declared PIDs, titles, AppUserModelID or
files do not authenticate an endpoint. OS process references retain creation
identity; HWND ownership and life are checked immediately before Host action.

A locator is NOT a secret. Host issues it only to the exact native Runtime start
route, via deduplicated environment. Runtime strips it before probes/dependencies;
WPF environment is scrubbed again. Runtime retains its own Host-session directory;
WPF receives a new UIInstances/ui-* directory. If creation fails, empty SESSION_DIR
suppresses hints rather than falling back to a previous instance's state file.

Only one WPF child can start/run per coordinator. REGISTER waits for an exact ACK;
READY is never replayed. Transition to WPF retires native ownership first. The
native window may stay visible, but startup focus is not repeatedly transferred.
Host destroys its splash after the first attempted verified handoff or retirement.

Native close immediately cancels/revokes; it never waits for pipe I/O inside its
Win32 callback. WPF Wait triggers cancellation and EXIT, with Host independently
checking the retained owner's life. Any malformed message, stale generation,
wrong HWND, ACK failure or disconnected channel disables coordination. There is
no insecure file/TCP fallback. The application may continue without Host focus.

Client exchanges including lock acquisition are bounded to 3 seconds. Heartbeat
runs every second. Pipe operations retain their 5-second adapter cap. UI hint
readiness expires after 30 seconds, retiring coordination, NOT killing application
work. Kernel/driver cleanup is not promised to finish in a strict wall-clock bound.

## Remaining limits and gates

The real adapters were cross-compiled, not run. OS permissions, actual process and
HWND reuse, close races and foreground behavior need the Windows integration gate.
Same-process HWND reuse and validation/action races are not made atomic by Go.
WPF's own activation logic is unchanged. Job Objects/process-family shutdown,
manifest/pin validation, historical paths and transactional dependency repair
remain separate requirements. No test/compile result authorizes installation.

Read ../../WINDOWS_UIBRIDGE_ACCEPTANCE.md and ../../NEXT_SESSION.md before continuing.
