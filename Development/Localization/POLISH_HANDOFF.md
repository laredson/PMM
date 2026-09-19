# PMM Polish localization - published; user QA pending

## Publication checkpoint - 2026-09-18

The Git commit containing this record publishes Polish and Turkish together on `v1.5.0.0-PMM-translated`, based on `7b0209836ddcf8027c604bad9ea5c9e9ee0da9d2`. Polish is reused byte for byte as blob `0485e18aa3ac5b10a83b408f7b140b3d17f7c564`; Turkish remains blob `a91f23d0efc9b1fd53570b2f94f1078c6fec0487`. Neither catalog has been retranslated. Both packages passed checksum verification and both local structural validators were rerun successfully with zero errors. Both exact catalog objects were retrieved through the GitHub connector before publication.

The published registry is `5045c649730ae8cd50864285ecc6da5948008c46`: 29 registered locales, 15 enabled. Polish and Turkish are enabled/complete; only their activation fields differ from the Italian checkpoint. The thirteen previously published catalogs and the entire visual selector order are unchanged. Italian user confirmation is included in its progress and handoff; Turkish/Polish user runtime and visual testing remain pending.

Pull the branch, select `Polski`, apply/save and restart PMM. Do not apply the old local patches after pulling this publication. Publication is a single normal fast-forward development commit with `[skip ci]`, with no force-push, transfer-only commits, PR, release, tag, main update, workflow dispatch, runtime-code change or binary change.

**Next translation: Nederlands (`nl`), then Gaeilge (`ga`).** `Progress/pl.json` records the current publication separately from the retained preparation validation. No PMM/WPF, Windows PowerShell 5.1, full source-code audit or native-speaker acceptance is claimed. Generic dynamic-runtime and Arabic bidi QA remain open.

## Historical preparation handoff

The original preparation document below is retained. Its unpublished status and alternative patch instructions describe the earlier local delivery only and are superseded by this publication checkpoint.

# PMM Polish localization - complete catalog, publication pending

Date: 2026-09-18
Repository: `laredson/PMM`
Branch: `v1.5.0.0-PMM-translated`
Verified source checkpoint: `7b0209836ddcf8027c604bad9ea5c9e9ee0da9d2`
Locale: `pl` / `Polski`
Next translation: **Dutch (`nl`, Nederlands)**, then **Irish (`ga`, Gaeilge)**.

## Actual state

Polish is newly translated and structurally validated: **1,291/1,291 canonical English entries**, no missing/extra/empty keys, **109 parameterized entries**, **23 intentional invariant values**, and zero structural errors in the executed local checks. It is prepared locally, **not published to GitHub**. Do not mistake a generated patch, local blob hash or registry activation in this package for a remote commit.

English source Git blob: `2fa3c4712619cc5f811ce2251cef3daf5b0e2024` (132,005 bytes). The source copied from the prior Turkish delivery matches the blob reconfirmed by the GitHub connector at the source checkpoint.
Polish Git blob, computed locally: `0485e18aa3ac5b10a83b408f7b140b3d17f7c564`.
Polish SHA-256: `b00efd82dbbcacb3b36e32c310b1879d958f8775eda5ee907703be93cc3b9164`.
Polish bytes: 143,271, UTF-8/LF.

Turkish is also complete but still pending publication. The cumulative delivery includes the exact previous Turkish catalog, Git blob `a91f23d0efc9b1fd53570b2f94f1078c6fec0487`, without retranslating it. Its existing structural validator was rerun locally and passed; this is not a Turkish runtime test. The prior Italian feedback ("italiano probado. ok.") is preserved in the Turkish delivery's Italian progress/handoff updates. No new language acceptance is inferred from the request to continue.

## Integration choices

`PMM_Turkish_Polish.patch` integrates both prepared languages on the verified Italian branch checkpoint. It changes eleven files: the two catalogs, registry, Italian/Turkish/Polish progress, their relevant handoffs, and the two shared ledgers. The thirteen already enabled catalogs are not changed.

`PMM_Polish.patch` is incremental: apply it only after the exact previous Turkish patch has been applied. It changes six files and leaves Turkish's catalog intact. It must not be applied directly to the unmodified Italian checkpoint.

Both routes produce the same final catalog/registry/document state. They are alternatives, not two patches to apply in succession. The cumulative registry has **29 registered locales and 15 enabled locales**; the verified remote checkpoint still has 13. Only `tr` and `pl` change enabled/status relative to that checkpoint. `pl` alone is new relative to the prepared Turkish registry.

Three large existing documents are integrated by exact-prefix replacements, never by truncating/replacing the entire file with a snippet. `DELIVERY.json` describes both integration profiles. Fetch the full documents and preserve all bytes after the stated prefixes. Hash checks are mandatory before a future publication. No automatic commit or push is performed by this delivery.

## Terminology

| Source | Polish |
|---|---|
| Analyze | Analizuj / analiza |
| Build | Zbuduj / budowanie; kompilacja for a built artifact |
| Deploy / Undeploy | Wdróż / Wycofaj z gry |
| Delete / disable | Usuń / Wyłącz |
| Merge | Scalanie / scalenie |
| Repair | Napraw / naprawa |
| Case / job | Sprawa / zadanie |
| Game Reference | Dane referencyjne gry |
| Current Game Reference | Aktualne dane referencyjne gry |
| Shared assets | Zasoby współdzielone |
| Mappings | Mapowania |
| Compatibility patch / overlay | Poprawka zgodności / nakładka zgodności |
| Handoff / evidence | Pakiet przekazania / dowody |
| Settings | Ustawienia |
| Save backup / save restore | Kopia zapasowa zapisu gry / przywracanie zapisu gry |
| Light | Jasny |

Product names, actual identifiers, extensions, format placeholders and native language labels remain intact. `UNPROVEN` is retained with `NIEPOTWIERDZONE`. Generic Vanilla/Knowledge/cooked prose is translated; actual identifiers such as GameReference and cooked-tree remain recognizable. Where a numeric placeholder can represent different Polish plural forms, neutral labels are used rather than adding pluralization logic. Invariant values are explicitly allowlisted; `Adapter` and `Mod` are also valid Polish words. Labels such as English, Español and 简体中文 remain in their own language.

## Visual order and unchanged scope

The quasi-continental selector order is unchanged. English remains first/default. **Deutsch -> Polski -> Nederlands** stays together; Japanese begins the Asian block, both Chinese variants remain adjacent, and Turkish retains its position before Arabic. Unfinished entries remain hidden. Romanian remains a possibility only, not a new registered language.

No runtime code, WPF layout, native executable, live switching, Arabic bidi implementation, workflow, main, release, tag, PR or installed game file is changed. Existing dynamic-counter localization gaps, the older Library.UI selector path and Arabic mixed-direction/virtualized-cell QA remain open separately.

## Executed validation and limits

`qa/validate_pl.py` checks strict UTF-8 JSON and duplicates, exact key set/order, locale metadata, nonempty strings, full placeholder/format multisets, remaining braces, numeric literals, edge whitespace, literal PowerShell escapes, protected technical-token counts, extensions/wildcards/filter patterns, units, color syntax, ~mods, Unicode controls/NFC, explicit invariants, native labels, registry changes/order, and unchanged Turkish bytes. No contextual technical-token count exception was required; PAKs/ZIPs normalize to PAK/ZIP.

`qa/patch_validation.json` records local application/reversal and convergent integration tests in bounded Git fixtures with LF and CRLF. Those fixtures contain complete affected catalog/registry/progress files and the exact document prefixes with protected synthetic tails. They are **not a full repository checkout or a runtime/source-code localization audit**.

No PMM/WPF, Windows PowerShell 5.1 or native-speaker acceptance was run. These remain required for release acceptance. For user testing: apply one suitable patch, run PMM from that checkout, choose `Polski`, apply/save and restart. Check long labels, dialogs, tooltips and Polish letters (ą, ć, ę, ł, ń, ó, ś, ź, ż). Do not bring back live language switching.

## Publication handoff

Re-read remote HEAD and affected files first; do not overwrite newer work. Publish only when an authenticated write action is available, with a normal fast-forward commit and `[skip ci]`. Never create transfer-only files, repeated partial commits, or force-push. Preserve user changes. Verify the published Polish and Turkish blobs against the identities above, then verify the branch ref and registry. Only after successful publication record the actual remote status/commit.

Next translation is **Nederlands**, then **Gaeilge**. Turkish and Polish are not to be translated from scratch again. Their user runtime/visual QA remains pending. Historical next-language pointers below the new shared checkpoints are snapshots, not the current execution queue.
