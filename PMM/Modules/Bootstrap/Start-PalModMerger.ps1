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
. (Join-Path $Script:Root 'Modules\AIIO\AIIO.ModCreationService.ps1')
. (Join-Path $Script:Root 'Modules\AIIO\AIIO.ResponseService.ps1')
. (Join-Path $Script:Root 'Modules\AIIO\AIIO.ArtifactService.ps1')
. (Join-Path $Script:Root 'Modules\AIIO\AIIO.ValidationService.ps1')
. (Join-Path $Script:Root 'Modules\Theme\ThemeEditorService.ps1')
. (Join-Path $Script:Root 'Modules\CKL\KnowledgeContributionService.ps1')
. (Join-Path $Script:Root 'Modules\Workbench.Services.ps1') -Profile UI

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
  'TabAIHelp','BrdAIHelpBadge','TxtAIHelpBadge','AIHelpTabs','LstAIHelpDiagnostics','BtnAIHelpRefresh','BtnAIHelpNewCase','BtnAIHelpNewModProject','BtnAIHelpPrepareDiagnostic','PnlAIHelpSelectedCase','PnlAIHelpNewCase','TxtAIHelpSelectedCaseTitle','TxtAIHelpSelectedCaseMeta','TxtAIHelpSelectedCaseDescription','CmbAIHelpDiagnosticType','TxtAIHelpDiagnosticTitle','TxtAIHelpDiagnosticDescription','ChkAIHelpIncludePalLog','BtnAIHelpCreateCase','BtnAIHelpCreateAndPrepareCase','BtnAIHelpCancelNewCase','TxtAIHelpDiagnosticStatus',
  'LstAIIOSessions','LstAIIOCandidates','TxtAIIOCandidateStatus','BtnAIIOOpenWorkspace','BtnAIIOOpenHandoff','BtnAIIOArchive','BtnAIIOOpenCandidate','BtnAIIOUseCandidate','CmbAIIOType','TxtAIIOTitle','TxtAIIODescription','CmbAIOTargetKind','TxtAIOTargetId','BtnAIIONewSession','BtnAIIOPrepare','BtnAIIOImportResponse','BtnAIIOContinue','TxtAIIOStatus',
  'CmbAIHelpFeedbackType','TxtAIHelpFeedbackTitle','TxtAIHelpFeedbackComments','CmbAIHelpFeedbackBuild','BtnAIHelpCreateFeedback','BtnAIHelpGenerateFeedback','BtnAIHelpOpenFeedback','BtnAIHelpUploadFeedback','TxtAIHelpFeedbackStatus',
  'TxtAIHelpKnowledgeSummary','BtnAIHelpOpenKnowledge','TxtAIHelpStorageSummary','LstAIHelpInterrupted','BtnAIHelpRefreshKnowledge','BtnAIHelpCleanup','ChkAIIOAutoCreateErrorCases','TxtAIIOSettingsStatus',
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
$Script:ActiveThemeId=''
$Script:ActiveThemeColorFlow=$null
$Script:ActiveThemeDefinition=$null
$Script:ThemeFallbackNotice=''

. (Join-Path $Script:Root 'Modules\Presentation\Theme.UI.ps1')

. (Join-Path $Script:Root 'Modules\Presentation\Assistance.UI.ps1')

. (Join-Path $Script:Root 'Modules\Presentation\FixLab.UI.ps1')

. (Join-Path $Script:Root 'Modules\Workflow\GuidedFlow.ps1')

. (Join-Path $Script:Root 'Modules\Presentation\Layout.UI.ps1')

. (Join-Path $Script:Root 'Modules\Presentation\Operations.UI.ps1')

. (Join-Path $Script:Root 'Modules\Presentation\Library.UI.ps1')

. (Join-Path $Script:Root 'Modules\Presentation\Shell.Actions.ps1')

. (Join-Path $Script:Root 'Modules\Presentation\Library.Actions.ps1')

. (Join-Path $Script:Root 'Modules\Presentation\Assistance.Actions.ps1')

# Re-evaluate externally changed game PAKs when the user returns to PMM. A
# lightweight metadata heartbeat below also covers changes made while PMM stays
# focused (downloads/mod managers/background copies). It never hashes unless the
# higher-level state logic finds evidence that a same-size deployed file changed.
$Window.Add_Activated({try{Check-PMMExternalModChanges}catch{}})
$Script:ExternalModsTimer=[System.Windows.Threading.DispatcherTimer]::new([System.Windows.Threading.DispatcherPriority]::Background)
$Script:ExternalModsTimer.Interval=[TimeSpan]::FromSeconds(60)
$Script:ExternalModsTimer.Add_Tick({
  try{
    if(-not[bool]$Window.IsActive -or $Window.WindowState -eq [System.Windows.WindowState]::Minimized){return}
    if(-not[string]::IsNullOrWhiteSpace((Get-PMMActiveProcessingOperation))){return}
    Check-PMMExternalModChanges
  }catch{}
})
try{$Script:GameModsFingerprint=Get-PMMGameModsFingerprint;$Script:LastExternalModsCheckUtc=[DateTime]::UtcNow}catch{}
$Script:ExternalModsTimer.Start()

$Window.Add_Closing({
  try { if($Script:ExternalModsTimer){$Script:ExternalModsTimer.Stop()} } catch {}
  try { Save-DecisionGridToPlan -Silent } catch {}
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
. (Join-Path $Script:Root 'Modules\MCP\MCP.UI.ps1')
. (Join-Path $Script:Root 'Modules\Unreal\Dependencies.UI.ps1')
. (Join-Path $Script:Root 'Modules\AIIO\AIIO.Workspaces.UI.ps1')
Initialize-PMMWorkspaces
. (Join-Path $Script:Root 'Modules\Presentation\Workbench.UI.ps1')
. (Join-Path $Script:Root 'Modules\Presentation\Workbench.Actions.ps1')
Initialize-PMMModuleRuntime -Root $Script:Root | Out-Null
Initialize-PMMWorkbench
Start-PMMWorkbenchObservation
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
