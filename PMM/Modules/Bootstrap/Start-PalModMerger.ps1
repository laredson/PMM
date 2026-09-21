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

. (Join-Path $Script:Root 'Modules\Presentation\Assistance.Actions.ps1')
. (Join-Path $Script:Root 'Modules\Presentation\Assistance.UI.ps1')
. (Join-Path $Script:Root 'Modules\Presentation\FixLab.UI.ps1')
. (Join-Path $Script:Root 'Modules\Presentation\Layout.UI.ps1')
. (Join-Path $Script:Root 'Modules\Presentation\Legacy.UI.ps1')
. (Join-Path $Script:Root 'Modules\Presentation\Library.Actions.ps1')
. (Join-Path $Script:Root 'Modules\Presentation\Library.UI.ps1')
. (Join-Path $Script:Root 'Modules\Presentation\Operations.UI.ps1')
. (Join-Path $Script:Root 'Modules\Presentation\Shell.Actions.ps1')
. (Join-Path $Script:Root 'Modules\Presentation\Theme.UI.ps1')
. (Join-Path $Script:Root 'Modules\Workflow\GuidedFlow.ps1')
. (Join-Path $Script:Root 'Modules\Workbench.Services.ps1') -Profile UI
function L([string]$English,[string]$Spanish){ return Get-PMMText $English $Spanish }
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
$lang = Resolve-PMMLanguageCode ([string]$startupCfg.Language)
$xamlPath = Get-PMMLanguageXamlPath $lang
try {
  $xamlText=Get-Content -LiteralPath $xamlPath -Raw -Encoding UTF8
  if($lang -ne 'en' -and [IO.Path]::GetFileName($xamlPath) -ieq 'MainWindow.en.xaml'){$xamlText=Convert-PMMXamlLocalization $xamlText $lang}
  [xml]$xaml=$xamlText
  $reader = New-Object System.Xml.XmlNodeReader $xaml
  $Window = [Windows.Markup.XamlReader]::Load($reader)
  Set-PMMLanguageDirection $Window $lang
  $versionPath=Join-Path $Script:Root 'Resources/Metadata/VERSION.txt'
  $Window.Title='PMM - Palworld Manager Merger v'+([IO.File]::ReadAllText($versionPath).Trim())
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
$Script:LanguageOptions=@(Get-PMMLanguageOptions)
$Script:CmbLanguage.ItemsSource=$Script:LanguageOptions

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

# ---------------------------------------------------------------------------
# AI & Help: local-first sessions, diagnostics, Knowledge and theme editor.
# ---------------------------------------------------------------------------
$Script:AIHelpLoaded=$false
$Script:AIIOBusy=$false
$Script:AIHelpUiRefreshing=$false
$Script:ThemeEditorUiBuilding=$false
$Script:AIHelpNewCaseMode=$false
$Script:ActiveThemeDraft=$null
$Script:ThemeEditorRowControls=@{}
$Script:ThemeEditorDirtyFields=[Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
$Script:ThemePreviewActive=$false

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

Set-PMMFixLabControlsEnabled $false
$Script:TxtFixLabAnalysis.Text=L 'Fix Lab will load only when this tab is opened.' 'Fix Lab se cargara solo cuando abras esta pestana.'
Initialize-PMMAIHelpUi
$Script:MainTabs.Add_SelectionChanged({
  param($sender,$e)
  try{
    # SelectionChanged is a routed event. Ignore ComboBox/ListBox changes that
    # bubble out of the selected tab; rebinding AI controls while their popup
    # is open was the reason the Feedback merge selector appeared to reset.
    if($e.OriginalSource -ne $sender){return}
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
    if(Test-PMMFixLabTabSelected){
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
$Script:AIHelpTabs.Add_SelectionChanged({
  param($sender,$e)
  try{
    if($e.OriginalSource -ne $sender){return}
    [void]$Window.Dispatcher.BeginInvoke([System.Action]{try{Refresh-PMMAIHelpUi}catch{Write-PMMLog ('AI & Help section refresh failed: '+$_.Exception.Message)}},[System.Windows.Threading.DispatcherPriority]::ContextIdle)
  }catch{Write-PMMLog ('AI & Help navigation warning: '+$_.Exception.Message)}
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
$Script:LastExternalModsCheckUtc=[DateTime]::MinValue
$Script:ExternalModsTimer=$null
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

$Script:UniversalProgressOperation=''
$Script:UniversalProgressFraction=0.0
$Script:UniversalProgressMessage=''
$Script:ProgressAnimationStates=@{}
$Script:ProgressAnimationTimer=$null

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

# Fix Lab workflow guidance is resolved exclusively by Get-PMMWorkflowState.

# Legacy AUTO/Fix Lab routing removed in RC6. Get-PMMWorkflowState is the single workflow authority.

$Script:ResponsiveLayoutNarrow=$false
$Script:ResponsiveHeaderStacked=$false
$Script:ResponsiveSavedLibraryWidth=470.0

Apply-PMMLayoutFromConfig
$Window.Add_SizeChanged({Update-PMMResponsiveLayout})
# The 500 ms dispatcher watchdog was diagnostic instrumentation, not product
# work. Leaving it armed for the full lifetime of an idle window caused an
# unnecessary permanent wake-up. Operation-specific timers still report and
# stop with their operation.
Update-PMMWorkspaceRows

# ---------------------------------------------------------------------------
# Workflow progress. Import / Analyze / Build / Deploy reuse their own button
# as the local progress surface. A persistent universal progress bar below
# Build/Deploy mirrors the same real progress and keeps the last completed 100%
# result until a new operation starts. Legacy per-panel bars stay hidden except
# where an advanced workspace explicitly needs them.
# ---------------------------------------------------------------------------


$Script:AnalyzeBusy=$false

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

# ---------------------------------------------------------------------------
# Conflict workspace helpers.
# ---------------------------------------------------------------------------
$Script:LoadingConflictView = $false
$Script:CurrentConflictAssetKey = ''
$Script:LastConflictPlanCreated = ''
$Script:CurrentUnsupportedAssetKey = ''

$Script:LibraryDisplayItems=@()
$Script:PriorityDragStartPoint=$null
$Script:PriorityDragName=''
$Script:PriorityEditorCommitInProgress=$false
$Script:ModListScrollViewer=$null

# ---------------------------------------------------------------------------
# General UI refresh / errors / game detection.
# ---------------------------------------------------------------------------

$Script:HandlingUIError=$false

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
    $enabled=[bool]$Script:TglAutoMode.IsChecked;Save-PMMAutoPreferences
    if(-not$enabled){Stop-PMMAutoPipeline (L 'SemiAUTO is disabled. Manual actions perform one workflow step per click.' 'SemiAUTO esta desactivado. Las acciones manuales hacen un paso del flujo por clic.')}
    else{$Script:TxtStatus.Text=L 'SemiAUTO armed. The next workflow action you start manually will continue through the remaining safe steps.' 'SemiAUTO preparado. La siguiente accion del flujo que inicies manualmente continuara por los pasos seguros restantes.';Update-PMMCancelButtonState}
  }catch{Handle-UIError $_ (L 'Automatic mode' 'Modo automatico')}
})
$Script:ChkAutoPlay.Add_Click({try{Save-PMMAutoPreferences;Update-PMMGuidedActionState}catch{}})
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
    Apply-PMMTheme (Get-PMMSelectedThemeId) -Force
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
$Script:ChkAIIOAutoCreateErrorCases.Add_Click({if(-not$Script:UiSettingsRefreshing){try{Save-PMMAIHelpSettings;$Script:TxtAIIOSettingsStatus.Text=L 'AI & Help settings saved.' 'Ajustes de IA y ayuda guardados.'}catch{Handle-UIError $_ (L 'Save AI & Help settings' 'Guardar ajustes de IA y ayuda')}}})
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
    Update-PMMValidatedPatchRow $entry $record.Summary
    if($result -in @('PASS','PASS_RECONFIRMED') -and (Show-PMMValidationContributionDialog)){Open-PMMValidationFeedbackForPatch $entry.Patch}
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

# Compatibility entrypoint retained for older UI integrations; it opens the case.


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

$Script:ExpSelectedSave.Add_Expanded({Update-PMMSavePaneRows});$Script:ExpSelectedSave.Add_Collapsed({Update-PMMSavePaneRows})
$Script:ExpSaveBackups.Add_Expanded({Update-PMMSavePaneRows});$Script:ExpSaveBackups.Add_Collapsed({Update-PMMSavePaneRows})
Update-PMMSavePaneRows

$Script:LstSaves.Add_SelectionChanged({try{$save=$Script:LstSaves.SelectedItem;if($save){$Script:TxtSaveDetails.Text=(Get-PMMSaveDetails $save|Out-String);$Script:ExpSelectedSave.Header=((L 'Selected save - {0}' 'Save seleccionado - {0}') -f [string]$save.WorldName)};Refresh-PMMSaveBackupPane}catch{$Script:TxtSaveDetails.Text=$_.Exception.Message}})
$Script:LstSaveBackups.Add_SelectionChanged({try{$row=$Script:LstSaveBackups.SelectedItem;$Script:TxtSaveBackupDetails.Text=Get-PMMSaveBackupDetails $row $Script:LstSaves.SelectedItem;$Script:BtnRestoreSave.IsEnabled=($null -ne $row);$Script:BtnOpenSaveBackupFolder.IsEnabled=($null -ne $row)}catch{$Script:TxtSaveBackupDetails.Text=$_.Exception.Message}})
$Script:BtnBackupSave.Add_Click({try{$save=$Script:LstSaves.SelectedItem;if(-not$save){throw(L 'Select a world.' 'Selecciona un mundo.')};$path=Backup-PMMSave $save;$when=(Get-Date).ToString('yyyy-MM-dd HH:mm:ss');$msg=((L 'Backup created successfully' 'Backup creado correctamente')+' - '+$when+' | '+[IO.Path]::GetFileName($path));$Script:TxtStatus.Text=$msg;$Script:TxtSaveBackupStatus.Text=$msg;$Script:TxtSaveBackupStatus.Foreground=$Window.Resources['AccentHeadingGreen'];$Script:TxtSaveBackupStatus.ToolTip=$path;Refresh-PMMSaveBackupPane;Notify-PMMWorkflowStepComplete}catch{Handle-UIError $_ (L 'Save backup' 'Backup de save')}})
$Script:BtnRestoreSave.Add_Click({try{$save=$Script:LstSaves.SelectedItem;if(-not$save){throw(L 'Select a world.' 'Selecciona un mundo.')};$row=$Script:LstSaveBackups.SelectedItem;if(-not$row){throw(L 'Select a PMM backup from the Backups made panel.' 'Selecciona un backup PMM en el panel Backups creados.')};if(Confirm(L 'Restoring this backup will replace the current world. PMM will create a safety backup first. Continue?' 'Restaurar este backup reemplazara el mundo actual. PMM creara antes un backup de seguridad. Continuar?')){[void](Restore-PMMSaveFromArchive $save ([string]$row.Path));Refresh-UI;$Script:TxtStatus.Text=L 'Save restored. A safety backup was created automatically before restore.' 'Save restaurado. Se creo automaticamente un backup de seguridad antes de restaurar.';Notify-PMMWorkflowStepComplete}}catch{Handle-UIError $_ (L 'Save restore' 'Restaurar save')}})
$Script:BtnOpenSaveBackupFolder.Add_Click({try{$row=$Script:LstSaveBackups.SelectedItem;if($row){Start-Process explorer.exe -ArgumentList ('/select,"'+[string]$row.Path+'"')}else{$save=$Script:LstSaves.SelectedItem;if(-not$save){return};$dir=Join-Path (Join-PMMPath 'Saves' 'Backups') ([string]$save.Name);New-Item -ItemType Directory -Force -Path $dir|Out-Null;Start-Process explorer.exe -ArgumentList ('"'+$dir+'"')}}catch{Handle-UIError $_ (L 'Open backup folder' 'Abrir carpeta de backups')}})


# ---------------------------------------------------------------------------
# AI & Help.
# ---------------------------------------------------------------------------

$Script:BtnAIHelpRefresh.Add_Click({try{Refresh-PMMAIHelpDiagnostics;Refresh-PMMAIHelpBadge;$Script:TxtAIHelpDiagnosticStatus.Text=L 'Cases refreshed.' 'Casos actualizados.'}catch{Handle-UIError $_ (L 'Refresh AI assistance' 'Actualizar ayuda IA')}})
$Script:LstAIHelpDiagnostics.Add_SelectionChanged({try{if(-not[bool]$Script:AIHelpUiRefreshing){$Script:AIHelpNewCaseMode=$false;Update-PMMAIHelpDiagnosticSelection}}catch{}})
$Script:BtnAIHelpNewCase.Add_Click({try{Set-PMMAIHelpNewCaseMode $true -Clear;try{$Script:TxtAIHelpDiagnosticTitle.Focus()|Out-Null}catch{}}catch{Handle-UIError $_ (L 'Open new AI assistance case' 'Abrir nuevo caso de ayuda IA')}})
$Script:BtnAIHelpNewModProject.Add_Click({
  try{
    $project=Show-PMMModCreationProjectDialog;if(-not$project){return}
    $targets=@();if(-not[string]::IsNullOrWhiteSpace([string]$project.TargetHint)){$targets=@([pscustomobject]@{Kind='GameReferenceSearchHint';Id=[string]$project.TargetHint;UserSuspects=$false;CauseConfirmed=$false})}
    $case=Get-OrCreate-PMMOriginCase -Origin ModCreation -SourceId ([guid]::NewGuid().ToString('N')) -Type NEW_MOD -Title ([string]$project.Title) -Description ([string]$project.Description) -Context ([ordered]@{SelectedTargets=$targets})
    Select-PMMCaseLocation $case
  }catch{Handle-UIError $_ (L 'Create standalone mod project' 'Crear proyecto independiente de mod')}
})
$Script:BtnAIHelpCancelNewCase.Add_Click({try{Set-PMMAIHelpNewCaseMode $false}catch{}})
$Script:BtnAIHelpRefreshKnowledge.Add_Click({try{$done={param($result) Refresh-PMMAIHelpKnowledge;Refresh-PMMAIHelpBadge};[void](Start-PMMBackgroundOperation -Operation AIIOArtifactRefresh -OnSuccess $done)}catch{Handle-UIError $_ (L 'Refresh Knowledge and storage' 'Actualizar Knowledge y almacenamiento')}})

$Script:BtnAIHelpCreateCase.Add_Click({try{[void](New-PMMAIHelpCaseFromUi)}catch{Handle-UIError $_ (L 'Create diagnostic case' 'Crear caso de diagnostico')}})
$Script:BtnAIHelpCreateAndPrepareCase.Add_Click({
  try{
    $case=New-PMMAIHelpCaseFromUi
    if($case){$Script:BtnAIHelpPrepareDiagnostic.RaiseEvent([System.Windows.RoutedEventArgs]::new([System.Windows.Controls.Button]::ClickEvent))}
  }catch{Handle-UIError $_ (L 'Create and open case' 'Crear y abrir caso')}
})
$Script:BtnAIHelpPrepareDiagnostic.Content=L 'Open case' 'Abrir caso'
$Script:BtnAIHelpCreateAndPrepareCase.Content=L 'Create and open case' 'Crear y abrir caso'
$Script:BtnAIHelpPrepareDiagnostic.Add_Click({
  try{
    $row=$Script:LstAIHelpDiagnostics.SelectedItem;if(-not$row){throw (L 'Select a diagnostic case.' 'Selecciona un caso de diagnostico.')}
    $diagnostic=Get-Content -LiteralPath (Get-PMMDiagnosticCasePath ([string]$row.CaseId)) -Raw -Encoding UTF8|ConvertFrom-Json
    Select-PMMCaseLocation (Sync-PMMDiagnosticToCase $diagnostic)
  }catch{Handle-UIError $_ (L 'Open diagnostic case' 'Abrir caso de diagnostico')}
})
$Script:LstAIIOSessions.Add_SelectionChanged({
  try{
    if([bool]$Script:AIHelpUiRefreshing){return}
    $session=Get-PMMSelectedAIIOSession
    if($session){Refresh-PMMAIIOCandidates ([string]$session.SessionId);$Script:TxtAIIOStatus.Text=((L 'Session {0} - {1} - iteration {2}. Returned candidates remain staged until you explicitly review and act.' 'Sesion {0} - {1} - iteracion {2}. Los candidatos devueltos quedan en staging hasta que los revises y actues expresamente.') -f [string]$session.SessionId,[string]$session.Status,[int]$session.Iteration)}
    Update-PMMAIIOHandoffButton
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
    $case=Get-OrCreate-PMMOriginCase -Origin Help -SourceId ([guid]::NewGuid().ToString('N')) -Title $title -Description ([string]$Script:TxtAIIODescription.Text) -Context ([ordered]@{TaskType=$type;SelectedTargets=$targets})
    Select-PMMCaseLocation $case
  }catch{Handle-UIError $_ (L 'Create case' 'Crear caso')}
})
$Script:BtnAIIOPrepare.Add_Click({
  try{
    $session=Get-PMMSelectedAIIOSession
    if(-not$session){throw (L 'Select a case first.' 'Selecciona primero un caso.')}
    Initialize-PMMAIIOCasesFromLegacySessions;Initialize-PMMCaseContracts
    $case=@(Get-PMMAIIOCases|Where-Object{[string]$_.LegacySessionId -ceq [string]$session.SessionId}|Select-Object -First 1)
    if($case.Count){Select-PMMCaseLocation $case[0]}
  }catch{Handle-UIError $_ (L 'Open case' 'Abrir caso')}
})
$Script:BtnAIIOImportResponse.Add_Click({
  try{
    $dialog=[Microsoft.Win32.OpenFileDialog]::new();$dialog.Title=L 'Import AI response ZIP' 'Importar ZIP de respuesta IA';$dialog.Filter='PMM AI response (*.zip)|*.zip'
    if($dialog.ShowDialog() -ne $true){return}
    $zipPath=[string]$dialog.FileName;$hint=Get-PMMAIIOResponsePackageHint $zipPath;$session=$null
    if([string]$hint.Kind -eq 'ThemeResponse'){
      $result=Import-PMMThemeAIResponse $zipPath
      $Script:ActiveThemeDraft=$result.Draft;Refresh-PMMThemeEditorCatalog -Force;$Script:LstThemeDrafts.SelectedValue=[string]$result.Draft.DraftId;Show-PMMThemeDraft $result.Draft
      $Script:AIHelpTabs.SelectedItem=$Script:PMMHelpThemeTab
      $Script:TxtThemeEditorStatus.Text=((L 'Standalone AI theme validated into draft {0}. It remains uninstalled until you review and explicitly install it.' 'Tema IA independiente validado como borrador {0}. Sigue sin instalar hasta que lo revises y lo instales expresamente.') -f [string]$result.Draft.Name)
      return
    }
    if([string]$hint.SessionId){$session=Get-PMMAIIOSession ([string]$hint.SessionId)}
    elseif([string]$hint.CaseId){
      foreach($candidate in @(Get-PMMAIIOSessions|Where-Object{-not[bool]$_.Archived})){
        $full=Get-PMMAIIOSession ([string]$candidate.SessionId)
        if($full -and [string]$hint.CaseId -in @($full.CaseIds|ForEach-Object{[string]$_})){$session=$full;break}
      }
      if(-not$session){$session=Get-PMMSelectedAIIOSession}
    }
    if(-not$session){throw (L 'PMM could not match this package to a known AI exchange. Standard responses route themselves by their embedded session id; standalone cooked solutions still require their exact existing case.' 'PMM no pudo relacionar este paquete con un intercambio IA conocido. Las respuestas estandar se enrutan solas por su id de sesion; las soluciones cooked independientes aun necesitan su caso exacto existente.')}
    $sessionId=[string]$session.SessionId
    Select-PMMAIIOUiSession $sessionId
    $done={param($result) Complete-PMMAIIOImportResponseUi $result $sessionId}.GetNewClosure()
    [void](Start-PMMBackgroundOperation -Operation AIIOImportResponse -SessionId $sessionId -InputZip $zipPath -OnSuccess $done)
  }catch{Handle-UIError $_ (L 'Import AI response' 'Importar respuesta IA')}
})
$Script:BtnAIIOContinue.Add_Click({
  try{$session=Get-PMMSelectedAIIOSession;if(-not$session){throw (L 'Select a session.' 'Selecciona una sesion.')};$sessionId=[string]$session.SessionId;$done={param($result) Complete-PMMAIIOPendingDataUi $result $sessionId}.GetNewClosure();[void](Start-PMMBackgroundOperation -Operation AIIOPendingData -SessionId $sessionId -OnSuccess $done)}catch{Handle-UIError $_ (L 'Prepare requested AI data' 'Preparar datos pedidos por IA')}
})
$Script:BtnAIIOArchive.Add_Click({try{$session=Get-PMMSelectedAIIOSession;if(-not$session){return};if(Confirm ((L 'Archive session {0}? Its history and artifacts remain on disk.' 'Archivar la sesion {0}? Su historial y artefactos seguiran guardados.') -f [string]$session.SessionId)){Set-PMMAIIOSessionArchived ([string]$session.SessionId) $true|Out-Null;Refresh-PMMAIHelpUi}}catch{Handle-UIError $_ (L 'Archive AIIO session' 'Archivar sesion AIIO')}})
$Script:BtnAIIOOpenWorkspace.Add_Click({try{$session=Get-PMMSelectedAIIOSession;$path=if($session){Get-PMMAIIOSessionPath ([string]$session.SessionId)}else{Get-PMMPath 'AIIO'};Start-Process explorer.exe -ArgumentList ('"'+$path+'"')}catch{Handle-UIError $_ (L 'Open AI workspace' 'Abrir espacio de IA')}})
$Script:BtnAIIOOpenHandoff.Add_Click({try{$session=Get-PMMSelectedAIIOSession;if(-not$session){throw (L 'Select an AI exchange first.' 'Selecciona primero un intercambio IA.')};$path=[string](Get-PMMAIIOLatestHandoffPath ([string]$session.SessionId));if([string]::IsNullOrWhiteSpace($path)){throw (L 'The selected exchange does not have an available handoff ZIP.' 'El intercambio seleccionado no tiene un ZIP handoff disponible.')};Start-Process explorer.exe -ArgumentList ('/select,"'+$path+'"')}catch{Handle-UIError $_ (L 'Open latest AI handoff' 'Abrir ultimo handoff IA')}})
$Script:BtnAIIOOpenCandidate.Add_Click({try{$row=$Script:LstAIIOCandidates.SelectedItem;if(-not$row){return};Start-Process explorer.exe -ArgumentList ('"'+[string]$row.Root+'"')}catch{Handle-UIError $_ (L 'Inspect AI candidate' 'Inspeccionar candidato IA')}})
$Script:BtnAIIOUseCandidate.Add_Click({
  try{
    $session=Get-PMMSelectedAIIOSession;$row=$Script:LstAIIOCandidates.SelectedItem
    if(-not$session -or -not$row){throw (L 'Select a session and candidate.' 'Selecciona una sesion y un candidato.')}
    if([string]$row.InputSchema -eq 'PMM_MOD_CREATION_CANDIDATE_V1'){
      $warning=L "Build this standalone mod candidate?`n`nPMM will verify the staged bytes again, require the exact current Vanilla GameReference identity, run a read-only AssetReader probe on every returned asset header, pack only the declared cooked tree plus inert PMM attribution metadata, and verify every PAK entry. The PAK will remain local, undeployed, unpublished and runtime UNPROVEN.`n`nYou must test it in Palworld. If you share or publish it, its public description must include: This mod was created with PMM assistance.`n`nContinue?" "Crear este candidato de mod independiente?`n`nPMM volvera a verificar los bytes en staging, exigira la identidad exacta de la GameReference Vanilla vigente, ejecutara una prueba de solo lectura con AssetReader sobre cada cabecera devuelta, empaquetara solo el arbol cooked declarado mas metadatos inertes de atribucion PMM y verificara cada entrada del PAK. El PAK quedara local, sin desplegar, sin publicar y runtime UNPROVEN.`n`nDebes probarlo en Palworld. Si lo compartes o publicas, su descripcion publica debe incluir: This mod was created with PMM assistance.`n`nContinuar?"
      if(-not(Confirm $warning)){return}
      $sessionId=[string]$session.SessionId;$solutionId=[string]$row.SolutionId
      $done={param($result) Complete-PMMAIIOModBuildUi $result $sessionId}.GetNewClosure()
      [void](Start-PMMBackgroundOperation -Operation AIIOModBuild -SessionId $sessionId -SolutionId $solutionId -OnSuccess $done)
      return
    }
    $warning=L "Use this returned cooked-family candidate in Merge?`n`nPMM will revalidate the exact current case, source hashes, ZIP paths, cooked-family topology, output hashes and a read-only AssetReader parse. This cannot prove gameplay semantics. The candidate remains experimental and runtime UNPROVEN until you test the resulting exact build in Palworld.`n`nNothing will be deployed automatically. Continue?" "Usar este candidato cooked devuelto en Merge?`n`nPMM volvera a validar el caso exacto vigente, hashes fuente, rutas ZIP, topologia de la familia cooked, hashes de salida y una lectura con AssetReader. Esto no puede demostrar la semantica de gameplay. El candidato seguira experimental y runtime UNPROVEN hasta probar el build exacto en Palworld.`n`nNo se desplegara nada automaticamente. Continuar?"
    if(-not(Confirm $warning)){return}
    $sessionId=[string]$session.SessionId;$solutionId=[string]$row.SolutionId
    $done={param($result) Complete-PMMAIIOUseCandidateUi $result $sessionId}.GetNewClosure()
    [void](Start-PMMBackgroundOperation -Operation AIIOUseCandidate -SessionId $sessionId -SolutionId $solutionId -OnSuccess $done)
  }catch{Handle-UIError $_ (L 'Use AI candidate in Merge' 'Usar candidato IA en Merge')}
})
$Script:BtnAIHelpOpenKnowledge.Add_Click({try{Start-Process explorer.exe -ArgumentList ('"'+(Get-PMMPath 'CKL')+'"')}catch{Handle-UIError $_ (L 'Open Knowledge library' 'Abrir biblioteca Knowledge')}})
$Script:CmbAIHelpFeedbackBuild.Add_SelectionChanged({try{Update-PMMAIHelpFeedbackSelection}catch{}})
$Script:BtnAIHelpCreateFeedback.Add_Click({
  try{
    $kind=[string]$Script:CmbAIHelpFeedbackType.SelectedValue;if([string]::IsNullOrWhiteSpace($kind)){$kind='GENERAL_COMMENT'}
    $patch=Get-PMMAIHelpFeedbackPatch
    $result=New-PMMUserFeedbackFile -Kind $kind -Title ([string]$Script:TxtAIHelpFeedbackTitle.Text) -Comments ([string]$Script:TxtAIHelpFeedbackComments.Text) -Patch $patch
    $message=((L 'Inspectable feedback file created: {0}. Share it manually if you want; nothing was uploaded.' 'Archivo de feedback inspeccionable creado: {0}. Compartelo manualmente si quieres; no se subio nada.') -f [string]$result.Path)
    $Script:TxtAIHelpFeedbackStatus.Text=$message;$Script:TxtStatus.Text=$message
    Start-Process explorer.exe -ArgumentList ('/select,"'+[string]$result.Path+'"')
  }catch{Handle-UIError $_ (L 'Create manual feedback file' 'Crear archivo de feedback manual') -NoDiagnostic}
})
$Script:BtnAIHelpGenerateFeedback.Add_Click({
  try{
    $patch=Get-PMMAIHelpFeedbackPatch
    if(-not$patch){throw (L 'Choose a compatibility merge in this Feedback tab first.' 'Elige primero un merge de compatibilidad en esta pestana Feedback.')}
    $summary=Get-PMMBuildValidationSummary $patch
    if([string]::IsNullOrWhiteSpace([string]$summary.LatestEventId)){throw (L 'Validate this exact deployed merge first. Feedback is tied to a deterministic build and validation event.' 'Valida primero este merge desplegado exacto. El feedback queda ligado a un build determinista y a su evento de validacion.')}
    $result=Export-PMMBuildValidationFeedback ([string]$summary.LatestEventId)
    $message=((L 'Exact validation feedback created: {0}. Share it manually if you want; nothing was uploaded.' 'Feedback de validacion exacta creado: {0}. Compartelo manualmente si quieres; no se subio nada.') -f [string]$result.Path)
    $Script:TxtAIHelpFeedbackStatus.Text=$message;$Script:TxtStatus.Text=$message
    Start-Process explorer.exe -ArgumentList ('/select,"'+[string]$result.Path+'"')
  }catch{Handle-UIError $_ (L 'Generate local validation feedback' 'Generar feedback local de validacion') -NoDiagnostic}
})
$Script:BtnAIHelpOpenFeedback.Add_Click({try{Start-Process explorer.exe -ArgumentList ('"'+(Get-PMMPath 'ValidationFeedback')+'"')}catch{Handle-UIError $_ (L 'Open local feedback files' 'Abrir feedback local')}})
$Script:BtnAIHelpUploadFeedback.Add_Click({Show-Info (L 'Online upload is not connected in this release. Create an inspectable file and share it manually.' 'La subida online no esta conectada en esta version. Crea un archivo inspeccionable y compartelo manualmente.')})
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
$Script:BtnThemeEditorCreateAI.Add_Click({try{$draft=Update-PMMThemeEditorDraftFromUi -Save;$case=Get-OrCreate-PMMOriginCase -Origin Theme -SourceId ([string]$draft.DraftId) -Title ('Theme: '+[string]$draft.Name) -Description ([string]$Script:TxtThemeEditorPrompt.Text) -Context $draft;Select-PMMCaseLocation $case}catch{Handle-UIError $_ (L 'Open theme case' 'Abrir caso de tema')}})
$Script:BtnThemeEditorImportAI.Add_Click({try{$dialog=[Microsoft.Win32.OpenFileDialog]::new();$dialog.Title=L 'Import AI theme response' 'Importar respuesta IA de tema';$dialog.Filter='PMM theme AI response (*.zip)|*.zip';if($dialog.ShowDialog() -ne $true){return};$result=Import-PMMThemeAIResponse ([string]$dialog.FileName);$Script:ActiveThemeDraft=$result.Draft;Refresh-PMMThemeEditorCatalog;$Script:LstThemeDrafts.SelectedValue=[string]$result.Draft.DraftId;Show-PMMThemeDraft $result.Draft;$Script:TxtThemeEditorStatus.Text=((L 'AI theme response validated into draft {0}. It is not installed; review and preview it first.' 'Respuesta IA de tema validada como borrador {0}. No esta instalada; revisala y previsualizala primero.') -f [string]$result.Draft.Name)}catch{Handle-UIError $_ (L 'Import AI theme response' 'Importar respuesta IA de tema')}})
$Script:BtnThemeEditorDelete.Add_Click({try{$row=$Script:LstThemeDrafts.SelectedItem;if(-not$row){return};if(Confirm ((L 'Delete draft "{0}" and its copied image assets? Installed themes are not affected.' 'Eliminar el borrador "{0}" y sus imagenes copiadas? No afecta a temas instalados.') -f [string]$row.Name)){Remove-PMMThemeDraft ([string]$row.DraftId);if($Script:ActiveThemeDraft -and [string]$Script:ActiveThemeDraft.DraftId -eq [string]$row.DraftId){$Script:ActiveThemeDraft=$null;$Script:PnlThemeEditorRows.Children.Clear()};Refresh-PMMThemeEditorCatalog}}catch{Handle-UIError $_ (L 'Delete theme draft' 'Eliminar borrador de tema')}})


# ---------------------------------------------------------------------------
# AI & Help Settings / Knowledge actions.
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
    # Game Reference is itself a workflow step. With SemiAUTO, a manual click
    # arms continuation; with one-shot AUTO already running, it preserves that
    # run and completion resumes from the new reference state.
    if(-not$Script:AutoPipelineActive -and [bool]$Script:TglAutoMode.IsChecked){Start-PMMAutoPipeline}
    $Script:GameReferenceResumeAuto=[bool]$Script:AutoPipelineActive
    $started=Start-PMMGameReferenceBuild
    if(-not$started -and $Script:GameReferenceResumeAuto){Write-PMMLog 'Manual Game Reference did not start; AUTO remains armed for the next valid workflow action.'}
  }catch{Handle-UIError $_ (L 'Build Game Reference' 'Crear Game Reference')}
})
$Window.FindName('BtnImportMappings').Add_Click({try{
  $dialog=[Microsoft.Win32.OpenFileDialog]::new();$dialog.Filter='Unreal mappings (*.usmap)|*.usmap';$dialog.Title=L 'Select mappings for your game version' 'Selecciona los mappings de tu version del juego'
  if($dialog.ShowDialog() -eq $true){[void](Start-PMMBackgroundOperation -Operation MappingsImport -MappingsFile $dialog.FileName -OnSuccess {param($r) Refresh-UI;$Script:TxtStatus.Text=L 'Mappings selected. Run Analyze again.' 'Mappings seleccionados. Ejecuta Analizar de nuevo.'})}
}catch{Handle-UIError $_ (L 'Import mappings' 'Importar mappings')}})
$Window.FindName('BtnBundledMappings').Add_Click({try{[void](Start-PMMBackgroundOperation -Operation MappingsImport -OnSuccess {param($r) Refresh-UI})}catch{Handle-UIError $_ (L 'Use bundled mappings' 'Usar mappings incluidos')}})
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
      if((Show-PMMStyledDialog $form) -ne [System.Windows.Forms.DialogResult]::OK){return};$chosen=$list.SelectedItem
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
    $cfg.Language = Resolve-PMMLanguageCode $selectedCode
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
Initialize-PMMUpdatesUI
Initialize-PMMLibraryCaseMenu
Initialize-PMMDeepAnalysisUI
. (Join-Path $Script:Root 'Modules/MCP/AppServer.UI.ps1')
Initialize-PMMCaseAgentUI
try{Invoke-PMMLocalizeVisualTree $Window $lang;Set-PMMLanguageDirection $Window $lang}catch{Write-PMMLog ('Startup localization sweep failed: '+$_.Exception.Message)}
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
