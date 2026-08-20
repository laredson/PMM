# Future PMM Community Knowledge Intake - Design Contract

This document defines the server-side direction only. PMM v1.1 implements the portable
submission artifact (`PMM_KNOWLEDGE_CONTRIBUTION_V1`) and local export UI; it does not
require or trust a live community service.

## Input

Accept exactly one contribution ZIP produced by PMM. Never execute files from it.
Quarantine the upload before parsing nested ZIPs.

Minimum validation:

- maximum compressed/uncompressed sizes and nested depth;
- reject absolute paths, drive paths, `..`, symlinks/reparse semantics and duplicate
  normalized ZIP names;
- parse supported JSON schemas only;
- verify contribution.json -> validation/runtime/solution/handoff hashes;
- verify caseId and target-asset identity across all nested metadata;
- fingerprint exact mappings, Vanilla family, complete provider hashes and provider
  family hashes;
- deduplicate by content hash and by normalized exact fixture signature;
- preserve original upload privately for audit, subject to retention policy.

## Review

Runtime PASS is a user report, not automatic proof. Aggregate independent reports when
possible. A reviewer/validator should decide whether the lesson is:

- explanatory Knowledge only;
- a regression fixture;
- an exact runtime-proven production recipe;
- a candidate generic adapter improvement;
- rejected / insufficient / stale.

## Publication

Publish only sanitized Knowledge metadata/recipes. Do not publicly mirror source mod
PAKs or extracted Vanilla cooked assets from submitted handoffs.

Production-capable packs should have an explicit trust/signature/version mechanism and
must use exact preconditions. The application should treat untrusted community packs as
explanatory evidence only.

## Client policy

A future PMM client may upload after explicit user action and may download a catalog of
approved packs. It must not silently upload user mods/game data, and it must not promote
an arbitrary downloaded community contribution into production write permission.
