<#
Palworld Manager Merger WPF front-end
==========================

This file should remain a THIN UI layer.

Editable capabilities live in Modules/*.  The UI is responsible only for:
  * rendering current config/library/save state;
  * starting Analyze / Build actions;
  * displaying Analyze progress;
  * presenting only true overlapping-change decisions calculated by MergeEngine;
  * persisting deterministic source choices for those overlapping properties/bytes;
  * opening the read-only review workspace for complex values.

Palworld Manager Merger v1.3.0 keeps the proven conservative merge adapters, indexed CKL discovery, AIIO disk-safety, and exact runtime-proven CKL production recipes. It does not use whole-asset fallback for Unreal asset families. Analyze
merges independent changes automatically; the embedded conflict workspace is
only for bytes/properties that two or more mods actually change differently.
#>

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'
$Script:Root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
. (Join-Path $Script:Root 'Modules\Shared\Paths.ps1')
Initialize-PMMPaths $Script:Root|Out-Null

function Set-PMMHostStartupState([string]$Value) {
  try {
    $sessionDir=[Environment]::GetEnvironmentVariable('PMM_HOST_SESSION_DIR')
    if(-not [string]::IsNullOrWhiteSpace($sessionDir)){
      $statePath=Join-Path $sessionDir 'state.txt'
      [System.IO.File]::WriteAllText($statePath,([string]$Value+"`r`n"),[System.Text.UTF8Encoding]::new($false))
    }
  } catch {}
}
Set-PMMHostStartupState 'startup:UI-script-loading'

# ---------------------------------------------------------------------------
# Load core services in dependency order.
# ---------------------------------------------------------------------------
. (Join-Path $Script:Root 'Modules\Shared\Common.ps1')
. (Join-Path $Script:Root 'Modules\Operations\OperationJournal.ps1')
. (Join-Path $Script:Root 'Modules\Theme\ThemeService.ps1')
. (Join-Path $Script:Root 'Modules\Shared\GameLocator.ps1')
. (Join-Path $Script:Root 'Modules\Merge\PakService.ps1')
. (Join-Path $Script:Root 'Modules\Library\LibraryService.ps1')
. (Join-Path $Script:Root 'Modules\Saves\SaveService.ps1')
. (Join-Path $Script:Root 'Modules\CKL\SemanticLab.ps1')
. (Join-Path $Script:Root 'Modules\GameReference\GameReferenceService.ps1')
. (Join-Path $Script:Root 'Modules\CKL\KnowledgeRecipeService.ps1')
. (Join-Path $Script:Root 'Modules\Merge\MergeEngine.ps1')
. (Join-Path $Script:Root 'Modules\AIIO\AIIO.ps1')
. (Join-Path $Script:Root 'Modules\AIIO\AIIO.SessionService.ps1')
. (Join-Path $Script:Root 'Modules\Saves\SaveActivityService.ps1')
. (Join-Path $Script:Root 'Modules\AIIO\AIIO.DiagnosticService.ps1')
. (Join-Path $Script:Root 'Modules\AIIO\AIIO.ResponseService.ps1')
. (Join-Path $Script:Root 'Modules\AIIO\AIIO.ArtifactService.ps1')
. (Join-Path $Script:Root 'Modules\AIIO\AIIO.ValidationService.ps1')
. (Join-Path $Script:Root 'Modules\Theme\ThemeEditorService.ps1')
. (Join-Path $Script:Root 'Modules\CKL\KnowledgeContributionService.ps1')

Start-PMMLogSession 'UI'
Initialize-PMM
Add-Type -AssemblyName PresentationFramework,PresentationCore,WindowsBase
Add-Type -AssemblyName System.Windows.Forms

# Give the editable WPF child the same Windows Shell identity as PMM.exe.
# The full workspace is intentionally still loaded from editable PowerShell/XAML,
# but taskbar grouping, hover identity and icon belong to PMM rather than powershell.exe.
try {
  if(-not ('PMMShellIdentity' -as [type])){
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class PMMShellIdentity {
    [DllImport("shell32.dll", CharSet = CharSet.Unicode, SetLastError = false)]
    public static extern int SetCurrentProcessExplicitAppUserModelID(string appID);
    [DllImport("user32.dll", SetLastError = false)]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static extern bool SetForegroundWindow(IntPtr hWnd);
    [DllImport("user32.dll", SetLastError = false)]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static extern bool BringWindowToTop(IntPtr hWnd);
    [DllImport("user32.dll", SetLastError = false)]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
}
'@
  }
  [void][PMMShellIdentity]::SetCurrentProcessExplicitAppUserModelID('laredson.PalworldManagerMerger')
} catch {
  Write-PMMLog ('Could not set PMM AppUserModelID: ' + $_.Exception.Message)
}

$autoDepsOk = Initialize-PMMDependenciesIfNeeded # fast no-op when already prepared; conditional setup otherwise

# ---------------------------------------------------------------------------
# Load localized XAML.
# ---------------------------------------------------------------------------
$startupCfg = Get-PMMConfig
$lang = if ($startupCfg.Language -eq 'es') { 'es' } else { 'en' }
$xamlPath = Join-Path $Script:Root ("Resources\UI\MainWindow.{0}.xaml" -f $lang)
try {
  [xml]$xaml = Get-Content -LiteralPath $xamlPath -Raw -Encoding UTF8
  $reader = New-Object System.Xml.XmlNodeReader $xaml
  $Window = [Windows.Markup.XamlReader]::Load($reader)
} catch {
  [System.Windows.MessageBox]::Show(("XAML load failed:`n{0}`n`n{1}" -f $xamlPath,$_.Exception.Message),'Palworld Manager Merger',[System.Windows.MessageBoxButton]::OK,[System.Windows.MessageBoxImage]::Error) | Out-Null
  throw
}

# Use the PMM application icon for the WPF title bar, Alt-Tab and taskbar.
# The ICO is loaded fully into memory so the file is not held open while PMM runs.
try {
  $iconPath = Join-Path $Script:Root 'Resources\UI\PMM.ico'
  if (Test-Path -LiteralPath $iconPath -PathType Leaf) {
    $iconStream = [System.IO.File]::OpenRead($iconPath)
    try {
      $iconDecoder = [System.Windows.Media.Imaging.IconBitmapDecoder]::new(
        $iconStream,
        [System.Windows.Media.Imaging.BitmapCreateOptions]::PreservePixelFormat,
        [System.Windows.Media.Imaging.BitmapCacheOption]::OnLoad
      )
      $iconFrame = @($iconDecoder.Frames | Sort-Object PixelWidth -Descending)[0]
      if ($iconFrame) { $Window.Icon = $iconFrame }
    } finally {
      $iconStream.Dispose()
    }
  }
} catch {
  Write-PMMLog ('Could not load PMM window icon: ' + $_.Exception.Message)
}
try {
  $Window.ShowInTaskbar = $true
  $Window.ShowActivated = $true
} catch {}
Set-PMMHostStartupState 'startup:UI-window-created'

function Find-Control([string]$Name) {
  $control = $Window.FindName($Name)
  if (-not $control) { throw "UI control not found: $Name" }
  return $control
}

$controlNames = @(
  'GrdHeaderLayout','PnlHeaderTitle','GrdHeaderActions','ImgPMMLogo','TxtGamePath','TxtGamePathStatus','BtnDetectGame','BtnDetectGameSettings','BtnBrowseGame','BtnBrowseGameManual','BtnOpenGame','BtnOpenGameSettings','BtnOpenModsFolder','BtnOpenModsSettings','BtnPlay',
  'BtnImport','BtnImportGameMods','BtnScan','TxtModFilter','TxtLibraryCount','LstMods','BtnSelectAllMods','BtnClearModSelection','BtnEnableMods','BtnDisableMods','BtnPriorityUp','BtnPriorityDown','BtnDeleteMod','CmbLibraryOrder','BtnReorderLibrary','TxtPatchCount','LstPatches','BtnValidatePatch','BtnDeletePatch','ChkCloseGame','ChkForceClose','TglAutoMode','ChkAutoPlay','BtnAutoRun','BtnCancelOperation',
  'ExpAnalysis','TxtAnalysisHeadline','TxtSharedCount','TxtAutoCount','TxtDecisionCount','TxtUnsupportedCount','TxtExperimentalCount','TxtIdenticalCount','TxtAnalysisScope','DgAnalysisAssets',
  'TxtAnalyzeProgress','PrgAnalyze','TxtBuildProgress','PrgBuild','ExpConflicts','TxtConflictHeader','LstConflictAssets','TxtConflictMods','TxtConflictAsset','CmbBulkWinner','TxtBulkCustom','BtnApplyBulk','BtnOpenReview','DgDecisions',
  'ExpUnsupported','LstUnsupportedAssets','TxtUnsupported','TxtUnsupportedHint','CmbUnsupportedDisable','BtnDisableUnsupported','BtnOpenAIHandoff','BtnImportManualSolution',
  'TxtBuildDeployHint','BtnBuild','BtnDeploy','BtnUndeployPatch','TxtOperationProgress','PrgOperation',
  'ColLibrary','ColAnalysisWorkspace','RowPatches','ColConflictAssets','RowAnalysisWorkspace','RowAnalysisConflictSplitter','RowResolutionWorkspace','RowWorkspaceFiller','SplAnalysisResolution',
  'LstSaves','RowSelectedSave','RowSavePaneSplitter','RowSaveBackups','SplSavePanes','ExpSelectedSave','TxtSaveDetails','ExpSaveBackups','LstSaveBackups','TxtSaveBackupDetails','TxtSaveBackupStatus','BtnBackupSave','BtnRestoreSave','BtnOpenSaveBackupFolder',
  'MainTabs','TabFixLab','BtnFixLabOpenRoot','CmbFixLabJob','BtnFixLabRefreshJobs','BtnFixLabOpenJob','LstFixLabPrimaryMods','BtnFixLabUseLibraryMod','BtnFixLabBrowsePrimary','TxtFixLabPrimary',
  'LstFixLabRelated','BtnFixLabAddRelated','BtnFixLabRemoveRelated','TxtFixLabGameReference','BtnFixLabBuildReference','BtnFixLabOpenReference','BtnFixLabAnalyze','TxtFixLabAnalysis','DgFixLabPakInventory','CmbFixLabRecipe','CmbFixLabVariant','TxtFixLabVariantDescription','BtnFixLabCreateHandoff','TxtFixLabBuildState','BtnFixLabBuild','BtnFixLabRebuild','TxtFixLabResult','BtnFixLabOpenOutput','BtnFixLabAddOutputToLibrary',
  'BtnFixLabDiscover','BtnFixLabRefreshDashboard','LstFixLabCandidates','TxtFixLabCandidate','BtnFixLabIgnoreSource','BtnFixLabDeleteSource','LstFixLabBackups','BtnFixLabRevertBackup','BtnFixLabOpenBackupFolder','LstFixLabBuiltFixes','BtnFixLabApplyBuilt','BtnFixLabRepair','TxtFixLabRepairState','TxtFixLabRepairProgress','PrgFixLabRepair','TxtFixLabGameReferenceProgress','PrgFixLabGameReference','BrdFixLabBadge','TxtFixLabBadge','BrdFixLabNotice','TxtFixLabNotice','BtnFixLabDismissNotice','TxtFixLabCandidateCount','TxtFixLabBackupCount','TxtFixLabBuiltCount','TxtFixLabIgnoredCount','BtnFixLabClearIgnored','TxtFixLabLegacySource','TxtFixLabModules','TxtFixLabOutputSize','ExpFixLabSource','ExpFixLabConfigure','ExpFixLabBuild','ExpFixLabOutputs','ExpFixLabBackups','ExpFixLabAdvanced',
  'TabAIHelp','BrdAIHelpBadge','TxtAIHelpBadge','AIHelpTabs','LstAIHelpDiagnostics','BtnAIHelpRefresh','BtnAIHelpPrepareDiagnostic','CmbAIHelpDiagnosticType','TxtAIHelpDiagnosticTitle','TxtAIHelpDiagnosticDescription','ChkAIHelpIncludePalLog','BtnAIHelpCreateCase','TxtAIHelpDiagnosticStatus',
  'LstAIIOSessions','LstAIIOCandidates','TxtAIIOCandidateStatus','BtnAIIOOpenWorkspace','BtnAIIOArchive','BtnAIIOOpenCandidate','BtnAIIOUseCandidate','CmbAIIOType','TxtAIIOTitle','TxtAIIODescription','CmbAIOTargetKind','TxtAIOTargetId','BtnAIIONewSession','BtnAIIOPrepare','BtnAIIOImportResponse','BtnAIIOContinue','TxtAIIOStatus',
  'TxtAIHelpKnowledgeSummary','BtnAIHelpOpenKnowledge','BtnAIHelpGenerateFeedback','BtnAIHelpOpenFeedback','TxtAIHelpStorageSummary','LstAIHelpInterrupted','BtnAIHelpRefreshKnowledge','BtnAIHelpCleanup',
  'CmbThemeEditorSource','BtnThemeEditorNew','LstThemeDrafts','BtnThemeEditorLoad','BtnThemeEditorDelete','TxtThemeEditorName','TxtThemeEditorId','CmbThemeEditorBase','BrdThemeEditorPreview','PnlThemeEditorRows','TxtThemeEditorPrompt','BtnThemeEditorSave','BtnThemeEditorPreview','BtnThemeEditorRevert','BtnThemeEditorInstall','BtnThemeEditorExport','BtnThemeEditorCreateAI','BtnThemeEditorImportAI','TxtThemeEditorStatus',
  'CmbLanguage','BtnApplyLanguage','BtnResetLayout','CmbActionHintDuration','BtnRestoreDefaults','BtnApplySettings','PnlThemeOptions','PnlUserThemeOptions','TxtUserThemeEmpty','BtnImportTheme','BtnOpenThemesFolder','TxtThemeInfo','CmbSoundEventProfile','TxtSoundEventDescription','RdoSoundNone','RdoSoundBell','RdoSoundMicrowave','RdoSoundMicrowave3','RdoSoundOk','RdoSoundGood','RdoSoundCrystal','RdoSoundAlert','RdoSoundCustom','PnlCustomSoundOptions','ChkSoundEachAutoStep','ChkSoundAttention','BtnImportSound','BtnOpenSoundsFolder','BtnTestCompletionSound','SldCompletionVolume','TxtCompletionVolume','TxtSoundInfo','TxtLibraryPath','BtnOpenLibrary',
  'TxtGameReferenceSummary','BtnBuildGameReference','BtnOpenGameReference','TxtGameReferenceProgress','PrgGameReference',
  'TxtKnowledgeSummary','BtnOpenKnowledge','BtnOpenReviewCases','BtnExportKnowledgeContribution','BtnOpenKnowledgeContributions','BtnSetupDeps','TxtLog','TxtStatus'
)
foreach ($name in $controlNames) {
  Set-Variable -Scope Script -Name $name -Value (Find-Control $name)
}

# Use data items rather than nested ComboBoxItem controls. This keeps the
# collapsed language selector and its popup on the same typography/height path.
$Script:LanguageOptions=@(
  [pscustomobject]@{Label='English';Code='en'},
  [pscustomobject]@{Label='Español';Code='es'}
)
$Script:CmbLanguage.ItemsSource=$Script:LanguageOptions

function L([string]$English,[string]$Spanish) {
  return (Get-PMMText $English $Spanish)
}


# Load the transparent high-resolution header mark fully into memory so the
# portable PNG remains replaceable and is never held open by WPF.
try {
  $logoPath = Join-Path $Script:Root 'Resources\UI\PMMLogo.png'
  if (Test-Path -LiteralPath $logoPath -PathType Leaf) {
    $logoStream = [System.IO.File]::OpenRead($logoPath)
    try {
      $logoBitmap = [System.Windows.Media.Imaging.BitmapImage]::new()
      $logoBitmap.BeginInit()
      $logoBitmap.CacheOption = [System.Windows.Media.Imaging.BitmapCacheOption]::OnLoad
      $logoBitmap.StreamSource = $logoStream
      $logoBitmap.EndInit()
      $logoBitmap.Freeze()
      $Script:ImgPMMLogo.Source = $logoBitmap
    } finally {
      $logoStream.Dispose()
    }
  }
} catch {
  Write-PMMLog ('Could not load PMM header logo: ' + $_.Exception.Message)
}

$Script:ThemeOptionButtons=[System.Collections.Generic.List[object]]::new()
$Script:CustomSoundOptionButtons=[System.Collections.Generic.List[object]]::new()
$Script:PendingSoundSelections=@{}
$Script:ActiveThemeId='pmm-crystal'
$Script:ActiveThemeColorFlow=$null
$Script:ActiveThemeDefinition=$null
$Script:ThemeFallbackNotice=''

function Get-PMMThemeStore {
  $p=Join-PMMPath 'Themes'
  if(-not(Test-Path -LiteralPath $p -PathType Container)){New-Item -ItemType Directory -Force -Path $p|Out-Null}
  return $p
}
function Get-PMMSoundStore {
  $p=Join-PMMPath 'Sounds'
  if(-not(Test-Path -LiteralPath $p -PathType Container)){New-Item -ItemType Directory -Force -Path $p|Out-Null}
  return $p
}
function Get-PMMBaseThemePalette([string]$Base='Night') {
  if($Base -ieq 'Light'){
    return [ordered]@{
      AppBackground='#EAF0F7';HeaderBackground='#F8FBFF';CardBackground='#FFFFFF';CardAltBackground='#F7F9FC';InputBackground='#FFFFFF';
      CardBorder='#D5DAE0';InputBorder='#C5CBD2';PrimaryText='#17202A';MutedText='#5F6B76';SelectionBackground='#DDEBFF';SelectionText='#152238';
      GridLine='#E6E9ED';Splitter='#DDE2E8';StatusBackground='#E9EDF2';SoftBlue='#EEF4FF';SoftGreen='#ECF8EF';SoftAmber='#FFF7E6';SoftRed='#FFF0F0';SoftGray='#F7F8FA';
      FixHeaderBackground='#EEF3F8';FixHeaderBorder='#C9D5E2';NoticeBackground='#FFF7ED';NoticeBorder='#F2B56B';DecisionNoticeBackground='#EFF6FF';DecisionNoticeBorder='#3B82F6';DecisionNoticeHeading='#1D4ED8';SourceBackground='#F4F8FF';SourceBorder='#CAD8EA';
      ConfigureBackground='#FFF9EE';ConfigureBorder='#E8D6AE';BuildBackground='#F7F5FF';BuildBorder='#D8D1EF';OutputBackground='#F1FAF3';OutputBorder='#C8E2CE';
      BackupBackground='#FAF8F5';BackupBorder='#DDD7CF';AdvancedBackground='#F7F8FA';AccentHeadingBlue='#284B73';AccentHeadingAmber='#7A551A';AccentHeadingPurple='#51427C';AccentHeadingGreen='#2F6B3B';WarmHeading='#62584C';
      ButtonBackground='#F8FAFC';ButtonHover='#F1F5F9';ButtonForeground='#111827';ButtonBorder='#CBD5E1'
    }
  }
  return [ordered]@{
    AppBackground='#0B1016';HeaderBackground='#121A24';CardBackground='#171E27';CardAltBackground='#1D2631';InputBackground='#111820';
    CardBorder='#303C4A';InputBorder='#3B4A5B';PrimaryText='#E7EDF5';MutedText='#A8B3C0';SelectionBackground='#314963';SelectionText='#FFFFFF';
    GridLine='#2A3541';Splitter='#3B4A5B';StatusBackground='#121A23';SoftBlue='#172535';SoftGreen='#17291F';SoftAmber='#2B2418';SoftRed='#2B1D21';SoftGray='#1C2530';
    FixHeaderBackground='#162331';FixHeaderBorder='#34485D';NoticeBackground='#2A2218';NoticeBorder='#8A652F';DecisionNoticeBackground='#10263F';DecisionNoticeBorder='#38BDF8';DecisionNoticeHeading='#7DD3FC';SourceBackground='#18283A';SourceBorder='#35506A';
    ConfigureBackground='#292315';ConfigureBorder='#5A492A';BuildBackground='#241F31';BuildBorder='#51446A';OutputBackground='#18291F';OutputBorder='#385A43';
    BackupBackground='#24211D';BackupBorder='#4B453C';AdvancedBackground='#1A232E';AccentHeadingBlue='#9CC8F6';AccentHeadingAmber='#E0BD73';AccentHeadingPurple='#C2B3E7';AccentHeadingGreen='#93D5A4';WarmHeading='#C5B9AA';
    ButtonBackground='#263241';ButtonHover='#334255';ButtonForeground='#EAF0F7';ButtonBorder='#44566A'
  }
}
function Get-PMMDefaultColorFlow {
  return [ordered]@{
    Import=[ordered]@{Progress='#C4B5FD';Border='#6D28D9'}
    Analyze=[ordered]@{Progress='#93C5FD';Border='#1D4ED8'}
    Build=[ordered]@{Progress='#FCD34D';Border='#B45309'}
    Deploy=[ordered]@{Progress='#86EFAC';Border='#258342'}
    Play=[ordered]@{Progress='#5EEAD4';Border='#0F766E'}
  }
}
function Convert-PMMThemeJson([string]$Path){
  try{
    $doc=Get-Content -LiteralPath $Path -Raw -Encoding UTF8|ConvertFrom-Json
    if(-not$doc){return $null}
    $schema='';try{$schema=[string]$doc.schema}catch{}
    if($schema -notin @('PMM_COLOR_SCHEME_V1','PMM_COLOR_SCHEME_V2')){throw ('Unsupported color scheme schema: '+$schema)}
    $id='';try{$id=[string]$doc.id}catch{}
    if($id -cnotmatch '^[a-z0-9][a-z0-9._-]{0,63}$'){throw 'Color scheme id must use lowercase letters, digits, dot, underscore or hyphen (maximum 64 characters).'}
    $name='';try{$name=[string]$doc.name}catch{};if([string]::IsNullOrWhiteSpace($name)){$name=$id}
    $base='Night';try{$base=[string]$doc.base}catch{};if($base -notin @('Light','Night','Dark')){$base='Night'};if($base -eq 'Dark'){$base='Night'}
    $palette=Get-PMMBaseThemePalette $base
    if($doc.PSObject.Properties.Name -contains 'palette' -and $doc.palette){foreach($prop in $doc.palette.PSObject.Properties){if($palette.Contains($prop.Name) -and -not[string]::IsNullOrWhiteSpace([string]$prop.Value)){$palette[$prop.Name]=[string]$prop.Value}}}
    $flow=Get-PMMDefaultColorFlow
    if($doc.PSObject.Properties.Name -contains 'colorFlow' -and $doc.colorFlow){
      foreach($state in @('Import','Analyze','Build','Deploy','Play')){
        $sp=$doc.colorFlow.PSObject.Properties[$state]
        if($sp -and $sp.Value){
          foreach($part in @('Progress','Border')){if($sp.Value.PSObject.Properties.Name -contains $part -and -not[string]::IsNullOrWhiteSpace([string]$sp.Value.$part)){$flow[$state][$part]=[string]$sp.Value.$part}}
        }
      }
    }
    # Keep validation independent from WPF resource initialization.  RC26
    # attempted to run ColorConverter while the window resources were still
    # being constructed on Windows and rejected every bundled scheme.  Theme
    # data uses an intentionally small, deterministic hex contract.
    foreach($hex in @($palette.Values)){if(-not(Test-PMMThemeHexColor ([string]$hex))){throw ('Invalid palette color: '+[string]$hex)}}
    foreach($state in @('Import','Analyze','Build','Deploy','Play')){
      if(-not(Test-PMMThemeHexColor ([string]$flow[$state].Progress))){throw ('Invalid ColorFlow progress color for '+$state+'.')}
      if(-not(Test-PMMThemeHexColor ([string]$flow[$state].Border))){throw ('Invalid ColorFlow border color for '+$state+'.')}
    }
    $brushes=[ordered]@{}
    if($schema -eq 'PMM_COLOR_SCHEME_V2' -and $doc.PSObject.Properties.Name -contains 'brushes' -and $doc.brushes){
      $root=(Get-Item -LiteralPath $Path).DirectoryName
      foreach($prop in $doc.brushes.PSObject.Properties){
        $key=[string]$prop.Name;$entry=$prop.Value
        $known=($palette.Contains($key) -or $key -cmatch '^ColorFlow\.(Import|Analyze|Build|Deploy|Play)\.(Progress|Border)$')
        if(-not$known){throw ('Unknown image brush key: '+$key)}
        if(-not$entry -or [string]$entry.type -ne 'image'){throw ('Unsupported brush type for '+$key+'.')}
        $source=([string]$entry.source).Replace([char]92,[char]47)
        if([string]::IsNullOrWhiteSpace($source) -or $source.StartsWith('/') -or $source -match '^[A-Za-z]:' -or $source -match '(^|/)\.\.(/|$)' -or $source -match '^(?i:https?|file):'){throw ('Unsafe image source for '+$key+'.')}
        if([IO.Path]::GetExtension($source).ToLowerInvariant() -notin @('.png','.jpg','.jpeg')){throw ('Unsupported image source type for '+$key+'.')}
        $asset=Join-Path $root $source.Replace([char]47,[IO.Path]::DirectorySeparatorChar)
        if(-not(Test-PMMPathInside $asset $root) -or -not(Test-Path -LiteralPath $asset -PathType Leaf)){throw ('Missing packaged image for '+$key+': '+$source)}
        $imageInfo=Test-PMMThemeImageFile $asset
        $expected='';try{$expected=([string]$entry.sha256).ToLowerInvariant()}catch{}
        if($expected -and ($expected -notmatch '^[0-9a-f]{64}$' -or $expected -ne [string]$imageInfo.Sha256)){throw ('Image hash mismatch for '+$key+'.')}
        $stretch='UniformToFill';try{$stretch=[string]$entry.stretch}catch{};if($stretch -notin @('None','Fill','Uniform','UniformToFill')){throw ('Invalid image stretch for '+$key+'.')}
        $alignment='Center';try{$alignment=[string]$entry.alignment}catch{};if($alignment -notin @('Center','Left','Right','Top','Bottom','TopLeft','TopRight','BottomLeft','BottomRight')){throw ('Invalid image alignment for '+$key+'.')}
        $tile='None';try{$tile=[string]$entry.tileMode}catch{};if($tile -notin @('None','Tile','FlipX','FlipY','FlipXY')){throw ('Invalid image tile mode for '+$key+'.')}
        $opacity=1.0;try{$opacity=[double]$entry.opacity}catch{throw ('Invalid image opacity for '+$key+'.')};if($opacity -lt 0 -or $opacity -gt 1){throw ('Image opacity must be between 0 and 1 for '+$key+'.')}
        $overlay='#00000000';try{$overlay=[string]$entry.overlay}catch{};if(-not(Test-PMMThemeHexColor $overlay)){throw ('Invalid image overlay color for '+$key+'.')}
        $brushes[$key]=$entry
      }
    }
    $definition=[pscustomobject]@{Id=$id;Name=$name;Schema=$schema;Base=$base;Palette=$palette;ColorFlow=$flow;Brushes=$brushes;Builtin=$false;Path=$Path;ThemeRoot=(Get-Item -LiteralPath $Path).DirectoryName}
    $contrast=Test-PMMThemeContrast $definition
    if(-not[bool]$contrast.Valid){throw ('Color-scheme contrast validation failed: '+(@($contrast.Errors)-join ' | '))}
    return $definition
  }catch{Write-PMMLog ('Invalid PMM color scheme '+$Path+': '+$_.Exception.Message);return $null}
}
function Get-PMMThemeDefinitions {
  $items=[System.Collections.Generic.List[object]]::new()
  $seen=[System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
  $bundledFiles=@(Get-PMMBundledThemeFiles)
  foreach($f in $bundledFiles){
    $t=Convert-PMMThemeJson $f.FullName
    if($t){$t|Add-Member -NotePropertyName Bundled -NotePropertyValue $true -Force;$items.Add($t);[void]$seen.Add([string]$t.Id)}
  }
  $ordered=@(
    @($items.ToArray()|Where-Object{[string]$_.Id -ieq 'pmm-crystal'})
    @($items.ToArray()|Where-Object{[string]$_.Id -ine 'pmm-crystal'}|Sort-Object Name)
  )
  $items.Clear();foreach($t in $ordered){$items.Add($t)}
  $items.Add([pscustomobject]@{Id='Night';Name=(L 'Night (legacy built-in)' 'Noche (integrado clasico)');Base='Night';Palette=(Get-PMMBaseThemePalette 'Night');ColorFlow=(Get-PMMDefaultColorFlow);Builtin=$true;Bundled=$false;Path=''})
  [void]$seen.Add('Night')
  $items.Add([pscustomobject]@{Id='Light';Name=(L 'Light' 'Claro');Base='Light';Palette=(Get-PMMBaseThemePalette 'Light');ColorFlow=(Get-PMMDefaultColorFlow);Builtin=$true;Path=''})
  [void]$seen.Add('Light')
  foreach($f in @(Get-PMMUserThemeFiles)){$t=Convert-PMMThemeJson $f.FullName;if($t -and $seen.Add([string]$t.Id)){$t|Add-Member -NotePropertyName Bundled -NotePropertyValue $false -Force;$items.Add($t)}}
  $loadedBundled=@($items.ToArray()|Where-Object{try{[bool]$_.Bundled}catch{$false}}).Count
  if($bundledFiles.Count -ne 11 -or $loadedBundled -ne 11){Write-PMMLog ('Official theme audit: expected 11, discovered '+$bundledFiles.Count+', loaded '+$loadedBundled+'. Night/Light remain emergency built-ins.')}
  return @($items.ToArray())
}
function Get-PMMSelectedThemeId {
  foreach($rb in @($Script:ThemeOptionButtons)){if($rb -and [bool]$rb.IsChecked){return [string]$rb.Tag}}
  return 'pmm-crystal'
}
function Set-PMMSelectedThemeId([string]$Id){
  if($Id -eq 'Dark'){$Id='Night'}
  $found=$false
  foreach($rb in @($Script:ThemeOptionButtons)){if($rb){$yes=([string]$rb.Tag -ieq $Id);$rb.IsChecked=$yes;if($yes){$found=$true}}}
  if(-not$found){foreach($fallback in @('pmm-crystal','Night')){foreach($rb in @($Script:ThemeOptionButtons)){if([string]$rb.Tag -ieq $fallback){$rb.IsChecked=$true;$found=$true;break}};if($found){break}}}
}
function Refresh-PMMThemeOptions([string]$Selected=''){
  $Script:PnlThemeOptions.Children.Clear();$Script:PnlUserThemeOptions.Children.Clear();$Script:ThemeOptionButtons.Clear()
  if([string]::IsNullOrWhiteSpace($Selected)){try{$Selected=[string](Get-PMMConfig).Theme}catch{$Selected='pmm-crystal'}}
  if($Selected -eq 'Dark'){$Selected='Night'}
  $official=0;$bundled=0;$legacy=0;$custom=0
  foreach($t in @(Get-PMMThemeDefinitions)){
    $rb=[System.Windows.Controls.RadioButton]::new();$rb.Content=[string]$t.Name;$rb.Tag=[string]$t.Id;$rb.GroupName='PMMColorScheme';$rb.Margin=[System.Windows.Thickness]::new(0,3,12,3);$rb.Padding=[System.Windows.Thickness]::new(2)
    $isBundled=$false;try{$isBundled=[bool]$t.Bundled}catch{}
    $isOfficial=([bool]$t.Builtin -or $isBundled)
    $rb.ToolTip=if($isOfficial){(L 'Official PMM color scheme.' 'Esquema de color oficial de PMM.')}else{[string]$t.Path}
    $rb.Add_Checked({if(-not$Script:UiSettingsRefreshing){$Script:TxtStatus.Text=L 'Color scheme changed. Press Apply changes.' 'Esquema de color cambiado. Pulsa Aplicar cambios.'}})
    $Script:ThemeOptionButtons.Add($rb)
    if($isOfficial){$official++;if($isBundled){$bundled++}else{$legacy++};[void]$Script:PnlThemeOptions.Children.Add($rb)}else{$custom++;[void]$Script:PnlUserThemeOptions.Children.Add($rb)}
  }
  Set-PMMSelectedThemeId $Selected
  $Script:TxtUserThemeEmpty.Visibility=if($custom -eq 0){[System.Windows.Visibility]::Visible}else{[System.Windows.Visibility]::Collapsed}
  $text=((L '{0} user scheme(s) in Workspace\Themes. {1} official schemes and {2} legacy palette(s) are always available.' '{0} esquema(s) del usuario en Workspace\Themes. Siempre estan disponibles {1} esquemas oficiales y {2} paleta(s) heredadas.') -f $custom,$bundled,$legacy)
  if(-not[string]::IsNullOrWhiteSpace([string]$Script:ThemeFallbackNotice)){$text+=' '+[string]$Script:ThemeFallbackNotice}
  $Script:TxtThemeInfo.Text=$text
}
function Get-PMMSoundDefinitions {
  return @(
    [pscustomobject]@{Id='None';Name=(L 'No sound' 'Sin sonido');Path='';Builtin=$true},
    [pscustomobject]@{Id='Bell';Name=(L 'Bell' 'Campana');Path=(Join-Path $Script:Root 'Resources\Sounds\PMM_bell.wav');Builtin=$true},
    [pscustomobject]@{Id='Microwave';Name=(L 'Microwave finish' 'Final de microondas');Path=(Join-Path $Script:Root 'Resources\Sounds\PMM_microwave.wav');Builtin=$true},
    [pscustomobject]@{Id='Microwave3';Name=(L '3 beeps' '3 pitidos');Path=(Join-Path $Script:Root 'Resources\Sounds\PMM_microwave_3beeps.wav');Builtin=$true},
    [pscustomobject]@{Id='Ok';Name='OK';Path=(Join-Path $Script:Root 'Resources\Sounds\PMM_ok.wav');Builtin=$true},
    [pscustomobject]@{Id='Good';Name='Good';Path=(Join-Path $Script:Root 'Resources\Sounds\PMM_good.wav');Builtin=$true},
    [pscustomobject]@{Id='Crystal';Name=(L 'Crystal chime' 'Campanilla cristalina');Path=(Join-Path $Script:Root 'Resources\Sounds\PMM_crystal.wav');Builtin=$true},
    [pscustomobject]@{Id='Alert';Name=(L 'Short alert' 'Alerta corta');Path=(Join-Path $Script:Root 'Resources\Sounds\PMM_alert.wav');Builtin=$true}
  )
}
function Get-PMMCustomSoundDefinitions {
  $rows=[System.Collections.Generic.List[object]]::new()
  foreach($f in @(Get-ChildItem -LiteralPath (Get-PMMSoundStore) -File -ErrorAction SilentlyContinue|Where-Object{$_.Extension -match '(?i)^\.(wav|mp3|wma)$'}|Sort-Object Name)){
    $rows.Add([pscustomobject]@{Id=('file:'+[string]$f.Name);Name=([IO.Path]::GetFileNameWithoutExtension($f.Name));Path=$f.FullName;Builtin=$false})
  }
  return @($rows.ToArray())
}
function Get-PMMSoundProfileDefinitions {
  return @(
    [pscustomobject]@{Id='Auto';Label=(L 'Auto - workflow finished' 'Auto - flujo terminado');Description=(L 'Played once when an automatic workflow really finishes. If Run Palworld after Deploy is enabled, it plays after Palworld is launched; otherwise after Deploy.' 'Suena una vez cuando termina realmente un flujo automatico. Si Iniciar Palworld tras Deploy esta activado, suena despues de iniciar Palworld; si no, despues de Deploy.')},
    [pscustomobject]@{Id='SemiAuto';Label=(L 'Semiauto - each AUTO step' 'Semiauto - cada paso de AUTO');Description=(L 'Optional short sound after each completed step while AUTO/Auto ON is still running.' 'Sonido corto opcional despues de cada paso completado mientras AUTO/Auto ON sigue ejecutandose.')},
    [pscustomobject]@{Id='Manual';Label=(L 'Manual - completed action' 'Manual - accion completada');Description=(L 'Played after a manually-started workflow action completes. Start Palworld by itself never plays this sound.' 'Suena cuando termina una accion del flujo iniciada manualmente. Iniciar Palworld por si solo nunca reproduce este sonido.')},
    [pscustomobject]@{Id='Attention';Label=(L 'Attention required' 'Atencion requerida');Description=(L 'Optional notification when PMM is waiting for a real user decision, such as choosing a Fix Lab output or resolving a compatibility decision.' 'Aviso opcional cuando PMM espera una decision real del usuario, como elegir una salida de Fix Lab o resolver una decision de compatibilidad.')},
    [pscustomobject]@{Id='Error';Label=(L 'Error' 'Error');Description=(L 'Short alert when PMM reports an operation error.' 'Alerta corta cuando PMM informa de un error de operacion.')}
  )
}
function Get-PMMSoundProfileConfigProperty([string]$Profile){
  switch($Profile){'Auto'{return 'SoundAuto'}'SemiAuto'{return 'SoundSemiAuto'}'Manual'{return 'SoundManual'}'Attention'{return 'SoundAttention'}'Error'{return 'SoundError'}default{return 'SoundManual'}}
}
function Get-PMMSoundProfileDefault([string]$Profile){
  switch($Profile){'Auto'{return 'Microwave'}'SemiAuto'{return 'Ok'}'Manual'{return 'Good'}'Attention'{return 'Alert'}'Error'{return 'Microwave3'}default{return 'Microwave'}}
}
function Initialize-PMMPendingSoundSelections($Config){
  $Script:PendingSoundSelections=@{}
  foreach($profile in @('Auto','SemiAuto','Manual','Attention','Error')){
    $prop=Get-PMMSoundProfileConfigProperty $profile;$value=''
    try{if($Config -and ($Config.PSObject.Properties.Name -contains $prop)){$value=[string]$Config.$prop}}catch{}
    if([string]::IsNullOrWhiteSpace($value)){$value=Get-PMMSoundProfileDefault $profile}
    # Missing imported files fall back safely instead of leaving an invisible selection.
    if($value -like 'file:*' -and [string]::IsNullOrWhiteSpace([string](Get-PMMSoundPathById $value))){$value=Get-PMMSoundProfileDefault $profile}
    $Script:PendingSoundSelections[$profile]=$value
  }
}
function Get-PMMCurrentSoundProfileId {
  try{if($Script:CmbSoundEventProfile.SelectedValue){return [string]$Script:CmbSoundEventProfile.SelectedValue}}catch{}
  return 'Auto'
}
function Get-PMMPendingSoundId([string]$Profile=''){
  if([string]::IsNullOrWhiteSpace($Profile)){$Profile=Get-PMMCurrentSoundProfileId}
  if(-not$Script:PendingSoundSelections){Initialize-PMMPendingSoundSelections (Get-PMMConfig)}
  if($Script:PendingSoundSelections.ContainsKey($Profile)){return [string]$Script:PendingSoundSelections[$Profile]}
  return (Get-PMMSoundProfileDefault $Profile)
}
function Set-PMMPendingSoundId([string]$Id,[string]$Profile=''){
  if([string]::IsNullOrWhiteSpace($Profile)){$Profile=Get-PMMCurrentSoundProfileId}
  if(-not$Script:PendingSoundSelections){Initialize-PMMPendingSoundSelections (Get-PMMConfig)}
  $Script:PendingSoundSelections[$Profile]=[string]$Id
  # Selecting a concrete Semiauto sound must not leave its independent master
  # switch silently disabled. None remains the explicit mute choice.
  if($Profile -eq 'SemiAuto' -and $Script:ChkSoundEachAutoStep){$Script:ChkSoundEachAutoStep.IsChecked=([string]$Id -ne 'None')}
  if(-not$Script:UiSettingsRefreshing){$Script:TxtStatus.Text=L 'Sound settings changed. Press Apply changes.' 'Los sonidos han cambiado. Pulsa Aplicar cambios.'}
}
function Get-PMMSelectedCustomSoundId {
  foreach($rb in @($Script:CustomSoundOptionButtons)){if($rb -and [bool]$rb.IsChecked){return [string]$rb.Tag}}
  return ''
}
function Refresh-PMMCustomSoundOptions([string]$Selected=''){
  $Script:PnlCustomSoundOptions.Children.Clear();$Script:CustomSoundOptionButtons.Clear()
  $custom=@(Get-PMMCustomSoundDefinitions)
  foreach($snd in $custom){
    $rb=[System.Windows.Controls.RadioButton]::new();$rb.Content=[string]$snd.Name;$rb.Tag=[string]$snd.Id;$rb.GroupName='PMMCustomSound';$rb.Margin=[System.Windows.Thickness]::new(0,2,12,2);$rb.Padding=[System.Windows.Thickness]::new(2);$rb.ToolTip=[string]$snd.Path
    $rb.Add_Checked({
      param($sender,$e)
      if($Script:UiSettingsRefreshing){return}
      try{$Script:RdoSoundCustom.IsChecked=$true;Set-PMMPendingSoundId ([string]$sender.Tag)}catch{}
    })
    if([string]$snd.Id -ieq [string]$Selected){$rb.IsChecked=$true}
    $Script:CustomSoundOptionButtons.Add($rb);[void]$Script:PnlCustomSoundOptions.Children.Add($rb)
  }
  $Script:RdoSoundCustom.IsEnabled=($custom.Count -gt 0)
  $Script:TxtSoundInfo.Text=((L '{0} custom sound(s) in Workspace\Sounds.' '{0} sonido(s) custom en Workspace\Sounds.') -f $custom.Count)
}
function Refresh-PMMSoundProfileUi([string]$Profile=''){
  if([string]::IsNullOrWhiteSpace($Profile)){$Profile=Get-PMMCurrentSoundProfileId}
  $defs=@(Get-PMMSoundProfileDefinitions);$desc=@($defs|Where-Object{[string]$_.Id -eq $Profile}|Select-Object -First 1)
  if($desc.Count -gt 0){$Script:TxtSoundEventDescription.Text=[string]$desc[0].Description}
  $selected=Get-PMMPendingSoundId $Profile
  $priorRefreshing=[bool]$Script:UiSettingsRefreshing;$Script:UiSettingsRefreshing=$true
  try{
    $Script:RdoSoundNone.IsChecked=($selected -eq 'None')
    $Script:RdoSoundBell.IsChecked=($selected -eq 'Bell')
    $Script:RdoSoundMicrowave.IsChecked=($selected -eq 'Microwave')
    $Script:RdoSoundMicrowave3.IsChecked=($selected -eq 'Microwave3')
    $Script:RdoSoundOk.IsChecked=($selected -eq 'Ok')
    $Script:RdoSoundGood.IsChecked=($selected -eq 'Good')
    $Script:RdoSoundCrystal.IsChecked=($selected -eq 'Crystal')
    $Script:RdoSoundAlert.IsChecked=($selected -eq 'Alert')
    $isCustom=($selected -like 'file:*');$Script:RdoSoundCustom.IsChecked=$isCustom
    Refresh-PMMCustomSoundOptions $(if($isCustom){$selected}else{''})
  }finally{$Script:UiSettingsRefreshing=$priorRefreshing}
}
function Initialize-PMMSoundSettingsUi($Config){
  Initialize-PMMPendingSoundSelections $Config
  $Script:SoundEventProfiles=@(Get-PMMSoundProfileDefinitions)
  $Script:CmbSoundEventProfile.ItemsSource=$Script:SoundEventProfiles;$Script:CmbSoundEventProfile.DisplayMemberPath='Label';$Script:CmbSoundEventProfile.SelectedValuePath='Id';$Script:CmbSoundEventProfile.SelectedValue='Auto'
  $semi=$true;$attn=$true
  try{if($Config.PSObject.Properties.Name -contains 'SoundSemiAutoEnabled'){$semi=[bool]$Config.SoundSemiAutoEnabled}}catch{}
  try{if($Config.PSObject.Properties.Name -contains 'SoundAttentionEnabled'){$attn=[bool]$Config.SoundAttentionEnabled}}catch{}
  $Script:ChkSoundEachAutoStep.IsChecked=$semi;$Script:ChkSoundAttention.IsChecked=$attn
  Refresh-PMMSoundProfileUi 'Auto'
}

function Convert-PMMThemeHexToWpf([string]$Hex) {
  if(-not(Test-PMMThemeHexColor $Hex)){throw ('Invalid theme color: '+$Hex)}
  # PMM's data contract uses #RRGGBBAA; WPF ColorConverter uses #AARRGGBB.
  if($Hex.Length -eq 9){return ('#'+$Hex.Substring(7,2)+$Hex.Substring(1,6))}
  return $Hex
}

function Set-PMMThemeBrush([string]$Key,[string]$Hex) {
  try{
    # Always replace the resource instead of mutating an existing brush.
    # WPF may freeze/share brushes once a template has consumed them; mutating
    # such an instance produces the partial-theme behaviour seen in RC15.
    # DynamicResource users are invalidated immediately when the dictionary
    # entry itself is replaced, so every tab/control resolves the new colour.
    $color=[System.Windows.Media.ColorConverter]::ConvertFromString((Convert-PMMThemeHexToWpf $Hex))
    $Window.Resources[$Key]=[System.Windows.Media.SolidColorBrush]::new($color)
  }catch{Write-PMMLog ('Theme brush warning '+$Key+': '+$_.Exception.Message)}
}

function Set-PMMThemeDefinitionBrush($Definition,[string]$Key,[string]$FallbackHex,[string]$ResourceKey='') {
  if([string]::IsNullOrWhiteSpace($ResourceKey)){$ResourceKey=$Key}
  $entry=$null
  try{if($Definition.Brushes -is [Collections.IDictionary]){$entry=$Definition.Brushes[$Key]}else{$property=$Definition.Brushes.PSObject.Properties[$Key];if($property){$entry=$property.Value}}}catch{}
  if(-not$entry){Set-PMMThemeBrush $ResourceKey $FallbackHex;return}
  try{
    $source=([string]$entry.source).Replace([char]47,[IO.Path]::DirectorySeparatorChar)
    $path=Join-Path ([string]$Definition.ThemeRoot) $source
    $info=Test-PMMThemeImageFile $path
    $stream=[IO.File]::Open($info.Path,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::Read)
    try{
      $bitmap=[System.Windows.Media.Imaging.BitmapImage]::new();$bitmap.BeginInit();$bitmap.CacheOption=[System.Windows.Media.Imaging.BitmapCacheOption]::OnLoad;$bitmap.StreamSource=$stream;$bitmap.EndInit();$bitmap.Freeze()
    }finally{$stream.Dispose()}
    $rect=[System.Windows.Rect]::new(0,0,[double]$bitmap.PixelWidth,[double]$bitmap.PixelHeight)
    $group=[System.Windows.Media.DrawingGroup]::new();[void]$group.Children.Add([System.Windows.Media.ImageDrawing]::new($bitmap,$rect))
    $overlay='#00000000';try{if(Test-PMMThemeHexColor ([string]$entry.overlay)){$overlay=[string]$entry.overlay}}catch{}
    $overlayBrush=[System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString((Convert-PMMThemeHexToWpf $overlay)))
    [void]$group.Children.Add([System.Windows.Media.GeometryDrawing]::new($overlayBrush,$null,[System.Windows.Media.RectangleGeometry]::new($rect)))
    $brush=[System.Windows.Media.DrawingBrush]::new($group)
    $stretch='UniformToFill';try{$stretch=[string]$entry.stretch}catch{}
    $brush.Stretch=switch($stretch){'None'{[System.Windows.Media.Stretch]::None};'Fill'{[System.Windows.Media.Stretch]::Fill};'Uniform'{[System.Windows.Media.Stretch]::Uniform};default{[System.Windows.Media.Stretch]::UniformToFill}}
    $alignment='Center';try{$alignment=[string]$entry.alignment}catch{}
    if($alignment -in @('Left','TopLeft','BottomLeft')){$brush.AlignmentX=[System.Windows.Media.AlignmentX]::Left}elseif($alignment -in @('Right','TopRight','BottomRight')){$brush.AlignmentX=[System.Windows.Media.AlignmentX]::Right}else{$brush.AlignmentX=[System.Windows.Media.AlignmentX]::Center}
    if($alignment -in @('Top','TopLeft','TopRight')){$brush.AlignmentY=[System.Windows.Media.AlignmentY]::Top}elseif($alignment -in @('Bottom','BottomLeft','BottomRight')){$brush.AlignmentY=[System.Windows.Media.AlignmentY]::Bottom}else{$brush.AlignmentY=[System.Windows.Media.AlignmentY]::Center}
    $tileMode='None';try{$tileMode=[string]$entry.tileMode}catch{}
    $brush.TileMode=switch($tileMode){'Tile'{[System.Windows.Media.TileMode]::Tile};'FlipX'{[System.Windows.Media.TileMode]::FlipX};'FlipY'{[System.Windows.Media.TileMode]::FlipY};'FlipXY'{[System.Windows.Media.TileMode]::FlipXY};default{[System.Windows.Media.TileMode]::None}}
    if($brush.TileMode -ne [System.Windows.Media.TileMode]::None){$brush.ViewportUnits=[System.Windows.Media.BrushMappingMode]::RelativeToBoundingBox;$brush.Viewport=[System.Windows.Rect]::new(0,0,0.25,0.25)}
    $opacity=1.0;try{$opacity=[double]$entry.opacity}catch{};$brush.Opacity=[Math]::Max(0.0,[Math]::Min(1.0,$opacity))
    $brush.Freeze();$Window.Resources[$ResourceKey]=$brush
  }catch{Write-PMMLog ('Theme image brush '+$Key+' rejected; solid fallback retained. '+$_.Exception.Message);Set-PMMThemeBrush $ResourceKey $FallbackHex}
}

function Get-PMMThemeDefinitionBrush($Definition,[string]$Key,[string]$FallbackHex) {
  $temporary='__PMM_THEME_BRUSH_'+[guid]::NewGuid().ToString('N')
  try{Set-PMMThemeDefinitionBrush $Definition $Key $FallbackHex $temporary;return $Window.Resources[$temporary]}
  finally{try{$Window.Resources.Remove($temporary)}catch{}}
}

function Apply-PMMTheme([string]$Theme='') {
  if([string]::IsNullOrWhiteSpace($Theme)){try{$Theme=[string](Get-PMMConfig).Theme}catch{$Theme='pmm-crystal'}}
  if($Theme -eq 'Dark'){$Theme='Night'}
  $requested=$Theme;$definitions=@(Get-PMMThemeDefinitions)
  $definition=@($definitions|Where-Object{[string]$_.Id -ieq $Theme}|Select-Object -First 1)
  $Script:ThemeFallbackNotice=''
  if($definition.Count -eq 0){
    $definition=@($definitions|Where-Object{[string]$_.Id -ieq 'pmm-crystal'}|Select-Object -First 1)
    if($definition.Count -gt 0){$Script:ThemeFallbackNotice=(L ('Configured scheme "'+$requested+'" is unavailable; PMM Crystal is active without changing your saved choice.') ('El esquema configurado "'+$requested+'" no esta disponible; PMM Crystal esta activo sin cambiar tu eleccion guardada.'))}
  }
  if($definition.Count -eq 0){$definition=@($definitions|Where-Object{[string]$_.Id -eq 'Night'}|Select-Object -First 1);$Script:ThemeFallbackNotice=L 'PMM Crystal is unavailable; the emergency Night palette is active.' 'PMM Crystal no esta disponible; esta activa la paleta de emergencia Noche.'}
  Apply-PMMThemeDefinition $definition[0]
}

function Apply-PMMThemeDefinition($def) {
  if(-not$def){throw 'A valid color-scheme definition is required.'}
  foreach($kv in $def.Palette.GetEnumerator()){Set-PMMThemeDefinitionBrush $def ([string]$kv.Key) ([string]$kv.Value)}
  $Script:ActiveThemeId=[string]$def.Id;$Script:ActiveThemeColorFlow=$def.ColorFlow;$Script:ActiveThemeDefinition=$def
  try{$Window.Foreground=$Window.Resources['PrimaryText'];$Window.Background=$Window.Resources['AppBackground'];$Script:TxtStatus.Foreground=$Window.Resources['PrimaryText']}catch{}
  try{$Window.InvalidateVisual();$Window.UpdateLayout()}catch{}
  Write-PMMLog ('UI color scheme applied: '+[string]$def.Id)
}

# ---------------------------------------------------------------------------
# AI & Help: local-first sessions, diagnostics, Knowledge and theme editor.
# ---------------------------------------------------------------------------
$Script:AIHelpLoaded=$false
$Script:AIIOBusy=$false
$Script:ActiveThemeDraft=$null
$Script:ThemeEditorRowControls=@{}
$Script:ThemePreviewActive=$false

function Set-PMMAIIOActiveSession([string]$SessionId) {
  $session=Get-PMMAIIOSession $SessionId
  if(-not$session){return $null}
  $cfg=Get-PMMConfig;$cfg.AIIOActiveSession=$SessionId;Save-PMMConfig $cfg
  return $session
}

function Refresh-PMMAIHelpBadge {
  $attention=0
  try{$attention+=@(Get-PMMAIIOSessions|Where-Object{-not[bool]$_.Archived -and [bool]$_.Attention}).Count}catch{}
  try{$attention+=@(Get-PMMDiagnosticCases|Where-Object{[string]$_.Status -eq 'Open'}).Count}catch{}
  try{$attention+=@(Get-PMMInterruptedOperations).Count}catch{}
  try{
    $plan=Read-PMMMergePlan
    if($plan){$attention+=@($plan.Assets|Where-Object{[string]$_.Mode -eq 'Unsupported'}).Count}
  }catch{}
  $Script:TxtAIHelpBadge.Text=[string]$attention
  $Script:BrdAIHelpBadge.Visibility=if($attention -gt 0){[System.Windows.Visibility]::Visible}else{[System.Windows.Visibility]::Collapsed}
}

function Refresh-PMMAIHelpKnowledge {
  try{
    $summary=Get-PMMKnowledgeSummary
    $Script:TxtAIHelpKnowledgeSummary.Text=((L '{0} behavior cases, {1} exact fixtures, {2} runtime-proven fixtures and {3} production recipes. Local evidence never becomes Proven merely because an AI proposed it.' '{0} casos de comportamiento, {1} fixtures exactos, {2} fixtures probados en runtime y {3} recetas de produccion. La evidencia local nunca pasa a Proven solo porque la propuso una IA.') -f $summary.BehaviorCases,$summary.Fixtures,$summary.RuntimeProven,$summary.ProductionRecipes)
  }catch{$Script:TxtAIHelpKnowledgeSummary.Text=$_.Exception.Message}
  try{
    $storage=Get-PMMArtifactStorageSummary
    if(-not[bool]$storage.Available){
      $Script:TxtAIHelpStorageSummary.Text=L 'Storage inventory has not been refreshed yet. Press Refresh to scan it in the background.' 'El inventario de almacenamiento aun no se ha actualizado. Pulsa Actualizar para escanearlo en segundo plano.'
    }else{
      $mib=1048576.0
      $parts=@($storage.Categories|ForEach-Object{([string]$_.Category+': '+('{0:N1} MiB' -f ([double]$_.Bytes/$mib)))})
      $Script:TxtAIHelpStorageSummary.Text=((L '{0} registered artifacts, {1:N1} MiB total. Current/protected items are never offered as disposable.' '{0} artefactos registrados, {1:N1} MiB en total. Los elementos actuales/protegidos nunca se ofrecen como desechables.') -f $storage.ArtifactCount,([double]$storage.TotalBytes/$mib))+' '+($parts -join ' | ')
    }
  }catch{$Script:TxtAIHelpStorageSummary.Text=$_.Exception.Message}
  try{
    $rows=@(Get-PMMInterruptedOperations|ForEach-Object{[pscustomobject]@{OperationId=[string]$_.OperationId;Kind=[string]$_.Kind;Display=([string]$_.Kind+' — '+[string]$_.LastStep+' — '+[string]$_.LastUtc)}})
    $Script:LstAIHelpInterrupted.ItemsSource=$rows
  }catch{$Script:LstAIHelpInterrupted.ItemsSource=@()}
}

function Refresh-PMMAIIOCandidates([string]$SessionId) {
  $selected='';try{$selected=[string]$Script:LstAIIOCandidates.SelectedValue}catch{}
  $rows=if($SessionId){@(Get-PMMAIIOCandidateRecords $SessionId)}else{@()}
  $Script:LstAIIOCandidates.SelectedValuePath='SolutionId';$Script:LstAIIOCandidates.ItemsSource=$rows
  if($selected){$Script:LstAIIOCandidates.SelectedValue=$selected}
  if($Script:LstAIIOCandidates.SelectedIndex -lt 0 -and $rows.Count -gt 0){$Script:LstAIIOCandidates.SelectedIndex=0}
  Update-PMMAIIOCandidateSelection
}

function Update-PMMAIIOCandidateSelection {
  $row=$Script:LstAIIOCandidates.SelectedItem
  if(-not$row){$Script:BtnAIIOOpenCandidate.IsEnabled=$false;$Script:BtnAIIOUseCandidate.IsEnabled=$false;$Script:TxtAIIOCandidateStatus.Text=L 'No staged candidate is selected.' 'No hay ningun candidato en staging seleccionado.';return}
  $Script:BtnAIIOOpenCandidate.IsEnabled=$true
  $current=$false
  if([bool]$row.CanUseInMerge){try{$ids=@($row.CaseIds|ForEach-Object{[string]$_}|Where-Object{$_});$current=($ids.Count -eq 1 -and -not[string]::IsNullOrWhiteSpace((Get-PMMAIIOCurrentReviewFolderForCaseId $ids[0])))}catch{$current=$false}}
  $Script:BtnAIIOUseCandidate.IsEnabled=(-not[bool]$Script:AIIOBusy -and [bool]$row.CanUseInMerge -and $current)
  $caseText=(@($row.CaseIds|ForEach-Object{[string]$_}|Where-Object{$_}) -join ', ')
  if([string]$row.InputSchema -eq 'PMM_MANUAL_SOLUTION_V1'){
    $state=if([string]$row.Status -eq 'AcceptedExperimental'){L 'Accepted into the local experimental solution store; runtime remains UNPROVEN until you validate the exact build in Palworld.' 'Aceptado en el almacen local de soluciones experimentales; el runtime sigue UNPROVEN hasta validar el build exacto en Palworld.'}elseif($current){L 'Structurally accepted and tied to a current exact case. It is still inactive.' 'Aceptado estructuralmente y ligado a un caso exacto vigente. Sigue inactivo.'}else{L 'The exact review case is stale or unavailable. Run Analyze before using this candidate.' 'El caso exacto de revision ya no esta vigente o disponible. Ejecuta Analizar antes de usar este candidato.'}
  }else{$state=L 'This candidate type is inspectable but cannot enter Merge in this build. It remains inactive.' 'Este tipo de candidato se puede inspeccionar, pero no puede entrar en Merge en este build. Sigue inactivo.'}
  $Script:TxtAIIOCandidateStatus.Text=((L '{0} | case {1} | {2}' '{0} | caso {1} | {2}') -f [string]$row.InputSchema,$caseText,$state)
}

function Refresh-PMMAIHelpUi([switch]$EnsureUnsupported) {
  if($EnsureUnsupported){try{[void](Get-PMMAIIOUnsupportedSession)}catch{Write-PMMLog ('AIIO Unsupported session warning: '+$_.Exception.Message)}}
  $diagnostics=@(Get-PMMDiagnosticCases);$sessions=@(Get-PMMAIIOSessions)
  $selectedDiagnostic='';try{$selectedDiagnostic=[string]$Script:LstAIHelpDiagnostics.SelectedValue}catch{}
  $selectedSession='';try{$selectedSession=[string]$Script:LstAIIOSessions.SelectedValue}catch{}
  $Script:LstAIHelpDiagnostics.SelectedValuePath='CaseId';$Script:LstAIHelpDiagnostics.ItemsSource=$diagnostics
  $Script:LstAIIOSessions.SelectedValuePath='SessionId';$Script:LstAIIOSessions.ItemsSource=$sessions
  if($selectedDiagnostic){$Script:LstAIHelpDiagnostics.SelectedValue=$selectedDiagnostic}elseif($diagnostics.Count -gt 0){$Script:LstAIHelpDiagnostics.SelectedIndex=0}
  $configured='';try{$configured=[string](Get-PMMConfig).AIIOActiveSession}catch{}
  if($selectedSession){$Script:LstAIIOSessions.SelectedValue=$selectedSession}elseif($configured){$Script:LstAIIOSessions.SelectedValue=$configured}elseif($sessions.Count -gt 0){$Script:LstAIIOSessions.SelectedIndex=0}
  Refresh-PMMAIIOCandidates ([string]$Script:LstAIIOSessions.SelectedValue)
  Refresh-PMMAIHelpKnowledge
  Refresh-PMMThemeEditorCatalog
  Refresh-PMMAIHelpBadge
  $hasSession=(-not[string]::IsNullOrWhiteSpace([string]$Script:LstAIIOSessions.SelectedValue))
  $busy=[bool]$Script:AIIOBusy
  $Script:BtnAIIONewSession.IsEnabled=-not$busy
  $Script:BtnAIIOPrepare.IsEnabled=-not$busy
  $Script:BtnAIIOImportResponse.IsEnabled=(-not$busy -and $hasSession)
  $Script:BtnAIIOArchive.IsEnabled=(-not$busy -and $hasSession)
  $Script:BtnAIHelpCleanup.IsEnabled=-not$busy
  $pending=0;if($hasSession -and -not$busy){try{$pending=@(Get-PMMAIIOPendingRequests ([string]$Script:LstAIIOSessions.SelectedValue)).Count}catch{$pending=0}}
  $Script:BtnAIIOContinue.IsEnabled=(-not$busy -and $hasSession -and $pending -gt 0)
  if($busy){$Script:BtnAIIOUseCandidate.IsEnabled=$false}
  $Script:AIHelpLoaded=$true
}

function Get-PMMSelectedAIIOSession {
  $row=$Script:LstAIIOSessions.SelectedItem
  if(-not$row){return $null}
  return (Set-PMMAIIOActiveSession ([string]$row.SessionId))
}

function Refresh-PMMThemeEditorCatalog {
  $selectedSource='';try{$selectedSource=[string]$Script:CmbThemeEditorSource.SelectedValue}catch{}
  $definitions=@(Get-PMMThemeDefinitions)
  $Script:CmbThemeEditorSource.ItemsSource=$definitions
  if($selectedSource){$Script:CmbThemeEditorSource.SelectedValue=$selectedSource}
  if($Script:CmbThemeEditorSource.SelectedIndex -lt 0){$crystal=@($definitions|Where-Object{[string]$_.Id -eq 'pmm-crystal'}|Select-Object -First 1);if($crystal.Count -gt 0){$Script:CmbThemeEditorSource.SelectedValue='pmm-crystal'}elseif($definitions.Count -gt 0){$Script:CmbThemeEditorSource.SelectedIndex=0}}
  $selectedDraft='';try{$selectedDraft=[string]$Script:LstThemeDrafts.SelectedValue}catch{}
  $drafts=@(Get-PMMThemeDrafts);$Script:LstThemeDrafts.SelectedValuePath='DraftId';$Script:LstThemeDrafts.ItemsSource=$drafts
  if($selectedDraft){$Script:LstThemeDrafts.SelectedValue=$selectedDraft}elseif($drafts.Count -gt 0){$Script:LstThemeDrafts.SelectedIndex=0}
}

function Get-PMMThemeDraftFieldValue($Draft,$Field) {
  $fieldKey=[string]$Field.Key
  if([string]$Field.Kind -eq 'Palette'){$palette=ConvertTo-PMMThemeDraftHashtable $Draft.Palette;return [string]$palette[$fieldKey]}
  $stateKey=[string]$Field.State;$partKey=[string]$Field.Part
  $flow=ConvertTo-PMMThemeDraftHashtable $Draft.ColorFlow;$state=ConvertTo-PMMThemeDraftHashtable $flow[$stateKey];return [string]$state[$partKey]
}

function Set-PMMThemeEditorSwatch($Button,[string]$Hex) {
  try{$Button.Background=[System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString((Convert-PMMThemeHexToWpf $Hex)))}catch{$Button.ClearValue([System.Windows.Controls.Control]::BackgroundProperty)}
}

function Show-PMMThemeImageOptions($Entry) {
  if(-not$Entry){return $null}
  $form=[System.Windows.Forms.Form]::new();$form.Text=L 'Image brush options' 'Opciones de imagen del brush';$form.Width=520;$form.Height=310;$form.StartPosition='CenterParent';$form.FormBorderStyle=[System.Windows.Forms.FormBorderStyle]::FixedDialog;$form.MaximizeBox=$false;$form.MinimizeBox=$false
  $labels=@((L 'Fit / stretch' 'Ajuste / stretch'),(L 'Alignment' 'Alineacion'),(L 'Tile mode' 'Modo mosaico'),(L 'Image opacity (%)' 'Opacidad de imagen (%)'),(L 'Overlay / tint (#RRGGBB or #RRGGBBAA)' 'Overlay / tinte (#RRGGBB o #RRGGBBAA)'))
  $controls=[Collections.Generic.List[object]]::new();$top=18
  foreach($text in $labels){$label=[System.Windows.Forms.Label]::new();$label.Left=18;$label.Top=$top+4;$label.Width=245;$label.Text=$text;[void]$form.Controls.Add($label);$top+=40}
  $stretch=[System.Windows.Forms.ComboBox]::new();$stretch.Left=270;$stretch.Top=16;$stretch.Width=210;$stretch.DropDownStyle='DropDownList';[void]$stretch.Items.AddRange(@('None','Fill','Uniform','UniformToFill'));$stretch.SelectedItem=[string]$Entry.stretch;if($stretch.SelectedIndex -lt 0){$stretch.SelectedItem='UniformToFill'}
  $align=[System.Windows.Forms.ComboBox]::new();$align.Left=270;$align.Top=56;$align.Width=210;$align.DropDownStyle='DropDownList';[void]$align.Items.AddRange(@('Center','Left','Right','Top','Bottom','TopLeft','TopRight','BottomLeft','BottomRight'));$align.SelectedItem=[string]$Entry.alignment;if($align.SelectedIndex -lt 0){$align.SelectedItem='Center'}
  $tile=[System.Windows.Forms.ComboBox]::new();$tile.Left=270;$tile.Top=96;$tile.Width=210;$tile.DropDownStyle='DropDownList';[void]$tile.Items.AddRange(@('None','Tile','FlipX','FlipY','FlipXY'));$tile.SelectedItem=[string]$Entry.tileMode;if($tile.SelectedIndex -lt 0){$tile.SelectedItem='None'}
  $opacity=[System.Windows.Forms.NumericUpDown]::new();$opacity.Left=270;$opacity.Top=136;$opacity.Width=210;$opacity.Minimum=0;$opacity.Maximum=100;$opacity.Value=[decimal]([Math]::Round([Math]::Max(0,[Math]::Min(1,[double]$Entry.opacity))*100))
  $overlay=[System.Windows.Forms.TextBox]::new();$overlay.Left=270;$overlay.Top=176;$overlay.Width=210;$overlay.Text=if(Test-PMMThemeHexColor ([string]$Entry.overlay)){[string]$Entry.overlay}else{'#00000000'}
  foreach($control in @($stretch,$align,$tile,$opacity,$overlay)){[void]$form.Controls.Add($control)}
  $ok=[System.Windows.Forms.Button]::new();$ok.Text='OK';$ok.Left=300;$ok.Top=220;$ok.Width=85;$ok.DialogResult=[System.Windows.Forms.DialogResult]::OK;$cancel=[System.Windows.Forms.Button]::new();$cancel.Text=L 'Cancel' 'Cancelar';$cancel.Left=395;$cancel.Top=220;$cancel.Width=85;$cancel.DialogResult=[System.Windows.Forms.DialogResult]::Cancel;[void]$form.Controls.Add($ok);[void]$form.Controls.Add($cancel);$form.AcceptButton=$ok;$form.CancelButton=$cancel
  if($form.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK){return $null}
  if(-not(Test-PMMThemeHexColor ([string]$overlay.Text))){throw 'Overlay color must be #RRGGBB or #RRGGBBAA.'}
  return [pscustomobject]@{stretch=[string]$stretch.SelectedItem;alignment=[string]$align.SelectedItem;tileMode=[string]$tile.SelectedItem;opacity=([double]$opacity.Value/100.0);overlay=([string]$overlay.Text).ToUpperInvariant()}
}

function Update-PMMThemeEditorDraftFromUi([switch]$Save) {
  $draft=$Script:ActiveThemeDraft;if(-not$draft){throw (L 'Create or load a draft first.' 'Crea o carga primero un borrador.')}
  $draft.Name=[string]$Script:TxtThemeEditorName.Text;$draft.ThemeId=[string]$Script:TxtThemeEditorId.Text;$draft.Base=[string]$Script:CmbThemeEditorBase.SelectedItem
  $palette=ConvertTo-PMMThemeDraftHashtable $draft.Palette;$flow=ConvertTo-PMMThemeDraftHashtable $draft.ColorFlow
  foreach($field in @(Get-PMMThemeEditorFields)){
    $fieldKey=[string]$field.Key;$row=$Script:ThemeEditorRowControls[$fieldKey];if(-not$row){continue};$value=([string]$row.TextBox.Text).Trim()
    if(-not(Test-PMMThemeHexColor $value)){throw ((L 'Invalid color in {0}: {1}' 'Color no valido en {0}: {1}') -f $fieldKey,$value)}
    if([string]$field.Kind -eq 'Palette'){$palette[$fieldKey]=$value}else{$stateKey=[string]$field.State;$partKey=[string]$field.Part;$state=ConvertTo-PMMThemeDraftHashtable $flow[$stateKey];$state[$partKey]=$value;$flow[$stateKey]=$state}
  }
  $draft.Palette=$palette;$draft.ColorFlow=$flow
  [void](Convert-PMMThemeDraftToDefinition $draft)
  if($Save){Save-PMMThemeDraft $draft|Out-Null;Refresh-PMMThemeEditorCatalog}
  return $draft
}

function Show-PMMThemeDraft($Draft) {
  if(-not$Draft){return}
  $Script:ActiveThemeDraft=$Draft;$Script:TxtThemeEditorName.Text=[string]$Draft.Name;$Script:TxtThemeEditorId.Text=[string]$Draft.ThemeId;$Script:CmbThemeEditorBase.SelectedItem=[string]$Draft.Base
  $Script:PnlThemeEditorRows.Children.Clear();$Script:ThemeEditorRowControls=@{};$lastGroup=''
  $brushes=ConvertTo-PMMThemeDraftHashtable $Draft.Brushes
  foreach($field in @(Get-PMMThemeEditorFields)){
    if([string]$field.Group -ne $lastGroup){$heading=[System.Windows.Controls.TextBlock]::new();$heading.Text=[string]$field.Group;$heading.FontWeight=[System.Windows.FontWeights]::SemiBold;$heading.FontSize=15;$heading.Margin=[System.Windows.Thickness]::new(0,9,0,4);[void]$Script:PnlThemeEditorRows.Children.Add($heading);$lastGroup=[string]$field.Group}
    $border=[System.Windows.Controls.Border]::new();$border.BorderBrush=$Window.Resources['CardBorder'];$border.BorderThickness=[System.Windows.Thickness]::new(1);$border.CornerRadius=[System.Windows.CornerRadius]::new(4);$border.Padding=[System.Windows.Thickness]::new(7);$border.Margin=[System.Windows.Thickness]::new(0,0,0,4)
    $grid=[System.Windows.Controls.Grid]::new();foreach($width in @('185','*','105','70','105','86','78')){$column=[System.Windows.Controls.ColumnDefinition]::new();$column.Width=if($width -eq '*'){[System.Windows.GridLength]::new(1,[System.Windows.GridUnitType]::Star)}else{[System.Windows.GridLength]::new([double]$width)};[void]$grid.ColumnDefinitions.Add($column)}
    $label=[System.Windows.Controls.StackPanel]::new();$name=[System.Windows.Controls.TextBlock]::new();$name.Text=[string]$field.Key;$name.FontWeight=[System.Windows.FontWeights]::SemiBold;$affected=[System.Windows.Controls.TextBlock]::new();$affected.Text=[string]$field.Affected;$affected.FontSize=10.5;$affected.Foreground=$Window.Resources['MutedText'];$affected.TextWrapping=[System.Windows.TextWrapping]::Wrap;[void]$label.Children.Add($name);[void]$label.Children.Add($affected);[System.Windows.Controls.Grid]::SetColumn($label,0);[void]$grid.Children.Add($label)
    $key=[string]$field.Key;$imageText=[System.Windows.Controls.TextBlock]::new();$imageText.VerticalAlignment=[System.Windows.VerticalAlignment]::Center;$imageText.Foreground=$Window.Resources['MutedText'];$imageText.TextTrimming=[System.Windows.TextTrimming]::CharacterEllipsis;$imageText.Margin=[System.Windows.Thickness]::new(5,0,5,0);$entry=$null;if($brushes.Contains($key)){$entry=$brushes[$key]};$imageText.Text=if($entry){[string]$entry.source}else{L 'Solid fallback' 'Color solido'};[System.Windows.Controls.Grid]::SetColumn($imageText,1);[void]$grid.Children.Add($imageText)
    $textBox=[System.Windows.Controls.TextBox]::new();$textBox.Text=Get-PMMThemeDraftFieldValue $Draft $field;$textBox.Margin=[System.Windows.Thickness]::new(2);[System.Windows.Controls.Grid]::SetColumn($textBox,2);[void]$grid.Children.Add($textBox)
    $pick=[System.Windows.Controls.Button]::new();$pick.Content=L 'Color...' 'Color...';$pick.Margin=[System.Windows.Thickness]::new(2);Set-PMMThemeEditorSwatch $pick $textBox.Text;[System.Windows.Controls.Grid]::SetColumn($pick,3);[void]$grid.Children.Add($pick)
    $upload=[System.Windows.Controls.Button]::new();$upload.Content=L 'Upload image' 'Subir imagen';$upload.Margin=[System.Windows.Thickness]::new(2);[System.Windows.Controls.Grid]::SetColumn($upload,4);[void]$grid.Children.Add($upload)
    $options=[System.Windows.Controls.Button]::new();$options.Content=L 'Image...' 'Imagen...';$options.Margin=[System.Windows.Thickness]::new(2);$options.IsEnabled=($null -ne $entry);[System.Windows.Controls.Grid]::SetColumn($options,5);[void]$grid.Children.Add($options)
    $remove=[System.Windows.Controls.Button]::new();$remove.Content=L 'Remove' 'Quitar';$remove.Margin=[System.Windows.Thickness]::new(2);$remove.IsEnabled=($null -ne $entry);[System.Windows.Controls.Grid]::SetColumn($remove,6);[void]$grid.Children.Add($remove)
    $pickHandler={try{$dialog=[System.Windows.Forms.ColorDialog]::new();$dialog.FullOpen=$true;if($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK){$hex=('#{0:X2}{1:X2}{2:X2}' -f $dialog.Color.R,$dialog.Color.G,$dialog.Color.B);$textBox.Text=$hex;Set-PMMThemeEditorSwatch $pick $hex}}catch{Handle-UIError $_ (L 'Choose theme color' 'Elegir color del tema')}}.GetNewClosure();$pick.Add_Click($pickHandler)
    $uploadHandler={try{[void](Update-PMMThemeEditorDraftFromUi -Save);$dialog=[Microsoft.Win32.OpenFileDialog]::new();$dialog.Filter='PNG/JPEG images (*.png;*.jpg;*.jpeg)|*.png;*.jpg;*.jpeg';if($dialog.ShowDialog() -eq $true){$Script:ActiveThemeDraft=Set-PMMThemeDraftImage $Script:ActiveThemeDraft $key ([string]$dialog.FileName);Show-PMMThemeDraft $Script:ActiveThemeDraft;$Script:TxtThemeEditorStatus.Text=(L 'Image copied into the draft. The fallback color remains required.' 'Imagen copiada al borrador. El color de respaldo sigue siendo obligatorio.')}}catch{Handle-UIError $_ (L 'Upload theme image' 'Subir imagen del tema')}}.GetNewClosure();$upload.Add_Click($uploadHandler)
    $optionsHandler={try{[void](Update-PMMThemeEditorDraftFromUi -Save);$all=ConvertTo-PMMThemeDraftHashtable $Script:ActiveThemeDraft.Brushes;if(-not$all.Contains($key)){return};$result=Show-PMMThemeImageOptions $all[$key];if($result){$entry=$all[$key];$entry.stretch=[string]$result.stretch;$entry.alignment=[string]$result.alignment;$entry.tileMode=[string]$result.tileMode;$entry.opacity=[double]$result.opacity;$entry.overlay=[string]$result.overlay;$all[$key]=$entry;$Script:ActiveThemeDraft.Brushes=$all;Save-PMMThemeDraft $Script:ActiveThemeDraft|Out-Null;Show-PMMThemeDraft $Script:ActiveThemeDraft}}catch{Handle-UIError $_ (L 'Edit image brush' 'Editar imagen del brush')}}.GetNewClosure();$options.Add_Click($optionsHandler)
    $removeHandler={try{$Script:ActiveThemeDraft=Remove-PMMThemeDraftImage $Script:ActiveThemeDraft $key;Show-PMMThemeDraft $Script:ActiveThemeDraft}catch{Handle-UIError $_ (L 'Remove theme image' 'Quitar imagen del tema')}}.GetNewClosure();$remove.Add_Click($removeHandler)
    $border.Child=$grid;[void]$Script:PnlThemeEditorRows.Children.Add($border);$Script:ThemeEditorRowControls[$key]=[pscustomobject]@{TextBox=$textBox;Swatch=$pick;ImageText=$imageText;ImageOptions=$options}
  }
  $Script:TxtThemeEditorStatus.Text=((L 'Draft loaded: {0}. Edit colors/images, then Save draft. Preview never changes the saved Settings choice.' 'Borrador cargado: {0}. Edita colores/imagenes y guarda el borrador. Vista previa nunca cambia la eleccion guardada en Opciones.') -f [string]$Draft.Name)
}

function Get-PMMThemeDraftPreviewDefinition($Draft) {
  $raw=Convert-PMMThemeDraftToDefinition $Draft
  return [pscustomobject]@{Id=[string]$raw.id;Name=[string]$raw.name;Schema=[string]$raw.schema;Base=[string]$raw.base;Palette=$raw.palette;ColorFlow=$raw.colorFlow;Brushes=$raw.brushes;ThemeRoot=(Get-PMMThemeDraftRoot ([string]$Draft.DraftId))}
}

function Initialize-PMMAIHelpUi {
  $Script:CmbAIHelpDiagnosticType.ItemsSource=@(
    [pscustomobject]@{Id='MOD_NOT_WORKING';Label=(L 'A mod does not work' 'Un mod no funciona')},[pscustomobject]@{Id='GAME_CRASH';Label=(L 'Palworld crash' 'Crash de Palworld')},[pscustomobject]@{Id='BUILD_FAILURE';Label=(L 'Build problem' 'Problema de Build')},[pscustomobject]@{Id='DEPLOY_FAILURE';Label=(L 'Deploy problem' 'Problema de Deploy')},[pscustomobject]@{Id='FIXLAB_FAILURE';Label=(L 'Fix Lab problem' 'Problema de Fix Lab')},[pscustomobject]@{Id='SAVE_PROBLEM';Label=(L 'Save/world problem' 'Problema de save/mundo')},[pscustomobject]@{Id='PERFORMANCE_PROBLEM';Label=(L 'Performance problem' 'Problema de rendimiento')},[pscustomobject]@{Id='FEATURE_MISSING';Label=(L 'Feature missing' 'Falta una funcion')},[pscustomobject]@{Id='UNKNOWN';Label=(L "I don't know" 'No lo se')})
  $Script:CmbAIHelpDiagnosticType.SelectedIndex=0
  $Script:CmbAIIOType.ItemsSource=@(
    [pscustomobject]@{Id='MOD_NOT_WORKING';Label=(L 'Investigate a mod' 'Investigar un mod')},[pscustomobject]@{Id='UNSUPPORTED_CONFLICT';Label=(L 'Resolve Unsupported conflicts' 'Resolver conflictos Unsupported')},[pscustomobject]@{Id='CREATE_MOD';Label=(L 'Create a mod' 'Crear un mod')},[pscustomobject]@{Id='MODIFY_MOD';Label=(L 'Modify a mod' 'Modificar un mod')},[pscustomobject]@{Id='PMM_DEVELOPMENT';Label=(L 'Develop or repair PMM' 'Desarrollar o reparar PMM')},[pscustomobject]@{Id='THEME_DESIGN';Label=(L 'Design a color scheme' 'Disenar un esquema de color')},[pscustomobject]@{Id='UNKNOWN';Label=(L 'General task' 'Tarea general')})
  $Script:CmbAIIOType.SelectedIndex=0
  $Script:CmbAIOTargetKind.ItemsSource=@(
    [pscustomobject]@{Id='Palworld';Label='Palworld'},[pscustomobject]@{Id='Mod';Label=(L 'Mod' 'Mod')},[pscustomobject]@{Id='CompatibilityBuild';Label=(L 'Compatibility build' 'Build de compatibilidad')},[pscustomobject]@{Id='FixLabResult';Label='Fix Lab result'},[pscustomobject]@{Id='Save';Label=(L 'Save/world' 'Save/mundo')},[pscustomobject]@{Id='Deployment';Label='Deployment'},[pscustomobject]@{Id='PMM';Label='PMM'},[pscustomobject]@{Id='Unknown';Label=(L "I don't know" 'No lo se')})
  $Script:CmbAIOTargetKind.SelectedIndex=0
  $Script:CmbThemeEditorBase.ItemsSource=@('Night','Light');$Script:CmbThemeEditorBase.SelectedItem='Night'
}

function Show-PMMBuildValidationDialog([string]$CurrentStatus) {
  $form=[System.Windows.Forms.Form]::new();$form.Text=L 'Validate exact compatibility merge' 'Validar merge de compatibilidad exacto';$form.Width=620;$form.Height=245;$form.StartPosition='CenterParent';$form.FormBorderStyle=[System.Windows.Forms.FormBorderStyle]::FixedDialog;$form.MaximizeBox=$false;$form.MinimizeBox=$false
  $label=[System.Windows.Forms.Label]::new();$label.Left=18;$label.Top=18;$label.Width=570;$label.Height=62
  $label.Text=if($CurrentStatus -eq 'LOCAL_PASS'){L 'This exact merge is marked as working. Has it stopped working?' 'Este merge exacto esta marcado como funcional. Ha dejado de funcionar?'}else{L 'Have you tested this exact merge in Palworld?' 'Has probado este merge exacto dentro de Palworld?'}
  $buttons=[Collections.Generic.List[object]]::new()
  $choices=if($CurrentStatus -eq 'LOCAL_PASS'){@(@('FAIL',(L 'Report a problem' 'Reportar un problema')),@('PASS_RECONFIRMED',(L 'No, it still works' 'No, sigue funcionando')),@('CANCEL',(L 'Cancel' 'Cancelar')))}else{@(@('PASS',(L 'Yes, it works' 'Si, funciona')),@('PARTIAL',(L 'Partially works' 'Funciona parcialmente')),@('FAIL',(L 'No, it failed' 'No, fallo')),@('CANCEL',(L 'Cancel' 'Cancelar')))}
  $left=18
  foreach($choice in $choices){$button=[System.Windows.Forms.Button]::new();$button.Text=[string]$choice[1];$button.Tag=[string]$choice[0];$button.Left=$left;$button.Top=105;$button.Width=135;$button.Height=38;$button.Add_Click({param($sender,$e)$form.Tag=[string]$sender.Tag;$form.Close()});[void]$form.Controls.Add($button);$buttons.Add($button);$left+=143}
  $note=[System.Windows.Forms.Label]::new();$note.Left=18;$note.Top=158;$note.Width=570;$note.Height=35;$note.Text=L 'The result is recorded locally against a deterministic buildId. It is not uploaded.' 'El resultado se registra localmente contra un buildId determinista. No se sube.'
  [void]$form.Controls.Add($label);[void]$form.Controls.Add($note);[void]$form.ShowDialog();return [string]$form.Tag
}

# Action-required hint duration: 0 disables the popup, 1..120 are seconds,
# and -1 means that the hint remains until the user closes it explicitly.
$Script:ActionHintOptions=[System.Collections.Generic.List[object]]::new()
$Script:ActionHintOptions.Add([pscustomobject]@{Label=(L '0 (Off)' '0 (Desactivado)');Value=0})
for($i=1;$i -le 120;$i++){$Script:ActionHintOptions.Add([pscustomobject]@{Label=($i.ToString()+' s');Value=$i})}
$Script:ActionHintOptions.Add([pscustomobject]@{Label=(L 'Infinite' 'Infinito');Value=-1})
$Script:CmbActionHintDuration.ItemsSource=$Script:ActionHintOptions

$Script:LibraryOrderOptions=@(
  [pscustomobject]@{Label=(L 'Alphabetical' 'Alfabetico');Mode='Alphabetical'},
  [pscustomobject]@{Label=(L 'Import date - oldest first' 'Fecha de importacion - antiguos primero');Mode='ImportedOldest'},
  [pscustomobject]@{Label=(L 'Import date - newest first' 'Fecha de importacion - recientes primero');Mode='ImportedNewest'},
  [pscustomobject]@{Label=(L 'Modified date - newest first' 'Fecha de modificacion - recientes primero');Mode='ModifiedNewest'}
)
$Script:CmbLibraryOrder.ItemsSource=$Script:LibraryOrderOptions
$Script:CmbLibraryOrder.DisplayMemberPath='Label';$Script:CmbLibraryOrder.SelectedValuePath='Mode';$Script:CmbLibraryOrder.SelectedValue='Alphabetical'


# ---------------------------------------------------------------------------
# Fix Lab lazy boundary.
#
# Fix Lab is optional and MUST NOT participate in application startup. The
# module is parsed/loaded only when the user opens the tab. Any failure remains
# inside the tab so a new repair feature can never take down Mods & Merge.
# ---------------------------------------------------------------------------
$Script:FixLabLoaded=$false
$Script:FixLabLoadAttempted=$false
$Script:FixLabHandlersBound=$false
$Script:FixLabUiRefreshing=$false
$Script:FixLabAttentionSignature=''
$Script:FixLabNoticeDismissed=$false
$Script:FixLabAttentionOrigin=''
# Persistent Fix Lab UI selection state. These must exist before any lazy
# refresh runs because StrictMode rejects reads of undefined script variables.
$Script:FixLabSelectedRecipeId=''
$Script:FixLabSelectedVariantId=''
$Script:FixLabSelectedBuildId=''
$Script:FixLabAnalyzePromptSkipSignature=''
$Script:FixLabOperationBusy=$false
$Script:FixLabCachedCandidates=@()
$Script:FixLabCachedAttentionCandidates=@()
$Script:FixLabCachedBuilt=@()
$Script:FixLabCachedBackups=@()
$Script:FixLabCachedGameReferenceState=$null
$Script:FixLabCachedBuildState=$null
$Script:FixLabLastRefreshUtc=[datetime]::MinValue
$Script:FixLabRefreshQueued=$false
$Script:FixLabRefreshForce=$false
$Script:FixLabRefreshIntervalSeconds=60

function Set-PMMFixLabAttentionVisual([array]$Candidates,[string]$Origin='') {
  $items=@($Candidates)
  $hashParts=[System.Collections.Generic.List[string]]::new()
  foreach($c in $items){foreach($src in @($c.Sources)){if($src -and $src.Hash){$hashParts.Add(([string]$src.Hash).ToLowerInvariant())}}}
  $sig=(@($hashParts.ToArray()|Sort-Object -Unique) -join '|')
  if($sig -ne [string]$Script:FixLabAttentionSignature){$Script:FixLabNoticeDismissed=$false;$Script:FixLabAttentionSignature=$sig}
  if(-not[string]::IsNullOrWhiteSpace($Origin)){$Script:FixLabAttentionOrigin=$Origin}

  $active=($items.Count -gt 0)
  if($Script:BrdFixLabBadge){$Script:BrdFixLabBadge.Visibility=if($active){[System.Windows.Visibility]::Visible}else{[System.Windows.Visibility]::Collapsed}}
  if($Script:TxtFixLabBadge){$Script:TxtFixLabBadge.Text=[string]$items.Count}
  if($Script:TabFixLab){
    if($active){
      $Script:TabFixLab.FontWeight='SemiBold'
      try{$Script:TabFixLab.Foreground=$Window.Resources['AccentHeadingAmber']}catch{}
      try{$Script:TabFixLab.Background=$Window.Resources['NoticeBackground']}catch{}
    }else{
      $Script:TabFixLab.ClearValue([System.Windows.Controls.Control]::ForegroundProperty)
      $Script:TabFixLab.ClearValue([System.Windows.Controls.Control]::BackgroundProperty)
      $Script:TabFixLab.ClearValue([System.Windows.Controls.Control]::FontWeightProperty)
    }
  }
  if($Script:BrdFixLabNotice){$Script:BrdFixLabNotice.Visibility=if($active -and -not$Script:FixLabNoticeDismissed){[System.Windows.Visibility]::Visible}else{[System.Windows.Visibility]::Collapsed}}
  if($active -and $Script:TxtFixLabNotice){
    $names=@($items|ForEach-Object{[string]$_.Name}) -join ', '
    if([string]$Script:FixLabAttentionOrigin -eq 'Analyze'){$Script:TxtFixLabNotice.Text=((L 'Analyze detected {0} repairable legacy case(s): {1}. Fix Lab has preselected the repair case.' 'Analyze detecto {0} caso(s) antiguos reparables: {1}. Fix Lab ha preseleccionado el caso de reparacion.') -f $items.Count,$names)}
    elseif([string]$Script:FixLabAttentionOrigin -eq 'Import'){$Script:TxtFixLabNotice.Text=((L 'Import detected {0} repairable legacy case(s): {1}. Fix Lab is ready.' 'Import detecto {0} caso(s) antiguos reparables: {1}. Fix Lab esta listo.') -f $items.Count,$names)}
    else{$Script:TxtFixLabNotice.Text=((L '{0} repairable legacy case(s) are available in Fix Lab: {1}.' 'Hay {0} caso(s) antiguos reparables disponibles en Fix Lab: {1}.') -f $items.Count,$names)}
  }
}

function Update-PMMFixLabAttentionFromLibrary([string]$Origin='') {
  try{
    if(-not(Initialize-PMMFixLabFeature)){return}
    $candidates=@(Get-PMMFixLabDiscoveryCandidates)
    if($candidates.Count -gt 0 -and [string]::IsNullOrWhiteSpace([string]$Script:FixLabSelectedRecipeId)){$Script:FixLabSelectedRecipeId=[string]$candidates[0].RecipeId;$Script:FixLabSelectedVariantId=''}
    Set-PMMFixLabAttentionVisual $candidates $Origin
    Refresh-PMMFixLabUI
  }catch{Write-PMMLog ('Fix Lab notification refresh failed: '+$_.Exception.Message)}
}

function New-PMMFixLabUiCollection([array]$Items) {
  $list=[System.Collections.ArrayList]::new()
  foreach($item in @($Items)){if($null -ne $item){[void]$list.Add($item)}}
  # Do not let PowerShell enumerate the ArrayList on function return. Without
  # this, a one-row list is emitted as a scalar PSCustomObject and WPF throws
  # when assigning it to ItemsSource because ItemsSource requires IEnumerable.
  return ,$list
}

function Set-PMMFixLabControlsEnabled([bool]$Enabled) {
  foreach($b in @(
    $Script:BtnFixLabOpenRoot,$Script:BtnFixLabBuildReference,$Script:BtnFixLabOpenReference,$Script:BtnFixLabCreateHandoff,
    $Script:BtnFixLabDiscover,$Script:BtnFixLabRefreshDashboard,$Script:BtnFixLabRevertBackup,$Script:BtnFixLabOpenBackupFolder,$Script:BtnFixLabIgnoreSource,$Script:BtnFixLabDeleteSource,$Script:BtnFixLabClearIgnored,$Script:BtnFixLabApplyBuilt,$Script:BtnFixLabRepair,$Script:BtnFixLabDismissNotice
  )){if($b){$b.IsEnabled=$Enabled}}
}

function Set-PMMFixLabUnavailable([string]$Message) {
  Set-PMMFixLabControlsEnabled $false
  if($Script:TxtFixLabCandidate){$Script:TxtFixLabCandidate.Text=L 'Fix Lab could not be loaded. Mods & Merge remains usable.' 'Fix Lab no pudo cargarse. Mods & Merge sigue disponible.'}
  if($Script:TxtFixLabRepairState){$Script:TxtFixLabRepairState.Text=[string]$Message}
  if($Script:TxtFixLabResult){$Script:TxtFixLabResult.Text=''}
}

function Get-PMMFixLabSelectedCandidate {
  if($Script:LstFixLabCandidates -and $Script:LstFixLabCandidates.SelectedItem){return $Script:LstFixLabCandidates.SelectedItem}
  if(-not[string]::IsNullOrWhiteSpace([string]$Script:FixLabSelectedRecipeId)){
    $cached=@($Script:FixLabCachedCandidates|Where-Object{[string]$_.RecipeId -ieq [string]$Script:FixLabSelectedRecipeId}|Select-Object -First 1)
    if($cached.Count -gt 0){return $cached[0]}
  }
  return $null
}

function Test-PMMFixLabBuiltDeployAllowed($Built) {
  if(-not$Built){return $false}
  if($Built.PSObject.Properties.Name -contains 'DeployAllowed'){return [bool]$Built.DeployAllowed}
  return $true
}

function Get-PMMFixLabBuiltDeploymentNote($Built) {
  if(-not$Built){return ''}
  if($Built.PSObject.Properties.Name -contains 'DeploymentNote'){return [string]$Built.DeploymentNote}
  return ''
}

function Get-PMMFixLabBuiltOutputClass($Built) {
  if(-not$Built){return ''}
  if($Built.PSObject.Properties.Name -contains 'OutputClass'){return [string]$Built.OutputClass}
  if(Test-PMMFixLabBuiltDeployAllowed $Built){return 'experimental-repair'}
  return 'engine-test'
}

function Update-PMMFixLabDeployButtonPresentation($Built) {
  if(-not$Script:BtnFixLabApplyBuilt){return}
  if(-not$Built){
    $Script:BtnFixLabApplyBuilt.Content=L 'Apply Fix' 'Aplicar Fix'
    $Script:BtnFixLabApplyBuilt.ToolTip=L 'Select a deployable built repair output.' 'Selecciona una salida reparada desplegable.'
    return
  }
  if(($Built.PSObject.Properties.Name -contains 'Applied') -and [bool]$Built.Applied){
    $Script:BtnFixLabApplyBuilt.Content=L 'Applied' 'Aplicado'
    $Script:BtnFixLabApplyBuilt.ToolTip=L 'This repaired output is already installed. The next workflow action is Analyze.' 'Esta salida reparada ya esta instalada. La siguiente accion del flujo es Analyze.'
    return
  }
  if(Test-PMMFixLabBuiltDeployAllowed $Built){
    $Script:BtnFixLabApplyBuilt.Content=L 'Apply Fix' 'Aplicar Fix'
    if((Get-PMMFixLabBuiltOutputClass $Built) -ieq 'runtime-proven-repair'){
      $Script:BtnFixLabApplyBuilt.ToolTip=L 'Runtime-proven repair. Archive the recognized legacy source and install this repaired PAK.' 'Reparacion probada en runtime. Archiva la fuente antigua reconocida e instala este PAK reparado.'
    }else{
      $Script:BtnFixLabApplyBuilt.ToolTip=L 'Deployable repair. See the confidence level in Built outputs for the evidence currently recorded by Fix Lab.' 'Reparacion desplegable. Consulta el nivel de confianza en Built outputs para ver la evidencia registrada actualmente por Fix Lab.'
    }
  }else{
    $Script:BtnFixLabApplyBuilt.Content=L 'Engine test - no deploy' 'Prueba de motor - sin deploy'
    $note=Get-PMMFixLabBuiltDeploymentNote $Built
    if([string]::IsNullOrWhiteSpace($note)){$note=L 'This output validates engine primitives only and is not a finished repair.' 'Esta salida solo valida primitivas del motor y no es una reparacion final.'}
    $Script:BtnFixLabApplyBuilt.ToolTip=$note
  }
}

function Refresh-PMMFixLabUI {
  if(-not$Script:FixLabLoaded -or $Script:FixLabUiRefreshing){return}
  $Script:FixLabUiRefreshing=$true
  try{
    $selectedRecipe=[string]$Script:FixLabSelectedRecipeId
    if($Script:LstFixLabCandidates -and $Script:LstFixLabCandidates.SelectedItem){$selectedRecipe=[string]$Script:LstFixLabCandidates.SelectedItem.RecipeId}
    $selectedBuild=if($Script:LstFixLabBuiltFixes -and $Script:LstFixLabBuiltFixes.SelectedItem){[string]$Script:LstFixLabBuiltFixes.SelectedItem.BuildId}else{[string]$Script:FixLabSelectedBuildId}

    # Build one filesystem snapshot and derive the attention subset from it.
    # RC23 performed two complete library discoveries plus a second backup scan
    # every time this dashboard refreshed.
    $backups=@(Get-PMMFixLabBackups)
    $candidates=@(Get-PMMFixLabDiscoveryCandidates -IncludeBackups -BackupRows $backups)
    $attentionCandidates=@($candidates|Where-Object{$row=$_;@($row.Sources|Where-Object{[string]$_.Origin -eq 'Library'}).Count -gt 0})
    $Script:FixLabCachedCandidates=@($candidates)
    $Script:FixLabCachedAttentionCandidates=@($attentionCandidates)
    if($Script:TxtFixLabCandidateCount){$Script:TxtFixLabCandidateCount.Text=((L '{0} candidate(s)' '{0} candidato(s)') -f $candidates.Count)}
    $Script:LstFixLabCandidates.ItemsSource=(New-PMMFixLabUiCollection $candidates)
    if(-not[string]::IsNullOrWhiteSpace($selectedRecipe)){
      $candidate=@($candidates|Where-Object{[string]$_.RecipeId -ieq $selectedRecipe}|Select-Object -First 1)[0]
      if($candidate){$Script:LstFixLabCandidates.SelectedValue=[string]$candidate.RecipeId;$Script:FixLabSelectedRecipeId=[string]$candidate.RecipeId}
    }
    if(-not$Script:LstFixLabCandidates.SelectedItem -and $candidates.Count -gt 0){$Script:LstFixLabCandidates.SelectedIndex=0;$Script:FixLabSelectedRecipeId=[string]$candidates[0].RecipeId}

    $Script:FixLabCachedBackups=@($backups)
    if($Script:TxtFixLabBackupCount){$Script:TxtFixLabBackupCount.Text=((L '{0} case backup(s)' '{0} backup(s) de caso') -f $backups.Count)}
    $Script:LstFixLabBackups.ItemsSource=(New-PMMFixLabUiCollection $backups)
    if($backups.Count -eq 1){$Script:LstFixLabBackups.SelectedIndex=0}
    $hasBackup=($null -ne $Script:LstFixLabBackups.SelectedItem)
    $Script:BtnFixLabRevertBackup.IsEnabled=$hasBackup
    if($Script:BtnFixLabOpenBackupFolder){$Script:BtnFixLabOpenBackupFolder.IsEnabled=$hasBackup}

    $built=@(Get-PMMFixLabBuiltOutputs)
    $Script:FixLabCachedBuilt=@($built)
    if($Script:TxtFixLabBuiltCount){$Script:TxtFixLabBuiltCount.Text=((L '{0} variant(s)' '{0} variante(s)') -f $built.Count)}
    $Script:LstFixLabBuiltFixes.ItemsSource=(New-PMMFixLabUiCollection $built)
    if(-not[string]::IsNullOrWhiteSpace($selectedBuild)){
      $b=@($built|Where-Object{[string]$_.BuildId -ieq $selectedBuild}|Select-Object -First 1)[0]
      if($b){$Script:LstFixLabBuiltFixes.SelectedValue=[string]$b.BuildId;$Script:FixLabSelectedBuildId=[string]$b.BuildId}
    }
    $selectedBuilt=$Script:LstFixLabBuiltFixes.SelectedItem
    $Script:BtnFixLabApplyBuilt.IsEnabled=(-not[bool]$Script:FixLabOperationBusy -and $selectedBuilt -and -not[bool]$selectedBuilt.Applied -and (Test-PMMFixLabBuiltDeployAllowed $selectedBuilt))
    Update-PMMFixLabDeployButtonPresentation $selectedBuilt

    $candidate=Get-PMMFixLabSelectedCandidate
    $candidateBuildState=$null
    if($candidate){
      $recipe=Get-PMMFixLabRecipe ([string]$candidate.RecipeId)
      $Script:TxtFixLabCandidate.Text=((L 'Selected case: {0}`nDetected source mods: {1}' 'Caso seleccionado: {0}`nMods fuente detectados: {1}') -f [string]$candidate.Name,[string]$candidate.SourceNames)
      if($Script:TxtFixLabLegacySource){$Script:TxtFixLabLegacySource.Text=[string]$candidate.SourceNames}
      $strategies=@($recipe.repairStrategies)
      if($Script:TxtFixLabModules){$Script:TxtFixLabModules.Text=((L '{0} repair strategies' '{0} estrategias de reparacion') -f $strategies.Count)}
      $variantRows=[System.Collections.Generic.List[object]]::new()
      foreach($v in @($recipe.variants)){$variantRows.Add([pscustomobject]@{Id=[string]$v.id;Label=[string]$v.label;Description=[string]$v.description;RuntimeStatus=[string]$v.runtimeStatus;BuildStatus=[string]$v.buildStatus;Display=([string]$v.label+' | '+[string]$v.runtimeStatus)})}
      $Script:CmbFixLabVariant.ItemsSource=(New-PMMFixLabUiCollection $variantRows.ToArray())
      $wanted=[string]$Script:FixLabSelectedVariantId
      # A recipe with exactly one output is safe to select automatically. With
      # multiple cosmetic/behavior outputs PMM must stop and let the user pick.
      if([string]::IsNullOrWhiteSpace($wanted) -and $variantRows.Count -eq 1){$wanted=[string]$variantRows[0].Id}
      if(-not[string]::IsNullOrWhiteSpace($wanted)){$Script:CmbFixLabVariant.SelectedValue=$wanted}else{$Script:CmbFixLabVariant.SelectedIndex=-1}
      if($Script:CmbFixLabVariant.SelectedItem){
        $Script:FixLabSelectedVariantId=[string]$Script:CmbFixLabVariant.SelectedItem.Id
        $Script:TxtFixLabVariantDescription.Text=[string]$Script:CmbFixLabVariant.SelectedItem.Description
        if($Script:TxtFixLabOutputSize){
          $existing=@($built|Where-Object{[string]$_.RecipeId -ieq [string]$candidate.RecipeId -and [string]$_.VariantId -ieq [string]$Script:FixLabSelectedVariantId}|Select-Object -First 1)[0]
          $Script:TxtFixLabOutputSize.Text=if($existing){[string]$existing.SizeMb}else{L 'Pending build' 'Pendiente de construir'}
        }
      }else{
        $Script:FixLabSelectedVariantId=''
        $Script:TxtFixLabVariantDescription.Text=if($variantRows.Count -gt 1){L 'Choose one output. PMM will not choose a cosmetic/behavior variant for you.' 'Elige una salida. PMM no elegira por ti una variante cosmetica/de comportamiento.'}else{''}
        if($Script:TxtFixLabOutputSize){$Script:TxtFixLabOutputSize.Text=L 'Pending selection' 'Pendiente de seleccion'}
      }
      $candidateBuildState=Get-PMMFixLabCandidateBuildState $candidate ([string]$Script:FixLabSelectedVariantId)
      $Script:FixLabCachedBuildState=$candidateBuildState
      $Script:TxtFixLabRepairState.Text=[string]$candidateBuildState.Reason
      $Script:BtnFixLabRepair.IsEnabled=[bool]$candidateBuildState.Ready
      $Script:BtnFixLabCreateHandoff.IsEnabled=$true
    }else{
      $Script:TxtFixLabCandidate.Text=L 'No repairable imported mods detected. Press ANALYZE FIXABLE MODS after importing legacy mods.' 'No se detectaron mods importados reparables. Pulsa ANALYZE FIXABLE MODS despues de importar mods antiguos.'
      $Script:CmbFixLabVariant.ItemsSource=(New-PMMFixLabUiCollection @())
      if($Script:TxtFixLabLegacySource){$Script:TxtFixLabLegacySource.Text='-'}
      if($Script:TxtFixLabModules){$Script:TxtFixLabModules.Text='-'}
      if($Script:TxtFixLabOutputSize){$Script:TxtFixLabOutputSize.Text=L 'Pending build' 'Pendiente de construir'}
      $Script:TxtFixLabVariantDescription.Text=''
      $Script:FixLabCachedBuildState=$null
      $Script:TxtFixLabRepairState.Text=L 'Fix Lab Analyze only searches for mods with a known repair recipe.' 'Fix Lab Analyze solo busca mods con una receta de reparacion conocida.'
      $Script:BtnFixLabRepair.IsEnabled=$false;$Script:BtnFixLabCreateHandoff.IsEnabled=$false
    }

    try{
      $gr=Get-PMMGameReferenceState
      $Script:FixLabCachedGameReferenceState=$gr
      if([string]$gr.Status -eq 'Current'){$Script:TxtFixLabGameReference.Text=((L 'Current Game Reference: READY | {0} families | mappings {1}' 'Game Reference actual: LISTA | {0} familias | mappings {1}') -f [int]$gr.FamilyCount,[string]$gr.Identity.MappingsSha256)}
      else{$Script:TxtFixLabGameReference.Text=((L 'Current Game Reference: {0}. Repair recipes may require a fresh reference.' 'Game Reference actual: {0}. Las recetas pueden requerir una referencia actualizada.') -f [string]$gr.Status)}
    }catch{$Script:FixLabCachedGameReferenceState=$null;$Script:TxtFixLabGameReference.Text=L 'Game Reference status unavailable.' 'Estado de Game Reference no disponible.'}

    # The legacy job/debug controls are hidden and can be expensive to hydrate.
    # Populate them only when the Advanced card is actually expanded. Normal
    # navigation must never scan job inventories that the user cannot see.
    if($Script:ExpFixLabAdvanced -and [bool]$Script:ExpFixLabAdvanced.IsExpanded){
      $jobs=@(Get-PMMFixLabJobs);$Script:CmbFixLabJob.ItemsSource=(New-PMMFixLabUiCollection $jobs)
      $job=Get-PMMFixLabCurrentJob
      if($job){
        $Script:TxtFixLabPrimary.Text=[string]$job.Primary.Name
        $Script:LstFixLabRelated.ItemsSource=(New-PMMFixLabUiCollection @($job.Related))
        $Script:TxtFixLabAnalysis.Text=if($job.Analysis){[string]$job.Analysis.Summary}else{''}
        $pakRows=@()
        if($job.Analysis){$pakRows=@($job.Analysis.PakInventory)}
        $Script:DgFixLabPakInventory.ItemsSource=(New-PMMFixLabUiCollection $pakRows)
        $matches=[System.Collections.Generic.List[object]]::new()
        foreach($m in @($job.Analysis.RecipeMatches)){$matches.Add([pscustomobject]@{RecipeId=[string]$m.RecipeId;Name=[string]$m.Name})}
        $Script:CmbFixLabRecipe.ItemsSource=(New-PMMFixLabUiCollection $matches.ToArray())
        $Script:TxtFixLabBuildState.Text=[string](Get-PMMFixLabBuildState $job).Reason
        if($job.Build){$Script:TxtFixLabResult.Text=((L 'Last job result: {0} | {1}' 'Ultimo resultado: {0} | {1}') -f [string]$job.Build.Status,[string]$job.Build.Validation)}
      }
    }

    Set-PMMFixLabControlsEnabled (-not[bool]$Script:FixLabOperationBusy)
    # A shared Game Reference worker can be running while Fix Lab refreshes.
    # Keep the Fix Lab reference button locked and repaint its ColorFlow
    # progress after the generic control refresh so it cannot be started twice.
    $grRunningNow=$false;try{$grRunningNow=($Script:GameReferenceProcess -and -not$Script:GameReferenceProcess.HasExited)}catch{}
    if($grRunningNow -and $Script:BtnFixLabBuildReference){
      $Script:BtnFixLabBuildReference.IsEnabled=$false
      $grFraction=[double]$Script:GameReferenceProgressPercent/100.0
      Set-PMMWorkflowButtonProgress $Script:BtnFixLabBuildReference 'Build' $grFraction ([string]$Script:GameReferenceProgressMessage) -Indeterminate:([bool]$Script:GameReferenceProgressIndeterminate)
    }
    $repairReady=$false;try{if($candidateBuildState){$repairReady=[bool]$candidateBuildState.Ready}}catch{}
    $Script:BtnFixLabRepair.IsEnabled=(-not[bool]$Script:FixLabOperationBusy -and $repairReady)
    $selectedBuilt=$Script:LstFixLabBuiltFixes.SelectedItem
    $Script:BtnFixLabApplyBuilt.IsEnabled=(-not[bool]$Script:FixLabOperationBusy -and $selectedBuilt -and -not[bool]$selectedBuilt.Applied -and (Test-PMMFixLabBuiltDeployAllowed $selectedBuilt))
    Update-PMMFixLabDeployButtonPresentation $selectedBuilt
    $backupSelected=($null -ne $Script:LstFixLabBackups.SelectedItem)
    $Script:BtnFixLabRevertBackup.IsEnabled=(-not[bool]$Script:FixLabOperationBusy -and $backupSelected)
    if($Script:BtnFixLabOpenBackupFolder){$Script:BtnFixLabOpenBackupFolder.IsEnabled=(-not[bool]$Script:FixLabOperationBusy -and $backupSelected)}
    $liveSource=$false
    if($candidate){foreach($src in @($candidate.Sources)){if($src -and [string]$src.Origin -ne 'FixLabBackup' -and [string]$src.Origin -ne 'Backup'){$liveSource=$true;break}}}
    if($Script:BtnFixLabIgnoreSource){$Script:BtnFixLabIgnoreSource.IsEnabled=(-not[bool]$Script:FixLabOperationBusy -and $liveSource)}
    if($Script:BtnFixLabDeleteSource){$Script:BtnFixLabDeleteSource.IsEnabled=(-not[bool]$Script:FixLabOperationBusy -and $liveSource)}
    $ignoredNow=@(Get-PMMFixLabIgnoredSourceRecords)
    if($Script:TxtFixLabIgnoredCount){$Script:TxtFixLabIgnoredCount.Text=((L '{0} ignored source(s)' '{0} fuente(s) ignorada(s)') -f $ignoredNow.Count)}
    if($Script:BtnFixLabClearIgnored){$Script:BtnFixLabClearIgnored.IsEnabled=(-not[bool]$Script:FixLabOperationBusy -and $ignoredNow.Count -gt 0)}
    try{Set-PMMFixLabAttentionVisual $attentionCandidates ''}catch{}
    $Script:FixLabLastRefreshUtc=[datetime]::UtcNow
  }finally{$Script:FixLabUiRefreshing=$false}
}

function Update-PMMFixLabVariantSelectionUi {
  param($Variant=$null)
  if(-not$Script:FixLabLoaded){return}
  $candidate=Get-PMMFixLabSelectedCandidate
  if(-not$candidate){return}
  if(-not$Variant -and $Script:CmbFixLabVariant){$Variant=$Script:CmbFixLabVariant.SelectedItem}
  if($Variant){
    $Script:FixLabSelectedVariantId=[string]$Variant.Id
    if($Script:TxtFixLabVariantDescription){$Script:TxtFixLabVariantDescription.Text=[string]$Variant.Description}
    if($Script:TxtFixLabOutputSize){
      $existing=@($Script:FixLabCachedBuilt|Where-Object{[string]$_.RecipeId -ieq [string]$candidate.RecipeId -and [string]$_.VariantId -ieq [string]$Script:FixLabSelectedVariantId}|Select-Object -First 1)
      $Script:TxtFixLabOutputSize.Text=if($existing.Count -gt 0){[string]$existing[0].SizeMb}else{L 'Pending build' 'Pendiente de construir'}
    }
  }else{
    $Script:FixLabSelectedVariantId=''
    if($Script:TxtFixLabVariantDescription){$Script:TxtFixLabVariantDescription.Text=L 'Choose one output. PMM will not choose a cosmetic/behavior variant for you.' 'Elige una salida. PMM no elegira por ti una variante cosmetica/de comportamiento.'}
    if($Script:TxtFixLabOutputSize){$Script:TxtFixLabOutputSize.Text=L 'Pending selection' 'Pendiente de seleccion'}
  }
  $state=Get-PMMFixLabCandidateBuildState $candidate ([string]$Script:FixLabSelectedVariantId)
  $Script:FixLabCachedBuildState=$state
  if($Script:TxtFixLabRepairState){$Script:TxtFixLabRepairState.Text=[string]$state.Reason}
  if($Script:BtnFixLabRepair){$Script:BtnFixLabRepair.IsEnabled=(-not[bool]$Script:FixLabOperationBusy -and [bool]$state.Ready)}
  try{Set-PMMFixLabAttentionVisual @($Script:FixLabCachedAttentionCandidates) ''}catch{}
}

function Update-PMMFixLabCandidateSelectionUi {
  if(-not$Script:FixLabLoaded){return}
  $candidate=Get-PMMFixLabSelectedCandidate
  if(-not$candidate){return}
  $recipe=Get-PMMFixLabRecipe ([string]$candidate.RecipeId)
  if(-not$recipe){return}
  if($Script:TxtFixLabCandidate){$Script:TxtFixLabCandidate.Text=((L 'Selected case: {0}`nDetected source mods: {1}' 'Caso seleccionado: {0}`nMods fuente detectados: {1}') -f [string]$candidate.Name,[string]$candidate.SourceNames)}
  if($Script:TxtFixLabLegacySource){$Script:TxtFixLabLegacySource.Text=[string]$candidate.SourceNames}
  if($Script:TxtFixLabModules){$Script:TxtFixLabModules.Text=((L '{0} repair strategies' '{0} estrategias de reparacion') -f @($recipe.repairStrategies).Count)}
  $rows=[System.Collections.Generic.List[object]]::new()
  foreach($v in @($recipe.variants)){$rows.Add([pscustomobject]@{Id=[string]$v.id;Label=[string]$v.label;Description=[string]$v.description;RuntimeStatus=[string]$v.runtimeStatus;BuildStatus=[string]$v.buildStatus;Display=([string]$v.label+' | '+[string]$v.runtimeStatus)})}
  $previous=[string]$Script:FixLabSelectedVariantId
  $was=[bool]$Script:FixLabUiRefreshing
  $Script:FixLabUiRefreshing=$true
  try{
    $Script:CmbFixLabVariant.ItemsSource=(New-PMMFixLabUiCollection $rows.ToArray())
    if(-not[string]::IsNullOrWhiteSpace($previous)){$Script:CmbFixLabVariant.SelectedValue=$previous}
    elseif($rows.Count -eq 1){$Script:CmbFixLabVariant.SelectedIndex=0}
    else{$Script:CmbFixLabVariant.SelectedIndex=-1}
  }finally{$Script:FixLabUiRefreshing=$was}
  Update-PMMFixLabVariantSelectionUi $Script:CmbFixLabVariant.SelectedItem
}

function Queue-PMMFixLabUiRefresh {
  param([switch]$Force)
  if($Force){$Script:FixLabRefreshForce=$true}
  if($Script:FixLabRefreshQueued){return}
  $Script:FixLabRefreshQueued=$true
  $callback=[System.Action]{
    $Script:FixLabRefreshQueued=$false
    $forceNow=[bool]$Script:FixLabRefreshForce
    $Script:FixLabRefreshForce=$false
    try{
      # Let WPF paint the selected tab/expanded card first. The refresh still
      # runs on the dispatcher because it binds WPF controls, but navigation is
      # no longer blocked inside SelectionChanged or Expander.Expanded.
      if($Script:MainTabs.SelectedItem -ne $Script:TabFixLab -and -not$forceNow){return}
      $stateUpdated=$false
      if(-not$Script:FixLabLoaded){
        $stateUpdated=[bool](Initialize-PMMFixLabFeature)
      }elseif(-not[bool]$Script:FixLabOperationBusy){
        $age=[TimeSpan]::MaxValue
        try{if($Script:FixLabLastRefreshUtc){$age=[datetime]::UtcNow-[datetime]$Script:FixLabLastRefreshUtc}}catch{}
        if($forceNow -or $age.TotalSeconds -ge [double]$Script:FixLabRefreshIntervalSeconds){Refresh-PMMFixLabUI;$stateUpdated=$true}
        else{try{Set-PMMFixLabAttentionVisual @($Script:FixLabCachedAttentionCandidates) ''}catch{}}
      }
      if($stateUpdated){try{Update-PMMGuidedActionState}catch{}}
    }catch{Set-PMMFixLabUnavailable $_.Exception.Message}
  }
  try{[void]$Window.Dispatcher.BeginInvoke([System.Windows.Threading.DispatcherPriority]::ContextIdle,$callback)}
  catch{
    $Script:FixLabRefreshQueued=$false
    $Script:FixLabRefreshForce=$false
    throw
  }
}

function Register-PMMFixLabHandlers {
  if($Script:FixLabHandlersBound){return}
  $Script:FixLabHandlersBound=$true
  $Script:BtnFixLabOpenRoot.Add_Click({try{Initialize-PMMFixLab;Start-Process explorer.exe -ArgumentList ('"'+(Get-PMMPath 'FixLab')+'"')}catch{Handle-UIError $_ (L 'Open Fix Lab folder' 'Abrir carpeta Fix Lab')}})
  if($Script:ExpFixLabAdvanced){$Script:ExpFixLabAdvanced.Add_Expanded({try{Queue-PMMFixLabUiRefresh -Force}catch{}})}
  $refreshAction={try{$Script:TxtStatus.Text=L 'Refreshing Fix Lab after the interface update...' 'Actualizando Fix Lab despues de mostrar la interfaz...';Queue-PMMFixLabUiRefresh -Force}catch{Handle-UIError $_ (L 'Refresh Fix Lab' 'Actualizar Fix Lab')}}
  $Script:BtnFixLabDiscover.Add_Click({try{$Script:FixLabNoticeDismissed=$false;Queue-PMMFixLabUiRefresh -Force}catch{Handle-UIError $_ (L 'Analyze Fixable Mods' 'Analizar mods reparables')}});$Script:BtnFixLabRefreshDashboard.Add_Click($refreshAction)
  $Script:BtnFixLabDismissNotice.Add_Click({$Script:FixLabNoticeDismissed=$true;if($Script:BrdFixLabNotice){$Script:BrdFixLabNotice.Visibility=[System.Windows.Visibility]::Collapsed}})
  $Script:LstFixLabCandidates.Add_SelectionChanged({if($Script:FixLabUiRefreshing){return};try{$c=$Script:LstFixLabCandidates.SelectedItem;if($c){$Script:FixLabSelectedRecipeId=[string]$c.RecipeId;$Script:FixLabSelectedVariantId='';Update-PMMFixLabCandidateSelectionUi}}catch{Handle-UIError $_ (L 'Choose repairable mod' 'Elegir mod reparable')}})
  $Script:CmbFixLabVariant.Add_SelectionChanged({if($Script:FixLabUiRefreshing){return};try{$v=$Script:CmbFixLabVariant.SelectedItem;Update-PMMFixLabVariantSelectionUi $v;try{Update-PMMGuidedActionState}catch{};if($v){if($Script:AutoPipelineActive){Invoke-PMMAutoContinue}elseif([bool]$Script:TglAutoMode.IsChecked){Start-PMMAutoPipeline;Invoke-PMMAutoContinue}}}catch{Handle-UIError $_ (L 'Choose Fix Lab output' 'Elegir salida Fix Lab')}})
  $Script:LstFixLabBuiltFixes.Add_SelectionChanged({if($Script:FixLabUiRefreshing){return};try{$b=$Script:LstFixLabBuiltFixes.SelectedItem;$Script:FixLabSelectedBuildId=if($b){[string]$b.BuildId}else{''};$Script:BtnFixLabApplyBuilt.IsEnabled=(-not[bool]$Script:FixLabOperationBusy -and $b -and -not[bool]$b.Applied -and (Test-PMMFixLabBuiltDeployAllowed $b));Update-PMMFixLabDeployButtonPresentation $b;if($b -and -not(Test-PMMFixLabBuiltDeployAllowed $b)){$Script:TxtStatus.Text=(Get-PMMFixLabBuiltDeploymentNote $b)}}catch{}})
  $Script:LstFixLabBackups.Add_SelectionChanged({if($Script:FixLabUiRefreshing){return};$has=($null -ne $Script:LstFixLabBackups.SelectedItem);$Script:BtnFixLabRevertBackup.IsEnabled=$has;if($Script:BtnFixLabOpenBackupFolder){$Script:BtnFixLabOpenBackupFolder.IsEnabled=$has}})
  $Script:BtnFixLabOpenBackupFolder.Add_Click({
    try{
      $row=$Script:LstFixLabBackups.SelectedItem;if(-not$row){return}
      $folder=Split-Path -Parent ([string]$row.Path)
      if(-not(Test-Path -LiteralPath $folder -PathType Container)){throw (L 'The backup folder no longer exists.' 'La carpeta del backup ya no existe.')}
      Start-Process explorer.exe -ArgumentList ('/select,"'+[string]$row.Path+'"')
    }catch{Handle-UIError $_ (L 'Open Fix Lab backup folder' 'Abrir carpeta de backup Fix Lab')}
  })
  $Script:BtnFixLabIgnoreSource.Add_Click({
    try{
      $candidate=Get-PMMFixLabSelectedCandidate;if(-not$candidate){return}
      $warning=L 'Ignore Fix Lab for this exact legacy source hash? PMM will allow Analyze/AUTO to continue with the unfixed mod under your responsibility. You can clear ignored repairs from Advanced.' 'Ignorar Fix Lab para este hash exacto del mod antiguo? PMM permitira continuar Analyze/AUTO con el mod sin reparar bajo tu responsabilidad. Puedes borrar los ignorados desde Advanced.'
      if([System.Windows.MessageBox]::Show($warning,(L 'Ignore repair warning' 'Ignorar aviso de reparacion'),[System.Windows.MessageBoxButton]::YesNo,[System.Windows.MessageBoxImage]::Warning) -ne [System.Windows.MessageBoxResult]::Yes){return}
      [void](Ignore-PMMFixLabCandidate $candidate)
      $Script:FixLabSelectedRecipeId='';$Script:FixLabSelectedVariantId='';$Script:FixLabNoticeDismissed=$true
      Refresh-PMMFixLabUI
      $live=@(Get-PMMFixLabDiscoveryCandidates);$Script:FixLabCachedAttentionCandidates=@($live);Set-PMMFixLabAttentionVisual $live ''
      $Script:MainTabs.SelectedIndex=0
      $Script:TxtStatus.Text=L 'Fix Lab warning ignored for this exact source. Next action: Analyze.' 'Aviso de Fix Lab ignorado para esta fuente exacta. Siguiente accion: Analyze.'
      Close-PMMRequiredActionPopup;$Script:RequiredActionSignature='';Update-PMMGuidedActionState
      if([bool]$Script:TglAutoMode.IsChecked){Start-PMMAutoPipeline;Invoke-PMMAutoContinue}
    }catch{Handle-UIError $_ (L 'Ignore Fix Lab source' 'Ignorar fuente de Fix Lab')}
  })
  $Script:BtnFixLabDeleteSource.Add_Click({
    try{
      $candidate=Get-PMMFixLabSelectedCandidate;if(-not$candidate){return}
      $live=@($candidate.Sources|Where-Object{[string]$_.Origin -eq 'Library'})
      if($live.Count -eq 0){throw (L 'This Fix Lab case currently has only archived backup sources. There is no imported/live legacy mod to delete.' 'Este caso Fix Lab solo tiene fuentes archivadas en backup. No hay ningun mod antiguo importado/en vivo que borrar.')}
      $names=@($live|ForEach-Object{[string]$_.Name}|Sort-Object -Unique)
      $question=if($names.Count -eq 1){
        (L "Delete {0} everywhere? This is the same operation as Imported Mods > Delete: PMM removes the managed library copy and the exact matching PAK from Palworld ~mods. Any deployed compatibility merge is preserved until you explicitly change it in Mods & Merge." "Borrar {0} de todas partes? Es la misma operacion que Imported Mods > Delete: PMM elimina la copia gestionada de la biblioteca y el PAK exacto de ~mods de Palworld. Cualquier merge de compatibilidad desplegado se conserva hasta que lo cambies explicitamente en Mods & Merge.") -f $names[0]
      }else{
        (L "Delete these {0} Fix Lab source mods everywhere? PMM will use the same transactional Delete operation as Imported Mods." "Borrar de todas partes estos {0} mods fuente de Fix Lab? PMM usara la misma operacion transaccional Delete que Imported Mods.") -f $names.Count
      }
      if(-not(Confirm $question)){return}
      $results=[System.Collections.Generic.List[object]]::new()
      foreach($name in $names){$results.Add((Remove-PMMLibraryMod $name))}
      $Script:FixLabSelectedRecipeId='';$Script:FixLabSelectedVariantId='';$Script:FixLabNoticeDismissed=$true
      Refresh-UI
      try{Check-PMMExternalModChanges -Force}catch{}
      try{Refresh-PMMFixLabUI;Update-PMMFixLabAttentionFromLibrary 'Delete'}catch{}
      try{Close-PMMRequiredActionPopup;$Script:RequiredActionSignature='';Update-PMMGuidedActionState}catch{}
      $gameRemoved=@($results.ToArray()|Where-Object{[bool]$_.DeletedFromGame}).Count
      $Script:TxtStatus.Text=((L 'Deleted {0} Fix Lab source mod(s) from PMM and removed {1} exact matching PAK(s) from Palworld ~mods.' 'Borrados {0} mod(s) fuente de Fix Lab de PMM y eliminados {1} PAK(s) exactos correspondientes de ~mods de Palworld.') -f $results.Count,$gameRemoved)
      if($Script:AutoPipelineActive){Invoke-PMMAutoContinue}elseif([bool]$Script:TglAutoMode.IsChecked){Start-PMMAutoPipeline;Invoke-PMMAutoContinue}
    }catch{Handle-UIError $_ (L 'Delete Fix Lab source mod' 'Borrar mod fuente de Fix Lab')}
  })
  $Script:BtnFixLabClearIgnored.Add_Click({
    try{
      Clear-PMMFixLabIgnoredSources
      $Script:FixLabNoticeDismissed=$false
      Refresh-PMMFixLabUI;Update-PMMFixLabAttentionFromLibrary ''
      $Script:TxtStatus.Text=L 'Ignored Fix Lab repair warnings cleared.' 'Avisos ignorados de Fix Lab borrados.'
      Update-PMMGuidedActionState
    }catch{Handle-UIError $_ (L 'Clear ignored Fix Lab repairs' 'Borrar reparaciones ignoradas de Fix Lab')}
  })
  $Script:BtnFixLabBuildReference.Add_Click({try{$args=[System.Windows.RoutedEventArgs]::new([System.Windows.Controls.Button]::ClickEvent);$Script:BtnBuildGameReference.RaiseEvent($args)}catch{Handle-UIError $_ (L 'Build Game Reference' 'Crear Game Reference')}})
  $Script:BtnFixLabOpenReference.Add_Click({try{$p=Get-PMMGameReferenceRoot;if(-not(Test-Path -LiteralPath $p -PathType Container)){New-Item -ItemType Directory -Force -Path $p|Out-Null};Start-Process explorer.exe -ArgumentList ('"'+$p+'"')}catch{Handle-UIError $_ (L 'Open Game Reference' 'Abrir Game Reference')}})
  $Script:BtnFixLabRepair.Add_Click({
    try{
      $candidate=Get-PMMFixLabSelectedCandidate;if(-not$candidate){throw(L 'Select a repairable mod case first.' 'Selecciona primero un caso reparable.')}
      $variant=[string]$Script:FixLabSelectedVariantId;if([string]::IsNullOrWhiteSpace($variant)){throw(L 'Choose an output variant first.' 'Elige primero una variante de salida.')}
      # Do not perform Game Reference hashing or recipe preflight on the WPF
      # thread. The processing worker is authoritative and validates all of it.
      # The UI only captures stable identities and returns to the dispatcher.

      # The UI passes only stable identities. Job creation, exact source
      # snapshot/analyze, expansion, native execution, packing and readback all
      # run in the shared worker so even a first-time large case cannot block WPF.
      $recipeId=[string]$candidate.RecipeId
      $Script:TxtFixLabRepairState.Text=L 'Starting the Fix Lab processing worker...' 'Iniciando el worker de procesamiento Fix Lab...'
      # The click handler does not parse recipes, inspect source PAKs or touch
      # Game Reference. The discovery row already carries the stable case id;
      # the child processing worker revalidates everything authoritatively.
      $caseId=if($candidate.PSObject.Properties.Name -contains 'CaseId' -and -not[string]::IsNullOrWhiteSpace([string]$candidate.CaseId)){[string]$candidate.CaseId}else{$recipeId}
      $expectedBuildId=$caseId+'__'+$variant

      $done={
        param($result)
        # The worker result is authoritative. A later WPF refresh/selection
        # warning must never relabel a validated build as Failed.
        $Script:FixLabSelectedBuildId=if($result -and -not[string]::IsNullOrWhiteSpace([string]$result.BuildId)){[string]$result.BuildId}else{$expectedBuildId}
        $uiWarning=''
        try{
          Refresh-PMMFixLabUI
          $built=@(Get-PMMFixLabBuiltOutputs|Where-Object{[string]$_.BuildId -ieq [string]$Script:FixLabSelectedBuildId}|Select-Object -First 1)
          if($built.Count -gt 0){
            $builtControl=$Window.FindName('LstFixLabBuiltFixes')
            if($builtControl -is [System.Windows.Controls.Primitives.Selector]){
              $builtControl.SelectedValue=[string]$built[0].BuildId
              $Script:FixLabSelectedBuildId=[string]$built[0].BuildId
            }
          }
        }catch{
          $uiWarning=$_.Exception.Message
          Write-PMMLog ("Fix Lab build succeeded, but its UI refresh/selection raised a warning: {0}`n{1}" -f $uiWarning,$_.ScriptStackTrace)
        }
        try{
          $validation=if($result){[string]$result.Validation}else{''}
          $out=if($result){[string]$result.OutputPath}else{''}
          if($Script:TxtFixLabResult){$Script:TxtFixLabResult.Text=((L 'Repair built in the processing engine: {0}`n{1}' 'Fix construido en el motor de procesamiento: {0}`n{1}') -f $out,$validation)}
          if(-not[string]::IsNullOrWhiteSpace($uiWarning)){$Script:TxtStatus.Text=((L 'Repair built successfully. UI refresh warning: {0}' 'La reparacion se construyo correctamente. Aviso al actualizar la interfaz: {0}') -f $uiWarning)}
          Update-PMMGuidedActionState
        }catch{Write-PMMLog ("Post-build UI continuation warning: {0}`n{1}" -f $_.Exception.Message,$_.ScriptStackTrace)}
      }.GetNewClosure()
      $failed={
        param($message)
        try{
          Refresh-PMMFixLabUI
          $Script:TxtFixLabRepairState.Text=((L 'Fix Lab repair failed: {0}' 'La reparacion Fix Lab fallo: {0}') -f $message)
          Stop-PMMAutoPipeline
        }catch{}
      }.GetNewClosure()
      [void](Start-PMMBackgroundOperation -Operation FixLabBuild -FixLabRecipeId $recipeId -FixLabVariantId $variant -OnSuccess $done -OnFailure $failed)
    }catch{Handle-UIError $_ (L 'Repair mod' 'Reparar mod');try{Refresh-PMMFixLabUI}catch{}}
  })
  $Script:BtnFixLabApplyBuilt.Add_Click({
    try{
      if(-not(Request-PMMProcessingSlot 'DeployFix')){return}
      $built=$Script:LstFixLabBuiltFixes.SelectedItem;if(-not$built){return}
      if(($built.PSObject.Properties.Name -contains 'Applied') -and [bool]$built.Applied){$Script:TxtStatus.Text=L 'This Fix Lab output is already applied. Next action: Analyze.' 'Esta salida de Fix Lab ya esta aplicada. Siguiente accion: Analyze.';Update-PMMGuidedActionState;return}
      if(-not(Test-PMMFixLabBuiltDeployAllowed $built)){
        $note=Get-PMMFixLabBuiltDeploymentNote $built
        if([string]::IsNullOrWhiteSpace($note)){$note=L 'This Fix Lab output is an engine-validation milestone and cannot be deployed.' 'Esta salida de Fix Lab es un hito de validacion del motor y no se puede desplegar.'}
        $Script:TxtStatus.Text=$note
        try{$Script:TxtOperationProgress.Text=$note}catch{}
        Write-PMMLog ('Fix Lab non-deployable output: '+$note)
        return
      }
      $Script:FixLabOperationBusy=$true
      $Script:BtnFixLabApplyBuilt.IsEnabled=$false
      $Script:TxtStatus.Text=L 'Deploying repaired mod and archiving the legacy source. The deployed compatibility merge will be preserved...' 'Desplegando el mod reparado y archivando la fuente antigua. El merge de compatibilidad desplegado se conservara...'
      Update-PMMCancelButtonState
      try{[System.Windows.Forms.Application]::DoEvents()}catch{}
      $result=Deploy-PMMFixLabBuiltOutput $built
      $Script:TxtStatus.Text=((L 'Fix deployed: {0}. Legacy source archived. Next action: Analyze the new mod list.' 'Fix desplegado: {0}. Fuente antigua archivada. Siguiente accion: analizar la nueva lista de mods.') -f [string]$result.Name)
      Refresh-UI;Check-PMMExternalModChanges -Force;Refresh-PMMFixLabUI
      $live=@(Get-PMMFixLabDiscoveryCandidates);$Script:FixLabCachedAttentionCandidates=@($live);$Script:FixLabNoticeDismissed=$true
      try{Set-PMMFixLabAttentionVisual $live ''}catch{}
      Close-PMMRequiredActionPopup;$Script:RequiredActionSignature=''
      $Script:MainTabs.SelectedIndex=0
      Update-PMMGuidedActionState
      Notify-PMMWorkflowStepComplete
    }catch{if(Test-PMMCancellationError $_){Set-PMMOperationResult 'FixLab' (L 'Apply Fix cancelled. Transaction rolled back.' 'Aplicar Fix cancelado. La transaccion se revirtio.');Stop-PMMAutoPipeline}else{Handle-UIError $_ (L 'Apply Fix' 'Aplicar Fix')}}
    finally{
      $Script:FixLabOperationBusy=$false;Update-PMMCancelButtonState;try{Update-PMMGuidedActionState}catch{}
      if($Script:AutoPipelineActive){try{Invoke-PMMAutoContinue}catch{Write-PMMLog ('AUTO continuation after Apply Fix failed: '+$_.Exception.Message)}}
    }
  })
  $Script:BtnFixLabRevertBackup.Add_Click({
    try{
      $row=$Script:LstFixLabBackups.SelectedItem;if(-not$row){return}
      $answer=[System.Windows.MessageBox]::Show((L 'Restore the original legacy mod? PMM will remove/archive the applied repair and restore the original source to both the PMM library and Palworld ~mods. The deployed compatibility merge will not be changed.' 'Restaurar el mod antiguo original? PMM retirara/archivara el fix aplicado y restaurara la fuente original tanto en la biblioteca PMM como en ~mods de Palworld. El merge de compatibilidad desplegado no se modificara.'),(L 'Restore original mod' 'Restaurar mod original'),[System.Windows.MessageBoxButton]::YesNo,[System.Windows.MessageBoxImage]::Warning)
      if($answer -ne [System.Windows.MessageBoxResult]::Yes){return}
      [void](Restore-PMMFixLabCase ([string]$row.CaseId))
      Refresh-UI;Check-PMMExternalModChanges -Force;Refresh-PMMFixLabUI
      $Script:TxtStatus.Text=L 'Original legacy mod restored to the PMM library and Palworld ~mods. Fix Lab will warn again unless you choose Ignore this legacy mod.' 'Mod antiguo original restaurado en la biblioteca PMM y en ~mods de Palworld. Fix Lab volvera a avisar salvo que elijas Ignorar este mod antiguo.'
      Update-PMMGuidedActionState
    }catch{Handle-UIError $_ (L 'Restore original mod' 'Restaurar mod original')}
  })
  $Script:BtnFixLabCreateHandoff.Add_Click({
    try{
      $candidate=Get-PMMFixLabSelectedCandidate;if(-not$candidate){throw(L 'Select a repairable mod case first.' 'Selecciona primero un caso reparable.')}
      $job=Ensure-PMMFixLabJobForCandidate $candidate -Analyze
      if(-not[string]::IsNullOrWhiteSpace([string]$Script:FixLabSelectedVariantId)){Set-PMMFixLabSelection ([string]$job.JobId) ([string]$candidate.RecipeId) ([string]$Script:FixLabSelectedVariantId)|Out-Null}
      $zip=Export-PMMFixLabHandoff ([string]$job.JobId);$Script:TxtFixLabResult.Text=((L 'Repair handoff created: {0}' 'Handoff de reparacion creado: {0}') -f $zip);Start-Process explorer.exe -ArgumentList ('/select,"'+$zip+'"')
    }catch{Handle-UIError $_ (L 'Create Fix Lab handoff' 'Crear handoff Fix Lab')}
  })
  $Script:BtnFixLabOpenOutput.Add_Click({try{$job=Get-PMMFixLabCurrentJob;if(-not$job){return};$p=Join-Path (Get-PMMFixLabJobPath ([string]$job.JobId)) 'Output';if(-not(Test-Path -LiteralPath $p -PathType Container)){New-Item -ItemType Directory -Force -Path $p|Out-Null};Start-Process explorer.exe -ArgumentList ('"'+$p+'"')}catch{Handle-UIError $_ (L 'Open Fix Lab output' 'Abrir output Fix Lab')}})
}

function Initialize-PMMFixLabFeature {
  if($Script:FixLabLoaded){return $true}
  if($Script:FixLabLoadAttempted){return $false}
  $Script:FixLabLoadAttempted=$true
  Set-PMMFixLabControlsEnabled $false
  $Script:TxtFixLabAnalysis.Text=L 'Loading Fix Lab module...' 'Cargando modulo Fix Lab...'
  try{
    $service=Join-Path $Script:Root 'Modules\FixLab\FixLabService.ps1'
    if(-not(Test-Path -LiteralPath $service -PathType Leaf)){throw 'Modules/FixLab/FixLabService.ps1 is missing.'}
    . $service
    foreach($fn in @('Initialize-PMMFixLab','Get-PMMFixLabRecipes','Get-PMMFixLabJobs','Get-PMMFixLabLibrarySources','Invoke-PMMFixLabAnalyze','Get-PMMFixLabDiscoveryCandidates','Get-PMMFixLabBuiltOutputs','Get-PMMFixLabBackups','Apply-PMMFixLabBuiltOutput','Ignore-PMMFixLabCandidate','Get-PMMFixLabIgnoredSourceRecords')){if(-not(Get-Command $fn -ErrorAction SilentlyContinue)){throw ('Fix Lab function missing after load: '+$fn)}}
    Initialize-PMMFixLab
    $Script:FixLabLoaded=$true
    Register-PMMFixLabHandlers
    Refresh-PMMFixLabUI
    Write-PMMLog 'Fix Lab loaded lazily after the user opened its tab.'
    return $true
  }catch{
    $msg=$_.Exception.Message
    Write-PMMLog ('Fix Lab lazy-load failure (PMM remains usable): '+$msg)
    Set-PMMFixLabUnavailable $msg
    return $false
  }
}

Set-PMMFixLabControlsEnabled $false
$Script:TxtFixLabAnalysis.Text=L 'Fix Lab will load only when this tab is opened.' 'Fix Lab se cargara solo cuando abras esta pestana.'
Initialize-PMMAIHelpUi
$Script:MainTabs.Add_SelectionChanged({
  try{
    # Tab navigation must stay presentation-only. Older builds recalculated the
    # entire normal workflow (library signature, merge-plan freshness and
    # deployment state) on every tab click; after a large AUTO run that could
    # turn a simple tab switch into seconds of synchronous filesystem work.
    # Operation completion / actual state-changing handlers already refresh the
    # ColorFlow guide. Here we only do the work needed by the selected tab.
    if($Script:MainTabs.SelectedItem -eq $Script:TabAIHelp){
      [void]$Window.Dispatcher.BeginInvoke([System.Action]{try{Refresh-PMMAIHelpUi -EnsureUnsupported}catch{Write-PMMLog ('AI & Help refresh failed: '+$_.Exception.Message)}},[System.Windows.Threading.DispatcherPriority]::ContextIdle)
      return
    }
    if($Script:MainTabs.SelectedItem -eq $Script:TabFixLab){
      # Queue the lazy load or at-most-once-per-minute refresh at ContextIdle so
      # WPF paints the selected tab before any filesystem snapshot/rebinding.
      Queue-PMMFixLabUiRefresh
      return
    }

    # When Fix Lab still owns a repairable source, keep its tab highlighted
    # without evaluating the much more expensive normal Import/Analyze/Build/
    # Deploy state. Once the case is resolved, state-changing operations will
    # have already recomputed normal guidance.
    if($Script:FixLabLoaded -and @($Script:FixLabCachedAttentionCandidates).Count -gt 0){
      $grRunning=$false;try{$grRunning=($Script:GameReferenceProcess -and -not$Script:GameReferenceProcess.HasExited)}catch{}
      if($grRunning -or $Script:AutoPipelineActive){
        # During the concurrent reference/choice phase the unified state machine
        # knows whether the real pending action is wait, choose output, repair,
        # etc. Do not replace it with the old generic 'open Fix Lab' hint.
        Update-PMMGuidedActionState
      }else{
        Reset-PMMGuidedActionStyles
        Set-PMMRequiredAction $Script:TabFixLab 'FixLab:Tab' (L 'A repairable legacy mod was detected. Open Fix Lab.' 'Se detecto un mod antiguo reparable. Abre Fix Lab.')
      }
    }
  }catch{Write-PMMLog ('Tab navigation refresh warning: '+$_.Exception.Message)}
})

# ---------------------------------------------------------------------------
# Guided workflow button colors + in-button progress.
#
# PMM derives the next useful action from state, never from the last click:
#   Import -> Analyze -> Build -> Deploy -> Play
# Only one stage is highlighted at a time. While Import/Analyze/Build/Deploy is
# running, that same highlighted button becomes its progress bar: the normal
# neutral button surface grows from left to right until the special color is
# completely consumed. Play is a terminal READY indicator and never animates.
# ---------------------------------------------------------------------------
$Script:ImportBusy=$false
$Script:ImportBusyButton=$null
$Script:BuildBusy=$false
$Script:DeployBusy=$false
$Script:GameModsFingerprint=''
$Script:ExternalModsTimer=$null
$Script:UiResponsivenessTimer=$null
$Script:UiResponsivenessExpectedUtc=[datetime]::UtcNow
$Script:UiResponsivenessLastLogUtc=[datetime]::MinValue
$Script:CancelRequested=$false
$Script:AutoPipelineActive=$false
$Script:AutoOneShotActive=$false
$Script:AutoStepInProgress=$false
$Script:AutoWorkflowTimer=$null
$Script:AutoFixLabPresentedRecipeId=''
$Script:AutoLastWorkflowKey=''
$Script:AutoReferenceStartRecipeId=''
$Script:GameReferenceProgressPercent=0
$Script:GameReferenceProgressMessage=''
$Script:GameReferenceProgressIndeterminate=$false
$Script:GameReferenceResumeAuto=$false
$Script:CompletionMediaPlayer=$null
$Script:CompletionMediaPath=''
$Script:UiSettingsRefreshing=$false

function Get-PMMSoundPathById([string]$Mode){
  switch($Mode){
    'None' { return '' }
    'Bell' { return (Join-Path $Script:Root 'Resources\Sounds\PMM_bell.wav') }
    'Microwave' { return (Join-Path $Script:Root 'Resources\Sounds\PMM_microwave.wav') }
    'Microwave3' { return (Join-Path $Script:Root 'Resources\Sounds\PMM_microwave_3beeps.wav') }
    'Ok' { return (Join-Path $Script:Root 'Resources\Sounds\PMM_ok.wav') }
    'Good' { return (Join-Path $Script:Root 'Resources\Sounds\PMM_good.wav') }
    'Crystal' { return (Join-Path $Script:Root 'Resources\Sounds\PMM_crystal.wav') }
    'Alert' { return (Join-Path $Script:Root 'Resources\Sounds\PMM_alert.wav') }
  }
  if($Mode -like 'file:*'){$name=$Mode.Substring(5);$p=Join-Path (Get-PMMSoundStore) $name;if(Test-Path -LiteralPath $p -PathType Leaf){return $p}}
  return ''
}
function Get-PMMConfiguredSoundId([string]$Profile){
  $cfg=Get-PMMConfig;$prop=Get-PMMSoundProfileConfigProperty $Profile;$value=''
  try{if($cfg.PSObject.Properties.Name -contains $prop){$value=[string]$cfg.$prop}}catch{}
  if([string]::IsNullOrWhiteSpace($value)){$value=Get-PMMSoundProfileDefault $Profile}
  return $value
}
function Play-PMMSoundId([string]$SoundId,[int]$Volume=-1){
  try{
    $path=Get-PMMSoundPathById $SoundId
    if([string]::IsNullOrWhiteSpace($path) -or -not(Test-Path -LiteralPath $path -PathType Leaf)){return}
    if($Volume -lt 0){$cfg=Get-PMMConfig;$Volume=50;try{if($cfg.PSObject.Properties.Name -contains 'CompletionVolume'){$Volume=[int]$cfg.CompletionVolume}}catch{$Volume=50}}
    $Volume=[Math]::Max(0,[Math]::Min(100,$Volume));if($Volume -le 0){return}
    if(-not$Script:CompletionMediaPlayer){$Script:CompletionMediaPlayer=[System.Windows.Media.MediaPlayer]::new()}
    try{$Script:CompletionMediaPlayer.Stop()}catch{}
    if([string]$Script:CompletionMediaPath -cne [string]$path){try{$Script:CompletionMediaPlayer.Close()}catch{};$Script:CompletionMediaPlayer.Open([System.Uri]::new([IO.Path]::GetFullPath($path)));$Script:CompletionMediaPath=[string]$path}
    $Script:CompletionMediaPlayer.Volume=[double]$Volume/100.0;$Script:CompletionMediaPlayer.Position=[TimeSpan]::Zero;$Script:CompletionMediaPlayer.Play()
  }catch{Write-PMMLog ('Sound playback warning: '+$_.Exception.Message)}
}
function Play-PMMSoundEvent([ValidateSet('Auto','SemiAuto','Manual','Attention','Error')][string]$Profile){
  try{
    $cfg=Get-PMMConfig
    if($Profile -eq 'SemiAuto'){
      $enabled=$true;try{if($cfg.PSObject.Properties.Name -contains 'SoundSemiAutoEnabled'){$enabled=[bool]$cfg.SoundSemiAutoEnabled}}catch{}
      if(-not$enabled){return}
    }
    if($Profile -eq 'Attention'){
      $enabled=$true;try{if($cfg.PSObject.Properties.Name -contains 'SoundAttentionEnabled'){$enabled=[bool]$cfg.SoundAttentionEnabled}}catch{}
      if(-not$enabled){return}
    }
    Play-PMMSoundId (Get-PMMConfiguredSoundId $Profile)
  }catch{Write-PMMLog ('Sound event warning '+$Profile+': '+$_.Exception.Message)}
}
function Notify-PMMWorkflowStepComplete {
  if([bool]$Script:AutoPipelineActive){Play-PMMSoundEvent 'SemiAuto'}else{Play-PMMSoundEvent 'Manual'}
}
function Complete-PMMAutoPipeline([string]$Message='') {
  $wasActive=[bool]$Script:AutoPipelineActive
  Stop-PMMAutoPipeline $Message
  if($wasActive){Play-PMMSoundEvent 'Auto'}
}


function Test-PMMOperationCancellationRequested { return [bool]$Script:CancelRequested }
function Reset-PMMOperationCancellation { $Script:CancelRequested=$false; Update-PMMCancelButtonState }
function Test-PMMCancellationError($ErrorRecord) {
  if(-not$ErrorRecord){return $false}
  try{if($ErrorRecord.Exception -is [System.OperationCanceledException]){return $true}}catch{}
  try{if(([string]$ErrorRecord.Exception.Message) -eq 'PMM_OPERATION_CANCELLED'){return $true}}catch{}
  return $false
}

function Get-PMMActiveProcessingOperation {
  try{if($Script:BackgroundOperationProcess -and -not$Script:BackgroundOperationProcess.HasExited){return [string]$Script:BackgroundOperationKind}}catch{}
  try{if($Script:GameReferenceProcess -and -not$Script:GameReferenceProcess.HasExited){return 'GameReference'}}catch{}
  if([bool]$Script:ImportBusy){return 'Import'}
  if([bool]$Script:DeployBusy){return 'Deploy'}
  if([bool]$Script:AnalyzeBusy){return 'Analyze'}
  if([bool]$Script:BuildBusy){return 'Build'}
  if([bool]$Script:AIIOBusy){return 'AIIO'}
  if([bool]$Script:FixLabOperationBusy){return 'FixLab'}
  return ''
}

function Request-PMMProcessingSlot([string]$RequestedOperation) {
  $active=[string](Get-PMMActiveProcessingOperation)
  if([string]::IsNullOrWhiteSpace($active)){return $true}
  $message=(L ("Processing engine busy: {0}. Wait for it to finish or press Cancel before starting {1}." -f $active,$RequestedOperation) ("Motor de procesamiento ocupado: {0}. Espera a que termine o pulsa Cancelar antes de iniciar {1}." -f $active,$RequestedOperation))
  $Script:TxtStatus.Text=$message
  try{$Script:TxtOperationProgress.Text=$message}catch{}
  try{[System.Media.SystemSounds]::Beep.Play()}catch{}
  return $false
}

function Update-PMMCancelButtonState {
  if(-not$Script:BtnCancelOperation){return}
  $workerRunning=$false
  try{$workerRunning=($Script:BackgroundOperationProcess -and -not$Script:BackgroundOperationProcess.HasExited)}catch{}
  $gameRefRunning=$false
  try{$gameRefRunning=($Script:GameReferenceProcess -and -not$Script:GameReferenceProcess.HasExited)}catch{}
  $busy=([bool]$Script:ImportBusy -or [bool]$Script:AnalyzeBusy -or [bool]$Script:BuildBusy -or [bool]$Script:DeployBusy -or [bool]$Script:AIIOBusy -or [bool]$Script:FixLabOperationBusy -or $workerRunning -or $gameRefRunning -or [bool]$Script:AutoPipelineActive)
  $Script:BtnCancelOperation.IsEnabled=$busy
}

function Stop-PMMAutoPipeline([string]$Reason='') {
  $Script:AutoPipelineActive=$false
  $Script:AutoOneShotActive=$false
  $Script:AutoStepInProgress=$false
  $Script:AutoFixLabPresentedRecipeId=''
  $Script:AutoLastWorkflowKey=''
  $Script:AutoReferenceStartRecipeId=''
  try{if($Script:AutoWorkflowTimer){$Script:AutoWorkflowTimer.Stop()}}catch{}
  Update-PMMCancelButtonState
  if(-not[string]::IsNullOrWhiteSpace($Reason)){
    $Script:TxtStatus.Text=$Reason
    try{$Script:TxtOperationProgress.Text=$Reason}catch{}
  }
}

function Ensure-PMMAutoWorkflowTimer {
  if($Script:AutoWorkflowTimer){return}
  # AUTO continuation is a watchdog. Actual operation completions explicitly
  # continue the pipeline, so keep this timer at Background priority to never
  # compete with tab changes, list selection, resize or other user input.
  $timer=[System.Windows.Threading.DispatcherTimer]::new([System.Windows.Threading.DispatcherPriority]::Background)
  $timer.Interval=[TimeSpan]::FromMilliseconds(2000)
  $timer.Add_Tick({
    try{Invoke-PMMAutoContinue}catch{
      Write-PMMLog ('Auto workflow error: '+$_.Exception.Message)
      Stop-PMMAutoPipeline ((L 'Auto paused: {0}' 'Auto pausado: {0}') -f $_.Exception.Message)
    }
  })
  $Script:AutoWorkflowTimer=$timer
}

function Test-PMMAutoContinuationEnabled { return ([bool]$Script:TglAutoMode.IsChecked -or [bool]$Script:AutoOneShotActive) }

function Start-PMMAutoPipeline {
  param([switch]$OneShot)
  $wasActive=[bool]$Script:AutoPipelineActive
  if($OneShot){$Script:AutoOneShotActive=$true}
  if(-not(Test-PMMAutoContinuationEnabled)){return}
  if(-not$wasActive){$Script:AutoFixLabPresentedRecipeId='';$Script:AutoLastWorkflowKey='';$Script:AutoReferenceStartRecipeId=''}
  $Script:CancelRequested=$false
  $Script:AutoPipelineActive=$true
  Ensure-PMMAutoWorkflowTimer
  $Script:AutoWorkflowTimer.Start()
  Update-PMMCancelButtonState
}

function Ensure-PMMUiResponsivenessMonitor {
  if($Script:UiResponsivenessTimer){return}
  $timer=[System.Windows.Threading.DispatcherTimer]::new([System.Windows.Threading.DispatcherPriority]::Background)
  $timer.Interval=[TimeSpan]::FromMilliseconds(500)
  $Script:UiResponsivenessExpectedUtc=[datetime]::UtcNow.AddMilliseconds(500)
  $timer.Add_Tick({
    try{
      $now=[datetime]::UtcNow
      $lag=($now-$Script:UiResponsivenessExpectedUtc).TotalMilliseconds
      $Script:UiResponsivenessExpectedUtc=$now.AddMilliseconds(500)
      if($lag -gt 750 -and ($now-$Script:UiResponsivenessLastLogUtc).TotalSeconds -gt 5){
        $Script:UiResponsivenessLastLogUtc=$now
        $active=Get-PMMActiveProcessingOperation
        Write-PMMLog (('UI dispatcher delay detected: {0:N0} ms | active={1}') -f $lag,$active)
      }
    }catch{}
  })
  $Script:UiResponsivenessTimer=$timer
  $timer.Start()
}

function Get-PMMGuidePalette([ValidateSet('Import','Analyze','Build','Deploy','Play')][string]$State) {
  try{
    if($Script:ActiveThemeColorFlow -and $Script:ActiveThemeColorFlow.Contains($State)){
      $v=$Script:ActiveThemeColorFlow[$State]
      return [pscustomobject]@{Progress=[string]$v.Progress;Border=[string]$v.Border}
    }
  }catch{}
  $flow=Get-PMMDefaultColorFlow;$v=$flow[$State]
  return [pscustomobject]@{Progress=[string]$v.Progress;Border=[string]$v.Border}
}

function Get-PMMGuideBrush([ValidateSet('Import','Analyze','Build','Deploy','Play')][string]$State,[ValidateSet('Progress','Border')][string]$Part) {
  $palette=Get-PMMGuidePalette $State;$fallback=if($Part -eq 'Progress'){[string]$palette.Progress}else{[string]$palette.Border}
  if($Script:ActiveThemeDefinition){try{return (Get-PMMThemeDefinitionBrush $Script:ActiveThemeDefinition ('ColorFlow.'+$State+'.'+$Part) $fallback)}catch{}}
  return [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString((Convert-PMMThemeHexToWpf $fallback)))
}

$Script:UniversalProgressOperation=''
$Script:UniversalProgressFraction=0.0
$Script:UniversalProgressMessage=''
$Script:ProgressAnimationStates=@{}
$Script:ProgressAnimationTimer=$null

function Update-PMMUniversalProgressText([string]$Operation,[string]$Message,[bool]$Indeterminate) {
  if(-not$Script:TxtOperationProgress){return}
  $label=Get-PMMUniversalProgressLabel $Operation
  if($Indeterminate){$text=$label+'...'}else{$text=('{0} {1}%' -f $label,[int][Math]::Floor([double]$Script:PrgOperation.Value))}
  if(-not[string]::IsNullOrWhiteSpace($Message)){$text+='  -  '+$Message}
  $Script:TxtOperationProgress.Text=$text
}

function Ensure-PMMProgressAnimationTimer {
  if($Script:ProgressAnimationTimer){if(-not$Script:ProgressAnimationTimer.IsEnabled){$Script:ProgressAnimationTimer.Start()};return}
  $timer=[System.Windows.Threading.DispatcherTimer]::new([System.Windows.Threading.DispatcherPriority]::Background)
  $timer.Interval=[TimeSpan]::FromMilliseconds(40)
  $timer.Add_Tick({
    try{
      $active=$false;$now=[DateTime]::UtcNow
      foreach($key in @($Script:ProgressAnimationStates.Keys)){
        $state=$Script:ProgressAnimationStates[$key]
        if(-not$state -or -not$state.Bar){[void]$Script:ProgressAnimationStates.Remove($key);continue}
        if([double]$state.Displayed -lt [double]$state.Target){
          $active=$true
          if(($now-[datetime]$state.LastStepUtc).TotalMilliseconds -ge [double]$state.IntervalMs){
            $state.Displayed=[Math]::Min([double]$state.Target,[double]$state.Displayed+1.0)
            $state.LastStepUtc=$now
            $state.Bar.Value=[double]$state.Displayed
            if([string]$key -eq 'Universal'){Update-PMMUniversalProgressText ([string]$state.Operation) ([string]$state.Message) $false}
          }
        }
      }
      if(-not$active -and $Script:ProgressAnimationTimer){$Script:ProgressAnimationTimer.Stop()}
    }catch{Write-PMMLog ('Progress animation warning: '+$_.Exception.Message)}
  })
  $Script:ProgressAnimationTimer=$timer
  $timer.Start()
}

function Set-PMMSmoothedProgressBar {
  param(
    $Bar,
    [Parameter(Mandatory=$true)][string]$Key,
    [double]$TargetPercent=0.0,
    [string]$Operation='',
    [string]$Message='',
    [switch]$Indeterminate
  )
  if(-not$Bar){return 0.0}
  $Bar.Minimum=0;$Bar.Maximum=100;$Bar.IsIndeterminate=[bool]$Indeterminate
  if($Indeterminate){
    [void]$Script:ProgressAnimationStates.Remove($Key)
    # Every indeterminate phase is a new real operation boundary. Clearing the
    # stale percentage here lets the first known target animate from zero rather
    # than inheriting the previous operation's 100%.
    $Bar.Value=0
    return 0.0
  }

  # Floor is deliberate: presentation can lag real work, but can never claim a
  # percentage the worker has not reached.
  $target=[Math]::Floor([Math]::Max(0.0,[Math]::Min(100.0,$TargetPercent)))
  # Completion is a real operation boundary, not an interval to animate. If
  # 100% were left to catch up one point at a time, the next workflow step
  # could already be running while the previous bar still looked busy.
  if($target -ge 100.0){
    [void]$Script:ProgressAnimationStates.Remove($Key)
    $Bar.Value=100.0
    if($Key -eq 'Universal'){Update-PMMUniversalProgressText $Operation $Message $false}
    return 100.0
  }
  $state=$null;if($Script:ProgressAnimationStates.ContainsKey($Key)){$state=$Script:ProgressAnimationStates[$Key]}
  if(-not$state -or ([string]$state.Operation -ne $Operation -and -not[string]::IsNullOrWhiteSpace($Operation))){
    # A missing state or changed operation is a real presentation boundary.
    # Never inherit a stale 100% from the preceding worker; animate the first
    # known range from zero (except a 0/1% acknowledgement).
    $start=if($target -le 1){$target}else{0.0}
    $state=[pscustomobject]@{Bar=$Bar;Displayed=[double]$start;Target=[double]$target;IntervalMs=250.0;LastStepUtc=[DateTime]::UtcNow;Operation=$Operation;Message=$Message}
    $Script:ProgressAnimationStates[$Key]=$state
  }else{
    # If real work advances again while the display is still catching up, snap
    # only to the previous proven target and animate the newly reported range.
    $priorTarget=[double]$state.Target
    if($target -gt $priorTarget -and [double]$state.Displayed -lt $priorTarget){$state.Displayed=$priorTarget}
    if($target -lt [double]$state.Displayed -or $target -eq 0){$state.Displayed=$target}
    $state.Target=$target;$state.Operation=$Operation;$state.Message=$Message
    # Repeated status messages at the same percentage must not keep postponing
    # the next visual step. Restart the pacing window only for a real target change.
    if($target -ne $priorTarget){$state.LastStepUtc=[DateTime]::UtcNow}
  }
  $gap=[Math]::Max(0.0,[double]$state.Target-[double]$state.Displayed)
  if($gap -gt 0){$state.IntervalMs=[Math]::Max(50.0,[Math]::Min(500.0,3000.0/$gap))}
  $Bar.Value=[double]$state.Displayed
  if($gap -gt 0){Ensure-PMMProgressAnimationTimer}
  return [double]$state.Displayed
}

function Reset-PMMSmoothedProgressBar([string]$Key,$Bar) {
  [void]$Script:ProgressAnimationStates.Remove($Key)
  if($Bar){$Bar.IsIndeterminate=$false;$Bar.Value=0}
}

function Get-PMMUniversalProgressColor([string]$Operation) {
  if($Operation -in @('Import','Analyze','Build','Deploy')){try{return [string](Get-PMMGuidePalette $Operation).Border}catch{}}
  switch($Operation){'AIIO'{return '#7C3AED'}'FixLab'{return '#D97706'}default{return '#64748B'}}
}

function Get-PMMUniversalProgressLabel([string]$Operation) {
  switch($Operation){
    'Import'  { return (L 'Importing' 'Importando') }
    'Analyze' { return (L 'Analyzing' 'Analizando') }
    'Build'   { return (L 'Merging' 'Fusionando') }
    'Deploy'  { return (L 'Deploying' 'Desplegando') }
    'AIIO'    { return 'AIIO' }
    'FixLab'  { return (L 'Repairing' 'Reparando') }
    default   { return $(if([string]::IsNullOrWhiteSpace($Operation)){L 'Ready' 'Listo'}else{$Operation}) }
  }
}

function Set-PMMUniversalProgress {
  param(
    [Parameter(Mandatory=$true)][string]$Operation,
    [double]$Fraction=0.0,
    [string]$Message='',
    [switch]$Indeterminate
  )
  if(-not$Script:PrgOperation -or -not$Script:TxtOperationProgress){return}
  $fraction=[Math]::Max(0.0,[Math]::Min(1.0,$Fraction))
  $Script:UniversalProgressOperation=$Operation
  $Script:UniversalProgressFraction=$fraction
  $Script:UniversalProgressMessage=$Message
  $Script:PrgOperation.Visibility=[System.Windows.Visibility]::Visible
  $Script:PrgOperation.IsIndeterminate=[bool]$Indeterminate
  [void](Set-PMMSmoothedProgressBar $Script:PrgOperation 'Universal' (100.0*$fraction) -Operation $Operation -Message $Message -Indeterminate:$Indeterminate)
  try{$Script:PrgOperation.Foreground=[System.Windows.Media.BrushConverter]::new().ConvertFromString((Get-PMMUniversalProgressColor $Operation))}catch{}
  Update-PMMUniversalProgressText $Operation $Message ([bool]$Indeterminate)
}

function Set-PMMOperationResult([string]$Operation,[string]$Message) {
  Set-PMMUniversalProgress -Operation $Operation -Fraction 1.0 -Message $Message
  if(-not[string]::IsNullOrWhiteSpace($Message)){$Script:TxtStatus.Text=$Message}
}

function Set-PMMOperationFailure([string]$Operation,[string]$Message) {
  Set-PMMUniversalProgress -Operation $Operation -Fraction 1.0 -Message $Message
  [void]$Script:ProgressAnimationStates.Remove('Universal')
  $Script:PrgOperation.IsIndeterminate=$false;$Script:PrgOperation.Value=100
  try{$Script:PrgOperation.Foreground=[System.Windows.Media.BrushConverter]::new().ConvertFromString('#DC2626')}catch{}
  $Script:TxtOperationProgress.Text=((Get-PMMUniversalProgressLabel $Operation)+' - '+(L 'failed' 'fallo')+'  -  '+$Message)
  $Script:TxtStatus.Text=$Message
}

function Clear-PMMWorkflowButtonVisual($Button) {
  if(-not$Button){return}
  try{$Button.ClearValue([System.Windows.Controls.Control]::BackgroundProperty)}catch{}
  try{$Button.ClearValue([System.Windows.Controls.Control]::ForegroundProperty)}catch{}
  try{$Button.ClearValue([System.Windows.Controls.Control]::BorderBrushProperty)}catch{}
  try{$Button.ClearValue([System.Windows.UIElement]::OpacityProperty)}catch{}
}

function Set-PMMWorkflowButtonProgress {
  param(
    $Button,
    [Parameter(Mandatory=$true)][ValidateSet('Import','Analyze','Build','Deploy')][string]$State,
    [double]$Fraction=0.0,
    [string]$Message='',
    [switch]$Indeterminate
  )
  if(-not$Button){return}
  # Indeterminate work starts fully highlighted. Once real progress is known,
  # the neutral surface consumes the highlight from left to right.
  $p=if($Indeterminate){0.0}else{[Math]::Max(0.0,[Math]::Min(1.0,$Fraction))}
  $normalBrush=$Window.Resources['CardAltBackground'];$specialBrush=Get-PMMGuideBrush $State 'Progress'
  $unit=[System.Windows.Rect]::new(0,0,1,1);$group=[System.Windows.Media.DrawingGroup]::new();$group.Children.Add([System.Windows.Media.GeometryDrawing]::new($normalBrush,$null,[System.Windows.Media.RectangleGeometry]::new($unit)))
  if($p -lt 0.999){$remaining=[System.Windows.Rect]::new($p,0,1-$p,1);$group.Children.Add([System.Windows.Media.GeometryDrawing]::new($specialBrush,$null,[System.Windows.Media.RectangleGeometry]::new($remaining)))}
  $brush=[System.Windows.Media.DrawingBrush]::new($group);$brush.Stretch=[System.Windows.Media.Stretch]::Fill
  $Button.Background=$brush
  try{$Button.Foreground=$Window.Resources['PrimaryText']}catch{$Button.Foreground=[System.Windows.Media.BrushConverter]::new().ConvertFromString('#111827')}
  $Button.BorderBrush=Get-PMMGuideBrush $State 'Border'
  $Button.Opacity=1.0
  if(-not[string]::IsNullOrWhiteSpace($Message)){$Script:TxtStatus.Text=$Message}
  try{[System.Windows.Forms.Application]::DoEvents()}catch{}
}

function Set-PMMGuideButtonStyle($Button,[ValidateSet('Default','Import','Analyze','Build','Deploy','Play')][string]$State='Default') {
  if(-not$Button){return}
  Clear-PMMWorkflowButtonVisual $Button
  try{$Button.Style=$Window.FindResource('DefaultButton')}catch{}
  if($State -eq 'Default'){return}
  try{
    $Button.Background=Get-PMMGuideBrush $State 'Border'
    $Button.BorderBrush=Get-PMMGuideBrush $State 'Border'
    $Button.Foreground=[System.Windows.Media.Brushes]::White
    $Button.FontWeight=[System.Windows.FontWeights]::SemiBold
  }catch{Write-PMMLog ('Could not apply guided button colors '+$State+': '+$_.Exception.Message)}
}

function Reset-PMMGuidedActionStyles {
  $grRunning=$false;try{$grRunning=($Script:GameReferenceProcess -and -not$Script:GameReferenceProcess.HasExited)}catch{}
  foreach($button in @($Script:BtnDetectGame,$Script:BtnImport,$Script:BtnImportGameMods,$Script:BtnScan,$Script:BtnBuild,$Script:BtnDeploy,$Script:BtnPlay,$Script:BtnFixLabBuildReference,$Script:BtnFixLabRepair,$Script:BtnFixLabApplyBuilt)){
    if($grRunning -and $button -eq $Script:BtnFixLabBuildReference){continue}
    Set-PMMGuideButtonStyle $button 'Default'
  }
  if($grRunning){
    $fraction=[double]$Script:GameReferenceProgressPercent/100.0
    Set-PMMWorkflowButtonProgress $Script:BtnFixLabBuildReference 'Build' $fraction ([string]$Script:GameReferenceProgressMessage) -Indeterminate:([bool]$Script:GameReferenceProgressIndeterminate)
  }
}

# ---------------------------------------------------------------------------
# Required-action guidance.
# The color remains until the state changes. The small popup is intentionally
# ephemeral (5 s by default) and is shown at most once for an unchanged action.
# ---------------------------------------------------------------------------
$Script:RequiredActionSignature=''
$Script:RequiredActionDismissedSignature=''
$Script:RequiredActionTarget=$null
$Script:RequiredActionPopup=$null
$Script:RequiredActionTimer=$null
$Script:LastAttentionSoundKey=''

function Close-PMMRequiredActionPopup([switch]$Dismiss) {
  try{if($Script:RequiredActionTimer){$Script:RequiredActionTimer.Stop()}}catch{}
  $Script:RequiredActionTimer=$null
  try{if($Script:RequiredActionPopup){$Script:RequiredActionPopup.IsOpen=$false}}catch{}
  $Script:RequiredActionPopup=$null
  if($Dismiss -and -not[string]::IsNullOrWhiteSpace([string]$Script:RequiredActionSignature)){$Script:RequiredActionDismissedSignature=[string]$Script:RequiredActionSignature}
}

function Clear-PMMRequiredActionTargetVisual {
  $target=$Script:RequiredActionTarget
  if(-not$target){return}
  $normal=@($Script:BtnDetectGame,$Script:BtnImport,$Script:BtnImportGameMods,$Script:BtnScan,$Script:BtnBuild,$Script:BtnDeploy,$Script:BtnPlay,$Script:BtnFixLabBuildReference,$Script:BtnFixLabRepair,$Script:BtnFixLabApplyBuilt)
  if($target -notin $normal){
    try{$target.ClearValue([System.Windows.Controls.Control]::BorderBrushProperty)}catch{}
    try{$target.ClearValue([System.Windows.Controls.Control]::BorderThicknessProperty)}catch{}
  }
}

function Clear-PMMRequiredAction {
  Close-PMMRequiredActionPopup
  Clear-PMMRequiredActionTargetVisual
  $Script:RequiredActionTarget=$null
  $Script:RequiredActionSignature=''
  $Script:LastAttentionSoundKey=''
}

function Get-PMMActionHintSeconds {
  try{
    $cfg=Get-PMMConfig
    $v=[int]$cfg.ActionHintSeconds
    if($v -eq -1 -or ($v -ge 0 -and $v -le 120)){return $v}
  }catch{}
  return 5
}

function Set-PMMRequiredAction {
  param($Target,[string]$Key,[string]$Detail='')
  if(-not$Target -or [string]::IsNullOrWhiteSpace($Key)){Clear-PMMRequiredAction;return}

  if($Script:RequiredActionTarget -ne $Target){
    Clear-PMMRequiredActionTargetVisual
    $Script:RequiredActionTarget=$Target
  }
  $normal=@($Script:BtnDetectGame,$Script:BtnImport,$Script:BtnImportGameMods,$Script:BtnScan,$Script:BtnBuild,$Script:BtnDeploy,$Script:BtnPlay,$Script:BtnFixLabBuildReference,$Script:BtnFixLabRepair,$Script:BtnFixLabApplyBuilt)
  if($Target -notin $normal){
    try{$Target.BorderBrush=[System.Windows.Media.BrushConverter]::new().ConvertFromString('#F97316')}catch{}
    try{$Target.BorderThickness=[System.Windows.Thickness]::new(3)}catch{}
  }

  # While AUTO is actively moving, keep the color cue but do not distract
  # with a popup. If AUTO pauses, the same action will then show the hint.
  $humanDecisionRequired=([string]$Key -like 'Flow:FixLabVariant*' -or [string]$Key -like 'Flow:ResolveDecisions*')
  if([bool]$Script:AutoPipelineActive -and -not$humanDecisionRequired){Close-PMMRequiredActionPopup;$Script:RequiredActionSignature='';return}

  $sig=[string]$Key
  if($sig -ceq [string]$Script:RequiredActionSignature){return}
  Close-PMMRequiredActionPopup
  $Script:RequiredActionSignature=$sig
  $Script:RequiredActionDismissedSignature=''
  if($humanDecisionRequired){
    $attentionKey=([string]$sig -replace ':(Tab|Combo)$','')
    if([string]$attentionKey -cne [string]$Script:LastAttentionSoundKey){try{Play-PMMSoundEvent 'Attention'}catch{};$Script:LastAttentionSoundKey=$attentionKey}
  }

  $seconds=Get-PMMActionHintSeconds
  if($seconds -eq 0){return}

  try{
    $popup=[System.Windows.Controls.Primitives.Popup]::new()
    $popup.PlacementTarget=$Target
    $popup.Placement=[System.Windows.Controls.Primitives.PlacementMode]::Top
    $popup.VerticalOffset=-6
    $popup.AllowsTransparency=$true
    $popup.StaysOpen=$true
    $popup.PopupAnimation=[System.Windows.Controls.Primitives.PopupAnimation]::Fade

    $border=[System.Windows.Controls.Border]::new()
    $isFixLabChoice=([string]$Key -like 'Flow:FixLabVariant*')
    $popupBackgroundKey=if($isFixLabChoice){'DecisionNoticeBackground'}else{'NoticeBackground'}
    $popupBorderKey=if($isFixLabChoice){'DecisionNoticeBorder'}else{'NoticeBorder'}
    $popupHeadingKey=if($isFixLabChoice){'DecisionNoticeHeading'}else{'AccentHeadingAmber'}
    $border.Background=$Window.Resources[$popupBackgroundKey]
    $border.BorderBrush=$Window.Resources[$popupBorderKey]
    $border.BorderThickness=[System.Windows.Thickness]::new(1)
    $border.CornerRadius=[System.Windows.CornerRadius]::new(7)
    $border.Padding=[System.Windows.Thickness]::new(9,6,6,6)

    $grid=[System.Windows.Controls.Grid]::new()
    $col1=[System.Windows.Controls.ColumnDefinition]::new();$col1.Width=[System.Windows.GridLength]::new(1,[System.Windows.GridUnitType]::Star)
    $col2=[System.Windows.Controls.ColumnDefinition]::new();$col2.Width=[System.Windows.GridLength]::Auto
    [void]$grid.ColumnDefinitions.Add($col1);[void]$grid.ColumnDefinitions.Add($col2)

    $stack=[System.Windows.Controls.StackPanel]::new()
    $title=[System.Windows.Controls.TextBlock]::new();$title.Text=L 'Action required' 'Acción requerida';$title.FontWeight=[System.Windows.FontWeights]::SemiBold;$title.Foreground=$Window.Resources[$popupHeadingKey]
    [void]$stack.Children.Add($title)
    if(-not[string]::IsNullOrWhiteSpace($Detail)){$body=[System.Windows.Controls.TextBlock]::new();$body.Text=$Detail;$body.TextWrapping=[System.Windows.TextWrapping]::Wrap;$body.MaxWidth=330;$body.Margin=[System.Windows.Thickness]::new(0,2,8,0);$body.Foreground=$Window.Resources['PrimaryText'];[void]$stack.Children.Add($body)}
    [System.Windows.Controls.Grid]::SetColumn($stack,0);[void]$grid.Children.Add($stack)

    $close=[System.Windows.Controls.Button]::new();$close.Content='X';$close.Width=24;$close.Height=24;$close.Padding=[System.Windows.Thickness]::new(0);$close.Margin=[System.Windows.Thickness]::new(6,0,0,0);$close.VerticalAlignment=[System.Windows.VerticalAlignment]::Top
    $close.Add_Click({Close-PMMRequiredActionPopup -Dismiss})
    [System.Windows.Controls.Grid]::SetColumn($close,1);[void]$grid.Children.Add($close)
    $border.Child=$grid;$popup.Child=$border
    $Script:RequiredActionPopup=$popup;$popup.IsOpen=$true

    if($seconds -gt 0){
      $timer=[System.Windows.Threading.DispatcherTimer]::new();$timer.Interval=[TimeSpan]::FromSeconds($seconds)
      $timer.Add_Tick({Close-PMMRequiredActionPopup -Dismiss})
      $Script:RequiredActionTimer=$timer;$timer.Start()
    }
  }catch{Write-PMMLog ('Action-required hint popup failed: '+$_.Exception.Message)}
}

# Fix Lab workflow guidance is resolved exclusively by Get-PMMWorkflowState.

function Get-PMMImportGuidanceTarget {
  <#
  Import is recommended only when it can actually reconcile something safely.

  - Empty library: recommend importing from ~mods when source PAKs exist there,
    otherwise recommend normal file Import.
  - Non-empty library: recommend Import ~mods only for a game source PAK that
    is not represented by either the library or PMM's last deployment record,
    or when PMM can prove a previously deployed/library-identical PAK was
    changed externally in the game folder.

  If the PMM library itself advanced after Deploy, the old game copy is stale:
  Analyze/Deploy is the next step, never Import. PMM merge PAKs are ignored.
  #>
  $libraryFiles=@(Get-PMMAllLibrarySourcePakFiles)
  $libraryByName=@{}
  foreach($file in $libraryFiles){
    $name=[string]$file.Name
    if(-not[string]::IsNullOrWhiteSpace($name) -and -not$libraryByName.ContainsKey($name.ToLowerInvariant())){
      $libraryByName[$name.ToLowerInvariant()]=$file
    }
  }

  $state=Read-PMMDeploymentState
  $stateByName=@{}
  $stateDeployedUtc=$null
  if($state){
    try{if($state.PSObject.Properties.Name -contains 'Deployed'){$stateDeployedUtc=([datetime]$state.Deployed).ToUniversalTime()}}catch{}
    if($state.PSObject.Properties.Name -contains 'SourceMods'){
      foreach($item in @($state.SourceMods)){
        $name=[string]$item.Name
        if(-not[string]::IsNullOrWhiteSpace($name)){$stateByName[$name.ToLowerInvariant()]=$item}
      }
    }
  }

  $gameSourcePaks=@()
  try{
    $gameMods=Get-GameModsPath
    if(-not[string]::IsNullOrWhiteSpace([string]$gameMods) -and (Test-Path -LiteralPath $gameMods -PathType Container)){
      $gameSourcePaks=@(Get-ChildItem -LiteralPath $gameMods -Filter *.pak -File -ErrorAction SilentlyContinue |
        Where-Object{$_.Name -notlike 'zzzzzzzzzz_PMM_Merge_*_P.pak'})
    }
  }catch{$gameSourcePaks=@()}

  if($libraryFiles.Count -eq 0){
    if($gameSourcePaks.Count -gt 0){return 'GameMods'}
    return 'Files'
  }

  foreach($gamePak in $gameSourcePaks){
    $key=([string]$gamePak.Name).ToLowerInvariant()
    $libraryPak=if($libraryByName.ContainsKey($key)){$libraryByName[$key]}else{$null}
    $stateItem=if($stateByName.ContainsKey($key)){$stateByName[$key]}else{$null}

    if(-not$libraryPak){
      # A source previously managed by PMM but intentionally removed from the
      # library is waiting for Deploy removal, not re-import.
      if($stateItem){continue}
      return 'GameMods'
    }

    if($stateItem){
      $libraryHash=Get-PMMCachedFileHash $libraryPak
      $stateHash=[string]$stateItem.Hash
      if($stateHash -eq $libraryHash){
        if([int64]$libraryPak.Length -ne [int64]$gamePak.Length){return 'GameMods'}
        # Same-size replacements need a hash only when metadata proves the game
        # file changed after PMM recorded the deployment. Normal refresh never
        # hashes the whole deployed library.
        if($stateDeployedUtc -and $gamePak.LastWriteTimeUtc -gt $stateDeployedUtc.AddSeconds(2)){
          $gameHash=Get-PMMCachedFileHash $gamePak
          if($gameHash -ne $libraryHash){return 'GameMods'}
        }
      }
      continue
    }

    # No PMM deployment record: if the game copy is newer than the library,
    # treat a different-size file as an external install immediately. For a
    # same-size replacement, hash only this one candidate after metadata moved;
    # the 2-second heartbeat itself never hashes the full mod set.
    if($gamePak.LastWriteTimeUtc -gt $libraryPak.LastWriteTimeUtc.AddSeconds(2)){
      if([int64]$libraryPak.Length -ne [int64]$gamePak.Length){return 'GameMods'}
      $libraryHash=Get-PMMCachedFileHash $libraryPak
      $gameHash=Get-PMMCachedFileHash $gamePak
      if($gameHash -ne $libraryHash){return 'GameMods'}
    }
  }
  return ''
}

function Get-PMMGameModsFingerprint {
  <#
  Cheap external-change detector: names, sizes and LastWriteTime only. No PAK
  hashes are computed here, so even a 70+ GB mod set can be checked frequently.
  The expensive state comparison runs only when this metadata fingerprint moves.
  #>
  try{
    $gameMods=Get-GameModsPath
    if([string]::IsNullOrWhiteSpace([string]$gameMods)){return 'NO_GAME_PATH'}
    if(-not(Test-Path -LiteralPath $gameMods -PathType Container)){return ('MISSING|'+[string]$gameMods)}
    $parts=@(Get-ChildItem -LiteralPath $gameMods -Filter *.pak -File -ErrorAction SilentlyContinue |
      Sort-Object Name |
      ForEach-Object{('{0}|{1}|{2}' -f ([string]$_.Name).ToLowerInvariant(),[int64]$_.Length,[int64]$_.LastWriteTimeUtc.Ticks)})
    return (([string]$gameMods).ToLowerInvariant()+'::'+($parts -join ';'))
  }catch{return ('ERROR|'+$_.Exception.GetType().FullName)}
}

function Test-PMMDesiredDeploymentCurrent {
  param([array]$SourceMods=@())
  try{
    if($SourceMods.Count -eq 0){return $false}
    $state=Read-PMMDeploymentState
    if(-not$state){return $false}

    $context=Get-PMMDeploymentContext
    if(-not$context){return $false}
    if([string]$state.SourceSignature -ne [string]$context.Signature){return $false}

    $expectedPatch=$context.Patch
    $statePatch=$null
    if($state.PSObject.Properties.Name -contains 'Patch'){$statePatch=$state.Patch}
    if($expectedPatch){
      if(-not$statePatch){return $false}
      if([string]$statePatch.Name -ine [string]$expectedPatch.Name){return $false}
      if([string]$statePatch.Hash -ne [string]$expectedPatch.Hash){return $false}
    }elseif($statePatch){
      return $false
    }

    $suppressed=[System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach($name in @($context.Suppressed)){if($name){[void]$suppressed.Add([string]$name)}}

    $actual=@{}
    if($state.PSObject.Properties.Name -contains 'SourceMods'){
      foreach($item in @($state.SourceMods)){
        $name=[string]$item.Name
        if([string]::IsNullOrWhiteSpace($name)){continue}
        $actual[$name.ToLowerInvariant()]=$item
      }
    }
    if($actual.Count -ne $context.Active.Count){return $false}

    $gameMods=[string]$context.GameMods
    if([string]::IsNullOrWhiteSpace($gameMods) -or -not(Test-Path -LiteralPath $gameMods -PathType Container)){return $false}

    foreach($mod in @($context.Active)){
      $key=([string]$mod.Name).ToLowerInvariant()
      if(-not$actual.ContainsKey($key)){return $false}
      $item=$actual[$key]
      if([string]$item.Hash -ne [string]$mod.Hash){return $false}
      $expectedDeployed=-not$suppressed.Contains([string]$mod.Name)
      $actualDeployed=$true
      if($item.PSObject.Properties.Name -contains 'Deployed'){$actualDeployed=[bool]$item.Deployed}
      if($actualDeployed -ne $expectedDeployed){return $false}

      # Verify the real game folder cheaply, not only deployment-state.json.
      $gamePath=Join-Path $gameMods ([string]$mod.Name)
      if($expectedDeployed){
        if(-not(Test-Path -LiteralPath $gamePath -PathType Leaf)){return $false}
        try{
          $gameFile=Get-Item -LiteralPath $gamePath -ErrorAction Stop
          $sourcePath=[string]$mod.Path
          if(-not[string]::IsNullOrWhiteSpace($sourcePath) -and (Test-Path -LiteralPath $sourcePath -PathType Leaf)){
            $sourceFile=Get-Item -LiteralPath $sourcePath -ErrorAction Stop
            if([int64]$gameFile.Length -ne [int64]$sourceFile.Length){return $false}
          }
        }catch{return $false}
      }elseif(Test-Path -LiteralPath $gamePath -PathType Leaf){
        return $false
      }
    }

    $gameMergePaks=@(Get-ChildItem -LiteralPath $gameMods -Filter 'zzzzzzzzzz_PMM_Merge_*_P.pak' -File -ErrorAction SilentlyContinue)
    if($expectedPatch){
      $expectedGamePatch=Join-Path $gameMods ([string]$expectedPatch.Name)
      if(-not(Test-Path -LiteralPath $expectedGamePatch -PathType Leaf)){return $false}
      if(@($gameMergePaks|Where-Object{[string]$_.Name -ine [string]$expectedPatch.Name}).Count -gt 0){return $false}
      try{
        if($expectedPatch.PSObject.Properties.Name -contains 'Path' -and (Test-Path -LiteralPath ([string]$expectedPatch.Path) -PathType Leaf)){
          if([int64](Get-Item -LiteralPath $expectedGamePatch).Length -ne [int64](Get-Item -LiteralPath ([string]$expectedPatch.Path)).Length){return $false}
        }
      }catch{return $false}
    }elseif($gameMergePaks.Count -gt 0){
      return $false
    }

    return $true
  }catch{
    # If PMM cannot prove the desired deployment is current, Deploy remains the
    # final recommended step rather than claiming the game is ready.
    return $false
  }
}

function Test-PMMGameInstallationReady {
  try{
    $cfg=Get-PMMConfig
    if(-not$cfg.GamePath){return $false}
    return (-not[string]::IsNullOrWhiteSpace([string](Resolve-PalworldRoot ([string]$cfg.GamePath))))
  }catch{return $false}
}

function Get-PMMFixLabRequirementLightweight {
  # Prefer the loaded recipe engine. This respects per-hash Ignore rules and
  # avoids maintaining two different Fix Lab interpretations.
  if($Script:FixLabLoaded){
    try{
      $live=@(Get-PMMFixLabDiscoveryCandidates)
      $Script:FixLabCachedAttentionCandidates=@($live)
      if($live.Count -gt 0){$c=$live[0];return [pscustomobject]@{Loaded=$true;Candidate=$c;Recipe=(Get-PMMFixLabRecipe ([string]$c.RecipeId));Matches=@($c.Sources)}}
      return $null
    }catch{}
  }

  # Before the tab is loaded, match only the compact Stable recipe signatures.
  # This keeps Fix Lab lazy/failure-isolated while still letting the global
  # ColorFlow know that a repair must precede Analyze.
  try{
    $recipeFile=Join-Path (Get-PMMPath 'CKLFixLabStable') 'fix-recipes.json'
    if(-not(Test-Path -LiteralPath $recipeFile -PathType Leaf)){return $null}
    $doc=Get-Content -LiteralPath $recipeFile -Raw|ConvertFrom-Json
    $mods=@(Get-LibraryMods)
    if($mods.Count -eq 0){return $null}
    $ignored=@{}
    $ignorePath=Join-PMMPath 'State' 'fixlab-ignored-sources.json'
    if(Test-Path -LiteralPath $ignorePath -PathType Leaf){
      try{
        $ignoreDoc=Get-Content -LiteralPath $ignorePath -Raw|ConvertFrom-Json
        $ignoreRows=@($ignoreDoc)
        if($ignoreDoc -and ($ignoreDoc.PSObject.Properties.Name -contains 'Sources')){$ignoreRows=@($ignoreDoc.Sources)}
        foreach($r in $ignoreRows){if($r -and -not[string]::IsNullOrWhiteSpace([string]$r.Hash)){$ignored[([string]$r.Hash).ToLowerInvariant()]=$true}}
      }catch{}
    }
    foreach($recipe in @($doc.recipes)){
      if(-not($recipe.PSObject.Properties.Name -contains 'sourcePolicy') -or -not$recipe.sourcePolicy -or -not$recipe.sourcePolicy.automaticDetection){continue}
      $required=@($recipe.sourcePolicy.automaticDetection.requiredPakSha256|ForEach-Object{([string]$_).ToLowerInvariant()}|Where-Object{$_})
      if($required.Count -eq 0){continue}
      $matches=@($mods|Where-Object{$h=([string]$_.Hash).ToLowerInvariant();$required -contains $h -and -not$ignored.ContainsKey($h)})
      if($matches.Count -gt 0){return [pscustomobject]@{Loaded=$false;Candidate=$null;Recipe=$recipe;Matches=$matches}}
    }
  }catch{Write-PMMLog ('Lightweight Fix Lab routing check failed: '+$_.Exception.Message)}
  return $null
}

function Get-PMMWorkflowState {
  # ONE state machine is authoritative for both ColorFlow and AUTO.
  # Detect -> Import -> [Fix Lab: reference -> choice -> repair -> deploy] -> Analyze -> Build -> Deploy -> Play(optional)
  if(-not(Test-PMMGameInstallationReady)){
    return [pscustomobject]@{Action='Detect';Target=$Script:BtnDetectGame;Palette='Import';Key='Flow:Detect';Detail=(L 'Detect the Palworld installation before importing or deploying mods.' 'Detecta la instalacion de Palworld antes de importar o desplegar mods.')}
  }

  $sourceMods=@(Get-LibraryMods)
  $importTarget=Get-PMMImportGuidanceTarget
  if($importTarget -eq 'GameMods' -and $Script:BtnImportGameMods.IsEnabled){return [pscustomobject]@{Action='ImportGameMods';Target=$Script:BtnImportGameMods;Palette='Import';Key='Flow:ImportGameMods';Detail=(L 'Import the mods currently found in Palworld ~mods.' 'Importa los mods que estan actualmente en ~mods de Palworld.')}}
  if($importTarget -eq 'Files' -and $Script:BtnImport.IsEnabled){return [pscustomobject]@{Action='ImportFiles';Target=$Script:BtnImport;Palette='Import';Key='Flow:ImportFiles';Detail=(L 'Import mod files or a folder to begin.' 'Importa archivos de mod o una carpeta para comenzar.')}}

  # A supported legacy repair always precedes normal Analyze.
  # Game Reference is a dependency, not a navigation step: AUTO starts the
  # existing background builder directly before it ever asks the UI to open
  # Fix Lab.  This lets the user browse Settings/Fix Lab freely while the same
  # shared progress state updates both tabs.
  $fix=Get-PMMFixLabRequirementLightweight
  if($fix){
    $recipe=$fix.Recipe
    if(-not$recipe -and $Script:FixLabLoaded -and $fix.Candidate){$recipe=Get-PMMFixLabRecipe ([string]$fix.Candidate.RecipeId)}
    if(-not$recipe){
      return [pscustomobject]@{Action='FixLabOpen';Target=$Script:TabFixLab;Palette='Build';Key='Flow:FixLabOpenRecipe';Detail=(L 'A supported legacy mod was detected. Open Fix Lab to load its repair recipe.' 'Se detecto un mod antiguo compatible. Abre Fix Lab para cargar su receta de reparacion.')}
    }

    $variants=@($recipe.variants)
    $selected=[string]$Script:FixLabSelectedVariantId
    if(-not[string]::IsNullOrWhiteSpace($selected) -and @($variants|Where-Object{[string]$_.id -ieq $selected}).Count -eq 0){$selected='';$Script:FixLabSelectedVariantId=''}
    if($variants.Count -eq 1 -and [string]::IsNullOrWhiteSpace($selected)){$selected=[string]$variants[0].id;$Script:FixLabSelectedVariantId=$selected}

    $requiresCurrent=$false;try{$requiresCurrent=[bool]$recipe.referencePolicy.currentRequired}catch{}
    if($requiresCurrent){
      $gr=Get-PMMGameReferenceState
      if([string]$gr.Status -ne 'Current'){
        $grRunning=$false;try{$grRunning=($Script:GameReferenceProcess -and -not$Script:GameReferenceProcess.HasExited)}catch{}
        if(-not$grRunning){
          return [pscustomobject]@{Action='FixLabGameReference';Target=$Script:BtnFixLabBuildReference;Palette='Build';Key='Flow:FixLabGameReference';Detail=(L 'Create the current Game Reference in the background. You can keep using PMM while it builds.' 'Crea la Game Reference actual en segundo plano. Puedes seguir usando PMM mientras se crea.')}
        }

        # The reference is already building.  If the recipe has multiple
        # outputs, expose the human choice concurrently; never force the user
        # back to the Fix Lab tab after they navigate elsewhere.
        if(-not $Script:FixLabLoaded){
          return [pscustomobject]@{Action='FixLabOpen';Target=$Script:TabFixLab;Palette='Build';Key='Flow:FixLabPrepareChoice';Detail=(L 'Game Reference is building. Fix Lab can be opened now to choose the repair output while it continues.' 'Game Reference se esta creando. Puedes abrir Fix Lab ahora para elegir la salida mientras continua.')}
        }

        $candidate=$fix.Candidate
        if(-not$candidate){$candidate=Get-PMMFixLabSelectedCandidate}
        if(-not$candidate){
          return [pscustomobject]@{Action='FixLabOpen';Target=$Script:TabFixLab;Palette='Build';Key='Flow:FixLabRefresh';Detail=(L 'Game Reference is building. Open Fix Lab to refresh the detected repair case.' 'Game Reference se esta creando. Abre Fix Lab para actualizar el caso detectado.')}
        }
        $Script:FixLabSelectedRecipeId=[string]$candidate.RecipeId
        if([string]::IsNullOrWhiteSpace($selected) -and $variants.Count -gt 1){
          $choiceOnTab=($Script:MainTabs.SelectedItem -ne $Script:TabFixLab)
          $choiceTarget=if($choiceOnTab){$Script:TabFixLab}else{$Script:CmbFixLabVariant}
          $choiceKey=if($choiceOnTab){'Flow:FixLabVariantWhileReference:'+[string]$candidate.RecipeId+':Tab'}else{'Flow:FixLabVariantWhileReference:'+[string]$candidate.RecipeId+':Combo'}
          return [pscustomobject]@{Action='FixLabChooseVariant';Target=$choiceTarget;Palette='Build';Key=$choiceKey;Detail=((L 'Game Reference is building in the background. Choose one of {0} repair outputs now; AUTO will continue as soon as the reference is ready.' 'Game Reference se esta creando en segundo plano. Elige ahora una de las {0} salidas de reparacion; AUTO continuara en cuanto la referencia este lista.') -f $variants.Count)}
        }
        return [pscustomobject]@{Action='FixLabWaitReference';Target=$null;Palette='';Key='Flow:FixLabWaitReference';Detail=(L 'Game Reference is building in the background. No further action is required yet.' 'Game Reference se esta creando en segundo plano. Todavia no se requiere ninguna otra accion.')}
      }
    }

    # The dependency is ready. Load Fix Lab lazily only now (or while the
    # reference is building for the concurrent output choice). AUTO initializes
    # the module without changing the selected tab.
    if(-not $Script:FixLabLoaded){
      return [pscustomobject]@{Action='FixLabOpen';Target=$Script:TabFixLab;Palette='Build';Key='Flow:FixLabOpen';Detail=(L 'Game Reference is ready. Open Fix Lab to continue the detected repair.' 'Game Reference esta lista. Abre Fix Lab para continuar la reparacion detectada.')}
    }

    $candidate=$fix.Candidate
    if(-not$candidate){$candidate=Get-PMMFixLabSelectedCandidate}
    if(-not$candidate){return [pscustomobject]@{Action='FixLabOpen';Target=$Script:TabFixLab;Palette='Build';Key='Flow:FixLabRefreshReady';Detail=(L 'Refresh Fix Lab to select the detected repair case.' 'Actualiza Fix Lab para seleccionar el caso detectado.')}}
    $Script:FixLabSelectedRecipeId=[string]$candidate.RecipeId
    $recipe=Get-PMMFixLabRecipe ([string]$candidate.RecipeId)
    if(-not$recipe){return [pscustomobject]@{Action='FixLabBlocked';Target=$Script:TabFixLab;Palette='Build';Key='Flow:FixLabRecipeMissing';Detail=(L 'The exact repair recipe could not be loaded.' 'No se pudo cargar la receta exacta de reparacion.')}}

    $variants=@($recipe.variants)
    $selected=[string]$Script:FixLabSelectedVariantId
    if(-not[string]::IsNullOrWhiteSpace($selected) -and @($variants|Where-Object{[string]$_.id -ieq $selected}).Count -eq 0){$selected='';$Script:FixLabSelectedVariantId=''}
    if($variants.Count -eq 1 -and [string]::IsNullOrWhiteSpace($selected)){$selected=[string]$variants[0].id;$Script:FixLabSelectedVariantId=$selected;try{$Script:CmbFixLabVariant.SelectedValue=$selected}catch{}}

    if([string]::IsNullOrWhiteSpace($selected)){
      $choiceOnTab=($Script:MainTabs.SelectedItem -ne $Script:TabFixLab)
      $choiceTarget=if($choiceOnTab){$Script:TabFixLab}else{$Script:CmbFixLabVariant}
      $choiceKey=if($choiceOnTab){'Flow:FixLabVariant:'+[string]$candidate.RecipeId+':Tab'}else{'Flow:FixLabVariant:'+[string]$candidate.RecipeId+':Combo'}
      return [pscustomobject]@{Action='FixLabChooseVariant';Target=$choiceTarget;Palette='Build';Key=$choiceKey;Detail=((L 'Choose one of {0} repair outputs.' 'Elige una de las {0} salidas de reparacion.') -f $variants.Count)}
    }

    $built=@(Get-PMMFixLabBuiltOutputs|Where-Object{[string]$_.RecipeId -ieq [string]$candidate.RecipeId -and [string]$_.VariantId -ieq $selected}|Sort-Object BuiltUtc -Descending|Select-Object -First 1)[0]
    if(-not$built){
      $ready=Get-PMMFixLabCandidateBuildState $candidate $selected
      if(-not[bool]$ready.Ready){return [pscustomobject]@{Action='FixLabBlocked';Target=$Script:BtnFixLabRepair;Palette='Build';Key=('Flow:FixLabBlocked:'+$selected);Detail=[string]$ready.Reason}}
      return [pscustomobject]@{Action='FixLabRepair';Target=$Script:BtnFixLabRepair;Palette='Build';Key=('Flow:FixLabRepair:'+$selected);Detail=(L 'Build and validate the selected repair in the background.' 'Construye y valida la reparacion seleccionada en segundo plano.')}
    }
    $Script:FixLabSelectedBuildId=[string]$built.BuildId
    if(($built.PSObject.Properties.Name -contains 'Applied') -and [bool]$built.Applied){
      # Applied is terminal for Fix Lab. Normal Analyze is now authoritative.
    }elseif(-not(Test-PMMFixLabBuiltDeployAllowed $built)){
      $note=Get-PMMFixLabBuiltDeploymentNote $built;if([string]::IsNullOrWhiteSpace($note)){$note=L 'The built engine milestone is not deployable.' 'El hito construido del motor no se puede desplegar.'}
      return [pscustomobject]@{Action='FixLabBlocked';Target=$Script:LstFixLabBuiltFixes;Palette='Build';Key=('Flow:FixLabBuiltBlocked:'+[string]$built.BuildId);Detail=$note}
    }else{
      return [pscustomobject]@{Action='FixLabDeploy';Target=$Script:BtnFixLabApplyBuilt;Palette='Deploy';Key=('Flow:FixLabDeploy:'+[string]$built.BuildId);Detail=(L 'Deploy the repaired PAK and archive the legacy source. PMM will continue to Analyze.' 'Despliega el PAK reparado y archiva la fuente antigua. PMM continuara con Analyze.')}
    }
  }

  $analysisCurrent=$false
  if($sourceMods.Count -gt 0){try{$analysisCurrent=Test-PMMMergePlanCurrent}catch{$analysisCurrent=$false}}
  if($analysisCurrent){
    try{
      $decisionPlan=Read-PMMMergePlan
      $pendingDecisions=if($decisionPlan){@($decisionPlan.Rows|Where-Object{-not(Test-PMMDecisionRowResolved $_)}).Count}else{0}
      if($pendingDecisions -gt 0){return [pscustomobject]@{Action='ResolveDecisions';Target=$Script:ExpConflicts;Palette='Analyze';Key='Flow:ResolveDecisions';Detail=((L 'Resolve {0} compatibility decision(s) before Build can continue.' 'Resuelve {0} decision(es) de compatibilidad antes de continuar con Build.') -f $pendingDecisions)}}
    }catch{}
  }
  if($sourceMods.Count -gt 0 -and -not$analysisCurrent -and $Script:BtnScan.IsEnabled){return [pscustomobject]@{Action='Analyze';Target=$Script:BtnScan;Palette='Analyze';Key='Flow:Analyze';Detail=(L 'Analyze the current repaired/imported mod list.' 'Analiza la lista actual de mods importados/reparados.')}}
  if($analysisCurrent -and $Script:BtnBuild.IsEnabled){return [pscustomobject]@{Action='Build';Target=$Script:BtnBuild;Palette='Build';Key='Flow:Build';Detail=(L 'Build the compatibility overlay for this analysis.' 'Construye el overlay de compatibilidad para este analisis.')}}

  $deploymentCurrent=$false
  if($sourceMods.Count -gt 0){$deploymentCurrent=Test-PMMDesiredDeploymentCurrent $sourceMods}
  if($Script:BtnDeploy.IsEnabled -and -not$deploymentCurrent){return [pscustomobject]@{Action='Deploy';Target=$Script:BtnDeploy;Palette='Deploy';Key='Flow:Deploy';Detail=(L 'Deploy the selected source mods and compatibility patch.' 'Despliega los mods fuente y el parche de compatibilidad seleccionados.')}}
  # A current deployment always ends on the Play-ready state. The checkbox
  # controls automatic launch only; it must not hide the final guided action.
  if($sourceMods.Count -gt 0 -and $analysisCurrent -and $deploymentCurrent -and $Script:BtnPlay.IsEnabled){return [pscustomobject]@{Action='Play';Target=$Script:BtnPlay;Palette='Play';Key='Flow:Play';Detail=(L 'Everything is ready to play.' 'Ya está todo listo para jugar.')}}
  return [pscustomobject]@{Action='None';Target=$null;Palette='';Key='Flow:None';Detail=''}
}

function Get-PMMNextWorkflowAction { return [string](Get-PMMWorkflowState).Action }

function Update-PMMGuidedActionState {
  if($Script:ImportBusy -or $Script:AnalyzeBusy -or $Script:BuildBusy -or $Script:DeployBusy -or $Script:AIIOBusy -or $Script:FixLabOperationBusy -or ($Script:BackgroundOperationProcess -and -not$Script:BackgroundOperationProcess.HasExited)){return}
  Reset-PMMGuidedActionStyles
  $state=Get-PMMWorkflowState
  $target=$state.Target
  switch([string]$state.Action){
    'Detect' { if($Script:BtnDetectGame.Visibility -eq [System.Windows.Visibility]::Visible){Set-PMMGuideButtonStyle $Script:BtnDetectGame 'Import'} }
    'ImportGameMods' { Set-PMMGuideButtonStyle $Script:BtnImportGameMods 'Import' }
    'ImportFiles' { Set-PMMGuideButtonStyle $Script:BtnImport 'Import' }
    'FixLabGameReference' { Set-PMMGuideButtonStyle $Script:BtnFixLabBuildReference 'Build' }
    'FixLabWaitReference' { Clear-PMMRequiredAction;return }
    'FixLabRepair' { Set-PMMGuideButtonStyle $Script:BtnFixLabRepair 'Build' }
    'FixLabDeploy' { Set-PMMGuideButtonStyle $Script:BtnFixLabApplyBuilt 'Deploy' }
    'Analyze' { Set-PMMGuideButtonStyle $Script:BtnScan 'Analyze' }
    'Build' { Set-PMMGuideButtonStyle $Script:BtnBuild 'Build' }
    'Deploy' { Set-PMMGuideButtonStyle $Script:BtnDeploy 'Deploy' }
    'Play' { Set-PMMGuideButtonStyle $Script:BtnPlay 'Play' }
  }
  if([string]$state.Action -eq 'None'){Clear-PMMRequiredAction;return}
  Set-PMMRequiredAction $target ([string]$state.Key) ([string]$state.Detail)
}

function Get-PMMAutoAnalysisBlocker {
  $plan=$null
  try{if(Test-PMMMergePlanCurrent){$plan=Read-PMMMergePlan}}catch{}
  if(-not$plan){return ''}
  $unsupported=@($plan.Assets|Where-Object{[string]$_.Mode -eq 'Unsupported'}).Count
  if($unsupported -gt 0){return ((L 'Auto paused: Analyze found {0} unsupported shared asset(s). Review them or create an AI handoff.' 'Auto pausado: Analyze encontro {0} asset(s) compartido(s) no soportado(s). Revisalos o crea un handoff para IA.') -f $unsupported)}
  $packageChoices=@($plan.Assets|Where-Object{[string]$_.Mode -eq 'PackageChoice'}).Count
  if($packageChoices -gt 0){return ((L 'Auto paused: {0} package choice(s) require a user decision and re-analysis.' 'Auto pausado: {0} eleccion(es) de paquete requieren una decision del usuario y volver a analizar.') -f $packageChoices)}
  $unresolved=@($plan.Rows|Where-Object{[string]::IsNullOrWhiteSpace([string]$_.SelectedChoice)}).Count
  if($unresolved -gt 0){return ((L 'Auto paused: {0} conflict decision(s) still require a user choice.' 'Auto pausado: {0} decision(es) de conflicto aun requieren una eleccion del usuario.') -f $unresolved)}
  return ''
}

function Test-PMMAutoBuildRequiresConfirmation {
  try{
    $plan=Read-PMMMergePlan
    if(-not$plan){return $false}
    return (@($plan.Assets|Where-Object{[string]$_.Mode -eq 'ManualSolutionExperimental'}).Count -gt 0)
  }catch{return $false}
}

# Legacy AUTO/Fix Lab routing removed in RC6. Get-PMMWorkflowState is the single workflow authority.

function Ensure-PMMAutoFixLabGameReference {
  # AUTO prerequisite preflight.  The Settings button is the canonical Game
  # Reference command: manual Windows testing already proved that this path
  # launches the worker and updates BOTH Settings and Fix Lab progress bars.
  # AUTO therefore raises that exact command instead of maintaining a second
  # launch path that can drift from the manual implementation.
  if(-not$Script:AutoPipelineActive){return $false}
  $fix=$null
  try{$fix=Get-PMMFixLabRequirementLightweight}catch{Write-PMMLog ('AUTO Fix Lab preflight discovery warning: '+$_.Exception.Message)}
  if(-not$fix -or -not$fix.Recipe){return $false}

  $recipe=$fix.Recipe
  $requiresCurrent=$false;try{$requiresCurrent=[bool]$recipe.referencePolicy.currentRequired}catch{}
  if(-not$requiresCurrent){return $false}

  $gr=$null;try{$gr=Get-PMMGameReferenceState}catch{}
  if($gr -and [string]$gr.Status -eq 'Current'){
    $Script:AutoReferenceStartRecipeId=''
    return $false
  }

  $running=$false;try{$running=($Script:GameReferenceProcess -and -not$Script:GameReferenceProcess.HasExited)}catch{}
  if($running){return $true}

  # Do not cancel AUTO for a transient engine owner. The watchdog will call
  # this preflight again. This is especially important immediately after an
  # Import, when the library may already expose the Fix Lab candidate a few
  # milliseconds before Import releases its busy flag.
  $active=[string](Get-PMMActiveProcessingOperation)
  if(-not[string]::IsNullOrWhiteSpace($active)){
    if($active -ne 'GameReference'){Write-PMMLog ('AUTO Game Reference waiting for processing slot; active='+$active)}
    return $true
  }

  $recipeId=[string]$recipe.id
  try{
    $Script:TxtStatus.Text=L 'AUTO: starting the required Game Reference in the background...' 'AUTO: iniciando la Game Reference necesaria en segundo plano...'
    Write-PMMLog ('AUTO invoking canonical Game Reference command before Fix Lab navigation for recipe '+$recipeId)

    # This is intentionally the same routed click used by a human in Settings.
    # It performs config validation, arms the same completion callback and then
    # calls Start-PMMGameReferenceBuild.  No alternate AUTO worker path exists.
    Invoke-PMMButtonClick $Script:BtnBuildGameReference

    $started=$false
    try{$started=($Script:GameReferenceProcess -and -not$Script:GameReferenceProcess.HasExited)}catch{}
    if($started){
      $Script:AutoReferenceStartRecipeId=$recipeId
      Write-PMMLog ('AUTO Game Reference worker confirmed running for recipe '+$recipeId)
      try{Update-PMMGuidedActionState}catch{}
      return $true
    }

    # A processing-slot race can still happen between the check above and the
    # button handler. Keep AUTO alive; retry on the next watchdog tick.
    Write-PMMLog ('AUTO canonical Game Reference command returned without a running worker; will retry.')
    return $true
  }catch{
    Stop-PMMAutoPipeline ((L 'Auto paused: Game Reference could not be started: ' 'Auto pausado: no se pudo iniciar Game Reference: ')+$_.Exception.Message)
    return $true
  }
}

function Invoke-PMMButtonClick($Button) {
  if(-not$Button){return}
  $args=[System.Windows.RoutedEventArgs]::new([System.Windows.Controls.Button]::ClickEvent)
  $Button.RaiseEvent($args)
}

function Invoke-PMMAutoContinue {
  if(-not$Script:AutoPipelineActive){return}
  if(-not(Test-PMMAutoContinuationEnabled)){Stop-PMMAutoPipeline;return}
  if($Script:CancelRequested){Stop-PMMAutoPipeline (L 'Automatic workflow cancelled.' 'Flujo automatico cancelado.');return}

  # Dependency preflight is deliberately BEFORE the generic busy return.  It
  # will not start a competing worker, but it means AUTO can observe a newly
  # detected Fix Lab case immediately and begin Game Reference on the first
  # dispatcher turn after the previous operation actually releases its slot.
  [void](Ensure-PMMAutoFixLabGameReference)

  if($Script:AutoStepInProgress -or $Script:ImportBusy -or $Script:AnalyzeBusy -or $Script:BuildBusy -or $Script:DeployBusy -or $Script:AIIOBusy -or $Script:FixLabOperationBusy){return}
  try{if($Script:BackgroundOperationProcess -and -not$Script:BackgroundOperationProcess.HasExited){return}}catch{}
  $gameReferenceRunning=$false
  try{$gameReferenceRunning=($Script:GameReferenceProcess -and -not$Script:GameReferenceProcess.HasExited)}catch{}
  $state=Get-PMMWorkflowState
  $action=[string]$state.Action
  # A running Game Reference blocks processing actions, but it must NOT block
  # Fix Lab navigation/choice state. This is what lets the user choose an
  # output while the reference is still being built.
  if($gameReferenceRunning -and $action -notin @('FixLabOpen','FixLabChooseVariant','FixLabWaitReference')){return}
  if($action -eq 'Build'){
    $blocker=Get-PMMAutoAnalysisBlocker
    if(-not[string]::IsNullOrWhiteSpace($blocker)){Stop-PMMAutoPipeline $blocker;return}
    if(Test-PMMAutoBuildRequiresConfirmation){Stop-PMMAutoPipeline (L 'Auto paused: this Build contains an experimental AI/manual solution and needs explicit confirmation.' 'Auto pausado: este Build contiene una solucion experimental de IA/manual y necesita confirmacion explicita.');return}
  }

  # AUTO presents a detected Fix Lab case exactly once per repair case/run.
  # After that first navigation the user owns the tabs: changing to Settings
  # while Game Reference runs will never be undone by the AUTO watchdog.
  if($action -like 'FixLab*'){
    $routeRecipeId=''
    try{
      $routeFix=Get-PMMFixLabRequirementLightweight
      if($routeFix){
        if($routeFix.Recipe){$routeRecipeId=[string]$routeFix.Recipe.id}
        elseif($routeFix.Candidate){$routeRecipeId=[string]$routeFix.Candidate.RecipeId}
      }
    }catch{}
    if(-not[string]::IsNullOrWhiteSpace($routeRecipeId) -and [string]$Script:AutoFixLabPresentedRecipeId -ine $routeRecipeId){
      try{
        if(-not $Script:FixLabLoaded){[void](Initialize-PMMFixLabFeature)}
        if($Script:FixLabLoaded){
          Refresh-PMMFixLabUI
          $Script:MainTabs.SelectedItem=$Script:TabFixLab
          $Script:AutoFixLabPresentedRecipeId=$routeRecipeId
          Write-PMMLog ('AUTO presented Fix Lab once for recipe '+$routeRecipeId)
        }
      }catch{Write-PMMLog ('AUTO initial Fix Lab presentation warning: '+$_.Exception.Message)}
    }
  }

  if([string]$state.Key -cne [string]$Script:AutoLastWorkflowKey){
    $Script:AutoLastWorkflowKey=[string]$state.Key
    Write-PMMLog ('AUTO workflow state: '+[string]$state.Action+' | '+[string]$state.Key)
  }

  $Script:AutoStepInProgress=$true
  try{
    switch($action){
      'Detect' {
        Reset-PMMOperationCancellation
        Invoke-PMMButtonClick $Script:BtnDetectGame
        if((Get-PMMNextWorkflowAction) -eq 'Detect'){Stop-PMMAutoPipeline (L 'Auto paused: choose a valid Steam or Palworld folder to continue.' 'Auto pausado: elige una carpeta valida de Steam o Palworld para continuar.')}
      }
      'ImportGameMods' { Reset-PMMOperationCancellation;Invoke-PMMButtonClick $Script:BtnImportGameMods }
      'ImportFiles' { Stop-PMMAutoPipeline (L 'Auto paused: choose the mod files/folder to import, then press AUTO again (or enable Auto ON).' 'Auto pausado: elige los archivos/carpeta de mods que quieres importar y despues pulsa AUTO de nuevo (o activa Auto ON).') }
      'FixLabOpen' {
        if(-not $Script:FixLabLoaded){[void](Initialize-PMMFixLabFeature)}
        if($Script:FixLabLoaded){Refresh-PMMFixLabUI}
        # Initial navigation is handled once above. Repeated watchdog passes
        # only refresh state and never steal the user's current tab.
        try{Update-PMMGuidedActionState}catch{}
      }
      'FixLabGameReference' {
        # Normally the preflight above has already launched it. If a transient
        # slot race delayed launch, keep AUTO alive and let the watchdog retry.
        [void](Ensure-PMMAutoFixLabGameReference)
      }
      'FixLabChooseVariant' {
        $Script:TxtStatus.Text=[string]$state.Detail
        try{Update-PMMGuidedActionState}catch{}
        return
      }
      'FixLabWaitReference' { return }
      'FixLabRepair' { Reset-PMMOperationCancellation;Invoke-PMMButtonClick $Script:BtnFixLabRepair }
      'FixLabDeploy' { Reset-PMMOperationCancellation;Invoke-PMMButtonClick $Script:BtnFixLabApplyBuilt }
      'FixLabBlocked' { Stop-PMMAutoPipeline ([string]$state.Detail) }
      'ResolveDecisions' {$Script:ExpConflicts.IsExpanded=$true;$Script:TxtStatus.Text=[string]$state.Detail;try{Update-PMMGuidedActionState}catch{};return}
      'Analyze' { Reset-PMMOperationCancellation;Invoke-PMMButtonClick $Script:BtnScan }
      'Build' { Reset-PMMOperationCancellation;Invoke-PMMButtonClick $Script:BtnBuild }
      'Deploy' { Reset-PMMOperationCancellation;Invoke-PMMButtonClick $Script:BtnDeploy }
      'Play' {
        if([bool]$Script:ChkAutoPlay.IsChecked){Invoke-PMMButtonClick $Script:BtnPlay;Complete-PMMAutoPipeline}
        else{Complete-PMMAutoPipeline (L 'Automatic workflow complete. Palworld launch is optional.' 'Flujo automatico terminado. Iniciar Palworld es opcional.')}
      }
      default { Complete-PMMAutoPipeline (L 'Automatic workflow is complete.' 'El flujo automatico ha terminado.') }
    }
  }finally{$Script:AutoStepInProgress=$false}
}

function Check-PMMExternalModChanges([switch]$Force) {
  try{
    $fingerprint=Get-PMMGameModsFingerprint
    $changed=($fingerprint -cne [string]$Script:GameModsFingerprint)
    $Script:GameModsFingerprint=$fingerprint
    if($Force -or $changed){Update-PMMGuidedActionState}
  }catch{Write-PMMLog ('External ~mods state check failed: '+$_.Exception.Message)}
}


function Show-Info([string]$Message) {
  # Informational results are persistent/non-modal. PMM reserves modal dialogs
  # for errors and decisions that really require the user to answer.
  if(-not[string]::IsNullOrWhiteSpace($Message)){
    try{$Script:TxtStatus.Text=$Message}catch{}
    try{$Script:TxtOperationProgress.Text=$Message}catch{}
    Write-PMMLog ('Info: '+$Message)
  }
}

function Show-Error([string]$Message) {
  try{Play-PMMSoundEvent 'Error'}catch{}
  [System.Windows.MessageBox]::Show($Message,'Palworld Manager Merger',[System.Windows.MessageBoxButton]::OK,[System.Windows.MessageBoxImage]::Error) | Out-Null
}

function Get-PMMUiNumber($Config,[string]$Property,[double]$Default,[double]$Minimum,[double]$Maximum) {
  $value=$Default
  try {
    if($Config -and ($Config.PSObject.Properties.Name -contains $Property)){$value=[double]$Config.$Property}
  } catch {$value=$Default}
  if([double]::IsNaN($value) -or [double]::IsInfinity($value)){$value=$Default}
  return [Math]::Max($Minimum,[Math]::Min($Maximum,$value))
}

function Get-PMMUsableWorkArea {
  try{return [System.Windows.SystemParameters]::WorkArea}catch{return [System.Windows.Rect]::new(0,0,1920,1080)}
}

$Script:ResponsiveLayoutNarrow=$false
$Script:ResponsiveHeaderStacked=$false
$Script:ResponsiveSavedLibraryWidth=470.0
function Update-PMMResponsiveLayout {
  try{
    $width=[double]$Window.ActualWidth;if($width -le 0){$width=[double]$Window.Width}
    $narrow=($width -lt 1080)
    $extreme=($width -lt 840)
    # 900 DIPs remains the normal minimum. A highly-scaled 1080p desktop can
    # expose less than that, so both work columns temporarily relax their own
    # minima instead of forcing one side completely off-screen.
    $Script:ColLibrary.MinWidth=if($extreme){240.0}else{290.0}
    $Script:ColAnalysisWorkspace.MinWidth=if($extreme){330.0}else{460.0}
    if($narrow -ne [bool]$Script:ResponsiveLayoutNarrow){
      if($narrow){
        $current=[double]$Script:ColLibrary.ActualWidth
        if($current -le 0 -and $Script:ColLibrary.Width.IsAbsolute){$current=[double]$Script:ColLibrary.Width.Value}
        if($current -ge 290){$Script:ResponsiveSavedLibraryWidth=$current}
        $lower=if($extreme){240.0}else{290.0};$upper=if($extreme){260.0}else{330.0}
        $target=[Math]::Max($lower,[Math]::Min($upper,$width*0.34))
        $Script:ColLibrary.Width=[System.Windows.GridLength]::new($target)
      }else{
        $target=[Math]::Max(330.0,[Math]::Min(520.0,[double]$Script:ResponsiveSavedLibraryWidth))
        $Script:ColLibrary.Width=[System.Windows.GridLength]::new($target)
      }
      $Script:ResponsiveLayoutNarrow=$narrow
    }elseif($narrow){
      $lower=if($extreme){240.0}else{290.0};$upper=if($extreme){260.0}else{330.0}
      $target=[Math]::Max($lower,[Math]::Min($upper,$width*0.34))
      if([Math]::Abs([double]$Script:ColLibrary.Width.Value-$target) -gt 2){$Script:ColLibrary.Width=[System.Windows.GridLength]::new($target)}
    }

    # Below the ordinary minimum (possible on a highly scaled 1080p work area),
    # move actions below the brand instead of allowing either side to vanish.
    $stackHeader=$extreme
    if($stackHeader -ne [bool]$Script:ResponsiveHeaderStacked){
      if($stackHeader){
        [System.Windows.Controls.Grid]::SetRow($Script:GrdHeaderActions,1)
        [System.Windows.Controls.Grid]::SetColumn($Script:GrdHeaderActions,0)
        [System.Windows.Controls.Grid]::SetColumnSpan($Script:GrdHeaderActions,2)
        $Script:GrdHeaderActions.Margin=[System.Windows.Thickness]::new(0,10,0,0)
      }else{
        [System.Windows.Controls.Grid]::SetRow($Script:GrdHeaderActions,0)
        [System.Windows.Controls.Grid]::SetColumn($Script:GrdHeaderActions,1)
        [System.Windows.Controls.Grid]::SetColumnSpan($Script:GrdHeaderActions,1)
        $Script:GrdHeaderActions.Margin=[System.Windows.Thickness]::new(0)
      }
      $Script:ResponsiveHeaderStacked=$stackHeader
    }
  }catch{Write-PMMLog ('Could not update responsive UI layout: '+$_.Exception.Message)}
}

function Apply-PMMLayoutFromConfig {
  try {
    $cfg=Get-PMMConfig
    $work=Get-PMMUsableWorkArea
    $maxWidth=[Math]::Max(640.0,[double]$work.Width-24.0)
    $maxHeight=[Math]::Max(440.0,[double]$work.Height-48.0)
    $minWidth=[Math]::Min(900.0,$maxWidth)
    $minHeight=[Math]::Min(600.0,$maxHeight)
    $Window.MinWidth=$minWidth;$Window.MinHeight=$minHeight
    $Window.Width=Get-PMMUiNumber $cfg 'UiWindowWidth' 1460 $minWidth $maxWidth
    $Window.Height=Get-PMMUiNumber $cfg 'UiWindowHeight' 900 $minHeight $maxHeight
    $Script:ColLibrary.Width=[System.Windows.GridLength]::new((Get-PMMUiNumber $cfg 'UiLibraryWidth' 470 320 900))
    $Script:ResponsiveSavedLibraryWidth=[double]$Script:ColLibrary.Width.Value
    $Script:RowPatches.Height=[System.Windows.GridLength]::new((Get-PMMUiNumber $cfg 'UiPatchHeight' 180 110 520))
    $Script:ColConflictAssets.Width=[System.Windows.GridLength]::new((Get-PMMUiNumber $cfg 'UiConflictListWidth' 250 175 650))
    $Script:SavedAnalysisHeight=Get-PMMUiNumber $cfg 'UiAnalysisHeight' 300 120 1400
    $Script:SavedResolutionHeight=Get-PMMUiNumber $cfg 'UiResolutionHeight' 220 120 1200
    if(($cfg.PSObject.Properties.Name -contains 'UiWindowState') -and [string]$cfg.UiWindowState -eq 'Maximized'){
      $Window.WindowState=[System.Windows.WindowState]::Maximized
    }
    Update-PMMResponsiveLayout
  } catch {
    Write-PMMLog ('Could not restore UI layout: '+$_.Exception.Message)
  }
}

function Update-PMMWorkspaceRows {
  try {
    $analysis=[bool]$Script:ExpAnalysis.IsExpanded
    $resolution=[bool]$Script:ExpConflicts.IsExpanded
    $Script:SplAnalysisResolution.Visibility=[System.Windows.Visibility]::Collapsed
    $Script:RowAnalysisConflictSplitter.Height=[System.Windows.GridLength]::new(0.0)
    $Script:RowWorkspaceFiller.Height=[System.Windows.GridLength]::new(0.0)

    if($analysis -and $resolution){
      $a=if($Script:SavedAnalysisHeight -and [double]$Script:SavedAnalysisHeight -gt 0){[double]$Script:SavedAnalysisHeight}else{300.0}
      $r=if($Script:SavedResolutionHeight -and [double]$Script:SavedResolutionHeight -gt 0){[double]$Script:SavedResolutionHeight}else{220.0}
      $Script:RowAnalysisWorkspace.Height=[System.Windows.GridLength]::new($a,[System.Windows.GridUnitType]::Star)
      $Script:RowResolutionWorkspace.Height=[System.Windows.GridLength]::new($r,[System.Windows.GridUnitType]::Star)
      $Script:RowAnalysisConflictSplitter.Height=[System.Windows.GridLength]::new(6.0)
      $Script:SplAnalysisResolution.Visibility=[System.Windows.Visibility]::Visible
      return
    }
    if($analysis){
      $Script:RowAnalysisWorkspace.Height=[System.Windows.GridLength]::new(1.0,[System.Windows.GridUnitType]::Star)
      $Script:RowResolutionWorkspace.Height=[System.Windows.GridLength]::Auto
      return
    }
    if($resolution){
      $Script:RowAnalysisWorkspace.Height=[System.Windows.GridLength]::Auto
      $Script:RowResolutionWorkspace.Height=[System.Windows.GridLength]::new(1.0,[System.Windows.GridUnitType]::Star)
      return
    }
    $Script:RowAnalysisWorkspace.Height=[System.Windows.GridLength]::Auto
    $Script:RowResolutionWorkspace.Height=[System.Windows.GridLength]::Auto
    $Script:RowWorkspaceFiller.Height=[System.Windows.GridLength]::new(1.0,[System.Windows.GridUnitType]::Star)
  } catch {
    Write-PMMLog ('Could not update collapsible workspace rows: '+$_.Exception.Message)
  }
}

function Save-PMMLayoutSettings {
  try {
    $cfg=Get-PMMConfig
    $bounds=if($Window.WindowState -eq [System.Windows.WindowState]::Normal){$null}else{$Window.RestoreBounds}
    $width=if($bounds){[double]$bounds.Width}else{[double]$Window.ActualWidth}
    $height=if($bounds){[double]$bounds.Height}else{[double]$Window.ActualHeight}
    if($width -ge 640){$cfg.UiWindowWidth=[Math]::Round($width)}
    if($height -ge 440){$cfg.UiWindowHeight=[Math]::Round($height)}
    $cfg.UiWindowState=[string]$Window.WindowState
    if($Script:ResponsiveLayoutNarrow){$cfg.UiLibraryWidth=[Math]::Round([double]$Script:ResponsiveSavedLibraryWidth)}elseif($Script:ColLibrary.ActualWidth -gt 0){$cfg.UiLibraryWidth=[Math]::Round($Script:ColLibrary.ActualWidth)}
    if($Script:RowPatches.ActualHeight -gt 0){$cfg.UiPatchHeight=[Math]::Round($Script:RowPatches.ActualHeight)}
    if($Script:ColConflictAssets.ActualWidth -gt 0){$cfg.UiConflictListWidth=[Math]::Round($Script:ColConflictAssets.ActualWidth)}
    if($Script:ExpAnalysis.IsExpanded -and $Script:RowAnalysisWorkspace.ActualHeight -gt 100){$cfg.UiAnalysisHeight=[Math]::Round($Script:RowAnalysisWorkspace.ActualHeight)}
    if($Script:ExpConflicts.IsExpanded -and $Script:RowResolutionWorkspace.ActualHeight -gt 100){$cfg.UiResolutionHeight=[Math]::Round($Script:RowResolutionWorkspace.ActualHeight)}
    Save-PMMConfig $cfg
  } catch {
    Write-PMMLog ('Could not save UI layout: '+$_.Exception.Message)
  }
}

function Reset-PMMLayout {
  $Window.WindowState=[System.Windows.WindowState]::Normal
  $work=Get-PMMUsableWorkArea
  $Window.Width=[Math]::Min(1460.0,[Math]::Max(640.0,[double]$work.Width-24.0))
  $Window.Height=[Math]::Min(900.0,[Math]::Max(440.0,[double]$work.Height-48.0))
  $Script:ColLibrary.Width=[System.Windows.GridLength]::new(470.0)
  $Script:ResponsiveSavedLibraryWidth=470.0
  $Script:RowPatches.Height=[System.Windows.GridLength]::new(180.0)
  $Script:ColConflictAssets.Width=[System.Windows.GridLength]::new(250.0)
  $Script:SavedAnalysisHeight=300.0
  $Script:SavedResolutionHeight=220.0
  Update-PMMWorkspaceRows
  Update-PMMResponsiveLayout
  Save-PMMLayoutSettings
}

function Confirm([string]$Message) {
  return ([System.Windows.MessageBox]::Show($Message,'Palworld Manager Merger',[System.Windows.MessageBoxButton]::YesNo,[System.Windows.MessageBoxImage]::Question) -eq [System.Windows.MessageBoxResult]::Yes)
}

Apply-PMMLayoutFromConfig
$Window.Add_SizeChanged({Update-PMMResponsiveLayout})
Ensure-PMMUiResponsivenessMonitor
Update-PMMWorkspaceRows

# ---------------------------------------------------------------------------
# Workflow progress. Import / Analyze / Build / Deploy reuse their own button
# as the local progress surface. A persistent universal progress bar below
# Build/Deploy mirrors the same real progress and keeps the last completed 100%
# result until a new operation starts. Legacy per-panel bars stay hidden except
# where an advanced workspace explicitly needs them.
# ---------------------------------------------------------------------------
function Set-PMMAnalyzeProgress {
  param([int]$Current,[int]$Total,[string]$Message,[switch]$Indeterminate)
  $fraction=if($Total -gt 0){[double]$Current/[double]$Total}else{0.0}
  Set-PMMWorkflowButtonProgress $Script:BtnScan 'Analyze' $fraction $Message -Indeterminate:$Indeterminate
  Set-PMMUniversalProgress -Operation 'Analyze' -Fraction $fraction -Message $Message -Indeterminate:$Indeterminate
}

$Script:AnalyzeBusy=$false
function Update-PMMAnalyzeIndicator {
  if($Script:AnalyzeBusy){return}
  # The analysis workspace itself already shows whether the plan is current.
  # Do not duplicate that state with a permanent progress bar.
  $Script:PrgAnalyze.IsIndeterminate=$false
  $Script:PrgAnalyze.Visibility=[System.Windows.Visibility]::Collapsed
  Reset-PMMSmoothedProgressBar 'AIIO' $Script:PrgAnalyze
  $Script:TxtAnalyzeProgress.Text=''
}

function Set-PMMAnalyzeBusy([bool]$Busy) {
  $Script:AnalyzeBusy=$Busy
  Update-PMMCancelButtonState
  $enabled=-not$Busy
  $Script:BtnScan.IsEnabled=$true
  $Script:BtnScan.IsHitTestVisible=$enabled
  $Script:BtnScan.Focusable=$enabled
  $Script:BtnImport.IsEnabled=$enabled
  $Script:BtnImportGameMods.IsEnabled=$enabled
  $Script:LstMods.IsEnabled=$enabled
  if($Busy){
    Update-PMMLibraryButtons
    Reset-PMMGuidedActionStyles
    $Script:BtnPriorityUp.IsEnabled=$false;$Script:BtnPriorityDown.IsEnabled=$false;$Script:BtnDeleteMod.IsEnabled=$false
    Set-PMMWorkflowButtonProgress $Script:BtnScan 'Analyze' 0.0 (L 'Starting Analyze...' 'Iniciando Analizar...') -Indeterminate
  }else{
    Clear-PMMWorkflowButtonVisual $Script:BtnScan
    $Script:BtnScan.IsHitTestVisible=$true
    $Script:BtnScan.Focusable=$true
    Update-PMMLibraryButtons
    Update-PMMAnalyzeIndicator
    Update-BuildButtonState
    Update-PMMGuidedActionState
  }
}

function Set-PMMBuildProgress {
  param([int]$Current,[int]$Total,[string]$Message,[switch]$Indeterminate)
  $fraction=if($Total -gt 0){[double]$Current/[double]$Total}else{0.0}
  Set-PMMWorkflowButtonProgress $Script:BtnBuild 'Build' $fraction $Message -Indeterminate:$Indeterminate
  Set-PMMUniversalProgress -Operation 'Build' -Fraction $fraction -Message $Message -Indeterminate:$Indeterminate
}

function Set-PMMBuildBusy([bool]$Busy) {
  $Script:BuildBusy=$Busy
  Update-PMMCancelButtonState
  if($Busy){
    Reset-PMMGuidedActionStyles
    $Script:BtnBuild.IsEnabled=$true
    $Script:BtnBuild.IsHitTestVisible=$false
    $Script:BtnBuild.Focusable=$false
    $Script:BtnDeploy.IsEnabled=$false
    $Script:BtnScan.IsEnabled=$false
    $Script:BtnImport.IsEnabled=$false
    $Script:BtnImportGameMods.IsEnabled=$false
    $Script:LstMods.IsEnabled=$false
    Update-PMMLibraryButtons
    $Script:BtnPriorityUp.IsEnabled=$false;$Script:BtnPriorityDown.IsEnabled=$false;$Script:BtnDeleteMod.IsEnabled=$false
    Set-PMMWorkflowButtonProgress $Script:BtnBuild 'Build' 0.0 (L 'Preparing build...' 'Preparando build...') -Indeterminate
  }else{
    Clear-PMMWorkflowButtonVisual $Script:BtnBuild
    $Script:BtnBuild.IsHitTestVisible=$true
    $Script:BtnBuild.Focusable=$true
    $Script:BtnScan.IsEnabled=$true
    $Script:BtnImport.IsEnabled=$true
    $Script:BtnImportGameMods.IsEnabled=$true
    $Script:LstMods.IsEnabled=$true
    $Script:PrgBuild.IsIndeterminate=$false
    $Script:PrgBuild.Visibility=[System.Windows.Visibility]::Collapsed
    $Script:PrgBuild.Value=0
    $Script:TxtBuildProgress.Text=''
    Update-PMMLibraryButtons
    Update-BuildButtonState
    Update-PMMGuidedActionState
  }
}

function Set-PMMDeployProgress {
  param([int]$Current,[int]$Total,[string]$Message,[switch]$Indeterminate)
  $fraction=if($Total -gt 0){[double]$Current/[double]$Total}else{0.0}
  Set-PMMWorkflowButtonProgress $Script:BtnDeploy 'Deploy' $fraction $Message -Indeterminate:$Indeterminate
  Set-PMMUniversalProgress -Operation 'Deploy' -Fraction $fraction -Message $Message -Indeterminate:$Indeterminate
}

function Set-PMMDeployBusy([bool]$Busy) {
  $Script:DeployBusy=$Busy
  Update-PMMCancelButtonState
  if($Busy){
    Reset-PMMGuidedActionStyles
    $Script:BtnBuild.IsEnabled=$false
    $Script:BtnDeploy.IsEnabled=$true
    $Script:BtnDeploy.IsHitTestVisible=$false
    $Script:BtnDeploy.Focusable=$false
    $Script:BtnScan.IsEnabled=$false
    $Script:BtnImport.IsEnabled=$false
    $Script:BtnImportGameMods.IsEnabled=$false
    $Script:BtnPlay.IsEnabled=$false
    $Script:LstMods.IsEnabled=$false
    Update-PMMLibraryButtons
    $Script:BtnPriorityUp.IsEnabled=$false;$Script:BtnPriorityDown.IsEnabled=$false;$Script:BtnDeleteMod.IsEnabled=$false
    Set-PMMWorkflowButtonProgress $Script:BtnDeploy 'Deploy' 0.0 (L 'Preparing deployment...' 'Preparando despliegue...') -Indeterminate
  }else{
    Clear-PMMWorkflowButtonVisual $Script:BtnDeploy
    $Script:BtnDeploy.IsHitTestVisible=$true
    $Script:BtnDeploy.Focusable=$true
    $Script:BtnPlay.IsEnabled=$true
    $Script:BtnScan.IsEnabled=$true
    $Script:BtnImport.IsEnabled=$true
    $Script:BtnImportGameMods.IsEnabled=$true
    $Script:LstMods.IsEnabled=$true
    Update-PMMLibraryButtons
    Update-BuildButtonState
    Update-PMMGuidedActionState
  }
}

function Set-PMMImportProgress {
  param($Button,[double]$Fraction,[string]$Message,[switch]$Indeterminate)
  Set-PMMWorkflowButtonProgress $Button 'Import' $Fraction $Message -Indeterminate:$Indeterminate
  Set-PMMUniversalProgress -Operation 'Import' -Fraction $Fraction -Message $Message -Indeterminate:$Indeterminate
}

function Set-PMMImportBusy($Button,[bool]$Busy) {
  $Script:ImportBusy=$Busy
  Update-PMMCancelButtonState
  if($Busy){
    $Script:ImportBusyButton=$Button
    Reset-PMMGuidedActionStyles
    $Script:BtnImport.IsEnabled=($Button -eq $Script:BtnImport)
    $Script:BtnImportGameMods.IsEnabled=($Button -eq $Script:BtnImportGameMods)
    $Button.IsHitTestVisible=$false
    $Button.Focusable=$false
    $Script:BtnScan.IsEnabled=$false
    $Script:BtnBuild.IsEnabled=$false
    $Script:BtnDeploy.IsEnabled=$false
    $Script:LstMods.IsEnabled=$false
    Update-PMMLibraryButtons
    $Script:BtnPriorityUp.IsEnabled=$false;$Script:BtnPriorityDown.IsEnabled=$false;$Script:BtnDeleteMod.IsEnabled=$false
    Set-PMMImportProgress $Button 0.0 (L 'Preparing import...' 'Preparando importacion...') -Indeterminate
  }else{
    if($Script:ImportBusyButton){Clear-PMMWorkflowButtonVisual $Script:ImportBusyButton;$Script:ImportBusyButton.IsHitTestVisible=$true;$Script:ImportBusyButton.Focusable=$true}
    $Script:ImportBusyButton=$null
    $Script:BtnImport.IsEnabled=$true
    $Script:BtnImportGameMods.IsEnabled=$true
    $Script:BtnScan.IsEnabled=$true
    $Script:LstMods.IsEnabled=$true
    Update-PMMLibraryButtons
    Update-BuildButtonState
    Update-PMMGuidedActionState
  }
}

function Set-PMMAIIOProgress {
  param([int]$Current,[int]$Total,[string]$Message,[switch]$Indeterminate)
  $fraction=if($Total -gt 0){[double]$Current/[double]$Total}else{0.0}
  $unknown=([bool]$Indeterminate -or $Total -le 0)
  $Script:PrgAnalyze.Visibility=[System.Windows.Visibility]::Visible
  $Script:TxtAnalyzeProgress.Text=$Message
  [void](Set-PMMSmoothedProgressBar $Script:PrgAnalyze 'AIIO' (100.0*$fraction) -Operation 'AIIO' -Message $Message -Indeterminate:$unknown)
  $Script:TxtStatus.Text=$Message
  Set-PMMUniversalProgress -Operation 'AIIO' -Fraction $fraction -Message $Message -Indeterminate:$unknown
  try{[System.Windows.Forms.Application]::DoEvents()}catch{}
}

function Set-PMMAIIOBusy([bool]$Busy) {
  $Script:AIIOBusy=$Busy
  Update-PMMCancelButtonState
  if($Busy){
    Reset-PMMGuidedActionStyles
    $Script:BtnOpenAIHandoff.IsEnabled=$false
    foreach($button in @($Script:BtnAIIONewSession,$Script:BtnAIIOPrepare,$Script:BtnAIIOImportResponse,$Script:BtnAIIOContinue,$Script:BtnAIIOArchive,$Script:BtnAIIOUseCandidate,$Script:BtnAIHelpCleanup)){$button.IsEnabled=$false}
    $Script:BtnScan.IsEnabled=$false
    $Script:BtnImport.IsEnabled=$false
    $Script:BtnImportGameMods.IsEnabled=$false
    $Script:LstMods.IsEnabled=$false
    Update-PMMLibraryButtons
    $Script:BtnPriorityUp.IsEnabled=$false;$Script:BtnPriorityDown.IsEnabled=$false;$Script:BtnDeleteMod.IsEnabled=$false
    Set-PMMAIIOProgress 0 0 (L 'Creating AI handoff bundle...' 'Creando paquete de entrega para IA...') -Indeterminate
  }else{
    $Script:BtnScan.IsEnabled=$true
    $Script:BtnImport.IsEnabled=$true
    $Script:BtnImportGameMods.IsEnabled=$true
    $Script:LstMods.IsEnabled=$true
    Update-PMMLibraryButtons
    Update-PMMAnalyzeIndicator
    Update-BuildButtonState
    Update-PMMGuidedActionState
    try{Show-SelectedUnsupportedAsset}catch{}
    try{Refresh-PMMAIHelpUi}catch{}
  }
}


function Set-PMMFixLabProgress {
  param([int]$Current,[int]$Total,[string]$Message,[switch]$Indeterminate)
  $fraction=if($Total -gt 0){[double]$Current/[double]$Total}else{0.0}
  if($Script:TxtFixLabRepairState){$Script:TxtFixLabRepairState.Text=$Message}
  if($Script:TxtFixLabRepairProgress){$Script:TxtFixLabRepairProgress.Text=$Message;$Script:TxtFixLabRepairProgress.Visibility=[System.Windows.Visibility]::Visible}
  if($Script:PrgFixLabRepair){$Script:PrgFixLabRepair.Visibility=[System.Windows.Visibility]::Visible;[void](Set-PMMSmoothedProgressBar $Script:PrgFixLabRepair 'FixLab' ($fraction*100.0) -Operation 'FixLab' -Message $Message -Indeterminate:$Indeterminate)}
  Set-PMMUniversalProgress -Operation 'FixLab' -Fraction $fraction -Message $Message -Indeterminate:$Indeterminate
}

function Set-PMMFixLabBusy([bool]$Busy) {
  $Script:FixLabOperationBusy=$Busy
  Update-PMMCancelButtonState
  if($Busy){
    Reset-PMMGuidedActionStyles
    # The rest of WPF remains navigable. Only controls that would alter the
    # active Fix Lab job or start another conflicting operation are locked.
    if($Script:BtnFixLabRepair){$Script:BtnFixLabRepair.IsEnabled=$false}
    if($Script:BtnFixLabApplyBuilt){$Script:BtnFixLabApplyBuilt.IsEnabled=$false}
    if($Script:BtnFixLabDiscover){$Script:BtnFixLabDiscover.IsEnabled=$false}
    if($Script:BtnFixLabBuildReference){$Script:BtnFixLabBuildReference.IsEnabled=$false}
    if($Script:CmbFixLabVariant){$Script:CmbFixLabVariant.IsEnabled=$false}
    if($Script:LstFixLabCandidates){$Script:LstFixLabCandidates.IsEnabled=$false}
    Set-PMMFixLabProgress 0 0 (L 'Fix Lab is running in the processing engine. You can continue browsing PMM.' 'Fix Lab se esta ejecutando en el motor de procesamiento. Puedes seguir navegando por PMM.') -Indeterminate
  }else{
    if($Script:BtnFixLabDiscover){$Script:BtnFixLabDiscover.IsEnabled=$true}
    if($Script:BtnFixLabBuildReference){$Script:BtnFixLabBuildReference.IsEnabled=$true}
    if($Script:CmbFixLabVariant){$Script:CmbFixLabVariant.IsEnabled=$true}
    if($Script:LstFixLabCandidates){$Script:LstFixLabCandidates.IsEnabled=$true}
    try{Update-PMMGuidedActionState}catch{}
  }
}

# ---------------------------------------------------------------------------
# Background Analyze / Build / AIIO / Fix Lab operations.
# Heavy merge-engine work runs in a child PowerShell process. WPF only polls
# small atomic JSON files, so the main window remains responsive.
# ---------------------------------------------------------------------------
$Script:BackgroundOperationProcess=$null
$Script:BackgroundOperationTimer=$null
$Script:BackgroundOperationKind=''
$Script:BackgroundOperationProgressPath=''
$Script:BackgroundOperationResultPath=''
$Script:BackgroundOperationJobRoot=''
$Script:BackgroundOperationOnSuccess=$null
$Script:BackgroundOperationOnFailure=$null
$Script:BackgroundOperationFixLabJobId=''

function Stop-PMMBackgroundOperation([switch]$Silent) {
  try{if($Script:BackgroundOperationTimer){$Script:BackgroundOperationTimer.Stop()}}catch{}
  try{
    if($Script:BackgroundOperationProcess -and -not$Script:BackgroundOperationProcess.HasExited){
      # PMMFixLab.exe/repak may be descendants of the PowerShell worker. Kill
      # the complete process tree so Cancel never leaves an orphan engine.
      try{Start-Process -FilePath 'taskkill.exe' -ArgumentList ('/PID '+[int]$Script:BackgroundOperationProcess.Id+' /T /F') -WindowStyle Hidden -Wait -ErrorAction Stop|Out-Null}catch{$Script:BackgroundOperationProcess.Kill()}
    }
  }catch{}
  $kind=[string]$Script:BackgroundOperationKind
  $cancelledFixLabJob=[string]$Script:BackgroundOperationFixLabJobId
  if($kind -eq 'FixLabBuild' -and -not[string]::IsNullOrWhiteSpace($cancelledFixLabJob)){
    try{
      $cancelledJob=Get-PMMFixLabJob $cancelledFixLabJob
      if($cancelledJob -and $cancelledJob.Build -and [string]$cancelledJob.Build.Status -eq 'Building'){
        $cancelledJob.Build.Status='Failed'
        $cancelledJob.Build.Validation='PMM_OPERATION_CANCELLED'
        Save-PMMFixLabJob $cancelledJob|Out-Null
      }
    }catch{Write-PMMLog ('Could not persist cancelled Fix Lab job state: '+$_.Exception.Message)}
  }
  $Script:BackgroundOperationProcess=$null
  $Script:BackgroundOperationKind=''
  $Script:BackgroundOperationFixLabJobId=''
  $Script:BackgroundOperationOnSuccess=$null
  $Script:BackgroundOperationOnFailure=$null
  if($kind -eq 'Analyze'){Set-PMMAnalyzeBusy $false}
  elseif($kind -eq 'Build'){Set-PMMBuildBusy $false}
  elseif($kind -in @('AIHandoff','AIIOPrepare','AIIOPendingData','AIIOImportResponse','AIIOUseCandidate','AIIOArtifactRefresh')){Set-PMMAIIOBusy $false}
  elseif($kind -eq 'FixLabBuild'){Set-PMMFixLabBusy $false}
  if(-not$Silent -and -not[string]::IsNullOrWhiteSpace($kind)){
    $Script:TxtStatus.Text=(L ($kind+' stopped.') ($kind+' detenido.'))
  }
  Update-PMMCancelButtonState
}

function Complete-PMMBackgroundOperation {
  try{if($Script:BackgroundOperationTimer){$Script:BackgroundOperationTimer.Stop()}}catch{}
  $kind=[string]$Script:BackgroundOperationKind
  $result=$null
  try{
    if(Test-Path -LiteralPath $Script:BackgroundOperationResultPath -PathType Leaf){
      $result=Get-Content -LiteralPath $Script:BackgroundOperationResultPath -Raw|ConvertFrom-Json
    }
  }catch{}

  $successCallback=$Script:BackgroundOperationOnSuccess
  $failureCallback=$Script:BackgroundOperationOnFailure
  $Script:BackgroundOperationOnSuccess=$null
  $Script:BackgroundOperationOnFailure=$null
  $Script:BackgroundOperationProcess=$null
  $Script:BackgroundOperationKind=''
  $Script:BackgroundOperationFixLabJobId=''

  if($result -and [bool]$result.Success){
    # Force a final 100% sample even when the worker exits between UI polling
    # ticks. This guarantees both the in-button fill and the persistent bar
    # finish cleanly before the next guided action is highlighted.
    if($kind -eq 'Analyze'){Set-PMMAnalyzeProgress 1 1 (L 'Analyze complete.' 'Analisis terminado.')}
    elseif($kind -eq 'Build'){Set-PMMBuildProgress 1 1 (L 'Build complete.' 'Build terminado.')}
    elseif($kind -in @('AIHandoff','AIIOPrepare','AIIOPendingData','AIIOImportResponse','AIIOUseCandidate','AIIOArtifactRefresh')){Set-PMMAIIOProgress 1 1 (L 'AIIO operation complete.' 'Operacion AIIO terminada.')}
    elseif($kind -eq 'FixLabBuild'){Set-PMMFixLabProgress 1 1 (L 'Fix Lab repair build complete.' 'Build de reparacion Fix Lab terminado.')}
    try{
      if($successCallback){& $successCallback $result}
    }catch{Handle-UIError $_ ($kind+' completion')}
  }else{
    $message=if($result -and -not[string]::IsNullOrWhiteSpace([string]$result.Error)){
      [string]$result.Error
    }else{
      (L ($kind+' worker stopped without a valid result.') ('El proceso '+$kind+' termino sin un resultado valido.'))
    }
    Write-PMMLog ('Background '+$kind+' failed: '+$message)
    $failureOperation=if($kind -in @('AIHandoff','AIIOPrepare','AIIOPendingData','AIIOImportResponse','AIIOUseCandidate','AIIOArtifactRefresh')){'AIIO'}elseif($kind -eq 'FixLabBuild'){'FixLab'}else{$kind}
    Set-PMMOperationFailure $failureOperation $message
    try{
      if($failureCallback){& $failureCallback $message}else{Show-Error $message}
    }catch{}
  }

  # Keep the current workflow button in its progress state while the completion
  # callback refreshes plan/build state. Only then clear Busy and illuminate the
  # next real step, avoiding a one-frame stale highlight between operations.
  if($kind -eq 'Analyze'){Set-PMMAnalyzeBusy $false}
  elseif($kind -eq 'Build'){Set-PMMBuildBusy $false}
  elseif($kind -in @('AIHandoff','AIIOPrepare','AIIOPendingData','AIIOImportResponse','AIIOUseCandidate','AIIOArtifactRefresh')){Set-PMMAIIOBusy $false}
  elseif($kind -eq 'FixLabBuild'){Set-PMMFixLabBusy $false}

  if($result -and [bool]$result.Success -and @('Analyze','Build','FixLabBuild') -contains $kind){Notify-PMMWorkflowStepComplete}

  try{
    if($Script:BackgroundOperationJobRoot){
      Remove-Item -LiteralPath $Script:BackgroundOperationJobRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
  }catch{}

  # AUTO continuation belongs here rather than in individual UI callbacks: the
  # worker has exited, result state is refreshed and Busy is already false.
  if($result -and [bool]$result.Success -and $Script:AutoPipelineActive -and @('Analyze','Build','FixLabBuild') -contains $kind){
    try{Invoke-PMMAutoContinue}catch{Write-PMMLog ('AUTO continuation after '+$kind+' failed: '+$_.Exception.Message)}
  }else{
    try{Update-PMMGuidedActionState}catch{}
  }
}

function Start-PMMBackgroundOperation {
  param(
    [Parameter(Mandatory=$true)][ValidateSet('Analyze','Build','AIHandoff','AIIOPrepare','AIIOPendingData','AIIOImportResponse','AIIOUseCandidate','AIIOArtifactRefresh','FixLabBuild')][string]$Operation,
    [switch]$Force,
    [switch]$AllowOversize,
    [ValidateSet('ConflictGroups')][string]$Mode='ConflictGroups',
    [string]$SessionId='',
    [string]$InputZip='',
    [string]$SolutionId='',
    [string]$FixLabJobId='',
    [string]$FixLabRecipeId='',
    [string]$FixLabVariantId='',
    [scriptblock]$OnSuccess=$null,
    [scriptblock]$OnFailure=$null
  )

  if($Operation -in @('AIIOPrepare','AIIOPendingData','AIIOImportResponse','AIIOUseCandidate') -and -not(Test-PMMAIIOSessionId $SessionId)){throw ($Operation+' requires a valid persistent AIIO session id.')}
  if($Operation -eq 'AIIOImportResponse' -and -not(Test-Path -LiteralPath $InputZip -PathType Leaf)){throw 'AIIO response ZIP was not found.'}
  if($Operation -eq 'AIIOUseCandidate' -and $SolutionId -notmatch '^[a-f0-9]{64}$'){throw 'AIIO candidate solution id is invalid.'}
  if(-not(Request-PMMProcessingSlot $Operation)){return $false}
  Reset-PMMOperationCancellation

  $worker=Join-Path $Script:Root 'Modules\Operations\OperationWorker.ps1'
  if(-not(Test-Path -LiteralPath $worker -PathType Leaf)){throw 'Modules\Operations\OperationWorker.ps1 is missing.'}

  $jobsRoot=Join-PMMPath 'Cache' 'OperationJobs'
  New-Item -ItemType Directory -Force -Path $jobsRoot|Out-Null
  $job=Join-Path $jobsRoot ([guid]::NewGuid().ToString('N'))
  New-Item -ItemType Directory -Force -Path $job|Out-Null

  $Script:BackgroundOperationJobRoot=$job
  $Script:BackgroundOperationProgressPath=Join-Path $job 'progress.json'
  $Script:BackgroundOperationResultPath=Join-Path $job 'result.json'
  $Script:BackgroundOperationOnSuccess=$OnSuccess
  $Script:BackgroundOperationOnFailure=$OnFailure
  $Script:BackgroundOperationKind=$Operation
  $Script:BackgroundOperationFixLabJobId=if($Operation -eq 'FixLabBuild'){[string]$FixLabJobId}else{''}

  $stdout=Join-Path $job 'worker.stdout.txt'
  $stderr=Join-Path $job 'worker.stderr.txt'
  # Always use a dedicated PowerShell process for processing jobs. Reusing
  # PMM.exe as the worker host can involve the desktop host/single-instance
  # layer and makes UI responsiveness dependent on host implementation details.
  $hostExe=Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
  if(-not(Test-Path -LiteralPath $hostExe -PathType Leaf)){
    try{$hostExe=[string](Get-Command powershell.exe -ErrorAction Stop).Source}catch{$hostExe='powershell.exe'}
  }

  $args='-NoLogo -NoProfile -ExecutionPolicy Bypass -File "'+$worker+'" -Root "'+$Script:Root+'" -Operation '+$Operation+' -ProgressPath "'+$Script:BackgroundOperationProgressPath+'" -ResultPath "'+$Script:BackgroundOperationResultPath+'" -Mode '+$Mode
  if($Operation -eq 'FixLabBuild'){
    if(-not[string]::IsNullOrWhiteSpace($FixLabJobId)){$args+=' -FixLabJobId "'+$FixLabJobId+'"'}
    if(-not[string]::IsNullOrWhiteSpace($FixLabRecipeId)){$args+=' -FixLabRecipeId "'+$FixLabRecipeId+'"'}
    if(-not[string]::IsNullOrWhiteSpace($FixLabVariantId)){$args+=' -FixLabVariantId "'+$FixLabVariantId+'"'}
  }
  if($Operation -in @('AIIOPrepare','AIIOPendingData','AIIOImportResponse','AIIOUseCandidate')){
    $args+=' -SessionId "'+$SessionId+'"'
  }
  if($Operation -eq 'AIIOImportResponse'){$args+=' -InputZip "'+$InputZip+'"'}
  if($Operation -eq 'AIIOUseCandidate'){$args+=' -SolutionId "'+$SolutionId+'"'}
  if($Force){$args+=' -Force'}
  if($AllowOversize){$args+=' -AllowOversize'}

  if($Operation -eq 'Analyze'){
    Set-PMMAnalyzeBusy $true
    Set-PMMAnalyzeProgress 0 0 (L 'Starting Analyze in the background...' 'Iniciando Analizar en segundo plano...') -Indeterminate
    $Script:TxtStatus.Text=L 'Analyzing shared assets in the background...' 'Analizando assets compartidos en segundo plano...'
  }elseif($Operation -eq 'Build'){
    Set-PMMBuildBusy $true
    Set-PMMBuildProgress 0 0 (L 'Starting Build in the background...' 'Iniciando Build en segundo plano...') -Indeterminate
    $Script:TxtStatus.Text=L 'Building compatibility patch in the background...' 'Creando parche de compatibilidad en segundo plano...'
  }elseif($Operation -in @('AIHandoff','AIIOPrepare','AIIOPendingData','AIIOImportResponse','AIIOUseCandidate','AIIOArtifactRefresh')){
    Set-PMMAIIOBusy $true
    $message=switch($Operation){
      'AIHandoff' {L 'Creating one AI handoff for all current Unsupported cases...' 'Creando una unica entrega para IA con todos los casos no soportados...'}
      'AIIOPendingData' {L 'Preparing only the validated data requested for this session...' 'Preparando solo los datos validados pedidos para esta sesion...'}
      'AIIOImportResponse' {L 'Validating and staging the untrusted AI response...' 'Validando y dejando en staging la respuesta IA no confiable...'}
      'AIIOUseCandidate' {L 'Revalidating the selected candidate against the exact current case...' 'Revalidando el candidato contra el caso actual exacto...'}
      'AIIOArtifactRefresh' {L 'Refreshing the local artifact inventory...' 'Actualizando el inventario local de artefactos...'}
      default {L 'Preparing the selected persistent AIIO session...' 'Preparando la sesion AIIO persistente seleccionada...'}
    }
    Set-PMMAIIOProgress 0 0 $message -Indeterminate
    $Script:TxtStatus.Text=$message
  }else{
    if([string]::IsNullOrWhiteSpace($FixLabJobId) -and ([string]::IsNullOrWhiteSpace($FixLabRecipeId) -or [string]::IsNullOrWhiteSpace($FixLabVariantId))){throw 'FixLabBuild requires a job id or recipe + variant.'}
    Set-PMMFixLabBusy $true
    $Script:TxtStatus.Text=L 'Fix Lab repair is running in the processing engine. PMM remains responsive.' 'La reparacion Fix Lab se ejecuta en el motor de procesamiento. PMM sigue respondiendo.'
  }

  try{
    $Script:BackgroundOperationProcess=Start-Process -FilePath $hostExe -ArgumentList $args -WorkingDirectory $Script:Root -WindowStyle Hidden -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
    try{$Script:BackgroundOperationProcess.PriorityClass=[System.Diagnostics.ProcessPriorityClass]::BelowNormal}catch{}
    Write-PMMLog ('Background processing worker started: '+$Operation+' | pid='+[string]$Script:BackgroundOperationProcess.Id+' | host='+$hostExe)
  }catch{
    if($Operation -eq 'Analyze'){Set-PMMAnalyzeBusy $false}elseif($Operation -eq 'Build'){Set-PMMBuildBusy $false}elseif($Operation -in @('AIHandoff','AIIOPrepare','AIIOPendingData','AIIOImportResponse','AIIOUseCandidate','AIIOArtifactRefresh')){Set-PMMAIIOBusy $false}else{Set-PMMFixLabBusy $false}
    $Script:BackgroundOperationKind=''
    $Script:BackgroundOperationFixLabJobId=''
    Remove-Item -LiteralPath $job -Recurse -Force -ErrorAction SilentlyContinue
    throw
  }

  # Progress polling is presentation-only and must yield to real WPF input.
  $timer=[System.Windows.Threading.DispatcherTimer]::new([System.Windows.Threading.DispatcherPriority]::Background)
  $timer.Interval=[TimeSpan]::FromMilliseconds(650)
  $timer.Add_Tick({
    try{
      if(Test-Path -LiteralPath $Script:BackgroundOperationProgressPath -PathType Leaf){
        try{
          $progress=Get-Content -LiteralPath $Script:BackgroundOperationProgressPath -Raw|ConvertFrom-Json
          if([string]$progress.Operation -eq 'Analyze'){
            Set-PMMAnalyzeProgress ([int]$progress.Current) ([int]$progress.Total) ([string]$progress.Message) -Indeterminate:([bool]$progress.Indeterminate)
          }elseif([string]$progress.Operation -eq 'Build'){
            Set-PMMBuildProgress ([int]$progress.Current) ([int]$progress.Total) ([string]$progress.Message) -Indeterminate:([bool]$progress.Indeterminate)
          }elseif([string]$progress.Operation -in @('AIHandoff','AIIOPrepare','AIIOPendingData','AIIOImportResponse','AIIOUseCandidate','AIIOArtifactRefresh')){
            Set-PMMAIIOProgress ([int]$progress.Current) ([int]$progress.Total) ([string]$progress.Message) -Indeterminate:([bool]$progress.Indeterminate)
          }elseif([string]$progress.Operation -eq 'FixLabBuild'){
            if($progress.PSObject.Properties.Name -contains 'JobId' -and -not[string]::IsNullOrWhiteSpace([string]$progress.JobId)){$Script:BackgroundOperationFixLabJobId=[string]$progress.JobId}
            Set-PMMFixLabProgress ([int]$progress.Current) ([int]$progress.Total) ([string]$progress.Message) -Indeterminate:([bool]$progress.Indeterminate)
          }
          $Script:TxtStatus.Text=[string]$progress.Message
        }catch{}
      }
      if($Script:BackgroundOperationProcess -and $Script:BackgroundOperationProcess.HasExited){
        Complete-PMMBackgroundOperation
      }
    }catch{Write-PMMLog ('Background operation progress monitor error: '+$_.Exception.Message)}
  })
  $Script:BackgroundOperationTimer=$timer
  $timer.Start()
  return $true
}

# ---------------------------------------------------------------------------
# Background Game Reference build.
# ---------------------------------------------------------------------------
$Script:GameReferenceProcess=$null
$Script:GameReferenceTimer=$null
$Script:GameReferenceProgressPath=''
$Script:GameReferenceResultPath=''
$Script:GameReferenceJobRoot=''
$Script:GameReferenceOnSuccess=$null
$Script:GameReferenceOnFailure=$null

function Set-PMMGameReferenceProgressUi([int]$Percent,[string]$Message,[bool]$Indeterminate=$false) {
  $Percent=[Math]::Max(0,[Math]::Min(100,$Percent))
  $Script:GameReferenceProgressPercent=$Percent
  $Script:GameReferenceProgressMessage=[string]$Message
  $Script:GameReferenceProgressIndeterminate=[bool]$Indeterminate
  $Script:PrgGameReference.Visibility=[System.Windows.Visibility]::Visible
  $Script:TxtGameReferenceProgress.Visibility=[System.Windows.Visibility]::Visible
  [void](Set-PMMSmoothedProgressBar $Script:PrgGameReference 'GameReferenceMain' $Percent -Operation 'GameReference' -Message $Message -Indeterminate:$Indeterminate)
  $Script:TxtGameReferenceProgress.Text=$Message
  if($Script:PrgFixLabGameReference){
    $Script:PrgFixLabGameReference.Visibility=[System.Windows.Visibility]::Visible
    $Script:TxtFixLabGameReferenceProgress.Visibility=[System.Windows.Visibility]::Visible
    [void](Set-PMMSmoothedProgressBar $Script:PrgFixLabGameReference 'GameReferenceFixLab' $Percent -Operation 'GameReference' -Message $Message -Indeterminate:$Indeterminate)
    $Script:TxtFixLabGameReferenceProgress.Text=$Message
  }
  # The existing ColorFlow convention is preserved: a running operation also
  # consumes the highlighted button as a progress surface. The human output
  # choice may still be highlighted simultaneously on the Fix Lab combo/tab.
  $fraction=[double]$Percent/100.0
  foreach($button in @($Script:BtnBuildGameReference,$Script:BtnFixLabBuildReference)){
    if($button){Set-PMMWorkflowButtonProgress $button 'Build' $fraction $Message -Indeterminate:$Indeterminate}
  }
}

function Stop-PMMGameReferenceBuild([switch]$Silent) {
  try{if($Script:GameReferenceTimer){$Script:GameReferenceTimer.Stop()}}catch{}
  try{if($Script:GameReferenceProcess -and -not$Script:GameReferenceProcess.HasExited){$Script:GameReferenceProcess.Kill()}}catch{}
  $Script:GameReferenceProcess=$null
  $Script:GameReferenceResumeAuto=$false
  $Script:BtnBuildGameReference.IsEnabled=$true
  if($Script:BtnFixLabBuildReference){$Script:BtnFixLabBuildReference.IsEnabled=$true}
  try{Set-PMMGuideButtonStyle $Script:BtnBuildGameReference 'Default';Set-PMMGuideButtonStyle $Script:BtnFixLabBuildReference 'Default'}catch{}
  if(-not$Silent){
    Set-PMMGameReferenceProgressUi 100 (L 'Game Reference build stopped.' 'Creacion de Game Reference detenida.') $false
  }
}

function Complete-PMMGameReferenceBuild {
  try{if($Script:GameReferenceTimer){$Script:GameReferenceTimer.Stop()}}catch{}
  $result=$null
  try{
    if(Test-Path -LiteralPath $Script:GameReferenceResultPath -PathType Leaf){
      $result=Get-Content -LiteralPath $Script:GameReferenceResultPath -Raw|ConvertFrom-Json
    }
  }catch{}
  $Script:BtnBuildGameReference.IsEnabled=$true
  if($Script:BtnFixLabBuildReference){$Script:BtnFixLabBuildReference.IsEnabled=$true}
  $callback=$Script:GameReferenceOnSuccess
  $failureCallback=$Script:GameReferenceOnFailure
  $Script:GameReferenceOnSuccess=$null
  $Script:GameReferenceOnFailure=$null

  if($result -and [bool]$result.Success){
    Set-PMMGameReferenceProgressUi 100 (L 'Game Reference ready.' 'Game Reference lista.') $false
    Refresh-UI
    try{if($Script:FixLabLoaded){Refresh-PMMFixLabUI}}catch{}
    try{
      $built=$result.State
      if($built){$Script:TxtStatus.Text=((L 'Game Reference ready: {0} families, {1:N1} MiB.' 'Game Reference lista: {0} familias, {1:N1} MiB.') -f [int]$built.FamilyCount,([double]$built.Bytes/1MB))}
      if($Script:GameReferenceResumeAuto){Write-PMMLog 'Game Reference completed; AUTO continuation remains armed.'}
    }catch{Write-PMMLog ('Game Reference completion UI warning: '+$_.Exception.Message)}
    try{if($callback){& $callback $result.State}}catch{Write-PMMLog ('Game Reference optional callback warning: '+$_.Exception.Message)}
  }else{
    $message=if($result -and -not[string]::IsNullOrWhiteSpace([string]$result.Error)){
      [string]$result.Error
    }else{
      L 'Game Reference worker stopped without a valid result.' 'El proceso de Game Reference termino sin un resultado valido.'
    }
    Set-PMMGameReferenceProgressUi 100 ((L 'Game Reference failed: ' 'Game Reference fallo: ')+$message) $false
    Write-PMMLog ('Background Game Reference build failed: '+$message)
    try{if($failureCallback){& $failureCallback $message}else{Show-Error $message}}catch{}
  }

  try{
    if($Script:GameReferenceJobRoot){
      Remove-Item -LiteralPath $Script:GameReferenceJobRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
  }catch{}
  $Script:GameReferenceProcess=$null
  $Script:GameReferenceResumeAuto=$false
  try{Set-PMMGuideButtonStyle $Script:BtnBuildGameReference 'Default';Set-PMMGuideButtonStyle $Script:BtnFixLabBuildReference 'Default'}catch{}
  if($result -and [bool]$result.Success){Notify-PMMWorkflowStepComplete}
  if($result -and [bool]$result.Success -and $Script:AutoPipelineActive){
    Write-PMMLog 'Game Reference completed with AUTO active; resuming unified workflow.'
    try{Invoke-PMMAutoContinue}catch{Write-PMMLog ('AUTO continuation after Game Reference failed: '+$_.Exception.Message)}
  }else{
    try{Update-PMMGuidedActionState}catch{}
  }
}

function Start-PMMGameReferenceBuild {
  param([scriptblock]$OnSuccess=$null,[scriptblock]$OnFailure=$null)
  if(-not(Request-PMMProcessingSlot 'GameReference')){return $false}

  $worker=Join-Path $Script:Root 'Modules\GameReference\GameReferenceWorker.ps1'
  if(-not(Test-Path -LiteralPath $worker -PathType Leaf)){throw 'Modules\GameReference\GameReferenceWorker.ps1 is missing.'}

  $jobsRoot=Join-PMMPath 'Cache' 'GameReferenceJobs'
  New-Item -ItemType Directory -Force -Path $jobsRoot|Out-Null
  $job=Join-Path $jobsRoot ([guid]::NewGuid().ToString('N'))
  New-Item -ItemType Directory -Force -Path $job|Out-Null

  $Script:GameReferenceJobRoot=$job
  $Script:GameReferenceProgressPath=Join-Path $job 'progress.json'
  $Script:GameReferenceResultPath=Join-Path $job 'result.json'
  $stdout=Join-Path $job 'worker.stdout.txt'
  $stderr=Join-Path $job 'worker.stderr.txt'
  $Script:GameReferenceOnSuccess=$OnSuccess
  $Script:GameReferenceOnFailure=$OnFailure

  $hostExe=''
  try{$hostExe=[string](Get-Process -Id $PID -ErrorAction Stop).Path}catch{}
  if([string]::IsNullOrWhiteSpace($hostExe) -or -not(Test-Path -LiteralPath $hostExe -PathType Leaf)){
    $hostExe='powershell.exe'
  }

  $args='-NoLogo -NoProfile -ExecutionPolicy Bypass -File "'+$worker+'" -Root "'+$Script:Root+'" -ProgressPath "'+$Script:GameReferenceProgressPath+'" -ResultPath "'+$Script:GameReferenceResultPath+'"'
  Set-PMMGameReferenceProgressUi 0 (L 'Starting Game Reference build in the background...' 'Iniciando Game Reference en segundo plano...') $true
  $Script:BtnBuildGameReference.IsEnabled=$false
  if($Script:BtnFixLabBuildReference){$Script:BtnFixLabBuildReference.IsEnabled=$false}

  try{
    $Script:GameReferenceProcess=Start-Process -FilePath $hostExe -ArgumentList $args -WorkingDirectory $Script:Root -WindowStyle Hidden -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
  }catch{
    $Script:BtnBuildGameReference.IsEnabled=$true
    if($Script:BtnFixLabBuildReference){$Script:BtnFixLabBuildReference.IsEnabled=$true}
    Remove-Item -LiteralPath $job -Recurse -Force -ErrorAction SilentlyContinue
    throw
  }

  # Game Reference progress is non-critical presentation work; user input wins.
  $timer=[System.Windows.Threading.DispatcherTimer]::new([System.Windows.Threading.DispatcherPriority]::Background)
  $timer.Interval=[TimeSpan]::FromMilliseconds(500)
  $timer.Add_Tick({
    try{
      if(Test-Path -LiteralPath $Script:GameReferenceProgressPath -PathType Leaf){
        try{
          $progress=Get-Content -LiteralPath $Script:GameReferenceProgressPath -Raw|ConvertFrom-Json
          Set-PMMGameReferenceProgressUi ([int]$progress.Percent) ([string]$progress.Message) ([bool]$progress.Indeterminate)
        }catch{}
      }
      if($Script:GameReferenceProcess -and $Script:GameReferenceProcess.HasExited){
        Complete-PMMGameReferenceBuild
      }
    }catch{Write-PMMLog ('Game Reference progress monitor error: '+$_.Exception.Message)}
  })
  $Script:GameReferenceTimer=$timer
  $timer.Start()
  try{Update-PMMGuidedActionState}catch{}
  return $true
}


# ---------------------------------------------------------------------------
# Conflict workspace helpers.
# ---------------------------------------------------------------------------
$Script:LoadingConflictView = $false
$Script:CurrentConflictAssetKey = ''
$Script:LastConflictPlanCreated = ''
$Script:CurrentUnsupportedAssetKey = ''

function Get-OptionJson($Options,[string]$Name) {
  if ($null -eq $Options) { return $null }
  if ($Options -is [hashtable]) {
    if ($Options.ContainsKey($Name)) { return [string]$Options[$Name] }
    return $null
  }
  $property = $Options.PSObject.Properties[$Name]
  if ($property) { return [string]$property.Value }
  return $null
}

function New-PMMTextColumn([string]$Header,[string]$Property,[double]$Width,[bool]$ReadOnly=$true) {
  $column = New-Object System.Windows.Controls.DataGridTextColumn
  $column.Header = $Header
  $column.Width = $Width
  $column.IsReadOnly = $ReadOnly
  $binding = New-Object System.Windows.Data.Binding -ArgumentList $Property
  if (-not $ReadOnly) {
    $binding.Mode = [System.Windows.Data.BindingMode]::TwoWay
    $binding.UpdateSourceTrigger = [System.Windows.Data.UpdateSourceTrigger]::PropertyChanged
  }
  $column.Binding = $binding
  return $column
}

function Configure-ConflictColumns([array]$ModNames) {
  <#
  Columns are dynamic because a shared asset may involve 2, 3 or more mods.

  IMPORTANT: Source choice uses a DataGridTemplateColumn with an always-live ComboBox.
  Previous previews used DataGridComboBoxColumn, whose edit lifecycle could
  close the popup while WPF committed a cell.  The template ComboBox is not
  tied to DataGrid edit mode, so it remains open until the user chooses/closes.
  #>
  $Script:DgDecisions.Columns.Clear()
  [void]$Script:DgDecisions.Columns.Add((New-PMMTextColumn (L 'Parameter' 'Parametro') 'DisplayProperty' 360 $true))
  [void]$Script:DgDecisions.Columns.Add((New-PMMTextColumn 'Vanilla' 'VanillaDisplay' 190 $true))

  $index = 0
  foreach ($modName in @($ModNames)) {
    $index++
    [void]$Script:DgDecisions.Columns.Add((New-PMMTextColumn $modName ("ModValue{0}" -f $index) 190 $true))
  }

  $winner = New-Object System.Windows.Controls.DataGridTemplateColumn
  $winner.Header = L 'Use value from' 'Usar valor de'
  $winner.Width = 200

  $template = New-Object System.Windows.DataTemplate
  $comboFactory = New-Object System.Windows.FrameworkElementFactory([System.Windows.Controls.ComboBox])
  $itemsBinding = New-Object System.Windows.Data.Binding -ArgumentList 'WinnerChoices'
  $comboFactory.SetBinding([System.Windows.Controls.ItemsControl]::ItemsSourceProperty,$itemsBinding)
  $selectedBinding = New-Object System.Windows.Data.Binding -ArgumentList 'SelectedChoice'
  $selectedBinding.Mode = [System.Windows.Data.BindingMode]::TwoWay
  $selectedBinding.UpdateSourceTrigger = [System.Windows.Data.UpdateSourceTrigger]::PropertyChanged
  $comboFactory.SetBinding([System.Windows.Controls.Primitives.Selector]::SelectedItemProperty,$selectedBinding)
  $comboFactory.SetValue([System.Windows.Controls.Control]::MinWidthProperty,[double]165)
  $comboFactory.SetValue([System.Windows.FrameworkElement]::HeightProperty,[double]30)
  $comboFactory.SetValue([System.Windows.Controls.Control]::FontSizeProperty,[double]13)
  $comboFactory.SetValue([System.Windows.Controls.Control]::PaddingProperty,[System.Windows.Thickness]::new(7,2,7,2))
  $comboFactory.SetValue([System.Windows.Controls.Control]::VerticalContentAlignmentProperty,[System.Windows.VerticalAlignment]::Center)
  $comboFactory.SetValue([System.Windows.Controls.Control]::HorizontalContentAlignmentProperty,[System.Windows.HorizontalAlignment]::Stretch)
  $template.VisualTree = $comboFactory
  $winner.CellTemplate = $template
  $winner.CellEditingTemplate = $template
  [void]$Script:DgDecisions.Columns.Add($winner)
  [void]$Script:DgDecisions.Columns.Add((New-PMMTextColumn (L 'Custom value' 'Valor custom') 'CustomValue' 120 $false))

  [void]$Script:DgDecisions.Columns.Add((New-PMMTextColumn (L 'Status' 'Estado') 'Status' 125 $true))
}

function Save-DecisionGridToPlan {
  param([switch]$Silent)

  if ($Script:LoadingConflictView) { return }
  try {
    [void]$Script:DgDecisions.CommitEdit([System.Windows.Controls.DataGridEditingUnit]::Cell,$true)
    [void]$Script:DgDecisions.CommitEdit([System.Windows.Controls.DataGridEditingUnit]::Row,$true)
    $rows = @()
    if ($null -ne $Script:DgDecisions.ItemsSource) { $rows = @($Script:DgDecisions.ItemsSource) }
    if ($rows.Count -gt 0) { Save-PMMDecisionRows $rows }
  } catch {
    if (-not $Silent) { throw }
    Write-PMMLog ("Background decision save failed: {0}" -f $_.Exception.Message)
  }
}

function Show-SelectedConflictAsset {
  param($AssetSummary)

  $Script:LoadingConflictView = $true
  try {
    if (-not $AssetSummary) {
      $Script:CurrentConflictAssetKey = ''
$Script:LastConflictPlanCreated = ''
$Script:CurrentUnsupportedAssetKey = ''
      $Script:TxtConflictMods.Text = L 'No true overlapping-change decisions.' 'No hay decisiones de cambios solapados.'
      $Script:TxtConflictAsset.Text = ''
      $Script:CmbBulkWinner.ItemsSource = @()
      $Script:TxtBulkCustom.Text = ''
      $Script:BtnOpenReview.IsEnabled = $false
      $Script:BtnOpenReview.Tag = $null
      $Script:DgDecisions.ItemsSource = @()
      $Script:DgDecisions.Columns.Clear()
      return
    }

    $assetKey = [string]$AssetSummary.AssetKey
    $Script:CurrentConflictAssetKey = $assetKey
    $modNames = @($AssetSummary.ConflictMods)
    $allProviders=@($AssetSummary.Providers)
    $compatibleProviders=@($allProviders|Where-Object{[string]$_ -notin $modNames})
    $isPackageChoice=(($AssetSummary.PSObject.Properties.Name -contains 'Mode') -and [string]$AssetSummary.Mode -eq 'PackageChoice')
    if($isPackageChoice){
      $conflictText=(L 'Alternative package components detected: ' 'Componentes alternativos de paquete detectados: ') + ($modNames -join '  <->  ')
    }else{
      $conflictText=(L 'Competing mods for this parameter: ' 'Mods que compiten por este parametro: ') + ($modNames -join '  <->  ')
      if($compatibleProviders.Count -gt 0){
        $conflictText += "`n" + (L 'Other changes in this same file are still merged automatically: ' 'Los demas cambios de este mismo archivo se fusionan automaticamente: ') + ($compatibleProviders -join ', ')
      }
    }
    $Script:TxtConflictMods.Text=$conflictText
    $reason = if ($AssetSummary.PSObject.Properties['Reason']) { [string]$AssetSummary.Reason } else { '' }
    $prefix=if($isPackageChoice){L 'Package: ' 'Paquete: '}else{L 'File: ' 'Archivo: '}
    $Script:TxtConflictAsset.Text = ($prefix + [string]$AssetSummary.Asset + $(if($reason){"`n" + (L 'Reason: ' 'Motivo: ') + $reason}else{''}))

    Configure-ConflictColumns $modNames

    $Script:CmbBulkWinner.ItemsSource = @()
    $Script:TxtBulkCustom.Text = ''
    $reviewFolder = if ($AssetSummary.PSObject.Properties['ReviewFolder']) { [string]$AssetSummary.ReviewFolder } else { '' }
    $Script:BtnOpenReview.Tag = $reviewFolder
    $Script:BtnOpenReview.IsEnabled = (-not [string]::IsNullOrWhiteSpace($reviewFolder)) -and (Test-Path -LiteralPath $reviewFolder -PathType Container)

    $planRows = @(Get-PMMDecisionRows | Where-Object { [string]$_.AssetKey -eq $assetKey })
    if ($planRows.Count -gt 0) {
      $bulk = @($planRows[0].Choices)
      foreach ($other in @($planRows | Select-Object -Skip 1)) { $bulk = @($bulk | Where-Object { $_ -in @($other.Choices) }) }
      $Script:CmbBulkWinner.ItemsSource = $bulk
      if ($bulk.Count -gt 0) { $Script:CmbBulkWinner.SelectedIndex = 0 }
    }
    $viewRows = New-Object System.Collections.Generic.List[object]
    foreach ($row in $planRows) {
      $properties = [ordered]@{
        DecisionId = [string]$row.DecisionId
        AssetKey = [string]$row.AssetKey
        DisplayProperty = [string]$row.DisplayProperty
        VanillaJson = [string]$row.VanillaJson
        VanillaDisplay = ConvertTo-PMMDisplayValue ([string]$row.VanillaJson)
        SelectedChoice = [string]$row.SelectedChoice
        WinnerChoices = @($row.Choices)
        CustomValue = [string]$row.CustomValue
        ResolutionOrigin = $(if($row.PSObject.Properties.Name -contains 'ResolutionOrigin'){[string]$row.ResolutionOrigin}else{'Manual'})
        Status = $(if ([string]::IsNullOrWhiteSpace([string]$row.SelectedChoice) -or ([string]$row.SelectedChoice -eq 'Custom' -and [string]::IsNullOrWhiteSpace([string]$row.CustomValue))) { L 'Decision required' 'Decision requerida' } elseif(($row.PSObject.Properties.Name -contains 'ResolutionOrigin') -and [string]$row.ResolutionOrigin -eq 'Priority') { L 'Resolved by priority' 'Resuelto por prioridad' } else { L 'Resolved' 'Resuelto' })
      }

      $i = 0
      foreach ($modName in $modNames) {
        $i++
        $value = Get-OptionJson $row.Options $modName
        if ($null -eq $value) { $value = '-' }
        $properties[("ModValue{0}" -f $i)] = ConvertTo-PMMDisplayValue ([string]$value)
      }
      $viewRows.Add([pscustomobject]$properties)
    }
    $Script:DgDecisions.ItemsSource = $viewRows.ToArray()
  } finally {
    $Script:LoadingConflictView = $false
  }
}

function Get-PMMUnsupportedDisableRanking($UnsupportedAsset) {
  if(-not$UnsupportedAsset){return @()}
  $plan=Read-PMMMergePlan
  if(-not$plan){return @()}
  $providers=@($UnsupportedAsset.Providers|ForEach-Object{[string]$_}|Where-Object{$_}|Sort-Object -Unique)
  $rank=[System.Collections.Generic.List[object]]::new()
  foreach($provider in $providers){
    $otherCompatible=@($plan.Assets|Where-Object{
      [string]$_.AssetKey -ne [string]$UnsupportedAsset.AssetKey -and
      [string]$_.Mode -notin @('Unsupported','Identical') -and
      [string]$provider -in @($_.Providers|ForEach-Object{[string]$_})
    }).Count
    $otherShared=@($plan.Assets|Where-Object{
      [string]$_.AssetKey -ne [string]$UnsupportedAsset.AssetKey -and
      [string]$provider -in @($_.Providers|ForEach-Object{[string]$_})
    }).Count
    $rank.Add([pscustomobject]@{Name=$provider;CompatibleImpact=$otherCompatible;SharedImpact=$otherShared})
  }
  return @($rank|Sort-Object CompatibleImpact,SharedImpact,Name)
}

function Show-SelectedUnsupportedAsset {
  $item=$Script:LstUnsupportedAssets.SelectedItem
  $Script:CmbUnsupportedDisable.Items.Clear()
  $Script:BtnDisableUnsupported.IsEnabled=$false
  $Script:BtnOpenAIHandoff.IsEnabled=$false;$Script:BtnOpenAIHandoff.Tag=$null
  $Script:BtnImportManualSolution.IsEnabled=$false;$Script:BtnImportManualSolution.Tag=$null
  if(-not$item){
    $Script:CurrentUnsupportedAssetKey=''
    $Script:TxtUnsupported.Text=L 'None.' 'Ninguno.'
    $Script:TxtUnsupportedHint.Text=L 'No unsupported shared asset is selected.' 'No hay ningun asset compartido no soportado seleccionado.'
    return
  }
  $Script:CurrentUnsupportedAssetKey=[string]$item.AssetKey
  $Script:TxtUnsupported.Text=("{0}`n{1}" -f [string]$item.Asset,[string]$item.Reason)
  try{
    $aiEstimate=Get-PMMAIHandoffEstimate
    $Script:BtnOpenAIHandoff.Tag=[string]$aiEstimate.ZipPath
    $Script:BtnOpenAIHandoff.IsEnabled=$true
    if([bool]$aiEstimate.Existing){$Script:BtnOpenAIHandoff.Content=L 'OPEN AI HANDOFF' 'ABRIR ENTREGA PARA IA'}else{$Script:BtnOpenAIHandoff.Content=L 'CREATE AI HANDOFF' 'CREAR ENTREGA PARA IA'}
  }catch{
    $Script:BtnOpenAIHandoff.Tag=$null
    $Script:BtnOpenAIHandoff.IsEnabled=$false
    $Script:BtnOpenAIHandoff.Content=L 'CREATE AI HANDOFF' 'CREAR ENTREGA PARA IA'
  }
  $Script:BtnImportManualSolution.Tag=[string]$item.ReviewFolder
  $Script:BtnImportManualSolution.IsEnabled=([IO.Path]::GetExtension([string]$item.Asset) -ieq '.uasset' -and -not[string]::IsNullOrWhiteSpace([string]$item.ReviewFolder) -and (Test-Path -LiteralPath (Join-Path ([string]$item.ReviewFolder) 'case.json') -PathType Leaf))
  $ranking=@(Get-PMMUnsupportedDisableRanking $item)
  foreach($r in $ranking){[void]$Script:CmbUnsupportedDisable.Items.Add([string]$r.Name)}
  if($ranking.Count -gt 0){
    $Script:CmbUnsupportedDisable.SelectedIndex=0
    $Script:BtnDisableUnsupported.IsEnabled=$true
    $min=[int]$ranking[0].CompatibleImpact
    $ties=@($ranking|Where-Object{[int]$_.CompatibleImpact -eq $min})
    if($ties.Count -eq 1 -and $ranking.Count -gt 1){
      $Script:TxtUnsupportedHint.Text=((L 'Suggested: disable {0}. It participates in {1} other mergeable shared asset(s), the smallest impact among these providers. This does not predict gameplay preference.' 'Sugerencia: desactiva {0}. Participa en {1} otro(s) asset(s) compartido(s) fusionables, el menor impacto entre estos providers. Esto no predice una preferencia de gameplay.') -f [string]$ranking[0].Name,$min)
    }else{
      $Script:TxtUnsupportedHint.Text=L 'Choose which provider to disable. PMM cannot infer gameplay preference when the structural impact is tied.' 'Elige que provider desactivar. PMM no puede inferir una preferencia de gameplay cuando el impacto estructural esta empatado.'
    }
  }
}

function Refresh-ConflictWorkspace {
  param([string]$PreferAssetKey='')

  Save-DecisionGridToPlan -Silent
  $Script:LoadingConflictView = $true
  try {
    $plan=$null
    $assets=@()
    $unsupported=@()
    if(Test-PMMMergePlanCurrent){
      $plan=Read-PMMMergePlan
      $assets=@(Get-PMMConflictAssets)
      $unsupported=@(Get-PMMUnsupportedAssets)
    }

    $Script:LstConflictAssets.Items.Clear()
    foreach($asset in $assets){[void]$Script:LstConflictAssets.Items.Add($asset)}

    $unresolved=0
    if($plan){$unresolved=@($plan.Rows|Where-Object{-not(Test-PMMDecisionRowResolved $_)}).Count}
    if($assets.Count -eq 0){
      $Script:TxtConflictHeader.Text=L 'Resolution & Review (0)' 'Resolucion y revision (0)'
      $Script:TxtConflictHeader.Foreground=$Window.Resources['PrimaryText']
      $Script:ExpConflicts.IsExpanded=$false
    }elseif($unresolved -gt 0){
      $Script:TxtConflictHeader.Text=((L 'Resolution & Review ({0}) - DECISION REQUIRED' 'Resolucion y revision ({0}) - SE NECESITA DECISION') -f $assets.Count)
      $Script:TxtConflictHeader.Foreground=$Window.Resources['AccentHeadingAmber']
      $created=if($plan -and ($plan.PSObject.Properties.Name -contains 'Created')){[string]$plan.Created}else{''}
      if($created -ne $Script:LastConflictPlanCreated -and $unsupported.Count -eq 0){$Script:ExpConflicts.IsExpanded=$true}
      $Script:LastConflictPlanCreated=$created
    }else{
      $Script:TxtConflictHeader.Text=((L 'Resolution & Review ({0}) - resolved' 'Resolucion y revision ({0}) - resuelto') -f $assets.Count)
      $Script:TxtConflictHeader.Foreground=$Window.Resources['AccentHeadingGreen']
    }

    $Script:LstUnsupportedAssets.Items.Clear()
    foreach($asset in $unsupported){
      [void]$Script:LstUnsupportedAssets.Items.Add([pscustomobject]@{
        AssetKey=[string]$asset.AssetKey;Asset=[string]$asset.Asset;Providers=@($asset.Providers);Reason=[string]$asset.Reason;
        ReviewFolder=$(if($asset.PSObject.Properties.Name -contains 'ReviewFolder'){[string]$asset.ReviewFolder}else{''});
        AIHandoff=$(if($asset.PSObject.Properties.Name -contains 'AIHandoff'){[string]$asset.AIHandoff}else{''});
        CaseId=$(if($asset.PSObject.Properties.Name -contains 'CaseId'){[string]$asset.CaseId}else{''});
        Display=(("{0}  -  {1}" -f [IO.Path]::GetFileName([string]$asset.Asset),(@($asset.Providers)-join ', ')))
      })
    }
    if($unsupported.Count -eq 0){
      $Script:ExpUnsupported.Header=L 'Blocked shared assets (0)' 'Assets compartidos bloqueados (0)'
      $Script:ExpUnsupported.IsExpanded=$false
      $Script:TxtUnsupported.Text=L 'None.' 'Ninguno.'
    }else{
      $Script:ExpUnsupported.Header=((L 'Blocked shared assets ({0}) - Build/Deploy blocked' 'Assets compartidos bloqueados ({0}) - Build/Deploy bloqueados') -f $unsupported.Count)
      $Script:ExpUnsupported.IsExpanded=$true
      $wantedUnsupported=$Script:CurrentUnsupportedAssetKey
      $selectedUnsupported=$null
      if($wantedUnsupported){$selectedUnsupported=@($Script:LstUnsupportedAssets.Items|Where-Object{[string]$_.AssetKey -eq $wantedUnsupported}|Select-Object -First 1)[0]}
      if(-not$selectedUnsupported -and $Script:LstUnsupportedAssets.Items.Count -gt 0){$selectedUnsupported=$Script:LstUnsupportedAssets.Items[0]}
      if($selectedUnsupported){$Script:LstUnsupportedAssets.SelectedItem=$selectedUnsupported}
    }

    $selected=$null
    $wanted=if($PreferAssetKey){$PreferAssetKey}else{$Script:CurrentConflictAssetKey}
    if($wanted){foreach($item in $assets){if([string]$item.AssetKey -eq $wanted){$selected=$item;break}}}
    if(-not$selected -and $assets.Count -gt 0){$selected=$assets[0]}
    if($selected){$Script:LstConflictAssets.SelectedItem=$selected}
  } finally {
    $Script:LoadingConflictView=$false
  }

  Show-SelectedConflictAsset $Script:LstConflictAssets.SelectedItem
  Show-SelectedUnsupportedAsset
  Update-BuildButtonState
  Update-PMMGuidedActionState
}

$Script:LibraryDisplayItems=@()
$Script:PriorityDragStartPoint=$null
$Script:PriorityDragName=''
$Script:PriorityEditorCommitInProgress=$false
$Script:ModListScrollViewer=$null

function Get-PMMUiAncestor($Source,[Type]$TargetType) {
  $current=$Source
  while($null -ne $current){
    if($TargetType.IsInstanceOfType($current)){return $current}
    $next=$null
    try{
      if($current -is [System.Windows.DependencyObject]){$next=[System.Windows.Media.VisualTreeHelper]::GetParent($current)}
    }catch{$next=$null}
    if(-not$next){
      try{
        if($current -is [System.Windows.FrameworkElement]){$next=$current.Parent}
        elseif($current -is [System.Windows.FrameworkContentElement]){$next=$current.Parent}
      }catch{$next=$null}
    }
    if(-not$next -and $current -is [System.Windows.DependencyObject]){
      try{$next=[System.Windows.LogicalTreeHelper]::GetParent($current)}catch{$next=$null}
    }
    $current=$next
  }
  return $null
}

function Get-PMMUiDescendant($Root,[Type]$TargetType) {
  if(-not$Root){return $null}
  $count=0
  try{$count=[System.Windows.Media.VisualTreeHelper]::GetChildrenCount($Root)}catch{return $null}
  for($i=0;$i -lt $count;$i++){
    $child=[System.Windows.Media.VisualTreeHelper]::GetChild($Root,$i)
    if($TargetType.IsInstanceOfType($child)){return $child}
    $found=Get-PMMUiDescendant $child $TargetType
    if($found){return $found}
  }
  return $null
}

function Test-PMMPriorityDragInteractiveSource($Source) {
  foreach($type in @(
    [System.Windows.Controls.TextBox],
    [System.Windows.Controls.CheckBox],
    [System.Windows.Controls.ComboBox],
    [System.Windows.Controls.Primitives.ButtonBase],
    [System.Windows.Controls.Primitives.ScrollBar]
  )){
    if(Get-PMMUiAncestor $Source $type){return $true}
  }
  return $false
}

function Refresh-PMMLibraryAfterPriorityChange([string]$Name) {
  Refresh-UI
  $selected=@($Script:LstMods.ItemsSource|Where-Object{[string]$_.Name -ieq $Name}|Select-Object -First 1)
  if($selected.Count -gt 0){
    $Script:LstMods.SelectedItem=$selected[0]
    $Script:LstMods.ScrollIntoView($selected[0])
  }
}

function Invoke-PMMPriorityEditorCommit([System.Windows.Controls.TextBox]$Editor) {
  if(-not$Editor -or $Script:PriorityEditorCommitInProgress){return $false}
  $name=[string]$Editor.Tag
  if([string]::IsNullOrWhiteSpace($name)){return $false}

  [long]$requested=0
  $raw=([string]$Editor.Text).Trim()
  if(-not[long]::TryParse($raw,[ref]$requested)){
    $map=Get-PMMModPriorityMap
    if($map.ContainsKey($name)){$Editor.Text=[string]$map[$name]}
    $Script:TxtStatus.Text=L 'Order must be a whole number. The previous position was kept.' 'Orden debe ser un numero entero. Se mantuvo la posicion anterior.'
    return $false
  }

  $Script:PriorityEditorCommitInProgress=$true
  try{
    $changed=Set-PMMModPriorityPosition $name $requested
    if($changed){
      Refresh-PMMLibraryAfterPriorityChange $name
    }else{
      # Also normalizes an out-of-range value when it clamps to the current end.
      $map=Get-PMMModPriorityMap
      if($map.ContainsKey($name)){$Editor.Text=[string]$map[$name]}
    }
    return $changed
  }finally{
    $Script:PriorityEditorCommitInProgress=$false
  }
}

function Apply-PMMLibraryFilter {
  $query=[string]$Script:TxtModFilter.Text
  $items=@($Script:LibraryDisplayItems)
  if(-not[string]::IsNullOrWhiteSpace($query)){
    $items=@($items|Where-Object{
      ([string]$_.Name).IndexOf($query,[StringComparison]::OrdinalIgnoreCase) -ge 0 -or
      ([string]$_.State).IndexOf($query,[StringComparison]::OrdinalIgnoreCase) -ge 0
    })
  }
  $Script:LstMods.ItemsSource=$items
  Update-PMMLibraryButtons
}

function Set-PMMLibraryDisplayItems([array]$Items) {
  $Script:LibraryDisplayItems=@($Items)
  Apply-PMMLibraryFilter
}

function Get-PMMAnalysisModeInfo([string]$Mode,[bool]$Resolved=$false) {
  switch($Mode){
    'BinaryAuto' { return [pscustomobject]@{Result=(L 'Auto merged' 'Auto merge');Adapter='Binary range'} }
    'StaticItemAuto' { return [pscustomobject]@{Result=(L 'Auto merged' 'Auto merge');Adapter='Static Item'} }
    'SupersetAuto' { return [pscustomobject]@{Result=(L 'Auto merged' 'Auto merge');Adapter='Superset anchor'} }
    'ContainedSupersetAuto' { return [pscustomobject]@{Result=(L 'Auto merged' 'Auto merge');Adapter='Contained code superset'} }
    'KnownRecipeAuto' { return [pscustomobject]@{Result=(L 'Auto merged' 'Auto merge');Adapter=(L 'Runtime-proven recipe' 'Receta runtime probada')} }
    'ManualSolutionExperimental' { return [pscustomobject]@{Result=(L 'Experimental solution' 'Solucion experimental');Adapter=(L 'Manual/AI cooked family' 'Familia cooked manual/IA')} }
    'DataTableAuto' { return [pscustomobject]@{Result=(L 'Auto merged' 'Auto merge');Adapter='DataTable scalar'} }
    'RelocatableAuto' { return [pscustomobject]@{Result=(L 'Auto merged' 'Auto merge');Adapter='Relocatable delta'} }
    'BinaryConflict' { return [pscustomobject]@{Result=$(if($Resolved){L 'Conflict resolved' 'Conflicto resuelto'}else{L 'Decision required' 'Decision requerida'});Adapter='Binary range'} }
    'StaticItemConflict' { return [pscustomobject]@{Result=$(if($Resolved){L 'Conflict resolved' 'Conflicto resuelto'}else{L 'Decision required' 'Decision requerida'});Adapter='Static Item'} }
    'DataTableConflict' { return [pscustomobject]@{Result=$(if($Resolved){L 'Conflict resolved' 'Conflicto resuelto'}else{L 'Decision required' 'Decision requerida'});Adapter='DataTable scalar'} }
    'RelocatableConflict' { return [pscustomobject]@{Result=$(if($Resolved){L 'Conflict resolved' 'Conflicto resuelto'}else{L 'Decision required' 'Decision requerida'});Adapter='Relocatable delta'} }
    'PackageChoice' { return [pscustomobject]@{Result=$(if($Resolved){L 'Package selected' 'Paquete elegido'}else{L 'Decision required' 'Decision requerida'});Adapter=(L 'Package variant' 'Variante de paquete')} }
    'Unsupported' { return [pscustomobject]@{Result=(L 'Unsupported' 'No soportado');Adapter=(L 'No safe adapter' 'Sin adapter seguro')} }
    'Identical' { return [pscustomobject]@{Result=(L 'Identical' 'Identico');Adapter=(L 'No patch needed' 'No requiere parche')} }
    default { return [pscustomobject]@{Result=$Mode;Adapter=$Mode} }
  }
}

function Test-PMMDecisionRowResolved($Row) {
  if(-not$Row){return $false}
  $choice=[string]$Row.SelectedChoice
  if([string]::IsNullOrWhiteSpace($choice)){return $false}
  if($choice -eq 'Custom' -and [string]::IsNullOrWhiteSpace([string]$Row.CustomValue)){return $false}
  return $true
}

function Refresh-PMMAnalysisWorkspace {
  $Script:TxtSharedCount.Text='0'
  $Script:TxtAutoCount.Text='0'
  $Script:TxtDecisionCount.Text='0'
  $Script:TxtUnsupportedCount.Text='0'
  $Script:TxtExperimentalCount.Text='0'
  $Script:TxtIdenticalCount.Text='0'
  $Script:DgAnalysisAssets.ItemsSource=@()

  $isCurrent=$false
  try{$isCurrent=Test-PMMMergePlanCurrent}catch{$isCurrent=$false}
  if(-not$isCurrent){
    $Script:TxtAnalysisHeadline.Text=L 'Run Analyze to build a compatibility plan for the current mod library.' 'Ejecuta Analizar para crear el plan de compatibilidad de la biblioteca actual.'
    $Script:TxtAnalysisScope.Text=L 'PMM will list every shared asset here, the mods involved, and whether it can be merged automatically or needs a decision.' 'PMM mostrara aqui cada asset compartido, los mods implicados y si puede fusionarse automaticamente o necesita una decision.'
    return
  }

  $plan=Read-PMMMergePlan
  if(-not$plan){return}
  $assets=@($plan.Assets)
  $decisionRows=@($plan.Rows)
  $alreadyPatched=($plan.PSObject.Properties.Name -contains 'AlreadyPatched' -and [bool]$plan.AlreadyPatched)
  $activePatch=$null

  if($alreadyPatched){
    try{$activePatch=Get-PMMCurrentManagedPatch @(Get-LibraryMods)}catch{$activePatch=$null}
    if($activePatch -and $activePatch.Manifest){
      if($activePatch.Manifest.PSObject.Properties.Name -contains 'Assets'){$assets=@($activePatch.Manifest.Assets)}
      if($activePatch.Manifest.PSObject.Properties.Name -contains 'Decisions'){$decisionRows=@($activePatch.Manifest.Decisions)}
    }
  }

  $report=Get-PMMLastScanReport
  $shared=if($alreadyPatched -and $report -and ($report.PSObject.Properties.Name -contains 'SharedAssetGroups')){[int]$report.SharedAssetGroups}else{$assets.Count}
  $autoModes=@('BinaryAuto','StaticItemAuto','SupersetAuto','ContainedSupersetAuto','KnownRecipeAuto','DataTableAuto','RelocatableAuto')
  $auto=@($assets|Where-Object{[string]$_.Mode -in $autoModes}).Count
  $unsupported=@($assets|Where-Object{[string]$_.Mode -eq 'Unsupported'}).Count
  $experimental=@($assets|Where-Object{[string]$_.Mode -eq 'ManualSolutionExperimental'}).Count
  $identical=@($assets|Where-Object{[string]$_.Mode -eq 'Identical'}).Count
  if($alreadyPatched -and $shared -gt $assets.Count){$identical += ($shared-$assets.Count)}
  $decisions=$decisionRows.Count
  $unresolved=@($decisionRows|Where-Object{-not(Test-PMMDecisionRowResolved $_)}).Count
  $requiresPatchCurrent=Test-PMMPlanRequiresPatch $plan

  $Script:TxtSharedCount.Text=[string]$shared
  $Script:TxtAutoCount.Text=[string]$auto
  $Script:TxtDecisionCount.Text=[string]$decisions
  $Script:TxtUnsupportedCount.Text=[string]$unsupported
  $Script:TxtExperimentalCount.Text=[string]$experimental
  $Script:TxtIdenticalCount.Text=[string]$identical

  if($alreadyPatched){
    $state=if($plan.PSObject.Properties.Name -contains 'PatchDeployed' -and [bool]$plan.PatchDeployed){L 'deployed' 'desplegado'}else{L 'built locally; Deploy pending' 'creado localmente; Deploy pendiente'}
    $Script:TxtAnalysisHeadline.Text=((L 'Current compatibility patch is up to date: {0} ({1}).' 'El parche de compatibilidad actual esta al dia: {0} ({1}).') -f [string]$plan.ActivePatch,$state)
  }elseif($unsupported -gt 0){
    $Script:TxtAnalysisHeadline.Text=((L '{0} shared asset(s) analyzed. Build is blocked by {1} unsupported asset(s).' '{0} asset(s) compartidos analizados. Build esta bloqueado por {1} asset(s) no soportados.') -f $shared,$unsupported)
  }elseif($unresolved -gt 0){
    $Script:TxtAnalysisHeadline.Text=((L '{0} shared asset(s) analyzed. {1} decision(s) still require your choice.' '{0} asset(s) compartidos analizados. Todavia faltan {1} decision(es).') -f $shared,$unresolved)
  }elseif($experimental -gt 0){
    $Script:TxtAnalysisHeadline.Text=((L '{0} shared asset(s) analyzed. Ready to build with {1} experimental manual/AI solution(s); in-game validation is required.' '{0} asset(s) compartidos analizados. Listo para Build con {1} solucion(es) manual/IA experimental(es); se requiere validacion dentro del juego.') -f $shared,$experimental)
  }elseif(-not$requiresPatchCurrent){
    $Script:TxtAnalysisHeadline.Text=((L '{0} compatibility/package item(s) analyzed. No compatibility patch is required; Deploy can use the resolved source set.' '{0} elemento(s) de compatibilidad/paquete analizados. No hace falta parche de compatibilidad; Deploy puede usar el conjunto fuente resuelto.') -f $shared)
  }else{
    $Script:TxtAnalysisHeadline.Text=((L '{0} shared asset(s) analyzed. The compatibility plan is ready to build.' '{0} asset(s) compartidos analizados. El plan de compatibilidad esta listo para Build.') -f $shared)
  }

  $participants=@($assets|Where-Object{[string]$_.Mode -notin @('Identical','Unsupported','PackageChoice')}|ForEach-Object{@($_.Providers)}|ForEach-Object{[string]$_}|Where-Object{$_}|Sort-Object -Unique)
  if($participants.Count -eq 0 -and ($plan.PSObject.Properties.Name -contains 'PatchedMods')){$participants=@($plan.PatchedMods|ForEach-Object{[string]$_}|Where-Object{$_}|Sort-Object -Unique)}
  if($participants.Count -gt 0){
    $Script:TxtAnalysisScope.Text=(L 'Compatibility overlay reconciles shared changes from: ' 'El overlay de compatibilidad reconcilia cambios compartidos de: ') + ($participants -join ', ') + '. ' + (L 'Mods with only unique files remain normal source PAKs.' 'Los mods con archivos unicos permanecen como PAK fuente normales.')
  }else{
    $Script:TxtAnalysisScope.Text=L 'No compatibility overlay work is required for the current shared files.' 'No se necesita trabajo de overlay para los archivos compartidos actuales.'
  }

  $view=[System.Collections.Generic.List[object]]::new()
  foreach($asset in @($assets)){
    $assetRows=@($decisionRows|Where-Object{[string]$_.AssetKey -eq [string]$asset.AssetKey})
    $assetResolved=($assetRows.Count -gt 0 -and @($assetRows|Where-Object{-not(Test-PMMDecisionRowResolved $_)}).Count -eq 0)
    $info=Get-PMMAnalysisModeInfo ([string]$asset.Mode) $assetResolved
    $changed=0
    if($asset.PSObject.Properties.Name -contains 'ChangedPathCount'){$changed=[int]$asset.ChangedPathCount}
    $conflicts=if($asset.PSObject.Properties.Name -contains 'ConflictCount'){[int]$asset.ConflictCount}else{$assetRows.Count}
    $changesText=if($conflicts -gt 0){((L '{0} decision(s)' '{0} decision(es)') -f $conflicts)}elseif($changed -gt 0){[string]$changed}elseif([string]$asset.Mode -eq 'Identical'){'-'}else{L 'composed' 'compuesto'}
    $reason=if($asset.PSObject.Properties.Name -contains 'Reason'){[string]$asset.Reason}else{''}
    if($assetRows.Count -gt 0){
      $unresolvedHere=@($assetRows|Where-Object{-not(Test-PMMDecisionRowResolved $_)}).Count
      if($unresolvedHere -gt 0){
        $reason += $(if($reason){'  '}else{''}) + ((L '{0} decision(s) unresolved.' '{0} decision(es) sin resolver.') -f $unresolvedHere)
      }else{
        $choices=@($assetRows|ForEach-Object{if([string]$_.SelectedChoice -eq 'Custom'){('Custom='+[string]$_.CustomValue)}else{[string]$_.SelectedChoice}}|Where-Object{$_}|Sort-Object -Unique)
        if($choices.Count -gt 0){$reason += $(if($reason){'  '}else{''}) + (L 'Resolved value source(s): ' 'Fuente(s) de valor resuelto: ') + ($choices -join ', ') + '.'}
      }
    }
    if([string]::IsNullOrWhiteSpace($reason) -and $alreadyPatched){$reason=L 'Already reconciled in the current compatibility patch.' 'Ya reconciliado en el parche de compatibilidad actual.'}
    $providers=@($asset.Providers|ForEach-Object{[string]$_}|Where-Object{$_})
    $full=[string]$asset.Asset
    $leaf=if([string]::IsNullOrWhiteSpace($full)){'-'}else{[IO.Path]::GetFileName($full)}
    $view.Add([pscustomobject]@{
      Result=[string]$info.Result
      Asset=$leaf
      Adapter=[string]$info.Adapter
      Providers=($providers -join ', ')
      Changes=$changesText
      FullAsset=$full
      Details=$reason
    })
  }
  $Script:DgAnalysisAssets.ItemsSource=$view.ToArray()
}

function Get-SelectedPMMLibraryEntries {
  return @($Script:LstMods.SelectedItems | Where-Object{$_ -and [string]$_.Kind -eq 'Source'})
}

function Get-SelectedPMMLibraryEntry {
  $items=@(Get-SelectedPMMLibraryEntries)
  if($items.Count -eq 0){return $null}
  return $items[0]
}

function Update-PMMLibraryButtons {
  if($Script:ImportBusy -or $Script:AnalyzeBusy -or $Script:BuildBusy -or $Script:DeployBusy -or $Script:AIIOBusy){
    foreach($button in @($Script:BtnSelectAllMods,$Script:BtnClearModSelection,$Script:BtnEnableMods,$Script:BtnDisableMods,$Script:BtnDeleteMod,$Script:BtnPriorityUp,$Script:BtnPriorityDown)){$button.IsEnabled=$false}
    return
  }
  $entries=@(Get-SelectedPMMLibraryEntries)
  $count=$entries.Count
  $single=($count -eq 1)
  $entry=if($single){$entries[0]}else{$null}
  $allSources=@($Script:LstMods.ItemsSource | Where-Object{$_ -and [string]$_.Kind -eq 'Source'})

  $Script:BtnSelectAllMods.IsEnabled=($allSources.Count -gt 0 -and $count -lt $allSources.Count)
  $Script:BtnClearModSelection.IsEnabled=($count -gt 0)
  $Script:BtnEnableMods.IsEnabled=(@($entries|Where-Object{-not[bool]$_.Enabled}).Count -gt 0)
  $Script:BtnDisableMods.IsEnabled=(@($entries|Where-Object{[bool]$_.Enabled}).Count -gt 0)
  $Script:BtnDeleteMod.IsEnabled=($count -gt 0)

  # Selection is presentation-only. The old code enumerated the full portable
  # library twice on every row click via Test-PMMModPriorityMove. Priority is
  # already normalized in the current ItemsSource, so no filesystem access is
  # needed to decide whether Earlier/Later should be enabled.
  if($single){
    $priority=0
    try{$priority=[int]$entry.Priority}catch{$priority=0}
    $Script:BtnPriorityUp.IsEnabled=($priority -gt 1)
    $Script:BtnPriorityDown.IsEnabled=($priority -gt 0 -and $priority -lt $allSources.Count)
  }else{
    $Script:BtnPriorityUp.IsEnabled=$false
    $Script:BtnPriorityDown.IsEnabled=$false
  }
}

function Update-PMMPatchActionButtons {
  if(-not$Script:BtnDeletePatch -or -not$Script:BtnValidatePatch -or -not$Script:BtnUndeployPatch){return}
  $Script:BtnDeletePatch.IsEnabled=$false;$Script:BtnValidatePatch.IsEnabled=$false;$Script:BtnUndeployPatch.IsEnabled=$false
  $Script:BtnValidatePatch.Content=L 'Validate merge' 'Validar merge'
  if($Script:ImportBusy -or $Script:AnalyzeBusy -or $Script:BuildBusy -or $Script:DeployBusy -or $Script:AIIOBusy){return}
  $entry=$Script:LstPatches.SelectedItem
  if(-not$entry -or -not($entry.PSObject.Properties.Name -contains 'Patch') -or -not$entry.Patch){return}
  $patch=$entry.Patch
  $validation=$null;try{$validation=Get-PMMBuildValidationSummary $patch}catch{}
  $state=if($validation){[string]$validation.Status}else{'UNVALIDATED'}
  switch($state){
    'LOCAL_PASS' {$Script:BtnValidatePatch.Content=L 'Working - validate again' 'Funciona - validar de nuevo';$Script:BtnValidatePatch.IsEnabled=$true}
    'LOCAL_PARTIAL' {$Script:BtnValidatePatch.Content=L 'Partial - validate again' 'Parcial - validar de nuevo';$Script:BtnValidatePatch.IsEnabled=$true}
    'LOCAL_FAIL' {$Script:BtnValidatePatch.Content=L 'Failed - validate again' 'Fallo - validar de nuevo';$Script:BtnValidatePatch.IsEnabled=$true}
    'STALE' {$Script:BtnValidatePatch.Content=L 'Validation stale' 'Validacion obsoleta';$Script:BtnValidatePatch.IsEnabled=$false}
    'NOT_DEPLOYED' {$Script:BtnValidatePatch.Content=L 'Deploy before validation' 'Despliega antes de validar';$Script:BtnValidatePatch.IsEnabled=$false}
    default {$Script:BtnValidatePatch.IsEnabled=[bool]$patch.Deployed}
  }
  # Delete is a full lifecycle delete: exact game copy + saved PMM copies.
  $Script:BtnDeletePatch.IsEnabled=$true
  # Undeploy is deliberately independent of source compatibility/selectability.
  $Script:BtnUndeployPatch.IsEnabled=[bool]$patch.Deployed
}

function Get-PMMPatchDecisionDisplay($Patch) {
  if(-not$Patch -or -not$Patch.Manifest){return [pscustomobject]@{Summary=(L 'Unknown' 'Desconocido');Details=''}}
  $manifest=$Patch.Manifest
  $rows=@()
  if($manifest.PSObject.Properties.Name -contains 'Decisions'){$rows=@($manifest.Decisions)}
  if($rows.Count -eq 0){
    $experimental=0
    if($manifest.PSObject.Properties.Name -contains 'ExperimentalManualSolutions'){$experimental=@($manifest.ExperimentalManualSolutions).Count}
    if($experimental -gt 0){return [pscustomobject]@{Summary=(L 'Experimental manual' 'Manual experimental');Details=(L 'Contains an explicitly accepted experimental manual/AI cooked solution.' 'Contiene una solucion cooked manual/IA experimental aceptada explicitamente.')}}
    return [pscustomobject]@{Summary=(L 'Automatic' 'Automatico');Details=(L 'No user conflict decisions are stored in this patch.' 'Este parche no guarda decisiones de conflicto del usuario.')}
  }
  $parts=[System.Collections.Generic.List[string]]::new()
  foreach($row in $rows){
    $choice=[string]$row.SelectedChoice
    if([string]::IsNullOrWhiteSpace($choice)){$choice=L 'unresolved' 'sin resolver'}
    elseif($choice -eq 'Custom'){$choice='Custom='+[string]$row.CustomValue}
    $label=''
    if($row.PSObject.Properties.Name -contains 'DisplayProperty'){$label=[string]$row.DisplayProperty}
    if([string]::IsNullOrWhiteSpace($label) -and ($row.PSObject.Properties.Name -contains 'Property')){$label=[string]$row.Property}
    if([string]::IsNullOrWhiteSpace($label)){$label=L 'decision' 'decision'}
    $parts.Add(($label+' = '+$choice))
  }
  $all=$parts.ToArray()
  $summary=if($all.Count -eq 1){
    $choice=[string]$rows[0].SelectedChoice
    if($choice -eq 'Custom'){'Custom='+[string]$rows[0].CustomValue}elseif([string]::IsNullOrWhiteSpace($choice)){L 'unresolved' 'sin resolver'}else{$choice}
  }else{(L '{0} decisions' '{0} decisiones') -f $all.Count}
  return [pscustomobject]@{Summary=$summary;Details=($all -join "`n")}
}

function Update-BuildButtonState {
  $Script:BtnBuild.IsEnabled=$false
  $Script:BtnDeploy.IsEnabled=$false
  $Script:TxtBuildDeployHint.Text=L 'Analyze the active source set to prepare Build/Deploy.' 'Analiza el conjunto de fuentes activo para preparar Build/Deploy.'
  $sourceMods=@(Get-LibraryMods)
  $noPatchSelected=Test-PMMNoPatchSelected
  $selectedPatch=if($noPatchSelected){$null}else{Get-PMMSelectedManagedPatch $sourceMods}
  $plan=Read-PMMMergePlan
  if(-not$plan -or -not(Test-PMMMergePlanCurrent)){
    if($noPatchSelected -and $sourceMods.Count -gt 0){
      $Script:BtnDeploy.IsEnabled=$true
      $Script:TxtBuildDeployHint.Text=L 'Manager-only mode: Deploy will synchronize active source mods without a compatibility overlay and remove any PMM overlay currently deployed. Analyze is optional in this mode.' 'Modo solo manager: Deploy sincronizara los mods fuente activos sin overlay de compatibilidad y retirara cualquier overlay PMM desplegado. Analizar es opcional en este modo.'
    }elseif($selectedPatch){
      $Script:BtnDeploy.IsEnabled=$true
      $Script:TxtBuildDeployHint.Text=((L 'Selected saved patch matches the exact active source hashes and mappings: {0}. Deploy is ready without Analyze. Run Analyze only if you want to inspect or build a new compatibility plan.' 'El parche guardado seleccionado coincide exactamente con los hashes de fuentes activos y los mappings: {0}. Deploy esta listo sin Analizar. Usa Analizar solo si quieres revisar o crear un nuevo plan de compatibilidad.') -f [string]$selectedPatch.Name)
    }
    return
  }

  $currentDecisionPatch=Get-PMMCurrentManagedPatch $sourceMods
  $unsupported=@(Get-PMMUnsupportedAssets)
  $alreadyPatched=($plan.PSObject.Properties.Name -contains 'AlreadyPatched' -and [bool]$plan.AlreadyPatched)
  $requiresPatch=Test-PMMPlanRequiresPatch $plan
  $unresolved=@($plan.Rows|Where-Object{-not(Test-PMMDecisionRowResolved $_)}).Count
  $unresolvedPackage=@($plan.Rows|Where-Object{($_.PSObject.Properties.Name -contains 'DecisionKind') -and [string]$_.DecisionKind -eq 'PackageChoice' -and -not(Test-PMMDecisionRowResolved $_)}).Count
  $packagePending=(($plan.PSObject.Properties.Name -contains 'PackageChoicePendingReanalysis') -and [bool]$plan.PackageChoicePendingReanalysis)
  $selectedMatchesDecision=($selectedPatch -and (Test-PMMPatchCurrent $selectedPatch $sourceMods))

  # Build always follows the currently displayed Analyze decisions. Deploy can
  # also intentionally roll back to an exact-source patch, or reuse one after
  # current Analyze proves its effective conflict recipe is still identical.
  $Script:BtnBuild.IsEnabled=(-not$alreadyPatched -and -not$packagePending -and $requiresPatch -and $unsupported.Count -eq 0 -and $unresolved -eq 0 -and -not$currentDecisionPatch)
  $Script:BtnDeploy.IsEnabled=(-not$packagePending -and $unresolvedPackage -eq 0 -and ($noPatchSelected -or -not$requiresPatch -or $null -ne $selectedPatch))

  if($packagePending){
    if($unresolvedPackage -gt 0){
      $Script:TxtBuildDeployHint.Text=((L '{0} package variant decision(s) must be resolved. Open Resolution & Review, choose the valid package configuration, then run Analyze again.' 'Debes resolver {0} decision(es) de variante de paquete. Abre Resolucion y revision, elige la configuracion valida y vuelve a ejecutar Analizar.') -f $unresolvedPackage)
    }else{
      $Script:TxtBuildDeployHint.Text=L 'Package variant selected. Run Analyze again so PMM can analyze only the chosen package components before Build/Deploy.' 'Variante de paquete elegida. Ejecuta Analizar de nuevo para que PMM analice solo los componentes elegidos antes de Build/Deploy.'
    }
    return
  }

  if($unsupported.Count -gt 0){
    if($noPatchSelected){
      $Script:TxtBuildDeployHint.Text=((L 'Manager-only mode selected. Analyze found {0} unsupported shared asset(s), but Deploy may still synchronize the active source PAKs without a PMM compatibility overlay. Their conflicts will then follow normal Palworld PAK load order.' 'Modo solo manager seleccionado. Analizar encontro {0} asset(s) compartido(s) no soportado(s), pero Deploy puede sincronizar los PAK fuente activos sin overlay de compatibilidad PMM. Sus conflictos seguiran entonces el orden normal de carga de PAK de Palworld.') -f $unsupported.Count)
    }elseif($selectedPatch){
      $Script:TxtBuildDeployHint.Text=((L 'Current Analyze is blocked by {0} unsupported asset(s), but the selected saved patch was built for this exact source set. Build remains blocked; Deploy can roll back to the selected known patch.' 'El Analisis actual esta bloqueado por {0} asset(s) no soportado(s), pero el parche guardado seleccionado fue creado para este conjunto exacto de fuentes. Build sigue bloqueado; Deploy puede volver al parche conocido seleccionado.') -f $unsupported.Count)
    }else{
      $Script:TxtBuildDeployHint.Text=((L 'Blocked by {0} unsupported shared asset(s). Disable one provider above or use CREATE AI HANDOFF. A patch from a different source set cannot be deployed.' 'Bloqueado por {0} asset(s) compartido(s) no soportado(s). Desactiva un provider arriba o usa CREAR ENTREGA PARA IA. No se puede desplegar un parche de otro conjunto de fuentes.') -f $unsupported.Count)
    }
    return
  }

  if($unresolved -gt 0){
    if($noPatchSelected){
      $Script:TxtBuildDeployHint.Text=((L 'Manager-only mode selected. {0} compatibility decision(s) are unresolved, but Deploy can still install the active source mods without a PMM overlay. Normal PAK load order will decide those overlaps.' 'Modo solo manager seleccionado. Hay {0} decision(es) de compatibilidad sin resolver, pero Deploy puede instalar los mods fuente activos sin overlay PMM. El orden normal de carga de PAK decidira esos solapamientos.') -f $unresolved)
    }elseif($selectedPatch){
      $Script:TxtBuildDeployHint.Text=((L '{0} new decision(s) are unresolved, so Build is waiting. The selected saved patch already contains an older resolved choice for this exact source set and may still be deployed as a rollback.' 'Hay {0} decision(es) nuevas sin resolver, asi que Build esta esperando. El parche guardado seleccionado ya contiene una eleccion anterior resuelta para este conjunto exacto y aun puede desplegarse como rollback.') -f $unresolved)
    }else{
      $Script:TxtBuildDeployHint.Text=((L '{0} true-conflict decision(s) still need a value. Expand Resolution & Review and choose the value before Build.' 'Todavia faltan {0} decision(es) de conflicto real. Abre Resolucion y revision y elige el valor antes de Build.') -f $unresolved)
    }
    return
  }

  if($noPatchSelected){
    $resolvedPackageRows=@($plan.Rows|Where-Object{($_.PSObject.Properties.Name -contains 'DecisionKind') -and [string]$_.DecisionKind -eq 'PackageChoice' -and (Test-PMMDecisionRowResolved $_)})
    if($resolvedPackageRows.Count -gt 0){
      $Script:TxtBuildDeployHint.Text=L 'Package choice is resolved. Deploy will keep the chosen package components, exclude the unselected alternative(s), synchronize the other active source mods, and remove any PMM overlay.' 'La eleccion de paquete esta resuelta. Deploy conservara los componentes elegidos, excluira las alternativas no seleccionadas, sincronizara los demas mods fuente activos y retirara cualquier overlay PMM.'
    }else{
      $Script:TxtBuildDeployHint.Text=L 'No compatibility patch selected. Deploy will synchronize active source mods only, remove any deployed PMM overlay, and leave source-mod conflicts to normal Palworld PAK load order. Saved patches are kept in the library.' 'No hay parche de compatibilidad seleccionado. Deploy sincronizara solo los mods fuente activos, retirara cualquier overlay PMM desplegado y dejara los conflictos entre mods fuente al orden normal de carga de PAK de Palworld. Los parches guardados se conservan en la biblioteca.'
    }
    return
  }

  if(@($plan.Assets|Where-Object{[string]$_.Mode -eq 'ManualSolutionExperimental'}).Count -gt 0 -and -not$currentDecisionPatch){
    $Script:TxtBuildDeployHint.Text=L 'The plan contains an experimental manual/AI cooked solution. PMM validated provenance/structure, not gameplay. Build only if you accept an in-game test.' 'El plan contiene una solucion cooked manual/IA experimental. PMM valido procedencia/estructura, no gameplay. Usa Build solo si aceptas probarla dentro del juego.'
    return
  }

  if($alreadyPatched -and ($plan.PSObject.Properties.Name -contains 'PatchReuseKind') -and [string]$plan.PatchReuseKind -eq 'EffectiveConflictSet'){
    $Script:TxtBuildDeployHint.Text=((L 'The effective conflict set is unchanged, so PMM reused {0}. No Build is needed. Deploy will only synchronize the changed active/disabled source PAKs and keep the proven overlay.' 'El conjunto efectivo de conflictos no ha cambiado, asi que PMM reutilizo {0}. No hace falta Build. Deploy solo sincronizara los PAK fuente activados/desactivados y conservara el overlay probado.') -f [string]$plan.ActivePatch)
    return
  }

  if($requiresPatch -and $selectedPatch){
    if($selectedMatchesDecision){
      $Script:TxtBuildDeployHint.Text=((L 'Selected patch matches the active source set and current Analyze decisions: {0}. Deploy is ready.' 'El parche seleccionado coincide con el conjunto activo y las decisiones actuales de Analisis: {0}. Deploy esta listo.') -f [string]$selectedPatch.Name)
    }else{
      $Script:TxtBuildDeployHint.Text=((L 'Selected saved patch matches the exact active source set but contains different earlier conflict decisions: {0}. Deploy will roll back to it. Build creates the currently analyzed decisions instead.' 'El parche guardado seleccionado coincide con el conjunto exacto de fuentes, pero contiene decisiones de conflicto anteriores distintas: {0}. Deploy volvera a ese parche. Build crea en cambio las decisiones analizadas actualmente.') -f [string]$selectedPatch.Name)
    }
  }elseif($requiresPatch){
    $Script:TxtBuildDeployHint.Text=L 'Analysis is compatible and complete. Build a new compatibility patch, then Deploy.' 'El analisis es compatible y esta completo. Crea un nuevo parche de compatibilidad y despues usa Deploy.'
  }else{
    $Script:TxtBuildDeployHint.Text=L 'No compatibility patch is required for the analyzed set. Deploy can synchronize the source mods.' 'No hace falta parche de compatibilidad para el conjunto analizado. Deploy puede sincronizar los mods fuente.'
  }
}

# ---------------------------------------------------------------------------
# General UI refresh / errors / game detection.
# ---------------------------------------------------------------------------
function Update-PMMDeploymentOptionsState {
  $Script:ChkForceClose.IsEnabled=[bool]$Script:ChkCloseGame.IsChecked
}

function Refresh-UI {
  $cfg = Get-PMMConfig
  $gamePath=[string]$cfg.GamePath
  $resolvedGame=$null
  try{if(-not[string]::IsNullOrWhiteSpace($gamePath)){$resolvedGame=Resolve-PalworldRoot $gamePath}}catch{$resolvedGame=$null}
  $gameReady=(-not[string]::IsNullOrWhiteSpace([string]$resolvedGame))
  $Script:TxtGamePath.Text = $gamePath
  $Script:TxtGamePath.ToolTip = $gamePath
  if($gameReady){
    $Script:TxtGamePathStatus.Text=((L 'Palworld detected - {0}' 'Palworld detectado - {0}') -f [string]$resolvedGame)
    $Script:TxtGamePathStatus.Foreground=$Window.Resources['AccentHeadingGreen']
    $Script:TxtGamePathStatus.ToolTip=[string]$resolvedGame
  }elseif(-not[string]::IsNullOrWhiteSpace($gamePath)){
    $Script:TxtGamePathStatus.Text=L 'Configured Palworld path is not valid - click to detect or configure it in Settings.' 'La ruta configurada de Palworld no es válida - pulsa para detectar o configúrala en Opciones.'
    $Script:TxtGamePathStatus.Foreground=$Window.Resources['AccentHeadingAmber']
    $Script:TxtGamePathStatus.ToolTip=$gamePath
  }else{
    $Script:TxtGamePathStatus.Text=L 'Palworld not detected - click to detect' 'Palworld no detectado - pulsa para detectar'
    $Script:TxtGamePathStatus.Foreground=$Window.Resources['MutedText']
    $Script:TxtGamePathStatus.ToolTip=$null
  }
  foreach($button in @($Script:BtnOpenGame,$Script:BtnOpenGameSettings,$Script:BtnOpenModsFolder,$Script:BtnOpenModsSettings,$Script:BtnPlay)){if($button){$button.IsEnabled=$gameReady}}
  if($Script:BtnDetectGame){$Script:BtnDetectGame.Visibility=[System.Windows.Visibility]::Visible;$Script:BtnDetectGame.IsEnabled=(-not $gameReady)}
  $Script:TxtLibraryPath.Text = Get-PMMPath 'Mods'
  $Script:UiSettingsRefreshing=$true
  try{
    $Script:ChkCloseGame.IsChecked = [bool]$cfg.CloseGameBeforeDeploy
    $Script:ChkForceClose.IsChecked = [bool]$cfg.ForceCloseOnTimeout
    $Script:TglAutoMode.IsChecked = [bool]$cfg.AutoMode
    $Script:ChkAutoPlay.IsChecked = [bool]$cfg.AutoIncludePlay
    Update-PMMDeploymentOptionsState
    $Script:CmbLanguage.SelectedValue = if ($cfg.Language -eq 'es') { 'es' } else { 'en' }
    $hintSeconds=5
    try{$hintSeconds=[int]$cfg.ActionHintSeconds}catch{$hintSeconds=5}
    if(-($hintSeconds -eq -1 -or ($hintSeconds -ge 0 -and $hintSeconds -le 120))){$hintSeconds=5}
    $Script:CmbActionHintDuration.SelectedValue=$hintSeconds
    $theme='pmm-crystal';try{$theme=[string]$cfg.Theme}catch{};if($theme -eq 'Dark'){$theme='Night'}
    if($Script:ThemePreviewActive -and $Script:ActiveThemeDraft){Apply-PMMThemeDefinition (Get-PMMThemeDraftPreviewDefinition $Script:ActiveThemeDraft)}else{Apply-PMMTheme $theme}
    Refresh-PMMThemeOptions $theme
    Initialize-PMMSoundSettingsUi $cfg
    $volume=50;try{$volume=[int]$cfg.CompletionVolume}catch{};$volume=[Math]::Max(0,[Math]::Min(100,$volume))
    $Script:SldCompletionVolume.Value=$volume;$Script:TxtCompletionVolume.Text=($volume.ToString()+'%')
  }finally{$Script:UiSettingsRefreshing=$false}

  $sourceMods=@(Get-LibraryMods)
  $disabledMods=@(Get-PMMDisabledMods)
  $managedPatches=@(Get-PMMManagedPatches)
  $displayItems=[System.Collections.Generic.List[object]]::new()
  foreach($mod in $sourceMods){
    $displayItems.Add([pscustomobject]@{Kind='Source';Name=[string]$mod.Name;Enabled=$true;State=(L 'active' 'activo');Priority=[int]$mod.Priority;SizeText=("{0:N2}" -f ($mod.Size/1MB));HashShort=$mod.Hash.Substring(0,12)})
  }
  foreach($mod in $disabledMods){
    $displayItems.Add([pscustomobject]@{Kind='Source';Name=[string]$mod.Name;Enabled=$false;State=(L 'disabled' 'desactivado');Priority=[int]$mod.Priority;SizeText=("{0:N2}" -f ($mod.Size/1MB));HashShort=$mod.Hash.Substring(0,12)})
  }
  $Script:TxtLibraryCount.Text=((L '{0} active  |  {1} disabled' '{0} activos  |  {1} desactivados') -f $sourceMods.Count,$disabledMods.Count)
  Set-PMMLibraryDisplayItems @($displayItems|Sort-Object Priority,Name)

  $Script:LstPatches.Items.Clear()
  $selectedPatch=Get-PMMSelectedManagedPatch $sourceMods
  $currentCompatibilityPlan=Get-PMMCurrentPlanForPatchCompatibility $sourceMods
  $noPatchSelected=Test-PMMNoPatchSelected
  $compatibleCount=0
  $deployedCount=0
  $savedCount=0
  foreach($patch in $managedPatches){if($patch.Deployed){$deployedCount++};if([bool]$patch.BackedUp){$savedCount++}}
  $noneStatus=if($noPatchSelected -and $deployedCount -gt 0){L 'SELECTED | OVERLAY REMOVAL PENDING' 'SELECCIONADO | RETIRAR OVERLAY PENDIENTE'}elseif($noPatchSelected){L 'SELECTED | SOURCE MODS ONLY' 'SELECCIONADO | SOLO MODS FUENTE'}else{L 'SOURCE MODS ONLY' 'SOLO MODS FUENTE'}
  [void]$Script:LstPatches.Items.Add([pscustomobject]@{
    Name=(L 'No compatibility patch' 'Sin parche de compatibilidad');SelectionKey=(Get-PMMNoPatchSelectionName);Patch=$null;Selected=[bool]$noPatchSelected;Selectable=$true;
    SelectTip=(L 'Deploy active source mods without a PMM compatibility overlay. Any deployed PMM overlay will be removed; saved patches stay in the library.' 'Despliega los mods fuente activos sin overlay de compatibilidad PMM. Se retirara cualquier overlay PMM desplegado; los parches guardados permanecen en la biblioteca.');
    Status=$noneStatus;Built='';Assets='';DecisionSummary=(L 'None' 'Ninguna');DecisionDetails=(L 'Manager-only deployment. PMM does not apply a compatibility overlay.' 'Deploy solo como manager. PMM no aplica un overlay de compatibilidad.')
  })
  foreach($patch in $managedPatches){
    $exactSourceMatch=Test-PMMPatchSourceSetCompatible $patch $sourceMods
    $effectivePlanMatch=($currentCompatibilityPlan -and (Test-PMMPatchPlanCompatible $patch $currentCompatibilityPlan $sourceMods))
    $sourceMatch=($exactSourceMatch -or $effectivePlanMatch)
    if($sourceMatch){$compatibleCount++}
    $selected=($selectedPatch -and [string]$selectedPatch.Name -ieq [string]$patch.Name)
    $decisionMatch=($sourceMatch -and (Test-PMMPatchCurrent $patch $sourceMods))
    $effectiveOrderMatch=($sourceMatch -and (Test-PMMPatchEffectiveOrderCompatible $patch $sourceMods))
    $status=if($patch.Deployed -and -not[bool]$patch.BackedUp){L 'DEPLOYED | EXTERNAL ONLY' 'DESPLEGADO | SOLO EXTERNO'}elseif($patch.Deployed -and $decisionMatch){L 'DEPLOYED / CURRENT' 'DESPLEGADO / ACTUAL'}elseif($patch.Deployed -and -not$sourceMatch){L 'DEPLOYED | SOURCES NOT IMPORTED' 'DESPLEGADO | FUENTES NO IMPORTADAS'}elseif($patch.Deployed){L 'DEPLOYED | SAVED BUILD' 'DESPLEGADO | BUILD GUARDADO'}elseif($decisionMatch){L 'SAVED | CURRENT BUILD' 'GUARDADO | BUILD ACTUAL'}elseif($sourceMatch -and -not$effectiveOrderMatch){L 'SAVED | EFFECTIVE ORDER CHANGED' 'GUARDADO | CAMBIO DE ORDEN EFECTIVO'}elseif($sourceMatch){L 'SAVED | SAME SOURCE SET' 'GUARDADO | MISMAS FUENTES'}else{L 'SAVED | OTHER SOURCES' 'GUARDADO | OTRAS FUENTES'}
    if($selected -and -not$patch.Deployed){$status=(L 'SELECTED | ' 'SELECCIONADO | ')+$status}
    $validated=$false;$validationStatus='UNVALIDATED'
    try{$validation=Get-PMMBuildValidationSummary $patch;$validationStatus=[string]$validation.Status;$validated=($validationStatus -eq 'LOCAL_PASS')}catch{}
    $validationLabel=switch($validationStatus){
      'LOCAL_PASS' {L 'LOCAL PASS' 'PASS LOCAL'}
      'LOCAL_PARTIAL' {L 'LOCAL PARTIAL' 'PARCIAL LOCAL'}
      'LOCAL_FAIL' {L 'LOCAL FAIL' 'FALLO LOCAL'}
      'STALE' {L 'VALIDATION STALE' 'VALIDACION OBSOLETA'}
      'NOT_DEPLOYED' {L 'NOT DEPLOYED' 'NO DESPLEGADO'}
      default {L 'UNVALIDATED' 'SIN VALIDAR'}
    }
    $status=$validationLabel+' | '+$status
    $tip=if($sourceMatch){
      if($effectivePlanMatch -and -not$exactSourceMatch){L 'Selectable: current Analyze proves that every effective conflict participant, provider hash, adapter, decision, mapping and Vanilla input still matches. Unrelated unique source mods may differ; Deploy will synchronize them without rebuilding the overlay.' 'Seleccionable: el Analisis actual demuestra que siguen coincidiendo todos los participantes efectivos de conflicto, hashes de providers, adapters, decisiones, mappings y Vanilla. Pueden diferir mods fuente unicos no relacionados; Deploy los sincronizara sin reconstruir el overlay.'}
      elseif($decisionMatch){L 'Selectable: exact source hashes, mappings, effective conflict order and current Analyze decisions match.' 'Seleccionable: coinciden hashes fuente, mappings, orden efectivo de conflictos y decisiones actuales de Analisis.'}
      elseif(-not$effectiveOrderMatch){L 'Selectable rollback: source hashes + mappings match, but an output-relevant priority winner changed (or the patch uses a legacy order signature). Select it explicitly only if you want that older output.' 'Rollback seleccionable: coinciden hashes fuente + mappings, pero cambio un ganador de prioridad que afecta al resultado (o el parche usa una firma de orden legacy). Seleccionalo explicitamente solo si quieres esa salida anterior.'}
      else{L 'Selectable rollback: source hashes + mappings + effective conflict order match; this patch may contain different previous manual conflict choices.' 'Rollback seleccionable: coinciden hashes fuente + mappings + orden efectivo de conflictos; este parche puede contener elecciones manuales de conflicto anteriores distintas.'}
    }elseif($patch.Deployed -and -not[bool]$patch.BackedUp){
      L 'External PMM merge detected in Palworld. PMM recognizes its deployment but will not silently recreate a saved build. Undeploy removes it from the game; Delete removes the exact deployed copy and any matching saved copy.' 'Merge PMM externo detectado en Palworld. PMM reconoce su despliegue pero no recreara silenciosamente un build guardado. Undeploy lo retira del juego; Delete borra la copia desplegada exacta y cualquier copia guardada coincidente.'
    }else{L 'Not selectable yet: the current PMM library does not contain the exact source mod hashes + mappings recorded by this patch. Import the source mods first; a deployed copy may remain active in Palworld meanwhile.' 'Aun no seleccionable: la biblioteca PMM actual no contiene los hashes exactos de mods fuente + mappings registrados por este parche. Importa primero los mods fuente; mientras tanto una copia ya desplegada puede seguir activa en Palworld.'}
    $built=''
    try{$built=([datetime]$patch.Modified).ToLocalTime().ToString('yyyy-MM-dd HH:mm')}catch{$built=[string]$patch.Modified}
    $decisionDisplay=Get-PMMPatchDecisionDisplay $patch
    [void]$Script:LstPatches.Items.Add([pscustomobject]@{
      Name=[string]$patch.Name;SelectionKey=[string]$patch.Name;Patch=$patch;Selected=[bool]$selected;Selectable=[bool]$sourceMatch;SelectTip=$tip;Validated=[bool]$validated;
      Status=$status;Built=$built;Assets=[string]$patch.AssetCount;DecisionSummary=[string]$decisionDisplay.Summary;DecisionDetails=[string]$decisionDisplay.Details
    })
  }
  $Script:TxtPatchCount.Text=((L '{0} saved  |  {1} selectable for active set  |  {2} deployed' '{0} guardado(s)  |  {1} seleccionable(s) para activos  |  {2} desplegado(s)') -f $savedCount,$compatibleCount,$deployedCount)

  Refresh-PMMAnalysisWorkspace
  Refresh-ConflictWorkspace

  $selectedSaveName='';try{if($Script:LstSaves.SelectedItem){$selectedSaveName=[string]$Script:LstSaves.SelectedItem.Name}}catch{}
  $Script:LstSaves.Items.Clear()
  foreach ($save in @(Get-PMMSaveWorlds)) { [void]$Script:LstSaves.Items.Add($save) }
  if($selectedSaveName){foreach($item in @($Script:LstSaves.Items)){if([string]$item.Name -eq $selectedSaveName){$Script:LstSaves.SelectedItem=$item;break}}}
  $Script:PrgBuild.IsIndeterminate = $false
  $Script:PrgBuild.Visibility = [System.Windows.Visibility]::Collapsed
  $Script:PrgBuild.Value = 0
  $Script:TxtBuildProgress.Text = ''
  $Script:TxtStatus.Text = Get-PMMStatusLine
  $Script:TxtLog.Text = Get-PMMRecentLog
  try{
    $gr=Get-PMMGameReferenceState
    $grSize=if([int64]$gr.Bytes -gt 0){('{0:N1} MiB' -f ([double]$gr.Bytes/1MB))}else{'0 MiB'}
    $grCreated=''
    if(-not [string]::IsNullOrWhiteSpace([string]$gr.CreatedUtc)){try{$grCreated=([datetime]$gr.CreatedUtc).ToLocalTime().ToString('yyyy-MM-dd HH:mm')}catch{$grCreated=[string]$gr.CreatedUtc}}
    if([string]$gr.Status -eq 'Current'){
      $Script:TxtGameReferenceSummary.Text=((L 'Status: Current | {0} families | {1} files | {2} | built {3}. This is a local research/reference cache; AIIO handoffs independently extract only each exact conflicting Vanilla file.' 'Estado: Actual | {0} familias | {1} archivos | {2} | creado {3}. Esta es una cache local de investigacion/referencia; los handoffs AIIO extraen de forma independiente solo cada archivo Vanilla exacto en conflicto.') -f [int]$gr.FamilyCount,[int]$gr.FileCount,$grSize,$grCreated)
    }elseif([string]$gr.Status -eq 'Stale'){
      $Script:TxtGameReferenceSummary.Text=((L 'Status: Stale. {0} Build/refresh before relying on it for a new AI_HANDOFF.' 'Estado: Desactualizado. {0} Crea/actualiza la referencia antes de usarla en un nuevo AI_HANDOFF.') -f [string]$gr.Reason)
    }elseif([string]$gr.Status -eq 'NotBuilt'){
      $Script:TxtGameReferenceSummary.Text=L 'Status: Not built. Optional local research/reference cache; AIIO does not require it to create a handoff.' 'Estado: No creada. Cache local opcional de investigacion/referencia; AIIO no la necesita para crear un handoff.'
    }else{
      $Script:TxtGameReferenceSummary.Text=((L 'Status: {0}. {1}' 'Estado: {0}. {1}') -f [string]$gr.Status,[string]$gr.Reason)
    }
  }catch{$Script:TxtGameReferenceSummary.Text=L 'Game Reference status unavailable.' 'Estado de Game Reference no disponible.'}
  try{
    $ks=Get-PMMKnowledgeSummary
    $Script:TxtKnowledgeSummary.Text=((L 'Bundled knowledge: {0} behavior case(s), {1} exact fixture(s), {2} runtime-proven fixture(s), {3} exact runtime recipe(s). Recipes activate only after exact hash/structure validation.' 'Conocimiento incluido: {0} caso(s) de comportamiento, {1} fixture(s) exactos, {2} fixture(s) probados en runtime, {3} receta(s) runtime exacta(s). Las recetas solo se activan tras validar hashes/estructura exactos.') -f $ks.BehaviorCases,$ks.Fixtures,$ks.RuntimeProven,$ks.ProductionRecipes)
  }catch{$Script:TxtKnowledgeSummary.Text=L 'Knowledge library unavailable.' 'Biblioteca Knowledge no disponible.'}
  Update-PMMLibraryButtons
  Update-PMMPatchActionButtons
  Update-PMMAnalyzeIndicator
  Update-BuildButtonState
  Update-PMMGuidedActionState
  try{Refresh-PMMAIHelpBadge}catch{}
}

function Select-PalworldInstallation([array]$Paths) {
  $items = @(Get-UniqueWindowsPaths $Paths)
  if ($items.Count -eq 0) { return $null }
  if ($items.Count -eq 1) { return $items[0] }

  Add-Type -AssemblyName System.Windows.Forms
  Add-Type -AssemblyName System.Drawing
  $form = New-Object System.Windows.Forms.Form
  $form.Text = L 'Choose Palworld installation' 'Elegir instalacion de Palworld'
  $form.Width = 780; $form.Height = 390; $form.StartPosition = 'CenterScreen'
  $label = New-Object System.Windows.Forms.Label
  $label.Left = 15; $label.Top = 15; $label.Width = 735; $label.Height = 45
  $label.Text = L 'More than one different Palworld installation was found. Choose the one PMM should manage.' 'Se encontro mas de una instalacion diferente de Palworld. Elige la que debe gestionar PMM.'
  $list = New-Object System.Windows.Forms.ListBox
  $list.Left = 15; $list.Top = 65; $list.Width = 735; $list.Height = 220
  foreach ($item in $items) { [void]$list.Items.Add($item) }
  $list.SelectedIndex = 0
  $ok = New-Object System.Windows.Forms.Button; $ok.Text = 'OK'; $ok.Left = 575; $ok.Top = 300; $ok.Width = 80; $ok.DialogResult = [System.Windows.Forms.DialogResult]::OK
  $cancel = New-Object System.Windows.Forms.Button; $cancel.Text = L 'Cancel' 'Cancelar'; $cancel.Left = 665; $cancel.Top = 300; $cancel.Width = 85; $cancel.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
  $form.Controls.AddRange(@($label,$list,$ok,$cancel)); $form.AcceptButton = $ok; $form.CancelButton = $cancel
  if ($form.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) { return $null }
  return [string]$list.SelectedItem
}

function Handle-UIError($ErrorRecord,[string]$Action) {
  $message = $ErrorRecord.Exception.Message
  Write-PMMLog ("ERROR during {0}: {1}`n{2}" -f $Action,$message,$ErrorRecord.ScriptStackTrace)
  Show-Error (L "$Action failed:`n`n$message`n`nFull details were saved to Workspace\Logs\PalModMerger.log" "$Action fallo:`n`n$message`n`nEl detalle completo se guardo en Workspace\Logs\PalModMerger.log")
  try{
    $cfg=Get-PMMConfig;$create=$true;try{$create=[bool]$cfg.AIIOAutoCreateErrorCases}catch{}
    if($create){
      $case=New-PMMDiagnosticCase -Type PMM_ERROR -Title $Action -UserDescription ($Action+': '+$message)
      Refresh-PMMAIHelpUi;$Script:LstAIHelpDiagnostics.SelectedValue=[string]$case.CaseId
      $Script:MainTabs.SelectedItem=$Script:TabAIHelp;$Script:AIHelpTabs.SelectedIndex=0
      $Script:TxtAIHelpDiagnosticStatus.Text=((L 'PMM created local diagnostic case {0} for this error. Review it here or prepare it for an AI.' 'PMM creo el caso de diagnostico local {0} para este error. Revisalo aqui o preparalo para una IA.') -f [string]$case.CaseId)
    }
  }catch{Write-PMMLog ('Could not route the error into AI & Help: '+$_.Exception.Message)}
  try { Refresh-UI } catch { Write-PMMLog ("Secondary UI refresh failure after {0}: {1}" -f $Action,$_.Exception.Message) }
}

function Select-PMMSteamFolderInteractive {
  Add-Type -AssemblyName System.Windows.Forms
  $dialog=New-Object System.Windows.Forms.FolderBrowserDialog
  $dialog.Description=L 'Select a Steam installation or Steam library. PMM will inspect steamapps and registered Steam libraries.' 'Selecciona una instalacion o biblioteca de Steam. PMM revisara steamapps y las bibliotecas registradas de Steam.'
  if($dialog.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK){return $false}
  $paths=@(Get-PalworldInstallationsFromSteamRoot $dialog.SelectedPath)
  $selected=Select-PalworldInstallation $paths
  if(-not$selected){
    if($paths.Count -eq 0){throw (L 'No valid Palworld installation was found from the selected Steam folder.' 'No se encontro una instalacion valida de Palworld desde la carpeta de Steam seleccionada.')}
    return $false
  }
  $cfg=Get-PMMConfig
  if(-not($cfg.PSObject.Properties.Name -contains 'SteamRoot')){$cfg|Add-Member -NotePropertyName SteamRoot -NotePropertyValue ''}
  $cfg.SteamRoot=[IO.Path]::GetFullPath($dialog.SelectedPath)
  Save-PMMConfig $cfg
  Set-PMMGamePath $selected
  Refresh-UI
  return $true
}

function Select-PMMPalworldFolderInteractive {
  Add-Type -AssemblyName System.Windows.Forms
  $dialog=New-Object System.Windows.Forms.FolderBrowserDialog
  $dialog.Description=L 'Select the Palworld folder, Pal\Content\Paks, or a nearby subfolder. PMM will resolve the actual game root.' 'Selecciona la carpeta de Palworld, Pal\Content\Paks o una subcarpeta cercana. PMM encontrara la raiz real del juego.'
  if($dialog.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK){return $false}
  Set-PMMGamePath $dialog.SelectedPath
  Refresh-UI
  return $true
}

function Show-PMMGameDetectionFallback {
  Add-Type -AssemblyName System.Windows.Forms
  Add-Type -AssemblyName System.Drawing
  $form=New-Object System.Windows.Forms.Form
  $form.Text=L 'Palworld location required' 'Se necesita la ubicacion de Palworld'
  $form.Width=560;$form.Height=235;$form.StartPosition='CenterParent';$form.FormBorderStyle='FixedDialog';$form.MaximizeBox=$false;$form.MinimizeBox=$false
  $label=New-Object System.Windows.Forms.Label
  $label.Left=18;$label.Top=18;$label.Width=510;$label.Height=68
  $label.Text=L 'Palworld could not be detected automatically. Choose the Steam folder or the Palworld folder itself.' 'Palworld no pudo detectarse automaticamente. Elige la carpeta de Steam o la propia carpeta de Palworld.'
  $steam=New-Object System.Windows.Forms.Button;$steam.Text=L 'Choose Steam folder' 'Elegir carpeta de Steam';$steam.Left=18;$steam.Top=108;$steam.Width=165;$steam.Height=34
  $game=New-Object System.Windows.Forms.Button;$game.Text=L 'Choose Palworld folder' 'Elegir carpeta de Palworld';$game.Left=194;$game.Top=108;$game.Width=175;$game.Height=34
  $cancel=New-Object System.Windows.Forms.Button;$cancel.Text=L 'Cancel' 'Cancelar';$cancel.Left=380;$cancel.Top=108;$cancel.Width=145;$cancel.Height=34
  $steam.Add_Click({$form.Tag='Steam';$form.Close()})
  $game.Add_Click({$form.Tag='Palworld';$form.Close()})
  $cancel.Add_Click({$form.Tag='Cancel';$form.Close()})
  $form.Controls.AddRange(@($label,$steam,$game,$cancel));$form.CancelButton=$cancel
  [void]$form.ShowDialog()
  return [string]$form.Tag
}

function Invoke-PMMGameDetection([bool]$ShowNotFound=$true) {
  $Script:TxtStatus.Text=L 'Detecting Steam libraries and Palworld installations...' 'Detectando bibliotecas de Steam e instalaciones de Palworld...'
  try{[System.Windows.Forms.Application]::DoEvents()}catch{}
  $paths=@(Find-PalworldInstallations)
  $selected=Select-PalworldInstallation $paths
  if($selected){Set-PMMGamePath $selected;Refresh-UI;return $true}
  if($ShowNotFound){
    $choice=Show-PMMGameDetectionFallback
    switch($choice){
      'Steam' {return [bool](Select-PMMSteamFolderInteractive)}
      'Palworld' {return [bool](Select-PMMPalworldFolderInteractive)}
    }
  }
  Refresh-UI
  return $false
}

function Save-UiSettings {
  $cfg = Get-PMMConfig
  $cfg.CloseGameBeforeDeploy = [bool]$Script:ChkCloseGame.IsChecked
  $cfg.ForceCloseOnTimeout = [bool]$Script:ChkForceClose.IsChecked
  $cfg.MergeMode = 'ConflictGroups'
  $cfg.AutoMode = [bool]$Script:TglAutoMode.IsChecked
  $cfg.AutoIncludePlay = [bool]$Script:ChkAutoPlay.IsChecked
  $hintValue=5
  try{$hintValue=[int]$Script:CmbActionHintDuration.SelectedValue}catch{$hintValue=5}
  if(-($hintValue -eq -1 -or ($hintValue -ge 0 -and $hintValue -le 120))){$hintValue=5}
  $cfg.ActionHintSeconds=$hintValue
  try{$cfg.Theme=[string](Get-PMMSelectedThemeId)}catch{$cfg.Theme='pmm-crystal'}
  foreach($profile in @('Auto','SemiAuto','Manual','Attention','Error')){$prop=Get-PMMSoundProfileConfigProperty $profile;$value=Get-PMMPendingSoundId $profile;if(-not($cfg.PSObject.Properties.Name -contains $prop)){$cfg|Add-Member -NotePropertyName $prop -NotePropertyValue $value}else{$cfg.$prop=$value}}
  if(-not($cfg.PSObject.Properties.Name -contains 'SoundSemiAutoEnabled')){$cfg|Add-Member -NotePropertyName SoundSemiAutoEnabled -NotePropertyValue ([bool]$Script:ChkSoundEachAutoStep.IsChecked)}else{$cfg.SoundSemiAutoEnabled=[bool]$Script:ChkSoundEachAutoStep.IsChecked}
  if(-not($cfg.PSObject.Properties.Name -contains 'SoundAttentionEnabled')){$cfg|Add-Member -NotePropertyName SoundAttentionEnabled -NotePropertyValue ([bool]$Script:ChkSoundAttention.IsChecked)}else{$cfg.SoundAttentionEnabled=[bool]$Script:ChkSoundAttention.IsChecked}
  # Retain legacy fields for downgrade compatibility; Auto is the closest old equivalent.
  $cfg.CompletionSound=Get-PMMPendingSoundId 'Auto'
  try{$cfg.CompletionVolume=[int][Math]::Round([double]$Script:SldCompletionVolume.Value)}catch{}
  Save-PMMConfig $cfg
  Save-PMMLayoutSettings
}

function Run-Analyze {
  param([switch]$Force)
  Set-PMMAnalyzeBusy $true
  $Script:TxtStatus.Text = L 'Analyzing shared assets against vanilla...' 'Analizando assets compartidos contra vanilla...'
  try {
    $result = Invoke-PMMScan -Force:$Force
    Refresh-PMMAnalysisWorkspace
    Refresh-ConflictWorkspace
    $Script:TxtLog.Text = Get-PMMRecentLog
    $Script:TxtStatus.Text = Get-PMMStatusLine
    return $result
  } finally {
    Set-PMMAnalyzeBusy $false
  }
}

# ---------------------------------------------------------------------------
# Game location / launch controls.
# ---------------------------------------------------------------------------
$detectHandler={try{$ok=[bool](Invoke-PMMGameDetection $true);if($ok -and [bool]$Script:TglAutoMode.IsChecked){Start-PMMAutoPipeline;Invoke-PMMAutoContinue};if($ok){Notify-PMMWorkflowStepComplete}}catch{Handle-UIError $_ (L 'Palworld detection' 'Deteccion de Palworld')}}
$Script:BtnDetectGame.Add_Click($detectHandler)
$Script:BtnDetectGameSettings.Add_Click($detectHandler)

$Script:BtnBrowseGame.Add_Click({try{[void](Select-PMMSteamFolderInteractive)}catch{Handle-UIError $_ (L 'Steam location selection' 'Seleccion de Steam')}})
$Script:BtnBrowseGameManual.Add_Click({try{[void](Select-PMMPalworldFolderInteractive)}catch{Handle-UIError $_ (L 'Manual Palworld location selection' 'Seleccion manual de Palworld')}})

$openGameHandler={
  try{
    $path=(Get-PMMConfig).GamePath
    if(-not$path){throw (L 'Detect or configure Palworld first.' 'Detecta o configura Palworld primero.')}
    Start-Process explorer.exe -ArgumentList ('"'+$path+'"')
  }catch{Handle-UIError $_ (L 'Open game folder' 'Abrir carpeta del juego')}
}
$Script:BtnOpenGame.Add_Click($openGameHandler)
$Script:BtnOpenGameSettings.Add_Click($openGameHandler)

$openModsHandler={
  try{
    $path=Get-GameModsPath
    if(-not$path){throw (L 'Detect or configure Palworld first.' 'Detecta o configura Palworld primero.')}
    Ensure-GameModsFolder
    Start-Process explorer.exe -ArgumentList ('"'+$path+'"')
  }catch{Handle-UIError $_ (L 'Open mods folder' 'Abrir carpeta de mods')}
}
$Script:BtnOpenModsFolder.Add_Click($openModsHandler)
$Script:BtnOpenModsSettings.Add_Click($openModsHandler)

$Script:BtnOpenLibrary.Add_Click({try{Start-Process explorer.exe -ArgumentList ('"'+(Get-PMMPath 'Mods')+'"')}catch{Handle-UIError $_ (L 'Open library' 'Abrir biblioteca')}})
$Script:BtnPlay.Add_Click({try{Start-Palworld}catch{Handle-UIError $_ (L 'Start Palworld' 'Iniciar Palworld')}})

$Script:TglAutoMode.Add_Click({
  try{
    $enabled=[bool]$Script:TglAutoMode.IsChecked;Save-UiSettings
    if(-not$enabled){Stop-PMMAutoPipeline (L 'Auto ON is disabled. Manual actions perform one workflow step per click.' 'Auto ON esta desactivado. Las acciones manuales hacen un paso del flujo por clic.')}
    else{$Script:TxtStatus.Text=L 'Auto ON armed. The next workflow action you start manually will continue through the remaining safe steps.' 'Auto ON preparado. La siguiente accion del flujo que inicies manualmente continuara por los pasos seguros restantes.';Update-PMMCancelButtonState}
  }catch{Handle-UIError $_ (L 'Automatic mode' 'Modo automatico')}
})
$Script:ChkAutoPlay.Add_Click({try{Save-UiSettings;Update-PMMGuidedActionState}catch{}})
$Script:BtnAutoRun.Add_Click({
  try{
    Start-PMMAutoPipeline -OneShot
    if($Script:AutoPipelineActive){
      $Script:TxtStatus.Text=L 'AUTO started from the current workflow state.' 'AUTO iniciado desde el estado actual del flujo.'
      [void](Ensure-PMMAutoFixLabGameReference)
      Invoke-PMMAutoContinue
    }
  }
  catch{Stop-PMMAutoPipeline;Handle-UIError $_ (L 'AUTO workflow' 'Flujo AUTO')}
})
$Script:CmbActionHintDuration.Add_SelectionChanged({try{if(-not $Script:UiSettingsRefreshing -and $Script:CmbActionHintDuration.SelectedItem){$Script:TxtStatus.Text=L 'Settings changed. Press Apply changes.' 'Ajustes modificados. Pulsa Aplicar cambios.'}}catch{}})
$Script:SldCompletionVolume.Add_ValueChanged({
  try{$v=[Math]::Max(0,[Math]::Min(100,[int][Math]::Round([double]$Script:SldCompletionVolume.Value)));$Script:TxtCompletionVolume.Text=($v.ToString()+'%');if(-not $Script:UiSettingsRefreshing){$Script:TxtStatus.Text=L 'Settings changed. Press Apply changes.' 'Ajustes modificados. Pulsa Aplicar cambios.'}}catch{}
})
$Script:BtnApplySettings.Add_Click({
  try{
    Save-UiSettings
    Apply-PMMTheme (Get-PMMSelectedThemeId)
    $Script:ThemePreviewActive=$false
    Close-PMMRequiredActionPopup;$Script:RequiredActionSignature='';Update-PMMGuidedActionState
    $Script:TxtStatus.Text=L 'Settings applied.' 'Ajustes aplicados.'
  }catch{Handle-UIError $_ (L 'Apply settings' 'Aplicar ajustes')}
})
$Script:BtnRestoreDefaults.Add_Click({
  try{
    $priorRefreshing=[bool]$Script:UiSettingsRefreshing
    $Script:UiSettingsRefreshing=$true
    try{
      Set-PMMSelectedThemeId 'pmm-crystal'
      $Script:CmbActionHintDuration.SelectedValue=5
      $Script:SldCompletionVolume.Value=50
      $Script:TxtCompletionVolume.Text='50%'
      $Script:PendingSoundSelections=@{
        Auto='Microwave'
        SemiAuto='Ok'
        Manual='Good'
        Attention='Alert'
        Error='Microwave3'
      }
      $Script:ChkSoundEachAutoStep.IsChecked=$true
      $Script:ChkSoundAttention.IsChecked=$true
      Refresh-PMMSoundProfileUi (Get-PMMCurrentSoundProfileId)
    } finally {
      $Script:UiSettingsRefreshing=$priorRefreshing
    }
    $Script:TxtStatus.Text=L 'Defaults restored in Settings. Press Apply changes to save them.' 'Valores restaurados en Opciones. Pulsa Aplicar cambios para guardarlos.'
  }catch{Handle-UIError $_ (L 'Restore defaults' 'Restaurar valores')}
})
$Script:BtnImportTheme.Add_Click({
  try{
    $dlg=[Microsoft.Win32.OpenFileDialog]::new();$dlg.Title=L 'Add PMM color schemes' 'Agregar esquemas de color PMM';$dlg.Filter='PMM schemes (*.json;*.zip)|*.json;*.zip|JSON schemes (*.json)|*.json|PMM scheme packs (*.zip)|*.zip';$dlg.Multiselect=$true
    if($dlg.ShowDialog() -ne $true){return}
    $result=Import-PMMThemeInputs -Paths @($dlg.FileNames)
    if(@($result.Conflicts).Count -gt 0){
      $question=(L 'Replace the existing user scheme(s)? PMM will create backups first:' '¿Reemplazar los esquemas del usuario existentes? PMM creara copias antes:')+[Environment]::NewLine+(@($result.Conflicts)-join ', ')
      if(Confirm $question){$result=Import-PMMThemeInputs -Paths @($dlg.FileNames) -AllowReplace}
    }
    if(-not[bool]$result.Success){
      $details=@(@($result.Errors)+@($result.Conflicts|ForEach-Object{(L 'Replacement not confirmed: ' 'Reemplazo no confirmado: ')+[string]$_})) -join [Environment]::NewLine
      throw $details
    }
    $selected=Get-PMMSelectedThemeId
    if(@($result.Imported).Count -gt 0){$selected=[string](@($result.Imported)[-1])}
    Refresh-PMMThemeOptions $selected
    $Script:TxtStatus.Text=((L 'Theme import complete: {0} installed, {1} already available, {2} warning(s). Press Apply changes to use the selected scheme.' 'Importacion de temas terminada: {0} instalados, {1} ya disponibles, {2} aviso(s). Pulsa Aplicar cambios para usar el esquema seleccionado.') -f @($result.Imported).Count,@($result.Skipped).Count,@($result.Warnings).Count)
  }catch{Handle-UIError $_ (L 'Add color scheme' 'Agregar esquema de color')}
})
$Script:BtnOpenThemesFolder.Add_Click({try{Start-Process explorer.exe -ArgumentList ('"'+(Get-PMMThemeStore)+'"')}catch{Handle-UIError $_ (L 'Open themes folder' 'Abrir carpeta de temas')}})
$Script:CmbSoundEventProfile.Add_SelectionChanged({try{if(-not$Script:UiSettingsRefreshing -and $Script:CmbSoundEventProfile.SelectedValue){Refresh-PMMSoundProfileUi ([string]$Script:CmbSoundEventProfile.SelectedValue)}}catch{}})
$builtinSoundHandler={
  param($sender,$e)
  if($Script:UiSettingsRefreshing -or -not[bool]$sender.IsChecked){return}
  try{Set-PMMPendingSoundId ([string]$sender.Tag);Refresh-PMMCustomSoundOptions ''}catch{}
}
foreach($rb in @($Script:RdoSoundNone,$Script:RdoSoundBell,$Script:RdoSoundMicrowave,$Script:RdoSoundMicrowave3,$Script:RdoSoundOk,$Script:RdoSoundGood,$Script:RdoSoundCrystal,$Script:RdoSoundAlert)){if($rb){$rb.Add_Checked($builtinSoundHandler)}}
$Script:RdoSoundCustom.Add_Checked({
  if($Script:UiSettingsRefreshing -or -not[bool]$Script:RdoSoundCustom.IsChecked){return}
  try{
    $selected=Get-PMMSelectedCustomSoundId
    if([string]::IsNullOrWhiteSpace($selected)){
      $custom=@(Get-PMMCustomSoundDefinitions)
      if($custom.Count -gt 0){$selected=[string]$custom[0].Id;Refresh-PMMCustomSoundOptions $selected}
    }
    if(-not[string]::IsNullOrWhiteSpace($selected)){Set-PMMPendingSoundId $selected}
  }catch{}
})
$Script:ChkSoundEachAutoStep.Add_Click({if(-not$Script:UiSettingsRefreshing){$Script:TxtStatus.Text=L 'Sound settings changed. Press Apply changes.' 'Los sonidos han cambiado. Pulsa Aplicar cambios.'}})
$Script:ChkSoundAttention.Add_Click({if(-not$Script:UiSettingsRefreshing){$Script:TxtStatus.Text=L 'Sound settings changed. Press Apply changes.' 'Los sonidos han cambiado. Pulsa Aplicar cambios.'}})
$Script:BtnImportSound.Add_Click({
  try{
    $dlg=[Microsoft.Win32.OpenFileDialog]::new();$dlg.Title=L 'Add reusable PMM sound' 'Agregar sonido reutilizable de PMM';$dlg.Filter='Audio files (*.wav;*.mp3;*.wma)|*.wav;*.mp3;*.wma'
    if($dlg.ShowDialog() -ne $true){return}
    $dest=Join-Path (Get-PMMSoundStore) ([IO.Path]::GetFileName([string]$dlg.FileName));Copy-Item -LiteralPath ([string]$dlg.FileName) -Destination $dest -Force
    $id='file:'+[IO.Path]::GetFileName($dest);Set-PMMPendingSoundId $id;Refresh-PMMSoundProfileUi (Get-PMMCurrentSoundProfileId)
    $Script:TxtStatus.Text=L 'Custom sound added and selected for the current sound event. Press Apply changes.' 'Sonido custom agregado y seleccionado para el evento actual. Pulsa Aplicar cambios.'
  }catch{Handle-UIError $_ (L 'Add sound' 'Agregar sonido')}
})
$Script:BtnOpenSoundsFolder.Add_Click({try{Start-Process explorer.exe -ArgumentList ('"'+(Get-PMMSoundStore)+'"')}catch{Handle-UIError $_ (L 'Open sounds folder' 'Abrir carpeta de sonidos')}})
$Script:BtnTestCompletionSound.Add_Click({
  try{
    $id=Get-PMMPendingSoundId (Get-PMMCurrentSoundProfileId)
    $volume=[Math]::Max(0,[Math]::Min(100,[int][Math]::Round([double]$Script:SldCompletionVolume.Value)));Play-PMMSoundId $id $volume
  }catch{Handle-UIError $_ (L 'Test sound' 'Probar sonido')}
})

$Script:BtnCancelOperation.Add_Click({
  try{
    $operation=if($Script:ImportBusy){'Import'}elseif($Script:AnalyzeBusy){'Analyze'}elseif($Script:BuildBusy){'Build'}elseif($Script:DeployBusy){'Deploy'}elseif($Script:FixLabOperationBusy){'FixLab'}elseif($Script:AIIOBusy){'AIIO'}elseif($Script:AutoPipelineActive){'Auto'}else{'Operation'}
    $Script:CancelRequested=$true
    Stop-PMMAutoPipeline
    $hadBackground=$false
    try{$hadBackground=($Script:BackgroundOperationProcess -and -not$Script:BackgroundOperationProcess.HasExited)}catch{}
    if($hadBackground){Stop-PMMBackgroundOperation -Silent}
    try{if($Script:GameReferenceProcess -and -not$Script:GameReferenceProcess.HasExited){Stop-PMMGameReferenceBuild -Silent}}catch{}
    $msg=L 'Cancellation requested. PMM will stop at the nearest safe checkpoint; Deploy rolls back if commit already started.' 'Cancelacion solicitada. PMM se detendra en el punto seguro mas cercano; Deploy hace rollback si el commit ya habia empezado.'
    $Script:TxtStatus.Text=$msg
    try{$Script:TxtOperationProgress.Text=$msg}catch{}
    if($hadBackground){Set-PMMOperationResult $operation (L 'Operation cancelled.' 'Operacion cancelada.')}
    Update-PMMCancelButtonState
  }catch{Handle-UIError $_ (L 'Cancel operation' 'Cancelar operacion')}
})

# ---------------------------------------------------------------------------
# Library / Analyze / conflict editing / Build.
# ---------------------------------------------------------------------------
$Script:ExpAnalysis.Add_Expanded({try{Update-PMMWorkspaceRows}catch{}})
$Script:ExpAnalysis.Add_Collapsed({try{Update-PMMWorkspaceRows}catch{}})
$Script:ExpConflicts.Add_Expanded({try{Update-PMMWorkspaceRows}catch{}})
$Script:ExpConflicts.Add_Collapsed({try{Update-PMMWorkspaceRows}catch{}})
$Script:SplAnalysisResolution.Add_DragCompleted({
  try{
    if($Script:ExpAnalysis.IsExpanded -and $Script:ExpConflicts.IsExpanded){
      if($Script:RowAnalysisWorkspace.ActualHeight -gt 100){$Script:SavedAnalysisHeight=[double]$Script:RowAnalysisWorkspace.ActualHeight}
      if($Script:RowResolutionWorkspace.ActualHeight -gt 100){$Script:SavedResolutionHeight=[double]$Script:RowResolutionWorkspace.ActualHeight}
    }
  }catch{}
})
function Invoke-PMMImportBatch {
  param(
    [Parameter(Mandatory=$true)][string[]]$Files,
    [switch]$FolderMode
  )
  if(-not(Request-PMMProcessingSlot 'Import')){return}
  $files=@($Files|Where-Object{$_ -and (Test-Path -LiteralPath $_ -PathType Leaf)})
  if($files.Count -eq 0){
    $Script:TxtStatus.Text=L 'No supported mod files were selected.' 'No se seleccionaron archivos de mod compatibles.'
    return
  }

  $busy=$false
  $importSucceeded=$false
  $importedInputs=0
  $failed=[System.Collections.Generic.List[string]]::new()
  Reset-PMMOperationCancellation
  if([bool]$Script:TglAutoMode.IsChecked){Start-PMMAutoPipeline}
  try{
    Set-PMMImportBusy $Script:BtnImport $true;$busy=$true
    for($i=0;$i -lt $files.Count;$i++){
      $base=[double]$i/[double]$files.Count
      $span=1.0/[double]$files.Count
      $file=[string]$files[$i]
      $cb={
        param([double]$fraction,[string]$message)
        Set-PMMImportProgress $Script:BtnImport ($base+($span*$fraction)) $message
      }.GetNewClosure()
      try{
        Import-PMMMod $file $cb
        $importedInputs++
      }catch{
        if(Test-PMMCancellationError $_){throw}
        $failed.Add(([IO.Path]::GetFileName($file)+': '+$_.Exception.Message))
        Write-PMMLog ('Import skipped/failed for '+$file+': '+$_.Exception.Message)
        # Folder import is intentionally tolerant: a downloads folder can
        # contain archives unrelated to PMM. Explicit multi-file import also
        # continues so one bad archive does not discard the other selections.
      }
    }
    if($failed.Count -gt 0){
      $msg=((L 'Import finished: {0} selected item(s) imported, {1} skipped/failed. See the log for details.' 'Importacion terminada: {0} elemento(s) seleccionado(s) importados, {1} omitidos/con fallo. Consulta el log para detalles.') -f $importedInputs,$failed.Count)
      Set-PMMOperationFailure 'Import' $msg
      Stop-PMMAutoPipeline (L 'Auto paused because one or more imports failed.' 'Auto pausado porque una o mas importaciones fallaron.')
    }else{
      Set-PMMImportProgress $Script:BtnImport 1.0 ((L 'Import complete: {0} selected item(s).' 'Importacion terminada: {0} elemento(s) seleccionado(s).') -f $importedInputs)
      $importSucceeded=$true
    }
  }catch{
    if(Test-PMMCancellationError $_){
      Set-PMMOperationResult 'Import' (L 'Import cancelled.' 'Importacion cancelada.')
      Stop-PMMAutoPipeline
    }else{throw}
  }finally{
    if($busy){Refresh-UI;Check-PMMExternalModChanges -Force;Set-PMMImportBusy $Script:BtnImport $false;try{Update-PMMFixLabAttentionFromLibrary 'Import'}catch{};try{Update-PMMGuidedActionState}catch{};if($importSucceeded){Notify-PMMWorkflowStepComplete};if($Script:AutoPipelineActive){Invoke-PMMAutoContinue}}
  }
}

function Test-PMMFolderImportCandidate([System.IO.FileInfo]$File) {
  if(-not$File){return $false}
  $ext=$File.Extension.ToLowerInvariant()
  if($ext -eq '.pak'){return $true}
  if($ext -eq '.zip'){
    try{
      Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction SilentlyContinue
      $zip=[System.IO.Compression.ZipFile]::OpenRead($File.FullName)
      try{return (@($zip.Entries|Where-Object{([string]$_.FullName).ToLowerInvariant().EndsWith('.pak')}).Count -gt 0)}finally{$zip.Dispose()}
    }catch{
      Write-PMMLog ('Folder import skipped unreadable ZIP '+$File.FullName+': '+$_.Exception.Message)
      return $false
    }
  }
  return ($ext -in @('.7z','.rar'))
}

function Get-PMMFolderImportFiles([string]$Folder) {
  if([string]::IsNullOrWhiteSpace($Folder) -or -not(Test-Path -LiteralPath $Folder -PathType Container)){return @()}
  $supported=@('.pak','.zip','.7z','.rar')
  return @(Get-ChildItem -LiteralPath $Folder -File -ErrorAction Stop |
    Where-Object{($supported -contains $_.Extension.ToLowerInvariant()) -and (Test-PMMFolderImportCandidate $_)} |
    Sort-Object Name | ForEach-Object{$_.FullName})
}

function Show-PMMImportWindow {
  $dialog=[System.Windows.Window]::new()
  $dialog.Title=L 'Import mods' 'Importar mods'
  $dialog.Width=560;$dialog.Height=245;$dialog.ResizeMode=[System.Windows.ResizeMode]::NoResize
  $dialog.WindowStartupLocation=[System.Windows.WindowStartupLocation]::CenterOwner
  $dialog.Owner=$Window;$dialog.ShowInTaskbar=$false
  try{$dialog.Icon=$Window.Icon}catch{}

  $grid=[System.Windows.Controls.Grid]::new();$grid.Margin=[System.Windows.Thickness]::new(16)
  foreach($height in @('Auto','*','Auto')){
    $row=[System.Windows.Controls.RowDefinition]::new()
    $row.Height=if($height -eq '*'){[System.Windows.GridLength]::new(1,[System.Windows.GridUnitType]::Star)}else{[System.Windows.GridLength]::Auto}
    [void]$grid.RowDefinitions.Add($row)
  }

  $info=[System.Windows.Controls.TextBlock]::new()
  $info.Text=L 'Choose individual mod files or a folder containing mods. ZIP/7Z/RAR files are only containers: PMM extracts their PAK files and stores only the PAKs in the mod library.' 'Elige archivos de mod individuales o una carpeta que contenga mods. Los ZIP/7Z/RAR son solo contenedores: PMM extrae sus PAK y guarda unicamente los PAK en la biblioteca.'
  $info.TextWrapping=[System.Windows.TextWrapping]::Wrap;$info.Margin=[System.Windows.Thickness]::new(0,0,0,12)
  [System.Windows.Controls.Grid]::SetRow($info,0);[void]$grid.Children.Add($info)

  $status=[System.Windows.Controls.TextBlock]::new()
  $status.Text=L 'Import folder or mods' 'Importar carpeta o mods'
  $status.HorizontalAlignment=[System.Windows.HorizontalAlignment]::Center
  $status.VerticalAlignment=[System.Windows.VerticalAlignment]::Center
  $status.FontSize=14;$status.FontWeight=[System.Windows.FontWeights]::SemiBold
  $status.Foreground=[System.Windows.Media.Brushes]::DimGray
  $status.TextWrapping=[System.Windows.TextWrapping]::Wrap
  [System.Windows.Controls.Grid]::SetRow($status,1);[void]$grid.Children.Add($status)

  $buttons=[System.Windows.Controls.WrapPanel]::new();$buttons.HorizontalAlignment=[System.Windows.HorizontalAlignment]::Center;$buttons.Margin=[System.Windows.Thickness]::new(0,12,0,0)
  $btnMods=[System.Windows.Controls.Button]::new();$btnMods.Content=L 'Import mods...' 'Importar mods...';$btnMods.MinWidth=145;$btnMods.Padding=[System.Windows.Thickness]::new(14,7,14,7);$btnMods.Margin=[System.Windows.Thickness]::new(0,0,8,0)
  $btnFolder=[System.Windows.Controls.Button]::new();$btnFolder.Content=L 'Import folder...' 'Importar carpeta...';$btnFolder.MinWidth=145;$btnFolder.Padding=[System.Windows.Thickness]::new(14,7,14,7);$btnFolder.Margin=[System.Windows.Thickness]::new(0,0,8,0)
  $btnCancel=[System.Windows.Controls.Button]::new();$btnCancel.Content=L 'Cancel' 'Cancelar';$btnCancel.MinWidth=90;$btnCancel.Padding=[System.Windows.Thickness]::new(12,7,12,7)
  [void]$buttons.Children.Add($btnMods);[void]$buttons.Children.Add($btnFolder);[void]$buttons.Children.Add($btnCancel)
  [System.Windows.Controls.Grid]::SetRow($buttons,2);[void]$grid.Children.Add($buttons)

  $selected=[System.Collections.Generic.List[string]]::new()
  $btnMods.Add_Click({
    $pick=New-Object System.Windows.Forms.OpenFileDialog
    $pick.Multiselect=$true
    $pick.Filter=L 'Mods (*.pak;*.zip;*.7z;*.rar)|*.pak;*.zip;*.7z;*.rar|All files (*.*)|*.*' 'Mods (*.pak;*.zip;*.7z;*.rar)|*.pak;*.zip;*.7z;*.rar|Todos (*.*)|*.*'
    if($pick.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK){
      foreach($path in @($pick.FileNames)){if(-not[string]::IsNullOrWhiteSpace($path)){$selected.Add([IO.Path]::GetFullPath($path))}}
      if($selected.Count -gt 0){$dialog.DialogResult=$true;$dialog.Close()}
    }
  }.GetNewClosure())
  $btnFolder.Add_Click({
    $pick=New-Object System.Windows.Forms.FolderBrowserDialog
    $pick.Description=L 'Choose a folder containing PAK/ZIP/7Z/RAR mod files. PMM extracts archives and imports only their PAK files.' 'Elige una carpeta con mods PAK/ZIP/7Z/RAR. PMM extrae los comprimidos e importa solo sus PAK.'
    if($pick.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK){
      $found=@(Get-PMMFolderImportFiles $pick.SelectedPath)
      if($found.Count -eq 0){
        $status.Text=L 'The selected folder contains no supported mod files.' 'La carpeta seleccionada no contiene archivos de mod compatibles.'
        $status.Foreground=[System.Windows.Media.Brushes]::DarkOrange
      }else{
        foreach($path in $found){$selected.Add([IO.Path]::GetFullPath([string]$path))}
        $dialog.DialogResult=$true;$dialog.Close()
      }
    }
  }.GetNewClosure())
  $btnCancel.Add_Click({$dialog.DialogResult=$false;$dialog.Close()})

  $dialog.Content=$grid
  $ok=$dialog.ShowDialog()
  if($ok -eq $true -and $selected.Count -gt 0){Invoke-PMMImportBatch -Files @($selected.ToArray())}
}

$Script:BtnImport.Add_Click({
  try{Show-PMMImportWindow}catch{Handle-UIError $_ (L 'Mod import' 'Importacion de mod')}
})

$Script:BtnImportGameMods.Add_Click({
  if(-not(Request-PMMProcessingSlot 'Import')){return}
  $busy=$false
  $importSucceeded=$false
  Reset-PMMOperationCancellation
  if([bool]$Script:TglAutoMode.IsChecked){Start-PMMAutoPipeline}
  try{
    Set-PMMImportBusy $Script:BtnImportGameMods $true;$busy=$true
    $cb={param([double]$fraction,[string]$message) Set-PMMImportProgress $Script:BtnImportGameMods $fraction $message}.GetNewClosure()
    $count=Import-GameModsToLibrary $cb
    Set-PMMImportProgress $Script:BtnImportGameMods 1.0 ((L 'Import complete: {0} PAK(s) imported/updated.' 'Importacion terminada: {0} PAK importados/actualizados.') -f $count)
    $importSucceeded=$true
  }catch{
    if(Test-PMMCancellationError $_){Set-PMMOperationResult 'Import' (L 'Import cancelled.' 'Importacion cancelada.');Stop-PMMAutoPipeline}
    else{Stop-PMMAutoPipeline;Handle-UIError $_ (L 'Import game ~mods' 'Importacion de ~mods')}
  }
  finally{
    if($busy){Refresh-UI;Check-PMMExternalModChanges -Force;Set-PMMImportBusy $Script:BtnImportGameMods $false;try{Update-PMMFixLabAttentionFromLibrary 'Import'}catch{};try{Update-PMMGuidedActionState}catch{};if($importSucceeded){Notify-PMMWorkflowStepComplete};if($Script:AutoPipelineActive){Invoke-PMMAutoContinue}}
  }
})
# Manual and automatic guidance share Get-PMMWorkflowState; no separate Analyze/Fix Lab router.
$Script:BtnScan.Add_Click({
  try{
    Reset-PMMOperationCancellation
    if([bool]$Script:TglAutoMode.IsChecked){Start-PMMAutoPipeline}
    Save-DecisionGridToPlan -Silent
    $done={
      param($result)
      Refresh-UI
      $Script:TxtLog.Text=Get-PMMRecentLog
      $Script:TxtStatus.Text=Get-PMMStatusLine
      try{Update-PMMFixLabAttentionFromLibrary 'Analyze'}catch{}
      if(-not$Script:AutoPipelineActive){Prompt-PMMAIHandoffAfterAnalyze}
    }
    $failed={param($message) Stop-PMMAutoPipeline;Show-Error ([string]$message)}
    [void](Start-PMMBackgroundOperation -Operation Analyze -OnSuccess $done -OnFailure $failed)
  }catch{Stop-PMMAutoPipeline;Handle-UIError $_ (L 'Analyze' 'Analizar')}
})
$Script:TxtModFilter.Add_TextChanged({try{Apply-PMMLibraryFilter}catch{}})
$Script:LstMods.Add_SelectionChanged({try{Update-PMMLibraryButtons}catch{}})
$Script:BtnReorderLibrary.Add_Click({
  try{
    $mode=[string]$Script:CmbLibraryOrder.SelectedValue;if([string]::IsNullOrWhiteSpace($mode)){$mode='Alphabetical'}
    [void](Set-PMMLibraryOrderBy $mode);Clear-PMMAnalysisState;Refresh-UI
    $Script:TxtStatus.Text=((L 'Mod library reordered: {0}. Analyze is required again.' 'Biblioteca de mods reordenada: {0}. Es necesario volver a Analyze.') -f $mode)
    Update-PMMGuidedActionState
  }catch{Handle-UIError $_ (L 'Reorder mod library' 'Reordenar biblioteca de mods')}
})

$Script:BtnSelectAllMods.Add_Click({
  try{$Script:LstMods.SelectAll();Update-PMMLibraryButtons}catch{Handle-UIError $_ (L 'Select mods' 'Seleccionar mods')}
})
$Script:BtnClearModSelection.Add_Click({
  try{$Script:LstMods.UnselectAll();Update-PMMLibraryButtons}catch{Handle-UIError $_ (L 'Clear mod selection' 'Limpiar seleccion de mods')}
})
$Script:BtnEnableMods.Add_Click({
  try{
    $entries=@(Get-SelectedPMMLibraryEntries)
    if($entries.Count -eq 0){return}
    foreach($entry in $entries){if(-not[bool]$entry.Enabled){Set-PMMLibraryModEnabled ([string]$entry.Name) $true}}
    Refresh-UI
  }catch{Handle-UIError $_ (L 'Enable selected mods' 'Activar mods seleccionados')}
})
$Script:BtnDisableMods.Add_Click({
  try{
    $entries=@(Get-SelectedPMMLibraryEntries)
    if($entries.Count -eq 0){return}
    foreach($entry in $entries){if([bool]$entry.Enabled){Set-PMMLibraryModEnabled ([string]$entry.Name) $false}}
    Refresh-UI
  }catch{Handle-UIError $_ (L 'Disable selected mods' 'Desactivar mods seleccionados')}
})

# The Order cell is always-live like the decision ComboBox: type a final 1-based
# position and commit by Enter or by leaving the field. The core operation is an
# insertion, so every other mod is shifted and the persisted order remains 1..N.
$priorityLostFocusHandler=[System.Windows.Input.KeyboardFocusChangedEventHandler]{
  param($sender,$e)
  try{
    $editor=Get-PMMUiAncestor $e.OriginalSource ([System.Windows.Controls.TextBox])
    if($editor -and -not[string]::IsNullOrWhiteSpace([string]$editor.Tag)){
      [void](Invoke-PMMPriorityEditorCommit $editor)
    }
  }catch{Handle-UIError $_ (L 'Change mod priority' 'Cambiar prioridad del mod')}
}
$Script:LstMods.AddHandler([System.Windows.Input.Keyboard]::LostKeyboardFocusEvent,$priorityLostFocusHandler,$true)
$Script:LstMods.Add_PreviewKeyDown({
  param($sender,$e)
  $editor=Get-PMMUiAncestor $e.OriginalSource ([System.Windows.Controls.TextBox])
  if(-not$editor -or [string]::IsNullOrWhiteSpace([string]$editor.Tag)){return}
  if($e.Key -eq [System.Windows.Input.Key]::Enter -or $e.Key -eq [System.Windows.Input.Key]::Return){
    try{[void](Invoke-PMMPriorityEditorCommit $editor)}catch{Handle-UIError $_ (L 'Change mod priority' 'Cambiar prioridad del mod')}
    $e.Handled=$true
  }elseif($e.Key -eq [System.Windows.Input.Key]::Escape){
    try{
      $map=Get-PMMModPriorityMap
      if($map.ContainsKey([string]$editor.Tag)){$editor.Text=[string]$map[[string]$editor.Tag]}
      [void]$Script:LstMods.Focus()
    }catch{}
    $e.Handled=$true
  }
})

# Drag any non-interactive part of a source row. Drop on the upper/lower half of
# another row to insert before/after it; dragging near the edges auto-scrolls.
$Script:LstMods.Add_PreviewMouseLeftButtonDown({
  param($sender,$e)
  $Script:PriorityDragStartPoint=$null
  $Script:PriorityDragName=''
  if(Test-PMMPriorityDragInteractiveSource $e.OriginalSource){return}
  $row=Get-PMMUiAncestor $e.OriginalSource ([System.Windows.Controls.DataGridRow])
  if(-not$row -or -not$row.Item -or [string]$row.Item.Kind -ne 'Source'){return}
  $Script:PriorityDragStartPoint=$e.GetPosition($Script:LstMods)
  $Script:PriorityDragName=[string]$row.Item.Name
})
$Script:LstMods.Add_PreviewMouseMove({
  param($sender,$e)
  if($e.LeftButton -ne [System.Windows.Input.MouseButtonState]::Pressed){
    $Script:PriorityDragStartPoint=$null;$Script:PriorityDragName='';return
  }
  if($null -eq $Script:PriorityDragStartPoint -or [string]::IsNullOrWhiteSpace($Script:PriorityDragName)){return}
  $point=$e.GetPosition($Script:LstMods)
  $dx=[Math]::Abs($point.X-$Script:PriorityDragStartPoint.X)
  $dy=[Math]::Abs($point.Y-$Script:PriorityDragStartPoint.Y)
  if($dx -lt [System.Windows.SystemParameters]::MinimumHorizontalDragDistance -and $dy -lt [System.Windows.SystemParameters]::MinimumVerticalDragDistance){return}
  $data=New-Object System.Windows.DataObject
  $data.SetData('PMM.ModPriority',[string]$Script:PriorityDragName)
  try{[void][System.Windows.DragDrop]::DoDragDrop($Script:LstMods,$data,[System.Windows.DragDropEffects]::Move)}finally{
    $Script:PriorityDragStartPoint=$null
    $Script:PriorityDragName=''
  }
})
$Script:LstMods.Add_DragOver({
  param($sender,$e)
  if(-not$e.Data.GetDataPresent('PMM.ModPriority')){$e.Effects=[System.Windows.DragDropEffects]::None;$e.Handled=$true;return}
  $e.Effects=[System.Windows.DragDropEffects]::Move
  $e.Handled=$true
  try{
    if(-not$Script:ModListScrollViewer){$Script:ModListScrollViewer=Get-PMMUiDescendant $Script:LstMods ([System.Windows.Controls.ScrollViewer])}
    if($Script:ModListScrollViewer){
      $p=$e.GetPosition($Script:LstMods)
      if($p.Y -lt 34){$Script:ModListScrollViewer.LineUp()}
      elseif($p.Y -gt ($Script:LstMods.ActualHeight-34)){$Script:ModListScrollViewer.LineDown()}
    }
  }catch{}
})
$Script:LstMods.Add_Drop({
  param($sender,$e)
  if(-not$e.Data.GetDataPresent('PMM.ModPriority')){return}
  $name=[string]$e.Data.GetData('PMM.ModPriority')
  if([string]::IsNullOrWhiteSpace($name)){return}
  if(Get-PMMUiAncestor $e.OriginalSource ([System.Windows.Controls.Primitives.ScrollBar])){return}
  try{
    $map=Get-PMMModPriorityMap
    if(-not$map.ContainsKey($name)){return}
    $sourcePosition=[int]$map[$name]
    $targetRow=Get-PMMUiAncestor $e.OriginalSource ([System.Windows.Controls.DataGridRow])
    [long]$desired=0
    if($targetRow -and $targetRow.Item -and [string]$targetRow.Item.Kind -eq 'Source'){
      $targetName=[string]$targetRow.Item.Name
      if($targetName -ieq $name){return}
      if(-not$map.ContainsKey($targetName)){return}
      $targetPosition=[int]$map[$targetName]
      $rowPoint=$e.GetPosition($targetRow)
      $lowerHalf=($rowPoint.Y -ge ($targetRow.ActualHeight/2.0))
      if($sourcePosition -lt $targetPosition){
        $desired=if($lowerHalf){$targetPosition}else{$targetPosition-1}
      }else{
        $desired=if($lowerHalf){$targetPosition+1}else{$targetPosition}
      }
    }else{
      $gridPoint=$e.GetPosition($Script:LstMods)
      if($gridPoint.Y -lt 34){return}
      $desired=$map.Count
    }
    if(Set-PMMModPriorityPosition $name $desired){Refresh-PMMLibraryAfterPriorityChange $name}
  }catch{Handle-UIError $_ (L 'Change mod priority' 'Cambiar prioridad del mod')}
  $e.Handled=$true
})

$Script:LstMods.AddHandler([System.Windows.Controls.Primitives.ButtonBase]::ClickEvent,[System.Windows.RoutedEventHandler]{
  param($sender,$e)
  $box=$e.OriginalSource
  if($box -is [System.Windows.Controls.CheckBox] -and -not[string]::IsNullOrWhiteSpace([string]$box.Tag)){
    try{
      Set-PMMLibraryModEnabled ([string]$box.Tag) ([bool]$box.IsChecked)
      Refresh-UI
    }catch{Handle-UIError $_ (L 'Enable/disable mod' 'Activar/desactivar mod')}
    $e.Handled=$true
  }
})
$Script:LstPatches.Add_SelectionChanged({
  try{
    Update-PMMPatchActionButtons
    $entry=$Script:LstPatches.SelectedItem
    if($entry -and $entry.Patch -and -not[bool]$entry.Selectable){
      $Script:TxtStatus.Text=L 'This saved merge is not yet proven for the current library. Run Analyze so PMM can compare the effective conflict set, or import the exact original sources.' 'Este merge guardado aun no esta probado para la biblioteca actual. Ejecuta Analizar para que PMM compare el conjunto efectivo de conflictos, o importa las fuentes originales exactas.'
    }
  }catch{Handle-UIError $_ (L 'Select compatibility merge row' 'Seleccionar fila de merge de compatibilidad')}
})
$Script:BtnValidatePatch.Add_Click({
  try{
    $entry=$Script:LstPatches.SelectedItem;if(-not$entry -or -not$entry.Patch){return}
    $summary=Get-PMMBuildValidationSummary $entry.Patch
    if([string]$summary.Status -eq 'NOT_DEPLOYED'){throw (L 'Deploy this exact merge before validating it in Palworld.' 'Despliega este merge exacto antes de validarlo dentro de Palworld.')}
    $result=Show-PMMBuildValidationDialog ([string]$summary.Status);if([string]::IsNullOrWhiteSpace($result) -or $result -eq 'CANCEL'){return}
    $record=New-PMMBuildValidationEvent -Patch $entry.Patch -Result $result
    $Script:TxtStatus.Text=((L 'Local validation recorded: {0}. buildId {1}' 'Validacion local registrada: {0}. buildId {1}') -f [string]$record.Summary.Status,[string]$record.Summary.BuildId)
    Refresh-UI
  }catch{Handle-UIError $_ (L 'Validate merge' 'Validar merge')}
})
$Script:BtnDeletePatch.Add_Click({
  try{
    $entry=$Script:LstPatches.SelectedItem
    if(-not$entry -or -not$entry.Patch){return}
    $name=[string]$entry.Patch.Name
    $question=((L "Delete merge '{0}' completely?`n`nPMM will remove the exact deployed copy from Palworld ~mods if it exists, delete matching saved copies + manifests inside PMM, clear its validation/selection state, and leave all source mods untouched.`n`nA same-name file with a different hash will NOT be deleted." "Borrar completamente el merge '{0}'?`n`nPMM retirara de ~mods de Palworld la copia desplegada exacta si existe, borrara las copias guardadas + manifests coincidentes dentro de PMM, limpiara su validacion/seleccion y dejara intactos todos los mods fuente.`n`nNO se borrara un archivo del mismo nombre si tiene otro hash.") -f $name)
    if(-not(Confirm $question)){return}
    $result=Remove-PMMManagedPatch $entry.Patch
    $Script:TxtStatus.Text=((L 'Merge deleted. Game copy removed: {0}; saved PMM copies removed: {1}.' 'Merge borrado. Copia del juego retirada: {0}; copias guardadas en PMM borradas: {1}.') -f [bool]$result.GameRemoved,[int]$result.LocalCopiesRemoved)
    Refresh-UI;Update-PMMGuidedActionState
  }catch{Handle-UIError $_ (L 'Delete merge' 'Borrar merge')}
})
$Script:LstPatches.AddHandler([System.Windows.Controls.Primitives.ButtonBase]::ClickEvent,[System.Windows.RoutedEventHandler]{
  param($sender,$e)
  try{
    $radio=$e.OriginalSource -as [System.Windows.Controls.RadioButton]
    if(-not$radio -or [string]::IsNullOrWhiteSpace([string]$radio.Tag)){return}
    $name=[string]$radio.Tag
    $entry=@($Script:LstPatches.Items|Where-Object{[string]$_.SelectionKey -ieq $name}|Select-Object -First 1)[0]
    if(-not$entry -or -not[bool]$entry.Selectable){return}
    Set-PMMSelectedPatchName $name
    if($name -eq (Get-PMMNoPatchSelectionName)){Write-PMMLog 'User selected manager-only Deploy: no compatibility patch.'}
    else{Write-PMMLog "User selected saved compatibility patch for Deploy: $name"}
    Refresh-UI
  }catch{Handle-UIError $_ (L 'Select compatibility patch' 'Seleccionar parche de compatibilidad')}
  $e.Handled=$true
})
$Script:ChkCloseGame.Add_Click({try{Update-PMMDeploymentOptionsState}catch{}})
$Script:BtnPriorityUp.Add_Click({
  try{
    $entry=Get-SelectedPMMLibraryEntry
    if(-not$entry -or $entry.Kind -ne 'Source'){return}
    $name=[string]$entry.Name
    if(Move-PMMModPriority $name 'Earlier'){
      Refresh-PMMLibraryAfterPriorityChange $name
    }
  }catch{Handle-UIError $_ (L 'Change mod priority' 'Cambiar prioridad del mod')}
})
$Script:BtnPriorityDown.Add_Click({
  try{
    $entry=Get-SelectedPMMLibraryEntry
    if(-not$entry -or $entry.Kind -ne 'Source'){return}
    $name=[string]$entry.Name
    if(Move-PMMModPriority $name 'Later'){
      Refresh-PMMLibraryAfterPriorityChange $name
    }
  }catch{Handle-UIError $_ (L 'Change mod priority' 'Cambiar prioridad del mod')}
})

$Script:BtnDeleteMod.Add_Click({
  try{
    $entries=@(Get-SelectedPMMLibraryEntries)
    if($entries.Count -eq 0){return}
    $names=@($entries|ForEach-Object{[string]$_.Name})
    $preview=($names|Select-Object -First 8) -join "`n"
    if($names.Count -gt 8){$preview+="`n... +"+($names.Count-8)}
    $question=if($names.Count -eq 1){
      (L "Delete {0} everywhere? This immediately removes the imported copy from PMM and the exact matching PAK from Palworld ~mods. A deployed compatibility merge is preserved until you explicitly change it in the Compatibility patches panel." "Borrar {0} de todas partes? Esto elimina inmediatamente la copia importada de PMM y el PAK exacto correspondiente de ~mods de Palworld. Un merge de compatibilidad desplegado se conserva hasta que lo cambies explicitamente en el panel Compatibility patches.") -f $names[0]
    }else{
      ((L "Delete {0} selected mods everywhere? Each imported copy will be removed from PMM and its exact matching PAK will be removed from Palworld ~mods. Any deployed compatibility merge is preserved until you explicitly change it in the Compatibility patches panel.`n`n{1}" "Borrar {0} mods seleccionados de todas partes? Cada copia importada se eliminara de PMM y su PAK exacto correspondiente se eliminara de ~mods de Palworld. Cualquier merge de compatibilidad desplegado se conserva hasta que lo cambies explicitamente en el panel Compatibility patches.`n`n{1}") -f $names.Count,$preview)
    }
    if(Confirm $question){
      $results=[System.Collections.Generic.List[object]]::new()
      foreach($name in $names){$results.Add((Remove-PMMLibraryMod $name))}
      $gameRemoved=@($results.ToArray()|Where-Object{[bool]$_.DeletedFromGame}).Count
      Refresh-UI
      try{Check-PMMExternalModChanges -Force}catch{}
      try{Update-PMMFixLabAttentionFromLibrary 'Delete'}catch{}
      try{Update-PMMGuidedActionState}catch{}
      $Script:TxtStatus.Text=((L 'Deleted {0} imported mod(s) from PMM; {1} matching game PAK(s) removed from ~mods. The deployed compatibility merge was preserved.' 'Borrados {0} mod(s) importados de PMM; {1} PAK coincidente(s) eliminados de ~mods. El merge de compatibilidad desplegado se conservo.') -f $results.Count,$gameRemoved)
    }
  }catch{Handle-UIError $_ (L 'Delete mods' 'Borrar mods')}
})

$Script:LstConflictAssets.Add_SelectionChanged({
  if ($Script:LoadingConflictView) { return }
  try {
    Save-DecisionGridToPlan -Silent
    Refresh-PMMAnalysisWorkspace
    Show-SelectedConflictAsset $Script:LstConflictAssets.SelectedItem
    Update-BuildButtonState
    Update-PMMGuidedActionState
  } catch { Handle-UIError $_ (L 'Conflict view' 'Vista de conflictos') }
})

$Script:LstUnsupportedAssets.Add_SelectionChanged({
  if($Script:LoadingConflictView){return}
  try{Show-SelectedUnsupportedAsset}catch{Handle-UIError $_ (L 'Unsupported asset view' 'Vista de asset no soportado')}
})

$Script:BtnDisableUnsupported.Add_Click({
  try{
    $name=[string]$Script:CmbUnsupportedDisable.SelectedItem
    if([string]::IsNullOrWhiteSpace($name)){throw (L 'Choose a source mod to disable.' 'Elige un mod fuente para desactivar.')}
    $message=(L "Disable {0} in the PMM library and run Analyze again?`n`nThe PAK is kept under Mods\_Disabled and the game folder is unchanged until Deploy." "Desactivar {0} en la biblioteca PMM y volver a Analizar?`n`nEl PAK se conserva en Mods\_Disabled y la carpeta del juego no cambia hasta Deploy.") -f $name
    if(Confirm $message){
      Set-PMMLibraryModEnabled $name $false
      Refresh-UI
      $done={param($result) Refresh-UI}
      [void](Start-PMMBackgroundOperation -Operation Analyze -OnSuccess $done)
    }
  }catch{Handle-UIError $_ (L 'Disable unsupported source' 'Desactivar fuente no soportada')}
})


function Format-PMMByteSize([int64]$Bytes) {
  if($Bytes -ge 1GB){return ('{0:N2} GiB' -f ([double]$Bytes/1GB))}
  if($Bytes -ge 1MB){return ('{0:N1} MiB' -f ([double]$Bytes/1MB))}
  if($Bytes -ge 1KB){return ('{0:N1} KiB' -f ([double]$Bytes/1KB))}
  return ([string]$Bytes+' B')
}

function Start-PMMAIHandoffFromUI {
  param([switch]$AllowOversize,[switch]$Force)
  try{
    $estimate=Get-PMMAIHandoffEstimate
    $allow=[bool]$AllowOversize
    if($estimate.PSObject.Properties.Name -contains 'InsufficientDiskSpace' -and [bool]$estimate.InsufficientDiskSpace){
      Show-Error ((L "Not enough free disk space to create this handoff safely.`n`nAvailable: {0}`nConservative working-space requirement: {1}`n`nPMM reserves room for both the extracted staging files and a worst-case ZIP so the disk cannot be filled by an unexpectedly incompressible bundle." "No hay suficiente espacio libre para crear esta entrega de forma segura.`n`nDisponible: {0}`nEspacio de trabajo conservador necesario: {1}`n`nPMM reserva espacio tanto para los archivos extraidos como para un ZIP en el peor caso, evitando llenar el disco si el paquete comprime peor de lo esperado.") -f (Format-PMMByteSize ([int64]$estimate.AvailableFreeBytes)),(Format-PMMByteSize ([int64]$estimate.RequiredWorkingBytes)))
      return
    }
    if([bool]$estimate.NeedsOversizeConfirmation -and -not$allow){
      $question=((L "This AI handoff will be unusually large.`n`nUnsupported cases: {0}`nKnown raw conflict files: {1}`nEstimated ZIP: {2}`nNormal raw limit: {3}`nTarget ZIP size: {4}`n`nAIIO will still include ONLY the exact conflicting files; it will never copy whole source PAKs.`n`nCreate it anyway?" "Esta entrega para IA sera inusualmente grande.`n`nCasos no soportados: {0}`nArchivos de conflicto conocidos sin comprimir: {1}`nZIP estimado: {2}`nLimite normal sin comprimir: {3}`nTamano objetivo del ZIP: {4}`n`nAIIO seguira incluyendo SOLO los archivos exactos en conflicto; nunca copiara PAK fuente completos.`n`nCrear de todas formas?") -f [int]$estimate.CaseCount,(Format-PMMByteSize ([int64]$estimate.RawBytes)),(Format-PMMByteSize ([int64]$estimate.EstimatedZipBytes)),(Format-PMMByteSize ([int64]$estimate.DefaultRawLimitBytes)),(Format-PMMByteSize ([int64]$estimate.SoftZipTargetBytes)))
      if(-not(Confirm $question)){return}
      $allow=$true
    }

    $done={
      param($result)
      try{
        Refresh-UI
        $zip=[string]$result.ZipPath
        if([string]::IsNullOrWhiteSpace($zip) -or -not(Test-Path -LiteralPath $zip -PathType Leaf)){throw (L 'AIIO finished but no handoff ZIP was found.' 'AIIO termino pero no se encontro el ZIP de entrega.')}
        if($result.PSObject.Properties.Name -contains 'OverSoftZipTarget' -and [bool]$result.OverSoftZipTarget){
          Set-PMMOperationResult 'AIIO' ((L 'AI handoff ready. Large valid package: {0}.' 'Entrega para IA lista. Paquete grande valido: {0}.') -f (Format-PMMByteSize ([int64]$result.ZipBytes)))
        }else{
          Set-PMMOperationResult 'AIIO' (L 'AI handoff ready.' 'Entrega para IA lista.')
        }
        Start-Process explorer.exe -ArgumentList ('/select,"'+$zip+'"')
      }catch{Handle-UIError $_ (L 'AI handoff' 'Entrega para IA')}
    }.GetNewClosure()

    $failed={
      param($message)
      if(([string]$message).StartsWith('PMM_AIIO_INSUFFICIENT_DISK|',[StringComparison]::Ordinal)){
        $required=0L;$free=0L
        if(([string]$message) -match 'requiredBytes=([0-9]+)'){$required=[int64]$Matches[1]}
        if(([string]$message) -match 'freeBytes=([0-9]+)'){$free=[int64]$Matches[1]}
        Show-Error ((L "AIIO stopped before filling the disk.`n`nFree: {0}`nRequired for this phase: {1}`n`nFree some space or move PMM to a drive with more capacity, then try again." "AIIO se detuvo antes de llenar el disco.`n`nLibre: {0}`nNecesario para esta fase: {1}`n`nLibera espacio o mueve PMM a una unidad con mas capacidad y vuelve a intentarlo.") -f (Format-PMMByteSize $free),(Format-PMMByteSize $required))
        return
      }
      if(([string]$message).StartsWith('PMM_AIIO_OVERSIZE_CONFIRMATION_REQUIRED|',[StringComparison]::Ordinal)){
        $actualZip=0L
        if(([string]$message) -match 'actualZipBytes=([0-9]+)'){$actualZip=[int64]$Matches[1]}
        $question=if($actualZip -gt 0){
          ((L 'The completed ZIP is {0}, above the normal 512 MiB handoff target. Create the large handoff anyway?' 'El ZIP terminado ocupa {0}, por encima del objetivo normal de 512 MiB para la entrega. Crear de todas formas la entrega grande?') -f (Format-PMMByteSize $actualZip))
        }else{
          (L 'The extracted files crossed the normal 5 GiB raw handoff limit. Create the large handoff anyway?' 'Los archivos extraidos superaron el limite normal de 5 GiB sin comprimir. Crear de todas formas la entrega grande?')
        }
        $retry=Confirm $question
        if($retry){Start-PMMAIHandoffFromUI -AllowOversize -Force:$Force}
        return
      }
      Show-Error ([string]$message)
    }.GetNewClosure()

    [void](Start-PMMBackgroundOperation -Operation AIHandoff -AllowOversize:$allow -Force:$Force -OnSuccess $done -OnFailure $failed)
  }catch{Handle-UIError $_ (L 'AI handoff' 'Entrega para IA')}
}

function Prompt-PMMAIHandoffAfterAnalyze {
  try{
    $unsupported=@(Get-PMMUnsupportedAssets)
    if($unsupported.Count -eq 0){return}
    $estimate=Get-PMMAIHandoffEstimate
    if([bool]$estimate.Existing){return}
    $question=((L "Analyze found {0} Unsupported shared asset(s).`n`nCreate ONE AI handoff ZIP for the complete current mod list now? AIIO will extract only the exact conflicting files from each involved mod and Vanilla; source PAKs are never copied." "Analizar encontro {0} asset(s) compartido(s) no soportado(s).`n`nCrear ahora UN unico ZIP de entrega para IA para la lista de mods actual? AIIO extraera solo los archivos exactos en conflicto de cada mod implicado y Vanilla; nunca se copiaran los PAK fuente.") -f $unsupported.Count)
    if(Confirm $question){Start-PMMAIHandoffFromUI}
  }catch{Write-PMMLog ('AIIO post-Analyze prompt skipped: '+$_.Exception.Message)}
}

$Script:BtnOpenAIHandoff.Add_Click({
  Start-PMMAIHandoffFromUI
})

$Script:BtnImportManualSolution.Add_Click({
  try{
    $review=[string]$Script:BtnImportManualSolution.Tag
    if([string]::IsNullOrWhiteSpace($review) -or -not(Test-Path -LiteralPath (Join-Path $review 'case.json') -PathType Leaf)){throw (L 'This unsupported asset has no current review case. Run Analyze again.' 'Este asset no soportado no tiene un caso de revision actual. Ejecuta Analizar de nuevo.')}
    Add-Type -AssemblyName System.Windows.Forms
    $dialog=New-Object System.Windows.Forms.OpenFileDialog
    $dialog.Multiselect=$false
    $dialog.Filter=L 'PMM manual/AI solution (*.zip)|*.zip|All files (*.*)|*.*' 'Solucion manual/IA de PMM (*.zip)|*.zip|Todos (*.*)|*.*'
    if($dialog.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK){return}
    $warning=L "Import this experimental cooked solution?`n`nPMM will verify the exact case ID/input hashes, ZIP paths, cooked-family topology, output hashes and a read-only AssetReader parse. It CANNOT prove the proposed gameplay semantics. Build will remain clearly marked experimental until you test it in Palworld.`n`nContinue under your responsibility?" "Importar esta solucion cooked experimental?`n`nPMM verificara el ID de caso/hashes exactos, rutas del ZIP, topologia de la familia cooked, hashes de salida y una lectura con AssetReader. NO PUEDE demostrar la semantica de gameplay propuesta. Build seguira marcado como experimental hasta que lo pruebes en Palworld.`n`nContinuar bajo tu responsabilidad?"
    if(-not(Confirm $warning)){return}
    $imported=Import-PMMManualSolutionZip $dialog.FileName $review $true
    $Script:TxtStatus.Text=((L 'Experimental solution validated for case {0}. PMM will re-analyze.' 'Solucion experimental validada para el caso {0}. PMM volvera a analizar.') -f [string]$imported.CaseId)
    $done={param($result) Refresh-UI}
    [void](Start-PMMBackgroundOperation -Operation Analyze -Force -OnSuccess $done)
  }catch{Handle-UIError $_ (L 'Import manual/AI solution' 'Importar solucion manual/IA')}
})

# Decisions are persisted when the user changes asset, applies a bulk choice,
# starts Build, or closes PMM.  Preview 13 used a one-second timer that called
# CommitEdit while the Winner ComboBox was open; WPF therefore closed the
# dropdown almost immediately.  Do not reintroduce that polling pattern.

$Script:BtnApplyBulk.Add_Click({
  try {
    $choice = [string]$Script:CmbBulkWinner.SelectedItem
    if ([string]::IsNullOrWhiteSpace($choice)) { throw (L 'Choose a source first.' 'Elige primero una fuente para aplicar a todas las filas.') }
    if ($choice -eq 'Custom' -and [string]::IsNullOrWhiteSpace([string]$Script:TxtBulkCustom.Text)) {
      throw (L 'Enter the Custom value that should be applied to all visible conflict rows.' 'Introduce el valor Custom que se aplicara a todas las filas visibles.')
    }
    foreach ($row in @($Script:DgDecisions.ItemsSource)) {
      $row.SelectedChoice = $choice
      if ($choice -eq 'Custom') { $row.CustomValue = [string]$Script:TxtBulkCustom.Text }
      $row.ResolutionOrigin='Manual'
      $row.Status = L 'Resolved' 'Resuelto'
    }
    $Script:DgDecisions.Items.Refresh()
    Save-DecisionGridToPlan
    Refresh-PMMAnalysisWorkspace
    Refresh-ConflictWorkspace $Script:CurrentConflictAssetKey
    Update-BuildButtonState
    Update-PMMGuidedActionState
  } catch { Handle-UIError $_ (L 'Bulk conflict decision' 'Decision masiva de conflictos') }
})

$Script:BtnOpenReview.Add_Click({
  try {
    $folder = [string]$Script:BtnOpenReview.Tag
    if ([string]::IsNullOrWhiteSpace($folder) -or -not (Test-Path -LiteralPath $folder -PathType Container)) {
      throw (L 'No review folder is available for the selected asset. Run Analyze again.' 'No hay carpeta de revision para el asset seleccionado. Ejecuta Analizar de nuevo.')
    }
    Start-Process explorer.exe -ArgumentList ('"'+$folder+'"')
  } catch { Handle-UIError $_ (L 'Open review files' 'Abrir archivos de revision') }
})

$Script:BtnBuild.Add_Click({
  try {
    Save-UiSettings
    Save-DecisionGridToPlan
    $plan=Read-PMMMergePlan

    [object[]]$experimental=@(
      if($plan -and $null -ne $plan.Assets){
        $plan.Assets | Where-Object{[string]$_.Mode -eq 'ManualSolutionExperimental'}
      }
    )
    [int]$experimentalCount=$experimental.Length
    if($experimentalCount -gt 0){
      $names=@($experimental|ForEach-Object{[IO.Path]::GetFileName([string]$_.Asset)}) -join ', '
      $warning=(L "This Build contains {0} experimental manual/AI cooked solution(s):`n{1}`n`nPMM validated provenance, file topology, hashes and parsing, but not the intended gameplay behavior. Continue and test the result in Palworld?" "Este Build contiene {0} solucion(es) cooked manual/IA experimental(es):`n{1}`n`nPMM valido procedencia, topologia, hashes y lectura del asset, pero no el comportamiento de gameplay previsto. Continuar y probar el resultado en Palworld?") -f $experimentalCount,$names
      if(-not(Confirm $warning)){return}
    }

    Reset-PMMOperationCancellation
    if([bool]$Script:TglAutoMode.IsChecked){Start-PMMAutoPipeline}
    $done={
      param($result)
      $message=if($result){[string]$result.ResultText}else{''}
      if([string]::IsNullOrWhiteSpace($message)){$message=L 'Build complete.' 'Build terminado.'}
      Set-PMMOperationResult 'Build' $message
      Refresh-UI
      $Script:TxtLog.Text=Get-PMMRecentLog
      $Script:TxtStatus.Text=Get-PMMStatusLine
    }
    $failed={param($message) Stop-PMMAutoPipeline;Show-Error ([string]$message)}
    [void](Start-PMMBackgroundOperation -Operation Build -Mode 'ConflictGroups' -OnSuccess $done -OnFailure $failed)
  } catch { Stop-PMMAutoPipeline;Handle-UIError $_ 'Build Merge' }
})

$Script:BtnDeploy.Add_Click({
  if(-not(Request-PMMProcessingSlot 'Deploy')){return}
  Reset-PMMOperationCancellation
  if([bool]$Script:TglAutoMode.IsChecked){Start-PMMAutoPipeline}
  try{
    Save-UiSettings
    Save-DecisionGridToPlan
    $preview=Get-PMMDeploymentPreview
    Write-PMMLog ('Deploy preflight: '+($preview -replace "(`r`n|`n|`r)",' | '))
    Set-PMMDeployBusy $true
    $deployProgress={
      param([double]$fraction,[string]$message)
      Set-PMMDeployProgress ([int][Math]::Round(100.0*$fraction)) 100 $message
    }.GetNewClosure()
    $result=Deploy-PMMManagedState $deployProgress
    $deployDone=if([string]::IsNullOrWhiteSpace([string]$result)){L 'Deploy complete.' 'Deploy terminado.'}else{[string]$result}
    Set-PMMDeployProgress 100 100 $deployDone
    Refresh-UI
    Check-PMMExternalModChanges -Force
    Notify-PMMWorkflowStepComplete
  }catch{
    if(Test-PMMCancellationError $_){Set-PMMOperationResult 'Deploy' (L 'Deploy cancelled. Any committed managed files were rolled back.' 'Deploy cancelado. Cualquier archivo gestionado ya aplicado fue restaurado mediante rollback.');Stop-PMMAutoPipeline}
    else{Stop-PMMAutoPipeline;Handle-UIError $_ 'Deploy'}
  }
  finally{
    Set-PMMDeployBusy $false
    try{Update-PMMGuidedActionState}catch{}
    if($Script:AutoPipelineActive){try{Invoke-PMMAutoContinue}catch{Write-PMMLog ('AUTO continuation after Deploy failed: '+$_.Exception.Message)}}
  }
})


$Script:BtnUndeployPatch.Add_Click({
  try{
    $entry=$Script:LstPatches.SelectedItem
    if(-not$entry -or -not$entry.Patch){throw (L 'Select the deployed merge you want to undeploy.' 'Selecciona el merge desplegado que quieres retirar.')}
    $patch=$entry.Patch
    if(-not[bool]$patch.Deployed){$Script:TxtStatus.Text=L 'The selected merge is already not deployed.' 'El merge seleccionado ya no esta desplegado.';Update-PMMPatchActionButtons;return}
    $name=[string]$patch.Name
    if(-not(Confirm ((L "Undeploy '{0}'? This removes only the exact PMM merge PAK + its sidecar from Palworld ~mods. The saved build inside PMM and all source mods are kept." "Retirar '{0}'? Esto elimina solamente el PAK exacto del merge PMM + su sidecar de ~mods de Palworld. El build guardado dentro de PMM y todos los mods fuente se conservan.") -f $name))){return}
    $result=Undeploy-PMMManagedPatch $patch
    $Script:TxtStatus.Text=if([bool]$result.Removed){(L 'Merge undeployed from Palworld. Saved PMM build was kept.' 'Merge retirado de Palworld. El build guardado en PMM se conservo.')}else{(L 'The selected merge was not present in Palworld ~mods.' 'El merge seleccionado no estaba en ~mods de Palworld.')}
    Refresh-UI;Update-PMMGuidedActionState
  }catch{Handle-UIError $_ (L 'Undeploy merge' 'Retirar merge')}
})

# ---------------------------------------------------------------------------
# Save backup controls.
# ---------------------------------------------------------------------------
function Update-PMMSavePaneRows {
  try{
    $a=[bool]$Script:ExpSelectedSave.IsExpanded;$b=[bool]$Script:ExpSaveBackups.IsExpanded
    if($a -and $b){$Script:RowSelectedSave.Height=[System.Windows.GridLength]::new(1,[System.Windows.GridUnitType]::Star);$Script:RowSaveBackups.Height=[System.Windows.GridLength]::new(1,[System.Windows.GridUnitType]::Star);$Script:RowSavePaneSplitter.Height=[System.Windows.GridLength]::new(6);$Script:SplSavePanes.Visibility=[System.Windows.Visibility]::Visible}
    elseif($a){$Script:RowSelectedSave.Height=[System.Windows.GridLength]::new(1,[System.Windows.GridUnitType]::Star);$Script:RowSaveBackups.Height=[System.Windows.GridLength]::Auto;$Script:RowSavePaneSplitter.Height=[System.Windows.GridLength]::new(0);$Script:SplSavePanes.Visibility=[System.Windows.Visibility]::Collapsed}
    elseif($b){$Script:RowSelectedSave.Height=[System.Windows.GridLength]::Auto;$Script:RowSaveBackups.Height=[System.Windows.GridLength]::new(1,[System.Windows.GridUnitType]::Star);$Script:RowSavePaneSplitter.Height=[System.Windows.GridLength]::new(0);$Script:SplSavePanes.Visibility=[System.Windows.Visibility]::Collapsed}
    else{$Script:RowSelectedSave.Height=[System.Windows.GridLength]::Auto;$Script:RowSaveBackups.Height=[System.Windows.GridLength]::Auto;$Script:RowSavePaneSplitter.Height=[System.Windows.GridLength]::new(0);$Script:SplSavePanes.Visibility=[System.Windows.Visibility]::Collapsed}
  }catch{}
}
$Script:ExpSelectedSave.Add_Expanded({Update-PMMSavePaneRows});$Script:ExpSelectedSave.Add_Collapsed({Update-PMMSavePaneRows})
$Script:ExpSaveBackups.Add_Expanded({Update-PMMSavePaneRows});$Script:ExpSaveBackups.Add_Collapsed({Update-PMMSavePaneRows})
Update-PMMSavePaneRows
function Refresh-PMMSaveBackupPane {
  try{
    $save=$Script:LstSaves.SelectedItem;$Script:LstSaveBackups.ItemsSource=$null;$Script:TxtSaveBackupDetails.Text=''
    if(-not$save){return}
    $rows=@(Get-PMMSaveBackups $save);$Script:LstSaveBackups.ItemsSource=$rows
    $Script:BtnOpenSaveBackupFolder.IsEnabled=$true;$Script:BtnRestoreSave.IsEnabled=$false
    if($rows.Count -gt 0){$Script:LstSaveBackups.SelectedIndex=0}
    $Script:ExpSaveBackups.Header=((L 'PMM backups made ({0})' 'Backups PMM creados ({0})') -f $rows.Count)
  }catch{Write-PMMLog ('Save backup pane refresh warning: '+$_.Exception.Message)}
}
$Script:LstSaves.Add_SelectionChanged({try{$save=$Script:LstSaves.SelectedItem;if($save){$Script:TxtSaveDetails.Text=(Get-PMMSaveDetails $save|Out-String);$Script:ExpSelectedSave.Header=((L 'Selected save - {0}' 'Save seleccionado - {0}') -f [string]$save.WorldName)};Refresh-PMMSaveBackupPane}catch{$Script:TxtSaveDetails.Text=$_.Exception.Message}})
$Script:LstSaveBackups.Add_SelectionChanged({try{$row=$Script:LstSaveBackups.SelectedItem;$Script:TxtSaveBackupDetails.Text=Get-PMMSaveBackupDetails $row $Script:LstSaves.SelectedItem;$Script:BtnRestoreSave.IsEnabled=($null -ne $row);$Script:BtnOpenSaveBackupFolder.IsEnabled=($null -ne $row)}catch{$Script:TxtSaveBackupDetails.Text=$_.Exception.Message}})
$Script:BtnBackupSave.Add_Click({try{$save=$Script:LstSaves.SelectedItem;if(-not$save){throw(L 'Select a world.' 'Selecciona un mundo.')};$path=Backup-PMMSave $save;$when=(Get-Date).ToString('yyyy-MM-dd HH:mm:ss');$msg=((L 'Backup created successfully' 'Backup creado correctamente')+' - '+$when+' | '+[IO.Path]::GetFileName($path));$Script:TxtStatus.Text=$msg;$Script:TxtSaveBackupStatus.Text=$msg;$Script:TxtSaveBackupStatus.Foreground=$Window.Resources['AccentHeadingGreen'];$Script:TxtSaveBackupStatus.ToolTip=$path;Refresh-PMMSaveBackupPane;Notify-PMMWorkflowStepComplete}catch{Handle-UIError $_ (L 'Save backup' 'Backup de save')}})
$Script:BtnRestoreSave.Add_Click({try{$save=$Script:LstSaves.SelectedItem;if(-not$save){throw(L 'Select a world.' 'Selecciona un mundo.')};$row=$Script:LstSaveBackups.SelectedItem;if(-not$row){throw(L 'Select a PMM backup from the Backups made panel.' 'Selecciona un backup PMM en el panel Backups creados.')};if(Confirm(L 'Restoring this backup will replace the current world. PMM will create a safety backup first. Continue?' 'Restaurar este backup reemplazara el mundo actual. PMM creara antes un backup de seguridad. Continuar?')){[void](Restore-PMMSaveFromArchive $save ([string]$row.Path));Refresh-UI;$Script:TxtStatus.Text=L 'Save restored. A safety backup was created automatically before restore.' 'Save restaurado. Se creo automaticamente un backup de seguridad antes de restaurar.';Notify-PMMWorkflowStepComplete}}catch{Handle-UIError $_ (L 'Save restore' 'Restaurar save')}})
$Script:BtnOpenSaveBackupFolder.Add_Click({try{$row=$Script:LstSaveBackups.SelectedItem;if($row){Start-Process explorer.exe -ArgumentList ('/select,"'+[string]$row.Path+'"')}else{$save=$Script:LstSaves.SelectedItem;if(-not$save){return};$dir=Join-Path (Join-PMMPath 'Saves' 'Backups') ([string]$save.Name);New-Item -ItemType Directory -Force -Path $dir|Out-Null;Start-Process explorer.exe -ArgumentList ('"'+$dir+'"')}}catch{Handle-UIError $_ (L 'Open backup folder' 'Abrir carpeta de backups')}})


# ---------------------------------------------------------------------------
# AI & Help.
# ---------------------------------------------------------------------------
$Script:BtnAIHelpRefresh.Add_Click({try{Refresh-PMMAIHelpUi -EnsureUnsupported;$Script:TxtAIHelpDiagnosticStatus.Text=L 'Diagnostics refreshed.' 'Diagnosticos actualizados.'}catch{Handle-UIError $_ (L 'Refresh AI & Help' 'Actualizar IA y ayuda')}})
$Script:BtnAIHelpRefreshKnowledge.Add_Click({try{$done={param($result) Refresh-PMMAIHelpKnowledge;Refresh-PMMAIHelpBadge}.GetNewClosure();[void](Start-PMMBackgroundOperation -Operation AIIOArtifactRefresh -OnSuccess $done)}catch{Handle-UIError $_ (L 'Refresh Knowledge and storage' 'Actualizar Knowledge y almacenamiento')}})
$Script:BtnAIHelpCreateCase.Add_Click({
  try{
    $type=[string]$Script:CmbAIHelpDiagnosticType.SelectedValue;if(-not$type){$type='UNKNOWN'}
    $case=New-PMMDiagnosticCase -Type $type -Title ([string]$Script:TxtAIHelpDiagnosticTitle.Text) -UserDescription ([string]$Script:TxtAIHelpDiagnosticDescription.Text) -IncludePalworldLogSummary:([bool]$Script:ChkAIHelpIncludePalLog.IsChecked)
    Refresh-PMMAIHelpUi;$Script:LstAIHelpDiagnostics.SelectedValue=[string]$case.CaseId
    $Script:TxtAIHelpDiagnosticStatus.Text=((L 'Diagnostic case created locally: {0}. It has not been uploaded.' 'Caso de diagnostico creado localmente: {0}. No se ha subido.') -f [string]$case.CaseId)
  }catch{Handle-UIError $_ (L 'Create diagnostic case' 'Crear caso de diagnostico')}
})
$Script:BtnAIHelpPrepareDiagnostic.Add_Click({
  try{
    $row=$Script:LstAIHelpDiagnostics.SelectedItem;if(-not$row){throw (L 'Select a diagnostic case.' 'Selecciona un caso de diagnostico.')}
    $casePath=Get-PMMDiagnosticCasePath ([string]$row.CaseId);$case=Get-Content -LiteralPath $casePath -Raw -Encoding UTF8|ConvertFrom-Json
    $session=New-PMMAIIOSessionFromDiagnostic $case;Refresh-PMMAIHelpUi;$Script:LstAIIOSessions.SelectedValue=[string]$session.SessionId;$Script:AIHelpTabs.SelectedIndex=1
    $sessionId=[string]$session.SessionId
    $done={param($result) Refresh-PMMAIHelpUi;$Script:LstAIIOSessions.SelectedValue=$sessionId;$Script:TxtAIIOStatus.Text=((L 'AI request ready: {0}. Give this ZIP to the AI yourself. Nothing was uploaded.' 'Peticion para IA lista: {0}. Entrega tu mismo este ZIP a la IA. No se subio nada.') -f [string]$result.ZipPath);Start-Process explorer.exe -ArgumentList ('/select,"'+[string]$result.ZipPath+'"')}.GetNewClosure()
    [void](Start-PMMBackgroundOperation -Operation AIIOPrepare -SessionId $sessionId -OnSuccess $done)
  }catch{Handle-UIError $_ (L 'Prepare diagnostic for AI' 'Preparar diagnostico para IA')}
})
$Script:LstAIIOSessions.Add_SelectionChanged({
  try{
    $session=Get-PMMSelectedAIIOSession
    if($session){Refresh-PMMAIIOCandidates ([string]$session.SessionId);$Script:TxtAIIOStatus.Text=((L 'Session {0} — {1} — iteration {2}. Returned candidates remain staged until you explicitly review and act.' 'Sesion {0} — {1} — iteracion {2}. Los candidatos devueltos quedan en staging hasta que los revises y actues expresamente.') -f [string]$session.SessionId,[string]$session.Status,[int]$session.Iteration)}
  }catch{}
})
$Script:LstAIIOCandidates.Add_SelectionChanged({try{Update-PMMAIIOCandidateSelection}catch{}})
$Script:BtnAIIONewSession.Add_Click({
  try{
    $type=[string]$Script:CmbAIIOType.SelectedValue;if(-not$type){$type='UNKNOWN'}
    $title=[string]$Script:TxtAIIOTitle.Text;if([string]::IsNullOrWhiteSpace($title)){$title=(L 'AI & Help task' 'Tarea de IA y ayuda')}
    $targetKind=[string]$Script:CmbAIOTargetKind.SelectedValue;if(-not$targetKind){$targetKind='Palworld'}
    $targetId=[string]$Script:TxtAIOTargetId.Text
    $targets=@();if($targetId){$targets=@([pscustomobject]@{Kind=$targetKind;Id=$targetId;UserSuspects=$true;CauseConfirmed=$false})}
    $session=New-PMMAIIOSession -Title $title -Description ([string]$Script:TxtAIIODescription.Text) -TaskType $type -TargetKind $targetKind -TargetId $targetId -SelectedTargets $targets
    Refresh-PMMAIHelpUi;$Script:LstAIIOSessions.SelectedValue=[string]$session.SessionId
    $Script:TxtAIIOStatus.Text=((L 'Local session created: {0}. Press Prepare for AI when the description is ready.' 'Sesion local creada: {0}. Pulsa Preparar para IA cuando la descripcion este lista.') -f [string]$session.SessionId)
  }catch{Handle-UIError $_ (L 'Create AIIO session' 'Crear sesion AIIO')}
})
$Script:BtnAIIOPrepare.Add_Click({
  try{
    $session=Get-PMMSelectedAIIOSession
    if(-not$session){
      $Script:BtnAIIONewSession.RaiseEvent([System.Windows.RoutedEventArgs]::new([System.Windows.Controls.Button]::ClickEvent));$session=Get-PMMSelectedAIIOSession
    }
    if(-not$session){throw (L 'Create or select a session first.' 'Crea o selecciona primero una sesion.')}
    $sessionId=[string]$session.SessionId
    $done={param($result) Refresh-PMMAIHelpUi;$Script:LstAIIOSessions.SelectedValue=$sessionId;$Script:TxtAIIOStatus.Text=((L 'AI request ready: {0}. Nothing was uploaded.' 'Peticion para IA lista: {0}. No se subio nada.') -f [string]$result.ZipPath);Start-Process explorer.exe -ArgumentList ('/select,"'+[string]$result.ZipPath+'"')}.GetNewClosure()
    [void](Start-PMMBackgroundOperation -Operation AIIOPrepare -SessionId $sessionId -OnSuccess $done)
  }catch{Handle-UIError $_ (L 'Prepare task for AI' 'Preparar tarea para IA')}
})
$Script:BtnAIIOImportResponse.Add_Click({
  try{
    $session=Get-PMMSelectedAIIOSession;if(-not$session){throw (L 'Select the session that owns the response.' 'Selecciona la sesion a la que pertenece la respuesta.')}
    $dialog=[Microsoft.Win32.OpenFileDialog]::new();$dialog.Title=L 'Import AI response ZIP' 'Importar ZIP de respuesta IA';$dialog.Filter='PMM AI response (*.zip)|*.zip'
    if($dialog.ShowDialog() -ne $true){return}
    $sessionId=[string]$session.SessionId;$zipPath=[string]$dialog.FileName
    $done={param($result) Refresh-PMMAIHelpUi;$Script:LstAIIOSessions.SelectedValue=$sessionId;$Script:TxtAIIOStatus.Text=((L 'Response validated: {0} data request(s), {1} staged candidate(s). No candidate was run, applied or deployed.' 'Respuesta validada: {0} peticion(es) de datos, {1} candidato(s) en staging. No se ejecuto, aplico ni desplego ningun candidato.') -f $result.RequestCount,$result.CandidateCount)}.GetNewClosure()
    [void](Start-PMMBackgroundOperation -Operation AIIOImportResponse -SessionId $sessionId -InputZip $zipPath -OnSuccess $done)
  }catch{Handle-UIError $_ (L 'Import AI response' 'Importar respuesta IA')}
})
$Script:BtnAIIOContinue.Add_Click({
  try{$session=Get-PMMSelectedAIIOSession;if(-not$session){throw (L 'Select a session.' 'Selecciona una sesion.')};$sessionId=[string]$session.SessionId;$done={param($result) Refresh-PMMAIHelpUi;$Script:LstAIIOSessions.SelectedValue=$sessionId;$Script:TxtAIIOStatus.Text=((L 'Requested-data ZIP ready: {0}' 'ZIP de datos solicitados listo: {0}') -f [string]$result.ZipPath);Start-Process explorer.exe -ArgumentList ('/select,"'+[string]$result.ZipPath+'"')}.GetNewClosure();[void](Start-PMMBackgroundOperation -Operation AIIOPendingData -SessionId $sessionId -OnSuccess $done)}catch{Handle-UIError $_ (L 'Prepare requested AI data' 'Preparar datos pedidos por IA')}
})
$Script:BtnAIIOArchive.Add_Click({try{$session=Get-PMMSelectedAIIOSession;if(-not$session){return};if(Confirm ((L 'Archive session {0}? Its history and artifacts remain on disk.' 'Archivar la sesion {0}? Su historial y artefactos seguiran guardados.') -f [string]$session.SessionId)){Set-PMMAIIOSessionArchived ([string]$session.SessionId) $true|Out-Null;Refresh-PMMAIHelpUi}}catch{Handle-UIError $_ (L 'Archive AIIO session' 'Archivar sesion AIIO')}})
$Script:BtnAIIOOpenWorkspace.Add_Click({try{$session=Get-PMMSelectedAIIOSession;$path=if($session){Get-PMMAIIOSessionPath ([string]$session.SessionId)}else{Get-PMMPath 'AIIO'};Start-Process explorer.exe -ArgumentList ('"'+$path+'"')}catch{Handle-UIError $_ (L 'Open AI workspace' 'Abrir espacio de IA')}})
$Script:BtnAIIOOpenCandidate.Add_Click({try{$row=$Script:LstAIIOCandidates.SelectedItem;if(-not$row){return};Start-Process explorer.exe -ArgumentList ('"'+[string]$row.Root+'"')}catch{Handle-UIError $_ (L 'Inspect AI candidate' 'Inspeccionar candidato IA')}})
$Script:BtnAIIOUseCandidate.Add_Click({
  try{
    $session=Get-PMMSelectedAIIOSession;$row=$Script:LstAIIOCandidates.SelectedItem
    if(-not$session -or -not$row){throw (L 'Select a session and candidate.' 'Selecciona una sesion y un candidato.')}
    $warning=L "Use this returned cooked-family candidate in Merge?`n`nPMM will revalidate the exact current case, source hashes, ZIP paths, cooked-family topology, output hashes and a read-only AssetReader parse. This cannot prove gameplay semantics. The candidate remains experimental and runtime UNPROVEN until you test the resulting exact build in Palworld.`n`nNothing will be deployed automatically. Continue?" "Usar este candidato cooked devuelto en Merge?`n`nPMM volvera a validar el caso exacto vigente, hashes fuente, rutas ZIP, topologia de la familia cooked, hashes de salida y una lectura con AssetReader. Esto no puede demostrar la semantica de gameplay. El candidato seguira experimental y runtime UNPROVEN hasta probar el build exacto en Palworld.`n`nNo se desplegara nada automaticamente. Continuar?"
    if(-not(Confirm $warning)){return}
    $sessionId=[string]$session.SessionId;$solutionId=[string]$row.SolutionId
    $done={
      param($result)
      Refresh-PMMAIHelpUi;$Script:LstAIIOSessions.SelectedValue=$sessionId
      $Script:TxtAIIOStatus.Text=((L 'Experimental candidate validated for case {0}. Analyze is refreshing the plan; Build and Deploy remain explicit.' 'Candidato experimental validado para el caso {0}. Analizar esta actualizando el plan; Build y Deploy siguen siendo explicitos.') -f [string]$result.CaseId)
      $analyzeDone={param($analyzeResult) Refresh-UI;$Script:MainTabs.SelectedIndex=0}.GetNewClosure()
      $startAnalyze={try{[void](Start-PMMBackgroundOperation -Operation Analyze -Force -OnSuccess $analyzeDone)}catch{Handle-UIError $_ (L 'Analyze AI candidate' 'Analizar candidato IA')}}.GetNewClosure()
      [void]$Window.Dispatcher.BeginInvoke([System.Windows.Threading.DispatcherPriority]::ContextIdle,$startAnalyze)
    }.GetNewClosure()
    [void](Start-PMMBackgroundOperation -Operation AIIOUseCandidate -SessionId $sessionId -SolutionId $solutionId -OnSuccess $done)
  }catch{Handle-UIError $_ (L 'Use AI candidate in Merge' 'Usar candidato IA en Merge')}
})
$Script:BtnAIHelpOpenKnowledge.Add_Click({try{Start-Process explorer.exe -ArgumentList ('"'+(Get-PMMPath 'CKL')+'"')}catch{Handle-UIError $_ (L 'Open Knowledge library' 'Abrir biblioteca Knowledge')}})
$Script:BtnAIHelpGenerateFeedback.Add_Click({
  try{
    $entry=$Script:LstPatches.SelectedItem
    if(-not$entry -or -not$entry.Patch){throw (L 'Select a compatibility merge in Mods & Merge first.' 'Selecciona primero un merge de compatibilidad en Mods y Merge.')}
    $summary=Get-PMMBuildValidationSummary $entry.Patch
    if([string]::IsNullOrWhiteSpace([string]$summary.LatestEventId)){throw (L 'Validate this exact deployed merge first. Feedback is tied to a deterministic build and validation event.' 'Valida primero este merge desplegado exacto. El feedback queda ligado a un build determinista y a su evento de validacion.')}
    $result=Export-PMMBuildValidationFeedback ([string]$summary.LatestEventId)
    $Script:TxtStatus.Text=((L 'Inspectable local feedback file created: {0}. Nothing was uploaded.' 'Archivo local de feedback inspeccionable creado: {0}. No se subio nada.') -f [string]$result.Path)
    Start-Process explorer.exe -ArgumentList ('/select,"'+[string]$result.Path+'"')
  }catch{Handle-UIError $_ (L 'Generate local validation feedback' 'Generar feedback local de validacion')}
})
$Script:BtnAIHelpOpenFeedback.Add_Click({try{Start-Process explorer.exe -ArgumentList ('"'+(Get-PMMPath 'ValidationFeedback')+'"')}catch{Handle-UIError $_ (L 'Open local feedback files' 'Abrir feedback local')}})
$Script:BtnAIHelpCleanup.Add_Click({
  try{
    $registry=Update-PMMArtifactRegistry;$disposable=@($registry.Artifacts|Where-Object{[string]$_.Category -eq 'DISPOSABLE' -and -not[bool]$_.ProtectedByDefault});[int64]$bytes=0;foreach($row in $disposable){$bytes+=[int64]$row.Size}
    if($disposable.Count -eq 0){Show-Info (L 'No disposable artifact is currently eligible for cleanup.' 'No hay artefactos desechables disponibles para limpiar.');return}
    $mib=1048576.0
    $question=((L 'Delete {0} allowlisted disposable item(s), approximately {1:N1} MiB? Current builds, sessions, fixes, saves, Knowledge and protected evidence are excluded.' 'Eliminar {0} elemento(s) desechables permitidos, aproximadamente {1:N1} MiB? Se excluyen builds actuales, sesiones, fixes, saves, Knowledge y evidencia protegida.') -f $disposable.Count,([double]$bytes/$mib))
    if(Confirm $question){$result=Remove-PMMDisposableArtifacts -Confirm:$false;[void](Get-PMMArtifactStorageSummary -Refresh);Refresh-PMMAIHelpKnowledge;Show-Info ((L 'Disposable cleanup removed {0:N1} MiB.' 'La limpieza elimino {0:N1} MiB desechables.') -f ([double]$result.RemovedBytes/$mib))}
  }catch{Handle-UIError $_ (L 'Disposable cleanup' 'Limpieza desechable')}
})

$Script:BtnThemeEditorNew.Add_Click({try{$source=$Script:CmbThemeEditorSource.SelectedItem;if(-not$source){throw (L 'Choose a source scheme.' 'Elige un esquema de origen.')};$draft=New-PMMThemeDraft -SourceDefinition $source;Refresh-PMMThemeEditorCatalog;$Script:LstThemeDrafts.SelectedValue=[string]$draft.DraftId;Show-PMMThemeDraft $draft}catch{Handle-UIError $_ (L 'Create color-scheme draft' 'Crear borrador de esquema')}})
$Script:BtnThemeEditorLoad.Add_Click({try{$row=$Script:LstThemeDrafts.SelectedItem;if(-not$row){throw (L 'Select a draft.' 'Selecciona un borrador.')};$draft=Get-PMMThemeDraft ([string]$row.DraftId);if(-not$draft){throw (L 'Draft could not be read.' 'No se pudo leer el borrador.')};Show-PMMThemeDraft $draft}catch{Handle-UIError $_ (L 'Load color-scheme draft' 'Cargar borrador de esquema')}})
$Script:BtnThemeEditorSave.Add_Click({try{$Script:ActiveThemeDraft=Update-PMMThemeEditorDraftFromUi -Save;$Script:TxtThemeEditorStatus.Text=L 'Draft saved and validated locally.' 'Borrador guardado y validado localmente.'}catch{Handle-UIError $_ (L 'Save color-scheme draft' 'Guardar borrador de esquema')}})
$Script:BtnThemeEditorPreview.Add_Click({try{$Script:ActiveThemeDraft=Update-PMMThemeEditorDraftFromUi -Save;$definition=Get-PMMThemeDraftPreviewDefinition $Script:ActiveThemeDraft;Apply-PMMThemeDefinition $definition;$Script:ThemePreviewActive=$true;$Script:TxtThemeEditorStatus.Text=L 'Temporary whole-app preview is active. Revert or install it before closing.' 'Vista previa temporal activa en toda la aplicacion. Revierte o instala antes de cerrar.'}catch{Handle-UIError $_ (L 'Preview color scheme' 'Vista previa del esquema')}})
$Script:BtnThemeEditorRevert.Add_Click({try{Apply-PMMTheme ([string](Get-PMMConfig).Theme);$Script:ThemePreviewActive=$false;$Script:TxtThemeEditorStatus.Text=L 'Preview reverted to the saved Settings scheme.' 'Vista previa revertida al esquema guardado en Opciones.'}catch{Handle-UIError $_ (L 'Revert theme preview' 'Revertir vista previa')}})
$Script:BtnThemeEditorInstall.Add_Click({
  try{
    $draft=Update-PMMThemeEditorDraftFromUi -Save;$id=[string]$draft.ThemeId;$existing=@(Get-PMMUserThemeFiles|ForEach-Object{Read-PMMThemeFileIdentity $_.FullName}|Where-Object{$_ -and [string]$_.Id -ieq $id})
    $replace=$false;if($existing.Count -gt 0){$replace=Confirm ((L 'Replace the installed user scheme "{0}"? PMM will keep a backup.' 'Reemplazar el esquema del usuario "{0}"? PMM guardara un backup.') -f $id);if(-not$replace){return}}
    $result=Install-PMMThemeDraft $draft -AllowReplace:$replace;Refresh-PMMThemeOptions $id;Refresh-PMMThemeEditorCatalog;$Script:TxtThemeEditorStatus.Text=((L 'Scheme installed locally: {0}. It is now available in Settings under user schemes.' 'Esquema instalado localmente: {0}. Ya esta disponible en Opciones dentro de esquemas del usuario.') -f [string]$result.Path)
  }catch{Handle-UIError $_ (L 'Install color scheme' 'Instalar esquema de color')}
})
$Script:BtnThemeEditorExport.Add_Click({try{$draft=Update-PMMThemeEditorDraftFromUi -Save;$dialog=[System.Windows.Forms.FolderBrowserDialog]::new();$dialog.Description=L 'Choose the export folder' 'Elige la carpeta de exportacion';if($dialog.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK){return};$result=Export-PMMThemeDraft $draft ([string]$dialog.SelectedPath);$Script:TxtThemeEditorStatus.Text=((L 'Theme export created: {0}' 'Exportacion de tema creada: {0}') -f [string]$result.Path);Start-Process explorer.exe -ArgumentList ('/select,"'+[string]$result.Path+'"')}catch{Handle-UIError $_ (L 'Export color scheme' 'Exportar esquema de color')}})
$Script:BtnThemeEditorCreateAI.Add_Click({try{$draft=Update-PMMThemeEditorDraftFromUi -Save;$result=New-PMMThemeAIRequest $draft ([string]$Script:TxtThemeEditorPrompt.Text);$Script:TxtThemeEditorStatus.Text=((L 'Offline theme AI request created: {0}. Nothing was uploaded.' 'Peticion offline de tema para IA creada: {0}. No se subio nada.') -f [string]$result.Path);Start-Process explorer.exe -ArgumentList ('/select,"'+[string]$result.Path+'"')}catch{Handle-UIError $_ (L 'Create theme with AI' 'Crear tema con IA')}})
$Script:BtnThemeEditorImportAI.Add_Click({try{$dialog=[Microsoft.Win32.OpenFileDialog]::new();$dialog.Title=L 'Import AI theme response' 'Importar respuesta IA de tema';$dialog.Filter='PMM theme AI response (*.zip)|*.zip';if($dialog.ShowDialog() -ne $true){return};$result=Import-PMMThemeAIResponse ([string]$dialog.FileName);$Script:ActiveThemeDraft=$result.Draft;Refresh-PMMThemeEditorCatalog;$Script:LstThemeDrafts.SelectedValue=[string]$result.Draft.DraftId;Show-PMMThemeDraft $result.Draft;$Script:TxtThemeEditorStatus.Text=((L 'AI theme response validated into draft {0}. It is not installed; review and preview it first.' 'Respuesta IA de tema validada como borrador {0}. No esta instalada; revisala y previsualizala primero.') -f [string]$result.Draft.Name)}catch{Handle-UIError $_ (L 'Import AI theme response' 'Importar respuesta IA de tema')}})
$Script:BtnThemeEditorDelete.Add_Click({try{$row=$Script:LstThemeDrafts.SelectedItem;if(-not$row){return};if(Confirm ((L 'Delete draft "{0}" and its copied image assets? Installed themes are not affected.' 'Eliminar el borrador "{0}" y sus imagenes copiadas? No afecta a temas instalados.') -f [string]$row.Name)){Remove-PMMThemeDraft ([string]$row.DraftId);if($Script:ActiveThemeDraft -and [string]$Script:ActiveThemeDraft.DraftId -eq [string]$row.DraftId){$Script:ActiveThemeDraft=$null;$Script:PnlThemeEditorRows.Children.Clear()};Refresh-PMMThemeEditorCatalog}}catch{Handle-UIError $_ (L 'Delete theme draft' 'Eliminar borrador de tema')}})


# ---------------------------------------------------------------------------
# Settings.
# ---------------------------------------------------------------------------
$Script:BtnBuildGameReference.Add_Click({
  try{
    $cfg=Get-PMMConfig
    if(-not$cfg.GamePath){throw (L 'Configure Palworld first.' 'Configura Palworld primero.')}
    $gr=Get-PMMGameReferenceState
    if([string]$gr.Status -eq 'Current'){
      $question=L 'Rebuild the local Game Reference now? This reads Pal-Windows.pak in the background and replaces only PMM Workspace\GameReference. Palworld is never modified.' 'Volver a crear Game Reference local? Esto lee Pal-Windows.pak en segundo plano y solo sustituye PMM Workspace\GameReference. Palworld no se modifica.'
      if(-not(Confirm $question)){return}
    }
    # Game Reference is itself a workflow step. With Auto ON, a manual click
    # arms continuation; with one-shot AUTO already running, it preserves that
    # run and completion resumes from the new reference state.
    if(-not$Script:AutoPipelineActive -and [bool]$Script:TglAutoMode.IsChecked){Start-PMMAutoPipeline}
    $Script:GameReferenceResumeAuto=[bool]$Script:AutoPipelineActive
    $started=Start-PMMGameReferenceBuild
    if(-not$started -and $Script:GameReferenceResumeAuto){Write-PMMLog 'Manual Game Reference did not start; AUTO remains armed for the next valid workflow action.'}
  }catch{Handle-UIError $_ (L 'Build Game Reference' 'Crear Game Reference')}
})
$Script:BtnOpenGameReference.Add_Click({try{$p=Get-PMMGameReferenceRoot;if(-not(Test-Path -LiteralPath $p -PathType Container)){New-Item -ItemType Directory -Force -Path $p|Out-Null};Start-Process explorer.exe -ArgumentList ('"'+$p+'"')}catch{Handle-UIError $_ (L 'Open Game Reference' 'Abrir Game Reference')}})
$Script:BtnOpenKnowledge.Add_Click({try{Start-Process explorer.exe -ArgumentList ('"'+(Get-PMMPath 'CKL')+'"')}catch{Handle-UIError $_ (L 'Open Knowledge library' 'Abrir biblioteca Knowledge')}})
$Script:BtnOpenReviewCases.Add_Click({try{$p=Get-PMMPath 'Review';if(-not(Test-Path -LiteralPath $p -PathType Container)){New-Item -ItemType Directory -Force -Path $p|Out-Null};Start-Process explorer.exe -ArgumentList ('"'+$p+'"')}catch{Handle-UIError $_ (L 'Open AI review cases' 'Abrir casos para IA')}})
$Script:BtnExportKnowledgeContribution.Add_Click({
  try{
    $items=@(Get-PMMKnowledgeContributionCandidates)
    if($items.Count -eq 0){Show-Info (L 'No imported AI/manual solution is available yet. This button is used after PMM validates a returned solution and you test it successfully in Palworld.' 'Todavia no hay ninguna solucion IA/manual importada. Este boton se usa despues de que PMM valide una solucion devuelta y la pruebes correctamente en Palworld.');return}
    $chosen=$null
    if($items.Count -eq 1){$chosen=$items[0]}else{
      Add-Type -AssemblyName System.Windows.Forms
      $form=New-Object System.Windows.Forms.Form;$form.Text=L 'Choose tested AI/manual case' 'Elegir caso IA/manual probado';$form.Width=850;$form.Height=390;$form.StartPosition='CenterScreen'
      $label=New-Object System.Windows.Forms.Label;$label.Left=14;$label.Top=14;$label.Width=800;$label.Height=40;$label.Text=L 'Choose the solution you have already tested successfully in Palworld.' 'Elige la solucion que ya has probado correctamente dentro de Palworld.'
      $list=New-Object System.Windows.Forms.ListBox;$list.Left=14;$list.Top=58;$list.Width=805;$list.Height=235;$list.DisplayMember='Display'
      foreach($x in $items){[void]$list.Items.Add($x)};$list.SelectedIndex=0
      $ok=New-Object System.Windows.Forms.Button;$ok.Text='OK';$ok.Left=650;$ok.Top=305;$ok.Width=75;$ok.DialogResult=[System.Windows.Forms.DialogResult]::OK
      $cancel=New-Object System.Windows.Forms.Button;$cancel.Text=L 'Cancel' 'Cancelar';$cancel.Left=735;$cancel.Top=305;$cancel.Width=85;$cancel.DialogResult=[System.Windows.Forms.DialogResult]::Cancel
      $form.Controls.AddRange(@($label,$list,$ok,$cancel));$form.AcceptButton=$ok;$form.CancelButton=$cancel
      if($form.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK){return};$chosen=$list.SelectedItem
    }
    if(-not$chosen){return}
    $warning=L "Only create a runtime contribution after you tested this exact imported solution in Palworld and the expected behaviors worked. Mark this case as a user-reported runtime PASS and package it for maintainer/community validation?`n`nThe package can contain the original AIIO handoff, returned solution and validation/runtime evidence. Whole source mod PAKs are not copied into it. Send it to the PMM maintainer/approved private intake.`n`nThis does NOT auto-authorize a Knowledge recipe on this PC." "Crea una contribucion runtime solo despues de probar esta solucion importada exacta dentro de Palworld y confirmar los comportamientos esperados. Marcar este caso como PASS runtime reportado por el usuario y empaquetarlo para validacion comunitaria/mantenedor?`n`nEl paquete puede contener la entrega AIIO original, la solucion devuelta y la evidencia de validacion/runtime. No se copian PAK fuente completos dentro del paquete. Envialo al mantenedor/servicio privado aprobado de PMM.`n`nEsto NO autoriza automaticamente una receta Knowledge en este PC."
    if(-not(Confirm $warning)){return}
    $zip=Export-PMMKnowledgeContribution ([string]$chosen.CaseId)
    $Script:TxtStatus.Text=((L 'Contribution package created: {0}' 'Paquete de contribucion creado: {0}') -f $zip)
    Start-Process explorer.exe -ArgumentList ('/select,"'+$zip+'"')
  }catch{Handle-UIError $_ (L 'Create Knowledge contribution' 'Crear contribucion Knowledge')}
})
$Script:BtnOpenKnowledgeContributions.Add_Click({try{$p=Get-PMMKnowledgeContributionRoot;Start-Process explorer.exe -ArgumentList ('"'+$p+'"')}catch{Handle-UIError $_ (L 'Open contribution folder' 'Abrir carpeta de contribuciones')}})
$Script:BtnSetupDeps.Add_Click({ try { & (Join-Path $Script:Root 'Modules\Bootstrap\Setup-Dependencies.ps1'); Refresh-UI; $Script:TxtStatus.Text=L 'Dependency preparation finished.' 'Proceso de dependencias terminado.' } catch { Handle-UIError $_ (L 'Dependency preparation' 'Preparacion de dependencias') } })
$Script:BtnApplyLanguage.Add_Click({
  try {
    $cfg = Get-PMMConfig
    $selectedCode = [string]$Script:CmbLanguage.SelectedValue
    $cfg.Language = if ($selectedCode -eq 'es') { 'es' } else { 'en' }
    Save-PMMConfig $cfg
    $Script:TxtStatus.Text=L 'Language saved. Restart Palworld Manager Merger to apply it to the entire interface.' 'Idioma guardado. Reinicia Palworld Manager Merger para aplicarlo a toda la interfaz.'
  } catch { Handle-UIError $_ 'Language' }
})

$Script:BtnResetLayout.Add_Click({
  try {
    Reset-PMMLayout
    $Script:TxtStatus.Text=L 'Workspace layout reset. The new divider positions will be remembered.' 'Distribucion restablecida. Las nuevas posiciones de los divisores se recordaran.'
  } catch { Handle-UIError $_ (L 'Reset workspace layout' 'Restablecer distribucion') }
})

# Re-evaluate externally changed game PAKs when the user returns to PMM. A
# lightweight metadata heartbeat below also covers changes made while PMM stays
# focused (downloads/mod managers/background copies). It never hashes unless the
# higher-level state logic finds evidence that a same-size deployed file changed.
$Window.Add_Activated({try{Check-PMMExternalModChanges -Force}catch{}})
$Script:ExternalModsTimer=[System.Windows.Threading.DispatcherTimer]::new([System.Windows.Threading.DispatcherPriority]::Background)
$Script:ExternalModsTimer.Interval=[TimeSpan]::FromSeconds(10)
$Script:ExternalModsTimer.Add_Tick({try{Check-PMMExternalModChanges}catch{}})
$Script:ExternalModsTimer.Start()

$Window.Add_Closing({
  try { if($Script:ExternalModsTimer){$Script:ExternalModsTimer.Stop()} } catch {}
  try { Save-DecisionGridToPlan -Silent } catch {}
  try { Save-UiSettings } catch {}
  try { Save-PMMLayoutSettings } catch {}
  try { Stop-PMMBackgroundOperation -Silent } catch {}
  try { Stop-PMMGameReferenceBuild -Silent } catch {}
})

# Automatic startup detection happens after WPF renders so slow drive scanning
# has visible status feedback.
$Script:StartupDetectionDone = $false
$Window.Add_ContentRendered({
  if ($Script:StartupDetectionDone) { return }
  $Script:StartupDetectionDone = $true

  # Do not retire the native splash merely because WPF painted its first frame.
  # Wait until the dispatcher reaches idle, force the top-level HWND into a
  # normal visible/activated state, then give PMM.exe the exact HWND so the host
  # can transfer foreground ownership before destroying the splash. This avoids
  # the brief taskbar gap / Explorer focus steal seen on Windows 10.
  [void]$Window.Dispatcher.BeginInvoke(
    [System.Action]{
      try {
        $Window.ShowInTaskbar = $true
        $Window.ShowActivated = $true
        $interop = [System.Windows.Interop.WindowInteropHelper]::new($Window)
        $hwnd = $interop.Handle
        if ($hwnd -eq [IntPtr]::Zero) { $hwnd = $interop.EnsureHandle() }
        [void][PMMShellIdentity]::ShowWindow($hwnd,5)
        [void]$Window.Activate()
        [void]$Window.Focus()
        [void][PMMShellIdentity]::BringWindowToTop($hwnd)
        [void][PMMShellIdentity]::SetForegroundWindow($hwnd)
        Set-PMMHostStartupState ("startup:UI-shell-ready:{0}" -f $hwnd.ToInt64())
      } catch {
        Write-PMMLog ("Could not complete PMM shell handoff: {0}" -f $_.Exception.Message)
        Set-PMMHostStartupState 'startup:UI-ready'
      }

      try {
        $cfg = Get-PMMConfig
        $valid = $null
        if ($cfg.GamePath) { $valid = Resolve-PalworldRoot ([string]$cfg.GamePath) }
        if ($valid) {
          if ([string]$cfg.GamePath -cne [string]$valid) { $cfg.GamePath=$valid; Save-PMMConfig $cfg }
          Refresh-UI
        } else {
          Invoke-PMMGameDetection $false | Out-Null
        }
      } catch {
        Write-PMMLog ("Automatic startup game detection failed: {0}" -f $_.Exception.Message)
        Refresh-UI
      }
      try{Check-PMMExternalModChanges -Force}catch{}
    },
    [System.Windows.Threading.DispatcherPriority]::ApplicationIdle
  )
})

Refresh-UI
if (-not $autoDepsOk) {
  Show-Info (L 'Some dependencies are still unavailable. Restart PMM.exe or use Settings > Prepare / repair dependencies.' 'Aun faltan algunas dependencias. Reinicia PMM.exe o usa Configuracion > Preparar / reparar dependencias.')
}
$uiExitState='Normal'
try {
  [void]$Window.ShowDialog()
} catch {
  $uiExitState='Failed'
  try{Write-PMMLog ("UNHANDLED UI exception: {0}`n{1}" -f $_.Exception.Message,$_.ScriptStackTrace)}catch{}
  throw
} finally {
  Stop-PMMLogSession $uiExitState
}
