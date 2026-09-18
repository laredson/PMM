# PMM Traditional Chinese localization - complete and published

Date: 2026-09-18
Branch: `v1.5.0.0-PMM-translated`
Base commit: `e1267ee66b934ea5610b085f6f7ce67d710b2b79`
Locale: `zh-TW` / `繁體中文`
Next queued language: Japanese (`ja`, 日本語)

## Publication

Traditional Chinese now covers **1,291/1,291 canonical English entries** and is enabled for user testing. This publication uses the exact catalog prepared and validated before GitHub write access was restored; it was not retranslated during publication. The ten previously enabled language catalogs, runtime code, binaries and restart-based language switching are unchanged.

The temporary transfer commits used only to move the prepared payload are intentionally replaced by this single clean development commit. Publication uses `[skip ci]`; no PR, tag, release, main update or workflow dispatch is part of this checkpoint.

Canonical English blob: `2fa3c4712619cc5f811ce2251cef3daf5b0e2024` (132,005 bytes).
Traditional Chinese blob: `1360cf6ae05998cb8170aac47b9714972a70fa86`.
Traditional Chinese SHA-256: `8abfe1603399d60d9d20be961c45237a9b6dc77a9c771016443abb73e9904b56`.
Target size: 131,024 bytes, UTF-8/LF.

## Translation approach

The catalog was authored against canonical English, using Taiwan-oriented Traditional Chinese interface terminology. The existing Simplified Chinese catalog was inspected but not used as an automatic conversion source. No Simplified Chinese strings were changed.

| Source concept | Traditional Chinese |
|---|---|
| Case / job | 案例 / 工作項目 |
| Analyze / build | 分析 / 建置 |
| Deploy / undeploy | 部署 / 移除部署 |
| Delete / remove | 刪除 / 移除 |
| Merge | 合併 |
| Repair / recipe | 修復 / 配方 |
| Game Reference | 遊戲參考資料 |
| Asset / shared assets | 資源 / 共用資源 |
| Mappings | 對應資料 |
| Library / Steam library | 資料庫 / Steam 收藏庫 |
| Compatibility patch / overlay | 相容性修補檔 / 相容性覆蓋層 |
| Evidence / findings | 佐證資料 / 分析發現 |
| Handoff | 交接套件 |
| Backup / restore / rollback | 備份 / 還原 / 回復 |
| File / folder | 檔案 / 資料夾 |
| Settings / refresh | 設定 / 重新整理 |
| Preview / color scheme | 預覽 / 配色方案 |
| AI | AI |

`UNPROVEN` remains visible as `未證實 (UNPROVEN)`. Product names, technical identifiers, format placeholders and native language names remain intact. In particular, `English`, `Español` and `简体中文` remain in their own native writing.

## Validation

Local structural validation passed strict JSON/duplicate rejection, metadata, exact case-sensitive key set and order, nonempty strings, all placeholder/format multisets, braces, numeric literals, edge whitespace, selected technical tokens, extensions, units, file-dialog patterns, NFC and Unicode controls. There are **109 parameterized entries**, **21 intentional invariants**, zero missing keys, zero empty values and zero structural errors.

An ICU Hans-Hant comparison found no unexpected script differences; the native language label `简体中文` is the deliberate exception because language names must remain native. This is a script check, not native-speaker acceptance.

No PMM/WPF runtime, Windows PowerShell 5.1, native-speaker acceptance or full source-code localization audit was run for this catalog. Existing dynamic English counters, the older Library.UI selector assignment, Arabic mixed prose/path bidi scopes and virtualized technical cells remain separate QA items.

## User test and continuation

Pull `v1.5.0.0-PMM-translated`, launch PMM from that checkout, select `繁體中文`, apply/save the language and restart PMM. Review the main screens, Mods & Merge, Fix Lab, AI/help, Mod Creation, Settings, installations, saves, dialogs, long tooltips and the language selector.

German runtime/visual QA remains pending because no explicit German confirmation was supplied before this publication. Traditional Chinese runtime/visual QA and native-speaker review are pending. Address any feedback by exact canonical key rather than retranslating the catalog. Next translation: **Japanese (`ja`, 日本語)**.
