# Preserved 1.3.2 definitions; extracted for 1.3.3.
function Get-PMMSoundStore {
  $p=Join-PMMPath 'Sounds'
  if(-not(Test-Path -LiteralPath $p -PathType Container)){New-Item -ItemType Directory -Force -Path $p|Out-Null}
  return $p
}

function Get-PMMBaseThemePalette([string]$Base='Night') {
  if($Base -ieq 'Light'){
    return [ordered]@{
      AppBackground='#EAF0F7';HeaderBackground='#F8FBFF';CardBackground='#FFFFFF';CardAltBackground='#F7F9FC';InputBackground='#FFFFFF';
      CardBorder='#D5DAE0';InputBorder='#C5CBD2';PrimaryText='#17202A';MutedText='#5F6B76';SelectionBackground='#DDEBFF';SelectionText='#152238';
      GridLine='#E6E9ED';Splitter='#DDE2E8';StatusBackground='#E9EDF2';SoftBlue='#EEF4FF';SoftGreen='#ECF8EF';SoftAmber='#FFF7E6';SoftRed='#FFF0F0';SoftGray='#F7F8FA';
      FixHeaderBackground='#EEF3F8';FixHeaderBorder='#C9D5E2';NoticeBackground='#FFF7ED';NoticeBorder='#F2B56B';DecisionNoticeBackground='#EFF6FF';DecisionNoticeBorder='#3B82F6';DecisionNoticeHeading='#1D4ED8';SourceBackground='#F4F8FF';SourceBorder='#CAD8EA';
      ConfigureBackground='#FFF9EE';ConfigureBorder='#E8D6AE';BuildBackground='#F7F5FF';BuildBorder='#D8D1EF';OutputBackground='#F1FAF3';OutputBorder='#C8E2CE';
      BackupBackground='#FAF8F5';BackupBorder='#DDD7CF';AdvancedBackground='#F7F8FA';AccentHeadingBlue='#284B73';AccentHeadingAmber='#7A551A';AccentHeadingPurple='#51427C';AccentHeadingGreen='#2F6B3B';WarmHeading='#62584C';
      ButtonBackground='#F8FAFC';ButtonHover='#F1F5F9';ButtonForeground='#111827';ButtonBorder='#CBD5E1'
    }
  }
  return [ordered]@{
    AppBackground='#0B1016';HeaderBackground='#121A24';CardBackground='#171E27';CardAltBackground='#1D2631';InputBackground='#111820';
    CardBorder='#303C4A';InputBorder='#3B4A5B';PrimaryText='#E7EDF5';MutedText='#A8B3C0';SelectionBackground='#314963';SelectionText='#FFFFFF';
    GridLine='#2A3541';Splitter='#3B4A5B';StatusBackground='#121A23';SoftBlue='#172535';SoftGreen='#17291F';SoftAmber='#2B2418';SoftRed='#2B1D21';SoftGray='#1C2530';
    FixHeaderBackground='#162331';FixHeaderBorder='#34485D';NoticeBackground='#2A2218';NoticeBorder='#8A652F';DecisionNoticeBackground='#10263F';DecisionNoticeBorder='#38BDF8';DecisionNoticeHeading='#7DD3FC';SourceBackground='#18283A';SourceBorder='#35506A';
    ConfigureBackground='#292315';ConfigureBorder='#5A492A';BuildBackground='#241F31';BuildBorder='#51446A';OutputBackground='#18291F';OutputBorder='#385A43';
    BackupBackground='#24211D';BackupBorder='#4B453C';AdvancedBackground='#1A232E';AccentHeadingBlue='#9CC8F6';AccentHeadingAmber='#E0BD73';AccentHeadingPurple='#C2B3E7';AccentHeadingGreen='#93D5A4';WarmHeading='#C5B9AA';
    ButtonBackground='#263241';ButtonHover='#334255';ButtonForeground='#EAF0F7';ButtonBorder='#44566A'
  }
}

function Get-PMMDefaultColorFlow {
  return [ordered]@{
    Import=[ordered]@{Progress='#C4B5FD';Border='#6D28D9'}
    Analyze=[ordered]@{Progress='#93C5FD';Border='#1D4ED8'}
    Build=[ordered]@{Progress='#FCD34D';Border='#B45309'}
    Deploy=[ordered]@{Progress='#86EFAC';Border='#258342'}
    Play=[ordered]@{Progress='#5EEAD4';Border='#0F766E'}
  }
}

function Convert-PMMThemeJson([string]$Path){
  try{
    $doc=Get-Content -LiteralPath $Path -Raw -Encoding UTF8|ConvertFrom-Json
    if(-not$doc){return $null}
    $schema='';try{$schema=[string]$doc.schema}catch{}
    if($schema -notin @('PMM_COLOR_SCHEME_V1','PMM_COLOR_SCHEME_V2')){throw ('Unsupported color scheme schema: '+$schema)}
    $id='';try{$id=[string]$doc.id}catch{}
    if($id -cnotmatch '^[a-z0-9][a-z0-9._-]{0,63}$'){throw 'Color scheme id must use lowercase letters, digits, dot, underscore or hyphen (maximum 64 characters).'}
    $name='';try{$name=[string]$doc.name}catch{};if([string]::IsNullOrWhiteSpace($name)){$name=$id}
    $base='Night';try{$base=[string]$doc.base}catch{};if($base -notin @('Light','Night','Dark')){$base='Night'};if($base -eq 'Dark'){$base='Night'}
    $palette=Get-PMMBaseThemePalette $base
    if($doc.PSObject.Properties.Name -contains 'palette' -and $doc.palette){foreach($prop in $doc.palette.PSObject.Properties){if($palette.Contains($prop.Name) -and -not[string]::IsNullOrWhiteSpace([string]$prop.Value)){$palette[$prop.Name]=[string]$prop.Value}}}
    $flow=Get-PMMDefaultColorFlow
    if($doc.PSObject.Properties.Name -contains 'colorFlow' -and $doc.colorFlow){
      foreach($state in @('Import','Analyze','Build','Deploy','Play')){
        $sp=$doc.colorFlow.PSObject.Properties[$state]
        if($sp -and $sp.Value){
          foreach($part in @('Progress','Border')){if($sp.Value.PSObject.Properties.Name -contains $part -and -not[string]::IsNullOrWhiteSpace([string]$sp.Value.$part)){$flow[$state][$part]=[string]$sp.Value.$part}}
        }
      }
    }
    # Keep validation independent from WPF resource initialization.  RC26
    # attempted to run ColorConverter while the window resources were still
    # being constructed on Windows and rejected every bundled scheme.  Theme
    # data uses an intentionally small, deterministic hex contract.
    foreach($hex in @($palette.Values)){if(-not(Test-PMMThemeHexColor ([string]$hex))){throw ('Invalid palette color: '+[string]$hex)}}
    foreach($state in @('Import','Analyze','Build','Deploy','Play')){
      if(-not(Test-PMMThemeHexColor ([string]$flow[$state].Progress))){throw ('Invalid ColorFlow progress color for '+$state+'.')}
      if(-not(Test-PMMThemeHexColor ([string]$flow[$state].Border))){throw ('Invalid ColorFlow border color for '+$state+'.')}
    }
    $brushes=[ordered]@{}
    if($schema -eq 'PMM_COLOR_SCHEME_V2' -and $doc.PSObject.Properties.Name -contains 'brushes' -and $doc.brushes){
      $root=(Get-Item -LiteralPath $Path).DirectoryName
      foreach($prop in $doc.brushes.PSObject.Properties){
        $key=[string]$prop.Name;$entry=$prop.Value
        $known=($palette.Contains($key) -or $key -cmatch '^ColorFlow\.(Import|Analyze|Build|Deploy|Play)\.(Progress|Border)$')
        if(-not$known){throw ('Unknown image brush key: '+$key)}
        if(-not$entry -or [string]$entry.type -ne 'image'){throw ('Unsupported brush type for '+$key+'.')}
        $source=([string]$entry.source).Replace([char]92,[char]47)
        if([string]::IsNullOrWhiteSpace($source) -or $source.StartsWith('/') -or $source -match '^[A-Za-z]:' -or $source -match '(^|/)\.\.(/|$)' -or $source -match '^(?i:https?|file):'){throw ('Unsafe image source for '+$key+'.')}
        if([IO.Path]::GetExtension($source).ToLowerInvariant() -notin @('.png','.jpg','.jpeg')){throw ('Unsupported image source type for '+$key+'.')}
        $asset=Join-Path $root $source.Replace([char]47,[IO.Path]::DirectorySeparatorChar)
        if(-not(Test-PMMPathInside $asset $root) -or -not(Test-Path -LiteralPath $asset -PathType Leaf)){throw ('Missing packaged image for '+$key+': '+$source)}
        $imageInfo=Test-PMMThemeImageFile $asset
        $expected='';try{$expected=([string]$entry.sha256).ToLowerInvariant()}catch{}
        if($expected -and ($expected -notmatch '^[0-9a-f]{64}$' -or $expected -ne [string]$imageInfo.Sha256)){throw ('Image hash mismatch for '+$key+'.')}
        $stretch='UniformToFill';try{$stretch=[string]$entry.stretch}catch{};if($stretch -notin @('None','Fill','Uniform','UniformToFill')){throw ('Invalid image stretch for '+$key+'.')}
        $alignment='Center';try{$alignment=[string]$entry.alignment}catch{};if($alignment -notin @('Center','Left','Right','Top','Bottom','TopLeft','TopRight','BottomLeft','BottomRight')){throw ('Invalid image alignment for '+$key+'.')}
        $tile='None';try{$tile=[string]$entry.tileMode}catch{};if($tile -notin @('None','Tile','FlipX','FlipY','FlipXY')){throw ('Invalid image tile mode for '+$key+'.')}
        $opacity=1.0;try{$opacity=[double]$entry.opacity}catch{throw ('Invalid image opacity for '+$key+'.')};if($opacity -lt 0 -or $opacity -gt 1){throw ('Image opacity must be between 0 and 1 for '+$key+'.')}
        $overlay='#00000000';try{$overlay=[string]$entry.overlay}catch{};if(-not(Test-PMMThemeHexColor $overlay)){throw ('Invalid image overlay color for '+$key+'.')}
        $brushes[$key]=$entry
      }
    }
    $definition=[pscustomobject]@{Id=$id;Name=$name;Schema=$schema;Base=$base;Palette=$palette;ColorFlow=$flow;Brushes=$brushes;Builtin=$false;Path=$Path;ThemeRoot=(Get-Item -LiteralPath $Path).DirectoryName}
    $contrast=Test-PMMThemeContrast $definition
    if(-not[bool]$contrast.Valid){throw ('Color-scheme contrast validation failed: '+(@($contrast.Errors)-join ' | '))}
    return $definition
  }catch{Write-PMMLog ('Invalid PMM color scheme '+$Path+': '+$_.Exception.Message);return $null}
}

function Get-PMMThemeDefinitions {
  $items=[System.Collections.Generic.List[object]]::new()
  $seen=[System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
  $bundledFiles=@(Get-PMMBundledThemeFiles)
  foreach($f in $bundledFiles){
    $t=Convert-PMMThemeJson $f.FullName
    if($t){$t|Add-Member -NotePropertyName Bundled -NotePropertyValue $true -Force;$items.Add($t);[void]$seen.Add([string]$t.Id)}
  }
  $ordered=@(
    @($items.ToArray()|Where-Object{[string]$_.Id -ieq 'pmm-crystal'})
    @($items.ToArray()|Where-Object{[string]$_.Id -ine 'pmm-crystal'}|Sort-Object Name)
  )
  $items.Clear();foreach($t in $ordered){$items.Add($t)}
  $items.Add([pscustomobject]@{Id='Night';Name=(L 'Night (legacy built-in)' 'Noche (integrado clasico)');Base='Night';Palette=(Get-PMMBaseThemePalette 'Night');ColorFlow=(Get-PMMDefaultColorFlow);Builtin=$true;Bundled=$false;Path=''})
  [void]$seen.Add('Night')
  $items.Add([pscustomobject]@{Id='Light';Name=(L 'Light' 'Claro');Base='Light';Palette=(Get-PMMBaseThemePalette 'Light');ColorFlow=(Get-PMMDefaultColorFlow);Builtin=$true;Path=''})
  [void]$seen.Add('Light')
  foreach($f in @(Get-PMMUserThemeFiles)){$t=Convert-PMMThemeJson $f.FullName;if($t -and $seen.Add([string]$t.Id)){$t|Add-Member -NotePropertyName Bundled -NotePropertyValue $false -Force;$items.Add($t)}}
  $loadedBundled=@($items.ToArray()|Where-Object{try{[bool]$_.Bundled}catch{$false}}).Count
  if($bundledFiles.Count -ne 11 -or $loadedBundled -ne 11){Write-PMMLog ('Official theme audit: expected 11, discovered '+$bundledFiles.Count+', loaded '+$loadedBundled+'. Night/Light remain emergency built-ins.')}
  return @($items.ToArray())
}

function Get-PMMSelectedThemeId {
  foreach($rb in @($Script:ThemeOptionButtons)){if($rb -and [bool]$rb.IsChecked){return [string]$rb.Tag}}
  return 'pmm-crystal'
}

function Set-PMMSelectedThemeId([string]$Id){
  if($Id -eq 'Dark'){$Id='Night'}
  $found=$false
  foreach($rb in @($Script:ThemeOptionButtons)){if($rb){$yes=([string]$rb.Tag -ieq $Id);$rb.IsChecked=$yes;if($yes){$found=$true}}}
  if(-not$found){foreach($fallback in @('pmm-crystal','Night')){foreach($rb in @($Script:ThemeOptionButtons)){if([string]$rb.Tag -ieq $fallback){$rb.IsChecked=$true;$found=$true;break}};if($found){break}}}
}

function Refresh-PMMThemeOptions([string]$Selected=''){
  $Script:PnlThemeOptions.Children.Clear();$Script:PnlUserThemeOptions.Children.Clear();$Script:ThemeOptionButtons.Clear()
  if([string]::IsNullOrWhiteSpace($Selected)){try{$Selected=[string](Get-PMMConfig).Theme}catch{$Selected='pmm-crystal'}}
  if($Selected -eq 'Dark'){$Selected='Night'}
  $official=0;$bundled=0;$legacy=0;$custom=0
  foreach($t in @(Get-PMMThemeDefinitions)){
    $rb=[System.Windows.Controls.RadioButton]::new();$rb.Content=[string]$t.Name;$rb.Tag=[string]$t.Id;$rb.GroupName='PMMColorScheme';$rb.Margin=[System.Windows.Thickness]::new(0,3,12,3);$rb.Padding=[System.Windows.Thickness]::new(2)
    $isBundled=$false;try{$isBundled=[bool]$t.Bundled}catch{}
    $isOfficial=([bool]$t.Builtin -or $isBundled)
    $rb.ToolTip=if($isOfficial){(L 'Official PMM color scheme.' 'Esquema de color oficial de PMM.')}else{[string]$t.Path}
    $rb.Add_Checked({if(-not$Script:UiSettingsRefreshing){$Script:TxtStatus.Text=L 'Color scheme changed. Press Apply changes.' 'Esquema de color cambiado. Pulsa Aplicar cambios.'}})
    $Script:ThemeOptionButtons.Add($rb)
    if($isOfficial){$official++;if($isBundled){$bundled++}else{$legacy++};[void]$Script:PnlThemeOptions.Children.Add($rb)}else{$custom++;[void]$Script:PnlUserThemeOptions.Children.Add($rb)}
  }
  Set-PMMSelectedThemeId $Selected
  $Script:TxtUserThemeEmpty.Visibility=if($custom -eq 0){[System.Windows.Visibility]::Visible}else{[System.Windows.Visibility]::Collapsed}
  $text=((L '{0} user scheme(s) in Workspace\Themes. {1} official schemes and {2} legacy palette(s) are always available.' '{0} esquema(s) del usuario en Workspace\Themes. Siempre estan disponibles {1} esquemas oficiales y {2} paleta(s) heredadas.') -f $custom,$bundled,$legacy)
  if(-not[string]::IsNullOrWhiteSpace([string]$Script:ThemeFallbackNotice)){$text+=' '+[string]$Script:ThemeFallbackNotice}
  $Script:TxtThemeInfo.Text=$text
}

function Get-PMMSoundDefinitions {
  return @(
    [pscustomobject]@{Id='None';Name=(L 'No sound' 'Sin sonido');Path='';Builtin=$true},
    [pscustomobject]@{Id='Bell';Name=(L 'Bell' 'Campana');Path=(Join-Path $Script:Root 'Resources\Sounds\PMM_bell.wav');Builtin=$true},
    [pscustomobject]@{Id='Microwave';Name=(L 'Microwave finish' 'Final de microondas');Path=(Join-Path $Script:Root 'Resources\Sounds\PMM_microwave.wav');Builtin=$true},
    [pscustomobject]@{Id='Microwave3';Name=(L '3 beeps' '3 pitidos');Path=(Join-Path $Script:Root 'Resources\Sounds\PMM_microwave_3beeps.wav');Builtin=$true},
    [pscustomobject]@{Id='Ok';Name='OK';Path=(Join-Path $Script:Root 'Resources\Sounds\PMM_ok.wav');Builtin=$true},
    [pscustomobject]@{Id='Good';Name='Good';Path=(Join-Path $Script:Root 'Resources\Sounds\PMM_good.wav');Builtin=$true},
    [pscustomobject]@{Id='Crystal';Name=(L 'Crystal chime' 'Campanilla cristalina');Path=(Join-Path $Script:Root 'Resources\Sounds\PMM_crystal.wav');Builtin=$true},
    [pscustomobject]@{Id='Alert';Name=(L 'Short alert' 'Alerta corta');Path=(Join-Path $Script:Root 'Resources\Sounds\PMM_alert.wav');Builtin=$true}
  )
}

function Get-PMMCustomSoundDefinitions {
  $rows=[System.Collections.Generic.List[object]]::new()
  foreach($f in @(Get-ChildItem -LiteralPath (Get-PMMSoundStore) -File -ErrorAction SilentlyContinue|Where-Object{$_.Extension -match '(?i)^\.(wav|mp3|wma)$'}|Sort-Object Name)){
    $rows.Add([pscustomobject]@{Id=('file:'+[string]$f.Name);Name=([IO.Path]::GetFileNameWithoutExtension($f.Name));Path=$f.FullName;Builtin=$false})
  }
  return @($rows.ToArray())
}

function Get-PMMSoundProfileDefinitions {
  return @(
    [pscustomobject]@{Id='Auto';Label=(L 'Auto - workflow finished' 'Auto - flujo terminado');Description=(L 'Played once when an automatic workflow really finishes. If Run Palworld after Deploy is enabled, it plays after Palworld is launched; otherwise after Deploy.' 'Suena una vez cuando termina realmente un flujo automatico. Si Iniciar Palworld tras Deploy esta activado, suena despues de iniciar Palworld; si no, despues de Deploy.')},
    [pscustomobject]@{Id='SemiAuto';Label=(L 'Semiauto - each AUTO step' 'Semiauto - cada paso de AUTO');Description=(L 'Optional short sound after each completed step while AUTO/SemiAUTO is still running.' 'Sonido corto opcional despues de cada paso completado mientras AUTO/SemiAUTO sigue ejecutandose.')},
    [pscustomobject]@{Id='Manual';Label=(L 'Manual - completed action' 'Manual - accion completada');Description=(L 'Played after a manually-started workflow action completes. Start Palworld by itself never plays this sound.' 'Suena cuando termina una accion del flujo iniciada manualmente. Iniciar Palworld por si solo nunca reproduce este sonido.')},
    [pscustomobject]@{Id='Attention';Label=(L 'Attention required' 'Atencion requerida');Description=(L 'Optional notification when PMM is waiting for a real user decision, such as choosing a Fix Lab output or resolving a compatibility decision.' 'Aviso opcional cuando PMM espera una decision real del usuario, como elegir una salida de Fix Lab o resolver una decision de compatibilidad.')},
    [pscustomobject]@{Id='Error';Label=(L 'Error' 'Error');Description=(L 'Short alert when PMM reports an operation error.' 'Alerta corta cuando PMM informa de un error de operacion.')}
  )
}

function Get-PMMSoundProfileConfigProperty([string]$Profile){
  switch($Profile){'Auto'{return 'SoundAuto'}'SemiAuto'{return 'SoundSemiAuto'}'Manual'{return 'SoundManual'}'Attention'{return 'SoundAttention'}'Error'{return 'SoundError'}default{return 'SoundManual'}}
}

function Get-PMMSoundProfileDefault([string]$Profile){
  switch($Profile){'Auto'{return 'Microwave'}'SemiAuto'{return 'Ok'}'Manual'{return 'Good'}'Attention'{return 'Alert'}'Error'{return 'Microwave3'}default{return 'Microwave'}}
}

function Initialize-PMMPendingSoundSelections($Config){
  $Script:PendingSoundSelections=@{}
  foreach($profile in @('Auto','SemiAuto','Manual','Attention','Error')){
    $prop=Get-PMMSoundProfileConfigProperty $profile;$value=''
    try{if($Config -and ($Config.PSObject.Properties.Name -contains $prop)){$value=[string]$Config.$prop}}catch{}
    if([string]::IsNullOrWhiteSpace($value)){$value=Get-PMMSoundProfileDefault $profile}
    # Missing imported files fall back safely instead of leaving an invisible selection.
    if($value -like 'file:*' -and [string]::IsNullOrWhiteSpace([string](Get-PMMSoundPathById $value))){$value=Get-PMMSoundProfileDefault $profile}
    $Script:PendingSoundSelections[$profile]=$value
  }
}

function Get-PMMCurrentSoundProfileId {
  try{if($Script:CmbSoundEventProfile.SelectedValue){return [string]$Script:CmbSoundEventProfile.SelectedValue}}catch{}
  return 'Auto'
}

function Get-PMMPendingSoundId([string]$Profile=''){
  if([string]::IsNullOrWhiteSpace($Profile)){$Profile=Get-PMMCurrentSoundProfileId}
  if(-not$Script:PendingSoundSelections){Initialize-PMMPendingSoundSelections (Get-PMMConfig)}
  if($Script:PendingSoundSelections.ContainsKey($Profile)){return [string]$Script:PendingSoundSelections[$Profile]}
  return (Get-PMMSoundProfileDefault $Profile)
}

function Set-PMMPendingSoundId([string]$Id,[string]$Profile=''){
  if([string]::IsNullOrWhiteSpace($Profile)){$Profile=Get-PMMCurrentSoundProfileId}
  if(-not$Script:PendingSoundSelections){Initialize-PMMPendingSoundSelections (Get-PMMConfig)}
  $Script:PendingSoundSelections[$Profile]=[string]$Id
  # Selecting a concrete Semiauto sound must not leave its independent master
  # switch silently disabled. None remains the explicit mute choice.
  if($Profile -eq 'SemiAuto' -and $Script:ChkSoundEachAutoStep){$Script:ChkSoundEachAutoStep.IsChecked=([string]$Id -ne 'None')}
  if(-not$Script:UiSettingsRefreshing){$Script:TxtStatus.Text=L 'Sound settings changed. Press Apply changes.' 'Los sonidos han cambiado. Pulsa Aplicar cambios.'}
}

function Get-PMMSelectedCustomSoundId {
  foreach($rb in @($Script:CustomSoundOptionButtons)){if($rb -and [bool]$rb.IsChecked){return [string]$rb.Tag}}
  return ''
}

function Refresh-PMMCustomSoundOptions([string]$Selected=''){
  $Script:PnlCustomSoundOptions.Children.Clear();$Script:CustomSoundOptionButtons.Clear()
  $custom=@(Get-PMMCustomSoundDefinitions)
  foreach($snd in $custom){
    $rb=[System.Windows.Controls.RadioButton]::new();$rb.Content=[string]$snd.Name;$rb.Tag=[string]$snd.Id;$rb.GroupName='PMMCustomSound';$rb.Margin=[System.Windows.Thickness]::new(0,2,12,2);$rb.Padding=[System.Windows.Thickness]::new(2);$rb.ToolTip=[string]$snd.Path
    $rb.Add_Checked({
      param($sender,$e)
      if($Script:UiSettingsRefreshing){return}
      try{$Script:RdoSoundCustom.IsChecked=$true;Set-PMMPendingSoundId ([string]$sender.Tag)}catch{}
    })
    if([string]$snd.Id -ieq [string]$Selected){$rb.IsChecked=$true}
    $Script:CustomSoundOptionButtons.Add($rb);[void]$Script:PnlCustomSoundOptions.Children.Add($rb)
  }
  $Script:RdoSoundCustom.IsEnabled=($custom.Count -gt 0)
  $Script:TxtSoundInfo.Text=((L '{0} custom sound(s) in Workspace\Sounds.' '{0} sonido(s) custom en Workspace\Sounds.') -f $custom.Count)
}

function Refresh-PMMSoundProfileUi([string]$Profile=''){
  if([string]::IsNullOrWhiteSpace($Profile)){$Profile=Get-PMMCurrentSoundProfileId}
  $defs=@(Get-PMMSoundProfileDefinitions);$desc=@($defs|Where-Object{[string]$_.Id -eq $Profile}|Select-Object -First 1)
  if($desc.Count -gt 0){$Script:TxtSoundEventDescription.Text=[string]$desc[0].Description}
  $selected=Get-PMMPendingSoundId $Profile
  $priorRefreshing=[bool]$Script:UiSettingsRefreshing;$Script:UiSettingsRefreshing=$true
  try{
    $Script:RdoSoundNone.IsChecked=($selected -eq 'None')
    $Script:RdoSoundBell.IsChecked=($selected -eq 'Bell')
    $Script:RdoSoundMicrowave.IsChecked=($selected -eq 'Microwave')
    $Script:RdoSoundMicrowave3.IsChecked=($selected -eq 'Microwave3')
    $Script:RdoSoundOk.IsChecked=($selected -eq 'Ok')
    $Script:RdoSoundGood.IsChecked=($selected -eq 'Good')
    $Script:RdoSoundCrystal.IsChecked=($selected -eq 'Crystal')
    $Script:RdoSoundAlert.IsChecked=($selected -eq 'Alert')
    $isCustom=($selected -like 'file:*');$Script:RdoSoundCustom.IsChecked=$isCustom
    Refresh-PMMCustomSoundOptions $(if($isCustom){$selected}else{''})
  }finally{$Script:UiSettingsRefreshing=$priorRefreshing}
}

function Initialize-PMMSoundSettingsUi($Config){
  Initialize-PMMPendingSoundSelections $Config
  $Script:SoundEventProfiles=@(Get-PMMSoundProfileDefinitions)
  $Script:CmbSoundEventProfile.ItemsSource=$Script:SoundEventProfiles;$Script:CmbSoundEventProfile.DisplayMemberPath='Label';$Script:CmbSoundEventProfile.SelectedValuePath='Id';$Script:CmbSoundEventProfile.SelectedValue='Auto'
  $semi=$true;$attn=$true
  try{if($Config.PSObject.Properties.Name -contains 'SoundSemiAutoEnabled'){$semi=[bool]$Config.SoundSemiAutoEnabled}}catch{}
  try{if($Config.PSObject.Properties.Name -contains 'SoundAttentionEnabled'){$attn=[bool]$Config.SoundAttentionEnabled}}catch{}
  $Script:ChkSoundEachAutoStep.IsChecked=$semi;$Script:ChkSoundAttention.IsChecked=$attn
  Refresh-PMMSoundProfileUi 'Auto'
}

function Convert-PMMThemeHexToWpf([string]$Hex) {
  if(-not(Test-PMMThemeHexColor $Hex)){throw ('Invalid theme color: '+$Hex)}
  # PMM's data contract uses #RRGGBBAA; WPF ColorConverter uses #AARRGGBB.
  if($Hex.Length -eq 9){return ('#'+$Hex.Substring(7,2)+$Hex.Substring(1,6))}
  return $Hex
}

function Set-PMMThemeBrush([string]$Key,[string]$Hex) {
  try{
    # Always replace the resource instead of mutating an existing brush.
    # WPF may freeze/share brushes once a template has consumed them; mutating
    # such an instance produces the partial-theme behaviour seen in RC15.
    # DynamicResource users are invalidated immediately when the dictionary
    # entry itself is replaced, so every tab/control resolves the new colour.
    $color=[System.Windows.Media.ColorConverter]::ConvertFromString((Convert-PMMThemeHexToWpf $Hex))
    $Window.Resources[$Key]=[System.Windows.Media.SolidColorBrush]::new($color)
  }catch{Write-PMMLog ('Theme brush warning '+$Key+': '+$_.Exception.Message)}
}

function Set-PMMThemeDefinitionBrush($Definition,[string]$Key,[string]$FallbackHex,[string]$ResourceKey='') {
  if([string]::IsNullOrWhiteSpace($ResourceKey)){$ResourceKey=$Key}
  $entry=$null
  try{if($Definition.Brushes -is [Collections.IDictionary]){$entry=$Definition.Brushes[$Key]}else{$property=$Definition.Brushes.PSObject.Properties[$Key];if($property){$entry=$property.Value}}}catch{}
  if(-not$entry){Set-PMMThemeBrush $ResourceKey $FallbackHex;return}
  try{
    $source=([string]$entry.source).Replace([char]47,[IO.Path]::DirectorySeparatorChar)
    $path=Join-Path ([string]$Definition.ThemeRoot) $source
    $info=Test-PMMThemeImageFile $path
    $stream=[IO.File]::Open($info.Path,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::Read)
    try{
      $bitmap=[System.Windows.Media.Imaging.BitmapImage]::new();$bitmap.BeginInit();$bitmap.CacheOption=[System.Windows.Media.Imaging.BitmapCacheOption]::OnLoad;$bitmap.StreamSource=$stream;$bitmap.EndInit();$bitmap.Freeze()
    }finally{$stream.Dispose()}
    $rect=[System.Windows.Rect]::new(0,0,[double]$bitmap.PixelWidth,[double]$bitmap.PixelHeight)
    $group=[System.Windows.Media.DrawingGroup]::new();[void]$group.Children.Add([System.Windows.Media.ImageDrawing]::new($bitmap,$rect))
    $overlay='#00000000';try{if(Test-PMMThemeHexColor ([string]$entry.overlay)){$overlay=[string]$entry.overlay}}catch{}
    $overlayBrush=[System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString((Convert-PMMThemeHexToWpf $overlay)))
    [void]$group.Children.Add([System.Windows.Media.GeometryDrawing]::new($overlayBrush,$null,[System.Windows.Media.RectangleGeometry]::new($rect)))
    $brush=[System.Windows.Media.DrawingBrush]::new($group)
    $stretch='UniformToFill';try{$stretch=[string]$entry.stretch}catch{}
    $brush.Stretch=switch($stretch){'None'{[System.Windows.Media.Stretch]::None};'Fill'{[System.Windows.Media.Stretch]::Fill};'Uniform'{[System.Windows.Media.Stretch]::Uniform};default{[System.Windows.Media.Stretch]::UniformToFill}}
    $alignment='Center';try{$alignment=[string]$entry.alignment}catch{}
    if($alignment -in @('Left','TopLeft','BottomLeft')){$brush.AlignmentX=[System.Windows.Media.AlignmentX]::Left}elseif($alignment -in @('Right','TopRight','BottomRight')){$brush.AlignmentX=[System.Windows.Media.AlignmentX]::Right}else{$brush.AlignmentX=[System.Windows.Media.AlignmentX]::Center}
    if($alignment -in @('Top','TopLeft','TopRight')){$brush.AlignmentY=[System.Windows.Media.AlignmentY]::Top}elseif($alignment -in @('Bottom','BottomLeft','BottomRight')){$brush.AlignmentY=[System.Windows.Media.AlignmentY]::Bottom}else{$brush.AlignmentY=[System.Windows.Media.AlignmentY]::Center}
    $tileMode='None';try{$tileMode=[string]$entry.tileMode}catch{}
    $brush.TileMode=switch($tileMode){'Tile'{[System.Windows.Media.TileMode]::Tile};'FlipX'{[System.Windows.Media.TileMode]::FlipX};'FlipY'{[System.Windows.Media.TileMode]::FlipY};'FlipXY'{[System.Windows.Media.TileMode]::FlipXY};default{[System.Windows.Media.TileMode]::None}}
    if($brush.TileMode -ne [System.Windows.Media.TileMode]::None){$brush.ViewportUnits=[System.Windows.Media.BrushMappingMode]::RelativeToBoundingBox;$brush.Viewport=[System.Windows.Rect]::new(0,0,0.25,0.25)}
    $opacity=1.0;try{$opacity=[double]$entry.opacity}catch{};$brush.Opacity=[Math]::Max(0.0,[Math]::Min(1.0,$opacity))
    $brush.Freeze();$Window.Resources[$ResourceKey]=$brush
  }catch{Write-PMMLog ('Theme image brush '+$Key+' rejected; solid fallback retained. '+$_.Exception.Message);Set-PMMThemeBrush $ResourceKey $FallbackHex}
}

function Get-PMMThemeDefinitionBrush($Definition,[string]$Key,[string]$FallbackHex) {
  $temporary='__PMM_THEME_BRUSH_'+[guid]::NewGuid().ToString('N')
  try{Set-PMMThemeDefinitionBrush $Definition $Key $FallbackHex $temporary;return $Window.Resources[$temporary]}
  finally{try{$Window.Resources.Remove($temporary)}catch{}}
}

function Apply-PMMTheme([string]$Theme='',[switch]$Force) {
  if([string]::IsNullOrWhiteSpace($Theme)){try{$Theme=[string](Get-PMMConfig).Theme}catch{$Theme='pmm-crystal'}}
  if($Theme -eq 'Dark'){$Theme='Night'}
  $requested=$Theme;$definitions=@(Get-PMMThemeDefinitions)
  $definition=@($definitions|Where-Object{[string]$_.Id -ieq $Theme}|Select-Object -First 1)
  $Script:ThemeFallbackNotice=''
  if($definition.Count -eq 0){
    $definition=@($definitions|Where-Object{[string]$_.Id -ieq 'pmm-crystal'}|Select-Object -First 1)
    if($definition.Count -gt 0){$Script:ThemeFallbackNotice=(L ('Configured scheme "'+$requested+'" is unavailable; PMM Crystal is active without changing your saved choice.') ('El esquema configurado "'+$requested+'" no esta disponible; PMM Crystal esta activo sin cambiar tu eleccion guardada.'))}
  }
  if($definition.Count -eq 0){$definition=@($definitions|Where-Object{[string]$_.Id -eq 'Night'}|Select-Object -First 1);$Script:ThemeFallbackNotice=L 'PMM Crystal is unavailable; the emergency Night palette is active.' 'PMM Crystal no esta disponible; esta activa la paleta de emergencia Noche.'}
  $resolvedId=[string]$definition[0].Id
  # An id alone is not proof that its brushes were installed. At startup the
  # selected id is known before any theme definition has been applied.
  if(-not$Force -and -not[bool]$Script:ThemePreviewActive -and $Script:ActiveThemeDefinition -and -not[string]::IsNullOrWhiteSpace([string]$Script:ActiveThemeId) -and [string]$Script:ActiveThemeId -ieq $resolvedId){return}
  Apply-PMMThemeDefinition $definition[0]
}

function Refresh-PMMThemeSelectionVisuals {
  # DataGrid cells cache their selected visual independently from the row.  A
  # theme dictionary swap therefore needs one presentation-only refresh so the
  # selected merge never keeps the previous palette until the user clicks it.
  foreach($name in @('LstMods','LstPatches','DgAnalysisAssets','DgDecisions','LstConflictAssets','LstUnsupportedAssets','LstAIHelpDiagnostics','LstAIIOSessions','LstAIIOCandidates')){
    try{
      $variable=Get-Variable -Scope Script -Name $name -ErrorAction SilentlyContinue
      if(-not$variable -or -not$variable.Value){continue}
      $control=$variable.Value
      try{$control.Items.Refresh()}catch{}
      try{$control.InvalidateVisual()}catch{}
    }catch{}
  }
}

function Apply-PMMThemeDefinition($def) {
  if(-not$def){throw 'A valid color-scheme definition is required.'}
  foreach($kv in $def.Palette.GetEnumerator()){Set-PMMThemeDefinitionBrush $def ([string]$kv.Key) ([string]$kv.Value)}
  $Script:ActiveThemeId=[string]$def.Id;$Script:ActiveThemeColorFlow=$def.ColorFlow;$Script:ActiveThemeDefinition=$def
  try{$Window.Foreground=$Window.Resources['PrimaryText'];$Window.Background=$Window.Resources['AppBackground'];$Script:TxtStatus.Foreground=$Window.Resources['PrimaryText']}catch{}
  try{$Window.InvalidateVisual();$Window.UpdateLayout()}catch{}
  try{[void]$Window.Dispatcher.BeginInvoke([System.Windows.Threading.DispatcherPriority]::Render,{Refresh-PMMThemeSelectionVisuals})}catch{}
  Write-PMMLog ('UI color scheme applied: '+[string]$def.Id)
}