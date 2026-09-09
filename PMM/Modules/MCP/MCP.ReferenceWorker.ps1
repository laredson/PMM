
param([Parameter(Mandatory=$true)][string]$Root)
Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
$Script:Root=[IO.Path]::GetFullPath($Root)
. (Join-Path $Root 'Modules\MCP\MCP.Service.ps1')
. (Join-Path $Root 'Modules\AIIO\AIIO.SessionService.ps1')
$job=Resolve-PMMMCPPath (Get-PMMMCPRoot) 'ReferenceJob'
$proc=$null
try{
    $worker=Resolve-PMMMCPPath $Root 'Modules\GameReference\GameReferenceWorker.ps1'
    $ps=Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
    $progress=Resolve-PMMMCPPath $job 'progress.json';$result=Resolve-PMMMCPPath $job 'result.json'
    foreach($file in @($progress,$result)){if(Test-Path $file){Remove-Item -LiteralPath $file}}
    $args='-NoProfile -NonInteractive -ExecutionPolicy Bypass -File "'+$worker+'" -Root "'+$Root+'" -ProgressPath "'+$progress+'" -ResultPath "'+$result+'" -MCP'
    $proc=Start-Process $ps -ArgumentList $args -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $job 'stdout.txt') -RedirectStandardError (Join-Path $job 'stderr.txt')
    $handle=$proc.Handle
    $watch=[Diagnostics.Stopwatch]::StartNew()
    while(-not $proc.WaitForExit(1000)){
        if(-not(Get-PMMMCPEnabled)){throw 'MCP disabled: reference preparation stopped.'}
        foreach($name in @('stdout.txt','stderr.txt')){if((Get-Item (Join-Path $job $name)).Length -gt 8MB){throw 'Reference worker diagnostics exceeded 8 MiB.'}}
        if($watch.Elapsed.TotalMinutes -gt 30){throw 'Reference preparation exceeded 30 minutes.'}
        $drive=[IO.DriveInfo]::new([IO.Path]::GetPathRoot($Root))
        if($drive.AvailableFreeSpace -lt 2GB){throw 'Reference preparation stopped: less than 2 GiB free.'}
    }
    if($proc.ExitCode -ne 0){throw 'Game Reference worker failed. Local ReferenceJob diagnostics contain details.'}
    $r=Read-PMMMCPJson $result
    if(-not $r.Success){throw $r.Error}
    Write-PMMAIIOJsonAtomic (Join-Path $job 'status.json') @{status='COMPLETE';message='Game Reference ready. Continue with pmm_reference_search.'} 6
}catch{
    Write-PMMAIIOJsonAtomic (Join-Path $job 'status.json') @{status='FAILED';message=$_.Exception.Message} 6
}finally{
    if($proc){
        if(-not $proc.HasExited){Start-Process (Join-Path $env:SystemRoot 'System32\taskkill.exe') -ArgumentList @('/PID',[string]$proc.Id,'/T','/F') -WindowStyle Hidden -Wait | Out-Null}
        $proc.Dispose()
    }
}
