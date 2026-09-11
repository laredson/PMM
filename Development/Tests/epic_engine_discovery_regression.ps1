$ErrorActionPreference='Stop'
Set-StrictMode -Version 2.0
$repo=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
. (Join-Path $repo 'PMM\Modules\Unreal\Unreal.Service.ps1')
function Read-PMMMCPJson($Path){Get-Content -LiteralPath $Path -Raw|ConvertFrom-Json}
$dir=Join-Path $repo ('Development\TestResults\EpicDiscovery-'+[guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($dir)
[IO.File]::WriteAllText((Join-Path $dir 'bad.item'),'{')
[IO.File]::WriteAllText((Join-Path $dir 'game.item'),' {"AppName":"OtherGame","InstallLocation":"D:\\Game"}')
[IO.File]::WriteAllText((Join-Path $dir 'engine.item'),' {"AppName":"UE_5.1","InstallLocation":"D:\\Custom Epic\\UE_5.1"}')
$found=@(Get-PMMEpicEngineRoots $dir)
if($found.Count -ne 1 -or $found[0] -ne 'D:\Custom Epic\UE_5.1'){throw 'Unexpected discovery result'}
'EPIC_DISCOVERY_OK: custom location found, unrelated game and malformed manifest ignored.'
