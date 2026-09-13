# Preserved 1.3.2 definitions; extracted for 1.3.3.
function Find-Control([string]$Name) {
  $control = $Window.FindName($Name)
  if (-not $control) { throw "UI control not found: $Name" }
  return $control
}

function L([string]$English,[string]$Spanish) {
  return (Get-PMMText $English $Spanish)
}

function Get-PMMThemeStore {
  $p=Join-PMMPath 'Themes'
  if(-not(Test-Path -LiteralPath $p -PathType Container)){New-Item -ItemType Directory -Force -Path $p|Out-Null}
  return $p
}

function Set-PMMAIIOActiveSession([string]$SessionId) {
  $session=Get-PMMAIIOSession $SessionId
  if(-not$session){return $null}
  $cfg=Get-PMMConfig;$cfg.AIIOActiveSession=$SessionId;Save-PMMConfig $cfg
  return $session
}

function Set-PMMFixLabAttentionVisual([array]$Candidates,[string]$Origin='') {
  $items=@($Candidates)
  $hashParts=[System.Collections.Generic.List[string]]::new()
  foreach($c in $items){foreach($src in @($c.Sources)){if($src -and $src.Hash){$hashParts.Add(([string]$src.Hash).ToLowerInvariant())}}}
  $sig=(@($hashParts.ToArray()|Sort-Object -Unique) -join '|')
  if($sig -ne [string]$Script:FixLabAttentionSignature){$Script:FixLabNoticeDismissed=$false;$Script:FixLabAttentionSignature=$sig}
  if(-not[string]::IsNullOrWhiteSpace($Origin)){$Script:FixLabAttentionOrigin=$Origin}

  $active=($items.Count -gt 0)
  if($Script:BrdFixLabBadge){$Script:BrdFixLabBadge.Visibility=if($active){[System.Windows.Visibility]::Visible}else{[System.Windows.Visibility]::Collapsed}}
  if($Script:TxtFixLabBadge){$Script:TxtFixLabBadge.Text=[string]$items.Count}
  if($Script:TabFixLab){
    if($active){
      $Script:TabFixLab.FontWeight='SemiBold'
      try{$Script:TabFixLab.Foreground=$Window.Resources['AccentHeadingAmber']}catch{}
      try{$Script:TabFixLab.Background=$Window.Resources['NoticeBackground']}catch{}
    }else{
      $Script:TabFixLab.ClearValue([System.Windows.Controls.Control]::ForegroundProperty)
      $Script:TabFixLab.ClearValue([System.Windows.Controls.Control]::BackgroundProperty)
      $Script:TabFixLab.ClearValue([System.Windows.Controls.Control]::FontWeightProperty)
    }
  }
  if($Script:BrdFixLabNotice){$Script:BrdFixLabNotice.Visibility=if($active -and -not$Script:FixLabNoticeDismissed){[System.Windows.Visibility]::Visible}else{[System.Windows.Visibility]::Collapsed}}
  if($active -and $Script:TxtFixLabNotice){
    $names=@($items|ForEach-Object{[string]$_.Name}) -join ', '
    if([string]$Script:FixLabAttentionOrigin -eq 'Analyze'){$Script:TxtFixLabNotice.Text=((L 'Analyze detected {0} repairable legacy case(s): {1}. Fix Lab has preselected the repair case.' 'Analyze detecto {0} caso(s) antiguos reparables: {1}. Fix Lab ha preseleccionado el caso de reparacion.') -f $items.Count,$names)}
    elseif([string]$Script:FixLabAttentionOrigin -eq 'Import'){$Script:TxtFixLabNotice.Text=((L 'Import detected {0} repairable legacy case(s): {1}. Fix Lab is ready.' 'Import detecto {0} caso(s) antiguos reparables: {1}. Fix Lab esta listo.') -f $items.Count,$names)}
    else{$Script:TxtFixLabNotice.Text=((L '{0} repairable legacy case(s) are available in Fix Lab: {1}.' 'Hay {0} caso(s) antiguos reparables disponibles en Fix Lab: {1}.') -f $items.Count,$names)}
  }
}

function Show-Info([string]$Message) {
  # Informational results are persistent/non-modal. PMM reserves modal dialogs
  # for errors and decisions that really require the user to answer.
  if(-not[string]::IsNullOrWhiteSpace($Message)){
    try{$Script:TxtStatus.Text=$Message}catch{}
    try{$Script:TxtOperationProgress.Text=$Message}catch{}
    Write-PMMLog ('Info: '+$Message)
  }
}

function Set-PMMAnalyzeProgress {
  param([int]$Current,[int]$Total,[string]$Message,[switch]$Indeterminate)
  $fraction=if($Total -gt 0){[double]$Current/[double]$Total}else{0.0}
  Set-PMMWorkflowButtonProgress $Script:BtnScan 'Analyze' $fraction $Message -Indeterminate:$Indeterminate
  Set-PMMUniversalProgress -Operation 'Analyze' -Fraction $fraction -Message $Message -Indeterminate:$Indeterminate
}

function Get-OptionJson($Options,[string]$Name) {
  if ($null -eq $Options) { return $null }
  if ($Options -is [hashtable]) {
    if ($Options.ContainsKey($Name)) { return [string]$Options[$Name] }
    return $null
  }
  $property = $Options.PSObject.Properties[$Name]
  if ($property) { return [string]$property.Value }
  return $null
}

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

function Open-PMMUnsupportedCaseFromUI {
  try{
    $selected=$Script:LstUnsupportedAssets.SelectedItem
    if(-not$selected){throw (L 'Select an unsupported asset first.' 'Selecciona primero un asset no soportado.')}
    $case=Get-PMMCaseForAsset $selected
    if(-not$case){throw (L 'Run Analyze to register the case from current evidence.' 'Ejecuta Analizar para registrar el caso con la evidencia actual.')}
    Select-PMMCaseLocation $case
  }catch{Handle-UIError $_ (L 'Open case' 'Abrir caso')}
}