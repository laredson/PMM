# PMM Japanese localization — complete; user QA pending

Date: 2026-09-18
Branch: `v1.5.0.0-PMM-translated`
Source checkpoint: `bd4f35a96fb6912843e31568a0ebad2a7b72297e`
Locale: `ja` / `日本語`
Next requested translation: **Italian (`it`, Italiano)**

## State

Japanese now covers **1,291/1,291 canonical English keys** and is enabled for user testing. The Japanese catalog is the exact locally validated payload: Git blob `0523fa7a906e7b7a13e24217c1b5142efb8feff5`, SHA-256 `2444aedd657e925cfde04436b5d02671b67651f490456627ca6f6ec0b4fa252c`, 159,854 bytes. Canonical English remains blob `2fa3c4712619cc5f811ce2251cef3daf5b0e2024`.

Structural checks found zero missing/extra/empty keys, zero placeholder/format mismatches across **109 parameterized entries**, zero remaining-brace, numeric-literal, edge-whitespace, Unicode-control, extension/wildcard or protected-token errors. There are **26 intentional values identical to English**, primarily product names, technical identifiers and native language labels. This does not replace native-speaker or Windows/WPF review.

## Terminology

| Source concept | Japanese |
|---|---|
| Analyze | 分析 |
| Build | ビルド |
| Deploy | デプロイ |
| Undeploy | デプロイ解除 |
| Repair | 修復 |
| Case | ケース |
| Game Reference | ゲーム参照 |
| Shared assets | 共有アセット |
| Compatibility patch | 互換性パッチ |
| Overlay | オーバーレイ |
| Handoff | 引き継ぎ |
| Settings | 設定 |
| Backup / restore | バックアップ / 復元 |

Technical/product terms such as PMM, Palworld, PAK, ZIP, AI, MCP, Nexus, Steam and Fix Lab remain recognizable. `UNPROVEN` is retained alongside Japanese wording. Native language names are never translated by the selector.

## User-defined ordering

Translation execution queue requested by the user:
`日本語 -> Italiano -> Türkçe -> Polski -> Nederlands -> Gaeilge`.

Japanese is completed by this checkpoint, so the next translation is **Italiano**, followed by **Türkçe**, **Polski**, **Nederlands**, and **Gaeilge**.

The product selector order is separate from market evidence. Its leading order is now:
`English -> Español -> Português (Brasil) -> Italiano -> Français -> Deutsch -> Polski -> Nederlands -> 日本語 -> 简体中文 -> 繁體中文 -> 한국어 -> Русский -> Türkçe ...`

Disabled languages keep their reserved position and appear automatically there when completed. Polish and Dutch therefore sit immediately after German once enabled. The two Chinese variants stay together. Irish is standardized as `ga` with native label `Gaeilge`; its disabled template is registered in this checkpoint.

## Limits / test

No PMM/WPF runtime, Windows PowerShell 5.1 or native-speaker acceptance was run here. Pull the branch, choose `日本語`, apply/save the language and restart PMM. Review the principal tabs, long descriptions/tooltips, Fix Lab, AI/help, Settings/installations, World Save and dialogs for truncation or unnatural phrasing.

Existing dynamic English counters, Arabic bidi exceptions, virtualized technical-cell review and the older Library.UI selector path remain separate QA items.
