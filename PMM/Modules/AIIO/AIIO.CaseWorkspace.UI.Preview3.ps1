<# AIIO Case Workspace preview 3 runtime fixes.
   Windows PowerShell 5.1 can scalarize a one-item command result when assigning
   directly to WPF ItemsSource. Use the DataGrid Items collection instead so
   zero, one and many rows follow exactly the same path. #>

function Set-PMMAIIOCaseGridRows($Grid,$Rows){
  if(-not$Grid){return}
  $Grid.ItemsSource=$null
  $Grid.Items.Clear()
  foreach($row in @($Rows)){
    if($null -ne $row){[void]$Grid.Items.Add($row)}
  }
}

function Select-PMMAIIOCaseRow([string]$Id){
  $grid=Get-PMMAIIOCaseControl 'DgCases'
  if(-not$grid){return}
  foreach($row in @($grid.Items)){
    if([string](Get-PMMAIIOCaseValue $row 'CaseId' '') -eq $Id){
      $grid.SelectedItem=$row
      $grid.ScrollIntoView($row)
      return
    }
  }
}

function Refresh-PMMAIIOCaseList([string]$SelectId=''){
  $grid=Get-PMMAIIOCaseControl 'DgCases'
  if(-not$grid){return}
  $keep=if($SelectId){$SelectId}elseif($Script:PMMAIIOCaseSelectedId){$Script:PMMAIIOCaseSelectedId}else{''}
  $rows=@(Get-PMMAIIOCaseRows)
  Set-PMMAIIOCaseGridRows $grid $rows
  if($keep){
    Select-PMMAIIOCaseRow $keep
    if(-not$grid.SelectedItem -and $grid.Items.Count -gt 0){$grid.SelectedIndex=0}
  }elseif($grid.Items.Count -gt 0){
    $grid.SelectedIndex=0
  }else{
    $Script:PMMAIIOCaseSelectedId=''
    Show-PMMAIIOCaseEditor
  }
}

function Show-PMMAIIOCaseEditor{
  $case=Get-PMMAIIOSelectedCase
  $controls=@('TxtTitle','CmbType','TxtDescription','CmbTransport','BtnSave','BtnHandoff','BtnFolder','BtnAuto','BtnCancel','BtnLast','BtnNext','BtnAddPak','BtnAddModFamily','BtnAddVanilla','BtnRemoveRef')
  foreach($name in $controls){$control=Get-PMMAIIOCaseControl $name;if($control){$control.IsEnabled=($null -ne $case)}}

  $referenceGrid=Get-PMMAIIOCaseControl 'DgRefs'
  if(-not$case){
    (Get-PMMAIIOCaseControl 'TxtHeader').Text='Select or create a case'
    (Get-PMMAIIOCaseControl 'TxtPosition').Text=''
    (Get-PMMAIIOCaseControl 'TxtProgress').Text='No case selected'
    $bar=Get-PMMAIIOCaseControl 'PrgProgress';$bar.IsIndeterminate=$false;$bar.Value=0
    Set-PMMAIIOCaseGridRows $referenceGrid @()
    (Get-PMMAIIOCaseControl 'PnlHistory').Children.Clear()
    (Get-PMMAIIOCaseControl 'TxtListStatus').Text='No case selected'
    Set-PMMAIIOCaseNextHighlight $null
    return
  }

  $caseId=[string](Get-PMMAIIOCaseValue $case 'CaseId' '')
  $current=[int](Get-PMMAIIOCaseValue $case 'CurrentStep' 0)
  $selected=[int](Get-PMMAIIOCaseValue $case 'SelectedStep' 0)
  if($selected -le 0){$selected=$current}
  $historical=($selected -gt 0 -and $selected -lt $current)
  $view=$case
  if($historical){
    $step=Get-PMMAIIOCaseStep $caseId $selected
    $state=Get-PMMAIIOCaseValue $step 'State' $null
    if($state){$view=$state}
  }

  $title=[string](Get-PMMAIIOCaseValue $view 'Title' (Get-PMMAIIOCaseValue $case 'Title' 'Untitled case'))
  $type=[string](Get-PMMAIIOCaseValue $view 'Type' (Get-PMMAIIOCaseValue $case 'Type' 'UNDEFINED'))
  $description=[string](Get-PMMAIIOCaseValue $view 'Description' '')
  $transport=[string](Get-PMMAIIOCaseValue $view 'Transport' (Get-PMMAIIOCaseValue $case 'Transport' 'AUTO'))
  $lastAction=[string](Get-PMMAIIOCaseValue $case 'LastAction' 'Case created')
  $status=[string](Get-PMMAIIOCaseValue $case 'Status' 'DRAFT')

  (Get-PMMAIIOCaseControl 'TxtHeader').Text=($title+$(if($historical){' - historical Step '+$selected}else{''}))
  (Get-PMMAIIOCaseControl 'TxtTitle').Text=$title
  (Get-PMMAIIOCaseControl 'CmbType').SelectedValue=$type
  (Get-PMMAIIOCaseControl 'TxtDescription').Text=$description
  (Get-PMMAIIOCaseControl 'CmbTransport').SelectedValue=$transport
  Set-PMMAIIOCaseGridRows $referenceGrid @(Get-PMMAIIOReferenceRows $view)

  $pending=[Collections.Generic.List[object]]::new()
  foreach($row in @(Get-PMMAIIOCaseArray $view 'PendingActions')){
    if([string](Get-PMMAIIOCaseValue $row 'Status' 'Pending') -eq 'Pending'){$pending.Add($row)}
  }
  (Get-PMMAIIOCaseControl 'TxtPending').Text=$(if($pending.Count -gt 0){@($pending.ToArray()|ForEach-Object{[string](Get-PMMAIIOCaseValue $_ 'Action' (Get-PMMAIIOCaseValue $_ 'Capability' 'Pending action'))}) -join ', '}else{'No pending work.'})

  $operation=Get-PMMAIIOCaseValue $case 'ActiveOperation' $null
  $running=[bool](Get-PMMAIIOCaseValue $operation 'Running' $false)
  $message=[string](Get-PMMAIIOCaseValue $operation 'Message' '')
  $indeterminate=[bool](Get-PMMAIIOCaseValue $operation 'Indeterminate' $false)
  $opCurrent=[int](Get-PMMAIIOCaseValue $operation 'Current' 0)
  $opTotal=[int](Get-PMMAIIOCaseValue $operation 'Total' 0)
  $bar=Get-PMMAIIOCaseControl 'PrgProgress'
  if($running){
    $bar.IsIndeterminate=$indeterminate
    if(-not$indeterminate -and $opTotal -gt 0){$bar.Value=[Math]::Min(100,[Math]::Floor(100.0*$opCurrent/$opTotal))}
    (Get-PMMAIIOCaseControl 'TxtProgress').Text=$(if($message){$message}else{'Working...'})
  }else{
    $bar.IsIndeterminate=$false
    $bar.Value=100
    (Get-PMMAIIOCaseControl 'TxtProgress').Text=$(if($message){$message}else{$lastAction})
  }

  (Get-PMMAIIOCaseControl 'TxtPosition').Text=('Step '+$selected+' / '+$current)
  $last=Get-PMMAIIOCaseControl 'BtnLast'
  $next=Get-PMMAIIOCaseControl 'BtnNext'
  $previous=if($selected -gt 1){Get-PMMAIIOCaseStep $caseId ($selected-1)}else{$null}
  $following=if($selected -lt $current){Get-PMMAIIOCaseStep $caseId ($selected+1)}else{$null}
  $last.Content=$(if($previous){'Last Step - '+[string](Get-PMMAIIOCaseValue $previous 'Summary' ('Step '+($selected-1)))}else{'Last Step'})
  $last.IsEnabled=($null -ne $previous)
  $next.Content=$(if($following){'Next Step - '+[string](Get-PMMAIIOCaseValue $following 'Summary' ('Step '+($selected+1)))}else{'Current - '+$lastAction})
  $next.IsEnabled=($null -ne $following)

  foreach($name in @('TxtTitle','CmbType','TxtDescription','CmbTransport','BtnSave','BtnAddPak','BtnAddModFamily','BtnAddVanilla','BtnRemoveRef','BtnAuto')){
    $control=Get-PMMAIIOCaseControl $name
    if($control){$control.IsEnabled=(-not$historical)}
  }
  (Get-PMMAIIOCaseControl 'BtnHandoff').IsEnabled=$true
  Show-PMMAIIOHistory $case
  Set-PMMAIIOCaseNextHighlight $case
  (Get-PMMAIIOCaseControl 'TxtListStatus').Text=($type+' | '+$status)
}
