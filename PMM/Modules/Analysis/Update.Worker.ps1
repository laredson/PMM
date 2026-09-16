param([string]$Root,[string]$SessionId,[string]$JobId)
Set-StrictMode -Version 2;$ErrorActionPreference='Stop';$Script:Root=[IO.Path]::GetFullPath($Root)
. (Join-Path $Script:Root 'Modules/Analysis/Services.ps1')
. (Join-Path $Script:Root 'Modules/Workbench.Services.ps1') -Profile Worker|Out-Null
if($JobId -notmatch '^[a-f0-9]{32}$'){throw 'Invalid job identifier.'}
$job=Join-Path (Get-PMMRepairSessionRoot $SessionId) ('Jobs/'+$JobId);$lock=$null;$gate=$null;$lease=$null
try{
  $lock=[IO.File]::Open((Join-Path $job 'worker.lock'),[IO.FileMode]::OpenOrCreate,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)
  $gate=Enter-PMMAnalysisLock (Join-PMMPath 'Cache' 'PMM.background-operation.lock') 1
  $lease=Start-PMMModuleOperation 'AuthorUpdate'
  $request=Read-PMMJsonFile (Join-Path $job 'request.json') -Schema PMM_UPDATE_JOB_V1
  $result=Save-PMMUpdateDownload $request.Update $request.CaseId $request.EvidenceRevision $request.SessionId
  Write-PMMJsonAtomic (Join-Path $job 'progress.json') @{jobId=$JobId;status='Reanalyzing';archiveSha256=$result.Sha256}
  $candidate=Test-PMMStagedUpdate $result $SessionId
  Write-PMMJsonAtomic (Join-Path $job 'result.json') @{jobId=$JobId;status='Complete';candidateId=$candidate.CandidateId;proposedAnalysisId=$candidate.ProposedAnalysisId;pakSha256=$candidate.PakSha256;statusDetail=$candidate.Status;runtime=$candidate.Runtime;removedResources=$candidate.RemovedResources;findings=$candidate.Findings;limitations=$candidate.Limitations}
}catch{if($lock){Write-PMMJsonAtomic (Join-Path $job 'result.json') @{jobId=$JobId;status='Failed';message=$_.Exception.Message}}else{throw}}
finally{if($lease){Complete-PMMModuleOperation $lease.Id};if($gate){$gate.Dispose()};if($lock){$lock.Dispose()}}
