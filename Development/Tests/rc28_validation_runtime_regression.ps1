param([string]$Root=([IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))))

Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$Root=[IO.Path]::GetFullPath($Root)
$App=Join-Path $Root 'PMM'

function Assert-RC28([bool]$Condition,[string]$Message){if(-not$Condition){throw ('RC28 regression failed: '+$Message)}}

. (Join-Path $App 'Modules\AIIO\AIIO.ValidationService.ps1')

$manifest=[pscustomobject]@{
  Sources=@(
    [pscustomobject]@{Name='ModA_P.pak';Hash=('b'*64);Priority=2},
    [pscustomobject]@{Name='ModB_P.pak';Hash=('c'*64);Priority=1}
  )
  SourceMods=@();PatchedMods=@();IncludedSolutions=@();ExperimentalManualSolutions=@()
  Assets=@([pscustomobject]@{RecipeId='recipe-one';RecipeCaseId='case-one';Asset='Pal/Content/Data/Test.uasset'})
  SourceSignature='source-signature';MergeOrderSignature='merge-order';EffectiveMergeOrderSignature='EFFECTIVE_ORDER_V2:ORDER-INDEPENDENT'
  DecisionSignature='decision-signature';MappingsSha256=('d'*64);VanillaSourceSignature='vanilla-signature';Engine='PMMCore-v0.9.0'
}
$patch=[pscustomobject]@{Hash=('a'*64);Manifest=$manifest;ManifestPath=''}
$first=Get-PMMDeterministicBuildId $patch
$second=Get-PMMDeterministicBuildId $patch
Assert-RC28 ($first -cmatch '^[0-9a-f]{64}$') 'Build ID must be a complete lowercase SHA-256.'
Assert-RC28 ($first -ceq 'f9384ae08e215151e8d8b885239f2c6190fdb0bfce2e4467983eef67ef26776c') 'Build ID fixture mismatch.'
Assert-RC28 ($first -ceq $second) 'Build ID is not deterministic.'

. (Join-Path $App 'Modules\AIIO\AIIO.SessionService.ps1')
$fixtureRoot=Join-Path ([IO.Path]::GetTempPath()) ('PMM-RC28-'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force -Path (Join-Path $fixtureRoot 'State')|Out-Null
function Join-PMMPath([string]$Category,[string]$Child=''){
  $path=Join-Path $fixtureRoot $Category
  if($Child){$path=Join-Path $path $Child}
  return $path
}
try{
  $state=[ordered]@{
    SchemaVersion=3;Deployed='2026-08-30T14:32:14Z';SourceSignature='fixture'
    SourceMods=@(
      [pscustomobject]@{Name='Enabled_P.pak';Hash=('1'*64);Deployed=$true},
      [pscustomobject]@{Name='Suppressed_P.pak';Hash=('2'*64);Deployed=$false}
    )
    SuppressedAlternatives=@('Suppressed_P.pak')
    Patch=[pscustomobject]@{Name='zzzzzzzzzz_PMM_Merge_Test_P.pak';Hash=('3'*64)}
  }
  $state|ConvertTo-Json -Depth 10|Set-Content -LiteralPath (Join-Path $fixtureRoot 'State\deployment-state.json') -Encoding UTF8
  $snapshot=Get-PMMAIIOCurrentDeploymentSnapshot
  Assert-RC28 ([bool]$snapshot.Present) 'Schema-3 deployment was not recognized.'
  Assert-RC28 ([string]$snapshot.UpdatedUtc -ceq [string]$state.Deployed) 'Schema-3 Deployed timestamp was not normalized.'
  Assert-RC28 ([string]$snapshot.SelectedPatch -ceq [string]$state.Patch.Name) 'Schema-3 patch selection was not normalized.'
  Assert-RC28 (@($snapshot.ManagedFiles).Count -eq 2) 'Schema-3 snapshot must contain one deployed source and one patch.'
  Assert-RC28 (@($snapshot.ManagedFiles|Where-Object{[string]$_.Kind -eq 'SourceMod'}).Count -eq 1) 'Deployed source-mod normalization failed.'
  Assert-RC28 (@($snapshot.ManagedFiles|Where-Object{[string]$_.Kind -eq 'CompatibilityPatch'}).Count -eq 1) 'Compatibility-patch normalization failed.'

  $legacy=[ordered]@{UpdatedUtc='2026-08-30T15:00:00Z';SelectedPatch='legacy.pak';ManagedFiles=@([pscustomobject]@{Path='C:\fixture\legacy.pak';Sha256=('4'*64);Kind='CompatibilityPatch'})}
  $legacy|ConvertTo-Json -Depth 10|Set-Content -LiteralPath (Join-Path $fixtureRoot 'State\deployment-state.json') -Encoding UTF8
  $legacySnapshot=Get-PMMAIIOCurrentDeploymentSnapshot
  Assert-RC28 (@($legacySnapshot.ManagedFiles).Count -eq 1) 'Legacy singleton ManagedFiles was not preserved as an array.'
  Assert-RC28 ([string]$legacySnapshot.ManagedFiles[0].Name -ceq 'legacy.pak') 'Legacy managed path was not reduced to a safe filename.'
}finally{Remove-Item -LiteralPath $fixtureRoot -Recurse -Force -ErrorAction SilentlyContinue}

$bootstrap=Get-Content -LiteralPath (Join-Path $App 'Modules\Bootstrap\Start-PalModMerger.ps1') -Raw -Encoding UTF8
$candidateBody=[regex]::Match($bootstrap,'(?s)function Refresh-PMMAIIOCandidates\b.*?(?=\r?\nfunction Update-PMMAIIOCandidateSelection\b)').Value
Assert-RC28 ($candidateBody -match [regex]::Escape('$rows=@()')) 'Candidate refresh does not initialize an actual array.'
Assert-RC28 ($candidateBody -notmatch '\$rows\s*=\s*if\s*\(') 'Candidate refresh still assigns a collection through an unwrapping if expression.'
$dialogBody=[regex]::Match($bootstrap,'(?s)function Show-PMMBuildValidationDialog\b.*?(?=\r?\n# Action-required hint duration:)').Value
Assert-RC28 ($dialogBody -match [regex]::Escape('$choices=@()')) 'Validation dialog choices do not initialize an actual array.'
Assert-RC28 ($dialogBody -match [regex]::Escape("[pscustomobject]@{Result='PASS';Label=")) 'Validation dialog choices are not structured records.'
Assert-RC28 ($dialogBody -notmatch '\$choices\s*=\s*if\s*\(') 'Validation dialog choices still use an unwrapping if expression.'

Write-Output 'RC28_VALIDATION_RUNTIME_REGRESSION_OK'
