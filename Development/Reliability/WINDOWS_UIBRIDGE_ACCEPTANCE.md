# UIBridge Windows acceptance - all NOT_RUN

Library 02C-2A only; Host/Runtime wiring still belongs to 02C-2B. No Windows
results are inferred from compilation, Linux race tests or the user's successful
launch of the unchanged application. Do not install a candidate for these tests.

The opt-in tests in pipe_windows_test.go are scaffolding, not evidence of passing.
They exercise a deliberately spawned child TEST executable, not PowerShell/PMM.
Run only in an explicitly authorized Windows test session. No CI workflow added.

| ID | Case / required evidence | Status |
| --- | --- | --- |
| IPC-01 | Live controlled direct child connects; both peer IDs match retained process identities | NOT_RUN |
| IPC-02 | Another process or wrong creation time cannot authenticate; no window action | NOT_RUN |
| IPC-03 | Another logon/remote client denied; inspect DACL, no inherited server handle | NOT_RUN |
| IPC-04 | Name collision/second server instance fails; never attach to an existing foreign endpoint | NOT_RUN |
| IPC-05 | Header/body stalls, abrupt disconnect and short reads revoke coordination within requested bounds | NOT_RUN |
| IPC-06 | Cancel overlapped connect/read/write; caller returns, Done eventually closes, no freed pending buffers | NOT_RUN |
| IPC-07 | Controlled WPF-like child and native Runtime owner verified by handle/time/parent, not names | NOT_RUN |
| IPC-08 | Foreign HWND, destroyed HWND and recycled PID rejected; access denied stays fail-closed | NOT_RUN |
| IPC-09 | Gate cannot focus before ACK, after EXIT/FAILED/CLOSE or after pipe revocation | NOT_RUN |
| IPC-10 | Same-process HWND reuse and exit between last validation and foreground action characterized honestly | NOT_RUN |
| IPC-11 | Real integration: early ready, fresh per-generation state, repeated WPF button and native -> WPF | NOT_RUN / NOT_INTEGRATED |
| IPC-12 | Real integration: idle/slow startup heartbeat, user changes foreground, optional coordination failure | NOT_RUN / NOT_INTEGRATED |

Three top-level Windows adapter tests plus one child dispatcher are supplied.
They cover parts of IPC-01/02/05/06; this table is NOT fully automated. In the
Windows session use Go1.23.2 and explicit PMM_UIBRIDGE_WINDOWS_TESTS=1, then
`go test -count=1 -timeout=30s -run '^TestWindows' .` within the UIBridge folder.
Unset the variable afterwards. Collect exit status, exact source/executable
hashes and actual results; a skipped test is not PASS. The child-dispatcher env
must not be set manually. Do not run test executables received from unverified
sources, and do not remove OS security protections to obtain a passing result.

Host and Runtime acceptance tables remain applicable after wiring. A failure or
inability to run a Windows case does not become success because the library
model accepted an analogous fake-process fixture.
