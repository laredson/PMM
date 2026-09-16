param([string]$ThreadId)
Set-StrictMode -Version 2;$ErrorActionPreference='Stop'
$repo=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
. (Join-Path $repo 'PMM/Modules/Analysis/Analysis.Model.ps1')
. (Join-Path $repo 'PMM/Modules/MCP/MCP.Client.ps1')
. (Join-Path $repo 'PMM/Modules/MCP/AppServer.Client.ps1')
$c=Start-PMMAppServer
try{
Invoke-PMMAppServerRequest $c initialize @{clientInfo=@{name='pmm_probe';version='1.3.3'}}|Out-Null
Send-PMMAppServer $c initialized @{} -Notification
Invoke-PMMAppServerRequest $c 'thread/resume' @{threadId=$ThreadId;approvalPolicy='never';sandbox='read-only';model='gpt-5.6-luna';serviceTier='default'}|Out-Null
$before=Invoke-PMMAppServerRequest $c 'thread/read' @{threadId=$ThreadId;includeTurns=$true}
$t=Invoke-PMMAppServerRequest $c 'turn/start' @{model='gpt-5.6-luna';effort='low';serviceTierForTurn='default';threadId=$ThreadId;input=@(@{type='text';text='PMM interruption protocol test. Do not use tools. This request will be cancelled immediately.'})}
Invoke-PMMAppServerRequest $c 'turn/interrupt' @{threadId=$ThreadId;turnId=$t.turn.id}|Out-Null
$watch=[Diagnostics.Stopwatch]::StartNew();$status=''
while($watch.Elapsed.TotalSeconds -lt 15 -and -not$status){
$m=if($c.Notifications.Count){$c.Notifications.Dequeue()}else{Receive-PMMAppServer $c 100}
if($m -and (Get-PMMAnalysisValue $m method '') -eq 'turn/completed' -and $m.params.turn.id -eq $t.turn.id){$status=$m.params.turn.status}
}
if($status -ne 'interrupted'){throw ('Unexpected interruption result: '+$status)}
$read=Invoke-PMMAppServerRequest $c 'thread/read' @{threadId=$ThreadId;includeTurns=$true}
if($read.thread.id -cne $ThreadId -or @($read.thread.turns).Count -lt (@($before.thread.turns).Count+1)){throw 'Interrupted conversation lost persisted history.'}
$result=@{ThreadId=$ThreadId;TurnId=$t.turn.id;Status=$status;PreservedTurns=@($read.thread.turns).Count}
[IO.File]::WriteAllText((Join-Path $repo 'Development/TestResults/Agent133-Protocol/interrupt.json'),($result|ConvertTo-Json))
$result|ConvertTo-Json -Compress
}finally{Stop-PMMAppServer $c}
