param([string]$Root=([IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))))
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$Root=[IO.Path]::GetFullPath($Root)
$App=Join-Path $Root 'PMM'
$fail=[System.Collections.Generic.List[string]]::new()
function Assert-PMM([bool]$Condition,[string]$Message){if(-not$Condition){$fail.Add($Message);Write-Output ('[FAIL] '+$Message)}else{Write-Output ('[PASS] '+$Message)}}
function Read([string]$Relative){Get-Content -LiteralPath (Join-Path $Root $Relative) -Raw}

Assert-PMM (Test-Path (Join-Path $App 'PMM.exe') -PathType Leaf) 'PMM.exe exists'
Assert-PMM (Test-Path (Join-Path $Root 'Development\Tests\rc23_singleton_collection_regression.ps1') -PathType Leaf) 'RC23 singleton collection regression exists'
Assert-PMM (Test-Path (Join-Path $Root 'Development\Tests\rc23_singleton_guard_model.py') -PathType Leaf) 'RC23 cross-platform singleton guard model exists'
Assert-PMM (Test-Path (Join-Path $Root 'Development\Tests\rc24_ui_fixlab_ownership_regression.ps1') -PathType Leaf) 'RC24 Windows PowerShell UI/Fix Lab ownership regression exists'
Assert-PMM (Test-Path (Join-Path $Root 'Development\Tests\rc24_ui_fixlab_ownership_model.py') -PathType Leaf) 'RC24 cross-platform UI/Fix Lab ownership model exists'
Assert-PMM (Test-Path (Join-Path $Root 'Development\Tests\rc25_release_model.py') -PathType Leaf) 'RC25 cross-platform release model exists'
Assert-PMM (Test-Path (Join-Path $Root 'Development\Tests\rc26_official_themes_progress_compatibility_model.py') -PathType Leaf) 'RC26 cross-platform release model exists'
Assert-PMM (Test-Path (Join-Path $Root 'Development\Tests\rc26_semantic_compatibility_regression.ps1') -PathType Leaf) 'RC26 Windows PowerShell semantic compatibility regression exists'
Assert-PMM (Test-Path (Join-Path $Root 'Development\Tests\rc28_validation_runtime_regression.ps1') -PathType Leaf) 'RC28 Windows PowerShell validation/runtime regression exists'
Assert-PMM (Test-Path (Join-Path $Root 'Development\Tests\rc28_validation_runtime_regression_model.py') -PathType Leaf) 'RC28 cross-platform validation/runtime model exists'
Assert-PMM (Test-Path (Join-Path $Root 'Development\Tests\rc29_aihelp_feedback_ui_regression.ps1') -PathType Leaf) 'RC29 Windows PowerShell AI & Help/feedback/UI regression exists'
Assert-PMM (Test-Path (Join-Path $Root 'Development\Tests\rc29_aihelp_feedback_ui_model.py') -PathType Leaf) 'RC29 cross-platform AI & Help/feedback/UI model exists'
Assert-PMM (@(Get-ChildItem -LiteralPath $App -File -Force).Count -eq 1) 'PMM root exposes only one file'
Assert-PMM (-not(Test-Path (Join-Path $App 'Workspace'))) 'Workspace is not shipped'
foreach($d in @('Engine','Modules','Resources','CKL','Documentation')){Assert-PMM (Test-Path (Join-Path $App $d) -PathType Container) ('PMM/'+$d+' exists')}

$paths=Read 'PMM/Modules/Shared/Paths.ps1'
foreach($m in @('Engine','Modules','Resources','CKLStable','CKLExperimental','CKLCatalog','Workspace','Move-PMMLegacyWorkspaceIfPresent')){Assert-PMM ($paths -match [regex]::Escape($m)) ('Path contract: '+$m)}

$merge=Read 'PMM/Modules/Merge/MergeEngine.ps1'
$library=Read 'PMM/Modules/Library/LibraryService.ps1'
$fixlab=Read 'PMM/Modules/FixLab/FixLabService.ps1'
$common=Read 'PMM/Modules/Shared/Common.ps1'
$aiio=Read 'PMM/Modules/AIIO/AIIO.ps1'
$ckl=Read 'PMM/Modules/CKL/KnowledgeRecipeService.ps1'
$contrib=Read 'PMM/Modules/CKL/KnowledgeContributionService.ps1'
$bootstrap=Read 'PMM/Modules/Bootstrap/Start-PalModMerger.ps1'
$xaml=Read 'PMM/Resources/UI/MainWindow.xaml'
Assert-PMM ($merge -notmatch 'Compress-Archive') 'Analyze/MergeEngine does not use Compress-Archive'
Assert-PMM ($merge -notmatch 'source-paks') 'Analyze/MergeEngine does not package whole PAKs'
Assert-PMM ($merge -match 'Write-PMMAIHandoff request redirected to review metadata only') 'Legacy handoff shim is metadata-only'
foreach($m in @('Get-PMMPlanSchemaVersion { return 18 }','PMM_ANALYZE_GROUP_CACHE_V2','AnalyzeGroupsV2','Try-PMMReuseCurrentAnalyzePlan','KnowledgeRulesSha256=')){Assert-PMM ($merge -match [regex]::Escape($m)) ('RC26 Analyze cache: '+$m)}
foreach($m in @('Get-PMMFastPatchReuseCandidate','Set-PMMPlanEquivalentPatch','AnalyzedSharedAssets=@(','ProductionRecipesSha256=','SchemaVersion=9','PatchReuseKind=''EffectiveConflictSet''')){Assert-PMM ($merge -match [regex]::Escape($m)) ('RC23 effective patch reuse: '+$m)}
foreach($m in @('Test-PMMPatchPlanCompatible','Test-PMMPlanCurrentForPatchCompatibility','Test-PMMPatchRuntimeCompatible','Test-PMMKnownRecipeAssetCompatible','Get-PMMProductionRecipeLibrarySha256','Keep an actual Object[] for zero, one or many matches')){Assert-PMM ($library -match [regex]::Escape($m)) ('RC23 patch proof: '+$m)}
foreach($m in @('Get-PMMAutomaticResolutionSignature','knowledgeAuthorizedAssets','KnowledgeRulesSha256')){Assert-PMM ($library -match [regex]::Escape($m)) ('RC26 semantic patch proof: '+$m)}
Assert-PMM ($library -notmatch '\$(knownRecipeAssets|knowledgeAuthorizedAssets)\s*=\s*if\s*\(') 'RC23/RC26 knowledge-authorized collection is not assigned through an unwrapping if pipeline'
Assert-PMM ($merge -notmatch '\$(decisions|patchAssets)\s*=\s*if\s*\([^\r\n]*\)\s*\{@\(') 'RC23 fast-reuse collections are not assigned through an unwrapping if pipeline'
foreach($m in @('SoundDefaultsVersion=3','SoundSemiAutoEnabled=$true','$soundDefaultsVersion -lt 3')){Assert-PMM ($common -match [regex]::Escape($m)) ('RC22 Semiauto migration: '+$m)}
$pakService=Read 'PMM/Modules/Merge/PakService.ps1'
foreach($m in @('PMM_PAK_INDEX_V1','PakIndexesV1','LastWriteTimeUtc.Ticks')){Assert-PMM ($pakService -match [regex]::Escape($m)) ('RC22 PAK index: '+$m)}
foreach($m in @('New-PMMAIHandoffBundle','PMM_AI_HANDOFF_BUNDLE_V1','WholeSourcePaksIncluded=$false','PMM_AIIO_OVERSIZE_CONFIRMATION_REQUIRED','archive create','relevant-knowledge.json')){Assert-PMM ($aiio -match [regex]::Escape($m)) ('AIIO invariant: '+$m)}
foreach($m in @('PMM_CKL_CASE_INDEX_V1','EXACT_PROVIDER_FIXTURE','HASH_PINNED_PARTIAL','SAME_NAME_DIFFERENT_BUILD','production.enabled')){Assert-PMM ($ckl -match [regex]::Escape($m)) ('CKL lookup/safety: '+$m)}
Assert-PMM ($contrib -match 'ckl-context.json') 'Knowledge contribution preserves CKL context'
foreach($m in @('ImgPMMLogo','BtnRestoreDefaults','Everything is ready to play.','PMMLogo.png','Set-PMMPendingSoundId','EffectiveConflictSet')){Assert-PMM ($bootstrap -match [regex]::Escape($m)) ('RC22 bootstrap/UI: '+$m)}
foreach($m in @('PnlUserThemeOptions','TxtUserThemeEmpty','if($target -ge 100.0)','$Bar.Value=100.0')){Assert-PMM ($bootstrap -match [regex]::Escape($m)) ('RC26 themes/progress: '+$m)}
foreach($m in @('Complete-PMMAIIOPrepareUi','Repair-PMMDuplicateDiagnosticSessions','Register-PMMAutomaticErrorCase','Flow:PlayReady')){Assert-PMM ($bootstrap -match [regex]::Escape($m)) ('RC29 AI & Help/UI: '+$m)}
Assert-PMM ($bootstrap -notmatch [regex]::Escape('$Script:LstAIIOSessions.SelectedValue')) 'RC29 AIIO session selection avoids closure-fragile SelectedValue'
foreach($m in @('x:Name="ImgPMMLogo"','x:Name="BtnRestoreDefaults"','Content="3 beeps"')){Assert-PMM ($xaml -match [regex]::Escape($m)) ('RC22 XAML: '+$m)}
foreach($m in @('<ColumnDefinition Width="*"/>','x:Name="GrdHeaderActions" Grid.Column="1" MinWidth="0" HorizontalAlignment="Stretch"','x:Name="BtnFixLabRefreshDashboard"')){Assert-PMM ($xaml -match [regex]::Escape($m)) ('RC27 responsive/Fix Lab XAML: '+$m)}
foreach($m in @('function Queue-PMMFixLabUiRefresh','DispatcherPriority]::ContextIdle','$Script:FixLabRefreshIntervalSeconds=60','Get-PMMFixLabDiscoveryCandidates -IncludeBackups -BackupRows $backups')){Assert-PMM ($bootstrap -match [regex]::Escape($m)) ('RC24 deferred Fix Lab UI: '+$m)}
Assert-PMM ($fixlab -match [regex]::Escape('belongs exclusively to Mods & Merge')) 'RC24 Fix Lab deployment ownership boundary'
Assert-PMM ($fixlab -match [regex]::Escape('deployed compatibility merge preserved')) 'RC24 Fix Lab restore preservation marker'
Assert-PMM ($library -match [regex]::Escape('deployedMergePreserved=true')) 'RC24 source-delete merge preservation marker'

$idx=Get-Content (Join-Path $App 'CKL/Catalog/case-index.json') -Raw|ConvertFrom-Json
Assert-PMM ([string]$idx.schema -eq 'PMM_CKL_CASE_INDEX_V1') 'CKL index schema'
Assert-PMM (@($idx.entries).Count -ge 12) ('CKL master index has '+@($idx.entries).Count+' entries')
Assert-PMM (@($idx.entries|Where-Object{[string]$_.kind -eq 'production-recipe' -and [bool]$_.productionEnabled}).Count -eq 1) 'Exactly one production-enabled indexed recipe'

$recipe=Get-Content (Join-Path $App 'CKL/Stable/production-recipes.json') -Raw|ConvertFrom-Json
Assert-PMM (@($recipe.recipes|Where-Object{$_.production.enabled}).Count -eq 1) 'Stable CKL has exactly one automatic production recipe'

$manifest=Get-Content (Join-Path $App 'Resources/Metadata/RELEASE_MANIFEST.json') -Raw|ConvertFrom-Json
Assert-PMM ([string]$manifest.version -eq '1.3.0') 'Manifest version 1.3.0'
Assert-PMM ([int]$manifest.mergePlanSchema -eq 18) 'Merge plan schema 18'
Assert-PMM ([int]$manifest.buildManifestSchema -eq 9) 'Build manifest schema 9'
Assert-PMM ([string]$manifest.buildId -eq 'PMM-v1.3.0-RC30-LEAN-AI-VALIDATION-FLOW') 'RC30 build identity'
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
