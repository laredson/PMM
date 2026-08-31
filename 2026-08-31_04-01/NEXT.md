# Next work

## Before the large AIIO redesign

Complete the remaining small UI/presentation changes on `1.3.1-mod-creation` as one coherent polish block:

1. Rename visible `Auto ON` / related wording to **SemiAUTO** consistently in UI, tooltips, status text and relevant documentation.
2. Enlarge the one-shot **AUTO** button horizontally so it uses the remaining header-row space while Cancel keeps a sensible fixed width.
3. Give AUTO a stronger visual border/treatment compatible with themes.
4. Add a subtle periodic sparkle/star pass over AUTO only while AUTO is idle; disable the effect while the automatic workflow is running.
5. Finish the requested natural progress presentation using the existing smoothing layer rather than creating a competing progress system:
   - start visual progress at 0 for a new real operation;
   - slow +1% visual movement at randomized ~0.5–2.0 s pacing while remaining below the real step ceiling;
   - when real work advances, accelerate catch-up at randomized ~0.1–0.5 s per 1% until the newly proven minimum is reached;
   - never move backward and never display progress beyond the real operation boundary;
   - completion may still snap/confirm at 100% when the real operation is finished.

After these changes: Windows test, then decide whether this becomes the intermediate publication candidate.

## Larger follow-up phase

Redesign AIIO/Game Reference to minimize human round trips. Priority concepts already identified:

- complete Vanilla PAK path/family index even when bytes are not cached;
- extraction on demand from proven index paths;
- composed research operation that can search/rank/extract in one preparation;
- strict request-field validation and explicit aliases;
- pagination, filtering, exclusions, total matches and truncation metadata;
- clear separation of payload bytes, metadata bytes, compressed size and expanded size;
- configurable transfer profile around 500 MiB for ChatGPT Work and multipart support;
- ability for Mod Creation, and potentially Fix Lab/Merge, to request purpose-built additional Game Reference evidence.

The inventory-capacity experiment is the key regression scenario: useful evidence should be reachable with roughly one preparation round after the initial request, not 5–10 technical exchanges.
