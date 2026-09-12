function Save-UiSettings {
  $cfg = Get-PMMConfig
  $cfg.CloseGameBeforeDeploy = [bool]$Script:ChkCloseGame.IsChecked
  $cfg.ForceCloseOnTimeout = [bool]$Script:ChkForceClose.IsChecked
  $cfg.MergeMode = 'ConflictGroups'
  $cfg.AutoMode = [bool]$Script:TglAutoMode.IsChecked
  $cfg.AutoIncludePlay = [bool]$Script:ChkAutoPlay.IsChecked
  $hintValue=5
  try{$hintValue=[int]$Script:CmbActionHintDuration.SelectedValue}catch{$hintValue=5}
  if(-($hintValue -eq -1 -or ($hintValue -ge 0 -and $hintValue -le 120))){$hintValue=5}
  $cfg.ActionHintSeconds=$hintValue
  try{$cfg.Theme=[string](Get-PMMSelectedThemeId)}catch{$cfg.Theme='pmm-crystal'}
  foreach($profile in @('Auto','SemiAuto','Manual','Attention','Error')){$prop=Get-PMMSoundProfileConfigProperty $profile;$value=Get-PMMPendingSoundId $profile;if(-not($cfg.PSObject.Properties.Name -contains $prop)){$cfg|Add-Member -NotePropertyName $prop -NotePropertyValue $value}else{$cfg.$prop=$value}}
  if(-not($cfg.PSObject.Properties.Name -contains 'SoundSemiAutoEnabled')){$cfg|Add-Member -NotePropertyName SoundSemiAutoEnabled -NotePropertyValue ([bool]$Script:ChkSoundEachAutoStep.IsChecked)}else{$cfg.SoundSemiAutoEnabled=[bool]$Script:ChkSoundEachAutoStep.IsChecked}
  if(-not($cfg.PSObject.Properties.Name -contains 'SoundAttentionEnabled')){$cfg|Add-Member -NotePropertyName SoundAttentionEnabled -NotePropertyValue ([bool]$Script:ChkSoundAttention.IsChecked)}else{$cfg.SoundAttentionEnabled=[bool]$Script:ChkSoundAttention.IsChecked}
  if(-not($cfg.PSObject.Properties.Name -contains 'AIIOAutoCreateErrorCases')){$cfg|Add-Member -NotePropertyName AIIOAutoCreateErrorCases -NotePropertyValue ([bool]$Script:ChkAIIOAutoCreateErrorCases.IsChecked)}else{$cfg.AIIOAutoCreateErrorCases=[bool]$Script:ChkAIIOAutoCreateErrorCases.IsChecked}
  # Retain legacy fields for downgrade compatibility; Auto is the closest old equivalent.
  $cfg.CompletionSound=Get-PMMPendingSoundId 'Auto'
  try{$cfg.CompletionVolume=[int][Math]::Round([double]$Script:SldCompletionVolume.Value)}catch{}
  Save-PMMConfig $cfg
  Save-PMMLayoutSettings
}

function Save-PMMAutoPreferences {
  # AUTO controls commit immediately. Keep them isolated from Settings values
  # that deliberately remain a draft until the user presses Apply changes.
  $cfg=Get-PMMConfig
  $cfg.AutoMode=[bool]$Script:TglAutoMode.IsChecked
  $cfg.AutoIncludePlay=[bool]$Script:ChkAutoPlay.IsChecked
  Save-PMMConfig $cfg
}

function Save-PMMAIHelpSettings {
  # AI & Help settings commit independently.  Toggling one must not silently
  # save a theme or sound selection that is still awaiting Apply changes.
  $cfg=Get-PMMConfig
  $value=[bool]$Script:ChkAIIOAutoCreateErrorCases.IsChecked
  if(-not($cfg.PSObject.Properties.Name -contains 'AIIOAutoCreateErrorCases')){$cfg|Add-Member -NotePropertyName AIIOAutoCreateErrorCases -NotePropertyValue $value}else{$cfg.AIIOAutoCreateErrorCases=$value}
  Save-PMMConfig $cfg
}

function Run-Analyze {
  param([switch]$Force)
  Set-PMMAnalyzeBusy $true
  $Script:TxtStatus.Text = L 'Analyzing shared assets against vanilla...' 'Analizando assets compartidos contra vanilla...'
  try {
    $result = Invoke-PMMScan -Force:$Force
    Refresh-PMMAnalysisWorkspace
    Refresh-ConflictWorkspace
    $Script:TxtLog.Text = Get-PMMRecentLog
    $Script:TxtStatus.Text = Get-PMMStatusLine
    return $result
  } finally {
    Set-PMMAnalyzeBusy $false
  }
}

# ---------------------------------------------------------------------------
# Game location / launch controls.
# ---------------------------------------------------------------------------
$detectHandler={try{$ok=[bool](Invoke-PMMGameDetection $true);if($ok -and [bool]$Script:TglAutoMode.IsChecked){Start-PMMAutoPipeline;Invoke-PMMAutoContinue};if($ok){Notify-PMMWorkflowStepComplete}}catch{Handle-UIError $_ (L 'Palworld detection' 'Deteccion de Palworld')}}
$Script:BtnDetectGame.Add_Click($detectHandler)
$Script:BtnDetectGameSettings.Add_Click($detectHandler)

$Script:BtnBrowseGame.Add_Click({try{[void](Select-PMMSteamFolderInteractive)}catch{Handle-UIError $_ (L 'Steam location selection' 'Seleccion de Steam')}})
$Script:BtnBrowseGameManual.Add_Click({try{[void](Select-PMMPalworldFolderInteractive)}catch{Handle-UIError $_ (L 'Manual Palworld location selection' 'Seleccion manual de Palworld')}})

$openGameHandler={
  try{
    $path=(Get-PMMConfig).GamePath
    if(-not$path){throw (L 'Detect or configure Palworld first.' 'Detecta o configura Palworld primero.')}
    Start-Process explorer.exe -ArgumentList ('"'+$path+'"')
  }catch{Handle-UIError $_ (L 'Open game folder' 'Abrir carpeta del juego')}
}
$Script:BtnOpenGame.Add_Click($openGameHandler)
$Script:BtnOpenGameSettings.Add_Click($openGameHandler)

$openModsHandler={
  try{
    $path=Get-GameModsPath
    if(-not$path){throw (L 'Detect or configure Palworld first.' 'Detecta o configura Palworld primero.')}
    Ensure-GameModsFolder
    Start-Process explorer.exe -ArgumentList ('"'+$path+'"')
  }catch{Handle-UIError $_ (L 'Open mods folder' 'Abrir carpeta de mods')}
}
$Script:BtnOpenModsFolder.Add_Click($openModsHandler)
$Script:BtnOpenModsSettings.Add_Click($openModsHandler)

$Script:BtnOpenLibrary.Add_Click({try{Start-Process explorer.exe -ArgumentList ('"'+(Get-PMMPath 'Mods')+'"')}catch{Handle-UIError $_ (L 'Open library' 'Abrir biblioteca')}})
$Script:BtnPlay.Add_Click({try{Start-Palworld}catch{Handle-UIError $_ (L 'Start Palworld' 'Iniciar Palworld')}})

$Script:TglAutoMode.Add_Click({
  try{
    $enabled=[bool]$Script:TglAutoMode.IsChecked;Save-PMMAutoPreferences
    if(-not$enabled){Stop-PMMAutoPipeline (L 'SemiAUTO is disabled. Manual actions perform one workflow step per click.' 'SemiAUTO esta desactivado. Las acciones manuales hacen un paso del flujo por clic.')}
    else{$Script:TxtStatus.Text=L 'SemiAUTO armed. The next workflow action you start manually will continue through the remaining safe steps.' 'SemiAUTO preparado. La siguiente accion del flujo que inicies manualmente continuara por los pasos seguros restantes.';Update-PMMCancelButtonState}
  }catch{Handle-UIError $_ (L 'Automatic mode' 'Modo automatico')}
})
$Script:ChkAutoPlay.Add_Click({try{Save-PMMAutoPreferences;Update-PMMGuidedActionState}catch{}})
$Script:BtnAutoRun.Add_Click({
  try{
    Start-PMMAutoPipeline -OneShot
    if($Script:AutoPipelineActive){
      $Script:TxtStatus.Text=L 'AUTO started from the current workflow state.' 'AUTO iniciado desde el estado actual del flujo.'
      [void](Ensure-PMMAutoFixLabGameReference)
      Invoke-PMMAutoContinue
    }
  }
  catch{Stop-PMMAutoPipeline;Handle-UIError $_ (L 'AUTO workflow' 'Flujo AUTO')}
})
$Script:CmbActionHintDuration.Add_SelectionChanged({try{if(-not $Script:UiSettingsRefreshing -and $Script:CmbActionHintDuration.SelectedItem){$Script:TxtStatus.Text=L 'Settings changed. Press Apply changes.' 'Ajustes modificados. Pulsa Aplicar cambios.'}}catch{}})
$Script:SldCompletionVolume.Add_ValueChanged({
  try{$v=[Math]::Max(0,[Math]::Min(100,[int][Math]::Round([double]$Script:SldCompletionVolume.Value)));$Script:TxtCompletionVolume.Text=($v.ToString()+'%');if(-not $Script:UiSettingsRefreshing){$Script:TxtStatus.Text=L 'Settings changed. Press Apply changes.' 'Ajustes modificados. Pulsa Aplicar cambios.'}}catch{}
})
$Script:BtnApplySettings.Add_Click({
  try{
    Save-UiSettings
    Apply-PMMTheme (Get-PMMSelectedThemeId) -Force
    $Script:ThemePreviewActive=$false
    Close-PMMRequiredActionPopup;$Script:RequiredActionSignature='';Update-PMMGuidedActionState
    $Script:TxtStatus.Text=L 'Settings applied.' 'Ajustes aplicados.'
  }catch{Handle-UIError $_ (L 'Apply settings' 'Aplicar ajustes')}
})
$Script:BtnRestoreDefaults.Add_Click({
  try{
    $priorRefreshing=[bool]$Script:UiSettingsRefreshing
    $Script:UiSettingsRefreshing=$true
    try{
      Set-PMMSelectedThemeId 'pmm-crystal'
      $Script:CmbActionHintDuration.SelectedValue=5
      $Script:SldCompletionVolume.Value=50
      $Script:TxtCompletionVolume.Text='50%'
      $Script:PendingSoundSelections=@{
        Auto='Microwave'
        SemiAuto='Ok'
        Manual='Good'
        Attention='Alert'
        Error='Microwave3'
      }
      $Script:ChkSoundEachAutoStep.IsChecked=$true
      $Script:ChkSoundAttention.IsChecked=$true
      Refresh-PMMSoundProfileUi (Get-PMMCurrentSoundProfileId)
    } finally {
      $Script:UiSettingsRefreshing=$priorRefreshing
    }
    $Script:TxtStatus.Text=L 'Defaults restored in Settings. Press Apply changes to save them.' 'Valores restaurados en Opciones. Pulsa Aplicar cambios para guardarlos.'
  }catch{Handle-UIError $_ (L 'Restore defaults' 'Restaurar valores')}
})
$Script:BtnImportTheme.Add_Click({
  try{
    $dlg=[Microsoft.Win32.OpenFileDialog]::new();$dlg.Title=L 'Add PMM color schemes' 'Agregar esquemas de color PMM';$dlg.Filter='PMM schemes (*.json;*.zip)|*.json;*.zip|JSON schemes (*.json)|*.json|PMM scheme packs (*.zip)|*.zip';$dlg.Multiselect=$true
    if($dlg.ShowDialog() -ne $true){return}
    $result=Import-PMMThemeInputs -Paths @($dlg.FileNames)
    if(@($result.Conflicts).Count -gt 0){
      $question=(L 'Replace the existing user scheme(s)? PMM will create backups first:' '¿Reemplazar los esquemas del usuario existentes? PMM creara copias antes:')+[Environment]::NewLine+(@($result.Conflicts)-join ', ')
      if(Confirm $question){$result=Import-PMMThemeInputs -Paths @($dlg.FileNames) -AllowReplace}
    }
    if(-not[bool]$result.Success){
      $details=@(@($result.Errors)+@($result.Conflicts|ForEach-Object{(L 'Replacement not confirmed: ' 'Reemplazo no confirmado: ')+[string]$_})) -join [Environment]::NewLine
      throw $details
    }
    $selected=Get-PMMSelectedThemeId
    if(@($result.Imported).Count -gt 0){$selected=[string](@($result.Imported)[-1])}
    Refresh-PMMThemeOptions $selected
    $Script:TxtStatus.Text=((L 'Theme import complete: {0} installed, {1} already available, {2} warning(s). Press Apply changes to use the selected scheme.' 'Importacion de temas terminada: {0} instalados, {1} ya disponibles, {2} aviso(s). Pulsa Aplicar cambios para usar el esquema seleccionado.') -f @($result.Imported).Count,@($result.Skipped).Count,@($result.Warnings).Count)
  }catch{Handle-UIError $_ (L 'Add color scheme' 'Agregar esquema de color')}
})
$Script:BtnOpenThemesFolder.Add_Click({try{Start-Process explorer.exe -ArgumentList ('"'+(Get-PMMThemeStore)+'"')}catch{Handle-UIError $_ (L 'Open themes folder' 'Abrir carpeta de temas')}})
$Script:CmbSoundEventProfile.Add_SelectionChanged({try{if(-not$Script:UiSettingsRefreshing -and $Script:CmbSoundEventProfile.SelectedValue){Refresh-PMMSoundProfileUi ([string]$Script:CmbSoundEventProfile.SelectedValue)}}catch{}})
$builtinSoundHandler={
  param($sender,$e)
  if($Script:UiSettingsRefreshing -or -not[bool]$sender.IsChecked){return}
  try{Set-PMMPendingSoundId ([string]$sender.Tag);Refresh-PMMCustomSoundOptions ''}catch{}
}
foreach($rb in @($Script:RdoSoundNone,$Script:RdoSoundBell,$Script:RdoSoundMicrowave,$Script:RdoSoundMicrowave3,$Script:RdoSoundOk,$Script:RdoSoundGood,$Script:RdoSoundCrystal,$Script:RdoSoundAlert)){if($rb){$rb.Add_Checked($builtinSoundHandler)}}
$Script:RdoSoundCustom.Add_Checked({
  if($Script:UiSettingsRefreshing -or -not[bool]$Script:RdoSoundCustom.IsChecked){return}
  try{
    $selected=Get-PMMSelectedCustomSoundId
    if([string]::IsNullOrWhiteSpace($selected)){
      $custom=@(Get-PMMCustomSoundDefinitions)
      if($custom.Count -gt 0){$selected=[string]$custom[0].Id;Refresh-PMMCustomSoundOptions $selected}
    }
    if(-not[string]::IsNullOrWhiteSpace($selected)){Set-PMMPendingSoundId $selected}
  }catch{}
})
$Script:ChkSoundEachAutoStep.Add_Click({if(-not$Script:UiSettingsRefreshing){$Script:TxtStatus.Text=L 'Sound settings changed. Press Apply changes.' 'Los sonidos han cambiado. Pulsa Aplicar cambios.'}})
$Script:ChkSoundAttention.Add_Click({if(-not$Script:UiSettingsRefreshing){$Script:TxtStatus.Text=L 'Sound settings changed. Press Apply changes.' 'Los sonidos han cambiado. Pulsa Aplicar cambios.'}})
$Script:ChkAIIOAutoCreateErrorCases.Add_Click({if(-not$Script:UiSettingsRefreshing){try{Save-PMMAIHelpSettings;$Script:TxtAIIOSettingsStatus.Text=L 'AI & Help settings saved.' 'Ajustes de IA y ayuda guardados.'}catch{Handle-UIError $_ (L 'Save AI & Help settings' 'Guardar ajustes de IA y ayuda')}}})
$Script:BtnImportSound.Add_Click({
  try{
    $dlg=[Microsoft.Win32.OpenFileDialog]::new();$dlg.Title=L 'Add reusable PMM sound' 'Agregar sonido reutilizable de PMM';$dlg.Filter='Audio files (*.wav;*.mp3;*.wma)|*.wav;*.mp3;*.wma'
    if($dlg.ShowDialog() -ne $true){return}
    $dest=Join-Path (Get-PMMSoundStore) ([IO.Path]::GetFileName([string]$dlg.FileName));Copy-Item -LiteralPath ([string]$dlg.FileName) -Destination $dest -Force
    $id='file:'+[IO.Path]::GetFileName($dest);Set-PMMPendingSoundId $id;Refresh-PMMSoundProfileUi (Get-PMMCurrentSoundProfileId)
    $Script:TxtStatus.Text=L 'Custom sound added and selected for the current sound event. Press Apply changes.' 'Sonido custom agregado y seleccionado para el evento actual. Pulsa Aplicar cambios.'
  }catch{Handle-UIError $_ (L 'Add sound' 'Agregar sonido')}
})
$Script:BtnOpenSoundsFolder.Add_Click({try{Start-Process explorer.exe -ArgumentList ('"'+(Get-PMMSoundStore)+'"')}catch{Handle-UIError $_ (L 'Open sounds folder' 'Abrir carpeta de sonidos')}})
$Script:BtnTestCompletionSound.Add_Click({
  try{
    $id=Get-PMMPendingSoundId (Get-PMMCurrentSoundProfileId)
    $volume=[Math]::Max(0,[Math]::Min(100,[int][Math]::Round([double]$Script:SldCompletionVolume.Value)));Play-PMMSoundId $id $volume
  }catch{Handle-UIError $_ (L 'Test sound' 'Probar sonido')}
})

$Script:BtnCancelOperation.Add_Click({
  if((Get-PMMActiveProcessingOperation) -eq 'Tool'){Stop-PMMWorkbenchTool;return}
  try{
    $operation=if($Script:ImportBusy){'Import'}elseif($Script:AnalyzeBusy){'Analyze'}elseif($Script:BuildBusy){'Build'}elseif($Script:DeployBusy){'Deploy'}elseif($Script:FixLabOperationBusy){'FixLab'}elseif($Script:AIIOBusy){'AIIO'}elseif($Script:AutoPipelineActive){'Auto'}else{'Operation'}
    $Script:CancelRequested=$true
    Stop-PMMAutoPipeline
    $hadBackground=$false
    try{$hadBackground=($Script:BackgroundOperationProcess -and -not$Script:BackgroundOperationProcess.HasExited)}catch{}
    if($hadBackground){Stop-PMMBackgroundOperation -Silent}
    try{if($Script:GameReferenceProcess -and -not$Script:GameReferenceProcess.HasExited){Stop-PMMGameReferenceBuild -Silent}}catch{}
    $msg=L 'Cancellation requested. PMM will stop at the nearest safe checkpoint; Deploy rolls back if commit already started.' 'Cancelacion solicitada. PMM se detendra en el punto seguro mas cercano; Deploy hace rollback si el commit ya habia empezado.'
    $Script:TxtStatus.Text=$msg
    try{$Script:TxtOperationProgress.Text=$msg}catch{}
    if($hadBackground){Set-PMMOperationResult $operation (L 'Operation cancelled.' 'Operacion cancelada.')}
    Update-PMMCancelButtonState
  }catch{Handle-UIError $_ (L 'Cancel operation' 'Cancelar operacion')}
})

