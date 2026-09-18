# 02C-2B integration contract - NOT implemented in 02C-2A

Start from the current remote commit, not old chat ZIPs. At the start of 2A it
was 054e16404e1e45fcc614e24645c7fb651db80afb; C1 candidate hashes there are Host
96e6e6b024207257e7777d7ad72711bf8f8c0966c86929d6f5528ec177ddb059 and Runtime
db39fb942ebf9ba2c8d78c71abf4df43ec918a4040fe09dfaad65cba9a97ac77.
The earlier downloadable C1 archive contains DIFFERENT candidate sources and
hashes. It is not the integration baseline. All old reports remain historical.

## Required wiring, not merely importing the module

1. Add a local pmm/uibridge replace to Host/Runtime recipes and include its complete
   sources/hashes in offline staging. Keep the existing Supervision module and
   all output_complete/error behavior. Never substitute packaged EXEs here.
2. Host creates Server before Runtime Start; supplies Descriptor through a
   controlled, case-insensitive de-duplicated environment (not a shared file).
   CaptureProcess(RuntimePID) before Wait can release the original handle. Check
   the CURRENT Supervision OnStart/Wait ordering and introduce a bounded capture
   hook if necessary. Do not invent identities from a later PID lookup.
3. Runtime connects early, before long dependency work, not after it: otherwise
   the Host's 5-second accept deadline expires. It validates the live launching
   Host, keeps the authenticated channel and serializes complete transactions.
   No transport descriptors should be passed on to tools or WPF. PING/ACK must
   keep the session responsive during UI waits and long initialization.
4. Host Accept returns an OS-peer-checked Conn. NewAuthenticatedGate(Conn) obtains
   a duplicate of that verified Runtime handle. Never call NewGate with a process
   identity taken from state.txt. Any channel/parse/ACK error retires focus; the
   visible application may continue with a diagnostic, NOT a legacy unsafe
   fallback that activates an unverified window.
5. Runtime allocates a fresh generation and EMPTY per-UI state directory. Preserve
   its own Host-session diagnostics. Start WPF directly, capture its OS identity
   before Wait, REGISTER, then wait for ValidateAck. Readiness arriving early may
   be held as at most one hint, then revalidated after ACK. Never reuse a previous
   UI's state directory or ready file for a new generation.
6. For Win32 native UI register the Runtime process itself. Publish that HWND
   when the actual window is ready; do not let the splash wait forever for a WPF
   message that native UI never emits. If no usable HWND is available, retire
   the splash WITHOUT a focus action; do not synthesize a handle.
7. Enforce one focus-owner UI per generation. Repeated native-shell WPF buttons
   must not create competing registrations. Native -> WPF needs explicit EXIT
   of native registration, new generation and new per-UI state. The native window
   can remain visible but no longer owns the focus token.
8. Send EXIT/FAILED on observed UI completion; connection loss/current Runtime
   exit closes Gate immediately. Host state-file monitor becomes PROGRESS ONLY.
   Remove every direct HandoffTo(raw HWND from state.txt) route from the candidate.
   Post a bounded notification to the splash's own thread, then TryHandoff on
   that thread with a short callback respecting current foreground. Close/failure
   must win if already observed; do not cache handles for later use.
9. Review error paths: capture denied, server collision, peer mismatch, registration
   failure, EOF, slow startup, missing UI script, old Runtime without protocol,
   stale frames, inherited descriptors, native/WPF transitions and process exit.
   Missing coordination never permits broadening ACLs, disabling protection,
   forcing focus or silently trusting a file again.
10. Test models/adapters with controlled stubs; compile both candidates twice,
    persist evidence and exact hashes. No PMM/ changes, no WPF translation edits,
    no repair/download redesign. Windows visual/IPC tests remain a separate gate.

## What remains deliberately outside

The source only package does not implement Host/Runtime message loops, per-UI
state directory routing, heartbeat scheduling, single-WPF ownership or splash
callbacks. Those are actual integration tasks, not tests already completed.
Do not count the 25 library model tests as real named-pipe/GUI acceptance.
Process-family cancellation/Job Objects, manifest/pin validation, old paths and
transactional dependency repair remain separate unresolved work.

## Primary references consulted for the adapter

- https://learn.microsoft.com/en-us/windows/win32/ipc/named-pipe-security-and-access-rights
- https://learn.microsoft.com/en-us/windows/win32/api/winbase/nf-winbase-getnamedpipeclientprocessid
- https://learn.microsoft.com/en-us/windows/win32/api/winbase/nf-winbase-getnamedpipeserverprocessid
- https://learn.microsoft.com/en-us/windows/win32/api/ioapiset/nf-ioapiset-cancelioex

The cancellation documentation requires retaining OVERLAPPED data until actual
completion. A requested cancellation is not proof that cleanup finished. These
references do not replace running the opt-in Windows adapter fixtures.
