
function Assert-PMMEpicInstaller([string]$Path) {
    $p=Resolve-PMMMCPPath $Path
    if([IO.Path]::GetExtension($p) -ine '.msi'){throw 'Select the official Epic Games Launcher MSI installer.'}
    $sig=Get-AuthenticodeSignature -LiteralPath $p
    if($sig.Status -ne 'Valid' -or -not $sig.SignerCertificate -or $sig.SignerCertificate.Subject -notmatch '(?i)(CN|O)=("?Epic Games[,]? Inc\.?"?)(,|$)'){throw 'Installer signature must be valid and issued to Epic Games, Inc.'}
    return $p
}
function Get-PMMEpicLauncher {
    $candidates=[Collections.Generic.List[string]]::new()
    foreach($process in @(Get-Process EpicGamesLauncher -ErrorAction SilentlyContinue)){
        if($process.Path){$candidates.Add($process.Path)}
    }
    foreach($key in @('HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*','HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*','HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*')){
        foreach($entry in @(Get-ItemProperty $key -ErrorAction SilentlyContinue)){
            if($entry.PSObject.Properties['DisplayName'] -and $entry.DisplayName -eq 'Epic Games Launcher' -and $entry.PSObject.Properties['InstallLocation'] -and $entry.InstallLocation){
                $candidates.Add((Join-Path $entry.InstallLocation 'Portal\Binaries\Win64\EpicGamesLauncher.exe'))
                $candidates.Add((Join-Path $entry.InstallLocation 'Portal\Binaries\Win32\EpicGamesLauncher.exe'))
            }
        }
    }
    foreach($base in @([Environment]::GetEnvironmentVariable('ProgramFiles(x86)'),$env:ProgramFiles)){
        if($base){$candidates.Add((Join-Path $base 'Epic Games\Launcher\Portal\Binaries\Win64\EpicGamesLauncher.exe'))}
    }
    foreach($candidate in @($candidates|Select-Object -Unique)){
        if(-not(Test-Path -LiteralPath $candidate -PathType Leaf)){continue}
        $signature=Get-AuthenticodeSignature -LiteralPath $candidate
        if($signature.Status -eq 'Valid' -and $signature.SignerCertificate -and $signature.SignerCertificate.Subject -match '(?i)(CN|O)=("?Epic Games[,]? Inc\.?"?)(,|$)'){return $candidate}
    }
    return $null
}
function ConvertTo-PMMInstallerCommandLine([string[]]$Arguments){
    # MSI parses switches itself; keep switches unquoted and quote argument values.
    return (@($Arguments|ForEach-Object{if($_ -match '^[/-][A-Za-z][A-Za-z0-9-]*$'){$_}else{ConvertTo-PMMNativeArgument $_}}) -join ' ')
}
function Open-PMMUnrealInstaller {
    $launcher=Get-PMMEpicLauncher
    if($launcher){Start-Process -FilePath $launcher -WindowStyle Normal;return}
    Start-Process (Get-PMMUnrealProfile).urls.epic
}
