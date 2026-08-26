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

Palworld Manager Merger v1.2.1 keeps the proven conservative merge adapters, indexed CKL discovery, AIIO disk-safety, and exact runtime-proven CKL production recipes. It does not use whole-asset fallback for Unreal asset families. Analyze
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
. (Join-Path $Script:Root 'Modules\Shared\GameLocator.ps1')
. (Join-Path $Script:Root 'Modules\Merge\PakService.ps1')
. (Join-Path $Script:Root 'Modules\Library\LibraryService.ps1')
. (Join-Path $Script:Root 'Modules\Saves\SaveService.ps1')
. (Join-Path $Script:Root 'Modules\CKL\SemanticLab.ps1')
. (Join-Path $Script:Root 'Modules\GameReference\GameReferenceService.ps1')
. (Join-Path $Script:Root 'Modules\CKL\KnowledgeRecipeService.ps1')
. (Join-Path $Script:Root 'Modules\Merge\MergeEngine.ps1')
. (Join-Path $Script:Root 'Modules\AIIO\AIIO.ps1')
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
  'TxtGamePath','BtnDetectGame','BtnBrowseGame','BtnBrowseGameManual','BtnOpenGame','BtnPlay',
  'BtnImport','BtnImportGameMods','BtnScan','TxtModFilter','TxtLibraryCount','LstMods','BtnPriorityUp','BtnPriorityDown','BtnDeleteMod','TxtPatchCount','LstPatches','BtnOpenPatches','ChkCloseGame','ChkForceClose',
  'ExpAnalysis','TxtAnalysisHeadline','TxtSharedCount','TxtAutoCount','TxtDecisionCount','TxtUnsupportedCount','TxtExperimentalCount','TxtIdenticalCount','TxtAnalysisScope','DgAnalysisAssets',
  'TxtAnalyzeProgress','PrgAnalyze','TxtBuildProgress','PrgBuild','ExpConflicts','TxtConflictHeader','LstConflictAssets','TxtConflictMods','TxtConflictAsset','CmbBulkWinner','TxtBulkCustom','BtnApplyBulk','BtnOpenReview','DgDecisions',
  'ExpUnsupported','LstUnsupportedAssets','TxtUnsupported','TxtUnsupportedHint','CmbUnsupportedDisable','BtnDisableUnsupported','BtnOpenAIHandoff','BtnImportManualSolution',
  'TxtBuildDeployHint','BtnBuild','BtnDeploy','BtnRestore',
  'ColLibrary','RowPatches','ColConflictAssets','RowAnalysisWorkspace','RowAnalysisConflictSplitter','RowResolutionWorkspace','RowWorkspaceFiller','SplAnalysisResolution',
  'LstSaves','TxtSaveDetails','BtnBackupSave','BtnRestoreSave',
  'CmbLanguage','BtnApplyLanguage','BtnResetLayout','TxtLibraryPath','BtnOpenLibrary',
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

# ---------------------------------------------------------------------------
# Guided workflow button colors.
#
# The highlight is derived from PMM state, never from the last button clicked.
# Only the next useful workflow stage is highlighted:
#   Import -> Analyze -> Build -> Deploy
# Normal enabled buttons remain visually neutral.
# ---------------------------------------------------------------------------
function Set-PMMGuideButtonStyle($Button,[ValidateSet('Default','Import','Analyze','Build','Deploy')][string]$State='Default') {
  if(-not$Button){return}
  $key=switch($State){
    'Import' {'ImportButton'}
    'Analyze' {'PrimaryButton'}
    'Build' {'BuildButton'}
    'Deploy' {'DeployButton'}
    default {'DefaultButton'}
  }
  try{
    $style=$Window.FindResource($key)
    if($style){$Button.Style=$style}
  }catch{Write-PMMLog ('Could not apply guided button style '+$State+': '+$_.Exception.Message)}
}

function Reset-PMMGuidedActionStyles {
  foreach($button in @($Script:BtnImport,$Script:BtnImportGameMods,$Script:BtnScan,$Script:BtnBuild,$Script:BtnDeploy)){
    Set-PMMGuideButtonStyle $button 'Default'
  }
}

function Get-PMMImportGuidanceTarget {
  <#
  Import is recommended only when it can actually reconcile something safely.

  - Empty library: recommend importing from ~mods when source PAKs exist there,
    otherwise recommend normal file Import.
  - Non-empty library: recommend Import ~mods only for a game source PAK that
    is not represented by either the library or PMM's last deployment record,
    or when PMM can prove a previously deployed/library-identical PAK was
    changed externally in the game folder.

  This distinction matters: if the user intentionally updates or removes a mod
  in the PMM library, the old deployed copy is expected to differ until Deploy.
  We must NOT tell the user to import that stale game copy back over the new
  library state. PMM merge PAKs are ignored because Deploy owns overlay state.
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
      # A PAK previously deployed by PMM but intentionally removed from the
      # library is waiting for Deploy removal, not re-import.
      if($stateItem){continue}
      return 'GameMods'
    }

    if($stateItem){
      $libraryHash=Get-PMMCachedFileHash $libraryPak
      $stateHash=[string]$stateItem.Hash
      if($stateHash -eq $libraryHash){
        # The library has not changed since PMM's recorded deployment. A size
        # mismatch therefore proves the game copy was replaced externally.
        if([int64]$libraryPak.Length -ne [int64]$gamePak.Length){return 'GameMods'}

        # Same-size replacements are uncommon but possible. Hash only files
        # touched after the recorded deployment, avoiding a 70-GB hash sweep
        # on every UI refresh for normal large mod lists.
        if($stateDeployedUtc -and $gamePak.LastWriteTimeUtc -gt $stateDeployedUtc.AddSeconds(2)){
          $gameHash=Get-PMMCachedFileHash $gamePak
          if($gameHash -ne $libraryHash){return 'GameMods'}
        }
      }
      # If libraryHash != stateHash, the library itself was intentionally
      # updated after Deploy. Analyze is the next step; never suggest importing
      # the stale deployed version back over it.
      continue
    }

    # No PMM deployment record: use timestamps only to break a same-name
    # ambiguity. A newer game copy is likely an externally installed update;
    # a newer/equal library copy is treated as intentional library state.
    if([int64]$libraryPak.Length -ne [int64]$gamePak.Length -and $gamePak.LastWriteTimeUtc -gt $libraryPak.LastWriteTimeUtc.AddSeconds(2)){
      return 'GameMods'
    }
  }
  return ''
}

function Test-PMMDesiredDeploymentCurrent {
  param([array]$SourceMods=@())
  try{
    if($SourceMods.Count -eq 0){return $true}
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

    foreach($mod in @($context.Active)){
      $key=([string]$mod.Name).ToLowerInvariant()
      if(-not$actual.ContainsKey($key)){return $false}
      $item=$actual[$key]
      if([string]$item.Hash -ne [string]$mod.Hash){return $false}
      $expectedDeployed=-not$suppressed.Contains([string]$mod.Name)
      $actualDeployed=$true
      if($item.PSObject.Properties.Name -contains 'Deployed'){$actualDeployed=[bool]$item.Deployed}
      if($actualDeployed -ne $expectedDeployed){return $false}
    }
    return $true
  }catch{
    # If PMM cannot prove the desired deployment is current, keep Deploy as the
    # recommended final step rather than claiming synchronization is complete.
    return $false
  }
}

function Update-PMMGuidedActionState {
  Reset-PMMGuidedActionStyles
  if($Script:AnalyzeBusy -or $Script:AIIOBusy -or ($Script:BackgroundOperationProcess -and -not$Script:BackgroundOperationProcess.HasExited)){return}

  $sourceMods=@(Get-LibraryMods)
  $importTarget=Get-PMMImportGuidanceTarget
  if($importTarget -eq 'GameMods' -and $Script:BtnImportGameMods.IsEnabled){
    Set-PMMGuideButtonStyle $Script:BtnImportGameMods 'Import'
    return
  }
  if($importTarget -eq 'Files' -and $Script:BtnImport.IsEnabled){
    Set-PMMGuideButtonStyle $Script:BtnImport 'Import'
    return
  }

  $analysisCurrent=$false
  if($sourceMods.Count -gt 0){try{$analysisCurrent=Test-PMMMergePlanCurrent}catch{$analysisCurrent=$false}}
  if($sourceMods.Count -gt 0 -and -not$analysisCurrent -and $Script:BtnScan.IsEnabled){
    Set-PMMGuideButtonStyle $Script:BtnScan 'Analyze'
    return
  }

  if($analysisCurrent -and $Script:BtnBuild.IsEnabled){
    Set-PMMGuideButtonStyle $Script:BtnBuild 'Build'
    return
  }

  if($Script:BtnDeploy.IsEnabled){
    $deploymentCurrent=Test-PMMDesiredDeploymentCurrent $sourceMods
    if(-not$deploymentCurrent){
      Set-PMMGuideButtonStyle $Script:BtnDeploy 'Deploy'
      return
    }
  }
}

function Show-Info([string]$Message) {
  [System.Windows.MessageBox]::Show($Message,'Palworld Manager Merger',[System.Windows.MessageBoxButton]::OK,[System.Windows.MessageBoxImage]::Information) | Out-Null
}

function Show-Error([string]$Message) {
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

function Apply-PMMLayoutFromConfig {
  try {
    $cfg=Get-PMMConfig
    $Window.Width=Get-PMMUiNumber $cfg 'UiWindowWidth' 1580 1180 3840
    $Window.Height=Get-PMMUiNumber $cfg 'UiWindowHeight' 940 720 2160
    $Script:ColLibrary.Width=[System.Windows.GridLength]::new((Get-PMMUiNumber $cfg 'UiLibraryWidth' 470 320 900))
    $Script:RowPatches.Height=[System.Windows.GridLength]::new((Get-PMMUiNumber $cfg 'UiPatchHeight' 145 95 320))
    $Script:ColConflictAssets.Width=[System.Windows.GridLength]::new((Get-PMMUiNumber $cfg 'UiConflictListWidth' 250 175 650))
    $Script:SavedAnalysisHeight=Get-PMMUiNumber $cfg 'UiAnalysisHeight' 300 120 1400
    $Script:SavedResolutionHeight=Get-PMMUiNumber $cfg 'UiResolutionHeight' 220 120 1200
    if(($cfg.PSObject.Properties.Name -contains 'UiWindowState') -and [string]$cfg.UiWindowState -eq 'Maximized'){
      $Window.WindowState=[System.Windows.WindowState]::Maximized
    }
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
    if($width -ge 1180){$cfg.UiWindowWidth=[Math]::Round($width)}
    if($height -ge 720){$cfg.UiWindowHeight=[Math]::Round($height)}
    $cfg.UiWindowState=[string]$Window.WindowState
    if($Script:ColLibrary.ActualWidth -gt 0){$cfg.UiLibraryWidth=[Math]::Round($Script:ColLibrary.ActualWidth)}
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
  $Window.Width=1580
  $Window.Height=940
  $Script:ColLibrary.Width=[System.Windows.GridLength]::new(470.0)
  $Script:RowPatches.Height=[System.Windows.GridLength]::new(145.0)
  $Script:ColConflictAssets.Width=[System.Windows.GridLength]::new(250.0)
  $Script:SavedAnalysisHeight=300.0
  $Script:SavedResolutionHeight=220.0
  Update-PMMWorkspaceRows
  Save-PMMLayoutSettings
}

function Confirm([string]$Message) {
  return ([System.Windows.MessageBox]::Show($Message,'Palworld Manager Merger',[System.Windows.MessageBoxButton]::YesNo,[System.Windows.MessageBoxImage]::Question) -eq [System.Windows.MessageBoxResult]::Yes)
}

Apply-PMMLayoutFromConfig
Update-PMMWorkspaceRows

# ---------------------------------------------------------------------------
# Analyze progress callback used by MergeEngine.ps1.
# ---------------------------------------------------------------------------
function Set-PMMAnalyzeProgress {
  param(
    [int]$Current,
    [int]$Total,
    [string]$Message,
    [switch]$Indeterminate
  )

  $Script:PrgAnalyze.Visibility = [System.Windows.Visibility]::Visible
  $Script:TxtAnalyzeProgress.Text = $Message

  if ($Indeterminate -or $Total -le 0) {
    $Script:PrgAnalyze.IsIndeterminate = $true
  } else {
    $Script:PrgAnalyze.IsIndeterminate = $false
    $Script:PrgAnalyze.Minimum = 0
    $Script:PrgAnalyze.Maximum = $Total
    $Script:PrgAnalyze.Value = [Math]::Min($Current,$Total)
  }

  try { [System.Windows.Forms.Application]::DoEvents() } catch {}
}

$Script:AnalyzeBusy=$false
function Update-PMMAnalyzeIndicator {
  if($Script:AnalyzeBusy){return}
  $current=$false
  try{$current=(Test-PMMMergePlanCurrent)}catch{$current=$false}
  if($current){
    $Script:PrgAnalyze.Visibility=[System.Windows.Visibility]::Visible
    $Script:PrgAnalyze.IsIndeterminate=$false
    $Script:PrgAnalyze.Minimum=0;$Script:PrgAnalyze.Maximum=1;$Script:PrgAnalyze.Value=1
    $Script:TxtAnalyzeProgress.Text=L 'Analyze complete - current mod list is analyzed.' 'Analisis terminado - la lista actual de mods esta analizada.'
  }else{
    $Script:PrgAnalyze.IsIndeterminate=$false
    $Script:PrgAnalyze.Visibility=[System.Windows.Visibility]::Collapsed
    $Script:PrgAnalyze.Value=0
    $Script:TxtAnalyzeProgress.Text=''
  }
}

function Set-PMMAnalyzeBusy([bool]$Busy) {
  $Script:AnalyzeBusy=$Busy
  $enabled=-not $Busy
  $Script:BtnScan.IsEnabled=$enabled
  $Script:BtnImport.IsEnabled=$enabled
  $Script:BtnImportGameMods.IsEnabled=$enabled
  $Script:LstMods.IsEnabled=$enabled
  if($Busy){$Script:BtnPriorityUp.IsEnabled=$false;$Script:BtnPriorityDown.IsEnabled=$false;$Script:BtnDeleteMod.IsEnabled=$false}
  if ($Busy) {
    Reset-PMMGuidedActionStyles
    $Script:PrgAnalyze.Visibility = [System.Windows.Visibility]::Visible
    $Script:PrgAnalyze.IsIndeterminate = $true
  } else {
    Update-PMMLibraryButtons
    Update-PMMAnalyzeIndicator
    Update-BuildButtonState
    Update-PMMGuidedActionState
  }
}

function Set-PMMBuildProgress {
  param(
    [int]$Current,
    [int]$Total,
    [string]$Message,
    [switch]$Indeterminate
  )

  $Script:PrgBuild.Visibility = [System.Windows.Visibility]::Visible
  $Script:TxtBuildProgress.Text = $Message

  if ($Indeterminate -or $Total -le 0) {
    $Script:PrgBuild.IsIndeterminate = $true
  } else {
    $Script:PrgBuild.IsIndeterminate = $false
    $Script:PrgBuild.Minimum = 0
    $Script:PrgBuild.Maximum = $Total
    $Script:PrgBuild.Value = [Math]::Min($Current,$Total)
  }

  try { [System.Windows.Forms.Application]::DoEvents() } catch {}
}

function Set-PMMBuildBusy([bool]$Busy) {
  if ($Busy) {
    Reset-PMMGuidedActionStyles
    $Script:BtnBuild.IsEnabled=$false
    $Script:BtnDeploy.IsEnabled=$false
    $Script:BtnScan.IsEnabled=$false
    $Script:BtnImport.IsEnabled=$false
    $Script:BtnImportGameMods.IsEnabled=$false
    $Script:LstMods.IsEnabled=$false
    $Script:BtnPriorityUp.IsEnabled=$false;$Script:BtnPriorityDown.IsEnabled=$false;$Script:BtnDeleteMod.IsEnabled=$false
    $Script:PrgBuild.Visibility=[System.Windows.Visibility]::Visible
    $Script:PrgBuild.IsIndeterminate=$true
    if ([string]::IsNullOrWhiteSpace($Script:TxtBuildProgress.Text)) {
      $Script:TxtBuildProgress.Text = L 'Preparing build...' 'Preparando build...'
    }
  } else {
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


$Script:AIIOBusy=$false
function Set-PMMAIIOBusy([bool]$Busy) {
  $Script:AIIOBusy=$Busy
  if($Busy){
    Reset-PMMGuidedActionStyles
    $Script:BtnOpenAIHandoff.IsEnabled=$false
    $Script:BtnScan.IsEnabled=$false
    $Script:BtnImport.IsEnabled=$false
    $Script:BtnImportGameMods.IsEnabled=$false
    $Script:LstMods.IsEnabled=$false
    $Script:BtnPriorityUp.IsEnabled=$false;$Script:BtnPriorityDown.IsEnabled=$false;$Script:BtnDeleteMod.IsEnabled=$false
    $Script:PrgAnalyze.Visibility=[System.Windows.Visibility]::Visible
    $Script:PrgAnalyze.IsIndeterminate=$true
    $Script:TxtAnalyzeProgress.Text=L 'Creating AI handoff bundle...' 'Creando paquete de entrega para IA...'
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
  }
}

# ---------------------------------------------------------------------------
# Background Analyze / Build / AIIO operations.
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

function Stop-PMMBackgroundOperation([switch]$Silent) {
  try{if($Script:BackgroundOperationTimer){$Script:BackgroundOperationTimer.Stop()}}catch{}
  try{
    if($Script:BackgroundOperationProcess -and -not$Script:BackgroundOperationProcess.HasExited){
      $Script:BackgroundOperationProcess.Kill()
    }
  }catch{}
  $kind=[string]$Script:BackgroundOperationKind
  $Script:BackgroundOperationProcess=$null
  $Script:BackgroundOperationKind=''
  $Script:BackgroundOperationOnSuccess=$null
  $Script:BackgroundOperationOnFailure=$null
  if($kind -eq 'Analyze'){Set-PMMAnalyzeBusy $false}
  elseif($kind -eq 'Build'){Set-PMMBuildBusy $false}
  elseif($kind -eq 'AIHandoff'){Set-PMMAIIOBusy $false}
  if(-not$Silent -and -not[string]::IsNullOrWhiteSpace($kind)){
    $Script:TxtStatus.Text=(L ($kind+' stopped.') ($kind+' detenido.'))
  }
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

  if($kind -eq 'Analyze'){Set-PMMAnalyzeBusy $false}
  elseif($kind -eq 'Build'){Set-PMMBuildBusy $false}
  elseif($kind -eq 'AIHandoff'){Set-PMMAIIOBusy $false}

  $successCallback=$Script:BackgroundOperationOnSuccess
  $failureCallback=$Script:BackgroundOperationOnFailure
  $Script:BackgroundOperationOnSuccess=$null
  $Script:BackgroundOperationOnFailure=$null
  $Script:BackgroundOperationProcess=$null
  $Script:BackgroundOperationKind=''

  if($result -and [bool]$result.Success){
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
    try{
      if($failureCallback){& $failureCallback $message}else{Show-Error $message}
    }catch{}
  }

  try{
    if($Script:BackgroundOperationJobRoot){
      Remove-Item -LiteralPath $Script:BackgroundOperationJobRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
  }catch{}
}

function Start-PMMBackgroundOperation {
  param(
    [Parameter(Mandatory=$true)][ValidateSet('Analyze','Build','AIHandoff')][string]$Operation,
    [switch]$Force,
    [switch]$AllowOversize,
    [ValidateSet('ConflictGroups')][string]$Mode='ConflictGroups',
    [scriptblock]$OnSuccess=$null,
    [scriptblock]$OnFailure=$null
  )

  if($Script:BackgroundOperationProcess -and -not$Script:BackgroundOperationProcess.HasExited){
    Show-Info (L 'Another Analyze/Build operation is already running.' 'Ya hay otra operacion Analyze/Build en ejecucion.')
    return $false
  }
  if($Script:GameReferenceProcess -and -not$Script:GameReferenceProcess.HasExited){
    Show-Info (L 'Wait for the background Game Reference build to finish before starting Analyze/Build.' 'Espera a que termine Game Reference en segundo plano antes de iniciar Analyze/Build.')
    return $false
  }

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

  $stdout=Join-Path $job 'worker.stdout.txt'
  $stderr=Join-Path $job 'worker.stderr.txt'
  $hostExe=''
  try{$hostExe=[string](Get-Process -Id $PID -ErrorAction Stop).Path}catch{}
  if([string]::IsNullOrWhiteSpace($hostExe) -or -not(Test-Path -LiteralPath $hostExe -PathType Leaf)){
    $hostExe='powershell.exe'
  }

  $args='-NoLogo -NoProfile -ExecutionPolicy Bypass -File "'+$worker+'" -Root "'+$Script:Root+'" -Operation '+$Operation+' -ProgressPath "'+$Script:BackgroundOperationProgressPath+'" -ResultPath "'+$Script:BackgroundOperationResultPath+'" -Mode '+$Mode
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
  }else{
    Set-PMMAIIOBusy $true
    Set-PMMAnalyzeProgress 0 0 (L 'Creating one AI handoff for all current Unsupported cases...' 'Creando una unica entrega para IA con todos los casos no soportados...') -Indeterminate
    $Script:TxtStatus.Text=L 'AIIO is extracting only the exact conflicting files. Source PAKs are never copied.' 'AIIO esta extrayendo solo los archivos exactos en conflicto. Los PAK fuente nunca se copian.'
  }

  try{
    $Script:BackgroundOperationProcess=Start-Process -FilePath $hostExe -ArgumentList $args -WorkingDirectory $Script:Root -WindowStyle Hidden -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
  }catch{
    if($Operation -eq 'Analyze'){Set-PMMAnalyzeBusy $false}elseif($Operation -eq 'Build'){Set-PMMBuildBusy $false}else{Set-PMMAIIOBusy $false}
    $Script:BackgroundOperationKind=''
    Remove-Item -LiteralPath $job -Recurse -Force -ErrorAction SilentlyContinue
    throw
  }

  $timer=New-Object System.Windows.Threading.DispatcherTimer
  $timer.Interval=[TimeSpan]::FromMilliseconds(250)
  $timer.Add_Tick({
    try{
      if(Test-Path -LiteralPath $Script:BackgroundOperationProgressPath -PathType Leaf){
        try{
          $progress=Get-Content -LiteralPath $Script:BackgroundOperationProgressPath -Raw|ConvertFrom-Json
          if([string]$progress.Operation -eq 'Analyze'){
            Set-PMMAnalyzeProgress ([int]$progress.Current) ([int]$progress.Total) ([string]$progress.Message) -Indeterminate:([bool]$progress.Indeterminate)
          }elseif([string]$progress.Operation -eq 'Build'){
            Set-PMMBuildProgress ([int]$progress.Current) ([int]$progress.Total) ([string]$progress.Message) -Indeterminate:([bool]$progress.Indeterminate)
          }elseif([string]$progress.Operation -eq 'AIHandoff'){
            Set-PMMAnalyzeProgress ([int]$progress.Current) ([int]$progress.Total) ([string]$progress.Message) -Indeterminate:([bool]$progress.Indeterminate)
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
  $Script:PrgGameReference.Visibility=[System.Windows.Visibility]::Visible
  $Script:TxtGameReferenceProgress.Visibility=[System.Windows.Visibility]::Visible
  $Script:PrgGameReference.IsIndeterminate=$Indeterminate
  if(-not$Indeterminate){
    $Script:PrgGameReference.Minimum=0
    $Script:PrgGameReference.Maximum=100
    $Script:PrgGameReference.Value=[Math]::Max(0,[Math]::Min(100,$Percent))
  }
  $Script:TxtGameReferenceProgress.Text=$Message
  $Script:TxtStatus.Text=$Message
}

function Stop-PMMGameReferenceBuild([switch]$Silent) {
  try{if($Script:GameReferenceTimer){$Script:GameReferenceTimer.Stop()}}catch{}
  try{if($Script:GameReferenceProcess -and -not$Script:GameReferenceProcess.HasExited){$Script:GameReferenceProcess.Kill()}}catch{}
  $Script:GameReferenceProcess=$null
  $Script:BtnBuildGameReference.IsEnabled=$true
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
  $callback=$Script:GameReferenceOnSuccess
  $failureCallback=$Script:GameReferenceOnFailure
  $Script:GameReferenceOnSuccess=$null
  $Script:GameReferenceOnFailure=$null

  if($result -and [bool]$result.Success){
    Set-PMMGameReferenceProgressUi 100 (L 'Game Reference ready.' 'Game Reference lista.') $false
    Refresh-UI
    try{if($callback){& $callback $result.State}}catch{Handle-UIError $_ (L 'Game Reference completion' 'Finalizacion de Game Reference')}
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
}

function Start-PMMGameReferenceBuild {
  param([scriptblock]$OnSuccess=$null,[scriptblock]$OnFailure=$null)
  if($Script:GameReferenceProcess -and -not$Script:GameReferenceProcess.HasExited){
    Show-Info (L 'Game Reference is already being built in the background.' 'Game Reference ya se esta creando en segundo plano.')
    return $false
  }
  if($Script:BackgroundOperationProcess -and -not$Script:BackgroundOperationProcess.HasExited){
    Show-Info (L 'Wait for the current Analyze/Build operation to finish before rebuilding Game Reference.' 'Espera a que termine la operacion Analyze/Build actual antes de reconstruir Game Reference.')
    return $false
  }

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

  try{
    $Script:GameReferenceProcess=Start-Process -FilePath $hostExe -ArgumentList $args -WorkingDirectory $Script:Root -WindowStyle Hidden -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
  }catch{
    $Script:BtnBuildGameReference.IsEnabled=$true
    Remove-Item -LiteralPath $job -Recurse -Force -ErrorAction SilentlyContinue
    throw
  }

  $timer=New-Object System.Windows.Threading.DispatcherTimer
  $timer.Interval=[TimeSpan]::FromMilliseconds(250)
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
      $Script:TxtConflictHeader.Foreground=[System.Windows.Media.Brushes]::Black
      $Script:ExpConflicts.IsExpanded=$false
    }elseif($unresolved -gt 0){
      $Script:TxtConflictHeader.Text=((L 'Resolution & Review ({0}) - DECISION REQUIRED' 'Resolucion y revision ({0}) - SE NECESITA DECISION') -f $assets.Count)
      $Script:TxtConflictHeader.Foreground=[System.Windows.Media.BrushConverter]::new().ConvertFromString('#9A6700')
      $created=if($plan -and ($plan.PSObject.Properties.Name -contains 'Created')){[string]$plan.Created}else{''}
      if($created -ne $Script:LastConflictPlanCreated -and $unsupported.Count -eq 0){$Script:ExpConflicts.IsExpanded=$true}
      $Script:LastConflictPlanCreated=$created
    }else{
      $Script:TxtConflictHeader.Text=((L 'Resolution & Review ({0}) - resolved' 'Resolucion y revision ({0}) - resuelto') -f $assets.Count)
      $Script:TxtConflictHeader.Foreground=[System.Windows.Media.BrushConverter]::new().ConvertFromString('#247A3B')
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

function Get-SelectedPMMLibraryEntry {
  $item=$Script:LstMods.SelectedItem
  if(-not$item){return $null}
  return $item
}

function Update-PMMLibraryButtons {
  $entry=Get-SelectedPMMLibraryEntry
  $isSource=($null -ne $entry -and [string]$entry.Kind -eq 'Source')
  $Script:BtnDeleteMod.IsEnabled=$isSource
  $Script:BtnPriorityUp.IsEnabled=($isSource -and (Test-PMMModPriorityMove ([string]$entry.Name) 'Earlier'))
  $Script:BtnPriorityDown.IsEnabled=($isSource -and (Test-PMMModPriorityMove ([string]$entry.Name) 'Later'))
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
  # also intentionally roll back to a previously built patch when that patch
  # proves it was created from this exact source hash set + mappings.
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
  $Script:TxtGamePath.Text = [string]$cfg.GamePath
  $Script:TxtLibraryPath.Text = Get-PMMPath 'Mods'
  $Script:ChkCloseGame.IsChecked = [bool]$cfg.CloseGameBeforeDeploy
  $Script:ChkForceClose.IsChecked = [bool]$cfg.ForceCloseOnTimeout
  Update-PMMDeploymentOptionsState
  $Script:CmbLanguage.SelectedValue = if ($cfg.Language -eq 'es') { 'es' } else { 'en' }

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
  $noPatchSelected=Test-PMMNoPatchSelected
  $compatibleCount=0
  $deployedCount=0
  foreach($patch in $managedPatches){if($patch.Deployed){$deployedCount++}}
  $noneStatus=if($noPatchSelected -and $deployedCount -gt 0){L 'SELECTED | OVERLAY REMOVAL PENDING' 'SELECCIONADO | RETIRAR OVERLAY PENDIENTE'}elseif($noPatchSelected){L 'SELECTED | SOURCE MODS ONLY' 'SELECCIONADO | SOLO MODS FUENTE'}else{L 'SOURCE MODS ONLY' 'SOLO MODS FUENTE'}
  [void]$Script:LstPatches.Items.Add([pscustomobject]@{
    Name=(L 'No compatibility patch' 'Sin parche de compatibilidad');SelectionKey=(Get-PMMNoPatchSelectionName);Patch=$null;Selected=[bool]$noPatchSelected;Selectable=$true;
    SelectTip=(L 'Deploy active source mods without a PMM compatibility overlay. Any deployed PMM overlay will be removed; saved patches stay in the library.' 'Despliega los mods fuente activos sin overlay de compatibilidad PMM. Se retirara cualquier overlay PMM desplegado; los parches guardados permanecen en la biblioteca.');
    Status=$noneStatus;Built='';Assets='';DecisionSummary=(L 'None' 'Ninguna');DecisionDetails=(L 'Manager-only deployment. PMM does not apply a compatibility overlay.' 'Deploy solo como manager. PMM no aplica un overlay de compatibilidad.')
  })
  foreach($patch in $managedPatches){
    $sourceMatch=Test-PMMPatchSourceSetCompatible $patch $sourceMods
    if($sourceMatch){$compatibleCount++}
    $selected=($selectedPatch -and [string]$selectedPatch.Name -ieq [string]$patch.Name)
    $decisionMatch=($sourceMatch -and (Test-PMMPatchCurrent $patch $sourceMods))
    $effectiveOrderMatch=($sourceMatch -and (Test-PMMPatchEffectiveOrderCompatible $patch $sourceMods))
    $status=if($patch.Deployed -and $decisionMatch){L 'DEPLOYED / CURRENT' 'DESPLEGADO / ACTUAL'}elseif($patch.Deployed){L 'DEPLOYED / ARCHIVED' 'DESPLEGADO / ARCHIVADO'}elseif($decisionMatch){L 'CURRENT BUILD' 'BUILD ACTUAL'}elseif($sourceMatch -and -not$effectiveOrderMatch){L 'ARCHIVED - EFFECTIVE ORDER CHANGED' 'ARCHIVADO - CAMBIO DE ORDEN EFECTIVO'}elseif($sourceMatch){L 'ARCHIVED - SAME EFFECTIVE MERGE' 'ARCHIVADO - MISMO MERGE EFECTIVO'}else{L 'ARCHIVED - OTHER SOURCES' 'ARCHIVADO - OTRAS FUENTES'}
    if($selected -and -not$patch.Deployed){$status=(L 'SELECTED | ' 'SELECCIONADO | ')+$status}
    $tip=if($sourceMatch){
      if($decisionMatch){L 'Selectable: exact source hashes, mappings, effective conflict order and current Analyze decisions match.' 'Seleccionable: coinciden hashes fuente, mappings, orden efectivo de conflictos y decisiones actuales de Analisis.'}
      elseif(-not$effectiveOrderMatch){L 'Selectable rollback: source hashes + mappings match, but an output-relevant priority winner changed (or the patch uses a legacy order signature). Select it explicitly only if you want that older output.' 'Rollback seleccionable: coinciden hashes fuente + mappings, pero cambio un ganador de prioridad que afecta al resultado (o el parche usa una firma de orden legacy). Seleccionalo explicitamente solo si quieres esa salida anterior.'}
      else{L 'Selectable rollback: source hashes + mappings + effective conflict order match; this patch may contain different previous manual conflict choices.' 'Rollback seleccionable: coinciden hashes fuente + mappings + orden efectivo de conflictos; este parche puede contener elecciones manuales de conflicto anteriores distintas.'}
    }else{L 'Not selectable for Deploy because this patch was built from a different source set or mappings.' 'No se puede seleccionar para Deploy porque este parche se creo con otro conjunto de fuentes o mappings.'}
    $built=''
    try{$built=([datetime]$patch.Modified).ToLocalTime().ToString('yyyy-MM-dd HH:mm')}catch{$built=[string]$patch.Modified}
    $decisionDisplay=Get-PMMPatchDecisionDisplay $patch
    [void]$Script:LstPatches.Items.Add([pscustomobject]@{
      Name=[string]$patch.Name;SelectionKey=[string]$patch.Name;Patch=$patch;Selected=[bool]$selected;Selectable=[bool]$sourceMatch;SelectTip=$tip;
      Status=$status;Built=$built;Assets=[string]$patch.AssetCount;DecisionSummary=[string]$decisionDisplay.Summary;DecisionDetails=[string]$decisionDisplay.Details
    })
  }
  $Script:TxtPatchCount.Text=((L '{0} saved  |  {1} selectable for active set  |  {2} deployed' '{0} guardado(s)  |  {1} seleccionable(s) para activos  |  {2} desplegado(s)') -f $managedPatches.Count,$compatibleCount,$deployedCount)

  Refresh-PMMAnalysisWorkspace
  Refresh-ConflictWorkspace

  $Script:LstSaves.Items.Clear()
  foreach ($save in @(Get-PMMSaveWorlds)) { [void]$Script:LstSaves.Items.Add($save) }
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
  Update-PMMAnalyzeIndicator
  Update-BuildButtonState
  Update-PMMGuidedActionState
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
  try { Refresh-UI } catch { Write-PMMLog ("Secondary UI refresh failure after {0}: {1}" -f $Action,$_.Exception.Message) }
}

function Invoke-PMMGameDetection([bool]$ShowNotFound=$true) {
  $Script:TxtStatus.Text = L 'Searching C: for Steam/Palworld, then other fixed drives if needed...' 'Buscando Steam/Palworld en C: y despues en otras unidades si es necesario...'
  try { [System.Windows.Forms.Application]::DoEvents() } catch {}
  $paths = @(Find-PalworldInstallations)
  $selected = Select-PalworldInstallation $paths
  if ($selected) { Set-PMMGamePath $selected; Refresh-UI; return $true }
  if ($paths.Count -eq 0 -and $ShowNotFound) {
    Show-Info (L 'Palworld was not found automatically. Use Choose Steam... or Choose Palworld... for a manual location.' 'No se encontro Palworld automaticamente. Usa Elegir Steam... o Elegir Palworld... para indicar la ubicacion manualmente.')
  }
  Refresh-UI
  return $false
}

function Save-UiSettings {
  $cfg = Get-PMMConfig
  $cfg.CloseGameBeforeDeploy = [bool]$Script:ChkCloseGame.IsChecked
  $cfg.ForceCloseOnTimeout = [bool]$Script:ChkForceClose.IsChecked
  $cfg.MergeMode = 'ConflictGroups'
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
$Script:BtnDetectGame.Add_Click({ try { Invoke-PMMGameDetection $true | Out-Null } catch { Handle-UIError $_ (L 'Palworld detection' 'Deteccion de Palworld') } })

$Script:BtnBrowseGame.Add_Click({
  try {
    Add-Type -AssemblyName System.Windows.Forms
    $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
    $dialog.Description = L 'Select a Steam installation or Steam library. PMM will inspect steamapps and registered Steam libraries.' 'Selecciona una instalacion o biblioteca de Steam. PMM revisara steamapps y las bibliotecas registradas de Steam.'
    if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
      $paths = @(Get-PalworldInstallationsFromSteamRoot $dialog.SelectedPath)
      $selected = Select-PalworldInstallation $paths
      if (-not $selected) {
        if ($paths.Count -eq 0) { throw (L 'No valid Palworld installation was found from the selected Steam folder.' 'No se encontro una instalacion valida de Palworld desde la carpeta de Steam seleccionada.') }
        return
      }
      $cfg = Get-PMMConfig
      $cfg.SteamRoot = [IO.Path]::GetFullPath($dialog.SelectedPath)
      Save-PMMConfig $cfg
      Set-PMMGamePath $selected
      Refresh-UI
    }
  } catch { Handle-UIError $_ (L 'Steam location selection' 'Seleccion de Steam') }
})

$Script:BtnBrowseGameManual.Add_Click({
  try {
    Add-Type -AssemblyName System.Windows.Forms
    $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
    $dialog.Description = L 'Select the Palworld game folder itself. It must contain Palworld.exe and Pal\Content\Paks.' 'Selecciona directamente la carpeta del juego Palworld. Debe contener Palworld.exe y Pal\Content\Paks.'
    if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
      Set-PMMGamePath $dialog.SelectedPath
      Refresh-UI
    }
  } catch { Handle-UIError $_ (L 'Manual Palworld location selection' 'Seleccion manual de Palworld') }
})

$Script:BtnOpenGame.Add_Click({ try { $path=(Get-PMMConfig).GamePath; if($path){ Start-Process explorer.exe -ArgumentList ('"'+$path+'"') } } catch { Handle-UIError $_ (L 'Open game folder' 'Abrir carpeta del juego') } })
$Script:BtnOpenLibrary.Add_Click({ try { Start-Process explorer.exe -ArgumentList ('"'+(Get-PMMPath 'Mods')+'"') } catch { Handle-UIError $_ (L 'Open library' 'Abrir biblioteca') } })
$Script:BtnPlay.Add_Click({ try { Start-Palworld } catch { Handle-UIError $_ (L 'Start Palworld' 'Iniciar Palworld') } })

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
  try {
    Add-Type -AssemblyName System.Windows.Forms
    $dialog = New-Object System.Windows.Forms.OpenFileDialog
    $dialog.Multiselect = $true
    $dialog.Filter = L 'Mods (*.pak;*.zip;*.7z;*.rar)|*.pak;*.zip;*.7z;*.rar|All files (*.*)|*.*' 'Mods (*.pak;*.zip;*.7z;*.rar)|*.pak;*.zip;*.7z;*.rar|Todos (*.*)|*.*'
    if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
      foreach ($file in $dialog.FileNames) { Import-PMMMod $file }
      Refresh-UI
    }
  } catch { Handle-UIError $_ (L 'Mod import' 'Importacion de mod') }
})

$Script:BtnImportGameMods.Add_Click({ try { $count=Import-GameModsToLibrary; Show-Info ((L 'Imported/updated: {0} PAK(s)' 'Importados/actualizados: {0} PAK') -f $count); Refresh-UI } catch { Handle-UIError $_ (L 'Import game ~mods' 'Importacion de ~mods') } })
$Script:BtnScan.Add_Click({
  try{
    Save-DecisionGridToPlan -Silent
    $done={
      param($result)
      Refresh-UI
      $Script:TxtLog.Text=Get-PMMRecentLog
      $Script:TxtStatus.Text=Get-PMMStatusLine
      Prompt-PMMAIHandoffAfterAnalyze
    }
    [void](Start-PMMBackgroundOperation -Operation Analyze -OnSuccess $done)
  }catch{Handle-UIError $_ (L 'Analyze' 'Analizar')}
})
$Script:TxtModFilter.Add_TextChanged({try{Apply-PMMLibraryFilter}catch{}})
$Script:LstMods.Add_SelectionChanged({try{Update-PMMLibraryButtons}catch{}})

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
$Script:BtnOpenPatches.Add_Click({try{Start-Process explorer.exe -ArgumentList ('"'+(Get-PMMPath 'Builds')+'"')}catch{Handle-UIError $_ (L 'Open patch folders' 'Abrir carpetas de parches')}})
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
    $entry=Get-SelectedPMMLibraryEntry
    if(-not$entry -or $entry.Kind -ne 'Source'){return}
    if(Confirm((L "Delete {0} from the PMM library? The game folder is not changed until Deploy." "Borrar {0} de la biblioteca PMM? La carpeta del juego no cambia hasta Deploy.") -f $entry.Name)){
      Remove-PMMLibraryMod $entry.Name
      Refresh-UI
    }
  }catch{Handle-UIError $_ (L 'Delete mod' 'Borrar mod')}
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
          Show-Info ((L 'AI handoff created successfully. It is larger than the normal 512 MiB target ({0}), but the package is valid.' 'Entrega para IA creada correctamente. Es mayor que el objetivo normal de 512 MiB ({0}), pero el paquete es valido.') -f (Format-PMMByteSize ([int64]$result.ZipBytes)))
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
    Show-Info ((L 'Experimental solution validated for case {0}. PMM will re-analyze; automatic safe adapters still have priority over manual solutions.' 'Solucion experimental validada para el caso {0}. PMM volvera a analizar; los adapters automaticos seguros siguen teniendo prioridad sobre las soluciones manuales.') -f [string]$imported.CaseId)
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

    $done={
      param($result)
      $message=if($result){[string]$result.ResultText}else{''}
      if(-not[string]::IsNullOrWhiteSpace($message)){Show-Info $message}
      Refresh-UI
      $Script:TxtLog.Text=Get-PMMRecentLog
      $Script:TxtStatus.Text=Get-PMMStatusLine
    }
    [void](Start-PMMBackgroundOperation -Operation Build -Mode 'ConflictGroups' -OnSuccess $done)
  } catch { Handle-UIError $_ 'Build Merge' }
})

$Script:BtnDeploy.Add_Click({
  try{
    Save-UiSettings
    Save-DecisionGridToPlan
    $preview=Get-PMMDeploymentPreview
    Write-PMMLog ('Deploy preflight: '+($preview -replace "(`r`n|`n|`r)",' | '))
    Set-PMMBuildBusy $true
    Set-PMMBuildProgress 0 3 (L 'Preparing transactional deployment...' 'Preparando despliegue transaccional...')
    Set-PMMBuildProgress 1 3 (L 'Staging and hash-checking managed files...' 'Preparando y verificando por hash los archivos gestionados...')
    $result=Deploy-PMMManagedState
    Set-PMMBuildProgress 3 3 (L 'Deploy complete.' 'Deploy terminado.')
    Show-Info $result
    Refresh-UI
  }catch{Handle-UIError $_ 'Deploy'}
  finally{Set-PMMBuildBusy $false}
})


$Script:BtnRestore.Add_Click({ try { if (Confirm (L 'This removes all PMM-generated overlays from the game. Original mods are not deleted. Continue?' 'Esto retira del juego todos los overlays generados por PMM. Los mods originales no se borran. Continuar?')) { $message=Restore-PMMDeployment; if($message){Show-Info $message}; Refresh-UI } } catch { Handle-UIError $_ (L 'Restore deployment' 'Restaurar deployment') } })

# ---------------------------------------------------------------------------
# Save backup controls.
# ---------------------------------------------------------------------------
$Script:LstSaves.Add_SelectionChanged({ try { $save=$Script:LstSaves.SelectedItem; if($save){ $Script:TxtSaveDetails.Text=(Get-PMMSaveDetails $save | Out-String) } } catch { $Script:TxtSaveDetails.Text=$_.Exception.Message } })
$Script:BtnBackupSave.Add_Click({ try { $save=$Script:LstSaves.SelectedItem; if(-not$save){throw(L 'Select a world.' 'Selecciona un mundo.')}; $path=Backup-PMMSave $save; Show-Info((L 'Backup created:`n' 'Backup creado:`n')+$path); Refresh-UI } catch { Handle-UIError $_ (L 'Save backup' 'Backup de save') } })
$Script:BtnRestoreSave.Add_Click({ try { $save=$Script:LstSaves.SelectedItem; if(-not$save){throw(L 'Select a world.' 'Selecciona un mundo.')}; if(Confirm(L 'Restoring a save can overwrite current progress. Continue?' 'Restaurar un save puede sobrescribir progreso actual. Continuar?')){Restore-PMMSaveInteractive $save;Refresh-UI} } catch { Handle-UIError $_ (L 'Save restore' 'Restauracion de save') } })

# ---------------------------------------------------------------------------
# Settings.
# ---------------------------------------------------------------------------
$Script:BtnBuildGameReference.Add_Click({
  try{
    $cfg=Get-PMMConfig
    if(-not$cfg.GamePath){throw (L 'Configure Palworld first.' 'Configura Palworld primero.')}
    $gr=Get-PMMGameReferenceState
    $question=if([string]$gr.Status -eq 'Current'){
      L 'Rebuild the local Game Reference now? This reads Pal-Windows.pak in the background and replaces only PMM Workspace\GameReference. Palworld is never modified.' 'Volver a crear Game Reference local? Esto lee Pal-Windows.pak en segundo plano y solo sustituye PMM Workspace\GameReference. Palworld no se modifica.'
    }else{
      L 'Build the local Game Reference now? PMM will process it in the background, show progress here, and keep the rest of the GUI responsive. This can use a few hundred MB of disk space and does not modify Palworld.' 'Crear Game Reference local ahora? PMM la procesara en segundo plano, mostrara el progreso aqui y mantendra el resto de la interfaz operativa. Puede usar unos cientos de MB y no modifica Palworld.'
    }
    if(-not(Confirm $question)){return}
    $onSuccess={
      param($built)
      Show-Info ((L 'Game Reference ready: {0} families, {1:N1} MiB. It remains available as a local research/reference cache.' 'Game Reference lista: {0} familias, {1:N1} MiB. Queda disponible como cache local de investigacion/referencia.') -f [int]$built.FamilyCount,([double]$built.Bytes/1MB))
    }
    [void](Start-PMMGameReferenceBuild -OnSuccess $onSuccess)
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
    Show-Info ((L 'Contribution package created:`n{0}`n`nSend this single ZIP to the PMM maintainer or an approved private Knowledge intake. It contains the case, original handoff when available, returned solution and runtime PASS evidence.' 'Paquete de contribucion creado:`n{0}`n`nEnvia este unico ZIP al mantenedor de PMM o a un servicio privado aprobado de Knowledge. Contiene el caso, handoff original cuando esta disponible, solucion devuelta y evidencia PASS runtime.') -f $zip)
    Start-Process explorer.exe -ArgumentList ('/select,"'+$zip+'"')
  }catch{Handle-UIError $_ (L 'Create Knowledge contribution' 'Crear contribucion Knowledge')}
})
$Script:BtnOpenKnowledgeContributions.Add_Click({try{$p=Get-PMMKnowledgeContributionRoot;Start-Process explorer.exe -ArgumentList ('"'+$p+'"')}catch{Handle-UIError $_ (L 'Open contribution folder' 'Abrir carpeta de contribuciones')}})
$Script:BtnSetupDeps.Add_Click({ try { & (Join-Path $Script:Root 'Modules\Bootstrap\Setup-Dependencies.ps1'); Refresh-UI; Show-Info(L 'Dependency preparation finished.' 'Proceso de dependencias terminado.') } catch { Handle-UIError $_ (L 'Dependency preparation' 'Preparacion de dependencias') } })
$Script:BtnApplyLanguage.Add_Click({
  try {
    $cfg = Get-PMMConfig
    $selectedCode = [string]$Script:CmbLanguage.SelectedValue
    $cfg.Language = if ($selectedCode -eq 'es') { 'es' } else { 'en' }
    Save-PMMConfig $cfg
    Show-Info (L 'Language saved. Restart Palworld Manager Merger to apply it to the entire interface.' 'Idioma guardado. Reinicia Palworld Manager Merger para aplicarlo a toda la interfaz.')
  } catch { Handle-UIError $_ 'Language' }
})

$Script:BtnResetLayout.Add_Click({
  try {
    Reset-PMMLayout
    Show-Info (L 'Workspace layout reset. You can drag the dividers again; the new positions will be remembered.' 'Distribucion restablecida. Puedes volver a arrastrar los divisores; las nuevas posiciones se recordaran.')
  } catch { Handle-UIError $_ (L 'Reset workspace layout' 'Restablecer distribucion') }
})

$Window.Add_Closing({
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
  throw
} finally {
  Stop-PMMLogSession $uiExitState
}
