param([switch]$Quiet)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$Root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..'))
$App = Join-Path $Root 'PMM'
$Failures = [System.Collections.Generic.List[string]]::new()

function Fail([string]$Message) {
  $Failures.Add($Message)
  Write-Output ('[FAIL] ' + $Message)
}

function Pass([string]$Message) {
  if (-not $Quiet) { Write-Output ('[PASS] ' + $Message) }
}

function NeedFile([string]$Relative) {
  if (Test-Path -LiteralPath (Join-Path $Root $Relative) -PathType Leaf) { Pass $Relative }
  else { Fail ('Missing file: ' + $Relative) }
}

function NeedDir([string]$Relative) {
  if (Test-Path -LiteralPath (Join-Path $Root $Relative) -PathType Container) { Pass $Relative }
  else { Fail ('Missing directory: ' + $Relative) }
}

foreach ($directory in @(
  '.github','PMM','Development','Development\Source','Development\Docs','Development\AI',
  'Development\Scripts','Development\Tests','PMM\Engine','PMM\Modules','PMM\Resources','PMM\Resources\Themes',
  'PMM\CKL','PMM\Documentation'
)) { NeedDir $directory }

foreach ($file in @(
  'README.md','LICENSE','Development\AI\CURRENT_STATE.md','Development\AI\AI_CONTINUE_HERE.md',
  'Development\AI\AIIO_1_3_0_HANDOFF.md','Development\Docs\RC23_RELEASE_NOTES.md','Development\Docs\RC24_RELEASE_NOTES.md','Development\Docs\RC25_RELEASE_NOTES.md','Development\Docs\RC26_RELEASE_NOTES.md','Development\Docs\RC27_RELEASE_NOTES.md','Development\Docs\RC28_RELEASE_NOTES.md','Development\Docs\RC29_RELEASE_NOTES.md','Development\Docs\RC30_RELEASE_NOTES.md',
  'Development\Docs\PMM_1_3_1_MOD_CREATION.md','Development\Tests\v131_mod_creation_model.py',
  'Development\Docs\Validation\RC23_STATIC_VALIDATION.md','Development\Docs\Validation\RC24_STATIC_VALIDATION.md','Development\Docs\Validation\RC25_STATIC_VALIDATION.md','Development\Docs\Validation\RC26_STATIC_VALIDATION.md','Development\Docs\Validation\RC27_STATIC_VALIDATION.md','Development\Docs\Validation\RC28_STATIC_VALIDATION.md','Development\Docs\Validation\RC29_STATIC_VALIDATION.md','Development\Docs\Validation\RC30_STATIC_VALIDATION.md','Development\Tests\rc23_singleton_collection_regression.ps1',
  'Development\Tests\rc23_singleton_guard_model.py','Development\Tests\rc24_ui_fixlab_ownership_regression.ps1','Development\Tests\rc24_ui_fixlab_ownership_model.py','Development\Tests\rc25_release_model.py','Development\Tests\rc26_official_themes_progress_compatibility_model.py','Development\Tests\rc26_semantic_compatibility_regression.ps1','Development\Tests\rc27_aiio_local_first_model.py','Development\Tests\rc28_validation_runtime_regression.ps1','Development\Tests\rc28_validation_runtime_regression_model.py','Development\Tests\rc29_aihelp_feedback_ui_regression.ps1','Development\Tests\rc29_aihelp_feedback_ui_model.py','Development\Tests\rc30_lean_ai_validation_regression.ps1','Development\Tests\rc30_lean_ai_validation_model.py',
  'PMM\PMM.exe','PMM\Engine\PMMRuntime.exe','PMM\Engine\PMMFixLab.exe','PMM\Engine\repak.exe',
  'PMM\Modules\Shared\Paths.ps1','PMM\Modules\Bootstrap\Start-PalModMerger.ps1',
  'PMM\Modules\Merge\MergeEngine.ps1','PMM\Modules\Merge\PakService.ps1','PMM\Modules\AIIO\AIIO.ps1','PMM\Modules\AIIO\AIIO.SessionService.ps1','PMM\Modules\AIIO\AIIO.DiagnosticService.ps1','PMM\Modules\AIIO\AIIO.ModCreationService.ps1','PMM\Modules\AIIO\AIIO.ResponseService.ps1','PMM\Modules\AIIO\AIIO.ArtifactService.ps1','PMM\Modules\AIIO\AIIO.ValidationService.ps1','PMM\Modules\Operations\OperationJournal.ps1','PMM\Modules\Saves\SaveActivityService.ps1','PMM\Modules\Theme\ThemeService.ps1','PMM\Modules\Theme\ThemeEditorService.ps1',
  'PMM\Resources\Metadata\RELEASE_MANIFEST.json','PMM\Resources\Metadata\VERSION.txt',
  'PMM\Resources\Metadata\BUILD_ID.txt','PMM\Resources\Metadata\SHA256SUMS.txt',
  'PMM\Resources\UI\PMM.ico','PMM\Resources\UI\PMMLogo.png','PMM\Resources\UI\MainWindow.xaml',
  'PMM\Resources\UI\MainWindow.en.xaml','PMM\Resources\UI\MainWindow.es.xaml','PMM\Resources\Themes\BUNDLED_THEME_MANIFEST.json','PMM\Resources\Themes\PMM_COLOR_SCHEME_PMM_CRYSTAL.json','PMM\Resources\Themes\PMM_COLOR_SCHEME_AURORA_CONFETTI.json',
  'PMM\Resources\Mappings\Mappings.usmap','PMM\CKL\Catalog\case-index.json',
  'PMM\CKL\channels.json','PMM\CKL\Stable\production-recipes.json',
  'PMM\Documentation\RC23_RELEASE_CANDIDATE.md','PMM\Documentation\AIIO_HANDOFF_RC23.md',
  'PMM\Documentation\RC24_RELEASE_CANDIDATE.md','PMM\Documentation\AIIO_HANDOFF_RC24.md',
  'PMM\Documentation\RC25_RELEASE_CANDIDATE.md','PMM\Documentation\AIIO_HANDOFF_RC25.md',
  'PMM\Documentation\RC26_RELEASE_CANDIDATE.md','PMM\Documentation\AIIO_HANDOFF_RC26.md',
  'PMM\Documentation\RC27_AIIO_RELEASE_CANDIDATE.md','PMM\Documentation\AIIO_HANDOFF_RC27.md','PMM\Documentation\TEST_THIS_BUILD_RC27.txt',
  'PMM\Documentation\RC28_VALIDATION_RUNTIME_FIX.md','PMM\Documentation\AIIO_HANDOFF_RC28.md','PMM\Documentation\TEST_THIS_BUILD_RC28.txt',
  'PMM\Documentation\RC29_AIHELP_FEEDBACK_UI_FIX.md','PMM\Documentation\AIIO_HANDOFF_RC29.md','PMM\Documentation\TEST_THIS_BUILD_RC29.txt','PMM\Documentation\RC30_RELEASE_CANDIDATE.md','PMM\Documentation\AIIO_HANDOFF_RC30.md','PMM\Documentation\TEST_THIS_BUILD_RC30.txt',
  'PMM\Documentation\MOD_CREATION_AIIO.md','PMM\Documentation\TEST_THIS_BUILD_1_3_1_MOD_CREATION.txt'
)) { NeedFile $file }

$rootFiles = @(Get-ChildItem -LiteralPath $App -File -Force)
if ($rootFiles.Count -ne 1 -or $rootFiles[0].Name -ne 'PMM.exe') {
  Fail ('PMM application root must expose only PMM.exe; found: ' + ($rootFiles.Name -join ', '))
} else { Pass 'PMM root exposes only PMM.exe' }

if (Test-Path -LiteralPath (Join-Path $App 'Workspace')) { Fail 'Workspace must not be committed or shipped.' }
else { Pass 'No runtime Workspace shipped' }

foreach ($pattern in @('*.pak','*.ucas','*.utoc')) {
  $payloads = @(Get-ChildItem -LiteralPath $Root -Recurse -File -Filter $pattern -ErrorAction SilentlyContinue)
  if ($payloads.Count) { Fail ($pattern + ' payloads present: ' + $payloads.Count) }
  else { Pass ('No ' + $pattern + ' payloads committed') }
}
$oodle = @(Get-ChildItem -LiteralPath $Root -Recurse -File -Filter 'oo2core_9_win64.dll' -ErrorAction SilentlyContinue)
if ($oodle.Count) { Fail 'Proprietary oo2core_9_win64.dll must not be committed or shipped.' }
else { Pass 'No proprietary Oodle DLL shipped' }

foreach ($json in @(Get-ChildItem -LiteralPath $App -Recurse -File -Filter '*.json')) {
  try { $null = Get-Content -LiteralPath $json.FullName -Raw -Encoding UTF8 | ConvertFrom-Json }
  catch { Fail ('Invalid JSON: ' + $json.FullName + ' | ' + $_.Exception.Message) }
}
Pass 'Application JSON parsed'

$manifestPath = Join-Path $App 'Resources\Metadata\RELEASE_MANIFEST.json'
$manifest = Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
if ([string]$manifest.version -ne '1.3.1') { Fail 'Manifest version must be 1.3.1.' }
if ([int]$manifest.mergePlanSchema -ne 18) { Fail 'Manifest merge-plan schema must be 18.' }
if ([int]$manifest.buildManifestSchema -ne 9) { Fail 'Manifest build-manifest schema must be 9.' }
if ([string]$manifest.releaseCandidate -ne '1.3.1-mod-creation-preview') { Fail 'Manifest 1.3.1 Mod Creation identity mismatch.' }
if ([string]$manifest.buildId -ne 'PMM-v1.3.1-MOD-CREATION-PREVIEW') { Fail 'Manifest 1.3.1 Mod Creation build ID mismatch.' }
if ([int]$manifest.bundledThemeCount -ne 11) { Fail 'Manifest bundled-theme count must be 11.' }
if ([int]$manifest.officialThemeChoiceCount -ne 13) { Fail 'Manifest official-theme choice count must be 13.' }
if ([string]$manifest.runtime.executable -ne 'Engine/PMMRuntime.exe') { Fail 'Runtime manifest path mismatch.' }
if ([string]$manifest.aiioModule -ne 'Modules/AIIO/AIIO.ps1') { Fail 'AIIO manifest path mismatch.' }
if ([string]$manifest.aiioCapabilitySet -ne 'PMM_CAPABILITIES_V2') { Fail 'AIIO Mod Creation capability-set mismatch.' }
if ([string]$manifest.aiioModCreationCandidateSchema -ne 'PMM_MOD_CREATION_CANDIDATE_V1') { Fail 'AIIO Mod Creation candidate schema mismatch.' }
if ([string]$manifest.aiioTransport -ne 'manual local ZIP only') { Fail 'RC27 AIIO transport must remain manual local ZIP only.' }
if ([bool]$manifest.aiioRemoteUploadEnabled -or [bool]$manifest.aiioProviderLoginEnabled -or [bool]$manifest.aiioReturnedCodeExecutionEnabled) { Fail 'RC27 AIIO trust boundary was weakened.' }
if ([string]$manifest.aiioFeedbackSchema -ne 'PMM_USER_FEEDBACK_V1' -or [string]$manifest.aiioFeedbackTransport -notmatch 'manual sharing only') { Fail 'RC30 feedback boundary mismatch.' }
if ('AIIOArtifactRefresh' -notin @($manifest.backgroundOperations|ForEach-Object{[string]$_})) { Fail 'RC27 background artifact inventory is not declared.' }
if ('AIIOModBuild' -notin @($manifest.backgroundOperations|ForEach-Object{[string]$_})) { Fail 'AIIO standalone mod build operation is not declared.' }
$buildId = (Get-Content -LiteralPath (Join-Path $App 'Resources\Metadata\BUILD_ID.txt') -Raw).Trim()
if ($buildId -ne [string]$manifest.buildId) { Fail 'Metadata BUILD_ID and manifest buildId differ.' }
else { Pass ('Build identity: ' + $buildId) }

$xamlNamespace = 'http://schemas.microsoft.com/winfx/2006/xaml'
$xamlNameSets = @{}
foreach ($name in @('MainWindow.xaml','MainWindow.en.xaml','MainWindow.es.xaml')) {
  $path = Join-Path $App ('Resources\UI\' + $name)
  try {
    [xml]$document = Get-Content -LiteralPath $path -Raw -Encoding UTF8
    $manager = New-Object System.Xml.XmlNamespaceManager($document.NameTable)
    $manager.AddNamespace('x',$xamlNamespace)
    $names = @($document.SelectNodes('//*[@x:Name]',$manager) | ForEach-Object { $_.GetAttribute('Name',$xamlNamespace) })
    $duplicates = @($names | Group-Object | Where-Object Count -gt 1 | ForEach-Object Name)
    if ($duplicates.Count) { Fail ($name + ' duplicate x:Name: ' + ($duplicates -join ', ')) }
    $xamlNameSets[$name] = @($names | Sort-Object -Unique)
  } catch { Fail ('Invalid XAML ' + $name + ': ' + $_.Exception.Message) }
}
if ($xamlNameSets.Count -eq 3) {
  $reference = @($xamlNameSets['MainWindow.xaml'])
  foreach ($name in @('MainWindow.en.xaml','MainWindow.es.xaml')) {
    $delta = @(Compare-Object $reference @($xamlNameSets[$name]))
    if ($delta.Count) { Fail ('XAML x:Name parity mismatch: ' + $name) }
  }
  if (-not $Failures.Count) { Pass 'Default/English/Spanish XAML control parity' }
}

$bootstrapPath = Join-Path $App 'Modules\Bootstrap\Start-PalModMerger.ps1'
$bootstrap = Get-Content -LiteralPath $bootstrapPath -Raw -Encoding UTF8
foreach ($marker in @('ImgPMMLogo','BtnRestoreDefaults','Everything is ready to play.','Ya está todo listo para jugar.','PMMLogo.png')) {
  if ($bootstrap -notmatch [regex]::Escape($marker)) { Fail ('Bootstrap marker missing: ' + $marker) }
}
foreach ($marker in @('function Set-PMMSmoothedProgressBar','3000.0/$gap','state.Displayed=$priorTarget','$start=if($target -le 1){$target}else{0.0}','function Update-PMMResponsiveLayout','SetRow($Script:GrdHeaderActions,1)','Import-PMMThemeInputs -Paths')) {
  if ($bootstrap -notmatch [regex]::Escape($marker)) { Fail ('RC25 bootstrap marker missing: ' + $marker) }
}
foreach ($marker in @('PnlUserThemeOptions','TxtUserThemeEmpty','if($target -ge 100.0)','$Bar.Value=100.0','return 100.0')) {
  if ($bootstrap -notmatch [regex]::Escape($marker)) { Fail ('RC26 theme/progress marker missing: ' + $marker) }
}
foreach ($marker in @('TabAIHelp','AIHelpTabs','LstAIIOSessions','LstAIIOCandidates','PnlThemeEditorRows','AIIOArtifactRefresh','Set-PMMAIIOProgress')) {
  if ($bootstrap -notmatch [regex]::Escape($marker)) { Fail ('RC27 AI & Help marker missing: ' + $marker) }
}
$merge = Get-Content -LiteralPath (Join-Path $App 'Modules\Merge\MergeEngine.ps1') -Raw -Encoding UTF8
foreach ($marker in @('Get-PMMPlanSchemaVersion { return 18 }','PMM_ANALYZE_GROUP_CACHE_V2','AnalyzeGroupsV2','Try-PMMReuseCurrentAnalyzePlan','Test-PMMSafeAnalyzeCacheMode','Get-PMMFastPatchReuseCandidate','AnalyzedSharedAssets=@(','ProductionRecipesSha256=','SchemaVersion=9','KnowledgeRulesSha256=','DecisionKind=''AutomaticCompatibility''','AutomaticResolutions=$automatic.ToArray()')) {
  if ($merge -notmatch [regex]::Escape($marker)) { Fail ('Analyze marker missing: ' + $marker) }
}
foreach ($marker in @("'anyTwoActive' {`$triggerAccepted=(`$present.Count -ge 2)}",'Get-PMMPackageChoiceAnalyses $mods $previous','Get-PMMAssetGroups $analysisMods','Analyze slow-group complete:')) {
  if ($merge -notmatch [regex]::Escape($marker)) { Fail ('RC25 Analyze preflight marker missing: ' + $marker) }
}
if ($merge.IndexOf('Get-PMMPackageChoiceAnalyses $mods $previous') -ge $merge.IndexOf('Get-PMMAssetGroups $analysisMods')) { Fail 'Package choice must run before asset enumeration.' }
$library = Get-Content -LiteralPath (Join-Path $App 'Modules\Library\LibraryService.ps1') -Raw -Encoding UTF8
foreach ($marker in @('Test-PMMPatchPlanCompatible','Test-PMMPlanCurrentForPatchCompatibility','Test-PMMPatchRuntimeCompatible','Test-PMMKnownRecipeAssetCompatible','Get-PMMProductionRecipeLibrarySha256','Get-PMMAutomaticResolutionSignature','knowledgeAuthorizedAssets','KnowledgeRulesSha256')) {
  if ($library -notmatch [regex]::Escape($marker)) { Fail ('Patch-proof marker missing: ' + $marker) }
}
if ($library -notmatch [regex]::Escape('Keep an actual Object[] for zero, one or many matches')) { Fail 'RC23 singleton collection guard marker missing.' }
if ($library -match '\$(knownRecipeAssets|knowledgeAuthorizedAssets)\s*=\s*if\s*\(') { Fail 'Knowledge-authorized collection still uses an unwrapping if assignment.' }
if ($merge -match '\$(decisions|patchAssets)\s*=\s*if\s*\([^\r\n]*\)\s*\{@\(') { Fail 'Fast-reuse collection still uses an unwrapping if assignment.' }
$fixlab = Get-Content -LiteralPath (Join-Path $App 'Modules\FixLab\FixLabService.ps1') -Raw -Encoding UTF8
foreach ($marker in @('function Queue-PMMFixLabUiRefresh','DispatcherPriority]::ContextIdle','$Script:FixLabRefreshIntervalSeconds=60','Get-PMMFixLabDiscoveryCandidates -IncludeBackups -BackupRows $backups')) {
  if ($bootstrap -notmatch [regex]::Escape($marker)) { Fail ('RC24 deferred Fix Lab UI marker missing: ' + $marker) }
}
foreach ($marker in @('belongs exclusively to Mods & Merge','deployed compatibility merge preserved')) {
  if ($fixlab -notmatch [regex]::Escape($marker)) { Fail ('RC24 Fix Lab merge-ownership marker missing: ' + $marker) }
}
if ($library -notmatch [regex]::Escape('deployedMergePreserved=true')) { Fail 'RC24 source-delete merge-preservation marker missing.' }
$common = Get-Content -LiteralPath (Join-Path $App 'Modules\Shared\Common.ps1') -Raw -Encoding UTF8
foreach ($marker in @('SoundDefaultsVersion=3','SoundSemiAutoEnabled=$true','$soundDefaultsVersion -lt 3')) {
  if ($common -notmatch [regex]::Escape($marker)) { Fail ('RC22 Semiauto marker missing: ' + $marker) }
}
$pakService = Get-Content -LiteralPath (Join-Path $App 'Modules\Merge\PakService.ps1') -Raw -Encoding UTF8
foreach ($marker in @('PMM_PAK_INDEX_V1','PakIndexesV1','LastWriteTimeUtc.Ticks')) {
  if ($pakService -notmatch [regex]::Escape($marker)) { Fail ('RC22 PAK-index marker missing: ' + $marker) }
}

$themeService = Get-Content -LiteralPath (Join-Path $App 'Modules\Theme\ThemeService.ps1') -Raw -Encoding UTF8
foreach ($marker in @('Theme ZIP exceeds 25 MiB','Archive contains more than 200 entries','Archive expands beyond 75 MiB','Nested archives are not allowed','Executable content is not allowed','Invalid or unsafe PMM_COLOR_SCHEME_V1 definition','official reserved id and cannot be replaced','legacy built-in reserved id','parse-all-before-commit')) {
  if ($themeService -notmatch [regex]::Escape($marker)) { Fail ('RC25 theme-import marker missing: ' + $marker) }
}
$themeFiles = @(Get-ChildItem -LiteralPath (Join-Path $App 'Resources\Themes') -File -Filter 'PMM_COLOR_SCHEME_*.json')
if ($themeFiles.Count -ne 11) { Fail ('Expected 11 bundled themes, found ' + $themeFiles.Count) }
else { Pass 'Bundled theme count: 11' }
$themeIds = @()
foreach ($themeFile in $themeFiles) {
  $theme = Get-Content -LiteralPath $themeFile.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
  if ([string]$theme.schema -ne 'PMM_COLOR_SCHEME_V1') { Fail ('Bad theme schema: ' + $themeFile.Name) }
  if (@($theme.palette.PSObject.Properties).Count -ne 46) { Fail ('Theme palette-key count is not 46: ' + $themeFile.Name) }
  if (@($theme.colorFlow.PSObject.Properties).Count -ne 5) { Fail ('Theme ColorFlow-state count is not 5: ' + $themeFile.Name) }
  $themeIds += [string]$theme.id
}
if (@($themeIds|Group-Object|Where-Object Count -gt 1).Count) { Fail 'Bundled theme IDs are not unique.' }
if ('pmm-crystal' -notin $themeIds -or 'aurora-confetti' -notin $themeIds) { Fail 'Required RC25 theme IDs are missing.' }
$officialThemeManifest = Get-Content -LiteralPath (Join-Path $App 'Resources\Themes\OFFICIAL_THEME_MANIFEST.json') -Raw -Encoding UTF8 | ConvertFrom-Json
if ([int]$officialThemeManifest.officialThemeCount -ne 11 -or @($officialThemeManifest.themes).Count -ne 11 -or @($officialThemeManifest.excludedExperiments).Count -ne 0) { Fail 'RC26 official-theme manifest must contain all eleven JSON schemes and no excluded experiment.' }
else { Pass 'RC27 official-theme manifest: 11 JSON schemes plus Night/Light built-ins' }

$aiioResponse = Get-Content -LiteralPath (Join-Path $App 'Modules\AIIO\AIIO.ResponseService.ps1') -Raw -Encoding UTF8
foreach ($marker in @('PMM_AI_RESPONSE_V2','Unsafe AI response path','Duplicate AI response path','AI response contains an undeclared payload','Symbolic links are forbidden','Executable content is forbidden','PMM_MANUAL_SOLUTION_V1','AcceptedExperimental','UNPROVEN')) {
  if ($aiioResponse -notmatch [regex]::Escape($marker)) { Fail ('RC27 AIIO response boundary marker missing: ' + $marker) }
}
foreach ($forbidden in @('Invoke-WebRequest','Invoke-RestMethod','Invoke-Expression')) {
  if ($aiioResponse -match [regex]::Escape($forbidden)) { Fail ('Forbidden executable/network primitive in AIIO response service: ' + $forbidden) }
}
$modCreation = Get-Content -LiteralPath (Join-Path $App 'Modules\AIIO\AIIO.ModCreationService.ps1') -Raw -Encoding UTF8
foreach ($marker in @('PMM_MOD_CREATION_CANDIDATE_V1','standalone-cooked-tree','Get-PMMAIIOGameReferenceProof -RequireCurrent','PMM/Metadata/created-with-pmm.json','This mod was created with PMM assistance.','AutomaticallyDeployed=$false','AutomaticallyPublished=$false','KnowledgeStatus=''UNPROVEN''')) {
  if ($modCreation -notmatch [regex]::Escape($marker)) { Fail ('1.3.1 Mod Creation marker missing: ' + $marker) }
}
$modBuildBody = [regex]::Match($modCreation,'(?s)function Build-PMMAIIOModCandidate\b.*$').Value
foreach ($forbidden in @('Invoke-PMMDeploy','Deploy-PMM','Invoke-WebRequest','Invoke-RestMethod')) {
  if ($modBuildBody -match [regex]::Escape($forbidden)) { Fail ('Forbidden Mod Creation primitive: ' + $forbidden) }
}
$themeEditor = Get-Content -LiteralPath (Join-Path $App 'Modules\Theme\ThemeEditorService.ps1') -Raw -Encoding UTF8
foreach ($marker in @('PMM_COLOR_SCHEME_V2','PMM_THEME_PACK_V1','Set-PMMThemeDraftImage','Import-PMMThemeAIResponse')) {
  if ($themeEditor -notmatch [regex]::Escape($marker)) { Fail ('RC27 theme-editor marker missing: ' + $marker) }
}

$validationService = Get-Content -LiteralPath (Join-Path $App 'Modules\AIIO\AIIO.ValidationService.ps1') -Raw -Encoding UTF8
foreach ($marker in @('function Get-PMMBuildIdentitySha256','Get-PMMBuildIdentitySha256 ($parts -join','^[0-9a-f]{64}$')) {
  if ($validationService -notmatch [regex]::Escape($marker)) { Fail ('RC28 build-validation marker missing: ' + $marker) }
}
$buildIdBody = [regex]::Match($validationService,'(?s)function Get-PMMDeterministicBuildId\b.*?(?=\r?\nfunction Get-PMMBuildValidationSummaryPath\b)').Value
if ($buildIdBody -match [regex]::Escape('Get-PMMStableTextId')) { Fail 'RC28 deterministic build ID still uses the truncated stable-text identifier.' }
$sessionService = Get-Content -LiteralPath (Join-Path $App 'Modules\AIIO\AIIO.SessionService.ps1') -Raw -Encoding UTF8
foreach ($marker in @('ConvertTo-PMMAIIOUtcTimestamp',"Properties.Name -contains 'SourceMods'","Kind='SourceMod'","Kind='CompatibilityPatch'","Properties.Name -contains 'Deployed'")) {
  if ($sessionService -notmatch [regex]::Escape($marker)) { Fail ('RC28 schema-3 deployment marker missing: ' + $marker) }
}
$candidateBody = [regex]::Match($bootstrap,'(?s)function Refresh-PMMAIIOCandidates\b.*?(?=\r?\nfunction Update-PMMAIIOCandidateSelection\b)').Value
if ($candidateBody -notmatch [regex]::Escape('$rows=@()') -or $candidateBody -match '\$rows\s*=\s*if\s*\(') { Fail 'RC28 candidate collection can still be unwrapped by Windows PowerShell.' }

foreach ($marker in @('Complete-PMMAIIOPrepareUi','Complete-PMMAIIOImportResponseUi','Complete-PMMAIIOPendingDataUi','Complete-PMMAIIOUseCandidateUi','Repair-PMMDuplicateDiagnosticSessions','Register-PMMAutomaticErrorCase','PMM_USER_FEEDBACK_V1','Flow:PlayReady')) {
  if (($bootstrap + $validationService) -notmatch [regex]::Escape($marker)) { Fail ('RC29 callback/feedback/UI marker missing: ' + $marker) }
}
if ($bootstrap -match [regex]::Escape('$Script:LstAIIOSessions.SelectedValue') -or $bootstrap -match [regex]::Escape('$Script:LstAIHelpDiagnostics.SelectedValue')) { Fail 'RC29 AIIO ListBox selection still uses SelectedValue.' }
$badgeBody = [regex]::Match($bootstrap,'(?s)function Refresh-PMMAIHelpBadge\b.*?(?=\r?\nfunction Refresh-PMMAIHelpKnowledge\b)').Value
if ($badgeBody -match [regex]::Escape("'WaitingForAI'") -or $badgeBody -notmatch 'Unsupported' -or $badgeBody -notmatch 'AttentionEligible') { Fail 'RC30 main AI & Help badge semantics mismatch.' }
$dialogBody = [regex]::Match($bootstrap,'(?s)function Show-PMMBuildValidationDialog\b.*?(?=\r?\n# Action-required hint duration:)').Value
if ($dialogBody -notmatch [regex]::Escape('$buttonWidth=230') -or $dialogBody -notmatch [regex]::Escape('$button.Height=76')) { Fail 'RC30 validation buttons are not enlarged.' }
if ($bootstrap -notmatch [regex]::Escape('TotalSeconds -lt 60')) { Fail 'RC30 external-mod activation/timer checks do not share the 60-second throttle.' }
$diagnosticService = Get-Content -LiteralPath (Join-Path $App 'Modules\AIIO\AIIO.DiagnosticService.ps1') -Raw -Encoding UTF8
foreach ($marker in @('function Register-PMMAutomaticErrorCase','function Resolve-PMMKnownLegacyUiDiagnostics','OccurrenceCount','ResolvedByUpgrade')) {
  if ($diagnosticService -notmatch [regex]::Escape($marker)) { Fail ('RC29 diagnostic marker missing: ' + $marker) }
}

$knowledgeService = Get-Content -LiteralPath (Join-Path $App 'Modules\CKL\KnowledgeRecipeService.ps1') -Raw -Encoding UTF8
foreach ($marker in @('Get-PMMDataTableCompatibilityResolution','requireExactConflictProviders','Get-PMMConflictCanonicalValue')) {
  if ($knowledgeService -notmatch [regex]::Escape($marker)) { Fail ('RC26 semantic-rule marker missing: ' + $marker) }
}
$productionRecipes = Get-Content -LiteralPath (Join-Path $App 'CKL\Stable\production-recipes.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$semanticRecipes = @($productionRecipes.recipes | Where-Object { $_.semanticFallback.enabled })
if ($semanticRecipes.Count -ne 1 -or [string]$semanticRecipes[0].semanticFallback.conflicts[0].path -ne 'Rows[Boar].WorkSuitability_MonsterFarm' -or [string]$semanticRecipes[0].semanticFallback.conflicts[0].selectProvider -ne 'FasterMounts4xAllWorkSuitabilitiesLevel10_P.pak') { Fail 'RC26 FasterMounts/RushRoar exact semantic rule is missing or changed.' }
else { Pass 'RC26 exact FasterMounts/RushRoar semantic rule' }

$packageRules = Get-Content -LiteralPath (Join-Path $App 'CKL\Stable\package-rules.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$guraRule = @($packageRules.rules|Where-Object id -eq 'pmm-fixlab-gawr-gura-case-001-variants-v1')
if ($guraRule.Count -ne 1 -or [string]$guraRule[0].trigger -ne 'anyTwoActive' -or @($guraRule[0].members).Count -ne 5 -or @($guraRule[0].choices).Count -ne 5) { Fail 'Gura package-choice rule is incomplete.' }
else { Pass 'Gura any-two-active preflight rule' }

foreach ($script in @(Get-ChildItem -LiteralPath (Join-Path $App 'Modules') -Recurse -File -Filter '*.ps1')) {
  $tokens = $null
  $parseErrors = $null
  $null = [System.Management.Automation.Language.Parser]::ParseFile($script.FullName,[ref]$tokens,[ref]$parseErrors)
  if (@($parseErrors).Count) { Fail ('PowerShell parse errors in ' + $script.FullName + ': ' + ((@($parseErrors).Message) -join ' | ')) }
}
Pass 'Active PowerShell modules parsed'

try {
  $singletonOutput = @(& (Join-Path $Root 'Development\Tests\rc23_singleton_collection_regression.ps1') -Root $Root)
  if ($singletonOutput -contains 'RC23_SINGLETON_COLLECTION_REGRESSION_OK') { Pass 'RC23 Windows PowerShell singleton collection regression' }
  else { Fail ('RC23 singleton collection regression returned unexpected output: ' + ($singletonOutput -join ' | ')) }
} catch { Fail ('RC23 singleton collection regression failed: ' + $_.Exception.Message) }

try {
  $ownershipOutput = @(& (Join-Path $Root 'Development\Tests\rc24_ui_fixlab_ownership_regression.ps1') -Root $Root)
  if ($ownershipOutput -contains 'RC24_UI_FIXLAB_OWNERSHIP_REGRESSION_OK') { Pass 'RC24 Windows PowerShell UI/Fix Lab ownership regression' }
  else { Fail ('RC24 UI/Fix Lab ownership regression returned unexpected output: ' + ($ownershipOutput -join ' | ')) }
} catch { Fail ('RC24 UI/Fix Lab ownership regression failed: ' + $_.Exception.Message) }

try {
  $semanticOutput = @(& (Join-Path $Root 'Development\Tests\rc26_semantic_compatibility_regression.ps1') -Root $Root)
  if ($semanticOutput -contains 'RC26_SEMANTIC_COMPATIBILITY_REGRESSION_OK') { Pass 'RC26 Windows PowerShell exact semantic-compatibility regression' }
  else { Fail ('RC26 semantic-compatibility regression returned unexpected output: ' + ($semanticOutput -join ' | ')) }
} catch { Fail ('RC26 semantic-compatibility regression failed: ' + $_.Exception.Message) }

try {
  $runtimeOutput = @(& (Join-Path $Root 'Development\Tests\rc28_validation_runtime_regression.ps1') -Root $Root)
  if ($runtimeOutput -contains 'RC28_VALIDATION_RUNTIME_REGRESSION_OK') { Pass 'RC28 Windows PowerShell validation/runtime regression' }
  else { Fail ('RC28 validation/runtime regression returned unexpected output: ' + ($runtimeOutput -join ' | ')) }
} catch { Fail ('RC28 validation/runtime regression failed: ' + $_.Exception.Message) }

try {
  $rc30Output = @(& (Join-Path $Root 'Development\Tests\rc30_lean_ai_validation_regression.ps1') -Root $Root)
  if ($rc30Output -contains 'RC30_LEAN_AI_VALIDATION_REGRESSION_OK') { Pass 'RC30 Windows PowerShell lean AI/validation regression' }
  else { Fail ('RC30 lean AI/validation regression returned unexpected output: ' + ($rc30Output -join ' | ')) }
} catch { Fail ('RC30 lean AI/validation regression failed: ' + $_.Exception.Message) }

$index = Get-Content -LiteralPath (Join-Path $App 'CKL\Catalog\case-index.json') -Raw -Encoding UTF8 | ConvertFrom-Json
if ([string]$index.schema -ne 'PMM_CKL_CASE_INDEX_V1') { Fail 'Bad CKL index schema.' }
if (@($index.entries).Count -lt 12) { Fail 'CKL index unexpectedly incomplete.' }
else { Pass ('CKL indexed entries: ' + @($index.entries).Count) }

$sumPath = Join-Path $App 'Resources\Metadata\SHA256SUMS.txt'
$expected = @{}
foreach ($line in @(Get-Content -LiteralPath $sumPath -Encoding UTF8)) {
  if ([string]::IsNullOrWhiteSpace($line)) { continue }
  if ($line -notmatch '^([a-f0-9]{64})  (.+)$') { Fail ('Invalid SHA256SUMS line: ' + $line); continue }
  $expected[$Matches[2]] = $Matches[1]
}
$actualFiles = @(Get-ChildItem -LiteralPath $App -Recurse -File | Where-Object FullName -ne $sumPath)
foreach ($file in $actualFiles) {
  $relative = $file.FullName.Substring($App.Length + 1).Replace('\','/')
  if (-not $expected.ContainsKey($relative)) { Fail ('SHA256SUMS missing: ' + $relative); continue }
  $actual = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
  if ($actual -cne [string]$expected[$relative]) { Fail ('SHA-256 mismatch: ' + $relative) }
}
foreach ($relative in @($expected.Keys)) {
  if (-not (Test-Path -LiteralPath (Join-Path $App $relative) -PathType Leaf)) { Fail ('SHA256SUMS references missing file: ' + $relative) }
}
if ($expected.Count -ne $actualFiles.Count) { Fail ('SHA256SUMS count mismatch: expected=' + $expected.Count + ' files=' + $actualFiles.Count) }
else { Pass ('SHA256SUMS verified: ' + $expected.Count + ' files') }

if ($Failures.Count) {
  Write-Output ('PMM_V131_MOD_CREATION_REPOSITORY_VALIDATION_FAILED count=' + $Failures.Count)
  exit 1
}
Write-Output 'PMM_V131_MOD_CREATION_REPOSITORY_VALIDATION_OK'
Write-Output 'LAYOUT=PASS'
Write-Output 'JSON_XAML_POWERSHELL=PASS'
Write-Output 'HASH_MANIFEST=PASS'
exit 0
