# Versioned capability descriptions wrap the existing validated providers.
function Get-PMMToolAdapterManifest {
    $manifest=Read-PMMKnowledgeJson (Join-Path $Script:Root 'Modules/Tools/adapters.json')
    if($manifest.schema -cne 'PMM_TOOL_ADAPTERS_V1' -or $manifest.contractVersion -ne 1){throw 'Unsupported tool adapter contract.'}
    return $manifest
}
function Get-PMMToolCapabilities {
    $enabled=$false
    if(Get-Command Get-PMMMCPEnabled -ErrorAction SilentlyContinue){$enabled=Get-PMMMCPEnabled}
    foreach($adapter in (Get-PMMToolAdapterManifest).adapters){
        $available=$false;$reason='Enable local tools in AI settings.';$status='PendingConfiguration'
        if($adapter.id -eq 'scalar' -and $enabled){
            try{$dotnet=Get-PMMMCPDotnet;$available=(Test-Path (Join-Path $Script:Root 'Engine\AssetTools\PMM.AssetTools.dll')) -and (Test-Path (Join-Path $Script:Root 'Engine\repak.exe'));$reason='Only parsed numeric and Boolean properties; source-family verification is required per edit.'}catch{$reason=$_.Exception.Message}
        }
        if($adapter.id -eq 'unreal' -and $enabled){
            try{$state=Get-PMMUnrealStatus;$available=[bool]$state.readyToPrepare;$reason=if($available){[string]$state.verification}else{'Configure: '+(@($state.missing) -join ', ')}}catch{$reason=$_.Exception.Message}
        }
        if($available){$status='Available'}
        [pscustomobject]@{Id=$adapter.id;Version=$adapter.version;ContractVersion=1;Label=$adapter.label;Status=$status;Capabilities=@($adapter.capabilities);Unsupported=@($adapter.unsupported);Operations=@($adapter.operations.PSObject.Properties.Name);Cancellation=$adapter.cancellation;Detail=$reason}
    }
}
function New-PMMToolRequest([string]$AdapterId,[string]$Operation,[string]$CaseId,$Arguments) {
    $adapter=@((Get-PMMToolAdapterManifest).adapters|Where-Object id -CEQ $AdapterId)
    if($adapter.Count -ne 1 -or -not$adapter[0].operations.PSObject.Properties[$Operation]){throw 'Tool capability is not supported.'}
    [void](Get-PMMMCPCase $CaseId)
    $argsCopy=if($Arguments){$Arguments|ConvertTo-Json -Depth 15|ConvertFrom-Json}else{[pscustomobject]@{}}
    if($argsCopy.PSObject.Properties['caseId'] -and $argsCopy.caseId -cne $CaseId){throw 'Tool input belongs to a different case.'}
    $argsCopy|Add-Member -NotePropertyName caseId -NotePropertyValue $CaseId -Force
    $tool=[string]$adapter[0].operations.$Operation
    $definition=@(Get-PMMMCPTools|Where-Object name -CEQ $tool)
    if($definition.Count -ne 1){throw 'Provider is unavailable.'}
    $revision=''
    if(Get-Command Get-PMMCaseContract -ErrorAction SilentlyContinue){$revision=[string](Get-PMMCaseContract (Get-PMMAIIOCase $CaseId)).CurrentEvidenceRevision}
    if($tool -eq 'pmm_asset_edit' -and $revision){
        if($argsCopy.PSObject.Properties['evidenceRevision'] -and $argsCopy.evidenceRevision -cne $revision){throw 'Tool input evidence is obsolete.'}
        $argsCopy|Add-Member -NotePropertyName evidenceRevision -NotePropertyValue $revision -Force
    }
    Assert-PMMMCPArguments $definition[0] $argsCopy
    return [pscustomobject]@{Schema='PMM_TOOL_REQUEST_V1';RequestId=[guid]::NewGuid().ToString('N');AdapterId=$AdapterId;AdapterVersion=$adapter[0].version;ContractVersion=1;Operation=$Operation;Tool=$tool;CaseId=$CaseId;EvidenceRevisionId=$revision;Arguments=$argsCopy}
}
function Invoke-PMMToolOperation {
    param($Request,[scriptblock]$ProgressCallback=$null,[scriptblock]$CancellationRequested=$null)
    if($Request.Schema -cne 'PMM_TOOL_REQUEST_V1'){throw 'Invalid tool request.'}
    $verified=New-PMMToolRequest $Request.AdapterId $Request.Operation $Request.CaseId $Request.Arguments
    if($Request.Tool -cne $verified.Tool -or $Request.AdapterVersion -cne $verified.AdapterVersion -or $Request.EvidenceRevisionId -cne $verified.EvidenceRevisionId){throw 'Tool request is obsolete. Prepare it again.'}
    if($CancellationRequested -and (& $CancellationRequested)){return [pscustomobject]@{Status='Cancelled';CaseId=$Request.CaseId}}
    if($ProgressCallback){& $ProgressCallback ([pscustomobject]@{Phase='Starting';Indeterminate=$true;Message=$Request.Tool})}
    try{
        $result=Invoke-PMMMCPTool $Request.Tool $Request.Arguments
        if($CancellationRequested -and (& $CancellationRequested)){
            $pendingJob=[string](Get-PMMKnowledgeField $result 'jobId' '')
            if($pendingJob -and $Request.AdapterId -eq 'unreal'){Invoke-PMMMCPTool 'pmm_unreal_cancel' ([pscustomobject]@{caseId=$Request.CaseId;jobId=$pendingJob})|Out-Null}
            return [pscustomobject]@{Schema='PMM_TOOL_RESULT_V1';RequestId=$Request.RequestId;CaseId=$Request.CaseId;AdapterId=$Request.AdapterId;EvidenceRevisionId=$Request.EvidenceRevisionId;JobId=$pendingJob;Status=$(if($pendingJob){'Running'}else{'Cancelled'});CancellationRequested=$true;Result=$result}
        }
        $candidate=[string](Get-PMMKnowledgeField $result 'candidateId' '')
        if($candidate){
            # Pin at operation time, never infer a revision when discovering legacy outputs.
            if($Request.AdapterId -eq 'scalar'){
                $dir=Get-PMMMCPAssetCandidate $Request.CaseId $candidate;$path=Join-Path $dir 'candidate.json'
                $manifest=Read-PMMKnowledgeJson $path
                $existing=[string](Get-PMMKnowledgeField $manifest 'EvidenceRevisionId' '')
                if($existing -and $existing -cne $Request.EvidenceRevisionId){throw 'Candidate belongs to an earlier evidence revision.'}
                $manifest|Add-Member -NotePropertyName EvidenceRevisionId -NotePropertyValue $Request.EvidenceRevisionId -Force
                Write-PMMKnowledgeJson $path $manifest
            }
        }
        if($Request.Operation -eq 'build'){[void]@(Sync-PMMGeneratedCandidateLibrary $Request.CaseId)}
        $job=[string](Get-PMMKnowledgeField $result 'jobId' '')
        if($ProgressCallback){& $ProgressCallback ([pscustomobject]@{Phase=$(if($job){'Running'}else{'Complete'});Indeterminate=[bool]$job;Message=[string](Get-PMMKnowledgeField $result 'status' 'Complete')})}
        return [pscustomobject]@{Schema='PMM_TOOL_RESULT_V1';RequestId=$Request.RequestId;CaseId=$Request.CaseId;AdapterId=$Request.AdapterId;EvidenceRevisionId=$Request.EvidenceRevisionId;JobId=$job;Status=$(if($job){'Running'}else{'Complete'});Result=$result}
    }catch{
        $failedId='attempt-'+$Request.RequestId
        Register-PMMKnowledgeCandidate -CaseId $Request.CaseId -CandidateId $failedId -EvidenceRevisionId $Request.EvidenceRevisionId -TechnicalStatus Rejected -Outcome ('Tool failed: '+$_.Exception.Message) -Objective ([string]$Request.Operation)|Out-Null
        throw
    }
}
function Get-PMMToolOperation($Operation) {
    if($Operation.Schema -ne 'PMM_TOOL_RESULT_V1'){throw 'Invalid tool operation handle.'}
    if(-not$Operation.JobId){return $Operation}
    if($Operation.AdapterId -ne 'unreal'){throw 'Unknown asynchronous provider.'}
    $result=Get-PMMUnrealJob ([pscustomobject]@{caseId=$Operation.CaseId;jobId=$Operation.JobId;waitSeconds=0})
    return [pscustomobject]@{Status=[string]$result.status;Message=[string](Get-PMMKnowledgeField $result 'message' '');CaseId=$Operation.CaseId;JobId=$Operation.JobId;Result=$result}
}
function Stop-PMMToolOperation($Operation) {
    if($Operation.Schema -ne 'PMM_TOOL_RESULT_V1'){throw 'Invalid tool operation handle.'}
    if(-not$Operation.JobId){return [pscustomobject]@{Status='AlreadyFinished'}}
    if($Operation.AdapterId -ne 'unreal'){throw 'Provider does not support cancellation while running.'}
    return (Invoke-PMMMCPTool 'pmm_unreal_cancel' ([pscustomobject]@{caseId=$Operation.CaseId;jobId=$Operation.JobId}))
}


function Enter-PMMToolBackgroundLock([string]$CancelPath='',[int]$TimeoutSeconds=300) {
    $path=Join-Path (Get-PMMPath 'Cache') 'PMM.background-operation.lock'
    [void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($path))
    $clock=[Diagnostics.Stopwatch]::StartNew()
    while($true){
        if($CancelPath -and (Test-Path -LiteralPath $CancelPath)){throw [OperationCanceledException]::new('Cancelled while waiting for another PMM operation.')}
        try{return [IO.File]::Open($path,[IO.FileMode]::OpenOrCreate,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)}
        catch [IO.IOException]{if($clock.Elapsed.TotalSeconds -ge $TimeoutSeconds){throw 'Another PMM operation is still running. Retry after it finishes.'};Start-Sleep -Milliseconds 200}
    }
}

