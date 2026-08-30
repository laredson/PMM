param([string]$Root=([IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))))

Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$Root=[IO.Path]::GetFullPath($Root)
$App=Join-Path $Root 'PMM'

. (Join-Path $App 'Modules\Library\LibraryService.ps1')
. (Join-Path $App 'Modules\CKL\KnowledgeRecipeService.ps1')
. (Join-Path $App 'Modules\Merge\MergeEngine.ps1')

function Assert-RC26([bool]$Condition,[string]$Message){if(-not$Condition){throw $Message}}
function Write-PMMLog([string]$Message){}

$asset='Pal/Content/Pal/DataTable/Character/DT_PalMonsterParameter_Common.uasset'
$property='Rows[Boar].WorkSuitability_MonsterFarm'
$faster='FasterMounts4xAllWorkSuitabilitiesLevel10_P.pak'
$rush='RushRoarLeatherDrop_v2_P.pak'

$Script:RC26RecipeDocument=[pscustomobject]@{
  recipes=@([pscustomobject]@{
    id='rushroar-v2-fastermounts-palmonsterparameter-20260817'
    asset=$asset
    production=[pscustomobject]@{enabled=$true}
    semanticFallback=[pscustomobject]@{
      enabled=$true
      class='datatable-proven-dominance'
      conflicts=@([pscustomobject]@{
        id='rushroar-ranch-level-satisfied-by-fastermounts'
        path=$property
        requireExactConflictProviders=$true
        providers=@(
          [pscustomobject]@{name=$faster;canonicalValue='10'},
          [pscustomobject]@{name=$rush;canonicalValue='1'}
        )
        selectProvider=$faster
        semanticReason='Exact RC26 regression fixture.'
        runtime='proven-test'
      })
    }
  })
}
function Get-PMMProductionRecipeDocument{return $Script:RC26RecipeDocument}

$providers=@(
  [pscustomobject]@{Mod=[pscustomobject]@{Name=$faster;Hash='FASTER'}},
  [pscustomobject]@{Mod=[pscustomobject]@{Name=$rush;Hash='RUSH'}}
)
$group=[pscustomobject]@{Key=$asset.ToLowerInvariant();Asset=$asset;Providers=@($faster,$rush);Kind='AssetFamily'}

function New-Conflict([string]$Path=$property,[string]$FasterValue='10',[string]$RushValue='1',[switch]$Third){
  $values=[ordered]@{
    $faster=[pscustomobject]@{Kind='IntProperty';Value=[int]$FasterValue;Canonical=$FasterValue}
    $rush=[pscustomobject]@{Kind='IntProperty';Value=[int]$RushValue;Canonical=$RushValue}
  }
  if($Third){$values['ThirdProvider.pak']=[pscustomobject]@{Kind='IntProperty';Value=1;Canonical='1'}}
  return [pscustomobject]@{
    Path=$Path
    Vanilla=[pscustomobject]@{Kind='IntProperty';Value=0;Canonical='0'}
    Providers=[pscustomobject]$values
  }
}

$exact=New-Conflict
$resolution=Get-PMMDataTableCompatibilityResolution $group $exact $providers
Assert-RC26 ($null -ne $resolution) 'Exact 10/1 fixture was not resolved.'
Assert-RC26 ([string]$resolution.SelectedChoice -ceq $faster) 'Exact fixture did not select FasterMounts.'

$analysis=New-PMMDataTableConflictAnalysis $group $providers $null ([pscustomobject]@{Report=[pscustomobject]@{conflicts=@($exact);patches=@()}}) @{} ''
Assert-RC26 ([string]$analysis.Asset.Mode -ceq 'DataTableAuto') 'Resolved fixture did not become DataTableAuto.'
Assert-RC26 (@($analysis.Rows).Count -eq 0) 'Resolved fixture still exposed a user decision.'
Assert-RC26 (@($analysis.Asset.AutomaticResolutions).Count -eq 1) 'Resolved fixture did not preserve one automatic-resolution proof.'
Assert-RC26 ([string](Get-PMMResolutionToken $analysis.Asset.AutomaticResolutions[0]) -ceq $faster) 'Automatic build token does not select FasterMounts.'

Assert-RC26 ($null -eq (Get-PMMDataTableCompatibilityResolution $group (New-Conflict -Path ($property+'_Other')) $providers)) 'Different path was resolved unexpectedly.'
Assert-RC26 ($null -eq (Get-PMMDataTableCompatibilityResolution $group (New-Conflict -FasterValue '9') $providers)) '9/1 values were resolved unexpectedly.'
Assert-RC26 ($null -eq (Get-PMMDataTableCompatibilityResolution $group (New-Conflict -RushValue '2') $providers)) '10/2 values were resolved unexpectedly.'
Assert-RC26 ($null -eq (Get-PMMDataTableCompatibilityResolution $group (New-Conflict -Third) $providers)) 'Additional competing provider was resolved unexpectedly.'

$stored=[pscustomobject]@{AutomaticResolutions=@($analysis.Asset.AutomaticResolutions[0])}
$reversed=[pscustomobject]@{AutomaticResolutions=@([pscustomobject]@{
  RuleId=$analysis.Asset.AutomaticResolutions[0].RuleId
  RecipeId=$analysis.Asset.AutomaticResolutions[0].RecipeId
  Property=$analysis.Asset.AutomaticResolutions[0].Property
  SelectedChoice=$analysis.Asset.AutomaticResolutions[0].SelectedChoice
  ExpectedProviders=@($analysis.Asset.AutomaticResolutions[0].ExpectedProviders[1],$analysis.Asset.AutomaticResolutions[0].ExpectedProviders[0])
})}
Assert-RC26 ((Get-PMMAutomaticResolutionSignature $stored) -ceq (Get-PMMAutomaticResolutionSignature $reversed)) 'Automatic-resolution signature depends on provider serialization order.'
Assert-RC26 ((Get-PMMPlanSchemaVersion) -eq 18) 'RC26 Analyze plan schema is not 18.'

Write-Output 'RC26_SEMANTIC_COMPATIBILITY_REGRESSION_OK'
