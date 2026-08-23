<#
Palworld Manager Merger v1.1 - local Vanilla Game Reference Library
===================================================================

The Game Reference Library is generated locally from the user's installed
Pal-Windows.pak.  It is evidence for Semantic Lab / AI handoffs; it NEVER grants
permission to merge or write a cooked asset.

Performance rule: list the huge PAK once and bulk-unpack the broad reference
roots in one repak process.  Do not regress to per-file or tiny-batch unpacking.
#>

$Script:PMMGameReferenceScopeVersion = 'PMM_GAME_REFERENCE_SCOPE_V1'
$Script:PMMGameReferenceFamilyCache = $null
$Script:PMMGameReferenceFamilyCacheStamp = ''

function Get-PMMGameReferenceRoot { return (Join-Path $Script:Root 'Data\GameReference') }
function Get-PMMGameReferenceCurrentRoot { return (Join-Path (Get-PMMGameReferenceRoot) 'current') }
function Get-PMMGameReferenceCookedRoot { return (Join-Path (Get-PMMGameReferenceCurrentRoot) 'cooked') }
function Get-PMMGameReferenceIndexRoot { return (Join-Path (Get-PMMGameReferenceCurrentRoot) 'index') }
function Get-PMMGameReferenceStatePath { return (Join-Path (Get-PMMGameReferenceRoot) 'current.json') }

function Get-PMMGameReferencePak {
  $cfg=Get-PMMConfig
  if(-not$cfg -or [string]::IsNullOrWhiteSpace([string]$cfg.GamePath)){return ''}
  $pak=Join-Path ([string]$cfg.GamePath) 'Pal\Content\Paks\Pal-Windows.pak'
  if(Test-Path -LiteralPath $pak -PathType Leaf){return [IO.Path]::GetFullPath($pak)}
  return ''
}

function Normalize-PMMReferenceLogicalPath([string]$Path) {
  if($null -eq $Path){return ''}
  $n=([string]$Path).Trim().Replace([char]92,[char]47)
  while($n.StartsWith('/')){$n=$n.Substring(1)}
  while($n.StartsWith('../')){$n=$n.Substring(3)}
  return $n
}

function Get-PMMReferenceTokens([string]$Text) {
  $set=[System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
  if([string]::IsNullOrWhiteSpace($Text)){return @()}
  $generic=@('pal','content','blueprint','datatable','character','monster','player','common','component','action','base','uasset','uexp','ubulk','uptnl','asset','provider','windows','data')
  $segments=@(([string]$Text -replace '[\\/\.\-:;\[\]\(\)\{\},=+]+',' ') -split '\s+' | Where-Object{$_})
  foreach($segment in $segments){
    $parts=@($segment -split '_' | Where-Object{$_})
    foreach($part in $parts){
      $full=[string]$part
      if($full.Length -ge 3 -and $full.ToLowerInvariant() -notin $generic){[void]$set.Add($full)}
      $camel=($full -replace '([a-z0-9])([A-Z])','$1 $2')
      foreach($piece in @($camel -split '\s+'|Where-Object{$_})){
        if($piece.Length -ge 3 -and $piece.ToLowerInvariant() -notin $generic){[void]$set.Add([string]$piece)}
      }
    }
  }
  return @($set|Sort-Object)
}

function Get-PMMGameReferenceQuickIdentity {
  $pak=Get-PMMGameReferencePak
  $mapping=Join-Path $Script:Root 'Mappings\Mappings.usmap'
  $mappingHash=if(Test-Path -LiteralPath $mapping -PathType Leaf){Get-Sha256 $mapping}else{''}
  if(-not$pak){
    return [pscustomobject]@{PakPath='';PakSize=0;PakLastWriteUtc='';MappingsSha256=$mappingHash;ScopeVersion=$Script:PMMGameReferenceScopeVersion}
  }
  $info=Get-Item -LiteralPath $pak
  return [pscustomobject]@{
    PakPath=$pak;PakSize=[int64]$info.Length;PakLastWriteUtc=$info.LastWriteTimeUtc.ToString('o');
    MappingsSha256=$mappingHash;ScopeVersion=$Script:PMMGameReferenceScopeVersion
  }
}

function Get-PMMGameReferenceState {
  $identity=Get-PMMGameReferenceQuickIdentity
  $statePath=Get-PMMGameReferenceStatePath
  if(-not(Test-Path -LiteralPath $statePath -PathType Leaf)){
    return [pscustomobject]@{Status='NotBuilt';Reason='No local Game Reference library has been built yet.';FamilyCount=0;FileCount=0;Bytes=0;CreatedUtc='';Identity=$identity;State=$null}
  }
  try{$state=Get-Content -LiteralPath $statePath -Raw|ConvertFrom-Json}catch{
    return [pscustomobject]@{Status='Error';Reason=('current.json cannot be read: '+$_.Exception.Message);FamilyCount=0;FileCount=0;Bytes=0;CreatedUtc='';Identity=$identity;State=$null}
  }
  $currentRoot=Get-PMMGameReferenceCurrentRoot
  if(-not(Test-Path -LiteralPath $currentRoot -PathType Container)){
    return [pscustomobject]@{Status='Error';Reason='Game Reference metadata exists but the current library folder is missing.';FamilyCount=0;FileCount=0;Bytes=0;CreatedUtc='';Identity=$identity;State=$state}
  }
  $familiesPath=Join-Path (Get-PMMGameReferenceIndexRoot) 'families.jsonl'
  $cookedRoot=Get-PMMGameReferenceCookedRoot
  if(-not(Test-Path -LiteralPath $familiesPath -PathType Leaf) -or -not(Test-Path -LiteralPath $cookedRoot -PathType Container)){
    return [pscustomobject]@{Status='Error';Reason='Game Reference is incomplete (family index or cooked folder is missing). Rebuild it from Settings.';FamilyCount=0;FileCount=0;Bytes=0;CreatedUtc='';Identity=$identity;State=$state}
  }
  $same=$true;$reason='Current local Vanilla reference matches the configured Palworld installation and mappings.'
  if([string]::IsNullOrWhiteSpace([string]$identity.PakPath)){$same=$false;$reason='Configured Palworld installation has no Pal-Windows.pak.'}
  elseif([string]$state.ScopeVersion -ne [string]$identity.ScopeVersion){$same=$false;$reason='Reference extraction scope changed.'}
  elseif(-not [string]::IsNullOrWhiteSpace([string]$state.SourcePak) -and [string]$state.SourcePak -ine [string]$identity.PakPath){$same=$false;$reason='Configured Palworld installation changed.'}
  elseif(([string]$state.MappingsSha256).ToLowerInvariant() -ne ([string]$identity.MappingsSha256).ToLowerInvariant()){$same=$false;$reason='Mappings changed since this reference was built.'}
  elseif([int64]$state.SourcePakSize -ne [int64]$identity.PakSize){$same=$false;$reason='Pal-Windows.pak size changed.'}
  elseif([string]$state.SourcePakLastWriteUtc -ne [string]$identity.PakLastWriteUtc){$same=$false;$reason='Pal-Windows.pak timestamp changed.'}
  $status=if($same){'Current'}else{'Stale'}
  return [pscustomobject]@{
    Status=$status;Reason=$reason;FamilyCount=[int]$state.ExtractedFamilyCount;FileCount=[int]$state.ExtractedFileCount;
    Bytes=[int64]$state.ExtractedBytes;CreatedUtc=[string]$state.CreatedUtc;Identity=$identity;State=$state
  }
}


function Report-PMMGameReferenceProgress {
  param(
    [int]$Current=0,
    [int]$Total=100,
    [string]$Message='',
    [switch]$Indeterminate
  )
  $callback=Get-Command Set-PMMGameReferenceProgress -ErrorAction SilentlyContinue
  if($callback){
    try{Set-PMMGameReferenceProgress -Current $Current -Total $Total -Message $Message -Indeterminate:$Indeterminate}catch{}
  }
}

function Get-PMMGameReferenceBroadRoots {
  return @(
    'Pal/Content/Pal/DataTable/',
    'Pal/Content/Pal/Blueprint/Action/',
    'Pal/Content/Pal/Blueprint/Character/Monster/',
    'Pal/Content/Pal/Blueprint/Character/Player/',
    'Pal/Content/Pal/Blueprint/Component/'
  )
}

function Test-PMMGameReferenceEntrySelected([string]$Entry) {
  $n=Normalize-PMMReferenceLogicalPath $Entry
  $ext=[IO.Path]::GetExtension($n).ToLowerInvariant()
  if($ext -notin @('.uasset','.uexp','.ubulk','.uptnl')){return $false}
  foreach($root in @(Get-PMMGameReferenceBroadRoots)){
    if($n.StartsWith($root,[StringComparison]::OrdinalIgnoreCase)){return $true}
  }
  # Deliberate exact leaf allow-list for useful PMM assets outside the broad
  # roots.  Do not replace this with substring matching: Ranch != Branch.
  $stem=[IO.Path]::GetFileNameWithoutExtension($n)
  return ($stem -in @(
    'BP_WingGlider','WBP_JetPackGauge','DA_StaticItemDataAsset',
    'BP_BuildObject_BreedFarm','DT_PlayerStatusRankMasterDataTable','BP_PlayerBase'
  ))
}

function Get-PMMGameReferenceRawIncludeRoot([array]$SelectedRows,[string]$NormalizedRoot) {
  $needle=$NormalizedRoot.TrimEnd('/')+'/'
  foreach($row in @($SelectedRows)){
    $norm=[string]$row.Normalized
    if($norm.StartsWith($needle,[StringComparison]::OrdinalIgnoreCase)){
      $raw=([string]$row.Entry).Trim().Replace([char]92,[char]47)
      $idx=$raw.IndexOf($norm,[StringComparison]::OrdinalIgnoreCase)
      if($idx -ge 0){return $raw.Substring(0,$idx)+$NormalizedRoot.TrimEnd('/')}
      return $NormalizedRoot.TrimEnd('/')
    }
  }
  return $null
}

function Write-PMMGameReferenceFamilyIndex([string]$CookedRoot,[string]$IndexRoot) {
  New-Item -ItemType Directory -Force -Path $IndexRoot|Out-Null
  $groups=@{}
  foreach($file in @(Get-ChildItem -LiteralPath $CookedRoot -File -Recurse -ErrorAction Stop)){
    $rel=$file.FullName.Substring($CookedRoot.Length).TrimStart([char]92,[char]47).Replace([char]92,[char]47)
    $ext=[IO.Path]::GetExtension($rel).ToLowerInvariant()
    if($ext -notin @('.uasset','.uexp','.ubulk','.uptnl')){continue}
    $stem=$rel.Substring(0,$rel.Length-$ext.Length)
    $key=$stem.ToLowerInvariant()
    if(-not$groups.ContainsKey($key)){$groups[$key]=[System.Collections.Generic.List[object]]::new()}
    $groups[$key].Add([pscustomobject]@{File=$file;RelativePath=$rel;Extension=$ext})
  }
  $lines=[System.Collections.Generic.List[string]]::new()
  [int64]$totalBytes=0;$fileCount=0
  $orderedKeys=@($groups.Keys|Sort-Object)
  $familyDone=0;$familyTotal=[Math]::Max(1,$orderedKeys.Count)
  foreach($key in $orderedKeys){
    $familyDone++
    if($familyDone -eq 1 -or $familyDone -eq $familyTotal -or ($familyDone % 25) -eq 0){
      $pct=82+[int][Math]::Floor((14.0*$familyDone)/$familyTotal)
      Report-PMMGameReferenceProgress -Current $pct -Total 100 -Message ("Indexing/hashing Vanilla families ({0}/{1})..." -f $familyDone,$familyTotal)
    }
    $parts=[System.Collections.Generic.List[object]]::new();$header=''
    foreach($part in @($groups[$key]|Sort-Object Extension)){
      $hash=Get-Sha256 $part.File.FullName
      $size=[int64]$part.File.Length;$totalBytes+=$size;$fileCount++
      $parts.Add([pscustomobject]@{Extension=[string]$part.Extension;RelativePath=[string]$part.RelativePath;Size=$size;Sha256=$hash})
      if([string]$part.Extension -eq '.uasset'){$header=[string]$part.RelativePath}
    }
    if([string]::IsNullOrWhiteSpace($header)){$header=([string]$groups[$key][0].RelativePath)}
    $tokens=Get-PMMReferenceTokens $key
    $obj=[ordered]@{Schema='PMM_GAME_REFERENCE_FAMILY_V1';FamilyKey=$key;Asset=$header;Bytes=[int64](($parts.ToArray()|Measure-Object Size -Sum).Sum);Parts=$parts.ToArray();Tokens=$tokens}
    $lines.Add(($obj|ConvertTo-Json -Depth 12 -Compress))
  }
  $familiesPath=Join-Path $IndexRoot 'families.jsonl'
  $lines.ToArray()|Set-Content -LiteralPath $familiesPath -Encoding UTF8
  return [pscustomobject]@{FamilyCount=$groups.Count;FileCount=$fileCount;Bytes=$totalBytes;FamiliesPath=$familiesPath}
}

function Build-PMMGameReferenceLibrary {
  Report-PMMGameReferenceProgress -Current 0 -Total 100 -Message 'Preparing Game Reference build...'
  Assert-Repak
  $identity=Get-PMMGameReferenceQuickIdentity
  if([string]::IsNullOrWhiteSpace([string]$identity.PakPath)){throw (Get-PMMText 'Configure a valid Palworld installation before building Game Reference.' 'Configura una instalacion valida de Palworld antes de crear Game Reference.')}
  $pak=[string]$identity.PakPath
  $root=Get-PMMGameReferenceRoot
  New-Item -ItemType Directory -Force -Path $root|Out-Null
  $incoming=Join-Path $root ('_incoming_'+[guid]::NewGuid().ToString('N'))
  $cooked=Join-Path $incoming 'cooked';$index=Join-Path $incoming 'index'
  New-Item -ItemType Directory -Force -Path $cooked,$index|Out-Null
  try{
    Report-PMMGameReferenceProgress -Current 5 -Total 100 -Message 'Reading Pal-Windows.pak index...' -Indeterminate
    Write-PMMLog ('Game Reference: reading Pal-Windows.pak index once: '+$pak)
    $allEntries=@(Get-PakEntriesCached $pak)
    if($allEntries.Count -eq 0){throw 'Pal-Windows.pak index is empty.'}
    $pakIndexPath=Join-Path $index 'pak-index.txt'
    @($allEntries|ForEach-Object{[string]$_})|Set-Content -LiteralPath $pakIndexPath -Encoding UTF8
    $pakIndexHash=Get-Sha256 $pakIndexPath

    Report-PMMGameReferenceProgress -Current 15 -Total 100 -Message 'Selecting reusable Vanilla assets...'
    $selected=[System.Collections.Generic.List[object]]::new();$seen=@{}
    $entryDone=0;$entryTotal=[Math]::Max(1,$allEntries.Count)
    foreach($entry in $allEntries){
      $entryDone++
      if(($entryDone % 5000) -eq 0 -or $entryDone -eq $entryTotal){
        $pct=15+[int][Math]::Floor((10.0*$entryDone)/$entryTotal)
        Report-PMMGameReferenceProgress -Current $pct -Total 100 -Message ("Selecting reusable Vanilla assets ({0}/{1})..." -f $entryDone,$entryTotal)
      }
      if(-not(Test-PMMGameReferenceEntrySelected ([string]$entry))){continue}
      $norm=Normalize-PMMReferenceLogicalPath ([string]$entry)
      $key=$norm.ToLowerInvariant();if($seen.ContainsKey($key)){continue};$seen[$key]=$true
      $selected.Add([pscustomobject]@{Entry=[string]$entry;Normalized=$norm})
    }
    if($selected.Count -eq 0){throw 'Game Reference selector found no cooked assets; Palworld PAK layout may have changed.'}
    @($selected.ToArray()|Sort-Object Normalized|ForEach-Object{[string]$_.Entry})|Set-Content -LiteralPath (Join-Path $index 'selected-entries.txt') -Encoding UTF8

    # FAST PATH: one bulk unpack for the five large roots.
    $bulkArgs=@('unpack',$pak,'--output',$cooked,'--force','--quiet')
    $bulkRawRoots=[System.Collections.Generic.List[string]]::new()
    foreach($broad in @(Get-PMMGameReferenceBroadRoots)){
      $raw=Get-PMMGameReferenceRawIncludeRoot $selected.ToArray() $broad
      if($raw){$bulkRawRoots.Add([string]$raw);$bulkArgs+=@('--include',[string]$raw)}
    }
    if($bulkRawRoots.Count -gt 0){
      Report-PMMGameReferenceProgress -Current 30 -Total 100 -Message 'Bulk-extracting Vanilla reference roots with repak...' -Indeterminate
      Write-PMMLog ('Game Reference: bulk extracting '+$bulkRawRoots.Count+' broad roots in one repak process.')
      Invoke-RepakText -Arguments $bulkArgs -Context 'Game Reference bulk unpack'|Out-Null
    }
    Report-PMMGameReferenceProgress -Current 56 -Total 100 -Message 'Bulk extraction complete.'

    # Narrow exact extras outside the broad roots are extracted in one small
    # extra process, not hundreds of tiny batches.
    $extras=@($selected.ToArray()|Where-Object{
      $n=[string]$_.Normalized;$inside=$false
      foreach($r in @(Get-PMMGameReferenceBroadRoots)){if($n.StartsWith($r,[StringComparison]::OrdinalIgnoreCase)){$inside=$true;break}}
      -not$inside
    })
    if($extras.Count -gt 0){
      Report-PMMGameReferenceProgress -Current 58 -Total 100 -Message 'Extracting exact reference extras...' -Indeterminate
      $extraArgs=@('unpack',$pak,'--output',$cooked,'--force','--quiet')
      foreach($row in $extras){$extraArgs+=@('--include',[string]$row.Entry)}
      Invoke-RepakText -Arguments $extraArgs -Context 'Game Reference exact extras unpack'|Out-Null
    }
    Report-PMMGameReferenceProgress -Current 63 -Total 100 -Message 'Normalizing extracted reference files...'

    # A broad repak include may return auxiliary files in the selected trees.
    # Keep the on-disk library exactly equal to the cooked selector so future
    # handoffs cannot accidentally pick an unindexed/unintended file.
    $selectedPaths=[System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach($row in $selected){[void]$selectedPaths.Add([string]$row.Normalized)}
    $extractedFiles=@(Get-ChildItem -LiteralPath $cooked -File -Recurse -ErrorAction SilentlyContinue)
    $pruneDone=0;$pruneTotal=[Math]::Max(1,$extractedFiles.Count)
    foreach($file in $extractedFiles){
      $pruneDone++
      if(($pruneDone % 250) -eq 0 -or $pruneDone -eq $pruneTotal){
        $pct=63+[int][Math]::Floor((7.0*$pruneDone)/$pruneTotal)
        Report-PMMGameReferenceProgress -Current $pct -Total 100 -Message ("Normalizing extracted files ({0}/{1})..." -f $pruneDone,$pruneTotal)
      }
      $rel=Normalize-PMMReferenceLogicalPath ($file.FullName.Substring($cooked.Length).TrimStart([char]92,[char]47))
      if(-not$selectedPaths.Contains($rel)){Remove-Item -LiteralPath $file.FullName -Force -ErrorAction SilentlyContinue}
    }

    # Exact fallback is reserved only for entries the bulk extraction genuinely
    # missed.  This should normally be zero.
    $missing=[System.Collections.Generic.List[object]]::new()
    foreach($row in $selected){
      $dest=Join-Path $cooked (([string]$row.Normalized).Replace([char]47,[char]92))
      if(-not(Test-Path -LiteralPath $dest -PathType Leaf)){$missing.Add($row)}
    }
    if($missing.Count -gt 0){
      Write-PMMLog ('Game Reference: bulk extraction missed '+$missing.Count+' entries; using exact fallback only for them.')
      $missingDone=0;$missingTotal=[Math]::Max(1,$missing.Count)
      foreach($row in $missing){
        $missingDone++
        $pct=72+[int][Math]::Floor((8.0*$missingDone)/$missingTotal)
        Report-PMMGameReferenceProgress -Current $pct -Total 100 -Message ("Recovering missed entries ({0}/{1})..." -f $missingDone,$missingTotal)
        $dest=Join-Path $cooked (([string]$row.Normalized).Replace([char]47,[char]92))
        Get-PakEntry $pak ([string]$row.Entry) $dest
      }
    }

    Report-PMMGameReferenceProgress -Current 82 -Total 100 -Message 'Indexing and hashing extracted Vanilla families...'
    $indexStats=Write-PMMGameReferenceFamilyIndex $cooked $index
    $versionPath=Join-Path $Script:Root 'VERSION.txt'
    $pmmVersion=if(Test-Path -LiteralPath $versionPath -PathType Leaf){(Get-Content -LiteralPath $versionPath -Raw).Trim()}else{'unknown'}
    $state=[ordered]@{
      Schema='PMM_GAME_REFERENCE_STATE_V1';CreatedUtc=[DateTime]::UtcNow.ToString('o');PmmVersion=$pmmVersion;
      SourcePak=$pak;SourcePakSize=[int64]$identity.PakSize;SourcePakLastWriteUtc=[string]$identity.PakLastWriteUtc;
      PakIndexSha256=$pakIndexHash;MappingsSha256=[string]$identity.MappingsSha256;ScopeVersion=$Script:PMMGameReferenceScopeVersion;
      PakIndexEntryCount=$allEntries.Count;SelectedEntryCount=$selected.Count;ExtractedFamilyCount=[int]$indexStats.FamilyCount;
      ExtractedFileCount=[int]$indexStats.FileCount;ExtractedBytes=[int64]$indexStats.Bytes;Status='Current'
    }
    $state|ConvertTo-Json -Depth 12|Set-Content -LiteralPath (Join-Path $incoming 'state.json') -Encoding UTF8

    Report-PMMGameReferenceProgress -Current 97 -Total 100 -Message 'Publishing Game Reference atomically...'
    $current=Get-PMMGameReferenceCurrentRoot
    $old=Join-Path $root '_previous'
    Remove-Item -LiteralPath $old -Recurse -Force -ErrorAction SilentlyContinue
    if(Test-Path -LiteralPath $current -PathType Container){Move-Item -LiteralPath $current -Destination $old}
    Move-Item -LiteralPath $incoming -Destination $current
    # Publish the small root metadata only after the new current folder exists.
    # Keep _previous until metadata publication succeeds so a failed rebuild can
    # restore the previous complete reference instead of leaving a half-swap.
    Copy-Item -LiteralPath (Join-Path $current 'state.json') -Destination (Get-PMMGameReferenceStatePath) -Force
    Remove-Item -LiteralPath $old -Recurse -Force -ErrorAction SilentlyContinue
    $Script:PMMGameReferenceFamilyCache=$null;$Script:PMMGameReferenceFamilyCacheStamp=''
    Write-PMMLog ('Game Reference built: '+$indexStats.FamilyCount+' families, '+$indexStats.FileCount+' files, '+$indexStats.Bytes+' bytes.')
    Report-PMMGameReferenceProgress -Current 100 -Total 100 -Message 'Game Reference ready.'
    return Get-PMMGameReferenceState
  }catch{
    $buildError=$_.Exception
    Remove-Item -LiteralPath $incoming -Recurse -Force -ErrorAction SilentlyContinue
    try{
      $current=Get-PMMGameReferenceCurrentRoot;$old=Join-Path (Get-PMMGameReferenceRoot) '_previous'
      if(Test-Path -LiteralPath $old -PathType Container){
        Remove-Item -LiteralPath $current -Recurse -Force -ErrorAction SilentlyContinue
        Move-Item -LiteralPath $old -Destination $current
        if(Test-Path -LiteralPath (Join-Path $current 'state.json') -PathType Leaf){Copy-Item -LiteralPath (Join-Path $current 'state.json') -Destination (Get-PMMGameReferenceStatePath) -Force}
      }elseif(Test-Path -LiteralPath $current -PathType Container){
        # First-build failure after the swap: do not advertise a partial library.
        Remove-Item -LiteralPath $current -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath (Get-PMMGameReferenceStatePath) -Force -ErrorAction SilentlyContinue
      }
    }catch{}
    Write-PMMLog ('Game Reference build failed: '+$buildError.Message)
    Report-PMMGameReferenceProgress -Current 100 -Total 100 -Message ('Game Reference build failed: '+$buildError.Message)
    throw $buildError
  }
}

function Get-PMMGameReferenceFamilies {
  $state=Get-PMMGameReferenceState
  if([string]$state.Status -ne 'Current'){return @()}
  $path=Join-Path (Get-PMMGameReferenceIndexRoot) 'families.jsonl'
  if(-not(Test-Path -LiteralPath $path -PathType Leaf)){return @()}
  $stamp=((Get-Item -LiteralPath $path).LastWriteTimeUtc.ToString('o'))
  if($Script:PMMGameReferenceFamilyCache -and $Script:PMMGameReferenceFamilyCacheStamp -eq $stamp){return @($Script:PMMGameReferenceFamilyCache)}
  $items=[System.Collections.Generic.List[object]]::new()
  foreach($line in @(Get-Content -LiteralPath $path -Encoding UTF8)){
    if([string]::IsNullOrWhiteSpace([string]$line)){continue}
    try{$items.Add(([string]$line|ConvertFrom-Json))}catch{}
  }
  $Script:PMMGameReferenceFamilyCache=$items.ToArray();$Script:PMMGameReferenceFamilyCacheStamp=$stamp
  return @($Script:PMMGameReferenceFamilyCache)
}

function Get-PMMGameReferenceRelationRules {
  $path=Join-Path $Script:Root 'Knowledge\reference-relations.json'
  if(-not(Test-Path -LiteralPath $path -PathType Leaf)){return @()}
  try{return @((Get-Content -LiteralPath $path -Raw|ConvertFrom-Json).rules)}catch{return @()}
}

function Get-PMMGameReferenceProviderSeedInfo([array]$ProviderRecords,[string]$ConflictAsset) {
  $tokens=[System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
  $direct=[System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
  foreach($t in @(Get-PMMReferenceTokens $ConflictAsset)){[void]$tokens.Add([string]$t)}
  foreach($record in @($ProviderRecords)){
    foreach($t in @(Get-PMMReferenceTokens ([string]$record.Mod.Name))){[void]$tokens.Add([string]$t)}
    $pak=[string]$record.Mod.Path
    if(-not$pak -or -not(Test-Path -LiteralPath $pak -PathType Leaf)){continue}
    try{
      $headers=@(Get-PakEntriesCached $pak|Where-Object{[IO.Path]::GetExtension((Normalize-PMMReferenceLogicalPath ([string]$_))) -ieq '.uasset'})
      # Very small focused mods are valuable context. Broader providers can pollute
      # the graph with unrelated entity names, so only their conflict-neighborhood
      # paths seed. The complete source PAK + provider index still remain in handoff.
      $seedHeaders=if($headers.Count -le 8){$headers}else{@($headers|Where-Object{
        $candidate=Normalize-PMMReferenceLogicalPath ([string]$_)
        $candidate.StartsWith('Pal/Content/Pal/DataTable/Character/',[StringComparison]::OrdinalIgnoreCase) -and
        (Normalize-PMMReferenceLogicalPath $ConflictAsset).StartsWith('Pal/Content/Pal/DataTable/Character/',[StringComparison]::OrdinalIgnoreCase)
      }|Select-Object -First 40)}
      foreach($entry in $seedHeaders){
        $logical=Normalize-PMMReferenceLogicalPath ([string]$entry)
        [void]$direct.Add((Get-PakLogicalStem $logical).ToLowerInvariant())
        foreach($t in @(Get-PMMReferenceTokens $logical)){[void]$tokens.Add([string]$t)}
      }
    }catch{Write-PMMLog ('Game Reference provider seed scan skipped for '+[string]$record.Mod.Name+': '+$_.Exception.Message)}
  }
  return [pscustomobject]@{Tokens=@($tokens|Sort-Object);DirectFamilyKeys=@($direct|Sort-Object)}
}

function Add-PMMProviderContextToHandoff([string]$StageRoot,[array]$ProviderRecords,[string]$ConflictAsset) {
  $refRoot=Join-Path $StageRoot 'references'
  $indexRoot=Join-Path $refRoot 'provider-indexes'
  New-Item -ItemType Directory -Force -Path $indexRoot|Out-Null
  $rows=[System.Collections.Generic.List[object]]::new()
  foreach($record in @($ProviderRecords)){
    $pak=[string]$record.Mod.Path
    if(-not$pak -or -not(Test-Path -LiteralPath $pak -PathType Leaf)){continue}
    $providerStem=[IO.Path]::GetFileNameWithoutExtension([string]$record.Mod.Name)
    try{
      $entries=@(Get-PakEntriesCached $pak)
      $safeName=($providerStem -replace '[^A-Za-z0-9_.-]','_')
      @($entries|ForEach-Object{[string]$_})|Set-Content -LiteralPath (Join-Path $indexRoot ($safeName+'.txt')) -Encoding UTF8
      $headers=@($entries|Where-Object{[IO.Path]::GetExtension((Normalize-PMMReferenceLogicalPath ([string]$_))) -ieq '.uasset'})
      $extracted=[System.Collections.Generic.List[object]]::new()
      # For very focused mods, unpack their small non-conflict neighborhood so a
      # fresh AI does not need a PAK tool just to discover related custom assets.
      # Broader providers keep an entry index + original source PAK instead.
      if($headers.Count -le 8){
        $providerRoot=Join-Path $refRoot ('Providers\'+$safeName)
        foreach($entry in @($headers|Select-Object -First 12)){
          $logical=Normalize-PMMReferenceLogicalPath ([string]$entry)
          if($logical -ieq (Normalize-PMMReferenceLogicalPath $ConflictAsset)){continue}
          try{
            $export=Export-PakAssetFamilyExact $pak $logical $providerRoot
            $extracted.Add([pscustomobject]@{Asset=$logical;Files=@($export.Files);Reason='Focused involved source PAK: non-conflict family included so the receiving AI can inspect provider-side context without unpacking the PAK.'})
          }catch{Write-PMMLog ('Provider handoff context extraction skipped '+$logical+': '+$_.Exception.Message)}
        }
      }
      $rows.Add([pscustomobject]@{Provider=[string]$record.Mod.Name;PakSha256=[string]$record.Mod.Hash;PakEntryCount=$entries.Count;UassetFamilyCount=$headers.Count;ExtractedContext=$extracted.ToArray()})
    }catch{Write-PMMLog ('Provider handoff index failed for '+[string]$record.Mod.Name+': '+$_.Exception.Message)}
  }
  [ordered]@{Schema='PMM_HANDOFF_PROVIDER_CONTEXT_V1';ConflictAsset=$ConflictAsset;Providers=$rows.ToArray();Safety='Provider context is explanatory evidence only. Exact case.json inputs remain the manual solution target.'}|ConvertTo-Json -Depth 20|Set-Content -LiteralPath (Join-Path $refRoot 'provider-context.json') -Encoding UTF8
  return $rows.ToArray()
}

function Copy-PMMGameReferenceFamilyToHandoff($Family,[string]$StageRoot) {
  $copied=[System.Collections.Generic.List[object]]::new()
  $cookedRoot=Get-PMMGameReferenceCookedRoot
  foreach($part in @($Family.Parts)){
    $rel=[string]$part.RelativePath
    $src=Join-Path $cookedRoot ($rel.Replace([char]47,[char]92))
    if(-not(Test-Path -LiteralPath $src -PathType Leaf)){throw ('Game Reference family part is missing: '+$rel)}
    if((Get-Sha256 $src) -ne ([string]$part.Sha256).ToLowerInvariant()){throw ('Game Reference family hash changed: '+$rel)}
    $dst=Join-Path $StageRoot ('references\Vanilla\'+$rel.Replace([char]47,[char]92))
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $dst)|Out-Null
    Copy-Item -LiteralPath $src -Destination $dst -Force
    $copied.Add([pscustomobject]@{RelativePath=$rel;Size=[int64]$part.Size;Sha256=[string]$part.Sha256})
  }
  return $copied.ToArray()
}

function Add-PMMGameReferenceToHandoff([string]$StageRoot,$Case,[array]$ProviderRecords,[int]$MaxFamilies=40,[int64]$MaxBytes=26214400) {
  $refDir=Join-Path $StageRoot 'references';New-Item -ItemType Directory -Force -Path $refDir|Out-Null
  # Provider PAK indexes are always useful. Focused/small provider PAKs also
  # contribute a few non-conflict cooked families so the handoff is usable by
  # a fresh AI even when it has no PAK extraction tooling.
  [void](Add-PMMProviderContextToHandoff $StageRoot $ProviderRecords ([string]$Case.Asset))
  $state=Get-PMMGameReferenceState
  if([string]$state.Status -ne 'Current'){
    [ordered]@{Schema='PMM_HANDOFF_REFERENCE_SELECTION_V1';Status=[string]$state.Status;Reason=[string]$state.Reason;IncludedFamilies=0;IncludedBytes=0}|ConvertTo-Json -Depth 12|Set-Content -LiteralPath (Join-Path $refDir 'reference-selection.json') -Encoding UTF8
    return [pscustomobject]@{Status=[string]$state.Status;Count=0;Bytes=0;Reason=[string]$state.Reason}
  }
  $families=@(Get-PMMGameReferenceFamilies)
  if($families.Count -eq 0){return [pscustomobject]@{Status='Error';Count=0;Bytes=0;Reason='Game Reference family index is empty.'}}

  $seed=Get-PMMGameReferenceProviderSeedInfo $ProviderRecords ([string]$Case.Asset)
  $seedTokens=[System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
  foreach($t in @($seed.Tokens)){[void]$seedTokens.Add([string]$t)}
  foreach($t in @(Get-PMMReferenceTokens ([string]$Case.Reason))){[void]$seedTokens.Add([string]$t)}
  # Include semantic evidence / human context terms when available. They remain
  # hints only and merely improve reference selection.
  foreach($evidenceName in @('semantic-evidence.json','CONTEXT_NOTES.md')){
    $p=Join-Path $StageRoot $evidenceName
    if(Test-Path -LiteralPath $p -PathType Leaf){
      try{foreach($t in @(Get-PMMReferenceTokens (Get-Content -LiteralPath $p -Raw))){[void]$seedTokens.Add([string]$t)}}catch{}
    }
  }

  $forced=@{};$forcedReasons=@{}
  foreach($rule in @(Get-PMMGameReferenceRelationRules)){
    $triggered=$false
    foreach($trigger in @($rule.triggerTokens)){if($seedTokens.Contains([string]$trigger)){$triggered=$true;break}}
    if(-not$triggered){continue}
    foreach($asset in @($rule.includeExactAssets)){
      $key=(Get-PakLogicalStem (Normalize-PMMReferenceLogicalPath ([string]$asset))).ToLowerInvariant()
      $forced[$key]=150
      $forcedReasons[$key]=@('Knowledge relation '+[string]$rule.id+': '+[string]$rule.reason)
    }
  }

  $directSet=[System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
  foreach($k in @($seed.DirectFamilyKeys)){[void]$directSet.Add([string]$k)}
  $conflictKey=(Get-PakLogicalStem (Normalize-PMMReferenceLogicalPath ([string]$Case.Asset))).ToLowerInvariant()
  $candidates=[System.Collections.Generic.List[object]]::new()
  foreach($family in $families){
    $key=[string]$family.FamilyKey;if($key -eq $conflictKey){continue}
    $score=0;$reasons=[System.Collections.Generic.List[string]]::new()
    if($directSet.Contains($key)){$score+=120;$reasons.Add('Same Vanilla asset family is also present as a non-conflict asset in an involved source PAK.')}
    if($forced.ContainsKey($key)){$score+=[int]$forced[$key];foreach($r in @($forcedReasons[$key])){$reasons.Add([string]$r)}}
    $matches=[System.Collections.Generic.List[string]]::new()
    foreach($token in @($family.Tokens)){
      if($seedTokens.Contains([string]$token)){$matches.Add([string]$token)}
    }
    $uniqueMatches=@($matches.ToArray()|Sort-Object -Unique)
    if($uniqueMatches.Count -gt 0){
      $tokenScore=[Math]::Min(80,$uniqueMatches.Count*20);$score+=$tokenScore
      $reasons.Add('Exact token relationship: '+((@($uniqueMatches|Select-Object -First 6)) -join ', ')+'.')
    }
    $assetNorm=Normalize-PMMReferenceLogicalPath ([string]$family.Asset)
    $caseNorm=Normalize-PMMReferenceLogicalPath ([string]$Case.Asset)
    $familyParent=[IO.Path]::GetDirectoryName($assetNorm.Replace([char]47,[char]92))
    $caseParent=[IO.Path]::GetDirectoryName($caseNorm.Replace([char]47,[char]92))
    if($familyParent -and $caseParent -and $familyParent -ieq $caseParent){$score+=10;$reasons.Add('Same Vanilla subsystem directory as the conflict asset (weak supporting signal).')}
    if($score -ge 20){$candidates.Add([pscustomobject]@{Family=$family;Score=$score;Reasons=$reasons.ToArray()})}
  }

  $selected=[System.Collections.Generic.List[object]]::new();[int64]$bytes=0
  foreach($candidate in @($candidates.ToArray()|Sort-Object @{Expression='Score';Descending=$true},@{Expression={ [int64]$_.Family.Bytes };Ascending=$true},@{Expression={ [string]$_.Family.Asset };Ascending=$true})){
    if($selected.Count -ge $MaxFamilies){break}
    $familyBytes=[int64]$candidate.Family.Bytes
    if($selected.Count -gt 0 -and ($bytes+$familyBytes) -gt $MaxBytes -and -not$forced.ContainsKey([string]$candidate.Family.FamilyKey)){continue}
    $selected.Add($candidate);$bytes+=$familyBytes
  }

  $indexRows=[System.Collections.Generic.List[object]]::new();$reasonRows=[System.Collections.Generic.List[object]]::new()
  foreach($candidate in $selected){
    $copied=Copy-PMMGameReferenceFamilyToHandoff $candidate.Family $StageRoot
    $indexRows.Add([pscustomobject]@{Asset=[string]$candidate.Family.Asset;FamilyKey=[string]$candidate.Family.FamilyKey;Score=[int]$candidate.Score;Bytes=[int64]$candidate.Family.Bytes;Parts=$copied})
    $reasonRows.Add([pscustomobject]@{Asset=[string]$candidate.Family.Asset;Score=[int]$candidate.Score;Reasons=@($candidate.Reasons)})
  }
  [ordered]@{Schema='PMM_HANDOFF_REFERENCE_INDEX_V1';CaseId=[string]$Case.CaseId;References=$indexRows.ToArray()}|ConvertTo-Json -Depth 30|Set-Content -LiteralPath (Join-Path $refDir 'reference-index.json') -Encoding UTF8
  [ordered]@{Schema='PMM_HANDOFF_REFERENCE_REASONS_V1';CaseId=[string]$Case.CaseId;References=$reasonRows.ToArray()}|ConvertTo-Json -Depth 20|Set-Content -LiteralPath (Join-Path $refDir 'reference-reasons.json') -Encoding UTF8
  [ordered]@{
    Schema='PMM_HANDOFF_GAME_REFERENCE_CONTEXT_V1';CaseId=[string]$Case.CaseId;ReferenceStateSchema='PMM_GAME_REFERENCE_STATE_V1';
    ScopeVersion=[string]$state.State.ScopeVersion;MappingsSha256=[string]$state.State.MappingsSha256;SourcePakSize=[int64]$state.State.SourcePakSize;
    SourcePakLastWriteUtc=[string]$state.State.SourcePakLastWriteUtc;PakIndexSha256=[string]$state.State.PakIndexSha256;
    ReferenceFamilyCount=$selected.Count;ReferenceBytes=$bytes;SelectionDepth=2;SelectionPolicy='deterministic-exact-token-and-knowledge-neighborhood-v1';
    Safety='Supporting Vanilla evidence only. Reference selection never authorizes a merge.'
  }|ConvertTo-Json -Depth 20|Set-Content -LiteralPath (Join-Path $refDir 'game-reference-context.json') -Encoding UTF8
  return [pscustomobject]@{Status='Current';Count=$selected.Count;Bytes=$bytes;Reason='Relevant Vanilla reference families included.'}
}
