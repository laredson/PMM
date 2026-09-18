# UIBridge - candidate UI ownership coordination

S02C-2A introduced the isolated protocol/Windows adapters. **S02C-2B integrates
this module into the Host and Runtime candidates.** Nothing is installed in PMM/.
The original 2A reports remain historical under evidence/.

Read [INTEGRATION.md](INTEGRATION.md), ../../SESSION02C2B_FINDINGS.md and
../../WINDOWS_UIBRIDGE_ACCEPTANCE.md for current wiring, tests and remaining gates.

The transport is a local single-instance Windows named pipe. Logon-SID ACL,
remote-client rejection, OS peer PID checks and retained process handles bind
endpoints to the supervised Host/Runtime instances. Descriptor strings are only
locators; they are removed before launching WPF or helpers. No file/TCP fallback.

Frames are bounded to 4096 bytes with closed schema/canonical integers. HELLO,
REGISTER/ACK, generation, READY and retirement are serialized. The Host's Gate
revalidates process life and HWND ownership before a one-shot action on its splash
thread. State-file hints cannot independently grant a focus capability.

Client exchanges are bounded to 3 seconds including transaction-lock acquisition;
heartbeat runs every second. Windows overlapped I/O keeps its 5-second requested
cap, revokes immediately and retains buffers until OS cleanup really completes.
A stuck driver may delay cleanup; cancellation is not proof of kernel completion.

Pure tests use framed in-memory transports and fake OS process references. They
do NOT establish Windows ACL/pipe/HWND correctness. Windows adapters and opt-in
harnesses cross-compile; real execution remains NOT_RUN. Same-process HWND reuse,
validation/action races, WPF's own activation and process-family cancellation
remain explicit limitations. No GUI focus is forced or security policy changed.

From this directory, with Go1.23.2 already installed and network disabled:

```text
go test -count=1 ./...
go test -race -count=1 ./...
```

The library build.py builds only its Windows test harness outside the repository.
Host/Runtime build.py recipes stage this local module and record its file hashes.
Neither recipe executes or installs the resulting Windows candidate.
