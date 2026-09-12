# ---------------------------------------------------------------------------
# Library / Analyze / conflict editing / Build.
# ---------------------------------------------------------------------------
$Script:ExpAnalysis.Add_Expanded({try{Update-PMMWorkspaceRows}catch{}})
$Script:ExpAnalysis.Add_Collapsed({try{Update-PMMWorkspaceRows}catch{}})
$Script:ExpConflicts.Add_Expanded({try{Update-PMMWorkspaceRows}catch{}})
$Script:ExpConflicts.Add_Collapsed({try{Update-PMMWorkspaceRows}catch{}})
$Script:SplAnalysisResolution.Add_DragCompleted({
  try{
    if($Script:ExpAnalysis.IsExpanded -and $Script:ExpConflicts.IsExpanded){
      if($Script:RowAnalysisWorkspace.ActualHeight -gt 100){$Script:SavedAnalysisHeight=[double]$Script:RowAnalysisWorkspace.ActualHeight}
      if($Script:RowResolutionWorkspace.ActualHeight -gt 100){$Script:SavedResolutionHeight=[double]$Script:RowResolutionWorkspace.ActualHeight}
    }
  }catch{}
})
function Invoke-PMMImportBatch {
  param(
    [Parameter(Mandatory=$true)][string[]]$Files,
    [switch]$FolderMode
  )
  if(-not(Request-PMMProcessingSlot 'Import')){return}
  $files=@($Files|Where-Object{$_ -and (Test-Path -LiteralPath $_ -PathType Leaf)})
  if($files.Count -eq 0){
    $Script:TxtStatus.Text=L 'No supported mod files were selected.' 'No se seleccionaron archivos de mod compatibles.'
    return
  }

  $busy=$false
  $importSucceeded=$false
  $importedInputs=0
  $failed=[System.Collections.Generic.List[string]]::new()
  Reset-PMMOperationCancellation
  if([bool]$Script:TglAutoMode.IsChecked){Start-PMMAutoPipeline}
  try{
    Set-PMMImportBusy $Script:BtnImport $true;$busy=$true
    for($i=0;$i -lt $files.Count;$i++){
      $base=[double]$i/[double]$files.Count
      $span=1.0/[double]$files.Count
      $file=[string]$files[$i]
      $cb={
        param([double]$fraction,[string]$message)
        Set-PMMImportProgress $Script:BtnImport ($base+($span*$fraction)) $message
      }.GetNewClosure()
      try{
        Import-PMMMod $file $cb
        $importedInputs++
      }catch{
        if(Test-PMMCancellationError $_){throw}
        $failed.Add(([IO.Path]::GetFileName($file)+': '+$_.Exception.Message))
        Write-PMMLog ('Import skipped/failed for '+$file+': '+$_.Exception.Message)
        # Folder import is intentionally tolerant: a downloads folder can
        # contain archives unrelated to PMM. Explicit multi-file import also
        # continues so one bad archive does not discard the other selections.
      }
    }
    if($failed.Count -gt 0){
      $msg=((L 'Import finished: {0} selected item(s) imported, {1} skipped/failed. See the log for details.' 'Importacion terminada: {0} elemento(s) seleccionado(s) importados, {1} omitidos/con fallo. Consulta el log para detalles.') -f $importedInputs,$failed.Count)
      Set-PMMOperationFailure 'Import' $msg
      Stop-PMMAutoPipeline (L 'Auto paused because one or more imports failed.' 'Auto pausado porque una o mas importaciones fallaron.')
    }else{
      Set-PMMImportProgress $Script:BtnImport 1.0 ((L 'Import complete: {0} selected item(s).' 'Importacion terminada: {0} elemento(s) seleccionado(s).') -f $importedInputs)
      $importSucceeded=$true
    }
  }catch{
    if(Test-PMMCancellationError $_){
      Set-PMMOperationResult 'Import' (L 'Import cancelled.' 'Importacion cancelada.')
      Stop-PMMAutoPipeline
    }else{throw}
  }finally{
    if($busy){Refresh-UI;Check-PMMExternalModChanges -Force;Set-PMMImportBusy $Script:BtnImport $false;try{Update-PMMFixLabAttentionFromLibrary 'Import'}catch{};try{Update-PMMGuidedActionState}catch{};if($importSucceeded){Notify-PMMWorkflowStepComplete};if($Script:AutoPipelineActive){Invoke-PMMAutoContinue}}
  }
}

function Test-PMMFolderImportCandidate([System.IO.FileInfo]$File) {
  if(-not$File){return $false}
  $ext=$File.Extension.ToLowerInvariant()
  if($ext -eq '.pak'){return $true}
  if($ext -eq '.zip'){
    try{
      Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction SilentlyContinue
      $zip=[System.IO.Compression.ZipFile]::OpenRead($File.FullName)
      try{return (@($zip.Entries|Where-Object{([string]$_.FullName).ToLowerInvariant().EndsWith('.pak')}).Count -gt 0)}finally{$zip.Dispose()}
    }catch{
      Write-PMMLog ('Folder import skipped unreadable ZIP '+$File.FullName+': '+$_.Exception.Message)
      return $false
    }
  }
  return ($ext -in @('.7z','.rar'))
}

function Get-PMMFolderImportFiles([string]$Folder) {
  if([string]::IsNullOrWhiteSpace($Folder) -or -not(Test-Path -LiteralPath $Folder -PathType Container)){return @()}
  $supported=@('.pak','.zip','.7z','.rar')
  return @(Get-ChildItem -LiteralPath $Folder -File -ErrorAction Stop |
    Where-Object{($supported -contains $_.Extension.ToLowerInvariant()) -and (Test-PMMFolderImportCandidate $_)} |
    Sort-Object Name | ForEach-Object{$_.FullName})
}

function Show-PMMImportWindow {
  $dialog=[System.Windows.Window]::new()
  $dialog.Title=L 'Import mods' 'Importar mods'
  $dialog.Width=560;$dialog.Height=245;$dialog.ResizeMode=[System.Windows.ResizeMode]::NoResize
  $dialog.WindowStartupLocation=[System.Windows.WindowStartupLocation]::CenterOwner
  $dialog.Owner=$Window;$dialog.ShowInTaskbar=$false
  try{$dialog.Icon=$Window.Icon}catch{}

  $grid=[System.Windows.Controls.Grid]::new();$grid.Margin=[System.Windows.Thickness]::new(16)
  foreach($height in @('Auto','*','Auto')){
    $row=[System.Windows.Controls.RowDefinition]::new()
    $row.Height=if($height -eq '*'){[System.Windows.GridLength]::new(1,[System.Windows.GridUnitType]::Star)}else{[System.Windows.GridLength]::Auto}
    [void]$grid.RowDefinitions.Add($row)
  }

  $info=[System.Windows.Controls.TextBlock]::new()
  $info.Text=L 'Choose individual mod files or a folder containing mods. ZIP/7Z/RAR files are only containers: PMM extracts their PAK files and stores only the PAKs in the mod library.' 'Elige archivos de mod individuales o una carpeta que contenga mods. Los ZIP/7Z/RAR son solo contenedores: PMM extrae sus PAK y guarda unicamente los PAK en la biblioteca.'
  $info.TextWrapping=[System.Windows.TextWrapping]::Wrap;$info.Margin=[System.Windows.Thickness]::new(0,0,0,12)
  [System.Windows.Controls.Grid]::SetRow($info,0);[void]$grid.Children.Add($info)

  $status=[System.Windows.Controls.TextBlock]::new()
  $status.Text=L 'Import folder or mods' 'Importar carpeta o mods'
  $status.HorizontalAlignment=[System.Windows.HorizontalAlignment]::Center
  $status.VerticalAlignment=[System.Windows.VerticalAlignment]::Center
  $status.FontSize=14;$status.FontWeight=[System.Windows.FontWeights]::SemiBold
  $status.Foreground=[System.Windows.Media.Brushes]::DimGray
  $status.TextWrapping=[System.Windows.TextWrapping]::Wrap
  [System.Windows.Controls.Grid]::SetRow($status,1);[void]$grid.Children.Add($status)

  $buttons=[System.Windows.Controls.WrapPanel]::new();$buttons.HorizontalAlignment=[System.Windows.HorizontalAlignment]::Center;$buttons.Margin=[System.Windows.Thickness]::new(0,12,0,0)
  $btnMods=[System.Windows.Controls.Button]::new();$btnMods.Content=L 'Import mods...' 'Importar mods...';$btnMods.MinWidth=145;$btnMods.Padding=[System.Windows.Thickness]::new(14,7,14,7);$btnMods.Margin=[System.Windows.Thickness]::new(0,0,8,0)
  $btnFolder=[System.Windows.Controls.Button]::new();$btnFolder.Content=L 'Import folder...' 'Importar carpeta...';$btnFolder.MinWidth=145;$btnFolder.Padding=[System.Windows.Thickness]::new(14,7,14,7);$btnFolder.Margin=[System.Windows.Thickness]::new(0,0,8,0)
  $btnCancel=[System.Windows.Controls.Button]::new();$btnCancel.Content=L 'Cancel' 'Cancelar';$btnCancel.MinWidth=90;$btnCancel.Padding=[System.Windows.Thickness]::new(12,7,12,7)
  [void]$buttons.Children.Add($btnMods);[void]$buttons.Children.Add($btnFolder);[void]$buttons.Children.Add($btnCancel)
  [System.Windows.Controls.Grid]::SetRow($buttons,2);[void]$grid.Children.Add($buttons)

  $selected=[System.Collections.Generic.List[string]]::new()
  $btnMods.Add_Click({
    $pick=New-Object System.Windows.Forms.OpenFileDialog
    $pick.Multiselect=$true
    $pick.Filter=L 'Mods (*.pak;*.zip;*.7z;*.rar)|*.pak;*.zip;*.7z;*.rar|All files (*.*)|*.*' 'Mods (*.pak;*.zip;*.7z;*.rar)|*.pak;*.zip;*.7z;*.rar|Todos (*.*)|*.*'
    if($pick.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK){
      foreach($path in @($pick.FileNames)){if(-not[string]::IsNullOrWhiteSpace($path)){$selected.Add([IO.Path]::GetFullPath($path))}}
      if($selected.Count -gt 0){$dialog.DialogResult=$true;$dialog.Close()}
    }
  }.GetNewClosure())
  $btnFolder.Add_Click({
    $pick=New-Object System.Windows.Forms.FolderBrowserDialog
    $pick.Description=L 'Choose a folder containing PAK/ZIP/7Z/RAR mod files. PMM extracts archives and imports only their PAK files.' 'Elige una carpeta con mods PAK/ZIP/7Z/RAR. PMM extrae los comprimidos e importa solo sus PAK.'
    if($pick.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK){
      $found=@(Get-PMMFolderImportFiles $pick.SelectedPath)
      if($found.Count -eq 0){
        $status.Text=L 'The selected folder contains no supported mod files.' 'La carpeta seleccionada no contiene archivos de mod compatibles.'
        $status.Foreground=[System.Windows.Media.Brushes]::DarkOrange
      }else{
        foreach($path in $found){$selected.Add([IO.Path]::GetFullPath([string]$path))}
        $dialog.DialogResult=$true;$dialog.Close()
      }
    }
  }.GetNewClosure())
  $btnCancel.Add_Click({$dialog.DialogResult=$false;$dialog.Close()})

  $dialog.Content=$grid
  $ok=$dialog.ShowDialog()
  if($ok -eq $true -and $selected.Count -gt 0){Invoke-PMMImportBatch -Files @($selected.ToArray())}
}

$Script:BtnImport.Add_Click({
  try{Show-PMMImportWindow}catch{Handle-UIError $_ (L 'Mod import' 'Importacion de mod')}
})

$Script:BtnImportGameMods.Add_Click({
  if(-not(Request-PMMProcessingSlot 'Import')){return}
  $busy=$false
  $importSucceeded=$false
  Reset-PMMOperationCancellation
  if([bool]$Script:TglAutoMode.IsChecked){Start-PMMAutoPipeline}
  try{
    Set-PMMImportBusy $Script:BtnImportGameMods $true;$busy=$true
    $cb={param([double]$fraction,[string]$message) Set-PMMImportProgress $Script:BtnImportGameMods $fraction $message}.GetNewClosure()
    $count=Import-GameModsToLibrary $cb
    Set-PMMImportProgress $Script:BtnImportGameMods 1.0 ((L 'Import complete: {0} PAK(s) imported/updated.' 'Importacion terminada: {0} PAK importados/actualizados.') -f $count)
    $importSucceeded=$true
  }catch{
    if(Test-PMMCancellationError $_){Set-PMMOperationResult 'Import' (L 'Import cancelled.' 'Importacion cancelada.');Stop-PMMAutoPipeline}
    else{Stop-PMMAutoPipeline;Handle-UIError $_ (L 'Import game ~mods' 'Importacion de ~mods')}
  }
  finally{
    if($busy){Refresh-UI;Check-PMMExternalModChanges -Force;Set-PMMImportBusy $Script:BtnImportGameMods $false;try{Update-PMMFixLabAttentionFromLibrary 'Import'}catch{};try{Update-PMMGuidedActionState}catch{};if($importSucceeded){Notify-PMMWorkflowStepComplete};if($Script:AutoPipelineActive){Invoke-PMMAutoContinue}}
  }
})
# Manual and automatic guidance share Get-PMMWorkflowState; no separate Analyze/Fix Lab router.
$Script:BtnScan.Add_Click({
  try{
    Reset-PMMOperationCancellation
    if([bool]$Script:TglAutoMode.IsChecked){Start-PMMAutoPipeline}
    Save-DecisionGridToPlan -Silent
    $done={
      param($result)
      Refresh-UI
      $Script:TxtLog.Text=Get-PMMRecentLog
      $Script:TxtStatus.Text=Get-PMMStatusLine
      try{Update-PMMFixLabAttentionFromLibrary 'Analyze'}catch{}
      if(-not$Script:AutoPipelineActive){Prompt-PMMAIHandoffAfterAnalyze}
    }
    $failed={param($message) Stop-PMMAutoPipeline;Show-Error ([string]$message)}
    [void](Start-PMMBackgroundOperation -Operation Analyze -OnSuccess $done -OnFailure $failed)
  }catch{Stop-PMMAutoPipeline;Handle-UIError $_ (L 'Analyze' 'Analizar')}
})
$Script:TxtModFilter.Add_TextChanged({try{Apply-PMMLibraryFilter}catch{}})
$Script:LstMods.Add_SelectionChanged({try{Update-PMMLibraryButtons}catch{}})
$Script:BtnReorderLibrary.Add_Click({
  if(-not(Request-PMMProcessingSlot 'Library')){return}
  try{
    $mode=[string]$Script:CmbLibraryOrder.SelectedValue;if([string]::IsNullOrWhiteSpace($mode)){$mode='Alphabetical'}
    [void](Set-PMMLibraryOrderBy $mode);Clear-PMMAnalysisState;Refresh-UI
    $Script:TxtStatus.Text=((L 'Mod library reordered: {0}. Analyze is required again.' 'Biblioteca de mods reordenada: {0}. Es necesario volver a Analyze.') -f $mode)
    Update-PMMGuidedActionState
  }catch{Handle-UIError $_ (L 'Reorder mod library' 'Reordenar biblioteca de mods')}
})

$Script:BtnSelectAllMods.Add_Click({
  try{$Script:LstMods.SelectAll();Update-PMMLibraryButtons}catch{Handle-UIError $_ (L 'Select mods' 'Seleccionar mods')}
})
$Script:BtnClearModSelection.Add_Click({
  try{$Script:LstMods.UnselectAll();Update-PMMLibraryButtons}catch{Handle-UIError $_ (L 'Clear mod selection' 'Limpiar seleccion de mods')}
})
$Script:BtnEnableMods.Add_Click({
  if(-not(Request-PMMProcessingSlot 'Library')){return}
  try{
    $entries=@(Get-SelectedPMMLibraryEntries)
    if($entries.Count -eq 0){return}
    foreach($entry in $entries){if(-not[bool]$entry.Enabled){Set-PMMLibraryModEnabled ([string]$entry.Name) $true}}
    Refresh-UI
  }catch{Handle-UIError $_ (L 'Enable selected mods' 'Activar mods seleccionados')}
})
$Script:BtnDisableMods.Add_Click({
  if(-not(Request-PMMProcessingSlot 'Library')){return}
  try{
    $entries=@(Get-SelectedPMMLibraryEntries)
    if($entries.Count -eq 0){return}
    foreach($entry in $entries){if([bool]$entry.Enabled){Set-PMMLibraryModEnabled ([string]$entry.Name) $false}}
    Refresh-UI
  }catch{Handle-UIError $_ (L 'Disable selected mods' 'Desactivar mods seleccionados')}
})

# The Order cell is always-live like the decision ComboBox: type a final 1-based
# position and commit by Enter or by leaving the field. The core operation is an
# insertion, so every other mod is shifted and the persisted order remains 1..N.
$priorityLostFocusHandler=[System.Windows.Input.KeyboardFocusChangedEventHandler]{
  param($sender,$e)
  try{
    $editor=Get-PMMUiAncestor $e.OriginalSource ([System.Windows.Controls.TextBox])
    if($editor -and -not[string]::IsNullOrWhiteSpace([string]$editor.Tag)){
      [void](Invoke-PMMPriorityEditorCommit $editor)
    }
  }catch{Handle-UIError $_ (L 'Change mod priority' 'Cambiar prioridad del mod')}
}
$Script:LstMods.AddHandler([System.Windows.Input.Keyboard]::LostKeyboardFocusEvent,$priorityLostFocusHandler,$true)
$Script:LstMods.Add_PreviewKeyDown({
  param($sender,$e)
  $editor=Get-PMMUiAncestor $e.OriginalSource ([System.Windows.Controls.TextBox])
  if(-not$editor -or [string]::IsNullOrWhiteSpace([string]$editor.Tag)){return}
  if($e.Key -eq [System.Windows.Input.Key]::Enter -or $e.Key -eq [System.Windows.Input.Key]::Return){
    try{[void](Invoke-PMMPriorityEditorCommit $editor)}catch{Handle-UIError $_ (L 'Change mod priority' 'Cambiar prioridad del mod')}
    $e.Handled=$true
  }elseif($e.Key -eq [System.Windows.Input.Key]::Escape){
    try{
      $map=Get-PMMModPriorityMap
      if($map.ContainsKey([string]$editor.Tag)){$editor.Text=[string]$map[[string]$editor.Tag]}
      [void]$Script:LstMods.Focus()
    }catch{}
    $e.Handled=$true
  }
})

# Drag any non-interactive part of a source row. Drop on the upper/lower half of
# another row to insert before/after it; dragging near the edges auto-scrolls.
$Script:LstMods.Add_PreviewMouseLeftButtonDown({
  param($sender,$e)
  $Script:PriorityDragStartPoint=$null
  $Script:PriorityDragName=''
  if(Test-PMMPriorityDragInteractiveSource $e.OriginalSource){return}
  $row=Get-PMMUiAncestor $e.OriginalSource ([System.Windows.Controls.DataGridRow])
  if(-not$row -or -not$row.Item -or [string]$row.Item.Kind -ne 'Source'){return}
  $Script:PriorityDragStartPoint=$e.GetPosition($Script:LstMods)
  $Script:PriorityDragName=[string]$row.Item.Name
})
$Script:LstMods.Add_PreviewMouseMove({
  param($sender,$e)
  if($e.LeftButton -ne [System.Windows.Input.MouseButtonState]::Pressed){
    $Script:PriorityDragStartPoint=$null;$Script:PriorityDragName='';return
  }
  if($null -eq $Script:PriorityDragStartPoint -or [string]::IsNullOrWhiteSpace($Script:PriorityDragName)){return}
  $point=$e.GetPosition($Script:LstMods)
  $dx=[Math]::Abs($point.X-$Script:PriorityDragStartPoint.X)
  $dy=[Math]::Abs($point.Y-$Script:PriorityDragStartPoint.Y)
  if($dx -lt [System.Windows.SystemParameters]::MinimumHorizontalDragDistance -and $dy -lt [System.Windows.SystemParameters]::MinimumVerticalDragDistance){return}
  $data=New-Object System.Windows.DataObject
  $data.SetData('PMM.ModPriority',[string]$Script:PriorityDragName)
  try{[void][System.Windows.DragDrop]::DoDragDrop($Script:LstMods,$data,[System.Windows.DragDropEffects]::Move)}finally{
    $Script:PriorityDragStartPoint=$null
    $Script:PriorityDragName=''
  }
})
$Script:LstMods.Add_DragOver({
  param($sender,$e)
  if(-not$e.Data.GetDataPresent('PMM.ModPriority')){$e.Effects=[System.Windows.DragDropEffects]::None;$e.Handled=$true;return}
  $e.Effects=[System.Windows.DragDropEffects]::Move
  $e.Handled=$true
  try{
    if(-not$Script:ModListScrollViewer){$Script:ModListScrollViewer=Get-PMMUiDescendant $Script:LstMods ([System.Windows.Controls.ScrollViewer])}
    if($Script:ModListScrollViewer){
      $p=$e.GetPosition($Script:LstMods)
      if($p.Y -lt 34){$Script:ModListScrollViewer.LineUp()}
      elseif($p.Y -gt ($Script:LstMods.ActualHeight-34)){$Script:ModListScrollViewer.LineDown()}
    }
  }catch{}
})
$Script:LstMods.Add_Drop({
  param($sender,$e)
  if(-not$e.Data.GetDataPresent('PMM.ModPriority')){return}
  $name=[string]$e.Data.GetData('PMM.ModPriority')
  if([string]::IsNullOrWhiteSpace($name)){return}
  if(Get-PMMUiAncestor $e.OriginalSource ([System.Windows.Controls.Primitives.ScrollBar])){return}
  try{
    $map=Get-PMMModPriorityMap
    if(-not$map.ContainsKey($name)){return}
    $sourcePosition=[int]$map[$name]
    $targetRow=Get-PMMUiAncestor $e.OriginalSource ([System.Windows.Controls.DataGridRow])
    [long]$desired=0
    if($targetRow -and $targetRow.Item -and [string]$targetRow.Item.Kind -eq 'Source'){
      $targetName=[string]$targetRow.Item.Name
      if($targetName -ieq $name){return}
      if(-not$map.ContainsKey($targetName)){return}
      $targetPosition=[int]$map[$targetName]
      $rowPoint=$e.GetPosition($targetRow)
      $lowerHalf=($rowPoint.Y -ge ($targetRow.ActualHeight/2.0))
      if($sourcePosition -lt $targetPosition){
        $desired=if($lowerHalf){$targetPosition}else{$targetPosition-1}
      }else{
        $desired=if($lowerHalf){$targetPosition+1}else{$targetPosition}
      }
    }else{
      $gridPoint=$e.GetPosition($Script:LstMods)
      if($gridPoint.Y -lt 34){return}
      $desired=$map.Count
    }
    if(-not(Request-PMMProcessingSlot 'Library')){return}
    if(Set-PMMModPriorityPosition $name $desired){Refresh-PMMLibraryAfterPriorityChange $name}
  }catch{Handle-UIError $_ (L 'Change mod priority' 'Cambiar prioridad del mod')}
  $e.Handled=$true
})

$Script:LstMods.AddHandler([System.Windows.Controls.Primitives.ButtonBase]::ClickEvent,[System.Windows.RoutedEventHandler]{
  param($sender,$e)
  $box=$e.OriginalSource
  if($box -is [System.Windows.Controls.CheckBox] -and -not[string]::IsNullOrWhiteSpace([string]$box.Tag)){
    try{
      if(-not(Request-PMMProcessingSlot 'Library')){Refresh-UI;$e.Handled=$true;return}
      Set-PMMLibraryModEnabled ([string]$box.Tag) ([bool]$box.IsChecked)
      Refresh-UI
    }catch{Handle-UIError $_ (L 'Enable/disable mod' 'Activar/desactivar mod')}
    $e.Handled=$true
  }
})
function Get-PMMBuildValidationLabel([string]$Status) {
  switch($Status){
    'LOCAL_PASS' {return (L 'LOCAL PASS' 'PASS LOCAL')}
    'LOCAL_PARTIAL' {return (L 'LOCAL PARTIAL' 'PARCIAL LOCAL')}
    'LOCAL_FAIL' {return (L 'LOCAL FAIL' 'FALLO LOCAL')}
    'STALE' {return (L 'VALIDATION STALE' 'VALIDACION OBSOLETA')}
    'NOT_DEPLOYED' {return (L 'NOT DEPLOYED' 'NO DESPLEGADO')}
    default {return (L 'UNVALIDATED' 'SIN VALIDAR')}
  }
}

function Update-PMMValidatedPatchRow($Entry,$Summary) {
  if(-not$Entry -or -not$Entry.Patch -or -not$Summary){return}
  $base='';try{$base=[string]$Entry.BaseStatus}catch{}
  if([string]::IsNullOrWhiteSpace($base)){
    $current=[string]$Entry.Status
    $separator=$current.IndexOf(' | ',[StringComparison]::Ordinal)
    $base=if($separator -ge 0){$current.Substring($separator+3)}else{$current}
    $Entry|Add-Member -NotePropertyName BaseStatus -NotePropertyValue $base -Force
  }
  $Entry.Status=(Get-PMMBuildValidationLabel ([string]$Summary.Status))+' | '+$base
  $Entry.Validated=([string]$Summary.Status -eq 'LOCAL_PASS')
  try{$Script:LstPatches.Items.Refresh()}catch{}
  Update-PMMPatchActionButtons
}

function Open-PMMValidationFeedbackForPatch($Patch) {
  if(-not$Patch){return}
  $Script:MainTabs.SelectedItem=$Script:TabAIHelp
  $Script:AIHelpTabs.SelectedItem=$Script:PMMHelpFeedbackTab
  Refresh-PMMAIHelpFeedback -Force
  [void](Select-PMMSelectorItemId $Script:CmbAIHelpFeedbackBuild 'Key' ([string]$Patch.Name))
  $Script:CmbAIHelpFeedbackType.SelectedValue='MERGE_COMMENT'
  $Script:TxtAIHelpFeedbackTitle.Text=((L 'Tested merge: {0}' 'Merge probado: {0}') -f [string]$Patch.Name)
  $Script:TxtAIHelpFeedbackStatus.Text=L 'The exact validated merge is selected. Add any useful comments, then create the validation feedback or a general share file.' 'El merge exacto validado esta seleccionado. Anade comentarios utiles y crea el feedback de validacion o un archivo general para compartir.'
  Update-PMMAIHelpFeedbackSelection
  try{$Script:TxtAIHelpFeedbackComments.Focus()|Out-Null}catch{}
}

$Script:LstPatches.Add_SelectionChanged({
  try{
    Update-PMMPatchActionButtons
    $entry=$Script:LstPatches.SelectedItem
    if($entry -and $entry.Patch -and -not[bool]$entry.Selectable){
      $Script:TxtStatus.Text=L 'This saved merge is not yet proven for the current library. Run Analyze so PMM can compare the effective conflict set, or import the exact original sources.' 'Este merge guardado aun no esta probado para la biblioteca actual. Ejecuta Analizar para que PMM compare el conjunto efectivo de conflictos, o importa las fuentes originales exactas.'
    }
  }catch{Handle-UIError $_ (L 'Select compatibility merge row' 'Seleccionar fila de merge de compatibilidad')}
})
$Script:BtnValidatePatch.Add_Click({
  try{
    $entry=$Script:LstPatches.SelectedItem;if(-not$entry -or -not$entry.Patch){return}
    $summary=Get-PMMBuildValidationSummary $entry.Patch
    if([string]$summary.Status -eq 'NOT_DEPLOYED'){throw (L 'Deploy this exact merge before validating it in Palworld.' 'Despliega este merge exacto antes de validarlo dentro de Palworld.')}
    $result=Show-PMMBuildValidationDialog ([string]$summary.Status);if([string]::IsNullOrWhiteSpace($result) -or $result -eq 'CANCEL'){return}
    $record=New-PMMBuildValidationEvent -Patch $entry.Patch -Result $result
    $Script:TxtStatus.Text=((L 'Local validation recorded: {0}. buildId {1}' 'Validacion local registrada: {0}. buildId {1}') -f [string]$record.Summary.Status,[string]$record.Summary.BuildId)
    Update-PMMValidatedPatchRow $entry $record.Summary
    if($result -in @('PASS','PASS_RECONFIRMED') -and (Show-PMMValidationContributionDialog)){Open-PMMValidationFeedbackForPatch $entry.Patch}
  }catch{Handle-UIError $_ (L 'Validate merge' 'Validar merge')}
})
$Script:BtnDeletePatch.Add_Click({
  if(-not(Request-PMMProcessingSlot 'Library')){return}
  try{
    $entry=$Script:LstPatches.SelectedItem
    if(-not$entry -or -not$entry.Patch){return}
    $name=[string]$entry.Patch.Name
    $question=((L "Delete merge '{0}' completely?`n`nPMM will remove the exact deployed copy from Palworld ~mods if it exists, delete matching saved copies + manifests inside PMM, clear its validation/selection state, and leave all source mods untouched.`n`nA same-name file with a different hash will NOT be deleted." "Borrar completamente el merge '{0}'?`n`nPMM retirara de ~mods de Palworld la copia desplegada exacta si existe, borrara las copias guardadas + manifests coincidentes dentro de PMM, limpiara su validacion/seleccion y dejara intactos todos los mods fuente.`n`nNO se borrara un archivo del mismo nombre si tiene otro hash.") -f $name)
    if(-not(Confirm $question)){return}
    $result=Remove-PMMManagedPatch $entry.Patch
    $Script:TxtStatus.Text=((L 'Merge deleted. Game copy removed: {0}; saved PMM copies removed: {1}.' 'Merge borrado. Copia del juego retirada: {0}; copias guardadas en PMM borradas: {1}.') -f [bool]$result.GameRemoved,[int]$result.LocalCopiesRemoved)
    Refresh-UI;Update-PMMGuidedActionState
  }catch{Handle-UIError $_ (L 'Delete merge' 'Borrar merge')}
})
$Script:LstPatches.AddHandler([System.Windows.Controls.Primitives.ButtonBase]::ClickEvent,[System.Windows.RoutedEventHandler]{
  param($sender,$e)
  try{
    $radio=$e.OriginalSource -as [System.Windows.Controls.RadioButton]
    if(-not$radio -or [string]::IsNullOrWhiteSpace([string]$radio.Tag)){return}
    $name=[string]$radio.Tag
    $entry=@($Script:LstPatches.Items|Where-Object{[string]$_.SelectionKey -ieq $name}|Select-Object -First 1)[0]
    if(-not$entry -or -not[bool]$entry.Selectable){return}
    Set-PMMSelectedPatchName $name
    if($name -eq (Get-PMMNoPatchSelectionName)){Write-PMMLog 'User selected manager-only Deploy: no compatibility patch.'}
    else{Write-PMMLog "User selected saved compatibility patch for Deploy: $name"}
    Refresh-UI
  }catch{Handle-UIError $_ (L 'Select compatibility patch' 'Seleccionar parche de compatibilidad')}
  $e.Handled=$true
})
$Script:ChkCloseGame.Add_Click({try{Update-PMMDeploymentOptionsState}catch{}})
$Script:BtnPriorityUp.Add_Click({
  if(-not(Request-PMMProcessingSlot 'Library')){return}
  try{
    $entry=Get-SelectedPMMLibraryEntry
    if(-not$entry -or $entry.Kind -ne 'Source'){return}
    $name=[string]$entry.Name
    if(Move-PMMModPriority $name 'Earlier'){
      Refresh-PMMLibraryAfterPriorityChange $name
    }
  }catch{Handle-UIError $_ (L 'Change mod priority' 'Cambiar prioridad del mod')}
})
$Script:BtnPriorityDown.Add_Click({
  if(-not(Request-PMMProcessingSlot 'Library')){return}
  try{
    $entry=Get-SelectedPMMLibraryEntry
    if(-not$entry -or $entry.Kind -ne 'Source'){return}
    $name=[string]$entry.Name
    if(Move-PMMModPriority $name 'Later'){
      Refresh-PMMLibraryAfterPriorityChange $name
    }
  }catch{Handle-UIError $_ (L 'Change mod priority' 'Cambiar prioridad del mod')}
})

$Script:BtnDeleteMod.Add_Click({
  if(-not(Request-PMMProcessingSlot 'Library')){return}
  try{
    $entries=@(Get-SelectedPMMLibraryEntries)
    if($entries.Count -eq 0){return}
    $names=@($entries|ForEach-Object{[string]$_.Name})
    $preview=($names|Select-Object -First 8) -join "`n"
    if($names.Count -gt 8){$preview+="`n... +"+($names.Count-8)}
    $question=if($names.Count -eq 1){
      (L "Delete {0} everywhere? This immediately removes the imported copy from PMM and the exact matching PAK from Palworld ~mods. A deployed compatibility merge is preserved until you explicitly change it in the Compatibility patches panel." "Borrar {0} de todas partes? Esto elimina inmediatamente la copia importada de PMM y el PAK exacto correspondiente de ~mods de Palworld. Un merge de compatibilidad desplegado se conserva hasta que lo cambies explicitamente en el panel Compatibility patches.") -f $names[0]
    }else{
      ((L "Delete {0} selected mods everywhere? Each imported copy will be removed from PMM and its exact matching PAK will be removed from Palworld ~mods. Any deployed compatibility merge is preserved until you explicitly change it in the Compatibility patches panel.`n`n{1}" "Borrar {0} mods seleccionados de todas partes? Cada copia importada se eliminara de PMM y su PAK exacto correspondiente se eliminara de ~mods de Palworld. Cualquier merge de compatibilidad desplegado se conserva hasta que lo cambies explicitamente en el panel Compatibility patches.`n`n{1}") -f $names.Count,$preview)
    }
    if(Confirm $question){
      $results=[System.Collections.Generic.List[object]]::new()
      foreach($name in $names){$results.Add((Remove-PMMLibraryMod $name))}
      $gameRemoved=@($results.ToArray()|Where-Object{[bool]$_.DeletedFromGame}).Count
      Refresh-UI
      try{Check-PMMExternalModChanges -Force}catch{}
      try{Update-PMMFixLabAttentionFromLibrary 'Delete'}catch{}
      try{Update-PMMGuidedActionState}catch{}
      $Script:TxtStatus.Text=((L 'Deleted {0} imported mod(s) from PMM; {1} matching game PAK(s) removed from ~mods. The deployed compatibility merge was preserved.' 'Borrados {0} mod(s) importados de PMM; {1} PAK coincidente(s) eliminados de ~mods. El merge de compatibilidad desplegado se conservo.') -f $results.Count,$gameRemoved)
    }
  }catch{Handle-UIError $_ (L 'Delete mods' 'Borrar mods')}
})

$Script:LstConflictAssets.Add_SelectionChanged({
  if ($Script:LoadingConflictView) { return }
  try {
    Save-DecisionGridToPlan -Silent
    Refresh-PMMAnalysisWorkspace
    Show-SelectedConflictAsset $Script:LstConflictAssets.SelectedItem
    Update-BuildButtonState
    Update-PMMGuidedActionState
  } catch { Handle-UIError $_ (L 'Conflict view' 'Vista de conflictos') }
})

$Script:LstUnsupportedAssets.Add_SelectionChanged({
  if($Script:LoadingConflictView){return}
  try{Show-SelectedUnsupportedAsset}catch{Handle-UIError $_ (L 'Unsupported asset view' 'Vista de asset no soportado')}
})

$Script:BtnDisableUnsupported.Add_Click({
  try{
    $name=[string]$Script:CmbUnsupportedDisable.SelectedItem
    if([string]::IsNullOrWhiteSpace($name)){throw (L 'Choose a source mod to disable.' 'Elige un mod fuente para desactivar.')}
    $message=(L "Disable {0} in the PMM library and run Analyze again?`n`nThe PAK is kept under Mods\_Disabled and the game folder is unchanged until Deploy." "Desactivar {0} en la biblioteca PMM y volver a Analizar?`n`nEl PAK se conserva en Mods\_Disabled y la carpeta del juego no cambia hasta Deploy.") -f $name
    if(Confirm $message){
      Set-PMMLibraryModEnabled $name $false
      Refresh-UI
      $done={param($result) Refresh-UI}
      [void](Start-PMMBackgroundOperation -Operation Analyze -OnSuccess $done)
    }
  }catch{Handle-UIError $_ (L 'Disable unsupported source' 'Desactivar fuente no soportada')}
})


function Format-PMMByteSize([int64]$Bytes) {
  if($Bytes -ge 1GB){return ('{0:N2} GiB' -f ([double]$Bytes/1GB))}
  if($Bytes -ge 1MB){return ('{0:N1} MiB' -f ([double]$Bytes/1MB))}
  if($Bytes -ge 1KB){return ('{0:N1} KiB' -f ([double]$Bytes/1KB))}
  return ([string]$Bytes+' B')
}

function Start-PMMAIHandoffFromUI {
  param([switch]$AllowOversize,[switch]$Force)
  Open-PMMWorkbenchUnsupportedCase
}

function Prompt-PMMAIHandoffAfterAnalyze {
  # Cases are published by Analyze. Completion neither navigates nor contacts AI.
  $unsupported=@(Get-PMMUnsupportedAssets)
  if($unsupported.Count){$Script:TxtStatus.Text=((L '{0} case(s) need investigation. Open a case in Create.' '{0} caso(s) necesitan investigacion. Abre un caso en Crear.') -f $unsupported.Count)}
}

$Script:BtnOpenAIHandoff.Add_Click({
  Start-PMMAIHandoffFromUI
})

$Script:BtnImportManualSolution.Add_Click({
  try{
    $review=[string]$Script:BtnImportManualSolution.Tag
    if([string]::IsNullOrWhiteSpace($review) -or -not(Test-Path -LiteralPath (Join-Path $review 'case.json') -PathType Leaf)){throw (L 'This unsupported asset has no current review case. Run Analyze again.' 'Este asset no soportado no tiene un caso de revision actual. Ejecuta Analizar de nuevo.')}
    Add-Type -AssemblyName System.Windows.Forms
    $dialog=New-Object System.Windows.Forms.OpenFileDialog
    $dialog.Multiselect=$false
    $dialog.Filter=L 'PMM manual/AI solution (*.zip)|*.zip|All files (*.*)|*.*' 'Solucion manual/IA de PMM (*.zip)|*.zip|Todos (*.*)|*.*'
    if($dialog.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK){return}
    $warning=L "Import this experimental cooked solution?`n`nPMM will verify the exact case ID/input hashes, ZIP paths, cooked-family topology, output hashes and a read-only AssetReader parse. It CANNOT prove the proposed gameplay semantics. Build will remain clearly marked experimental until you test it in Palworld.`n`nContinue under your responsibility?" "Importar esta solucion cooked experimental?`n`nPMM verificara el ID de caso/hashes exactos, rutas del ZIP, topologia de la familia cooked, hashes de salida y una lectura con AssetReader. NO PUEDE demostrar la semantica de gameplay propuesta. Build seguira marcado como experimental hasta que lo pruebes en Palworld.`n`nContinuar bajo tu responsabilidad?"
    if(-not(Confirm $warning)){return}
    $imported=Import-PMMManualSolutionZip $dialog.FileName $review $true
    $Script:TxtStatus.Text=((L 'Experimental solution validated for case {0}. PMM will re-analyze.' 'Solucion experimental validada para el caso {0}. PMM volvera a analizar.') -f [string]$imported.CaseId)
    $done={param($result) Refresh-UI}
    [void](Start-PMMBackgroundOperation -Operation Analyze -Force -OnSuccess $done)
  }catch{Handle-UIError $_ (L 'Import manual/AI solution' 'Importar solucion manual/IA')}
})

# Decisions are persisted when the user changes asset, applies a bulk choice,
# starts Build, or closes PMM.  Preview 13 used a one-second timer that called
# CommitEdit while the Winner ComboBox was open; WPF therefore closed the
# dropdown almost immediately.  Do not reintroduce that polling pattern.

$Script:BtnApplyBulk.Add_Click({
  try {
    $choice = [string]$Script:CmbBulkWinner.SelectedItem
    if ([string]::IsNullOrWhiteSpace($choice)) { throw (L 'Choose a source first.' 'Elige primero una fuente para aplicar a todas las filas.') }
    if ($choice -eq 'Custom' -and [string]::IsNullOrWhiteSpace([string]$Script:TxtBulkCustom.Text)) {
      throw (L 'Enter the Custom value that should be applied to all visible conflict rows.' 'Introduce el valor Custom que se aplicara a todas las filas visibles.')
    }
    foreach ($row in @($Script:DgDecisions.ItemsSource)) {
      $row.SelectedChoice = $choice
      if ($choice -eq 'Custom') { $row.CustomValue = [string]$Script:TxtBulkCustom.Text }
      $row.ResolutionOrigin='Manual'
      $row.Status = L 'Resolved' 'Resuelto'
    }
    $Script:DgDecisions.Items.Refresh()
    Save-DecisionGridToPlan
    Refresh-PMMAnalysisWorkspace
    Refresh-ConflictWorkspace $Script:CurrentConflictAssetKey
    Update-BuildButtonState
    Update-PMMGuidedActionState
  } catch { Handle-UIError $_ (L 'Bulk conflict decision' 'Decision masiva de conflictos') }
})

$Script:BtnOpenReview.Add_Click({
  try {
    $folder = [string]$Script:BtnOpenReview.Tag
    if ([string]::IsNullOrWhiteSpace($folder) -or -not (Test-Path -LiteralPath $folder -PathType Container)) {
      throw (L 'No review folder is available for the selected asset. Run Analyze again.' 'No hay carpeta de revision para el asset seleccionado. Ejecuta Analizar de nuevo.')
    }
    Start-Process explorer.exe -ArgumentList ('"'+$folder+'"')
  } catch { Handle-UIError $_ (L 'Open review files' 'Abrir archivos de revision') }
})

$Script:BtnBuild.Add_Click({
  try {
    Save-DecisionGridToPlan
    $plan=Read-PMMMergePlan

    [object[]]$experimental=@(
      if($plan -and $null -ne $plan.Assets){
        $plan.Assets | Where-Object{[string]$_.Mode -eq 'ManualSolutionExperimental'}
      }
    )
    [int]$experimentalCount=$experimental.Length
    if($experimentalCount -gt 0){
      $names=@($experimental|ForEach-Object{[IO.Path]::GetFileName([string]$_.Asset)}) -join ', '
      $warning=(L "This Build contains {0} experimental manual/AI cooked solution(s):`n{1}`n`nPMM validated provenance, file topology, hashes and parsing, but not the intended gameplay behavior. Continue and test the result in Palworld?" "Este Build contiene {0} solucion(es) cooked manual/IA experimental(es):`n{1}`n`nPMM valido procedencia, topologia, hashes y lectura del asset, pero no el comportamiento de gameplay previsto. Continuar y probar el resultado en Palworld?") -f $experimentalCount,$names
      if(-not(Confirm $warning)){return}
    }

    Reset-PMMOperationCancellation
    if([bool]$Script:TglAutoMode.IsChecked){Start-PMMAutoPipeline}
    $done={
      param($result)
      $message=if($result){[string]$result.ResultText}else{''}
      if([string]::IsNullOrWhiteSpace($message)){$message=L 'Build complete.' 'Build terminado.'}
      Set-PMMOperationResult 'Build' $message
      Refresh-UI
      $Script:TxtLog.Text=Get-PMMRecentLog
      $Script:TxtStatus.Text=Get-PMMStatusLine
    }
    $failed={param($message) Stop-PMMAutoPipeline;Show-Error ([string]$message)}
    [void](Start-PMMBackgroundOperation -Operation Build -Mode 'ConflictGroups' -OnSuccess $done -OnFailure $failed)
  } catch { Stop-PMMAutoPipeline;Handle-UIError $_ 'Build Merge' }
})

$Script:BtnDeploy.Add_Click({
  if(-not(Request-PMMProcessingSlot 'Deploy')){return}
  Reset-PMMOperationCancellation
  if([bool]$Script:TglAutoMode.IsChecked){Start-PMMAutoPipeline}
  try{
    Save-DecisionGridToPlan
    $preview=Get-PMMDeploymentPreview
    Write-PMMLog ('Deploy preflight: '+($preview -replace "(`r`n|`n|`r)",' | '))
    Set-PMMDeployBusy $true
    $deployProgress={
      param([double]$fraction,[string]$message)
      Set-PMMDeployProgress ([int][Math]::Round(100.0*$fraction)) 100 $message
    }.GetNewClosure()
    $result=Deploy-PMMManagedState $deployProgress
    $deployDone=if([string]::IsNullOrWhiteSpace([string]$result)){L 'Deploy complete.' 'Deploy terminado.'}else{[string]$result}
    Set-PMMDeployProgress 100 100 $deployDone
    Refresh-UI
    Check-PMMExternalModChanges -Force
    Notify-PMMWorkflowStepComplete
  }catch{
    if(Test-PMMCancellationError $_){Set-PMMOperationResult 'Deploy' (L 'Deploy cancelled. Any committed managed files were rolled back.' 'Deploy cancelado. Cualquier archivo gestionado ya aplicado fue restaurado mediante rollback.');Stop-PMMAutoPipeline}
    else{Stop-PMMAutoPipeline;Handle-UIError $_ 'Deploy'}
  }
  finally{
    Set-PMMDeployBusy $false
    try{Update-PMMGuidedActionState}catch{}
    if($Script:AutoPipelineActive){try{Invoke-PMMAutoContinue}catch{Write-PMMLog ('AUTO continuation after Deploy failed: '+$_.Exception.Message)}}
  }
})


$Script:BtnUndeployPatch.Add_Click({
  try{
    $entry=$Script:LstPatches.SelectedItem
    if(-not$entry -or -not$entry.Patch){throw (L 'Select the deployed merge you want to undeploy.' 'Selecciona el merge desplegado que quieres retirar.')}
    $patch=$entry.Patch
    if(-not[bool]$patch.Deployed){$Script:TxtStatus.Text=L 'The selected merge is already not deployed.' 'El merge seleccionado ya no esta desplegado.';Update-PMMPatchActionButtons;return}
    $name=[string]$patch.Name
    if(-not(Confirm ((L "Undeploy '{0}'? This removes only the exact PMM merge PAK + its sidecar from Palworld ~mods. The saved build inside PMM and all source mods are kept." "Retirar '{0}'? Esto elimina solamente el PAK exacto del merge PMM + su sidecar de ~mods de Palworld. El build guardado dentro de PMM y todos los mods fuente se conservan.") -f $name))){return}
    $result=Undeploy-PMMManagedPatch $patch
    $Script:TxtStatus.Text=if([bool]$result.Removed){(L 'Merge undeployed from Palworld. Saved PMM build was kept.' 'Merge retirado de Palworld. El build guardado en PMM se conservo.')}else{(L 'The selected merge was not present in Palworld ~mods.' 'El merge seleccionado no estaba en ~mods de Palworld.')}
    Refresh-UI;Update-PMMGuidedActionState
  }catch{Handle-UIError $_ (L 'Undeploy merge' 'Retirar merge')}
})

