# PMM 1.3.3 — Deep analysis preview

Based on 1.3.2 commit 3e57247. Keeps the six-tab interface, case repairs, mappings handling and current-game table recovery.

- Adds background deep analysis, explicit coverage, evidence filtering, JSON/HTML reports and selected-finding case creation/linking.
- Adds Nexus/GitHub origin and variant checks, authorized staged downloads, preserved originals and proposed-set reanalysis.
- Replaces ephemeral agent execution with persistent App Server case bindings, session permissions, retained attempts and cancellable merge/update jobs.
- Selectively integrates the 1.4.0-ReUI service/presentation separation, module catalog, idle-compatible reload and durable deployment recovery. No 1.4.0 UI redesign is imported.
- Keeps existing native binaries.
- Adds account-aware AI routing: Luna/low/standard for routine work, explicit ceilings for Terra/Sol escalation, live model/effort acknowledgement, reported quota checks and a manual-chat path. API billing is a separate opt-in.

The complete automatic game repair/test/isolation loop is **not accepted**. Shared desktop control is unavailable in the tested Windows runtime; game isolation and supervised world validation still require a validated adapter. These capabilities are explicitly gated.

FasterMounts/RushRoar retains the 1.3.2 current-layout repair. EasyBreeding/NoCollision remains unsupported where current Blueprint schema coverage is insufficient. No Palworld launch or deployment was performed during development.

Usage: [English](DEEP_ANALYSIS.en.md) · [Español](DEEP_ANALYSIS.es.md).

## Case entry hotfix

- Right-click a library mod and choose **Create new case**. The dialog starts as a mod repair and attaches the selected PAKs with their full hashes. Multiple selections start a compatibility case.
- GPTD is the default case destination. Creating a case does not start an AI request.
- Explorer-launched PMM can discover the installed Codex desktop runtime without a task-specific PATH.
- The case editor shows connection failures, current progress, the persisted AI response and a link to the same conversation. Cancel revokes the case repair session.
- Retrying unchanged evidence reuses the existing session and preserves its limits. Empty repair cases explain that a PAK must first be attached.
- The window title now reads the packaged version. Restart PMM after installing this hotfix.
- No game runtime acceptance or shared Windows desktop control is claimed by these fixes.

### Case entry hotfix 2

The library's displayed rows now retain the actual source path and full SHA256. This fixes the missing Path exception when creating a case from an imported mod, including disabled and multiple selections, and restores references in manually created cases. The regression now invokes the production library scan and Refresh-UI instead of injecting synthetic display rows.

## Detected model picker hotfix

- AI level / connection now lists detected account models and each model's supported reasoning levels. The open dialog refreshes without reopening; connection errors appear there.
- Model IDs resolve case-only spelling differences against the live catalog. Missing models and duplicate catalog entries have distinct explanations; there is no fallback to a different model.
- Existing model choices and reasoning ceilings are preserved. An unsupported effort requires selection; it is never silently increased.
- The normal background account check now loads its runtime discovery and MCP service dependencies.
- Validated on PowerShell 5.1 with English/Spanish WPF fixtures and a real metadata-only account/model check. No repair inference or Palworld launch was started.
