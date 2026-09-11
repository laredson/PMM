# IO stays in a background runspace; the dispatcher only applies a completed snapshot.
$Script:PMMDependencySnapshotTask=$null
$Script:PMMDependencySnapshot=$null
function Get-PMMDependencySnapshot {
    if($Script:PMMDependencySnapshotTask -and $Script:PMMDependencySnapshotTask.handle.IsCompleted){
        $task=$Script:PMMDependencySnapshotTask
        try{$result=@($task.ps.EndInvoke($task.handle));if($result.Count){$Script:PMMDependencySnapshot=$result[-1]}}finally{$task.ps.Dispose();$Script:PMMDependencySnapshotTask=$null}
    }
    if(-not $Script:PMMDependencySnapshotTask){
        $ps=[PowerShell]::Create()
        [void]$ps.AddScript({param($root,$previous)
            $catalog=$null;$cache=@{};if($previous){$cache=$previous.cache}
            $path=Join-Path $root 'catalog.json'
            if(Test-Path -LiteralPath $path){try{$catalog=[IO.File]::ReadAllText($path)|ConvertFrom-Json}catch{}}
            $jobs=@(Get-ChildItem (Join-Path $root 'Jobs') -Filter *.json -ErrorAction SilentlyContinue|Sort-Object LastWriteTimeUtc -Descending|ForEach-Object {
                try{
                    $key=$_.FullName;$stamp=$_.LastWriteTimeUtc.Ticks.ToString()+'|'+$_.Length
                    if(-not $cache.ContainsKey($key) -or $cache[$key].stamp -ne $stamp){$cache[$key]=@{stamp=$stamp;job=([IO.File]::ReadAllText($key)|ConvertFrom-Json)}}
                    $j=$cache[$key].job;if($j.operation -eq 'install'){$j}
                }catch{}
            })
            [pscustomobject]@{catalog=$catalog;jobs=$jobs;cache=$cache}
        }).AddArgument((Get-PMMDependencyRoot)).AddArgument($Script:PMMDependencySnapshot)
        $Script:PMMDependencySnapshotTask=@{ps=$ps;handle=$ps.BeginInvoke()}
    }
    return $Script:PMMDependencySnapshot
}
function Stop-PMMDependencySnapshot {
    if($Script:PMMDependencySnapshotTask){$Script:PMMDependencySnapshotTask.ps.Stop();$Script:PMMDependencySnapshotTask.ps.Dispose();$Script:PMMDependencySnapshotTask=$null}
}
