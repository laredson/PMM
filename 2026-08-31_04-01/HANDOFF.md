# Handoff for a new AI/developer

Start here when continuing PMM development from a new chat or environment.

1. Read `README.md` at the root of the `info` branch.
2. Read the newest timestamp folder in `info`.
3. Check the exact application branch and commit recorded in that snapshot.
4. Read that branch's `Development/AI/CURRENT_STATE.md` and `Development/AI/AI_CONTINUE_HERE.md` before modifying code.
5. Treat `PMM/` in the active application branch as runnable authority.
6. Use older `info` folders only when historical rationale is required.

## Current continuation point

At this snapshot the accepted application baseline is:

- branch `1.3.1-mod-creation`
- commit `d487fc6d434f7972da0d390e5bf406c38e45f37d`

The maintainer has Windows-tested the checked 1.3.1 fixes and accepted this as the baseline.

The next implementation block is small release polish: SemiAUTO wording, AUTO button presentation/sparkle behavior, and natural progress animation. After that, test an intermediate publication-quality build. The larger AIIO/Game Reference minimum-interaction redesign should be handled as a separate focused phase.

Do not use the old `info` branch's former 1.2.1 application tree as source authority. Its unique Analyze/Merge architecture reference is preserved under `initial/` only for background.
