Set-StrictMode -Version 2.0;$ErrorActionPreference='Stop'
$repo=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$fixture=Join-Path $repo ('Development\TestResults\Locations-'+[guid]::NewGuid().ToString('N'))
. (Join-Path $repo 'PMM\Modules\Unreal\Dependency.Locations.ps1')
function Read-PMMMCPJson($Path){Get-Content -LiteralPath $Path -Raw|ConvertFrom-Json}
$Script:saved=[pscustomobject]@{enabled=$false;engineRoot='';wwiseSdk='';wwiseIntegration=''}
function Get-PMMUnrealSettings {$Script:saved|ConvertTo-Json|ConvertFrom-Json}
function Save-PMMUnrealSettings($Settings){$Script:saved=$Settings}
function Get-PMMWwiseOfflineInstaller {return $null}
function Put($Path,$Text){[void][IO.Directory]::CreateDirectory((Split-Path $Path -Parent));[IO.File]::WriteAllText($Path,$Text)}
$sdk=Join-Path $fixture 'custom\Wwise 2021.1.11\SDK'
$header=Join-Path $sdk 'include\AK\AkWwiseSDKVersion.h'
Put $header "#define AK_WWISESDK_VERSION_MAJOR 2021`n#define AK_WWISESDK_VERSION_MINOR 1`n#define AK_WWISESDK_VERSION_SUBMINOR 11`n"
if(Resolve-PMMWwiseSDKLocation $sdk){throw 'Incomplete SDK accepted'}
foreach($p in @('Win32_vc170','x64_vc170')){Put (Join-Path $sdk ($p+'\Release\lib\AkSoundEngine.lib')) 'fixture'}
$exe=Join-Path (Split-Path $sdk -Parent) 'Authoring\x64\Release\bin\Wwise.exe';Put $exe 'fixture'
foreach($p in @($sdk,$header,$exe,(Split-Path $sdk -Parent))){if((Resolve-PMMWwiseSDKLocation $p) -ne $sdk){throw "Cannot resolve SDK from $p"}}
$r=Set-PMMDependencyLocation 'wwise' $exe
if($r.status -ne 'DETECTED' -or $Script:saved.wwiseSdk -ne $sdk){throw 'Validated SDK not saved'}
$before=$Script:saved|ConvertTo-Json
$rejected=$false;try{Set-PMMDependencyLocation 'wwise' (Join-Path $fixture 'absent')}catch{$rejected=$true}
if(-not $rejected -or ($Script:saved|ConvertTo-Json) -ne $before){throw 'Bad path changed settings'}
Put $header "#define AK_WWISESDK_VERSION_MAJOR 2021`n#define AK_WWISESDK_VERSION_MINOR 1`n#define AK_WWISESDK_VERSION_SUBMINOR 12`n"
if(Resolve-PMMWwiseSDKLocation $sdk){throw 'Wrong patch accepted'}
$ue=Join-Path $fixture 'UE_5.1';$build=Join-Path $ue 'Engine\Build\Build.version'
Put $build '{"MajorVersion":5,"MinorVersion":1,"PatchVersion":1}'
$cmd=Join-Path $ue 'Engine\Binaries\Win64\UnrealEditor-Cmd.exe';Put $cmd 'fixture'
if((Set-PMMDependencyLocation unreal $cmd).path -ne $ue){throw 'Engine exe not normalized'}
Put $build '{"MajorVersion":5,"MinorVersion":8,"PatchVersion":2}'
$rejected=$false;try{Set-PMMDependencyLocation unreal $cmd}catch{$rejected=$true};if(-not $rejected){throw 'Wrong engine accepted'}
$plugin=Join-Path $fixture 'Integration\Wwise.uplugin';Put $plugin '{"VersionName":"2021.1.11.7933"}'
if(-not(Resolve-PMMWwiseIntegrationLocation $plugin)){throw 'Integration not normalized'}
Put $plugin '{"VersionName":"2021.1.12"}'
if(Resolve-PMMWwiseIntegrationLocation $plugin){throw 'Wrong integration accepted'}
'LOCATIONS_OK: root/header/exe normalization, missing libs, wrong versions, validation before persistence.'
