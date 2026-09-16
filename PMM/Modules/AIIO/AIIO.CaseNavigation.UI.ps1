# Loaded after the active editor overrides; identity belongs to the loaded view.
$Script:PMMEditorCaseId=''
$Script:PMMEditorLoading=$false
$Script:PMMCaseRefreshing=$false
$Script:PMMRenderCaseCore=${function:Show-PMMAIIOCaseEditor}
$Script:PMMSaveCaseCore=${function:Save-PMMAIIOCaseEditor}
function Show-PMMAIIOCaseEditor {
    $Script:PMMEditorLoading=$true;$Script:PMMEditorCaseId=''
    try{& $Script:PMMRenderCaseCore;$c=Get-PMMAIIOSelectedCase;if($Script:PMMAIIOCaseUI.ContainsKey('CmbClient')){$client=Get-PMMAIIOCaseControl 'CmbClient';$client.IsEnabled=($c -and ($c.SelectedStep -le 0 -or $c.SelectedStep -eq $c.CurrentStep));$client.SelectedValue=if($c){Get-PMMCaseClient $c}else{'EXTERNAL'};Update-PMMAIIOTransportButton};if($c){$Script:PMMEditorCaseId=$c.CaseId}else{(Get-PMMAIIOCaseControl 'TxtTitle').Text='';(Get-PMMAIIOCaseControl 'TxtDescription').Text=''}}
    finally{$Script:PMMEditorLoading=$false}
}
function Save-PMMAIIOCaseEditor {
    if($Script:PMMEditorLoading -or $Script:PMMCaseRefreshing -or -not $Script:PMMEditorCaseId -or $Script:PMMEditorCaseId -cne $Script:PMMAIIOCaseSelectedId){return $false}
    $before=Get-PMMAIIOSelectedCase
    if($before -and $Script:PMMAIIOCaseUI.ContainsKey('CmbClient')){
        $requestedClient=[string](Get-PMMAIIOCaseControl 'CmbClient').SelectedValue
        $beforeReply=Get-PMMMCPReplyView $before
        if($requestedClient -ne (Get-PMMCaseClient $before) -and ($before.ActiveOperation.Running -or ($beforeReply -and $beforeReply.status -eq 'PROCESSING'))){throw 'Wait for the active client before changing destination.'}
    }
    $changed=(& $Script:PMMSaveCaseCore)
    $c=Get-PMMAIIOSelectedCase
    if($c -and ($c.SelectedStep -le 0 -or $c.SelectedStep -eq $c.CurrentStep) -and $Script:PMMAIIOCaseUI.ContainsKey('CmbClient')){
        $choice=[string](Get-PMMAIIOCaseControl 'CmbClient').SelectedValue
        if($choice -in @('CHATGPT','CODEX_DESKTOP','EXTERNAL','CODEX') -and (Get-PMMCaseClient $c) -ne $choice){
            $reply=Get-PMMMCPReplyView $c
            if($c.ActiveOperation.Running -or ($reply -and $reply.status -eq 'PROCESSING')){throw 'Wait for the active client before changing destination.'}
            $c|Add-Member -NotePropertyName AIClient -NotePropertyValue $choice -Force
            Add-PMMAIIOCaseStep $c 'CLIENT_CHANGED' ('AI client: '+$choice) 'CREATE_HANDOFF' @() $null|Out-Null
            $changed=$true
        }
    }
    if($c -and ($c.SelectedStep -le 0 -or $c.SelectedStep -eq $c.CurrentStep)){Save-PMMDesktopOptionsUI $c}
    if($changed -and $c){Update-PMMCaseContextRevision ([string]$c.CaseId)|Out-Null}
    return $changed
}
function Select-PMMCaseFromGrid {
    if($Script:PMMCaseRefreshing -or $Script:PMMEditorLoading){return}
    $r=(Get-PMMAIIOCaseControl 'DgCases').SelectedItem
    if(-not $r -or $r -is [array] -or -not (Test-PMMAIIOCaseId ([string]$r.CaseId))){return}
    if($Script:PMMAIIOCaseSelectedId -ne $r.CaseId){[void](Save-PMMAIIOCaseEditor)}
    $Script:PMMAIIOCaseSelectedId=[string]$r.CaseId
    $c=Get-PMMAIIOSelectedCase
    if($c){$c.SelectedStep=$c.CurrentStep;Save-PMMAIIOCase $c|Out-Null}
    Show-PMMAIIOCaseEditor
}
function Refresh-PMMAIIOCaseList([string]$SelectId=''){
    $grid=Get-PMMAIIOCaseControl 'DgCases';if(-not $grid){return}
    $keep=if($SelectId){$SelectId}else{$Script:PMMAIIOCaseSelectedId}
    $Script:PMMCaseRefreshing=$true
    try{
        $grid.ItemsSource=$null;$grid.Items.Clear()
        foreach($row in @(Get-PMMAIIOCaseRows)){if($row -is [array]){throw 'Case rows must be flat.'};[void]$grid.Items.Add($row)}
        foreach($row in $grid.Items){if($row.CaseId -eq $keep){$grid.SelectedItem=$row;break}}
        if(-not $grid.SelectedItem -and $grid.Items.Count){$grid.SelectedIndex=0}
        $Script:PMMAIIOCaseSelectedId=if($grid.SelectedItem){[string]$grid.SelectedItem.CaseId}else{''}
    }finally{$Script:PMMCaseRefreshing=$false}
    Show-PMMAIIOCaseEditor
}
function Invoke-PMMNewCaseUI {
    [void](Save-PMMAIIOCaseEditor)
    $d=Show-PMMAIIONewCaseDialog
    if(-not $d){return}
    $transport='MCP';$client='CODEX_DESKTOP'
    $c=New-PMMAIIOCase -Title $d.Title -Type $d.Type -Description $d.Description -Transport $transport -AIClient $client
    Add-PMMCaseAreaContext $c.CaseId
    Select-PMMCaseLocation $c
}
function Select-PMMCaseLocation($c){
    if(-not $c){return}
    $area=Get-PMMCaseArea $c.Type
    if($area -ne $Script:PMMCaseArea){
        $Script:PMMAreaSelections[$area]=$c.CaseId
        foreach($tab in $Script:MainTabs.Items){if($tab.Tag -eq $area){$Script:MainTabs.SelectedItem=$tab;break}}
        Switch-PMMCaseArea $area
    }
    foreach($mainTab in $Script:MainTabs.Items){
      if([string]$mainTab.Tag -eq $area){
        $Script:MainTabs.SelectedItem=$mainTab
        if($mainTab.Content -is [Windows.Controls.TabControl]){foreach($subTab in $mainTab.Content.Items){if([string]$subTab.Tag -eq $area){$mainTab.Content.SelectedItem=$subTab;break}}}
        elseif($area -eq 'HELP'){$Script:AIHelpTabs.SelectedItem=$Script:PMMHelpCaseTab}
        break
      }
    }
    $Script:PMMAreaSelections[$area]=$c.CaseId
    Refresh-PMMAIIOCaseList $c.CaseId
}
