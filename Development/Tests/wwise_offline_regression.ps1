$ErrorActionPreference='Stop'
$repo=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$Script:Root=Join-Path $repo ('Development\TestResults\WwiseOffline-'+[guid]::NewGuid().ToString('N'))
function Get-PMMDependencyRoot {return $Script:Root}
function Resolve-PMMMCPPath($Root,$Relative){return (Join-Path $Root $Relative)}
. (Join-Path $repo 'PMM\Modules\Unreal\Dependency.Locations.ps1')
. (Join-Path $repo 'PMM\Modules\Unreal\Wwise.Offline.ps1')
function Read-PMMMCPJson($Path){Get-Content -LiteralPath $Path -Raw|ConvertFrom-Json}
if(Get-PMMWwiseOfflineInstaller){throw 'Missing package accepted'}
$dir=Get-PMMWwiseOfflineRoot
[void][IO.Directory]::CreateDirectory((Join-Path $dir 'bundle'))
[IO.File]::WriteAllText((Join-Path $dir 'WwiseLauncher.exe'),'fixture')
if(Get-PMMWwiseOfflineInstaller){throw 'Empty bundle accepted'}
[IO.File]::WriteAllText((Join-Path $dir 'bundle\fixture'),'fixture')
@{bundle=@{id='wwise.2021_1_11_7933'};installType='package'}|ConvertTo-Json -Depth 6|Set-Content (Join-Path $dir 'bundle\install-entry.json')
@{files=@(@{id='SDK.tar.xz';sourceName='SDK.tar.xz';size=7},@{id='SDK.Windows_vc170.tar.xz';sourceName='SDK.Windows_vc170.tar.xz';size=7})}|ConvertTo-Json -Depth 6|Set-Content (Join-Path $dir 'bundle\bundle.json')
foreach($name in @('SDK.tar.xz','SDK.Windows_vc170.tar.xz')){[IO.File]::WriteAllText((Join-Path $dir ('bundle\'+$name)),'fixture')}
function Get-AuthenticodeSignature {return @{Status='NotSigned';SignerCertificate=$null}}
$rejected=$false
try{Get-PMMWwiseOfflineInstaller|Out-Null}catch{$rejected=$true}
if(-not $rejected){throw 'Unsigned launcher accepted'}
function Get-AuthenticodeSignature {return @{Status='Valid';SignerCertificate=@{Subject='CN=Unrelated Inc., O=Unrelated Inc.'}}}
$rejected=$false
try{Get-PMMWwiseOfflineInstaller|Out-Null}catch{$rejected=$true}
if(-not $rejected){throw 'Wrong publisher accepted'}
function Get-AuthenticodeSignature {return @{Status='Valid';SignerCertificate=@{Subject='CN=Audiokinetic Inc., O=Audiokinetic Inc., C=CA'}}}
if((Get-PMMWwiseOfflineInstaller) -ne (Join-Path $dir 'WwiseLauncher.exe')){throw 'Expected fixture path'}

$nested=Join-Path $dir 'Wwise_2021.1.11.7933'
[void][IO.Directory]::CreateDirectory($nested)
Copy-Item (Join-Path $dir 'bundle') (Join-Path $nested 'bundle') -Recurse
[IO.File]::WriteAllText((Join-Path $nested 'AudiokineticLauncher-2026.1.1.6296.exe'),'fixture')
Rename-Item -LiteralPath (Join-Path $dir 'WwiseLauncher.exe') -NewName 'legacy.disabled'
$expected=Join-Path $nested 'AudiokineticLauncher-2026.1.1.6296.exe'
if((Get-PMMWwiseOfflineInstaller) -ne $expected){throw 'Nested modern launcher not found'}
if((Get-PMMWwiseOfflineInstaller -Location (Join-Path $nested 'bundle')) -ne $expected){throw 'Selecting bundle did not normalize'}
[IO.File]::WriteAllText((Join-Path $nested 'bundle\SDK.tar.xz'),'partial')
[IO.File]::WriteAllText((Join-Path $nested 'bundle\SDK.Windows_vc170.tar.xz'),'bad')
if(Get-PMMWwiseOfflineInstaller){throw 'Truncated bundle accepted'}
'WWISE_OFFLINE_OK: metadata, size, version, signature, legacy and nested modern paths. No installer executed.'
