# Initial preserved context

This folder marks the repurposing point of the historical `info` branch.

The old branch was based on PMM 1.2.1 and is **not current application authority**. Its useful unique contribution was detailed Analyze/Merge architecture documentation. That material is preserved here as a reference snapshot rather than keeping the whole old application tree as the visible branch state.

Historical branch tip before repurposing:

- `bd02ad8e6390c1c744e370c15581b2e7a4541933` — `Link expanded Analyze-Merge architecture reference`
- Parent `4dbe826fd18a9926fe22ae41cb141d8f01d379aa` — `Add comprehensive Analyze-Merge internals documentation`

The full old tree remains recoverable from Git history at those commits.

## Valuable preserved document

`ANALYZE_MERGE_INTERNALS.md` documents the PMM Analyze → compatibility planning → Build → Deploy model as verified against the 1.2.1 Guided Flow baseline. It remains useful architectural background, but newer branch-specific documents override it where the implementation has changed.
