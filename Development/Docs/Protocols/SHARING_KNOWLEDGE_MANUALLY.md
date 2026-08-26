# Sharing PMM knowledge manually — v1.1

PMM v1.1 deliberately keeps community upload/download manual. This gives the project a useful public release without making remote content or self-updating code part of the trusted runtime yet.

## Supported path

### 1. Normal supported merge

Run:

`Import -> Analyze -> resolve real conflicts -> Build -> Deploy`

If the automatic adapters/known Knowledge support the exact inputs, PMM creates only the compatibility patch. Original mods remain intact.

### 2. Unsupported merge -> AI handoff

For an Unsupported asset:

1. run Analyze and review the Unsupported set;
2. use **Create AI handoff** (or accept the prompt shown after Analyze);
3. AIIO produces one exact `AI_HANDOFF_<bundleId>.zip` for all current Unsupported cases;
4. the bundle contains only the exact conflicting files extracted separately from each provider and Vanilla; whole PAKs are never copied;
5. give the ZIP unchanged to an AI or experienced modder;
6. request a `PMM_MANUAL_SOLUTION_V1` response for each solved cooked-family case;
7. import the returned per-case ZIP through PMM.

PMM validates case identity, hashes, ZIP topology, cooked-family structure, and read-only parsing. This does **not** prove gameplay behavior.

### 3. Runtime test

Build and Deploy the experimental solution and test it in Palworld.

A useful report should record:

- exact PMM version/build ID;
- whether the game launched;
- whether the relevant world loaded;
- whether the affected mod behavior worked;
- whether the test used a new world or an existing world;
- any important additional mods that may interact with the same behavior.

For v1.1, this runtime evidence is user-reported. Automatic runtime observation is planned for a later release.

### 4. Export a tested contribution

After a successful test:

**Settings -> Create tested contribution...**

PMM creates:

`Data/KnowledgeContributions/PMM_KNOWLEDGE_CONTRIBUTION_<case-id>.zip`

The package contains the exact case, solution, validation metadata, original handoff when available, and an explicit user-reported PASS.

## Sharing it

Until the connected Knowledge service exists, share the contribution ZIP manually with the PMM project.

Developers can also open a GitHub pull request with code, tests, mappings, documentation, or carefully reviewed Knowledge changes. See `CONTRIBUTING.md`.

Do not commit or upload:

- personal save files;
- complete Palworld game assets;
- credentials/tokens;
- unrelated user PAKs;
- machine-specific paths or identifiers.

## Trust rule

A contribution never promotes itself into production Knowledge.

The intended lifecycle is:

`submission -> quarantine -> independent validation -> experimental -> stable`

The schemas/design for that future lifecycle are documented under `Documentation/Protocols/`.
