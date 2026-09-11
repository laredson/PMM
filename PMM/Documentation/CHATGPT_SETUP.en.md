# Connect ChatGPT Desktop to PMM

ChatGPT Desktop is optional. Each case can target **ChatGPT Desktop**, **Other MCP client**, or **Codex console**. Desktop and other clients retain `Transport=MCP`; only the console destination requires Codex CLI. Unreal and Wwise remain optional tools for particular authoring and cooking tasks.

## Initial connection

1. Detect or install ChatGPT in **Settings > Installations**. **Send to ChatGPT** also offers installation when the app is missing, using the existing installation service. PMM requests silent WinGet installation; OS prompts, sign-in and official installer steps remain yours to accept. ChatGPT is not bundled in the PMM ZIP.
2. Open **Settings > AI / MCP > Connect ChatGPT** and sign in to the client. The dialog identifies the detected app and version. An older app without the `codex://` protocol needs an update to open local chats.
3. Select or create a local project in the client using the installation folder containing `PMM.exe`. PMM uses its `Workspace` subfolder for cases and temporary work, without creating another fixed location on C:. An optional additional folder can be selected; grant its access separately in the client.
4. Click **MCP configuration**. Generated examples are `Workspace/MCP/codex-mcp.toml` and `mcp-config.json`. Import or add the PMM entry in your client's MCP settings, preserve other servers, then restart the server. PMM generates examples without overwriting client configuration. Adding the project folder alone does not configure MCP.
5. Click **Open synchronization chat** and send the prepared text. It asks the AI to call `pmm_desktop_pair` with the displayed code. Codes are single-use and expire after 30 minutes; use **Reconnect** to generate another.
6. Click **Check connection**. Only a successful MCP call verifies pairing. Opening the app does not prove sign-in or connectivity. Pairing does not certify the client brand, account plan, or filesystem permissions.

The binding is stored per installation in `Workspace/MCP/Desktop/binding.json`, without credentials. New UI cases default to ChatGPT after verification; existing cases keep their destination. Moving PMM requires regenerating the configuration and pairing again; a binding for the previous folder is not accepted.

## Send and continue

- Select a case, choose **ChatGPT Desktop** under **Client**, then **Send to ChatGPT**. PMM saves and publishes the request before opening the client. AUTO for that case uses the same destination and does not start Codex CLI.
- PMM uses the official `codex://threads/new` link with `path` and a message identifying the case/request. The link fills the composer; **it does not submit**. If no matching project is available, select or create the local project in the client. PMM does not inspect private client databases or claim to have created a project.
- A Windows accessibility adapter attempts submission only after verifying the app, foreground window, selected folder, exact composer text and a unique Send button. It uses no fixed coordinates and accepts no permission dialogs. **Automatic submission in the real app is not yet validated.** If verification fails, submit the prepared message yourself; PMM displays that state. Pressing the PMM button again also provides the text to copy.
- The initial request requires research, a proposed plan and your approval before editing, building, installing or deploying. This is a workflow instruction, not confirmed activation of the client's native Plan mode.
- The AI claims the request with `pmm_request_claim` and reports phases through `pmm_desktop_case_link`. It can associate its actual thread ID when available. PMM reopens known threads; otherwise it provides assisted opening and prepared text. PMM cannot discover arbitrary existing chats.
- Double clicking does not automatically open another chat. A processing request blocks another runner. After a result, edit the case to prepare a follow-up. If a thread is known, it reopens and the follow-up text is copied/submitted with assistance.
- **Cancel** cancels the pending PMM request. A previously submitted message remains in ChatGPT; stop the chat there too if it is working. PMM does not forcibly terminate the client or official installers.

Prepared text, sent message awaiting receipt, MCP receipt, research, awaiting approval and completed results have separate status indications. Opening a window does not prove AI activity; building a package does not prove a working mod.

## Access and validation

Giving the client access to the entire PMM folder can also expose PMM source files. The prompt asks it to work in `Workspace` and use MCP. PMM validates operations and paths inside its server; it cannot restrict shell, filesystem or Windows control granted to other client tools. Sign-in, trust and permissions remain user decisions.

Test candidates with isolated saves and retain the previous deployment. Keep “built” distinct from “tested in Palworld.” Visual automation is optional and depends on an available desktop and accessible client controls. Manual feedback such as “works” or “crashes,” with evidence, remains supported.

Local tests cover MCP contracts, pairing codes, destinations, cancellation, reopening with a known thread ID, double clicks, persistence and English/Spanish controls. Fresh real installation, accessibility submission and the full Free-account workflow remain **unverified**. Free does not guarantee unlimited autonomous use. The inventory mod is not declared game-tested.

## Official references

- [Chat links and commands](https://learn.chatgpt.com/docs/reference/commands#chats)
- [MCP](https://learn.chatgpt.com/docs/extend/mcp)
- [Local projects](https://learn.chatgpt.com/docs/projects)
- [Windows installation](https://learn.chatgpt.com/docs/enterprise/windows-deployment)
- [Plans](https://learn.chatgpt.com/docs/pricing)
- [Computer use](https://learn.chatgpt.com/use-cases/use-your-computer-with-codex)
