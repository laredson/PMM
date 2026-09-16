# Desktop-owned case conversations — PMM 1.3.3

The main Desktop action no longer runs the internal App Server agent. ChatGPT Desktop and Codex Desktop are separate destinations. Preparing a link is not delivery: the client must send the prepared request and report receipt over PMM MCP. Project-local MCP configuration targets the selected installation and preserves conflicting user entries.

Internal requests require a separate explicit opt-in. Transport, account/model policy and prompt entry live in the advanced chat panel. Every explicit prompt has a durable idempotency identifier; subsequent turns reuse the case thread. A suggested harder stage now pauses for user input rather than automatically spending on another model.

The case chat stores public prompts, replies, tool lifecycle events, requested and acknowledged models/efforts, and provider usage snapshots. It excludes hidden reasoning. Public history can be recovered with thread/read without starting inference. The view shows the latest 300 entries; the full saved journal stays in the case Chat folder.

## AUAT audit

Case: AICASE-20260913-015230-1532ec3e
Conversation: 01a09877-71f4-77e2-8261-930f91a85d6b

The installed records and the actual thread/read response establish **one conversation, three turns**, not three chats. The read recovered **61 public conversation items** into the installed case.

| Stage | Model | Effort | Reported total snapshot | Cached input | Output |
|---|---|---|---:|---:|---:|
| Routine | gpt-5.6-luna | low | 139,301 | 120,320 | 1,206 |
| Repair | gpt-5.6-sol | high | 801,671 | 750,592 | 4,240 |
| Complex | gpt-6-astra | high | 505,445 | 436,352 | 2,320 |

These are the saved provider tokenUsage.total snapshots for each stage. They can overlap or reset across resumed runtime/model contexts; this table does not sum them into a total or convert them to money or weekly allowance. No new inference was used to inspect or recover this history.

No candidate was built. The last public response identifies unavailable PMM inspection/adaptation capabilities. The earlier whole-library merge implicated unrelated providers and did not establish this single PAK's defect. The merge worker now rejects standalone repair contexts without an applicable deep-analysis library report before scanning the library.

## Validation

- Desktop binding: 27 checks; real local MCP pairing/lease protocol, mocked app opening, no message submission.
- Case entry and WPF chat: 28 checks in English and Spanish; Desktop sends no internal request, repeated send does not duplicate a prepared chat, advanced internal controls initially disabled.
- AI policy: 26 checks; persistent protocol: 10 checks; history: 5 checks covering read-only recovery, deduplication, explicit model changes, user prompts and cancellation.
- Case worker failure persistence: 9 checks; worker/job/update regression: 15 checks.
- Clean package SmokeTest passed under Windows PowerShell 5.1; 117 parsed PowerShell modules, 589 verified public files, 48 catalog modules.
- Installed in C:\Modding\palworld\1.3.3333\PMM with backup PMM-backup-desktop-chat-20260912-215631. Existing 198 case/mod/state files were preserved during patching; the subsequent requested history recovery only added chat records and normal metadata-operation logs.
- Package PMM-1.3.3-desktop-chat-hotfix4.zip, SHA-256 1c36c70e3169763baafd58a1fc46ef8d75defe66637f9230288d2227d4072203.

Installed app metadata: OpenAI.ChatGPT-Desktop 1.2025.139.0 does not expose the local-chat protocol used by this integration; OpenAI.Codex 26.903.8094.0 does. PMM no longer silently substitutes them. Updating ChatGPT or selecting Codex Desktop is the explicit path.

Full automatic Desktop submission, a free/unmetered background GPT endpoint, and AUAT repair are **not claimed**. Palworld was not launched, and installed game mods were not changed.

Official protocol references: https://learn.chatgpt.com/docs/extend/mcp and https://learn.chatgpt.com/docs/app-server .
