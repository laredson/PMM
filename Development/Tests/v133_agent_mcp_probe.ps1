Set-StrictMode -Version 2;$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'v133_analysis_regression.ps1')
$case=New-PMMCaseFromDeepAnalysis $report.Id
$session=New-PMMRepairSession $case.CaseId $options
Set-PMMMCPEnabled $true
$c=Start-PMMAppServer $case.CaseId $session.Id
$turnId='';$id=''
try{
Invoke-PMMAppServerRequest $c initialize @{clientInfo=@{name='pmm_scope_probe';version='1.3.3'};capabilities=@{experimentalApi=$true}}|Out-Null
Send-PMMAppServer $c initialized @{} -Notification
$t=Invoke-PMMAppServerRequest $c 'thread/start' @{cwd=(Get-PMMAIIOCasePath $case.CaseId);config=$c.CaseConfig;approvalPolicy='never';sandbox='read-only';model='gpt-5.6-luna';serviceTier='default';serviceName='PMM-scoped-protocol-test'}
$id=$t.thread.id
$prompt='Protocol test only. Call pmm_repair_get with caseId '+$case.CaseId+' and sessionId '+$session.Id+'. Do not modify anything or use any other tools. If it succeeds reply PMM_SCOPED_OK.'
$turn=Invoke-PMMAppServerRequest $c 'turn/start' @{model='gpt-5.6-luna';effort='low';serviceTierForTurn='default';threadId=$id;input=@(@{type='text';text=$prompt})}
$turnId=$turn.turn.id;$watch=[Diagnostics.Stopwatch]::StartNew();$done=$false;$response=''
while(-not$done -and $watch.Elapsed.TotalSeconds -lt 50){
$m=if($c.Notifications.Count){$c.Notifications.Dequeue()}else{Receive-PMMAppServer $c 100}
if(-not$m){continue}
$method=Get-PMMAnalysisValue $m method ''
if($method -eq 'item/agentMessage/delta'){$response+=$m.params.delta}
if($method -eq 'turn/completed'){$done=$true}
}
if(-not$done -or $response -notmatch 'PMM_SCOPED_OK'){throw ('Scoped MCP delivery was not proven: '+$response)}
$trace=Invoke-PMMAppServerRequest $c 'thread/read' @{threadId=$id;includeTurns=$true}
$calls=@($trace.thread.turns|ForEach-Object{$_.items}|Where-Object{$_.type -eq 'mcpToolCall' -and $_.server -eq 'pmm' -and $_.tool -eq 'pmm_repair_get' -and $_.status -eq 'completed'})
if($calls.Count -ne 1 -or $calls[0].arguments.caseId -cne $case.CaseId -or $calls[0].arguments.sessionId -cne $session.Id){throw 'No successful scoped MCP tool event was recorded.'}
$result=@{ThreadId=$id;CaseId=$case.CaseId;SessionId=$session.Id;Status='ReadOnlyMCPCallVerified';Response=$response;Fixture=$fixture}
Write-PMMJsonAtomic (Join-Path $repo 'Development/TestResults/agent133-scoped-validation.json') $result
$result|ConvertTo-Json -Compress
}finally{
if($id -and $turnId){try{Invoke-PMMAppServerRequest $c 'turn/interrupt' @{threadId=$id;turnId=$turnId} -TimeoutSeconds 5|Out-Null}catch{}}
Stop-PMMAppServer $c
}
