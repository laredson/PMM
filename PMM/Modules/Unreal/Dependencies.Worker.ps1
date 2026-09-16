
param([string]$Root,[string]$JobId)
Set-StrictMode -Version 2.0
# Load the utility module from this host, not an inherited PowerShell 7 module path.
Import-Module (Join-Path $PSHOME 'Modules\Microsoft.PowerShell.Utility\Microsoft.PowerShell.Utility.psd1') -ErrorAction Stop
$ErrorActionPreference='Stop';$Script:Root=[IO.Path]::GetFullPath($Root)
# Use the security module belonging to this PowerShell, even when launched from PowerShell 7.
Import-Module (Join-Path $PSHOME 'Modules\Microsoft.PowerShell.Security\Microsoft.PowerShell.Security.psd1') -ErrorAction Stop
. (Join-Path $Root 'Modules\AIIO\AIIO.SessionService.ps1')
. (Join-Path $Root 'Modules\MCP\MCP.Service.ps1')
. (Join-Path $Root 'Modules\Unreal\Dependencies.Service.ps1')
. (Join-Path $Root 'Modules\Unreal\Unreal.Files.ps1')
. (Join-Path $Root 'Modules\Unreal\Unreal.Install.ps1')
$path=Get-PMMDependencyJobPath $JobId
$job=Read-PMMMCPJson $path
if($job.PSObject.Properties.Name -contains 'repairSessionId' -and $job.repairSessionId){. (Join-Path $Root 'Modules/Analysis/Services.ps1')}
function Check-InstallCancellation{
    $current=Read-PMMMCPJson $path
    if($current.cancel){throw 'Installation request cancelled.'}
    if($current.PSObject.Properties.Name -contains 'repairSessionId' -and $current.repairSessionId){
      $s=Get-PMMRepairSession $current.repairSessionId
      Assert-PMMRepairAuthorization $s.Id $current.caseId $s.EvidenceRevision Dependencies|Out-Null
    }
}
function Report-Install([string]$State,[string]$Message){
    $current=Read-PMMMCPJson $path
    if($current.cancel){throw 'Installation request cancelled.'}
    $current.status=$State;$current.message=$Message
    Write-PMMAIIOJsonAtomic $path $current 8
}
function Get-SignedPMMInstaller([string]$Url,[string]$File,[string]$Publisher){
    $dir=Resolve-PMMMCPPath (Get-PMMDependencyRoot) ('Downloads\'+$JobId)
    [void][IO.Directory]::CreateDirectory($dir)
    $dest=Resolve-PMMMCPPath $dir $File
    $client=[Net.WebClient]::new()
    try{
        $task=$client.DownloadFileTaskAsync([uri]$Url,$dest);$watch=[Diagnostics.Stopwatch]::StartNew()
        while(-not $task.Wait(250)){
            Check-InstallCancellation
            if($watch.Elapsed.TotalSeconds -gt 180 -or ((Test-Path $dest) -and (Get-Item $dest).Length -gt 128MB)){$client.CancelAsync();throw 'Installer download limit exceeded.'}
        }
    }finally{$client.CancelAsync();$client.Dispose()}
    if((Get-Item $dest).Length -gt 128MB){throw 'Installer download limit exceeded.'}
    $sig=Get-AuthenticodeSignature -LiteralPath $dest
    if($sig.Status -ne 'Valid' -or -not $sig.SignerCertificate -or $sig.SignerCertificate.Subject -notmatch $Publisher){throw 'Installer signature or publisher rejected.'}
    Check-InstallCancellation
    return $dest
}
function Run-PMMOfficialInstaller([string]$File,[string[]]$Arguments){
    Check-InstallCancellation
    $line=ConvertTo-PMMInstallerCommandLine $Arguments
    $p=Start-Process -FilePath $File -ArgumentList $line -Verb RunAs -WindowStyle Normal -PassThru
    $handle=$p.Handle
    try{
        $deadline=[DateTime]::UtcNow.AddHours(4)
        while(-not $p.WaitForExit(1000)){
            if([DateTime]::UtcNow -gt $deadline){throw 'Official installer is still open; check it before retrying.'}
            # Cancellation leaves the official installer responsible for its own rollback.
            Check-InstallCancellation
        }
        if($p.ExitCode -notin @(0,3010)){throw ('Official installer exited with '+$p.ExitCode)}
    }finally{$p.Dispose()}
}
$gate=$null
try{
    if($job.operation -eq 'scan'){$rows=@(Get-PMMDependencyCatalog);Repair-PMMDependencyJobStates $rows;Report-Install 'COMPLETE' 'Detection complete';return}
    if($job.status -ne 'QUEUED'){throw 'Installer job has not been approved.'}
    $job|Add-Member -NotePropertyName workerPid -NotePropertyValue $PID -Force
    $job|Add-Member -NotePropertyName workerStartedUtc -NotePropertyValue ((Get-Process -Id $PID).StartTime.ToUniversalTime().ToString('o')) -Force
    Write-PMMAIIOJsonAtomic $path $job 8
    $queueDeadline=[DateTime]::UtcNow.AddHours(4)
    while(-not $gate){
        Check-InstallCancellation
        try{$gate=[IO.File]::Open((Join-Path (Get-PMMDependencyRoot) 'install.lock'),[IO.FileMode]::OpenOrCreate,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)}
        catch [IO.IOException]{
            if(($_.Exception.HResult -band 65535) -notin @(32,33)){throw}
            if([DateTime]::UtcNow -gt $queueDeadline){throw 'Installation queue timed out; check the active installer.'}
            Report-Install 'QUEUED' 'Waiting for another PMM installation request to finish.'
            Start-Sleep -Seconds 2
        }
    }
    $rows=@(Get-PMMDependencyCatalog)
    $pending=@($rows|Where-Object{-not $_.installed -and (($job.component -eq 'all' -and $_.id -ne 'chatgpt') -or $_.id -eq $job.component)})
    $external=$false;$vsDone=$false;$audioOpened=$false;$audioState=''
    foreach($component in $pending){
        Check-InstallCancellation
        Report-Install 'RUNNING' ('Preparing '+$component.name)
        switch($component.id){
            'chatgpt' {
                $appInstaller=$null
                try{$appInstaller=Get-AppxPackage -Name Microsoft.DesktopAppInstaller -ErrorAction Stop | Select-Object -First 1}catch{}
                $winget=if($appInstaller){Join-Path $appInstaller.InstallLocation 'winget.exe'}else{''}
                $installed=$false
                if($winget -and (Test-Path $winget)){
                    $sig=Get-AuthenticodeSignature -LiteralPath $winget
                    if($sig.Status -ne 'Valid' -or -not $sig.SignerCertificate -or $sig.SignerCertificate.Subject -notmatch 'Microsoft'){throw 'WinGet signature rejected.'}
                    $p=Start-Process $winget -ArgumentList 'install --id 9PLM9XGG6VKS --exact --source msstore --silent --accept-package-agreements --accept-source-agreements --disable-interactivity' -WindowStyle Hidden -PassThru
                    try{$deadline=[DateTime]::UtcNow.AddMinutes(30);while(-not $p.WaitForExit(1000)){Check-InstallCancellation;if([DateTime]::UtcNow -gt $deadline){throw 'ChatGPT installation still running after 30 minutes. Check Microsoft Store before retrying.'}};$installed=$p.ExitCode -eq 0}finally{$p.Dispose()}
                }
                Check-InstallCancellation
                if(-not $installed){Start-Process 'ms-windows-store://pdp/?ProductId=9PLM9XGG6VKS';$external=$true}
            }
            {$_ -in @('visualstudio','windowssdk')} {
                if(-not $vsDone){
                    # An elevated installer may hide its executable path. In that case wait
                    # conservatively instead of starting a competing setup process.
                    $waitDeadline=[DateTime]::UtcNow.AddMinutes(30)
                    while(@(Get-Process -Name setup,vs_installer,vs_installershell -ErrorAction SilentlyContinue).Count){
                        Report-Install 'RUNNING' 'Waiting for the open installer to close. Let any installation finish, then close Visual Studio Installer; PMM will continue automatically.'
                        Check-InstallCancellation
                        if([DateTime]::UtcNow -gt $waitDeadline){throw 'Installer remained open for 30 minutes. Close it after its work finishes and retry.'}
                        Start-Sleep -Seconds 2
                    }
                    $envState=Get-PMMUnrealEnvironment
                    $installArgs=@('--quiet','--norestart')
                    if(-not $envState.msvc){$installArgs+=@('--add','Microsoft.VisualStudio.Component.VC.14.38.17.8.x86.x64')}
                    if(-not $envState.windowsSdk){$installArgs+=@('--add','Microsoft.VisualStudio.Component.Windows11SDK.22621')}
                    if($envState.visualStudioInstalled){
                        $file=Join-Path ([Environment]::GetEnvironmentVariable('ProgramFiles(x86)')) 'Microsoft Visual Studio\Installer\setup.exe'
                        $sig=Get-AuthenticodeSignature -LiteralPath $file
                        if($sig.Status -ne 'Valid' -or -not $sig.SignerCertificate -or $sig.SignerCertificate.Subject -notmatch '(?i)(CN|O)=Microsoft Corporation(,|$)'){throw 'Visual Studio Installer signature rejected.'}
                        $installArgs=@('modify','--installPath',$envState.visualStudioInstalled)+$installArgs
                    }else{
                        $file=Get-SignedPMMInstaller 'https://aka.ms/vs/17/release/vs_community.exe' 'vs_community.exe' '(?i)(CN|O)=Microsoft Corporation(,|$)'
                        $installArgs=@('--wait')+$installArgs
                    }
                    Run-PMMOfficialInstaller $file $installArgs
                    $vsDone=$true
                }
            }
            'dotnet6' {
                $file=Get-SignedPMMInstaller 'https://builds.dotnet.microsoft.com/dotnet/Runtime/6.0.36/dotnet-runtime-6.0.36-win-x64.exe' 'dotnet6.exe' '(?i)(CN|O)=Microsoft Corporation(,|$)'
                Run-PMMOfficialInstaller $file @('/install','/passive','/norestart')
            }
            'unreal' {
                $launcher=Get-PMMEpicLauncher
                if(-not $launcher){
                    $file=Get-SignedPMMInstaller 'https://launcher-public-service-prod06.ol.epicgames.com/launcher/api/installer/download/EpicGamesLauncherInstaller.msi' 'EpicGamesLauncherInstaller.msi' '(?i)(CN|O)=("?Epic Games[,]? Inc\.?"?)(,|$)'
                    Run-PMMOfficialInstaller (Join-Path $env:SystemRoot 'System32\msiexec.exe') @('/i',$file,'/norestart')
                }
                Open-PMMUnrealInstaller
                $external=$true
            }
            {$_ -in @('wwise','wwiseintegration')} {
                if(-not $audioOpened){
                    if($component.id -eq 'wwise' -and (Open-PMMWwiseOfflineInstaller)){Report-Install 'RUNNING' 'Official Wwise offline installer opened. Confirm 2021.1.11, SDK Win32/x64 vc170 and Install.'}
                    else{$audioState=Open-PMMAudiokineticLauncher}
                    $audioOpened=$true
                }
                $external=$true
            }
            'kit' {
                # Kit download is separately consented; it does not enable the editor.
                $profile=Get-PMMUnrealProfile
                $dir=Resolve-PMMMCPPath (Get-PMMUnrealRoot) 'Downloads';[void][IO.Directory]::CreateDirectory($dir)
                $dest=Join-Path $dir ($profile.kitCommit+'.zip')
                $client=[Net.WebClient]::new()
                try{
                    $task=$client.DownloadFileTaskAsync([uri]$profile.kitUrl,$dest+'.download');$watch=[Diagnostics.Stopwatch]::StartNew()
                    while(-not $task.Wait(250)){Check-InstallCancellation;if($watch.Elapsed.TotalSeconds -gt 180 -or ((Test-Path ($dest+'.download')) -and (Get-Item ($dest+'.download')).Length -gt 512MB)){throw 'Kit download limit exceeded'}}
                }finally{$client.CancelAsync();$client.Dispose()}
                if((Get-Item ($dest+'.download')).Length -gt 512MB){throw 'Kit download limit exceeded'}
                if((Get-FileHash ($dest+'.download')).Hash -ine $profile.kitSha256){throw 'Pinned kit checksum mismatch'}
                Move-Item -LiteralPath ($dest+'.download') -Destination $dest -Force
            }
        }
    }
    $remaining=@(Get-PMMDependencyCatalog|Where-Object{-not $_.installed -and (($job.component -eq 'all' -and $_.id -ne 'chatgpt') -or $_.id -eq $job.component)})
    if($remaining.Count -and $audioState -eq 'OFFLINE_SESSION_OPEN'){Report-Install 'WAITING_EXTERNAL' 'The Audiokinetic Launcher is running in offline-install mode. Let installation finish, close that launcher window, then press Install / complete again to open the connected launcher. / Finaliza la instalacion, cierra el launcher offline y pulsa Instalar / completar de nuevo.'}
    elseif($remaining.Count -eq 1 -and $remaining[0].id -eq 'wwiseintegration'){Report-Install 'WAITING_EXTERNAL' ('Audiokinetic Launcher > Unreal Engine > Download > Offline integration files > 2021.1.11. Save to: '+(Get-PMMWwiseIntegrationDownloadRoot))}
    elseif($remaining.Count){Report-Install 'WAITING_EXTERNAL' ('Complete official installer/launcher steps: '+(($remaining|ForEach-Object{$_.name}) -join ', '))}
    else{Report-Install 'COMPLETE' 'Requested dependencies detected; editor verification is separate.'}
}catch{
    $latest=Read-PMMMCPJson $path
    if(-not $latest.cancel){$latest.status='FAILED';$latest.message=$_.Exception.Message;Write-PMMAIIOJsonAtomic $path $latest 8}
}finally{if($gate){$gate.Dispose()}}
