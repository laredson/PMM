function Get-PMMAnalysisMCPDefinitions($CaseSchema) {
  $id=@{type='string';pattern='^DA-[a-f0-9]{32}$'}
  $session=@{type='string';pattern='^RS-[a-f0-9]{32}$'}
  $revision=@{type='string';pattern='^EV-[a-f0-9]{64}$'}
  return @(
    @('pmm_agent_next_stage','Request a harder reasoning stage after recording the concrete block. Finish the current turn; PMM enforces the account and user cost ceiling before continuing the same conversation.',@{caseId=$CaseSchema;sessionId=$session;evidenceRevision=$revision;taskKind=@{type='string';enum=@('Repair','Complex')};reason=@{type='string';maxLength=2000}},@('caseId','sessionId','evidenceRevision','taskKind','reason'),$false),
    @('pmm_merge_start','Analyze and build a compatibility candidate through the same PMM merge service as AUTO. Runs as a persistent cancellable job and never deploys.',@{caseId=$CaseSchema;sessionId=$session;evidenceRevision=$revision},@('caseId','sessionId','evidenceRevision'),$false),
    @('pmm_known_solutions','Read local knowledge candidates applicable to this exact case evidence. Static validation is not game proof.',@{caseId=$CaseSchema},@('caseId'),$true),
    @('pmm_deep_report','Read findings and coverage attached to this case; pages contain at most 40 findings.',@{caseId=$CaseSchema;analysisId=$id;offset=@{type='integer';minimum=0;maximum=100000}},@('caseId','analysisId'),$true),
    @('pmm_repair_get','Read the authorized persistent session, its limits, attempts and conversation.',@{caseId=$CaseSchema;sessionId=$session},@('caseId','sessionId'),$true),
    @('pmm_repair_attempt','Record a failed, blocked or validated attempt without claiming game proof.',@{caseId=$CaseSchema;sessionId=$session;evidenceRevision=$revision;kind=@{type='string';maxLength=100};detail=@{type='string';maxLength=4000};outcome=@{type='string';enum=@('Failed','Blocked','CandidateBuilt','StructuralPass','NeedsFunctionalTest')}},@('caseId','sessionId','evidenceRevision','kind','detail','outcome'),$false),
    @('pmm_runtime_capabilities','Read available runtime adapters and exact unverified prerequisites. This does not launch Palworld.',@{caseId=$CaseSchema},@('caseId'),$true),
    @('pmm_update_stage','Start a bounded update download job for a verified successor from this case report. Never deploys; reanalysis is mandatory.',@{caseId=$CaseSchema;sessionId=$session;evidenceRevision=$revision;analysisId=$id;modSha256=@{type='string';pattern='^[a-f0-9]{64}$'}},@('caseId','sessionId','evidenceRevision','analysisId','modSha256'),$false),
    @('pmm_analysis_job','Read a persistent analysis/update job result.',@{caseId=$CaseSchema;sessionId=$session;jobId=@{type='string';pattern='^[a-f0-9]{32}$'}},@('caseId','sessionId','jobId'),$true),
    @('pmm_repair_stop','Revoke repair-session mutations and interrupt the agent. Restore recorded temporary changes.',@{caseId=$CaseSchema;sessionId=$session},@('caseId','sessionId'),$false)
  )
}
function Assert-PMMReportCase([string]$CaseId,[string]$AnalysisId) {
  $evidence=Get-PMMCaseEvidenceRevision $CaseId
  if([string](Get-PMMAnalysisValue $evidence.Evidence AnalysisId '') -cne $AnalysisId){throw 'This report is not the current evidence of the scoped case.'}
  $path=Join-Path (Get-PMMAnalysisPath $AnalysisId) 'report.json'
  if((Get-Sha256 $path) -cne [string]$evidence.Evidence.ReportSha256){throw 'The report bytes no longer match this case evidence.'}
  return (Read-PMMDeepAnalysis $AnalysisId)
}
function Invoke-PMMAnalysisMCP([string]$Name,$Arguments) {
  Get-PMMMCPCase $Arguments.caseId|Out-Null
  if($Name -eq 'pmm_known_solutions'){
    $case=Get-PMMAIIOCase $Arguments.caseId
    return @{solutions=@(Get-PMMKnowledgeSuggestions $case.CurrentEvidenceRevision);procedures=@(Get-PMMRepairProcedures $Arguments.caseId|Select-Object -First 40);catalogContext=@(Get-PMMDeepKnowledgeContext $Arguments.caseId|Select-Object -First 40);remoteExchange='Local only; no configured remote receiver'}
  }
  if($Name -eq 'pmm_runtime_capabilities'){return (Get-PMMRuntimeCapabilities)}
  if($Name -eq 'pmm_deep_report'){
    $report=Assert-PMMReportCase $Arguments.caseId $Arguments.analysisId
    $offset=[int](Get-PMMAnalysisValue $Arguments offset 0)
    return @{analysisId=$report.Id;summary=$report.Summary;coverage=$report.Coverage;findings=@($report.Findings|Select-Object -Skip $offset -First 40);total=$report.Findings.Count;nextOffset=$(if($offset+40 -lt $report.Findings.Count){$offset+40}else{$null})}
  }
  if((Get-Variable PMMMCPRepairSession -Scope Script -ErrorAction SilentlyContinue) -and $Script:PMMMCPRepairSession -and $Arguments.sessionId -cne $Script:PMMMCPRepairSession){throw 'This connection is authorized for another repair session.'}
  $s=Get-PMMRepairSession $Arguments.sessionId
  if($s.CaseId -cne $Arguments.caseId){throw 'The repair session belongs to another case.'}
  switch($Name){
    pmm_agent_next_stage {return (Request-PMMAgentStage $s.Id $s.CaseId $Arguments.evidenceRevision $Arguments.taskKind $Arguments.reason)}
    pmm_repair_get {return $s}
    pmm_merge_start {
      Assert-PMMRepairAuthorization $s.Id $s.CaseId $Arguments.evidenceRevision Build|Out-Null
      $jobId=(Get-PMMAnalysisHash @($s.Id,$s.EvidenceRevision,'Merge')).Substring(0,32)
      $root=Join-Path (Get-PMMRepairSessionRoot $s.Id) ('Jobs/'+$jobId)
      $launchLock=Enter-PMMAnalysisLock ($root+'.launch.lock')
      try{
        $result=Join-Path $root 'result.json'
        if(Test-Path -LiteralPath $result){return (Read-PMMJsonFile $result)}
        if(Test-Path -LiteralPath (Join-Path $root 'request.json')){return @{jobId=$jobId;status='PendingOrInterrupted';message='Use the existing job; equivalent requests are not repeated.'}}
        [void][IO.Directory]::CreateDirectory($root)
        Write-PMMJsonAtomic (Join-Path $root 'request.json') @{CaseId=$s.CaseId;EvidenceRevision=$s.EvidenceRevision;SessionId=$s.Id}
        $worker=Join-Path $Script:Root 'Modules/Analysis/Merge.Worker.ps1'
        $workerArgs=@('-NoProfile','-ExecutionPolicy','Bypass','-File',$worker,'-Root',$Script:Root,'-SessionId',$s.Id,'-JobId',$jobId)
        Start-Process -FilePath (Join-Path $env:SystemRoot 'System32/WindowsPowerShell/v1.0/powershell.exe') -ArgumentList (@($workerArgs|ForEach-Object{ConvertTo-PMMMCPNativeArgument $_}) -join ' ') -WindowStyle Hidden|Out-Null
        return @{jobId=$jobId;sessionId=$s.Id;status='Started'}
      }finally{$launchLock.Dispose()}
    }
    pmm_repair_stop {return (Stop-PMMRepairSession $s.Id)}
    pmm_repair_attempt {
      Assert-PMMRepairAuthorization $s.Id $s.CaseId $Arguments.evidenceRevision Research|Out-Null
      return (Add-PMMRepairAttempt $s.Id $Arguments.kind @{Detail=$Arguments.detail} $Arguments.outcome $Arguments.detail)
    }
    pmm_update_stage {
      Assert-PMMRepairAuthorization $s.Id $s.CaseId $Arguments.evidenceRevision Download|Out-Null
      $report=Assert-PMMReportCase $s.CaseId $Arguments.analysisId
      $update=@($report.Updates|Where-Object{$_.LocalSha256 -eq $Arguments.modSha256 -and $_.Status -eq 'UPDATE_AVAILABLE'})
      if($update.Count -ne 1){throw 'No unique verified successor exists in this report.'}
      $jobId=Get-PMMAnalysisHash @($s.Id,$Arguments.analysisId,$Arguments.modSha256,$update[0].Candidate)
      $jobId=$jobId.Substring(0,32)
      $root=Join-Path (Get-PMMRepairSessionRoot $s.Id) ('Jobs/'+$jobId);$result=Join-Path $root 'result.json'
      $jobLock=Enter-PMMAnalysisLock ($root+'.launch.lock')
      try{
      if(Test-Path -LiteralPath $result){return (Read-PMMJsonFile $result)}
      if(Test-Path -LiteralPath (Join-Path $root 'request.json')){return @{jobId=$jobId;status='PendingOrRunning';retrySafe=$false}}
      [void][IO.Directory]::CreateDirectory($root)
      Write-PMMJsonAtomic (Join-Path $root 'request.json') @{Schema='PMM_UPDATE_JOB_V1';CaseId=$s.CaseId;SessionId=$s.Id;EvidenceRevision=$s.EvidenceRevision;Update=$update[0]}
      $worker=Join-Path $Script:Root 'Modules/Analysis/Update.Worker.ps1'
      $args=@('-NoProfile','-ExecutionPolicy','Bypass','-File',$worker,'-Root',$Script:Root,'-SessionId',$s.Id,'-JobId',$jobId)
      $line=(@($args|ForEach-Object{ConvertTo-PMMMCPNativeArgument $_}) -join ' ')
      Start-Process -FilePath (Join-Path $env:SystemRoot 'System32/WindowsPowerShell/v1.0/powershell.exe') -ArgumentList $line -WindowStyle Hidden|Out-Null
      return @{jobId=$jobId;status='Started';sessionId=$s.Id}
      }finally{$jobLock.Dispose()}
    }
    pmm_analysis_job {
      $path=Join-Path (Get-PMMRepairSessionRoot $s.Id) ('Jobs/'+$Arguments.jobId+'/result.json')
      if(Test-Path -LiteralPath $path){return (Read-PMMJsonFile $path)}
      $progress=Join-Path (Get-PMMRepairSessionRoot $s.Id) ('Jobs/'+$Arguments.jobId+'/progress.json')
      if(Test-Path -LiteralPath $progress){return (Read-PMMJsonFile $progress)}
      return @{jobId=$Arguments.jobId;status='PendingOrInterrupted';message='No completed result yet; cancellation is available for this session.'}
    }
  }
}
