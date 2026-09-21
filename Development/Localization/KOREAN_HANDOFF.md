## Korean localization completed and published — 2026-09-18

한국어 now covers all 1,291 canonical English keys on `v1.5.0.0-PMM-translated` and is enabled for user testing.
Part 1 (645 entries) was preserved; part 2 added the remaining 646 entries.
Validation was deliberately bounded to one structural pass: JSON/key parity, non-empty values and placeholder preservation. No GitHub Actions, full repository audit or WPF visual/runtime test was run for this checkpoint.
Language switching remains restart-based. Portuguese remains user-validated; Arabic RTL behavior and its separately tracked UI exceptions are unchanged.
Next step: user runtime/visual QA of Korean. Do not retranslate Korean from scratch unless QA reports a specific issue.

# Korean localization: self-contained continuation handoff

Updated: 2026-09-18. Repository: `laredson/PMM`. Work ONLY on `v1.5.0.0-PMM-translated`.

## Start here in this or another chat

PMM is Palworld Manager Merger, a Windows application with editable PowerShell/WPF/XAML UI and independent JSON language catalogs. This branch prepares v1.5.0.0. The user approved translation work on this branch and now asks for one language in two bounded interventions instead of very long attempts. The active task is **Korean part 2**, not another language or a rewrite of part 1.

Read `Development/AI/WORKBENCH_STATE.md`, `Development/Localization/TRANSLATION_PLAN.md`, this file, and `Development/Localization/Progress/ko.json` before editing. Fetch the branch's actual HEAD first; never assume that a previous chat's last message is the current state.

## Verified checkpoint

- Starting commit: `ef68aeef85b5160948030a0eb358b932ed68a82f`.
- Canonical file: `PMM/Resources/Localization/en.json`; source blob `2fa3c4712619cc5f811ce2251cef3daf5b0e2024`; baseline has 1,291 entries.
- Part 1 is stored in the real runtime catalog `PMM/Resources/Localization/ko.json`, not a temporary draft: **645 entries**, including 11 deliberately invariant labels/identifiers listed in `Progress/ko.json`.
- It covers source entries 1-645, from `(not detected)` through `Load draft` inclusive (source file lines 7-651 at this pinned revision).
- The next untranslated key is **`Loading Fix Lab module...`**. The remaining baseline block is **646 entries**, ending at `简体中文`.
- Korean catalog blob: `e239428f7eab5b6ff954dbebfb50e3b198308cc9`. SHA-256: `ef8391cf4279e8686a906108818c75b1e7a735762e91d6f88bd102e98737d9a5`.
- `ko` is `translationStatus: in-progress`; registry `status: in-progress`, `enabled: false`, `direction: ltr`, `fallback: en`, `xaml: null`.
- Missing keys are intentionally absent, not empty strings or English copies counted as completed translations. The locale is not ready for the application selector yet.

The source-order cursor is a convenience, not the authority if files change. Compare current `en.strings` with current `ko.strings` case-sensitively, preserve existing translations, and translate only missing entries. Reconcile additions/removals if the source blob changed.

## Terminology and style for part 2

Use natural Korean UI labels and polite instructions. Keep labels concise; explanatory text should preserve warnings, consent, rollback and 'not yet tested' distinctions. Follow the first-half terminology:

| Source term | Korean convention |
|---|---|
| mod / source mod | 모드 / 소스 모드 |
| merge / compatibility patch | 병합 / 호환성 패치 |
| Build | 빌드 |
| Deploy / Undeploy | 게임에 적용 / 적용 해제 |
| Install | 설치 (dependencies/themes, distinct from mod deployment) |
| repair / restore | 복구 / 복원 |
| asset / adapter | 에셋 / 어댑터 |
| recipe / output variant | 레시피 / 결과물 변형 |
| Game Reference / vanilla | 게임 참조 데이터 / 기본 게임 |
| family | 파일군 |
| case / candidate / staged | 케이스 / 후보 / 검토 대기 |
| handoff / Knowledge | 인계 자료 / 지식 |
| color scheme / draft | 색상 구성 / 초안 |
| Refresh / Apply changes | 새로 고침 / 변경 사항 적용 |

Keep PMM, Palworld, Steam, Fix Lab, AIIO, MCP, SDK, Unreal, Wwise, ChatGPT, Codex, product names, protocol identifiers and actual filenames intact. AUTO/SemiAUTO are workflow names. Preserve native language names literally. Do not translate JSON keys. Distinguish UI 'mode' from game 'mod' by context, even though both can be written 모드 in Korean.

Preserve every placeholder occurrence and full specifier (`{0}`, `{0:N1}`, `{0:N2}`), backtick-newline sequences, file-dialog patterns and machine identifiers. Escape embedded quotes through a JSON serializer; previous Portuguese writes broke two quoted strings. Preserve intentional trailing spaces in concatenated fragments. Korean suffixes attached to Latin identifiers are normal; do not use Unicode word boundaries to decide an identifier is missing. English `PAKs` may become `PAK` followed by a Korean particle or counter.

## Part 1 checks actually executed

A local Python process serialized and reparsed the complete 645-entry partial catalog with duplicate-key rejection. It checked nonempty values, all full placeholder multisets (62 parameterized entries), numeric literals, selected technical/unit tokens, trailing spaces and unexpected bidi/replacement characters. No errors remained. The blob SHA returned by GitHub exactly matches the locally validated bytes, so serialization was not changed during upload.

The English source range was read sequentially through GitHub. **No full machine-run repository/source-parity audit, Windows PowerShell 5.1 execution or WPF visual test was performed in part 1.** Do not turn this report into a claim that Korean or the release is fully validated. The locale stays disabled.

## Resuming and validating

Use a strict, case-sensitive JSON parser. A minimal read-only Python check, run from the repository root after obtaining the checkout, is:

```python
import json, re
from collections import Counter
from pathlib import Path

def strict_pairs(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError('Duplicate JSON key: ' + key)
        result[key] = value
    return result

def load(path):
    return json.loads(Path(path).read_text(encoding='utf-8-sig'),
                      object_pairs_hook=strict_pairs)

base = Path('PMM/Resources/Localization')
en = load(base / 'en.json')['strings']
ko = load(base / 'ko.json')['strings']
assert not (set(ko) - set(en)), 'Unexpected Korean keys'
assert all(isinstance(v, str) and v.strip() for v in ko.values())
placeholder = re.compile(r'(?<!\{)\{\d+(?:,-?\d+)?(?::[^{}]+)?\}(?!\})')
for key, value in ko.items():
    assert Counter(placeholder.findall(en[key])) == Counter(placeholder.findall(value)), key
pending = [key for key in en if key not in ko]
print('Completed:', len(ko), 'Remaining:', len(pending))
print('Next:', pending[0] if pending else 'No missing keys')
```

At the part-1 checkpoint this should report 645 completed and 646 remaining. This repository-wide snippet is provided for the next checkout; it was not run against a full checkout here.

For part 2, complete the remaining block and review the whole catalog for terminology, English residue, format placeholders and safety warnings. Run the repository's `Development/Localization/Test-Localization.ps1 -Language ko` and `audit_localization.py` locally where supported, plus the relevant Windows PowerShell 5.1/WPF tests when that environment is available. Do not substitute a GitHub workflow for unavailable local Windows tests. Report any test you could not run. Never weaken a validator merely to get green results.

When the entire current English key set is covered and catalog checks pass, set `ko` to `translationStatus: complete`, registry `enabled: true` / `status: complete`, keep its native label `한국어`, and hand it to the user for runtime/visual QA. Catalog completeness is not release acceptance. Update both tracking documents, this handoff and the progress JSON in the same checkpoint.

## Product state and boundaries to preserve

The user has reported **Português (Brasil) works perfectly**. Record that as user-reported runtime QA, not as a new automated test. Active languages remain English, Español, 简体中文, Português (Brasil), हिन्दी, العربية. Keep the first three in exactly that order. Do not change these catalogs for the Korean task.

Language changes require a PMM restart. Live switching was reverted due to slow startup, slow changes and errors: **do not reintroduce it**. The Arabic layout intentionally remains RTL; existing narrow LTR data exceptions remain unchanged. Open issues are the mixed Arabic/path header, dynamic English counters, virtualized technical cells and the old EN/ES-only selection refresh. These are tracked separately; do not silently expand the Korean translation task into a runtime refactor.

Development pushes are silent: use `[skip ci]`, no Actions, new workflows, release, tag, PR or changes to main. Use a normal fast-forward commit; do not reset history or rename branches. Do not run Palworld or modify installed game mods/saves. Commit only the translation and tracking files. Confirm the remote HEAD after pushing. If interrupted, resume from canonical files and this checkpoint; do not restart the translation or leave marker files.
