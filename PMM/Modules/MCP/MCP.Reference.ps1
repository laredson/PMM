
function Get-PMMMCPReferenceStatus {
    try{$state=Get-PMMGameReferenceState}catch{return @{status='UNAVAILABLE';game='Palworld';gameDetected=$false;canPrepare=$false;message='PMM game configuration or reference metadata is unavailable.';prepareTool='pmm_reference_prepare'}}
    $result=[ordered]@{status=$state.Status;game='Palworld';gameDetected=([bool]$state.Identity.PakPath);families=$state.FamilyCount;bytes=$state.Bytes;message=$state.Reason;canPrepare=([bool]$state.Identity.PakPath);prepareTool='pmm_reference_prepare'}
    $job=Resolve-PMMMCPPath (Get-PMMMCPRoot) 'ReferenceJob'
    $statusPath=Resolve-PMMMCPPath $job 'status.json'
    if(Test-Path -LiteralPath $statusPath){
        $jobState=Read-PMMMCPJson $statusPath
        $result.jobStatus=$jobState.status
        $result.message=$jobState.message
        if($jobState.status -eq 'RUNNING'){
            $alive=$false
            try{$p=Get-Process -Id $jobState.processId -ErrorAction Stop;$alive=($p.StartTime.ToUniversalTime().ToString('o') -eq $jobState.processStartUtc)}catch{}
            if(-not $alive){$result.jobStatus='INTERRUPTED';$result.message='Reference worker stopped; call pmm_reference_prepare to retry.'}
            else{
                $result.status='RUNNING'
                $progress=Resolve-PMMMCPPath $job 'progress.json'
                if(Test-Path $progress){try{$pr=Read-PMMMCPJson $progress;$result.message=$pr.Message;$result.percent=$pr.Percent}catch{}}
            }
        }
    }
    return $result
}
function Start-PMMMCPReference {
    $current=Get-PMMMCPReferenceStatus
    if($current.status -eq 'Current' -or $current.status -eq 'RUNNING'){return $current}
    if(-not $current.gameDetected){throw 'PMM has no valid configured Palworld installation. Game detection/configuration is required.'}
    $job=Resolve-PMMMCPPath (Get-PMMMCPRoot) 'ReferenceJob'
    [void][IO.Directory]::CreateDirectory($job)
    $lock=[IO.File]::Open((Resolve-PMMMCPPath $job 'start.lock'),[IO.FileMode]::OpenOrCreate,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)
    try{
        $current=Get-PMMMCPReferenceStatus
        if($current.status -eq 'Current' -or $current.status -eq 'RUNNING'){return $current}
        $ref=Resolve-PMMMCPPath $Script:Root 'Workspace\GameReference'
        if(Test-Path $ref){foreach($f in Get-ChildItem -LiteralPath $ref -Recurse -Force){[void](Resolve-PMMMCPPath $ref $f.FullName.Substring($ref.Length).TrimStart('\'))}}
        foreach($rel in @('Workspace\Cache','Workspace\Logs','Workspace\State\config.json','Engine\repak.exe','Resources\Mappings\Mappings.usmap')){[void](Resolve-PMMMCPPath $Script:Root $rel)}
        if(([IO.DriveInfo]::new([IO.Path]::GetPathRoot($Script:Root))).AvailableFreeSpace -lt 2GB){throw 'At least 2 GiB of free space is required to prepare the reference.'}
        $worker=Resolve-PMMMCPPath $Script:Root 'Modules\MCP\MCP.ReferenceWorker.ps1'
        $ps=Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
        $args='-NoProfile -NonInteractive -ExecutionPolicy Bypass -File "'+$worker+'" -Root "'+$Script:Root+'"'
        $proc=Start-Process $ps -ArgumentList $args -WindowStyle Hidden -PassThru
        Write-PMMAIIOJsonAtomic (Join-Path $job 'status.json') @{status='RUNNING';message='Preparing Vanilla reference';processId=$proc.Id;processStartUtc=$proc.StartTime.ToUniversalTime().ToString('o')} 6
        $proc.Dispose()
        return (Get-PMMMCPReferenceStatus)
    }finally{$lock.Dispose()}
}
