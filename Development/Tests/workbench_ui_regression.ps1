param([string]$Repository=([IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))),[ValidateSet('en','es')][string]$Language='en',[switch]$Render,[string]$VerifyPersistedRoot='')
Set-StrictMode -Version 2.0;$ErrorActionPreference='Stop'
if($VerifyPersistedRoot){
    $Script:Root=$VerifyPersistedRoot
    . (Join-Path $Repository 'PMM\Modules\Shared\Paths.ps1')
    Initialize-PMMPaths $Script:Root|Out-Null
    . (Join-Path $Repository 'PMM\Modules\AIIO\AIIO.CaseWorkspaceService.ps1')
    $cases=@(Get-PMMAIIOCases)
    if($cases.Count -ne 8 -or @($cases.CaseId|Select-Object -Unique).Count -ne 8){throw 'Cases lost after process restart'}
    foreach($case in $cases){if(-not @(Get-PMMAIIOCaseSteps $case.CaseId).Count){throw 'History lost after process restart'}}
    'RESTART_CASES_OK';exit 0
}
$app=Join-Path $Repository 'PMM'
$Script:Root=Join-Path $Repository ('Development\TestResults\Workspaces-'+[guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($Script:Root)
Copy-Item (Join-Path $app 'Modules') (Join-Path $Script:Root 'Modules') -Recurse
Copy-Item (Join-Path $app 'Resources') (Join-Path $Script:Root 'Resources') -Recurse
. (Join-Path $Script:Root 'Modules\Shared\Paths.ps1')
Initialize-PMMPaths $Script:Root|Out-Null
. (Join-Path $Script:Root 'Modules\Shared\Common.ps1')
. (Join-Path $Script:Root 'Modules\AIIO\AIIO.SessionService.ps1')
. (Join-Path $Script:Root 'Modules\AIIO\AIIO.CaseWorkspaceService.ps1')
. (Join-Path $Script:Root 'Modules\MCP\MCP.Service.ps1')
function Write-PMMLog([string]$Message){}
function L([string]$English,[string]$Spanish){if($Language -eq 'es'){return $Spanish};return $English}
function Handle-UIError($Failure,[string]$Title){throw $Failure}
Add-Type -AssemblyName PresentationFramework,PresentationCore,WindowsBase,System.Windows.Forms
$c=New-PMMAIIOCase -Title 'New mod fixture' -Type NEW_MOD
$f=New-PMMAIIOCase -Title 'Fix fixture' -Type FIX_MOD
$m=New-PMMAIIOCase -Title 'Merge fixture' -Type COMPATIBILITY
$h=New-PMMAIIOCase -Title 'Research fixture' -Type UNDEFINED
[xml]$x=[IO.File]::ReadAllText((Join-Path $app ("Resources\UI\MainWindow."+ $Language +".xaml")))
$r=[Xml.XmlNodeReader]::new($x);try{$Window=[Windows.Markup.XamlReader]::Load($r)}finally{$r.Dispose()}
$Script:MainTabs=$Window.FindName('MainTabs');$Script:AIHelpTabs=$Window.FindName('AIHelpTabs');$Script:TabAIHelp=$Window.FindName('TabAIHelp');$Script:TabFixLab=$Window.FindName('TabFixLab')
. (Join-Path $Script:Root 'Modules\AIIO\AIIO.CaseWorkspace.UI.ps1')
foreach($preview in @('AIIO.CaseWorkspace.UI.Preview2.ps1','AIIO.CaseWorkspace.UI.Preview3.ps1','AIIO.CaseWorkspace.UI.Preview4.ps1','AIIO.CaseWorkspace.Preview5.ps1','AIIO.CaseWorkspace.UI.Preview6.ps1')){. (Join-Path $Script:Root ('Modules\AIIO\'+$preview))}
. (Join-Path $Script:Root 'Modules\Shared\Dialogs.ps1')
. (Join-Path $Script:Root 'Modules\Unreal\Dependencies.UI.ps1')
. (Join-Path $Script:Root 'Modules\AIIO\AIIO.Workspaces.UI.ps1')
$Script:GrdHeaderLayout=$Window.FindName('GrdHeaderLayout');$Script:ImgPMMLogo=$Window.FindName('ImgPMMLogo');$Script:PnlHeaderTitle=$Window.FindName('PnlHeaderTitle');$Script:BtnAutoRun=$Window.FindName('BtnAutoRun');$Script:BtnOpenAIHandoff=$Window.FindName('BtnOpenAIHandoff');$Script:LstMods=$Window.FindName('LstMods');$Script:TxtStatus=$Window.FindName('TxtStatus')
function Get-PMMWorkflowState {return [pscustomobject]@{Action='Analyze';Detail=(L '3 selected mods. Pending analysis; game installation unchanged.' '3 mods seleccionados. Analisis pendiente; instalacion sin cambios.')}}
function Get-PMMOperationJournalEvents {return @()}
$Script:FixtureSelection=@()
function Get-SelectedPMMLibraryEntries {return $Script:FixtureSelection}
try {
  function Start-PMMDependencyScan {}
  Initialize-PMMWorkspaces
  $Script:PMMDependencyTimer.Stop()
  Stop-PMMDependencySnapshot
  . (Join-Path $app 'Modules/Presentation/Workbench.UI.ps1')
  . (Join-Path $app 'Modules/Presentation/Theme.UI.ps1')
  foreach($key in (Get-PMMBaseThemePalette 'Night').Keys){$Window.Resources[$key]=[Windows.Media.BrushConverter]::new().ConvertFromString((Get-PMMBaseThemePalette 'Night')[$key])}
  Initialize-PMMWorkbench
  if($Script:PMMWorkbench.Mode -ne 'Play' -or $Script:PMMWorkbench.ActivePage -ne 'Library'){throw 'Library must be initial page'}
  if(@(Get-PMMAIIOCaseRows).Count -ne 4){throw 'Unified case list lost case types'}
  Select-PMMCaseLocation $f
  if($Script:PMMWorkbench.Mode -ne 'Create' -or $Script:PMMAIIOCaseSelectedId -ne $f.CaseId){throw 'Fix case did not route to Crear'}
  $title=Get-PMMAIIOCaseControl 'TxtTitle';$title.Text='Preserved draft'
  Show-PMMWorkbenchPage 'Library';Show-PMMWorkbenchPage 'Cases'
  if((Get-PMMAIIOCase $f.CaseId).Title -ne 'Preserved draft'){throw 'Navigation lost draft'}
  $Script:PMMWorkbench.CaseSearch.Text='Preserved'
  if(@(Get-PMMAIIOCaseRows).Count -ne 1){throw 'Case search failed'}
  Show-PMMWorkbenchPage 'Library';Show-PMMWorkbenchPage 'Cases'
  if($Script:PMMWorkbench.CaseSearch.Text -ne 'Preserved'){throw 'Search state lost'}
  if($Script:LstMods.ContextMenu.Items.Count -ne 3 -or $Script:LstMods.ContextMenu.Items[0].Items.Count -ne 3){throw 'Context actions missing'}
  $query=New-PMMAIIOCase -Type QUERY -Title 'Context question'
  Select-PMMCaseLocation $query
  if((Get-PMMAIIOCaseControl 'CmbType').SelectedValue -ne 'QUERY'){throw 'Query type missing from editor'}
  [void](Save-PMMAIIOCaseEditor)
  if((Get-PMMAIIOCase $query.CaseId).Type -ne 'QUERY'){throw 'Query type lost on editor save'}
  foreach($index in @(1,2)){
    $file=Join-Path $Script:Root ('fixture-'+$index+'.pak');[IO.File]::WriteAllText($file,('synthetic input '+$index))
    $mod=[pscustomobject]@{Name=[IO.Path]::GetFileName($file);Path=$file;Hash=(Get-FileHash -LiteralPath $file).Hash.ToLowerInvariant();Priority=$index;Enabled=$true;Size=(Get-Item $file).Length}
    $Script:FixtureSelection+=@([pscustomobject]@{Kind='Source';Name=$mod.Name;Mod=$mod})
  }
  function Start-PMMWorkbenchTool([string]$Mode,$Request){if($Mode -eq 'CreateContextCase'){$case=New-PMMContextCase -Type $Request.Type -Mods $Request.Mods -Title $Request.Title -Description $Request.Description -Origin $Request.Origin;Select-PMMCaseLocation $case}}
  Invoke-PMMWorkbenchContextCase 'Compat'
  $contextCase=Get-PMMAIIOSelectedCase
  if($contextCase.Type -ne 'COMPATIBILITY' -or @($contextCase.References.Mods).Count -ne 2){throw 'Multi-selection case lost provider references'}
  if($Script:PMMWorkbench.Mode -ne 'Create'){throw 'Context case failed to open Create'}
  foreach($reference in $contextCase.References.Mods){if(-not $reference.Path -or -not $reference.Sha256){throw 'Context case references must retain full path and hash'}}
  Select-PMMCaseLocation $f
  $Window.Width=1280;$Window.Height=850;$Window.Show();$Window.UpdateLayout()
  foreach($page in @('Library','Cases','Knowledge')){
    Show-PMMWorkbenchPage $page;$Window.UpdateLayout();[void]$Window.Dispatcher.Invoke([Windows.Threading.DispatcherPriority]::ApplicationIdle,[Action]{});$Window.UpdateLayout()
    $bitmap=[Windows.Media.Imaging.RenderTargetBitmap]::new([int]$Window.ActualWidth,[int]$Window.ActualHeight,96,96,[Windows.Media.PixelFormats]::Pbgra32);$bitmap.Render($Window)
    $encoder=[Windows.Media.Imaging.PngBitmapEncoder]::new();$encoder.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($bitmap));$target=Join-Path $Script:Root ('workbench-'+$page+'-'+$Language+'.png');$stream=[IO.File]::Create($target);try{$encoder.Save($stream)}finally{$stream.Dispose()};Write-Output ('RENDER '+$target)
  }
  $Window.Width=1000;$Window.UpdateLayout();if($Script:PMMWorkbench.Nav.Width -gt 60){throw 'Compact navigation failed'}
  Show-PMMWorkbenchPage 'Cases';$Window.UpdateLayout();[void]$Window.Dispatcher.Invoke([Windows.Threading.DispatcherPriority]::ApplicationIdle,[Action]{})
  $caseGrid=Get-PMMAIIOCaseControl 'DgCases'
  if($caseGrid.Columns[0].ActualWidth -lt 80){throw 'Case title column is not readable at compact width'}
  if(-not $Script:PMMWorkbench.PlayMode.Focusable -or -not $Script:PMMWorkbench.CreateMode.Focusable){throw 'Mode controls must be keyboard accessible'}
  [void]$Script:PMMWorkbench.CreateMode.Focus()
  if(-not $Script:PMMWorkbench.CreateMode.IsKeyboardFocused){throw 'Keyboard focus failed'}
  $Window.Width=1800;$Window.Height=1200;$Window.Content.LayoutTransform=[Windows.Media.ScaleTransform]::new(1.5,1.5);$Window.UpdateLayout();[void]$Window.Dispatcher.Invoke([Windows.Threading.DispatcherPriority]::ApplicationIdle,[Action]{})
  if($caseGrid.ActualWidth -lt 200){throw 'Case list collapsed at simulated 150 percent layout scale'}
  'WORKBENCH_UI_OK: shared editor, QUERY roundtrip, multiselection references, drafts/search, compact navigation, keyboard focus and 150 percent layout scale'
} finally { $Window.Close();if(Get-Variable PMMDependencyTimer -Scope Script -ErrorAction SilentlyContinue){$Script:PMMDependencyTimer.Stop()} }