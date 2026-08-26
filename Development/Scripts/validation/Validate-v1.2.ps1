param([switch]$Quiet)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$Root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..'))
$App=Join-Path $Root 'PMM'
$Failures=[System.Collections.Generic.List[string]]::new()
function Fail([string]$m){$Failures.Add($m);Write-Output ('[FAIL] '+$m)}
function Pass([string]$m){if(-not$Quiet){Write-Output ('[PASS] '+$m)}}
function NeedFile([string]$r){if(-not(Test-Path -LiteralPath (Join-Path $Root $r) -PathType Leaf)){Fail ('Missing file: '+$r)}else{Pass $r}}
function NeedDir([string]$r){if(-not(Test-Path -LiteralPath (Join-Path $Root $r) -PathType Container)){Fail ('Missing directory: '+$r)}else{Pass $r}}
foreach($d in @('.github','PMM','Development','Development\Source','Development\Docs','Development\AI','Development\Scripts','Development\Tests','PMM\Engine','PMM\Modules','PMM\Resources','PMM\CKL','PMM\Documentation')){NeedDir $d}
foreach($f in @('README.md','LICENSE','Development\AI\CURRENT_STATE.md','PMM\PMM.exe','PMM\Engine\PMMRuntime.exe','PMM\Engine\repak.exe','PMM\Modules\Shared\Paths.ps1','PMM\Modules\Bootstrap\Start-PalModMerger.ps1','PMM\Resources\Metadata\RELEASE_MANIFEST.json','PMM\Resources\Metadata\VERSION.txt','PMM\Resources\Metadata\BUILD_ID.txt','PMM\Resources\UI\PMM.ico','PMM\Resources\Mappings\Mappings.usmap','PMM\CKL\Catalog\case-index.json','PMM\CKL\channels.json','PMM\CKL\Stable\production-recipes.json')){NeedFile $f}
$rootFiles=@(Get-ChildItem -LiteralPath $App -File -Force)
if($rootFiles.Count -ne 1 -or $rootFiles[0].Name -ne 'PMM.exe'){Fail ('PMM application root must expose only PMM.exe; found: '+(($rootFiles.Name)-join ', '))}else{Pass 'PMM root exposes only PMM.exe'}
if(Test-Path -LiteralPath (Join-Path $App 'Workspace')){Fail 'Workspace must not be committed/shipped; PMM creates it at runtime.'}else{Pass 'No runtime Workspace shipped'}
$paks=@(Get-ChildItem -LiteralPath $Root -Recurse -File -Filter '*.pak' -ErrorAction SilentlyContinue);if($paks.Count){Fail ('PAK files present: '+$paks.Count)}else{Pass 'No PAK files committed'}
$ucas=@(Get-ChildItem -LiteralPath $Root -Recurse -File -Include '*.ucas','*.utoc' -ErrorAction SilentlyContinue);if($ucas.Count){Fail ('UCAS/UTOC files present: '+$ucas.Count)}else{Pass 'No UCAS/UTOC files committed'}
foreach($j in @(Get-ChildItem -LiteralPath (Join-Path $App 'CKL') -Recurse -File -Filter '*.json')){try{$null=Get-Content $j.FullName -Raw|ConvertFrom-Json}catch{Fail ('Invalid CKL JSON: '+$j.FullName)}}
$idx=Get-Content (Join-Path $App 'CKL\Catalog\case-index.json') -Raw|ConvertFrom-Json
if([string]$idx.schema -ne 'PMM_CKL_CASE_INDEX_V1'){Fail 'Bad CKL index schema'}
if(@($idx.entries).Count -lt 12){Fail 'CKL index unexpectedly incomplete'}else{Pass ('CKL indexed entries: '+@($idx.entries).Count)}
$manifest=Get-Content (Join-Path $App 'Resources\Metadata\RELEASE_MANIFEST.json') -Raw|ConvertFrom-Json
if([string]$manifest.version -ne '1.2.1'){Fail 'Manifest version mismatch'}
if([string]$manifest.runtime.executable -ne 'Engine/PMMRuntime.exe'){Fail 'Runtime manifest path mismatch'}
if([string]$manifest.aiioModule -ne 'Modules/AIIO/AIIO.ps1'){Fail 'AIIO manifest path mismatch'}
$paths=Get-Content (Join-Path $App 'Modules\Shared\Paths.ps1') -Raw
foreach($marker in @('Engine','Modules','Resources','CKLStable','Workspace','Move-PMMLegacyWorkspaceIfPresent')){if($paths -notmatch [regex]::Escape($marker)){Fail ('Path contract missing '+$marker)}}
$active=Get-ChildItem -LiteralPath (Join-Path $App 'Modules') -Recurse -File -Filter '*.ps1'
foreach($f in $active){
  $t=Get-Content $f.FullName -Raw
  foreach($legacy in @("'Tools\","'Core\","'Knowledge\","'Mappings\","'Data\Review")){if($t -match [regex]::Escape($legacy)){Fail ('Legacy path '+$legacy+' in '+$f.FullName)}}
  if($f.Name -ne 'Paths.ps1' -and $t -match [regex]::Escape("'AI_HANDOFFS'")){Fail ('Legacy AI_HANDOFFS path in '+$f.FullName)}
}
if($Failures.Count){Write-Output ('PMM_V121_REPOSITORY_VALIDATION_FAILED count='+$Failures.Count);exit 1}
Write-Output 'PMM_V121_REPOSITORY_VALIDATION_OK'
Write-Output 'LAYOUT=PASS'
Write-Output 'CKL_INDEX=PASS'
exit 0
