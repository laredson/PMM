param([string]$Root=([IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))))

Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$Root=[IO.Path]::GetFullPath($Root)
$App=Join-Path $Root 'PMM'

. (Join-Path $App 'Modules\Library\LibraryService.ps1')
. (Join-Path $App 'Modules\Merge\MergeEngine.ps1')

$Script:TempMapping=[IO.Path]::GetTempFileName()
try{
  function Get-PMMEngineId {'TEST-ENGINE'}
  function Get-PMMVanillaPakSetQuickSignature {'TEST-VANILLA'}
  function Get-PMMMappingsPath {$Script:TempMapping}
  function Get-Sha256([string]$Path) {'TEST-MAPPINGS'}
  function Get-PMMProductionRecipeLibrarySha256 {'TEST-RECIPES'}
  function Test-PMMPatchEffectiveOrderCompatible($Patch,[array]$SourceMods){$true}
  # PMM loads Common.ps1 before LibraryService/MergeEngine.  This isolated
  # regression must provide the same localization dependency explicitly.
  function Get-PMMText([string]$English,[string]$Spanish){return $English}

  # This mirrors the user's RC22 build: exactly one KnownRecipeAuto asset. In
  # Windows PowerShell 5.1, arrays emitted from an if branch are unrolled. The
  # old code therefore exposed a PSCustomObject to `.Count` under StrictMode.
  $recipeAsset=[pscustomobject]@{
    AssetKey='pal/content/test/single.uasset'
    Asset='Pal/Content/Test/Single.uasset'
    Mode='KnownRecipeAuto'
    Providers=@('Provider.pak')
    RecipeId='test-recipe'
    RecipeOutputProvider='Provider.pak'
  }
  $patch=[pscustomobject]@{
    Name='singleton-test.pak'
    Hash='PATCH-HASH'
    ManifestHashOk=$true
    Manifest=[pscustomobject]@{
      Engine='TEST-ENGINE'
      VanillaSourceSignature='TEST-VANILLA'
      MappingsSha256='TEST-MAPPINGS'
      ProductionRecipesSha256='TEST-RECIPES'
      Assets=@($recipeAsset)
      Decisions=@()
      Sources=@([pscustomobject]@{Name='Provider.pak';Hash='PROVIDER-HASH';Priority=1})
      AnalyzedSharedAssets=@($recipeAsset)
    }
  }
  $mod=[pscustomobject]@{Name='Provider.pak';Hash='PROVIDER-HASH';Size=1;Priority=1}

  if(-not(Test-PMMPatchRuntimeCompatible $patch @($mod))){throw 'Singleton KnownRecipe runtime proof was unexpectedly rejected.'}

  $Script:SingletonPatch=$patch
  function Get-PMMOrderedManagedPatchCandidates {return @($Script:SingletonPatch)}
  function Test-PMMPatchRuntimeCompatible($Patch,[array]$SourceMods){return $true}
  function Get-PMMLibrarySignature([array]$Mods){return 'TEST-SOURCES'}
  function Get-PMMMergeOrderSignature([array]$Mods){return 'TEST-ORDER'}
  function Get-PMMEffectivePatchOrderSignature([array]$Assets,[array]$Mods,[array]$Decisions){return 'EFFECTIVE_ORDER_V2:ORDER-INDEPENDENT'}
  function Test-PMMPatchPlanCompatible($Patch,$Plan,[array]$SourceMods){return $true}
  function Set-PMMPlanEquivalentPatch($Plan,$Patch,[array]$Mods){return $Plan}

  $group=[pscustomobject]@{Key=$recipeAsset.AssetKey;Asset=$recipeAsset.Asset;Providers=@('Provider.pak')}
  $reuse=Get-PMMFastPatchReuseCandidate @($mod) @($mod) @($group)
  if(-not$reuse){throw 'Singleton fast-reuse proof returned no candidate.'}
  if(@($reuse.Plan.Assets).Count -ne 1){throw 'Singleton fast-reuse proof did not retain exactly one asset.'}

  Write-Output 'RC23_SINGLETON_COLLECTION_REGRESSION_OK'
}finally{
  Remove-Item -LiteralPath $Script:TempMapping -Force -ErrorAction SilentlyContinue
}
