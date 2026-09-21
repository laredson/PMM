$script:deepChecks=0
function Assert-DeepUI($condition,[string]$message){if(-not$condition){throw $message};$script:deepChecks++}
Assert-DeepUI (-not($Script:DeepControls.ContainsKey('CheckUpdates')) -and -not$Script:DeepControls.AutomaticSolution.IsChecked) 'Deep Analysis still owns update-network controls.'
Assert-DeepUI (-not$Script:DeepControls.AllowGame.IsEnabled -and -not$Script:DeepControls.AllowGame.IsChecked) 'Unverified game automation was enabled.'
Assert-DeepUI ($Script:MainTabs.Items.Count -eq 5) 'Fix Lab was not moved out of top-level navigation.'
Assert-DeepUI ($Script:ModsWorkflowTabs.Items.Count -eq 5) 'Mods & Merge does not expose the five workflow subtabs.'
$expectedWorkflowTabs=if($Language -eq 'es'){'Mods y Merge|Actualizaciones|Fix Lab|Analisis profundo|Asistente IA'}else{'Mods & Merge|Updates|Fix Lab|Deep Analysis|AI Assistant'}
Assert-DeepUI ((@($Script:ModsWorkflowTabs.Items|ForEach-Object{[string]$_.Header}) -join '|') -eq $expectedWorkflowTabs) 'Workflow subtab order changed.'
Assert-DeepUI ($Script:UpdatesHost -and $Script:BtnCheckUpdates -and $Script:BtnUpdateSelected -and $Script:BtnUpdateSafe -and $Script:BtnCancelUpdates) 'Updates actions were not initialized.'
Assert-DeepUI ($Script:BtnRestoreUpdate -and $Script:BtnDeleteUpdateArchive -and $Script:DgUpdateArchives) 'Update history and rollback controls were not initialized.'
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
Get-PMMDeepUIOptions|Out-Null
Assert-DeepUI (-not(Read-PMMJsonFile (Join-PMMPath 'State' 'deep-analysis-options.json')).CheckUpdates) 'Preference was not persisted.'
$launchError=''
try{Start-PMMBackgroundOperation Recovery|Out-Null}catch{$launchError=$_.Exception.Message}
Assert-DeepUI ($launchError -like '*Fixture forbids starting external processes*') 'Recovery was dispatched as a Fix Lab operation.'
Assert-DeepUI (-not(Get-PMMModuleRuntimeSnapshot).Busy) 'A failed worker launch leaked its module lease.'

$dialogDefinition=(Get-Command Show-PMMAIPolicyDialog).Definition
$dialogDefinition=$dialogDefinition.Replace('[void]$v.window.ShowDialog()','$Script:PolicyFixture=@{View=$v;Controls=$controls;Save=$save;Api=$api;Status=$status}')
Invoke-Expression ('function Show-PMMAIPolicyDialog {'+$dialogDefinition+'}')
$catalog=[pscustomobject]@{Plan='fixture';Utc='fixture';Models=@(
  @{model='gpt-5.6-luna';supportedReasoningEfforts=@(@{reasoningEffort='low'},@{reasoningEffort='medium'})},
  @{model='gpt-5.6-sol';supportedReasoningEfforts=@(@{reasoningEffort='low'},@{reasoningEffort='high'},@{reasoningEffort='ultra'})},
  @{model='gpt-6-astra';supportedReasoningEfforts=@(@{reasoningEffort='high'})},
  @{model='hidden';hidden=$true;supportedReasoningEfforts=@()}
)}
Write-PMMJsonAtomic (Join-PMMPath 'State' 'ai-capabilities.json') $catalog
$policy=New-PMMAIPolicy;$policy.RepairModel='gpt-5.6-Sol';$policy.RepairEffort='high';$policy.ComplexModel='gpt-6-Astra';Save-PMMAIPolicy $policy
Show-PMMAIPolicyDialog
Assert-DeepUI ($Script:PolicyFixture.Controls.RoutineModel.SelectedValue -eq 'gpt-5.6-luna' -and $Script:PolicyFixture.Controls.RoutineEffort.SelectedItem -eq 'low') ('AI settings did not start with Luna low: '+$Script:PolicyFixture.Status.Text+' model='+$Script:PolicyFixture.Controls.RoutineModel.SelectedValue+' effort='+$Script:PolicyFixture.Controls.RoutineEffort.SelectedItem)
Assert-DeepUI ($Script:PolicyFixture.Controls.Profile.SelectedValue -eq 'Auto' -and $Script:PolicyFixture.Controls.MaxStage.SelectedValue -eq 'Routine' -and -not$Script:PolicyFixture.Api.IsChecked) 'Account or escalation defaults were unsafe.'
$c=$Script:PolicyFixture.Controls
Assert-DeepUI ($c.RepairModel -is [Windows.Controls.ComboBox] -and -not$c.RepairModel.IsEditable -and $c.RepairModel.SelectedValue -ceq 'gpt-5.6-sol') 'Repair field is not a detected canonical model picker.'
Assert-DeepUI (@($c.RepairModel.ItemsSource).Count -eq 3 -and $c.ComplexModel.SelectedValue -ceq 'gpt-6-astra') 'Picker includes hidden/unknown models or lost the user choice.'
$c.RoutineModel.SelectedValue='gpt-6-astra'
Assert-DeepUI (@($c.RoutineEffort.ItemsSource).Count -eq 1 -and -not$c.RoutineEffort.SelectedItem) 'Changing model silently escalated unsupported effort.'
$c.RoutineModel.SelectedValue='gpt-5.6-luna';$c.RoutineEffort.SelectedItem='low'
$c.Profile.SelectedValue='Free'
$Script:PolicyFixture.Save.RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Button]::ClickEvent))
Assert-DeepUI ((Get-PMMAIPolicy).Profile -eq 'Free' -and (Get-PMMAIPolicy).ServiceTier -eq 'default') ('AI policy UI did not persist the profile and standard speed: '+$Script:PolicyFixture.Status.Text)

Assert-DeepUI ((Get-PMMAIPolicy).RepairModel -ceq 'gpt-5.6-sol' -and (Get-PMMAIPolicy).ComplexModel -ceq 'gpt-6-astra') 'Save lost the selected repair/complex models.'
# Refresh success/failure update the currently open dialog, without inference.
Show-PMMAIPolicyDialog
function Start-PMMBackgroundOperation($Operation,$RequestPath,$OnSuccess,$OnFailure){
  $Script:PolicyRefreshCallback=$OnSuccess;$Script:PolicyRefreshFailure=$OnFailure
  return $true
}
$state=$Script:PolicyFixture.Save.Tag
$state.Refresh.RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Button]::ClickEvent))
Assert-DeepUI (-not$state.Refresh.IsEnabled) 'Refresh did not stay asynchronous.'
& $Script:PolicyRefreshCallback @{}
Assert-DeepUI ($state.Refresh.IsEnabled -and $state.Controls.RepairModel.SelectedValue -ceq 'gpt-5.6-sol') 'Refresh did not update the open dialog or changed choices.'
$state.Refresh.RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Button]::ClickEvent))
& $Script:PolicyRefreshFailure 'Fixture connection unavailable'
Assert-DeepUI ($state.Status.Text -eq 'Fixture connection unavailable' -and $state.Refresh.IsEnabled) 'Refresh failure was hidden outside the dialog.'

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
