param([string]$Root=([IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))))
Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
$app=Join-Path $Root 'PMM'
$fixture=Join-Path ([IO.Path]::GetTempPath()) ('PMM-ToolContract-'+[guid]::NewGuid().ToString('N'))
$count=0
function Assert-T([bool]$Condition,[string]$Message){$script:count++;if(-not$Condition){throw $Message}}
function Reject-T([scriptblock]$Action,[string]$Message){$rejected=$false;try{& $Action|Out-Null}catch{$rejected=$true};Assert-T $rejected $Message}
[void][IO.Directory]::CreateDirectory($fixture)
try{
    Copy-Item -LiteralPath (Join-Path $app 'Modules') -Destination (Join-Path $fixture 'Modules') -Recurse
    $Script:Root=$fixture
    . (Join-Path $fixture 'Modules\Shared\Paths.ps1')
    Initialize-PMMPaths $fixture|Out-Null
    foreach($module in @('Shared\Common.ps1','Shared\Persistence.ps1','MCP\MCP.Service.ps1','AIIO\AIIO.SessionService.ps1','AIIO\AIIO.CaseWorkspaceService.ps1','Cases\CaseService.ps1','Knowledge\Knowledge.Service.ps1','Tools\Tools.Service.ps1')){
        . (Join-Path $fixture ('Modules\'+$module))|Out-Null
    }
    Set-PMMMCPEnabled $true
    $case=New-PMMContextCase -Type NewMod -Title 'Tool contract fixture' -Description 'Synthetic case; no game content.'
    $request=New-PMMToolRequest -AdapterId scalar -Operation edit -CaseId $case.CaseId -Arguments ([pscustomobject]@{logicalPath='Pal/Content/Test.uasset';path='/Exports/0/Data/Health';expected='1';value='2'})
    Assert-T ($request.EvidenceRevisionId -eq $case.CurrentEvidenceRevision -and $request.Arguments.evidenceRevision -eq $case.CurrentEvidenceRevision) 'Tool must pin case revision into provider input.'
    Reject-T {New-PMMToolRequest scalar edit $case.CaseId ([pscustomobject]@{logicalPath='Pal/Content/Test.uasset';path='/Health';expected='1';value='2';command='powershell'})} 'Provider schema must reject arbitrary commands.'
    Reject-T {New-PMMToolRequest unreal models $case.CaseId ([pscustomobject]@{})} 'Unimplemented authoring must not be dispatched.'
    $newRevision=Add-PMMCaseEvidenceRevision -CaseId $case.CaseId -Evidence ([ordered]@{Kind='ManualContext';Objective='Changed evidence';Mods=@();RelatedCaseIds=@()})
    Assert-T ($newRevision -ne $request.EvidenceRevisionId) 'Fixture evidence must advance.'
    Reject-T {Invoke-PMMToolOperation -Request $request} 'Stale tool requests must fail before launching a provider.'
    $job=Join-Path (Get-PMMPath 'Temp') 'contract-worker';[void][IO.Directory]::CreateDirectory($job)
    $requestPath=Join-Path $job 'request.json';$resultPath=Join-Path $job 'result.json';Write-PMMKnowledgeJson $requestPath $request
    $hostExe=Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
    $worker=Join-Path $fixture 'Modules\Tools\Tool.Worker.ps1'
    & $hostExe -NoProfile -NonInteractive -File $worker -Root $fixture -RequestPath $requestPath -ResultPath $resultPath
    $result=Read-PMMKnowledgeJson $resultPath
    Assert-T ($LASTEXITCODE -eq 1 -and $result.Status -eq 'Failed' -and $result.Error -match 'obsolete') 'Real isolated worker must reject obsolete revision and retain a structured error.'
    $syncResult=Join-Path $job 'sync-result.json'
    & $hostExe -NoProfile -NonInteractive -File $worker -Root $fixture -Mode SyncCandidates -CaseId $case.CaseId -ResultPath $syncResult
    $result=Read-PMMKnowledgeJson $syncResult
    Assert-T ($LASTEXITCODE -eq 0 -and $result.Status -eq 'Complete' -and @($result.Result).Count -eq 0) 'Real worker must handle zero generated candidates.'
    $scanResult=Join-Path $job 'scan-result.json'
    & $hostExe -NoProfile -NonInteractive -File $worker -Root $fixture -Mode ScanKnowledge -ResultPath $scanResult
    $result=Read-PMMKnowledgeJson $scanResult
    Assert-T ($LASTEXITCODE -eq 0 -and $result.Status -eq 'Complete' -and @($result.Result.Candidates).Count -eq 0 -and @($result.Result.Imports).Count -eq 0) 'Knowledge scan must return independent candidate and import lists.'
    $trialResult=Join-Path $job 'trial-result.json'
    & $hostExe -NoProfile -NonInteractive -File $worker -Root $fixture -Mode ValidateCandidate -CaseId $case.CaseId -CandidateId 'missing-candidate' -ResultPath $trialResult
    $result=Read-PMMKnowledgeJson $trialResult
    Assert-T ($LASTEXITCODE -eq 1 -and $result.Status -eq 'Failed') 'Trial validation must not invent an admissible candidate.'

    $contextRequest=Join-Path $job 'context-request.json';$contextResult=Join-Path $job 'context-result.json'
    $selectedPak=Join-Path $job 'selected.pak';[IO.File]::WriteAllText($selectedPak,'synthetic selected mod')
    Write-PMMKnowledgeJson $contextRequest ([pscustomobject]@{Type='Fix';Mods=@([pscustomobject]@{Name='selected.pak';Path=$selectedPak;Hash=('0'*64);Priority=1;Enabled=$false});Title='Created in worker';Description='Hash selected bytes in worker';Origin='Jugar'})
    & $hostExe -NoProfile -NonInteractive -File $worker -Root $fixture -Mode CreateContextCase -RequestPath $contextRequest -ResultPath $contextResult
    $result=Read-PMMKnowledgeJson $contextResult
    Assert-T ($LASTEXITCODE -eq 0 -and $result.Status -eq 'Complete' -and $result.Result.CaseId -match '^AICASE-' -and $result.Result.References.Mods[0].Sha256 -eq (Get-Sha256 $selectedPak)) 'Context worker must capture actual selected file hashes, not trust a stale UI cache.'

    $slot=Enter-PMMToolBackgroundLock -TimeoutSeconds 0
    try{Assert-T ($null -ne $slot) 'Worker must release shared operation lock after success and failure.'}finally{$slot.Dispose()}
    $cancel=Join-Path $job 'cancel';[IO.File]::WriteAllText($cancel,'cancel')
    $cancelResult=Join-Path $job 'cancel-result.json'
    & $hostExe -NoProfile -NonInteractive -File $worker -Root $fixture -Mode SyncCandidates -CaseId $case.CaseId -CancelPath $cancel -ResultPath $cancelResult
    $result=Read-PMMKnowledgeJson $cancelResult
    Assert-T ($LASTEXITCODE -eq 1 -and $result.Status -eq 'Cancelled') 'Worker cancellation must retain its distinct state.'
    Assert-T (@(Get-PMMKnowledgeCandidates $case.CaseId).Count -eq 0) 'Stale/cancelled requests must not manufacture candidate success.'
    # A provider can return an asynchronous job just as cancellation arrives.
    # Decorate that process boundary without starting Unreal; keep the real
    # request schema, revision binding, operation dispatch and poll wrapper.
    $cancelRequest=New-PMMToolRequest -AdapterId unreal -Operation prepare -CaseId $case.CaseId -Arguments ([pscustomobject]@{})
    $Script:ToolCancelRequested=$false;$Script:ToolProviderCancelCalls=0
    function Invoke-PMMMCPTool([string]$Name,$Arguments){
        if($Name -eq 'pmm_unreal_prepare'){$Script:ToolCancelRequested=$true;return [pscustomobject]@{jobId='fixture-job';status='STARTING'}}
        if($Name -eq 'pmm_unreal_cancel'){$Script:ToolProviderCancelCalls++;return [pscustomobject]@{status='CANCELLING'}}
        throw ('Unexpected fixture tool: '+$Name)
    }
    $cancelled=Invoke-PMMToolOperation -Request $cancelRequest -CancellationRequested {$Script:ToolCancelRequested}
    Assert-T ($cancelled.Status -eq 'Running' -and $cancelled.CancellationRequested -and $cancelled.JobId -eq 'fixture-job' -and $Script:ToolProviderCancelCalls -eq 1) 'An asynchronous cancellation request must retain the active handle until the provider actually stops.'
    function Get-PMMUnrealJob($Arguments){return [pscustomobject]@{status='CANCELLED';message='Fixture completed cooperative cancellation'}}
    $finished=Get-PMMToolOperation $cancelled
    Assert-T ($finished.Status -eq 'CANCELLED' -and $finished.CaseId -eq $case.CaseId) 'Polling must report the asynchronous cancellation only when terminal.'
    Write-Output ('PASS: '+$count+' real tool request/worker contract assertions; no game or Unreal launched.')
}finally{
    $full=[IO.Path]::GetFullPath($fixture);$temp=[IO.Path]::GetFullPath([IO.Path]::GetTempPath())
    if($full.StartsWith($temp,[StringComparison]::OrdinalIgnoreCase) -and [IO.Path]::GetFileName($full).StartsWith('PMM-ToolContract-')){Remove-Item -LiteralPath $full -Recurse -Force}
}

