Set-StrictMode -Version 2;$ErrorActionPreference='Stop'
$repo=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$fixture=Join-Path $repo ('Development/TestResults/CoreOutput132-'+[guid]::NewGuid().ToString('N'))
. (Join-Path $repo 'PMM/Modules/Shared/Persistence.ps1')
. (Join-Path $repo 'PMM/Modules/Merge/MergeEngine.ps1')
function Get-PMMCorePath{'fixture.dll'}
function Get-PMMDotnetHostPath{'Invoke-FixtureCore'}
function Get-PMMPath([string]$Name){Join-Path $fixture $Name}
$script:fixtureOutput=@(1..11000|ForEach-Object{'unique diagnostic '+$_});$script:fixtureExit=9
function Invoke-FixtureCore{$global:LASTEXITCODE=$script:fixtureExit;$script:fixtureOutput}
$script:logCalls=0
function Write-PMMLog([string]$Message){$script:logCalls++}
function Write-PMMProcessOutputLog([string]$Prefix,[array]$Output){foreach($line in $Output){Write-PMMLog $line}}
$result=Invoke-PMMCore @('fixture') 'large report'
if($result.ExitCode -ne 9 -or $result.Output.Count -ne 11000 -or $result.Output[-1] -ne 'unique diagnostic 11000'){throw 'Caller lost native output or exit status.'}
$files=@(Get-ChildItem (Join-Path $fixture 'Logs/EngineReports') -File)
$stored=Get-Content $files[0].FullName -Raw|ConvertFrom-Json
if($files.Count -ne 1 -or $stored.Output.Count -ne 11000 -or $stored.Output[-1] -ne $result.Output[-1] -or $script:logCalls -ne 1){throw 'Large report was truncated or still logged per line.'}
Invoke-PMMCore @('fixture') 'large report'|Out-Null
if(@(Get-ChildItem (Join-Path $fixture 'Logs/EngineReports') -File).Count -ne 1){throw 'Identical report duplicated retained diagnostics.'}
$script:fixtureOutput=@('first','last');$script:fixtureExit=0;$script:logCalls=0
$result=Invoke-PMMCore @('fixture') 'small report'
if($result.ExitCode -ne 0 -or $result.Output.Count -ne 2 -or $script:logCalls -ne 2){throw 'Small diagnostic behavior changed.'}
'PASS core output132: native status/all 11000 lines preserved; one main-log write; repeat deduplicated; short output unchanged.'
