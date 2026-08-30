<#
LibraryService.ps1 - portable source-mod library
================================================

`Mods/` inside Palworld Manager Merger is the source of truth for original mods managed by
PMM.  Palworld's own ~mods folder is a deployment location, not PMM's database.

Hash cache
----------
The UI checks whether merge-plan.json is still current very frequently.  Older
previews recalculated SHA-256 for every PAK on every UI refresh/timer tick.
Preview 13 caches hashes by full path + size + LastWriteTimeUtc.  Replacing a
file invalidates the cache naturally, while normal UI updates become cheap.
#>

$Script:LibraryHashCache = @{}

function Get-LibraryRoot {
  return (Get-PMMPath 'Mods')
}

function Clear-PMMLibraryHashCache {
  $Script:LibraryHashCache = @{}
}

function Get-PMMCachedFileHash([IO.FileInfo]$File) {
  $key = ('{0}|{1}|{2}' -f $File.FullName.ToLowerInvariant(),$File.Length,$File.LastWriteTimeUtc.Ticks)
  if ($Script:LibraryHashCache.ContainsKey($key)) {
    return [string]$Script:LibraryHashCache[$key]
  }
  $hash = Get-Sha256 $File.FullName
  $Script:LibraryHashCache[$key] = $hash
  return $hash
}

function Get-PMMDisabledModRoot {
  return (Join-Path (Get-LibraryRoot) '_Disabled')
}

function Get-PMMModPriorityPath {
  return (Join-PMMPath 'State' 'mod-priorities.json')
}

function Get-PMMAllLibrarySourcePakFiles {
  $disabledRoot=Get-PMMDisabledModRoot
  return @(Get-ChildItem -LiteralPath (Get-LibraryRoot) -Filter *.pak -File -Recurse -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -notlike 'zzzzzzzzzz_PMM_Merge_*_P.pak' })
}

function Write-PMMModPriorityOrder([array]$Names) {
  $path=Get-PMMModPriorityPath
  $temp=$path+'.tmp'
  $state=[pscustomobject]@{
    SchemaVersion=1
    Meaning='OrderLowToHigh: first applies earlier; last has highest priority for true overlapping values.'
    Updated=(Get-Date).ToString('o')
    OrderLowToHigh=@($Names|ForEach-Object{[string]$_})
  }
  $state|ConvertTo-Json -Depth 8|Set-Content -LiteralPath $temp -Encoding UTF8
  Move-Item -LiteralPath $temp -Destination $path -Force
}

function Get-PMMModPriorityOrder {
  $available=@(Get-PMMAllLibrarySourcePakFiles|ForEach-Object{[string]$_.Name}|Sort-Object -Unique)
  $availableSet=[System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
  foreach($name in $available){[void]$availableSet.Add($name)}

  $stored=@()
  $path=Get-PMMModPriorityPath
  if(Test-Path -LiteralPath $path -PathType Leaf){
    try{
      $state=Get-Content -LiteralPath $path -Raw|ConvertFrom-Json
      if($state -and ($state.PSObject.Properties.Name -contains 'OrderLowToHigh')){$stored=@($state.OrderLowToHigh|ForEach-Object{[string]$_})}
    }catch{Write-PMMLog ('Could not read mod-priorities.json; rebuilding order: '+$_.Exception.Message)}
  }

  $seen=[System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
  $order=[System.Collections.Generic.List[string]]::new()
  foreach($name in $stored){
    if($availableSet.Contains($name) -and $seen.Add($name)){$order.Add($name)}
  }
  foreach($name in $available){if($seen.Add($name)){$order.Add($name)}}

  $normalized=@($order.ToArray())
  if((-not(Test-Path -LiteralPath $path -PathType Leaf)) -or (($stored -join "`n") -cne ($normalized -join "`n"))){
    Write-PMMModPriorityOrder $normalized
  }
  return $normalized
}

function Set-PMMLibraryOrderBy([string]$Mode='Alphabetical') {
  $files=@(Get-PMMAllLibrarySourcePakFiles)
  if($files.Count -eq 0){Write-PMMModPriorityOrder @();return @()}

  $rows=[System.Collections.Generic.List[object]]::new()
  foreach($f in $files){
    $imported=$null
    try{
      $metaPath=Join-Path $f.DirectoryName 'metadata.json'
      if(Test-Path -LiteralPath $metaPath -PathType Leaf){
        $meta=Get-Content -LiteralPath $metaPath -Raw|ConvertFrom-Json
        if($meta -and ($meta.PSObject.Properties.Name -contains 'Imported') -and -not[string]::IsNullOrWhiteSpace([string]$meta.Imported)){$imported=[datetime]$meta.Imported}
      }
    }catch{}
    if(-not$imported){$imported=$f.CreationTimeUtc}
    $rows.Add([pscustomobject]@{Name=[string]$f.Name;Imported=[datetime]$imported;Modified=[datetime]$f.LastWriteTimeUtc})
  }

  switch($Mode){
    'ImportedOldest' {$ordered=@($rows.ToArray()|Sort-Object Imported,Name)}
    'ImportedNewest' {$ordered=@($rows.ToArray()|Sort-Object @{Expression={$_.Imported};Descending=$true},Name)}
    'ModifiedNewest' {$ordered=@($rows.ToArray()|Sort-Object @{Expression={$_.Modified};Descending=$true},Name)}
    default           {$ordered=@($rows.ToArray()|Sort-Object Name)}
  }
  $names=@($ordered|ForEach-Object{[string]$_.Name})
  Write-PMMModPriorityOrder $names
  return $names
}

function Get-PMMMergeValidationPath { return (Join-PMMPath 'State' 'merge-validations.json') }

function Get-PMMMergeValidationRecords {
  $path=Get-PMMMergeValidationPath
  if(-not(Test-Path -LiteralPath $path -PathType Leaf)){return @()}
  try{
    $raw=Get-Content -LiteralPath $path -Raw
    if([string]::IsNullOrWhiteSpace($raw)){return @()}
    return @($raw|ConvertFrom-Json)
  }catch{Write-PMMLog ('Could not read merge validation records: '+$_.Exception.Message);return @()}
}

function Write-PMMMergeValidationRecords([array]$Records) {
  $path=Get-PMMMergeValidationPath
  $temp=$path+'.tmp'
  $normalized=@($Records|Where-Object{$_ -and -not[string]::IsNullOrWhiteSpace([string]$_.Hash)}|Sort-Object Hash -Unique)
  ConvertTo-Json -InputObject @($normalized) -Depth 8|Set-Content -LiteralPath $temp -Encoding UTF8
  Move-Item -LiteralPath $temp -Destination $path -Force
}

function Set-PMMMergeValidated($Patch) {
  if(-not$Patch){throw (Get-PMMText 'Select a saved merge first.' 'Selecciona primero un merge guardado.')}
  $hash=([string]$Patch.Hash).ToLowerInvariant()
  if([string]::IsNullOrWhiteSpace($hash)){throw 'Selected merge has no content hash.'}
  $rows=[System.Collections.Generic.List[object]]::new()
  foreach($r in @(Get-PMMMergeValidationRecords)){if(([string]$r.Hash).ToLowerInvariant() -ne $hash){$rows.Add($r)}}
  $rows.Add([pscustomobject]@{Schema='PMM_MERGE_VALIDATION_V1';Hash=$hash;Name=[string]$Patch.Name;ValidatedUtc=[DateTime]::UtcNow.ToString('o');Validated=$true})
  Write-PMMMergeValidationRecords @($rows.ToArray())
  Write-PMMLog ('User validated merge runtime result: '+[string]$Patch.Name+' | '+$hash)
  return $true
}

function Test-PMMMergeValidated($Patch) {
  if(-not$Patch){return $false}
  $hash=([string]$Patch.Hash).ToLowerInvariant()
  if([string]::IsNullOrWhiteSpace($hash)){return $false}
  return (@(Get-PMMMergeValidationRecords|Where-Object{([string]$_.Hash).ToLowerInvariant() -eq $hash -and [bool]$_.Validated}).Count -gt 0)
}


function Remove-PMMMergeValidationByHash([string]$Hash) {
  if([string]::IsNullOrWhiteSpace($Hash)){return $false}
  $wanted=$Hash.ToLowerInvariant()
  $before=@(Get-PMMMergeValidationRecords)
  $after=@($before|Where-Object{([string]$_.Hash).ToLowerInvariant() -ne $wanted})
  if($after.Count -eq $before.Count){return $false}
  Write-PMMMergeValidationRecords $after
  Write-PMMLog ('Removed merge runtime-validation record: '+$wanted)
  return $true
}

function Get-PMMModPriorityMap {
  $map=@{}
  $index=0
  foreach($name in @(Get-PMMModPriorityOrder)){$index++;$map[[string]$name]=$index}
  return $map
}

function Get-PMMMergeOrderSignature([array]$Mods) {
  $ordered=@($Mods|Sort-Object @{Expression={if($_.PSObject.Properties.Name -contains 'Priority'){[int]$_.Priority}else{2147483647}}},Name)
  return (($ordered|ForEach-Object{"$($_.Name):$($_.Hash)"}) -join '|')
}

function Get-PMMEffectivePatchOrderSignature([array]$Assets,[array]$Mods,[array]$Decisions=@()) {
  <#
  Saved-patch order compatibility is intentionally narrower than the full mod
  order. Automatic merges with no true conflicting value are order-independent:
  moving their providers may change which cooked file is used as a convenient
  construction anchor, but it does not change the requested merged behavior.

  Priority only changes a saved patch when it changes the winner of a true
  conflict row that was actually resolved by Priority. Manual/Custom decisions
  are explicit output choices and therefore remain valid regardless of source
  list order.
  #>
  $priority=@{}
  $hashes=@{}
  foreach($mod in @($Mods)){
    $name=[string]$mod.Name
    if([string]::IsNullOrWhiteSpace($name)){continue}
    $priority[$name]=if($mod.PSObject.Properties.Name -contains 'Priority'){[int]$mod.Priority}else{2147483647}
    $hashes[$name]=if($mod.PSObject.Properties.Name -contains 'Hash'){[string]$mod.Hash}else{''}
  }

  $tokens=[System.Collections.Generic.List[string]]::new()
  foreach($row in @($Decisions|Sort-Object @{Expression={[string]$_.AssetKey}},@{Expression={[string]$_.DecisionId}},@{Expression={[string]$_.Property}})){
    if(-not$row){continue}
    $choice=if($row.PSObject.Properties.Name -contains 'SelectedChoice'){[string]$row.SelectedChoice}else{''}
    $origin=if($row.PSObject.Properties.Name -contains 'ResolutionOrigin'){[string]$row.ResolutionOrigin}else{''}

    # Explicit choices do not depend on priority. For older manifests that do
    # not store ResolutionOrigin, conservatively treat a provider choice as
    # priority-derived only when the row exposes competing providers.
    $isPriority=($origin -eq 'Priority')
    if([string]::IsNullOrWhiteSpace($origin) -and -not[string]::IsNullOrWhiteSpace($choice) -and $choice -ne 'Custom'){$isPriority=$true}
    if(-not$isPriority){continue}

    $competing=@()
    if($row.PSObject.Properties.Name -contains 'CompetingMods'){
      $competing=@($row.CompetingMods|ForEach-Object{[string]$_}|Where-Object{$_}|Select-Object -Unique)
    }
    if($competing.Count -lt 2){continue}

    $choices=@()
    if($row.PSObject.Properties.Name -contains 'Choices'){$choices=@($row.Choices|ForEach-Object{[string]$_}|Where-Object{$_})}
    if($choices.Count -gt 0){$competing=@($competing|Where-Object{[string]$_ -in $choices})}
    if($competing.Count -lt 2){continue}

    # The priority engine is last-writer-wins for the actual competing values,
    # so only the current winner affects output identity. Reordering two losing
    # providers is harmless and should not archive a working patch.
    $ordered=@($competing|Sort-Object @{Expression={if($priority.ContainsKey([string]$_)){[int]$priority[[string]$_]}else{2147483647}}},@{Expression={[string]$_}})
    $winner=[string]$ordered[-1]
    $winnerHash=if($hashes.ContainsKey($winner)){[string]$hashes[$winner]}else{''}
    $assetKey=if($row.PSObject.Properties.Name -contains 'AssetKey'){[string]$row.AssetKey}else{''}
    $decisionId=if($row.PSObject.Properties.Name -contains 'DecisionId'){[string]$row.DecisionId}else{''}
    $property=if($row.PSObject.Properties.Name -contains 'Property'){[string]$row.Property}else{''}
    $decisionKey=if(-not[string]::IsNullOrWhiteSpace($decisionId)){$decisionId}else{$property}
    $tokens.Add(("{0}|{1}={2}:{3}" -f $assetKey,$decisionKey,$winner,$winnerHash))
  }

  if($tokens.Count -eq 0){return 'EFFECTIVE_ORDER_V2:ORDER-INDEPENDENT'}
  return ('EFFECTIVE_ORDER_V2:'+($tokens -join '|'))
}

function Get-PMMManifestEffectivePatchOrderSignature($Manifest) {
  if(-not$Manifest){return ''}
  if($Manifest.PSObject.Properties.Name -contains 'EffectiveMergeOrderSignature'){
    $stored=[string]$Manifest.EffectiveMergeOrderSignature
    # V2 records only output-changing priority winners. Older experimental
    # signatures encoded broader provider order and are migrated in memory.
    if($stored.StartsWith('EFFECTIVE_ORDER_V2:',[StringComparison]::Ordinal)){return $stored}
  }

  $orderIndex=@{}
  if($Manifest.PSObject.Properties.Name -contains 'MergeOrder'){
    $i=0
    foreach($name in @($Manifest.MergeOrder)){if(-not$orderIndex.ContainsKey([string]$name)){$i++;$orderIndex[[string]$name]=$i}}
  }
  $mods=[System.Collections.Generic.List[object]]::new()
  if($Manifest.PSObject.Properties.Name -contains 'Sources'){
    foreach($source in @($Manifest.Sources)){
      $name=[string]$source.Name
      if([string]::IsNullOrWhiteSpace($name)){continue}
      $priorityValue=2147483647
      if($source.PSObject.Properties.Name -contains 'Priority'){$priorityValue=[int]$source.Priority}
      elseif($orderIndex.ContainsKey($name)){$priorityValue=[int]$orderIndex[$name]}
      $mods.Add([pscustomobject]@{Name=$name;Hash=[string]$source.Hash;Priority=$priorityValue})
    }
  }
  $assets=@()
  if($Manifest.PSObject.Properties.Name -contains 'Assets'){$assets=@($Manifest.Assets)}
  $decisions=@()
  if($Manifest.PSObject.Properties.Name -contains 'Decisions'){$decisions=@($Manifest.Decisions)}
  return (Get-PMMEffectivePatchOrderSignature $assets @($mods.ToArray()) $decisions)
}

function Test-PMMPatchEffectiveOrderCompatible($Patch,[array]$SourceMods) {
  if(-not$Patch -or -not$Patch.Manifest -or -not$Patch.ManifestHashOk){return $false}
  $stored=Get-PMMManifestEffectivePatchOrderSignature $Patch.Manifest
  if([string]::IsNullOrWhiteSpace($stored)){return $false}
  $assets=@()
  if($Patch.Manifest.PSObject.Properties.Name -contains 'Assets'){$assets=@($Patch.Manifest.Assets)}
  $decisions=@()
  if($Patch.Manifest.PSObject.Properties.Name -contains 'Decisions'){$decisions=@($Patch.Manifest.Decisions)}
  $current=Get-PMMEffectivePatchOrderSignature $assets $SourceMods $decisions
  return ([string]$stored -eq [string]$current)
}

function Test-PMMStringSetEqual([array]$Left,[array]$Right) {
  $a=@($Left|ForEach-Object{[string]$_}|Where-Object{-not[string]::IsNullOrWhiteSpace($_)}|ForEach-Object{$_.ToLowerInvariant()}|Sort-Object -Unique)
  $b=@($Right|ForEach-Object{[string]$_}|Where-Object{-not[string]::IsNullOrWhiteSpace($_)}|ForEach-Object{$_.ToLowerInvariant()}|Sort-Object -Unique)
  return (($a -join '|') -ceq ($b -join '|'))
}

function Get-PMMPatchAssetIdentity($Asset) {
  if(-not$Asset){return ''}
  $key=''
  if($Asset.PSObject.Properties.Name -contains 'AssetKey'){$key=[string]$Asset.AssetKey}
  if([string]::IsNullOrWhiteSpace($key) -and ($Asset.PSObject.Properties.Name -contains 'Asset')){$key=[string]$Asset.Asset}
  return $key.Replace([char]92,[char]47).ToLowerInvariant()
}

function Get-PMMManifestSourceHashMap($Manifest) {
  $map=[System.Collections.Generic.Dictionary[string,string]]::new([StringComparer]::OrdinalIgnoreCase)
  if(-not$Manifest -or -not($Manifest.PSObject.Properties.Name -contains 'Sources')){return $map}
  foreach($source in @($Manifest.Sources)){
    $name=[string]$source.Name
    if([string]::IsNullOrWhiteSpace($name)){continue}
    $hash=if($source.PSObject.Properties.Name -contains 'Hash'){[string]$source.Hash}else{''}
    $map[$name]=$hash.ToLowerInvariant()
  }
  return $map
}

function Get-PMMProductionRecipeLibrarySha256 {
  $path=Get-PMMCKLStablePath 'production-recipes.json'
  if(-not(Test-Path -LiteralPath $path -PathType Leaf)){return ''}
  try{return (Get-Sha256 $path)}catch{return ''}
}

function Get-PMMAutomaticResolutionSignature($Asset) {
  if(-not$Asset -or -not($Asset.PSObject.Properties.Name -contains 'AutomaticResolutions')){return ''}
  $tokens=New-Object System.Collections.Generic.List[string]
  foreach($resolution in @($Asset.AutomaticResolutions)){
    if(-not$resolution){continue}
    $providers=New-Object System.Collections.Generic.List[string]
    if($resolution.PSObject.Properties.Name -contains 'ExpectedProviders'){
      foreach($provider in @($resolution.ExpectedProviders)){
        if(-not$provider){continue}
        $providers.Add(('{0}={1}' -f [string]$provider.Name,[string]$provider.CanonicalValue))
      }
    }
    $providerToken=@($providers.ToArray()|Sort-Object) -join ','
    $tokens.Add(('{0}|{1}|{2}|{3}|{4}' -f [string]$resolution.RuleId,[string]$resolution.RecipeId,[string]$resolution.Property,[string]$resolution.SelectedChoice,$providerToken))
  }
  return (@($tokens.ToArray()|Sort-Object) -join ';')
}

function Get-PMMManifestBuildEvidenceForAsset($Manifest,$Asset) {
  if(-not$Manifest -or -not$Asset -or -not($Manifest.PSObject.Properties.Name -contains 'BuildAssetEvidence')){return $null}
  $id=Get-PMMPatchAssetIdentity $Asset
  $matches=@($Manifest.BuildAssetEvidence|Where-Object{(Get-PMMPatchAssetIdentity $_) -eq $id})
  if($matches.Count -ne 1){return $null}
  return $matches[0]
}

function Test-PMMKnownRecipeAssetCompatible($StoredAsset,$PlanAsset,$Manifest) {
  <#
  KnownRecipeAuto is data-authorized rather than adapter-only. A changed CKL
  recipe could keep the same asset/provider names while selecting different
  output bytes, so mode/provider equality is insufficient. Current Analyze pins
  the recipe identity; the saved build evidence must also equal the current
  production recipe's exact output family. This lets schema-8 RC21 patches be
  reused safely after full Analyze even though they did not store RecipeId.
  #>
  if(-not$StoredAsset -or -not$PlanAsset -or -not$Manifest){return $false}
  if(-not($PlanAsset.PSObject.Properties.Name -contains 'RecipeId')){return $false}
  $recipeId=[string]$PlanAsset.RecipeId
  if([string]::IsNullOrWhiteSpace($recipeId)){return $false}
  if($StoredAsset.PSObject.Properties.Name -contains 'RecipeId'){
    $storedRecipe=[string]$StoredAsset.RecipeId
    if(-not[string]::IsNullOrWhiteSpace($storedRecipe) -and $storedRecipe -cne $recipeId){return $false}
  }

  $documentCommand=Get-Command Get-PMMProductionRecipeDocument -ErrorAction SilentlyContinue
  if(-not$documentCommand){return $false}
  $document=Get-PMMProductionRecipeDocument
  if(-not$document){return $false}
  $recipes=@($document.recipes|Where-Object{[string]$_.id -ceq $recipeId})
  if($recipes.Count -ne 1){return $false}
  $recipe=$recipes[0]
  if(-not($recipe.PSObject.Properties.Name -contains 'production') -or -not$recipe.production -or -not[bool]$recipe.production.enabled){return $false}
  if(-not($recipe.PSObject.Properties.Name -contains 'status') -or -not$recipe.status -or -not($recipe.status.PSObject.Properties.Name -contains 'runtime') -or [string]$recipe.status.runtime -notmatch '(?i)^proven'){return $false}
  if([string]$recipe.asset -cne [string]$PlanAsset.Asset){return $false}
  if(-not($recipe.PSObject.Properties.Name -contains 'providers') -or -not($recipe.PSObject.Properties.Name -contains 'output') -or -not$recipe.output -or -not($recipe.output.PSObject.Properties.Name -contains 'family') -or -not$recipe.output.family -or [string]$recipe.output.mode -cne 'reuse-provider-family'){return $false}

  $outputPakHash=([string]$recipe.output.providerPakSha256).ToLowerInvariant()
  $outputProviders=@($recipe.providers|Where-Object{([string]$_.pakSha256).ToLowerInvariant() -eq $outputPakHash})
  if($outputProviders.Count -ne 1){return $false}
  $expectedProvider=[string]$outputProviders[0].name
  if(-not($PlanAsset.PSObject.Properties.Name -contains 'RecipeOutputProvider') -or [string]$PlanAsset.RecipeOutputProvider -ine $expectedProvider){return $false}
  if($StoredAsset.PSObject.Properties.Name -contains 'RecipeOutputProvider'){
    $storedProvider=[string]$StoredAsset.RecipeOutputProvider
    if(-not[string]::IsNullOrWhiteSpace($storedProvider) -and $storedProvider -ine $expectedProvider){return $false}
  }

  $evidence=Get-PMMManifestBuildEvidenceForAsset $Manifest $StoredAsset
  if(-not$evidence -or -not($evidence.PSObject.Properties.Name -contains 'OutputParts')){return $false}
  $actual=@{}
  foreach($part in @($evidence.OutputParts)){
    $extension=([string]$part.Part).ToLowerInvariant()
    if([string]::IsNullOrWhiteSpace($extension) -or $actual.ContainsKey($extension)){return $false}
    $actual[$extension]=$part
  }
  $expectedCount=0
  foreach($partName in @('uasset','uexp','ubulk')){
    $property=$recipe.output.family.PSObject.Properties[$partName]
    if(-not$property){continue}
    $expectedCount++
    $extension='.'+$partName
    if(-not$actual.ContainsKey($extension)){return $false}
    $expected=$property.Value;$found=$actual[$extension]
    if(([string]$found.Sha256).ToLowerInvariant() -cne ([string]$expected.sha256).ToLowerInvariant()){return $false}
    if([int64]$found.Bytes -ne [int64]$expected.size){return $false}
  }
  return ($expectedCount -gt 0 -and $actual.Count -eq $expectedCount)
}

function Test-PMMPatchRuntimeCompatible($Patch,[array]$SourceMods) {
  <#
  Validate the immutable inputs that can change an overlay even when unrelated
  source PAKs are added or removed. This deliberately does not compare the full
  source-set signature; plan-level compatibility performs the narrower,
  conflict-participant comparison after a current Analyze has proved topology.
  #>
  if(-not$Patch -or -not$Patch.Manifest -or -not$Patch.ManifestHashOk){return $false}
  $manifest=$Patch.Manifest

  if(-not($manifest.PSObject.Properties.Name -contains 'Engine')){return $false}
  $engineCommand=Get-Command Get-PMMEngineId -ErrorAction SilentlyContinue
  if(-not$engineCommand -or [string]$manifest.Engine -cne [string](Get-PMMEngineId)){return $false}

  if(-not($manifest.PSObject.Properties.Name -contains 'VanillaSourceSignature')){return $false}
  $vanillaCommand=Get-Command Get-PMMVanillaPakSetQuickSignature -ErrorAction SilentlyContinue
  if(-not$vanillaCommand -or [string]$manifest.VanillaSourceSignature -cne [string](Get-PMMVanillaPakSetQuickSignature)){return $false}

  if(-not($manifest.PSObject.Properties.Name -contains 'MappingsSha256')){return $false}
  $map=Get-PMMMappingsPath
  if(-not(Test-Path -LiteralPath $map -PathType Leaf)){return $false}
  if([string]$manifest.MappingsSha256 -cne [string](Get-Sha256 $map)){return $false}

  # Keep an actual Object[] for zero, one or many matches. In Windows
  # PowerShell 5.1 an array emitted from an if branch is pipeline-unrolled; a
  # single knowledge-authorized asset then becomes a PSCustomObject and StrictMode
  # rejects `.Count` during the post-Build UI refresh.
  $knowledgeAuthorizedAssets=@()
  if($manifest.PSObject.Properties.Name -contains 'Assets'){
    $knowledgeAuthorizedAssets=@($manifest.Assets|Where-Object{
      [string]$_.Mode -eq 'KnownRecipeAuto' -or
      (($_.PSObject.Properties.Name -contains 'AutomaticResolutions') -and @($_.AutomaticResolutions).Count -gt 0)
    })
  }
  if($knowledgeAuthorizedAssets.Count -gt 0){
    if(-not($manifest.PSObject.Properties.Name -contains 'ProductionRecipesSha256')){return $false}
    $recipeHash=Get-PMMProductionRecipeLibrarySha256
    if([string]::IsNullOrWhiteSpace($recipeHash) -or [string]$manifest.ProductionRecipesSha256 -cne $recipeHash){return $false}
  }

  if(-not(Test-PMMPatchEffectiveOrderCompatible $Patch $SourceMods)){return $false}
  return $true
}

function Test-PMMPlanCurrentForPatchCompatibility($Plan,[array]$SourceMods) {
  # An effective-match patch is selectable only behind a fresh Analyze plan for
  # the exact current library. This prevents a stale manifest from blessing a
  # newly added provider or a newly introduced shared asset.
  if(-not$Plan){return $false}
  if(-not($Plan.PSObject.Properties.Name -contains 'SchemaVersion') -or [int]$Plan.SchemaVersion -ne (Get-PMMPlanSchemaVersion)){return $false}
  if(-not($Plan.PSObject.Properties.Name -contains 'Engine') -or [string]$Plan.Engine -cne [string](Get-PMMEngineId)){return $false}
  if(-not($Plan.PSObject.Properties.Name -contains 'EngineProfile') -or [string]$Plan.EngineProfile -cne 'UE5_1'){return $false}
  if(-not($Plan.PSObject.Properties.Name -contains 'Assets') -or -not($Plan.PSObject.Properties.Name -contains 'Rows')){return $false}
  if([string]$Plan.SourceSignature -cne [string](Get-PMMLibrarySignature $SourceMods)){return $false}
  if(-not($Plan.PSObject.Properties.Name -contains 'VanillaSourceSignature') -or [string]$Plan.VanillaSourceSignature -cne [string](Get-PMMVanillaPakSetQuickSignature)){return $false}
  if(-not($Plan.PSObject.Properties.Name -contains 'MergeOrderSignature') -or [string]$Plan.MergeOrderSignature -cne [string](Get-PMMMergeOrderSignature $SourceMods)){return $false}
  if(-not($Plan.PSObject.Properties.Name -contains 'MappingsSha256')){return $false}
  $map=Get-PMMMappingsPath
  if(-not(Test-Path -LiteralPath $map -PathType Leaf) -or [string]$Plan.MappingsSha256 -cne [string](Get-Sha256 $map)){return $false}
  if(-not($Plan.PSObject.Properties.Name -contains 'KnowledgeRulesSha256') -or [string]$Plan.KnowledgeRulesSha256 -cne [string](Get-PMMProductionRecipeLibrarySha256)){return $false}
  if(($Plan.PSObject.Properties.Name -contains 'PackageChoicePendingReanalysis') -and [bool]$Plan.PackageChoicePendingReanalysis){return $false}
  if(@($Plan.Assets|Where-Object{[string]$_.Mode -eq 'Unsupported'}).Count -gt 0){return $false}
  foreach($row in @($Plan.Rows)){
    $choice=[string]$row.SelectedChoice
    if([string]::IsNullOrWhiteSpace($choice)){return $false}
    if($choice -eq 'Custom' -and [string]::IsNullOrWhiteSpace([string]$row.CustomValue)){return $false}
  }
  return $true
}

function Get-PMMCurrentPlanForPatchCompatibility([array]$SourceMods) {
  $path=Join-PMMPath 'State' 'merge-plan.json'
  if(-not(Test-Path -LiteralPath $path -PathType Leaf)){return $null}
  try{
    $plan=Get-Content -LiteralPath $path -Raw|ConvertFrom-Json
    if(Test-PMMPlanCurrentForPatchCompatibility $plan $SourceMods){return $plan}
  }catch{}
  return $null
}

function Test-PMMPatchPlanCompatible($Patch,$Plan,[array]$SourceMods) {
  <#
  Prove that a saved overlay is the same recipe required by a current Analyze.
  Unique/non-conflicting PAKs are intentionally excluded. Every patched asset,
  provider name, provider hash, adapter mode, decision, Vanilla identity,
  mappings identity and output-relevant priority winner must still match.
  #>
  if(-not(Test-PMMPlanCurrentForPatchCompatibility $Plan $SourceMods)){return $false}
  if(-not(Test-PMMPatchRuntimeCompatible $Patch $SourceMods)){return $false}
  $manifest=$Patch.Manifest
  if(-not($manifest.PSObject.Properties.Name -contains 'Assets') -or -not($manifest.PSObject.Properties.Name -contains 'Sources')){return $false}

  $planAssets=@($Plan.Assets|Where-Object{[string]$_.Mode -notin @('Identical','Unsupported','PackageChoice')})
  $patchAssets=@($manifest.Assets|Where-Object{[string]$_.Mode -notin @('Identical','Unsupported','PackageChoice')})
  if($planAssets.Count -eq 0 -or $planAssets.Count -ne $patchAssets.Count){return $false}

  # Experimental cooked/manual solutions can change independently of their
  # source PAKs. They remain reusable only for the manifest's exact source set.
  if(@($planAssets|Where-Object{[string]$_.Mode -eq 'ManualSolutionExperimental'}).Count -gt 0){
    if([string]$Patch.SourceSignature -cne [string](Get-PMMLibrarySignature $SourceMods)){return $false}
  }

  $patchByAsset=@{}
  foreach($asset in $patchAssets){
    $id=Get-PMMPatchAssetIdentity $asset
    if([string]::IsNullOrWhiteSpace($id) -or $patchByAsset.ContainsKey($id)){return $false}
    $patchByAsset[$id]=$asset
  }
  $manifestHashes=Get-PMMManifestSourceHashMap $manifest
  $currentHashes=[System.Collections.Generic.Dictionary[string,string]]::new([StringComparer]::OrdinalIgnoreCase)
  foreach($mod in @($SourceMods)){$currentHashes[[string]$mod.Name]=([string]$mod.Hash).ToLowerInvariant()}

  foreach($asset in $planAssets){
    $id=Get-PMMPatchAssetIdentity $asset
    if(-not$patchByAsset.ContainsKey($id)){return $false}
    $stored=$patchByAsset[$id]
    if([string]$asset.Mode -cne [string]$stored.Mode){return $false}
    if([string]$asset.Mode -eq 'KnownRecipeAuto'){
      $recipeCompatible=$false
      try{$recipeCompatible=Test-PMMKnownRecipeAssetCompatible $stored $asset $manifest}catch{$recipeCompatible=$false}
      if(-not$recipeCompatible){return $false}
    }
    if((Get-PMMAutomaticResolutionSignature $asset) -cne (Get-PMMAutomaticResolutionSignature $stored)){return $false}
    $providers=@($asset.Providers|ForEach-Object{[string]$_})
    if(-not(Test-PMMStringSetEqual $providers @($stored.Providers))){return $false}
    foreach($name in $providers){
      if(-not$currentHashes.ContainsKey($name) -or -not$manifestHashes.ContainsKey($name)){return $false}
      if([string]$currentHashes[$name] -cne [string]$manifestHashes[$name]){return $false}
    }
  }

  $rows=@($Plan.Rows)
  $storedRows=@()
  if($manifest.PSObject.Properties.Name -contains 'Decisions'){$storedRows=@($manifest.Decisions)}
  if($manifest.PSObject.Properties.Name -contains 'DecisionSignature'){
    $decisionCommand=Get-Command Get-PMMDecisionSignature -ErrorAction SilentlyContinue
    if(-not$decisionCommand){return $false}
    if([string]$manifest.DecisionSignature -cne [string](Get-PMMDecisionSignature $rows)){return $false}
  }elseif($rows.Count -gt 0 -or $storedRows.Count -gt 0){
    return $false
  }
  return $true
}


function Get-PMMPatchContentSignature($Patch) {
  if(-not$Patch -or -not$Patch.Manifest){return ''}
  if(($Patch.PSObject.Properties.Name -contains 'ManifestHashOk') -and -not[bool]$Patch.ManifestHashOk){return ''}
  $manifest=$Patch.Manifest
  if($manifest.PSObject.Properties.Name -contains 'PatchContentSignature'){
    $stored=[string]$manifest.PatchContentSignature
    if(-not[string]::IsNullOrWhiteSpace($stored)){return $stored}
  }
  if(-not($manifest.PSObject.Properties.Name -contains 'BuildAssetEvidence')){return ''}

  $parts=[System.Collections.Generic.List[string]]::new()
  foreach($asset in @($manifest.BuildAssetEvidence|Sort-Object @{Expression={[string]$_.AssetKey}},@{Expression={[string]$_.Asset}})){
    foreach($part in @($asset.OutputParts|Sort-Object @{Expression={[string]$_.Part}})){
      $parts.Add(("{0}|{1}|{2}|{3}" -f [string]$asset.AssetKey,[string]$part.Part,[int64]$part.Bytes,[string]$part.Sha256))
    }
  }
  if($parts.Count -eq 0){return ''}
  $sha=[Security.Cryptography.SHA256]::Create()
  try{
    $bytes=[Text.Encoding]::UTF8.GetBytes(($parts -join ';'))
    return ((($sha.ComputeHash($bytes)|ForEach-Object{$_.ToString('x2')}) -join '').Substring(0,24))
  }finally{$sha.Dispose()}
}

function Test-PMMModPriorityMove([string]$Name,[ValidateSet('Earlier','Later')][string]$Direction) {
  $order=@(Get-PMMModPriorityOrder)
  $index=-1
  for($i=0;$i -lt $order.Count;$i++){if([string]$order[$i] -ieq $Name){$index=$i;break}}
  if($index -lt 0){return $false}
  if($Direction -eq 'Earlier'){return ($index -gt 0)}
  return ($index -lt ($order.Count-1))
}

function Clear-PMMModPriorityDerivedState {
  # Keep the previous merge-plan as a decision-history source. Its order
  # signature makes it invalid for Build immediately, but the next Analyze can
  # still preserve explicit manual choices while recomputing priority defaults.
  Remove-Item -LiteralPath (Join-PMMPath 'State' 'last-scan.json') -Force -ErrorAction SilentlyContinue

  # Keep the selected saved patch unless the move changes the winning provider
  # of a true conflict that was resolved by priority. Automatic merges and
  # explicit Manual/Custom conflict choices are order-independent for reuse.
  try{
    $cfg=Get-PMMConfig
    if($cfg.PSObject.Properties.Name -contains 'SelectedPatchName'){
      $selected=[string]$cfg.SelectedPatchName
      if(-not[string]::IsNullOrWhiteSpace($selected) -and $selected -ne '__PMM_NO_COMPATIBILITY_PATCH__'){
        $mods=@(Get-LibraryMods)
        $patch=@(Get-PMMManagedPatches|Where-Object{[string]$_.Name -ieq $selected}|Select-Object -First 1)[0]
        if(-not$patch -or -not(Test-PMMPatchEffectiveOrderCompatible $patch $mods)){
          $cfg.SelectedPatchName=''
          Save-PMMConfig $cfg
        }
      }
    }
  }catch{}
}

function Set-PMMModPriorityPosition([string]$Name,[long]$Position) {
  $order=@(Get-PMMModPriorityOrder)
  $index=-1
  for($i=0;$i -lt $order.Count;$i++){if([string]$order[$i] -ieq $Name){$index=$i;break}}
  if($index -lt 0){throw (Get-PMMText "Mod not found in PMM priority order: $Name" "No se encontro el mod en el orden de prioridad PMM: $Name")}
  if($order.Count -le 1){return $false}

  # The UI accepts any whole number. Positions outside the current library are
  # clamped so the stored order always remains the dense sequence 1..N.
  $target=$Position
  if($target -lt 1){$target=1}
  if($target -gt $order.Count){$target=$order.Count}
  $target=[int]$target
  $current=$index+1
  if($target -eq $current){return $false}

  $moving=[string]$order[$index]
  $newOrder=[System.Collections.Generic.List[string]]::new()
  for($i=0;$i -lt $order.Count;$i++){
    if($i -ne $index){$newOrder.Add([string]$order[$i])}
  }
  $newOrder.Insert($target-1,$moving)
  Write-PMMModPriorityOrder @($newOrder.ToArray())
  Clear-PMMModPriorityDerivedState
  Write-PMMLog ((Get-PMMText 'Changed merge priority position: {0} {1} -> {2}. Analyze is required again.' 'Cambio de posicion de prioridad de merge: {0} {1} -> {2}. Se requiere volver a Analizar.') -f $Name,$current,$target)
  return $true
}

function Move-PMMModPriority([string]$Name,[ValidateSet('Earlier','Later')][string]$Direction) {
  $order=@(Get-PMMModPriorityOrder)
  $index=-1
  for($i=0;$i -lt $order.Count;$i++){if([string]$order[$i] -ieq $Name){$index=$i;break}}
  if($index -lt 0){throw (Get-PMMText "Mod not found in PMM priority order: $Name" "No se encontro el mod en el orden de prioridad PMM: $Name")}
  $current=$index+1
  $target=if($Direction -eq 'Earlier'){$current-1}else{$current+1}
  if($target -lt 1 -or $target -gt $order.Count){return $false}
  return (Set-PMMModPriorityPosition $Name $target)
}

function Test-PMMPathInside([string]$Path,[string]$Root) {
  try {
    $full=[IO.Path]::GetFullPath($Path).TrimEnd([char]92,[char]47)+[IO.Path]::DirectorySeparatorChar
    $rootFull=[IO.Path]::GetFullPath($Root).TrimEnd([char]92,[char]47)+[IO.Path]::DirectorySeparatorChar
    return $full.StartsWith($rootFull,[StringComparison]::OrdinalIgnoreCase)
  } catch { return $false }
}

function Get-LibraryMods {
  $disabledRoot=Get-PMMDisabledModRoot
  $priorityMap=Get-PMMModPriorityMap
  $files = @(Get-PMMAllLibrarySourcePakFiles|Where-Object{-not(Test-PMMPathInside $_.DirectoryName $disabledRoot)}|Sort-Object @{Expression={if($priorityMap.ContainsKey($_.Name)){[int]$priorityMap[$_.Name]}else{2147483647}}},Name)
  foreach ($f in $files) {
    [pscustomobject]@{
      Name = $f.Name
      Path = $f.FullName
      Size = $f.Length
      Hash = Get-PMMCachedFileHash $f
      Enabled = $true
      Priority = $(if($priorityMap.ContainsKey($f.Name)){[int]$priorityMap[$f.Name]}else{2147483647})
    }
  }
}

function Get-PMMDisabledMods {
  $root=Get-PMMDisabledModRoot
  if(-not(Test-Path -LiteralPath $root -PathType Container)){return @()}
  $priorityMap=Get-PMMModPriorityMap
  foreach($f in @(Get-PMMAllLibrarySourcePakFiles|Where-Object{Test-PMMPathInside $_.DirectoryName $root}|Sort-Object @{Expression={if($priorityMap.ContainsKey($_.Name)){[int]$priorityMap[$_.Name]}else{2147483647}}},Name)){
    [pscustomobject]@{Name=$f.Name;Path=$f.FullName;Size=$f.Length;Hash=(Get-PMMCachedFileHash $f);Enabled=$false;Priority=$(if($priorityMap.ContainsKey($f.Name)){[int]$priorityMap[$f.Name]}else{2147483647})}
  }
}

function Clear-PMMAnalysisState {
  foreach($name in @('merge-plan.json','last-scan.json')){
    Remove-Item -LiteralPath (Join-Path (Get-PMMPath 'State') $name) -Force -ErrorAction SilentlyContinue
  }
}

function Get-PMMPendingRemovalPath { return (Join-PMMPath 'State' 'pending-removals.json') }

function Test-PMMSafePakLeafName([string]$Name) {
  if([string]::IsNullOrWhiteSpace($Name)){return $false}
  if([IO.Path]::GetFileName($Name) -ne $Name){return $false}
  return ([IO.Path]::GetExtension($Name) -ieq '.pak')
}

function Get-PMMPendingRemovalRecords {
  $path=Get-PMMPendingRemovalPath
  if(-not(Test-Path -LiteralPath $path -PathType Leaf)){return @()}
  try{
    $raw=Get-Content -LiteralPath $path -Raw
    if([string]::IsNullOrWhiteSpace($raw)){return @()}
    $parsed=$raw|ConvertFrom-Json
    $records=New-Object System.Collections.Generic.List[object]
    foreach($item in @($parsed)){
      $name='';$hash=''
      if($item -is [string]){
        # Migration from preview28's string-only pending-removal schema.
        $name=[string]$item
      }elseif($item -and ($item.PSObject.Properties.Name -contains 'Name')){
        $name=[string]$item.Name
        if($item.PSObject.Properties.Name -contains 'Hash'){$hash=[string]$item.Hash}
      }
      if(-not(Test-PMMSafePakLeafName $name)){
        if(-not[string]::IsNullOrWhiteSpace($name)){Write-PMMLog "Ignored unsafe pending-removal name: $name"}
        continue
      }
      $records.Add([pscustomobject]@{Name=$name;Hash=$hash.ToLowerInvariant()})
    }
    return @($records|Sort-Object Name -Unique)
  }catch{
    Write-PMMLog ('Could not read pending-removals.json: '+$_.Exception.Message)
    return @()
  }
}

function Get-PMMPendingRemovals {
  return @(Get-PMMPendingRemovalRecords|ForEach-Object{[string]$_.Name})
}

function Write-PMMPendingRemovalRecords([array]$Records){
  $path=Get-PMMPendingRemovalPath
  $temp=$path+'.tmp'
  $normalized=@($Records|Where-Object{$_ -and (Test-PMMSafePakLeafName ([string]$_.Name))}|ForEach-Object{
    [pscustomobject]@{Name=[string]$_.Name;Hash=([string]$_.Hash).ToLowerInvariant()}
  }|Sort-Object Name -Unique)
  $json=ConvertTo-Json -InputObject @($normalized) -Depth 5
  Set-Content -LiteralPath $temp -Value $json -Encoding UTF8
  Move-Item -LiteralPath $temp -Destination $path -Force
}

function Write-PMMPendingRemovals([array]$Names){
  $records=@($Names|Where-Object{Test-PMMSafePakLeafName ([string]$_)}|ForEach-Object{[pscustomobject]@{Name=[string]$_;Hash=''}})
  Write-PMMPendingRemovalRecords $records
}

function Add-PMMPendingRemoval([string]$Name,[string]$Hash=''){
  if(-not(Test-PMMSafePakLeafName $Name)){return}
  $records=@(Get-PMMPendingRemovalRecords)
  $found=$false
  foreach($record in $records){
    if([string]$record.Name -ieq $Name){
      $found=$true
      if(-not[string]::IsNullOrWhiteSpace($Hash)){$record.Hash=$Hash.ToLowerInvariant()}
    }
  }
  if(-not$found){$records+=,[pscustomobject]@{Name=$Name;Hash=$Hash.ToLowerInvariant()}}
  Write-PMMPendingRemovalRecords $records
}

function Remove-PMMPendingRemoval([string]$Name){
  if([string]::IsNullOrWhiteSpace($Name)){return}
  Write-PMMPendingRemovalRecords @((Get-PMMPendingRemovalRecords)|Where-Object{[string]$_.Name -ine $Name})
}


function Find-PMMLibraryMod([string]$Name) {
  $active=@(Get-LibraryMods|Where-Object{$_.Name -eq $Name}|Select-Object -First 1)
  if($active.Count -gt 0){return $active[0]}
  $disabled=@(Get-PMMDisabledMods|Where-Object{$_.Name -eq $Name}|Select-Object -First 1)
  if($disabled.Count -gt 0){return $disabled[0]}
  return $null
}

function Set-PMMLibraryModEnabled([string]$Name,[bool]$Enabled) {
  $mod=Find-PMMLibraryMod $Name
  if(-not$mod){throw (Get-PMMText "Mod not found in PMM library: $Name" "No se encontro el mod en la biblioteca PMM: $Name")}
  if([bool]$mod.Enabled -eq $Enabled){return}

  $srcDir=Split-Path -Parent ([string]$mod.Path)
  $folderName=Split-Path -Leaf $srcDir
  $destRoot=if($Enabled){Get-LibraryRoot}else{Get-PMMDisabledModRoot}
  New-Item -ItemType Directory -Force -Path $destRoot|Out-Null
  $destDir=Join-Path $destRoot $folderName
  if(Test-Path -LiteralPath $destDir){throw (Get-PMMText "Library destination already exists: $destDir" "Ya existe el destino en la biblioteca: $destDir")}
  Move-Item -LiteralPath $srcDir -Destination $destDir
  if($Enabled){Remove-PMMPendingRemoval $Name}
  Clear-PMMLibraryHashCache;Clear-PakEntryCache;Clear-PMMAnalysisState
  $actionLabel=if($Enabled){'Enabled'}else{'Disabled/backed up'}
  Write-PMMLog ("$actionLabel source mod: $Name")
}

function Remove-PMMLibraryMod([string]$Name) {
  <#
  DELETE MOD lifecycle contract (PMM 1.3):
    * Delete is immediate, not deferred until the next Deploy.
    * Remove the managed source from the PMM library (active or disabled).
    * Remove the exact same managed PAK from Palworld ~mods when present.
    * Preserve every deployed compatibility merge and sidecar. Only explicit
      actions in Mods & Merge may deploy, undeploy or delete a merge.
    * Refuse to delete a same-name game PAK whose SHA-256 differs from the
      library copy. PMM never treats a name alone as ownership proof.
    * Commit transactionally enough that a filesystem/state failure restores
      the library directory, game files and state/config snapshots.
  #>
  $mod=Find-PMMLibraryMod $Name
  if(-not$mod){throw (Get-PMMText "Mod not found in PMM library: $Name" "No se encontro el mod en la biblioteca PMM: $Name")}
  if(-not(Test-PMMSafePakLeafName ([string]$mod.Name))){throw ('Unsafe source mod name: '+[string]$mod.Name)}

  $cfg=Get-PMMConfig
  if(-not$cfg -or [string]::IsNullOrWhiteSpace([string]$cfg.GamePath)){
    throw (Get-PMMText 'Detect or configure Palworld before deleting an imported mod. Delete removes both the PMM-library copy and the game ~mods copy, so PMM must know the game folder first.' 'Detecta o configura Palworld antes de borrar un mod importado. Delete elimina tanto la copia de la biblioteca PMM como la copia de ~mods del juego, asi que PMM debe conocer primero la carpeta del juego.')
  }
  Ensure-GameModsFolder
  $gameMods=Get-GameModsPath
  if(-not$gameMods -or -not(Test-Path -LiteralPath $gameMods -PathType Container)){
    throw (Get-PMMText 'Palworld ~mods could not be resolved. Nothing was deleted.' 'No se pudo resolver ~mods de Palworld. No se borro nada.')
  }

  $name=[string]$mod.Name
  $hash=([string]$mod.Hash).ToLowerInvariant()
  $libraryDir=Split-Path -Parent ([string]$mod.Path)
  if(-not(Test-Path -LiteralPath $libraryDir -PathType Container)){throw ('PMM library directory is missing: '+$libraryDir)}

  # Preflight the game source before touching the library. Delete is allowed
  # when the source is not currently deployed, or when the deployed bytes are
  # exactly the bytes PMM imported. A same-name foreign/changed file blocks the
  # entire delete rather than risking data loss.
  $gamePak=Join-Path $gameMods $name
  $gameSourcePresent=Test-Path -LiteralPath $gamePak -PathType Leaf
  if($gameSourcePresent){
    $actual=(Get-Sha256 $gamePak).ToLowerInvariant()
    if($actual -ne $hash){
      throw ((Get-PMMText "Delete stopped: '{0}' exists in Palworld ~mods but its SHA-256 does not match the imported PMM copy. PMM will not delete either copy until that identity conflict is resolved. Existing SHA-256: {1}; expected: {2}." "Delete detenido: '{0}' existe en ~mods de Palworld pero su SHA-256 no coincide con la copia importada en PMM. PMM no borrara ninguna copia hasta resolver ese conflicto de identidad. SHA-256 existente: {1}; esperado: {2}.") -f $name,$actual,$hash)
    }
  }

  # Delete owns only the selected source PAK. A deployed compatibility merge is
  # intentionally outside this transaction even when the source set changes.
  $gameTargets=[System.Collections.Generic.List[string]]::new()
  if($gameSourcePresent){$gameTargets.Add($gamePak)}

  $tx=Join-Path (Get-PMMPath 'Cache') ('DeleteMod_'+[guid]::NewGuid().ToString('N'))
  $trash=Join-Path $tx 'trash'
  $stateBackup=Join-Path $tx 'state'
  New-Item -ItemType Directory -Force -Path $trash,$stateBackup|Out-Null
  $movedGame=[System.Collections.Generic.List[object]]::new()
  $libraryTrash=Join-Path $trash 'library-source'
  $libraryMoved=$false

  # Snapshot the small state files that this operation may rewrite so rollback
  # can restore the exact pre-delete manager state.
  $stateFiles=@(
    (Get-PMMDeploymentStatePath),
    (Get-PMMPendingRemovalPath),
    (Get-PMMModPriorityPath),
    (Join-PMMPath 'State' 'merge-plan.json'),
    (Join-PMMPath 'State' 'last-scan.json'),
    (Get-PMMConfigPath)
  )|Select-Object -Unique
  $stateRecords=[System.Collections.Generic.List[object]]::new()
  $si=0
  foreach($statePath in $stateFiles){
    if(Test-Path -LiteralPath $statePath -PathType Leaf){
      $si++
      $backup=Join-Path $stateBackup (('{0:D2}_{1}' -f $si,[IO.Path]::GetFileName($statePath)))
      Copy-Item -LiteralPath $statePath -Destination $backup -Force
      $stateRecords.Add([pscustomobject]@{Original=$statePath;Backup=$backup;Existed=$true})
    }else{
      $stateRecords.Add([pscustomobject]@{Original=$statePath;Backup='';Existed=$false})
    }
  }

  try{
    # Move the entire PMM library directory first. It is still recoverable in
    # the transaction trash until all game/state work has committed.
    Move-Item -LiteralPath $libraryDir -Destination $libraryTrash -Force
    $libraryMoved=$true

    # Move game files into transaction trash rather than deleting them in place.
    # This gives rollback exact bytes without relying on a second copy/hash pass.
    $gi=0
    foreach($target in @($gameTargets.ToArray()|Select-Object -Unique)){
      if(-not(Test-Path -LiteralPath $target -PathType Leaf)){continue}
      $gi++
      $dst=Join-Path $trash (('game_{0:D3}_{1}' -f $gi,[IO.Path]::GetFileName($target)))
      Move-Item -LiteralPath $target -Destination $dst -Force
      $movedGame.Add([pscustomobject]@{Original=$target;Trash=$dst})
    }

    # Delete is immediate: there is no future pending-removal record for this
    # source. Normalize priority now that the library directory is gone.
    Remove-PMMPendingRemoval $name
    [void](Get-PMMModPriorityOrder)

    # The previous deployment record remains authoritative for the compatibility
    # patch. Remove only the deleted source and clear source-set freshness; do
    # not clear Patch, its deployment timestamp, or the selected saved merge.
    $state=Read-PMMDeploymentState
    if($state){
      if($state.PSObject.Properties.Name -contains 'SourceMods'){
        $remaining=@($state.SourceMods|Where-Object{[string]$_.Name -ine $name})
        $state.SourceMods=$remaining
      }
      if($state.PSObject.Properties.Name -contains 'SourceSignature'){$state.SourceSignature=''}
      Write-PMMDeploymentState $state
    }

    Clear-PMMLibraryHashCache;Clear-PakEntryCache;Clear-PMMAnalysisState

    $overlayCount=0
    Write-PMMLog ('Deleted source mod everywhere: '+$name+' | hash='+$hash+' | gameSourceRemoved='+$gameSourcePresent+' | deployedMergePreserved=true')

    # Commit deletion by destroying transaction trash. Cleanup failure leaves
    # only an internal temporary backup and must not resurrect already-deleted
    # files or report a false rollback.
    try{Remove-Item -LiteralPath $tx -Recurse -Force -ErrorAction Stop}catch{Write-PMMLog ('Delete Mod transaction cleanup warning: '+$_.Exception.Message)}
    return [pscustomobject]@{Name=$name;Hash=$hash;DeletedFromLibrary=$true;DeletedFromGame=[bool]$gameSourcePresent;UndeployedMergeCount=[int]$overlayCount}
  }catch{
    $failure=$_.Exception.Message
    $rollbackErrors=[System.Collections.Generic.List[string]]::new()

    # Restore manager state first so a subsequent UI refresh cannot observe a
    # half-updated deployment/config record.
    foreach($r in @($stateRecords.ToArray())){
      try{
        if([bool]$r.Existed){
          $parent=Split-Path -Parent ([string]$r.Original);if($parent){New-Item -ItemType Directory -Force -Path $parent|Out-Null}
          Copy-Item -LiteralPath ([string]$r.Backup) -Destination ([string]$r.Original) -Force -ErrorAction Stop
        }else{
          Remove-Item -LiteralPath ([string]$r.Original) -Force -ErrorAction SilentlyContinue
        }
      }catch{$rollbackErrors.Add('restore state '+[string]$r.Original+': '+$_.Exception.Message)}
    }

    $gameRows=@($movedGame.ToArray())
    for($i=$gameRows.Count-1;$i -ge 0;$i--){
      $r=$gameRows[$i]
      try{
        if(Test-Path -LiteralPath ([string]$r.Trash) -PathType Leaf){
          $parent=Split-Path -Parent ([string]$r.Original);if($parent){New-Item -ItemType Directory -Force -Path $parent|Out-Null}
          Move-Item -LiteralPath ([string]$r.Trash) -Destination ([string]$r.Original) -Force -ErrorAction Stop
        }
      }catch{$rollbackErrors.Add('restore game file '+[string]$r.Original+': '+$_.Exception.Message)}
    }

    if($libraryMoved){
      try{
        if(Test-Path -LiteralPath $libraryTrash -PathType Container){
          $parent=Split-Path -Parent $libraryDir;if($parent){New-Item -ItemType Directory -Force -Path $parent|Out-Null}
          if(Test-Path -LiteralPath $libraryDir){Remove-Item -LiteralPath $libraryDir -Recurse -Force -ErrorAction Stop}
          Move-Item -LiteralPath $libraryTrash -Destination $libraryDir -Force -ErrorAction Stop
        }
      }catch{$rollbackErrors.Add('restore PMM library directory '+$libraryDir+': '+$_.Exception.Message)}
    }

    Clear-PMMLibraryHashCache;Clear-PakEntryCache
    if($rollbackErrors.Count -eq 0){
      Remove-Item -LiteralPath $tx -Recurse -Force -ErrorAction SilentlyContinue
      throw ((Get-PMMText 'Delete Mod failed before it could commit. PMM restored the library and game files. Details: ' 'Delete Mod fallo antes de completar el commit. PMM restauro la biblioteca y los archivos del juego. Detalles: ')+$failure)
    }
    $detail=$rollbackErrors.ToArray() -join "`n"
    throw ((Get-PMMText 'Delete Mod failed and rollback was incomplete. Do not launch Palworld yet. Recovery files are preserved in: ' 'Delete Mod fallo y el rollback quedo incompleto. No inicies Palworld todavia. Los archivos de recuperacion se conservaron en: ')+$tx+"`n"+$failure+"`n"+$detail)
  }
}

function Get-PMMManifestSourceSignature($Manifest) {
  if (-not $Manifest) { return '' }
  if ($Manifest.PSObject.Properties.Name -contains 'SourceSignature' -and -not [string]::IsNullOrWhiteSpace([string]$Manifest.SourceSignature)) {
    return [string]$Manifest.SourceSignature
  }
  if ($Manifest.PSObject.Properties.Name -contains 'Sources') {
    return ((@($Manifest.Sources) | ForEach-Object { "{0}:{1}" -f [string]$_.Name,[string]$_.Hash } | Sort-Object) -join '|')
  }
  return ''
}


function Find-PMMManifestForDeployedPak([IO.FileInfo]$Pak) {
  $candidates = New-Object System.Collections.Generic.List[string]
  $candidates.Add($Pak.FullName + '.manifest.json')
  foreach ($area in @('Current','Previous')) {
    $candidates.Add((Join-Path (Join-PMMPath 'Builds' $area) ($Pak.Name+'.manifest.json')))
  }

  # Upgrade/migration convenience: during development and after replacing PMM
  # with a newer portable folder, the deployed PAK may still have its manifest
  # in a neighboring older PMM folder. Search only immediate sibling PMM roots.
  try {
    $parent = Split-Path -Parent $Script:Root
    foreach ($dir in @(Get-ChildItem -LiteralPath $parent -Directory -Filter '*' -ErrorAction SilentlyContinue | Where-Object {$_.Name -like 'PalModMerger*' -or $_.Name -like 'Palworld*Manager*Merger*'})) {
      if ($dir.FullName -eq $Script:Root) { continue }
      foreach ($area in @('Current','Previous')) {
        $newLayout = Join-Path $dir.FullName ("PMM\Workspace\Builds\{0}\{1}.manifest.json" -f $area,$Pak.Name)
        $legacyLayout = Join-Path $dir.FullName ("Builds\{0}\{1}.manifest.json" -f $area,$Pak.Name)
        $candidates.Add($newLayout)
        $candidates.Add($legacyLayout)
      }
    }
  } catch {}

  foreach ($candidate in @($candidates | Select-Object -Unique)) {
    if (Test-Path -LiteralPath $candidate -PathType Leaf) { return $candidate }
  }
  return ($Pak.FullName + '.manifest.json')
}

function Get-PMMDeployedPatches {
  $gameMods = Get-GameModsPath
  if (-not $gameMods -or -not (Test-Path -LiteralPath $gameMods -PathType Container)) { return @() }

  $items = New-Object System.Collections.Generic.List[object]
  foreach ($pak in @(Get-ChildItem -LiteralPath $gameMods -Filter 'zzzzzzzzzz_PMM_Merge_*_P.pak' -File -ErrorAction SilentlyContinue | Sort-Object LastWriteTimeUtc -Descending)) {
    $manifestPath = Find-PMMManifestForDeployedPak $pak
    $manifest = $null
    if (Test-Path -LiteralPath $manifestPath -PathType Leaf) {
      try { $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json } catch { Write-PMMLog "Could not read deployed PMM manifest: $manifestPath :: $($_.Exception.Message)" }
    }

    $patchedMods = @()
    $assetCount = 0
    if ($manifest) {
      if ($manifest.PSObject.Properties.Name -contains 'PatchedMods') { $patchedMods = @($manifest.PatchedMods | ForEach-Object { [string]$_ }) }
      if ($manifest.PSObject.Properties.Name -contains 'Assets') { $assetCount = @($manifest.Assets).Count }
    }

    $hash = Get-Sha256 $pak.FullName
    $manifestHashOk = $false
    if ($manifest -and ($manifest.PSObject.Properties.Name -contains 'OutputHash')) { $manifestHashOk = ([string]$manifest.OutputHash -eq $hash) }

    $items.Add([pscustomobject]@{
      Name=$pak.Name
      Path=$pak.FullName
      Size=$pak.Length
      Hash=$hash
      ManifestPath=$manifestPath
      Manifest=$manifest
      SourceSignature=(Get-PMMManifestSourceSignature $manifest)
      PatchedMods=$patchedMods
      AssetCount=$assetCount
      ManifestHashOk=$manifestHashOk
      Modified=$pak.LastWriteTimeUtc
    })
  }
  return $items.ToArray()
}


function Get-PMMLocalPatchBackupRoot {
  return (Join-PMMPath 'Builds' 'Current')
}

function Get-PMMLocalPatchArea([ValidateSet('Current','Previous')][string]$Area) {
  $root = Join-Path (Get-PMMPath 'Builds') $Area
  if (-not (Test-Path -LiteralPath $root -PathType Container)) { return @() }

  $items = [System.Collections.Generic.List[object]]::new()
  foreach ($pak in @(Get-ChildItem -LiteralPath $root -Filter 'zzzzzzzzzz_PMM_Merge_*_P.pak' -File -ErrorAction SilentlyContinue | Sort-Object LastWriteTimeUtc -Descending)) {
    $manifestPath = $pak.FullName + '.manifest.json'
    $manifest = $null
    if (Test-Path -LiteralPath $manifestPath -PathType Leaf) {
      try { $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json } catch { Write-PMMLog "Could not read local PMM patch manifest: $manifestPath :: $($_.Exception.Message)" }
    }
    $hash = Get-Sha256 $pak.FullName
    $patchedMods = @()
    $assetCount = 0
    if ($manifest) {
      if ($manifest.PSObject.Properties.Name -contains 'PatchedMods') { $patchedMods = @($manifest.PatchedMods | ForEach-Object { [string]$_ }) }
      if ($manifest.PSObject.Properties.Name -contains 'Assets') { $assetCount = @($manifest.Assets).Count }
    }
    $items.Add([pscustomobject]@{
      Name=$pak.Name
      Path=$pak.FullName
      Size=$pak.Length
      Hash=$hash
      ManifestPath=$manifestPath
      Manifest=$manifest
      SourceSignature=(Get-PMMManifestSourceSignature $manifest)
      PatchedMods=$patchedMods
      AssetCount=$assetCount
      Modified=$pak.LastWriteTimeUtc
      LocalArea=$Area
      CurrentLocal=($Area -eq 'Current')
      Deployed=$false
      BackedUp=$true
      BackupPath=$pak.FullName
    })
  }
  return $items.ToArray()
}

function Get-PMMLocalPatchBackups { return @(Get-PMMLocalPatchArea 'Current') }
function Get-PMMArchivedPatchBackups { return @(Get-PMMLocalPatchArea 'Previous') }
function Get-PMMAllLocalPatches {
  return @((@(Get-PMMLocalPatchBackups) + @(Get-PMMArchivedPatchBackups)) | Sort-Object Modified -Descending)
}

function Sync-PMMDeployedPatchBackups {
  <#
  PMM 1.3 lifecycle rule: the game ~mods folder is deployment state, not the
  saved-build library. Merely discovering a deployed PMM merge MUST NOT recreate
  a local build that the user deleted. External deployed merges are recognized
  by Get-PMMDeployedPatches and shown as DEPLOYED / EXTERNAL ONLY until the user
  explicitly imports or rebuilds them.
  #>
  return 0
}

function Get-PMMManagedPatches {
  <#
  Return deployed + saved Current/Previous patches, de-duplicated by filename.
  IMPORTANT: this is discovery only. It never copies a deployed PAK back into
  PMM's saved-build library.
  #>
  $deployed = @(Get-PMMDeployedPatches)
  $locals = @(Get-PMMAllLocalPatches)
  $byName = @{}

  foreach ($patch in $deployed) {
    $matchingLocals=@($locals|Where-Object{$_.Name -eq $patch.Name})
    $local=@($matchingLocals|Where-Object{$_.LocalArea -eq 'Current'}|Select-Object -First 1)[0]
    if(-not$local){$local=@($matchingLocals|Sort-Object Modified -Descending|Select-Object -First 1)[0]}
    $backupOk = $false
    $backupPath = ''
    $localArea = 'DeployedOnly'
    $currentLocal = $false
    if ($local) {
      $backupPath = [string]$local.Path
      $backupOk = ([string]$local.Hash -eq [string]$patch.Hash)
      $localArea = [string]$local.LocalArea
      $currentLocal = [bool]$local.CurrentLocal
    }
    $byName[$patch.Name.ToLowerInvariant()] = [pscustomobject]@{
      Name=$patch.Name;Path=$patch.Path;Size=$patch.Size;Hash=$patch.Hash
      ManifestPath=$patch.ManifestPath;Manifest=$patch.Manifest;SourceSignature=$patch.SourceSignature
      PatchedMods=@($patch.PatchedMods);AssetCount=$patch.AssetCount;ManifestHashOk=$patch.ManifestHashOk
      Modified=$patch.Modified;Deployed=$true;BackedUp=$backupOk;BackupPath=$backupPath
      LocalArea=$localArea;CurrentLocal=$currentLocal
    }
  }

  foreach ($local in $locals) {
    $key = $local.Name.ToLowerInvariant()
    if ($byName.ContainsKey($key)) { continue }
    $manifestHashOk = $false
    if ($local.Manifest -and ($local.Manifest.PSObject.Properties.Name -contains 'OutputHash')) {
      $manifestHashOk = ([string]$local.Manifest.OutputHash -eq [string]$local.Hash)
    }
    $byName[$key] = [pscustomobject]@{
      Name=$local.Name;Path=$local.Path;Size=$local.Size;Hash=$local.Hash
      ManifestPath=$local.ManifestPath;Manifest=$local.Manifest;SourceSignature=$local.SourceSignature
      PatchedMods=@($local.PatchedMods);AssetCount=$local.AssetCount;ManifestHashOk=$manifestHashOk
      Modified=$local.Modified;Deployed=$false;BackedUp=$true;BackupPath=$local.Path
      LocalArea=[string]$local.LocalArea;CurrentLocal=[bool]$local.CurrentLocal
    }
  }

  return @($byName.Values | Sort-Object Modified -Descending)
}

function Test-PMMDeployedPatchCurrent($Patch,[array]$SourceMods) {
  return (Test-PMMPatchCurrent $Patch $SourceMods)
}

function Get-PMMCurrentDeployedPatch([array]$SourceMods) {
  foreach ($patch in @(Get-PMMDeployedPatches)) {
    if (Test-PMMDeployedPatchCurrent $patch $SourceMods) { return $patch }
  }
  return $null
}



function Test-PMMPatchCurrent($Patch,[array]$SourceMods) {
  if (-not(Test-PMMPatchRuntimeCompatible $Patch $SourceMods)) { return $false }
  $sourceSignature = Get-PMMLibrarySignature $SourceMods
  if ([string]$Patch.SourceSignature -cne [string]$sourceSignature) {
    $currentPlan=Get-PMMCurrentPlanForPatchCompatibility $SourceMods
    return ($null -ne $currentPlan -and (Test-PMMPatchPlanCompatible $Patch $currentPlan $SourceMods))
  }

  # A true-conflict choice is part of the output identity just like the source
  # hashes. After a forced Remerge the source mods may be unchanged while the
  # user selects a different provider for one byte/property. In that case an
  # older local patch must not keep Build disabled merely because its source
  # signature still matches.
  $planPath=Join-PMMPath 'State' 'merge-plan.json'
  if(Test-Path -LiteralPath $planPath -PathType Leaf){
    try{
      $plan=Get-Content -LiteralPath $planPath -Raw|ConvertFrom-Json
      $isShortCircuit=($plan.PSObject.Properties.Name -contains 'AlreadyPatched' -and [bool]$plan.AlreadyPatched)
      if(-not$isShortCircuit -and [string]$plan.SourceSignature -eq [string]$sourceSignature){
        $planRows=@($plan.Rows)
        if($planRows.Count -gt 0 -and -not($Patch.Manifest.PSObject.Properties.Name -contains 'DecisionSignature')){return $false}
        if($Patch.Manifest.PSObject.Properties.Name -contains 'DecisionSignature'){
          $decisionCommand=Get-Command Get-PMMDecisionSignature -ErrorAction SilentlyContinue
          if($decisionCommand){
            $currentDecisionSignature=Get-PMMDecisionSignature $planRows
            if([string]$Patch.Manifest.DecisionSignature -ne [string]$currentDecisionSignature){return $false}
          }
        }
      }
    }catch{return $false}
  }
  return $true
}

function Test-PMMPatchSourceSetCompatible($Patch,[array]$SourceMods) {
  if (-not $Patch -or -not $Patch.Manifest -or -not $Patch.ManifestHashOk) { return $false }
  $sourceSignature = Get-PMMLibrarySignature $SourceMods
  if ([string]$Patch.SourceSignature -ne [string]$sourceSignature) { return $false }
  if(-not($Patch.Manifest.PSObject.Properties.Name -contains 'VanillaSourceSignature')){return $false}
  $vanillaSigCommand=Get-Command Get-PMMVanillaPakSetQuickSignature -ErrorAction SilentlyContinue
  if(-not$vanillaSigCommand -or [string]$Patch.Manifest.VanillaSourceSignature -ne (Get-PMMVanillaPakSetQuickSignature)){return $false}
  if ($Patch.Manifest.PSObject.Properties.Name -contains 'MappingsSha256') {
    $map = Get-PMMMappingsPath
    if (-not (Test-Path -LiteralPath $map -PathType Leaf)) { return $false }
    if ([string]$Patch.Manifest.MappingsSha256 -ne (Get-Sha256 $map)) { return $false }
  }
  return $true
}

function Get-PMMSelectedPatchName {
  try {
    $cfg=Get-PMMConfig
    if($cfg.PSObject.Properties.Name -contains 'SelectedPatchName'){return [string]$cfg.SelectedPatchName}
  } catch {}
  return ''
}

function Get-PMMNoPatchSelectionName { return '__PMM_NO_COMPATIBILITY_PATCH__' }
function Test-PMMNoPatchSelected { return ([string](Get-PMMSelectedPatchName) -eq [string](Get-PMMNoPatchSelectionName)) }

function Set-PMMSelectedPatchName([string]$Name) {
  $cfg=Get-PMMConfig
  if(-not($cfg.PSObject.Properties.Name -contains 'SelectedPatchName')){$cfg|Add-Member -NotePropertyName SelectedPatchName -NotePropertyValue ''}
  $cfg.SelectedPatchName=[string]$Name
  Save-PMMConfig $cfg
}


function Test-PMMManifestOutputHash([string]$ManifestPath,[string]$ExpectedHash) {
  if([string]::IsNullOrWhiteSpace($ManifestPath) -or -not(Test-Path -LiteralPath $ManifestPath -PathType Leaf)){return $false}
  try{
    $doc=Get-Content -LiteralPath $ManifestPath -Raw|ConvertFrom-Json
    if($doc -and ($doc.PSObject.Properties.Name -contains 'OutputHash')){
      return (([string]$doc.OutputHash).ToLowerInvariant() -eq ([string]$ExpectedHash).ToLowerInvariant())
    }
  }catch{}
  return $false
}

function Move-PMMMergeFilesTransactional([array]$Paths,[string]$Purpose) {
  $items=@($Paths|Where-Object{$_ -and (Test-Path -LiteralPath ([string]$_) -PathType Leaf)}|Select-Object -Unique)
  if($items.Count -eq 0){return [pscustomobject]@{Count=0;Transaction=''}}
  $tx=Join-Path (Get-PMMPath 'Cache') (('{0}_{1}' -f $Purpose,[guid]::NewGuid().ToString('N')))
  New-Item -ItemType Directory -Force -Path $tx|Out-Null
  $moved=[System.Collections.Generic.List[object]]::new()
  try{
    $i=0
    foreach($src in $items){
      $i++
      $dst=Join-Path $tx (('{0:D3}_{1}' -f $i,[IO.Path]::GetFileName([string]$src)))
      Move-Item -LiteralPath ([string]$src) -Destination $dst -Force
      $moved.Add([pscustomobject]@{Original=[string]$src;Trash=$dst})
    }
    # Original paths are now clean. Trash cleanup is best-effort; a cleanup
    # failure must not trigger a fake rollback after some trash files may have
    # already been deleted by Windows.
    try{Remove-Item -LiteralPath $tx -Recurse -Force -ErrorAction Stop}catch{Write-PMMLog ('Merge lifecycle trash cleanup warning: '+$_.Exception.Message)}
    return [pscustomobject]@{Count=$moved.Count;Transaction=$tx}
  }catch{
    $failure=$_.Exception.Message
    $rollbackRows=@($moved.ToArray())
    for($ri=$rollbackRows.Count-1;$ri -ge 0;$ri--){
      $row=$rollbackRows[$ri]
      try{
        if(Test-Path -LiteralPath ([string]$row.Trash) -PathType Leaf){
          $parent=Split-Path -Parent ([string]$row.Original);if($parent){New-Item -ItemType Directory -Force -Path $parent|Out-Null}
          Move-Item -LiteralPath ([string]$row.Trash) -Destination ([string]$row.Original) -Force
        }
      }catch{Write-PMMLog ('Merge lifecycle rollback warning: '+$_.Exception.Message)}
    }
    Remove-Item -LiteralPath $tx -Recurse -Force -ErrorAction SilentlyContinue
    throw ((Get-PMMText 'Merge file operation failed and PMM rolled back the files it had already moved. Details: ' 'Fallo la operacion de archivos del merge y PMM revirtio los archivos que ya habia movido. Detalles: ')+$failure)
  }
}

function Undeploy-PMMManagedPatch($Patch) {
  if(-not$Patch){throw (Get-PMMText 'Select a merge first.' 'Selecciona primero un merge.')}
  $name=[string]$Patch.Name
  $hash=([string]$Patch.Hash).ToLowerInvariant()
  if([string]::IsNullOrWhiteSpace($name) -or [string]::IsNullOrWhiteSpace($hash)){throw 'Selected merge has no stable name/hash identity.'}
  $gameMods=Get-GameModsPath
  if(-not$gameMods -or -not(Test-Path -LiteralPath $gameMods -PathType Container)){return [pscustomobject]@{Removed=$false;Name=$name;Reason='game-mods-unavailable'}}
  $gamePak=Join-Path $gameMods $name
  if(-not(Test-Path -LiteralPath $gamePak -PathType Leaf)){return [pscustomobject]@{Removed=$false;Name=$name;Reason='not-deployed'}}
  $actual=(Get-Sha256 $gamePak).ToLowerInvariant()
  if($actual -ne $hash){
    throw ((Get-PMMText "PMM will not undeploy '{0}' because the file in ~mods is not the selected PMM-managed merge. Existing SHA-256: {1}; expected: {2}." "PMM no retirara '{0}' porque el archivo de ~mods no es el merge seleccionado gestionado por PMM. SHA-256 existente: {1}; esperado: {2}.") -f $name,$actual,$hash)
  }
  $targets=[System.Collections.Generic.List[string]]::new();$targets.Add($gamePak)
  $sidecar=$gamePak+'.manifest.json'
  if(Test-Path -LiteralPath $sidecar -PathType Leaf){
    # The PAK identity is already exact and the sidecar lives in PMM's reserved
    # namespace beside it, so it belongs to this deployment even if malformed.
    $targets.Add($sidecar)
  }
  [void](Move-PMMMergeFilesTransactional @($targets.ToArray()) 'UndeployMerge')
  Write-PMMLog ('Undeployed compatibility merge from Palworld ~mods only: '+$name+' | '+$hash)
  return [pscustomobject]@{Removed=$true;Name=$name;Hash=$hash;Reason='undeployed'}
}

function Remove-PMMManagedPatch($Patch) {
  <#
  DELETE lifecycle contract:
    * remove the exact deployed copy from Palworld ~mods when present;
    * remove every exact saved copy from Builds\Current / Builds\Previous;
    * remove matching sidecars, selection state and runtime-validation record;
    * never touch a same-name PAK whose hash does not match the selected merge.
  #>
  if(-not$Patch){throw (Get-PMMText 'Select a merge first.' 'Selecciona primero un merge.')}
  $name=[string]$Patch.Name
  $hash=([string]$Patch.Hash).ToLowerInvariant()
  if([string]::IsNullOrWhiteSpace($name) -or [string]::IsNullOrWhiteSpace($hash)){throw 'Selected merge has no stable name/hash identity.'}

  $targets=[System.Collections.Generic.List[string]]::new()
  $gameRemoved=$false;$localRemoved=0

  # Preflight the game copy. If a same-name foreign file exists, abort before
  # deleting the saved master: Delete promises to remove both managed states.
  $gameMods=Get-GameModsPath
  if($gameMods -and (Test-Path -LiteralPath $gameMods -PathType Container)){
    $gamePak=Join-Path $gameMods $name
    if(Test-Path -LiteralPath $gamePak -PathType Leaf){
      $actual=(Get-Sha256 $gamePak).ToLowerInvariant()
      if($actual -ne $hash){
        throw ((Get-PMMText "Delete stopped: '{0}' exists in ~mods but its hash does not match the selected merge. PMM will not delete either copy until that identity conflict is resolved. Existing SHA-256: {1}; expected: {2}." "Delete detenido: '{0}' existe en ~mods pero su hash no coincide con el merge seleccionado. PMM no borrara ninguna copia hasta resolver ese conflicto de identidad. SHA-256 existente: {1}; esperado: {2}.") -f $name,$actual,$hash)
      }
      $targets.Add($gamePak);$gameRemoved=$true
      $side=$gamePak+'.manifest.json';if(Test-Path -LiteralPath $side -PathType Leaf){$targets.Add($side)}
    }
  }

  # Saved library copies. Same filename with a different hash is deliberately
  # retained rather than silently deleting a different build.
  foreach($area in @('Current','Previous')){
    $root=Join-Path (Get-PMMPath 'Builds') $area
    if(-not(Test-Path -LiteralPath $root -PathType Container)){continue}
    $localPak=Join-Path $root $name
    if(Test-Path -LiteralPath $localPak -PathType Leaf){
      $actual=(Get-Sha256 $localPak).ToLowerInvariant()
      if($actual -eq $hash){
        $targets.Add($localPak);$localRemoved++
        $side=$localPak+'.manifest.json';if(Test-Path -LiteralPath $side -PathType Leaf){$targets.Add($side)}
      }else{
        Write-PMMLog ('Delete merge kept same-name local build because hash differs: '+$localPak+' | '+$actual+' != '+$hash)
      }
    }else{
      # Clean an orphan manifest only when it identifies this exact output hash.
      $side=$localPak+'.manifest.json'
      if(Test-PMMManifestOutputHash $side $hash){$targets.Add($side)}
    }
  }

  [void](Move-PMMMergeFilesTransactional @($targets.ToArray()) 'DeleteMerge')

  if([string](Get-PMMSelectedPatchName) -ieq $name){Set-PMMSelectedPatchName ''}
  try{[void](Remove-PMMMergeValidationByHash $hash)}catch{Write-PMMLog ('Could not remove merge validation record after Delete: '+$_.Exception.Message)}
  Write-PMMLog ('Deleted compatibility merge lifecycle: '+$name+' | hash='+$hash+' | gameRemoved='+$gameRemoved+' | localCopies='+$localRemoved)
  return [pscustomobject]@{Deleted=$true;Name=$name;Hash=$hash;GameRemoved=[bool]$gameRemoved;LocalCopiesRemoved=[int]$localRemoved;FilesRemoved=@($targets.ToArray()).Count}
}

function Get-PMMSelectedManagedPatch([array]$SourceMods) {
  if(Test-PMMNoPatchSelected){return $null}
  $all=@(Get-PMMManagedPatches)
  $currentPlan=Get-PMMCurrentPlanForPatchCompatibility $SourceMods
  $compatible=@($all|Where-Object{
    (Test-PMMPatchSourceSetCompatible $_ $SourceMods) -or ($currentPlan -and (Test-PMMPatchPlanCompatible $_ $currentPlan $SourceMods))
  }|Sort-Object Modified -Descending)
  if($compatible.Count -eq 0){return $null}

  $preferred=Get-PMMSelectedPatchName
  if(-not[string]::IsNullOrWhiteSpace($preferred)){
    $hit=@($compatible|Where-Object{[string]$_.Name -ieq [string]$preferred}|Select-Object -First 1)[0]
    if($hit){return $hit}
  }

  # Auto-select only a patch whose effective shared-provider order and current
  # conflict decisions still match. Reordering unrelated source mods does not
  # invalidate a patch; changing order inside one shared asset can.
  $currentMatch=@($compatible|Where-Object{Test-PMMPatchCurrent $_ $SourceMods}|Select-Object -First 1)[0]
  if($currentMatch){return $currentMatch}
  return $null
}

function Get-PMMExactDuplicateSuppressions([array]$ActiveMods) {
  $suppressed=[System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
  foreach($group in @($ActiveMods|Group-Object Hash)){
    $items=@($group.Group|Sort-Object Name)
    if($items.Count -le 1){continue}
    foreach($duplicate in @($items|Select-Object -Skip 1)){[void]$suppressed.Add([string]$duplicate.Name)}
  }
  return @($suppressed|Sort-Object)
}

function Get-PMMPatchDeploymentSuppressions([array]$ActiveMods,$Patch,$Plan) {
  if(-not$Patch -or -not$Patch.Manifest){return @(Get-PMMDeploymentSuppressions $ActiveMods $Plan)}
  $suppressed=[System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
  $hasPersisted=$Patch.Manifest.PSObject.Properties.Name -contains 'DeploymentSuppressions'
  if($hasPersisted){
    foreach($name in @($Patch.Manifest.DeploymentSuppressions)){
      if(-not[string]::IsNullOrWhiteSpace([string]$name)){[void]$suppressed.Add([string]$name)}
    }
  }elseif(($Patch.Manifest.PSObject.Properties.Name -contains 'Assets') -and ($Patch.Manifest.PSObject.Properties.Name -contains 'Decisions')){
    # Migration bridge for older manifests: reconstruct only the same proven
    # pure-alternative suppression logic from the decisions stored in the patch.
    $legacy=[pscustomobject]@{Assets=@($Patch.Manifest.Assets);Rows=@($Patch.Manifest.Decisions)}
    foreach($name in @(Get-PMMDeploymentSuppressions $ActiveMods $legacy)){[void]$suppressed.Add([string]$name)}
  }
  foreach($name in @(Get-PMMExactDuplicateSuppressions $ActiveMods)){[void]$suppressed.Add([string]$name)}
  return @($suppressed|Sort-Object)
}

function Promote-PMMPatchToCurrent([string]$Name) {
  if([string]::IsNullOrWhiteSpace($Name)){return}
  $patch=@(Get-PMMManagedPatches|Where-Object{[string]$_.Name -ieq [string]$Name}|Select-Object -First 1)[0]
  if(-not$patch){throw "Managed PMM patch not found: $Name"}

  $source=''
  if(-not[string]::IsNullOrWhiteSpace([string]$patch.BackupPath) -and (Test-Path -LiteralPath ([string]$patch.BackupPath) -PathType Leaf)){$source=[string]$patch.BackupPath}
  elseif(Test-Path -LiteralPath ([string]$patch.Path) -PathType Leaf){$source=[string]$patch.Path}
  if([string]::IsNullOrWhiteSpace($source)){throw "No local/deployed copy is available for patch: $Name"}

  $currentRoot=Join-PMMPath 'Builds' 'Current'
  $previousRoot=Join-PMMPath 'Builds' 'Previous'
  New-Item -ItemType Directory -Force -Path $currentRoot,$previousRoot|Out-Null
  $target=Join-Path $currentRoot $Name

  foreach($old in @(Get-ChildItem -LiteralPath $currentRoot -Filter 'zzzzzzzzzz_PMM_Merge_*_P.pak' -File -ErrorAction SilentlyContinue)){
    if($old.Name -ieq $Name){continue}
    $dst=Join-Path $previousRoot $old.Name
    Move-Item -LiteralPath $old.FullName -Destination $dst -Force
    $side=$old.FullName+'.manifest.json'
    if(Test-Path -LiteralPath $side -PathType Leaf){Move-Item -LiteralPath $side -Destination ($dst+'.manifest.json') -Force}
  }

  if([IO.Path]::GetFullPath($source) -ne [IO.Path]::GetFullPath($target)){
    if(Test-Path -LiteralPath $target -PathType Leaf){Remove-Item -LiteralPath $target -Force}
    $sourceUnderRoot=$false
    try{$sourceUnderRoot=([IO.Path]::GetFullPath($source).StartsWith(([IO.Path]::GetFullPath($Script:Root)+[IO.Path]::DirectorySeparatorChar),[StringComparison]::OrdinalIgnoreCase))}catch{}
    if($sourceUnderRoot){Move-Item -LiteralPath $source -Destination $target -Force}else{Copy-Item -LiteralPath $source -Destination $target -Force}

    $manifestSource=''
    $localSidecar=$source+'.manifest.json'
    if(Test-Path -LiteralPath $localSidecar -PathType Leaf){$manifestSource=$localSidecar}
    elseif(-not[string]::IsNullOrWhiteSpace([string]$patch.ManifestPath) -and (Test-Path -LiteralPath ([string]$patch.ManifestPath) -PathType Leaf)){$manifestSource=[string]$patch.ManifestPath}
    if($manifestSource){
      $manifestTarget=$target+'.manifest.json'
      if([IO.Path]::GetFullPath($manifestSource) -ne [IO.Path]::GetFullPath($manifestTarget)){
        if(Test-Path -LiteralPath $manifestTarget -PathType Leaf){Remove-Item -LiteralPath $manifestTarget -Force}
        $manifestUnderRoot=$false
        try{$manifestUnderRoot=([IO.Path]::GetFullPath($manifestSource).StartsWith(([IO.Path]::GetFullPath($Script:Root)+[IO.Path]::DirectorySeparatorChar),[StringComparison]::OrdinalIgnoreCase))}catch{}
        if($manifestUnderRoot){Move-Item -LiteralPath $manifestSource -Destination $manifestTarget -Force}else{Copy-Item -LiteralPath $manifestSource -Destination $manifestTarget -Force}
      }
    }
  }

  $cfg=Get-PMMConfig
  $cfg.LastBuild=$Name
  if(-not($cfg.PSObject.Properties.Name -contains 'SelectedPatchName')){$cfg|Add-Member -NotePropertyName SelectedPatchName -NotePropertyValue ''}
  $cfg.SelectedPatchName=$Name
  Save-PMMConfig $cfg
  Write-PMMLog "Selected PMM patch promoted to Builds\Current after Deploy: $Name"
}

function Get-PMMCurrentLocalPatch([array]$SourceMods) {
  foreach($patch in @(Get-PMMLocalPatchBackups)){
    $manifestHashOk=$false
    if($patch.Manifest -and ($patch.Manifest.PSObject.Properties.Name -contains 'OutputHash')){
      $manifestHashOk=([string]$patch.Manifest.OutputHash -eq [string]$patch.Hash)
    }
    $candidate=[pscustomobject]@{
      Name=$patch.Name;Path=$patch.Path;Size=$patch.Size;Hash=$patch.Hash;ManifestPath=$patch.ManifestPath;Manifest=$patch.Manifest;
      SourceSignature=$patch.SourceSignature;PatchedMods=@($patch.PatchedMods);AssetCount=$patch.AssetCount;ManifestHashOk=$manifestHashOk;Modified=$patch.Modified;
      Deployed=$false;BackedUp=$true;BackupPath=$patch.Path
    }
    if(Test-PMMPatchCurrent $candidate $SourceMods){return $candidate}
  }
  return $null
}

function Get-PMMCurrentManagedPatch([array]$SourceMods) {
  foreach($patch in @(Get-PMMManagedPatches)){if(Test-PMMPatchCurrent $patch $SourceMods){return $patch}}
  return $null
}

function Get-PMMDeploymentStatePath { return (Join-PMMPath 'State' 'deployment-state.json') }
function Read-PMMDeploymentState {
  $p=Get-PMMDeploymentStatePath
  if(-not(Test-Path -LiteralPath $p -PathType Leaf)){return $null}
  try{return (Get-Content -LiteralPath $p -Raw|ConvertFrom-Json)}catch{return $null}
}
function Write-PMMDeploymentState($State){
  $path=Get-PMMDeploymentStatePath
  $temp=$path+'.tmp'
  $State|ConvertTo-Json -Depth 20|Set-Content -LiteralPath $temp -Encoding UTF8
  Move-Item -LiteralPath $temp -Destination $path -Force
}

function Test-PMMModContainsOnlyAssetFamily($Mod,[string]$Asset) {
  if(-not$Mod -or [string]::IsNullOrWhiteSpace($Asset)){return $false}
  try{
    $stem=(Get-PakLogicalStem $Asset).ToLowerInvariant()
    $allowed=[System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach($ext in @('.uasset','.uexp','.ubulk')){[void]$allowed.Add($stem+$ext)}
    $entries=@(Get-PakEntriesCached $Mod.Path)
    if($entries.Count -eq 0){return $false}
    foreach($entry in $entries){
      $normalized=(Normalize-PakLogicalPath ([string]$entry)).ToLowerInvariant()
      if(-not$allowed.Contains($normalized)){return $false}
    }
    return $true
  }catch{return $false}
}

function Get-PMMPackageChoiceDeploymentSuppressions($Plan) {
  $suppressed=[System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
  if(-not$Plan -or -not($Plan.PSObject.Properties.Name -contains 'Rows')){return @()}
  foreach($row in @($Plan.Rows|Where-Object{($_.PSObject.Properties.Name -contains 'DecisionKind') -and [string]$_.DecisionKind -eq 'PackageChoice'})){
    $selected=[string]$row.SelectedChoice
    if([string]::IsNullOrWhiteSpace($selected) -or -not($row.PSObject.Properties.Name -contains 'PackageChoices')){continue}
    $choice=@($row.PackageChoices|Where-Object{[string]$_.Choice -eq $selected}|Select-Object -First 1)[0]
    if(-not$choice){continue}
    foreach($name in @($choice.Suppressed)){
      if(-not[string]::IsNullOrWhiteSpace([string]$name)){[void]$suppressed.Add([string]$name)}
    }
  }
  return @($suppressed|Sort-Object)
}

function Get-PMMDeploymentSuppressions([array]$ActiveMods,$Plan) {
  $suppressed=[System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)

  # A current-patch Analyze may short-circuit without rebuilding the original
  # conflict rows. Preserve the already-proven deployment decision instead of
  # accidentally re-installing an unselected pure alternative on the next Deploy.
  if($Plan -and ($Plan.PSObject.Properties.Name -contains 'DeploymentSuppressions')){
    foreach($name in @($Plan.DeploymentSuppressions)){
      if(-not[string]::IsNullOrWhiteSpace([string]$name)){[void]$suppressed.Add([string]$name)}
    }
  }
  foreach($name in @(Get-PMMPackageChoiceDeploymentSuppressions $Plan)){
    [void]$suppressed.Add([string]$name)
  }

  # Exact duplicate PAKs: keep one deterministic copy for deployment while all
  # copies remain in the PMM library for future Analyze/Remerge operations.
  foreach($group in @($ActiveMods|Group-Object Hash)){
    $items=@($group.Group|Sort-Object Name)
    if($items.Count -le 1){continue}
    foreach($duplicate in @($items|Select-Object -Skip 1)){[void]$suppressed.Add([string]$duplicate.Name)}
  }

  if(-not$Plan -or -not($Plan.PSObject.Properties.Name -contains 'Assets') -or -not($Plan.PSObject.Properties.Name -contains 'Rows')){
    return @($suppressed|Sort-Object)
  }

  foreach($assetPlan in @($Plan.Assets|Where-Object{$_.Mode -eq 'RelocatableConflict'})){
    $rows=@()
    if($assetPlan.PSObject.Properties.Name -contains 'AssetKey' -and -not[string]::IsNullOrWhiteSpace([string]$assetPlan.AssetKey)){
      $rows=@($Plan.Rows|Where-Object{[string]$_.AssetKey -eq [string]$assetPlan.AssetKey})
    }elseif($assetPlan.PSObject.Properties.Name -contains 'Asset'){
      # Preview28 manifests did not persist AssetKey in Assets, but their full
      # Decisions rows do persist Asset. This fallback lets preview29 recover
      # suppression semantics from an already-built preview28 patch.
      $rows=@($Plan.Rows|Where-Object{[string]$_.Asset -eq [string]$assetPlan.Asset})
    }

    # Quasi-duplicate suppression is only proven for a single alternative
    # conflict. Multi-conflict structural variants remain deployed until a
    # semantic adapter can prove which common edits belong to which property.
    if($rows.Count -ne 1){continue}
    $row=$rows[0]
    $choice=[string]$row.SelectedChoice
    if([string]::IsNullOrWhiteSpace($choice)){continue}
    $competitors=@($row.CompetingMods|ForEach-Object{[string]$_}|Where-Object{$_}|Sort-Object -Unique)
    if($competitors.Count -lt 2){continue}

    foreach($name in $competitors){
      $mod=@($ActiveMods|Where-Object{$_.Name -eq $name}|Select-Object -First 1)[0]
      if(-not$mod){continue}
      if(-not (Test-PMMModContainsOnlyAssetFamily $mod ([string]$row.Asset))){continue}

      if($choice -eq 'Vanilla' -or $choice -eq 'Custom' -or $name -ne $choice){
        [void]$suppressed.Add($name)
      }
    }
  }
  return @($suppressed|Sort-Object)
}

function Test-PMMPlanRequiresPatch($Plan) {
  if(-not$Plan){return $false}
  if($Plan.PSObject.Properties.Name -contains 'AlreadyPatched' -and [bool]$Plan.AlreadyPatched){return $true}
  if($Plan.PSObject.Properties.Name -contains 'Assets'){
    return (@($Plan.Assets|Where-Object{$_.Mode -notin @('Identical','PackageChoice')}).Count -gt 0)
  }
  return $false
}

function Get-PMMDeploymentContext {
  $cfg=Get-PMMConfig
  if(-not$cfg.GamePath){throw (Get-PMMText 'Detect or configure Palworld before Deploy.' 'Detecta o configura Palworld antes de Deploy.')}
  Ensure-GameModsFolder
  $active=@(Get-LibraryMods)
  $disabled=@(Get-PMMDisabledMods)
  if($active.Count -eq 0){throw (Get-PMMText 'There are no active source mods to deploy.' 'No hay mods fuente activos para desplegar.')}

  $signature=Get-PMMLibrarySignature $active
  $noPatchSelected=Test-PMMNoPatchSelected
  $selectedPatch=if($noPatchSelected){$null}else{Get-PMMSelectedManagedPatch $active}
  $planPath=Join-PMMPath 'State' 'merge-plan.json'
  $plan=$null
  if(Test-Path -LiteralPath $planPath -PathType Leaf){try{$plan=Get-Content -LiteralPath $planPath -Raw|ConvertFrom-Json}catch{}}

  # Manager-only mode is intentionally usable without Analyze. A previously
  # saved compatibility patch is also deployable without Analyze when its own
  # manifest proves the exact active source hashes + mappings and its output
  # hash is valid. Analyze remains the gate for creating a new Build plan.
  $planCurrent=$false
  if($plan -and [string]$plan.SourceSignature -eq [string]$signature){
    $planCurrent=$true
    $planCurrentCommand=Get-Command Test-PMMMergePlanCurrent -ErrorAction SilentlyContinue
    if($planCurrentCommand -and -not(Test-PMMMergePlanCurrent)){$planCurrent=$false}
  }
  $effectivePlan=if($planCurrent){$plan}else{$null}

  if($effectivePlan -and ($effectivePlan.PSObject.Properties.Name -contains 'PackageChoicePendingReanalysis') -and [bool]$effectivePlan.PackageChoicePendingReanalysis){
    throw (Get-PMMText 'A package variant was selected but the source set has not been re-analyzed yet. Run Analyze again before Deploy.' 'Se eligio una variante de paquete, pero el conjunto fuente aun no se ha vuelto a analizar. Ejecuta Analizar otra vez antes de Deploy.')
  }
  $unresolvedPackageRows=@()
  if($effectivePlan -and ($effectivePlan.PSObject.Properties.Name -contains 'Rows')){
    $unresolvedPackageRows=@($effectivePlan.Rows|Where-Object{($_.PSObject.Properties.Name -contains 'DecisionKind') -and [string]$_.DecisionKind -eq 'PackageChoice' -and [string]::IsNullOrWhiteSpace([string]$_.SelectedChoice)})
  }
  if($unresolvedPackageRows.Count -gt 0){
    throw (Get-PMMText 'Resolve the package variant decision and run Analyze again before Deploy.' 'Resuelve la decision de variante del paquete y vuelve a ejecutar Analizar antes de Deploy.')
  }

  if(-not$noPatchSelected -and -not$selectedPatch -and -not$effectivePlan){
    throw (Get-PMMText 'The active mod list has not been analyzed and no saved patch matches the exact active source hashes + mappings. Run Analyze first.' 'La lista de mods activa no se ha analizado y ningun parche guardado coincide exactamente con los hashes de fuentes activos + mappings. Ejecuta Analizar primero.')
  }

  $requiresPatch=if($selectedPatch){$true}elseif($effectivePlan){Test-PMMPlanRequiresPatch $effectivePlan}else{$false}
  $patch=$selectedPatch
  if(-not$noPatchSelected -and $requiresPatch -and -not$patch){
    throw (Get-PMMText 'This analyzed set requires a compatibility patch. Build one or select a saved patch that matches this exact active source set.' 'Este conjunto analizado requiere un parche de compatibilidad. Crea uno o selecciona un parche guardado que coincida exactamente con este conjunto activo.')
  }

  if($noPatchSelected){
    $suppressionSet=[System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach($name in @(Get-PMMExactDuplicateSuppressions $active)){[void]$suppressionSet.Add([string]$name)}
    foreach($name in @(Get-PMMPackageChoiceDeploymentSuppressions $effectivePlan)){[void]$suppressionSet.Add([string]$name)}
    $suppressed=@($suppressionSet|Sort-Object)
  }else{
    $suppressed=@(Get-PMMPatchDeploymentSuppressions $active $patch $effectivePlan)
  }
  $deployActive=@($active|Where-Object{[string]$_.Name -notin $suppressed})
  return [pscustomobject]@{
    Config=$cfg;Active=$active;Disabled=$disabled;Signature=$signature;Plan=$effectivePlan;Patch=$patch;RequiresPatch=$requiresPatch;NoPatchSelected=$noPatchSelected;
    Suppressed=$suppressed;DeployActive=$deployActive;Previous=(Read-PMMDeploymentState);GameMods=(Get-GameModsPath)
  }
}

function Add-PMMRemovalExpectation($Map,[string]$Name,[string]$Hash,[string]$Reason) {
  if(-not(Test-PMMSafePakLeafName $Name)){return}
  if(-not$Map.ContainsKey($Name)){
    $Map[$Name]=[pscustomobject]@{
      Name=$Name
      Hashes=(New-Object System.Collections.Generic.List[string])
      Reasons=(New-Object System.Collections.Generic.List[string])
    }
  }
  if(-not[string]::IsNullOrWhiteSpace($Hash)){
    $h=$Hash.ToLowerInvariant()
    if(-not$Map[$Name].Hashes.Contains($h)){$Map[$Name].Hashes.Add($h)}
  }
  if(-not[string]::IsNullOrWhiteSpace($Reason) -and -not$Map[$Name].Reasons.Contains($Reason)){$Map[$Name].Reasons.Add($Reason)}
}

function Add-PMMFileAction($List,$Seen,[string]$Path,[string]$Reason) {
  if([string]::IsNullOrWhiteSpace($Path)){return}
  $key=$Path.ToLowerInvariant()
  if($Seen.Contains($key)){return}
  [void]$Seen.Add($key)
  $List.Add([pscustomobject]@{Path=$Path;Reason=$Reason})
}

function New-PMMDeploymentOperationPlan($Context) {
  $gameMods=[string]$Context.GameMods
  $previous=$Context.Previous
  $previousHashes=@{}
  if($previous -and ($previous.PSObject.Properties.Name -contains 'SourceMods')){
    foreach($m in @($previous.SourceMods)){
      $name=[string]$m.Name
      if(-not(Test-PMMSafePakLeafName $name)){continue}
      $wasDeployed=$true
      if($m.PSObject.Properties.Name -contains 'Deployed'){$wasDeployed=[bool]$m.Deployed}
      if($wasDeployed -and -not[string]::IsNullOrWhiteSpace([string]$m.Hash)){$previousHashes[$name]=([string]$m.Hash).ToLowerInvariant()}
    }
  }

  $removalMap=@{}
  foreach($name in @($Context.Suppressed)){
    $mod=@($Context.Active|Where-Object{[string]$_.Name -ieq [string]$name}|Select-Object -First 1)[0]
    Add-PMMRemovalExpectation $removalMap ([string]$name) $(if($mod){[string]$mod.Hash}else{''}) 'suppressed alternative'
  }
  foreach($mod in @($Context.Disabled)){Add-PMMRemovalExpectation $removalMap ([string]$mod.Name) ([string]$mod.Hash) 'disabled source mod'}
  foreach($record in @(Get-PMMPendingRemovalRecords)){Add-PMMRemovalExpectation $removalMap ([string]$record.Name) ([string]$record.Hash) 'deleted from PMM library'}

  $desiredNames=@($Context.DeployActive|ForEach-Object{[string]$_.Name})
  if($previous -and ($previous.PSObject.Properties.Name -contains 'SourceMods')){
    foreach($m in @($previous.SourceMods)){
      $name=[string]$m.Name
      $wasDeployed=$true
      if($m.PSObject.Properties.Name -contains 'Deployed'){$wasDeployed=[bool]$m.Deployed}
      if($wasDeployed -and $name -notin $desiredNames){Add-PMMRemovalExpectation $removalMap $name ([string]$m.Hash) 'no longer desired from previous PMM deployment'}
    }
  }

  $removeActions=New-Object System.Collections.Generic.List[object]
  $removeSeen=[System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
  $copyActions=New-Object System.Collections.Generic.List[object]
  $blocking=New-Object System.Collections.Generic.List[string]
  $unchanged=New-Object System.Collections.Generic.List[string]

  foreach($item in @($removalMap.Values)){
    $target=Join-Path $gameMods ([string]$item.Name)
    if(-not(Test-Path -LiteralPath $target -PathType Leaf)){continue}
    $existingHash=Get-Sha256 $target
    $expected=@($item.Hashes|ForEach-Object{[string]$_}|Where-Object{$_})
    if($expected.Count -gt 0 -and $existingHash -in $expected){
      Add-PMMFileAction $removeActions $removeSeen $target (($item.Reasons|ForEach-Object{[string]$_}) -join ', ')
    }else{
      $expectedText=if($expected.Count -gt 0){$expected -join ', '}else{'no trusted hash is available'}
      $blocking.Add((Get-PMMText ("PMM will not remove '{0}' because the game-folder file is not the PMM-managed copy. Existing SHA-256: {1}; expected: {2}." -f $item.Name,$existingHash,$expectedText) ("PMM no eliminara '{0}' porque el archivo de la carpeta del juego no coincide con la copia gestionada por PMM. SHA-256 actual: {1}; esperado: {2}." -f $item.Name,$existingHash,$expectedText)))
    }
  }

  foreach($mod in @($Context.DeployActive)){
    $target=Join-Path $gameMods ([string]$mod.Name)
    if(Test-Path -LiteralPath $target -PathType Leaf){
      $existingHash=Get-Sha256 $target
      if($existingHash -eq [string]$mod.Hash){$unchanged.Add([string]$mod.Name);continue}
      $knownPrevious=$previousHashes[[string]$mod.Name]
      if([string]::IsNullOrWhiteSpace([string]$knownPrevious) -or $existingHash -ne [string]$knownPrevious){
        $blocking.Add((Get-PMMText ("PMM will not overwrite '{0}' because a different, unrecognized PAK already exists in ~mods. Existing SHA-256: {1}; desired: {2}. Rename/remove/import that file explicitly first." -f $mod.Name,$existingHash,$mod.Hash) ("PMM no sobrescribira '{0}' porque ya existe en ~mods un PAK diferente que PMM no reconoce como gestionado. SHA-256 actual: {1}; deseado: {2}. Renombra/elimina/importa ese archivo de forma explicita primero." -f $mod.Name,$existingHash,$mod.Hash)))
        continue
      }
    }
    $copyActions.Add([pscustomobject]@{Kind='Source';Name=[string]$mod.Name;Source=[string]$mod.Path;Destination=$target;ExpectedHash=[string]$mod.Hash})
  }

  # PMM owns its reserved overlay namespace. Old PMM overlays are backed up by
  # the transaction before removal/replacement, so a failed Deploy can roll back.
  $patch=$Context.Patch
  foreach($oldPatch in @(Get-ChildItem -LiteralPath $gameMods -Filter 'zzzzzzzzzz_PMM_Merge_*_P.pak' -File -ErrorAction SilentlyContinue)){
    $keep=$false
    if($patch -and $oldPatch.Name -eq $patch.Name -and (Get-Sha256 $oldPatch.FullName) -eq [string]$patch.Hash){$keep=$true}
    if(-not$keep){
      Add-PMMFileAction $removeActions $removeSeen $oldPatch.FullName 'replace/remove old PMM overlay'
      $sidecar=$oldPatch.FullName+'.manifest.json'
      if(Test-Path -LiteralPath $sidecar -PathType Leaf){Add-PMMFileAction $removeActions $removeSeen $sidecar 'replace/remove old PMM overlay manifest'}
    }
  }

  if($patch){
    $patchTarget=Join-Path $gameMods ([string]$patch.Name)
    $needsPatchCopy=$true
    if(Test-Path -LiteralPath $patchTarget -PathType Leaf){$needsPatchCopy=((Get-Sha256 $patchTarget) -ne [string]$patch.Hash)}
    if($needsPatchCopy){$copyActions.Add([pscustomobject]@{Kind='Patch';Name=[string]$patch.Name;Source=[string]$patch.Path;Destination=$patchTarget;ExpectedHash=[string]$patch.Hash})}
    if(Test-Path -LiteralPath $patch.ManifestPath -PathType Leaf){
      $manifestTarget=$patchTarget+'.manifest.json'
      $manifestHash=Get-Sha256 $patch.ManifestPath
      $needsManifest=$true
      if(Test-Path -LiteralPath $manifestTarget -PathType Leaf){$needsManifest=((Get-Sha256 $manifestTarget) -ne $manifestHash)}
      if($needsManifest){$copyActions.Add([pscustomobject]@{Kind='PatchManifest';Name=([string]$patch.Name+'.manifest.json');Source=[string]$patch.ManifestPath;Destination=$manifestTarget;ExpectedHash=$manifestHash})}
    }
  }

  return [pscustomobject]@{
    RemoveActions=$removeActions.ToArray();CopyActions=$copyActions.ToArray();BlockingConflicts=$blocking.ToArray();Unchanged=$unchanged.ToArray();PreviousHashes=$previousHashes
  }
}

function Get-PMMDeploymentPreview {
  $context=Get-PMMDeploymentContext
  $ops=New-PMMDeploymentOperationPlan $context
  if(@($ops.BlockingConflicts).Count -gt 0){throw ((Get-PMMText 'Deploy is blocked by game-folder identity conflicts:' 'Deploy esta bloqueado por conflictos de identidad en la carpeta del juego:')+"`n`n"+(@($ops.BlockingConflicts) -join "`n`n"))}
  $install=@($ops.CopyActions|Where-Object{$_.Kind -eq 'Source'}|ForEach-Object{[string]$_.Name})
  $remove=@($ops.RemoveActions|Where-Object{[IO.Path]::GetExtension([string]$_.Path) -ieq '.pak'}|ForEach-Object{[IO.Path]::GetFileName([string]$_.Path)})
  $suppressed=@($context.Suppressed)
  $patchText=if($context.Patch){[string]$context.Patch.Name}elseif($context.NoPatchSelected){Get-PMMText 'none - source mods only' 'ninguno - solo mods fuente'}else{Get-PMMText 'not required' 'no requerido'}
  return (Get-PMMText ("Deploy preview:`n- Active source mods: {0}`n- Source PAK copies/updates: {1}`n- Managed PAK removals/replacements: {2}`n- Alternatives kept only in PMM library: {3}`n- Compatibility patch: {4}`n`nNo unrecognized same-name PAK will be overwritten or deleted." -f $context.DeployActive.Count,$install.Count,$remove.Count,$suppressed.Count,$patchText) ("Vista previa de Deploy:`n- Mods fuente activos: {0}`n- PAK fuente a copiar/actualizar: {1}`n- PAK gestionados a retirar/reemplazar: {2}`n- Alternativas conservadas solo en la biblioteca PMM: {3}`n- Parche de compatibilidad: {4}`n`nNo se sobrescribira ni borrara ningun PAK del mismo nombre que PMM no reconozca como gestionado." -f $context.DeployActive.Count,$install.Count,$remove.Count,$suppressed.Count,$patchText))
}

function Remove-PMMOldDeploymentBackups([int]$Keep=3) {
  $root=Join-PMMPath 'Builds' 'DeploymentBackups'
  if(-not(Test-Path -LiteralPath $root -PathType Container)){return}
  $dirs=@(Get-ChildItem -LiteralPath $root -Directory -ErrorAction SilentlyContinue|Sort-Object LastWriteTimeUtc -Descending)
  foreach($dir in @($dirs|Select-Object -Skip $Keep)){Remove-Item -LiteralPath $dir.FullName -Recurse -Force -ErrorAction SilentlyContinue}
}

function Invoke-PMMDeploymentTransaction($Context,$Operations,$State,[scriptblock]$ProgressCallback=$null) {
  if(@($Operations.BlockingConflicts).Count -gt 0){throw (@($Operations.BlockingConflicts) -join "`n`n")}
  $id=(Get-Date -Format 'yyyyMMdd_HHmmss')+'_'+[guid]::NewGuid().ToString('N').Substring(0,8)
  $backupRoot=Join-Path (Join-PMMPath 'Builds' 'DeploymentBackups') $id
  $stageRoot=Join-Path ([string]$Context.GameMods) ('.pmm-stage-'+$id)
  New-Item -ItemType Directory -Force -Path $backupRoot,$stageRoot|Out-Null

  $touched=[System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
  foreach($a in @($Operations.RemoveActions)){[void]$touched.Add([string]$a.Path)}
  foreach($a in @($Operations.CopyActions)){[void]$touched.Add([string]$a.Destination)}
  $backupRecords=[System.Collections.Generic.List[object]]::new()
  $stagedRecords=[System.Collections.Generic.List[object]]::new()
  $commitStarted=$false
  $statePath=Get-PMMDeploymentStatePath
  $pendingPath=Get-PMMPendingRemovalPath
  $oldStateExists=Test-Path -LiteralPath $statePath -PathType Leaf
  $oldPendingExists=Test-Path -LiteralPath $pendingPath -PathType Leaf

  try{
    # Phase 1: stage every desired file and verify hashes before touching ~mods.
    $copyActions=@($Operations.CopyActions)
    $copyIndex=0
    foreach($action in $copyActions){
      $copyIndex++
      $stageBase=if($copyActions.Count -gt 0){0.15+(0.35*(($copyIndex-1)/[double]$copyActions.Count))}else{0.50}
      $stageEnd=if($copyActions.Count -gt 0){0.15+(0.35*($copyIndex/[double]$copyActions.Count))}else{0.50}
      Invoke-PMMProgressCallback $ProgressCallback $stageBase ((Get-PMMText 'Staging {0}...' 'Preparando {0}...') -f [string]$action.Name)
      $stageName=([IO.Path]::GetFileName([string]$action.Destination))+'.pmmstage'
      $stagePath=Join-Path $stageRoot $stageName
      Copy-PMMFileWithProgress ([string]$action.Source) $stagePath $ProgressCallback $stageBase ([Math]::Max($stageBase,($stageEnd-0.01))) ((Get-PMMText 'Staging {0}...' 'Preparando {0}...') -f [string]$action.Name)
      $stageHash=Get-Sha256 $stagePath
      if($stageHash -ne [string]$action.ExpectedHash){throw "Deployment staging hash mismatch for $($action.Name): $stageHash != $($action.ExpectedHash)"}
      $stagedRecords.Add([pscustomobject]@{Destination=[string]$action.Destination;Stage=$stagePath;ExpectedHash=[string]$action.ExpectedHash;Name=[string]$action.Name})
      Invoke-PMMProgressCallback $ProgressCallback $stageEnd ((Get-PMMText 'Staged and verified {0}' 'Preparado y verificado {0}') -f [string]$action.Name)
    }
    Invoke-PMMProgressCallback $ProgressCallback 0.50 (Get-PMMText 'Staging complete. Creating rollback backups...' 'Preparacion terminada. Creando backups de rollback...')

    # Phase 2: back up every existing file that the commit may replace/remove.
    $touchedPaths=@($touched)
    $touchIndex=0
    foreach($path in $touchedPaths){
      $touchIndex++
      if(Test-Path -LiteralPath $path -PathType Leaf){
        $backup=Join-Path $backupRoot (([IO.Path]::GetFileName($path))+'.before')
        Copy-Item -LiteralPath $path -Destination $backup -Force
        if((Get-Sha256 $backup) -ne (Get-Sha256 $path)){throw "Deployment backup verification failed for $path"}
        $backupRecords.Add([pscustomobject]@{Original=$path;Backup=$backup})
      }
      if($touchedPaths.Count -gt 0){Invoke-PMMProgressCallback $ProgressCallback (0.50+(0.18*($touchIndex/[double]$touchedPaths.Count))) (Get-PMMText 'Creating verified rollback backup...' 'Creando backup de rollback verificado...')}
    }
    if($oldStateExists){Copy-Item -LiteralPath $statePath -Destination (Join-Path $backupRoot 'deployment-state.before.json') -Force}
    if($oldPendingExists){Copy-Item -LiteralPath $pendingPath -Destination (Join-Path $backupRoot 'pending-removals.before.json') -Force}

    [pscustomobject]@{
      SchemaVersion=1;State='Prepared';Created=(Get-Date).ToString('o');GameMods=$Context.GameMods;
      Touched=[string[]]$touched;Copies=@($Operations.CopyActions);Removals=@($Operations.RemoveActions);Backups=$backupRecords.ToArray();
      DeploymentStateExisted=$oldStateExists;PendingRemovalsExisted=$oldPendingExists
    }|ConvertTo-Json -Depth 20|Set-Content -LiteralPath (Join-Path $backupRoot 'transaction.json') -Encoding UTF8

    Invoke-PMMProgressCallback $ProgressCallback 0.68 (Get-PMMText 'Rollback backup ready. Committing deployment...' 'Backup de rollback listo. Aplicando despliegue...')

    # Phase 3: commit. Staged files live on the same volume as ~mods, so the
    # final Move-Item is a same-volume rename rather than a long copy window.
    $commitStarted=$true
    foreach($action in @($Operations.RemoveActions)){if(Test-Path -LiteralPath ([string]$action.Path) -PathType Leaf){Remove-Item -LiteralPath ([string]$action.Path) -Force}}
    $commitIndex=0
    foreach($record in $stagedRecords){
      $commitIndex++
      if(Test-Path -LiteralPath ([string]$record.Destination) -PathType Leaf){Remove-Item -LiteralPath ([string]$record.Destination) -Force}
      Move-Item -LiteralPath ([string]$record.Stage) -Destination ([string]$record.Destination) -Force
      if($stagedRecords.Count -gt 0){Invoke-PMMProgressCallback $ProgressCallback (0.70+(0.12*($commitIndex/[double]$stagedRecords.Count))) ((Get-PMMText 'Committed {0}' 'Aplicado {0}') -f [string]$record.Name)}
    }

    # Phase 4: verify committed bytes before recording deployment state.
    $verifyIndex=0
    foreach($record in $stagedRecords){
      $verifyIndex++
      if(-not(Test-Path -LiteralPath ([string]$record.Destination) -PathType Leaf)){throw "Deploy verification missing file: $($record.Destination)"}
      $hash=Get-Sha256 ([string]$record.Destination)
      if($hash -ne [string]$record.ExpectedHash){throw "Deploy verification hash mismatch for $($record.Name): $hash != $($record.ExpectedHash)"}
      if($stagedRecords.Count -gt 0){Invoke-PMMProgressCallback $ProgressCallback (0.82+(0.15*($verifyIndex/[double]$stagedRecords.Count))) ((Get-PMMText 'Verified {0}' 'Verificado {0}') -f [string]$record.Name)}
    }
    Invoke-PMMProgressCallback $ProgressCallback 0.97 (Get-PMMText 'Recording deployment state...' 'Guardando estado del despliegue...')
    Write-PMMDeploymentState $State
    Write-PMMPendingRemovalRecords @()
    [pscustomobject]@{SchemaVersion=1;State='Committed';Completed=(Get-Date).ToString('o');GameMods=$Context.GameMods;Touched=[string[]]$touched;BackupCount=$backupRecords.Count}|ConvertTo-Json -Depth 10|Set-Content -LiteralPath (Join-Path $backupRoot 'transaction.json') -Encoding UTF8
    Remove-Item -LiteralPath $stageRoot -Recurse -Force -ErrorAction SilentlyContinue
    Remove-PMMOldDeploymentBackups 3
    return $backupRoot
  }catch{
    $failure=$_.Exception.Message
    $wasCancelled=($_.Exception -is [System.OperationCanceledException] -or $failure -eq 'PMM_OPERATION_CANCELLED')
    $rollbackErrors=[System.Collections.Generic.List[string]]::new()
    if($commitStarted){
      Write-PMMLog ('Deploy commit failed; rolling back managed game-folder changes: '+$failure)
      foreach($path in @($touched)){
        try{if(Test-Path -LiteralPath $path -PathType Leaf){Remove-Item -LiteralPath $path -Force -ErrorAction Stop}}catch{$rollbackErrors.Add("remove current '$path': "+$_.Exception.Message)}
      }
      foreach($record in $backupRecords){
        try{Copy-Item -LiteralPath ([string]$record.Backup) -Destination ([string]$record.Original) -Force -ErrorAction Stop}catch{$rollbackErrors.Add("restore '$($record.Original)': "+$_.Exception.Message)}
      }
      $oldStateBackup=Join-Path $backupRoot 'deployment-state.before.json'
      try{
        if($oldStateExists){if(Test-Path -LiteralPath $oldStateBackup -PathType Leaf){Copy-Item -LiteralPath $oldStateBackup -Destination $statePath -Force -ErrorAction Stop}else{throw 'deployment-state backup is missing'}}
        else{Remove-Item -LiteralPath $statePath -Force -ErrorAction SilentlyContinue}
      }catch{$rollbackErrors.Add('restore deployment-state.json: '+$_.Exception.Message)}
      $oldPendingBackup=Join-Path $backupRoot 'pending-removals.before.json'
      try{
        if($oldPendingExists){if(Test-Path -LiteralPath $oldPendingBackup -PathType Leaf){Copy-Item -LiteralPath $oldPendingBackup -Destination $pendingPath -Force -ErrorAction Stop}else{throw 'pending-removals backup is missing'}}
        else{Remove-Item -LiteralPath $pendingPath -Force -ErrorAction SilentlyContinue}
      }catch{$rollbackErrors.Add('restore pending-removals.json: '+$_.Exception.Message)}
      try{
        [pscustomobject]@{SchemaVersion=1;State=$(if($rollbackErrors.Count -eq 0){'RolledBack'}else{'RollbackIncomplete'});Failed=(Get-Date).ToString('o');Error=$failure;RollbackErrors=$rollbackErrors.ToArray()}|ConvertTo-Json -Depth 10|Set-Content -LiteralPath (Join-Path $backupRoot 'transaction.json') -Encoding UTF8
      }catch{}
    }
    Remove-Item -LiteralPath $stageRoot -Recurse -Force -ErrorAction SilentlyContinue
    if($commitStarted -and $rollbackErrors.Count -gt 0){
      $detail=($rollbackErrors.ToArray() -join "`n")
      throw (Get-PMMText ("Deploy failed and automatic rollback was incomplete. Do not launch Palworld yet. Recovery data is preserved in: {0}`nOriginal error: {1}`nRollback errors:`n{2}" -f $backupRoot,$failure,$detail) ("Deploy fallo y el rollback automatico quedo incompleto. No inicies Palworld todavia. Los datos de recuperacion se conservaron en: {0}`nError original: {1}`nErrores de rollback:`n{2}" -f $backupRoot,$failure,$detail))
    }
    if($wasCancelled){throw [System.OperationCanceledException]::new('PMM_OPERATION_CANCELLED')}
    $message=if($commitStarted){Get-PMMText 'Deploy failed after commit started, but PMM restored every managed game-folder file from its verified rollback backup.' 'Deploy fallo despues de iniciar el commit, pero PMM restauro todos los archivos gestionados de la carpeta del juego desde el backup verificado de rollback.'}else{Get-PMMText 'Deploy failed before any managed game-folder file was changed.' 'Deploy fallo antes de cambiar ningun archivo gestionado de la carpeta del juego.'}
    throw ("$message`n`n$failure")
  }
}

function Deploy-PMMManagedState([scriptblock]$ProgressCallback=$null) {
  $journal=''
  try{
  Invoke-PMMProgressCallback $ProgressCallback 0.02 (Get-PMMText 'Checking deployment state...' 'Comprobando estado del despliegue...')
  $context=Get-PMMDeploymentContext
  try{if(Get-Command Start-PMMJournalOperation -ErrorAction SilentlyContinue){$journal=Start-PMMJournalOperation -Kind Deploy -Target ([string]$context.GameMods) -Metadata ([ordered]@{ActiveMods=@($context.Active).Count;Patch=$(if($context.Patch){[string]$context.Patch.Name}else{''})})}}catch{Write-PMMLog ('Could not start common Deploy journal: '+$_.Exception.Message)}
  Invoke-PMMProgressCallback $ProgressCallback 0.05 (Get-PMMText 'Stopping Palworld if needed...' 'Cerrando Palworld si es necesario...')
  Stop-PalworldForDeployment
  if($journal){try{Write-PMMJournalStep -OperationId $journal -Kind Deploy -Step GameStopped -Status Complete}catch{Write-PMMLog ('Could not update common Deploy journal after game stop: '+$_.Exception.Message)}}

  # Recompute after Palworld is closed so hashes/collisions cannot change
  # between the user-facing preview and the actual commit.
  Invoke-PMMProgressCallback $ProgressCallback 0.10 (Get-PMMText 'Revalidating hashes and deployment plan...' 'Revalidando hashes y plan de despliegue...')
  $context=Get-PMMDeploymentContext
  $ops=New-PMMDeploymentOperationPlan $context
  if(@($ops.BlockingConflicts).Count -gt 0){
    throw ((Get-PMMText 'Deploy is blocked because PMM found same-name game files that it cannot prove are managed copies:' 'Deploy esta bloqueado porque PMM encontro archivos del mismo nombre en el juego que no puede demostrar que sean copias gestionadas:')+"`n`n"+(@($ops.BlockingConflicts) -join "`n`n"))
  }

  $state=[pscustomobject]@{
    SchemaVersion=3;Deployed=(Get-Date).ToString('o');SourceSignature=$context.Signature;
    SourceMods=@($context.Active|ForEach-Object{[pscustomobject]@{Name=$_.Name;Hash=$_.Hash;Deployed=([string]$_.Name -notin @($context.Suppressed))}});
    SuppressedAlternatives=@($context.Suppressed);
    Patch=$(if($context.Patch){[pscustomobject]@{Name=$context.Patch.Name;Hash=$context.Patch.Hash}}else{$null})
  }
  Invoke-PMMProgressCallback $ProgressCallback 0.14 (Get-PMMText 'Starting transactional deployment...' 'Iniciando despliegue transaccional...')
  if($journal){try{Write-PMMJournalStep -OperationId $journal -Kind Deploy -Step PlanValidated -Status Complete -Metadata ([ordered]@{Copies=@($ops.CopyActions).Count;Removals=@($ops.RemoveActions).Count})}catch{Write-PMMLog ('Could not update common Deploy journal after validation: '+$_.Exception.Message)}}
  $backupRoot=Invoke-PMMDeploymentTransaction $context $ops $state $ProgressCallback
  if($journal){try{Write-PMMJournalStep -OperationId $journal -Kind Deploy -Step TransactionCommitted -Status Complete -Metadata ([ordered]@{BackupId=[IO.Path]::GetFileName([string]$backupRoot)})}catch{Write-PMMLog ('Could not update common Deploy journal after commit: '+$_.Exception.Message)}}
  if($context.Patch){
    try{Promote-PMMPatchToCurrent ([string]$context.Patch.Name)}catch{Write-PMMLog ('Deploy succeeded but local patch promotion failed: '+$_.Exception.Message)}
  }
  Invoke-PMMProgressCallback $ProgressCallback 1.0 (Get-PMMText 'Deploy complete.' 'Deploy terminado.')
  Write-PMMLog ("Transactional Deploy synchronized {0} source mods; suppressed alternatives={1}; patch={2}; managerOnly={3}; backup={4}" -f $context.DeployActive.Count,$context.Suppressed.Count,$(if($context.Patch){$context.Patch.Name}else{'none'}),[bool]$context.NoPatchSelected,$backupRoot)
  $suppressedText=if($context.Suppressed.Count -gt 0){$context.Suppressed -join ', '}else{Get-PMMText 'none' 'ninguno'}
  $patchResult=if($context.Patch){[string]$context.Patch.Name}elseif($context.NoPatchSelected){Get-PMMText 'none - source mods only' 'ninguno - solo mods fuente'}else{Get-PMMText 'not required' 'no requerido'}
  if($journal){try{Complete-PMMJournalOperation -OperationId $journal -Kind Deploy -Metadata ([ordered]@{SourceMods=$context.DeployActive.Count;Suppressed=$context.Suppressed.Count;Patch=$patchResult})}catch{Write-PMMLog ('Deploy committed but its journal completion failed: '+$_.Exception.Message)}}
  return (Get-PMMText ("Deploy complete. Source mods installed: {0}. Redundant byte-identical source PAKs kept only in PMM library: {1}. Compatibility patch: {2}. Managed changes were hash-verified and committed with rollback backup." -f $context.DeployActive.Count,$suppressedText,$patchResult) ("Deploy terminado. Mods fuente instalados: {0}. PAK fuente redundantes e identicos byte a byte conservados solo en la biblioteca PMM: {1}. Parche de compatibilidad: {2}. Los cambios gestionados se verificaron por hash y se aplicaron con backup para rollback." -f $context.DeployActive.Count,$suppressedText,$patchResult))
  }catch{
    if($journal){try{Fail-PMMJournalOperation -OperationId $journal -Kind Deploy -Message $_.Exception.Message}catch{}}
    throw
  }
}

function Import-PMMPatchBackup([string]$PakPath) {
  if (-not (Test-Path -LiteralPath $PakPath -PathType Leaf)) { throw "PMM patch not found: $PakPath" }
  $file = Get-Item -LiteralPath $PakPath
  if ($file.Name -notlike 'zzzzzzzzzz_PMM_Merge_*_P.pak') { throw "Not a PMM generated patch: $($file.Name)" }

  $root = Get-PMMLocalPatchBackupRoot
  New-Item -ItemType Directory -Force -Path $root | Out-Null
  $dst = Join-Path $root $file.Name
  $srcHash = Get-Sha256 $file.FullName
  $copy = $true
  if (Test-Path -LiteralPath $dst -PathType Leaf) {
    $copy = ((Get-Sha256 $dst) -ne $srcHash)
  }
  if ($copy) { Copy-Item -LiteralPath $file.FullName -Destination $dst -Force }

  $manifestCandidates = @($file.FullName + '.manifest.json')
  foreach ($candidate in $manifestCandidates) {
    if (Test-Path -LiteralPath $candidate -PathType Leaf) {
      Copy-Item -LiteralPath $candidate -Destination ($dst + '.manifest.json') -Force
      break
    }
  }
  Write-PMMLog "Imported PMM patch as managed backup (not a source mod): $($file.Name)"
  return $dst
}

function Test-PMMCancellationRequestedFromUI {
  try{
    $cmd=Get-Command Test-PMMOperationCancellationRequested -ErrorAction SilentlyContinue
    if($cmd){return [bool](& $cmd)}
  }catch{}
  return $false
}

function Assert-PMMOperationNotCancelled {
  if(Test-PMMCancellationRequestedFromUI){throw [System.OperationCanceledException]::new('PMM_OPERATION_CANCELLED')}
}

function Invoke-PMMProgressCallback($ProgressCallback,[double]$Fraction,[string]$Message) {
  Assert-PMMOperationNotCancelled
  if($ProgressCallback){
    $value=[Math]::Max(0.0,[Math]::Min(1.0,$Fraction))
    try{& $ProgressCallback $value $Message}catch{
      if($_.Exception -is [System.OperationCanceledException]){throw}
      Write-PMMLog ('Progress callback failed: '+$_.Exception.Message)
    }
  }
  Assert-PMMOperationNotCancelled
}

function Quote-PMMProcessArgument([string]$Value) {
  if($null -eq $Value){return '""'}
  return ('"'+$Value.Replace('"','\\"')+'"')
}

function Invoke-PMMCancelableExternalProcess {
  param(
    [Parameter(Mandatory=$true)][string]$FilePath,
    [Parameter(Mandatory=$true)][string[]]$Arguments,
    [scriptblock]$ProgressCallback=$null,
    [double]$Fraction=0.0,
    [string]$Message='Working...'
  )
  Assert-PMMOperationNotCancelled
  $psi=[System.Diagnostics.ProcessStartInfo]::new()
  $psi.FileName=$FilePath
  $psi.Arguments=(@($Arguments|ForEach-Object{Quote-PMMProcessArgument ([string]$_)}) -join ' ')
  $psi.UseShellExecute=$false
  $psi.CreateNoWindow=$true
  $psi.WindowStyle=[System.Diagnostics.ProcessWindowStyle]::Hidden
  $proc=[System.Diagnostics.Process]::new();$proc.StartInfo=$psi
  try{
    if(-not$proc.Start()){throw ('Could not start external process: '+$FilePath)}
    while(-not$proc.WaitForExit(120)){
      Invoke-PMMProgressCallback $ProgressCallback $Fraction $Message
    }
    Invoke-PMMProgressCallback $ProgressCallback $Fraction $Message
    return [int]$proc.ExitCode
  }catch{
    try{if(-not$proc.HasExited){$proc.Kill()}}catch{}
    throw
  }finally{$proc.Dispose()}
}

function Copy-PMMFileWithProgress {
  param(
    [Parameter(Mandatory=$true)][string]$Source,
    [Parameter(Mandatory=$true)][string]$Destination,
    [scriptblock]$ProgressCallback=$null,
    [double]$StartFraction=0.0,
    [double]$EndFraction=1.0,
    [string]$Message='Copying file...'
  )
  $sourceInfo=Get-Item -LiteralPath $Source -ErrorAction Stop
  $destDir=Split-Path -Parent $Destination
  if($destDir){New-Item -ItemType Directory -Force -Path $destDir|Out-Null}
  [int64]$length=[int64]$sourceInfo.Length
  [int64]$written=0
  $input=$null;$output=$null
  try{
    $input=[IO.File]::Open($Source,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::Read)
    $output=[IO.File]::Open($Destination,[IO.FileMode]::Create,[IO.FileAccess]::Write,[IO.FileShare]::None)
    $buffer=[byte[]]::new(4194304)
    $reportClock=[System.Diagnostics.Stopwatch]::StartNew()
    $lastReport=0L
    while(($read=$input.Read($buffer,0,$buffer.Length)) -gt 0){
      $output.Write($buffer,0,$read)
      $written+=$read
      $now=[int64]$reportClock.ElapsedMilliseconds
      if(($now-$lastReport) -ge 150 -or $written -ge $length){
        $local=if($length -gt 0){[double]$written/[double]$length}else{1.0}
        $mapped=$StartFraction+(($EndFraction-$StartFraction)*$local)
        Invoke-PMMProgressCallback $ProgressCallback $mapped $Message
        $lastReport=$now
      }
    }
    $output.Flush()
  }finally{
    if($output){$output.Dispose()}
    if($input){$input.Dispose()}
  }
  if($length -eq 0){Invoke-PMMProgressCallback $ProgressCallback $EndFraction $Message}
}

function Assert-PMMZipImportWorkingSpace([string]$ZipPath,[string]$StagePath) {
  Add-Type -AssemblyName System.IO.Compression.FileSystem
  $archive=[IO.Compression.ZipFile]::OpenRead($ZipPath)
  [int64]$expanded=0
  try{
    foreach($entry in $archive.Entries){
      if([string]::IsNullOrWhiteSpace([string]$entry.FullName) -or ([string]$entry.FullName).EndsWith('/')){continue}
      if([int64]$entry.Length -lt 0 -or $expanded -gt ([int64]::MaxValue-[int64]$entry.Length)){throw 'ZIP import size metadata is invalid.'}
      $expanded+=[int64]$entry.Length
    }
  }finally{$archive.Dispose()}
  [int64]$required=$expanded+512MB
  [int64]$free=-1
  try{
    $probe=Split-Path -Parent $StagePath
    if(-not$probe){$probe=$Script:Root}
    $item=Get-Item -LiteralPath $probe -ErrorAction Stop
    if($item.PSDrive -and $null -ne $item.PSDrive.Free){$free=[int64]$item.PSDrive.Free}
  }catch{}
  if($free -lt 0){
    try{$driveRoot=[IO.Path]::GetPathRoot([IO.Path]::GetFullPath($StagePath));if($driveRoot){$free=[int64]([IO.DriveInfo]::new($driveRoot).AvailableFreeSpace)}}catch{}
  }
  if($free -ge 0 -and $free -lt $required){
    throw ((Get-PMMText 'The ZIP would need about {0:N1} GB of temporary space, but only {1:N1} GB are free. Import was stopped before extraction.' 'El ZIP necesitaria unos {0:N1} GB de espacio temporal, pero solo hay {1:N1} GB libres. La importacion se detuvo antes de extraer.') -f ($required/1GB),($free/1GB))
  }
  if($free -lt 0){Write-PMMLog ('ZIP import free-space preflight unavailable for '+$StagePath+'; safe runtime extraction will continue.')}
  return [pscustomobject]@{ExpandedBytes=$expanded;RequiredWorkingBytes=$required;FreeBytes=$free}
}

function Import-PMMMod([string]$Path,[scriptblock]$ProgressCallback=$null) {
  if (-not (Test-Path -LiteralPath $Path)) {
    throw (Get-PMMText "Source does not exist: $Path" "No existe: $Path")
  }

  $displayName=[IO.Path]::GetFileName($Path)
  Invoke-PMMProgressCallback $ProgressCallback 0.01 ((Get-PMMText 'Preparing import: {0}' 'Preparando importacion: {0}') -f $displayName)
  $ext = [IO.Path]::GetExtension($Path).ToLowerInvariant()
  $stage = Join-Path (Get-PMMPath 'Cache') ('Import_' + [guid]::NewGuid().ToString('N'))
  New-Item -ItemType Directory -Force -Path $stage | Out-Null
  Set-PMMTransientStageOwner $stage 'Import'

  try {
    if ($ext -eq '.pak') {
      $stagePak=Join-Path $stage ([IO.Path]::GetFileName($Path))
      Copy-PMMFileWithProgress $Path $stagePak $ProgressCallback 0.03 0.45 ((Get-PMMText 'Reading {0}...' 'Leyendo {0}...') -f $displayName)
    } elseif ($ext -eq '.zip') {
      Invoke-PMMProgressCallback $ProgressCallback 0.05 (Get-PMMText 'Checking archive size and free space...' 'Comprobando tamano del archivo y espacio libre...')
      [void](Assert-PMMZipImportWorkingSpace $Path $stage)
      $runtime=Get-PMMRuntimePath
      if(-not(Test-Path -LiteralPath $runtime -PathType Leaf)){throw 'PMMRuntime.exe is required to import ZIP archives safely.'}
      Invoke-PMMProgressCallback $ProgressCallback 0.12 ((Get-PMMText 'Extracting {0} safely...' 'Extrayendo {0} de forma segura...') -f $displayName)
      $exit=Invoke-PMMCancelableExternalProcess -FilePath $runtime -Arguments @('archive','extract',$Path,$stage) -ProgressCallback $ProgressCallback -Fraction 0.30 -Message ((Get-PMMText 'Extracting {0} safely...' 'Extrayendo {0} de forma segura...') -f $displayName)
      if($exit -ne 0){throw ('PMMRuntime archive extract failed while importing the mod. Exit code: '+$exit)}
      Invoke-PMMProgressCallback $ProgressCallback 0.48 (Get-PMMText 'Archive extracted. Inspecting PAK files...' 'Archivo extraido. Revisando PAK...')
    } elseif ($ext -in @('.7z','.rar')) {
      $seven = Get-Command 7z.exe -ErrorAction SilentlyContinue
      if (-not $seven) {
        throw (Get-PMMText '7-Zip is required for .7z/.rar archives, or import the .pak directly.' 'Para .7z/.rar instala 7-Zip o importa el .pak directamente.')
      }
      Invoke-PMMProgressCallback $ProgressCallback 0.12 ((Get-PMMText 'Extracting {0} with 7-Zip...' 'Extrayendo {0} con 7-Zip...') -f $displayName)
      $exit=Invoke-PMMCancelableExternalProcess -FilePath $seven.Source -Arguments @('x',('-o'+$stage),'-y',$Path) -ProgressCallback $ProgressCallback -Fraction 0.30 -Message ((Get-PMMText 'Extracting {0} with 7-Zip...' 'Extrayendo {0} con 7-Zip...') -f $displayName)
      if ($exit -ne 0) {
        throw (Get-PMMText '7-Zip could not extract the archive.' '7-Zip no pudo extraer el archivo.')
      }
      Invoke-PMMProgressCallback $ProgressCallback 0.48 (Get-PMMText 'Archive extracted. Inspecting PAK files...' 'Archivo extraido. Revisando PAK...')
    } else {
      throw (Get-PMMText 'Unsupported archive format.' 'Formato no compatible.')
    }

    $paks = @(Get-ChildItem -LiteralPath $stage -Filter *.pak -File -Recurse)
    if ($paks.Count -eq 0) {
      throw (Get-PMMText 'The archive does not contain any .pak files.' 'El archivo no contiene ningun .pak.')
    }

    $pakIndex=0
    foreach ($pak in $paks) {
      $pakIndex++
      $slotStart=0.50+(0.47*(($pakIndex-1)/[double]$paks.Count))
      $slotEnd=0.50+(0.47*($pakIndex/[double]$paks.Count))
      if ($pak.Name -like 'zzzzzzzzzz_PMM_Merge_*_P.pak') {
        Invoke-PMMProgressCallback $ProgressCallback $slotStart ((Get-PMMText 'Importing managed PMM patch {0}...' 'Importando parche PMM gestionado {0}...') -f $pak.Name)
        Import-PMMPatchBackup $pak.FullName | Out-Null
        Invoke-PMMProgressCallback $ProgressCallback $slotEnd ((Get-PMMText 'Imported {0}' 'Importado {0}') -f $pak.Name)
        continue
      }

      Invoke-PMMProgressCallback $ProgressCallback $slotStart ((Get-PMMText 'Hashing {0}...' 'Calculando hash de {0}...') -f $pak.Name)
      $hash = Get-Sha256 $pak.FullName
      Remove-PMMPendingRemoval $pak.Name
      $slug = ([IO.Path]::GetFileNameWithoutExtension($pak.Name) -replace '[^A-Za-z0-9_.-]','_')
      $dst = Join-Path (Get-LibraryRoot) $slug
      $disabledCopy=Join-Path (Get-PMMDisabledModRoot) $slug
      if(Test-Path -LiteralPath $disabledCopy -PathType Container){Remove-Item -LiteralPath $disabledCopy -Recurse -Force}
      New-Item -ItemType Directory -Force -Path $dst | Out-Null
      $copyStart=$slotStart+(($slotEnd-$slotStart)*0.20)
      Copy-PMMFileWithProgress $pak.FullName (Join-Path $dst $pak.Name) $ProgressCallback $copyStart $slotEnd ((Get-PMMText 'Adding {0} to the PMM library...' 'Anadiendo {0} a la biblioteca PMM...') -f $pak.Name)

      [pscustomobject]@{
        Name=$pak.Name
        Hash=$hash
        Imported=(Get-Date).ToString('o')
        Source=$Path
      } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $dst 'metadata.json') -Encoding UTF8

      Write-PMMLog "Imported mod: $($pak.Name)"
    }

    [void](Get-PMMModPriorityOrder)
    Clear-PMMLibraryHashCache
    Clear-PakEntryCache
    Clear-PMMAnalysisState
    Invoke-PMMProgressCallback $ProgressCallback 1.0 (Get-PMMText 'Import complete.' 'Importacion terminada.')
  } finally {
    Remove-Item -LiteralPath $stage -Recurse -Force -ErrorAction SilentlyContinue
    Remove-PMMTransientStageOwner $stage
  }
}

function Import-GameModsToLibrary([scriptblock]$ProgressCallback=$null) {
  $gp = Get-GameModsPath
  if (-not $gp) {
    throw (Get-PMMText 'Configure or detect Palworld before importing game ~mods.' 'Configura o detecta Palworld antes de importar los ~mods del juego.')
  }
  Ensure-GameModsFolder

  $all=@(Get-ChildItem -LiteralPath $gp -Filter *.pak -File -ErrorAction SilentlyContinue)
  $sourcePaks=@($all|Where-Object{$_.Name -notlike 'zzzzzzzzzz_PMM_Merge_*_P.pak'})
  $externalMerges=@($all|Where-Object{$_.Name -like 'zzzzzzzzzz_PMM_Merge_*_P.pak'})
  if($externalMerges.Count -gt 0){
    Write-PMMLog ('Import ~mods recognized '+$externalMerges.Count+' deployed PMM merge(s) but did not recreate saved builds. Deployment discovery is read-only in PMM 1.3.')
  }
  if($sourcePaks.Count -eq 0){
    Invoke-PMMProgressCallback $ProgressCallback 1.0 (Get-PMMText 'No source PAKs found in game ~mods.' 'No se encontraron PAK fuente en ~mods.')
    return 0
  }

  $count=0
  for($i=0;$i -lt $sourcePaks.Count;$i++){
    $pak=$sourcePaks[$i]
    $base=[double]$i/[double]$sourcePaks.Count
    $span=1.0/[double]$sourcePaks.Count
    $outer=$ProgressCallback
    $inner={
      param([double]$fraction,[string]$message)
      if($outer){& $outer ($base+($span*$fraction)) $message}
    }.GetNewClosure()
    Import-PMMMod $pak.FullName $inner
    $count++
  }
  Invoke-PMMProgressCallback $ProgressCallback 1.0 (Get-PMMText 'Game ~mods import complete.' 'Importacion de ~mods terminada.')
  return $count
}
