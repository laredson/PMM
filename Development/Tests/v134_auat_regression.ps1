param([string]$SourcePak='C:/steam/steamapps/common/Palworld/Pal/Content/Paks/~mods/AutoUnlockAllTechnology_V1_P.pak')
Set-StrictMode -Version 2;$ErrorActionPreference='Stop'
$repo=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'));$app=Join-Path $repo 'PMM'
$fixture=Join-Path $repo ('Development/TestResults/AuatFixLab134-'+[guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($fixture)
foreach($dir in @('Resources','CKL')){Copy-Item -LiteralPath (Join-Path $app $dir) -Destination (Join-Path $fixture $dir) -Recurse}
[void][IO.Directory]::CreateDirectory((Join-Path $fixture 'Engine'))
Copy-Item -LiteralPath (Join-Path $app 'Engine/AssetTools') -Destination (Join-Path $fixture 'Engine/AssetTools') -Recurse
Copy-Item -LiteralPath (Join-Path $app 'Engine/repak.exe') -Destination (Join-Path $fixture 'Engine/repak.exe')
foreach($m in @('Shared/Paths','Shared/Common','Shared/GameLocator','Merge/PakService','GameReference/GameReferenceService','Library/LibraryService','FixLab/FixLabService')){. (Join-Path $app ('Modules/'+$m+'.ps1'))}
function Get-PMMDotnetHostPath {return (Join-Path $app 'Engine/dotnet/8.0.30/dotnet.exe')}
Initialize-PMMPaths $fixture|Out-Null;Initialize-PMM
$cfg=Get-PMMConfig;$cfg.GamePath='C:/steam/steamapps/common/Palworld';Save-PMMConfig $cfg
# Load sources from the checkout while preserving a fully isolated fixture data root.
[void][IO.Directory]::CreateDirectory((Join-Path $fixture 'Modules/FixLab'))
Copy-Item -LiteralPath (Join-Path $app 'Modules/FixLab/AuatUpgrade.ps1') -Destination (Join-Path $fixture 'Modules/FixLab/AuatUpgrade.ps1')
$job=New-PMMFixLabJob $SourcePak
$job=Invoke-PMMFixLabAnalyze $job.JobId
if($job.SelectedRecipeId -ne 'fixlab-auat-v1-to-v1-1-pw104'){throw 'Exact AUAT input was not recognized.'}
$state=Get-PMMFixLabBuildState $job
if(-not$state.Ready -or $state.Mode -ne 'auat-property-upgrade'){throw 'Fix Lab cannot execute the selected AUAT recipe.'}
$built=Invoke-PMMFixLabBuild $job.JobId
if($built.Build.Status -ne 'Built' -or -not(Test-Path -LiteralPath $built.Build.OutputPath)){throw 'Fix Lab did not register an output.'}
$report=Get-Content -LiteralPath $built.Build.ReportPath -Raw|ConvertFrom-Json
if($report.StructuralValidation.technologies -ne 588 -or $report.RuntimeValidation -ne 'UNPROVEN'){throw 'Invalid structural/runtime distinction.'}
. (Join-Path $app 'Modules/FixLab/AuatUpgrade.ps1')
$bad=Join-Path $fixture 'bad.pak';[IO.File]::WriteAllText($bad,'wrong source')
$blocked=$false;try{New-PMMAuatUpgrade $bad '' (Join-Path $fixture 'bad-output') (Get-PMMFixLabRecipe $job.SelectedRecipeId)|Out-Null}catch{$blocked=$_.Exception.Message -match 'source hash'}
if(-not$blocked -or (Test-Path (Join-Path $fixture 'bad-output'))){throw 'Wrong source was not refused before creating output.'}
$receipt=[ordered]@{Fixture=$fixture;Output=$built.Build.OutputPath;Hash=$built.Build.OutputSha256;Report=$built.Build.ReportPath;JobId=$job.JobId;Checks=5;GameLaunched=$false}
Write-PMMJsonAtomic (Join-Path $repo 'Development/TestResults/auat134-validation.json') $receipt 8
'PASS AUAT recipe: '+($receipt|ConvertTo-Json -Compress)
