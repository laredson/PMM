$script:deepChecks=0
function Assert-DeepUI($condition,[string]$message){if(-not$condition){throw $message};$script:deepChecks++}
Assert-DeepUI ($Script:DeepControls.CheckUpdates.IsChecked -and -not$Script:DeepControls.AutomaticSolution.IsChecked) 'Wrong initial analysis options.'
Assert-DeepUI (-not$Script:DeepControls.AllowGame.IsEnabled -and -not$Script:DeepControls.AllowGame.IsChecked) 'Unverified game automation was enabled.'
Assert-DeepUI ($Script:MainTabs.Items.Count -eq 6) 'Legacy main navigation was replaced.'
function Start-PMMDeepUIOperation([string]$Operation,$Request,[scriptblock]$OnSuccess){
  if($Operation -ne 'DeepAnalysis'){throw 'Unexpected operation in UI fixture.'}
  $result=Invoke-PMMDeepAnalysis $Request.Options
  & $OnSuccess @{AnalysisId=$result.Id;RepairSessionId=''}
}
$Script:DeepControls.Run.RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Button]::ClickEvent))
Assert-DeepUI ($Script:DeepControls.CreateCase.IsEnabled -and $Script:DeepReportView.Id -like 'DA-*') 'Run button did not load its report.'
$case=New-PMMCaseFromDeepAnalysis $Script:DeepReportView.Id
Select-PMMCaseLocation $case
Assert-DeepUI ($Script:PMMAIIOCaseSelectedId -eq $case.CaseId) 'Deep case did not navigate to the correct persistent editor.'
$grid=$Script:DeepControls.Findings
$Script:DeepControls.Filter.Text='nothing matches this fixture'
Assert-DeepUI (@($grid.ItemsSource).Count -eq 0) 'Finding text filter failed.'
$Script:DeepControls.Filter.Text=''
Assert-DeepUI (@($grid.ItemsSource).Count -gt 0) 'Clear filter failed.'
$Script:DeepControls.MaxCandidates.Text='-1'
$invalid=$false;try{Get-PMMDeepUIOptions|Out-Null}catch{$invalid=$true}
Assert-DeepUI $invalid 'Invalid limits accepted.'
$Script:DeepControls.MaxCandidates.Text='6'
$Script:DeepControls.CheckUpdates.IsChecked=$false
Get-PMMDeepUIOptions|Out-Null
Assert-DeepUI (-not(Read-PMMJsonFile (Join-PMMPath 'State' 'deep-analysis-options.json')).CheckUpdates) 'Preference was not persisted.'
$launchError=''
try{Start-PMMBackgroundOperation Recovery|Out-Null}catch{$launchError=$_.Exception.Message}
Assert-DeepUI ($launchError -like '*Fixture forbids starting external processes*') 'Recovery was dispatched as a Fix Lab operation.'
Assert-DeepUI (-not(Get-PMMModuleRuntimeSnapshot).Busy) 'A failed worker launch leaked its module lease.'

$dialogDefinition=(Get-Command Show-PMMAIPolicyDialog).Definition
$dialogDefinition=$dialogDefinition.Replace('[void]$v.window.ShowDialog()','$Script:PolicyFixture=@{View=$v;Controls=$controls;Save=$save;Api=$api;Status=$status}')
Invoke-Expression ('function Show-PMMAIPolicyDialog {'+$dialogDefinition+'}')
Show-PMMAIPolicyDialog
Assert-DeepUI ($Script:PolicyFixture.Controls.RoutineModel.Text -eq 'gpt-5.6-luna' -and $Script:PolicyFixture.Controls.RoutineEffort.SelectedItem -eq 'low') 'AI settings did not start with Luna low.'
Assert-DeepUI ($Script:PolicyFixture.Controls.Profile.SelectedValue -eq 'Auto' -and $Script:PolicyFixture.Controls.MaxStage.SelectedValue -eq 'Routine' -and -not$Script:PolicyFixture.Api.IsChecked) 'Account or escalation defaults were unsafe.'
$Script:PolicyFixture.Controls.Profile.SelectedValue='Free'
$Script:PolicyFixture.Save.RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Button]::ClickEvent))
Assert-DeepUI ((Get-PMMAIPolicy).Profile -eq 'Free' -and (Get-PMMAIPolicy).ServiceTier -eq 'default') ('AI policy UI did not persist the profile and standard speed: '+$Script:PolicyFixture.Status.Text)


function Start-PMMDeepUIOperation([string]$Operation,$Request,[scriptblock]$OnSuccess){$Script:DialogRequest=@{Operation=$Operation;Request=$Request}}
$definition=(Get-Command Show-PMMDeepCaseDialog).Definition.Replace('[void]$dialog.window.ShowDialog()','$Script:CaseDialogFixture=$dialog')
Invoke-Expression ('function Show-PMMDeepCaseDialog {'+$definition+'}')
Show-PMMDeepCaseDialog
$Script:CaseDialogFixture.actions.Children[0].RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Button]::ClickEvent))
Assert-DeepUI ($Script:DialogRequest.Operation -eq 'DeepCase' -and -not$Script:DialogRequest.Request.StartRepair -and $Script:DialogRequest.Request.AnalysisId -eq $Script:DeepReportView.Id) 'Case dialog lost the current report or started unauthorized repair.'
$definition=(Get-Command Show-PMMUpdateSourceDialog).Definition.Replace('[void]$v.window.ShowDialog()','$Script:SourceDialogFixture=@{View=$v;Save=$save;Mods=$mods;Fields=$fields}')
Invoke-Expression ('function Show-PMMUpdateSourceDialog {'+$definition+'}')
Show-PMMUpdateSourceDialog
$mod=[pscustomobject]@{Name='Fixture.pak';Hash=('a'*64)}
$Script:SourceDialogFixture.Mods.ItemsSource=@($mod);$Script:SourceDialogFixture.Mods.SelectedIndex=0
$Script:SourceDialogFixture.Fields.Provider.Text='Nexus';$Script:SourceDialogFixture.Fields.ModId.Text='1';$Script:SourceDialogFixture.Fields.FileId.Text='2'
$Script:SourceDialogFixture.Save.RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Button]::ClickEvent))
Assert-DeepUI ($Script:DialogRequest.Operation -eq 'DeepSource' -and $Script:DialogRequest.Request.Origin.Provider -eq 'Nexus' -and $Script:DialogRequest.Request.Origin.FileId -eq '2') 'Origin dialog did not dispatch its bound values.'

$exp=$grid.Parent.Parent
if($exp -is [Windows.Controls.Expander]){$exp.IsExpanded=$true}
$Script:MainTabs.SelectedItem=$Script:PMMMergeTab
$Script:PMMMergeTab.Content.SelectedIndex=0
$Window.Content.Measure([Windows.Size]::new(1600,1050));$Window.Content.Arrange([Windows.Rect]::new(0,0,1600,1050));$Window.Content.UpdateLayout()
$bitmap=[Windows.Media.Imaging.RenderTargetBitmap]::new(1600,1050,96,96,[Windows.Media.PixelFormats]::Pbgra32)
$bitmap.Render($Window.Content)
$encoder=[Windows.Media.Imaging.PngBitmapEncoder]::new();$encoder.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($bitmap))
$png=Join-Path $Script:Root 'deep-ui.png';$stream=[IO.File]::Create($png);try{$encoder.Save($stream)}finally{$stream.Dispose()}
Write-Output ('PASS deep UI '+$Language+': '+$script:deepChecks+' assertions; '+$png)
