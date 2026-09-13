param([string]$Root,[string]$SessionId,[string]$JobId)
Set-StrictMode -Version 2;$ErrorActionPreference='Stop';$Script:Root=[IO.Path]::GetFullPath($Root)
. (Join-Path $Script:Root 'Modules/Analysis/Services.ps1')
. (Join-Path $Script:Root 'Modules/Workbench.Services.ps1') -Profile Worker|Out-Null
if($JobId -notmatch '^[a-f0-9]{32}$'){throw 'Invalid job identifier.'}
$job=Join-Path (Get-PMMRepairSessionRoot $SessionId) ('Jobs/'+$JobId)
$lock=$null;$gate=$null;$lease=$null
try{
  $lock=Enter-PMMAnalysisLock (Join-Path $job 'worker.lock') 1
  $request=Read-PMMJsonFile (Join-Path $job 'request.json')
  $s=Assert-PMMRepairAuthorization $SessionId $request.CaseId $request.EvidenceRevision Build
  $gate=Enter-PMMAnalysisLock (Join-PMMPath 'Cache' 'PMM.background-operation.lock') 1
  $lease=Start-PMMModuleOperation 'RepairMerge'
  function Assert-PMMOperationNotCancelled {
    if(Test-Path -LiteralPath (Join-Path (Get-PMMRepairSessionRoot $SessionId) 'cancel')){throw 'Repair merge cancelled.'}
  }
  function Set-PMMAnalyzeProgress([int]$Current,[int]$Total,[string]$Message,[switch]$Indeterminate){
    Write-PMMJsonAtomic (Join-Path $job 'progress.json') @{jobId=$JobId;status='Analyzing';current=$Current;total=$Total;message=$Message}
  }
  function Set-PMMBuildProgress([int]$Current,[int]$Total,[string]$Message,[switch]$Indeterminate){
    Write-PMMJsonAtomic (Join-Path $job 'progress.json') @{jobId=$JobId;status='Building';current=$Current;total=$Total;message=$Message}
  }
  Invoke-PMMScan -NoPatchSelection|Out-Null
  $plan=Assert-PMMPlanMatchesLibrary @(Get-LibraryMods)
  $fingerprint=Get-PMMAnalysisHash @($s.EvidenceRevision,$plan)
  Register-PMMRepairCandidate $SessionId $fingerprint $JobId|Out-Null
  $candidateDirectory=Join-Path $job 'candidate'
  $message=Build-PMMMerge -CandidateDirectory $candidateDirectory
  Assert-PMMRepairEvidenceCurrent $s
  Save-PMMRepairProcedure $SessionId Merge @(Get-ChildItem -LiteralPath $candidateDirectory -File|ForEach-Object{$_.FullName}) @{Service='Invoke-PMMScan + Build-PMMMerge';Plan=$plan;ModuleSnapshot=$lease.Snapshot} ValidatedContainerAndMergeProof|Out-Null
  Add-PMMRepairAttempt $SessionId Merge @{Fingerprint=$fingerprint} CandidateBuilt $message|Out-Null
  Write-PMMJsonAtomic (Join-Path $job 'result.json') @{jobId=$JobId;status='Complete';message=$message;runtime='UNPROVEN';deployed=$false;candidateFiles=@(Get-ChildItem -LiteralPath $candidateDirectory -File -ErrorAction SilentlyContinue|ForEach-Object{@{Path=$_.FullName;Sha256=(Get-Sha256 $_.FullName)}});moduleSnapshot=$lease.Snapshot}
}catch{
  if($lock){
    Add-PMMRepairAttempt $SessionId Merge @{JobId=$JobId} Blocked $_.Exception.Message|Out-Null
    Write-PMMJsonAtomic (Join-Path $job 'result.json') @{jobId=$JobId;status='Blocked';message=$_.Exception.Message;runtime='UNPROVEN';deployed=$false}
  }
}finally{if($lease){Complete-PMMModuleOperation $lease.Id};if($gate){$gate.Dispose()};if($lock){$lock.Dispose()}}
