<#
PMM Semantic Lab v0.1
=====================
Read-only evidence layer for explaining unknown/shared cooked assets.

This module deliberately does NOT authorize a merge. Production adapters remain
responsible for proving that bytes/structures can be composed safely. Semantic
Lab extracts stable symbol evidence from cooked families, compares each provider
against Vanilla, applies non-authoritative behavior hints from CKL/Stable, and
records exact known-fixture matches for regression/explanation.

Future versions can add Kismet disassembly, control-flow graphs and symbolic
execution behind the same evidence contract without changing the writer safety
boundary.
#>

function Get-PMMSemanticStringSet([string]$Path) {
  $set=[System.Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
  if(-not $Path -or -not(Test-Path -LiteralPath $Path -PathType Leaf)){return $set}
  $bytes=[IO.File]::ReadAllBytes($Path)
  $min=4;$max=160

  # ASCII/UTF-8-compatible printable runs. Unreal name/function identifiers are
  # commonly visible this way even when the surrounding asset is binary.
  $start=-1
  for($i=0;$i -le $bytes.Length;$i++){
    $printable=($i -lt $bytes.Length -and $bytes[$i] -ge 32 -and $bytes[$i] -le 126)
    if($printable){if($start -lt 0){$start=$i};continue}
    if($start -ge 0){
      $len=$i-$start
      if($len -ge $min -and $len -le $max){
        $s=[Text.Encoding]::ASCII.GetString($bytes,$start,$len)
        if($s -match '[A-Za-z_]'){[void]$set.Add($s)}
      }
      $start=-1
    }
  }

  # UTF-16LE printable runs. Some Unreal strings/names can appear in wide form.
  $i=0
  while($i -lt ($bytes.Length-1)){
    $begin=$i;$chars=[System.Text.StringBuilder]::new()
    while($i -lt ($bytes.Length-1) -and $bytes[$i] -ge 32 -and $bytes[$i] -le 126 -and $bytes[$i+1] -eq 0){
      [void]$chars.Append([char]$bytes[$i]);$i+=2
      if($chars.Length -gt $max){break}
    }
    if($chars.Length -ge $min -and $chars.Length -le $max){
      $s=$chars.ToString();if($s -match '[A-Za-z_]'){[void]$set.Add($s)}
    }
    if($i -eq $begin){$i++}
  }
  return $set
}

function Get-PMMSemanticFamilyStrings($Family) {
  $set=[System.Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
  if(-not $Family){return $set}
  foreach($ext in @('.uasset','.uexp','.ubulk')){
    try{$path=Get-PMMFamilyPartPath $Family $ext}catch{$path=''}
    if($path -and (Test-Path -LiteralPath $path -PathType Leaf)){
      foreach($s in (Get-PMMSemanticStringSet $path)){[void]$set.Add([string]$s)}
    }
  }
  return $set
}

function Get-PMMKnowledgeSummary {
  $behaviorCases=0;$fixtures=0;$runtimeProven=0
  $behaviorsPath=Get-PMMCKLStablePath 'known-behaviors.json'
  if(Test-Path -LiteralPath $behaviorsPath -PathType Leaf){
    try{$behaviorCases=@((Get-Content -LiteralPath $behaviorsPath -Raw|ConvertFrom-Json).cases).Count}catch{}
  }
  $fixturesPath=Get-PMMCKLStablePath 'known-fixtures.json'
  if(Test-Path -LiteralPath $fixturesPath -PathType Leaf){
    try{
      $items=@((Get-Content -LiteralPath $fixturesPath -Raw|ConvertFrom-Json).fixtures)
      $fixtures=$items.Count
      $runtimeProven=@($items|Where-Object{
        $status=''
        if($_.PSObject.Properties.Name -contains 'status' -and $_.status -and ($_.status.PSObject.Properties.Name -contains 'runtime')){$status=[string]$_.status.runtime}
        $status -match '(?i)proven' -and $status -notmatch '(?i)pending'
      }).Count
    }catch{}
  }
  $productionRecipes=0
  try{
    $recipeCommand=Get-Command Get-PMMProductionRecipeCount -ErrorAction SilentlyContinue
    if($recipeCommand){$productionRecipes=[int](Get-PMMProductionRecipeCount)}
  }catch{}
  return [pscustomobject]@{BehaviorCases=$behaviorCases;Fixtures=$fixtures;RuntimeProven=$runtimeProven;ProductionRecipes=$productionRecipes}
}

function Get-PMMSemanticHintRules {
  $path=Get-PMMCKLStablePath 'behavior-symbols.json'
  if(-not(Test-Path -LiteralPath $path -PathType Leaf)){return @()}
  try{return @((Get-Content -LiteralPath $path -Raw|ConvertFrom-Json).rules)}catch{return @()}
}

function Get-PMMKnownSemanticFixture($Group,[array]$ProviderRecords) {
  $path=Get-PMMCKLStablePath 'known-fixtures.json'
  if(-not(Test-Path -LiteralPath $path -PathType Leaf)){return $null}
  try{$kb=Get-Content -LiteralPath $path -Raw|ConvertFrom-Json}catch{return $null}
  $asset=[string]$Group.Asset
  $actual=@($ProviderRecords|ForEach-Object{([string]$_.Mod.Hash).ToLowerInvariant()}|Sort-Object)
  foreach($fixture in @($kb.fixtures)){
    if([string]$fixture.asset -ne $asset){continue}
    $expected=@($fixture.providers|ForEach-Object{([string]$_.pakSha256).ToLowerInvariant()}|Sort-Object)
    if($actual.Count -ne $expected.Count){continue}
    $same=$true
    for($i=0;$i -lt $actual.Count;$i++){if($actual[$i] -ne $expected[$i]){$same=$false;break}}
    if($same){return $fixture}
  }
  return $null
}

function Get-PMMKnownBehaviorContext($Group,[array]$ProviderRecords) {
  $candidateIds=[System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
  if(Get-Command Find-PMMCKLCaseCandidates -ErrorAction SilentlyContinue){foreach($candidate in @(Find-PMMCKLCaseCandidates $Group $ProviderRecords|Where-Object{[string]$_.kind -eq 'behavior'})){[void]$candidateIds.Add([string]$candidate.knowledgeId)}}
  if($candidateIds.Count -eq 0){return @()}
  $path=Get-PMMCKLStablePath 'known-behaviors.json'
  if(-not(Test-Path -LiteralPath $path -PathType Leaf)){return @()}
  try{$kb=Get-Content -LiteralPath $path -Raw|ConvertFrom-Json}catch{return @()}
  $asset=[string]$Group.Asset
  $current=@{}
  foreach($record in @($ProviderRecords)){$current[[string]$record.Mod.Name]=([string]$record.Mod.Hash).ToLowerInvariant()}
  $result=[System.Collections.Generic.List[object]]::new()
  foreach($case in @($kb.cases)){
    if(-not$candidateIds.Contains([string]$case.id)){continue}
    if([string]$case.asset -ne $asset){continue}
    $matches=[System.Collections.Generic.List[string]]::new()
    foreach($knownProvider in @($case.providers)){
      $name=[string]$knownProvider.name
      if(-not$current.ContainsKey($name)){continue}
      $expectedHash=if($knownProvider.PSObject.Properties.Name -contains 'pakSha256'){([string]$knownProvider.pakSha256).ToLowerInvariant()}else{''}
      if($expectedHash -and $current[$name] -ne $expectedHash){continue}
      [void]$matches.Add($name)
    }
    if($matches.Count -gt 0){
      $result.Add([pscustomobject]@{
        Id=[string]$case.id;MatchedProviders=$matches.ToArray();Observed=[string]$case.observed;
        MergeLesson=[string]$case.mergeLesson;StructuralStatus=[string]$case.status.structural;RuntimeStatus=[string]$case.status.runtime
      })
    }
  }
  return $result.ToArray()
}

function Write-PMMSemanticEvidence($Group,$Vanilla,[array]$ProviderRecords,[string]$ReviewFolder) {
  if(-not$ReviewFolder -or -not(Test-Path -LiteralPath $ReviewFolder -PathType Container)){return ''}
  try{
    $vanillaStrings=Get-PMMSemanticFamilyStrings $Vanilla
    $providerEvidence=[System.Collections.Generic.List[object]]::new()
    $capsuleCandidates=[System.Collections.Generic.List[object]]::new()
    $addedSets=[System.Collections.Generic.List[object]]::new()
    $rules=@(Get-PMMSemanticHintRules)

    foreach($record in @($ProviderRecords)){
      $strings=Get-PMMSemanticFamilyStrings $record.Export
      $added=[System.Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
      $removed=[System.Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
      foreach($s in $strings){if(-not$vanillaStrings.Contains([string]$s)){[void]$added.Add([string]$s)}}
      foreach($s in $vanillaStrings){if(-not$strings.Contains([string]$s)){[void]$removed.Add([string]$s)}}
      $addedSets.Add($added)

      $hints=[System.Collections.Generic.List[object]]::new()
      foreach($rule in $rules){
        $matches=[System.Collections.Generic.List[string]]::new()
        foreach($symbol in @($rule.symbols)){
          foreach($candidate in $added){
            if([string]$candidate -eq [string]$symbol -or ([string]$candidate).IndexOf([string]$symbol,[StringComparison]::OrdinalIgnoreCase) -ge 0){[void]$matches.Add([string]$candidate)}
          }
        }
        $unique=@($matches.ToArray()|Sort-Object -Unique)
        if($unique.Count -gt 0){$hints.Add([pscustomobject]@{EffectClass=[string]$rule.effectClass;Hint=[string]$rule.hint;Evidence=$unique})}
      }

      foreach($hint in @($hints.ToArray())){
        $capsuleCandidates.Add([pscustomobject]@{
          Id=(([string]$record.Mod.Name)+':'+([string]$hint.EffectClass));Provider=[string]$record.Mod.Name;
          EffectClass=[string]$hint.EffectClass;Evidence=@($hint.Evidence);Interpretation=[string]$hint.Hint;
          Confidence='HEURISTIC_ONLY';Selectable=$false;
          Safety='Candidate grouping only. It is not a dependency-closed code capsule and cannot authorize inclusion/exclusion.'
        })
      }

      $providerEvidence.Add([pscustomobject]@{
        Provider=[string]$record.Mod.Name;PakSha256=[string]$record.Mod.Hash;
        AddedSymbols=@($added|Sort-Object|Select-Object -First 500);
        RemovedSymbols=@($removed|Sort-Object|Select-Object -First 250);
        BehaviorHints=$hints.ToArray()
      })
    }

    $shared=@()
    if($addedSets.Count -gt 0){
      $shared=@($addedSets[0]|ForEach-Object{[string]$_})
      for($i=1;$i -lt $addedSets.Count;$i++){$shared=@($shared|Where-Object{$addedSets[$i].Contains([string]$_)})}
      $shared=@($shared|Sort-Object -Unique)
    }

    $known=Get-PMMKnownSemanticFixture $Group $ProviderRecords
    $knownContext=@(Get-PMMKnownBehaviorContext $Group $ProviderRecords)
    $result=[ordered]@{
      Schema='PMM_SEMANTIC_EVIDENCE_V1';LabVersion='0.1';Asset=[string]$Group.Asset;
      Safety='Explanatory/read-only evidence only. This report never authorizes Build; a production adapter or explicitly accepted manual cooked solution must validate separately.';
      VanillaAvailable=[bool]$Vanilla;SharedAddedSymbols=$shared;Providers=$providerEvidence.ToArray();
      ChangeCapsuleCandidates=$capsuleCandidates.ToArray();
      KnownBehaviorContext=$knownContext;
      KnownFixture=$(if($known){[pscustomobject]@{Id=[string]$known.id;StructuralStatus=[string]$known.status.structural;RuntimeStatus=[string]$known.status.runtime;Interpretation=[string]$known.semanticEvidence.interpretation}}else{$null})
    }
    $path=Join-Path $ReviewFolder 'semantic-evidence.json'
    $result|ConvertTo-Json -Depth 30|Set-Content -LiteralPath $path -Encoding UTF8
    return $path
  }catch{
    Write-PMMLog ('Semantic Lab evidence failed for '+[string]$Group.Asset+': '+$_.Exception.Message)
    return ''
  }
}
