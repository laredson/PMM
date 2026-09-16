<# AIIO Case Workspace preview 4.
   AUTO is a transaction over the editable case: save current edits, perform
   every available local action, then create the next handoff. Progress belongs
   in the case footer instead of occupying the step-navigation area. #>

$Script:PMMAIIOPreview4Applied=$false
$Script:PMMAIIOPreview4GetSessions=${function:Get-PMMAIIOSessions}

function Save-PMMAIIOCaseEditor {
  $case=Get-PMMAIIOSelectedCase
  if(-not$case){return $false}
  $current=[int](Get-PMMAIIOCaseValue $case 'CurrentStep' 0)
  $selected=[int](Get-PMMAIIOCaseValue $case 'SelectedStep' 0)
  if($selected -gt 0 -and $selected -lt $current){return $false}

  $newTitle=[string](Get-PMMAIIOCaseControl 'TxtTitle').Text
  $newType=Normalize-PMMAIIOCaseType ([string](Get-PMMAIIOCaseControl 'CmbType').SelectedValue)
  $newDescription=[string](Get-PMMAIIOCaseControl 'TxtDescription').Text
  $newTransport=Normalize-PMMAIIOCaseTransport ([string](Get-PMMAIIOCaseControl 'CmbTransport').SelectedValue)
  $changes=[Collections.Generic.List[string]]::new()

  if([string](Get-PMMAIIOCaseValue $case 'Title' '') -cne $newTitle){$changes.Add('title')}
  if([string](Get-PMMAIIOCaseValue $case 'Type' 'UNDEFINED') -cne $newType){$changes.Add('type')}
  if([string](Get-PMMAIIOCaseValue $case 'Description' '') -cne $newDescription){$changes.Add('description')}
  if([string](Get-PMMAIIOCaseValue $case 'Transport' 'AUTO') -cne $newTransport){$changes.Add('transport')}

  if($changes.Count -eq 0){return $false}

  $case.Title=$newTitle
  $case.Type=$newType
  $case.Description=$newDescription
  $case.Transport=$newTransport
  # Any previously generated handoff is stale as soon as the editable case
  # changes. The new current step must therefore lead to a fresh handoff.
  $case.NextAction='CREATE_HANDOFF'
  $case.Status='READY_FOR_HANDOFF'
  Save-PMMAIIOCase $case|Out-Null
  $summary='Edited case: '+($changes.ToArray() -join ', ')
  Add-PMMAIIOCaseStep $case 'CASE_EDITED' $summary 'CREATE_HANDOFF' @() ([pscustomobject]@{Changed=@($changes.ToArray())})|Out-Null
  return $true
}

function Invoke-PMMAIIOAutoCaseUiV4 {
  $case=Get-PMMAIIOSelectedCase
  if(-not$case){return}

  # First commit exactly what the user can currently see/edit. This prevents
  # refreshes or later operations from restoring the previous disk snapshot.
  [void](Save-PMMAIIOCaseEditor)
  $case=Get-PMMAIIOCase ([string]$case.CaseId)
  if(-not$case){throw 'Case disappeared while AUTO was running.'}
  Reset-PMMAIIOCaseAutomation

  $guard=0
  while($guard -lt 20){
    $guard++
    if($Script:PMMAIIOCaseCancelRequested){
      Set-PMMAIIOCaseUiStatus 'AUTO cancelled by user.'
      Refresh-PMMAIIOCaseList ([string]$case.CaseId)
      return
    }

    $case=Get-PMMAIIOCase ([string]$case.CaseId)
    $next=[string](Get-PMMAIIOCaseValue $case 'NextAction' '')

    if($next -eq 'PROCESS_REQUESTS'){
      [void](Invoke-PMMAIIOCasePendingActions ([string]$case.CaseId))
      continue
    }

    if($next -in @('CREATE_HANDOFF','EDIT_OR_CREATE_HANDOFF')){
      $fromStep=[int](Get-PMMAIIOCaseValue $case 'CurrentStep' 0)
      if($fromStep -lt 1){throw 'The case has no current step to export.'}
      Set-PMMAIIOCaseProgress ([string]$case.CaseId) 0 1 'Creating AI handoff...'
      $result=New-PMMAIIOCaseHandoff ([string]$case.CaseId) $fromStep
      Set-PMMAIIOCaseProgress ([string]$case.CaseId) 1 1 ('Handoff ready: '+[IO.Path]::GetFileName([string]$result.ZipPath)) -Completed
      Refresh-PMMAIIOCaseList ([string]$case.CaseId)
      Set-PMMAIIOCaseUiStatus ('AUTO complete. Handoff ready: '+[IO.Path]::GetFileName([string]$result.ZipPath))
      return
    }

    if($next -eq 'WAIT_FOR_AI'){
      Refresh-PMMAIIOCaseList ([string]$case.CaseId)
      Set-PMMAIIOCaseUiStatus 'AUTO complete. Waiting for AI input.'
      return
    }

    if($next -in @('USER_DECISION','REVIEW_CANDIDATE')){
      Refresh-PMMAIIOCaseList ([string]$case.CaseId)
      Set-PMMAIIOCaseUiStatus ('AUTO paused for supervision: '+(Get-PMMAIIOCaseNextLabel $next))
      return
    }

    # Be tolerant of imported work orders that contain pending actions but did
    # not explicitly set NextAction yet.
    $pending=0
    foreach($action in @(Get-PMMAIIOCaseArray $case 'PendingActions')){
      if([string](Get-PMMAIIOCaseValue $action 'Status' 'Pending') -eq 'Pending'){$pending++}
    }
    if($pending -gt 0){
      $case.NextAction='PROCESS_REQUESTS';Save-PMMAIIOCase $case|Out-Null
      continue
    }

    # A normal draft with no local work still ends by handing the current case
    # to the AI, which is the useful meaning of AUTO here.
    $case.NextAction='CREATE_HANDOFF';$case.Status='READY_FOR_HANDOFF';Save-PMMAIIOCase $case|Out-Null
  }
  throw 'AIIO AUTO exceeded its local step guard.'
}

function Install-PMMAIIOAutoButtonV4 {
  $old=Get-PMMAIIOCaseControl 'BtnAuto'
  if(-not$old){return}
  $parent=$old.Parent
  if(-not$parent -or -not($parent.PSObject.Properties.Name -contains 'Children')){return}
  $index=$parent.Children.IndexOf($old)
  if($index -lt 0){return}

  $button=[Windows.Controls.Button]::new()
  $button.Content='AUTO';$button.FontWeight='Bold';$button.MinWidth=90
  try{$button.Margin=$old.Margin}catch{}
  try{$button.Padding=$old.Padding}catch{}
  try{if($old.Style){$button.Style=$old.Style}}catch{}
  [void]$parent.Children.Remove($old)
  $parent.Children.Insert($index,$button)
  $Script:PMMAIIOCaseUI['BtnAuto']=$button
  $button.Add_Click({try{Invoke-PMMAIIOAutoCaseUiV4}catch{Handle-UIError $_ 'AIIO AUTO'}})
}

function Move-PMMAIIOProgressToFooterV4 {
  $progressText=Get-PMMAIIOCaseControl 'TxtProgress'
  $bar=Get-PMMAIIOCaseControl 'PrgProgress'
  $status=Get-PMMAIIOCaseControl 'TxtStatus'
  if(-not$progressText -or -not$bar -or -not$status){return}
  $progressGrid=$progressText.Parent
  if(-not$progressGrid){return}
  $progressBorder=$progressGrid.Parent
  if(-not$progressBorder){return}
  $rootGrid=$progressBorder.Parent
  if(-not$rootGrid){return}

  # Remove the standalone status line and reuse it inside the progress card.
  try{[void]$rootGrid.Children.Remove($status)}catch{}
  while($progressGrid.RowDefinitions.Count -lt 3){[void]$progressGrid.RowDefinitions.Add([Windows.Controls.RowDefinition]::new())}
  [Windows.Controls.Grid]::SetRow($status,2)
  $status.Margin=[Windows.Thickness]::new(0,5,0,0)
  [void]$progressGrid.Children.Add($status)

  # The original progress card occupied row 2, directly below step navigation.
  # Put it in the footer row instead; row 2 then collapses naturally to zero.
  [Windows.Controls.Grid]::SetRow($progressBorder,4)
  $progressBorder.Margin=[Windows.Thickness]::new(0,6,0,0)
}

function Copy-PMMAIIOMainResourcesToDialogV4($Dialog){
  try{foreach($key in @($Window.Resources.Keys)){if(-not$Dialog.Resources.Contains($key)){$Dialog.Resources[$key]=$Window.Resources[$key]}}}catch{}
}

function Show-PMMAIIONewCaseDialog {
  param([string]$DefaultTitle='',[string]$DefaultType='',[array]$ReferenceNames=@())
  $dialog=[Windows.Window]::new();$dialog.Title=L 'Create new case' 'Crear nuevo caso'
  $dialog.Width=700;$dialog.SizeToContent='Height';$dialog.MaxHeight=760;$dialog.ResizeMode='CanResize';$dialog.MinWidth=480
  $dialog.WindowStartupLocation='CenterOwner';try{$dialog.Owner=$Window}catch{};Copy-PMMAIIOMainResourcesToDialogV4 $dialog
  $dialog.Background=Get-PMMAIIODialogBrush 'AppBackground' ([Windows.Media.Brushes]::WhiteSmoke);$dialog.Foreground=Get-PMMAIIODialogBrush 'PrimaryText' ([Windows.Media.Brushes]::Black);$dialog.FontFamily='Segoe UI';$dialog.FontSize=13
  $scroll=[Windows.Controls.ScrollViewer]::new();$scroll.VerticalScrollBarVisibility='Auto'
  $root=[Windows.Controls.StackPanel]::new();$root.Margin=[Windows.Thickness]::new(22);$scroll.Content=$root
  $heading=[Windows.Controls.TextBlock]::new();$heading.Text=$dialog.Title;$heading.FontSize=22;$heading.FontWeight='SemiBold';[void]$root.Children.Add($heading)
  $intro=[Windows.Controls.TextBlock]::new();$intro.Text=L 'Choose the goal. The case keeps its references and conversation; creating it does not send an AI request.' 'Indica el objetivo. El caso conserva sus referencias y conversacion; crearlo no envia una peticion a la IA.';$intro.TextWrapping='Wrap';$intro.Margin=[Windows.Thickness]::new(0,6,0,12);[void]$root.Children.Add($intro)
  if($ReferenceNames.Count){
    $refs=[Windows.Controls.TextBlock]::new();$refs.Text=(L 'Attached mods: ' 'Mods adjuntos: ')+($ReferenceNames -join ', ');$refs.TextWrapping='Wrap';$refs.MaxHeight=90;$refs.Margin=[Windows.Thickness]::new(0,0,0,12);[void]$root.Children.Add($refs)
  }
  [void]$root.Children.Add((New-PMMAIIODialogLabel (L 'Title' 'Titulo') $true))
  $title=[Windows.Controls.TextBox]::new();$title.Text=$DefaultTitle;$title.MinHeight=32;Set-PMMAIIODialogInputStyle $title;[void]$root.Children.Add($title)
  [void]$root.Children.Add((New-PMMAIIODialogLabel (L 'Case type' 'Tipo de caso') $true))
  $type=[Windows.Controls.ComboBox]::new();$type.MinHeight=32;$type.DisplayMemberPath='Label';$type.SelectedValuePath='Value'
  $type.ItemsSource=@(
    [pscustomobject]@{Value='NEW_MOD';Label=(L 'New mod' 'Nuevo mod')},
    [pscustomobject]@{Value='FIX_MOD';Label=(L 'Update / repair mod' 'Actualizar / reparar mod')},
    [pscustomobject]@{Value='COMPATIBILITY';Label=(L 'Compatibility' 'Compatibilidad')},
    [pscustomobject]@{Value='UNDEFINED';Label=(L 'Research' 'Investigacion')}
  )
  $area=Get-Variable PMMCaseArea -Scope Script -ValueOnly -ErrorAction SilentlyContinue
  $type.SelectedValue=if($DefaultType){$DefaultType}else{switch($area){'FIX'{'FIX_MOD'};'MERGE'{'COMPATIBILITY'};'HELP'{'UNDEFINED'};default{'NEW_MOD'}}}
  [void]$root.Children.Add($type)
  [void]$root.Children.Add((New-PMMAIIODialogLabel (L 'Description / goal' 'Descripcion / objetivo') $true))
  $description=[Windows.Controls.TextBox]::new();$description.AcceptsReturn=$true;$description.TextWrapping='Wrap';$description.VerticalScrollBarVisibility='Auto';$description.Height=105;Set-PMMAIIODialogInputStyle $description;[void]$root.Children.Add($description)
  $validation=[Windows.Controls.TextBlock]::new();$validation.TextWrapping='Wrap';[void]$root.Children.Add($validation)
  $buttons=[Windows.Controls.StackPanel]::new();$buttons.Orientation='Horizontal';$buttons.HorizontalAlignment='Right';$buttons.Margin=[Windows.Thickness]::new(0,14,0,0)
  $cancel=[Windows.Controls.Button]::new();$cancel.Content=L 'Cancel' 'Cancelar';$cancel.MinWidth=100;$cancel.IsCancel=$true
  $create=[Windows.Controls.Button]::new();$create.Content=L 'Create case' 'Crear caso';$create.MinWidth=120;$create.IsDefault=$true;$create.Margin=[Windows.Thickness]::new(8,0,0,0)
  [void]$buttons.Children.Add($cancel);[void]$buttons.Children.Add($create);[void]$root.Children.Add($buttons)
  $dialog.Tag=@{Title=$title;Type=$type;Description=$description;Validation=$validation;Result=$null}
  $create.Tag=$dialog;$create.Add_Click({
    param($sender,$eventArgs)
    $window=$sender.Tag;$state=$window.Tag
    if([string]::IsNullOrWhiteSpace($state.Title.Text)){$state.Validation.Text=L 'Enter a title.' 'Escribe un titulo.';return}
    $state.Result=[pscustomobject]@{Title=$state.Title.Text.Trim();Type=[string]$state.Type.SelectedValue;Description=[string]$state.Description.Text}
    $window.DialogResult=$true
  })
  $dialog.Content=$scroll
  if($dialog.ShowDialog() -eq $true){return $dialog.Tag.Result}
  return $null
}

function Initialize-PMMAIIOPreview4Ui {
  if($Script:PMMAIIOPreview4Applied -or -not$Script:PMMAIIOCaseWorkspaceInitialized){return}
  Install-PMMAIIOAutoButtonV4
  Move-PMMAIIOProgressToFooterV4
  $Script:PMMAIIOPreview4Applied=$true
  try{Write-PMMLog 'AIIO Case Workspace preview 4 UI behavior applied.'}catch{}
}

# Wrap the existing lazy session accessor. Its first call initializes the Case
# Workspace; this wrapper then performs the one-time visual/event replacement.
function Get-PMMAIIOSessions {
  $rows=@(& $Script:PMMAIIOPreview4GetSessions)
  if(-not$Script:PMMAIIOPreview4Applied){try{Initialize-PMMAIIOPreview4Ui}catch{try{Write-PMMLog ('AIIO preview 4 init failed: '+$_.Exception.Message)}catch{}}}
  return $rows
}
