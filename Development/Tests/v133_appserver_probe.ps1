param([string]$ResumeId='')
Set-StrictMode -Version 2;$ErrorActionPreference='Stop'
$repo=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
. (Join-Path $repo 'PMM/Modules/Analysis/Analysis.Model.ps1')
. (Join-Path $repo 'PMM/Modules/MCP/MCP.Client.ps1')
. (Join-Path $repo 'PMM/Modules/MCP/AppServer.Client.ps1')
$probeRoot=Join-Path $repo 'Development/TestResults/Agent133-Protocol'
[void][IO.Directory]::CreateDirectory($probeRoot)
$client=$null
try {
$client=Start-PMMAppServer
Invoke-PMMAppServerRequest $client initialize @{clientInfo=@{name='pmm_probe';version='1.3.3'};capabilities=@{experimentalApi=$true}}|Out-Null
Send-PMMAppServer $client initialized @{} -Notification
$account=Invoke-PMMAppServerRequest $client 'account/read' @{refreshToken=$false}
if(-not$account.account){throw 'Authentication unavailable'}
'Authenticated'
if($ResumeId){$thread=Invoke-PMMAppServerRequest $client 'thread/resume' @{threadId=$ResumeId;cwd=$probeRoot;approvalPolicy='never';sandbox='read-only';model='gpt-5.6-luna';serviceTier='default'}}
else {$thread=Invoke-PMMAppServerRequest $client 'thread/start' @{cwd=$probeRoot;approvalPolicy='never';sandbox='read-only';model='gpt-5.6-luna';serviceTier='default';serviceName='PMM-133-Protocol-Probe';ephemeral=$false}}
$id=$thread.thread.id
[IO.File]::WriteAllText((Join-Path $probeRoot 'thread-id.txt'),$id)
Write-Output ('Thread: '+$id)
$prompt=if($ResumeId){'PMM protocol continuation check. Reply only PMM_CONTINUED. Do not use tools.'}else{'PMM protocol persistence check. Reply only PMM_CONNECTED. Do not use tools.'}
$turn=Invoke-PMMAppServerRequest $client 'turn/start' @{model='gpt-5.6-luna';effort='low';serviceTierForTurn='default';threadId=$id;input=@(@{type='text';text=$prompt})}
$watch=[Diagnostics.Stopwatch]::StartNew();$done=$false;$progress=$false
while(-not$done -and $watch.Elapsed.TotalSeconds -lt 50){
$m=if($client.Notifications.Count){$client.Notifications.Dequeue()}else{Receive-PMMAppServer $client 100}
if(-not$m){continue}
$method=Get-PMMAnalysisValue $m method ''
if($method -eq 'item/agentMessage/delta'){$progress=$true;Write-Output ([string]$m.params.delta)}
if($method -eq 'turn/completed'){$done=$true;Write-Output ('Turn status: '+$m.params.turn.status)}
}
if(-not$done){Invoke-PMMAppServerRequest $client 'turn/interrupt' @{threadId=$id;turnId=$turn.turn.id}|Out-Null;throw 'Probe exceeded 50 seconds; interrupt requested.'}
$read=Invoke-PMMAppServerRequest $client 'thread/read' @{threadId=$id;includeTurns=$true}
$result=@{ThreadId=$id;Resumed=[bool]$ResumeId;TurnCount=@($read.thread.turns).Count;ProgressObserved=$progress;DesktopVerified=$false;Utc=[DateTime]::UtcNow.ToString('o')}
[IO.File]::WriteAllText((Join-Path $probeRoot $(if($ResumeId){'resume.json'}else{'start.json'})),($result|ConvertTo-Json),[Text.UTF8Encoding]::new($false))
$result|ConvertTo-Json -Compress
}finally{Stop-PMMAppServer $client}
