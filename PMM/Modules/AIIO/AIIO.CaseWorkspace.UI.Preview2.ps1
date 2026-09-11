<# AIIO Case Workspace preview 2 UI corrections. Loaded after the base V3 UI. #>

function Get-PMMAIIOCaseValue($Object,[string]$Name,$Default=$null){
  if($null -eq $Object){return $Default}
  try{$property=$Object.PSObject.Properties[$Name];if($property){return $property.Value}}catch{}
  return $Default
}

function Get-PMMAIIOCaseArray($Object,[string]$Name){
  $value=Get-PMMAIIOCaseValue $Object $Name $null
  if($null -eq $value){return @()}
  return @($value)
}

function Refresh-PMMAIIOCaseList([string]$SelectId=''){
  $grid=Get-PMMAIIOCaseControl 'DgCases'
  if(-not$grid){return}
  $keep=if($SelectId){$SelectId}elseif($Script:PMMAIIOCaseSelectedId){$Script:PMMAIIOCaseSelectedId}else{''}
  [object[]]$rows=@(Get-PMMAIIOCaseRows)
  $grid.ItemsSource=$rows
  if($keep){
    Select-PMMAIIOCaseRow $keep
  }elseif($rows.Count -gt 0){
    $grid.SelectedIndex=0
  }else{
    $Script:PMMAIIOCaseSelectedId=''
    Show-PMMAIIOCaseEditor
  }
}

function Get-PMMAIIOReferenceRows($Case){
  $rows=[Collections.Generic.List[object]]::new()
  $references=Get-PMMAIIOCaseValue $Case 'References' $null
  $mods=Get-PMMAIIOCaseArray $references 'Mods'
  $vanilla=Get-PMMAIIOCaseArray $references 'VanillaFamilies'
  $index=0
  foreach($reference in $mods){
    $mode=[string](Get-PMMAIIOCaseValue $reference 'Mode' 'FULL_PAK')
    $families=@(Get-PMMAIIOCaseArray $reference 'Families')
    $rows.Add([pscustomobject]@{Bucket='Mods';Index=$index;Kind='Mod';Source=[string](Get-PMMAIIOCaseValue $reference 'Name' 'Mod');Mode=$mode;Selection=$(if($mode -eq 'FAMILIES'){$families -join ', '}else{'Full PAK'})})
    $index++
  }
  $index=0
  foreach($reference in $vanilla){
    $logical=[string](Get-PMMAIIOCaseValue $reference 'LogicalPath' '')
    $rows.Add([pscustomobject]@{Bucket='Vanilla';Index=$index;Kind='Vanilla';Source=[IO.Path]::GetFileName($logical);Mode='Family';Selection=$logical})
    $index++
  }
  return [object[]]$rows.ToArray()
}

function Show-PMMAIIOHistory($Case){
  $panel=Get-PMMAIIOCaseControl 'PnlHistory'
  $panel.Children.Clear()
  if(-not$Case){return}
  $caseId=[string](Get-PMMAIIOCaseValue $Case 'CaseId' '')
  $current=[int](Get-PMMAIIOCaseValue $Case 'CurrentStep' 0)
  foreach($step in @(Get-PMMAIIOCaseSteps $caseId)){
    $number=[int](Get-PMMAIIOCaseValue $step 'StepNumber' 0)
    $summary=[string](Get-PMMAIIOCaseValue $step 'Summary' ('Step '+$number))
    $kind=[string](Get-PMMAIIOCaseValue $step 'Kind' 'STEP')
    $utc=[string](Get-PMMAIIOCaseValue $step 'Utc' '')

    $expander=[Windows.Controls.Expander]::new();$expander.IsExpanded=$false;$expander.Margin=[Windows.Thickness]::new(0,2,0,2)
    $header=[Windows.Controls.Grid]::new();[void]$header.ColumnDefinitions.Add([Windows.Controls.ColumnDefinition]::new());$buttonColumn=[Windows.Controls.ColumnDefinition]::new();$buttonColumn.Width=[Windows.GridLength]::Auto;[void]$header.ColumnDefinitions.Add($buttonColumn)
    $text=[Windows.Controls.TextBlock]::new();$text.Text=$summary;$text.TextTrimming='CharacterEllipsis';$text.VerticalAlignment='Center';[void]$header.Children.Add($text)
    $button=[Windows.Controls.Button]::new();$button.Content=$(if($number -eq $current){'Current'}else{'Step '+$number});$button.Tag=$number;[Windows.Controls.Grid]::SetColumn($button,1);[void]$header.Children.Add($button)
    $handler={param($sender,$e)try{[void](Set-PMMAIIOCaseSelectedStep $Script:PMMAIIOCaseSelectedId ([int]$sender.Tag));Show-PMMAIIOCaseEditor}catch{Handle-UIError $_ 'Open AIIO step'}};$button.Add_Click($handler);$expander.Header=$header
    $border=[Windows.Controls.Border]::new();$border.BorderBrush=$Window.Resources['CardBorder'];$border.BorderThickness=[Windows.Thickness]::new(1);$border.CornerRadius=[Windows.CornerRadius]::new(4);$border.Padding=[Windows.Thickness]::new(6)
    $body=[Windows.Controls.TextBlock]::new();$body.Text=('Step '+$number+' | '+$kind+' | '+$utc+"`n"+$summary);$body.TextWrapping='Wrap';$body.Foreground=$Window.Resources['MutedText'];$border.Child=$body;$expander.Content=$border;[void]$panel.Children.Add($expander)
  }
}

function Show-PMMAIIOCaseEditor{
  $case=Get-PMMAIIOSelectedCase
  $controls=@('TxtTitle','CmbType','TxtDescription','CmbTransport','BtnSave','BtnHandoff','BtnFolder','BtnAuto','BtnCancel','BtnLast','BtnNext','BtnAddPak','BtnAddModFamily','BtnAddVanilla','BtnRemoveRef')
  foreach($name in $controls){$control=Get-PMMAIIOCaseControl $name;if($control){$control.IsEnabled=($null -ne $case)}}
  if(-not$case){
    (Get-PMMAIIOCaseControl 'TxtHeader').Text='Select or create a case';(Get-PMMAIIOCaseControl 'TxtPosition').Text='';(Get-PMMAIIOCaseControl 'TxtProgress').Text='No case selected';(Get-PMMAIIOCaseControl 'PrgProgress').Value=0;(Get-PMMAIIOCaseControl 'DgRefs').ItemsSource=[object[]]@();(Get-PMMAIIOCaseControl 'PnlHistory').Children.Clear();(Get-PMMAIIOCaseControl 'TxtListStatus').Text='No case selected';Set-PMMAIIOCaseNextHighlight $null;return
  }

  $current=[int](Get-PMMAIIOCaseValue $case 'CurrentStep' 0);$selected=[int](Get-PMMAIIOCaseValue $case 'SelectedStep' 0);if($selected -le 0){$selected=$current}
  $historical=($selected -gt 0 -and $selected -lt $current);$view=$case
  if($historical){$step=Get-PMMAIIOCaseStep ([string](Get-PMMAIIOCaseValue $case 'CaseId' '')) $selected;$state=Get-PMMAIIOCaseValue $step 'State' $null;if($state){$view=$state}}

  $title=[string](Get-PMMAIIOCaseValue $view 'Title' (Get-PMMAIIOCaseValue $case 'Title' 'Untitled case'))
  $type=[string](Get-PMMAIIOCaseValue $view 'Type' (Get-PMMAIIOCaseValue $case 'Type' 'UNDEFINED'))
  $description=[string](Get-PMMAIIOCaseValue $view 'Description' '')
  $transport=[string](Get-PMMAIIOCaseValue $view 'Transport' (Get-PMMAIIOCaseValue $case 'Transport' 'AUTO'))
  $caseId=[string](Get-PMMAIIOCaseValue $case 'CaseId' '')
  $lastAction=[string](Get-PMMAIIOCaseValue $case 'LastAction' 'Case created')
  $status=[string](Get-PMMAIIOCaseValue $case 'Status' 'DRAFT')

  (Get-PMMAIIOCaseControl 'TxtHeader').Text=($title+$(if($historical){' - historical Step '+$selected}else{''}));(Get-PMMAIIOCaseControl 'TxtTitle').Text=$title;(Get-PMMAIIOCaseControl 'CmbType').SelectedValue=$type;(Get-PMMAIIOCaseControl 'TxtDescription').Text=$description;(Get-PMMAIIOCaseControl 'CmbTransport').SelectedValue=$transport
  [object[]]$referenceRows=@(Get-PMMAIIOReferenceRows $view);(Get-PMMAIIOCaseControl 'DgRefs').ItemsSource=$referenceRows

  $pending=[Collections.Generic.List[object]]::new()
  foreach($row in @(Get-PMMAIIOCaseArray $view 'PendingActions')){if([string](Get-PMMAIIOCaseValue $row 'Status' 'Pending') -eq 'Pending'){$pending.Add($row)}}
  (Get-PMMAIIOCaseControl 'TxtPending').Text=$(if($pending.Count -gt 0){@($pending.ToArray()|ForEach-Object{[string](Get-PMMAIIOCaseValue $_ 'Action' (Get-PMMAIIOCaseValue $_ 'Capability' 'Pending action'))}) -join ', '}else{'No pending work.'})

  $operation=Get-PMMAIIOCaseValue $case 'ActiveOperation' $null;$running=[bool](Get-PMMAIIOCaseValue $operation 'Running' $false);$message=[string](Get-PMMAIIOCaseValue $operation 'Message' '');$indeterminate=[bool](Get-PMMAIIOCaseValue $operation 'Indeterminate' $false);$opCurrent=[int](Get-PMMAIIOCaseValue $operation 'Current' 0);$opTotal=[int](Get-PMMAIIOCaseValue $operation 'Total' 0);$bar=Get-PMMAIIOCaseControl 'PrgProgress'
  if($running){$bar.IsIndeterminate=$indeterminate;if(-not$indeterminate -and $opTotal -gt 0){$bar.Value=[Math]::Min(100,[Math]::Floor(100.0*$opCurrent/$opTotal))};(Get-PMMAIIOCaseControl 'TxtProgress').Text=$(if($message){$message}else{'Working...'})}
  else{$bar.IsIndeterminate=$false;$bar.Value=100;(Get-PMMAIIOCaseControl 'TxtProgress').Text=$(if($message){$message}else{$lastAction})}

  (Get-PMMAIIOCaseControl 'TxtPosition').Text=('Step '+$selected+' / '+$current);$last=Get-PMMAIIOCaseControl 'BtnLast';$next=Get-PMMAIIOCaseControl 'BtnNext';$previous=if($selected -gt 1){Get-PMMAIIOCaseStep $caseId ($selected-1)}else{$null};$following=if($selected -lt $current){Get-PMMAIIOCaseStep $caseId ($selected+1)}else{$null}
  $last.Content=$(if($previous){'Last Step - '+[string](Get-PMMAIIOCaseValue $previous 'Summary' ('Step '+($selected-1)))}else{'Last Step'});$last.IsEnabled=($null -ne $previous)
  $next.Content=$(if($following){'Next Step - '+[string](Get-PMMAIIOCaseValue $following 'Summary' ('Step '+($selected+1)))}else{'Current - '+$lastAction});$next.IsEnabled=($null -ne $following)

  foreach($name in @('TxtTitle','CmbType','TxtDescription','CmbTransport','BtnSave','BtnAddPak','BtnAddModFamily','BtnAddVanilla','BtnRemoveRef','BtnAuto')){$control=Get-PMMAIIOCaseControl $name;if($control){$control.IsEnabled=(-not$historical)}}
  (Get-PMMAIIOCaseControl 'BtnHandoff').IsEnabled=$true;Show-PMMAIIOHistory $case;Set-PMMAIIOCaseNextHighlight $case;(Get-PMMAIIOCaseControl 'TxtListStatus').Text=($type+' | '+$status)
}

function Get-PMMAIIODialogBrush([string]$Key,$Fallback){try{$value=$Window.Resources[$Key];if($value){return $value}}catch{};return $Fallback}
function Set-PMMAIIODialogInputStyle($Control){if(-not$Control){return};try{$Control.Background=Get-PMMAIIODialogBrush 'InputBackground' ([Windows.Media.Brushes]::White)}catch{};try{$Control.Foreground=Get-PMMAIIODialogBrush 'PrimaryText' ([Windows.Media.Brushes]::Black)}catch{};try{$Control.BorderBrush=Get-PMMAIIODialogBrush 'InputBorder' ([Windows.Media.Brushes]::Gray)}catch{};try{$Control.Padding=[Windows.Thickness]::new(7,4,7,4)}catch{}}
function New-PMMAIIODialogLabel([string]$Text,[bool]$Strong=$false){$label=[Windows.Controls.TextBlock]::new();$label.Text=$Text;$label.Margin=[Windows.Thickness]::new(0,0,0,4);$label.Foreground=Get-PMMAIIODialogBrush 'PrimaryText' ([Windows.Media.Brushes]::Black);if($Strong){$label.FontWeight='SemiBold'};return $label}

function Show-PMMAIIONewCaseDialog{
  $dialog=[Windows.Window]::new();$dialog.Title='New AIIO case';$dialog.Width=640;$dialog.Height=470;$dialog.MinWidth=560;$dialog.MinHeight=430;$dialog.ResizeMode='CanResize';$dialog.WindowStartupLocation='CenterOwner';try{$dialog.Owner=$Window}catch{};$dialog.Background=Get-PMMAIIODialogBrush 'AppBackground' ([Windows.Media.Brushes]::WhiteSmoke);$dialog.Foreground=Get-PMMAIIODialogBrush 'PrimaryText' ([Windows.Media.Brushes]::Black);$dialog.FontFamily='Segoe UI';$dialog.FontSize=13
  $outer=[Windows.Controls.Grid]::new();$outer.Margin=[Windows.Thickness]::new(18);[void]$outer.RowDefinitions.Add([Windows.Controls.RowDefinition]::new());$bodyRow=[Windows.Controls.RowDefinition]::new();$bodyRow.Height=[Windows.GridLength]::new(1,[Windows.GridUnitType]::Star);[void]$outer.RowDefinitions.Add($bodyRow);[void]$outer.RowDefinitions.Add([Windows.Controls.RowDefinition]::new())
  $heading=[Windows.Controls.StackPanel]::new();$heading.Margin=[Windows.Thickness]::new(2,0,2,12);$headingTitle=[Windows.Controls.TextBlock]::new();$headingTitle.Text='Create AIIO case';$headingTitle.FontSize=22;$headingTitle.FontWeight='SemiBold';$headingTitle.Foreground=Get-PMMAIIODialogBrush 'PrimaryText' ([Windows.Media.Brushes]::Black);$headingText=[Windows.Controls.TextBlock]::new();$headingText.Text='Create the persistent workspace first. Type, goal and references can still be changed later.';$headingText.TextWrapping='Wrap';$headingText.Margin=[Windows.Thickness]::new(0,4,0,0);$headingText.Foreground=Get-PMMAIIODialogBrush 'MutedText' ([Windows.Media.Brushes]::DimGray);[void]$heading.Children.Add($headingTitle);[void]$heading.Children.Add($headingText);[void]$outer.Children.Add($heading)
  $card=[Windows.Controls.Border]::new();$card.Background=Get-PMMAIIODialogBrush 'CardBackground' ([Windows.Media.Brushes]::White);$card.BorderBrush=Get-PMMAIIODialogBrush 'CardBorder' ([Windows.Media.Brushes]::LightGray);$card.BorderThickness=[Windows.Thickness]::new(1);$card.CornerRadius=[Windows.CornerRadius]::new(7);$card.Padding=[Windows.Thickness]::new(16);[Windows.Controls.Grid]::SetRow($card,1);[void]$outer.Children.Add($card)
  $form=[Windows.Controls.Grid]::new();foreach($height in @('Auto','Auto','Auto','*')){$row=[Windows.Controls.RowDefinition]::new();if($height -eq '*'){$row.Height=[Windows.GridLength]::new(1,[Windows.GridUnitType]::Star)};[void]$form.RowDefinitions.Add($row)};$card.Child=$form
  $titleBlock=[Windows.Controls.StackPanel]::new();[void]$titleBlock.Children.Add((New-PMMAIIODialogLabel 'Title' $true));$title=[Windows.Controls.TextBox]::new();$title.MinHeight=32;Set-PMMAIIODialogInputStyle $title;[void]$titleBlock.Children.Add($title);[void]$form.Children.Add($titleBlock)
  $typeBlock=[Windows.Controls.StackPanel]::new();$typeBlock.Margin=[Windows.Thickness]::new(0,12,0,0);[Windows.Controls.Grid]::SetRow($typeBlock,1);[void]$typeBlock.Children.Add((New-PMMAIIODialogLabel 'Case type' $true));$type=[Windows.Controls.ComboBox]::new();$type.MinHeight=32;$type.Width=270;$type.HorizontalAlignment='Left';Set-PMMAIIODialogInputStyle $type;[void]$type.Items.Add('New Mod');[void]$type.Items.Add('Fix Mod');[void]$type.Items.Add('Compatibility');[void]$type.Items.Add('Undefined / Research');$type.SelectedIndex=0;[void]$typeBlock.Children.Add($type);$hint=[Windows.Controls.TextBlock]::new();$hint.Text='New Mod creates something new; Fix Mod targets one mod; Compatibility can target several mods; Undefined / Research stays open-ended.';$hint.TextWrapping='Wrap';$hint.Margin=[Windows.Thickness]::new(0,5,0,0);$hint.Foreground=Get-PMMAIIODialogBrush 'MutedText' ([Windows.Media.Brushes]::DimGray);[void]$typeBlock.Children.Add($hint);[void]$form.Children.Add($typeBlock)
  $descriptionLabel=New-PMMAIIODialogLabel 'Description / goal' $true;$descriptionLabel.Margin=[Windows.Thickness]::new(0,12,0,4);[Windows.Controls.Grid]::SetRow($descriptionLabel,2);[void]$form.Children.Add($descriptionLabel);$description=[Windows.Controls.TextBox]::new();$description.AcceptsReturn=$true;$description.TextWrapping='Wrap';$description.VerticalScrollBarVisibility='Auto';$description.MinHeight=95;Set-PMMAIIODialogInputStyle $description;[Windows.Controls.Grid]::SetRow($description,3);[void]$form.Children.Add($description)
  $buttons=[Windows.Controls.StackPanel]::new();$buttons.Orientation='Horizontal';$buttons.HorizontalAlignment='Right';$buttons.Margin=[Windows.Thickness]::new(0,12,0,0);[Windows.Controls.Grid]::SetRow($buttons,2);$cancel=[Windows.Controls.Button]::new();$cancel.Content='Cancel';$cancel.MinWidth=100;$cancel.Margin=[Windows.Thickness]::new(0,0,6,0);$create=[Windows.Controls.Button]::new();$create.Content='Create case';$create.MinWidth=120;$create.FontWeight='SemiBold';try{$cancel.Style=$Window.FindResource('DefaultButton')}catch{};try{$create.Style=$Window.FindResource('PrimaryButton')}catch{};[void]$buttons.Children.Add($cancel);[void]$buttons.Children.Add($create);[void]$outer.Children.Add($buttons)
  $script:PMMAIIONewCaseDialogResult=$null;$cancel.Add_Click({$dialog.DialogResult=$false;$dialog.Close()});$create.Add_Click({$map=@{'New Mod'='NEW_MOD';'Fix Mod'='FIX_MOD';'Compatibility'='COMPATIBILITY';'Undefined / Research'='UNDEFINED'};$script:PMMAIIONewCaseDialogResult=[pscustomobject]@{Title=[string]$title.Text;Type=[string]$map[[string]$type.SelectedItem];Description=[string]$description.Text};$dialog.DialogResult=$true;$dialog.Close()});$dialog.Content=$outer;$title.Focus()|Out-Null;$result=$null;if($dialog.ShowDialog() -eq $true){$result=$script:PMMAIIONewCaseDialogResult};$script:PMMAIIONewCaseDialogResult=$null;return $result
}
