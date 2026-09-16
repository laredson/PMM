param([ValidateSet('en','es')][string]$Language='en',[string]$AssertionScript='v132_bootstrap_assertions.ps1')
Set-StrictMode -Version 2;$ErrorActionPreference='Stop'
$repo=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$fixture=Join-Path $repo ('Development/TestResults/Bootstrap132-'+$Language+'-'+[guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($fixture)
foreach($part in @('Modules','Resources','CKL')){Copy-Item (Join-Path $repo ('PMM/'+$part)) (Join-Path $fixture $part) -Recurse}
$Script:Root=$fixture
. (Join-Path $fixture 'Modules/Shared/Paths.ps1');Initialize-PMMPaths $fixture|Out-Null
. (Join-Path $fixture 'Modules/Shared/Common.ps1');Initialize-PMM
$cfg=Get-PMMConfig;$cfg.Language=$Language;$cfg.GamePath='';Save-PMMConfig $cfg
$boot=Join-Path $fixture 'Modules/Bootstrap/Start-PalModMerger.ps1'
$source=[IO.File]::ReadAllText($boot).Replace("`r`n","`n")
# Test-only environment boundaries. No engine installer, game, browser or modal UI.
$source=$source.Replace('$autoDepsOk = Initialize-PMMDependenciesIfNeeded','$autoDepsOk = $true # fixture: installed dependencies tested separately')
$source=$source.Replace('[void]$Window.ShowDialog()',('. '''+(Join-Path $PSScriptRoot $AssertionScript)+''''))
$source=$source.Replace("`nRefresh-UI`nif (-not `$autoDepsOk)","`nfunction Handle-UIError(`$Failure,[string]`$Title){throw `$Failure}`nfunction Show-Info([string]`$Message){throw ('Unexpected modal: '+`$Message)}`nRefresh-UI`nif (-not `$autoDepsOk)")
$source=$source.Replace("`nInitialize-PMMWorkspaces`n","`nfunction Start-PMMDependencyWorker([string]`$Id){} # fixture: inventory process boundary`nInitialize-PMMWorkspaces`n")
[IO.File]::WriteAllText($boot,$source,[Text.UTF8Encoding]::new($true))
function Start-Process {throw ('Fixture forbids starting external processes: '+($args -join ' ')+' TRACE '+(Get-PSCallStack|Out-String))}
. $boot
