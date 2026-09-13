Set-StrictMode -Version 2;$ErrorActionPreference='Stop'
$repo=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'));$app=Join-Path $repo 'PMM'
$fixture=Join-Path $repo ('Development/TestResults/DeepLocal133-'+[guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($fixture)
foreach($part in @('Modules','Resources','CKL','Engine')){Copy-Item (Join-Path $app $part) (Join-Path $fixture $part) -Recurse}
$Script:Root=$fixture
. (Join-Path $fixture 'Modules/Shared/Paths.ps1');Initialize-PMMPaths $fixture|Out-Null
. (Join-Path $fixture 'Modules/Shared/Common.ps1');Initialize-PMM
$cfg=Get-Content (Join-Path $app 'Workspace/State/config.json') -Raw|ConvertFrom-Json
Save-PMMConfig $cfg
. (Join-Path $fixture 'Modules/Analysis/Services.ps1')
$mapping=Get-Content (Join-Path $app 'Workspace/State/mappings-selection.json') -Raw|ConvertFrom-Json
Import-PMMLocalMappings (Join-Path $app ('Workspace/Mappings/'+$mapping.Sha256+'.usmap'))|Out-Null
$wanted=@('EasyBreeding_P.pak','NoCollisionFarmsAndExped_P.pak','FasterMounts4xAllWorkSuitabilitiesLevel10_P.pak','RushRoarLeatherDrop_v2_P.pak')
$sourceFiles=@(Get-ChildItem (Join-Path $app 'Workspace/Mods') -Recurse -File -Filter *.pak|Where-Object{$_.Name -in $wanted -and $_.FullName -notmatch '[\\/]_Disabled[\\/]'})
foreach($name in $wanted){
  $files=@($sourceFiles|Where-Object Name -eq $name)
  if($files.Count -ne 1){throw ('Expected one local fixture for '+$name)}
  $dir=Join-Path (Get-LibraryRoot) ([IO.Path]::GetFileNameWithoutExtension($name));[void][IO.Directory]::CreateDirectory($dir)
  Copy-Item -LiteralPath $files[0].FullName -Destination (Join-Path $dir $name)
}
$options=New-PMMDeepAnalysisOptions;$options.CheckUpdates=$false;$options.IncludePatch=$false;$options.MaxSemanticFamilies=80
$report=Invoke-PMMDeepAnalysis $options
if($report.Coverage.RuntimeTested -or @($report.Findings|Where-Object RuntimeProven).Count){throw 'Static scan invented runtime proof.'}
if($report.Snapshot.Active.Count -ne 4 -or $report.Snapshot.MappingsSha256 -cne $mapping.Sha256){throw 'Local fixture sources or mappings mismatch.'}
$summary=@{AnalysisId=$report.Id;Report=(Join-Path (Get-PMMAnalysisPath $report.Id) 'report.json');Coverage=$report.Coverage;Rules=@($report.Findings|Group-Object Rule|ForEach-Object{@{Rule=$_.Name;Count=$_.Count}});Sources=@($report.Snapshot.Active|Select-Object Name,Hash);SteamBuild=$report.Snapshot.Game.SteamBuildId}
Write-PMMJsonAtomic (Join-Path $repo 'Development/TestResults/deep133-local-validation.json') $summary -Depth 12
$summary|ConvertTo-Json -Depth 12
