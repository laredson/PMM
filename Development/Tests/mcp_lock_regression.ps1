
$ErrorActionPreference='Stop'
. ./PMM/Modules/MCP/MCP.Service.ps1
$folder=Join-Path (Get-Location) ('Development/TestResults/Lock-'+[guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($folder);$path=Join-Path $folder 'bridge.lock'
$job=Start-Job -ArgumentList $path -ScriptBlock {param($p)$s=[IO.File]::Open($p,'OpenOrCreate','ReadWrite','None');[IO.File]::WriteAllText($p+'.ready','ready');Start-Sleep -Seconds 2;$s.Dispose()}
try{
 $deadline=[DateTime]::UtcNow.AddSeconds(15)
 while(-not(Test-Path ($path+'.ready'))){if([DateTime]::UtcNow -gt $deadline){throw 'Fixture did not start'};Start-Sleep -Milliseconds 50}
 $watch=[Diagnostics.Stopwatch]::StartNew();$lock=Enter-PMMMCPFileLock $path 5
 try{if($watch.Elapsed.TotalMilliseconds -lt 500){throw 'Lock did not wait for contention'}}finally{$lock.Dispose()}
 Wait-Job $job -Timeout 10|Out-Null;Receive-Job $job|Out-Null
 'MCP_LOCK_CONTENTION_PASS'
}finally{Remove-Job $job -Force}
