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

Reject {Invoke-PMMPersistentAgent $s.Id} 'Internal request ran without separate opt-in.'
Assert ($script:protocolCalls.Count -eq 0) 'Disabled internal mode contacted the model server.'
$policy.InternalEnabled=$true;Save-PMMAIPolicy $policy
Invoke-PMMPersistentAgent $s.Id|Out-Null
Assert ($script:protocolTurns -eq 1 -and (Get-PMMRepairSession $s.Id).Status -eq 'NeedsInput') 'Routine request escalated without a user prompt.'
$policy.MaxStage='Repair';Save-PMMAIPolicy $policy
$p=New-PMMChatPrompt $s.Id 'Create an updated version for publication; explain missing PMM capabilities.' Repair
$again=New-PMMChatPrompt $s.Id $p.Text Repair $p.Id
Assert ($again.Id -ceq $p.Id) 'Retry duplicated the user prompt.'
Invoke-PMMChatPrompt $s.Id $p.Id|Out-Null
$turns=@($script:protocolCalls|Where-Object Method -eq 'turn/start')
Assert ($turns.Count -eq 2 -and $turns[1].Parameters.model -eq 'gpt-5.6-terra') 'Explicit repair request used the wrong model.'
Assert ($turns[1].Parameters.input[0].text -match [regex]::Escape($p.Text)) 'The user prompt was not delivered.'
Assert (@($script:protocolCalls|Where-Object Method -eq 'thread/start').Count -eq 1) 'Model change duplicated the conversation.'
Invoke-PMMChatPrompt $s.Id $p.Id|Out-Null
Assert ($script:protocolTurns -eq 2) 'Retry repeated a completed user turn.'
$history=Get-PMMCaseChatText $s.CaseId
Assert ($history -match 'gpt-5.6-luna' -and $history -match 'gpt-5.6-terra' -and $history -match 'Create an updated version') 'The public chat omitted model changes or the user prompt.'
Reject {New-PMMChatPrompt $s.Id 'Changed prompt' Repair $p.Id} 'Idempotency identifier accepted a different prompt.'
Write-Output ('PASS agent routing protocol133: '+($script:checks-$before)+' Desktop/default, journal and explicit-turn checks.')
