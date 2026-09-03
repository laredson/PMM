param(
  [Parameter(Mandatory=$true)][string]$Root,
  [Parameter(Mandatory=$true)][string]$CaseId,
  [ValidateSet('AUTO','HANDOFF')][string]$Mode='AUTO',
  [int]$FromStep=0
)

Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
$Script:Root=[IO.Path]::GetFullPath($Root)

. (Join-Path $Script:Root 'Modules\Shared\Paths.ps1')
Initialize-PMMPaths $Script:Root|Out-Null
. (Join-Path $Script:Root 'Modules\Shared\Common.ps1')
. (Join-Path $Script:Root 'Modules\Operations\OperationJournal.ps1')
. (Join-Path $Script:Root 'Modules\Theme\ThemeService.ps1')
. (Join-Path $Script:Root 'Modules\Shared\GameLocator.ps1')
. (Join-Path $Script:Root 'Modules\Merge\PakService.ps1')
. (Join-Path $Script:Root 'Modules\Library\LibraryService.ps1')
. (Join-Path $Script:Root 'Modules\CKL\SemanticLab.ps1')
. (Join-Path $Script:Root 'Modules\GameReference\GameReferenceService.ps1')
. (Join-Path $Script:Root 'Modules\CKL\KnowledgeRecipeService.ps1')
. (Join-Path $Script:Root 'Modules\Merge\MergeEngine.ps1')
. (Join-Path $Script:Root 'Modules\AIIO\AIIO.ps1')
. (Join-Path $Script:Root 'Modules\AIIO\AIIO.SessionService.ps1')
. (Join-Path $Script:Root 'Modules\AIIO\AIIO.DiagnosticService.ps1')
. (Join-Path $Script:Root 'Modules\AIIO\AIIO.ModCreationService.ps1')
. (Join-Path $Script:Root 'Modules\AIIO\AIIO.ResponseService.ps1')
. (Join-Path $Script:Root 'Modules\AIIO\AIIO.GameReferenceHydrationService.ps1')
. (Join-Path $Script:Root 'Modules\AIIO\AIIO.PendingDataService.ps1')
. (Join-Path $Script:Root 'Modules\AIIO\AIIO.SessionRecoveryService.ps1')
. (Join-Path $Script:Root 'Modules\AIIO\AIIO.CaseWorkspaceService.ps1')
. (Join-Path $Script:Root 'Modules\AIIO\AIIO.CaseWorkspace.ActionSafety.ps1')
. (Join-Path $Script:Root 'Modules\AIIO\AIIO.CaseWorkspace.RemoteFetch.ps1')

function Set-PMMGameReferenceProgress {
  param([int]$Current=0,[int]$Total=100,[string]$Message='',[switch]$Indeterminate)
  try{Set-PMMAIIOCaseProgress -Id $CaseId -Current $Current -Total $Total -Message $Message -Indeterminate:$Indeterminate}catch{}
}

function Write-PMMAIIOWorkerResult([string]$Status,[string]$Message,[string]$ZipPath=''){
  try{
    $path=Join-Path (Get-PMMAIIOCasePath $CaseId) 'worker-result.json'
    Write-PMMAIIOCaseJson $path ([ordered]@{Schema='PMM_AIIO_CASE_WORKER_RESULT_V1';CaseId=$CaseId;Mode=$Mode;Status=$Status;Message=$Message;ZipPath=$ZipPath;Utc=[DateTime]::UtcNow.ToString('o')}) 12
  }catch{}
}

try{
  $case=Get-PMMAIIOCase $CaseId
  if(-not$case){throw 'AIIO case not found.'}
  Set-PMMAIIOCaseProgress $CaseId 0 100 'AIIO worker started...' -Indeterminate

  $zipPath=''
  if($Mode -eq 'HANDOFF'){
    $step=$FromStep
    if($step -le 0){$step=[int](Get-PMMAIIOActionValue $case 'SelectedStep' 0);if($step -le 0){$step=[int](Get-PMMAIIOActionValue $case 'CurrentStep' 0)}}
    if($step -lt 1){throw 'The case has no step to export.'}
    Set-PMMAIIOCaseProgress $CaseId 0 1 ('Creating AI handoff from step '+$step+'...')
    $result=New-PMMAIIOCaseHandoff $CaseId $step
    $zipPath=[string]$result.ZipPath
    Set-PMMAIIOCaseProgress $CaseId 1 1 ('Handoff ready: '+[IO.Path]::GetFileName($zipPath)) -Completed
  }else{
    $guard=0
    while($guard -lt 30){
      $guard++
      $case=Get-PMMAIIOCase $CaseId
      if(-not$case){throw 'AIIO case disappeared while the worker was running.'}
      $next=[string](Get-PMMAIIOActionValue $case 'NextAction' '')
      $pending=[Collections.Generic.List[object]]::new()
      foreach($action in @(Get-PMMAIIOActionArray $case 'PendingActions')){
        if([string](Get-PMMAIIOActionValue $action 'Status' 'Pending') -eq 'Pending'){$pending.Add($action)}
      }

      if($pending.Count -gt 0 -and $next -ne 'PROCESS_REQUESTS'){
        $case.NextAction='PROCESS_REQUESTS';Save-PMMAIIOCase $case|Out-Null;$next='PROCESS_REQUESTS'
      }

      if($next -eq 'PROCESS_REQUESTS'){
        [void](Invoke-PMMAIIOCasePendingActions $CaseId)
        continue
      }
      if($next -in @('CREATE_HANDOFF','EDIT_OR_CREATE_HANDOFF')){
        $case=Get-PMMAIIOCase $CaseId
        $step=[int](Get-PMMAIIOActionValue $case 'CurrentStep' 0)
        if($step -lt 1){throw 'The case has no current step to export.'}
        Set-PMMAIIOCaseProgress $CaseId 0 1 ('Creating AI handoff from step '+$step+'...')
        $result=New-PMMAIIOCaseHandoff $CaseId $step
        $zipPath=[string]$result.ZipPath
        Set-PMMAIIOCaseProgress $CaseId 1 1 ('Handoff ready: '+[IO.Path]::GetFileName($zipPath)) -Completed
        break
      }
      if($next -eq 'WAIT_FOR_AI'){
        Set-PMMAIIOCaseProgress $CaseId 1 1 'AIIO is waiting for AI input.' -Completed
        break
      }
      if($next -in @('USER_DECISION','REVIEW_CANDIDATE')){
        Set-PMMAIIOCaseProgress $CaseId 1 1 ('AIIO paused for supervision: '+$next) -Completed
        break
      }

      $case.NextAction='CREATE_HANDOFF';$case.Status='READY_FOR_HANDOFF';Save-PMMAIIOCase $case|Out-Null
    }
    if($guard -ge 30){throw 'AIIO worker exceeded its local step guard.'}
  }

  Write-PMMAIIOWorkerResult 'Complete' 'AIIO worker completed.' $zipPath
  exit 0
}catch{
  $message=$_.Exception.Message
  try{Set-PMMAIIOCaseProgress $CaseId 1 1 ('AIIO worker failed: '+$message) -Completed}catch{}
  Write-PMMAIIOWorkerResult 'Failed' $message ''
  exit 1
}
