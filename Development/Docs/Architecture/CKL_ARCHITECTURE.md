# Community Knowledge Library (CKL) architecture

PMM 1.2.1 keeps reusable compatibility knowledge outside the native executables so it can be inspected, extended and updated independently.

## Runtime layout

- `PMM/CKL/Stable/` — reviewed knowledge shipped to normal users.
- `PMM/CKL/Experimental/` — candidate knowledge which may be useful as evidence but cannot authorize an automatic writer.
- `PMM/CKL/Catalog/case-index.json` — compact master catalog used for discovery before detailed recipe files are opened.
- `PMM/CKL/channels.json` — channel identity and repository references.
- `PMM/Modules/CKL/` — code that queries, validates, exports and applies CKL knowledge.

## Current knowledge inventory

The 1.2.1 library indexes 12 reusable records:

- 7 documented behavior cases;
- 4 exact fixtures;
- 1 production-enabled recipe.

The production-enabled recipe is the runtime-proven RushRoarLeatherDrop_v2 + FasterMounts case. Other historical cases such as Fly + Wing, MultiJump, StaticItem combinations, BreedFarm and PlayerStatus remain evidence/fixtures unless a general PMM adapter proves them automatically or an exact production recipe is explicitly enabled.

This distinction is intentional. Historical knowledge can explain a case or help an AI/modder without silently becoming permission to write cooked output.

## Analyze lookup flow

For every shared asset, Analyze has the asset path and active provider identities. It queries `case-index.json` first instead of opening every knowledge document.

Candidate matching uses:

1. asset path;
2. provider names;
3. provider PAK hashes when the exact case manifest contains them.

The resulting relationship is classified as one of:

- `EXACT_PROVIDER_FIXTURE` — all indexed providers are present and every available hash pin matches;
- `HASH_PINNED_PARTIAL` — at least one provider is hash-pinned and matches, but the current conflict has additional/different providers;
- `RELATED_PROVIDER` — same asset/provider identity with insufficient hash pins for exactness;
- `SAME_NAME_DIFFERENT_BUILD` — a known provider name is present but its pinned bytes differ.

Analyze can then use the detailed Stable records as context. A candidate by itself never grants merge permission.

## Automatic solution safety

Only two mechanisms may authorize automatic output:

1. a normal PMM adapter proves the current bytes can be composed safely; or
2. a CKL production recipe is explicitly `production.enabled=true` and its complete validation contract matches.

A production recipe requires exact engine profile, mappings hash, complete provider PAK hash set, Vanilla family hashes/sizes, provider family hashes/sizes and a runtime-proven output family. Any mismatch falls back to normal adapters or Unsupported.

Experimental knowledge never authorizes a writer.

## Unsupported and AIIO

When an asset remains Unsupported, Analyze records the relevant CKL candidates in the analysis metadata. It still creates no AI handoff automatically.

When the user explicitly creates an AI handoff, AIIO produces one bundle for the current Unsupported set. In addition to the exact Vanilla/provider files, the bundle contains:

- the local CKL snapshot;
- `knowledge/relevant-knowledge.json`, mapping each Unsupported case to its relevant CKL records and match type;
- `knowledge/channels.json`, identifying Stable and Experimental sources;
- exact case hashes and analysis evidence.

This gives the receiving AI/modder a richer starting point without treating CKL hints as proof.

## Contribution and promotion flow

After a returned AI/manual solution passes PMM validation and the user explicitly reports an in-game PASS, PMM can export a knowledge contribution. The contribution contains:

- exact `case.json`;
- validation metadata;
- returned solution bytes;
- runtime result and user notes;
- original handoff when available;
- `ckl-context.json` and CKL channel metadata, preserving which previous knowledge was relevant when the solution was created.

A contribution is evidence only. It does not install itself into Stable and cannot enable an automatic writer.

Promotion to Stable is a maintainer/community process: reproduce the case, validate provenance and hashes, identify the general lesson or exact fixture, and publish a reviewed CKL update. Only an explicitly reviewed production recipe may become automatic merge permission.

## Updating CKL independently

The runtime CKL directory is deliberately independent of `PMM.exe` and `PMMRuntime.exe`. A future signed CKL update can therefore replace Stable/Catalog data without rebuilding the engine.

PMM 1.2.1 ships the local channel/catalog contract and repository references. Automatic network installation of arbitrary GitHub/raw CKL files is intentionally not enabled yet: a remote update mechanism should only be activated once a signed/versioned CKL artifact contract exists. This prevents an unsigned knowledge download from becoming a software supply-chain path.
