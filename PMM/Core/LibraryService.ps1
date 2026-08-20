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
  return (Join-Path $Script:Root 'Mods')
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
  return (Join-Path $Script:Root 'Data\mod-priorities.json')
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
  $assets=if($Manifest.PSObject.Properties.Name -contains 'Assets'){@($Manifest.Assets)}else{@()}
  $decisions=if($Manifest.PSObject.Properties.Name -contains 'Decisions'){@($Manifest.Decisions)}else{@()}
  return (Get-PMMEffectivePatchOrderSignature $assets @($mods.ToArray()) $decisions)
}

function Test-PMMPatchEffectiveOrderCompatible($Patch,[array]$SourceMods) {
  if(-not$Patch -or -not$Patch.Manifest -or -not$Patch.ManifestHashOk){return $false}
  $stored=Get-PMMManifestEffectivePatchOrderSignature $Patch.Manifest
  if([string]::IsNullOrWhiteSpace($stored)){return $false}
  $assets=if($Patch.Manifest.PSObject.Properties.Name -contains 'Assets'){@($Patch.Manifest.Assets)}else{@()}
  $decisions=if($Patch.Manifest.PSObject.Properties.Name -contains 'Decisions'){@($Patch.Manifest.Decisions)}else{@()}
  $current=Get-PMMEffectivePatchOrderSignature $assets $SourceMods $decisions
  return ([string]$stored -eq [string]$current)
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
  Remove-Item -LiteralPath (Join-Path $Script:Root 'Data\last-scan.json') -Force -ErrorAction SilentlyContinue

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
    Remove-Item -LiteralPath (Join-Path $Script:Root ('Data\\'+$name)) -Force -ErrorAction SilentlyContinue
  }
}

function Get-PMMPendingRemovalPath { return (Join-Path $Script:Root 'Data\pending-removals.json') }

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
  $mod=Find-PMMLibraryMod $Name
  if(-not$mod){throw (Get-PMMText "Mod not found in PMM library: $Name" "No se encontro el mod en la biblioteca PMM: $Name")}
  $dir=Split-Path -Parent ([string]$mod.Path)
  Add-PMMPendingRemoval $Name ([string]$mod.Hash)
  Remove-Item -LiteralPath $dir -Recurse -Force
  [void](Get-PMMModPriorityOrder)
  Clear-PMMLibraryHashCache;Clear-PakEntryCache;Clear-PMMAnalysisState
  Write-PMMLog "Deleted source mod from PMM library: $Name"
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
    $candidates.Add((Join-Path $Script:Root ("Builds\{0}\{1}.manifest.json" -f $area,$Pak.Name)))
  }

  # Upgrade/migration convenience: during development and after replacing PMM
  # with a newer portable folder, the deployed PAK may still have its manifest
  # in a neighboring older PMM folder. Search only immediate sibling PMM roots.
  try {
    $parent = Split-Path -Parent $Script:Root
    foreach ($dir in @(Get-ChildItem -LiteralPath $parent -Directory -Filter '*' -ErrorAction SilentlyContinue | Where-Object {$_.Name -like 'PalModMerger*' -or $_.Name -like 'Palworld*Manager*Merger*'})) {
      if ($dir.FullName -eq $Script:Root) { continue }
      foreach ($area in @('Current','Previous')) {
        $candidates.Add((Join-Path $dir.FullName ("Builds\{0}\{1}.manifest.json" -f $area,$Pak.Name)))
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
  return (Join-Path $Script:Root 'Builds\Current')
}

function Get-PMMLocalPatchArea([ValidateSet('Current','Previous')][string]$Area) {
  $root = Join-Path $Script:Root ("Builds\{0}" -f $Area)
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
  The game folder is deployment, but a PMM overlay is valuable user data.
  Keep an exact local master in Builds\Current. This is especially important
  when the user opens a newer portable PMM folder: preview 25 could discover an
  older deployed overlay but did not migrate the PAK itself into the new PMM.

  Generated overlays are NEVER copied into Mods/, because Mods/ is the source
  graph. Feeding a PMM output back as a source would recursively merge PMM's
  own patch on the next Analyze.
  #>
  $gameMods = Get-GameModsPath
  if (-not $gameMods -or -not (Test-Path -LiteralPath $gameMods -PathType Container)) { return 0 }

  $current = Get-PMMLocalPatchBackupRoot
  $previous = Join-Path $Script:Root 'Builds\Previous'
  New-Item -ItemType Directory -Force -Path $current,$previous | Out-Null
  $synced = 0

  # If a newer patch has already been built locally for the current active
  # source set, the still-deployed older patch is deployment history, not the
  # new Current artifact. Preserve it under Previous instead of re-copying it
  # into Builds\Current while the user is waiting to press DEPLOY.
  $activeSignature=''
  try{$activeSignature=Get-PMMLibrarySignature @(Get-LibraryMods)}catch{}
  $desiredLocal=$null
  if($activeSignature){
    foreach($candidate in @(Get-PMMLocalPatchBackups)){
      if([string]$candidate.SourceSignature -eq [string]$activeSignature){$desiredLocal=$candidate;break}
    }
  }

  foreach ($deployed in @(Get-ChildItem -LiteralPath $gameMods -Filter 'zzzzzzzzzz_PMM_Merge_*_P.pak' -File -ErrorAction SilentlyContinue)) {
    if($desiredLocal -and [string]$desiredLocal.Name -ne [string]$deployed.Name){
      $archive=Join-Path $previous $deployed.Name
      if(-not(Test-Path -LiteralPath $archive -PathType Leaf)){Copy-Item -LiteralPath $deployed.FullName -Destination $archive -Force}
      $manifestSource=Find-PMMManifestForDeployedPak $deployed
      if($manifestSource -and (Test-Path -LiteralPath $manifestSource -PathType Leaf) -and -not(Test-Path -LiteralPath ($archive+'.manifest.json') -PathType Leaf)){
        Copy-Item -LiteralPath $manifestSource -Destination ($archive+'.manifest.json') -Force
      }
      Write-PMMLog "Deployed PMM patch is older than the current locally built patch; preserved under Builds\Previous: $($deployed.Name)"
      continue
    }
    $localPak = Join-Path $current $deployed.Name
    $deployedHash = Get-Sha256 $deployed.FullName
    $needCopy = $true

    if (Test-Path -LiteralPath $localPak -PathType Leaf) {
      $localHash = Get-Sha256 $localPak
      if ($localHash -eq $deployedHash) {
        $needCopy = $false
      } else {
        $stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
        $oldName = ([IO.Path]::GetFileNameWithoutExtension($deployed.Name)) + "_local_${stamp}.pak"
        $oldPath = Join-Path $previous $oldName
        Move-Item -LiteralPath $localPak -Destination $oldPath -Force
        $oldManifest = $localPak + '.manifest.json'
        if (Test-Path -LiteralPath $oldManifest -PathType Leaf) {
          Move-Item -LiteralPath $oldManifest -Destination ($oldPath + '.manifest.json') -Force
        }
        Write-PMMLog "Archived mismatched local PMM patch before syncing deployed copy: $($deployed.Name)"
      }
    }

    if ($needCopy) {
      Copy-Item -LiteralPath $deployed.FullName -Destination $localPak -Force
      $synced++
      Write-PMMLog "Backed up deployed PMM patch into current portable library: $($deployed.Name)"
    }

    $manifestSource = Find-PMMManifestForDeployedPak $deployed
    if ($manifestSource -and (Test-Path -LiteralPath $manifestSource -PathType Leaf)) {
      $localManifest = $localPak + '.manifest.json'
      $copyManifest = $true
      if (Test-Path -LiteralPath $localManifest -PathType Leaf) {
        try { $copyManifest = ((Get-Sha256 $localManifest) -ne (Get-Sha256 $manifestSource)) } catch { $copyManifest = $true }
      }
      if ($copyManifest) {
        Copy-Item -LiteralPath $manifestSource -Destination $localManifest -Force
        Write-PMMLog "Backed up PMM manifest into current portable library: $($deployed.Name)"
      }
    }
  }
  return $synced
}

function Get-PMMManagedPatches {
  <# Return deployed + Current + Previous patches, de-duplicated by filename. #>
  Sync-PMMDeployedPatchBackups | Out-Null
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
  if (-not $Patch -or -not $Patch.Manifest -or -not $Patch.ManifestHashOk) { return $false }
  $sourceSignature = Get-PMMLibrarySignature $SourceMods
  if ([string]$Patch.SourceSignature -ne [string]$sourceSignature) { return $false }
  # Saved-patch compatibility is based on output-changing priority winners,
  # not on unrelated positions in the full mod list.
  if(-not(Test-PMMPatchEffectiveOrderCompatible $Patch $SourceMods)){return $false}
  if ($Patch.Manifest.PSObject.Properties.Name -contains 'MappingsSha256') {
    $map = Join-Path $Script:Root 'Mappings\Mappings.usmap'
    if (-not (Test-Path -LiteralPath $map -PathType Leaf)) { return $false }
    if ([string]$Patch.Manifest.MappingsSha256 -ne (Get-Sha256 $map)) { return $false }
  }

  # A true-conflict choice is part of the output identity just like the source
  # hashes. After a forced Remerge the source mods may be unchanged while the
  # user selects a different provider for one byte/property. In that case an
  # older local patch must not keep Build disabled merely because its source
  # signature still matches.
  $planPath=Join-Path $Script:Root 'Data\merge-plan.json'
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
  if ($Patch.Manifest.PSObject.Properties.Name -contains 'MappingsSha256') {
    $map = Join-Path $Script:Root 'Mappings\Mappings.usmap'
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

function Get-PMMSelectedManagedPatch([array]$SourceMods) {
  if(Test-PMMNoPatchSelected){return $null}
  $all=@(Get-PMMManagedPatches)
  $compatible=@($all|Where-Object{Test-PMMPatchSourceSetCompatible $_ $SourceMods}|Sort-Object Modified -Descending)
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

  $currentRoot=Join-Path $Script:Root 'Builds\Current'
  $previousRoot=Join-Path $Script:Root 'Builds\Previous'
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

function Get-PMMDeploymentStatePath { return (Join-Path $Script:Root 'Data\deployment-state.json') }
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
    return (@($Plan.Assets|Where-Object{$_.Mode -ne 'Identical'}).Count -gt 0)
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
  $planPath=Join-Path $Script:Root 'Data\merge-plan.json'
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

  if(-not$noPatchSelected -and -not$selectedPatch -and -not$effectivePlan){
    throw (Get-PMMText 'The active mod list has not been analyzed and no saved patch matches the exact active source hashes + mappings. Run Analyze first.' 'La lista de mods activa no se ha analizado y ningun parche guardado coincide exactamente con los hashes de fuentes activos + mappings. Ejecuta Analizar primero.')
  }

  $requiresPatch=if($selectedPatch){$true}elseif($effectivePlan){Test-PMMPlanRequiresPatch $effectivePlan}else{$false}
  $patch=$selectedPatch
  if(-not$noPatchSelected -and $requiresPatch -and -not$patch){
    throw (Get-PMMText 'This analyzed set requires a compatibility patch. Build one or select a saved patch that matches this exact active source set.' 'Este conjunto analizado requiere un parche de compatibilidad. Crea uno o selecciona un parche guardado que coincida exactamente con este conjunto activo.')
  }

  $suppressed=@(if($noPatchSelected){Get-PMMExactDuplicateSuppressions $active}else{Get-PMMPatchDeploymentSuppressions $active $patch $effectivePlan})
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
  $root=Join-Path $Script:Root 'Builds\DeploymentBackups'
  if(-not(Test-Path -LiteralPath $root -PathType Container)){return}
  $dirs=@(Get-ChildItem -LiteralPath $root -Directory -ErrorAction SilentlyContinue|Sort-Object LastWriteTimeUtc -Descending)
  foreach($dir in @($dirs|Select-Object -Skip $Keep)){Remove-Item -LiteralPath $dir.FullName -Recurse -Force -ErrorAction SilentlyContinue}
}

function Invoke-PMMDeploymentTransaction($Context,$Operations,$State) {
  if(@($Operations.BlockingConflicts).Count -gt 0){throw (@($Operations.BlockingConflicts) -join "`n`n")}
  $id=(Get-Date -Format 'yyyyMMdd_HHmmss')+'_'+[guid]::NewGuid().ToString('N').Substring(0,8)
  $backupRoot=Join-Path $Script:Root ('Builds\DeploymentBackups\'+$id)
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
    foreach($action in @($Operations.CopyActions)){
      $stageName=([IO.Path]::GetFileName([string]$action.Destination))+'.pmmstage'
      $stagePath=Join-Path $stageRoot $stageName
      Copy-Item -LiteralPath ([string]$action.Source) -Destination $stagePath -Force
      $stageHash=Get-Sha256 $stagePath
      if($stageHash -ne [string]$action.ExpectedHash){throw "Deployment staging hash mismatch for $($action.Name): $stageHash != $($action.ExpectedHash)"}
      $stagedRecords.Add([pscustomobject]@{Destination=[string]$action.Destination;Stage=$stagePath;ExpectedHash=[string]$action.ExpectedHash;Name=[string]$action.Name})
    }

    # Phase 2: back up every existing file that the commit may replace/remove.
    foreach($path in @($touched)){
      if(Test-Path -LiteralPath $path -PathType Leaf){
        $backup=Join-Path $backupRoot (([IO.Path]::GetFileName($path))+'.before')
        Copy-Item -LiteralPath $path -Destination $backup -Force
        if((Get-Sha256 $backup) -ne (Get-Sha256 $path)){throw "Deployment backup verification failed for $path"}
        $backupRecords.Add([pscustomobject]@{Original=$path;Backup=$backup})
      }
    }
    if($oldStateExists){Copy-Item -LiteralPath $statePath -Destination (Join-Path $backupRoot 'deployment-state.before.json') -Force}
    if($oldPendingExists){Copy-Item -LiteralPath $pendingPath -Destination (Join-Path $backupRoot 'pending-removals.before.json') -Force}

    [pscustomobject]@{
      SchemaVersion=1;State='Prepared';Created=(Get-Date).ToString('o');GameMods=$Context.GameMods;
      Touched=[string[]]$touched;Copies=@($Operations.CopyActions);Removals=@($Operations.RemoveActions);Backups=$backupRecords.ToArray();
      DeploymentStateExisted=$oldStateExists;PendingRemovalsExisted=$oldPendingExists
    }|ConvertTo-Json -Depth 20|Set-Content -LiteralPath (Join-Path $backupRoot 'transaction.json') -Encoding UTF8

    # Phase 3: commit. Staged files live on the same volume as ~mods, so the
    # final Move-Item is a same-volume rename rather than a long copy window.
    $commitStarted=$true
    foreach($action in @($Operations.RemoveActions)){if(Test-Path -LiteralPath ([string]$action.Path) -PathType Leaf){Remove-Item -LiteralPath ([string]$action.Path) -Force}}
    foreach($record in $stagedRecords){
      if(Test-Path -LiteralPath ([string]$record.Destination) -PathType Leaf){Remove-Item -LiteralPath ([string]$record.Destination) -Force}
      Move-Item -LiteralPath ([string]$record.Stage) -Destination ([string]$record.Destination) -Force
    }

    # Phase 4: verify committed bytes before recording deployment state.
    foreach($record in $stagedRecords){
      if(-not(Test-Path -LiteralPath ([string]$record.Destination) -PathType Leaf)){throw "Deploy verification missing file: $($record.Destination)"}
      $hash=Get-Sha256 ([string]$record.Destination)
      if($hash -ne [string]$record.ExpectedHash){throw "Deploy verification hash mismatch for $($record.Name): $hash != $($record.ExpectedHash)"}
    }
    Write-PMMDeploymentState $State
    Write-PMMPendingRemovalRecords @()
    [pscustomobject]@{SchemaVersion=1;State='Committed';Completed=(Get-Date).ToString('o');GameMods=$Context.GameMods;Touched=[string[]]$touched;BackupCount=$backupRecords.Count}|ConvertTo-Json -Depth 10|Set-Content -LiteralPath (Join-Path $backupRoot 'transaction.json') -Encoding UTF8
    Remove-Item -LiteralPath $stageRoot -Recurse -Force -ErrorAction SilentlyContinue
    Remove-PMMOldDeploymentBackups 3
    return $backupRoot
  }catch{
    $failure=$_.Exception.Message
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
    $message=if($commitStarted){Get-PMMText 'Deploy failed after commit started, but PMM restored every managed game-folder file from its verified rollback backup.' 'Deploy fallo despues de iniciar el commit, pero PMM restauro todos los archivos gestionados de la carpeta del juego desde el backup verificado de rollback.'}else{Get-PMMText 'Deploy failed before any managed game-folder file was changed.' 'Deploy fallo antes de cambiar ningun archivo gestionado de la carpeta del juego.'}
    throw ("$message`n`n$failure")
  }
}

function Deploy-PMMManagedState {
  $context=Get-PMMDeploymentContext
  Stop-PalworldForDeployment

  # Recompute after Palworld is closed so hashes/collisions cannot change
  # between the user-facing preview and the actual commit.
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
  $backupRoot=Invoke-PMMDeploymentTransaction $context $ops $state
  if($context.Patch){
    try{Promote-PMMPatchToCurrent ([string]$context.Patch.Name)}catch{Write-PMMLog ('Deploy succeeded but local patch promotion failed: '+$_.Exception.Message)}
  }
  Write-PMMLog ("Transactional Deploy synchronized {0} source mods; suppressed alternatives={1}; patch={2}; managerOnly={3}; backup={4}" -f $context.DeployActive.Count,$context.Suppressed.Count,$(if($context.Patch){$context.Patch.Name}else{'none'}),[bool]$context.NoPatchSelected,$backupRoot)
  $suppressedText=if($context.Suppressed.Count -gt 0){$context.Suppressed -join ', '}else{Get-PMMText 'none' 'ninguno'}
  $patchResult=if($context.Patch){[string]$context.Patch.Name}elseif($context.NoPatchSelected){Get-PMMText 'none - source mods only' 'ninguno - solo mods fuente'}else{Get-PMMText 'not required' 'no requerido'}
  return (Get-PMMText ("Deploy complete. Source mods installed: {0}. Redundant byte-identical source PAKs kept only in PMM library: {1}. Compatibility patch: {2}. Managed changes were hash-verified and committed with rollback backup." -f $context.DeployActive.Count,$suppressedText,$patchResult) ("Deploy terminado. Mods fuente instalados: {0}. PAK fuente redundantes e identicos byte a byte conservados solo en la biblioteca PMM: {1}. Parche de compatibilidad: {2}. Los cambios gestionados se verificaron por hash y se aplicaron con backup para rollback." -f $context.DeployActive.Count,$suppressedText,$patchResult))
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

function Import-PMMMod([string]$Path) {
  if (-not (Test-Path -LiteralPath $Path)) {
    throw (Get-PMMText "Source does not exist: $Path" "No existe: $Path")
  }

  $ext = [IO.Path]::GetExtension($Path).ToLowerInvariant()
  $stage = Join-Path $Script:Root ('Cache\Import_' + [guid]::NewGuid().ToString('N'))
  New-Item -ItemType Directory -Force -Path $stage | Out-Null

  try {
    if ($ext -eq '.pak') {
      Copy-Item -LiteralPath $Path -Destination $stage
    } elseif ($ext -eq '.zip') {
      Expand-Archive -LiteralPath $Path -DestinationPath $stage -Force
    } elseif ($ext -in @('.7z','.rar')) {
      $seven = Get-Command 7z.exe -ErrorAction SilentlyContinue
      if (-not $seven) {
        throw (Get-PMMText '7-Zip is required for .7z/.rar archives, or import the .pak directly.' 'Para .7z/.rar instala 7-Zip o importa el .pak directamente.')
      }
      & $seven.Source x "-o$stage" -y $Path | Out-Null
      if ($LASTEXITCODE -ne 0) {
        throw (Get-PMMText '7-Zip could not extract the archive.' '7-Zip no pudo extraer el archivo.')
      }
    } else {
      throw (Get-PMMText 'Unsupported archive format.' 'Formato no compatible.')
    }

    $paks = @(Get-ChildItem -LiteralPath $stage -Filter *.pak -File -Recurse)
    if ($paks.Count -eq 0) {
      throw (Get-PMMText 'The archive does not contain any .pak files.' 'El archivo no contiene ningun .pak.')
    }

    foreach ($pak in $paks) {
      if ($pak.Name -like 'zzzzzzzzzz_PMM_Merge_*_P.pak') {
        Import-PMMPatchBackup $pak.FullName | Out-Null
        continue
      }

      $hash = Get-Sha256 $pak.FullName
      Remove-PMMPendingRemoval $pak.Name
      $slug = ([IO.Path]::GetFileNameWithoutExtension($pak.Name) -replace '[^A-Za-z0-9_.-]','_')
      $dst = Join-Path (Get-LibraryRoot) $slug
      $disabledCopy=Join-Path (Get-PMMDisabledModRoot) $slug
      if(Test-Path -LiteralPath $disabledCopy -PathType Container){Remove-Item -LiteralPath $disabledCopy -Recurse -Force}
      New-Item -ItemType Directory -Force -Path $dst | Out-Null
      Copy-Item -LiteralPath $pak.FullName -Destination (Join-Path $dst $pak.Name) -Force

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
  } finally {
    Remove-Item -LiteralPath $stage -Recurse -Force -ErrorAction SilentlyContinue
  }
}

function Import-GameModsToLibrary {
  $gp = Get-GameModsPath
  if (-not $gp) {
    throw (Get-PMMText 'Configure or detect Palworld before importing game ~mods.' 'Configura o detecta Palworld antes de importar los ~mods del juego.')
  }
  Ensure-GameModsFolder

  $count = 0
  foreach ($p in @(Get-ChildItem -LiteralPath $gp -Filter *.pak -File -ErrorAction SilentlyContinue)) {
    # PMM overlays are imported as managed backups, never as source mods.
    if ($p.Name -like 'zzzzzzzzzz_PMM_Merge_*_P.pak') {
      Import-PMMPatchBackup $p.FullName | Out-Null
      continue
    }
    Import-PMMMod $p.FullName
    $count++
  }
  return $count
}
