# Model routing is a local decision. Metadata requests do not start inference turns.
function New-PMMAIPolicy {
  return [pscustomobject]@{Schema='PMM_AI_POLICY_V1';InternalEnabled=$false;Profile='Auto';MaxStage='Routine';AllowApiBilling=$false;RoutineModel='gpt-5.6-luna';RoutineEffort='low';RepairModel='gpt-5.6-terra';RepairEffort='medium';ComplexModel='gpt-5.6-sol';ComplexEffort='high';ServiceTier='default'}
}
function Get-PMMAIPolicy {
  $path=Join-PMMPath 'State' 'ai-policy.json'
  if(Test-Path -LiteralPath $path){return (Read-PMMJsonFile $path -Schema PMM_AI_POLICY_V1)}
  return (New-PMMAIPolicy)
}
function Save-PMMAIPolicy($Policy) {
  if($Policy.Profile -notin @('Auto','Free','Paid','ManualChat') -or $Policy.MaxStage -notin @('Routine','Repair','Complex') -or $Policy.AllowApiBilling -isnot [bool]){throw 'Invalid AI policy.'}
  if($Policy.ServiceTier -cne 'default'){throw 'PMM automatic requests use standard speed.'}
  foreach($stage in @('Routine','Repair','Complex')){
    if($Policy.($stage+'Model') -notmatch '^[a-zA-Z0-9._-]{1,100}$' -or $Policy.($stage+'Effort') -notin @('none','minimal','low','medium','high','xhigh','max','ultra')){throw 'Invalid model or effort preference.'}
  }
  Write-PMMJsonAtomic (Join-PMMPath 'State' 'ai-policy.json') $Policy -Schema PMM_AI_POLICY_V1
}
function Get-PMMAICapabilities($Client) {
  $account=Invoke-PMMAppServerRequest $Client 'account/read' @{refreshToken=$false}
  $models=[Collections.Generic.List[object]]::new();$cursor=$null;$pages=0
  do{
    $parameters=@{limit=100;includeHidden=$false};if($cursor){$parameters.cursor=$cursor}
    $page=Invoke-PMMAppServerRequest $Client 'model/list' $parameters
    foreach($model in $page.data){$models.Add($model)}
    $cursor=$page.nextCursor;$pages++
  }while($cursor -and $pages -lt 10)
  if($cursor){throw 'Model catalog is incomplete; automatic model selection is paused.'}
  $limits=$null;$limitStatus='Unavailable'
  try{
    $rate=Invoke-PMMAppServerRequest $Client 'account/rateLimits/read' @{}
    $limits=Get-PMMAnalysisValue $rate rateLimitsByLimitId $null
    if(-not$limits){$limits=@{codex=(Get-PMMAnalysisValue $rate rateLimits $null)}}
    $limitStatus='Reported'
  }catch{}
  # Never persist email, account identifiers, tokens or credentials.
  $result=[pscustomobject]@{Schema='PMM_AI_CAPABILITIES_V1';Authenticated=($null -ne $account.account);AuthType=(Get-PMMAnalysisValue $account.account type 'Unknown');Plan=(Get-PMMAnalysisValue $account.account planType 'Unknown');Models=$models.ToArray();Limits=$limits;LimitStatus=$limitStatus;Utc=[DateTime]::UtcNow.ToString('o');ChatAutomaticControl=$false}
  Write-PMMJsonAtomic (Join-PMMPath 'State' 'ai-capabilities.json') $result -Depth 20
  return $result
}
function Resolve-PMMAIRoute($Policy,$Capabilities,[ValidateSet('Routine','Repair','Complex')][string]$TaskKind='Routine') {
  if($Policy.Profile -eq 'ManualChat'){return [pscustomobject]@{Status='Manual';TaskKind=$TaskKind;Model='User-selected in ChatGPT';Effort='Not controlled by PMM';ServiceTier='Not controlled by PMM';Reason='Manual chat has separate availability and limits. No automatic delivery or zero-usage guarantee.'}}
  if(-not$Capabilities.Authenticated){throw 'Sign in before requesting AI work.'}
  if($Capabilities.AuthType -eq 'apiKey' -and -not$Policy.AllowApiBilling){throw 'The connected runtime uses API billing. Enable that separate cost option or sign in with ChatGPT.'}
  if($Capabilities.AuthType -notin @('chatgpt','apiKey')){throw 'This authentication/billing mode needs an explicitly supported adapter.'}
  $ranks=@{Routine=0;Repair=1;Complex=2}
  if($ranks[$TaskKind] -gt $ranks[$Policy.MaxStage]){throw ('This task requires '+$TaskKind+' reasoning. Its escalation is not authorized by the AI policy; enable that stage or continue manually.')}
  $effectiveProfile=if($Policy.Profile -eq 'Free' -or ($Capabilities.AuthType -eq 'chatgpt' -and $Capabilities.Plan -in @('free','go','unknown','Unknown'))){'Free'}else{'Paid'}
  if($effectiveProfile -eq 'Free' -and $TaskKind -ne 'Routine'){throw 'The free/conservative profile permits routine AI work only. Continue this complex step manually or refresh the detected account access.'}
  $modelName=[string]$Policy.($TaskKind+'Model');$effort=[string]$Policy.($TaskKind+'Effort')
  $available=@($Capabilities.Models|Where-Object{$_.model -ieq $modelName -and -not(Get-PMMAnalysisValue $_ hidden $false)})
  if($available.Count -eq 0){throw ('Model '+$modelName+' was not found in the detected account catalog. Open AI level / connection, check plan and models, and select an available model.')}
  if($available.Count -gt 1){throw ('The detected catalog contains multiple entries for model '+$modelName+'. Refresh the model list before continuing.')}
  $modelName=[string]$available[0].model
  if($effort -notin @($available[0].supportedReasoningEfforts|ForEach-Object{$_.reasoningEffort})){throw ('Model '+$modelName+' does not advertise effort '+$effort+'. Select a supported level.')}
  $buckets=@()
  if($Capabilities.Limits){
    $names=if($Capabilities.Limits -is [Collections.IDictionary]){@($Capabilities.Limits.Keys)}else{@($Capabilities.Limits.PSObject.Properties.Name)}
    foreach($name in $names){
      # Check the shared bucket and this model's bucket; unrelated model exhaustion is not a block.
      if($name -eq 'codex' -or $name -eq $modelName){$buckets+=,(Get-PMMAnalysisValue $Capabilities.Limits $name $null)}
    }
  }
  foreach($bucket in $buckets){
    if(-not$bucket){continue}
    if(Get-PMMAnalysisValue $bucket spendControlReached $false){throw 'The account spending control is reached. No AI turn was started.'}
    foreach($window in @('primary','secondary')){
      $value=Get-PMMAnalysisValue $bucket $window $null
      if($value -and $null -ne (Get-PMMAnalysisValue $value usedPercent $null) -and [double]$value.usedPercent -ge 100){
        $reset=Get-PMMAnalysisValue $value resetsAt 0
        if(-not$reset -or [DateTimeOffset]::FromUnixTimeSeconds([long]$reset) -gt [DateTimeOffset]::UtcNow){throw 'The account/model usage limit is reached. PMM pauses instead of spending additional credits or switching models.'}
      }
    }
  }
  return [pscustomobject]@{Status='Ready';TaskKind=$TaskKind;Model=$modelName;Effort=$effort;ServiceTier='default';DetectedPlan=$Capabilities.Plan;EffectiveProfile=$effectiveProfile;AuthType=$Capabilities.AuthType;LimitsStatus=$Capabilities.LimitStatus;Reason=$(switch($TaskKind){Routine{'Bounded triage, updates, known procedures, deterministic PMM jobs and concise reports.'}Repair{'Diagnosis and adaptation after a recorded routine-stage block.'}Complex{'Complex repair design after a documented capability or reasoning gap.'}});ExecutionTelemetry='Requested settings; verify server acknowledgement before starting a turn.'}
}
function Assert-PMMAIRouteAcknowledged($Route,$Response) {
  if([string]$Response.model -cne $Route.Model -or [string]$Response.reasoningEffort -cne $Route.Effort){throw 'The agent server acknowledged different model/effort settings. No repair turn was started.'}
  $tier=[string](Get-PMMAnalysisValue $Response serviceTier '')
  if($tier -and $tier -ne 'default'){throw 'The server retained a nonstandard speed tier. No repair turn was started.'}
}
function Request-PMMAgentStage([string]$SessionId,[string]$CaseId,[string]$Revision,[ValidateSet('Repair','Complex')][string]$TaskKind,[string]$Reason) {
  $session=Assert-PMMRepairAuthorization $SessionId $CaseId $Revision Research
  $current=[string](Get-PMMAnalysisValue $session CurrentAITask 'Routine')
  $rank=@{Routine=0;Repair=1;Complex=2}
  if($rank[$TaskKind] -le $rank[$current]){throw 'Escalation must address a harder next stage; equivalent attempts are not repeated.'}
  if([string]::IsNullOrWhiteSpace($Reason) -or $Reason.Length -gt 2000){throw 'A specific bounded explanation is required.'}
  if(@($session.Attempts|Where-Object{$_.Outcome -in @('Failed','Blocked','NeedsFunctionalTest')}).Count -eq 0){throw 'Record the concrete blocked or failed attempt before requesting more reasoning.'}
  $path=Join-Path (Get-PMMRepairSessionRoot $SessionId) ('next-agent-'+$current+'.json')
  $record=@{SessionId=$SessionId;EvidenceRevision=$Revision;From=$current;TaskKind=$TaskKind;Reason=$Reason}
  $lock=Enter-PMMAnalysisLock ($path+'.lock')
  try{
    if(Test-Path -LiteralPath $path){return (Read-PMMJsonFile $path)}
    Write-PMMJsonAtomic $path $record
  }finally{$lock.Dispose()}
  return @{TaskKind=$TaskKind;Status='Requested';Message='Finish this turn. PMM checks account access and the user cost ceiling before continuing the same conversation.'}
}
function Export-PMMManualChatRequest([string]$SessionId) {
  $session=Get-PMMRepairSession $SessionId
  Assert-PMMRepairAuthorization $SessionId $session.CaseId $session.EvidenceRevision Research|Out-Null
  $path=Join-Path (Get-PMMRepairSessionRoot $SessionId) 'manual-chat-request.txt'
  $text='PMM case '+$session.CaseId+'; evidence '+$session.EvidenceRevision+'. Read the attached selected findings and report. Explain likely causes and required evidence; do not claim a static result proves a game repair. Prefer author updates, known exact-input solutions, repair, then replacement preserving functions. Return your proposed procedure to this PMM case. PMM has not verified which chat model is selected or delivered this message automatically.'
  $revision=Get-PMMCaseEvidenceRevision $session.CaseId
  if((Get-PMMAnalysisValue $revision.Evidence Kind '') -eq 'DeepAnalysis'){
    $report=Read-PMMDeepAnalysis $revision.Evidence.AnalysisId
    $text+=[Environment]::NewLine+($report.Findings|Select-Object -First 40|ConvertTo-Json -Depth 12)
  }
  [IO.File]::WriteAllText($path,$text,[Text.UTF8Encoding]::new($true))
  $session.Status='NeedsManualChat';$session.LastMessage='Manual chat request prepared: '+$path+'. Delivery and model selection require the user.';Save-PMMRepairSession $session
  return $session
}
