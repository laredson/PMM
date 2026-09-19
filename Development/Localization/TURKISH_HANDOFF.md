# PMM Turkish localization - published; user QA pending

## Publication checkpoint - 2026-09-18

The Git commit containing this record publishes Turkish and Polish together on `v1.5.0.0-PMM-translated`, based on `7b0209836ddcf8027c604bad9ea5c9e9ee0da9d2`. Turkish is reused byte for byte as blob `a91f23d0efc9b1fd53570b2f94f1078c6fec0487`; the catalog has not been retranslated. Both package checksums and the local Turkish structural validator were rechecked successfully. The corresponding GitHub catalog object was retrieved before publication.

Turkish is now enabled/complete in the published registry `5045c649730ae8cd50864285ecc6da5948008c46`, alongside Polish: 29 locales registered, 15 enabled. All thirteen previously published catalogs are unchanged. Italian user feedback is recorded. Turkish and Polish runtime/visual QA remain pending; no PMM/WPF, PowerShell 5.1 or native-speaker acceptance was performed.

Pull the branch, select `Türkçe`, apply/save the language and restart PMM. Do not apply the earlier local patches after pulling this publication. Publication uses one fast-forward commit with `[skip ci]`, no force-push, no workflow dispatch and no changes to runtime, binaries, main, tags or releases. The visual selector order remains unchanged.

**Next translation: Nederlands (`nl`), then Gaeilge (`ga`).** Polish was published with Turkish and is no longer the next translation. `Progress/tr.json` records current publication separately from retained local preparation evidence.

## Historical preparation handoff

The original preparation record below is retained as historical evidence. Its unpublished status, Turkish-only registry count and patch instructions describe the earlier local delivery, not the publication above.

# PMM Turkish localization - complete catalog; publication and user QA pending

Date: 2026-09-18
Branch: `v1.5.0.0-PMM-translated`
Source checkpoint: `7b0209836ddcf8027c604bad9ea5c9e9ee0da9d2`
Locale: `tr` / `Türkçe`
Next queued translation after Turkish: **Polish (`pl`, Polski)**

## Delivery state

This is a complete **1,291/1,291-entry** Turkish catalog prepared locally, not a claim of GitHub publication. The preparation turn had a working GitHub read connection but exposed no commit/file-write actions after discovery. No repository reference was updated. Do not confuse a computed Git blob hash with an uploaded blob or a published commit.

The prepared registry activates only `tr` (`enabled: true`, `status: complete`). All 13 previously active catalog files are untouched, including Italian. The user reported: "italiano probado. ok." Record this as Italian user runtime confirmation, not exhaustive native-speaker or automated review.

Canonical English blob: `2fa3c4712619cc5f811ce2251cef3daf5b0e2024`, 132,005 bytes.
Prepared Turkish blob (computed locally): `a91f23d0efc9b1fd53570b2f94f1078c6fec0487`.
Turkish SHA-256: `06d9235a5f6b59c9e2901c76d8ea438f317c34cd4ee72898584ef9de87a5142e`; 142,665 bytes, UTF-8/LF.
Registry before: `0bbac7221e8bd16c128758a50710e63c9b5d73e9`.
Registry after (computed locally): `7f88c7a1ca61f8c7baa9ba0d6431291b826e680a`.

The English file was recovered from the earlier attachment and matched the canonical GitHub blob reconfirmed at this source checkpoint. The base registry and empty Turkish template were also reconstructed and hash-verified against the current remote files. No translation was derived by changing the English source keys.

## Executed checks

The accompanying `qa/validate_tr.py` passed strict UTF-8 JSON/duplicate checks, metadata, exact case-sensitive keys/order, nonempty values, complete placeholder/format multisets, braces, numeric literals, edge whitespace, literal escapes, selected protected identifiers, extensions, file-dialog filters, units, color tokens, `~mods`, NFC, Unicode controls and native language names. It also verifies that the registry differs only in Turkish activation, preserving all ordering and locale fields.

Results: **109 parameterized entries**, **21 intentional English-identical entries**, no missing/extra/empty entries, zero structural errors. The invariant allowlist and exact findings are in `Progress/tr.json` and the delivery's `qa/validation.json`.

No PMM/WPF runtime, Windows PowerShell 5.1, full source-code localization auditor or native-speaker acceptance was run. Local script checks do not prove all dynamic UI text is translated. Known dynamic counters, the older Library.UI selector path, Arabic mixed prose/path bidi behavior and virtualized technical cells remain separate QA items.

## Terminology

| Source concept | Turkish |
|---|---|
| Analyze / build | Analiz et / Derle |
| Deploy / undeploy | Dağıt / Dağıtımı kaldır |
| Delete / remove | Sil / Kaldır |
| Repair / Apply Fix | Onar / Düzeltmeyi uygula |
| Merge | Birleştirme |
| Case / job | Vaka / İş |
| Game Reference | Oyun Referansı |
| Asset / shared assets | Varlık / Paylaşılan varlıklar |
| Mappings / hash | Eşlemeler / Karma |
| Compatibility overlay | Uyumluluk katmanı |
| Evidence / handoff | Kanıt / Aktarım paketi |
| Knowledge / AI | Bilgi Tabanı / YZ |
| Save backup / save restore | Oyun kaydı yedeği / Oyun kaydını geri yükleme |

`UNPROVEN` is retained as `KANITLANMADI (UNPROVEN)`. Product/code identifiers, native language labels, keyboard shortcuts and file filters remain recognizable. PAKs/ZIPs become PAK/ZIP in Turkish. Explicit consent, separately billed API opt-in, rollback warnings and untrusted/inactive returned content keep their original meaning.

## Selector and continuation

The quasi-continental selector order is unchanged. English remains first/default, Romance and other European locales stay above Asia, Polski and Nederlands retain their positions after Deutsch, both Chinese variants remain adjacent, and Türkçe keeps its reserved position immediately before العربية. Pending locales remain hidden. No Romanian template is added.

Next execution queue: **Polski -> Nederlands -> Gaeilge**. This is independent of the visual selector order.

When write actions are available, inspect the current branch and changed-file hashes first. Use the prepared catalog, registry, feedback and documentation changes without retranslating. Publish one normal fast-forward development commit with `[skip ci]`, without touching main, releases, tags, workflows, runtime code or binaries. Do not create transfer files, stage repeated partial commits or force-rewrite branch history. If the branch moved, reconcile the small changes with the new head rather than resetting it. After publication update `Progress/tr.json` publication status and verify the returned catalog blob equals `a91f23d0efc9b1fd53570b2f94f1078c6fec0487`.

For local testing, apply the delivery patch, open PMM from that checkout, select `Türkçe`, apply/save and restart PMM. Check main tabs, settings, long tooltips, confirmations and Turkish letters (İ/ı/Ş/ş/Ğ/ğ/Ç/ç/Ö/ö/Ü/ü). Keep restart-based language switching.
