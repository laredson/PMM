# PMM continuity / handoff contract

This directory is the canonical continuity layer for PMM development.

## Meaning of "handoff"

A handoff is the complete information another chat, Codex session, developer or AI needs to continue the project without access to the previous conversation.

The normal assumption is that the next worker has access to this Git repository. Therefore the handoff may point to source/evidence files in Git, but it must not require an old chat, a private ZIP or unrecorded context.

## Canonical entrypoints

Read in this order:

1. `CURRENT_HANDOFF.md` - complete human-readable project continuation.
2. `CURRENT_STATE.json` - machine-readable current state.
3. `../Reliability/V1502_SINGLE_EXE_AND_NOFLAG_PLAN.md` - authoritative execution plan.
4. `../Reliability/STATUS.md` - compact current status.
5. `../Reliability/NEXT_SESSION.md` - exact next block.
6. `HISTORY_REGISTRY.json` - classification/precedence of historical material.

`START_HERE_NEW_PROJECT.md` at repository root is intentionally a short pointer to this continuity layer.

## Precedence

If historical text conflicts with newer project state, use this order:

1. current checked-out code/package bytes;
2. CURRENT_STATE.json;
3. CURRENT_HANDOFF.md;
4. authoritative active plan;
5. STATUS + NEXT_SESSION;
6. current-line history/decision records;
7. session FINDINGS/CHECKS/evidence;
8. legacy handoffs and old release documentation.

Historical evidence is not rewritten merely because the plan changed. Instead it is classified and superseded.

## Historical classifications

- `CURRENT`: current state/continuation contract.
- `ACTIVE_PLAN`: normative current plan.
- `MILESTONE`: history of a completed integration/phase.
- `EVIDENCE`: hashes, checks, reports, acceptance notes.
- `INCIDENT`: an observed problem with explicit evidence state.
- `DECISION_CONTEXT`: rationale/transcript; useful context, not implementation spec.
- `LEGACY_HANDOFF`: complete handoff for an older branch/version.
- `LEGACY_PRODUCT_DOC`: old release/product state; not current branch authority.
- `LAB_CANDIDATE`: research/candidate source not automatically distributed.

## Update rule

Every development prompt that changes the project should end with one coherent local commit. If the prompt materially changes state, phase, plan or next work, update the continuity files in that same commit.

The handoff should always answer:

- What branch/version is this?
- What is actually packaged?
- What is proven and what is not?
- What features must be preserved?
- What architecture is intended?
- What changed in the last work block?
- What exact block is next?
- What tests/acceptance are still required?
- What historical files are evidence rather than current instructions?

Do not create a new ad-hoc handoff elsewhere unless a feature-specific exchange format explicitly requires it.
