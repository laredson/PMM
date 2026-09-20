# PMM — final four approved locales, prepared locally

Status: **catalogs complete; publication and runtime/native-speaker QA pending**.
Repository: `laredson/PMM`.
Target branch: `v1.5.0.0-PMM-translated`.
Verified source checkpoint: `020cd93667e2dd99ce7259cea1d3efe2922dc32c`.
Canonical English blob: `2fa3c4712619cc5f811ce2251cef3daf5b0e2024`.
Source registry blob: `49dc572386b41668265167260d439ebce1a8236a`.

## Catalogs

| Locale | Native name | Entries | Parameterized | Exact catalog Git blob |
|---|---|---:|---:|---|
| `vi` | Tiếng Việt | 1,291 | 109 | `61842d56dda59cda1c58458ac2beaba0c5a61ad1` |
| `uk` | Українська | 1,291 | 109 | `f97a08e9403ecf7e735907cfc2cbf86cc3c5cf02` |
| `cs` | Čeština | 1,291 | 109 | `58904313e49589339a8958fd7ecf82bc0a177fa4` |
| `ga` | Gaeilge | 1,291 | 109 | `0ce141cf8e1725c7df0112c35db86890c25649f6` |

Ukrainian, Czech and Irish were translated in this iteration against canonical English.
Vietnamese is preserved **byte-for-byte** from the preceding delivered catalog:
SHA-256 `8e39f52f1da202f3a8d9d13cbaba36c46fcaf2aa0e549654fe88611329d781a8`.
It was not retranslated.

The three new catalogs contain **3,873 entries**. The cumulative four-locale package
contains **5,164 entries**, including **436 parameterized entries**.
The supplied offline structural validator passed all four catalogs without errors.
Invariant counts are: vi 23, uk 22, cs 24, ga 23. These are explicitly reviewed
product/technical names, native labels and borrowed terms (Czech Hash/Mod, Irish Mod);
they are not untranslated English sentences.

## Registry and scope

The proposed registry changes only `enabled` and `status` for `vi`, `uk`, `cs`, `ga`.
There are still **30 registered locales**, with **23 enabled after applying this batch**
(previously 19). English stays first and is still the default/fallback.
All native labels, registry order and existing locale metadata are preserved.
This cumulative patch includes Vietnamese: **do not also apply the earlier Vietnamese patch**.

Visual code order remains:
`en -> es -> fr -> it -> pt-BR -> ro -> de -> pl -> nl -> ga -> cs -> uk -> ru -> ja -> zh-CN -> zh-TW -> ko -> hi -> bn -> ur -> mr -> te -> th -> id -> vi -> tr -> ar -> arz -> pcm -> ha`.

No runtime code, executable, workflow, main branch, release or tag is part of this patch.
The other 19 enabled catalogs are not changed.
The historical translation-plan/workbench documents are not rewritten by this local package;
this checkpoint records completion of the remaining approved `vi -> uk -> cs -> ga` queue.

## New-locale terminology

| English | Ukrainian | Czech | Irish |
|---|---|---|---|
| Analyze | Аналізувати | Analyzovat | Anailísigh |
| Build | Зібрати | Sestavit | Tóg |
| Deploy | Розгорнути | Nasadit | Imscar |
| Undeploy | Скасувати розгортання | Zrušit nasazení | Aistarraing ón gcluiche |
| Case | Кейс | Případ | Cás |
| Merge | Об'єднання | Sloučení | Cumasc |
| Repair | Виправити | Opravit | Deisigh |
| Game Reference | Еталонні дані гри | Referenční data hry | Tagairt an Chluiche |
| Shared assets | Спільні ресурси | Sdílené prostředky | Sócmhainní comhroinnte |
| Compatibility patch | Патч сумісності | Záplata kompatibility | Paiste comhoiriúnachta |
| Mappings | Зіставлення | Mapování | Mapálacha |
| Handoff | Пакет передавання | Balíček pro předání | Pacáiste aistrithe |
| Settings | Налаштування | Nastavení | Socruithe |

## Review and publication

Catalog completeness and structural checks do not imply Windows/WPF acceptance or
native-speaker review. No PMM/WPF or Windows PowerShell 5.1 execution took place.
Known separate concerns such as runtime-generated English, virtualized cells and Arabic
bidi behavior are not addressed by these catalog-only changes.

Before publishing, re-read the target branch and compare it with the source checkpoint.
If the branch moved, inspect conflicts instead of replacing newer content.
Publish the cumulative patch as one normal development commit with `[skip ci]`;
do not force-push, dispatch workflows, create releases/tags/PRs or update main.

After publication, choose each native language in PMM, apply it and restart.
Review primary screens, long descriptions, dialogs, tooltips, technical paths and fonts.
The remaining approved locale queue is complete at catalog level; runtime and linguistic
feedback should be fixed by exact canonical key rather than by retranslating entire catalogs.
