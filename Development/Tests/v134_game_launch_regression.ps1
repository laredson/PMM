Set-StrictMode -Version 2;$ErrorActionPreference='Stop'
$repo=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
. (Join-Path $repo 'PMM/Modules/Shared/GameLocator.ps1')
$fixture=Join-Path $repo ('Development/TestResults/Steam134-'+[guid]::NewGuid().ToString('N'))
$game=Join-Path $fixture 'steamapps/common/Palworld'
[void][IO.Directory]::CreateDirectory($game);[IO.File]::WriteAllText((Join-Path $game 'Palworld.exe'),'fixture: never execute')
$script:config=[pscustomobject]@{GamePath=$game}
function Get-PMMConfig {return $script:config}
function Get-PMMText($en,$es){return $en}
$script:launch=$null
function Start-Process {param($FilePath,$WorkingDirectory,$ArgumentList)$script:launch=@{FilePath=$FilePath;WorkingDirectory=$WorkingDirectory;ArgumentList=$ArgumentList;ArgumentsBound=$PSBoundParameters.ContainsKey('ArgumentList')}}
$manifest=Join-Path $fixture 'steamapps/appmanifest_1623730.acf'
[IO.File]::WriteAllText($manifest,'"AppState" { "appid" "1623730" "installdir" "Palworld" }')
Start-Palworld
if($script:launch.FilePath -cne 'steam://rungameid/1623730' -or $script:launch.ArgumentsBound -or $script:launch.WorkingDirectory){throw 'Steam launch added arguments or bypassed Steam.'}
[IO.File]::WriteAllText($manifest,'"AppState" { "appid" "1623730" "installdir" "AnotherGame" }')
Start-Palworld
if($script:launch.FilePath -cne (Join-Path $game 'Palworld.exe') -or $script:launch.WorkingDirectory -cne $game){throw 'Mismatched Steam manifest hijacked a standalone install.'}
[IO.File]::WriteAllText($manifest,'"AppState" { "appid" "999" "installdir" "Palworld" }')
Start-Palworld
if($script:launch.FilePath -like 'steam:*'){throw 'Wrong Steam app selected.'}
$script:config.GamePath=Join-Path $fixture 'missing'
$blocked=$false;try{Start-Palworld}catch{$blocked=$true}
if(-not$blocked){throw 'Missing game was accepted.'}
'PASS game launch: 4 assertions, mocked process boundary; no game started.'
