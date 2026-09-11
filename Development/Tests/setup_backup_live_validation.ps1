param([Parameter(Mandatory=$true)][string]$Archive,[Parameter(Mandatory=$true)][string]$ExpectedSha256)
$ErrorActionPreference='Stop'
$repo=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$app=Join-Path $repo 'PMM'
$target=Join-Path $repo ('Development\TestResults\RecoveredSetup-'+[guid]::NewGuid().ToString('N'))
$restore=Join-Path $app 'Resources\Unreal\Restore-OfflineBackup.ps1'
Write-Host 'Verifying downloaded archive'
$verified=& $restore -Archive $Archive -ExpectedSha256 $ExpectedSha256 -PmmRoot $target -VerifyOnly
if(Test-Path $target){throw 'VerifyOnly modified destination'}
Write-Host 'Restoring into isolated workspace'
$result=& $restore -Archive $Archive -ExpectedSha256 $ExpectedSha256 -PmmRoot $target
Write-Host 'Checking idempotent reuse'
$again=& $restore -Archive $Archive -ExpectedSha256 $ExpectedSha256 -PmmRoot $target
if($again.copied -ne 0 -or $again.reused -ne $result.files){throw 'Restore was not idempotent'}
. (Join-Path $app 'Modules/MCP/MCP.Service.ps1')
$Script:Root=$target
Write-Host 'Checking PMM offline discovery and signature'
$exe=Get-PMMWwiseOfflineInstaller
if(-not $exe -or -not $exe.StartsWith($target,[StringComparison]::OrdinalIgnoreCase)){throw 'Restored offline installer not recognized'}
$archivePath=Join-Path $target 'Workspace/Dependencies/Offline/Wwise-2021.1.11/Wwise_Unreal_Integration_2021.1.11.2437/Unreal.5.0.tar.xz'
$integration=Resolve-PMMWwiseIntegrationLocation $archivePath
if($integration -ne $archivePath){throw 'Restored integration location not recognized'}
$Script:Root=$app
$installed=Get-PMMUnrealEnvironment
$profile=Get-PMMUnrealProfile
$kit=Join-Path (Get-PMMUnrealRoot) ('Downloads/'+$profile.kitCommit+'.zip')
$kitOK=(Test-Path $kit) -and ((Get-FileHash $kit).Hash -ieq $profile.kitSha256)
[pscustomobject]@{restore=$result;idempotent=$true;offlineInstallerRecognized=$true;signature='Valid Audiokinetic publisher checked by PMM';integrationLocationRecognized=$true;installedComponents=@{engineVersion=$installed.engineVersion;compatible=$installed.compatible;readyToPrepare=$installed.readyToPrepare;missing=@($installed.missing);kitHashVerified=$kitOK};installersExecuted=$false;realUnrealValidation='NOT_VERIFIED'}|ConvertTo-Json -Depth 8
