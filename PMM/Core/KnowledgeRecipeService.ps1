<#
Palworld Manager Merger v1.1 - runtime-proven production recipes
================================================================

Knowledge remains explanatory by default. This service is the narrow exception for
promoting a completed AI_HANDOFF/manual solution into production behavior:

- the recipe must be explicitly marked production-enabled and runtime-proven;
- target asset, engine profile and mappings hash must match;
- the complete provider PAK hash set must match exactly;
- Vanilla and every provider cooked-family part must match pinned SHA-256 + size;
- the output is not synthesized from comments or intent: PMM reuses one already
  present provider cooked family whose exact bytes were runtime-proven as the
  solution for that exact fixture.

No cooked game/mod files are distributed in Knowledge. Recipes contain hashes and
proof metadata only. A changed mod/game version falls back to normal adapters or
Unsupported/AI_HANDOFF.
#>

function Get-PMMProductionRecipeDocument {
  $path=Join-Path $Script:Root 'Knowledge\production-recipes.json'
  if(-not(Test-Path -LiteralPath $path -PathType Leaf)){return $null}
  try{return (Get-Content -LiteralPath $path -Raw|ConvertFrom-Json)}catch{
    Write-PMMLog ('Production recipe library could not be read: '+$_.Exception.Message)
    return $null
  }
}

function Get-PMMProductionRecipeCount {
  $doc=Get-PMMProductionRecipeDocument
  if(-not$doc){return 0}
  return @($doc.recipes|Where-Object{
    $_ -and ($_.PSObject.Properties.Name -contains 'production') -and $_.production -and
    ($_.production.PSObject.Properties.Name -contains 'enabled') -and [bool]$_.production.enabled
  }).Count
}

function Test-PMMRecipeFamilyExact($Family,$ExpectedFamily,[ref]$FailureReason) {
  foreach($partName in @('uasset','uexp','ubulk')){
    $ext='.'+$partName
    $path=[IO.Path]::ChangeExtension([string]$Family.HeaderPath,$ext)
    $exists=Test-Path -LiteralPath $path -PathType Leaf
    $hasExpected=$false
    if($ExpectedFamily -and ($ExpectedFamily.PSObject.Properties.Name -contains $partName)){$hasExpected=$true}
    if($exists -ne $hasExpected){
      $FailureReason.Value=("family topology mismatch for {0}" -f $ext)
      return $false
    }
    if(-not$exists){continue}
    $expected=$ExpectedFamily.$partName
    if(-not$expected){$FailureReason.Value=("missing expected metadata for {0}" -f $ext);return $false}
    if($expected.PSObject.Properties.Name -contains 'size'){
      if([int64]$expected.size -ne [int64](Get-Item -LiteralPath $path).Length){
        $FailureReason.Value=("size mismatch for {0}" -f $ext)
        return $false
      }
    }
    if(-not($expected.PSObject.Properties.Name -contains 'sha256')){
      $FailureReason.Value=("missing expected SHA-256 for {0}" -f $ext)
      return $false
    }
    if(([string]$expected.sha256).ToLowerInvariant() -ne (Get-Sha256 $path)){
      $FailureReason.Value=("SHA-256 mismatch for {0}" -f $ext)
      return $false
    }
  }
  return $true
}

function Get-PMMProductionRecipeMatch($Group,$Vanilla,[array]$ProviderRecords) {
  if(-not$Group -or -not$Vanilla -or @($ProviderRecords).Count -lt 2){return $null}
  $doc=Get-PMMProductionRecipeDocument
  if(-not$doc){return $null}

  $asset=[string]$Group.Asset
  $mappings=Join-Path $Script:Root 'Mappings\Mappings.usmap'
  if(-not(Test-Path -LiteralPath $mappings -PathType Leaf)){return $null}
  $mappingHash=Get-Sha256 $mappings
  $actualProviderHashes=@($ProviderRecords|ForEach-Object{([string]$_.Mod.Hash).ToLowerInvariant()}|Sort-Object)

  foreach($recipe in @($doc.recipes)){
    if(-not$recipe){continue}
    if(-not($recipe.PSObject.Properties.Name -contains 'production') -or -not$recipe.production -or -not [bool]$recipe.production.enabled){continue}
    if([string]$recipe.asset -ne $asset){continue}
    if([string]$recipe.engineProfile -ne 'UE5_1'){continue}
    if(([string]$recipe.mappingsSha256).ToLowerInvariant() -ne $mappingHash){continue}
    $runtimeStatus=''
    if($recipe.PSObject.Properties.Name -contains 'status' -and $recipe.status -and ($recipe.status.PSObject.Properties.Name -contains 'runtime')){$runtimeStatus=[string]$recipe.status.runtime}
    if($runtimeStatus -notmatch '(?i)^proven'){continue}

    $expectedProviders=@($recipe.providers)
    $expectedHashes=@($expectedProviders|ForEach-Object{([string]$_.pakSha256).ToLowerInvariant()}|Sort-Object)
    if($expectedHashes.Count -ne $actualProviderHashes.Count){continue}
    $sameSet=$true
    for($i=0;$i -lt $expectedHashes.Count;$i++){
      if($expectedHashes[$i] -ne $actualProviderHashes[$i]){$sameSet=$false;break}
    }
    if(-not$sameSet){continue}

    $why=''
    if(-not(Test-PMMRecipeFamilyExact $Vanilla $recipe.vanilla ([ref]$why))){
      Write-PMMLog ("Production recipe {0} skipped: Vanilla {1}" -f [string]$recipe.id,$why)
      continue
    }

    $recordsByHash=@{}
    foreach($record in @($ProviderRecords)){$recordsByHash[([string]$record.Mod.Hash).ToLowerInvariant()]=$record}
    $allProviderFamiliesMatch=$true
    foreach($expectedProvider in $expectedProviders){
      $hash=([string]$expectedProvider.pakSha256).ToLowerInvariant()
      if(-not$recordsByHash.ContainsKey($hash)){$allProviderFamiliesMatch=$false;break}
      $why=''
      if(-not(Test-PMMRecipeFamilyExact $recordsByHash[$hash].Export $expectedProvider.family ([ref]$why))){
        Write-PMMLog ("Production recipe {0} skipped: provider {1}: {2}" -f [string]$recipe.id,[string]$expectedProvider.name,$why)
        $allProviderFamiliesMatch=$false
        break
      }
    }
    if(-not$allProviderFamiliesMatch){continue}

    if(-not($recipe.PSObject.Properties.Name -contains 'output') -or -not$recipe.output){continue}
    if([string]$recipe.output.mode -ne 'reuse-provider-family'){continue}
    $outputHash=([string]$recipe.output.providerPakSha256).ToLowerInvariant()
    if(-not$recordsByHash.ContainsKey($outputHash)){continue}
    $outputRecord=$recordsByHash[$outputHash]
    $why=''
    if(-not(Test-PMMRecipeFamilyExact $outputRecord.Export $recipe.output.family ([ref]$why))){
      Write-PMMLog ("Production recipe {0} skipped: output provider no longer matches: {1}" -f [string]$recipe.id,$why)
      continue
    }

    return [pscustomobject]@{
      Recipe=$recipe
      OutputRecord=$outputRecord
      RecipeId=[string]$recipe.id
      CaseId=[string]$recipe.caseId
      OutputProvider=[string]$outputRecord.Mod.Name
      RuntimeStatus=$runtimeStatus
    }
  }
  return $null
}
