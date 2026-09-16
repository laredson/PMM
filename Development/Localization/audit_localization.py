from __future__ import annotations

from pathlib import Path
import html
import json
import re
import sys

ROOT = Path(__file__).resolve().parents[2]
PMM = ROOT / "PMM"
LOC = PMM / "Resources" / "Localization"
MODULES = PMM / "Modules"
UI = PMM / "Resources" / "UI"


def load_catalog(code: str) -> dict[str, str]:
    doc = json.loads((LOC / f"{code}.json").read_text(encoding="utf-8-sig"))
    return {str(k): str(v) for k, v in doc["strings"].items()}


def add(found: dict[str, list[dict]], text: str, path: Path, line: int, kind: str):
    value = html.unescape(text).strip()
    if not value or value.startswith("{") or value in {"*", "-"}:
        return
    found.setdefault(value, []).append(
        {"path": str(path.relative_to(ROOT)), "line": line, "kind": kind}
    )


def discover_ui_strings() -> dict[str, list[dict]]:
    found: dict[str, list[dict]] = {}
    pair_patterns = [
        re.compile(r"\bL\s+'((?:''|[^'])*)'\s+'((?:''|[^'])*)'"),
        re.compile(r"\bGet-PMMText\s+'((?:''|[^'])*)'\s+'((?:''|[^'])*)'"),
    ]
    attr = re.compile(r'\b(Text|Content|Header|ToolTip)="([^"]+)"')
    direct = re.compile(
        r"\.(Text|Content|Header|ToolTip)\s*=\s*['\"]([^'\"]{2,})['\"]"
    )
    label_patterns = [
        re.compile(r"\b(?:Label|Display|Header)\s*=\s*'([^']{2,})'"),
        re.compile(r"@\('(?:General|AI|Installs|Mods|ModCreation|Help)'\s*,\s*'([^']{2,})'\)"),
    ]

    for path in MODULES.rglob("*.ps1"):
        text = path.read_text(encoding="utf-8-sig", errors="ignore")
        for line_no, line in enumerate(text.splitlines(), 1):
            for pattern in pair_patterns:
                for match in pattern.finditer(line):
                    add(found, match.group(1).replace("''", "'"), path, line_no, "localized-pair")
            if "<" in line and ">" in line:
                for match in attr.finditer(line):
                    add(found, match.group(2), path, line_no, "embedded-xaml")
            if "(L " not in line and "Get-PMMText" not in line and "Get-PMMLocalizedText" not in line:
                for match in direct.finditer(line):
                    add(found, match.group(2), path, line_no, "direct-wpf")
            for pattern in label_patterns:
                for match in pattern.finditer(line):
                    add(found, match.group(1), path, line_no, "ui-label")

    main = UI / "MainWindow.en.xaml"
    text = main.read_text(encoding="utf-8-sig")
    for line_no, line in enumerate(text.splitlines(), 1):
        for match in attr.finditer(line):
            add(found, match.group(2), main, line_no, "xaml")
    return found


# Invariant product names, acronyms and technical labels are intentionally not translated.
TECHNICAL_EXACT = {
    "AUTO",
    "AIIO",
    "CKL",
    "MCP",
    "PAK",
    "PMM",
    "SHA-256",
    "ZIP",
    "JSON",
    "MB",
    "OK",
    "ChatGPT",
    "Codex",
    "Palworld",
    "Steam",
    "Unreal",
    "Wwise",
    "Windows",
    "Visual Studio",
    "Visual Studio 2022 + MSVC",
    "Epic Launcher",
    "Unreal Engine / Epic Launcher",
    "Game Reference",
    "Fix Lab",
}
TECHNICAL_FRAGMENTS = (
    "http://",
    "https://",
    "\\",
    ".pak",
    ".zip",
    ".json",
    ".usmap",
    ".exe",
    "SHA-",
    "Workspace/",
    "Workspace\\",
)


def looks_ui(text: str) -> bool:
    if text in TECHNICAL_EXACT:
        return False
    if text.startswith("PMM_") or text.startswith("{"):
        return False
    if any(fragment in text for fragment in TECHNICAL_FRAGMENTS):
        # File filters can still be visible UI and are catalogued separately.
        if "All files" not in text:
            return False
    if re.fullmatch(r"[A-Za-z0-9_.:/+\\-]+", text) and any(
        char in text for char in "._:/\\"
    ):
        return False
    return any(char.isalpha() for char in text)


def clearly_untranslated_prose(key: str, value: str) -> bool:
    if key != value:
        return False
    if key in TECHNICAL_EXACT or any(fragment in key for fragment in TECHNICAL_FRAGMENTS):
        return False
    if len(key) < 18 or key.count(" ") < 2:
        return False
    if key.upper() == key:
        return False
    technical_words = {
        "ChatGPT",
        "Codex",
        "Palworld",
        "Unreal",
        "Wwise",
        "Steam",
        "PMM",
        "MCP",
        "AIIO",
        "CKL",
        "PAK",
        "ZIP",
    }
    words = re.findall(r"[A-Za-z]+", key)
    natural = [word for word in words if word not in technical_words]
    return len(natural) >= 3


def main() -> int:
    en = load_catalog("en")
    zh = load_catalog("zh-CN")
    found = discover_ui_strings()
    relevant = {key: refs for key, refs in found.items() if looks_ui(key)}

    missing_en = sorted(key for key in relevant if key not in en)
    missing_zh = sorted(key for key in relevant if key not in zh or not zh[key].strip())
    residue = sorted(
        key
        for key, value in zh.items()
        if re.search(r"PMMTERM|PMMTOKEN|__PMM|\bTERM\d+\b", value)
    )
    placeholders = []
    token = re.compile(r"\{[^{}]+\}")
    for key, value in zh.items():
        if sorted(token.findall(key)) != sorted(token.findall(value)):
            placeholders.append(key)

    critical = {
        "+ New case": "+ 新建案例",
        "Projects": "项目",
        "Send to ChatGPT": "发送到 ChatGPT",
        "Options": "选项",
        "Candidates": "候选",
        "Cases": "案例",
        "Newest first": "最新优先",
        "Last step": "上一步骤",
        "Next step": "下一步骤",
        "Delete case": "删除案例",
        "Receive file...": "接收文件...",
        "Create handoff": "创建交接包",
        "Select or create a case": "选择或创建案例",
        "References and evidence": "参考与证据",
        "Mod Creation": "模组创建",
        "Help": "帮助",
        "Research cases": "研究案例",
        "Workflow": "工作流",
        "AI assistant": "AI 助手",
        "Optional tools and AI clients": "可选工具与 AI 客户端",
        "Ask before each installation": "每次安装前询问",
        "Change permissions": "更改权限",
        "Installation tutorial": "安装教程",
        "Installations and status": "安装与状态",
    }
    critical_bad = {
        key: {"expected": expected, "actual": zh.get(key)}
        for key, expected in critical.items()
        if zh.get(key) != expected
    }
    untranslated_prose = sorted(
        key for key, value in zh.items() if clearly_untranslated_prose(key, value)
    )

    runtime = (MODULES / "Shared" / "Localization.ps1").read_text(
        encoding="utf-8-sig"
    )
    workspaces = (MODULES / "AIIO" / "AIIO.Workspaces.UI.ps1").read_text(
        encoding="utf-8-sig"
    )
    case_workspace = (MODULES / "AIIO" / "AIIO.CaseWorkspace.UI.ps1").read_text(
        encoding="utf-8-sig"
    )
    wiring_errors = []
    for required in (
        "Get-PMMLocalizedText",
        "Convert-PMMXamlLocalization",
        "Invoke-PMMLocalizeVisualTree",
        "Set-PMMLanguageDirection",
    ):
        if required not in runtime:
            wiring_errors.append(f"Localization.ps1 missing {required}")
    if "Invoke-PMMLocalizeVisualTree $Window" not in workspaces:
        wiring_errors.append("dynamic workspace localization sweep missing")
    if "Convert-PMMXamlLocalization $x" not in case_workspace:
        wiring_errors.append("embedded case XAML localization missing")
    start = (MODULES / "Bootstrap" / "Start-PalModMerger.ps1").read_text(encoding="utf-8-sig")
    if "Invoke-PMMLocalizeVisualTree $Window $lang;Set-PMMLanguageDirection $Window $lang" not in start:
        wiring_errors.append("safe startup localization sweep missing")
    if "Register-PMMLiveLocalization" in start:
        wiring_errors.append("unsafe live localization hook present")

    report = {
        "schema": "PMM_LOCALIZATION_AUDIT_V1",
        "discoveredUiStrings": len(found),
        "relevantUiStrings": len(relevant),
        "englishCatalogStrings": len(en),
        "chineseCatalogStrings": len(zh),
        "missingEnglish": missing_en,
        "missingChinese": missing_zh,
        "placeholderErrors": sorted(placeholders),
        "translationResidue": residue,
        "criticalTranslationErrors": critical_bad,
        "clearlyUntranslatedProse": untranslated_prose,
        "wiringErrors": wiring_errors,
    }
    output = ROOT / "Development" / "Localization" / "LAST_AUDIT.json"
    output.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({key: report[key] for key in (
        "discoveredUiStrings",
        "relevantUiStrings",
        "englishCatalogStrings",
        "chineseCatalogStrings",
    )}, ensure_ascii=False))

    failures = (
        missing_en
        or missing_zh
        or placeholders
        or residue
        or critical_bad
        or untranslated_prose
        or wiring_errors
    )
    if failures:
        print(json.dumps(report, ensure_ascii=False, indent=2), file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
