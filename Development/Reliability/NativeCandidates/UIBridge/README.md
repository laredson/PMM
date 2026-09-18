# UIBridge - 02C-2A: isolated protocol, ownership gate and Windows transport

**IMPLEMENTED AS AN ISOLATED LIBRARY; NOT WIRED INTO HOST/RUNTIME.**
No change to PMM/ or existing candidates. Windows adapters compile but have NOT
been executed. This is not original source recovery or a release security claim.

## Contents and boundaries

- protocol.go: flat, closed JSON schema; uint32 big-endian framing; <=4096-byte
  payloads; all IDs are canonical decimal strings. Reject duplicate/unknown/
  missing keys, nulls, numeric JSON values, overflow and trailing data.
- gate.go: session/sequence/generation, HELLO bound to the retained Runtime,
  REGISTER/ACK, at most one pending READY, explicit EXIT/FAILED/CLOSE, and
  immediate revalidation before a short foreground-respecting callback.
- process_windows.go: non-inheritable process handles with creation FILETIME;
  direct-parent Toolhelp check for WPF; native owner must be Runtime itself;
  top-level HWND owner/liveness checked through Win32, never by window title.
- pipe_windows.go: local-only, single-instance named pipe; explicit logon-SID
  DACL, FIRST_PIPE_INSTANCE, REJECT_REMOTE_CLIENTS; peer PIDs obtained from the
  pipe endpoints and compared with retained live process handles. Dial also
  checks that the client is a direct child of the expected live Host.
- NewAuthenticatedGate binds the model to an authenticated server Conn. Channel
  revocation is checked at each gate action, and a watcher releases references.
  NewGate alone is a model constructor, NOT authentication.
- build.py: offline Go1.23.2 model tests, Linux race test where available, and
  cross-compilation of a Windows TEST executable. It never runs that EXE.

There is no TCP/file fallback, shell execution, key simulation, foreground-lock
change, antivirus exception or elevation. No process is killed by this library.
The Windows tests launch only a deliberately selected child test process when
explicitly opted in; they do not launch PMM, PowerShell, .NET or the game.

## Protocol

Each frame has exactly version/session/seq/kind/generation/pid/created/route/hwnd.
All values are strings. Version is "1"; seq starts at 1 and increases by one.
HELLO has the known Runtime identity. REGISTER selects native or wpf and a new
positive generation with an exact process identity. ACK mirrors session/seq/
generation. ValidateAck must be called by the client; successful JSON parsing
alone is insufficient. READY carries a nonzero HWND; EXIT/FAILED retire the
current generation; CLOSE retires the session. PING/ACK maintain a live channel.

An identical REGISTER with a NEW sequence is idempotent. Replaying a sequence is
not. A different active owner is rejected; retire it before creating another
generation. Retired generations are not reused. A READY received after REGISTER
but before ACK completion can retain ONE hint, never give focus. A READY before
REGISTER is rejected. After AckWritten, TryHandoff still rechecks life/ownership.
A consumed READY is not retried even if the foreground callback is declined.

Apply returns an ACK; it does not write it. Call AckWritten ONLY after a
REGISTER ACK was actually written successfully. A malformed frame, pipe loss,
wrong session/sequence/owner or unexpected message retires coordination. CLOSE
and process-exit observations invalidate pending readiness. No data from
state.txt is accepted as proof of identity or actual ContentRendered.

## Windows lifetime and cancellation

CaptureProcess must run immediately after controlled Cmd.Start and BEFORE Wait
can release the child's original process handle. Keep a retained handle for
Runtime and the registered UI, not just numeric PIDs. Access denial is a reason
to refuse focus, not to request admin or broaden trust. Host and Runtime are
trusted code; a same-user attacker able to tamper/inject/duplicate their handles,
an administrator, or a compromised kernel is outside this protection boundary.

Conn has one worker and no buffered request queue. Each public operation has a
5-second requested deadline (or the shorter caller deadline). Close revokes
immediately. Its Done channel means OS cleanup really completed, not merely that
cancellation was requested. An overlapped operation owns pinned buffers until
Windows signals completion. The API caller can return while that worker waits
for cancellation; a pathological kernel/driver can retain that one worker and
its handles/buffers. Do not reopen connections in an unbounded retry loop.
Synchronous OS creation/query calls are not hard-real-time guarantees either.

The 5-second Receive deadline requires the future integration to send PING/ACK
while a UI is active or initialization is slow. Serialize complete send+ACK
transactions; single I/O serialization is NOT transaction serialization. Do not
call network-style waits on the WPF/splash dispatcher thread.

TryHandoff revalidates immediately, but Windows has no atomic transaction joining
process life, HWND ownership and foreground change. Same-process HWND reuse and
exit after the last query remain residual races. The callback must check current
foreground, act once, and not cache the HWND or re-enter the gate. No guarantee
of visible render completion is inferred from a local readiness file.

## Reproduce

From repository root, with Go1.23.2 already installed:

```text
python -B Development/Reliability/NativeCandidates/UIBridge/build.py --out ../PMM-UIBridge-S02C2A
```

Output must be new and outside the checkout. It includes source hashes, test
logs, a build report and UIBridge-S02C2A.test.exe. That EXE is a test harness,
NOT PMM.exe or PMMRuntime.exe; never copy it into the application package.

The repository keeps compact reports and real text test output. Full JSONL and
the test EXE are in the downloadable evidence archive. Repeated builds were
identical in the recorded environment, not certified across machines.

Next: 02C-2B, integrate this module into the CURRENT remote C1 candidates. See
INTEGRATION.md. H02B-04 remains open until integration and Windows acceptance.
