# Preserved 1.3.2 definitions; extracted for 1.3.3.
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

function Format-PMMByteSize([int64]$Bytes) {
  if($Bytes -ge 1GB){return ('{0:N2} GiB' -f ([double]$Bytes/1GB))}
  if($Bytes -ge 1MB){return ('{0:N1} MiB' -f ([double]$Bytes/1MB))}
  if($Bytes -ge 1KB){return ('{0:N1} KiB' -f ([double]$Bytes/1KB))}
  return ([string]$Bytes+' B')
}

function Start-PMMAIHandoffFromUI { param([switch]$AllowOversize,[switch]$Force) Open-PMMUnsupportedCaseFromUI }

function Prompt-PMMAIHandoffAfterAnalyze { # Cases are registered by the worker; no dialog or AI dispatch.
}
function Invoke-PMMNewLibraryCaseUI {
  [void](Save-PMMAIIOCaseEditor)
  $entries=@(Get-SelectedPMMLibraryEntries)
  if(-not$entries.Count){throw (L 'Select a source mod first.' 'Selecciona primero un mod de la biblioteca.')}
  # Freeze the selection before opening the modal; filtering cannot change its inputs.
  $paths=@(foreach($entry in $entries){
    if(-not[IO.File]::Exists($entry.Path)){throw ('Mod no longer available: '+$entry.Name)}
    [string]$entry.Path
  })
  $type=if($paths.Count -eq 1){'FIX_MOD'}else{'COMPATIBILITY'}
  $title=if($paths.Count -eq 1){[IO.Path]::GetFileNameWithoutExtension($paths[0])}else{L 'Compatibility of selected mods' 'Compatibilidad de los mods seleccionados'}
  $draft=Show-PMMAIIONewCaseDialog -DefaultTitle $title -DefaultType $type -ReferenceNames @($entries.Name)
  if(-not$draft){return}
  $case=New-PMMAIIOCase -Title $draft.Title -Type $draft.Type -Description $draft.Description -Transport MCP -AIClient CHATGPT
  foreach($path in $paths){$case=Add-PMMAIIOCaseModReference $case.CaseId $path 'FULL_PAK'}
  Select-PMMCaseLocation $case
}
