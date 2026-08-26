# PalModMerger roadmap after preview29

The preview28 runtime result is the point where PMM should move from architecture rescue to controlled hardening. The merger is not declared universal; proven adapters remain narrow by design.

## P0 - prove preview29 did not regress the working merge

1. Run the exact six-mod/current conflict fixture that passed preview28.
2. Confirm Analyze remains: `Shared 4 | merged automatically 3 | true-conflict decisions 1 | unsupported 0 | identical 0`.
3. Build/Deploy with Triple and confirm Fly + Triple + Stack/weight + NoSpoil + Early Aquatic + the previously proven pairs.
4. Analyze again without Force and Deploy again. The unselected Quad PAK must remain suppressed in `~mods`.
5. Remerge, choose Quad, Build/Deploy, and repeat the runtime checks.
6. Exercise Disable, Delete and re-import around Deploy. A same-name PAK with an unrecognized SHA-256 must block Deploy instead of being overwritten/deleted.
7. Keep the resulting logs, merge plan, output manifest and PAK hashes as the first preview29 release-candidate evidence set.

## P1 - automated regression suite

Build a Windows test harness around the real captured fixture plus distributable synthetic fixtures. It should validate routing, decision count, output hashes where deterministic, manifest contents, suppression state and repeated Analyze/Deploy behavior. The harness should run without the WPF UI.

Keep separate evidence labels:

- static/source validation;
- golden/fixture validation;
- Windows application validation;
- Palworld runtime validation.

## P1 - crash recovery for Deploy

Preview29 stages and hash-verifies desired files, backs up touched managed files, writes a transaction journal and automatically rolls back caught failures. A process kill, OS crash or power loss during the small commit window is a different failure class.

Next hardening step: on startup, detect a `Prepared` deployment transaction and offer/perform recovery from its preserved `Builds/DeploymentBackups/.../transaction.json` data before Palworld can be launched from PMM.

## P1 - transactional save restore

The existing save restore is conservative because it stops Palworld and creates a safety ZIP before replacing the world. Make it stronger without changing save parsing:

1. extract the selected backup into a staging directory first;
2. validate expected world files (`Level.sav` at minimum) before deleting anything;
3. preserve the current world as a verified rollback copy;
4. swap staged content into place;
5. automatically restore the safety copy if commit fails.

Do not add write-side save deserialization merely to make the feature look smarter.

## P1 - diagnostics export

Add one button that creates a privacy-conscious diagnostic bundle containing PMM version, dependency versions, mappings hash, source PAK names/hashes, merge plan, current patch manifest, deployment transaction/state and logs. Do not include save files by default.

This should be the first thing requested when a user reports `Unsupported`, Build failure or runtime regression.

## P1 - patch/deployment details UI

Expose a readable panel for:

- active / disabled / deployed source state;
- suppressed duplicate/alternative source PAKs;
- current / stale / legacy-compatible patch state;
- reconciled assets and adapter used;
- true-conflict decisions encoded in the output;
- last Deploy transaction and rollback backup location.

The goal is explainability, not more controls.

## P2 - adapter expansion only from real failures

When a new mod pair is unsupported, capture the real cooked families, classify the exact structural reason, and add the smallest safe adapter capability that proves composition. Do not pursue generic Blueprint/Kismet rewriting or revive `UAsset.Write()` as a universal writer.

Useful future adapter work is likely to come from repeated real patterns: fixed-size property transfers, well-proven relocation forms, compatible DataTable scalar families, or anchors that demonstrably contain all secondary edits.

## P2 - release engineering

Before a public beta:

- deterministic/pinned setup and dependency manifest;
- signed release packages if practical;
- generated `SHA256SUMS.txt` checked during release construction;
- clean upgrade path that preserves Mods, Saves/Backups and known-good patches while invalidating stale analysis state;
- explicit supported Palworld/mappings version in the UI;
- distributable regression fixtures plus hashes/metadata for non-distributable real mods.

## Product principle to keep

A successful PMM release should be judged by how rarely it guesses. Automatically merge only what can be proven compatible, ask the player only about the smallest genuine disagreement, and stop with an actionable `Unsupported` reason when composition is not proven.
