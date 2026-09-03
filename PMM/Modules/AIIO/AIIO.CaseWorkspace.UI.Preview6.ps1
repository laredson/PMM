<# AIIO Case Workspace preview 6.
   Long AIIO operations run in a separate worker process. The WPF thread only
   imports/routes quickly, launches the worker and polls persisted case progress. #>

$Script:PMMAIIOWorkerProcess=$null
$Script:PMMAIIOWorkerCaseId=''
$Script:PMMAIIOWorkerMode=''
$Script:PMMAIIOWorkerTimer=$null

function Get-PMMAIIOWorkerResultV6([string]$CaseId){
  try{
    $path=Join-Path (Get-PMMAIIOCasePath $CaseId) 'worker-result.json'
    if(Test-Path -LiteralPath $path -PathType Leaf){return (Get-Content -LiteralPath $path -Raw -Encoding UTF8|ConvertFrom-Json)}
  }catch{}
  return $null
}

function Set-PMMAIIOWorkerUiBusyV6([bool]$Busy){
  foreach($name in @('BtnAuto','BtnHandoff','BtnSave','BtnAddPak','BtnAddModFamily','BtnAddVanilla','BtnRemoveRef')){
    $control=Get-PMMAIIOCaseControl $name
    if($control){$control.IsEnabled=(-not$Busy)}
  }
  $cancel=Get-PMMAIIOCaseControl 'BtnCancel'
  if($cancel){$cancel.IsEnabled=$Busy}
}

function Update-PMMAIIOWorkerProgressV6 {
  if([string]::IsNullOrWhiteSpace($Script:PMMAIIOWorkerCaseId)){return}
  $case=Get-PMMAIIOCase $Script:PMMAIIOWorkerCaseId
  if(-not$case){return}
  if($Script:PMMAIIOCaseSelectedId -ne $Script:PMMAIIOWorkerCaseId){return}

  $operation=Get-PMMAIIOCaseValue $case 'ActiveOperation' $null
  $message=[string](Get-PMMAIIOCaseValue $operation 'Message' 'AIIO is working...')
  $indeterminate=[bool](Get-PMMAIIOCaseValue $operation 'Indeterminate' $false)
  $current=[int](Get-PMMAIIOCaseValue $operation 'Current' 0)
  $total=[int](Get-PMMAIIOCaseValue $operation 'Total' 100)
  $bar=Get-PMMAIIOCaseControl 'PrgProgress'
  if($bar){
    $bar.IsIndeterminate=$indeterminate
    if(-not$indeterminate){$bar.Value=$(if($total -gt 0){[Math]::Min(100,[Math]::Max(0,[Math]::Floor(100.0*$current/$total)))}else{0})}
  }
  $text=Get-PMMAIIOCaseControl 'TxtProgress';if($text){$text.Text=$message}
  $status=Get-PMMAIIOCaseControl 'TxtStatus';if($status){$status.Text=('Background AIIO worker: '+$message)}
}

function Complete-PMMAIIOWorkerV6 {
  $caseId=$Script:PMMAIIOWorkerCaseId
  $proc=$Script:PMMAIIOWorkerProcess
  $exitCode=-1
  try{$exitCode=$proc.ExitCode}catch{}
  try{$proc.Dispose()}catch{}
  $Script:PMMAIIOWorkerProcess=$null
  $Script:PMMAIIOWorkerCaseId=''
  $Script:PMMAIIOWorkerMode=''
  if($Script:PMMAIIOWorkerTimer){try{$Script:PMMAIIOWorkerTimer.Stop()}catch{};$Script:PMMAIIOWorkerTimer=$null}

  $result=Get-PMMAIIOWorkerResultV6 $caseId
  Refresh-PMMAIIOCaseList $caseId
  Set-PMMAIIOWorkerUiBusyV6 $false
  if($exitCode -eq 0 -and $result -and [string](Get-PMMAIIOCaseValue $result 'Status' '') -eq 'Complete'){
    $zip=[string](Get-PMMAIIOCaseValue $result 'ZipPath' '')
    Set-PMMAIIOCaseUiStatus $(if($zip){'AIIO background work complete. Handoff ready: '+[IO.Path]::GetFileName($zip)}else{'AIIO background work complete.'})
    if($zip){Show-PMMAIIOHandoffInExplorerV5 $zip}
  }else{
    $message=$(if($result){[string](Get-PMMAIIOCaseValue $result 'Message' 'AIIO worker failed.')}else{'AIIO worker stopped unexpectedly.'})
    Set-PMMAIIOCaseUiStatus $message
  }
}

function Invoke-PMMAIIOWorkerTickV6 {
  try{
    Update-PMMAIIOWorkerProgressV6
    if($Script:PMMAIIOWorkerProcess -and $Script:PMMAIIOWorkerProcess.HasExited){Complete-PMMAIIOWorkerV6}
  }catch{
    try{Set-PMMAIIOCaseUiStatus ('AIIO worker monitor error: '+$_.Exception.Message)}catch{}
  }
}

function Start-PMMAIIOCaseWorkerV6 {
  param([Parameter(Mandatory=$true)][string]$CaseId,[ValidateSet('AUTO','HANDOFF')][string]$Mode='AUTO',[int]$FromStep=0)
  if($Script:PMMAIIOWorkerProcess -and -not$Script:PMMAIIOWorkerProcess.HasExited){throw ('AIIO is already processing case '+$Script:PMMAIIOWorkerCaseId+'.')}
  $case=Get-PMMAIIOCase $CaseId
  if(-not$case){throw 'AIIO case not found.'}

  $resultPath=Join-Path (Get-PMMAIIOCasePath $CaseId) 'worker-result.json'
  Remove-Item -LiteralPath $resultPath -Force -ErrorAction SilentlyContinue
  Set-PMMAIIOCaseProgress $CaseId 0 100 'Starting background AIIO worker...' -Indeterminate

  $worker=Join-Path $Script:Root 'Modules\AIIO\AIIO.CaseWorker.ps1'
  if(-not(Test-Path -LiteralPath $worker -PathType Leaf)){throw 'AIIO worker script is missing.'}
  $psi=[Diagnostics.ProcessStartInfo]::new()
  $psi.FileName='powershell.exe'
  $psi.UseShellExecute=$false
  $psi.CreateNoWindow=$true
  $psi.WorkingDirectory=$Script:Root
  $args='-NoProfile -ExecutionPolicy Bypass -File "'+$worker+'" -Root "'+$Script:Root+'" -CaseId "'+$CaseId+'" -Mode '+$Mode
  if($FromStep -gt 0){$args+=' -FromStep '+$FromStep}
  $psi.Arguments=$args
  $proc=[Diagnostics.Process]::new();$proc.StartInfo=$psi
  if(-not$proc.Start()){throw 'Could not start the AIIO background worker.'}

  $Script:PMMAIIOWorkerProcess=$proc
  $Script:PMMAIIOWorkerCaseId=$CaseId
  $Script:PMMAIIOWorkerMode=$Mode
  Set-PMMAIIOWorkerUiBusyV6 $true

  $timer=[Windows.Threading.DispatcherTimer]::new()
  $timer.Interval=[TimeSpan]::FromMilliseconds(250)
  $timer.Add_Tick({Invoke-PMMAIIOWorkerTickV6})
  $Script:PMMAIIOWorkerTimer=$timer
  $timer.Start()
  Update-PMMAIIOWorkerProgressV6
}

function Stop-PMMAIIOCaseAutomation {
  $Script:PMMAIIOCaseCancelRequested=$true
  if(-not$Script:PMMAIIOWorkerProcess -or $Script:PMMAIIOWorkerProcess.HasExited){return}
  $caseId=$Script:PMMAIIOWorkerCaseId
  $pid=[int]$Script:PMMAIIOWorkerProcess.Id
  try{
    $killer=Start-Process -FilePath 'taskkill.exe' -ArgumentList @('/PID',[string]$pid,'/T','/F') -WindowStyle Hidden -Wait -PassThru
  }catch{try{$Script:PMMAIIOWorkerProcess.Kill()}catch{}}
  try{Set-PMMAIIOCaseProgress $caseId 1 1 'AIIO operation cancelled by user.' -Completed}catch{}
  try{Write-PMMAIIOCaseJson (Join-Path (Get-PMMAIIOCasePath $caseId) 'worker-result.json') ([ordered]@{Schema='PMM_AIIO_CASE_WORKER_RESULT_V1';CaseId=$caseId;Mode=$Script:PMMAIIOWorkerMode;Status='Cancelled';Message='AIIO operation cancelled by user.';ZipPath='';Utc=[DateTime]::UtcNow.ToString('o')}) 12}catch{}
  Set-PMMAIIOCaseUiStatus 'AIIO cancellation requested.'
}

function Invoke-PMMAIIOReceiveUi {
  $dialog=[Microsoft.Win32.OpenFileDialog]::new();$dialog.Filter='AIIO files (*.zip;*.json)|*.zip;*.json|All files (*.*)|*.*'
  if($dialog.ShowDialog() -ne $true){return}
  $path=[string]$dialog.FileName
  if(-not(Confirm-PMMAIIOInboundTrust $path)){return}
  $doc=Read-PMMAIIOWorkOrder $path
  if($doc){
    # Importing the envelope is intentionally separate from executing it. The
    # potentially long requested work is always delegated to CaseWorker.
    $case=Import-PMMAIIOWorkOrder $path $doc -Trusted
    $Script:PMMAIIOCaseSelectedId=[string]$case.CaseId
    Refresh-PMMAIIOCaseList ([string]$case.CaseId)
    Set-PMMAIIOCaseUiStatus ('Received '+[IO.Path]::GetFileName($path)+'. Background processing started.')
    Start-PMMAIIOCaseWorkerV6 -CaseId ([string]$case.CaseId) -Mode AUTO
    return
  }

  $case=Route-PMMAIIOLegacyFile $path
  if($case){$Script:PMMAIIOCaseSelectedId=[string]$case.CaseId;Refresh-PMMAIIOCaseList ([string]$case.CaseId)}
  Set-PMMAIIOCaseUiStatus ('Received '+[IO.Path]::GetFileName($path))
}

function Invoke-PMMAIIOAutoCaseUiV4 {
  $case=Get-PMMAIIOSelectedCase
  if(-not$case){return}
  [void](Save-PMMAIIOCaseEditor)
  $case=Get-PMMAIIOCase ([string]$case.CaseId)
  if(-not$case){throw 'Case disappeared while AUTO was starting.'}
  $next=[string](Get-PMMAIIOCaseValue $case 'NextAction' '')
  if($next -in @('USER_DECISION','REVIEW_CANDIDATE')){
    Set-PMMAIIOCaseUiStatus ('AUTO paused for supervision: '+(Get-PMMAIIOCaseNextLabel $next));return
  }
  if($next -eq 'WAIT_FOR_AI'){
    Set-PMMAIIOCaseUiStatus 'AUTO is waiting for AI input.';return
  }
  Start-PMMAIIOCaseWorkerV6 -CaseId ([string]$case.CaseId) -Mode AUTO
}

function Invoke-PMMAIIOCreateHandoffUi {
  $case=Get-PMMAIIOSelectedCase
  if(-not$case){return}
  [void](Save-PMMAIIOCaseEditor)
  $case=Get-PMMAIIOCase ([string]$case.CaseId)
  $step=[int](Get-PMMAIIOCaseValue $case 'SelectedStep' 0)
  if($step -le 0){$step=[int](Get-PMMAIIOCaseValue $case 'CurrentStep' 0)}
  if($step -lt 1){throw 'The case has no step to export.'}
  Start-PMMAIIOCaseWorkerV6 -CaseId ([string]$case.CaseId) -Mode HANDOFF -FromStep $step
}
