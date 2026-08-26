param([string]$Root=([IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))))
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$Root=[IO.Path]::GetFullPath($Root)
$App=Join-Path $Root 'PMM'
$fail=[System.Collections.Generic.List[string]]::new()
function Assert-PMM([bool]$Condition,[string]$Message){if(-not$Condition){$fail.Add($Message);Write-Output ('[FAIL] '+$Message)}else{Write-Output ('[PASS] '+$Message)}}
function Read([string]$Relative){Get-Content -LiteralPath (Join-Path $Root $Relative) -Raw}

Assert-PMM (Test-Path (Join-Path $App 'PMM.exe') -PathType Leaf) 'PMM.exe exists'
Assert-PMM (@(Get-ChildItem -LiteralPath $App -File -Force).Count -eq 1) 'PMM root exposes only one file'
Assert-PMM (-not(Test-Path (Join-Path $App 'Workspace'))) 'Workspace is not shipped'
foreach($d in @('Engine','Modules','Resources','CKL','Documentation')){Assert-PMM (Test-Path (Join-Path $App $d) -PathType Container) ('PMM/'+$d+' exists')}

$paths=Read 'PMM/Modules/Shared/Paths.ps1'
foreach($m in @('Engine','Modules','Resources','CKLStable','CKLExperimental','CKLCatalog','Workspace','Move-PMMLegacyWorkspaceIfPresent')){Assert-PMM ($paths -match [regex]::Escape($m)) ('Path contract: '+$m)}

$merge=Read 'PMM/Modules/Merge/MergeEngine.ps1'
$aiio=Read 'PMM/Modules/AIIO/AIIO.ps1'
$ckl=Read 'PMM/Modules/CKL/KnowledgeRecipeService.ps1'
$contrib=Read 'PMM/Modules/CKL/KnowledgeContributionService.ps1'
Assert-PMM ($merge -notmatch 'Compress-Archive') 'Analyze/MergeEngine does not use Compress-Archive'
Assert-PMM ($merge -notmatch 'source-paks') 'Analyze/MergeEngine does not package whole PAKs'
Assert-PMM ($merge -match 'Write-PMMAIHandoff request redirected to review metadata only') 'Legacy handoff shim is metadata-only'
foreach($m in @('New-PMMAIHandoffBundle','PMM_AI_HANDOFF_BUNDLE_V1','WholeSourcePaksIncluded=$false','PMM_AIIO_OVERSIZE_CONFIRMATION_REQUIRED','archive create','relevant-knowledge.json')){Assert-PMM ($aiio -match [regex]::Escape($m)) ('AIIO invariant: '+$m)}
foreach($m in @('PMM_CKL_CASE_INDEX_V1','EXACT_PROVIDER_FIXTURE','HASH_PINNED_PARTIAL','SAME_NAME_DIFFERENT_BUILD','production.enabled')){Assert-PMM ($ckl -match [regex]::Escape($m)) ('CKL lookup/safety: '+$m)}
Assert-PMM ($contrib -match 'ckl-context.json') 'Knowledge contribution preserves CKL context'

$idx=Get-Content (Join-Path $App 'CKL/Catalog/case-index.json') -Raw|ConvertFrom-Json
Assert-PMM ([string]$idx.schema -eq 'PMM_CKL_CASE_INDEX_V1') 'CKL index schema'
Assert-PMM (@($idx.entries).Count -ge 12) ('CKL master index has '+@($idx.entries).Count+' entries')
Assert-PMM (@($idx.entries|Where-Object{[string]$_.kind -eq 'production-recipe' -and [bool]$_.productionEnabled}).Count -eq 1) 'Exactly one production-enabled indexed recipe'

$recipe=Get-Content (Join-Path $App 'CKL/Stable/production-recipes.json') -Raw|ConvertFrom-Json
Assert-PMM (@($recipe.recipes|Where-Object{$_.production.enabled}).Count -eq 1) 'Stable CKL has exactly one automatic production recipe'

$manifest=Get-Content (Join-Path $App 'Resources/Metadata/RELEASE_MANIFEST.json') -Raw|ConvertFrom-Json
Assert-PMM ([string]$manifest.version -eq '1.2.1') 'Manifest version 1.2.1'
Assert-PMM ([string]$manifest.runtime.executable -eq 'Engine/PMMRuntime.exe') 'Runtime new path'
Assert-PMM ([string]$manifest.aiioModule -eq 'Modules/AIIO/AIIO.ps1') 'AIIO new path'
Assert-PMM ([string]$manifest.ckl.catalog -eq 'CKL/Catalog/case-index.json') 'Manifest CKL catalog path'

foreach($f in @(Get-ChildItem -LiteralPath (Join-Path $App 'Modules') -Recurse -File -Filter '*.ps1')){
  $text=Get-Content $f.FullName -Raw
  foreach($legacy in @("'Tools\","'Core\","'Knowledge\","'Mappings\","'Data\Review")){Assert-PMM (-not($text -match [regex]::Escape($legacy))) ('No active legacy path '+$legacy+' in '+$f.Name)}
}

if($fail.Count){Write-Output ('PMM_SMOKETEST_FAILED count='+$fail.Count);exit 1}
Write-Output 'PMM_SMOKETEST_OK'
exit 0
