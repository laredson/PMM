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
INVENTORY = ROOT / "Development" / "Localization" / "MISSING_ZH_CN.json"


def load_json(path: Path):
    return json.loads(path.read_text(encoding="utf-8-sig"))


def save_json(path: Path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def read_ps(path: Path) -> str:
    return path.read_text(encoding="utf-8-sig")


def write_ps(path: Path, text: str):
    path.write_text(text, encoding="utf-8-sig")


def replace_once(text: str, old: str, new: str, label: str) -> str:
    if new in text:
        return text
    if old not in text:
        raise RuntimeError(f"Patch anchor missing: {label}")
    return text.replace(old, new, 1)


def install_translator():
    import argostranslate.package
    import argostranslate.translate

    argostranslate.package.update_package_index()
    packages = argostranslate.package.get_available_packages()
    package = next((p for p in packages if p.from_code == "en" and p.to_code in ("zh", "zh_cn", "zh-CN")), None)
    if package is None:
        raise RuntimeError("No Argos English-to-Chinese package available")
    argostranslate.package.install_from_path(package.download())
    installed = argostranslate.translate.get_installed_languages()
    source = next(x for x in installed if x.code == "en")
    target = next(x for x in installed if x.code == package.to_code)
    return source.get_translation(target)


def repair_and_complete_catalogs():
    zh_path = LOC / "zh-CN.json"
    en_path = LOC / "en.json"
    zh_doc = load_json(zh_path)
    en_doc = load_json(en_path)
    zh = dict(zh_doc["strings"])
    en = dict(en_doc["strings"])
    missing = load_json(INVENTORY)["missing"]

    curated = {
        "PALWORLD": "PALWORLD",
        "MANAGER": "MANAGER",
        "MERGER": "MERGER",
        "AUTO": "AUTO",
        "PMM": "PMM",
        "PMM manual/AI solution (*.zip)|*.zip|All files (*.*)|*.*": "PMM 手动/AI 解决方案 (*.zip)|*.zip|所有文件 (*.*)|*.*",
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
        "Open folder": "打开文件夹",
        "Save": "保存",
        "Transport": "传输方式",
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
        "Mode": "模式",
        "Selection": "选择",
        "Add PAK...": "添加 PAK...",
        "Add mod family...": "添加模组族...",
        "Add Vanilla family...": "添加原版资源族...",
        "Remove": "移除",
        "Requested / pending work": "请求 / 待处理工作",
        "No pending work": "没有待处理工作",
        "History": "历史记录",
        "Newest first. Steps are collapsed by default; jump directly to any point.": "最新优先。步骤默认折叠，可直接跳转到任意节点。",
        "Research cases": "研究案例",
        "Workflow": "工作流",
        "AI assistant": "AI 助手",
        "AI client": "AI 客户端",
        "Advanced: other MCP client": "高级：其他 MCP 客户端",
        "Advanced: internal agent": "高级：内部代理",
        "Mod Creation": "模组创建",
        "Help": "帮助",
        "General": "常规",
        "AI / MCP": "AI / MCP",
        "Installations": "安装",
        "Mods & Merge": "模组与合并",
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
        "Cancel": "取消",
        "PMM proposes installing: ": "PMM 建议安装：",
        "Only the PMM dependency catalog is covered. Official account, license and Windows prompts remain. You can revoke this permission in Settings.": "此权限仅适用于 PMM 依赖项目录。官方账户、许可证和 Windows 提示仍会保留。你可以随时在设置中撤销此权限。",
        "Unreal requires version 5.1.1 for the supported Palworld kit. PMM opens Epic Launcher; in Unreal Engine > Library, add/select 5.1.1 manually, then Install. The launcher may suggest a newer version. Quixel Bridge is optional and is not required by PMM.": "受支持的 Palworld 工具包需要 Unreal 5.1.1。PMM 会打开 Epic Launcher；请在 Unreal Engine > Library 中手动添加或选择 5.1.1，然后安装。启动器可能会推荐更新版本。Quixel Bridge 为可选组件，PMM 不需要它。",
        "Wwise 2021.1.11: PMM detects the installed SDK and offline downloads separately. Downloading an offline package does not install the SDK. Use Install / complete to open the official installer, or Locate to select an existing folder or executable. The Unreal integration is a separate package.": "Wwise 2021.1.11：PMM 会分别检测已安装的 SDK 和离线下载包。下载离线包并不等于安装 SDK。使用“安装 / 完成”打开官方安装程序，或使用“定位”选择现有文件夹或可执行文件。Unreal 集成是独立的软件包。",
        "Open Wwise offline folder": "打开 Wwise 离线文件夹",
        "Wwise Unreal integration: in Audiokinetic Launcher, open Unreal Engine > Download > Offline integration files, choose 2021.1.11 and save in the integration folder below. PMM detects Unreal.5.0.tar.xz automatically; Locate also accepts a download saved elsewhere.": "Wwise Unreal 集成：在 Audiokinetic Launcher 中打开 Unreal Engine > Download > Offline integration files，选择 2021.1.11，并保存到下方的集成文件夹。PMM 会自动检测 Unreal.5.0.tar.xz；“定位”也可选择保存在其他位置的下载文件。",
        "Open integration download folder": "打开集成下载文件夹",
        "ChatGPT Desktop (optional AI client)": "ChatGPT Desktop（可选 AI 客户端）",
        "Unreal Engine / Epic Launcher": "Unreal Engine / Epic Launcher",
        "Visual Studio 2022 + MSVC": "Visual Studio 2022 + MSVC",
        "Windows SDK": "Windows SDK",
        ".NET Runtime x64": ".NET x64 运行时",
        "Wwise SDK": "Wwise SDK",
        "Wwise offline integration": "Wwise 离线集成",
        "Palworld Modding Kit": "Palworld 模组制作工具包",
        "Offline package ready; SDK not installed": "离线包已就绪；SDK 尚未安装",
        "Offline package rejected; inspect location": "离线包无效；请检查位置",
        "This settings workspace is managed by its own tab.": "此设置工作区由其自己的标签页管理。",
        "AI clients": "AI 客户端",
        "Optional. PMM can also work with manual ZIP exchange.": "可选。PMM 也可以通过手动 ZIP 交换工作。",
        "Folders": "文件夹",
        "Question": "问题",
        "Prepare question": "准备问题",
        "Send question": "发送问题",
        "Detect modes": "检测模式",
        "unavailable": "不可用",
        "Project folder: ": "项目文件夹：",
        "Solutions": "解决方案",
        "Evidence": "证据",
        "AI chat history": "AI 聊天历史",
        "Built mods": "已构建模组",
        "[current]": "[当前]",
        "Step {0}": "步骤 {0}",
        "historical Step {0}": "历史步骤 {0}",
        "Detecting installed components": "正在检测已安装组件",
        "Installation requested": "已请求安装",
        "Cancelled; no further installers will start.": "已取消；不会再启动其他安装程序。",
        "Requested components detected; project verification is separate.": "已检测到请求的组件；项目验证将单独进行。",
        "Installation worker stopped. Check any official installer still open before retrying.": "安装进程已停止。重试前请检查是否仍有官方安装程序处于打开状态。",
        "VS 2022 DETECTED; MSVC 14.38 MISSING": "已检测 VS 2022；缺少 MSVC 14.38",
    }
    zh.update(curated)
    for key in curated:
        en.setdefault(key, key)

    marker_re = re.compile(r"PMMTERM|PMMTOKEN|__PMM|\bTERM\d+\b")
    placeholder_re = re.compile(r"\{[^{}]+\}")
    broken = [
        key
        for key in missing
        if key not in curated
        and (
            marker_re.search(zh.get(key, ""))
            or placeholder_re.findall(key) != placeholder_re.findall(zh.get(key, ""))
        )
    ]

    if broken:
        translator = install_translator()
        protected = [
            "Palworld Manager Merger",
            "Game Reference",
            "Palworld Modding Kit",
            "ChatGPT Desktop",
            "Codex Desktop",
            "Visual Studio",
            "Epic Launcher",
            "Windows SDK",
            "Fix Lab",
            "SemiAUTO",
            "ChatGPT",
            "Palworld",
            "Unreal",
            "Wwise",
            "Audiokinetic",
            "Codex",
            "PMM",
            "MCP",
            "AIIO",
            "CKL",
            "PAK",
            "ZIP",
            "JSON",
            "SHA-256",
            ".usmap",
            ".pak",
            ".zip",
            ".7z",
            ".rar",
            "AUTO",
        ]
        protected_alt = "|".join(re.escape(x) for x in sorted(protected, key=len, reverse=True))
        token_re = re.compile(r"(\{[^{}]+\}|" + protected_alt + r")", re.I)

        def safe_translate(text: str) -> str:
            result: list[str] = []
            for piece in token_re.split(text):
                if not piece:
                    continue
                if token_re.fullmatch(piece):
                    result.append(piece)
                elif piece.strip():
                    result.append(translator.translate(piece))
                else:
                    result.append(piece)
            return "".join(result).strip()

        for index, key in enumerate(broken, 1):
            zh[key] = safe_translate(key)
            if index % 50 == 0:
                print(f"repaired {index}/{len(broken)}")

    leftovers = []
    for key, value in zh.items():
        if marker_re.search(value) or placeholder_re.findall(key) != placeholder_re.findall(value):
            leftovers.append(key)
    if leftovers:
        raise RuntimeError(f"Unrepaired translation artifacts/placeholders: {leftovers[:20]}")

    zh_doc["strings"] = dict(sorted(zh.items(), key=lambda kv: kv[0].lower()))
    en_doc["strings"] = dict(sorted(en.items(), key=lambda kv: kv[0].lower()))
    save_json(zh_path, zh_doc)
    save_json(en_path, en_doc)
    save_json(UI / "strings.zh-CN.json", zh_doc["strings"])

    # Build a Spanish catalog from the translations already maintained in source.
    es = {key: key for key in en_doc["strings"]}
    pair = re.compile(r"\b(?:L|Get-PMMText)\s+'((?:''|[^'])*)'\s+'((?:''|[^'])*)'")
    for path in MODULES.rglob("*.ps1"):
        text = path.read_text(encoding="utf-8-sig", errors="ignore")
        for match in pair.finditer(text):
            es[match.group(1).replace("''", "'")] = match.group(2).replace("''", "'")
    es.update(
        {
            "+ New case": "+ Nuevo caso",
            "Cases": "Casos",
            "Newest first": "Más recientes primero",
            "Case": "Caso",
            "Last step": "Último paso",
            "Next step": "Siguiente paso",
            "Delete case": "Eliminar caso",
            "No case selected": "Ningún caso seleccionado",
            "Receive file...": "Recibir archivo...",
            "Create handoff": "Crear entrega",
            "Open folder": "Abrir carpeta",
            "Save": "Guardar",
            "Transport": "Transporte",
            "Last Step": "Paso anterior",
            "Current": "Actual",
            "Select a case": "Selecciona un caso",
            "Select or create a case": "Selecciona o crea un caso",
            "Title": "Título",
            "Type": "Tipo",
            "Description / goal": "Descripción / objetivo",
            "AI response": "Respuesta de IA",
            "References and evidence": "Referencias y evidencia",
            "Kind": "Tipo",
            "Source": "Origen",
            "Mode": "Modo",
            "Selection": "Selección",
            "Add PAK...": "Añadir PAK...",
            "Add mod family...": "Añadir familia del mod...",
            "Add Vanilla family...": "Añadir familia Vanilla...",
            "Remove": "Quitar",
            "Requested / pending work": "Trabajo solicitado / pendiente",
            "No pending work": "No hay trabajo pendiente",
            "History": "Historial",
            "Newest first. Steps are collapsed by default; jump directly to any point.": "Más recientes primero. Los pasos están contraídos por defecto; puedes saltar directamente a cualquier punto.",
            "Help": "Ayuda",
            "AI / MCP": "IA / MCP",
            "Mods & Merge": "Mods y Merge",
            "Mod Creation": "Creación de mods",
            "Installations": "Instalaciones",
        }
    )
    save_json(
        LOC / "es.json",
        {
            "schema": "PMM_LANGUAGE_V1",
            "language": "es",
            "nativeName": "Español",
            "fallback": "en",
            "strings": dict(sorted(es.items(), key=lambda kv: kv[0].lower())),
        },
    )


def write_runtime():
    runtime = r'''$Script:PMMLanguageRegistryCache=$null
$Script:PMMLanguageCatalogCache=@{}
function Get-PMMLocalizationRoot { Join-Path $Script:Root 'Resources\Localization' }
function Get-PMMLanguageRegistry {
  if($Script:PMMLanguageRegistryCache){return $Script:PMMLanguageRegistryCache}
  $path=Join-Path (Get-PMMLocalizationRoot) 'languages.json'
  if(-not(Test-Path -LiteralPath $path -PathType Leaf)){throw 'Localization registry is missing.'}
  $Script:PMMLanguageRegistryCache=Get-Content -LiteralPath $path -Raw -Encoding UTF8|ConvertFrom-Json
  return $Script:PMMLanguageRegistryCache
}
function Get-PMMLanguageDefinition([string]$Code){
  $registry=Get-PMMLanguageRegistry
  return @($registry.languages|Where-Object{[string]$_.code -ieq $Code}|Select-Object -First 1)[0]
}
function Resolve-PMMLanguageCode([string]$Code){
  $registry=Get-PMMLanguageRegistry
  if(-[string]::IsNullOrWhiteSpace($Code)){
    $exact=Get-PMMLanguageDefinition $Code;if($exact){return [string]$exact.code}
    $base=($Code -split '-')[0]
    $match=@($registry.languages|Where-Object{([string]$_.code -split '-')[0] -ieq $base}|Select-Object -First 1)[0]
    if($match){return [string]$match.code}
  }
  return [string]$registry.default
}
function Get-PMMCurrentLanguage {try{return Resolve-PMMLanguageCode ([string](Get-PMMConfig).Language)}catch{return Resolve-PMMLanguageCode ''}}
function Get-PMMLanguageOptions {return @(Get-PMMLanguageRegistry).languages|ForEach-Object{[pscustomobject]@{Label=[string]$_.nativeName;Code=[string]$_.code}}}
function Get-PMMLanguageCatalog([string]$Code){
  $code=Resolve-PMMLanguageCode $Code
  if($Script:PMMLanguageCatalogCache.ContainsKey($code)){return $Script:PMMLanguageCatalogCache[$code]}
  $table=[Collections.Hashtable]::new([StringComparer]::Ordinal);$path=Join-Path (Get-PMMLocalizationRoot) ($code+'.json')
  if(Test-Path -LiteralPath $path -PathType Leaf){$doc=Get-Content -LiteralPath $path -Raw -Encoding UTF8|ConvertFrom-Json -AsHashtable;if($doc.ContainsKey('strings')){foreach($kv in $doc['strings'].GetEnumerator()){$table[[string]$kv.Key]=[string]$kv.Value}}}
  $Script:PMMLanguageCatalogCache[$code]=$table;return $table
}
function Get-PMMLocalizedText([string]$English,[string]$LanguageCode=''){
  if([string]::IsNullOrWhiteSpace($English)){return $English}
  $code=if($LanguageCode){Resolve-PMMLanguageCode $LanguageCode}else{Get-PMMCurrentLanguage};if($code -eq 'en'){return $English}
  $visited=@{}
  while($code -and -not$visited.ContainsKey($code)){$visited[$code]=$true;$catalog=Get-PMMLanguageCatalog $code;if($catalog.ContainsKey($English) -and -not[string]::IsNullOrWhiteSpace([string]$catalog[$English])){return [string]$catalog[$English]};$def=Get-PMMLanguageDefinition $code;$code=if($def){[string]$def.fallback}else{'en'};if($code -eq 'en'){break}}
  return $English
}
function Get-PMMLanguageXamlPath([string]$LanguageCode=''){
  $code=if($LanguageCode){Resolve-PMMLanguageCode $LanguageCode}else{Get-PMMCurrentLanguage};$def=Get-PMMLanguageDefinition $code
  if($def -and $def.xaml){$p=Join-Path $Script:Root ('Resources\UI\'+[string]$def.xaml);if(Test-Path -LiteralPath $p -PathType Leaf){return $p}}
  return (Join-Path $Script:Root 'Resources\UI\MainWindow.en.xaml')
}
function Convert-PMMXamlLocalization([string]$Xaml,[string]$LanguageCode=''){
  if([string]::IsNullOrWhiteSpace($Xaml)){return $Xaml};$code=if($LanguageCode){Resolve-PMMLanguageCode $LanguageCode}else{Get-PMMCurrentLanguage};if($code -eq 'en'){return $Xaml}
  $pattern='(?<prefix>\b(?:Text|Content|Header|ToolTip)=\")(?<value>[^\"]*)(?<suffix>\")'
  $eval=[Text.RegularExpressions.MatchEvaluator]{param($m)$raw=[Net.WebUtility]::HtmlDecode([string]$m.Groups['value'].Value);$translated=Get-PMMLocalizedText $raw $code;$escaped=[Security.SecurityElement]::Escape([string]$translated);return [string]$m.Groups['prefix'].Value+$escaped+[string]$m.Groups['suffix'].Value}
  return [Text.RegularExpressions.Regex]::Replace($Xaml,$pattern,$eval)
}
function Invoke-PMMLocalizeVisualTree($Root,[string]$LanguageCode=''){
  if(-not$Root){return};$code=if($LanguageCode){Resolve-PMMLanguageCode $LanguageCode}else{Get-PMMCurrentLanguage};if($code -eq 'en'){return}
  try{
    if($Root -is [Windows.Controls.TextBlock] -and -not[string]::IsNullOrWhiteSpace([string]$Root.Text)){$Root.Text=Get-PMMLocalizedText ([string]$Root.Text) $code}
    if($Root -is [Windows.Documents.Run] -and -not[string]::IsNullOrWhiteSpace([string]$Root.Text)){$Root.Text=Get-PMMLocalizedText ([string]$Root.Text) $code}
    if($Root -is [Windows.Controls.ContentControl] -and $Root.Content -is [string]){$Root.Content=Get-PMMLocalizedText ([string]$Root.Content) $code}
    if($Root -is [Windows.Controls.HeaderedContentControl] -and $Root.Header -is [string]){$Root.Header=Get-PMMLocalizedText ([string]$Root.Header) $code}
    if($Root -is [Windows.Controls.HeaderedItemsControl] -and $Root.Header -is [string]){$Root.Header=Get-PMMLocalizedText ([string]$Root.Header) $code}
    if($Root -is [Windows.FrameworkElement] -and $Root.ToolTip -is [string]){$Root.ToolTip=Get-PMMLocalizedText ([string]$Root.ToolTip) $code}
    if($Root -is [Windows.Controls.DataGrid]){foreach($column in @($Root.Columns)){if($column.Header -is [string]){$column.Header=Get-PMMLocalizedText ([string]$column.Header) $code}}}
  }catch{}
  try{foreach($child in [Windows.LogicalTreeHelper]::GetChildren($Root)){if($child -is [Windows.DependencyObject]){Invoke-PMMLocalizeVisualTree $child $code}}}catch{}
}
function Set-PMMLanguageDirection($Element,[string]$LanguageCode=''){
  if(-not$Element){return};$code=if($LanguageCode){Resolve-PMMLanguageCode $LanguageCode}else{Get-PMMCurrentLanguage};$def=Get-PMMLanguageDefinition $code
  try{$Element.FlowDirection=if($def -and [string]$def.direction -eq 'rtl'){[Windows.FlowDirection]::RightToLeft}else{[Windows.FlowDirection]::LeftToRight}}catch{}
}
'''
    (MODULES / "Shared" / "Localization.ps1").write_text(runtime, encoding="utf-8-sig")
    shim = "if(-not(Get-Command Get-PMMLocalizedText -ErrorAction SilentlyContinue)){. (Join-Path $PSScriptRoot 'Localization.ps1')}\nfunction Get-PMMChineseText([string]$English){return Get-PMMLocalizedText $English 'zh-CN'}\n"
    (MODULES / "Shared" / "Localization.zh-CN.ps1").write_text(shim, encoding="utf-8-sig")


def patch_source():
    p = MODULES / "Shared" / "Common.ps1"
    text = read_ps(p)
    text = replace_once(text, ". (Join-Path $PSScriptRoot 'Localization.zh-CN.ps1')", ". (Join-Path $PSScriptRoot 'Localization.ps1')", "Common localization include")
    old = """function Get-PMMText([string]$English,[string]$Spanish){
  $cfg=Get-PMMConfig
  if($cfg.Language -eq 'es'){return $Spanish}
  if($cfg.Language -eq 'zh-CN'){return Get-PMMChineseText $English}
  return $English
}"""
    new = """function Get-PMMText([string]$English,[string]$Spanish){
  $cfg=Get-PMMConfig
  $language=Resolve-PMMLanguageCode ([string]$cfg.Language)
  if($language -eq 'es'){return $Spanish}
  if($language -eq 'en'){return $English}
  return Get-PMMLocalizedText $English $language
}"""
    text = replace_once(text, old, new, "Get-PMMText")
    write_ps(p, text)

    p = MODULES / "Bootstrap" / "Start-PalModMerger.ps1"
    text = read_ps(p)
    text = replace_once(text, "$lang = if ($startupCfg.Language -eq 'es') { 'es' } elseif ($startupCfg.Language -eq 'zh-CN') { 'zh-CN' } else { 'en' }", "$lang = Resolve-PMMLanguageCode ([string]$startupCfg.Language)", "startup language")
    text = replace_once(text, '$xamlPath = Join-Path $Script:Root ("Resources\\UI\\MainWindow.{0}.xaml" -f $lang)', "$xamlPath = Get-PMMLanguageXamlPath $lang", "xaml path")
    text = replace_once(text, "  [xml]$xaml = Get-Content -LiteralPath $xamlPath -Raw -Encoding UTF8", "  $xamlText=Get-Content -LiteralPath $xamlPath -Raw -Encoding UTF8\n  if($lang -ne 'en' -and [IO.Path]::GetFileName($xamlPath) -ieq 'MainWindow.en.xaml'){$xamlText=Convert-PMMXamlLocalization $xamlText $lang}\n  [xml]$xaml=$xamlText", "xaml localization")
    text = replace_once(text, "  $Window = [Windows.Markup.XamlReader]::Load($reader)", "  $Window = [Windows.Markup.XamlReader]::Load($reader)\n  Set-PMMLanguageDirection $Window $lang", "window direction")
    options = re.compile(r"\$Script:LanguageOptions=@\(\n\s*\[pscustomobject\]@\{Label='English';Code='en'\},\n\s*\[pscustomobject\]@\{Label='Español';Code='es'\},\n\s*\[pscustomobject\]@\{Label='简体中文';Code='zh-CN'\}\n\)")
    if "$Script:LanguageOptions=@(Get-PMMLanguageOptions)" not in text:
        text, count = options.subn("$Script:LanguageOptions=@(Get-PMMLanguageOptions)", text, count=1)
        if count != 1:
            raise RuntimeError("Language options patch failed")
    text = replace_once(text, "$cfg.Language = if ($selectedCode -in @('es','zh-CN')) { $selectedCode } else { 'en' }", "$cfg.Language = Resolve-PMMLanguageCode $selectedCode", "apply language")
    write_ps(p, text)

    p = MODULES / "AIIO" / "AIIO.CaseWorkspace.UI.ps1"
    text = read_ps(p)
    text = replace_once(text, "  [xml]$xml=$x;$reader=New-Object System.Xml.XmlNodeReader $xml;$tab=[Windows.Markup.XamlReader]::Load($reader)", "  $x=Convert-PMMXamlLocalization $x\n  [xml]$xml=$x;$reader=New-Object System.Xml.XmlNodeReader $xml;$tab=[Windows.Markup.XamlReader]::Load($reader)\n  Invoke-PMMLocalizeVisualTree $tab", "embedded case XAML")
    text = text.replace("$btn.Content=$(if($n -eq [int]$Case.CurrentStep){'[current]'}else{'[Step '+$n+']'})", "$btn.Content=$(if($n -eq [int]$Case.CurrentStep){Get-PMMLocalizedText '[current]'}else{'['+((Get-PMMLocalizedText 'Step {0}') -f $n)+']'})")
    text = text.replace("' — historical Step '+[int]$c.SelectedStep", "' — '+((Get-PMMLocalizedText 'historical Step {0}') -f [int]$c.SelectedStep)")
    write_ps(p, text)

    p = MODULES / "AIIO" / "AIIO.CaseNavigation.UI.ps1"
    text = read_ps(p)
    anchor = "    finally{$Script:PMMEditorLoading=$false}"
    text = replace_once(text, anchor, "    finally{try{if($Script:PMMCaseEditor){Invoke-PMMLocalizeVisualTree $Script:PMMCaseEditor}}catch{};$Script:PMMEditorLoading=$false}", "case render sweep")
    write_ps(p, text)

    p = MODULES / "AIIO" / "AIIO.Workspaces.UI.ps1"
    text = read_ps(p)
    text = replace_once(text, "    $help.Header='Help';$help.Tag='HELP'", "    $help.Header=L 'Help' 'Ayuda';$help.Tag='HELP'", "help header")
    text = replace_once(text, "    $creation=[Windows.Controls.TabItem]::new();$creation.Header='Mod Creation';$creation.Name='TabModCreation';$creation.Tag='CREATE'", "    $creation=[Windows.Controls.TabItem]::new();$creation.Header=L 'Mod Creation' 'Creacion de mods';$creation.Name='TabModCreation';$creation.Tag='CREATE'", "creation header")
    text = replace_once(text, "    $Script:PMMWorkspacesInitialized=$true", "    try{Invoke-PMMLocalizeVisualTree $Window}catch{}\n    $Script:PMMWorkspacesInitialized=$true", "workspace localization sweep")
    write_ps(p, text)

    p = MODULES / "Shared" / "Settings.Workspaces.UI.ps1"
    text = read_ps(p)
    text = replace_once(text, "    $ai.Header='AI / MCP';$ai.Tag='AI'", "    $ai.Header=L 'AI / MCP' 'IA / MCP';$ai.Tag='AI'", "AI settings header")
    text = replace_once(text, "    $merge=New-PMMSettingsSection 'MERGE' 'Mods & Merge'", "    $merge=New-PMMSettingsSection 'MERGE' (L 'Mods & Merge' 'Mods y Merge')", "merge settings header")
    text = replace_once(text, "    $creation=New-PMMSettingsSection 'CREATE' 'Mod Creation'", "    $creation=New-PMMSettingsSection 'CREATE' (L 'Mod Creation' 'Creacion de mods')", "creation settings header")
    text = replace_once(text, "    $help=New-PMMSettingsSection 'HELP' 'Help'", "    $help=New-PMMSettingsSection 'HELP' (L 'Help' 'Ayuda')", "help settings header")
    write_ps(p, text)

    p = MODULES / "Unreal" / "Dependencies.UI.ps1"
    text = read_ps(p)
    old = "$label=[Windows.Controls.TextBlock]::new();$label.Text=$d.name+' ('+$d.version+')';$label.TextWrapping='Wrap';$label.VerticalAlignment='Center';[void]$row.Children.Add($label)"
    new = "$displayName=Get-PMMLocalizedText ([string]$d.name);$displayVersion=Get-PMMLocalizedText ([string]$d.version)\n        $label=[Windows.Controls.TextBlock]::new();$label.Text=$displayName+' ('+$displayVersion+')';$label.TextWrapping='Wrap';$label.VerticalAlignment='Center';[void]$row.Children.Add($label)"
    text = replace_once(text, old, new, "dependency label")
    text = replace_once(text, "$Script:PMMDependencyLabels[$d.id]=@{label=$label;button=$button;name=$d.name;version=$d.version}", "$Script:PMMDependencyLabels[$d.id]=@{label=$label;button=$button;name=$displayName;version=$displayVersion}", "dependency label cache")
    text = replace_once(text, "$Script:PMMDependencyStatus.Text=$job.status+' - '+$job.message", "$Script:PMMDependencyStatus.Text=(Get-PMMLocalizedText ([string]$job.status))+' - '+(Get-PMMLocalizedText ([string]$job.message))", "dependency job message")
    write_ps(p, text)


def regenerate_chinese_xaml():
    zh = load_json(LOC / "zh-CN.json")["strings"]
    source = (UI / "MainWindow.en.xaml").read_text(encoding="utf-8-sig")
    pattern = re.compile(r'(?P<prefix>\b(?:Text|Content|Header|ToolTip)=")(?P<value>[^"]*)(?P<suffix>")')

    def repl(match):
        english = html.unescape(match.group("value"))
        translated = zh.get(english, english)
        return match.group("prefix") + html.escape(translated, quote=True) + match.group("suffix")

    (UI / "MainWindow.zh-CN.xaml").write_text(pattern.sub(repl, source), encoding="utf-8-sig")


def write_validator():
    text = r'''param([string]$Language='zh-CN')
$ErrorActionPreference='Stop'
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$loc=Join-Path $root 'PMM\Resources\Localization'
$en=Get-Content (Join-Path $loc 'en.json') -Raw -Encoding UTF8|ConvertFrom-Json -AsHashtable
$target=Get-Content (Join-Path $loc ($Language+'.json')) -Raw -Encoding UTF8|ConvertFrom-Json -AsHashtable
$targetMap=$target['strings']
$missing=@();$empty=@();$placeholder=@();$residue=@()
foreach($keyValue in $en['strings'].GetEnumerator()){
  $key=[string]$keyValue.Key
  if(-not$targetMap.ContainsKey($key)){$missing+=$key;continue}
  $value=[string]$targetMap[$key];if([string]::IsNullOrWhiteSpace($value)){$empty+=$key}
  $a=@([regex]::Matches($key,'\{[^{}]+\}')|ForEach-Object{$_.Value}|Sort-Object);$b=@([regex]::Matches($value,'\{[^{}]+\}')|ForEach-Object{$_.Value}|Sort-Object)
  if(($a -join '|') -cne ($b -join '|')){$placeholder+=$key}
  if($value -match 'PMMTERM|PMMTOKEN|__PMM|\bTERM\d+\b'){$residue+=$key}
}
if($missing.Count -or $empty.Count -or $placeholder.Count -or $residue.Count){throw ('Localization validation failed. missing='+$missing.Count+' empty='+$empty.Count+' placeholders='+$placeholder.Count+' residue='+$residue.Count)}
$critical=@{'+ New case'='+ 新建案例';'Projects'='项目';'Cases'='案例';'Mod Creation'='模组创建';'Help'='帮助';'Research cases'='研究案例';'Optional tools and AI clients'='可选工具与 AI 客户端';'Installations and status'='安装与状态';'Change permissions'='更改权限'}
if($Language -eq 'zh-CN'){foreach($k in $critical.Keys){if($targetMap[$k] -cne $critical[$k]){throw ('Critical translation mismatch: '+$k)}}}
[xml](Get-Content (Join-Path $root 'PMM\Resources\UI\MainWindow.zh-CN.xaml') -Raw -Encoding UTF8)|Out-Null
Write-Host ('Localization '+$Language+' OK: '+$targetMap.Count+' strings')
'''
    (ROOT / "Development" / "Localization" / "Test-Localization.ps1").write_text(text, encoding="utf-8-sig")


def main():
    repair_and_complete_catalogs()
    write_runtime()
    patch_source()
    regenerate_chinese_xaml()
    write_validator()
    print("Localization build completed")


if __name__ == "__main__":
    main()
