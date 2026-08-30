<#
Palworld Manager Merger v1.3.0 - runtime-proven CKL production recipes
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
Unsupported/AI_HANDOFF unless a separately declared runtime-proven semantic rule
matches the exact current asset path, conflicting providers and canonical values.
That rule still uses the normal current-family adapter and never reuses stale bytes.
#>


$Script:PMMCKLIndexCache=$null
$Script:PMMProductionRecipeCache=$null
$Script:PMMProductionRecipeCacheIdentity=''

function Get-PMMCKLCaseIndexDocument {
  if($Script:PMMCKLIndexCache){return $Script:PMMCKLIndexCache}
  $path=Join-PMMPath 'CKLCatalog' 'case-index.json'
  if(-not(Test-Path -LiteralPath $path -PathType Leaf)){return $null}
  try{
    $doc=Get-Content -LiteralPath $path -Raw|ConvertFrom-Json
    if([string]$doc.schema -ne 'PMM_CKL_CASE_INDEX_V1'){throw 'unexpected CKL index schema'}
    foreach($source in @($doc.sourceFiles)){
      $sourcePath=Join-PMMPath 'CKL' ([string]$source.path).Replace('/',[IO.Path]::DirectorySeparatorChar)
      if(-not(Test-Path -LiteralPath $sourcePath -PathType Leaf)){throw ('CKL catalog source is missing: '+[string]$source.path)}
      if((Get-Sha256 $sourcePath) -ne ([string]$source.sha256).ToLowerInvariant()){throw ('CKL catalog is stale for '+[string]$source.path+'. Rebuild/install the matching CKL catalog before Analyze.')}
    }
    $Script:PMMCKLIndexCache=$doc
    return $doc
  }catch{
    Write-PMMLog ('CKL case index could not be read: '+$_.Exception.Message)
    return $null
  }
}

function Find-PMMCKLCaseCandidates($Group,[array]$ProviderRecords) {
  $doc=Get-PMMCKLCaseIndexDocument
  if(-not$doc -or -not$Group){return @()}
  $asset=[string]$Group.Asset
  $names=[System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
  $hashes=[System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
  foreach($record in @($ProviderRecords)){
    if($record -and $record.Mod){[void]$names.Add([string]$record.Mod.Name);if($record.Mod.Hash){[void]$hashes.Add([string]$record.Mod.Hash)}}
  }
  $result=[System.Collections.Generic.List[object]]::new()
  foreach($entry in @($doc.entries)){
    if([string]$entry.asset -ne $asset){continue}
    $matched=$false
    foreach($provider in @($entry.providers)){
      if(-not$names.Contains([string]$provider.name)){continue}
      $pin=[string]$provider.pakSha256
      if([string]::IsNullOrWhiteSpace($pin) -or $hashes.Contains($pin)){$matched=$true;break}
    }
    if($matched){$result.Add($entry)}
  }
  return $result.ToArray()
}

function Get-PMMCKLContextForPlanItem($Item) {
  if(-not$Item){return @()}
  $doc=Get-PMMCKLCaseIndexDocument;if(-not$doc){return @()}
  $asset=[string]$Item.Asset
  $names=[System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
  $hashByName=@{}
  foreach($n in @($Item.Providers)){if(-not[string]::IsNullOrWhiteSpace([string]$n)){[void]$names.Add([string]$n)}}
  # Review/AIIO plan items carry the exact case manifest. Prefer its provider
  # PAK hashes so an exact historical fixture can be distinguished from a mod
  # with the same filename but different bytes/version.
  if(($Item.PSObject.Properties.Name -contains 'Case') -and $Item.Case -and ($Item.Case.PSObject.Properties.Name -contains 'Providers')){
    foreach($p in @($Item.Case.Providers)){
      $name=[string]$p.Name;if([string]::IsNullOrWhiteSpace($name)){continue}
      [void]$names.Add($name)
      if(-not[string]::IsNullOrWhiteSpace([string]$p.PakSha256)){$hashByName[$name]=([string]$p.PakSha256).ToLowerInvariant()}
    }
  }
  $result=[System.Collections.Generic.List[object]]::new()
  foreach($entry in @($doc.entries)){
    if([string]$entry.asset -ne $asset){continue}
    $shared=0;$pinned=0;$pinsMatched=0;$pinMismatch=$false
    foreach($provider in @($entry.providers)){
      $name=[string]$provider.name
      if(-not$names.Contains($name)){continue}
      $shared++
      $pin=([string]$provider.pakSha256).ToLowerInvariant()
      if(-not[string]::IsNullOrWhiteSpace($pin)){
        $pinned++
        if($hashByName.ContainsKey($name)){
          if(([string]$hashByName[$name]).ToLowerInvariant() -eq $pin){$pinsMatched++}else{$pinMismatch=$true}
        }
      }
    }
    if($shared -eq 0){continue}
    $entryProviderCount=@($entry.providers).Count
    $matchType='RELATED_PROVIDER'
    if(-not$pinMismatch -and $shared -eq $entryProviderCount -and $pinned -eq $pinsMatched){$matchType='EXACT_PROVIDER_FIXTURE'}
    elseif(-not$pinMismatch -and $pinsMatched -gt 0){$matchType='HASH_PINNED_PARTIAL'}
    elseif($pinMismatch){$matchType='SAME_NAME_DIFFERENT_BUILD'}
    $result.Add([pscustomobject]@{
      knowledgeId=[string]$entry.knowledgeId;kind=[string]$entry.kind;channel=[string]$entry.channel;asset=[string]$entry.asset;
      providers=@($entry.providers);source=[string]$entry.source;runtimeStatus=[string]$entry.runtimeStatus;
      productionEnabled=$(if($entry.PSObject.Properties.Name -contains 'productionEnabled'){[bool]$entry.productionEnabled}else{$false});
      matchType=$matchType;sharedProviderCount=$shared;indexedProviderCount=$entryProviderCount
    })
  }
  return @($result.ToArray()|Sort-Object @{Expression={switch($_.matchType){'EXACT_PROVIDER_FIXTURE'{0};'HASH_PINNED_PARTIAL'{1};'RELATED_PROVIDER'{2};default{3}}}},knowledgeId)
}

function Get-PMMProductionRecipeDocument {
  $path=Get-PMMCKLStablePath 'production-recipes.json'
  if(-not(Test-Path -LiteralPath $path -PathType Leaf)){return $null}
  $identity=''
  try{$identity=Get-Sha256 $path}catch{return $null}
  if($Script:PMMProductionRecipeCache -and [string]$Script:PMMProductionRecipeCacheIdentity -cne '' -and [string]$Script:PMMProductionRecipeCacheIdentity -ceq $identity){return $Script:PMMProductionRecipeCache}
  try{
    $Script:PMMProductionRecipeCache=(Get-Content -LiteralPath $path -Raw|ConvertFrom-Json)
    $Script:PMMProductionRecipeCacheIdentity=$identity
    return $Script:PMMProductionRecipeCache
  }catch{
    $Script:PMMProductionRecipeCache=$null
    $Script:PMMProductionRecipeCacheIdentity=''
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

function Get-PMMConflictCanonicalValue($ConflictValue) {
  if(-not$ConflictValue){return ''}
  if($ConflictValue.PSObject.Properties.Name -contains 'Canonical'){
    return [string]$ConflictValue.Canonical
  }
  if($ConflictValue.PSObject.Properties.Name -contains 'Value'){
    try{return ($ConflictValue.Value|ConvertTo-Json -Compress -Depth 20)}catch{}
  }
  return ''
}

function Get-PMMDataTableCompatibilityResolution($Group,$Conflict,[array]$ProviderRecords) {
  <#
  Exact cooked-family recipes remain hash-pinned. This narrower fallback is
  different: PMMCore has already mapped the current DataTable and exposed one
  exact scalar conflict. A stable rule may resolve only that path, provider set
  and canonical value tuple. The current Vanilla/provider families are still
  merged by DataTableScalarTransfer; no stale cooked output is reused.
  #>
  if(-not$Group -or -not$Conflict -or -not($Conflict.PSObject.Properties.Name -contains 'Providers') -or -not$Conflict.Providers){return $null}
  $doc=Get-PMMProductionRecipeDocument
  if(-not$doc){return $null}

  $available=[System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
  foreach($record in @($ProviderRecords)){
    if($record -and $record.Mod -and -not[string]::IsNullOrWhiteSpace([string]$record.Mod.Name)){[void]$available.Add([string]$record.Mod.Name)}
  }
  $actualConflictNames=@($Conflict.Providers.PSObject.Properties.Name|ForEach-Object{[string]$_}|Sort-Object)

  foreach($recipe in @($doc.recipes)){
    if(-not$recipe -or [string]$recipe.asset -ine [string]$Group.Asset){continue}
    if(-not($recipe.PSObject.Properties.Name -contains 'production') -or -not$recipe.production -or -not[bool]$recipe.production.enabled){continue}
    if(-not($recipe.PSObject.Properties.Name -contains 'semanticFallback') -or -not$recipe.semanticFallback -or -not[bool]$recipe.semanticFallback.enabled){continue}
    if([string]$recipe.semanticFallback.class -cne 'datatable-proven-dominance'){continue}

    foreach($rule in @($recipe.semanticFallback.conflicts)){
      if(-not$rule -or [string]$rule.path -cne [string]$Conflict.Path){continue}
      if([string]$rule.runtime -notmatch '(?i)^proven'){continue}
      if(-not[bool]$rule.requireExactConflictProviders){continue}
      $expected=@($rule.providers)
      if($expected.Count -lt 2){continue}
      $expectedNames=@($expected|ForEach-Object{[string]$_.name}|Sort-Object)
      if(($expectedNames -join '|') -cne ($actualConflictNames -join '|')){continue}

      $matches=$true
      foreach($provider in $expected){
        $name=[string]$provider.name
        if([string]::IsNullOrWhiteSpace($name) -or -not$available.Contains($name)){$matches=$false;break}
        $property=$Conflict.Providers.PSObject.Properties[$name]
        if(-not$property){$matches=$false;break}
        $actual=Get-PMMConflictCanonicalValue $property.Value
        if($actual -cne [string]$provider.canonicalValue){$matches=$false;break}
      }
      if(-not$matches){continue}

      $selected=[string]$rule.selectProvider
      if([string]::IsNullOrWhiteSpace($selected) -or -not$available.Contains($selected) -or -not$Conflict.Providers.PSObject.Properties[$selected]){continue}
      return [pscustomobject]@{
        RuleId=([string]$recipe.id+'/'+[string]$rule.id)
        RecipeId=[string]$recipe.id
        Property=[string]$Conflict.Path
        SelectedChoice=$selected
        ExpectedProviders=@($expected|ForEach-Object{[pscustomobject]@{Name=[string]$_.name;CanonicalValue=[string]$_.canonicalValue}})
        Reason=[string]$rule.semanticReason
        RuntimeStatus=[string]$rule.runtime
      }
    }
  }
  return $null
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
  $candidates=@(Find-PMMCKLCaseCandidates $Group $ProviderRecords|Where-Object{[string]$_.kind -eq 'production-recipe' -and [string]$_.channel -eq 'stable'})
  if($candidates.Count -eq 0){return $null}
  $candidateIds=[System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
  foreach($candidate in $candidates){[void]$candidateIds.Add([string]$candidate.knowledgeId)}
  $doc=Get-PMMProductionRecipeDocument
  if(-not$doc){return $null}

  $asset=[string]$Group.Asset
  $mappings=Get-PMMMappingsPath
  if(-not(Test-Path -LiteralPath $mappings -PathType Leaf)){return $null}
  $mappingHash=Get-Sha256 $mappings
  $actualProviderHashes=@($ProviderRecords|ForEach-Object{([string]$_.Mod.Hash).ToLowerInvariant()}|Sort-Object)

  foreach($recipe in @($doc.recipes)){
    if(-not$recipe){continue}
    if(-not$candidateIds.Contains([string]$recipe.id)){continue}
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
