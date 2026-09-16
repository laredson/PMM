# PMM 1.3.4 — Desktop and AUAT
Release candidate for user acceptance; main and latest release remain unchanged.

- Desktop activation targets the unique running compatible signed Windows package. Branding no longer selects the obsolete logged-out ChatGPT installation.
- Existing conversation IDs are preserved. Opening them does not start a model request.
- New cases default to Codex Desktop and Chat / Quick Chat. Installed modes (chat, work, codex) are detected from the packaged route schema without AI inference. Unknown schemas fail closed.
- Prepare question opens a draft. Send question is an explicit intention, blocked until a verified automatic-send interface exists. Anonymous/new-profile launching is unavailable.
- Desktop owns authentication, account limits and model selection. Chat is not advertised as unlimited or zero cost. If Chat lacks local PMM tools, the user must choose Work; PMM never switches silently.
- A Folders panel provides case, handoff, solutions, candidates, evidence and chat history.
- Bundled mappings updated to Mapping104. Historical 1.0.3 mappings remain available for exact old donor assets.
- Fix Lab recognizes exact AUAT V1 and builds AUAT v1.1 against the pinned current Palworld 1.0.4 families. It modifies only DefaultUnlockTechnology, validates all 588 technology IDs, preserves the new WazaSelectPowerOverrideMap and other current Blueprint data, then proves lossless serialization and PAK readback.
- Structural validation is separate from in-game functional validation. The recipe reports runtime as unproven until a game test is recorded.

Use Fix Lab > analyze AutoUnlockAllTechnology_V1_P.pak > AUAT v1.1 > build. Different donor hashes, mappings or target game families require a new recipe.

Sources: [Mapping104](https://www.nexusmods.com/palworld/mods/2854?tab=files), [Desktop modes](https://learn.chatgpt.com/docs/quickstart).

The MCP status response includes installationRoot; case prompts verify the intended installation before claiming a request. Project-scoped MCP configuration is generated in the selected PMM folder without replacing global connections.

Steam installations now launch through steam://rungameid/1623730 without added arguments, retaining Steam's configured options. MCP explicitly loads the Windows PowerShell utility module when started by a non-PowerShell desktop process.
