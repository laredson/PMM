<#
AIIO Game Reference on-demand hydration
=======================================

CREATE_MOD may discover exact Vanilla assets that are present in Pal-Windows.pak
but were not part of PMM_GAME_REFERENCE_SCOPE_V1. This service searches the
persisted full PAK index without materializing tens of thousands of PowerShell
objects and hydrates only exact requested cooked families.

Performance / safety rules:
  * full-index search is lazy and uses a compact in-process helper;
  * exact families are resolved from the persisted PAK index, never guessed;
  * multiple exact families can be hydrated in one selective repak unpack;
  * missing files after bulk unpack fall back to exact repak get individually;
  * Game Reference mutation is serialized by GameReference.build.lock;
  * every published part is hashed before it enters the family index;
  * current PAK-index + mappings identity remains authoritative;
  * nothing here deploys, enables, builds, publishes, or promotes a mod.
#>

$Script:PMMAIIOPakIndexCatalogCache=$null
$Script:PMMAIIOPakIndexCatalogStamp=''

function Initialize-PMMAIIOFastPakIndexType {
  if('PMMAIIOFastPakIndexCatalog' -as [type]){return}
  Add-Type -Language CSharp -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.IO;

public sealed class PMMAIIOFastPakIndexPart {
    public string RawEntry { get; set; }
    public string Normalized { get; set; }
    public string Extension { get; set; }
}

public sealed class PMMAIIOFastPakIndexHit {
    public string LogicalPath { get; set; }
    public string FamilyKey { get; set; }
    public int Score { get; set; }
    public string Reason { get; set; }
}

public sealed class PMMAIIOFastPakIndexCatalog {
    private readonly Dictionary<string,List<PMMAIIOFastPakIndexPart>> _parts;
    private readonly List<string> _headers;

    public int LineCount { get; private set; }
    public int FamilyCount { get { return _headers.Count; } }

    public PMMAIIOFastPakIndexCatalog(string[] lines) {
        _parts = new Dictionary<string,List<PMMAIIOFastPakIndexPart>>(StringComparer.OrdinalIgnoreCase);
        _headers = new List<string>();
        if (lines == null) lines = new string[0];
        LineCount = lines.Length;
        foreach (string rawValue in lines) {
            if (String.IsNullOrWhiteSpace(rawValue)) continue;
            string normalized = Normalize(rawValue);
            string ext = Path.GetExtension(normalized).ToLowerInvariant();
            if (ext != ".uasset" && ext != ".uexp" && ext != ".ubulk" && ext != ".uptnl") continue;
            string stem = normalized.Substring(0,normalized.Length-ext.Length);
            List<PMMAIIOFastPakIndexPart> list;
            if (!_parts.TryGetValue(stem,out list)) {
                list = new List<PMMAIIOFastPakIndexPart>();
                _parts[stem] = list;
            }
            list.Add(new PMMAIIOFastPakIndexPart { RawEntry=rawValue, Normalized=normalized, Extension=ext });
            if (ext == ".uasset") _headers.Add(normalized);
        }
    }

    private static string Normalize(string value) {
        string n = (value ?? String.Empty).Trim().TrimStart('\uFEFF').Replace('\\','/');
        while (n.StartsWith("/",StringComparison.Ordinal)) n=n.Substring(1);
        while (n.StartsWith("../",StringComparison.Ordinal)) n=n.Substring(3);
        return n;
    }

    public bool ContainsFamily(string stem) {
        return _parts.ContainsKey(Normalize(stem));
    }

    public PMMAIIOFastPakIndexPart[] GetParts(string stem) {
        List<PMMAIIOFastPakIndexPart> list;
        if (!_parts.TryGetValue(Normalize(stem),out list)) return new PMMAIIOFastPakIndexPart[0];
        return list.ToArray();
    }

    public PMMAIIOFastPakIndexHit[] Search(string query, string queryStem, string[] queryTokens, int maximumResults) {
        if (maximumResults < 1) maximumResults=1;
        if (maximumResults > 2000) maximumResults=2000;
        string q=Normalize(query).ToLowerInvariant();
        string qStem=Normalize(queryStem).ToLowerInvariant();
        queryTokens=queryTokens ?? new string[0];
        var hits=new List<PMMAIIOFastPakIndexHit>();
        foreach(string asset in _headers) {
            string lower=asset.ToLowerInvariant();
            string stem=lower.Substring(0,lower.Length-7);
            string leaf=Path.GetFileNameWithoutExtension(lower);
            int score=0;
            var reasons=new List<string>();
            if(lower==q || stem==qStem){score+=1000;reasons.Add("exact logical family");}
            else if(lower.StartsWith(q,StringComparison.OrdinalIgnoreCase)){score+=520;reasons.Add("logical path prefix");}
            else if(lower.Contains(q)){score+=360;reasons.Add("logical path contains query");}
            else if(leaf.Contains(q)){score+=320;reasons.Add("asset name contains query");}

            int tokenScore=0;
            var matched=new List<string>();
            foreach(string rawToken in queryTokens) {
                string token=(rawToken ?? String.Empty).ToLowerInvariant();
                if(token.Length < 3 || !lower.Contains(token)) continue;
                tokenScore+=80;matched.Add(token);
            }
            if(tokenScore>0){score+=Math.Min(300,tokenScore);reasons.Add("token text match: "+String.Join(", ",matched.ToArray()));}
            if(score<=0) continue;
            hits.Add(new PMMAIIOFastPakIndexHit{LogicalPath=asset,FamilyKey=stem,Score=score,Reason=String.Join("; ",reasons.ToArray())});
        }
        hits.Sort(delegate(PMMAIIOFastPakIndexHit a,PMMAIIOFastPakIndexHit b){
            int byScore=b.Score.CompareTo(a.Score);
            return byScore!=0 ? byScore : StringComparer.OrdinalIgnoreCase.Compare(a.LogicalPath,b.LogicalPath);
        });
        if(hits.Count>maximumResults) hits.RemoveRange(maximumResults,hits.Count-maximumResults);
        return hits.ToArray();
    }
}
'@
}

function Get-PMMAIIOPakIndexCatalog {
  [CmdletBinding()]
  param()
  [void](Get-PMMAIIOGameReferenceProof -RequireCurrent)
  $indexPath=Join-Path (Get-PMMGameReferenceIndexRoot) 'pak-index.txt'
  if(-not(Test-Path -LiteralPath $indexPath -PathType Leaf)){throw 'Current Game Reference has no persisted Pal-Windows.pak index.'}
  $item=Get-Item -LiteralPath $indexPath
  $stamp=([IO.Path]::GetFullPath($item.FullName).ToLowerInvariant()+'|'+[string]$item.Length+'|'+$item.LastWriteTimeUtc.Ticks)
  if($null -ne $Script:PMMAIIOPakIndexCatalogCache -and $Script:PMMAIIOPakIndexCatalogStamp -eq $stamp){return $Script:PMMAIIOPakIndexCatalogCache}

  Initialize-PMMAIIOFastPakIndexType
  $watch=[Diagnostics.Stopwatch]::StartNew()
  $lines=[IO.File]::ReadAllLines($indexPath,[Text.Encoding]::UTF8)
  $fast=[PMMAIIOFastPakIndexCatalog]::new([string[]]$lines)
  $catalog=[pscustomobject]@{Schema='PMM_AIIO_PAK_INDEX_CATALOG_V2';IndexPath=$indexPath;Fast=$fast}
  $Script:PMMAIIOPakIndexCatalogCache=$catalog
  $Script:PMMAIIOPakIndexCatalogStamp=$stamp
  $watch.Stop()
  Write-PMMLog ('AIIO PAK index catalog ready: '+$fast.LineCount+' lines / '+$fast.FamilyCount+' .uasset headers in '+$watch.Elapsed.ToString())
  return $catalog
}

function Get-PMMAIIOGameReferenceSearchMatch {
  param([string]$Asset,[string]$FamilyKey,[array]$Tokens=@(),[string]$NormalizedQuery,[array]$QueryTokens=@())
  $assetLower=$Asset.ToLowerInvariant();$familyLower=$FamilyKey.ToLowerInvariant();$leaf=([IO.Path]::GetFileNameWithoutExtension($Asset)).ToLowerInvariant()
  $score=0;$reasons=[Collections.Generic.List[string]]::new()
  if($assetLower -eq $NormalizedQuery -or $familyLower -eq (Get-PakLogicalStem $NormalizedQuery)){$score+=1000;$reasons.Add('exact logical family')}
  elseif($assetLower.StartsWith($NormalizedQuery,[StringComparison]::OrdinalIgnoreCase)){$score+=520;$reasons.Add('logical path prefix')}
  elseif($assetLower.Contains($NormalizedQuery)){$score+=360;$reasons.Add('logical path contains query')}
  elseif($leaf.Contains($NormalizedQuery)){$score+=320;$reasons.Add('asset name contains query')}
  $familyTokens=@($Tokens|ForEach-Object{([string]$_).ToLowerInvariant()});$matched=[Collections.Generic.List[string]]::new()
  foreach($token in @($QueryTokens)){if($familyTokens -contains ([string]$token).ToLowerInvariant()){$matched.Add([string]$token)}}
  if($matched.Count -gt 0){$score+=[Math]::Min(300,80*$matched.Count);$reasons.Add('token match: '+(@($matched.ToArray()) -join ', '))}
  return [pscustomobject]@{Score=$score;Reason=(@($reasons.ToArray()) -join '; ')}
}

function Find-PMMAIIOHydratedGameReferenceFamily {
  param([Parameter(Mandatory=$true)][string]$LogicalPath)
  $asset=Normalize-PMMReferenceLogicalPath $LogicalPath;$stem=(Get-PakLogicalStem $asset).ToLowerInvariant()
  $matches=@(Get-PMMGameReferenceFamilies|Where-Object{(Normalize-PMMReferenceLogicalPath ([string]$_.Asset)) -ieq $asset -or [string]$_.FamilyKey -ieq $stem}|Select-Object -First 2)
  if($matches.Count -eq 1){return $matches[0]}
  if($matches.Count -gt 1){throw ('Current Game Reference contains duplicate family identity for: '+$asset)}
  return $null
}

function Get-PMMAIIOIndexedFamilyParts([string]$LogicalPath) {
  $asset=Normalize-PMMReferenceLogicalPath $LogicalPath
  if([string]::IsNullOrWhiteSpace($asset) -or [IO.Path]::GetExtension($asset) -ine '.uasset'){throw ('An exact Game Reference .uasset logical path is required: '+$LogicalPath)}
  $stem=(Get-PakLogicalStem $asset).ToLowerInvariant();$catalog=Get-PMMAIIOPakIndexCatalog
  $parts=@($catalog.Fast.GetParts($stem))
  if($parts.Count -eq 0){throw ('The exact family does not exist in the current Pal-Windows.pak index: '+$asset)}
  $headers=@($parts|Where-Object{[string]$_.Extension -eq '.uasset' -and (Normalize-PMMReferenceLogicalPath ([string]$_.Normalized)) -ieq $asset})
  if($headers.Count -ne 1){throw ('The current Pal-Windows.pak index does not resolve one exact .uasset header for: '+$asset)}
  return [pscustomobject]@{Asset=$asset;Stem=$stem;Parts=@($parts|Sort-Object Extension)}
}

function Ensure-PMMAIIOGameReferenceFamiliesExact {
  [CmdletBinding()]
  param([Parameter(Mandatory=$true)][string[]]$LogicalPaths)

  [void](Get-PMMAIIOGameReferenceProof -RequireCurrent)
  $requested=[Collections.Generic.List[string]]::new();$seen=[Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
  foreach($rawPath in @($LogicalPaths)){
    $asset=Normalize-PMMReferenceLogicalPath ([string]$rawPath)
    if([string]::IsNullOrWhiteSpace($asset) -or [IO.Path]::GetExtension($asset) -ine '.uasset'){throw ('An exact Game Reference .uasset logical path is required: '+[string]$rawPath)}
    if($seen.Add($asset)){$requested.Add($asset)}
  }
  if($requested.Count -eq 0){return @()}

  $missing=[Collections.Generic.List[object]]::new()
  foreach($asset in @($requested.ToArray())){if(-not(Find-PMMAIIOHydratedGameReferenceFamily $asset)){$missing.Add((Get-PMMAIIOIndexedFamilyParts $asset))}}
  if($missing.Count -eq 0){return @($requested.ToArray()|ForEach-Object{Find-PMMAIIOHydratedGameReferenceFamily $_})}

  $root=Get-PMMGameReferenceRoot;$lockPath=Join-Path $root 'GameReference.build.lock';$referenceLock=$null
  $stage=Join-Path (Join-PMMPath 'Temp' 'AIIO') ('GameReferenceHydrate_'+[guid]::NewGuid().ToString('N'))
  $extractRoot=Join-Path $stage 'unpack';$created=[Collections.Generic.List[string]]::new();$indexCommitted=$false
  $familiesPath=Join-Path (Get-PMMGameReferenceIndexRoot) 'families.jsonl';$selectedPath=Join-Path (Get-PMMGameReferenceIndexRoot) 'selected-entries.txt'
  $currentStatePath=Join-Path (Get-PMMGameReferenceCurrentRoot) 'state.json';$rootStatePath=Get-PMMGameReferenceStatePath
  $indexBackup=Join-Path $stage 'families.jsonl.before';$selectedBackup=Join-Path $stage 'selected-entries.txt.before';$currentStateBackup=Join-Path $stage 'state.json.before';$rootStateBackup=Join-Path $stage 'current.json.before'
  try{
    try{$referenceLock=[IO.File]::Open($lockPath,[IO.FileMode]::OpenOrCreate,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)}catch{throw 'Game Reference is currently busy. Finish the active Game Reference operation and retry the AIIO data request.'}
    $Script:PMMGameReferenceFamilyCache=$null;$Script:PMMGameReferenceFamilyCacheStamp=''

    # Re-resolve after the lock in case another process hydrated some families.
    $missing.Clear()
    foreach($asset in @($requested.ToArray())){if(-not(Find-PMMAIIOHydratedGameReferenceFamily $asset)){$missing.Add((Get-PMMAIIOIndexedFamilyParts $asset))}}
    if($missing.Count -eq 0){return @($requested.ToArray()|ForEach-Object{Find-PMMAIIOHydratedGameReferenceFamily $_})}

    $reference=Get-PMMGameReferenceState
    if([string]$reference.Status -ne 'Current'){throw ('Game Reference became unavailable before hydration: '+[string]$reference.Reason)}
    $state=$reference.State;$pak=Get-PMMGameReferencePak
    if([string]::IsNullOrWhiteSpace($pak)){throw 'Configured Palworld installation has no Pal-Windows.pak for on-demand hydration.'}
    $pakIndexPath=Join-Path (Get-PMMGameReferenceIndexRoot) 'pak-index.txt'
    if(-not(Test-Path -LiteralPath $pakIndexPath -PathType Leaf)){throw 'Current Game Reference PAK index disappeared before hydration.'}
    $actualIndexHash=Get-Sha256 $pakIndexPath
    if(([string]$state.PakIndexSha256).ToLowerInvariant() -ne $actualIndexHash.ToLowerInvariant()){throw 'Current Game Reference PAK index hash changed; rebuild Game Reference before on-demand extraction.'}

    New-Item -ItemType Directory -Force -Path $stage,$extractRoot|Out-Null;Set-PMMTransientStageOwner $stage 'AIIOGameReferenceHydration'
    $rawEntries=[Collections.Generic.List[string]]::new();$rawSeen=[Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach($family in @($missing.ToArray())){foreach($part in @($family.Parts)){if($rawSeen.Add([string]$part.RawEntry)){$rawEntries.Add([string]$part.RawEntry)}}}
    if($rawEntries.Count -eq 0){throw 'On-demand Game Reference hydration resolved no PAK entries.'}

    if(Get-Command Write-PMMOperationProgress -ErrorAction SilentlyContinue){Write-PMMOperationProgress 0 0 ('Hydrating '+$missing.Count+' Vanilla Game Reference families in one PAK pass...') $true}
    $args=@('unpack',$pak,'--output',$extractRoot,'--force','--quiet')
    foreach($entry in @($rawEntries.ToArray())){$args+=@('--include',[string]$entry)}
    Write-PMMLog ('AIIO Game Reference batch hydration: '+$missing.Count+' families / '+$rawEntries.Count+' entries in one repak unpack.')
    Invoke-RepakText -Arguments $args -Context 'AIIO Game Reference batch hydration'|Out-Null

    $familyRecords=[Collections.Generic.List[object]]::new();[int64]$addedBytes=0;$addedFiles=0
    foreach($familyInfo in @($missing.ToArray())){
      $parts=[Collections.Generic.List[object]]::new();[int64]$familyBytes=0
      foreach($row in @($familyInfo.Parts)){
        $rel=Normalize-PMMReferenceLogicalPath ([string]$row.Normalized);$stageFile=Join-Path $extractRoot ($rel.Replace([char]47,[char]92))
        if(-not(Test-Path -LiteralPath $stageFile -PathType Leaf)){
          New-Item -ItemType Directory -Force -Path (Split-Path -Parent $stageFile)|Out-Null
          Write-PMMLog ('AIIO batch unpack missed exact entry; using repak get fallback: '+$rel)
          Get-PakEntry $pak ([string]$row.RawEntry) $stageFile
        }
        if(-not(Test-Path -LiteralPath $stageFile -PathType Leaf)){throw ('On-demand extraction did not produce: '+$rel)}
        $size=[int64](Get-Item -LiteralPath $stageFile).Length;$hash=Get-Sha256 $stageFile;$familyBytes+=$size
        if($familyBytes -gt 536870912){throw ('On-demand Game Reference family exceeds the 512 MiB safety ceiling: '+[string]$familyInfo.Asset)}
        $parts.Add([pscustomobject]@{Extension=[string]$row.Extension;RelativePath=$rel;Size=$size;Sha256=$hash;StagePath=$stageFile;RawEntry=[string]$row.RawEntry})
      }
      if(@($parts.ToArray()|Where-Object{[string]$_.Extension -eq '.uasset'}).Count -ne 1){throw ('On-demand extraction produced an invalid cooked family topology for: '+[string]$familyInfo.Asset)}
      $record=[ordered]@{Schema='PMM_GAME_REFERENCE_FAMILY_V1';FamilyKey=[string]$familyInfo.Stem;Asset=[string]$familyInfo.Asset;Bytes=$familyBytes;Parts=@($parts.ToArray()|ForEach-Object{[pscustomobject]@{Extension=[string]$_.Extension;RelativePath=[string]$_.RelativePath;Size=[int64]$_.Size;Sha256=[string]$_.Sha256}});Tokens=@(Get-PMMReferenceTokens ([string]$familyInfo.Stem))}
      $familyRecords.Add([pscustomobject]@{Family=[pscustomobject]$record;Parts=@($parts.ToArray())});$addedBytes+=$familyBytes;$addedFiles+=$parts.Count
    }

    Copy-Item -LiteralPath $familiesPath -Destination $indexBackup -Force
    if(Test-Path -LiteralPath $selectedPath -PathType Leaf){Copy-Item -LiteralPath $selectedPath -Destination $selectedBackup -Force}
    Copy-Item -LiteralPath $currentStatePath -Destination $currentStateBackup -Force;Copy-Item -LiteralPath $rootStatePath -Destination $rootStateBackup -Force

    $cookedRoot=Get-PMMGameReferenceCookedRoot
    foreach($row in @($familyRecords.ToArray())){foreach($part in @($row.Parts)){
      $dest=Join-Path $cookedRoot (([string]$part.RelativePath).Replace([char]47,[char]92));New-Item -ItemType Directory -Force -Path (Split-Path -Parent $dest)|Out-Null
      if(Test-Path -LiteralPath $dest -PathType Leaf){if((Get-Sha256 $dest) -ne ([string]$part.Sha256).ToLowerInvariant()){throw ('Refused to overwrite unexpected existing Game Reference bytes during hydration: '+[string]$part.RelativePath)}}
      else{$partial=$dest+'.hydrate.'+[guid]::NewGuid().ToString('N')+'.partial';Copy-Item -LiteralPath ([string]$part.StagePath) -Destination $partial -Force;Move-Item -LiteralPath $partial -Destination $dest -Force;$created.Add($dest)}
    }}

    $existingLines=@(Get-Content -LiteralPath $familiesPath -Encoding UTF8);$newLines=@($familyRecords.ToArray()|ForEach-Object{$_.Family|ConvertTo-Json -Depth 15 -Compress})
    $newIndex=Join-Path (Get-PMMGameReferenceIndexRoot) ('families.'+[guid]::NewGuid().ToString('N')+'.tmp');@($existingLines+$newLines)|Set-Content -LiteralPath $newIndex -Encoding UTF8;Move-Item -LiteralPath $newIndex -Destination $familiesPath -Force
    $indexCommitted=$true
    if(Test-Path -LiteralPath $selectedPath -PathType Leaf){$selected=@(Get-Content -LiteralPath $selectedPath -Encoding UTF8);$mergedSelected=@($selected+@($rawEntries.ToArray())|Sort-Object -Unique);$mergedSelected|Set-Content -LiteralPath $selectedPath -Encoding UTF8}

    $state.ExtractedFamilyCount=[int]$state.ExtractedFamilyCount+$familyRecords.Count;$state.ExtractedFileCount=[int]$state.ExtractedFileCount+$addedFiles;$state.ExtractedBytes=[int64]$state.ExtractedBytes+$addedBytes
    if($state.PSObject.Properties.Name -contains 'SelectedEntryCount'){$state.SelectedEntryCount=[int]$state.SelectedEntryCount+$addedFiles}
    if(-not($state.PSObject.Properties.Name -contains 'OnDemandFamilyCount')){$state|Add-Member -NotePropertyName OnDemandFamilyCount -NotePropertyValue 0}
    if(-not($state.PSObject.Properties.Name -contains 'OnDemandFileCount')){$state|Add-Member -NotePropertyName OnDemandFileCount -NotePropertyValue 0}
    if(-not($state.PSObject.Properties.Name -contains 'OnDemandBytes')){$state|Add-Member -NotePropertyName OnDemandBytes -NotePropertyValue ([int64]0)}
    if(-not($state.PSObject.Properties.Name -contains 'HydrationPolicy')){$state|Add-Member -NotePropertyName HydrationPolicy -NotePropertyValue 'AIIO_ON_DEMAND_BATCH_V2'}
    if(-not($state.PSObject.Properties.Name -contains 'LastHydratedUtc')){$state|Add-Member -NotePropertyName LastHydratedUtc -NotePropertyValue ''}
    $state.OnDemandFamilyCount=[int]$state.OnDemandFamilyCount+$familyRecords.Count;$state.OnDemandFileCount=[int]$state.OnDemandFileCount+$addedFiles;$state.OnDemandBytes=[int64]$state.OnDemandBytes+$addedBytes;$state.HydrationPolicy='AIIO_ON_DEMAND_BATCH_V2';$state.LastHydratedUtc=[DateTime]::UtcNow.ToString('o')
    Write-PMMAIIOJsonAtomic $currentStatePath $state 30;Write-PMMAIIOJsonAtomic $rootStatePath $state 30
    $Script:PMMGameReferenceFamilyCache=$null;$Script:PMMGameReferenceFamilyCacheStamp=''
    Write-PMMLog ('Game Reference batch hydration published: '+$familyRecords.Count+' families / '+$addedFiles+' files / '+$addedBytes+' bytes.')
    $resolved=[Collections.Generic.List[object]]::new();foreach($asset in @($requested.ToArray())){$family=Find-PMMAIIOHydratedGameReferenceFamily $asset;if(-not$family){throw ('Hydrated Game Reference family was not visible after publication: '+$asset)};$resolved.Add($family)};return @($resolved.ToArray())
  }catch{
    $failure=$_.Exception
    if($indexCommitted -and (Test-Path -LiteralPath $indexBackup -PathType Leaf)){
      try{Copy-Item -LiteralPath $indexBackup -Destination $familiesPath -Force}catch{};try{if(Test-Path -LiteralPath $selectedBackup -PathType Leaf){Copy-Item -LiteralPath $selectedBackup -Destination $selectedPath -Force}}catch{}
      try{Copy-Item -LiteralPath $currentStateBackup -Destination $currentStatePath -Force}catch{};try{Copy-Item -LiteralPath $rootStateBackup -Destination $rootStatePath -Force}catch{}
    }
    foreach($path in @($created.ToArray())){Remove-Item -LiteralPath $path -Force -ErrorAction SilentlyContinue}
    $Script:PMMGameReferenceFamilyCache=$null;$Script:PMMGameReferenceFamilyCacheStamp='';throw $failure
  }finally{
    try{if($referenceLock){$referenceLock.Dispose()}}catch{};Remove-Item -LiteralPath $stage -Recurse -Force -ErrorAction SilentlyContinue;try{Remove-PMMTransientStageOwner $stage}catch{}
  }
}

function Ensure-PMMAIIOGameReferenceFamilyExact {
  [CmdletBinding()]
  param([Parameter(Mandatory=$true)][string]$LogicalPath)
  $rows=@(Ensure-PMMAIIOGameReferenceFamiliesExact -LogicalPaths @($LogicalPath));if($rows.Count -ne 1){throw ('Could not hydrate one exact Game Reference family: '+$LogicalPath)};return $rows[0]
}

# Override the narrow resolver loaded by AIIO.ModCreationService.
function Get-PMMAIIOGameReferenceFamilyExact([string]$LogicalPath) { return (Ensure-PMMAIIOGameReferenceFamilyExact -LogicalPath $LogicalPath) }

# Search both already-hydrated Game Reference families and every .uasset header
# in the persisted full Pal-Windows.pak index. Index-only hits intentionally have
# no fake bytes/hashes; exact extraction must hydrate them before source use.
function Search-PMMAIIOGameReferenceFamilies {
  [CmdletBinding()]
  param([Parameter(Mandatory=$true)][string]$Query,[ValidateRange(1,200)][int]$MaximumResults=100)
  [void](Get-PMMAIIOGameReferenceProof -RequireCurrent)
  $queryText=$Query.Trim();if([string]::IsNullOrWhiteSpace($queryText)){throw 'Game Reference query cannot be empty.'}
  if($queryText.Length -gt 256 -or $queryText.IndexOf([char]0) -ge 0 -or $queryText.Contains([char]10) -or $queryText.Contains([char]13)){throw 'Game Reference query is invalid or exceeds 256 characters.'}
  $watch=[Diagnostics.Stopwatch]::StartNew();$normalizedQuery=(Normalize-PMMReferenceLogicalPath $queryText).ToLowerInvariant();$queryStem=(Get-PakLogicalStem $normalizedQuery).ToLowerInvariant();[string[]]$queryTokens=@(Get-PMMReferenceTokens $queryText|ForEach-Object{([string]$_).ToLowerInvariant()}|Sort-Object -Unique)
  $rows=[Collections.Generic.List[object]]::new();$seen=[Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
  foreach($family in @(Get-PMMGameReferenceFamilies)){
    $asset=Normalize-PMMReferenceLogicalPath ([string]$family.Asset);$familyKey=([string]$family.FamilyKey).ToLowerInvariant();$match=Get-PMMAIIOGameReferenceSearchMatch -Asset $asset -FamilyKey $familyKey -Tokens @($family.Tokens) -NormalizedQuery $normalizedQuery -QueryTokens $queryTokens
    if([int]$match.Score -le 0){continue};[void]$seen.Add($familyKey);$parts=@($family.Parts|ForEach-Object{[pscustomobject]@{Extension=[string]$_.Extension;RelativePath=[string]$_.RelativePath;Size=[int64]$_.Size;Sha256=[string]$_.Sha256}})
    $rows.Add([pscustomobject]@{LogicalPath=$asset;FamilyKey=$familyKey;Bytes=[int64]$family.Bytes;Parts=$parts;Tokens=@($family.Tokens);MatchScore=[int]$match.Score;MatchReason=[string]$match.Reason;Availability='GameReference';Hydrated=$true})
  }
  $catalog=Get-PMMAIIOPakIndexCatalog;$candidateLimit=[Math]::Min(2000,$MaximumResults+512);$hits=@($catalog.Fast.Search($normalizedQuery,$queryStem,$queryTokens,$candidateLimit))
  foreach($hit in $hits){$familyKey=([string]$hit.FamilyKey).ToLowerInvariant();if($seen.Contains($familyKey)){continue};[void]$seen.Add($familyKey);$asset=[string]$hit.LogicalPath;$rows.Add([pscustomobject]@{LogicalPath=$asset;FamilyKey=$familyKey;Bytes=[int64]0;Parts=@();Tokens=@(Get-PMMReferenceTokens $asset);MatchScore=[int]$hit.Score;MatchReason=([string]$hit.Reason+'; PAK index only - request exact extraction to hydrate');Availability='PakIndexOnly';Hydrated=$false})}
  $result=@($rows.ToArray()|Sort-Object @{Expression='MatchScore';Descending=$true},@{Expression='LogicalPath';Ascending=$true}|Select-Object -First $MaximumResults);$watch.Stop();Write-PMMLog ('AIIO full-index Game Reference query: '+$watch.Elapsed.ToString()+' | '+$queryText+' | returned='+$result.Count);return $result
}
