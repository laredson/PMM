. (Join-Path $PSScriptRoot 'Dependency.Locations.ps1')

function Get-PMMUnrealRoot {return (Resolve-PMMMCPPath $Script:Root 'Workspace\Unreal')}
function Get-PMMUnrealProfile {return (Read-PMMMCPJson (Resolve-PMMMCPPath $Script:Root 'Resources\Unreal\profile.json'))}
function Get-PMMUnrealSettings {
    $p=Resolve-PMMMCPPath (Get-PMMUnrealRoot) 'settings.json'
    if(Test-Path $p){return (Read-PMMMCPJson $p)}
    return [pscustomobject]@{enabled=$false;engineRoot='';wwiseSdk='';wwiseIntegration=''}
}
function Save-PMMUnrealSettings($Settings) {Write-PMMAIIOJsonAtomic (Resolve-PMMMCPPath (Get-PMMUnrealRoot) 'settings.json') $Settings 8}
function Get-PMMEpicEngineRoots([string]$ManifestDirectory) {
    foreach($file in @(Get-ChildItem -LiteralPath $ManifestDirectory -Filter '*.item' -File -ErrorAction SilentlyContinue)){
        try{
            $item=Read-PMMMCPJson $file.FullName
            if($item.AppName -match '^UE_' -and $item.InstallLocation){[string]$item.InstallLocation}
        }catch{}
    }
}
function Get-PMMUnrealEnvironment {
    $cfg=Get-PMMUnrealSettings;$profile=Get-PMMUnrealProfile
    $pf86=[Environment]::GetEnvironmentVariable('ProgramFiles(x86)')
    $roots=[Collections.Generic.List[string]]::new()
    if($cfg.engineRoot){$roots.Add($cfg.engineRoot)}
    $manifest=Join-Path $env:ProgramData 'Epic\UnrealEngineLauncher\LauncherInstalled.dat'
    if(Test-Path $manifest){try{foreach($i in (Read-PMMMCPJson $manifest).InstallationList){if($i.AppName -match '^UE_'){$roots.Add($i.InstallLocation)}}}catch{}}
    foreach($location in @(Get-PMMEpicEngineRoots (Join-Path $env:ProgramData 'Epic\EpicGamesLauncher\Data\Manifests'))){$roots.Add($location)}
    foreach($key in @('HKLM:\SOFTWARE\EpicGames\Unreal Engine','HKLM:\SOFTWARE\WOW6432Node\EpicGames\Unreal Engine')){
        if(Test-Path $key){foreach($sub in Get-ChildItem $key){try{$roots.Add((Get-ItemProperty $sub.PSPath).InstalledDirectory)}catch{}}}
    }
    foreach($base in @($env:ProgramFiles,$pf86)){
        $epic=Join-Path $base 'Epic Games'
        if(Test-Path $epic){foreach($d in Get-ChildItem $epic -Directory -Filter 'UE_*'){$roots.Add($d.FullName)}}
    }
    $engine='';$version='';$compatible=$false
    $candidates=if($cfg.engineRoot){@($cfg.engineRoot)}else{@($roots|Select-Object -Unique)}
    foreach($r in $candidates){
        try{
            $r=Resolve-PMMMCPPath $r
            $versionFile=Join-Path $r 'Engine\Build\Build.version'
            if(-not(Test-Path -LiteralPath $versionFile -PathType Leaf)){continue}
            $v=Read-PMMMCPJson $versionFile
            if(-not(Test-Path (Join-Path $r 'Engine\Binaries\Win64\UnrealEditor-Cmd.exe'))){continue}
            $engine=$r;$version="$($v.MajorVersion).$($v.MinorVersion).$($v.PatchVersion)"
            if($v.MajorVersion -eq 5 -and $v.MinorVersion -eq 1){$compatible=$true;break}
        }catch{}
    }
    $vs='';$msvc='';$vsInstalled=''
    $vswhere=Join-Path $pf86 'Microsoft Visual Studio\Installer\vswhere.exe'
    if(Test-Path $vswhere){
        try{
            $instances=@((& $vswhere -products '*' -version '[17.0,18.0)' -format json | Out-String | ConvertFrom-Json))
            foreach($inst in $instances){
                if(-not $vsInstalled){$vsInstalled=$inst.installationPath}
                foreach($d in @(Get-ChildItem (Join-Path $inst.installationPath 'VC\Tools\MSVC') -Directory -ErrorAction SilentlyContinue)){
                    if($d.Name.StartsWith($profile.msvcPrefix)){$vs=$inst.installationPath;$msvc=$d.Name;break}
                }
                if($vs){break}
            }
        }catch{}
    }
    $sdkRoot=Join-Path $pf86 'Windows Kits\10\Include'
    $windowsSdk=@(Get-ChildItem $sdkRoot -Directory -ErrorAction SilentlyContinue | Where-Object{Test-Path (Join-Path $_.FullName 'um\Windows.h')}).Count -gt 0
    $dotnet6=@(Get-ChildItem (Join-Path $env:ProgramFiles 'dotnet\shared\Microsoft.NETCore.App') -Directory -Filter '6.*' -ErrorAction SilentlyContinue).Count -gt 0
    $wwise=Find-PMMWwiseSDK $cfg.wwiseSdk
    $wwiseOk=[bool]$wwise
    $integration=Resolve-PMMWwiseIntegrationLocation $cfg.wwiseIntegration
    if(-not $integration -and $wwise){
        $audio=Split-Path (Split-Path $wwise -Parent) -Parent
        $found=@(Get-ChildItem $audio -Filter 'Unreal.5.0.tar.xz' -Recurse -File -ErrorAction SilentlyContinue | Where-Object{$_.FullName -match '2021\.1\.11'} | Select-Object -First 1)
        if($found.Count){$integration=$found[0].FullName}
    }
    if(-not $integration){
        foreach($relative in @('Workspace\Dependencies\Offline\Wwise-Unreal-2021.1.11','Workspace\Dependencies\Offline\Wwise-2021.1.11')){
            $download=Join-Path $Script:Root $relative
            $found=@(Get-ChildItem -LiteralPath $download -Filter 'Unreal.5.0.tar.xz' -File -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1)
            if($found.Count){$integration=$found[0].FullName;break}
        }
    }
    $missing=[Collections.Generic.List[string]]::new()
    if(-not $compatible){$missing.Add('Unreal Engine 5.1.1')}
    if(-not $vsInstalled){$missing.Add('Visual Studio 2022')}
    if(-not $msvc){$missing.Add('MSVC 14.38 C++ x64/x86 tools for Visual Studio 2022')}
    if(-not $windowsSdk){$missing.Add('Windows SDK')}
    if(-not $dotnet6){$missing.Add('.NET Runtime 6 x64')}
    if(-not $wwiseOk){$missing.Add('Wwise 2021.1.11 SDK (Win32/x64 vc170)')}
    if(-not $integration -or -not(Test-Path $integration)){$missing.Add('Wwise 2021.1.11 offline Unreal.5.0.tar.xz or extracted Wwise plugin')}
    return [pscustomobject]@{enabled=[bool]$cfg.enabled;installed=[bool]$engine;compatible=$compatible;engineRoot=$engine;engineVersion=$version;visualStudio=$vs;visualStudioInstalled=$vsInstalled;msvc=$msvc;windowsSdk=$windowsSdk;dotnet6=$dotnet6;wwiseSdk=$wwise;wwiseIntegration=$integration;missing=$missing.ToArray();kitCommit=$profile.kitCommit;readyToPrepare=($missing.Count -eq 0)}
}
function Get-PMMUnrealStatus {
    $e=Get-PMMUnrealEnvironment
    return @{enabled=$e.enabled;installed=$e.installed;compatible=$e.compatible;verified=$false;engineVersion=$e.engineVersion;missing=$e.missing;kitCommit=$e.kitCommit;readyToPrepare=($e.enabled -and $e.readyToPrepare);verification='Per-project verification required: pmm_unreal_prepare then pmm_unreal_job.';supported=@('texture-import','texture-duplicate','texture-properties','windows-cook');python='Unreal embedded Python; no separate install'}
}
function Get-PMMUnrealProject([string]$CaseId) {
    [void](Get-PMMMCPCase $CaseId)
    $hash=[Security.Cryptography.SHA256]::Create()
    try{$id=([BitConverter]::ToString($hash.ComputeHash([Text.Encoding]::UTF8.GetBytes($CaseId)))).Replace('-','').Substring(0,16).ToLowerInvariant()}finally{$hash.Dispose()}
    return (Resolve-PMMMCPPath (Get-PMMUnrealRoot) ('Projects\'+$id))
}
function Get-PMMUnrealJobPath([string]$CaseId,[string]$JobId) {
    [void](Get-PMMMCPCase $CaseId)
    if($JobId -cnotmatch '^[a-f0-9]{32}$'){throw 'Invalid Unreal job ID.'}
    $p=Resolve-PMMMCPPath (Get-PMMUnrealRoot) ('Jobs\'+$JobId)
    $request=Read-PMMMCPJson (Join-Path $p 'request.json')
    if($request.caseId -cne $CaseId){throw 'Unreal job belongs to a different case.'}
    return $p
}
function Start-PMMUnrealJob([string]$Operation,$Arguments) {
    $e=Get-PMMUnrealEnvironment
    if(-not $e.enabled){throw 'Optional Unreal integration is disabled. PMM base tools remain available.'}
    if(-not $e.readyToPrepare){throw ('Unreal prerequisites missing: '+($e.missing -join ', '))}
    $project=Get-PMMUnrealProject $Arguments.caseId
    if($Operation -ne 'prepare'){
        $verified=Resolve-PMMMCPPath $project 'verified.json'
        if(-not(Test-Path $verified)){throw 'Prepare and verify this case project first.'}
        $v=Read-PMMMCPJson $verified
        if($v.engineRoot -ine $e.engineRoot -or $v.kitCommit -ne $e.kitCommit -or $v.engineVersion -ne $e.engineVersion){throw 'Project verification is stale. Prepare again.'}
    }
    $id=[guid]::NewGuid().ToString('N');$dir=Resolve-PMMMCPPath (Get-PMMUnrealRoot) ('Jobs\'+$id)
    [void][IO.Directory]::CreateDirectory($dir)
    Write-PMMAIIOJsonAtomic (Join-Path $dir 'request.json') @{caseId=$Arguments.caseId;operation=$Operation;arguments=$Arguments;jobId=$id} 12
    Write-PMMAIIOJsonAtomic (Join-Path $dir 'status.json') @{status='QUEUED';message='Starting Unreal operation';verified=$false} 8
    $ps=Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
    $worker=Resolve-PMMMCPPath $Script:Root 'Modules\Unreal\Unreal.Worker.ps1'
    $line=(@(@('-NoProfile','-NonInteractive','-ExecutionPolicy','Bypass','-File',$worker,'-Root',$Script:Root,'-JobId',$id)|ForEach-Object{ConvertTo-PMMNativeArgument $_}) -join ' ')
    $proc=Start-Process $ps -ArgumentList $line -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $dir 'worker.log') -RedirectStandardError (Join-Path $dir 'worker.err')
    Write-PMMAIIOJsonAtomic (Join-Path $dir 'owner.json') @{pid=$proc.Id;startUtc=$proc.StartTime.ToUniversalTime().ToString('o')} 5
    $proc.Dispose()
    return @{jobId=$id;status='QUEUED';nextTool='pmm_unreal_job'}
}
function Get-PMMUnrealJob($Arguments) {
    $dir=Get-PMMUnrealJobPath $Arguments.caseId $Arguments.jobId
    $wait=0;if(@($Arguments.PSObject.Properties|ForEach-Object{$_.Name}) -contains 'waitSeconds'){$wait=$Arguments.waitSeconds}
    $end=[DateTime]::UtcNow.AddSeconds($wait)
    do{
        $s=Read-PMMMCPJson (Join-Path $dir 'status.json')
        if($s.status -notin @('QUEUED','RUNNING')){return $s}
        $ownerPath=Join-Path $dir 'owner.json'
        if(Test-Path $ownerPath){
            $owner=Read-PMMMCPJson $ownerPath;$alive=$false
            try{$p=Get-Process -Id $owner.pid -ErrorAction Stop;$alive=($p.StartTime.ToUniversalTime().ToString('o') -eq $owner.startUtc)}catch{}
            if(-not $alive){return @{status='INTERRUPTED';message='Worker stopped before completing. Retry operation.';verified=$false}}
        }
        if([DateTime]::UtcNow -ge $end){return $s};Start-Sleep -Milliseconds 500
    }while($true)
}
