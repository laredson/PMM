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
  Show-PMMThemedMessage @($Message,'Palworld Manager Merger','OK') | Out-Null
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
  return ((Show-PMMThemedMessage @($Message,'Palworld Manager Merger','YesNo')) -eq [System.Windows.MessageBoxResult]::Yes)
}

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
