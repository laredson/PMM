# PMM Protocol Schemas

Formal protocol foundation for PMM community evolution.

- `Knowledge Schema v2`: stable identity for merge knowledge, conflict-set semantics, order relevance, compatibility and lifecycle.
- `Evidence Schema v1`: append-only positive/negative/runtime evidence, including new-world tests and anonymous installation deduplication.
- `Update Manifest v1`: independent PMM and Knowledge channels, hashes, compatibility, rollback and Ed25519 signatures.

Key rule: the complete installed mod list does **not** define a merge. The effective conflict set + normalized semantic result does. Unrelated mods remain evidence context.

Application channels: `stable`, `beta`, `community`.
Knowledge channels: `stable`, `experimental`.

Branches are development sources. PMM installs only artifacts produced from validated branches/PRs and referenced by a signed manifest.
