function Get-PMMWwiseOfflineRoot {
    return (Resolve-PMMMCPPath (Get-PMMDependencyRoot) 'Offline\Wwise-2021.1.11')
}
function Get-PMMWwiseOfflineInstaller([string]$Location='') {
    $roots=@()
    if($Location){$roots=@(Get-PMMDependencyAncestors $Location)}else{
        if(Get-Command Get-PMMUnrealSettings -ErrorAction SilentlyContinue){$cfg=Get-PMMUnrealSettings;if($cfg.PSObject.Properties['wwiseOffline'] -and $cfg.wwiseOffline){$roots+=@($cfg.wwiseOffline)}}
        $roots+=@(Get-PMMWwiseOfflineRoot)
    }
    foreach($root in @($roots|Select-Object -Unique)){
        $dirs=@($root)+@(Get-ChildItem -LiteralPath $root -Directory -ErrorAction SilentlyContinue | Where-Object{$_.Name -match '^Wwise'} | ForEach-Object{$_.FullName})
        foreach($dir in $dirs){
            $bundle=Join-Path $dir 'bundle'
            if(-not(Test-Path -LiteralPath $bundle -PathType Container)){continue}
            $entry=Join-Path $bundle 'install-entry.json';$manifest=Join-Path $bundle 'bundle.json'
            if(-not(Test-Path -LiteralPath $entry) -or -not(Test-Path -LiteralPath $manifest)){continue}
            try{$data=Read-PMMMCPJson $entry;$files=Read-PMMMCPJson $manifest}catch{continue}
            if($data.bundle.id -ne 'wwise.2021_1_11_7933' -or $data.installType -ne 'package'){continue}
            $complete=$true
            foreach($id in @('SDK.tar.xz','SDK.Windows_vc170.tar.xz')){
                $part=@($files.files|Where-Object{$_.id -eq $id})
                if($part.Count -ne 1){$complete=$false;break}
                if([IO.Path]::GetFileName($part[0].sourceName) -cne $part[0].sourceName){$complete=$false;break}
                $file=Join-Path $bundle $part[0].sourceName
                if(-not(Test-Path -LiteralPath $file -PathType Leaf) -or (Get-Item -LiteralPath $file).Length -ne $part[0].size){$complete=$false;break}
            }
            if(-not $complete){continue}
            foreach($exe in @(Get-ChildItem -LiteralPath $dir -File -ErrorAction SilentlyContinue | Where-Object{$_.Name -eq 'WwiseLauncher.exe' -or $_.Name -match '^AudiokineticLauncher-\d+(\.\d+){3}\.exe$'})){
                $sig=Get-AuthenticodeSignature -LiteralPath $exe.FullName
                if($sig.Status -ne 'Valid' -or -not $sig.SignerCertificate -or $sig.SignerCertificate.Subject -notmatch '(?i)(CN|O)="?Audiokinetic(?: Inc\.?)?"?(,|$)'){throw 'Offline launcher signature must be valid and issued to Audiokinetic.'}
                return $exe.FullName
            }
        }
    }
    return $null
}
function Open-PMMWwiseOfflineFolder {
    $root=Get-PMMWwiseOfflineRoot
    [void][IO.Directory]::CreateDirectory($root)
    Start-Process explorer.exe -ArgumentList (ConvertTo-PMMNativeArgument $root)
}
function Open-PMMWwiseOfflineInstaller {
    $exe=Get-PMMWwiseOfflineInstaller
    if(-not $exe){return $false}
    # Official offline installer retains package selection and final Install confirmation.
    Start-Process -FilePath $exe -WorkingDirectory (Split-Path $exe -Parent) -WindowStyle Normal
    return $true
}

function Get-PMMAudiokineticLauncher {
    $candidates=@()
    foreach($p in @(Get-Process -Name 'Wwise Launcher','WwiseLauncher','Audiokinetic Launcher' -ErrorAction SilentlyContinue)){if($p.Path){$candidates+=@($p.Path)}}
    foreach($base in @($env:ProgramFiles,[Environment]::GetEnvironmentVariable('ProgramFiles(x86)'),$env:LocalAppData)){
        if($base){foreach($relative in @('Wwise Launcher\Wwise Launcher.exe','Audiokinetic\Launcher\Audiokinetic Launcher.exe','Audiokinetic\Wwise Launcher\WwiseLauncher.exe','Programs\Wwise Launcher\Wwise Launcher.exe')){$candidates+=@(Join-Path $base $relative)}}
    }
    foreach($key in @('HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*','HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*','HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*')){
        foreach($entry in @(Get-ItemProperty $key -ErrorAction SilentlyContinue)){
            if($entry.PSObject.Properties['DisplayName'] -and $entry.DisplayName -match '(Wwise|Audiokinetic).*Launcher' -and $entry.PSObject.Properties['InstallLocation'] -and $entry.InstallLocation){
                foreach($name in @('Wwise Launcher.exe','WwiseLauncher.exe','Audiokinetic Launcher.exe')){$candidates+=@(Join-Path $entry.InstallLocation $name)}
            }
        }
    }
    foreach($file in @($candidates|Select-Object -Unique)){
        if(-not(Test-Path -LiteralPath $file -PathType Leaf)){continue}
        $sig=Get-AuthenticodeSignature -LiteralPath $file
        if($sig.Status -eq 'Valid' -and $sig.SignerCertificate -and $sig.SignerCertificate.Subject -match '(?i)(CN|O)="?Audiokinetic(?: Inc\.?)?"?(,|$)'){return $file}
    }
    return $null
}
function Open-PMMAudiokineticLauncher {
    $launcher=Get-PMMAudiokineticLauncher
    if($launcher){
        $offline=@(Get-CimInstance Win32_Process -ErrorAction SilentlyContinue | Where-Object{$_.ExecutablePath -ieq $launcher -and $_.CommandLine -match '(?:^|\s)--install(?:=|\s)'})
        if($offline.Count){return 'OFFLINE_SESSION_OPEN'}
        Start-Process -FilePath $launcher -WorkingDirectory (Split-Path $launcher -Parent) -WindowStyle Normal
        return 'OPENED'
    }
    Start-Process (Get-PMMUnrealProfile).urls.wwise
    return 'LAUNCHER_MISSING'

}
function Get-PMMWwiseIntegrationDownloadRoot {return (Resolve-PMMMCPPath (Get-PMMDependencyRoot) 'Offline\Wwise-Unreal-2021.1.11')}
function Open-PMMWwiseIntegrationDownloadFolder {
    $root=Get-PMMWwiseIntegrationDownloadRoot;[void][IO.Directory]::CreateDirectory($root)
    Start-Process explorer.exe -ArgumentList (ConvertTo-PMMNativeArgument $root)
}
