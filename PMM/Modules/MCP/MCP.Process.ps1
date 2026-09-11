
function ConvertTo-PMMNativeArgument([string]$Value) {
    return ('"'+[regex]::Replace([regex]::Replace($Value,'(\\*)"','$1$1\"'),'(\\+)$','$1$1')+'"')
}
function Invoke-PMMBoundedProcess {
    param([string]$Executable,[string[]]$Arguments,[string]$Directory,[int]$TimeoutSeconds=120,[string]$CancelPath='',[long]$OutputLimitBytes=8388608,[string]$DataDirectory='')
    [void][IO.Directory]::CreateDirectory($Directory)
    $stdout=Resolve-PMMMCPPath $Directory ('stdout-'+[guid]::NewGuid().ToString('N')+'.txt')
    $stderr=$stdout+'.err'
    $line=(@($Arguments|ForEach-Object{ConvertTo-PMMNativeArgument $_}) -join ' ')
    $proc=Start-Process -FilePath $Executable -ArgumentList $line -WorkingDirectory $Directory -WindowStyle Hidden -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
    $handle=$proc.Handle;$clock=[Diagnostics.Stopwatch]::StartNew()
    try {
        while(-not $proc.WaitForExit(250)){
            if($DataDirectory){
                [long]$dataBytes=0
                foreach($file in Get-ChildItem -LiteralPath $DataDirectory -Recurse -File){$dataBytes+=$file.Length;if($dataBytes -gt 64MB){throw 'Extracted data exceeds 64 MiB.'}}
            }
            if($clock.Elapsed.TotalSeconds -gt $TimeoutSeconds){throw 'Tool time limit exceeded.'}
            if($CancelPath -and (Test-Path -LiteralPath $CancelPath)){throw 'Operation cancelled.'}
            if($CancelPath -and (Get-Command Get-PMMUnrealSettings -ErrorAction SilentlyContinue) -and -not (Get-PMMUnrealSettings).enabled){throw 'Unreal integration disabled.'}
            if(([IO.DriveInfo]::new([IO.Path]::GetPathRoot($Directory))).AvailableFreeSpace -lt 2GB){throw 'Less than 2 GiB free space.'}
            if(-not(Get-PMMMCPEnabled)){throw 'MCP disabled; operation stopped.'}
            foreach($p in @($stdout,$stderr)){if((Get-Item $p).Length -gt $OutputLimitBytes){throw 'Tool diagnostic limit exceeded.'}}
        }
        if($proc.ExitCode -ne 0){
            $tail=((Get-Content -LiteralPath $stderr -Tail 6 -ErrorAction SilentlyContinue) -join ' ')
            if($tail.Length -gt 1800){$tail=$tail.Substring(0,1800)}
            throw ('Tool failed (exit '+$proc.ExitCode+'): '+$tail)
        }
        return @{exitCode=$proc.ExitCode;stdout=$stdout;stderr=$stderr}
    }finally{
        if(-not $proc.HasExited){Start-Process (Join-Path $env:SystemRoot 'System32\taskkill.exe') -ArgumentList @('/PID',[string]$proc.Id,'/T','/F') -WindowStyle Hidden -Wait | Out-Null}
        $proc.Dispose()
    }
}
function Get-PMMMCPDotnet {
    $direct=Resolve-PMMMCPPath $Script:Root 'Engine\dotnet\dotnet.exe'
    if(Test-Path $direct){return $direct}
    $base=Resolve-PMMMCPPath $Script:Root 'Engine\dotnet'
    foreach($d in @(Get-ChildItem $base -Directory | Sort-Object Name -Descending)){
        if($d.Name -match '^8\.\d+\.\d+$'){
            $p=Resolve-PMMMCPPath $base ($d.Name+'\dotnet.exe');if(Test-Path $p){return $p}
        }
    }
    throw 'PMM portable .NET runtime unavailable.'
}
