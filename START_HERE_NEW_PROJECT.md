# START HERE - PMM v1.5.0.2

Repository: `laredson/PMM`
Active development branch: `v1.5.0.2`
Current package identity: `PMM-v1.5.0.2-development-baseline`

This repository is designed to be self-handing-off. A new chat, Codex session, developer or AI should not need the previous conversation.

## Read in this order

1. `AGENTS.md`
2. `Development/Handoff/CURRENT_HANDOFF.md`
3. `Development/Handoff/CURRENT_STATE.json`
4. `Development/Reliability/V1502_SINGLE_EXE_AND_NOFLAG_PLAN.md`
5. `Development/Reliability/STATUS.md`
6. `Development/Reliability/NEXT_SESSION.md`

Historical material is classified by:
`Development/Handoff/HISTORY_REGISTRY.json`

## Normal local workflow

Use a local clone.

If the clone already exists: fetch, checkout `v1.5.0.2`, fast-forward only and confirm a clean tree.

Then run:

```
python Development/Tools/build_repo_index.py --check
```

If missing/stale:

```
python Development/Tools/build_repo_index.py
```

The index lives in local `.pmm-index/` and is not committed.

Normal development is one coherent commit per prompt, advancing as far as safely possible within the current acceptance gate. Update the handoff/status/history/next state in the same commit when materially changed.

## Current next step

**NF01 - exact baseline + executable/worker/process contract inventory.**

Do not start by:
- rewriting all PowerShell;
- deleting Runtime/FixLab;
- debugging the unreproduced pre-UI incident without new evidence;
- claiming antivirus causality.

See `Development/Reliability/NEXT_SESSION.md` for exact outputs.

## Current architecture direction

One PMM-owned executable, multiple isolated OS processes:

```text
PMM.exe
PMM.exe --worker <known-operation>
```

Keep the modding knowledge/modules/resources open and editable. External third-party EXEs remain external.

## Current product goal

Finish the capabilities PMM already intends to provide:
- mod updates;
- compatibility patches;
- old-mod restoration/FixLab;
- AI-created mods using PMM capabilities;
- reliable/Nexus-friendly packaging and execution.

Large future expansions are not required to close 1.5.0.2.
