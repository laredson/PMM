<#
AIIO fast full-PAK Game Reference index
=======================================

The on-demand hydration layer originally materialized every Pal-Windows.pak
family as PSCustomObject + token arrays before answering one query. On current
Palworld data that means roughly 185k index lines and can take minutes in
Windows PowerShell 5.1.

This additive override keeps the persisted PAK index as strings and performs
full-index matching + exact-family lookup in a tiny in-process C# helper. Only
actual query hits become PowerShell objects. Existing hash/provenance checks and
the exact hydration/publish path remain unchanged.
#>

if(-not('PMMAIIOFastPakIndex' -as [type])){
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

public sealed class PMMAIIOFastPakIndexParts {
    private readonly string[] _lines;
    private readonly Dictionary<string,List<PMMAIIOFastPakIndexPart>> _cache =
        new Dictionary<string,List<PMMAIIOFastPakIndexPart>>(StringComparer.OrdinalIgnoreCase);

    public PMMAIIOFastPakIndexParts(string[] lines) { _lines = lines ?? new string[0]; }

    private static string Normalize(string value) {
        if (String.IsNullOrEmpty(value)) return String.Empty;
        return value.Replace('\\','/').TrimStart('/');
    }

    private List<PMMAIIOFastPakIndexPart> Resolve(string key) {
        key = (key ?? String.Empty).Replace('\\','/').TrimStart('/');
        List<PMMAIIOFastPakIndexPart> found;
        if (_cache.TryGetValue(key, out found)) return found;
        found = new List<PMMAIIOFastPakIndexPart>();
        foreach (string raw in _lines) {
            if (String.IsNullOrWhiteSpace(raw)) continue;
            string normalized = Normalize(raw);
            string ext = Path.GetExtension(normalized).ToLowerInvariant();
            if (ext != ".uasset" && ext != ".uexp" && ext != ".ubulk" && ext != ".uptnl") continue;
            string stem = normalized.Substring(0, normalized.Length - ext.Length);
            if (!String.Equals(stem,key,StringComparison.OrdinalIgnoreCase)) continue;
            found.Add(new PMMAIIOFastPakIndexPart { RawEntry=raw, Normalized=normalized, Extension=ext });
        }
        _cache[key] = found;
        return found;
    }

    public bool ContainsKey(string key) { return Resolve(key).Count > 0; }
    public List<PMMAIIOFastPakIndexPart> this[string key] { get { return Resolve(key); } }
}

public static class PMMAIIOFastPakIndex {
    private static string Normalize(string value) {
        if (String.IsNullOrEmpty(value)) return String.Empty;
        return value.Replace('\\','/').TrimStart('/');
    }

    public static PMMAIIOFastPakIndexHit[] Search(
        string[] lines, string normalizedQuery, string queryStem, string[] queryTokens, int maximumResults) {
        if (maximumResults < 1) maximumResults = 1;
        normalizedQuery = (normalizedQuery ?? String.Empty).ToLowerInvariant();
        queryStem = (queryStem ?? normalizedQuery).ToLowerInvariant();
        queryTokens = queryTokens ?? new string[0];
        var hits = new List<PMMAIIOFastPakIndexHit>();
        foreach (string raw in lines ?? new string[0]) {
            if (String.IsNullOrWhiteSpace(raw) || !raw.EndsWith(".uasset",StringComparison.OrdinalIgnoreCase)) continue;
            string asset = Normalize(raw);
            string lower = asset.ToLowerInvariant();
            string stem = lower.Substring(0,lower.Length-7);
            int score = 0;
            var reasons = new List<string>();
            if (lower == normalizedQuery || stem == queryStem) { score += 1000; reasons.Add("exact logical family"); }
            else if (lower.StartsWith(normalizedQuery,StringComparison.OrdinalIgnoreCase)) { score += 520; reasons.Add("logical path prefix"); }
            else if (lower.Contains(normalizedQuery)) { score += 360; reasons.Add("logical path contains query"); }
            else {
                string leaf = Path.GetFileNameWithoutExtension(lower);
                if (leaf.Contains(normalizedQuery)) { score += 320; reasons.Add("asset name contains query"); }
            }
            int tokenScore = 0;
            var matched = new List<string>();
            foreach (string rawToken in queryTokens) {
                string token = (rawToken ?? String.Empty).ToLowerInvariant();
                if (token.Length == 0 || !lower.Contains(token)) continue;
                tokenScore += 80;
                matched.Add(token);
            }
            if (tokenScore > 0) {
                score += Math.Min(300,tokenScore);
                reasons.Add("token text match: "+String.Join(", ",matched.ToArray()));
            }
            if (score <= 0) continue;
            hits.Add(new PMMAIIOFastPakIndexHit {
                LogicalPath=asset, FamilyKey=stem, Score=score,
                Reason=String.Join("; ",reasons.ToArray())
            });
        }
        hits.Sort(delegate(PMMAIIOFastPakIndexHit a, PMMAIIOFastPakIndexHit b) {
            int score = b.Score.CompareTo(a.Score);
            return score != 0 ? score : StringComparer.OrdinalIgnoreCase.Compare(a.LogicalPath,b.LogicalPath);
        });
        if (hits.Count > maximumResults) hits.RemoveRange(maximumResults,hits.Count-maximumResults);
        return hits.ToArray();
    }
}
'@
}

$Script:PMMAIIOFastPakIndexCatalogCache=$null
$Script:PMMAIIOFastPakIndexCatalogStamp=''

function Get-PMMAIIOPakIndexCatalog {
  [CmdletBinding()]
  param()
  [void](Get-PMMAIIOGameReferenceProof -RequireCurrent)
  $indexPath=Join-Path (Get-PMMGameReferenceIndexRoot) 'pak-index.txt'
  if(-not(Test-Path -LiteralPath $indexPath -PathType Leaf)){throw 'Current Game Reference has no persisted Pal-Windows.pak index.'}
  $item=Get-Item -LiteralPath $indexPath
  $stamp=([IO.Path]::GetFullPath($item.FullName).ToLowerInvariant()+'|'+[string]$item.Length+'|'+$item.LastWriteTimeUtc.Ticks)
  if($Script:PMMAIIOFastPakIndexCatalogCache -and $Script:PMMAIIOFastPakIndexCatalogStamp -eq $stamp){return $Script:PMMAIIOFastPakIndexCatalogCache}
  $watch=[Diagnostics.Stopwatch]::StartNew()
  $lines=[IO.File]::ReadAllLines($indexPath,[Text.Encoding]::UTF8)
  $catalog=[pscustomobject]@{
    Schema='PMM_AIIO_PAK_INDEX_CATALOG_FAST_V2'
    IndexPath=$indexPath
    Lines=$lines
    Families=@()
    PartsByStem=[PMMAIIOFastPakIndexParts]::new($lines)
  }
  $Script:PMMAIIOFastPakIndexCatalogCache=$catalog
  $Script:PMMAIIOFastPakIndexCatalogStamp=$stamp
  $watch.Stop()
  Write-PMMLog ('AIIO fast PAK index loaded: '+$lines.Length+' lines in '+$watch.Elapsed.ToString())
  return $catalog
}

function Get-PMMAIIOGameReferenceFamilyExact([string]$LogicalPath) {
  if(Get-Command Write-PMMOperationProgress -ErrorAction SilentlyContinue){
    Write-PMMOperationProgress 0 0 ('Hydrating Vanilla asset: '+[IO.Path]::GetFileName([string]$LogicalPath)) $true
  }
  return (Ensure-PMMAIIOGameReferenceFamilyExact -LogicalPath $LogicalPath)
}

function Search-PMMAIIOGameReferenceFamilies {
  [CmdletBinding()]
  param([Parameter(Mandatory=$true)][string]$Query,[ValidateRange(1,200)][int]$MaximumResults=100)

  [void](Get-PMMAIIOGameReferenceProof -RequireCurrent)
  $queryText=$Query.Trim()
  if([string]::IsNullOrWhiteSpace($queryText)){throw 'Game Reference query cannot be empty.'}
  if($queryText.Length -gt 256 -or $queryText.IndexOf([char]0) -ge 0 -or $queryText.Contains([char]10) -or $queryText.Contains([char]13)){throw 'Game Reference query is invalid or exceeds 256 characters.'}
  if(Get-Command Write-PMMOperationProgress -ErrorAction SilentlyContinue){Write-PMMOperationProgress 0 0 ('Searching full Pal-Windows.pak index: '+$queryText) $true}

  $watch=[Diagnostics.Stopwatch]::StartNew()
  $normalizedQuery=(Normalize-PMMReferenceLogicalPath $queryText).ToLowerInvariant()
  $queryStem=(Get-PakLogicalStem $normalizedQuery).ToLowerInvariant()
  [string[]]$queryTokens=@(Get-PMMReferenceTokens $queryText|ForEach-Object{([string]$_).ToLowerInvariant()}|Sort-Object -Unique)
  $rows=[Collections.Generic.List[object]]::new()
  $seen=[Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)

  foreach($family in @(Get-PMMGameReferenceFamilies)){
    $asset=Normalize-PMMReferenceLogicalPath ([string]$family.Asset)
    $familyKey=([string]$family.FamilyKey).ToLowerInvariant()
    $match=Get-PMMAIIOGameReferenceSearchMatch -Asset $asset -FamilyKey $familyKey -Tokens @($family.Tokens) -NormalizedQuery $normalizedQuery -QueryTokens $queryTokens
    if([int]$match.Score -le 0){continue}
    [void]$seen.Add($familyKey)
    $parts=@($family.Parts|ForEach-Object{[pscustomobject]@{Extension=[string]$_.Extension;RelativePath=[string]$_.RelativePath;Size=[int64]$_.Size;Sha256=[string]$_.Sha256}})
    $rows.Add([pscustomobject]@{LogicalPath=$asset;FamilyKey=$familyKey;Bytes=[int64]$family.Bytes;Parts=$parts;Tokens=@($family.Tokens);MatchScore=[int]$match.Score;MatchReason=[string]$match.Reason;Availability='GameReference';Hydrated=$true})
  }

  $catalog=Get-PMMAIIOPakIndexCatalog
  $candidateLimit=[Math]::Min(2000,$MaximumResults+512)
  $hits=[PMMAIIOFastPakIndex]::Search([string[]]$catalog.Lines,$normalizedQuery,$queryStem,$queryTokens,$candidateLimit)
  foreach($hit in @($hits)){
    $familyKey=([string]$hit.FamilyKey).ToLowerInvariant()
    if($seen.Contains($familyKey)){continue}
    [void]$seen.Add($familyKey)
    $asset=[string]$hit.LogicalPath
    $rows.Add([pscustomobject]@{
      LogicalPath=$asset;FamilyKey=$familyKey;Bytes=[int64]0;Parts=@();Tokens=@(Get-PMMReferenceTokens $asset)
      MatchScore=[int]$hit.Score;MatchReason=([string]$hit.Reason+'; PAK index only - request exact extraction to hydrate')
      Availability='PakIndexOnly';Hydrated=$false
    })
  }

  $result=@($rows.ToArray()|Sort-Object @{Expression='MatchScore';Descending=$true},@{Expression='LogicalPath';Ascending=$true}|Select-Object -First $MaximumResults)
  $watch.Stop()
  Write-PMMLog ('AIIO fast full-index query: '+$watch.Elapsed.ToString()+' | '+$queryText+' | returned='+$result.Count)
  return $result
}
