function Set-PMMAnalyzeProgress {
  param([int]$Current,[int]$Total,[string]$Message,[switch]$Indeterminate)
  $fraction=if($Total -gt 0){[double]$Current/[double]$Total}else{0.0}
  Set-PMMWorkflowButtonProgress $Script:BtnScan 'Analyze' $fraction $Message -Indeterminate:$Indeterminate
  Set-PMMUniversalProgress -Operation 'Analyze' -Fraction $fraction -Message $Message -Indeterminate:$Indeterminate
}

$Script:AnalyzeBusy=$false
function Update-PMMAnalyzeIndicator {
  if($Script:AnalyzeBusy){return}
  # The analysis workspace itself already shows whether the plan is current.
  # Do not duplicate that state with a permanent progress bar.
  $Script:PrgAnalyze.IsIndeterminate=$false
  $Script:PrgAnalyze.Visibility=[System.Windows.Visibility]::Collapsed
  Reset-PMMSmoothedProgressBar 'AIIO' $Script:PrgAnalyze
  $Script:TxtAnalyzeProgress.Text=''
}

function Set-PMMAnalyzeBusy([bool]$Busy) {
  $Script:AnalyzeBusy=$Busy
  Update-PMMCancelButtonState
  $enabled=-not$Busy
  $Script:BtnScan.IsEnabled=$true
  $Script:BtnScan.IsHitTestVisible=$enabled
  $Script:BtnScan.Focusable=$enabled
  $Script:BtnImport.IsEnabled=$enabled
  $Script:BtnImportGameMods.IsEnabled=$enabled
  $Script:LstMods.IsEnabled=$enabled
  if($Busy){
    Update-PMMLibraryButtons
    Reset-PMMGuidedActionStyles
    $Script:BtnPriorityUp.IsEnabled=$false;$Script:BtnPriorityDown.IsEnabled=$false;$Script:BtnDeleteMod.IsEnabled=$false
    Set-PMMWorkflowButtonProgress $Script:BtnScan 'Analyze' 0.0 (L 'Starting Analyze...' 'Iniciando Analizar...') -Indeterminate
  }else{
    Clear-PMMWorkflowButtonVisual $Script:BtnScan
    $Script:BtnScan.IsHitTestVisible=$true
    $Script:BtnScan.Focusable=$true
    Update-PMMLibraryButtons
    Update-PMMAnalyzeIndicator
    Update-BuildButtonState
    Update-PMMGuidedActionState
  }
}

function Set-PMMBuildProgress {
  param([int]$Current,[int]$Total,[string]$Message,[switch]$Indeterminate)
  $fraction=if($Total -gt 0){[double]$Current/[double]$Total}else{0.0}
  Set-PMMWorkflowButtonProgress $Script:BtnBuild 'Build' $fraction $Message -Indeterminate:$Indeterminate
  Set-PMMUniversalProgress -Operation 'Build' -Fraction $fraction -Message $Message -Indeterminate:$Indeterminate
}

function Set-PMMBuildBusy([bool]$Busy) {
  $Script:BuildBusy=$Busy
  Update-PMMCancelButtonState
  if($Busy){
    Reset-PMMGuidedActionStyles
    $Script:BtnBuild.IsEnabled=$true
    $Script:BtnBuild.IsHitTestVisible=$false
    $Script:BtnBuild.Focusable=$false
    $Script:BtnDeploy.IsEnabled=$false
    $Script:BtnScan.IsEnabled=$false
    $Script:BtnImport.IsEnabled=$false
    $Script:BtnImportGameMods.IsEnabled=$false
    $Script:LstMods.IsEnabled=$false
    Update-PMMLibraryButtons
    $Script:BtnPriorityUp.IsEnabled=$false;$Script:BtnPriorityDown.IsEnabled=$false;$Script:BtnDeleteMod.IsEnabled=$false
    Set-PMMWorkflowButtonProgress $Script:BtnBuild 'Build' 0.0 (L 'Preparing build...' 'Preparando build...') -Indeterminate
  }else{
    Clear-PMMWorkflowButtonVisual $Script:BtnBuild
    $Script:BtnBuild.IsHitTestVisible=$true
    $Script:BtnBuild.Focusable=$true
    $Script:BtnScan.IsEnabled=$true
    $Script:BtnImport.IsEnabled=$true
    $Script:BtnImportGameMods.IsEnabled=$true
    $Script:LstMods.IsEnabled=$true
    $Script:PrgBuild.IsIndeterminate=$false
    $Script:PrgBuild.Visibility=[System.Windows.Visibility]::Collapsed
    $Script:PrgBuild.Value=0
    $Script:TxtBuildProgress.Text=''
    Update-PMMLibraryButtons
    Update-BuildButtonState
    Update-PMMGuidedActionState
  }
}

function Set-PMMDeployProgress {
  param([int]$Current,[int]$Total,[string]$Message,[switch]$Indeterminate)
  $fraction=if($Total -gt 0){[double]$Current/[double]$Total}else{0.0}
  Set-PMMWorkflowButtonProgress $Script:BtnDeploy 'Deploy' $fraction $Message -Indeterminate:$Indeterminate
  Set-PMMUniversalProgress -Operation 'Deploy' -Fraction $fraction -Message $Message -Indeterminate:$Indeterminate
}

function Set-PMMDeployBusy([bool]$Busy) {
  $Script:DeployBusy=$Busy
  Update-PMMCancelButtonState
  if($Busy){
    Reset-PMMGuidedActionStyles
    $Script:BtnBuild.IsEnabled=$false
    $Script:BtnDeploy.IsEnabled=$true
    $Script:BtnDeploy.IsHitTestVisible=$false
    $Script:BtnDeploy.Focusable=$false
    $Script:BtnScan.IsEnabled=$false
    $Script:BtnImport.IsEnabled=$false
    $Script:BtnImportGameMods.IsEnabled=$false
    $Script:BtnPlay.IsEnabled=$false
    $Script:LstMods.IsEnabled=$false
    Update-PMMLibraryButtons
    $Script:BtnPriorityUp.IsEnabled=$false;$Script:BtnPriorityDown.IsEnabled=$false;$Script:BtnDeleteMod.IsEnabled=$false
    Set-PMMWorkflowButtonProgress $Script:BtnDeploy 'Deploy' 0.0 (L 'Preparing deployment...' 'Preparando despliegue...') -Indeterminate
  }else{
    Clear-PMMWorkflowButtonVisual $Script:BtnDeploy
    $Script:BtnDeploy.IsHitTestVisible=$true
    $Script:BtnDeploy.Focusable=$true
    $Script:BtnPlay.IsEnabled=$true
    $Script:BtnScan.IsEnabled=$true
    $Script:BtnImport.IsEnabled=$true
    $Script:BtnImportGameMods.IsEnabled=$true
    $Script:LstMods.IsEnabled=$true
    Update-PMMLibraryButtons
    Update-BuildButtonState
    Update-PMMGuidedActionState
  }
}

function Set-PMMImportProgress {
  param($Button,[double]$Fraction,[string]$Message,[switch]$Indeterminate)
  Set-PMMWorkflowButtonProgress $Button 'Import' $Fraction $Message -Indeterminate:$Indeterminate
  Set-PMMUniversalProgress -Operation 'Import' -Fraction $Fraction -Message $Message -Indeterminate:$Indeterminate
}

function Set-PMMImportBusy($Button,[bool]$Busy) {
  $Script:ImportBusy=$Busy
  Update-PMMCancelButtonState
  if($Busy){
    $Script:ImportBusyButton=$Button
    Reset-PMMGuidedActionStyles
    $Script:BtnImport.IsEnabled=($Button -eq $Script:BtnImport)
    $Script:BtnImportGameMods.IsEnabled=($Button -eq $Script:BtnImportGameMods)
    $Button.IsHitTestVisible=$false
    $Button.Focusable=$false
    $Script:BtnScan.IsEnabled=$false
    $Script:BtnBuild.IsEnabled=$false
    $Script:BtnDeploy.IsEnabled=$false
    $Script:LstMods.IsEnabled=$false
    Update-PMMLibraryButtons
    $Script:BtnPriorityUp.IsEnabled=$false;$Script:BtnPriorityDown.IsEnabled=$false;$Script:BtnDeleteMod.IsEnabled=$false
    Set-PMMImportProgress $Button 0.0 (L 'Preparing import...' 'Preparando importacion...') -Indeterminate
  }else{
    if($Script:ImportBusyButton){Clear-PMMWorkflowButtonVisual $Script:ImportBusyButton;$Script:ImportBusyButton.IsHitTestVisible=$true;$Script:ImportBusyButton.Focusable=$true}
    $Script:ImportBusyButton=$null
    $Script:BtnImport.IsEnabled=$true
    $Script:BtnImportGameMods.IsEnabled=$true
    $Script:BtnScan.IsEnabled=$true
    $Script:LstMods.IsEnabled=$true
    Update-PMMLibraryButtons
    Update-BuildButtonState
    Update-PMMGuidedActionState
  }
}

function Set-PMMAIIOProgress {
  param([int]$Current,[int]$Total,[string]$Message,[switch]$Indeterminate)
  $fraction=if($Total -gt 0){[double]$Current/[double]$Total}else{0.0}
  $unknown=([bool]$Indeterminate -or $Total -le 0)
  $Script:PrgAnalyze.Visibility=[System.Windows.Visibility]::Visible
  $Script:TxtAnalyzeProgress.Text=$Message
  [void](Set-PMMSmoothedProgressBar $Script:PrgAnalyze 'AIIO' (100.0*$fraction) -Operation 'AIIO' -Message $Message -Indeterminate:$unknown)
  $Script:TxtStatus.Text=$Message
  Set-PMMUniversalProgress -Operation 'AIIO' -Fraction $fraction -Message $Message -Indeterminate:$unknown
  try{[System.Windows.Forms.Application]::DoEvents()}catch{}
}

function Set-PMMAIIOBusy([bool]$Busy) {
  $Script:AIIOBusy=$Busy
  Update-PMMCancelButtonState
  if($Busy){
    Reset-PMMGuidedActionStyles
    $Script:BtnOpenAIHandoff.IsEnabled=$false
    foreach($button in @($Script:BtnAIIONewSession,$Script:BtnAIIOPrepare,$Script:BtnAIIOImportResponse,$Script:BtnAIIOContinue,$Script:BtnAIIOOpenHandoff,$Script:BtnAIIOArchive,$Script:BtnAIIOUseCandidate,$Script:BtnAIHelpCleanup)){$button.IsEnabled=$false}
    $Script:BtnScan.IsEnabled=$false
    $Script:BtnImport.IsEnabled=$false
    $Script:BtnImportGameMods.IsEnabled=$false
    $Script:LstMods.IsEnabled=$false
    Update-PMMLibraryButtons
    $Script:BtnPriorityUp.IsEnabled=$false;$Script:BtnPriorityDown.IsEnabled=$false;$Script:BtnDeleteMod.IsEnabled=$false
    Set-PMMAIIOProgress 0 0 (L 'Creating AI handoff bundle...' 'Creando paquete de entrega para IA...') -Indeterminate
  }else{
    $Script:BtnScan.IsEnabled=$true
    $Script:BtnImport.IsEnabled=$true
    $Script:BtnImportGameMods.IsEnabled=$true
    $Script:LstMods.IsEnabled=$true
    Update-PMMLibraryButtons
    Update-PMMAnalyzeIndicator
    Update-BuildButtonState
    Update-PMMGuidedActionState
    try{Show-SelectedUnsupportedAsset}catch{}
    try{Refresh-PMMAIHelpUi}catch{}
  }
}


function Set-PMMFixLabProgress {
  param([int]$Current,[int]$Total,[string]$Message,[switch]$Indeterminate)
  $fraction=if($Total -gt 0){[double]$Current/[double]$Total}else{0.0}
  if($Script:TxtFixLabRepairState){$Script:TxtFixLabRepairState.Text=$Message}
  if($Script:TxtFixLabRepairProgress){$Script:TxtFixLabRepairProgress.Text=$Message;$Script:TxtFixLabRepairProgress.Visibility=[System.Windows.Visibility]::Visible}
  if($Script:PrgFixLabRepair){$Script:PrgFixLabRepair.Visibility=[System.Windows.Visibility]::Visible;[void](Set-PMMSmoothedProgressBar $Script:PrgFixLabRepair 'FixLab' ($fraction*100.0) -Operation 'FixLab' -Message $Message -Indeterminate:$Indeterminate)}
  Set-PMMUniversalProgress -Operation 'FixLab' -Fraction $fraction -Message $Message -Indeterminate:$Indeterminate
}

function Set-PMMFixLabBusy([bool]$Busy) {
  $Script:FixLabOperationBusy=$Busy
  Update-PMMCancelButtonState
  if($Busy){
    Reset-PMMGuidedActionStyles
    # The rest of WPF remains navigable. Only controls that would alter the
    # active Fix Lab job or start another conflicting operation are locked.
    if($Script:BtnFixLabRepair){$Script:BtnFixLabRepair.IsEnabled=$false}
    if($Script:BtnFixLabApplyBuilt){$Script:BtnFixLabApplyBuilt.IsEnabled=$false}
    if($Script:BtnFixLabDiscover){$Script:BtnFixLabDiscover.IsEnabled=$false}
    if($Script:BtnFixLabBuildReference){$Script:BtnFixLabBuildReference.IsEnabled=$false}
    if($Script:CmbFixLabVariant){$Script:CmbFixLabVariant.IsEnabled=$false}
    if($Script:LstFixLabCandidates){$Script:LstFixLabCandidates.IsEnabled=$false}
    Set-PMMFixLabProgress 0 0 (L 'Fix Lab is running in the processing engine. You can continue browsing PMM.' 'Fix Lab se esta ejecutando en el motor de procesamiento. Puedes seguir navegando por PMM.') -Indeterminate
  }else{
    if($Script:BtnFixLabDiscover){$Script:BtnFixLabDiscover.IsEnabled=$true}
    if($Script:BtnFixLabBuildReference){$Script:BtnFixLabBuildReference.IsEnabled=$true}
    if($Script:CmbFixLabVariant){$Script:CmbFixLabVariant.IsEnabled=$true}
    if($Script:LstFixLabCandidates){$Script:LstFixLabCandidates.IsEnabled=$true}
    try{Update-PMMGuidedActionState}catch{}
  }
}

# ---------------------------------------------------------------------------
# Background Analyze / Build / AIIO / Fix Lab operations.
# Heavy merge-engine work runs in a child PowerShell process. WPF only polls
# small atomic JSON files, so the main window remains responsive.
# ---------------------------------------------------------------------------
$Script:BackgroundOperationProcess=$null
$Script:BackgroundOperationTimer=$null
$Script:BackgroundOperationKind=''
$Script:BackgroundOperationProgressPath=''
$Script:BackgroundOperationResultPath=''
$Script:BackgroundOperationJobRoot=''
$Script:BackgroundOperationOnSuccess=$null
$Script:BackgroundOperationOnFailure=$null
$Script:BackgroundOperationFixLabJobId=''

function Stop-PMMBackgroundOperation([switch]$Silent) {
  try{if($Script:BackgroundOperationTimer){$Script:BackgroundOperationTimer.Stop()}}catch{}
  try{
    if($Script:BackgroundOperationProcess -and -not$Script:BackgroundOperationProcess.HasExited){
      # PMMFixLab.exe/repak may be descendants of the PowerShell worker. Kill
      # the complete process tree so Cancel never leaves an orphan engine.
      try{Start-Process -FilePath 'taskkill.exe' -ArgumentList ('/PID '+[int]$Script:BackgroundOperationProcess.Id+' /T /F') -WindowStyle Hidden -Wait -ErrorAction Stop|Out-Null}catch{$Script:BackgroundOperationProcess.Kill()}
    }
  }catch{}
  $kind=[string]$Script:BackgroundOperationKind
  $cancelledFixLabJob=[string]$Script:BackgroundOperationFixLabJobId
  if($kind -eq 'FixLabBuild' -and -not[string]::IsNullOrWhiteSpace($cancelledFixLabJob)){
    try{
      $cancelledJob=Get-PMMFixLabJob $cancelledFixLabJob
      if($cancelledJob -and $cancelledJob.Build -and [string]$cancelledJob.Build.Status -eq 'Building'){
        $cancelledJob.Build.Status='Failed'
        $cancelledJob.Build.Validation='PMM_OPERATION_CANCELLED'
        Save-PMMFixLabJob $cancelledJob|Out-Null
      }
    }catch{Write-PMMLog ('Could not persist cancelled Fix Lab job state: '+$_.Exception.Message)}
  }
  $Script:BackgroundOperationProcess=$null
  $Script:BackgroundOperationKind=''
  $Script:BackgroundOperationFixLabJobId=''
  $Script:BackgroundOperationOnSuccess=$null
  $Script:BackgroundOperationOnFailure=$null
  if($kind -eq 'Analyze'){Set-PMMAnalyzeBusy $false}
  elseif($kind -eq 'Build'){Set-PMMBuildBusy $false}
  elseif($kind -in @('AIHandoff','AIIOPrepare','AIIOPendingData','AIIOImportResponse','AIIOUseCandidate','AIIOModBuild','AIIOArtifactRefresh')){Set-PMMAIIOBusy $false}
  elseif($kind -eq 'FixLabBuild'){Set-PMMFixLabBusy $false}
  if(-not$Silent -and -not[string]::IsNullOrWhiteSpace($kind)){
    $Script:TxtStatus.Text=(L ($kind+' stopped.') ($kind+' detenido.'))
  }
  Update-PMMCancelButtonState
}

function Complete-PMMBackgroundOperation {
  try{if($Script:BackgroundOperationTimer){$Script:BackgroundOperationTimer.Stop()}}catch{}
  $kind=[string]$Script:BackgroundOperationKind
  $result=$null
  try{
    if(Test-Path -LiteralPath $Script:BackgroundOperationResultPath -PathType Leaf){
      $result=Get-Content -LiteralPath $Script:BackgroundOperationResultPath -Raw|ConvertFrom-Json
    }
  }catch{}

  $successCallback=$Script:BackgroundOperationOnSuccess
  $failureCallback=$Script:BackgroundOperationOnFailure
  $Script:BackgroundOperationOnSuccess=$null
  $Script:BackgroundOperationOnFailure=$null
  $Script:BackgroundOperationProcess=$null
  $Script:BackgroundOperationKind=''
  $Script:BackgroundOperationFixLabJobId=''

  if($result -and [bool]$result.Success){
    # Force a final 100% sample even when the worker exits between UI polling
    # ticks. This guarantees both the in-button fill and the persistent bar
    # finish cleanly before the next guided action is highlighted.
    if($kind -eq 'Analyze'){Set-PMMAnalyzeProgress 1 1 (L 'Analyze complete.' 'Analisis terminado.')}
    elseif($kind -eq 'Build'){Set-PMMBuildProgress 1 1 (L 'Build complete.' 'Build terminado.')}
    elseif($kind -in @('AIHandoff','AIIOPrepare','AIIOPendingData','AIIOImportResponse','AIIOUseCandidate','AIIOModBuild','AIIOArtifactRefresh')){Set-PMMAIIOProgress 1 1 (L 'AIIO operation complete.' 'Operacion AIIO terminada.')}
    elseif($kind -eq 'FixLabBuild'){Set-PMMFixLabProgress 1 1 (L 'Fix Lab repair build complete.' 'Build de reparacion Fix Lab terminado.')}
    try{
      if($successCallback){& $successCallback $result}
    }catch{Handle-UIError $_ ($kind+' completion')}
  }else{
    $message=if($result -and -not[string]::IsNullOrWhiteSpace([string]$result.Error)){
      [string]$result.Error
    }else{
      (L ($kind+' worker stopped without a valid result.') ('El proceso '+$kind+' termino sin un resultado valido.'))
    }
    Write-PMMLog ('Background '+$kind+' failed: '+$message)
    $failureOperation=if($kind -in @('AIHandoff','AIIOPrepare','AIIOPendingData','AIIOImportResponse','AIIOUseCandidate','AIIOModBuild','AIIOArtifactRefresh')){'AIIO'}elseif($kind -eq 'FixLabBuild'){'FixLab'}else{$kind}
    Set-PMMOperationFailure $failureOperation $message
    try{
      if($failureCallback){& $failureCallback $message}else{Show-Error $message}
    }catch{}
  }

  # Keep the current workflow button in its progress state while the completion
  # callback refreshes plan/build state. Only then clear Busy and illuminate the
  # next real step, avoiding a one-frame stale highlight between operations.
  if($kind -eq 'Analyze'){Set-PMMAnalyzeBusy $false}
  elseif($kind -eq 'Build'){Set-PMMBuildBusy $false}
  elseif($kind -in @('AIHandoff','AIIOPrepare','AIIOPendingData','AIIOImportResponse','AIIOUseCandidate','AIIOModBuild','AIIOArtifactRefresh')){Set-PMMAIIOBusy $false}
  elseif($kind -eq 'FixLabBuild'){Set-PMMFixLabBusy $false}

  if($result -and [bool]$result.Success -and @('Analyze','Build','FixLabBuild') -contains $kind){Notify-PMMWorkflowStepComplete}

  try{
    if($Script:BackgroundOperationJobRoot){
      Remove-Item -LiteralPath $Script:BackgroundOperationJobRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
  }catch{}

  # AUTO continuation belongs here rather than in individual UI callbacks: the
  # worker has exited, result state is refreshed and Busy is already false.
  if($result -and [bool]$result.Success -and $Script:AutoPipelineActive -and @('Analyze','Build','FixLabBuild') -contains $kind){
    try{Invoke-PMMAutoContinue}catch{Write-PMMLog ('AUTO continuation after '+$kind+' failed: '+$_.Exception.Message)}
  }else{
    try{Update-PMMGuidedActionState}catch{}
  }
}

function Start-PMMBackgroundOperation {
  param(
    [Parameter(Mandatory=$true)][ValidateSet('Analyze','Build','AIHandoff','AIIOPrepare','AIIOPendingData','AIIOImportResponse','AIIOUseCandidate','AIIOModBuild','AIIOArtifactRefresh','FixLabBuild')][string]$Operation,
    [switch]$Force,
    [switch]$AllowOversize,
    [ValidateSet('ConflictGroups')][string]$Mode='ConflictGroups',
    [string]$SessionId='',
    [string]$InputZip='',
    [string]$SolutionId='',
    [string]$FixLabJobId='',
    [string]$FixLabRecipeId='',
    [string]$FixLabVariantId='',
    [scriptblock]$OnSuccess=$null,
    [scriptblock]$OnFailure=$null
  )

  if($Operation -in @('AIIOPrepare','AIIOPendingData','AIIOImportResponse','AIIOUseCandidate','AIIOModBuild') -and -not(Test-PMMAIIOSessionId $SessionId)){throw ($Operation+' requires a valid persistent AIIO session id.')}
  if($Operation -eq 'AIIOImportResponse' -and -not(Test-Path -LiteralPath $InputZip -PathType Leaf)){throw 'AIIO response ZIP was not found.'}
  if($Operation -in @('AIIOUseCandidate','AIIOModBuild') -and $SolutionId -notmatch '^[a-f0-9]{64}$'){throw 'AIIO candidate solution id is invalid.'}
  if(-not(Request-PMMProcessingSlot $Operation)){return $false}
  Reset-PMMOperationCancellation

  $worker=Join-Path $Script:Root 'Modules\Operations\OperationWorker.ps1'
  if(-not(Test-Path -LiteralPath $worker -PathType Leaf)){throw 'Modules\Operations\OperationWorker.ps1 is missing.'}

  $jobsRoot=Join-PMMPath 'Cache' 'OperationJobs'
  New-Item -ItemType Directory -Force -Path $jobsRoot|Out-Null
  $job=Join-Path $jobsRoot ([guid]::NewGuid().ToString('N'))
  New-Item -ItemType Directory -Force -Path $job|Out-Null

  $Script:BackgroundOperationJobRoot=$job
  $Script:BackgroundOperationProgressPath=Join-Path $job 'progress.json'
  $Script:BackgroundOperationResultPath=Join-Path $job 'result.json'
  $Script:BackgroundOperationOnSuccess=$OnSuccess
  $Script:BackgroundOperationOnFailure=$OnFailure
  $Script:BackgroundOperationKind=$Operation
  $Script:BackgroundOperationFixLabJobId=if($Operation -eq 'FixLabBuild'){[string]$FixLabJobId}else{''}

  $stdout=Join-Path $job 'worker.stdout.txt'
  $stderr=Join-Path $job 'worker.stderr.txt'
  # Always use a dedicated PowerShell process for processing jobs. Reusing
  # PMM.exe as the worker host can involve the desktop host/single-instance
  # layer and makes UI responsiveness dependent on host implementation details.
  $hostExe=Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
  if(-not(Test-Path -LiteralPath $hostExe -PathType Leaf)){
    try{$hostExe=[string](Get-Command powershell.exe -ErrorAction Stop).Source}catch{$hostExe='powershell.exe'}
  }

  $args='-NoLogo -NoProfile -ExecutionPolicy Bypass -File "'+$worker+'" -Root "'+$Script:Root+'" -Operation '+$Operation+' -ProgressPath "'+$Script:BackgroundOperationProgressPath+'" -ResultPath "'+$Script:BackgroundOperationResultPath+'" -Mode '+$Mode
  if($Operation -eq 'FixLabBuild'){
    if(-not[string]::IsNullOrWhiteSpace($FixLabJobId)){$args+=' -FixLabJobId "'+$FixLabJobId+'"'}
    if(-not[string]::IsNullOrWhiteSpace($FixLabRecipeId)){$args+=' -FixLabRecipeId "'+$FixLabRecipeId+'"'}
    if(-not[string]::IsNullOrWhiteSpace($FixLabVariantId)){$args+=' -FixLabVariantId "'+$FixLabVariantId+'"'}
  }
  if($Operation -in @('AIIOPrepare','AIIOPendingData','AIIOImportResponse','AIIOUseCandidate','AIIOModBuild')){
    $args+=' -SessionId "'+$SessionId+'"'
  }
  if($Operation -eq 'AIIOImportResponse'){$args+=' -InputZip "'+$InputZip+'"'}
  if($Operation -in @('AIIOUseCandidate','AIIOModBuild')){$args+=' -SolutionId "'+$SolutionId+'"'}
  if($Force){$args+=' -Force'}
  if($AllowOversize){$args+=' -AllowOversize'}

  if($Operation -eq 'Analyze'){
    Set-PMMAnalyzeBusy $true
    Set-PMMAnalyzeProgress 0 0 (L 'Starting Analyze in the background...' 'Iniciando Analizar en segundo plano...') -Indeterminate
    $Script:TxtStatus.Text=L 'Analyzing shared assets in the background...' 'Analizando assets compartidos en segundo plano...'
  }elseif($Operation -eq 'Build'){
    Set-PMMBuildBusy $true
    Set-PMMBuildProgress 0 0 (L 'Starting Build in the background...' 'Iniciando Build en segundo plano...') -Indeterminate
    $Script:TxtStatus.Text=L 'Building compatibility patch in the background...' 'Creando parche de compatibilidad en segundo plano...'
  }elseif($Operation -in @('AIHandoff','AIIOPrepare','AIIOPendingData','AIIOImportResponse','AIIOUseCandidate','AIIOModBuild','AIIOArtifactRefresh')){
    Set-PMMAIIOBusy $true
    $message=switch($Operation){
      'AIHandoff' {L 'Creating one AI handoff for all current Unsupported cases...' 'Creando una unica entrega para IA con todos los casos no soportados...'}
      'AIIOPendingData' {L 'Preparing only the validated data requested for this session...' 'Preparando solo los datos validados pedidos para esta sesion...'}
      'AIIOImportResponse' {L 'Validating and staging the untrusted AI response...' 'Validando y dejando en staging la respuesta IA no confiable...'}
      'AIIOUseCandidate' {L 'Revalidating the selected candidate against the exact current case...' 'Revalidando el candidato contra el caso actual exacto...'}
      'AIIOModBuild' {L 'Building the selected standalone mod locally; it will remain undeployed...' 'Creando localmente el mod independiente seleccionado; quedara sin desplegar...'}
      'AIIOArtifactRefresh' {L 'Refreshing the local artifact inventory...' 'Actualizando el inventario local de artefactos...'}
      default {L 'Preparing the selected persistent AIIO session...' 'Preparando la sesion AIIO persistente seleccionada...'}
    }
    Set-PMMAIIOProgress 0 0 $message -Indeterminate
    $Script:TxtStatus.Text=$message
  }else{
    if([string]::IsNullOrWhiteSpace($FixLabJobId) -and ([string]::IsNullOrWhiteSpace($FixLabRecipeId) -or [string]::IsNullOrWhiteSpace($FixLabVariantId))){throw 'FixLabBuild requires a job id or recipe + variant.'}
    Set-PMMFixLabBusy $true
    $Script:TxtStatus.Text=L 'Fix Lab repair is running in the processing engine. PMM remains responsive.' 'La reparacion Fix Lab se ejecuta en el motor de procesamiento. PMM sigue respondiendo.'
  }

  try{
    $Script:BackgroundOperationProcess=Start-Process -FilePath $hostExe -ArgumentList $args -WorkingDirectory $Script:Root -WindowStyle Hidden -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
    try{$Script:BackgroundOperationProcess.PriorityClass=[System.Diagnostics.ProcessPriorityClass]::BelowNormal}catch{}
    Write-PMMLog ('Background processing worker started: '+$Operation+' | pid='+[string]$Script:BackgroundOperationProcess.Id+' | host='+$hostExe)
  }catch{
    if($Operation -eq 'Analyze'){Set-PMMAnalyzeBusy $false}elseif($Operation -eq 'Build'){Set-PMMBuildBusy $false}elseif($Operation -in @('AIHandoff','AIIOPrepare','AIIOPendingData','AIIOImportResponse','AIIOUseCandidate','AIIOModBuild','AIIOArtifactRefresh')){Set-PMMAIIOBusy $false}else{Set-PMMFixLabBusy $false}
    $Script:BackgroundOperationKind=''
    $Script:BackgroundOperationFixLabJobId=''
    Remove-Item -LiteralPath $job -Recurse -Force -ErrorAction SilentlyContinue
    throw
  }

  # Progress polling is presentation-only and must yield to real WPF input.
  $timer=[System.Windows.Threading.DispatcherTimer]::new([System.Windows.Threading.DispatcherPriority]::Background)
  $timer.Interval=[TimeSpan]::FromMilliseconds(650)
  $timer.Add_Tick({
    try{
      if(Test-Path -LiteralPath $Script:BackgroundOperationProgressPath -PathType Leaf){
        try{
          $progress=Get-Content -LiteralPath $Script:BackgroundOperationProgressPath -Raw|ConvertFrom-Json
          if([string]$progress.Operation -eq 'Analyze'){
            Set-PMMAnalyzeProgress ([int]$progress.Current) ([int]$progress.Total) ([string]$progress.Message) -Indeterminate:([bool]$progress.Indeterminate)
          }elseif([string]$progress.Operation -eq 'Build'){
            Set-PMMBuildProgress ([int]$progress.Current) ([int]$progress.Total) ([string]$progress.Message) -Indeterminate:([bool]$progress.Indeterminate)
          }elseif([string]$progress.Operation -in @('AIHandoff','AIIOPrepare','AIIOPendingData','AIIOImportResponse','AIIOUseCandidate','AIIOModBuild','AIIOArtifactRefresh')){
            Set-PMMAIIOProgress ([int]$progress.Current) ([int]$progress.Total) ([string]$progress.Message) -Indeterminate:([bool]$progress.Indeterminate)
          }elseif([string]$progress.Operation -eq 'FixLabBuild'){
            if($progress.PSObject.Properties.Name -contains 'JobId' -and -not[string]::IsNullOrWhiteSpace([string]$progress.JobId)){$Script:BackgroundOperationFixLabJobId=[string]$progress.JobId}
            Set-PMMFixLabProgress ([int]$progress.Current) ([int]$progress.Total) ([string]$progress.Message) -Indeterminate:([bool]$progress.Indeterminate)
          }
          $Script:TxtStatus.Text=[string]$progress.Message
        }catch{}
      }
      if($Script:BackgroundOperationProcess -and $Script:BackgroundOperationProcess.HasExited){
        Complete-PMMBackgroundOperation
      }
    }catch{Write-PMMLog ('Background operation progress monitor error: '+$_.Exception.Message)}
  })
  $Script:BackgroundOperationTimer=$timer
  $timer.Start()
  return $true
}

# ---------------------------------------------------------------------------
# Background Game Reference build.
# ---------------------------------------------------------------------------
$Script:GameReferenceProcess=$null
$Script:GameReferenceTimer=$null
$Script:GameReferenceProgressPath=''
$Script:GameReferenceResultPath=''
$Script:GameReferenceJobRoot=''
$Script:GameReferenceOnSuccess=$null
$Script:GameReferenceOnFailure=$null

function Set-PMMGameReferenceProgressUi([int]$Percent,[string]$Message,[bool]$Indeterminate=$false) {
  $Percent=[Math]::Max(0,[Math]::Min(100,$Percent))
  $Script:GameReferenceProgressPercent=$Percent
  $Script:GameReferenceProgressMessage=[string]$Message
  $Script:GameReferenceProgressIndeterminate=[bool]$Indeterminate
  $Script:PrgGameReference.Visibility=[System.Windows.Visibility]::Visible
  $Script:TxtGameReferenceProgress.Visibility=[System.Windows.Visibility]::Visible
  [void](Set-PMMSmoothedProgressBar $Script:PrgGameReference 'GameReferenceMain' $Percent -Operation 'GameReference' -Message $Message -Indeterminate:$Indeterminate)
  $Script:TxtGameReferenceProgress.Text=$Message
  if($Script:PrgFixLabGameReference){
    $Script:PrgFixLabGameReference.Visibility=[System.Windows.Visibility]::Visible
    $Script:TxtFixLabGameReferenceProgress.Visibility=[System.Windows.Visibility]::Visible
    [void](Set-PMMSmoothedProgressBar $Script:PrgFixLabGameReference 'GameReferenceFixLab' $Percent -Operation 'GameReference' -Message $Message -Indeterminate:$Indeterminate)
    $Script:TxtFixLabGameReferenceProgress.Text=$Message
  }
  # The existing ColorFlow convention is preserved: a running operation also
  # consumes the highlighted button as a progress surface. The human output
  # choice may still be highlighted simultaneously on the Fix Lab combo/tab.
  $fraction=[double]$Percent/100.0
  foreach($button in @($Script:BtnBuildGameReference,$Script:BtnFixLabBuildReference)){
    if($button){Set-PMMWorkflowButtonProgress $button 'Build' $fraction $Message -Indeterminate:$Indeterminate}
  }
}

function Stop-PMMGameReferenceBuild([switch]$Silent) {
  try{if($Script:GameReferenceTimer){$Script:GameReferenceTimer.Stop()}}catch{}
  try{if($Script:GameReferenceProcess -and -not$Script:GameReferenceProcess.HasExited){$Script:GameReferenceProcess.Kill()}}catch{}
  $Script:GameReferenceProcess=$null
  $Script:GameReferenceResumeAuto=$false
  $Script:BtnBuildGameReference.IsEnabled=$true
  if($Script:BtnFixLabBuildReference){$Script:BtnFixLabBuildReference.IsEnabled=$true}
  try{Set-PMMGuideButtonStyle $Script:BtnBuildGameReference 'Default';Set-PMMGuideButtonStyle $Script:BtnFixLabBuildReference 'Default'}catch{}
  if(-not$Silent){
    Set-PMMGameReferenceProgressUi 100 (L 'Game Reference build stopped.' 'Creacion de Game Reference detenida.') $false
  }
}

function Complete-PMMGameReferenceBuild {
  try{if($Script:GameReferenceTimer){$Script:GameReferenceTimer.Stop()}}catch{}
  $result=$null
  try{
    if(Test-Path -LiteralPath $Script:GameReferenceResultPath -PathType Leaf){
      $result=Get-Content -LiteralPath $Script:GameReferenceResultPath -Raw|ConvertFrom-Json
    }
  }catch{}
  $Script:BtnBuildGameReference.IsEnabled=$true
  if($Script:BtnFixLabBuildReference){$Script:BtnFixLabBuildReference.IsEnabled=$true}
  $callback=$Script:GameReferenceOnSuccess
  $failureCallback=$Script:GameReferenceOnFailure
  $Script:GameReferenceOnSuccess=$null
  $Script:GameReferenceOnFailure=$null

  if($result -and [bool]$result.Success){
    Set-PMMGameReferenceProgressUi 100 (L 'Game Reference ready.' 'Game Reference lista.') $false
    Refresh-UI
    try{if($Script:FixLabLoaded){Refresh-PMMFixLabUI}}catch{}
    try{
      $built=$result.State
      if($built){$Script:TxtStatus.Text=((L 'Game Reference ready: {0} families, {1:N1} MiB.' 'Game Reference lista: {0} familias, {1:N1} MiB.') -f [int]$built.FamilyCount,([double]$built.Bytes/1MB))}
      if($Script:GameReferenceResumeAuto){Write-PMMLog 'Game Reference completed; AUTO continuation remains armed.'}
    }catch{Write-PMMLog ('Game Reference completion UI warning: '+$_.Exception.Message)}
    try{if($callback){& $callback $result.State}}catch{Write-PMMLog ('Game Reference optional callback warning: '+$_.Exception.Message)}
  }else{
    $message=if($result -and -not[string]::IsNullOrWhiteSpace([string]$result.Error)){
      [string]$result.Error
    }else{
      L 'Game Reference worker stopped without a valid result.' 'El proceso de Game Reference termino sin un resultado valido.'
    }
    Set-PMMGameReferenceProgressUi 100 ((L 'Game Reference failed: ' 'Game Reference fallo: ')+$message) $false
    Write-PMMLog ('Background Game Reference build failed: '+$message)
    try{if($failureCallback){& $failureCallback $message}else{Show-Error $message}}catch{}
  }

  try{
    if($Script:GameReferenceJobRoot){
      Remove-Item -LiteralPath $Script:GameReferenceJobRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
  }catch{}
  $Script:GameReferenceProcess=$null
  $Script:GameReferenceResumeAuto=$false
  try{Set-PMMGuideButtonStyle $Script:BtnBuildGameReference 'Default';Set-PMMGuideButtonStyle $Script:BtnFixLabBuildReference 'Default'}catch{}
  if($result -and [bool]$result.Success){Notify-PMMWorkflowStepComplete}
  if($result -and [bool]$result.Success -and $Script:AutoPipelineActive){
    Write-PMMLog 'Game Reference completed with AUTO active; resuming unified workflow.'
    try{Invoke-PMMAutoContinue}catch{Write-PMMLog ('AUTO continuation after Game Reference failed: '+$_.Exception.Message)}
  }else{
    try{Update-PMMGuidedActionState}catch{}
  }
}

function Start-PMMGameReferenceBuild {
  param([scriptblock]$OnSuccess=$null,[scriptblock]$OnFailure=$null)
  if(-not(Request-PMMProcessingSlot 'GameReference')){return $false}

  $worker=Join-Path $Script:Root 'Modules\GameReference\GameReferenceWorker.ps1'
  if(-not(Test-Path -LiteralPath $worker -PathType Leaf)){throw 'Modules\GameReference\GameReferenceWorker.ps1 is missing.'}

  $jobsRoot=Join-PMMPath 'Cache' 'GameReferenceJobs'
  New-Item -ItemType Directory -Force -Path $jobsRoot|Out-Null
  $job=Join-Path $jobsRoot ([guid]::NewGuid().ToString('N'))
  New-Item -ItemType Directory -Force -Path $job|Out-Null

  $Script:GameReferenceJobRoot=$job
  $Script:GameReferenceProgressPath=Join-Path $job 'progress.json'
  $Script:GameReferenceResultPath=Join-Path $job 'result.json'
  $stdout=Join-Path $job 'worker.stdout.txt'
  $stderr=Join-Path $job 'worker.stderr.txt'
  $Script:GameReferenceOnSuccess=$OnSuccess
  $Script:GameReferenceOnFailure=$OnFailure

  $hostExe=''
  try{$hostExe=[string](Get-Process -Id $PID -ErrorAction Stop).Path}catch{}
  if([string]::IsNullOrWhiteSpace($hostExe) -or -not(Test-Path -LiteralPath $hostExe -PathType Leaf)){
    $hostExe='powershell.exe'
  }

  $args='-NoLogo -NoProfile -ExecutionPolicy Bypass -File "'+$worker+'" -Root "'+$Script:Root+'" -ProgressPath "'+$Script:GameReferenceProgressPath+'" -ResultPath "'+$Script:GameReferenceResultPath+'"'
  Set-PMMGameReferenceProgressUi 0 (L 'Starting Game Reference build in the background...' 'Iniciando Game Reference en segundo plano...') $true
  $Script:BtnBuildGameReference.IsEnabled=$false
  if($Script:BtnFixLabBuildReference){$Script:BtnFixLabBuildReference.IsEnabled=$false}

  try{
    $Script:GameReferenceProcess=Start-Process -FilePath $hostExe -ArgumentList $args -WorkingDirectory $Script:Root -WindowStyle Hidden -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
  }catch{
    $Script:BtnBuildGameReference.IsEnabled=$true
    if($Script:BtnFixLabBuildReference){$Script:BtnFixLabBuildReference.IsEnabled=$true}
    Remove-Item -LiteralPath $job -Recurse -Force -ErrorAction SilentlyContinue
    throw
  }

  # Game Reference progress is non-critical presentation work; user input wins.
  $timer=[System.Windows.Threading.DispatcherTimer]::new([System.Windows.Threading.DispatcherPriority]::Background)
  $timer.Interval=[TimeSpan]::FromMilliseconds(500)
  $timer.Add_Tick({
    try{
      if(Test-Path -LiteralPath $Script:GameReferenceProgressPath -PathType Leaf){
        try{
          $progress=Get-Content -LiteralPath $Script:GameReferenceProgressPath -Raw|ConvertFrom-Json
          Set-PMMGameReferenceProgressUi ([int]$progress.Percent) ([string]$progress.Message) ([bool]$progress.Indeterminate)
        }catch{}
      }
      if($Script:GameReferenceProcess -and $Script:GameReferenceProcess.HasExited){
        Complete-PMMGameReferenceBuild
      }
    }catch{Write-PMMLog ('Game Reference progress monitor error: '+$_.Exception.Message)}
  })
  $Script:GameReferenceTimer=$timer
  $timer.Start()
  try{Update-PMMGuidedActionState}catch{}
  return $true
}


# ---------------------------------------------------------------------------
# Conflict workspace helpers.
# ---------------------------------------------------------------------------
$Script:LoadingConflictView = $false
$Script:CurrentConflictAssetKey = ''
$Script:LastConflictPlanCreated = ''
$Script:CurrentUnsupportedAssetKey = ''

