. (Join-Path $PSScriptRoot '../MCP/ChatGPT.Desktop.ps1')
. (Join-Path $PSScriptRoot 'Wwise.Offline.ps1')

function Get-PMMDependencyRoot {return (Resolve-PMMMCPPath $Script:Root 'Workspace\Dependencies')}
function Get-PMMDependencyDefinitions {
    return @(
        @{id='chatgpt';name='ChatGPT Desktop (optional AI client)';version='Current';kind='microsoft-store'},        @{id='unreal';name='Unreal Engine / Epic Launcher';version='5.1.1';kind='epic'},
        @{id='visualstudio';name='Visual Studio 2022 + MSVC';version='14.38 / 17.8';kind='microsoft'},
        @{id='windowssdk';name='Windows SDK';version='10 / 11';kind='microsoft'},
        @{id='dotnet6';name='.NET Runtime x64';version='6.0';kind='microsoft'},
        @{id='wwise';name='Wwise SDK';version='2021.1.11';kind='audiokinetic'},
        @{id='wwiseintegration';name='Wwise offline integration';version='2021.1.11 / Unreal.5.0';kind='audiokinetic'},
        @{id='kit';name='Palworld Modding Kit';version=(Get-PMMUnrealProfile).kitCommit;kind='pinned-archive'}
    )
}
function Get-PMMDependencyCatalog {
    $e=Get-PMMUnrealEnvironment
    $kit=Join-Path (Get-PMMUnrealRoot) ('Downloads\'+$e.kitCommit+'.zip')
    $kitOK=(Test-Path $kit) -and (Get-FileHash $kit).Hash -ieq (Get-PMMUnrealProfile).kitSha256
    $ready=@{chatgpt=[bool](Get-PMMChatGPTDesktop);unreal=$e.compatible;visualstudio=[bool]$e.visualStudio;windowssdk=$e.windowsSdk;dotnet6=$e.dotnet6;wwise=($e.missing -notcontains 'Wwise 2021.1.11 SDK (Win32/x64 vc170)');wwiseintegration=([bool]$e.wwiseIntegration -and (Test-Path $e.wwiseIntegration));kit=$kitOK}
    $rows=@(foreach($d in Get-PMMDependencyDefinitions){[pscustomobject]@{id=$d.id;name=$d.name;version=$d.version;installed=[bool]$ready[$d.id];status=$(if($ready[$d.id]){'DETECTED'}else{'MISSING'});verified=$false;path=''}})
    if($e.PSObject.Properties['visualStudioInstalled'] -and $e.visualStudioInstalled -and -not $ready.visualstudio){
        ($rows | Where-Object {$_.id -eq 'visualstudio'}).status='VS 2022 DETECTED; MSVC 14.38 MISSING'
    }
    foreach($entry in @(@('unreal',$e.engineRoot),@('wwise',$e.wwiseSdk),@('wwiseintegration',$e.wwiseIntegration))){($rows|Where-Object{$_.id -eq $entry[0]}).path=[string]$entry[1]}
    if(-not $ready.wwise){
        $row=$rows|Where-Object{$_.id -eq 'wwise'}
        try{$offline=Get-PMMWwiseOfflineInstaller;if($offline){$row.status='OFFLINE_READY';$row.path=Split-Path $offline -Parent}}catch{$row.status='OFFLINE_INVALID';$row.path=$_.Exception.Message}
    }
    Write-PMMAIIOJsonAtomic (Join-Path (Get-PMMDependencyRoot) 'catalog.json') @{updatedUtc=[DateTime]::UtcNow.ToString('o');components=$rows} 8
    return $rows
}
function Get-PMMDependencyPolicy {
    $path=Join-Path (Get-PMMDependencyRoot) 'policy.json'
    if(Test-Path $path){return (Read-PMMMCPJson $path)}
    return [pscustomobject]@{mode='ask';catalogVersion=1}
}
function Set-PMMDependencyPolicy([string]$Mode){
    if($Mode -notin @('ask','automatic')){throw 'Invalid install policy.'}
    Write-PMMAIIOJsonAtomic (Join-Path (Get-PMMDependencyRoot) 'policy.json') @{mode=$Mode;catalogVersion=1} 5
}
function Get-PMMDependencyJobPath([string]$Id){
    if($Id -cnotmatch '^[a-f0-9]{32}$'){throw 'Invalid dependency job.'}
    return (Resolve-PMMMCPPath (Get-PMMDependencyRoot) ('Jobs\'+$Id+'.json'))
}
function Start-PMMDependencyWorker([string]$Id){
    $exe=Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
    $script=Join-Path $Script:Root 'Modules\Unreal\Dependencies.Worker.ps1'
    $args=(@(@('-NoProfile','-NonInteractive','-ExecutionPolicy','Bypass','-File',$script,'-Root',$Script:Root,'-JobId',$Id)|ForEach-Object{ConvertTo-PMMNativeArgument $_}) -join ' ')
    $p=Start-Process $exe -ArgumentList $args -WindowStyle Hidden -PassThru
    $p.Dispose()
}
function Request-PMMDependencyInstall([string]$Component,[string]$CaseId=''){
    if($CaseId){[void](Get-PMMMCPCase $CaseId)}
    if($Component -notin @('all')+@(Get-PMMDependencyDefinitions|ForEach-Object{$_.id})){throw 'Component is not in PMM catalog.'}
    $root=Get-PMMDependencyRoot;[void][IO.Directory]::CreateDirectory((Join-Path $root 'Jobs'))
    $gate=[IO.File]::Open((Join-Path $root 'requests.lock'),[IO.FileMode]::OpenOrCreate,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)
    try{
        foreach($file in @(Get-ChildItem (Join-Path $root 'Jobs') -Filter *.json)){
            $old=Read-PMMMCPJson $file.FullName
            if($old.operation -eq 'install' -and $old.component -eq $Component -and $old.caseId -eq $CaseId -and $old.status -in @('AWAITING_CONSENT','QUEUED','RUNNING','WAITING_EXTERNAL')){
                if($Component -in @('wwise','wwiseintegration') -and $old.status -eq 'WAITING_EXTERNAL'){
                    $old.status='QUEUED';Write-PMMAIIOJsonAtomic $file.FullName $old 8;Start-PMMDependencyWorker $old.id
                }
                return $old
            }
        }
        $policy=Get-PMMDependencyPolicy
        $auto=$policy.mode -eq 'automatic' -and $policy.catalogVersion -eq 1
        $id=[guid]::NewGuid().ToString('N')
        $job=[pscustomobject]@{id=$id;operation='install';component=$Component;caseId=$CaseId;status=$(if($auto){'QUEUED'}else{'AWAITING_CONSENT'});message='Installation requested';automatic=$auto;cancel=$false;createdUtc=[DateTime]::UtcNow.ToString('o')}
        Write-PMMAIIOJsonAtomic (Get-PMMDependencyJobPath $id) $job 8
        if($auto){Start-PMMDependencyWorker $id}
        return $job
    }finally{$gate.Dispose()}
}
function Approve-PMMDependencyInstall([string]$Id,[string]$Mode){
    $path=Get-PMMDependencyJobPath $Id;$job=Read-PMMMCPJson $path
    if($job.status -ne 'AWAITING_CONSENT'){throw 'Request is no longer awaiting consent.'}
    Set-PMMDependencyPolicy $Mode
    $job.automatic=$Mode -eq 'automatic';$job.status='QUEUED'
    Write-PMMAIIOJsonAtomic $path $job 8
    Start-PMMDependencyWorker $Id
}
function Cancel-PMMDependencyInstall([string]$Id){
    $path=Get-PMMDependencyJobPath $Id;$job=Read-PMMMCPJson $path
    $job.cancel=$true;$job.status='CANCELLED';$job.message='Cancelled; no further installers will start.'
    Write-PMMAIIOJsonAtomic $path $job 8
    return $job
}
function Get-PMMDependencyJob([string]$Id,[string]$CaseId=''){
    $job=Read-PMMMCPJson (Get-PMMDependencyJobPath $Id)
    if($CaseId -and $job.caseId -cne $CaseId){throw 'Dependency job belongs to another case.'}
    if($job.status -eq 'WAITING_EXTERNAL'){
        $rows=@(Get-PMMDependencyCatalog)
        $missing=@($rows|Where-Object{(-not $_.installed) -and (($job.component -eq 'all' -and $_.id -ne 'chatgpt') -or $_.id -eq $job.component)})
        if(-not $missing.Count){$job.status='COMPLETE';$job.message='Requested components detected; project verification is separate.';Write-PMMAIIOJsonAtomic (Get-PMMDependencyJobPath $Id) $job 8}
    }
    return $job
}

function Open-PMMDependencyComponent([string]$Component){
    $pf86=[Environment]::GetEnvironmentVariable('ProgramFiles(x86)')
    switch($Component){
        'chatgpt' {Open-PMMChatGPTDesktop}
        'unreal' {Open-PMMUnrealInstaller}
        'visualstudio' {
            $setup=Join-Path $pf86 'Microsoft Visual Studio/Installer/setup.exe'
            if(Test-Path $setup){Start-Process -FilePath $setup -WindowStyle Normal}else{throw 'Visual Studio Installer is not installed.'}
        }
        'windowssdk' {Start-Process explorer.exe -ArgumentList ('"'+(Join-Path $pf86 'Windows Kits/10')+'"')}
        'dotnet6' {Start-Process explorer.exe -ArgumentList ('"'+(Join-Path $env:ProgramFiles 'dotnet/shared/Microsoft.NETCore.App')+'"')}
        'wwise' {$p=(Get-PMMUnrealEnvironment).wwiseSdk;if($p){Start-Process explorer.exe -ArgumentList (ConvertTo-PMMNativeArgument $p)}else{Start-Process (Get-PMMUnrealProfile).urls.wwise}}
        'wwiseintegration' {$p=(Get-PMMUnrealEnvironment).wwiseIntegration;if($p){if(Test-Path -LiteralPath $p -PathType Leaf){$p=Split-Path $p -Parent};Start-Process explorer.exe -ArgumentList (ConvertTo-PMMNativeArgument $p)}else{Open-PMMAudiokineticLauncher}}
        'kit' {Start-Process explorer.exe -ArgumentList ('"'+(Resolve-PMMMCPPath (Get-PMMUnrealRoot) 'Downloads')+'"')}
        default {throw 'Component is not in PMM catalog.'}
    }
}

function Repair-PMMDependencyJobStates($Rows){
    foreach($file in @(Get-ChildItem (Join-Path (Get-PMMDependencyRoot) 'Jobs') -Filter *.json -ErrorAction SilentlyContinue)){
        $j=Read-PMMMCPJson $file.FullName
        if($j.operation -ne 'install' -or $j.cancel){continue}
        $changed=$false
        if($j.status -eq 'WAITING_EXTERNAL'){
            $missing=@($Rows|Where-Object{-not $_.installed -and (($j.component -eq 'all' -and $_.id -ne 'chatgpt') -or $_.id -eq $j.component)})
            if(-not $missing.Count){$j.status='COMPLETE';$j.message='Requested components detected; project verification is separate.';$changed=$true}
        }elseif($j.status -in @('QUEUED','RUNNING')){
            $alive=$false
            if($j.PSObject.Properties.Name -contains 'workerPid'){
                $p=Get-Process -Id $j.workerPid -ErrorAction SilentlyContinue
                if($p){try{$alive=$p.StartTime.ToUniversalTime().ToString('o') -eq $j.workerStartedUtc}catch{}}
            }
            if(-not $alive -and [DateTime]::Parse($j.createdUtc).ToUniversalTime() -lt [DateTime]::UtcNow.AddMinutes(-1)){
                $j.status='INTERRUPTED';$j.message='Installation worker stopped. Check any official installer still open before retrying.';$changed=$true
            }
        }
        if($changed){Write-PMMAIIOJsonAtomic $file.FullName $j 8}
    }
}
