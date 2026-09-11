# AIIO standalone mod creation

PMM 1.3.1 adds a separate `CREATE_MOD` exchange for creating a new standalone Palworld mod. It does not turn a new mod into a compatibility merge and it never grants Fix Lab or AIIO authority over the deployed compatibility patch.

## User workflow

1. Build or refresh **Vanilla Game Reference** in normal Settings when its status is not `Current`.
2. Open **AI & Help → AI assistance → New mod project...**.
3. Enter a title, describe the desired behavior and optionally add an asset/search hint.
4. Choose **Create AI ZIP** and give that ZIP to an external AI yourself. PMM uploads nothing. If you close Explorer, select the exchange in **AI reception** and use **Open latest handoff**.
5. Import the AI response in **AI reception**.
6. If the response asks for evidence, select the routed exchange and press **Prepare requested data**. Give the new ZIP back to the same AI conversation.
7. When a returned cooked-tree candidate is present, inspect it and press **Build standalone PAK...** only if you accept it.
8. PMM creates the PAK inside that exchange's local `artifacts/mod-builds` folder. It does not copy it to Palworld.
9. Install and test it only through a separate explicit user action. Until tested, its runtime status is `UNPROVEN`.

If the mod is shared or published, its public description must include exactly:

> This mod was created with PMM assistance.

Every PAK built through this workflow also contains an inert, machine-readable `PMM/Metadata/created-with-pmm.json` entry. It contains the same notice, PMM version/build identity and candidate identity, but no personal data.

## Data-request contract

An external AI may request only capabilities advertised as `Requestable` in `PMM_CAPABILITIES.json`. Creation-specific evidence is limited to:

- `query_game_reference`: focused text query, maximum 200 results; exports metadata and hashes, not asset bytes.
- `extract_game_reference_asset`: one exact `.uasset` family from the current indexed Vanilla Game Reference.
- `extract_reference_neighborhood`: one exact seed plus at most 32 deterministically related families, subject to a byte budget.

The last two capabilities are rejected outside a `CREATE_MOD` session. Every extraction rechecks the current Palworld PAK, mappings and Game Reference identity. Arbitrary filesystem paths, whole source PAKs, credentials, executable code and automatic network access are outside the contract.

Example request inside `response.json`:

```json
{
  "capability": "query_game_reference",
  "query": "BP_PlayerBase",
  "maximumResults": 50,
  "maximumExpectedBytes": 10485760,
  "required": true,
  "reason": "Find the exact Vanilla player inventory family before requesting bytes."
}
```

After receiving query results, an exact follow-up may use:

```json
{
  "capability": "extract_game_reference_asset",
  "logicalPath": "Pal/Content/Pal/Blueprint/Character/Player/BP_PlayerBase.uasset",
  "maximumExpectedBytes": 67108864,
  "required": true,
  "reason": "Use this exact current Vanilla family as the source for the candidate."
}
```

## Returned candidate contract

The response ZIP has this shape:

```text
response.json
solutions/<candidate-id>/mod-creation.json
solutions/<candidate-id>/cooked/Pal/Content/<exact path>.uasset
solutions/<candidate-id>/cooked/Pal/Content/<exact path>.uexp
```

`response.json` uses `PMM_AI_RESPONSE_V2`, matches the exact `sessionId`, `bundleId` and `iteration`, and points `candidates[].path` to `solutions/<candidate-id>`.

`mod-creation.json` uses this contract:

```json
{
  "schema": "PMM_MOD_CREATION_CANDIDATE_V1",
  "sessionId": "AIIO-YYYYMMDD-HHMMSS-1234abcd",
  "mode": "standalone-cooked-tree",
  "modId": "ExampleInventoryIncrease",
  "displayName": "Example Inventory Increase",
  "version": "0.1.0",
  "outputFileName": "ExampleInventoryIncrease_P.pak",
  "gameReference": {
    "ScopeVersion": "PMM_GAME_REFERENCE_SCOPE_V1",
    "PakIndexSha256": "<exact 64-character SHA-256>",
    "MappingsSha256": "<exact 64-character SHA-256>"
  },
  "sourceFamilies": [
    {
      "asset": "Pal/Content/Pal/Blueprint/Character/Player/BP_PlayerBase.uasset",
      "parts": [
        {
          "relativePath": "Pal/Content/Pal/Blueprint/Character/Player/BP_PlayerBase.uasset",
          "size": 123,
          "sha256": "<exact 64-character SHA-256>"
        }
      ]
    }
  ],
  "files": [
    {
      "relativePath": "cooked/Pal/Content/Pal/Blueprint/Character/Player/BP_PlayerBase.uasset",
      "bytes": 123,
      "sha256": "<exact 64-character SHA-256>"
    }
  ]
}
```

PMM rejects stale Game Reference identities, missing or mismatched source-family proofs, path traversal, executable/nested archive content, undeclared payloads, orphan Unreal sidecars, output hash/size mismatches, unsafe PAK names, more than 2,000 cooked files or more than 2 GiB of cooked candidate data.

## Build boundary

Building revalidates the staged candidate, current Game Reference and all byte hashes. It also runs the bundled AssetReader in read-only probe mode against every returned `.uasset` header. PMM then packs only the declared `Pal/Content` cooked tree plus its required attribution JSON, checks PAK V11 readability, checks asset-family completeness and compares the exact PAK entry set. The PAK and `mod-build.json` remain inside the AIIO exchange.

PMM does not claim that structural validation proves gameplay behavior. A successful in-game test and inspectable feedback are required before any future Knowledge contribution can be considered runtime-proven.
