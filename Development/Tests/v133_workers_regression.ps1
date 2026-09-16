Set-StrictMode -Version 2;$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'v133_analysis_regression.ps1')
. (Join-Path $Script:Root 'Modules/Analysis/MCP.Analysis.ps1')
$before=$script:checks
$worker=Join-Path $Script:Root 'Modules/Operations/OperationWorker.ps1'
$hostExe=Join-Path $env:SystemRoot 'System32/WindowsPowerShell/v1.0/powershell.exe'
function Run-Worker([string]$Operation,$Request){
  $job=Join-Path $fixture ('worker-'+[guid]::NewGuid().ToString('N'));[void][IO.Directory]::CreateDirectory($job)
  $requestPath=Join-PMMPath 'Cache' ('DeepRequests/'+[guid]::NewGuid().ToString('N')+'.json')
  Write-PMMJsonAtomic $requestPath $Request
  $resultPath=Join-Path $job 'result.json'
  & $hostExe -NoProfile -ExecutionPolicy Bypass -File $worker -Root $fixture -Operation $Operation -ProgressPath (Join-Path $job 'progress.json') -ResultPath $resultPath -RequestPath $requestPath|Out-Null
  if($LASTEXITCODE -ne 0){throw ('Worker failed: '+$Operation+' '+(Get-Content -LiteralPath $resultPath -Raw))}
  return (Read-PMMJsonFile $resultPath)
}
$result=Run-Worker DeepAnalysis @{Options=$options}
Assert ($result.Success -and $result.AnalysisId -like 'DA-*') 'Real DeepAnalysis worker failed.'
$caseResult=Run-Worker DeepCase @{AnalysisId=$result.AnalysisId;FindingIds=@();ExistingCaseId='';StartRepair=$false}
$repeatCase=Run-Worker DeepCase @{AnalysisId=$result.AnalysisId;FindingIds=@();ExistingCaseId='';StartRepair=$false}
Assert ($caseResult.Success -and $caseResult.CaseId -ceq $repeatCase.CaseId) 'Worker continuation duplicated its case.'
Assert ((Run-Worker Recovery @{}).Success) 'Recovery worker failed with no pending transaction.'
Set-PMMMCPEnabled $true
$s=New-PMMRepairSession $caseResult.CaseId $options;$s.Authorization.Build=$true;Save-PMMRepairSession $s
$Script:PMMMCPScopedCaseId=$s.CaseId;$Script:PMMMCPRepairSession=$s.Id
$argsObject=@{caseId=$s.CaseId;sessionId=$s.Id;evidenceRevision=$s.EvidenceRevision}
$job=Invoke-PMMAnalysisMCP pmm_merge_start $argsObject
$duplicate=Invoke-PMMAnalysisMCP pmm_merge_start $argsObject
Assert ($job.jobId -ceq $duplicate.jobId) 'Equivalent MCP requests launched different jobs.'
$deadline=[DateTime]::UtcNow.AddSeconds(45)
do{
  Start-Sleep -Milliseconds 100
  $jobResult=Invoke-PMMAnalysisMCP pmm_analysis_job @{caseId=$s.CaseId;sessionId=$s.Id;jobId=$job.jobId}
}while($jobResult.status -notin @('Blocked','Complete','Failed') -and [DateTime]::UtcNow -lt $deadline)
Assert ($jobResult.status -eq 'Blocked' -and -not$jobResult.deployed) 'Unavailable merge tools were not reported as a persistent block.'
Assert ((Get-PMMRepairSession $s.Id).Attempts.Count -eq 1) 'Failed merge history was lost.'
$last=Invoke-PMMAnalysisMCP pmm_merge_start $argsObject
Assert ($last.jobId -ceq $job.jobId -and $last.status -eq 'Blocked') 'Retry did not return the preserved result.'
# Real repak round-trip of harmless fixture content; no game files or network.
Copy-Item (Join-Path $repo 'PMM/Engine') (Join-Path $fixture 'Engine') -Recurse
$inputRoot=Join-Path $fixture 'input';[void][IO.Directory]::CreateDirectory($inputRoot)
[IO.File]::WriteAllText((Join-Path $inputRoot 'Fixture.txt'),'original')
$library=Join-Path (Get-LibraryRoot) 'Fixture';[void][IO.Directory]::CreateDirectory($library)
$originalPak=Join-Path $library 'Fixture.pak';Pack-Pak $inputRoot $originalPak
[IO.File]::WriteAllText((Join-Path $inputRoot 'Fixture.txt'),'updated')
$newPak=Join-Path $fixture 'updated.pak';Pack-Pak $inputRoot $newPak
$hash=Get-Sha256 $originalPak;$updateHash=Get-Sha256 $newPak
$report=Invoke-PMMDeepAnalysis $options;$case=New-PMMCaseFromDeepAnalysis $report.Id
$auto=$options|ConvertTo-Json|ConvertFrom-Json;$auto.AutomaticSolution=$true
$s=New-PMMRepairSession $case.CaseId $auto
$archive=Join-Path $fixture 'author.zip'
Add-Type -AssemblyName System.IO.Compression.FileSystem,System.IO.Compression
$zip=[IO.Compression.ZipFile]::Open($archive,[IO.Compression.ZipArchiveMode]::Create)
try{[IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip,$newPak,'nested/Fixture.pak')|Out-Null}finally{$zip.Dispose()}
$record=[pscustomobject]@{CaseId=$case.CaseId;EvidenceRevision=$s.EvidenceRevision;OriginalSha256=$hash;Path=$archive;Sha256=(Get-Sha256 $archive);Update=@{Mod='Fixture.pak';Candidate=@{AssetName='author.zip'}}}
$selected=Get-PMMSelectedPatchName
$candidate=Test-PMMStagedUpdate $record $s.Id
Assert ($candidate.Status -eq 'STAGED_REANALYZED' -and -not$candidate.Applied -and $candidate.PakSha256 -ceq $updateHash) 'Staged update bytes/reanalysis failed.'
Assert ((Get-Sha256 $originalPak) -ceq $hash -and (Get-PMMSelectedPatchName) -ceq $selected) 'Staged update changed the source or selection.'
$proposed=Read-PMMDeepAnalysis $candidate.ProposedAnalysisId
Assert ($proposed.Snapshot.Library[0].Hash -ceq $hash) 'Proposed set mutated the recorded original library.'
Assert ($proposed.Snapshot.Scenario -eq 'ProposedUpdateNotApplied' -and $proposed.Snapshot.Active[0].Hash -ceq $updateHash) 'Proposed analysis used the old provider.'
Reject {Test-PMMStagedUpdate $record $s.Id} 'Retry overwrote existing candidate files.'
Assert ((Get-Sha256 $candidate.PakPath) -ceq $updateHash) 'Refused replay damaged the candidate.'
$procedures=@(Get-PMMRepairProcedures $case.CaseId)
Assert ($procedures.Count -eq 1 -and $procedures[0].Runtime -eq 'UNPROVEN' -and -not$procedures[0].AutomaticEligible) 'Reproducible local procedure was missing or claimed game proof.'
$pakBytes=[IO.File]::ReadAllBytes($candidate.PakPath);[IO.File]::AppendAllText($candidate.PakPath,'tamper')
Assert (@(Get-PMMRepairProcedures $case.CaseId).Count -eq 0) 'Changed candidate remained an applicable known procedure.'
[IO.File]::WriteAllBytes($candidate.PakPath,$pakBytes)
Write-Output ('PASS workers133: '+($script:checks-$before)+' worker/job/staged-update checks; '+$fixture)
