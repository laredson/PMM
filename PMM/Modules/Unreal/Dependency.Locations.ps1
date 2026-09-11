# Location discovery reads bounded vendor folders; selected executables are never run.
function Get-PMMDependencyAncestors([string]$Path) {
    if(-not $Path -or -not(Test-Path -LiteralPath $Path)){return}
    $p=[IO.Path]::GetFullPath($Path)
    if(Test-Path -LiteralPath $p -PathType Leaf){$p=Split-Path $p -Parent}
    for($i=0;$i -lt 6 -and $p;$i++){$p;$p=Split-Path $p -Parent}
}
function Resolve-PMMWwiseSDKLocation([string]$Path) {
    foreach($parent in @(Get-PMMDependencyAncestors $Path)){
        foreach($sdk in @($parent,(Join-Path $parent 'SDK'))){
            $header=Join-Path $sdk 'include\AK\AkWwiseSDKVersion.h'
            if(-not(Test-Path -LiteralPath $header -PathType Leaf)){continue}
            $text=[IO.File]::ReadAllText($header)
            if($text -notmatch '(?m)^\s*#define\s+AK_WWISESDK_VERSION_MAJOR\s+2021\b' -or $text -notmatch '(?m)^\s*#define\s+AK_WWISESDK_VERSION_MINOR\s+1\b' -or $text -notmatch '(?m)^\s*#define\s+AK_WWISESDK_VERSION_SUBMINOR\s+11\b'){continue}
            $complete=$true
            foreach($platform in @('Win32_vc170','x64_vc170')){
                if(-not @(Get-ChildItem -LiteralPath (Join-Path $sdk $platform) -Filter AkSoundEngine.lib -File -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1).Count){$complete=$false}
            }
            if($complete){return $sdk}
        }
    }
    return ''
}
function Get-PMMWwiseSearchRoots {
    foreach($scope in @('Process','User','Machine')){
        $p=[Environment]::GetEnvironmentVariable('WWISEROOT',$scope);if($p){$p}
    }
    foreach($base in @($env:ProgramFiles,[Environment]::GetEnvironmentVariable('ProgramFiles(x86)'))){if($base){Join-Path $base 'Audiokinetic'}}
    foreach($key in @('HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*','HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*','HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*')){
        foreach($entry in @(Get-ItemProperty $key -ErrorAction SilentlyContinue)){
            if($entry.PSObject.Properties['DisplayName'] -and $entry.DisplayName -match '^Wwise' -and $entry.PSObject.Properties['InstallLocation'] -and $entry.InstallLocation){$entry.InstallLocation}
        }
    }
    Join-Path $Script:Root 'Workspace\Dependencies\Offline\Wwise-2021.1.11'
}
function Find-PMMWwiseSDK([string]$Configured) {
    $locations=@($Configured)+@(Get-PMMWwiseSearchRoots)
    foreach($root in @($locations|Where-Object{$_}|Select-Object -Unique)){
        $found=Resolve-PMMWwiseSDKLocation $root;if($found){return $found}
        # Vendor roots and generated version subfolders only, never scan a whole drive.
        foreach($dir in @(Get-ChildItem -LiteralPath $root -Directory -ErrorAction SilentlyContinue | Where-Object{$_.Name -match '^Wwise'})){
            $found=Resolve-PMMWwiseSDKLocation $dir.FullName;if($found){return $found}
        }
    }
    return ''
}
function Resolve-PMMWwiseIntegrationLocation([string]$Path) {
    if(-not $Path -or -not(Test-Path -LiteralPath $Path)){return ''}
    if(Test-Path -LiteralPath $Path -PathType Leaf){
        if([IO.Path]::GetFileName($Path) -eq 'Unreal.5.0.tar.xz'){
            # Archive structure and plugin version are validated again during preparation.
            return [IO.Path]::GetFullPath($Path)
        }
    }
    foreach($parent in @(Get-PMMDependencyAncestors $Path)){
        foreach($dir in @($parent,(Join-Path $parent 'Wwise'),(Join-Path $parent 'Plugins\Wwise'))){
            $file=Join-Path $dir 'Wwise.uplugin'
            if(Test-Path -LiteralPath $file -PathType Leaf){try{$p=Read-PMMMCPJson $file;if($p.VersionName -match '^2021\.1\.11(?:\D|$)'){return $dir}}catch{}}
        }
    }
    return ''
}
function Set-PMMDependencyLocation([ValidateSet('unreal','wwise','wwiseintegration')][string]$Component,[string]$Path) {
    $cfg=Get-PMMUnrealSettings;$value='';$kind='';$state='DETECTED'
    switch($Component){
        'unreal' {
            foreach($dir in @(Get-PMMDependencyAncestors $Path)){
                $build=Join-Path $dir 'Engine\Build\Build.version'
                if(Test-Path -LiteralPath $build){$v=Read-PMMMCPJson $build;if($v.MajorVersion -eq 5 -and $v.MinorVersion -eq 1 -and $v.PatchVersion -eq 1 -and (Test-Path -LiteralPath (Join-Path $dir 'Engine\Binaries\Win64\UnrealEditor-Cmd.exe'))){$value=$dir;break}}
            }
            $kind='engineRoot'
        }
        'wwise' {
            $value=Resolve-PMMWwiseSDKLocation $Path;$kind='wwiseSdk'
            if(-not $value){$exe=Get-PMMWwiseOfflineInstaller -Location $Path;if($exe){$value=Split-Path $exe -Parent;$kind='wwiseOffline';$state='OFFLINE_READY'}}
        }
        'wwiseintegration' {$value=Resolve-PMMWwiseIntegrationLocation $Path;$kind='wwiseIntegration'}
    }
    if(-not $value){throw 'No compatible component found / No se encontro el componente compatible. UE: 5.1.1; Wwise SDK: 2021.1.11 + Win32/x64 vc170; integration: Unreal.5.0.tar.xz or Wwise.uplugin 2021.1.11.'}
    $cfg|Add-Member -NotePropertyName $kind -NotePropertyValue $value -Force
    Save-PMMUnrealSettings $cfg
    return [pscustomobject]@{path=$value;status=$state;setting=$kind}
}
