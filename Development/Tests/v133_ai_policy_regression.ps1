param([switch]$Probe)
Set-StrictMode -Version 2;$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'v133_analysis_regression.ps1')
$before=$script:checks
$policy=New-PMMAIPolicy
$catalog=@(foreach($name in @('gpt-5.6-luna','gpt-5.6-terra','gpt-5.6-sol')){[pscustomobject]@{model=$name;hidden=$false;supportedReasoningEfforts=@(@{reasoningEffort='low'},@{reasoningEffort='medium'},@{reasoningEffort='high'})}})
$cap=[pscustomobject]@{Authenticated=$true;AuthType='chatgpt';Plan='plus';Models=$catalog;Limits=@{};LimitStatus='Unavailable'}
$route=Resolve-PMMAIRoute $policy $cap Routine
Assert ($route.Model -eq 'gpt-5.6-luna' -and $route.Effort -eq 'low' -and $route.ServiceTier -eq 'default') 'Routine work inherited an expensive model/effort/speed.'
Reject {Resolve-PMMAIRoute $policy $cap Repair} 'Escalation exceeded the default ceiling.'
$policy.MaxStage='Repair'
Assert ((Resolve-PMMAIRoute $policy $cap Repair).Model -eq 'gpt-5.6-terra') 'Repair did not use the configured appropriate model.'
$policy.MaxStage='Complex'
Assert ((Resolve-PMMAIRoute $policy $cap Complex).Model -eq 'gpt-5.6-sol') 'Complex work did not use the configured model.'
$cap.Plan='free';$policy.Profile='Paid'
Reject {Resolve-PMMAIRoute $policy $cap Complex} 'A paid profile upgraded a free account.'
Assert ((Resolve-PMMAIRoute $policy $cap Routine).EffectiveProfile -eq 'Free') 'Detected free access was ignored.'
$cap.Plan='plus';$cap.Models=@($catalog|Where-Object model -ne 'gpt-5.6-luna')
Reject {Resolve-PMMAIRoute $policy $cap Routine} 'Missing Luna silently fell back to an expensive default.'
$cap.Models=$catalog;$cap.Models[0].supportedReasoningEfforts=@(@{reasoningEffort='medium'})
Reject {Resolve-PMMAIRoute $policy $cap Routine} 'Unsupported low effort silently escalated.'
$cap.Models[0].supportedReasoningEfforts=@(@{reasoningEffort='low'})
$cap.AuthType='apiKey'
Reject {Resolve-PMMAIRoute $policy $cap Routine} 'API billing was implicitly authorized.'
$policy.AllowApiBilling=$true
Assert ((Resolve-PMMAIRoute $policy $cap Routine).AuthType -eq 'apiKey') 'Explicit API cost permission was ignored.'
$cap.Plan='Unknown'
Assert ((Resolve-PMMAIRoute $policy $cap Complex).Model -eq 'gpt-5.6-sol') 'Explicit API billing and a complex ceiling were treated as a free ChatGPT plan.'
$cap.AuthType='chatgpt';$cap.Plan='plus';$policy.AllowApiBilling=$false
$cap.Limits=@{codex=@{primary=@{usedPercent=100;resetsAt=[DateTimeOffset]::UtcNow.AddHours(1).ToUnixTimeSeconds()}}}
Reject {Resolve-PMMAIRoute $policy $cap Routine} 'Exhausted allowance started another request.'
$cap.Limits=@{'gpt-6-astra'=@{primary=@{usedPercent=100}}}
Assert ((Resolve-PMMAIRoute $policy $cap Routine).Model -eq 'gpt-5.6-luna') 'Unrelated model quota blocked Luna.'
$cap.Limits=@{};$cap.Authenticated=$false
Reject {Resolve-PMMAIRoute $policy $cap Routine} 'Unauthenticated account started inference.'
$policy.Profile='ManualChat'
Assert ((Resolve-PMMAIRoute $policy $cap).Status -eq 'Manual') 'Manual chat mode started automatic inference.'
$policy=New-PMMAIPolicy;Save-PMMAIPolicy $policy
Assert ((Get-PMMAIPolicy).RoutineModel -eq 'gpt-5.6-luna') 'Model policy did not persist.'
Reject {Assert-PMMAIRouteAcknowledged $route @{model='gpt-6-astra';reasoningEffort='low'}} 'Unexpected server model was accepted.'
Reject {Assert-PMMAIRouteAcknowledged $route @{model=$route.Model;reasoningEffort='medium'}} 'Unexpected server effort was accepted.'
Reject {Assert-PMMAIRouteAcknowledged $route @{model=$route.Model;reasoningEffort=$route.Effort;serviceTier='priority'}} 'Inherited fast mode was accepted.'
Assert-PMMAIRouteAcknowledged $route @{model=$route.Model;reasoningEffort=$route.Effort;serviceTier='default'};$script:checks++
$report=Invoke-PMMDeepAnalysis $options;$case=New-PMMCaseFromDeepAnalysis $report.Id;$s=New-PMMRepairSession $case.CaseId $options
Reject {Request-PMMAgentStage $s.Id $case.CaseId $s.EvidenceRevision Repair 'Guess'} 'Reasoning escalation without a concrete blocked attempt was accepted.'
Add-PMMRepairAttempt $s.Id Diagnosis @{Inputs='fixture'} Blocked 'Opaque layout needs a repair design'|Out-Null
$next=Request-PMMAgentStage $s.Id $case.CaseId $s.EvidenceRevision Repair 'Opaque layout needs adaptation'
Assert ($next.TaskKind -eq 'Repair') 'Concrete escalation request was not preserved.'
$manual=Export-PMMManualChatRequest $s.Id
Assert ($manual.Status -eq 'NeedsManualChat' -and -not$manual.ThreadId) 'Manual transfer claimed an agent conversation or delivery.'
if($Probe){
  $c=$null
  try{
    $c=Start-PMMAppServer
    Invoke-PMMAppServerRequest $c initialize @{clientInfo=@{name='pmm';version='1.3.3'};capabilities=@{experimentalApi=$true}}|Out-Null
    Send-PMMAppServer $c initialized @{} -Notification
    $live=Get-PMMAICapabilities $c;$route=Resolve-PMMAIRoute (New-PMMAIPolicy) $live Routine
    $t=Invoke-PMMAppServerRequest $c 'thread/start' @{cwd=$fixture;model=$route.Model;serviceTier='default';config=@{model_reasoning_effort=$route.Effort;service_tier='default'};approvalPolicy='never';sandbox='read-only'}
    Assert-PMMAIRouteAcknowledged $route $t
    $turn=Invoke-PMMAppServerRequest $c 'turn/start' @{threadId=$t.thread.id;model=$route.Model;effort=$route.Effort;serviceTierForTurn='default';input=@(@{type='text';text='PMM routing test. Reply exactly PMM_LUNA_OK. No tools, research, delegation or file changes.'})}
    $watch=[Diagnostics.Stopwatch]::StartNew();$done=$false;$text=''
    while(-not$done -and $watch.Elapsed.TotalSeconds -lt 45){
      $m=if($c.Notifications.Count){$c.Notifications.Dequeue()}else{Receive-PMMAppServer $c 100}
      if(-not$m){continue}
      if((Get-PMMAnalysisValue $m method '') -eq 'item/agentMessage/delta'){$text+=$m.params.delta}
      if((Get-PMMAnalysisValue $m method '') -eq 'turn/completed' -and $m.params.turn.id -eq $turn.turn.id){$done=$true}
    }
    Assert ($done -and $text -match 'PMM_LUNA_OK') 'Cheap routing probe failed.'
    $record=@{ThreadId=$t.thread.id;TurnId=$turn.turn.id;Requested=$route;Acknowledged=@{Model=$t.model;Effort=$t.reasoningEffort;ServiceTier=$t.serviceTier};Completed=$done;Text=$text}
    Write-PMMJsonAtomic (Join-Path $repo 'Development/TestResults/ai133-routing-validation.json') $record -Depth 12
    Write-Output ('Verified live route: '+$t.model+' / '+$t.reasoningEffort+' / '+$t.serviceTier)
  }finally{Stop-PMMAppServer $c}
}
Write-Output ('PASS AI policy133: '+($script:checks-$before)+' routing/account/quota/acknowledgement checks.')
