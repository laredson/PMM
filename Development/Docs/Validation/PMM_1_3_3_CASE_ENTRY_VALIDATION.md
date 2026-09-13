# PMM 1.3.3 case entry and GPT runtime hotfix

## Reproduced cause

The installed copy at C:/Modding/palworld/1.3.3333/PMM has version 1.3.3. Its hardcoded XAML title still showed 1.3.1. The library DataGrid had no case context menu. The existing AUAT 1.0.4 case contained no mod reference.

Seven paused repair sessions for the same case and evidence recorded the same failure: Codex was unavailable. The client only searched PATH. PMM launched from Explorer does not inherit the task-specific Codex runtime path. Errors appeared only in session JSON; the visible editor still showed old MCP publication guidance.

## Fix

The runtime resolver checks an explicitly configured executable, PATH, then the installed desktop runtime directory. It does not infer authentication from installation. The case editor reads its actual persistent agent session, response and failure, exposes the original conversation, and routes cancellation to that session. A repeated click reuses the session for unchanged evidence and does not extend its budget or authorization. Child launch and startup use a durable lock/handshake; stdout/stderr are retained.

The library context menu selects the clicked DataGrid row, preserves an existing multiselection and opens a localized draft with explicit references. The resulting case has full PAK hashes and uses the GPTD destination. Empty repair cases fail before a request is sent. Referenced PAK bytes are checked before investigation.

## Verification

- v133_case_entry_regression.ps1: 18 actual WPF assertions each in English and Spanish. Includes row selection, context-command event dispatch, exact PAK attachment, navigation, visible failure/response, cancellation, no duplicate session and real dialog binding.
- v133_case_agent_regression.ps1 -ProbeConnection: 10 additional checks including old-session reuse, budget preservation, changed evidence/bytes, real failing child process, persisted error and real authenticated App Server metadata connection with Codex removed from PATH. No inference turn started.
- Existing deep UI: 16 checks.
- Existing jobs/staged updates: 15 checks.
- Model policy: 23 checks; staged protocol: 7 checks.
- Existing cases/migrations: 44 checks; MCP bridge: 36 checks.
- Runtime control ownership and game-isolation limitations from the 1.3.3 preview remain.
- Palworld was not launched and installed game mods were not changed.

The installation is backed up before copying program changes. Existing AUAT case identity and history are preserved; adding the explicitly requested source reference is a normal case operation.

## Installed verification

Applied to C:/Modding/palworld/1.3.3333/PMM. Backup: PMM-backup-case-entry-20260912-191252 alongside PMM. All 589 installed public file hashes match the patched inventory. All 49 local mod PAK hashes remain unchanged.

AUAT case AICASE-20260913-004810-a5411828 keeps its identity and advances from step 3 to step 4 by adding AutoUnlockAllTechnology_V1_P.pak (SHA256 b6af99dfd1d597b9a04458c884aacb5d09f8c3f30ca77f819d67d9a87e183f40). No duplicate case, investigation turn, new mod build or game launch was started by installation. The running old UI was left open to preserve any unsaved edits; restart is required to activate the menu changes.

The clean PMM-1.3.3-case-entry-hotfix.zip passes SmokeTest, PS5.1 parsing of 117 scripts, all 589 file hashes and all 47 catalog entries. ZIP SHA256: 83b79f03d2f9bc638f005b04aa3b6a063e215535b3a8307be5637ca96b1d6148.
