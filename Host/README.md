# PMM Host (PMMH) — v1.2 RC1

`PMM.exe` is the deliberately small, open-source supervisor for Palworld Manager Merger. It is not the merge engine and it does not contain compatibility Knowledge.

RC1 introduces external routing through `Runner/routes.json`.

Normal startup is now:

```text
PMM.exe start
  -> Runner/routes.json
  -> PMMRuntime.exe start
```

That route does not start PowerShell. PMMH supervises the child process, captures stdout/stderr and state, records the session, classifies failures, and can create an emergency `AI_HANDOFF_*.zip` even when the child runtime fails.

Operations not present as native routes can still fall back to the editable `Runner/PMM-Runner.ps1` dispatcher. This keeps PMMH generic: future operations such as Fix Lab can be added by changing external routing/modules rather than teaching the Host merge semantics.

PMMH exposes `doctor --json`, `security status --json` and `handoff create` directly.

It never disables or bypasses Windows application-control policy.

Build from source on Windows with Go 1.23+:

```bat
Host\BUILD_HOST.cmd
```
