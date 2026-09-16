param([switch]$ProbeConnection)
Set-StrictMode -Version 2;$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'v133_analysis_regression.ps1')
$before=$script:checks
$c=New-PMMAIIOCase -Title 'AUAT retry fixture' -Type FIX_MOD -Transport MCP -AIClient CHATGPT
$options=New-PMMDeepAnalysisOptions;$options.AutomaticSolution=$true
$a=Get-OrCreate-PMMCaseRepairSession $c.CaseId $options
$a.Status='Paused';$a.LastMessage='First unavailable runtime';Save-PMMRepairSession $a
$b=Get-OrCreate-PMMCaseRepairSession $c.CaseId $options
Assert ($a.Id -ceq $b.Id) 'Repeated case dispatch created another session.'
$options.MaxActiveMinutes=90
$capped=Get-OrCreate-PMMCaseRepairSession $c.CaseId $options
Assert ($capped.Options.MaxActiveMinutes -eq 40) 'A retry silently extended the session budget.'
# Preview migration selects an existing latest session instead of discarding history.
$c2=New-PMMAIIOCase -Title 'Old sessions' -Type QUERY
$old=New-PMMRepairSession $c2.CaseId $options
$latest=New-PMMRepairSession $c2.CaseId $options
Assert ((Get-OrCreate-PMMCaseRepairSession $c2.CaseId $options).Id -ceq $latest.Id) 'Existing preview sessions were ignored.'
Add-PMMCaseEvidenceRevision $c.CaseId @{Kind='New evidence'}|Out-Null
$revised=Get-OrCreate-PMMCaseRepairSession $c.CaseId $options
Assert ($revised.Id -cne $a.Id -and $revised.EvidenceRevision -cne $a.EvidenceRevision) 'Changed evidence reused stale authorization.'
$mod=Join-Path $fixture 'AUAT-test.pak';[IO.File]::WriteAllText($mod,'old')
Add-PMMAIIOCaseModReference $c.CaseId $mod|Out-Null
$current=Get-OrCreate-PMMCaseRepairSession $c.CaseId $options
Assert-PMMRepairAuthorization $current.Id $c.CaseId $current.EvidenceRevision Research|Out-Null
[IO.File]::WriteAllText($mod,'changed')
Reject {Assert-PMMRepairAuthorization $current.Id $c.CaseId $current.EvidenceRevision Research} 'Changed manual-case mod bytes retained authorization.'
$c3=New-PMMAIIOCase -Title 'Worker persistence' -Type QUERY -Transport MCP -AIClient CHATGPT
$work=Get-OrCreate-PMMCaseRepairSession $c3.CaseId $options
# A real child process fails before any network request; its error must persist for the UI.
$runtimeFile=Join-Path $fixture 'Modules/MCP/MCP.Client.ps1'
[IO.File]::AppendAllText($runtimeFile,[Environment]::NewLine+"function Get-PMMCodexRuntime { throw 'Fixture runtime missing from PATH and desktop' }",[Text.UTF8Encoding]::new($true))
Reject {Start-PMMRepairAgentJob $work.Id} 'An internal worker started without explicit opt-in.'
$policy=New-PMMAIPolicy;$policy.InternalEnabled=$true;Save-PMMAIPolicy $policy
Start-PMMRepairAgentJob $work.Id|Out-Null
$watch=[Diagnostics.Stopwatch]::StartNew()
do{
  Start-Sleep -Milliseconds 100
  $state=Get-PMMRepairSession $work.Id
}while($watch.Elapsed.TotalSeconds -lt 20 -and ($state.Status -eq 'Starting' -or (Test-PMMRepairWorkerAlive $state)))
Assert ($state.Status -eq 'Paused' -and $state.LastMessage -like '*Fixture runtime missing*') ('Worker failure was not persisted: '+$state.Status+' '+$state.LastMessage)
Assert (@(Get-ChildItem (Get-PMMRepairSessionRoot $work.Id) -Filter '*.stderr.log').Count -eq 1) 'Child error output was discarded.'
$view=Get-PMMCaseAgentView (Get-PMMAIIOCase $c3.CaseId)
Assert (-not$view.Running -and $view.Message -like '*Fixture runtime missing*') 'Terminal worker failure was not available to the case UI.'
if($ProbeConnection){
  $savedPath=$env:PATH
  try{
    $env:PATH=Join-Path $env:SystemRoot 'System32'
    $runtime=Get-PMMCodexRuntime
    Assert ($runtime.Discovery -eq 'Desktop runtime' -and [IO.File]::Exists($runtime.Source)) 'Explorer-style PATH cannot find the desktop runtime.'
    $connection=Test-PMMAppServerConnection
    Assert ($connection.ProtocolVerified -and $connection.Authenticated) 'Desktop runtime did not authenticate without task PATH.'
    Write-PMMJsonAtomic (Join-Path $repo 'Development/TestResults/case133-no-path-connection.json') @{Runtime=$runtime;Connection=$connection;InferenceStarted=$false}
  }finally{$env:PATH=$savedPath}
}
Write-Output ('PASS case agent: '+($script:checks-$before)+' additional assertions')
