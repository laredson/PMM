$script:entryChecks=0
function Assert-Entry($condition,[string]$message){if(-not$condition){throw $message};$script:entryChecks++}
Assert-Entry ($Window.Title -like '*1.3.3') 'Window title retained the old XAML version.'
Assert-Entry ($Script:LstMods.ContextMenu.Items[0].Header -eq (L 'Create new case...' 'Crear nuevo caso...')) 'Library context menu is missing or not localized.'
$mods=Join-PMMPath 'Mods';foreach($folder in @('AUAT-test','Other-test')){[void][IO.Directory]::CreateDirectory((Join-Path $mods $folder))};[IO.File]::WriteAllText((Join-Path $mods 'AUAT-test/AUAT-test.pak'),'AUAT fixture')
[IO.File]::WriteAllText((Join-Path $mods 'Other-test/Other-test.pak'),'Other fixture')
# Use the real library scan and display projection; do not synthesize UI rows.
Set-PMMLibraryModEnabled 'Other-test.pak' $false|Out-Null
Refresh-UI
$rows=@($Script:LstMods.ItemsSource)
Assert-Entry ($rows.Count -eq 2 -and @($rows|Where-Object Enabled).Count -eq 1) 'The real library did not include active and disabled sources.'
foreach($entry in $rows){
  Assert-Entry ($entry.PSObject.Properties.Name -contains 'Path' -and $entry.PSObject.Properties.Name -contains 'Hash') 'The production display row lost the source path/full hash.'
  Assert-Entry ([IO.File]::Exists($entry.Path) -and $entry.Hash -ceq (Get-Sha256 $entry.Path)) 'Display identity does not match the scanned source.'
}
$Script:LstMods.SelectedIndex=1
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
Assert-Entry ($case.Title -eq 'AUAT 1.0.4' -and $case.References.Mods.Count -eq 1 -and $case.References.Mods[0].Sha256 -eq (Get-Sha256 (Join-Path $mods 'AUAT-test/AUAT-test.pak'))) 'Case lost the exact selected mod/hash.'
Assert-Entry ($case.Transport -eq 'MCP' -and (Get-PMMCaseClient $case) -eq 'CHATGPT') 'New mod case does not default to GPTD.'
Assert-Entry (@((Get-PMMAIIOCaseControl 'DgRefs').ItemsSource).Count -eq 1 -and $Script:PMMCaseArea -eq 'FIX') 'New case did not navigate to its references.'
$Script:Launches=0;$Script:DesktopOpens=0;$Script:DesktopHelp=0
function Start-PMMRepairAgentJob([string]$SessionId){$Script:Launches++;throw 'Desktop started an internal worker.'}
function Get-PMMChatGPTDesktop($Destination){return [pscustomobject]@{SupportsLocalChats=$true;InstallLocation='fixture'}}
function Open-PMMDesktopLink($Link,$Destination){$Script:DesktopOpens++;return $true}
function Show-PMMDesktopDispatchHelp($Dispatch,$CanOpen){$Script:DesktopHelp++}
$b=New-PMMDesktopBinding;Confirm-PMMDesktopBinding ([pscustomobject]@{nonce=$b.nonce})|Out-Null
Show-PMMChatGPTCase
Show-PMMChatGPTCase
Assert-Entry ($Script:Launches -eq 0 -and $Script:DesktopOpens -eq 1 -and $Script:DesktopHelp -eq 1) 'Desktop duplicated its chat or launched hidden AI.'
Assert-Entry ((Get-PMMDesktopDispatch $case.CaseId).prompt -match 'Fix Lab KL recipe') 'Desktop initial report omitted the user outcome choices.'
Assert-Entry ($null -eq (Get-PMMCaseRepairSession $case.CaseId)) 'Desktop dispatch created an internal repair session.'
Assert-Entry ($Script:PMMAIIOCaseUI.ContainsKey('ChatTranscript') -and -not(Get-PMMAIIOCaseControl 'ChatAdvanced').IsExpanded) 'AI chat or collapsed advanced settings are missing.'
Assert-Entry (-not(Get-PMMAIPolicy).InternalEnabled) 'Internal inference is enabled by default.'
Update-PMMMCPReplyUI
Assert-Entry ((Get-PMMAIIOCaseControl 'TxtMCPReplyStatus').Text -match 'prepared|preparado') 'Unacknowledged Desktop opening was reported as delivery.'
$empty=New-PMMAIIOCase -Title 'Empty repair' -Type FIX_MOD -Transport MCP -AIClient CHATGPT
Select-PMMCaseLocation $empty;$blocked=$false
try{Show-PMMChatGPTCase}catch{$blocked=$_.Exception.Message -match 'Attach|Adjunta'}
Assert-Entry $blocked 'An empty manual repair case was silently sent without a PAK.'
# The same real display rows must support disabled and multiple selected sources.
$Script:MainTabs.SelectedItem=$Script:PMMMergeTab;$Script:PMMMergeTab.Content.SelectedIndex=0
$Script:LstMods.SelectedItem=@($Script:LstMods.ItemsSource|Where-Object Name -eq 'Other-test.pak')[0]
$Script:LstMods.ContextMenu.Items[0].RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.MenuItem]::ClickEvent))
$disabledCase=Get-PMMAIIOSelectedCase
$disabledSource=@(Get-PMMDisabledMods|Where-Object Name -eq 'Other-test.pak')[0]
Assert-Entry ($disabledCase.References.Mods.Count -eq 1 -and $disabledCase.References.Mods[0].Path -ceq $disabledSource.Path -and $disabledCase.References.Mods[0].Sha256 -ceq $disabledSource.Hash) 'Disabled source case lost the actual PAK path or full hash.'
$Script:MainTabs.SelectedItem=$Script:PMMMergeTab;$Script:PMMMergeTab.Content.SelectedIndex=0
$Script:LstMods.SelectAll()
$Script:LstMods.ContextMenu.Items[0].RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.MenuItem]::ClickEvent))
$multiple=Get-PMMAIIOSelectedCase
Assert-Entry ($multiple.Type -eq 'COMPATIBILITY' -and $multiple.References.Mods.Count -eq 2) 'Multiple production rows did not create a compatibility case with both sources.'
$Script:MainTabs.SelectedItem=$Script:PMMMergeTab;$Script:PMMMergeTab.Content.SelectedIndex=0
$Script:LstMods.SelectedItem=@($Script:LstMods.ItemsSource|Where-Object Name -eq 'AUAT-test.pak')[0]
$manual=New-PMMAIIOCase -Title 'Manual context' -Type COMPATIBILITY
$Script:PMMCaseArea='MERGE'
Add-PMMCaseAreaContext $manual.CaseId
$manual=Get-PMMAIIOCase $manual.CaseId
Assert-Entry ($manual.References.Mods.Count -eq 1 -and $manual.References.Mods[0].Name -eq 'AUAT-test.pak') 'The manual new-case action silently lost the selected real library source.'
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

$case=Get-PMMAIIOSelectedCase
Select-PMMCaseLocation $case
(Get-PMMAIIOCaseControl 'ChatTabs').SelectedIndex=1
Update-PMMChatPanel $case
Assert-Entry ((Get-PMMAIIOCaseControl 'ChatTranscript').Text -match [regex]::Escape($case.CaseId)) 'Chat tab displays another case history.'
Assert-Entry (-not(Get-PMMAIIOCaseControl 'ChatSend').IsEnabled) 'Desktop case enabled internal prompt sending.'
(Get-PMMAIIOCaseControl 'ChatAdvanced').IsExpanded=$true
$Window.Content.Measure([Windows.Size]::new(1600,1050));$Window.Content.Arrange([Windows.Rect]::new(0,0,1600,1050));$Window.Content.UpdateLayout()
$bitmap=[Windows.Media.Imaging.RenderTargetBitmap]::new(1600,1050,96,96,[Windows.Media.PixelFormats]::Pbgra32)
$bitmap.Render($Window.Content)
$encoder=[Windows.Media.Imaging.PngBitmapEncoder]::new();$encoder.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($bitmap))
$png=Join-Path $Script:Root 'chat-ui.png';$stream=[IO.File]::Create($png);try{$encoder.Save($stream)}finally{$stream.Dispose()}
Write-Output ('Chat fixture: '+$png)
Write-Output ('PASS case entry '+$Language+': '+$script:entryChecks+' assertions')
