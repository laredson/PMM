# PMM 1.3.3 — Deep analysis

Open **Deep analysis**, above **Analysis plan**. The library stays visible and the existing merge workflow keeps its role.

Run the background analysis, filter findings by mod/resource/severity/confidence, and double-click a finding or press Enter to inspect evidence. Reports are retained as JSON and HTML. **Create case** uses selected findings or all findings and can link an existing case. **Investigate with GPTD** starts persistent research; **Candidates and attempts** opens its retained history and files.

## Evidence and updates

Snapshots retain complete SHA-256 values for source mods, the selected patch, mappings and analyzed tools, plus priorities, the configured deployment inventory, Steam build identity and executable version when available. The large game archive uses metadata identity; extracted resource families are hashed individually. PMM does not compute a whole-game archive hash.

Cooked PAK resources, object maps, imported references and optional references are inspected. Prepared Vanilla resources provide reverse-reference evidence. Coverage explicitly records opaque data, the semantic budget, unprepared resources and ambiguous mount priority. UE4SS, external loaders and files outside Paks/~mods need additional adapters. Differences, overwrites and unsupported readers are not proof of a crash.

**Check mod updates** is initially enabled. Link exact installed Nexus mod/file IDs or GitHub repository/installed tag/exact variant asset name in **Update sources**. A Nexus API key is optional and protected for the Windows user. New imports retain archive/content identity; legacy ZIP origin recovery verifies the actual PAK bytes. Names alone remain unconfirmed.

Nexus follows author file-update chains and rejects ambiguous branches. GitHub compares stable versions containing the same asset name. Unknown identity, authentication, rate limits and unavailable providers remain explicit. Release changes and requirements need review; recency does not prove compatibility.

Authorized downloads remain in the repair session. PMM preserves originals and hashes, reads staged PAKs and analyzes the proposed active set before application. Multiple PAK variants and unsupported extraction formats require intervention. Staging does not automatically replace the library or deployment.

## Preview boundaries

One persistent App Server conversation is bound to each case. Authentication, creation, reconnect/resume, progress, interruption, retained history and a real case-scoped MCP call have been verified.

**Automatic solution is a preview.** The tested Windows runtime cannot share the desktop daemon control channel. Opening a conversation in GPTD may give the desktop exclusive writer ownership. PMM then pauses and preserves the same conversation instead of creating another one. Opening a link alone is not delivery acknowledgement.

Research uses PMM services for update staging, local knowledge and candidate/merge builds. Mutations require current case evidence and session authorization. Initial configurable limits are 40 active minutes, 6 distinct candidates and 12 recorded game runs.

Temporary deployment, game launch, temporary worlds and automatic isolation remain off and unavailable until an isolation adapter is validated. Execution-state models and dependency-aware subset planning are present; the complete game-test loop, supervised world-entry acceptance and functional preservation are not accepted capabilities yet.

Durable deployment transactions recover interrupted changes, block new deployments while recovery is incomplete and preserve external edits. Knowledge exchange remains local, with no configured remote receiver. No static result is promoted as a game-tested repair.

Development validation did not launch Palworld or modify installed mods. Full automatic acceptance remains pending.

## AI level and account

**AI level** supports detected, free/conservative, paid and manual-chat profiles. Routine work starts with gpt-5.6-luna, low effort and standard speed. PMM performs deterministic indexing, hashing and validation locally without model requests.

The initial ceiling permits routine work only. Users can authorize Terra/medium for repair diagnosis and Sol/high for complex design. The agent must record the blocked attempt and a specific reason before requesting a harder stage. PMM preserves the conversation and session limits. Every request sets the model and effort; unavailable settings or a different server acknowledgement pause the request. PMM never silently inherits Astra or fast mode.

Detected access and the current model catalog take precedence over a paid-profile preference. Exhausted reported quotas pause work; unknown quota data remains unknown. API billing needs a separate opt-in. Session turn-request*.json and usage-*.json retain requested settings, server acknowledgement and reported usage; backend execution details not exposed by the server remain unverified.

Manual chat prepares text for user transfer and return to the case. PMM cannot control that chat's model or confirm delivery. Chats also use tokens and may have limits; ChatGPT Work shares usage with Codex. [Official usage documentation](https://learn.chatgpt.com/docs/pricing).

**Continue investigation** resumes pending stages with the same identity. Policy changes apply to subsequent requests while active turns retain their settings.
