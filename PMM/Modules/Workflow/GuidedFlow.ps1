# Guided workflow button colors + in-button progress.
#
# PMM derives the next useful action from state, never from the last click:
#   Import -> Analyze -> Build -> Deploy -> Play
# Only one stage is highlighted at a time. While Import/Analyze/Build/Deploy is
# running, that same highlighted button becomes its progress bar: the normal
# neutral button surface grows from left to right until the special color is
# completely consumed. Play is a terminal READY indicator and never animates.
# ---------------------------------------------------------------------------
$Script:ImportBusy=$false
$Script:ImportBusyButton=$null
$Script:BuildBusy=$false
$Script:DeployBusy=$false
$Script:GameModsFingerprint=''
$Script:LastExternalModsCheckUtc=[DateTime]::MinValue
$Script:ExternalModsTimer=$null
$Script:CancelRequested=$false
$Script:AutoPipelineActive=$false
$Script:AutoOneShotActive=$false
$Script:AutoStepInProgress=$false
$Script:AutoWorkflowTimer=$null
$Script:AutoFixLabPresentedRecipeId=''
$Script:AutoLastWorkflowKey=''
$Script:AutoReferenceStartRecipeId=''
$Script:GameReferenceProgressPercent=0
$Script:GameReferenceProgressMessage=''
$Script:GameReferenceProgressIndeterminate=$false
$Script:GameReferenceResumeAuto=$false
$Script:CompletionMediaPlayer=$null
$Script:CompletionMediaPath=''
$Script:UiSettingsRefreshing=$false

function Get-PMMSoundPathById([string]$Mode){
  switch($Mode){
    'None' { return '' }
    'Bell' { return (Join-Path $Script:Root 'Resources\Sounds\PMM_bell.wav') }
    'Microwave' { return (Join-Path $Script:Root 'Resources\Sounds\PMM_microwave.wav') }
    'Microwave3' { return (Join-Path $Script:Root 'Resources\Sounds\PMM_microwave_3beeps.wav') }
    'Ok' { return (Join-Path $Script:Root 'Resources\Sounds\PMM_ok.wav') }
    'Good' { return (Join-Path $Script:Root 'Resources\Sounds\PMM_good.wav') }
    'Crystal' { return (Join-Path $Script:Root 'Resources\Sounds\PMM_crystal.wav') }
    'Alert' { return (Join-Path $Script:Root 'Resources\Sounds\PMM_alert.wav') }
  }
  if($Mode -like 'file:*'){$name=$Mode.Substring(5);$p=Join-Path (Get-PMMSoundStore) $name;if(Test-Path -LiteralPath $p -PathType Leaf){return $p}}
  return ''
}
function Get-PMMConfiguredSoundId([string]$Profile){
  $cfg=Get-PMMConfig;$prop=Get-PMMSoundProfileConfigProperty $Profile;$value=''
  try{if($cfg.PSObject.Properties.Name -contains $prop){$value=[string]$cfg.$prop}}catch{}
  if([string]::IsNullOrWhiteSpace($value)){$value=Get-PMMSoundProfileDefault $Profile}
  return $value
}
function Play-PMMSoundId([string]$SoundId,[int]$Volume=-1){
  try{
    $path=Get-PMMSoundPathById $SoundId
    if([string]::IsNullOrWhiteSpace($path) -or -not(Test-Path -LiteralPath $path -PathType Leaf)){return}
    if($Volume -lt 0){$cfg=Get-PMMConfig;$Volume=50;try{if($cfg.PSObject.Properties.Name -contains 'CompletionVolume'){$Volume=[int]$cfg.CompletionVolume}}catch{$Volume=50}}
    $Volume=[Math]::Max(0,[Math]::Min(100,$Volume));if($Volume -le 0){return}
    if(-not$Script:CompletionMediaPlayer){$Script:CompletionMediaPlayer=[System.Windows.Media.MediaPlayer]::new()}
    try{$Script:CompletionMediaPlayer.Stop()}catch{}
    if([string]$Script:CompletionMediaPath -cne [string]$path){try{$Script:CompletionMediaPlayer.Close()}catch{};$Script:CompletionMediaPlayer.Open([System.Uri]::new([IO.Path]::GetFullPath($path)));$Script:CompletionMediaPath=[string]$path}
    $Script:CompletionMediaPlayer.Volume=[double]$Volume/100.0;$Script:CompletionMediaPlayer.Position=[TimeSpan]::Zero;$Script:CompletionMediaPlayer.Play()
  }catch{Write-PMMLog ('Sound playback warning: '+$_.Exception.Message)}
}
function Play-PMMSoundEvent([ValidateSet('Auto','SemiAuto','Manual','Attention','Error')][string]$Profile){
  try{
    $cfg=Get-PMMConfig
    if($Profile -eq 'SemiAuto'){
      $enabled=$true;try{if($cfg.PSObject.Properties.Name -contains 'SoundSemiAutoEnabled'){$enabled=[bool]$cfg.SoundSemiAutoEnabled}}catch{}
      if(-not$enabled){return}
    }
    if($Profile -eq 'Attention'){
      $enabled=$true;try{if($cfg.PSObject.Properties.Name -contains 'SoundAttentionEnabled'){$enabled=[bool]$cfg.SoundAttentionEnabled}}catch{}
      if(-not$enabled){return}
    }
    Play-PMMSoundId (Get-PMMConfiguredSoundId $Profile)
  }catch{Write-PMMLog ('Sound event warning '+$Profile+': '+$_.Exception.Message)}
}
function Notify-PMMWorkflowStepComplete {
  if([bool]$Script:AutoPipelineActive){Play-PMMSoundEvent 'SemiAuto'}else{Play-PMMSoundEvent 'Manual'}
}
function Complete-PMMAutoPipeline([string]$Message='') {
  $wasActive=[bool]$Script:AutoPipelineActive
  Stop-PMMAutoPipeline $Message
  if($wasActive){Play-PMMSoundEvent 'Auto'}
}


function Test-PMMOperationCancellationRequested { return [bool]$Script:CancelRequested }
function Reset-PMMOperationCancellation { $Script:CancelRequested=$false; Update-PMMCancelButtonState }
function Test-PMMCancellationError($ErrorRecord) {
  if(-not$ErrorRecord){return $false}
  try{if($ErrorRecord.Exception -is [System.OperationCanceledException]){return $true}}catch{}
  try{if(([string]$ErrorRecord.Exception.Message) -eq 'PMM_OPERATION_CANCELLED'){return $true}}catch{}
  return $false
}

function Get-PMMActiveProcessingOperation {
  try{if($Script:PMMWorkbench -and ($Script:PMMWorkbench.ToolLease -or $Script:PMMWorkbench.ToolHandle -or ($Script:PMMWorkbench.ToolProcess -and -not $Script:PMMWorkbench.ToolProcess.HasExited))){return 'Tool'}}catch{}
  try{if($Script:BackgroundOperationProcess -and -not$Script:BackgroundOperationProcess.HasExited){return [string]$Script:BackgroundOperationKind}}catch{}
  try{if($Script:GameReferenceProcess -and -not$Script:GameReferenceProcess.HasExited){return 'GameReference'}}catch{}
  if([bool]$Script:ImportBusy){return 'Import'}
  if([bool]$Script:DeployBusy){return 'Deploy'}
  if([bool]$Script:AnalyzeBusy){return 'Analyze'}
  if([bool]$Script:BuildBusy){return 'Build'}
  if([bool]$Script:AIIOBusy){return 'AIIO'}
  if([bool]$Script:FixLabOperationBusy){return 'FixLab'}
  return ''
}

function Request-PMMProcessingSlot([string]$RequestedOperation) {
  $active=[string](Get-PMMActiveProcessingOperation)
  if([string]::IsNullOrWhiteSpace($active)){return $true}
  $message=(L ("Processing engine busy: {0}. Wait for it to finish or press Cancel before starting {1}." -f $active,$RequestedOperation) ("Motor de procesamiento ocupado: {0}. Espera a que termine o pulsa Cancelar antes de iniciar {1}." -f $active,$RequestedOperation))
  $Script:TxtStatus.Text=$message
  try{$Script:TxtOperationProgress.Text=$message}catch{}
  try{[System.Media.SystemSounds]::Beep.Play()}catch{}
  return $false
}

function Update-PMMCancelButtonState {
  if(-not$Script:BtnCancelOperation){return}
  $workerRunning=$false
  try{$workerRunning=($Script:BackgroundOperationProcess -and -not$Script:BackgroundOperationProcess.HasExited)}catch{}
  $gameRefRunning=$false
  try{$gameRefRunning=($Script:GameReferenceProcess -and -not$Script:GameReferenceProcess.HasExited)}catch{}
  $busy=([bool]$Script:ImportBusy -or [bool]$Script:AnalyzeBusy -or [bool]$Script:BuildBusy -or [bool]$Script:DeployBusy -or [bool]$Script:AIIOBusy -or [bool]$Script:FixLabOperationBusy -or $workerRunning -or $gameRefRunning -or [bool]$Script:AutoPipelineActive)
  $Script:BtnCancelOperation.IsEnabled=$busy
}

function Stop-PMMAutoPipeline([string]$Reason='') {
  $Script:AutoPipelineActive=$false
  if($Script:BtnAutoRun){$Script:BtnAutoRun.Tag='Idle'}
  $Script:AutoOneShotActive=$false
  $Script:AutoStepInProgress=$false
  $Script:AutoFixLabPresentedRecipeId=''
  $Script:AutoLastWorkflowKey=''
  $Script:AutoReferenceStartRecipeId=''
  try{if($Script:AutoWorkflowTimer){$Script:AutoWorkflowTimer.Stop()}}catch{}
  Update-PMMCancelButtonState
  if(-not[string]::IsNullOrWhiteSpace($Reason)){
    $Script:TxtStatus.Text=$Reason
    try{$Script:TxtOperationProgress.Text=$Reason}catch{}
  }
}

function Ensure-PMMAutoWorkflowTimer {
  if($Script:AutoWorkflowTimer){return}
  # AUTO continuation is a watchdog. Actual operation completions explicitly
  # continue the pipeline, so keep this timer at Background priority to never
  # compete with tab changes, list selection, resize or other user input.
  $timer=[System.Windows.Threading.DispatcherTimer]::new([System.Windows.Threading.DispatcherPriority]::Background)
  $timer.Interval=[TimeSpan]::FromMilliseconds(2000)
  $timer.Add_Tick({
    try{Invoke-PMMAutoContinue}catch{
      Write-PMMLog ('Auto workflow error: '+$_.Exception.Message)
      Stop-PMMAutoPipeline ((L 'Auto paused: {0}' 'Auto pausado: {0}') -f $_.Exception.Message)
    }
  })
  $Script:AutoWorkflowTimer=$timer
}

function Test-PMMAutoContinuationEnabled { return ([bool]$Script:TglAutoMode.IsChecked -or [bool]$Script:AutoOneShotActive) }

function Start-PMMAutoPipeline {
  param([switch]$OneShot)
  $wasActive=[bool]$Script:AutoPipelineActive
  if($OneShot){$Script:AutoOneShotActive=$true}
  if(-not(Test-PMMAutoContinuationEnabled)){return}
  if(-not$wasActive){$Script:AutoFixLabPresentedRecipeId='';$Script:AutoLastWorkflowKey='';$Script:AutoReferenceStartRecipeId=''}
  $Script:CancelRequested=$false
  $Script:AutoPipelineActive=$true
  if($Script:BtnAutoRun){$Script:BtnAutoRun.Tag='Running'}
  Ensure-PMMAutoWorkflowTimer
  $Script:AutoWorkflowTimer.Start()
  Update-PMMCancelButtonState
}

function Get-PMMGuidePalette([ValidateSet('Import','Analyze','Build','Deploy','Play')][string]$State) {
  try{
    if($Script:ActiveThemeColorFlow -and $Script:ActiveThemeColorFlow.Contains($State)){
      $v=$Script:ActiveThemeColorFlow[$State]
      return [pscustomobject]@{Progress=[string]$v.Progress;Border=[string]$v.Border}
    }
  }catch{}
  $flow=Get-PMMDefaultColorFlow;$v=$flow[$State]
  return [pscustomobject]@{Progress=[string]$v.Progress;Border=[string]$v.Border}
}

function Get-PMMGuideBrush([ValidateSet('Import','Analyze','Build','Deploy','Play')][string]$State,[ValidateSet('Progress','Border')][string]$Part) {
  $palette=Get-PMMGuidePalette $State;$fallback=if($Part -eq 'Progress'){[string]$palette.Progress}else{[string]$palette.Border}
  if($Script:ActiveThemeDefinition){try{return (Get-PMMThemeDefinitionBrush $Script:ActiveThemeDefinition ('ColorFlow.'+$State+'.'+$Part) $fallback)}catch{}}
  return [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString((Convert-PMMThemeHexToWpf $fallback)))
}

$Script:UniversalProgressOperation=''
$Script:UniversalProgressFraction=0.0
$Script:UniversalProgressMessage=''
$Script:ProgressAnimationStates=@{}
$Script:ProgressAnimationTimer=$null

function Update-PMMUniversalProgressText([string]$Operation,[string]$Message,[bool]$Indeterminate) {
  if(-not$Script:TxtOperationProgress){return}
  $label=Get-PMMUniversalProgressLabel $Operation
  if($Indeterminate){$text=$label+'...'}else{$text=('{0} {1}%' -f $label,[int][Math]::Floor([double]$Script:PrgOperation.Value))}
  if(-not[string]::IsNullOrWhiteSpace($Message)){$text+='  -  '+$Message}
  $Script:TxtOperationProgress.Text=$text
}

function Get-PMMProgressAnimationInterval([bool]$CatchUp) {
  # Natural presentation pacing: catch-up uses 0.1-0.5 s per point, while
  # ordinary visual progress advances by one point every 0.5-2.0 s.
  if($CatchUp){return [double](Get-Random -Minimum 100 -Maximum 501)}
  return [double](Get-Random -Minimum 500 -Maximum 2001)
}

function Ensure-PMMProgressAnimationTimer {
  if($Script:ProgressAnimationTimer){if(-not$Script:ProgressAnimationTimer.IsEnabled){$Script:ProgressAnimationTimer.Start()};return}
  $timer=[System.Windows.Threading.DispatcherTimer]::new([System.Windows.Threading.DispatcherPriority]::Background)
  $timer.Interval=[TimeSpan]::FromMilliseconds(40)
  $timer.Add_Tick({
    try{
      $active=$false;$now=[DateTime]::UtcNow
      foreach($key in @($Script:ProgressAnimationStates.Keys)){
        $state=$Script:ProgressAnimationStates[$key]
        if(-not$state -or -not$state.Bar){[void]$Script:ProgressAnimationStates.Remove($key);continue}
        if([double]$state.Displayed -lt [double]$state.Target){
          $active=$true
          if(($now-[datetime]$state.LastStepUtc).TotalMilliseconds -ge [double]$state.IntervalMs){
            $state.Displayed=[Math]::Min([double]$state.Target,[double]$state.Displayed+1.0)
            $state.LastStepUtc=$now
            $catchUp=([double]$state.Displayed -lt [double]$state.CatchUpFloor)
            $state.IntervalMs=Get-PMMProgressAnimationInterval $catchUp
            $state.Bar.Value=[double]$state.Displayed
            if($key -eq 'Universal'){Update-PMMUniversalProgressText ([string]$state.Operation) ([string]$state.Message) $false}
          }
        }
      }
      if(-not$active -and $Script:ProgressAnimationTimer){$Script:ProgressAnimationTimer.Stop()}
    }catch{Write-PMMLog ('Progress animation warning: '+$_.Exception.Message)}
  })
  $Script:ProgressAnimationTimer=$timer
  $timer.Start()
}

function Set-PMMSmoothedProgressBar {
  param(
    $Bar,
    [Parameter(Mandatory=$true)][string]$Key,
    [double]$TargetPercent=0.0,
    [string]$Operation='',
    [string]$Message='',
    [switch]$Indeterminate
  )
  if(-not$Bar){return 0.0}
  $Bar.Minimum=0;$Bar.Maximum=100;$Bar.IsIndeterminate=[bool]$Indeterminate
  if($Indeterminate){
    [void]$Script:ProgressAnimationStates.Remove($Key)
    # Every indeterminate phase is a new real operation boundary. Clear stale
    # presentation so the first known target begins visually at zero.
    $Bar.Value=0
    return 0.0
  }
  $target=[Math]::Floor([Math]::Max(0.0,[Math]::Min(100.0,$TargetPercent)))
  if(-not [Windows.SystemParameters]::ClientAreaAnimation){
    [void]$Script:ProgressAnimationStates.Remove($Key);$Bar.Value=$target
    if($Key -eq 'Universal'){Update-PMMUniversalProgressText $Operation $Message $false}
    return $target
  }
  # Completion remains an exact boundary. Once the worker proves 100%, do not
  # leave the previous operation visually busy while the workflow moves on.
  if($target -ge 100.0){
    [void]$Script:ProgressAnimationStates.Remove($Key)
    $Bar.Value=100.0
    if($Key -eq 'Universal'){Update-PMMUniversalProgressText $Operation $Message $false}
    return 100.0
  }

  $state=$null;if($Script:ProgressAnimationStates.ContainsKey($Key)){$state=$Script:ProgressAnimationStates[$Key]}
  if(-not$state -or ([string]$state.Operation -ne $Operation -and -not[string]::IsNullOrWhiteSpace($Operation))){
    # A new real operation always starts at zero. The current worker report is
    # a hard ceiling, never a value the animation may exceed.
    $state=[pscustomobject]@{
      Bar=$Bar;Displayed=0.0;Target=[double]$target;CatchUpFloor=0.0
      IntervalMs=(Get-PMMProgressAnimationInterval $false);LastStepUtc=[DateTime]::UtcNow
      Operation=$Operation;Message=$Message
    }
    $Script:ProgressAnimationStates[$Key]=$state
  }else{
    $priorTarget=[double]$state.Target
    # Within one operation, noisy/stale reports may not move the presentation
    # backwards. A true new operation is handled by reset/indeterminate or by
    # an Operation identity change above.
    if($target -lt $priorTarget){$target=$priorTarget}
    if($target -gt $priorTarget){
      # The old worker target is now a proven floor. If presentation lagged
      # behind it, catch up quickly (0.1-0.5 s/point), then return to the slow
      # 0.5-2.0 s/point pace toward the new worker ceiling.
      $state.CatchUpFloor=[Math]::Max([double]$state.CatchUpFloor,$priorTarget)
      $state.Target=[double]$target
      $state.LastStepUtc=[DateTime]::UtcNow
      $state.IntervalMs=Get-PMMProgressAnimationInterval ([double]$state.Displayed -lt [double]$state.CatchUpFloor)
    }else{
      $state.Target=[double]$target
    }
    $state.Operation=$Operation;$state.Message=$Message;$state.Bar=$Bar
  }

  $Bar.Value=[double]$state.Displayed
  if([double]$state.Displayed -lt [double]$state.Target){Ensure-PMMProgressAnimationTimer}
  if($Key -eq 'Universal'){Update-PMMUniversalProgressText $Operation $Message $false}
  return [double]$state.Displayed
}

function Reset-PMMSmoothedProgressBar([string]$Key,$Bar) {
  [void]$Script:ProgressAnimationStates.Remove($Key)
  if($Bar){$Bar.IsIndeterminate=$false;$Bar.Value=0}
}

function Get-PMMUniversalProgressColor([string]$Operation) {
  if($Operation -in @('Import','Analyze','Build','Deploy')){try{return [string](Get-PMMGuidePalette $Operation).Border}catch{}}
  switch($Operation){'AIIO'{return '#7C3AED'}'FixLab'{return '#D97706'}default{return '#64748B'}}
}

function Get-PMMUniversalProgressLabel([string]$Operation) {
  switch($Operation){
    'Import'  { return (L 'Importing' 'Importando') }
    'Analyze' { return (L 'Analyzing' 'Analizando') }
    'Build'   { return (L 'Merging' 'Fusionando') }
    'Deploy'  { return (L 'Deploying' 'Desplegando') }
    'AIIO'    { return 'AIIO' }
    'FixLab'  { return (L 'Repairing' 'Reparando') }
    default   { return $(if([string]::IsNullOrWhiteSpace($Operation)){L 'Ready' 'Listo'}else{$Operation}) }
  }
}

function Set-PMMUniversalProgress {
  param(
    [Parameter(Mandatory=$true)][string]$Operation,
    [double]$Fraction=0.0,
    [string]$Message='',
    [switch]$Indeterminate
  )
  if(-not$Script:PrgOperation -or -not$Script:TxtOperationProgress){return}
  $fraction=[Math]::Max(0.0,[Math]::Min(1.0,$Fraction))
  $Script:UniversalProgressOperation=$Operation
  $Script:UniversalProgressFraction=$fraction
  $Script:UniversalProgressMessage=$Message
  $Script:PrgOperation.Visibility=[System.Windows.Visibility]::Visible
  $Script:PrgOperation.IsIndeterminate=[bool]$Indeterminate
  [void](Set-PMMSmoothedProgressBar $Script:PrgOperation 'Universal' (100.0*$fraction) -Operation $Operation -Message $Message -Indeterminate:$Indeterminate)
  try{$Script:PrgOperation.Foreground=[System.Windows.Media.BrushConverter]::new().ConvertFromString((Get-PMMUniversalProgressColor $Operation))}catch{}
  Update-PMMUniversalProgressText $Operation $Message ([bool]$Indeterminate)
}

function Set-PMMOperationResult([string]$Operation,[string]$Message) {
  Set-PMMUniversalProgress -Operation $Operation -Fraction 1.0 -Message $Message
  if(-not[string]::IsNullOrWhiteSpace($Message)){$Script:TxtStatus.Text=$Message}
}

function Set-PMMOperationFailure([string]$Operation,[string]$Message) {
  Set-PMMUniversalProgress -Operation $Operation -Fraction 1.0 -Message $Message
  [void]$Script:ProgressAnimationStates.Remove('Universal')
  $Script:PrgOperation.IsIndeterminate=$false;$Script:PrgOperation.Value=100
  try{$Script:PrgOperation.Foreground=[System.Windows.Media.BrushConverter]::new().ConvertFromString('#DC2626')}catch{}
  $Script:TxtOperationProgress.Text=((Get-PMMUniversalProgressLabel $Operation)+' - '+(L 'failed' 'fallo')+'  -  '+$Message)
  $Script:TxtStatus.Text=$Message
}

function Clear-PMMWorkflowButtonVisual($Button) {
  if(-not$Button){return}
  try{$Button.ClearValue([System.Windows.Controls.Control]::BackgroundProperty)}catch{}
  try{$Button.ClearValue([System.Windows.Controls.Control]::ForegroundProperty)}catch{}
  try{$Button.ClearValue([System.Windows.Controls.Control]::BorderBrushProperty)}catch{}
  try{$Button.ClearValue([System.Windows.UIElement]::OpacityProperty)}catch{}
}

function Set-PMMWorkflowButtonProgress {
  param(
    $Button,
    [Parameter(Mandatory=$true)][ValidateSet('Import','Analyze','Build','Deploy')][string]$State,
    [double]$Fraction=0.0,
    [string]$Message='',
    [switch]$Indeterminate
  )
  if(-not$Button){return}
  # Indeterminate work starts fully highlighted. Once real progress is known,
  # the neutral surface consumes the highlight from left to right.
  $p=if($Indeterminate){0.0}else{[Math]::Max(0.0,[Math]::Min(1.0,$Fraction))}
  $normalBrush=$Window.Resources['CardAltBackground'];$specialBrush=Get-PMMGuideBrush $State 'Progress'
  $unit=[System.Windows.Rect]::new(0,0,1,1);$group=[System.Windows.Media.DrawingGroup]::new();$group.Children.Add([System.Windows.Media.GeometryDrawing]::new($normalBrush,$null,[System.Windows.Media.RectangleGeometry]::new($unit)))
  if($p -lt 0.999){$remaining=[System.Windows.Rect]::new($p,0,1-$p,1);$group.Children.Add([System.Windows.Media.GeometryDrawing]::new($specialBrush,$null,[System.Windows.Media.RectangleGeometry]::new($remaining)))}
  $brush=[System.Windows.Media.DrawingBrush]::new($group);$brush.Stretch=[System.Windows.Media.Stretch]::Fill
  $Button.Background=$brush
  try{$Button.Foreground=$Window.Resources['PrimaryText']}catch{$Button.Foreground=[System.Windows.Media.BrushConverter]::new().ConvertFromString('#111827')}
  $Button.BorderBrush=Get-PMMGuideBrush $State 'Border'
  $Button.Opacity=1.0
  if(-not[string]::IsNullOrWhiteSpace($Message)){$Script:TxtStatus.Text=$Message}
  try{[System.Windows.Forms.Application]::DoEvents()}catch{}
}

function Set-PMMGuideButtonStyle($Button,[ValidateSet('Default','Import','Analyze','Build','Deploy','Play')][string]$State='Default') {
  if(-not$Button){return}
  Clear-PMMWorkflowButtonVisual $Button
  try{$Button.Style=$Window.FindResource('DefaultButton')}catch{}
  if($State -eq 'Default'){return}
  try{
    $Button.Background=Get-PMMGuideBrush $State 'Border'
    $Button.BorderBrush=Get-PMMGuideBrush $State 'Border'
    $Button.Foreground=[System.Windows.Media.Brushes]::White
    $Button.FontWeight=[System.Windows.FontWeights]::SemiBold
  }catch{Write-PMMLog ('Could not apply guided button colors '+$State+': '+$_.Exception.Message)}
}

function Reset-PMMGuidedActionStyles {
  $grRunning=$false;try{$grRunning=($Script:GameReferenceProcess -and -not$Script:GameReferenceProcess.HasExited)}catch{}
  foreach($button in @($Script:BtnDetectGame,$Script:BtnImport,$Script:BtnImportGameMods,$Script:BtnScan,$Script:BtnBuild,$Script:BtnDeploy,$Script:BtnPlay,$Script:BtnFixLabBuildReference,$Script:BtnFixLabRepair,$Script:BtnFixLabApplyBuilt)){
    if($grRunning -and $button -eq $Script:BtnFixLabBuildReference){continue}
    Set-PMMGuideButtonStyle $button 'Default'
  }
  if($grRunning){
    $fraction=[double]$Script:GameReferenceProgressPercent/100.0
    Set-PMMWorkflowButtonProgress $Script:BtnFixLabBuildReference 'Build' $fraction ([string]$Script:GameReferenceProgressMessage) -Indeterminate:([bool]$Script:GameReferenceProgressIndeterminate)
  }
}

# ---------------------------------------------------------------------------
# Required-action guidance.
# The color remains until the state changes. The small popup is intentionally
# ephemeral (5 s by default) and is shown at most once for an unchanged action.
# ---------------------------------------------------------------------------
$Script:RequiredActionSignature=''
$Script:RequiredActionDismissedSignature=''
$Script:RequiredActionTarget=$null
$Script:RequiredActionPopup=$null
$Script:RequiredActionTimer=$null
$Script:LastAttentionSoundKey=''

function Close-PMMRequiredActionPopup([switch]$Dismiss) {
  try{if($Script:RequiredActionTimer){$Script:RequiredActionTimer.Stop()}}catch{}
  $Script:RequiredActionTimer=$null
  try{if($Script:RequiredActionPopup){$Script:RequiredActionPopup.IsOpen=$false}}catch{}
  $Script:RequiredActionPopup=$null
  if($Dismiss -and -not[string]::IsNullOrWhiteSpace([string]$Script:RequiredActionSignature)){$Script:RequiredActionDismissedSignature=[string]$Script:RequiredActionSignature}
}

function Clear-PMMRequiredActionTargetVisual {
  $target=$Script:RequiredActionTarget
  if(-not$target){return}
  $normal=@($Script:BtnDetectGame,$Script:BtnImport,$Script:BtnImportGameMods,$Script:BtnScan,$Script:BtnBuild,$Script:BtnDeploy,$Script:BtnPlay,$Script:BtnFixLabBuildReference,$Script:BtnFixLabRepair,$Script:BtnFixLabApplyBuilt)
  if($target -notin $normal){
    try{$target.ClearValue([System.Windows.Controls.Control]::BorderBrushProperty)}catch{}
    try{$target.ClearValue([System.Windows.Controls.Control]::BorderThicknessProperty)}catch{}
  }
}

function Clear-PMMRequiredAction {
  Close-PMMRequiredActionPopup
  Clear-PMMRequiredActionTargetVisual
  $Script:RequiredActionTarget=$null
  $Script:RequiredActionSignature=''
  $Script:LastAttentionSoundKey=''
}

function Get-PMMActionHintSeconds {
  try{
    $cfg=Get-PMMConfig
    $v=[int]$cfg.ActionHintSeconds
    if($v -eq -1 -or ($v -ge 0 -and $v -le 120)){return $v}
  }catch{}
  return 5
}

function Set-PMMRequiredAction {
  param($Target,[string]$Key,[string]$Detail='')
  if(-not$Target -or [string]::IsNullOrWhiteSpace($Key)){Clear-PMMRequiredAction;return}

  if($Script:RequiredActionTarget -ne $Target){
    Clear-PMMRequiredActionTargetVisual
    $Script:RequiredActionTarget=$Target
  }
  $normal=@($Script:BtnDetectGame,$Script:BtnImport,$Script:BtnImportGameMods,$Script:BtnScan,$Script:BtnBuild,$Script:BtnDeploy,$Script:BtnPlay,$Script:BtnFixLabBuildReference,$Script:BtnFixLabRepair,$Script:BtnFixLabApplyBuilt)
  if($Target -notin $normal){
    try{$Target.BorderBrush=[System.Windows.Media.BrushConverter]::new().ConvertFromString('#F97316')}catch{}
    try{$Target.BorderThickness=[System.Windows.Thickness]::new(3)}catch{}
  }

  # While AUTO is actively moving, keep the color cue but do not distract
  # with a popup. If AUTO pauses, the same action will then show the hint.
  $humanDecisionRequired=([string]$Key -like 'Flow:FixLabVariant*' -or [string]$Key -like 'Flow:ResolveDecisions*')
  if([bool]$Script:AutoPipelineActive -and -not$humanDecisionRequired){Close-PMMRequiredActionPopup;$Script:RequiredActionSignature='';return}

  $sig=[string]$Key
  if($sig -ceq [string]$Script:RequiredActionSignature){return}
  Close-PMMRequiredActionPopup
  $Script:RequiredActionSignature=$sig
  $Script:RequiredActionDismissedSignature=''
  if($humanDecisionRequired){
    $attentionKey=([string]$sig -replace ':(Tab|Combo)$','')
    if([string]$attentionKey -cne [string]$Script:LastAttentionSoundKey){try{Play-PMMSoundEvent 'Attention'}catch{};$Script:LastAttentionSoundKey=$attentionKey}
  }

  $seconds=Get-PMMActionHintSeconds
  if($seconds -eq 0){return}

  try{
    $popup=[System.Windows.Controls.Primitives.Popup]::new()
    $popup.PlacementTarget=$Target
    $popup.Placement=[System.Windows.Controls.Primitives.PlacementMode]::Top
    $popup.VerticalOffset=-6
    $popup.AllowsTransparency=$true
    $popup.StaysOpen=$true
    $popup.PopupAnimation=[System.Windows.Controls.Primitives.PopupAnimation]::Fade

    $border=[System.Windows.Controls.Border]::new()
    $isFixLabChoice=([string]$Key -like 'Flow:FixLabVariant*')
    $popupBackgroundKey=if($isFixLabChoice){'DecisionNoticeBackground'}else{'NoticeBackground'}
    $popupBorderKey=if($isFixLabChoice){'DecisionNoticeBorder'}else{'NoticeBorder'}
    $popupHeadingKey=if($isFixLabChoice){'DecisionNoticeHeading'}else{'AccentHeadingAmber'}
    $border.Background=$Window.Resources[$popupBackgroundKey]
    $border.BorderBrush=$Window.Resources[$popupBorderKey]
    $border.BorderThickness=[System.Windows.Thickness]::new(1)
    $border.CornerRadius=[System.Windows.CornerRadius]::new(7)
    $border.Padding=[System.Windows.Thickness]::new(9,6,6,6)

    $grid=[System.Windows.Controls.Grid]::new()
    $col1=[System.Windows.Controls.ColumnDefinition]::new();$col1.Width=[System.Windows.GridLength]::new(1,[System.Windows.GridUnitType]::Star)
    $col2=[System.Windows.Controls.ColumnDefinition]::new();$col2.Width=[System.Windows.GridLength]::Auto
    [void]$grid.ColumnDefinitions.Add($col1);[void]$grid.ColumnDefinitions.Add($col2)

    $stack=[System.Windows.Controls.StackPanel]::new()
    $title=[System.Windows.Controls.TextBlock]::new();$title.Text=L 'Action required' 'Acción requerida';$title.FontWeight=[System.Windows.FontWeights]::SemiBold;$title.Foreground=$Window.Resources[$popupHeadingKey]
    [void]$stack.Children.Add($title)
    if(-not[string]::IsNullOrWhiteSpace($Detail)){$body=[System.Windows.Controls.TextBlock]::new();$body.Text=$Detail;$body.TextWrapping=[System.Windows.TextWrapping]::Wrap;$body.MaxWidth=330;$body.Margin=[System.Windows.Thickness]::new(0,2,8,0);$body.Foreground=$Window.Resources['PrimaryText'];[void]$stack.Children.Add($body)}
    [System.Windows.Controls.Grid]::SetColumn($stack,0);[void]$grid.Children.Add($stack)

    $close=[System.Windows.Controls.Button]::new();$close.Content='X';$close.Width=24;$close.Height=24;$close.Padding=[System.Windows.Thickness]::new(0);$close.Margin=[System.Windows.Thickness]::new(6,0,0,0);$close.VerticalAlignment=[System.Windows.VerticalAlignment]::Top
    $close.Add_Click({Close-PMMRequiredActionPopup -Dismiss})
    [System.Windows.Controls.Grid]::SetColumn($close,1);[void]$grid.Children.Add($close)
    $border.Child=$grid;$popup.Child=$border
    $Script:RequiredActionPopup=$popup;$popup.IsOpen=$true

    if($seconds -gt 0){
      $timer=[System.Windows.Threading.DispatcherTimer]::new();$timer.Interval=[TimeSpan]::FromSeconds($seconds)
      $timer.Add_Tick({Close-PMMRequiredActionPopup -Dismiss})
      $Script:RequiredActionTimer=$timer;$timer.Start()
    }
  }catch{Write-PMMLog ('Action-required hint popup failed: '+$_.Exception.Message)}
}

# Fix Lab workflow guidance is resolved exclusively by Get-PMMWorkflowState.

function Get-PMMImportGuidanceTarget {
  <#
  Import is recommended only when it can actually reconcile something safely.

  - Empty library: recommend importing from ~mods when source PAKs exist there,
    otherwise recommend normal file Import.
  - Non-empty library: recommend Import ~mods only for a game source PAK that
    is not represented by either the library or PMM's last deployment record,
    or when PMM can prove a previously deployed/library-identical PAK was
    changed externally in the game folder.

  If the PMM library itself advanced after Deploy, the old game copy is stale:
  Analyze/Deploy is the next step, never Import. PMM merge PAKs are ignored.
  #>
  $libraryFiles=@(Get-PMMAllLibrarySourcePakFiles)
  $libraryByName=@{}
  foreach($file in $libraryFiles){
    $name=[string]$file.Name
    if(-not[string]::IsNullOrWhiteSpace($name) -and -not$libraryByName.ContainsKey($name.ToLowerInvariant())){
      $libraryByName[$name.ToLowerInvariant()]=$file
    }
  }

  $state=Read-PMMDeploymentState
  $stateByName=@{}
  $stateDeployedUtc=$null
  if($state){
    try{if($state.PSObject.Properties.Name -contains 'Deployed'){$stateDeployedUtc=([datetime]$state.Deployed).ToUniversalTime()}}catch{}
    if($state.PSObject.Properties.Name -contains 'SourceMods'){
      foreach($item in @($state.SourceMods)){
        $name=[string]$item.Name
        if(-not[string]::IsNullOrWhiteSpace($name)){$stateByName[$name.ToLowerInvariant()]=$item}
      }
    }
  }

  $gameSourcePaks=@()
  try{
    $gameMods=Get-GameModsPath
    if(-not[string]::IsNullOrWhiteSpace([string]$gameMods) -and (Test-Path -LiteralPath $gameMods -PathType Container)){
      $gameSourcePaks=@(Get-ChildItem -LiteralPath $gameMods -Filter *.pak -File -ErrorAction SilentlyContinue |
        Where-Object{$_.Name -notlike 'zzzzzzzzzz_PMM_Merge_*_P.pak'})
    }
  }catch{$gameSourcePaks=@()}

  if($libraryFiles.Count -eq 0){
    if($gameSourcePaks.Count -gt 0){return 'GameMods'}
    return 'Files'
  }

  foreach($gamePak in $gameSourcePaks){
    $key=([string]$gamePak.Name).ToLowerInvariant()
    $libraryPak=if($libraryByName.ContainsKey($key)){$libraryByName[$key]}else{$null}
    $stateItem=if($stateByName.ContainsKey($key)){$stateByName[$key]}else{$null}

    if(-not$libraryPak){
      # A source previously managed by PMM but intentionally removed from the
      # library is waiting for Deploy removal, not re-import.
      if($stateItem){continue}
      return 'GameMods'
    }

    if($stateItem){
      $libraryHash=Get-PMMCachedFileHash $libraryPak
      $stateHash=[string]$stateItem.Hash
      if($stateHash -eq $libraryHash){
        if([int64]$libraryPak.Length -ne [int64]$gamePak.Length){return 'GameMods'}
        # Same-size replacements need a hash only when metadata proves the game
        # file changed after PMM recorded the deployment. Normal refresh never
        # hashes the whole deployed library.
        if($stateDeployedUtc -and $gamePak.LastWriteTimeUtc -gt $stateDeployedUtc.AddSeconds(2)){
          $gameHash=Get-PMMCachedFileHash $gamePak
          if($gameHash -ne $libraryHash){return 'GameMods'}
        }
      }
      continue
    }

    # No PMM deployment record: if the game copy is newer than the library,
    # treat a different-size file as an external install immediately. For a
    # same-size replacement, hash only this one candidate after metadata moved;
    # the low-frequency metadata heartbeat never hashes the full mod set.
    if($gamePak.LastWriteTimeUtc -gt $libraryPak.LastWriteTimeUtc.AddSeconds(2)){
      if([int64]$libraryPak.Length -ne [int64]$gamePak.Length){return 'GameMods'}
      $libraryHash=Get-PMMCachedFileHash $libraryPak
      $gameHash=Get-PMMCachedFileHash $gamePak
      if($gameHash -ne $libraryHash){return 'GameMods'}
    }
  }
  return ''
}

function Get-PMMGameModsFingerprint {
  <#
  Cheap external-change detector: names, sizes and LastWriteTime only. No PAK
  hashes are computed here, so even a 70+ GB mod set can be checked safely at
  the low-frequency active-window heartbeat.
  The expensive state comparison runs only when this metadata fingerprint moves.
  #>
  try{
    $gameMods=Get-GameModsPath
    if([string]::IsNullOrWhiteSpace([string]$gameMods)){return 'NO_GAME_PATH'}
    if(-not(Test-Path -LiteralPath $gameMods -PathType Container)){return ('MISSING|'+[string]$gameMods)}
    $parts=@(Get-ChildItem -LiteralPath $gameMods -Filter *.pak -File -ErrorAction SilentlyContinue |
      Sort-Object Name |
      ForEach-Object{('{0}|{1}|{2}' -f ([string]$_.Name).ToLowerInvariant(),[int64]$_.Length,[int64]$_.LastWriteTimeUtc.Ticks)})
    return (([string]$gameMods).ToLowerInvariant()+'::'+($parts -join ';'))
  }catch{return ('ERROR|'+$_.Exception.GetType().FullName)}
}

function Test-PMMDesiredDeploymentCurrent {
  param([array]$SourceMods=@())
  try{
    if($SourceMods.Count -eq 0){return $false}
    $state=Read-PMMDeploymentState
    if(-not$state){return $false}

    $context=Get-PMMDeploymentContext
    if(-not$context){return $false}
    if([string]$state.SourceSignature -ne [string]$context.Signature){return $false}

    $expectedPatch=$context.Patch
    $statePatch=$null
    if($state.PSObject.Properties.Name -contains 'Patch'){$statePatch=$state.Patch}
    if($expectedPatch){
      if(-not$statePatch){return $false}
      if([string]$statePatch.Name -ine [string]$expectedPatch.Name){return $false}
      if([string]$statePatch.Hash -ne [string]$expectedPatch.Hash){return $false}
    }elseif($statePatch){
      return $false
    }

    $suppressed=[System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach($name in @($context.Suppressed)){if($name){[void]$suppressed.Add([string]$name)}}

    $actual=@{}
    if($state.PSObject.Properties.Name -contains 'SourceMods'){
      foreach($item in @($state.SourceMods)){
        $name=[string]$item.Name
        if([string]::IsNullOrWhiteSpace($name)){continue}
        $actual[$name.ToLowerInvariant()]=$item
      }
    }
    if($actual.Count -ne $context.Active.Count){return $false}

    $gameMods=[string]$context.GameMods
    if([string]::IsNullOrWhiteSpace($gameMods) -or -not(Test-Path -LiteralPath $gameMods -PathType Container)){return $false}

    foreach($mod in @($context.Active)){
      $key=([string]$mod.Name).ToLowerInvariant()
      if(-not$actual.ContainsKey($key)){return $false}
      $item=$actual[$key]
      if([string]$item.Hash -ne [string]$mod.Hash){return $false}
      $expectedDeployed=-not$suppressed.Contains([string]$mod.Name)
      $actualDeployed=$true
      if($item.PSObject.Properties.Name -contains 'Deployed'){$actualDeployed=[bool]$item.Deployed}
      if($actualDeployed -ne $expectedDeployed){return $false}

      # Verify the real game folder cheaply, not only deployment-state.json.
      $gamePath=Join-Path $gameMods ([string]$mod.Name)
      if($expectedDeployed){
        if(-not(Test-Path -LiteralPath $gamePath -PathType Leaf)){return $false}
        try{
          $gameFile=Get-Item -LiteralPath $gamePath -ErrorAction Stop
          $sourcePath=[string]$mod.Path
          if(-not[string]::IsNullOrWhiteSpace($sourcePath) -and (Test-Path -LiteralPath $sourcePath -PathType Leaf)){
            $sourceFile=Get-Item -LiteralPath $sourcePath -ErrorAction Stop
            if([int64]$gameFile.Length -ne [int64]$sourceFile.Length){return $false}
          }
        }catch{return $false}
      }elseif(Test-Path -LiteralPath $gamePath -PathType Leaf){
        return $false
      }
    }

    $gameMergePaks=@(Get-ChildItem -LiteralPath $gameMods -Filter 'zzzzzzzzzz_PMM_Merge_*_P.pak' -File -ErrorAction SilentlyContinue)
    if($expectedPatch){
      $expectedGamePatch=Join-Path $gameMods ([string]$expectedPatch.Name)
      if(-not(Test-Path -LiteralPath $expectedGamePatch -PathType Leaf)){return $false}
      if(@($gameMergePaks|Where-Object{[string]$_.Name -ine [string]$expectedPatch.Name}).Count -gt 0){return $false}
      try{
        if($expectedPatch.PSObject.Properties.Name -contains 'Path' -and (Test-Path -LiteralPath ([string]$expectedPatch.Path) -PathType Leaf)){
          if([int64](Get-Item -LiteralPath $expectedGamePatch).Length -ne [int64](Get-Item -LiteralPath ([string]$expectedPatch.Path)).Length){return $false}
        }
      }catch{return $false}
    }elseif($gameMergePaks.Count -gt 0){
      return $false
    }

    return $true
  }catch{
    # If PMM cannot prove the desired deployment is current, Deploy remains the
    # final recommended step rather than claiming the game is ready.
    return $false
  }
}

function Test-PMMGameInstallationReady {
  try{
    $cfg=Get-PMMConfig
    if(-not$cfg.GamePath){return $false}
    return (-not[string]::IsNullOrWhiteSpace([string](Resolve-PalworldRoot ([string]$cfg.GamePath))))
  }catch{return $false}
}

function Get-PMMFixLabRequirementLightweight {
  # Prefer the loaded recipe engine. This respects per-hash Ignore rules and
  # avoids maintaining two different Fix Lab interpretations.
  if($Script:FixLabLoaded){
    try{
      $live=@(Get-PMMFixLabDiscoveryCandidates)
      $Script:FixLabCachedAttentionCandidates=@($live)
      if($live.Count -gt 0){$c=$live[0];return [pscustomobject]@{Loaded=$true;Candidate=$c;Recipe=(Get-PMMFixLabRecipe ([string]$c.RecipeId));Matches=@($c.Sources)}}
      return $null
    }catch{}
  }

  # Before the tab is loaded, match only the compact Stable recipe signatures.
  # This keeps Fix Lab lazy/failure-isolated while still letting the global
  # ColorFlow know that a repair must precede Analyze.
  try{
    $recipeFile=Join-Path (Get-PMMPath 'CKLFixLabStable') 'fix-recipes.json'
    if(-not(Test-Path -LiteralPath $recipeFile -PathType Leaf)){return $null}
    $doc=Get-Content -LiteralPath $recipeFile -Raw|ConvertFrom-Json
    $mods=@(Get-LibraryMods)
    if($mods.Count -eq 0){return $null}
    $ignored=@{}
    $ignorePath=Join-PMMPath 'State' 'fixlab-ignored-sources.json'
    if(Test-Path -LiteralPath $ignorePath -PathType Leaf){
      try{
        $ignoreDoc=Get-Content -LiteralPath $ignorePath -Raw|ConvertFrom-Json
        $ignoreRows=@($ignoreDoc)
        if($ignoreDoc -and ($ignoreDoc.PSObject.Properties.Name -contains 'Sources')){$ignoreRows=@($ignoreDoc.Sources)}
        foreach($r in $ignoreRows){if($r -and -not[string]::IsNullOrWhiteSpace([string]$r.Hash)){$ignored[([string]$r.Hash).ToLowerInvariant()]=$true}}
      }catch{}
    }
    foreach($recipe in @($doc.recipes)){
      if(-not($recipe.PSObject.Properties.Name -contains 'sourcePolicy') -or -not$recipe.sourcePolicy -or -not$recipe.sourcePolicy.automaticDetection){continue}
      $required=@($recipe.sourcePolicy.automaticDetection.requiredPakSha256|ForEach-Object{([string]$_).ToLowerInvariant()}|Where-Object{$_})
      if($required.Count -eq 0){continue}
      $matches=@($mods|Where-Object{$h=([string]$_.Hash).ToLowerInvariant();$required -contains $h -and -not$ignored.ContainsKey($h)})
      if($matches.Count -gt 0){return [pscustomobject]@{Loaded=$false;Candidate=$null;Recipe=$recipe;Matches=$matches}}
    }
  }catch{Write-PMMLog ('Lightweight Fix Lab routing check failed: '+$_.Exception.Message)}
  return $null
}

function Get-PMMWorkflowState {
  # ONE state machine is authoritative for both ColorFlow and AUTO.
  # Detect -> Import -> [Fix Lab: reference -> choice -> repair -> deploy] -> Analyze -> Build -> Deploy -> Play(optional)
  if(-not(Test-PMMGameInstallationReady)){
    return [pscustomobject]@{Action='Detect';Target=$Script:BtnDetectGame;Palette='Import';Key='Flow:Detect';Detail=(L 'Detect the Palworld installation before importing or deploying mods.' 'Detecta la instalacion de Palworld antes de importar o desplegar mods.')}
  }

  $sourceMods=@(Get-LibraryMods)
  $importTarget=Get-PMMImportGuidanceTarget
  if($importTarget -eq 'GameMods' -and $Script:BtnImportGameMods.IsEnabled){return [pscustomobject]@{Action='ImportGameMods';Target=$Script:BtnImportGameMods;Palette='Import';Key='Flow:ImportGameMods';Detail=(L 'Import the mods currently found in Palworld ~mods.' 'Importa los mods que estan actualmente en ~mods de Palworld.')}}
  if($importTarget -eq 'Files' -and $Script:BtnImport.IsEnabled){return [pscustomobject]@{Action='ImportFiles';Target=$Script:BtnImport;Palette='Import';Key='Flow:ImportFiles';Detail=(L 'Import mod files or a folder to begin.' 'Importa archivos de mod o una carpeta para comenzar.')}}

  # A supported legacy repair always precedes normal Analyze.
  # Game Reference is a dependency, not a navigation step: AUTO starts the
  # existing background builder directly before it ever asks the UI to open
  # Fix Lab.  This lets the user browse Settings/Fix Lab freely while the same
  # shared progress state updates both tabs.
  $fix=Get-PMMFixLabRequirementLightweight
  if($fix){
    $recipe=$fix.Recipe
    if(-not$recipe -and $Script:FixLabLoaded -and $fix.Candidate){$recipe=Get-PMMFixLabRecipe ([string]$fix.Candidate.RecipeId)}
    if(-not$recipe){
      return [pscustomobject]@{Action='FixLabOpen';Target=$Script:TabFixLab;Palette='Build';Key='Flow:FixLabOpenRecipe';Detail=(L 'A supported legacy mod was detected. Open Fix Lab to load its repair recipe.' 'Se detecto un mod antiguo compatible. Abre Fix Lab para cargar su receta de reparacion.')}
    }

    $variants=@($recipe.variants)
    $selected=[string]$Script:FixLabSelectedVariantId
    if(-not[string]::IsNullOrWhiteSpace($selected) -and @($variants|Where-Object{[string]$_.id -ieq $selected}).Count -eq 0){$selected='';$Script:FixLabSelectedVariantId=''}
    if($variants.Count -eq 1 -and [string]::IsNullOrWhiteSpace($selected)){$selected=[string]$variants[0].id;$Script:FixLabSelectedVariantId=$selected}

    $requiresCurrent=$false;try{$requiresCurrent=[bool]$recipe.referencePolicy.currentRequired}catch{}
    if($requiresCurrent){
      $gr=Get-PMMGameReferenceState
      if([string]$gr.Status -ne 'Current'){
        $grRunning=$false;try{$grRunning=($Script:GameReferenceProcess -and -not$Script:GameReferenceProcess.HasExited)}catch{}
        if(-not$grRunning){
          return [pscustomobject]@{Action='FixLabGameReference';Target=$Script:BtnFixLabBuildReference;Palette='Build';Key='Flow:FixLabGameReference';Detail=(L 'Create the current Game Reference in the background. You can keep using PMM while it builds.' 'Crea la Game Reference actual en segundo plano. Puedes seguir usando PMM mientras se crea.')}
        }

        # The reference is already building.  If the recipe has multiple
        # outputs, expose the human choice concurrently; never force the user
        # back to the Fix Lab tab after they navigate elsewhere.
        if(-not $Script:FixLabLoaded){
          return [pscustomobject]@{Action='FixLabOpen';Target=$Script:TabFixLab;Palette='Build';Key='Flow:FixLabPrepareChoice';Detail=(L 'Game Reference is building. Fix Lab can be opened now to choose the repair output while it continues.' 'Game Reference se esta creando. Puedes abrir Fix Lab ahora para elegir la salida mientras continua.')}
        }

        $candidate=$fix.Candidate
        if(-not$candidate){$candidate=Get-PMMFixLabSelectedCandidate}
        if(-not$candidate){
          return [pscustomobject]@{Action='FixLabOpen';Target=$Script:TabFixLab;Palette='Build';Key='Flow:FixLabRefresh';Detail=(L 'Game Reference is building. Open Fix Lab to refresh the detected repair case.' 'Game Reference se esta creando. Abre Fix Lab para actualizar el caso detectado.')}
        }
        $Script:FixLabSelectedRecipeId=[string]$candidate.RecipeId
        if([string]::IsNullOrWhiteSpace($selected) -and $variants.Count -gt 1){
          $choiceOnTab=($Script:MainTabs.SelectedItem -ne $Script:TabFixLab)
          $choiceTarget=if($choiceOnTab){$Script:TabFixLab}else{$Script:CmbFixLabVariant}
          $choiceKey=if($choiceOnTab){'Flow:FixLabVariantWhileReference:'+[string]$candidate.RecipeId+':Tab'}else{'Flow:FixLabVariantWhileReference:'+[string]$candidate.RecipeId+':Combo'}
          return [pscustomobject]@{Action='FixLabChooseVariant';Target=$choiceTarget;Palette='Build';Key=$choiceKey;Detail=((L 'Game Reference is building in the background. Choose one of {0} repair outputs now; AUTO will continue as soon as the reference is ready.' 'Game Reference se esta creando en segundo plano. Elige ahora una de las {0} salidas de reparacion; AUTO continuara en cuanto la referencia este lista.') -f $variants.Count)}
        }
        return [pscustomobject]@{Action='FixLabWaitReference';Target=$null;Palette='';Key='Flow:FixLabWaitReference';Detail=(L 'Game Reference is building in the background. No further action is required yet.' 'Game Reference se esta creando en segundo plano. Todavia no se requiere ninguna otra accion.')}
      }
    }

    # The dependency is ready. Load Fix Lab lazily only now (or while the
    # reference is building for the concurrent output choice). AUTO initializes
    # the module without changing the selected tab.
    if(-not $Script:FixLabLoaded){
      return [pscustomobject]@{Action='FixLabOpen';Target=$Script:TabFixLab;Palette='Build';Key='Flow:FixLabOpen';Detail=(L 'Game Reference is ready. Open Fix Lab to continue the detected repair.' 'Game Reference esta lista. Abre Fix Lab para continuar la reparacion detectada.')}
    }

    $candidate=$fix.Candidate
    if(-not$candidate){$candidate=Get-PMMFixLabSelectedCandidate}
    if(-not$candidate){return [pscustomobject]@{Action='FixLabOpen';Target=$Script:TabFixLab;Palette='Build';Key='Flow:FixLabRefreshReady';Detail=(L 'Refresh Fix Lab to select the detected repair case.' 'Actualiza Fix Lab para seleccionar el caso detectado.')}}
    $Script:FixLabSelectedRecipeId=[string]$candidate.RecipeId
    $recipe=Get-PMMFixLabRecipe ([string]$candidate.RecipeId)
    if(-not$recipe){return [pscustomobject]@{Action='FixLabBlocked';Target=$Script:TabFixLab;Palette='Build';Key='Flow:FixLabRecipeMissing';Detail=(L 'The exact repair recipe could not be loaded.' 'No se pudo cargar la receta exacta de reparacion.')}}

    $variants=@($recipe.variants)
    $selected=[string]$Script:FixLabSelectedVariantId
    if(-not[string]::IsNullOrWhiteSpace($selected) -and @($variants|Where-Object{[string]$_.id -ieq $selected}).Count -eq 0){$selected='';$Script:FixLabSelectedVariantId=''}
    if($variants.Count -eq 1 -and [string]::IsNullOrWhiteSpace($selected)){$selected=[string]$variants[0].id;$Script:FixLabSelectedVariantId=$selected;try{$Script:CmbFixLabVariant.SelectedValue=$selected}catch{}}

    if([string]::IsNullOrWhiteSpace($selected)){
      $choiceOnTab=($Script:MainTabs.SelectedItem -ne $Script:TabFixLab)
      $choiceTarget=if($choiceOnTab){$Script:TabFixLab}else{$Script:CmbFixLabVariant}
      $choiceKey=if($choiceOnTab){'Flow:FixLabVariant:'+[string]$candidate.RecipeId+':Tab'}else{'Flow:FixLabVariant:'+[string]$candidate.RecipeId+':Combo'}
      return [pscustomobject]@{Action='FixLabChooseVariant';Target=$choiceTarget;Palette='Build';Key=$choiceKey;Detail=((L 'Choose one of {0} repair outputs.' 'Elige una de las {0} salidas de reparacion.') -f $variants.Count)}
    }

    $built=@(Get-PMMFixLabBuiltOutputs|Where-Object{[string]$_.RecipeId -ieq [string]$candidate.RecipeId -and [string]$_.VariantId -ieq $selected}|Sort-Object BuiltUtc -Descending|Select-Object -First 1)[0]
    if(-not$built){
      $ready=Get-PMMFixLabCandidateBuildState $candidate $selected
      if(-not[bool]$ready.Ready){return [pscustomobject]@{Action='FixLabBlocked';Target=$Script:BtnFixLabRepair;Palette='Build';Key=('Flow:FixLabBlocked:'+$selected);Detail=[string]$ready.Reason}}
      return [pscustomobject]@{Action='FixLabRepair';Target=$Script:BtnFixLabRepair;Palette='Build';Key=('Flow:FixLabRepair:'+$selected);Detail=(L 'Build and validate the selected repair in the background.' 'Construye y valida la reparacion seleccionada en segundo plano.')}
    }
    $Script:FixLabSelectedBuildId=[string]$built.BuildId
    if(($built.PSObject.Properties.Name -contains 'Applied') -and [bool]$built.Applied){
      # Applied is terminal for Fix Lab. Normal Analyze is now authoritative.
    }elseif(-not(Test-PMMFixLabBuiltDeployAllowed $built)){
      $note=Get-PMMFixLabBuiltDeploymentNote $built;if([string]::IsNullOrWhiteSpace($note)){$note=L 'The built engine milestone is not deployable.' 'El hito construido del motor no se puede desplegar.'}
      return [pscustomobject]@{Action='FixLabBlocked';Target=$Script:LstFixLabBuiltFixes;Palette='Build';Key=('Flow:FixLabBuiltBlocked:'+[string]$built.BuildId);Detail=$note}
    }else{
      return [pscustomobject]@{Action='FixLabDeploy';Target=$Script:BtnFixLabApplyBuilt;Palette='Deploy';Key=('Flow:FixLabDeploy:'+[string]$built.BuildId);Detail=(L 'Deploy the repaired PAK and archive the legacy source. PMM will continue to Analyze.' 'Despliega el PAK reparado y archiva la fuente antigua. PMM continuara con Analyze.')}
    }
  }

  $analysisCurrent=$false
  if($sourceMods.Count -gt 0){try{$analysisCurrent=Test-PMMMergePlanCurrent}catch{$analysisCurrent=$false}}
  if($analysisCurrent){
    try{
      $decisionPlan=Read-PMMMergePlan
      $pendingDecisions=if($decisionPlan){@($decisionPlan.Rows|Where-Object{-not(Test-PMMDecisionRowResolved $_)}).Count}else{0}
      if($pendingDecisions -gt 0){return [pscustomobject]@{Action='ResolveDecisions';Target=$Script:ExpConflicts;Palette='Analyze';Key='Flow:ResolveDecisions';Detail=((L 'Resolve {0} compatibility decision(s) before Build can continue.' 'Resuelve {0} decision(es) de compatibilidad antes de continuar con Build.') -f $pendingDecisions)}}
    }catch{}
  }
  if($sourceMods.Count -gt 0 -and -not$analysisCurrent -and $Script:BtnScan.IsEnabled){return [pscustomobject]@{Action='Analyze';Target=$Script:BtnScan;Palette='Analyze';Key='Flow:Analyze';Detail=(L 'Analyze the current repaired/imported mod list.' 'Analiza la lista actual de mods importados/reparados.')}}
  if($analysisCurrent -and $Script:BtnBuild.IsEnabled){return [pscustomobject]@{Action='Build';Target=$Script:BtnBuild;Palette='Build';Key='Flow:Build';Detail=(L 'Build the compatibility overlay for this analysis.' 'Construye el overlay de compatibilidad para este analisis.')}}

  $deploymentCurrent=$false
  if($sourceMods.Count -gt 0){$deploymentCurrent=Test-PMMDesiredDeploymentCurrent $sourceMods}
  if($Script:BtnDeploy.IsEnabled -and -not$deploymentCurrent){return [pscustomobject]@{Action='Deploy';Target=$Script:BtnDeploy;Palette='Deploy';Key='Flow:Deploy';Detail=(L 'Deploy the selected source mods and compatibility patch.' 'Despliega los mods fuente y el parche de compatibilidad seleccionados.')}}
  # A current deployment always ends on the Play-ready state. The checkbox
  # controls automatic launch only; it must not hide the final guided action.
  if($sourceMods.Count -gt 0 -and $analysisCurrent -and $deploymentCurrent -and $Script:BtnPlay.IsEnabled){return [pscustomobject]@{Action='Play';Target=$Script:BtnPlay;Palette='Play';Key='Flow:Play';Detail=(L 'Everything is ready to play.' 'Ya está todo listo para jugar.')}}
  return [pscustomobject]@{Action='None';Target=$null;Palette='';Key='Flow:None';Detail=''}
}

function Get-PMMNextWorkflowAction { return [string](Get-PMMWorkflowState).Action }

function Update-PMMGuidedActionState {
  if($Script:ImportBusy -or $Script:AnalyzeBusy -or $Script:BuildBusy -or $Script:DeployBusy -or $Script:AIIOBusy -or $Script:FixLabOperationBusy -or ($Script:BackgroundOperationProcess -and -not$Script:BackgroundOperationProcess.HasExited)){return}
  Reset-PMMGuidedActionStyles
  $state=Get-PMMWorkflowState
  $target=$state.Target
  switch([string]$state.Action){
    'Detect' { if($Script:BtnDetectGame.Visibility -eq [System.Windows.Visibility]::Visible){Set-PMMGuideButtonStyle $Script:BtnDetectGame 'Import'} }
    'ImportGameMods' { Set-PMMGuideButtonStyle $Script:BtnImportGameMods 'Import' }
    'ImportFiles' { Set-PMMGuideButtonStyle $Script:BtnImport 'Import' }
    'FixLabGameReference' { Set-PMMGuideButtonStyle $Script:BtnFixLabBuildReference 'Build' }
    'FixLabWaitReference' { Clear-PMMRequiredAction;return }
    'FixLabRepair' { Set-PMMGuideButtonStyle $Script:BtnFixLabRepair 'Build' }
    'FixLabDeploy' { Set-PMMGuideButtonStyle $Script:BtnFixLabApplyBuilt 'Deploy' }
    'Analyze' { Set-PMMGuideButtonStyle $Script:BtnScan 'Analyze' }
    'Build' { Set-PMMGuideButtonStyle $Script:BtnBuild 'Build' }
    'Deploy' { Set-PMMGuideButtonStyle $Script:BtnDeploy 'Deploy' }
    'Play' { Set-PMMGuideButtonStyle $Script:BtnPlay 'Play' }
  }
  if([string]$state.Action -eq 'None'){Clear-PMMRequiredAction;return}
  if([string]$state.Action -eq 'Play'){
    # Play is an optional terminal READY state, never a required action. Keep
    # only the persistent color cue and suppress the action-required bubble.
    Close-PMMRequiredActionPopup
    $Script:RequiredActionTarget=$Script:BtnPlay
    $Script:RequiredActionSignature='Flow:PlayReady'
    $Script:LastAttentionSoundKey=''
    return
  }
  Set-PMMRequiredAction $target ([string]$state.Key) ([string]$state.Detail)
}

function Get-PMMAutoAnalysisBlocker {
  $plan=$null
  try{if(Test-PMMMergePlanCurrent){$plan=Read-PMMMergePlan}}catch{}
  if(-not$plan){return ''}
  $unsupported=@($plan.Assets|Where-Object{[string]$_.Mode -eq 'Unsupported'}).Count
  if($unsupported -gt 0){return ((L 'Auto paused: Analyze found {0} unsupported shared asset(s). Review them or create an AI handoff.' 'Auto pausado: Analyze encontro {0} asset(s) compartido(s) no soportado(s). Revisalos o crea un handoff para IA.') -f $unsupported)}
  $packageChoices=@($plan.Assets|Where-Object{[string]$_.Mode -eq 'PackageChoice'}).Count
  if($packageChoices -gt 0){return ((L 'Auto paused: {0} package choice(s) require a user decision and re-analysis.' 'Auto pausado: {0} eleccion(es) de paquete requieren una decision del usuario y volver a analizar.') -f $packageChoices)}
  $unresolved=@($plan.Rows|Where-Object{[string]::IsNullOrWhiteSpace([string]$_.SelectedChoice)}).Count
  if($unresolved -gt 0){return ((L 'Auto paused: {0} conflict decision(s) still require a user choice.' 'Auto pausado: {0} decision(es) de conflicto aun requieren una eleccion del usuario.') -f $unresolved)}
  return ''
}

function Test-PMMAutoBuildRequiresConfirmation {
  try{
    $plan=Read-PMMMergePlan
    if(-not$plan){return $false}
    return (@($plan.Assets|Where-Object{[string]$_.Mode -eq 'ManualSolutionExperimental'}).Count -gt 0)
  }catch{return $false}
}

# Legacy AUTO/Fix Lab routing removed in RC6. Get-PMMWorkflowState is the single workflow authority.

function Ensure-PMMAutoFixLabGameReference {
  # AUTO prerequisite preflight.  The Settings button is the canonical Game
  # Reference command: manual Windows testing already proved that this path
  # launches the worker and updates BOTH Settings and Fix Lab progress bars.
  # AUTO therefore raises that exact command instead of maintaining a second
  # launch path that can drift from the manual implementation.
  if(-not$Script:AutoPipelineActive){return $false}
  $fix=$null
  try{$fix=Get-PMMFixLabRequirementLightweight}catch{Write-PMMLog ('AUTO Fix Lab preflight discovery warning: '+$_.Exception.Message)}
  if(-not$fix -or -not$fix.Recipe){return $false}

  $recipe=$fix.Recipe
  $requiresCurrent=$false;try{$requiresCurrent=[bool]$recipe.referencePolicy.currentRequired}catch{}
  if(-not$requiresCurrent){return $false}

  $gr=$null;try{$gr=Get-PMMGameReferenceState}catch{}
  if($gr -and [string]$gr.Status -eq 'Current'){
    $Script:AutoReferenceStartRecipeId=''
    return $false
  }

  $running=$false;try{$running=($Script:GameReferenceProcess -and -not$Script:GameReferenceProcess.HasExited)}catch{}
  if($running){return $true}

  # Do not cancel AUTO for a transient engine owner. The watchdog will call
  # this preflight again. This is especially important immediately after an
  # Import, when the library may already expose the Fix Lab candidate a few
  # milliseconds before Import releases its busy flag.
  $active=[string](Get-PMMActiveProcessingOperation)
  if(-not[string]::IsNullOrWhiteSpace($active)){
    if($active -ne 'GameReference'){Write-PMMLog ('AUTO Game Reference waiting for processing slot; active='+$active)}
    return $true
  }

  $recipeId=[string]$recipe.id
  try{
    $Script:TxtStatus.Text=L 'AUTO: starting the required Game Reference in the background...' 'AUTO: iniciando la Game Reference necesaria en segundo plano...'
    Write-PMMLog ('AUTO invoking canonical Game Reference command before Fix Lab navigation for recipe '+$recipeId)

    # This is intentionally the same routed click used by a human in Settings.
    # It performs config validation, arms the same completion callback and then
    # calls Start-PMMGameReferenceBuild.  No alternate AUTO worker path exists.
    Invoke-PMMButtonClick $Script:BtnBuildGameReference

    $started=$false
    try{$started=($Script:GameReferenceProcess -and -not$Script:GameReferenceProcess.HasExited)}catch{}
    if($started){
      $Script:AutoReferenceStartRecipeId=$recipeId
      Write-PMMLog ('AUTO Game Reference worker confirmed running for recipe '+$recipeId)
      try{Update-PMMGuidedActionState}catch{}
      return $true
    }

    # A processing-slot race can still happen between the check above and the
    # button handler. Keep AUTO alive; retry on the next watchdog tick.
    Write-PMMLog ('AUTO canonical Game Reference command returned without a running worker; will retry.')
    return $true
  }catch{
    Stop-PMMAutoPipeline ((L 'Auto paused: Game Reference could not be started: ' 'Auto pausado: no se pudo iniciar Game Reference: ')+$_.Exception.Message)
    return $true
  }
}

function Invoke-PMMButtonClick($Button) {
  if(-not$Button){return}
  $args=[System.Windows.RoutedEventArgs]::new([System.Windows.Controls.Button]::ClickEvent)
  $Button.RaiseEvent($args)
}

function Invoke-PMMAutoContinue {
  if(-not$Script:AutoPipelineActive){return}
  if(-not(Test-PMMAutoContinuationEnabled)){Stop-PMMAutoPipeline;return}
  if($Script:CancelRequested){Stop-PMMAutoPipeline (L 'Automatic workflow cancelled.' 'Flujo automatico cancelado.');return}

  # Dependency preflight is deliberately BEFORE the generic busy return.  It
  # will not start a competing worker, but it means AUTO can observe a newly
  # detected Fix Lab case immediately and begin Game Reference on the first
  # dispatcher turn after the previous operation actually releases its slot.
  [void](Ensure-PMMAutoFixLabGameReference)

  if($Script:AutoStepInProgress -or $Script:ImportBusy -or $Script:AnalyzeBusy -or $Script:BuildBusy -or $Script:DeployBusy -or $Script:AIIOBusy -or $Script:FixLabOperationBusy){return}
  try{if($Script:BackgroundOperationProcess -and -not$Script:BackgroundOperationProcess.HasExited){return}}catch{}
  $gameReferenceRunning=$false
  try{$gameReferenceRunning=($Script:GameReferenceProcess -and -not$Script:GameReferenceProcess.HasExited)}catch{}
  $state=Get-PMMWorkflowState
  $action=[string]$state.Action
  # A running Game Reference blocks processing actions, but it must NOT block
  # Fix Lab navigation/choice state. This is what lets the user choose an
  # output while the reference is still being built.
  if($gameReferenceRunning -and $action -notin @('FixLabOpen','FixLabChooseVariant','FixLabWaitReference')){return}
  if($action -eq 'Build'){
    $blocker=Get-PMMAutoAnalysisBlocker
    if(-not[string]::IsNullOrWhiteSpace($blocker)){Stop-PMMAutoPipeline $blocker;return}
    if(Test-PMMAutoBuildRequiresConfirmation){Stop-PMMAutoPipeline (L 'Auto paused: this Build contains an experimental AI/manual solution and needs explicit confirmation.' 'Auto pausado: este Build contiene una solucion experimental de IA/manual y necesita confirmacion explicita.');return}
  }

  # AUTO presents a detected Fix Lab case exactly once per repair case/run.
  # After that first navigation the user owns the tabs: changing to Settings
  # while Game Reference runs will never be undone by the AUTO watchdog.
  if($action -like 'FixLab*'){
    $routeRecipeId=''
    try{
      $routeFix=Get-PMMFixLabRequirementLightweight
      if($routeFix){
        if($routeFix.Recipe){$routeRecipeId=[string]$routeFix.Recipe.id}
        elseif($routeFix.Candidate){$routeRecipeId=[string]$routeFix.Candidate.RecipeId}
      }
    }catch{}
    if(-not[string]::IsNullOrWhiteSpace($routeRecipeId) -and [string]$Script:AutoFixLabPresentedRecipeId -ine $routeRecipeId){
      try{
        if(-not $Script:FixLabLoaded){[void](Initialize-PMMFixLabFeature)}
        if($Script:FixLabLoaded){
          Refresh-PMMFixLabUI
          $Script:MainTabs.SelectedItem=$Script:TabFixLab
          $Script:AutoFixLabPresentedRecipeId=$routeRecipeId
          Write-PMMLog ('AUTO presented Fix Lab once for recipe '+$routeRecipeId)
        }
      }catch{Write-PMMLog ('AUTO initial Fix Lab presentation warning: '+$_.Exception.Message)}
    }
  }

  if([string]$state.Key -cne [string]$Script:AutoLastWorkflowKey){
    $Script:AutoLastWorkflowKey=[string]$state.Key
    Write-PMMLog ('AUTO workflow state: '+[string]$state.Action+' | '+[string]$state.Key)
  }

  $Script:AutoStepInProgress=$true
  try{
    switch($action){
      'Detect' {
        Reset-PMMOperationCancellation
        Invoke-PMMButtonClick $Script:BtnDetectGame
        if((Get-PMMNextWorkflowAction) -eq 'Detect'){Stop-PMMAutoPipeline (L 'Auto paused: choose a valid Steam or Palworld folder to continue.' 'Auto pausado: elige una carpeta valida de Steam o Palworld para continuar.')}
      }
      'ImportGameMods' { Reset-PMMOperationCancellation;Invoke-PMMButtonClick $Script:BtnImportGameMods }
      'ImportFiles' { Stop-PMMAutoPipeline (L 'Auto paused: choose the mod files/folder to import, then press AUTO again (or enable SemiAUTO).' 'Auto pausado: elige los archivos/carpeta de mods que quieres importar y despues pulsa AUTO de nuevo (o activa SemiAUTO).') }
      'FixLabOpen' {
        if(-not $Script:FixLabLoaded){[void](Initialize-PMMFixLabFeature)}
        if($Script:FixLabLoaded){Refresh-PMMFixLabUI}
        # Initial navigation is handled once above. Repeated watchdog passes
        # only refresh state and never steal the user's current tab.
        try{Update-PMMGuidedActionState}catch{}
      }
      'FixLabGameReference' {
        # Normally the preflight above has already launched it. If a transient
        # slot race delayed launch, keep AUTO alive and let the watchdog retry.
        [void](Ensure-PMMAutoFixLabGameReference)
      }
      'FixLabChooseVariant' {
        $Script:TxtStatus.Text=[string]$state.Detail
        try{Update-PMMGuidedActionState}catch{}
        return
      }
      'FixLabWaitReference' { return }
      'FixLabRepair' { Reset-PMMOperationCancellation;Invoke-PMMButtonClick $Script:BtnFixLabRepair }
      'FixLabDeploy' { Reset-PMMOperationCancellation;Invoke-PMMButtonClick $Script:BtnFixLabApplyBuilt }
      'FixLabBlocked' { Stop-PMMAutoPipeline ([string]$state.Detail) }
      'ResolveDecisions' {$Script:ExpConflicts.IsExpanded=$true;$Script:TxtStatus.Text=[string]$state.Detail;try{Update-PMMGuidedActionState}catch{};return}
      'Analyze' { Reset-PMMOperationCancellation;Invoke-PMMButtonClick $Script:BtnScan }
      'Build' { Reset-PMMOperationCancellation;Invoke-PMMButtonClick $Script:BtnBuild }
      'Deploy' { Reset-PMMOperationCancellation;Invoke-PMMButtonClick $Script:BtnDeploy }
      'Play' {
        if([bool]$Script:ChkAutoPlay.IsChecked){Invoke-PMMButtonClick $Script:BtnPlay;Complete-PMMAutoPipeline}
        else{Complete-PMMAutoPipeline (L 'Automatic workflow complete. Palworld launch is optional.' 'Flujo automatico terminado. Iniciar Palworld es opcional.')}
      }
      default { Complete-PMMAutoPipeline (L 'Automatic workflow is complete.' 'El flujo automatico ha terminado.') }
    }
  }finally{$Script:AutoStepInProgress=$false}
}

function Check-PMMExternalModChanges([switch]$Force) {
  try{
    $now=[DateTime]::UtcNow
    if(-not$Force -and $Script:LastExternalModsCheckUtc -ne [DateTime]::MinValue -and ($now-$Script:LastExternalModsCheckUtc).TotalSeconds -lt 60){return}
    $Script:LastExternalModsCheckUtc=$now
    $fingerprint=Get-PMMGameModsFingerprint
    $changed=($fingerprint -cne [string]$Script:GameModsFingerprint)
    $Script:GameModsFingerprint=$fingerprint
    if($Force -or $changed){Update-PMMGuidedActionState}
  }catch{Write-PMMLog ('External ~mods state check failed: '+$_.Exception.Message)}
}


