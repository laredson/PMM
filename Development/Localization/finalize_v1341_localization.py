from __future__ import annotations

from pathlib import Path
import html
import json
import re

ROOT = Path(__file__).resolve().parents[2]
PMM = ROOT / "PMM"
LOC = PMM / "Resources" / "Localization"
UI = PMM / "Resources" / "UI"
MODULES = PMM / "Modules"
DEV = ROOT / "Development" / "Localization"


def read(path: Path) -> str:
    return path.read_text(encoding="utf-8-sig")


def write(path: Path, text: str, bom: bool = False) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8-sig" if bom else "utf-8")


def load_json(path: Path):
    return json.loads(path.read_text(encoding="utf-8-sig"))


def save_json(path: Path, obj) -> None:
    path.write_text(json.dumps(obj, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def fix_language_runtime() -> None:
    # Real root cause found by the Windows smoke test: unary '-' was used where
    # PowerShell '-not' was intended. A non-empty zh-CN code therefore skipped
    # resolution and fell back to English.
    for path in (MODULES / "Shared" / "Localization.ps1", DEV / "build_localization.py"):
        text = read(path)
        text = text.replace(
            "if(-[string]::IsNullOrWhiteSpace($Code)){",
            "if(-not [string]::IsNullOrWhiteSpace($Code)){",
        )
        text = text.replace(
            "if(-[string]::IsNullOrWhiteSpace($requested)){",
            "if(-not [string]::IsNullOrWhiteSpace($requested)){",
        )
        write(path, text, bom=path.suffix.lower() == ".ps1")

    runtime_path = MODULES / "Shared" / "Localization.ps1"
    runtime = read(runtime_path)

    item_snippet = """    if($Root -is [Windows.Controls.ItemsControl] -and $Root.ItemsSource){foreach($item in @($Root.ItemsSource)){try{if($item -and ($item.PSObject.Properties.Name -contains 'Label') -and $item.Label -is [string]){$item.Label=Get-PMMLocalizedText ([string]$item.Label) $code}}catch{}}}\n"""
    grid_anchor = "    if($Root -is [Windows.Controls.DataGrid]){foreach($column in @($Root.Columns)){if($column.Header -is [string]){$column.Header=Get-PMMLocalizedText ([string]$column.Header) $code}}}\n"
    if item_snippet.strip() not in runtime:
        if grid_anchor not in runtime:
            raise RuntimeError("Localization ItemsControl anchor missing")
        runtime = runtime.replace(grid_anchor, item_snippet + grid_anchor, 1)

    live_helper = r'''
$Script:PMMLiveLocalizationHandler=$null
function Register-PMMLiveLocalization($Root,[string]$LanguageCode=''){
  if(-not$Root){return}
  $code=if($LanguageCode){Resolve-PMMLanguageCode $LanguageCode}else{Get-PMMCurrentLanguage}
  if($code -eq 'en'){return}
  Invoke-PMMLocalizeVisualTree $Root $code
  Set-PMMLanguageDirection $Root $code
  try{
    $handler=[Windows.RoutedEventHandler]{
      param($sender,$eventArgs)
      try{
        $target=$eventArgs.OriginalSource
        if($target -is [Windows.DependencyObject]){Invoke-PMMLocalizeVisualTree $target $code}
      }catch{}
    }.GetNewClosure()
    $Root.AddHandler([Windows.FrameworkElement]::LoadedEvent,$handler,$true)
    $Script:PMMLiveLocalizationHandler=$handler
  }catch{}
}
'''
    if "function Register-PMMLiveLocalization" not in runtime:
        runtime = runtime.rstrip() + "\n" + live_helper.lstrip()
    write(runtime_path, runtime, bom=True)

    # Keep the generator authoritative: regenerating localization later must not
    # restore an older runtime without dynamic ItemsSource/live UI support.
    builder_path = DEV / "build_localization.py"
    builder = read(builder_path)
    if item_snippet.strip() not in builder:
        if grid_anchor not in builder:
            raise RuntimeError("Builder ItemsControl anchor missing")
        builder = builder.replace(grid_anchor, item_snippet + grid_anchor, 1)
    builder_hook = '    (MODULES / "Shared" / "Localization.ps1").write_text(runtime, encoding="utf-8-sig")'
    if "function Register-PMMLiveLocalization" not in builder:
        if builder_hook not in builder:
            raise RuntimeError("Builder runtime write anchor missing")
        builder = builder.replace(
            builder_hook,
            "    runtime += " + repr(live_helper) + "\n" + builder_hook,
            1,
        )
    write(builder_path, builder)

    start_path = MODULES / "Bootstrap" / "Start-PalModMerger.ps1"
    start = read(start_path)
    anchor = "Initialize-PMMCaseAgentUI\n$uiExitState='Normal'"
    replacement = "Initialize-PMMCaseAgentUI\nRegister-PMMLiveLocalization $Window $lang\n$uiExitState='Normal'"
    if replacement not in start:
        if anchor not in start:
            raise RuntimeError("Final localization registration anchor missing")
        start = start.replace(anchor, replacement, 1)
    write(start_path, start, bom=True)

    dep_path = MODULES / "Unreal" / "Dependencies.UI.ps1"
    dep = read(dep_path)
    old = "$names=@(Get-PMMDependencyDefinitions|Where-Object{($Job.component -eq 'all' -and $_.id -ne 'chatgpt') -or $_.id -eq $Job.component}|ForEach-Object{$_.name+' '+$_.version})"
    new = "$names=@(Get-PMMDependencyDefinitions|Where-Object{($Job.component -eq 'all' -and $_.id -ne 'chatgpt') -or $_.id -eq $Job.component}|ForEach-Object{(Get-PMMLocalizedText ([string]$_.name))+' '+(Get-PMMLocalizedText ([string]$_.version))})"
    if new not in dep:
        if old not in dep:
            raise RuntimeError("Dependency consent names anchor missing")
        dep = dep.replace(old, new, 1)
    old = "$Script:PMMDependencySelectedJob=$job.id;$Script:PMMDependencyStatus.Text=$job.status}catch{Handle-UIError $_ 'Dependencies'}"
    new = "$Script:PMMDependencySelectedJob=$job.id;$Script:PMMDependencyStatus.Text=Get-PMMLocalizedText ([string]$job.status)}catch{Handle-UIError $_ 'Dependencies'}"
    if new not in dep:
        if old not in dep:
            raise RuntimeError("Dependency immediate status anchor missing")
        dep = dep.replace(old, new, 1)
    write(dep_path, dep, bom=True)


def reviewed_chinese() -> dict[str, str]:
    # Human-reviewed high-visibility vocabulary. The complete catalog contains
    # every audited UI string; this set guarantees polished terminology in the
    # main navigation and the exact dynamic areas reported by the user.
    return {
        "+ New case": "+ 新建案例",
        "Projects": "项目",
        "Send to ChatGPT": "发送到 ChatGPT",
        "Options": "选项",
        "Candidates": "候选",
        "Cases": "案例",
        "Newest first": "最新优先",
        "Case": "案例",
        "Last step": "上一步骤",
        "Next step": "下一步骤",
        "Delete case": "删除案例",
        "No case selected": "未选择案例",
        "Receive file...": "接收文件...",
        "Create handoff": "创建交接包",
        "Save": "保存",
        "AI client": "AI 客户端",
        "Advanced: other MCP client": "高级：其他 MCP 客户端",
        "Advanced: internal agent": "高级：内部代理",
        "Mode": "模式",
        "Question": "问题",
        "Detect modes": "检测模式",
        "Last Step": "上一步",
        "Current": "当前",
        "Select a case": "选择案例",
        "Select or create a case": "选择或创建案例",
        "Title": "标题",
        "Type": "类型",
        "Description / goal": "描述 / 目标",
        "AI response": "AI 响应",
        "References and evidence": "参考与证据",
        "Kind": "类型",
        "Source": "来源",
        "Selection": "选择",
        "Folders": "文件夹",
        "Research cases": "研究案例",
        "Workflow": "工作流",
        "AI assistant": "AI 助手",
        "Mod Creation": "模组创建",
        "Help": "帮助",
        "General": "常规",
        "AI / MCP": "AI / MCP",
        "Installations": "安装",
        "Mods & Merge": "模组与合并",
        "Feedback & Knowledge": "反馈与知识",
        "Color scheme editor": "配色方案编辑器",
        "Refresh": "刷新",
        "Cancel": "取消",
        "CANCEL": "取消",
        "Close": "关闭",
        "Optional tools and AI clients": "可选工具与 AI 客户端",
        "Ask before each installation": "每次安装前询问",
        "Change permissions": "更改权限",
        "Installation tutorial": "安装教程",
        "Installations and status": "安装与状态",
        "Open": "打开",
        "Locate...": "定位...",
        "Detected": "已检测",
        "Not detected": "未检测",
        "Install / complete": "安装 / 完成",
        "Detect installed tools": "检测已安装工具",
        "Install missing components": "安装缺失组件",
        "Cancel pending installations": "取消待处理安装",
        "Install modding tools": "安装模组制作工具",
        "Install everything needed without asking again": "安装所需全部组件，不再询问",
        "Accept": "接受",
        "Dependencies": "依赖项",
        "Unreal requires version 5.1.1 for the supported Palworld kit. PMM opens Epic Launcher; in Unreal Engine > Library, add/select 5.1.1 manually, then Install. The launcher may suggest a newer version. Quixel Bridge is optional and is not required by PMM.": "受支持的 Palworld 工具包需要 Unreal 5.1.1。PMM 会打开 Epic Launcher；请在 Unreal Engine > Library 中手动添加或选择 5.1.1，然后安装。启动器可能会推荐更新版本。Quixel Bridge 为可选组件，PMM 不需要它。",
        "Wwise 2021.1.11: PMM detects the installed SDK and offline downloads separately. Downloading an offline package does not install the SDK. Use Install / complete to open the official installer, or Locate to select an existing folder or executable. The Unreal integration is a separate package.": "Wwise 2021.1.11：PMM 会分别检测已安装的 SDK 和离线下载包。下载离线包并不等于安装 SDK。使用“安装 / 完成”打开官方安装程序，或使用“定位”选择现有文件夹或可执行文件。Unreal 集成是独立的软件包。",
        "Open Wwise offline folder": "打开 Wwise 离线文件夹",
        "Wwise Unreal integration: in Audiokinetic Launcher, open Unreal Engine > Download > Offline integration files, choose 2021.1.11 and save in the integration folder below. PMM detects Unreal.5.0.tar.xz automatically; Locate also accepts a download saved elsewhere.": "Wwise Unreal 集成：在 Audiokinetic Launcher 中打开 Unreal Engine > Download > Offline integration files，选择 2021.1.11，并保存到下方的集成文件夹。PMM 会自动检测 Unreal.5.0.tar.xz；“定位”也可选择保存在其他位置的下载文件。",
        "Open integration download folder": "打开集成下载文件夹",
        "ChatGPT Desktop (optional AI client)": "ChatGPT Desktop（可选 AI 客户端）",
        "Offline package ready; SDK not installed": "离线包已就绪；SDK 尚未安装",
        "Offline package rejected; inspect location": "离线包无效；请检查位置",
        ".NET runtime missing": "缺少 .NET 运行时",
        "AI assistance / reception": "AI 协助 / 接收",
        "A repairable legacy mod was detected. Open Fix Lab.": "检测到可修复的旧版模组。请打开 Fix Lab。",
        "A supported legacy mod was detected. Open Fix Lab to load its repair recipe.": "检测到受支持的旧版模组。请打开 Fix Lab 加载修复配方。",
        "AUTO workflow": "AUTO 工作流",
        "Automatic detection is recommended. Manual Steam and Palworld selectors are available here for unusual installations.": "建议使用自动检测。对于特殊安装位置，可在此手动选择 Steam 或 Palworld 文件夹。",
        "Automatic workflow complete. Palworld launch is optional.": "自动工作流已完成。是否启动 Palworld 由你决定。",
        "QUEUED": "排队中",
        "RUNNING": "运行中",
        "WAITING_EXTERNAL": "等待外部操作",
        "AWAITING_CONSENT": "等待确认",
        "COMPLETE": "已完成",
        "FAILED": "失败",
        "CANCELLED": "已取消",
    }


def update_catalogs() -> None:
    curated = reviewed_chinese()
    zh_path = LOC / "zh-CN.json"
    zh_doc = load_json(zh_path)
    zh_doc["strings"].update(curated)
    zh_doc["strings"] = dict(sorted(zh_doc["strings"].items(), key=lambda kv: kv[0].lower()))
    save_json(zh_path, zh_doc)

    for code in ("en", "es"):
        path = LOC / f"{code}.json"
        doc = load_json(path)
        for key in curated:
            doc["strings"].setdefault(key, key)
        doc["strings"] = dict(sorted(doc["strings"].items(), key=lambda kv: kv[0].lower()))
        save_json(path, doc)

    save_json(UI / "strings.zh-CN.json", zh_doc["strings"])

    # Rebuild the dedicated static Chinese XAML from the canonical English XAML
    # and the same catalog used by dynamic controls. This prevents drift.
    source = (UI / "MainWindow.en.xaml").read_text(encoding="utf-8-sig")
    attr = re.compile(r'(?P<prefix>\b(?:Text|Content|Header|ToolTip)=")(?P<value>[^"]*)(?P<suffix>")')

    def repl(match: re.Match[str]) -> str:
        raw = html.unescape(match.group("value"))
        value = zh_doc["strings"].get(raw, raw)
        return match.group("prefix") + html.escape(value, quote=True) + match.group("suffix")

    (UI / "MainWindow.zh-CN.xaml").write_text(attr.sub(repl, source), encoding="utf-8-sig")

    # Persist reviewed values in the localization builder too.
    builder_path = DEV / "build_localization.py"
    builder = read(builder_path)
    marker = "    zh.update(curated)"
    if "PMM_V1341_CURATED_ZH" not in builder:
        extra = (
            "    # PMM_V1341_CURATED_ZH: reviewed high-visibility strings.\n"
            "    curated.update(" + repr(curated) + ")\n"
        )
        if marker not in builder:
            raise RuntimeError("Curated builder anchor missing")
        builder = builder.replace(marker, extra + marker, 1)
    write(builder_path, builder)


def strengthen_audit_and_docs() -> None:
    audit_path = DEV / "audit_localization.py"
    audit = read(audit_path)
    if '"Register-PMMLiveLocalization",' not in audit:
        audit = audit.replace(
            '        "Set-PMMLanguageDirection",\n',
            '        "Set-PMMLanguageDirection",\n        "Register-PMMLiveLocalization",\n',
            1,
        )
    if "live localization registration missing" not in audit:
        needle = '    if "Convert-PMMXamlLocalization $x" not in case_workspace:\n        wiring_errors.append("embedded case XAML localization missing")\n'
        replacement = needle + '    start = (MODULES / "Bootstrap" / "Start-PalModMerger.ps1").read_text(encoding="utf-8-sig")\n    if "Register-PMMLiveLocalization $Window $lang" not in start:\n        wiring_errors.append("live localization registration missing")\n'
        if needle not in audit:
            raise RuntimeError("Audit wiring anchor missing")
        audit = audit.replace(needle, replacement, 1)
    write(audit_path, audit)

    readme = """# PMM localization

PMM uses a catalog-driven localization layer. English is the canonical source; every visible UI string is inventoried and every language is a data file. Application code must not add language-specific branches.

## Files

- `languages.json`: registry (`code`, native/English names, fallback, `ltr`/`rtl`, optional XAML file).
- `en.json`: canonical English keys/source text.
- `<BCP-47>.json`: one catalog per language, using the same English keys.
- `MainWindow.en.xaml`: canonical static WPF layout. A locale may provide `MainWindow.<code>.xaml`; otherwise PMM translates the English XAML from the catalog at runtime.
- `Modules/Shared/Localization.ps1`: generic lookup, fallback, XAML translation, visual-tree translation and live translation for dynamically created controls.
- `Development/Localization/audit_localization.py`: discovers visible strings in XAML and PowerShell and fails when catalogs/wiring drift.
- `Development/Localization/Test-Localization.ps1`: validates key completeness, placeholders, residue and critical strings.

## Add any language

1. Run `Development/Localization/New-Language.ps1 -Code de -NativeName Deutsch -EnglishName German` (use any BCP-47 code such as `ja`, `pt-BR`, `ar`, `zh-TW`).
2. Translate every empty value in `PMM/Resources/Localization/<code>.json`; never change the English keys.
3. Add/register the language in `languages.json` (the scaffold prints the exact entry). Set `direction` to `rtl` for Arabic/Hebrew-style layouts.
4. Run `Development/Localization/Test-Localization.ps1 -Language <code>` and `python Development/Localization/audit_localization.py`.
5. If a new UI label is added in PowerShell, use `L 'English' 'Spanish'` or `Get-PMMLocalizedText 'English'`. Embedded/static XAML may remain canonical English: the runtime/catalog layer translates it. Controls created dynamically are covered by `Register-PMMLiveLocalization`, but new strings still must be present in the catalog and audit.

Product names, file formats, paths, IDs, hashes and placeholders such as `{0}` are kept invariant unless grammar requires surrounding translation. The audit treats a small documented set of those values as intentionally language-neutral.
"""
    write(LOC / "README.md", readme)

    scaffold = r'''param(
  [Parameter(Mandatory=$true)][string]$Code,
  [Parameter(Mandatory=$true)][string]$NativeName,
  [Parameter(Mandatory=$true)][string]$EnglishName,
  [ValidateSet('ltr','rtl')][string]$Direction='ltr',
  [string]$Fallback='en'
)
$ErrorActionPreference='Stop'
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$loc=Join-Path $root 'PMM\Resources\Localization'
$target=Join-Path $loc ($Code+'.json')
if(Test-Path -LiteralPath $target){throw "Language catalog already exists: $target"}
$en=Get-Content (Join-Path $loc 'en.json') -Raw -Encoding UTF8|ConvertFrom-Json -AsHashtable
$strings=[ordered]@{}
foreach($key in @($en['strings'].Keys|Sort-Object)){$strings[[string]$key]=''}
$doc=[ordered]@{schema='PMM_LANGUAGE_V1';language=$Code;nativeName=$NativeName;fallback=$Fallback;strings=$strings}
$doc|ConvertTo-Json -Depth 20|Set-Content -LiteralPath $target -Encoding UTF8
Write-Host "Created $target with $($strings.Count) source strings."
Write-Host 'Add this object to languages.json:'
[ordered]@{code=$Code;nativeName=$NativeName;englishName=$EnglishName;fallback=$Fallback;direction=$Direction;xaml=$null}|ConvertTo-Json -Depth 5|Write-Host
Write-Host "Then translate all values and run: Development/Localization/Test-Localization.ps1 -Language $Code"
'''
    write(DEV / "New-Language.ps1", scaffold, bom=True)


def main() -> None:
    fix_language_runtime()
    update_catalogs()
    strengthen_audit_and_docs()
    print("Localization finalizer applied successfully.")


if __name__ == "__main__":
    main()
