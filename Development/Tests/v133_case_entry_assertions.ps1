$script:entryChecks=0
function Assert-Entry($condition,[string]$message){if(-not$condition){throw $message};$script:entryChecks++}
Assert-Entry ($Window.Title -like '*1.3.3') 'Window title retained the old XAML version.'
Assert-Entry ($Script:LstMods.ContextMenu.Items[0].Header -eq (L 'Create new case...' 'Crear nuevo caso...')) 'Library context menu is missing or not localized.'
$mods=Join-PMMPath 'Mods';[IO.File]::WriteAllText((Join-Path $mods 'AUAT-test.pak'),'AUAT fixture')
[IO.File]::WriteAllText((Join-Path $mods 'Other-test.pak'),'Other fixture')
$rows=@(foreach($name in @('AUAT-test.pak','Other-test.pak')){[pscustomobject]@{Kind='Source';Name=$name;Path=(Join-Path $mods $name);State='Active';Order=1;Enabled=$true;SizeMB='0';Hash='';HashShort='';Priority=1}})
$Script:LstMods.ItemsSource=$rows;$Script:LstMods.SelectedIndex=1
$Script:MainTabs.SelectedItem=$Script:PMMMergeTab;$Script:PMMMergeTab.Content.SelectedIndex=0
$Window.Content.Measure([Windows.Size]::new(1600,1050));$Window.Content.Arrange([Windows.Rect]::new(0,0,1600,1050));$Window.Content.UpdateLayout()
$row=$Script:LstMods.ItemContainerGenerator.ContainerFromIndex(0)
Assert-Entry ($null -ne $row) 'WPF did not generate the mod row.'
Select-PMMLibraryContextTarget $Script:LstMods $row
Assert-Entry ($Script:LstMods.SelectedItem.Name -eq 'AUAT-test.pak') 'Right-click did not select the clicked mod.'
$Script:DialogCalls=0
function Show-PMMAIIONewCaseDialog([string]$DefaultTitle,[string]$DefaultType,[array]$ReferenceNames){
  $Script:DialogCalls++;$Script:ReceivedDraft=@{Title=$DefaultTitle;Type=$DefaultType;Refs=$ReferenceNames}
  return @{Title='AUAT 1.0.4';Type=$DefaultType;Description='Update the selected mod.'}
}
$Script:LstMods.ContextMenu.Items[0].RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.MenuItem]::ClickEvent))
$case=Get-PMMAIIOSelectedCase
Assert-Entry ($Script:DialogCalls -eq 1 -and $Script:ReceivedDraft.Type -eq 'FIX_MOD' -and $Script:ReceivedDraft.Refs[0] -eq 'AUAT-test.pak') 'Context command did not open a repair draft for the clicked mod.'
Assert-Entry ($case.Title -eq 'AUAT 1.0.4' -and $case.References.Mods.Count -eq 1 -and $case.References.Mods[0].Sha256 -eq (Get-Sha256 (Join-Path $mods 'AUAT-test.pak'))) 'Case lost the exact selected mod/hash.'
Assert-Entry ($case.Transport -eq 'MCP' -and (Get-PMMCaseClient $case) -eq 'CHATGPT') 'New mod case does not default to GPTD.'
Assert-Entry (@((Get-PMMAIIOCaseControl 'DgRefs').ItemsSource).Count -eq 1 -and $Script:PMMCaseArea -eq 'FIX') 'New case did not navigate to its references.'
$Script:Launches=0
function Start-PMMRepairAgentJob([string]$SessionId){
  $Script:Launches++;$s=Get-PMMRepairSession $SessionId
  $s.Status='Paused';$s.LastMessage='Fixture: runtime unavailable';Save-PMMRepairSession $s;return $s
}
Show-PMMChatGPTCase
$first=Get-PMMCaseRepairSession $case.CaseId
Show-PMMChatGPTCase
$second=Get-PMMCaseRepairSession $case.CaseId
Assert-Entry ($first.Id -eq $second.Id -and $Script:Launches -eq 2) 'Retry created another repair session.'
Update-PMMMCPReplyUI
Assert-Entry ((Get-PMMAIIOCaseControl 'TxtMCPReplyStatus').Text -like '*Fixture: runtime unavailable*') 'The case hid its agent failure behind MCP publication status.'
Assert-Entry ((Get-PMMAIIOCaseControl 'PrgProgress').Value -eq 0 -and -not(Get-PMMAIIOCaseControl 'PrgProgress').IsIndeterminate) 'A failed request looked complete or kept spinning.'
[IO.File]::WriteAllText((Join-Path (Get-PMMRepairSessionRoot $first.Id) 'agent-response.txt'),'AUAT response fixture')
Update-PMMMCPReplyUI
Assert-Entry ((Get-PMMAIIOCaseControl 'TxtMCPResponse').Text -eq 'AUAT response fixture') 'Persistent agent response is not visible in the case.'
$s=Get-PMMRepairSession $first.Id;$s.Status='Running';$s.OwnerPid=$PID;$s.OwnerStart=(Get-Process -Id $PID).StartTime.ToUniversalTime().ToString('o');Save-PMMRepairSession $s
Update-PMMMCPReplyUI
Assert-Entry ((Get-PMMAIIOCaseControl 'PrgProgress').IsIndeterminate -and (Get-PMMAIIOCaseControl 'BtnCancel').IsEnabled) 'Running session has no visible progress/cancellation.'
(Get-PMMAIIOCaseControl 'BtnCancel').RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Button]::ClickEvent))
Assert-Entry ((Get-PMMRepairSession $first.Id).Revoked) 'Case cancel did not revoke its repair session.'
$empty=New-PMMAIIOCase -Title 'Empty repair' -Type FIX_MOD -Transport MCP -AIClient CHATGPT
Select-PMMCaseLocation $empty;$blocked=$false
try{Show-PMMChatGPTCase}catch{$blocked=$_.Exception.Message -match 'Attach|Adjunta'}
Assert-Entry $blocked 'An empty manual repair case was silently sent without a PAK.'
# Exercise the real dialog event binding without opening a modal.
. (Join-Path $Script:Root 'Modules/AIIO/AIIO.CaseWorkspace.UI.Preview4.ps1')
$definition=(Get-Command Show-PMMAIIONewCaseDialog).Definition.Replace('if($dialog.ShowDialog() -eq $true){return $dialog.Tag.Result}','return @{Dialog=$dialog;Create=$create}')
Invoke-Expression ('function Show-PMMAIIONewCaseDialog {'+$definition+'}')
$view=Show-PMMAIIONewCaseDialog -DefaultTitle AUAT -DefaultType FIX_MOD -ReferenceNames @('AUAT-test.pak')
Assert-Entry ($view.Dialog.Tag.Type.SelectedValue -eq 'FIX_MOD') 'Real dialog ignored the requested mod case type.'
$view.Dialog.Tag.Title.Text=''
$view.Create.RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Button]::ClickEvent))
Assert-Entry (-not$view.Dialog.Tag.Result -and $view.Dialog.Tag.Validation.Text) 'Dialog accepted an empty title or lost its bound state.'
$view.Dialog.Tag.Title.Text='AUAT update'
try{$view.Create.RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Button]::ClickEvent))}catch{if($_.Exception.ToString() -notmatch 'DialogResult'){throw}}
Assert-Entry ($view.Dialog.Tag.Result.Title -eq 'AUAT update' -and $view.Dialog.Tag.Result.Type -eq 'FIX_MOD') 'Create button lost its title/type.'
Write-Output ('PASS case entry '+$Language+': '+$script:entryChecks+' assertions')
