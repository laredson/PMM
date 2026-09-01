<#
AIIO Game Reference on-demand hydration
=======================================

CREATE_MOD may discover exact Vanilla assets that are present in Pal-Windows.pak
but were not part of the reusable PMM_GAME_REFERENCE_SCOPE_V1 extraction. This
service exposes those paths through the already-persisted PAK index and hydrates
only an explicitly requested cooked family into the current Game Reference.

Safety rules:
  * never accept fuzzy paths for hydration: one exact .uasset is required;
  * only entries already present in the current Pal-Windows.pak index are eligible;
  * keep the base Game Reference identity (PAK index + mappings) unchanged;
  * serialize mutation with the normal GameReference.build.lock;
  * hash every hydrated part before publishing it to the family index;
  * never deploy, build, or activate anything from this service.
#>

$Script:PMMAIIOPakIndexCatalogCache=$null
$Script:PMMAIIOPakIndexCatalogStamp=''

function Get-PMMAIIOPakIndexCatalog {
  [CmdletBinding()]
  param()

  [void](Get-PMMAIIOGameReferenceProof -RequireCurrent)
  $indexPath=Join-Path (Get-PMMGameReferenceIndexRoot) 'pak-index.txt'
  if(-not(Test-Path -LiteralPath $indexPath -PathType Leaf)){throw 'Current Game Reference has no persisted Pal-Windows.pak index.'}
  $item=Get-Item -LiteralPath $indexPath
  $stamp=([IO.Path]::GetFullPath($item.FullName).ToLowerInvariant()+'|'+[string]$item.Length+'|'+$item.LastWriteTimeUtc.Ticks)
  if($Script:PMMAIIOPakIndexCatalogCache -and $Script:PMMAIIOPakIndexCatalogStamp -eq $stamp){
    return $Script:PMMAIIOPakIndexCatalogCache
  }

  $partsByStem=@{}
  foreach($raw in @(Get-Content -LiteralPath $indexPath -Encoding UTF8)){
    if([string]::IsNullOrWhiteSpace([string]$raw)){continue}
    $normalized=Normalize-PMMReferenceLogicalPath ([string]$raw)
    $ext=[IO.Path]::GetExtension($normalized).ToLowerInvariant()
    if($ext -notin @('.uasset','.uexp','.ubulk','.uptnl')){continue}
    $stem=Get-PakLogicalStem $normalized
    if([string]::IsNullOrWhiteSpace($stem)){continue}
    $key=$stem.ToLowerInvariant()
    if(-not$partsByStem.ContainsKey($key)){$partsByStem[$key]=[Collections.Generic.List[object]]::new()}
    $partsByStem[$key].Add([pscustomobject]@{
      RawEntry=[string]$raw
      Normalized=$normalized
      Extension=$ext
    })
  }

  $families=[Collections.Generic.List[object]]::new()
  foreach($key in @($partsByStem.Keys|Sort-Object)){
    $parts=@($partsByStem[$key].ToArray())
    $headers=@($parts|Where-Object{[string]$_.Extension -eq '.uasset'})
    if($headers.Count -ne 1){continue}
    $asset=[string]$headers[0].Normalized
    $families.Add([pscustomobject]@{
      LogicalPath=$asset
      FamilyKey=$key
      Tokens=@(Get-PMMReferenceTokens $asset)
      Availability='PakIndexOnly'
      Hydrated=$false
    })
  }

  $catalog=[pscustomobject]@{
    Schema='PMM_AIIO_PAK_INDEX_CATALOG_V1'
    IndexPath=$indexPath
    Families=@($families.ToArray())
    PartsByStem=$partsByStem
  }
  $Script:PMMAIIOPakIndexCatalogCache=$catalog
  $Script:PMMAIIOPakIndexCatalogStamp=$stamp
  return $catalog
}

function Get-PMMAIIOGameReferenceSearchMatch {
  param(
    [Parameter(Mandatory=$true)][string]$Asset,
    [Parameter(Mandatory=$true)][string]$FamilyKey,
    [array]$Tokens=@(),
    [Parameter(Mandatory=$true)][string]$NormalizedQuery,
    [array]$QueryTokens=@()
  )
  $assetLower=$Asset.ToLowerInvariant()
  $familyLower=$FamilyKey.ToLowerInvariant()
  $leaf=([IO.Path]::GetFileNameWithoutExtension($Asset)).ToLowerInvariant()
  $score=0;$reasons=[Collections.Generic.List[string]]::new()

  if($assetLower -eq $NormalizedQuery -or $familyLower -eq (Get-PakLogicalStem $NormalizedQuery)){
    $score+=1000;$reasons.Add('exact logical family')
  }elseif($assetLower.StartsWith($NormalizedQuery,[StringComparison]::OrdinalIgnoreCase)){
    $score+=520;$reasons.Add('logical path prefix')
  }elseif($assetLower.Contains($NormalizedQuery)){
    $score+=360;$reasons.Add('logical path contains query')
  }elseif($leaf.Contains($NormalizedQuery)){
    $score+=320;$reasons.Add('asset name contains query')
  }

  $familyTokens=@($Tokens|ForEach-Object{([string]$_).ToLowerInvariant()})
  $matched=[Collections.Generic.List[string]]::new()
  foreach($token in @($QueryTokens)){
    $candidate=([string]$token).ToLowerInvariant()
    if($familyTokens -contains $candidate){$matched.Add($candidate)}
  }
  if($matched.Count -gt 0){
    $score+=[Math]::Min(300,80*$matched.Count)
    $reasons.Add('token match: '+(@($matched.ToArray()) -join ', '))
  }
  return [pscustomobject]@{Score=$score;Reason=(@($reasons.ToArray()) -join '; ')}
}

function Find-PMMAIIOHydratedGameReferenceFamily {
  param([Parameter(Mandatory=$true)][string]$LogicalPath)
  $asset=Normalize-PMMReferenceLogicalPath $LogicalPath
  $stem=(Get-PakLogicalStem $asset).ToLowerInvariant()
  $matches=@(Get-PMMGameReferenceFamilies|Where-Object{
    (Normalize-PMMReferenceLogicalPath ([string]$_.Asset)) -ieq $asset -or [string]$_.FamilyKey -ieq $stem
  }|Select-Object -First 2)
  if($matches.Count -eq 1){return $matches[0]}
  if($matches.Count -gt 1){throw ('Current Game Reference contains duplicate family identity for: '+$asset)}
  return $null
}

function Ensure-PMMAIIOGameReferenceFamilyExact {
  [CmdletBinding()]
  param([Parameter(Mandatory=$true)][string]$LogicalPath)

  $asset=Normalize-PMMReferenceLogicalPath $LogicalPath
  if([string]::IsNullOrWhiteSpace($asset) -or [IO.Path]::GetExtension($asset) -ine '.uasset'){
    throw ('An exact Game Reference .uasset logical path is required: '+$LogicalPath)
  }
  [void](Get-PMMAIIOGameReferenceProof -RequireCurrent)

  $existing=Find-PMMAIIOHydratedGameReferenceFamily $asset
  if($existing){return $existing}

  $catalog=Get-PMMAIIOPakIndexCatalog
  $stem=(Get-PakLogicalStem $asset).ToLowerInvariant()
  if(-not$catalog.PartsByStem.ContainsKey($stem)){
    throw ('The exact family does not exist in the current Pal-Windows.pak index: '+$asset)
  }

  $root=Get-PMMGameReferenceRoot
  $lockPath=Join-Path $root 'GameReference.build.lock'
  $referenceLock=$null
  $stage=Join-Path (Join-PMMPath 'Temp' 'AIIO') ('GameReferenceHydrate_'+[guid]::NewGuid().ToString('N'))
  $created=[Collections.Generic.List[string]]::new()
  $indexBackup=Join-Path $stage 'families.jsonl.before'
  $currentStateBackup=Join-Path $stage 'state.json.before'
  $rootStateBackup=Join-Path $stage 'current.json.before'
  $indexCommitted=$false
  try{
    try{$referenceLock=[IO.File]::Open($lockPath,[IO.FileMode]::OpenOrCreate,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)}catch{
      throw 'Game Reference is currently busy. Finish the active Game Reference operation and retry the AIIO data request.'
    }

    # Another request may have hydrated the same family while we were waiting.
    $Script:PMMGameReferenceFamilyCache=$null;$Script:PMMGameReferenceFamilyCacheStamp=''
    $existing=Find-PMMAIIOHydratedGameReferenceFamily $asset
    if($existing){return $existing}

    $reference=Get-PMMGameReferenceState
    if([string]$reference.Status -ne 'Current'){throw ('Game Reference became unavailable before hydration: '+[string]$reference.Reason)}
    $state=$reference.State
    $pak=Get-PMMGameReferencePak
    if([string]::IsNullOrWhiteSpace($pak)){throw 'Configured Palworld installation has no Pal-Windows.pak for on-demand hydration.'}

    # Refresh the catalog after taking the lock. A Game Reference rebuild may
    # have completed while this request was waiting.
    $catalog=Get-PMMAIIOPakIndexCatalog
    if(-not$catalog.PartsByStem.ContainsKey($stem)){
      throw ('The exact family no longer exists in the current Pal-Windows.pak index: '+$asset)
    }
    $indexRows=@($catalog.PartsByStem[$stem].ToArray())
    $headers=@($indexRows|Where-Object{[string]$_.Extension -eq '.uasset' -and (Normalize-PMMReferenceLogicalPath ([string]$_.Normalized)) -ieq $asset})
    if($headers.Count -ne 1){
      throw ('The current Pal-Windows.pak index does not resolve one exact .uasset header for: '+$asset)
    }

    $pakIndexPath=Join-Path (Get-PMMGameReferenceIndexRoot) 'pak-index.txt'
    if(-not(Test-Path -LiteralPath $pakIndexPath -PathType Leaf)){throw 'Current Game Reference PAK index disappeared before hydration.'}
    $actualIndexHash=Get-Sha256 $pakIndexPath
    if(([string]$state.PakIndexSha256).ToLowerInvariant() -ne $actualIndexHash.ToLowerInvariant()){
      throw 'Current Game Reference PAK index hash changed; rebuild Game Reference before on-demand extraction.'
    }

    New-Item -ItemType Directory -Force -Path $stage|Out-Null
    Set-PMMTransientStageOwner $stage 'AIIOGameReferenceHydration'
    $parts=[Collections.Generic.List[object]]::new()
    [int64]$familyBytes=0
    foreach($row in @($indexRows|Sort-Object Extension)){
      $rel=Normalize-PMMReferenceLogicalPath ([string]$row.Normalized)
      if((Get-PakLogicalStem $rel).ToLowerInvariant() -ne $stem){continue}
      $stageFile=Join-Path $stage ('family\'+$rel.Replace([char]47,[char]92))
      New-Item -ItemType Directory -Force -Path (Split-Path -Parent $stageFile)|Out-Null
      Get-PakEntry $pak ([string]$row.RawEntry) $stageFile
      if(-not(Test-Path -LiteralPath $stageFile -PathType Leaf)){throw ('On-demand extraction did not produce: '+$rel)}
      $size=[int64](Get-Item -LiteralPath $stageFile).Length
      $hash=Get-Sha256 $stageFile
      $familyBytes+=$size
      if($familyBytes -gt 536870912){throw ('On-demand Game Reference family exceeds the 512 MiB safety ceiling: '+$asset)}
      $parts.Add([pscustomobject]@{
        Extension=[string]$row.Extension
        RelativePath=$rel
        Size=$size
        Sha256=$hash
        StagePath=$stageFile
      })
    }
    if(@($parts.ToArray()|Where-Object{[string]$_.Extension -eq '.uasset'}).Count -ne 1){
      throw ('On-demand extraction produced an invalid cooked family topology for: '+$asset)
    }

    $family=[ordered]@{
      Schema='PMM_GAME_REFERENCE_FAMILY_V1'
      FamilyKey=$stem
      Asset=$asset
      Bytes=$familyBytes
      Parts=@($parts.ToArray()|ForEach-Object{
        [pscustomobject]@{
          Extension=[string]$_.Extension
          RelativePath=[string]$_.RelativePath
          Size=[int64]$_.Size
          Sha256=[string]$_.Sha256
        }
      })
      Tokens=@(Get-PMMReferenceTokens $stem)
    }

    $familiesPath=Join-Path (Get-PMMGameReferenceIndexRoot) 'families.jsonl'
    $currentStatePath=Join-Path (Get-PMMGameReferenceCurrentRoot) 'state.json'
    $rootStatePath=Get-PMMGameReferenceStatePath
    Copy-Item -LiteralPath $familiesPath -Destination $indexBackup -Force
    Copy-Item -LiteralPath $currentStatePath -Destination $currentStateBackup -Force
    Copy-Item -LiteralPath $rootStatePath -Destination $rootStateBackup -Force

    $cookedRoot=Get-PMMGameReferenceCookedRoot
    foreach($part in @($parts.ToArray())){
      $dest=Join-Path $cookedRoot (([string]$part.RelativePath).Replace([char]47,[char]92))
      New-Item -ItemType Directory -Force -Path (Split-Path -Parent $dest)|Out-Null
      if(Test-Path -LiteralPath $dest -PathType Leaf){
        if((Get-Sha256 $dest) -ne ([string]$part.Sha256).ToLowerInvariant()){
          throw ('Refused to overwrite unexpected existing Game Reference bytes during hydration: '+[string]$part.RelativePath)
        }
      }else{
        $partial=$dest+'.hydrate.'+[guid]::NewGuid().ToString('N')+'.partial'
        Copy-Item -LiteralPath ([string]$part.StagePath) -Destination $partial -Force
        Move-Item -LiteralPath $partial -Destination $dest -Force
        $created.Add($dest)
      }
    }

    $newLine=($family|ConvertTo-Json -Depth 15 -Compress)
    $newIndex=Join-Path (Get-PMMGameReferenceIndexRoot) ('families.'+[guid]::NewGuid().ToString('N')+'.tmp')
    $existingLines=@(Get-Content -LiteralPath $familiesPath -Encoding UTF8)
    @($existingLines+$newLine)|Set-Content -LiteralPath $newIndex -Encoding UTF8
    Move-Item -LiteralPath $newIndex -Destination $familiesPath -Force
    $indexCommitted=$true

    $state.ExtractedFamilyCount=[int]$state.ExtractedFamilyCount+1
    $state.ExtractedFileCount=[int]$state.ExtractedFileCount+$parts.Count
    $state.ExtractedBytes=[int64]$state.ExtractedBytes+$familyBytes
    if($state.PSObject.Properties.Name -contains 'SelectedEntryCount'){$state.SelectedEntryCount=[int]$state.SelectedEntryCount+$parts.Count}
    if(-not($state.PSObject.Properties.Name -contains 'OnDemandFamilyCount')){$state|Add-Member -NotePropertyName OnDemandFamilyCount -NotePropertyValue 0}
    if(-not($state.PSObject.Properties.Name -contains 'OnDemandFileCount')){$state|Add-Member -NotePropertyName OnDemandFileCount -NotePropertyValue 0}
    if(-not($state.PSObject.Properties.Name -contains 'OnDemandBytes')){$state|Add-Member -NotePropertyName OnDemandBytes -NotePropertyValue ([int64]0)}
    if(-not($state.PSObject.Properties.Name -contains 'HydrationPolicy')){$state|Add-Member -NotePropertyName HydrationPolicy -NotePropertyValue 'AIIO_ON_DEMAND_V1'}
    if(-not($state.PSObject.Properties.Name -contains 'LastHydratedUtc')){$state|Add-Member -NotePropertyName LastHydratedUtc -NotePropertyValue ''}
    $state.OnDemandFamilyCount=[int]$state.OnDemandFamilyCount+1
    $state.OnDemandFileCount=[int]$state.OnDemandFileCount+$parts.Count
    $state.OnDemandBytes=[int64]$state.OnDemandBytes+$familyBytes
    $state.HydrationPolicy='AIIO_ON_DEMAND_V1'
    $state.LastHydratedUtc=[DateTime]::UtcNow.ToString('o')

    Write-PMMAIIOJsonAtomic $currentStatePath $state 30
    Write-PMMAIIOJsonAtomic $rootStatePath $state 30
    $Script:PMMGameReferenceFamilyCache=$null;$Script:PMMGameReferenceFamilyCacheStamp=''
    Write-PMMLog ('Game Reference on-demand hydration: '+$asset+' | '+$parts.Count+' files | '+$familyBytes+' bytes.')

    $hydrated=Find-PMMAIIOHydratedGameReferenceFamily $asset
    if(-not$hydrated){throw ('Hydrated Game Reference family was not visible after publication: '+$asset)}
    return $hydrated
  }catch{
    $failure=$_.Exception
    if($indexCommitted -and (Test-Path -LiteralPath $indexBackup -PathType Leaf)){
      try{Copy-Item -LiteralPath $indexBackup -Destination (Join-Path (Get-PMMGameReferenceIndexRoot) 'families.jsonl') -Force}catch{}
      try{Copy-Item -LiteralPath $currentStateBackup -Destination (Join-Path (Get-PMMGameReferenceCurrentRoot) 'state.json') -Force}catch{}
      try{Copy-Item -LiteralPath $rootStateBackup -Destination (Get-PMMGameReferenceStatePath) -Force}catch{}
    }
    foreach($path in @($created.ToArray())){Remove-Item -LiteralPath $path -Force -ErrorAction SilentlyContinue}
    $Script:PMMGameReferenceFamilyCache=$null;$Script:PMMGameReferenceFamilyCacheStamp=''
    throw $failure
  }finally{
    try{if($referenceLock){$referenceLock.Dispose()}}catch{}
    Remove-Item -LiteralPath $stage -Recurse -Force -ErrorAction SilentlyContinue
    try{Remove-PMMTransientStageOwner $stage}catch{}
  }
}

# Override the narrow V1 resolver loaded earlier by AIIO.ModCreationService.
# Existing families are returned immediately; missing exact families are hydrated
# from the persisted PAK index before the normal CREATE_MOD request continues.
function Get-PMMAIIOGameReferenceFamilyExact([string]$LogicalPath) {
  return (Ensure-PMMAIIOGameReferenceFamilyExact -LogicalPath $LogicalPath)
}

# Override the V1 search so discovery can see every .uasset path in the persisted
# Pal-Windows.pak index, not only families already extracted into Game Reference.
# Index-only results intentionally expose no fake bytes/hashes; AIIO must request
# extract_game_reference_asset for the exact path before using it as source proof.
function Search-PMMAIIOGameReferenceFamilies {
  [CmdletBinding()]
  param([Parameter(Mandatory=$true)][string]$Query,[ValidateRange(1,200)][int]$MaximumResults=100)

  [void](Get-PMMAIIOGameReferenceProof -RequireCurrent)
  $queryText=$Query.Trim()
  if([string]::IsNullOrWhiteSpace($queryText)){throw 'Game Reference query cannot be empty.'}
  if($queryText.Length -gt 256 -or $queryText.IndexOf([char]0) -ge 0 -or $queryText.Contains([char]10) -or $queryText.Contains([char]13)){
    throw 'Game Reference query is invalid or exceeds 256 characters.'
  }

  $normalizedQuery=(Normalize-PMMReferenceLogicalPath $queryText).ToLowerInvariant()
  $queryTokens=@(Get-PMMReferenceTokens $queryText|ForEach-Object{([string]$_).ToLowerInvariant()}|Sort-Object -Unique)
  $rows=[Collections.Generic.List[object]]::new()
  $seen=[Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)

  foreach($family in @(Get-PMMGameReferenceFamilies)){
    $asset=Normalize-PMMReferenceLogicalPath ([string]$family.Asset)
    $familyKey=([string]$family.FamilyKey).ToLowerInvariant()
    $match=Get-PMMAIIOGameReferenceSearchMatch -Asset $asset -FamilyKey $familyKey -Tokens @($family.Tokens) -NormalizedQuery $normalizedQuery -QueryTokens $queryTokens
    if([int]$match.Score -le 0){continue}
    [void]$seen.Add($familyKey)
    $parts=@($family.Parts|ForEach-Object{
      [pscustomobject]@{
        Extension=[string]$_.Extension
        RelativePath=[string]$_.RelativePath
        Size=[int64]$_.Size
        Sha256=[string]$_.Sha256
      }
    })
    $rows.Add([pscustomobject]@{
      LogicalPath=$asset
      FamilyKey=$familyKey
      Bytes=[int64]$family.Bytes
      Parts=$parts
      Tokens=@($family.Tokens)
      MatchScore=[int]$match.Score
      MatchReason=[string]$match.Reason
      Availability='GameReference'
      Hydrated=$true
    })
  }

  $catalog=Get-PMMAIIOPakIndexCatalog
  foreach($entry in @($catalog.Families)){
    $familyKey=([string]$entry.FamilyKey).ToLowerInvariant()
    if($seen.Contains($familyKey)){continue}
    $asset=Normalize-PMMReferenceLogicalPath ([string]$entry.LogicalPath)
    $match=Get-PMMAIIOGameReferenceSearchMatch -Asset $asset -FamilyKey $familyKey -Tokens @($entry.Tokens) -NormalizedQuery $normalizedQuery -QueryTokens $queryTokens
    if([int]$match.Score -le 0){continue}
    $rows.Add([pscustomobject]@{
      LogicalPath=$asset
      FamilyKey=$familyKey
      Bytes=[int64]0
      Parts=@()
      Tokens=@($entry.Tokens)
      MatchScore=[int]$match.Score
      MatchReason=(([string]$match.Reason+'; PAK index only - request exact extraction to hydrate').Trim('; '))
      Availability='PakIndexOnly'
      Hydrated=$false
    })
  }

  return @($rows.ToArray()|Sort-Object @{Expression='MatchScore';Descending=$true},@{Expression='LogicalPath';Ascending=$true}|Select-Object -First $MaximumResults)
}
