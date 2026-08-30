# AI & Help, AIIO and Knowledge

PMM 1.3 RC27 adds a local-first **AI & Help** workspace. It is a durable task and evidence system, not a built-in cloud account. PMM does not connect to an AI provider, upload files, request credentials or run returned code.

## Persistent sessions

An AIIO v2 session keeps its description, selected targets, exact Unsupported case IDs, requests, responses, staged candidates and history below `Workspace\AIIO\Sessions`. Sessions survive restarts and may be archived explicitly. Re-analysis reuses an Unsupported session only when the exact case set, source signature and merge-order signature still match.

The Help page can create bounded diagnostic cases for PMM errors, crashes, mods that do not work, build/deploy failures, save problems and performance issues. A selected mod or build is recorded as a suspicion, never as a proven cause. Save activity, the recoverable operation journal, deployment metadata, Knowledge matches and bounded log summaries provide local context.

## Manual ZIP exchange

**Prepare for AI** creates `PMM_AIIO_REQUEST_...zip`. You choose whether and where to send it. The bundle uses `PMM_AI_HANDOFF_BUNDLE_V2` and includes:

- a sanitized session and current-plan summary;
- exact current Unsupported case metadata;
- the local capability registry;
- bounded diagnostic/operation evidence when relevant;
- a response contract and template.

Whole source PAKs, save contents, credentials and arbitrary local paths are not included. If an AI needs more data, its `PMM_AI_RESPONSE_V2` can request only enabled, allowlisted capabilities. A provider-source request must name the exact provider from the current Unsupported case; a Vanilla request is accepted only when that case has a Vanilla source. **Prepare requested data** creates the next bounded ZIP; it does not grant a general filesystem or command capability.

Session preparation, requested-data preparation, response import and candidate activation/validation execute through the supervised background operation worker so archive, extraction and hashing work do not block navigation in WPF.

## Returned content is untrusted

Imported response archives are checked for size, entry count, duplicate roots, traversal, absolute paths, links, nested archives and executable/script extensions. Every candidate is staged below its session and remains inactive.

Only an exact `PMM_MANUAL_SOLUTION_V1` cooked-family candidate can expose **Use candidate in Merge**. The user must confirm it, and PMM then repeats the existing exact case/hash/topology/AssetReader validation and forces Analyze. It never starts Build or Deploy. Full-PAK, theme and development candidates remain staged for inspection; PMM never executes them.

The older one-shot **CREATE AI HANDOFF** flow remains available for compatibility with existing `PMM_MANUAL_SOLUTION_V1` tooling. New work should use the persistent AIIO v2 tab.

## Knowledge and runtime evidence

Bundled and local CKL Knowledge can explain or prove narrowly defined compatibility behavior. It cannot silently promote an AI answer. Validation belongs to a deterministic build ID and is stored as immutable local events: `UNVALIDATED`, `LOCAL_PASS`, `LOCAL_PARTIAL`, `LOCAL_FAIL` or `NOT_DEPLOYED`. Feedback files are generated locally for review; RC27 has no feedback API and uploads nothing.

Gameplay semantics still require an in-game test. Publishing a branch, contribution or solution, applying a Fix, restoring state and deploying are always separate explicit actions.

See `MANUAL_SOLUTION_CONTRACT.md`, `COMMUNITY_KNOWLEDGE_WORKFLOW.md` and `RC27_AIIO_RELEASE_CANDIDATE.md`.
