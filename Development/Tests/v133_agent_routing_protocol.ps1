Set-StrictMode -Version 2;$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'v133_ai_policy_regression.ps1')
$before=$script:checks
$policy=New-PMMAIPolicy;Save-PMMAIPolicy $policy
$report=Invoke-PMMDeepAnalysis $options;$case=New-PMMCaseFromDeepAnalysis $report.Id;$s=New-PMMRepairSession $case.CaseId $options
$script:protocolSession=$s;$script:protocolCalls=[Collections.Generic.List[object]]::new();$script:protocolTurns=0
$script:protocolThread=[guid]::NewGuid().ToString()
function Start-PMMAppServer([string]$CaseId,[string]$RepairSessionId){
  return [pscustomobject]@{CaseConfig=@{};Notifications=[Collections.Generic.Queue[object]]::new()}
}
function Stop-PMMAppServer($Client){}
function Send-PMMAppServer($Client,[string]$Method,$Parameters,[switch]$Notification){if(-not$Notification){return 1}}
function Receive-PMMAppServer($Client,[int]$WaitMilliseconds){throw 'Protocol fixture unexpectedly waited for more notifications.'}
function Invoke-PMMAppServerRequest($Client,[string]$Method,$Parameters,[int]$TimeoutSeconds=40){
  $script:protocolCalls.Add(@{Method=$Method;Parameters=$Parameters})
  switch($Method){
    initialize {return @{userAgent='fixture'}}
    'account/read' {return @{account=@{type='chatgpt';planType='plus'}}}
    'model/list' {return @{data=@(foreach($id in @('gpt-5.6-luna','gpt-5.6-terra','gpt-5.6-sol')){@{model=$id;hidden=$false;supportedReasoningEfforts=@(@{reasoningEffort='low'},@{reasoningEffort='medium'},@{reasoningEffort='high'})}});nextCursor=$null}}
    'account/rateLimits/read' {return @{rateLimitsByLimitId=@{}}}
    {$_ -in @('thread/start','thread/resume')} {return @{thread=@{id=$script:protocolThread};model=$Parameters.model;reasoningEffort=$Parameters.config.model_reasoning_effort;serviceTier=$Parameters.serviceTier}}
    'turn/start' {
      $script:protocolTurns++
      if($Parameters.model -eq 'gpt-5.6-luna'){
        Add-PMMRepairAttempt $script:protocolSession.Id Diagnosis @{Stage='Routine'} Blocked 'Adaptation requires reasoning beyond update triage'|Out-Null
        Request-PMMAgentStage $script:protocolSession.Id $script:protocolSession.CaseId $script:protocolSession.EvidenceRevision Repair 'Need current-layout adaptation design'|Out-Null
      }
      $id='turn-'+$script:protocolTurns
      $Client.Notifications.Enqueue(@{method='turn/completed';params=@{turn=@{id=$id;status='completed'}}})
      return @{turn=@{id=$id}}
    }
    default {throw ('Unexpected protocol method '+$Method)}
  }
}
Reject {Invoke-PMMPersistentAgent $s.Id} 'A harder stage ran without the configured cost authorization.'
$turns=@($script:protocolCalls|Where-Object Method -eq 'turn/start')
Assert ($turns.Count -eq 1 -and $turns[0].Parameters.model -eq 'gpt-5.6-luna' -and $turns[0].Parameters.effort -eq 'low' -and $turns[0].Parameters.serviceTierForTurn -eq 'default') 'Routine turn inherited account defaults.'
Assert ((Get-PMMRepairSession $s.Id).Status -eq 'Paused') 'Blocked cost escalation lost its resumable state.'
$policy.MaxStage='Repair';Save-PMMAIPolicy $policy
Invoke-PMMPersistentAgent $s.Id|Out-Null
$turns=@($script:protocolCalls|Where-Object Method -eq 'turn/start')
Assert ($turns.Count -eq 2 -and $turns[1].Parameters.model -eq 'gpt-5.6-terra' -and $turns[1].Parameters.effort -eq 'medium') 'Authorized continuation repeated triage or used the wrong repair model.'
Assert (@($script:protocolCalls|Where-Object Method -eq 'thread/start').Count -eq 1) 'Reasoning escalation duplicated the conversation.'
Assert ($turns[0].Parameters.threadId -ceq $turns[1].Parameters.threadId) 'Reasoning escalation changed conversation identity.'
Invoke-PMMPersistentAgent $s.Id|Out-Null
Assert ($script:protocolTurns -eq 2) 'Retry repeated a completed turn.'
Write-Output ('PASS agent routing protocol133: '+($script:checks-$before)+' persistent staged-control checks.')
