<# Palworld Manager Merger v1.1 source-only smoke test. It never downloads/builds dependencies. #>
param([switch]$Quiet)
$ErrorActionPreference='Stop'
$Root=Split-Path -Parent $MyInvocation.MyCommand.Path
$releaseManifestPath=Join-Path $Root 'RELEASE_MANIFEST.json'
$releaseManifest=$null
try{if(Test-Path -LiteralPath $releaseManifestPath -PathType Leaf){$releaseManifest=Get-Content -LiteralPath $releaseManifestPath -Raw|ConvertFrom-Json}}catch{}
$isReleaseBuilder=[bool]($releaseManifest -and ($releaseManifest.PSObject.Properties.Name -contains 'sourceTreeRequiresReleaseBuild') -and [bool]$releaseManifest.sourceTreeRequiresReleaseBuild)
$isPublicPackage=[bool]($releaseManifest -and ($releaseManifest.PSObject.Properties.Name -contains 'packageProfile') -and ([string]$releaseManifest.packageProfile -eq 'public-offline-first'))
$failures=New-Object System.Collections.Generic.List[string]
function Fail([string]$m){$failures.Add($m)}
function Note([string]$m){if(-not$Quiet){Write-Host "[Smoke] $m"}}

$required=@(
  'Start-PalModMerger.ps1','Core\Common.ps1','Core\GameLocator.ps1','Core\PakService.ps1','Core\LibraryService.ps1','Core\SaveService.ps1','Core\MergeEngine.ps1','Core\SemanticLab.ps1','Core\GameReferenceService.ps1','Core\GameReferenceWorker.ps1','Core\OperationWorker.ps1','Core\KnowledgeRecipeService.ps1','Core\KnowledgeContributionService.ps1','BUILD_ID.txt',
  'Setup-Dependencies.ps1','SETUP_ONCE.cmd','Tools\PMMCore\src\PMM.Core\PMM.Core.csproj','Tools\PMMCore\src\PMM.Cli\PMM.Cli.csproj',
  'Tools\PMMCore\src\PMM.Core\BinaryRangeMergeAdapter.cs','Tools\PMMCore\src\PMM.Core\SupersetAnchorAdapter.cs','Tools\PMMCore\src\PMM.Core\ContainedDeltaSupersetAdapter.cs','Tools\PMMCore\src\PMM.Core\RelocatableDeltaAdapter.cs',
  'Tools\PMMCore\src\PMM.Core\Semantic\StaticItemDataAssetAdapter.cs','Tools\PMMCore\src\PMM.Core\Semantic\DataTableMergeAdapter.cs','Tools\PMMCore\src\PMM.Core\Semantic\DataTableMap.cs',
  'Tools\AssetReader\Program.cs','Tools\AssetReader\AssetReader.csproj','UI\MainWindow.xaml','UI\MainWindow.en.xaml','UI\MainWindow.es.xaml','RELEASE_MANIFEST.json','Knowledge\README.md','Knowledge\behavior-symbols.json','Knowledge\known-fixtures.json','Knowledge\known-behaviors.json','Knowledge\production-recipes.json','Knowledge\reference-relations.json','Docs\COMMUNITY_KNOWLEDGE_WORKFLOW.md','Docs\COMMUNITY_KNOWLEDGE_SERVER_SPEC.md','Docs\MANUAL_SOLUTION_CONTRACT.md','Documentation\GAME_REFERENCE_AND_COMMUNITY_CONTRIBUTIONS.md','Documentation\README.md','Documentation\AI_DEVELOPMENT_HANDOFF.md','Documentation\USER_GUIDE_EN.md','Documentation\USER_GUIDE_ES.md','LICENSE','THIRD_PARTY_NOTICES.md'
)
if($isReleaseBuilder){$required+=@('BUILD_FINAL_RELEASE.cmd','Build-Release.ps1','Test-ReleasePackage.ps1')}
foreach($rel in $required){if(-not(Test-Path -LiteralPath (Join-Path $Root $rel) -PathType Leaf)){Fail "Missing required file: $rel"}}
$versionText=(Get-Content -LiteralPath (Join-Path $Root 'VERSION.txt') -Raw).Trim()
if($versionText -ne 'v1.1'){Fail "VERSION.txt mismatch: $versionText"}

foreach($file in @(Get-ChildItem -LiteralPath $Root -Filter *.ps1 -File -Recurse -ErrorAction SilentlyContinue)){
  $tokens=$null;$errors=$null
  [void][System.Management.Automation.Language.Parser]::ParseFile($file.FullName,[ref]$tokens,[ref]$errors)
  foreach($e in @($errors)){Fail ("PowerShell syntax: {0}:{1} {2}" -f $file.FullName,$e.Extent.StartLineNumber,$e.Message)}
}
foreach($rel in @('UI\MainWindow.xaml','UI\MainWindow.en.xaml','UI\MainWindow.es.xaml')){
  $p=Join-Path $Root $rel
  if(Test-Path $p){try{[xml]$null=Get-Content -LiteralPath $p -Raw -Encoding UTF8}catch{Fail "Invalid XAML/XML $rel : $($_.Exception.Message)"}}
}

$merge=Get-Content -LiteralPath (Join-Path $Root 'Core\MergeEngine.ps1') -Raw
$core=Get-Content -LiteralPath (Join-Path $Root 'Tools\PMMCore\src\PMM.Cli\Program.cs') -Raw
$coreProj=Get-Content -LiteralPath (Join-Path $Root 'Tools\PMMCore\src\PMM.Cli\PMM.Cli.csproj') -Raw
$reader=Get-Content -LiteralPath (Join-Path $Root 'Tools\AssetReader\Program.cs') -Raw
$readerProj=Get-Content -LiteralPath (Join-Path $Root 'Tools\AssetReader\AssetReader.csproj') -Raw
$setup=Get-Content -LiteralPath (Join-Path $Root 'Setup-Dependencies.ps1') -Raw
$common=Get-Content -LiteralPath (Join-Path $Root 'Core\Common.ps1') -Raw
$start=Get-Content -LiteralPath (Join-Path $Root 'Start.cmd') -Raw
$recipeService=Get-Content -LiteralPath (Join-Path $Root 'Core\KnowledgeRecipeService.ps1') -Raw
$recipeJson=Get-Content -LiteralPath (Join-Path $Root 'Knowledge\production-recipes.json') -Raw
$dataTableMap=Get-Content -LiteralPath (Join-Path $Root 'Tools\PMMCore\src\PMM.Core\Semantic\DataTableMap.cs') -Raw
$gameReference=Get-Content -LiteralPath (Join-Path $Root 'Core\GameReferenceService.ps1') -Raw
$contributionService=Get-Content -LiteralPath (Join-Path $Root 'Core\KnowledgeContributionService.ps1') -Raw
$operationWorker=Get-Content -LiteralPath (Join-Path $Root 'Core\OperationWorker.ps1') -Raw
$gameReferenceWorker=Get-Content -LiteralPath (Join-Path $Root 'Core\GameReferenceWorker.ps1') -Raw
$referenceRelations=Get-Content -LiteralPath (Join-Path $Root 'Knowledge\reference-relations.json') -Raw
$releaseBuilder=if(Test-Path -LiteralPath (Join-Path $Root 'Build-Release.ps1') -PathType Leaf){Get-Content -LiteralPath (Join-Path $Root 'Build-Release.ps1') -Raw}else{''}
$releaseValidator=if(Test-Path -LiteralPath (Join-Path $Root 'Test-ReleasePackage.ps1') -PathType Leaf){Get-Content -LiteralPath (Join-Path $Root 'Test-ReleasePackage.ps1') -Raw}else{''}
$releaseManifestText=Get-Content -LiteralPath (Join-Path $Root 'RELEASE_MANIFEST.json') -Raw
$setupCode=($setup -replace '(?s)<#.*?#>','' -replace '(?m)^\s*#.*$','')

foreach($mode in @('BinaryAuto','BinaryConflict','StaticItemAuto','StaticItemConflict','SupersetAuto','ContainedSupersetAuto','KnownRecipeAuto','ManualSolutionExperimental','DataTableAuto','DataTableConflict','RelocatableAuto','RelocatableConflict','Unsupported')){if($merge -notmatch [regex]::Escape($mode)){Fail "MergeEngine is missing plan mode: $mode"}}
foreach($cmd in @('--version','self-test','binary-plan','binary-merge','superset-merge','contained-superset-merge','staticitem-merge','datatable-merge','relocatable-merge')){if($core -notmatch [regex]::Escape($cmd)){Fail "PMMCore CLI command is missing: $cmd"}}
if($reader -match '\.Write\s*\('){Fail 'AssetReader contains a writer call; reader must remain read-only.'}

if($core -notmatch 'PMMCORE_SELFTEST_OK'){Fail 'PMMCore source does not expose the functional self-test marker.'}
if($core -notmatch 'PMMCORE_SELFTEST_NPROVIDER_OK'){Fail 'PMMCore self-test does not exercise the 3-provider Double/Triple/Quad value-conflict contract.'}
if($core -notmatch 'PMMCORE_SELFTEST_DATATABLE_DUPLICATES_OK'){Fail 'PMMCore self-test does not cover duplicate DataTable row identities.'}
if($setup -match 'Select-Object -First 1.*ExpectedCoreVersion'){Fail 'Setup still parses only the first textual version line.'}
if($setup -notmatch 'Invoke-PMMCoreProbe'){Fail 'Setup does not use the PMMCore functional probe.'}

if($core -notmatch 'CoreVersion = "0\.9\.0"'){Fail 'PMMCore source does not expose exact version 0.9.0.'}
if($setup -notmatch "ExpectedCoreVersion='0\.9\.0'"){Fail 'Setup does not require exact PMMCore version 0.9.0.'}
if($merge -notmatch "Get-PMMExpectedCoreVersion \{ return '0\.9\.0' \}"){Fail 'MergeEngine does not enforce PMMCore 0.9.0.'}
if($coreProj -notmatch '<AssemblyVersion>0\.9\.0\.0</AssemblyVersion>'){Fail 'PMMCore assembly metadata version 0.9.0.0 is missing.'}
if($common -notmatch "Get-PMMDependencyCoreVersion \{ return '0\.9\.0' \}"){Fail 'Common dependency health check does not declare exact PMMCore 0.9.0.'}
if($common -match 'PMMCORE_SELFTEST_OK\\s\+0\\.7\\.0'){Fail 'Common dependency health check still expects the stale PMMCore 0.7.0 self-test marker.'}
if($common -notmatch '\[regex\]::Escape\(\$expectedCore\)'){Fail 'Common dependency self-test marker is not derived from the expected PMMCore version.'}

if($readerProj -match 'Version="\*"'){Fail 'Floating NuGet versions are forbidden.'}
foreach($pkg in @('UAssetAPI','Newtonsoft.Json','ZstdSharp.Port')){if($readerProj -notmatch [regex]::Escape($pkg)){Fail "AssetReader project does not pin $pkg."}}
foreach($dll in @('UAssetAPI.dll','Newtonsoft.Json.dll','ZstdSharp.dll')){if($setup -notmatch [regex]::Escape($dll)){Fail "Setup does not verify runtime dependency $dll."}}
if($setup -notmatch 'self-test-deps'){Fail 'Setup does not execute AssetReader dependency self-test.'}
if($setup -notmatch 'ExpectedRepakSha256' -or $setup -notmatch 'Test-ExactRepak'){Fail 'Setup does not cryptographically pin/verify bundled repak.'}
if($setup -notmatch 'Repair-OodleIfUnexpected' -or $setup -notmatch 'ExpectedOodleSha256'){Fail 'Setup does not validate an already-present local Oodle runtime.'}
if($common -notmatch 'Get-PMMReleaseManifest' -or $common -notmatch 'Test-PMMExpectedFileHash'){Fail 'Common dependency health check does not use release-manifest hashes.'}

# v1.1 runtime contract: managed helpers require exact .NET Runtime 8.0.30,
# never the SDK. Setup may reuse an exact host or install/repair the pinned
# portable runtime, but it never compiles PMM on an end-user PC.
if($setup -notmatch "ExpectedDotnetRuntimeVersion='8\.0\.30'"){Fail 'Setup does not require exact .NET Runtime 8.0.30.'}
if($setup -notmatch 'ExpectedDotnetRuntimeArchiveSha512'){Fail 'Setup does not pin the official .NET Runtime archive SHA-512.'}
if($setup -notmatch 'Test-ExactRuntimeHost' -or $setup -notmatch '--list-runtimes'){Fail 'Setup does not verify the portable runtime by runtime inventory/version.'}
if($setup -notmatch 'Test-RuntimeInventory'){Fail 'Setup does not verify the bundled .NET runtime file inventory.'}
if($setup -notmatch 'Test-StandardPackageRequiresBundledRuntime'){Fail 'Setup does not enforce the bundled runtime contract for public packages.'}
if($common -notmatch 'Test-PMMBundledRuntimeInventory'){Fail 'Common dependency health does not verify the bundled runtime inventory.'}
if($common -notmatch 'if\(\$requiresBundled\)\{return'){Fail 'Common can silently bypass a damaged public bundled runtime.'}
if($setupCode -match 'dotnet\s+publish|&\s+\$dotnet\s+publish'){Fail 'End-user setup still invokes dotnet publish; the SDK must not be required.'}
if($setupCode -match 'nuget\s+restore|dotnet\s+restore'){Fail 'End-user setup still invokes NuGet restore.'}
if($isReleaseBuilder){
  if($releaseBuilder -notmatch 'dotnet-runtime-8\.0\.30-win-x64\.zip'){Fail 'Release builder does not bundle the pinned .NET Runtime 8.0.30 payload.'}
  if($releaseBuilder -notmatch 'DotnetRuntimeSha512'){Fail 'Release builder does not SHA-512 verify the Microsoft runtime archive.'}
  if($releaseBuilder -notmatch "standardPackageDotnetBundled' \$true"){Fail 'Release builder does not declare the public .NET runtime as bundled.'}
  if($releaseBuilder -notmatch "packageProfile' 'public-offline-first'"){Fail 'Release builder does not finalize the public offline-first package profile.'}
  if($releaseValidator -notmatch 'sourceTreeRequiresReleaseBuild must be false'){Fail 'Release validator does not reject an unfinalized release-builder source tree.'}
  if($releaseValidator -notmatch 'PMMCore self-test passes under bundled runtime'){Fail 'Release validator does not execute PMMCore under the bundled runtime.'}
  if($releaseValidator -notmatch 'AssetReader dependency self-test passes under bundled runtime'){Fail 'Release validator does not execute AssetReader under the bundled runtime.'}
  if($releaseValidator -notmatch 'Tools\\dotnet\\sdk'){Fail 'Release validator does not reject an end-user .NET SDK payload.'}
} elseif($isPublicPackage){
  if(-not($releaseManifest.PSObject.Properties.Name -contains 'standardPackageDotnetBundled') -or -not[bool]$releaseManifest.standardPackageDotnetBundled){Fail 'Public package does not declare its portable .NET runtime as bundled.'}
  if(([string]$releaseManifest.dotnetRuntimeContract) -ne '8.0.30'){Fail 'Public package runtime contract is not .NET 8.0.30.'}
}
if($common -notmatch 'Get-PMMDotnetHostPath' -or $common -notmatch [regex]::Escape("Join-Path `$Script:Root 'Tools\dotnet\8.0.30'") -or $common -notmatch [regex]::Escape("Join-Path `$runtimeDir 'dotnet.exe'")){Fail 'Common runtime layer does not prefer the local .NET 8.0.30 host.'}
if($merge -notmatch '\$dotnet \$dll @Arguments'){Fail 'PMMCore is not invoked through the portable dotnet host.'}
if($merge -notmatch '\$dotnet \$reader'){Fail 'AssetReader is not invoked through the portable dotnet host.'}

if($start -notmatch 'Setup-Dependencies\.ps1.*-IfNeeded'){Fail 'Start.cmd does not run conditional dependency setup.'}
if($isReleaseBuilder){
  if($start -notmatch 'sourceTreeRequiresReleaseBuild' -or $start -notmatch 'BUILD_FINAL_RELEASE\.cmd'){Fail 'Start.cmd does not auto-route the release-builder source tree to the public release build.'}
} elseif($isPublicPackage){
  if($start -match 'sourceTreeRequiresReleaseBuild|BUILD_FINAL_RELEASE\.cmd'){Fail 'Public Start.cmd still contains maintainer release-builder routing.'}
}
if($merge -match "Mode='WinnerRequired'|Mode='FileWinnerRequired'"){Fail 'Whole-file winner fallback reappeared in MergeEngine.'}
if($merge -notmatch 'Get-PMMAssetFamilyCacheFingerprint'){Fail 'Semantic cache is not keyed by the complete cooked asset family.'}
if($merge -match '\$assetHash'){Fail 'Old .uasset-only semantic cache variable is still present.'}
if($merge -notmatch 'SemanticJson\\v2_UE5_1_'){Fail 'Semantic JSON cache schema v2 marker missing.'}


$library=Get-Content -LiteralPath (Join-Path $Root 'Core\LibraryService.ps1') -Raw
$ui=Get-Content -LiteralPath (Join-Path $Root 'Start-PalModMerger.ps1') -Raw
$xamlEn=Get-Content -LiteralPath (Join-Path $Root 'UI\MainWindow.en.xaml') -Raw
$xamlEs=Get-Content -LiteralPath (Join-Path $Root 'UI\MainWindow.es.xaml') -Raw
$start=Get-Content -LiteralPath (Join-Path $Root 'Start.cmd') -Raw
foreach($marker in @('Get-PMMDeployedPatches','Test-PMMDeployedPatchCurrent','Get-PMMCurrentDeployedPatch','Sync-PMMDeployedPatchBackups','Get-PMMLocalPatchBackups','Get-PMMManagedPatches','Import-PMMPatchBackup')){if($library -notmatch [regex]::Escape($marker)){Fail "Patch lifecycle function missing: $marker"}}
if(-not $library.Contains('Builds\Current')){Fail 'PMM patch backup library is not rooted in Builds\Current.'}
if($library -notmatch 'managed backup \(not a source mod\)'){Fail 'Generated PMM patches are not explicitly separated from source mods.'}
foreach($marker in @('AlreadyPatched','ActivePatch','OverlayPolicy','PatchedMods','DecisionSignature')){if($merge -notmatch [regex]::Escape($marker)){Fail "Merge plan/manifest patch metadata missing: $marker"}}
if($ui -notmatch 'LstPatches'){Fail 'UI does not render PMM patches in a dedicated patch area.'}
if($ui -match 'BtnRemerge|BtnRebuild'){Fail 'Obsolete Remerge/Rebuild buttons are still referenced by the UI script.'}
if($start -notmatch 'PALWORLD MANAGER MERGER'){Fail 'Start.cmd visible Palworld Manager Merger header missing.'}

$reloc=Get-Content -LiteralPath (Join-Path $Root 'Tools\PMMCore\src\PMM.Core\RelocatableDeltaAdapter.cs') -Raw
$static=Get-Content -LiteralPath (Join-Path $Root 'Tools\PMMCore\src\PMM.Core\Semantic\StaticItemDataAssetAdapter.cs') -Raw
$normalizer=Get-Content -LiteralPath (Join-Path $Root 'Tools\PMMCore\src\PMM.Core\Semantic\SemanticValueNormalizer.cs') -Raw
foreach($marker in @('RelocatableDelta-v2','CollectVariantConflicts','ApplyVariantResolutions','RequestedValues')){if($reloc -notmatch [regex]::Escape($marker)){Fail "Relocatable true-conflict support missing: $marker"}}
foreach($marker in @('IntPropertyData','EncodeInt32','IsIntProperty')){if($static -notmatch [regex]::Escape($marker)){Fail "StaticItem IntProperty support missing: $marker"}}
if($normalizer -notmatch 'IntPropertyData'){Fail 'Semantic IntProperty normalization is missing.'}
foreach($marker in @('New-PMMStaticItemConflictAnalysis','StaticItemResolutions','StaticItemConflict')){if($merge -notmatch [regex]::Escape($marker)){Fail "StaticItem property-conflict workflow missing: $marker"}}
if($core -notmatch 'SupportsStaticCustomValue'){Fail 'StaticItem scalar Custom resolution support is missing.'}
foreach($marker in @('Deploy-PMMManagedState','Get-PMMDisabledMods','Set-PMMLibraryModEnabled','Remove-PMMLibraryMod','Get-PMMPendingRemovals')){if($library -notmatch [regex]::Escape($marker)){Fail "Library/deploy workflow missing: $marker"}}
foreach($marker in @('BtnDeleteMod','BtnDeploy','Update-PMMAnalyzeIndicator','Set-PMMLibraryModEnabled','BtnDisableUnsupported')){if($ui -notmatch [regex]::Escape($marker)){Fail "UI workflow marker missing: $marker"}}
if($merge -notmatch 'RelocatableConflict'){Fail 'Relocatable true-conflict plan mode is missing.'}
if($library -notmatch 'pending-removals\.json'){Fail 'Pending-removal deployment state is missing.'}
if($ui -notmatch 'Analyze complete - current mod list is analyzed'){Fail 'Persistent analyzed-state indicator is missing.'}


# True conflicts are value-level decisions, not whole-mod winners.
foreach($marker in @('Vanilla','Custom','CompetingMods','Get-PMMResolutionToken')){if($merge -notmatch [regex]::Escape($marker)){Fail "Value-level conflict workflow missing: $marker"}}
if($ui -notmatch 'Custom value'){Fail 'Per-conflict Custom value editor is missing.'}
if($reloc -notmatch 'MergeWithoutVariants'){Fail 'Relocatable Vanilla resolution path is missing.'}
if($reloc -notmatch 'TryParseCustomByte'){Fail 'Relocatable Custom byte resolution is missing.'}
if($library -notmatch 'Get-PMMDeploymentSuppressions'){Fail 'Duplicate/quasi-duplicate deploy suppression is missing.'}
if($library -notmatch 'Test-PMMModContainsOnlyAssetFamily'){Fail 'Quasi-duplicate suppression safety check is missing.'}

# Preview29/30 hardening retained in RC34: stale plans must not survive upgrades; deployment must
# preserve alternative suppressions and never delete/overwrite unknown same-name PAKs.
foreach($marker in @('Get-PMMPlanSchemaVersion { return 14 }','Get-PMMEngineId','DeploymentSuppressions')){if($merge -notmatch [regex]::Escape($marker)){Fail "RC34 merge-plan contract marker missing: $marker"}}
foreach($marker in @('Get-PMMPendingRemovalRecords','Test-PMMSafePakLeafName','Get-PMMDeploymentPreview','New-PMMDeploymentOperationPlan','Invoke-PMMDeploymentTransaction','Builds\DeploymentBackups','BlockingConflicts')){if($library -notmatch [regex]::Escape($marker)){Fail "RC34 deployment safety marker missing: $marker"}}
if($library -notmatch 'Existing SHA-256'){Fail 'Deploy identity-collision diagnostics are missing.'}
if($ui -notmatch 'Get-PMMDeploymentPreview'){Fail 'UI does not run deployment preflight before commit.'}
if($ui -match 'Confirm\(\$preview'){Fail 'Unexpected modal Deploy confirmation reappeared.'}
if($library -notmatch '\$backupRecords=\[System\.Collections\.Generic\.List\[object\]\]::new\(\)'){Fail 'Deploy backup List[object] is not using the direct .NET constructor.'}
if($library -notmatch '\$stagedRecords=\[System\.Collections\.Generic\.List\[object\]\]::new\(\)'){Fail 'Deploy staging List[object] is not using the direct .NET constructor.'}
if($library -notmatch 'Backups=\$backupRecords\.ToArray\(\)'){Fail 'Deploy journal does not serialize backup records through ToArray().' }
if($merge -notmatch 'Migration bridge for preview28 manifests'){Fail 'Preview28 suppression migration bridge is missing.'}

# RC34 contained-superset proof and Semantic Lab/manual handoff contract.
$contained=Get-Content -LiteralPath (Join-Path $Root 'Tools\PMMCore\src\PMM.Core\ContainedDeltaSupersetAdapter.cs') -Raw
$semanticLab=Get-Content -LiteralPath (Join-Path $Root 'Core\SemanticLab.ps1') -Raw
foreach($marker in @('ContainedDeltaSuperset-v1','ExportMapEntrySize = 96','ImportMapEntrySize = 32','NormalizedExportMap','RequirePrefix','DependsBytes','PreloadDependencyBytes','SerialSize','SerialOffset','current Palworld UE5.1')){if($contained -notmatch [regex]::Escape($marker)){Fail "Contained-superset safety proof marker missing: $marker"}}
if($contained -match 'BaseLength\s*<=\s*4'){Fail 'Contained-superset adapter regressed to arbitrary small fixed-hunk acceptance.'}
if($contained -match 'asset.*BP_WingGlider|FlyMode|WingPack'){Fail 'Contained-superset adapter must remain generic and may not special-case Fly/Wing names.'}
foreach($marker in @('Write-PMMSemanticEvidence','semantic-evidence.json','Knowledge','behavior-symbols.json','known-fixtures.json','known-behaviors.json','ChangeCapsuleCandidates','HEURISTIC_ONLY','Selectable=$false','never authorizes Build')){if($semanticLab -notmatch [regex]::Escape($marker)){Fail "Semantic Lab evidence-only contract marker missing: $marker"}}
foreach($marker in @('AI_HANDOFF_','PMM_MANUAL_SOLUTION_V1','PMM_VALIDATED_MANUAL_SOLUTION_V1','Expand-PMMSafeSolutionZip','Test-PMMReviewCaseIntegrity','CONTEXT_NOTES.md','return-template','AcceptedExperimental','RuntimeStatus','UNPROVEN','ManualSolutionExperimental','ExperimentalManualSolutions')){if($merge -notmatch [regex]::Escape($marker)){Fail "AI/manual-solution contract marker missing: $marker"}}
if($merge -notmatch 'automatic safe adapters still have priority' -and $ui -notmatch 'automatic safe adapters still have priority'){Fail 'Safe automatic adapters are not explicitly prioritized over imported manual solutions.'}

# RC34 saved-patch selector contract: Previous is visible, only exact-source-set
# patches are selectable, and selected patch suppressions/deployment are derived from
# the selected manifest rather than from a different current decision.
foreach($marker in @('Get-PMMArchivedPatchBackups','Get-PMMAllLocalPatches','Test-PMMPatchSourceSetCompatible','Get-PMMSelectedManagedPatch','Set-PMMSelectedPatchName','Get-PMMPatchDeploymentSuppressions','Promote-PMMPatchToCurrent')){if($library -notmatch [regex]::Escape($marker)){Fail "RC34 saved-patch selector function missing: $marker"}}
foreach($marker in @('SelectedPatchName','Builds\Previous','ARCHIVED - SAME EFFECTIVE MERGE','Selectable rollback','User selected saved compatibility patch for Deploy','Get-PMMPatchDecisionDisplay','DecisionSummary')){if(($common+$library+$ui+$merge) -notmatch [regex]::Escape($marker)){Fail "RC34 saved-patch workflow marker missing: $marker"}}
if($library -notmatch 'Patch\.Manifest\.DeploymentSuppressions' -and $library -notmatch 'DeploymentSuppressions'){Fail 'Selected patch deployment does not preserve manifest suppressions.'}
if($merge -notmatch '\$cfg\.SelectedPatchName=\$name'){Fail 'New Build does not automatically select its newly created patch.'}
foreach($xaml in @($xamlEn,$xamlEs)){
  foreach($marker in @('GroupName="PMMPatchSelection"','IsChecked="{Binding Selected, Mode=OneWay}"','IsEnabled="{Binding Selectable}"','Binding="{Binding DecisionSummary}"','Binding="{Binding Status}"')){if($xaml -notmatch [regex]::Escape($marker)){Fail "RC34 patch radio selector XAML marker missing: $marker"}}
}

# RC34 Knowledge/community contract.
foreach($marker in @('Get-PMMKnowledgeSummary','known-fixtures.json','known-behaviors.json')){if($semanticLab -notmatch [regex]::Escape($marker)){Fail "RC34 Knowledge summary marker missing: $marker"}}
foreach($marker in @('context/global-context.json','ActiveSources','CurrentPlanAssets','COMMUNITY_KNOWLEDGE_WORKFLOW.md','Share the AI_HANDOFF ZIP as-is','RUNTIME_RESULT_TEMPLATE.md')){if($merge -notmatch [regex]::Escape($marker)){Fail "RC34 AI handoff context marker missing: $marker"}}
foreach($marker in @('TxtKnowledgeSummary','BtnOpenKnowledge','BtnOpenReviewCases')){if($ui -notmatch [regex]::Escape($marker)){Fail "RC34 Knowledge UI marker missing: $marker"}}
# RC34 UX contract: Analysis remains dominant; conflict/unsupported panels are compact;
# source mods are directly toggled; PMM outputs are separated from the source graph.
foreach($marker in @('DgAnalysisAssets','TxtAnalysisHeadline','TxtAnalysisScope','TxtSharedCount','TxtAutoCount','TxtDecisionCount','TxtUnsupportedCount','TxtExperimentalCount','TxtIdenticalCount','TxtModFilter','ExpAnalysis','ExpConflicts','ExpUnsupported','LstUnsupportedAssets','CmbUnsupportedDisable','BtnDisableUnsupported','BtnOpenAIHandoff','BtnImportManualSolution','LstPatches','TxtPatchCount','BtnResetLayout','Refresh-PMMAnalysisWorkspace','Save-PMMLayoutSettings','Update-PMMWorkspaceRows','RowAnalysisWorkspace','RowResolutionWorkspace','RowAnalysisConflictSplitter','RowWorkspaceFiller','SplAnalysisResolution')){if($ui -notmatch [regex]::Escape($marker)){Fail "RC34 UI workflow marker missing: $marker"}}
foreach($marker in @('UiWindowWidth','UiWindowHeight','UiLibraryWidth','UiAnalysisHeight','UiResolutionHeight','UiConflictListWidth','UiPatchHeight','SelectedPatchName')){if($common -notmatch [regex]::Escape($marker)){Fail "RC34 persisted layout setting missing: $marker"}}
if($ui -match 'BtnRemerge|BtnRebuild|BtnToggleMod'){Fail 'Removed preview31 action controls are still referenced by the RC34 UI script.'}
if($ui -notmatch 'Get-PMMUnsupportedDisableRanking'){Fail 'Unsupported-source least-impact suggestion helper is missing.'}
if($ui -notmatch 'different source set cannot be deployed' -and $ui -notmatch 'otro conjunto de fuentes'){Fail 'Unsafe different-source-set patch deployment explanation is missing.'}
foreach($xaml in @($xamlEn,$xamlEs)){
  foreach($marker in @('x:Name="DgAnalysisAssets"','x:Name="ExpAnalysis"','x:Name="ColLibrary"','x:Name="RowPatches"','x:Name="ColConflictAssets"','x:Name="ExpConflicts"','x:Name="ExpUnsupported"','x:Name="LstUnsupportedAssets"','x:Name="BtnOpenAIHandoff"','x:Name="BtnImportManualSolution"','x:Name="LstPatches"','x:Name="TxtKnowledgeSummary"','x:Name="BtnOpenKnowledge"','x:Name="BtnOpenReviewCases"','DataGridTemplateColumn','x:Name="RowAnalysisWorkspace"','x:Name="RowAnalysisConflictSplitter"','x:Name="RowResolutionWorkspace"','x:Name="RowWorkspaceFiller"','x:Name="SplAnalysisResolution"','x:Name="BtnBuild"','x:Name="BtnDeploy"','x:Name="BtnRestore"')){if($xaml -notmatch [regex]::Escape($marker)){Fail "RC34 XAML marker missing: $marker"}}
  foreach($removed in @('x:Name="CmbMergeMode"','x:Name="BtnRemerge"','x:Name="BtnRebuild"','x:Name="BtnToggleMod"','x:Name="RowAnalysis"')){if($xaml -match [regex]::Escape($removed)){Fail "Removed preview31 XAML control reappeared: $removed"}}
}
if($ui -match 'CmbMergeMode'){Fail 'Obsolete Strategy selector is still referenced by the RC34 UI script.'}


# v1.1 priority-order contract. The full order is persisted for reproducibility,
# but saved-patch validity changes only when priority changes an actual conflict winner.
foreach($marker in @('Get-PMMModPriorityOrder','Set-PMMModPriorityPosition','Move-PMMModPriority','Clear-PMMModPriorityDerivedState','Get-PMMMergeOrderSignature','mod-priorities.json','Get-PMMEffectivePatchOrderSignature','Test-PMMPatchEffectiveOrderCompatible','Get-PMMPatchContentSignature')){if($library -notmatch [regex]::Escape($marker)){Fail "Priority/effective-order library contract missing: $marker"}}
foreach($marker in @('MergeOrderSignature','EffectiveMergeOrderSignature','PatchContentSignature','ResolutionOrigin','Resolved by priority','Get-PMMPriorityDefaultChoice','BuildAssetEvidence')){if($merge -notmatch [regex]::Escape($marker)){Fail "Priority/build-evidence merge contract missing: $marker"}}
foreach($marker in @('BtnPriorityUp','BtnPriorityDown','Priority=[int]$mod.Priority','Sort-Object Priority,Name','Invoke-PMMPriorityEditorCommit','Add_PreviewMouseMove','Add_DragOver','Add_Drop','PMM.ModPriority','MinimumVerticalDragDistance','ModListScrollViewer.LineUp()','ModListScrollViewer.LineDown()')){if($ui -notmatch [regex]::Escape($marker)){Fail "Priority UI contract missing: $marker"}}
foreach($xaml in @($xamlEn,$xamlEs)){foreach($marker in @('x:Name="BtnPriorityUp"','x:Name="BtnPriorityDown"','AllowDrop="True"','PriorityEditorTextBox','Text="{Binding Priority, Mode=OneWay}"','DisplayMemberPath="Label"','SelectedValuePath="Code"','Style TargetType="ComboBoxItem"')){if($xaml -notmatch [regex]::Escape($marker)){Fail "Priority/XAML UI marker missing: $marker"}}}
foreach($marker in @('SelectedValue','LanguageOptions','HeightProperty,[double]30','FontSizeProperty,[double]13')){if($ui -notmatch [regex]::Escape($marker)){Fail "ComboBox consistency marker missing: $marker"}}
if($merge -notmatch "SchemaVersion=8"){Fail 'Build manifest schema 8 is missing.'}
if($merge -notmatch "uasset\|uexp\|ubulk"){Fail 'Cooked backup-artifact filter is missing.'}
if($library -notmatch 'return \$null\s*\r?\n\}'){Fail 'Saved-patch selection no longer has an explicit no-current-order fallback.'}

# Windows PowerShell 5.1 regression: do not wrap an `if` statement in ordinary parentheses as an expression.
# RC2 used `Write-PMMLog ((if(...)) + ...)`, which PowerShell attempted to invoke as a command at runtime.
if($library -match '\(\(\s*if\b'){Fail 'Invalid PowerShell inline ((if...) expression found in LibraryService.'}
if($library -notmatch '\$actionLabel=if\(\$Enabled\)'){Fail 'RC4 enable/disable action-label hotfix is missing.'}

# RC34 RC4 manager-only deployment contract.
foreach($marker in @('Get-PMMNoPatchSelectionName','Test-PMMNoPatchSelected','Get-PMMExactDuplicateSuppressions','NoPatchSelected')){if($library -notmatch [regex]::Escape($marker)){Fail "RC34 RC4 manager-only function/marker missing: $marker"}}
foreach($marker in @('No compatibility patch','SOURCE MODS ONLY','manager-only Deploy','User selected manager-only Deploy')){if($ui -notmatch [regex]::Escape($marker)){Fail "RC34 RC4 manager-only UI marker missing: $marker"}}
foreach($xaml in @($xamlEn,$xamlEs)){if($xaml -notmatch 'Tag="\{Binding SelectionKey\}"'){Fail 'RC34 RC4 patch radio does not bind its explicit selection key.'}}
if($library -notmatch 'if\s*\(\s*-not\s*\$noPatchSelected\s*-and\s*-not\s*\$selectedPatch\s*-and\s*-not\s*\$effectivePlan\s*\)'){Fail 'Manager-only/saved-patch deployment Analyze gate is not conditioned on no-patch, saved-patch and current-plan state.'}
if($library -notmatch 'Get-PMMExactDuplicateSuppressions \$active'){Fail 'Manager-only deployment does not limit automatic suppression to exact duplicates.'}
if($library -notmatch 'replace/remove old PMM overlay'){Fail 'Manager-only Deploy can no longer remove an existing managed PMM overlay.'}
if($xamlEn -notmatch 'Palworld Manager Merger v1.1' -or $xamlEs -notmatch 'Palworld Manager Merger v1.1'){Fail 'v1.1 window branding is missing.'}


# v1.1 saved-patch/no-Analyze regression: after manager-only deployment, selecting an
# already saved patch for the exact active source hashes + mappings must enable Deploy
# immediately. Analyze is required for Build/new planning, not for safe saved-patch deployment.
foreach($marker in @('$selectedPatch=if($noPatchSelected){$null}else{Get-PMMSelectedManagedPatch $sourceMods}','elseif($selectedPatch){','$Script:BtnDeploy.IsEnabled=$true','Deploy is ready without Analyze.')){if($ui -notmatch [regex]::Escape($marker)){Fail "v1.1 saved-patch-without-Analyze marker missing: $marker"}}
foreach($marker in @('$selectedPatch=if($noPatchSelected){$null}else{Get-PMMSelectedManagedPatch $active}','$effectivePlan=if($planCurrent){$plan}else{$null}','no saved patch matches the exact active source hashes + mappings','Get-PMMPatchDeploymentSuppressions $active $patch $effectivePlan')){if($library -notmatch [regex]::Escape($marker)){Fail "v1.1 saved-patch deployment-context marker missing: $marker"}}

# v1.1 community/runtime recipe contract. A contributed manual solution may be
# promoted only as an exact hash-pinned runtime-proven reuse recipe. Changed inputs
# must fall back to normal adapters/Unsupported rather than matching by filename.
foreach($marker in @('Get-PMMProductionRecipeMatch','Test-PMMRecipeFamilyExact','exact-runtime-proven-reuse-provider','reuse-provider-family','requireExactProviderSet')){if(($recipeService+$recipeJson) -notmatch [regex]::Escape($marker)){Fail "v1.1 production recipe marker missing: $marker"}}
foreach($marker in @('RushRoarLeatherDrop_v2_P.pak','FasterMounts4xAllWorkSuitabilitiesLevel10_P.pak','73bb3d0635170dad4cb3f7a8','b663b49a2a0825b01c45bfd223b2114e7dfc30bf108d8250aa89f6d82ee4a266','f91dd7ae1aa0d5ef1399d9185cee74a4ce06d907cfaf4c936489dbdf67b21e64')){if($recipeJson -notmatch [regex]::Escape($marker)){Fail "v1.1 RushRoar/FasterMounts recipe evidence missing: $marker"}}
foreach($marker in @('KnownRecipeAuto','New-PMMKnownRecipeAnalysis','Get-PMMProductionRecipeMatch','Runtime-proven exact Knowledge recipe matched')){if($merge -notmatch [regex]::Escape($marker)){Fail "v1.1 known-recipe merge path missing: $marker"}}
if($dataTableMap -notmatch 'SourceId' -or $dataTableMap -notmatch '#\{occurrence\}'){Fail 'v1.1 duplicate DataTable row occurrence identity support is missing.'}
if($recipeService -match 'RushRoarLeatherDrop_v2_P\.pak.*-eq|FasterMounts4xAllWorkSuitabilitiesLevel10_P\.pak.*-eq'){Fail 'Production recipe service must not authorize by provider filename.'}

# v1.1 Game Reference / fresh-session AI handoff / contribution contract.
foreach($marker in @('PMM_GAME_REFERENCE_SCOPE_V1','Build-PMMGameReferenceLibrary','Get-PMMGameReferenceState','Add-PMMGameReferenceToHandoff','families.jsonl','reference-reasons.json')){if($gameReference -notmatch [regex]::Escape($marker)){Fail "v1.1 Game Reference marker missing: $marker"}}
foreach($marker in @('Pal/Content/Pal/DataTable/','Pal/Content/Pal/Blueprint/Action/','Pal/Content/Pal/Blueprint/Character/Monster/','Pal/Content/Pal/Blueprint/Character/Player/','Pal/Content/Pal/Blueprint/Component/')){if($gameReference -notmatch [regex]::Escape($marker)){Fail "v1.1 Game Reference broad root missing: $marker"}}
if($gameReference -match "-match.*ranch|Contains\('ranch'\)"){Fail 'Game Reference reintroduced an unrestricted ranch substring selector (Ranch != Branch).'}
if($gameReference -match 'Build-PMMMerge|production-recipes\.json'){Fail 'Game Reference service must not authorize production merge/recipe writes.'}
foreach($marker in @('Assume you have ZERO prior PMM/Palworld project chat context','Add-PMMGameReferenceToHandoff','source-solution.zip')){if($merge -notmatch [regex]::Escape($marker)){Fail "v1.1 enriched handoff marker missing: $marker"}}
foreach($marker in @('PMM_KNOWLEDGE_CONTRIBUTION_V1','runtime-result.json','original-handoff.zip','returned-solution.zip')){if($contributionService -notmatch [regex]::Escape($marker)){Fail "v1.1 tested contribution marker missing: $marker"}}
if($contributionService -match 'production-recipes\.json'){Fail 'Community contribution export must not auto-promote a production recipe.'}
foreach($marker in @('ranch-spawnitem-context-v1','SpawnItem','DT_ItemLotteryDataTable','BP_Action_SpawnItemBase')){if($referenceRelations -notmatch [regex]::Escape($marker)){Fail "v1.1 reference-relation marker missing: $marker"}}
foreach($marker in @('TxtGameReferenceSummary','BtnBuildGameReference','BtnOpenGameReference','BtnExportKnowledgeContribution','BtnOpenKnowledgeContributions')){if($ui -notmatch [regex]::Escape($marker)){Fail "v1.1 Game Reference/community UI marker missing: $marker"}}

# RC34 regression: Build must not use scalar .Count on the experimental-solution producer.
if($ui -match '\$experimental\.Count'){Fail 'Build wrapper still uses the preview32 scalar experimental.Count pattern.'}
if($ui -notmatch '\[object\[\]\]\$experimental=@\('){Fail 'Build wrapper does not force experimental solutions into an object array.'}
if($ui -notmatch '\$experimentalCount=\$experimental\.Length'){Fail 'Build wrapper does not use array Length for experimental solution count.'}


# Clean v1.1 release contract.
$buildId=(Get-Content -LiteralPath (Join-Path $Root 'BUILD_ID.txt') -Raw).Trim()
if($buildId -ne 'PMM-v1.1-CLEAN-RC1'){Fail "Unexpected BUILD_ID.txt: $buildId"}
foreach($forbidden in @('MegaMerge','Copy-PMMUniqueGroupsForMegaMerge','Resolve-PMMGroupProviderForBuild')){
  if($merge -match [regex]::Escape($forbidden)){Fail "Retired MegaMerge code is present: $forbidden"}
}
foreach($forbidden in @('BtnConsoleRun','ChkConsoleDeveloperMode','CmbConsoleMode','ModEditService','BtnModEdit')){
  if(($ui+$xamlEn+$xamlEs) -match [regex]::Escape($forbidden)){Fail "Removed Console/Mod Edit UI marker is present: $forbidden"}
}
foreach($marker in @('Start-PMMBackgroundOperation','Complete-PMMBackgroundOperation','Core\OperationWorker.ps1','-Operation Analyze','-Operation Build')){
  if($ui -notmatch [regex]::Escape($marker)){Fail "Background Analyze/Build UI contract missing: $marker"}
}
foreach($marker in @('PMM_BACKGROUND_OPERATION_PROGRESS_V1','PMM_BACKGROUND_OPERATION_RESULT_V1','Invoke-PMMScan','Build-PMMMerge')){
  if($operationWorker -notmatch [regex]::Escape($marker)){Fail "Background operation worker marker missing: $marker"}
}
foreach($marker in @('Start-PMMGameReferenceBuild','PrgGameReference','TxtGameReferenceProgress')){
  if(($ui+$xamlEn+$xamlEs) -notmatch [regex]::Escape($marker)){Fail "Background Game Reference UI marker missing: $marker"}
}
foreach($marker in @('PMM_GAME_REFERENCE_PROGRESS_V1','Build-PMMGameReferenceLibrary')){
  if($gameReferenceWorker -notmatch [regex]::Escape($marker)){Fail "Game Reference worker marker missing: $marker"}
}
if($releaseManifestText -notmatch '"megaMergeSupported"\s*:\s*false'){Fail 'Release manifest does not explicitly disable MegaMerge.'}
if($releaseManifestText -match '"consoleModes"|"modEditSchema"'){Fail 'Release manifest still advertises removed Console/Mod Edit features.'}
if($releaseManifestText -notmatch '"packageProfile"\s*:\s*"public-offline-first"'){Fail 'Clean release is not marked public-offline-first.'}
if($releaseManifestText -notmatch '"operationBackgroundWorker"\s*:\s*"Core/OperationWorker.ps1"'){Fail 'Release manifest does not record the Analyze/Build worker.'}

if($failures.Count -gt 0){Write-Host 'Palworld Manager Merger v1.1 smoke test FAILED:' -ForegroundColor Red;foreach($f in $failures){Write-Host " - $f"};exit 1}
Note 'Source/XAML/runtime-contract checks passed.'
exit 0
