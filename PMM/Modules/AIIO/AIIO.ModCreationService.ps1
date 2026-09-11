<#
AIIO standalone mod-creation service
====================================

This service adds a deliberately narrow Level-B creation path to AIIO.  An
external AI may query and request exact families from the user's current local
Game Reference, then return a declarative cooked-tree candidate.  PMM validates
the candidate, stages it as untrusted data and can build a standalone PAK only
after the user presses the explicit build button.  Nothing in this module can
deploy, enable, publish or promote the result to stable Knowledge.
#>

$Script:PMMAIIOModCreationSchema='PMM_MOD_CREATION_CANDIDATE_V1'
$Script:PMMAIIOModCreationMode='standalone-cooked-tree'
$Script:PMMAIIOModAttributionEntry='PMM/Metadata/created-with-pmm.json'
$Script:PMMAIIOModPublicAttribution='This mod was created with PMM assistance.'

function Get-PMMAIIOGameReferenceProof {
  [CmdletBinding()]
  param([switch]$RequireCurrent)
  $reference=Get-PMMGameReferenceState
  if($RequireCurrent -and [string]$reference.Status -ne 'Current'){
    throw ('A current local Vanilla Game Reference is required for mod creation. '+[string]$reference.Reason)
  }
  $state=$reference.State
  return [pscustomobject][ordered]@{
    Schema='PMM_AIIO_GAME_REFERENCE_PROOF_V1'
    Status=[string]$reference.Status
    Reason=[string]$reference.Reason
    ScopeVersion=$(if($state){[string]$state.ScopeVersion}else{[string]$reference.Identity.ScopeVersion})
    PakIndexSha256=$(if($state){[string]$state.PakIndexSha256}else{''})
    MappingsSha256=$(if($state){[string]$state.MappingsSha256}else{[string]$reference.Identity.MappingsSha256})
    SourcePakSize=$(if($state){[int64]$state.SourcePakSize}else{[int64]$reference.Identity.PakSize})
    SourcePakLastWriteUtc=$(if($state){[string]$state.SourcePakLastWriteUtc}else{[string]$reference.Identity.PakLastWriteUtc})
    FamilyCount=[int]$reference.FamilyCount
    FileCount=[int]$reference.FileCount
    Bytes=[int64]$reference.Bytes
  }
}

function Get-PMMAIIOGameReferenceFamilyExact([string]$LogicalPath) {
  $asset=Normalize-PMMReferenceLogicalPath $LogicalPath
  if([string]::IsNullOrWhiteSpace($asset) -or [IO.Path]::GetExtension($asset) -ine '.uasset'){
    throw ('An exact Game Reference .uasset logical path is required: '+$LogicalPath)
  }
  $stem=(Get-PakLogicalStem $asset).ToLowerInvariant()
  $matches=@(Get-PMMGameReferenceFamilies|Where-Object{
    (Normalize-PMMReferenceLogicalPath ([string]$_.Asset)) -ieq $asset -or [string]$_.FamilyKey -ieq $stem
  }|Select-Object -First 2)
  if($matches.Count -ne 1){throw ('The current Game Reference does not contain one exact family for: '+$asset)}
  return $matches[0]
}

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
  foreach($family in @(Get-PMMGameReferenceFamilies)){
    $asset=Normalize-PMMReferenceLogicalPath ([string]$family.Asset)
    $assetLower=$asset.ToLowerInvariant()
    $familyKey=([string]$family.FamilyKey).ToLowerInvariant()
    $leaf=([IO.Path]::GetFileNameWithoutExtension($asset)).ToLowerInvariant()
    $score=0;$reasons=[Collections.Generic.List[string]]::new()
    if($assetLower -eq $normalizedQuery -or $familyKey -eq (Get-PakLogicalStem $normalizedQuery)){$score+=1000;$reasons.Add('exact logical family')}
    elseif($assetLower.StartsWith($normalizedQuery,[StringComparison]::OrdinalIgnoreCase)){$score+=520;$reasons.Add('logical path prefix')}
    elseif($assetLower.Contains($normalizedQuery)){$score+=360;$reasons.Add('logical path contains query')}
    elseif($leaf.Contains($normalizedQuery)){$score+=320;$reasons.Add('asset name contains query')}
    $familyTokens=@($family.Tokens|ForEach-Object{([string]$_).ToLowerInvariant()})
    $matched=[Collections.Generic.List[string]]::new()
    foreach($token in $queryTokens){if($familyTokens -contains $token){$matched.Add($token)}}
    if($matched.Count -gt 0){$score+=[Math]::Min(300,80*$matched.Count);$reasons.Add('token match: '+(@($matched.ToArray()) -join ', '))}
    if($score -le 0){continue}
    $parts=@($family.Parts|ForEach-Object{[pscustomobject]@{Extension=[string]$_.Extension;RelativePath=[string]$_.RelativePath;Size=[int64]$_.Size;Sha256=[string]$_.Sha256}})
    $rows.Add([pscustomobject]@{LogicalPath=$asset;FamilyKey=[string]$family.FamilyKey;Bytes=[int64]$family.Bytes;Parts=$parts;Tokens=@($family.Tokens);MatchScore=$score;MatchReason=(@($reasons.ToArray()) -join '; ')})
  }
  return @($rows.ToArray()|Sort-Object @{Expression='MatchScore';Descending=$true},@{Expression='LogicalPath';Ascending=$true}|Select-Object -First $MaximumResults)
}

function Copy-PMMAIIOGameReferenceSelection {
  [CmdletBinding()]
  param([Parameter(Mandatory=$true)][array]$Families,[Parameter(Mandatory=$true)][string]$Destination,[Parameter(Mandatory=$true)][string]$SelectionPolicy,[string]$SeedAsset='')
  $proof=Get-PMMAIIOGameReferenceProof -RequireCurrent
  $rows=[Collections.Generic.List[object]]::new();[int64]$bytes=0
  foreach($family in @($Families)){
    $copied=@(Copy-PMMGameReferenceFamilyToHandoff $family $Destination)
    $familyBytes=[int64]($copied|Measure-Object Size -Sum).Sum;$bytes+=$familyBytes
    $rows.Add([pscustomobject]@{Asset=[string]$family.Asset;FamilyKey=[string]$family.FamilyKey;Bytes=$familyBytes;Parts=$copied})
  }
  $manifest=[ordered]@{
    Schema='PMM_AIIO_GAME_REFERENCE_DATA_V1'
    SelectionPolicy=$SelectionPolicy
    SeedAsset=$SeedAsset
    GameReference=$proof
    FamilyCount=$rows.Count
    Bytes=$bytes
    Families=$rows.ToArray()
    Safety='Local Vanilla evidence for this AIIO exchange only. It does not authorize deployment or prove runtime behavior.'
  }
  Write-PMMAIIOJsonAtomic (Join-Path $Destination 'game-reference-data.json') $manifest 45
  return [pscustomobject]@{Count=$rows.Count;Bytes=$bytes;Manifest=$manifest}
}

function Export-PMMAIIOGameReferenceAsset {
  [CmdletBinding()]
  param([Parameter(Mandatory=$true)][string]$LogicalPath,[Parameter(Mandatory=$true)][string]$Destination,[int64]$MaximumBytes=67108864)
  $family=Get-PMMAIIOGameReferenceFamilyExact $LogicalPath
  if($MaximumBytes -le 0){$MaximumBytes=67108864}
  if([int64]$family.Bytes -gt $MaximumBytes){throw ('The exact Game Reference family exceeds the declared data budget: '+[string]$family.Asset)}
  return (Copy-PMMAIIOGameReferenceSelection -Families @($family) -Destination $Destination -SelectionPolicy 'exact-current-family-v1' -SeedAsset ([string]$family.Asset))
}

function Export-PMMAIIOGameReferenceNeighborhood {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory=$true)][string]$LogicalPath,
    [Parameter(Mandatory=$true)][string]$Destination,
    [ValidateRange(1,32)][int]$MaximumFamilies=12,
    [int64]$MaximumBytes=134217728
  )
  if($MaximumBytes -le 0){$MaximumBytes=134217728}
  $seed=Get-PMMAIIOGameReferenceFamilyExact $LogicalPath
  if([int64]$seed.Bytes -gt $MaximumBytes){throw ('The seed Game Reference family exceeds the declared data budget: '+[string]$seed.Asset)}
  $seedAsset=Normalize-PMMReferenceLogicalPath ([string]$seed.Asset)
  $seedParent=[IO.Path]::GetDirectoryName($seedAsset.Replace([char]47,[char]92))
  $seedTokens=@($seed.Tokens|ForEach-Object{([string]$_).ToLowerInvariant()}|Sort-Object -Unique)
  $candidates=[Collections.Generic.List[object]]::new()
  foreach($family in @(Get-PMMGameReferenceFamilies)){
    $asset=Normalize-PMMReferenceLogicalPath ([string]$family.Asset)
    $score=0
    if([string]$family.FamilyKey -ieq [string]$seed.FamilyKey){$score=10000}
    else{
      $parent=[IO.Path]::GetDirectoryName($asset.Replace([char]47,[char]92))
      if($seedParent -and $parent -and $parent -ieq $seedParent){$score+=300}
      $tokens=@($family.Tokens|ForEach-Object{([string]$_).ToLowerInvariant()})
      foreach($token in $seedTokens){if($tokens -contains $token){$score+=70}}
    }
    if($score -gt 0){$candidates.Add([pscustomobject]@{Family=$family;Score=$score})}
  }
  $selected=[Collections.Generic.List[object]]::new();[int64]$bytes=0
  foreach($candidate in @($candidates.ToArray()|Sort-Object @{Expression='Score';Descending=$true},@{Expression={ [int64]$_.Family.Bytes };Ascending=$true},@{Expression={ [string]$_.Family.Asset };Ascending=$true})){
    if($selected.Count -ge $MaximumFamilies){break}
    $candidateBytes=[int64]$candidate.Family.Bytes
    if(($bytes+$candidateBytes) -gt $MaximumBytes){continue}
    $selected.Add($candidate.Family);$bytes+=$candidateBytes
  }
  if($selected.Count -eq 0){throw 'No Game Reference family fit inside the requested neighborhood budget.'}
  return (Copy-PMMAIIOGameReferenceSelection -Families @($selected.ToArray()) -Destination $Destination -SelectionPolicy 'exact-seed-directory-token-neighborhood-v1' -SeedAsset ([string]$seed.Asset))
}

function Test-PMMAIIOModCreationManifest {
  [CmdletBinding()]
  param([Parameter(Mandatory=$true)]$Manifest,[Parameter(Mandatory=$true)]$Session)
  if([string]$Manifest.schema -ne $Script:PMMAIIOModCreationSchema){throw 'Unsupported standalone mod-creation manifest schema.'}
  if([string]$Session.TaskType -ne 'CREATE_MOD'){throw 'Standalone mod candidates are accepted only by a CREATE_MOD AIIO project.'}
  if([string]$Manifest.sessionId -ne [string]$Session.SessionId){throw 'Standalone mod candidate sessionId does not match the current AIIO project.'}
  if([string]$Manifest.mode -ne $Script:PMMAIIOModCreationMode){throw 'Standalone mod candidate mode must be standalone-cooked-tree.'}
  $modId=[string]$Manifest.modId
  if($modId -notmatch '^[A-Za-z][A-Za-z0-9_.-]{2,63}$'){throw 'modId must be 3-64 safe ASCII characters and begin with a letter.'}
  $displayName=[string]$Manifest.displayName
  if([string]::IsNullOrWhiteSpace($displayName) -or $displayName.Length -gt 120){throw 'displayName is required and cannot exceed 120 characters.'}
  $version=[string]$Manifest.version
  if([string]::IsNullOrWhiteSpace($version) -or $version.Length -gt 40 -or $version.IndexOfAny([char[]]@([char]0,[char]10,[char]13)) -ge 0){throw 'Mod version is missing or invalid.'}
  $output=[string]$Manifest.outputFileName
  if($output -notmatch '^[A-Za-z0-9][A-Za-z0-9_.-]{1,118}_P\.pak$'){throw 'outputFileName must be a safe Unreal patch PAK name ending in _P.pak.'}
  $reference=Get-PMMAIIOGameReferenceProof -RequireCurrent
  $declared=$Manifest.gameReference
  if(-not$declared){throw 'Standalone mod candidate is missing exact Game Reference identity.'}
  foreach($field in @('ScopeVersion','PakIndexSha256','MappingsSha256')){
    $actual=[string]$reference.$field;$expected=[string]$declared.$field
    if([string]::IsNullOrWhiteSpace($expected) -or $actual.ToLowerInvariant() -ne $expected.ToLowerInvariant()){
      throw ('Standalone mod candidate Game Reference identity is stale: '+$field)
    }
  }
  $sources=@($Manifest.sourceFamilies)
  if($sources.Count -lt 1 -or $sources.Count -gt 64){throw 'Standalone mod candidate must declare 1-64 exact sourceFamilies.'}
  $seenSources=[Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
  foreach($source in $sources){
    $asset=Normalize-PMMReferenceLogicalPath ([string]$source.asset)
    if(-not$seenSources.Add($asset)){throw ('Duplicate source family: '+$asset)}
    $family=Get-PMMAIIOGameReferenceFamilyExact $asset
    $actualParts=@($family.Parts|ForEach-Object{([string]$_.RelativePath).ToLowerInvariant()+'|'+([string]$_.Sha256).ToLowerInvariant()+'|'+([string]([int64]$_.Size))}|Sort-Object)
    $declaredParts=@($source.parts|ForEach-Object{([string]$_.relativePath).ToLowerInvariant()+'|'+([string]$_.sha256).ToLowerInvariant()+'|'+([string]([int64]$_.size))}|Sort-Object)
    if($declaredParts.Count -eq 0 -or ($actualParts -join "`n") -cne ($declaredParts -join "`n")){throw ('Source-family proof does not match the current Game Reference: '+$asset)}
  }
  $files=@($Manifest.files)
  if($files.Count -lt 1 -or $files.Count -gt 2000){throw 'Standalone mod candidate must declare 1-2,000 cooked files.'}
  return [pscustomobject]@{Schema=$Script:PMMAIIOModCreationSchema;ModId=$modId;DisplayName=$displayName;Version=$version;OutputFileName=$output;SourceFamilies=$sources;GameReference=$reference}
}

function Test-PMMAIIOModCreationCandidateTree {
  [CmdletBinding()]
  param([Parameter(Mandatory=$true)][string]$Root,[Parameter(Mandatory=$true)]$Manifest)
  $manifestPath=Join-Path $Root 'mod-creation.json'
  if(-not(Test-Path -LiteralPath $manifestPath -PathType Leaf)){throw 'Standalone mod candidate is missing mod-creation.json.'}
  $all=@(Get-ChildItem -LiteralPath $Root -Recurse -File -ErrorAction Stop)
  $actual=[Collections.Generic.List[object]]::new();$headers=[Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase);$sidecars=[Collections.Generic.List[string]]::new();[int64]$bytes=0
  foreach($file in $all){
    $rel=$file.FullName.Substring($Root.Length).TrimStart([char]92,[char]47).Replace([char]92,[char]47)
    if($rel -ceq 'mod-creation.json'){continue}
    if($rel -cnotmatch '^cooked/Pal/Content/.+\.(uasset|uexp|ubulk|uptnl)$'){throw ('Unexpected standalone mod candidate file: '+$rel)}
    $logical=$rel.Substring('cooked/'.Length)
    [void](Get-PMMSafePakOutputPath (Join-Path $Root '_path_validation_only') $logical)
    $ext=[IO.Path]::GetExtension($rel).ToLowerInvariant();$stem=$rel.Substring(0,$rel.Length-$ext.Length)
    if($ext -eq '.uasset'){[void]$headers.Add($stem)}else{$sidecars.Add($stem)}
    $hash=Get-Sha256 $file.FullName;$bytes+=[int64]$file.Length
    $actual.Add([pscustomobject]@{RelativePath=$rel;Bytes=[int64]$file.Length;Sha256=$hash})
  }
  if($actual.Count -eq 0 -or $headers.Count -eq 0){throw 'Standalone mod candidate contains no cooked .uasset family.'}
  if($bytes -gt 2147483648){throw 'Standalone mod candidate cooked tree exceeds 2 GiB.'}
  foreach($stem in $sidecars){if(-not$headers.Contains($stem)){throw ('Standalone mod candidate contains an orphan sidecar: '+$stem)}}
  $declared=@($Manifest.files|ForEach-Object{([string]$_.relativePath).Replace([char]92,[char]47).ToLowerInvariant()+'|'+([string]$_.sha256).ToLowerInvariant()+'|'+([string]([int64]$_.bytes))}|Sort-Object)
  $observed=@($actual.ToArray()|ForEach-Object{([string]$_.RelativePath).ToLowerInvariant()+'|'+([string]$_.Sha256).ToLowerInvariant()+'|'+([string]([int64]$_.Bytes))}|Sort-Object)
  if(($declared -join "`n") -cne ($observed -join "`n")){throw 'Standalone mod candidate files do not match the exact manifest hashes/sizes.'}
  return [pscustomobject]@{Files=$actual.ToArray();Bytes=$bytes;FamilyCount=$headers.Count}
}

function Assert-PMMAIIOCandidateRecordIntegrity($Record) {
  foreach($proof in @($Record.Files)){
    $path=Join-Path ([string]$Record.Root) (([string]$proof.RelativePath).Replace([char]47,[char]92))
    if(-not(Test-Path -LiteralPath $path -PathType Leaf)){throw ('Staged candidate file is missing: '+[string]$proof.RelativePath)}
    if([int64](Get-Item -LiteralPath $path).Length -ne [int64]$proof.Bytes -or (Get-Sha256 $path) -ne ([string]$proof.Sha256).ToLowerInvariant()){
      throw ('Staged candidate bytes changed after import: '+[string]$proof.RelativePath)
    }
  }
}

function Build-PMMAIIOModCandidate {
  [CmdletBinding()]
  param([Parameter(Mandatory=$true)][string]$SessionId,[Parameter(Mandatory=$true)][string]$SolutionId)
  $session=Get-PMMAIIOSession $SessionId
  if(-not$session){throw ('AIIO session not found: '+$SessionId)}
  if([string]$session.TaskType -ne 'CREATE_MOD'){throw 'Only a CREATE_MOD project can build a standalone mod.'}
  $records=@(Get-PMMAIIOCandidateRecords $SessionId|Where-Object{[string]$_.SolutionId -eq $SolutionId}|Select-Object -First 1)
  if($records.Count -ne 1){throw 'Selected standalone mod candidate was not found.'}
  $record=$records[0]
  if([string]$record.InputSchema -ne $Script:PMMAIIOModCreationSchema){throw 'Selected candidate is not a standalone mod-creation candidate.'}
  Assert-PMMAIIOCandidateRecordIntegrity $record
  $manifestPath=Join-Path ([string]$record.Root) 'mod-creation.json'
  $manifest=Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8|ConvertFrom-Json -ErrorAction Stop
  $contract=Test-PMMAIIOModCreationManifest $manifest $session
  $tree=Test-PMMAIIOModCreationCandidateTree ([string]$record.Root) $manifest
  $probeCount=0
  foreach($header in @($tree.Files|Where-Object{[IO.Path]::GetExtension([string]$_.RelativePath) -ieq '.uasset'})){
    $headerPath=Join-Path ([string]$record.Root) (([string]$header.RelativePath).Replace([char]47,[char]92))
    $probe=Invoke-PMMManualSolutionProbe $headerPath
    if(-not$probe.Ok){throw ('Standalone mod candidate failed the read-only AssetReader probe for '+[string]$header.RelativePath+'. '+[string]$probe.Reason+' '+[string]$probe.Output)}
    $probeCount++
  }
  $cooked=Join-Path ([string]$record.Root) 'cooked'
  $outputRoot=Join-Path (Get-PMMAIIOSessionPath $SessionId) ('artifacts\mod-builds\'+$SolutionId)
  # Reuse AIIO's transient-root cleanup contract so an interrupted worker does
  # not leave a multi-gigabyte candidate build behind indefinitely.
  $tempRoot=Join-Path (Join-PMMPath 'Temp' 'AIIO') ('AIIOModBuild_'+[guid]::NewGuid().ToString('N'))
  $packRoot=Join-Path $tempRoot 'payload'
  $tempPak=Join-Path $tempRoot ([string]$contract.OutputFileName)
  $outputPak=Join-Path $outputRoot ([string]$contract.OutputFileName)
  $journal=''
  try{
    if(Get-Command Start-PMMJournalOperation -ErrorAction SilentlyContinue){$journal=Start-PMMJournalOperation -Kind AIIOModBuild -Target $SolutionId -Metadata ([ordered]@{SessionId=$SessionId;ModId=[string]$contract.ModId})}
    New-Item -ItemType Directory -Force -Path $tempRoot,$packRoot,$outputRoot|Out-Null
    Set-PMMTransientStageOwner $tempRoot 'AIIOModBuild'
    foreach($child in @(Get-ChildItem -LiteralPath $cooked -Force -ErrorAction Stop)){Copy-Item -LiteralPath $child.FullName -Destination $packRoot -Recurse -Force}
    $identity=Get-PMMAIIOProductIdentity
    $attribution=[ordered]@{
      Schema='PMM_MOD_ATTRIBUTION_V1'
      CreatedWith='Palworld Manager Merger (PMM)'
      Notice=$Script:PMMAIIOModPublicAttribution
      ProductVersion=[string]$identity.Version
      BuildId=[string]$identity.BuildId
      SolutionId=$SolutionId
      ContainsPersonalData=$false
      RequiredPublicDescription=$Script:PMMAIIOModPublicAttribution
    }
    $attributionPath=Join-Path $packRoot ($Script:PMMAIIOModAttributionEntry.Replace([char]47,[char]92))
    Write-PMMAIIOJsonAtomic $attributionPath $attribution 20
    Pack-Pak $packRoot $tempPak
    if(-not(Test-Pak $tempPak)){throw 'Standalone mod PAK failed repak index verification.'}
    Assert-PakAssetFamiliesComplete $tempPak
    $entries=@(Get-PakEntries $tempPak)
    foreach($file in @($tree.Files)){
      $expected=([string]$file.RelativePath).Substring('cooked/'.Length)
      if(-not(Find-PakEntryExact $entries $expected)){throw ('Standalone mod PAK is missing a declared cooked entry: '+$expected)}
    }
    if(-not(Find-PakEntryExact $entries $Script:PMMAIIOModAttributionEntry)){throw 'Standalone mod PAK is missing its required PMM attribution metadata.'}
    if($entries.Count -ne (@($tree.Files).Count+1)){throw 'Standalone mod PAK contains undeclared entries beyond its cooked tree and required PMM attribution.'}
    $pakHash=Get-Sha256 $tempPak;$pakBytes=[int64](Get-Item -LiteralPath $tempPak).Length
    if(Test-Path -LiteralPath $outputPak -PathType Leaf){Remove-Item -LiteralPath $outputPak -Force}
    Move-Item -LiteralPath $tempPak -Destination $outputPak
    $build=[ordered]@{
      Schema='PMM_MOD_CREATION_BUILD_V1';Status='LOCAL_BUILD_UNPROVEN';SessionId=$SessionId;SolutionId=$SolutionId
      ModId=[string]$contract.ModId;DisplayName=[string]$contract.DisplayName;Version=[string]$contract.Version
      OutputFileName=[string]$contract.OutputFileName;PakSha256=$pakHash;PakBytes=$pakBytes;PakEntryCount=$entries.Count;AssetReaderProbeCount=$probeCount
      GameReference=$contract.GameReference;SourceFamilies=@($contract.SourceFamilies);CandidateFiles=@($tree.Files);Attribution=$attribution;AttributionPakEntry=$Script:PMMAIIOModAttributionEntry
      BuiltUtc=[DateTime]::UtcNow.ToString('o');AutomaticallyDeployed=$false;AutomaticallyPublished=$false;KnowledgeStatus='UNPROVEN'
      RequiredPublicDescription=$Script:PMMAIIOModPublicAttribution
      NextStep='Import or deploy the PAK only through an explicit user action, test it in Palworld, include the required PMM-assistance sentence in its public description, then submit exact validation/Knowledge feedback.'
    }
    Write-PMMAIIOJsonAtomic (Join-Path $outputRoot 'mod-build.json') $build 60
    $stored=Get-Content -LiteralPath ([string]$record.RecordPath) -Raw -Encoding UTF8|ConvertFrom-Json
    $stored.Status='ModBuiltUnproven';$stored.RuntimeStatus='UNPROVEN'
    $stored|Add-Member -NotePropertyName BuiltPak -NotePropertyValue ([pscustomobject]@{Path=$outputPak;FileName=[string]$contract.OutputFileName;Sha256=$pakHash;Bytes=$pakBytes;BuiltUtc=[string]$build.BuiltUtc;AttributionEntry=$Script:PMMAIIOModAttributionEntry;RequiredPublicDescription=$Script:PMMAIIOModPublicAttribution}) -Force
    Write-PMMAIIOJsonAtomic ([string]$record.RecordPath) $stored 45
    $session.Status='ModBuiltUnproven';$session.AttentionRequired=$true;$session.OperationState='UserRuntimeTestRequired';$session.LastPresentedCandidate=$SolutionId
    Save-PMMAIIOSession $session|Out-Null
    try{Add-PMMAIIOHistoryEvent -SessionId $SessionId -Event MOD_BUILT_UNPROVEN -Message ([string]$contract.OutputFileName) -Data ([ordered]@{SolutionId=$SolutionId;PakSha256=$pakHash;PakBytes=$pakBytes;AutomaticallyDeployed=$false})|Out-Null}catch{Write-PMMLog ('Standalone mod was built, but its auxiliary history event could not be written: '+$_.Exception.Message)}
    if($journal){try{Complete-PMMJournalOperation -OperationId $journal -Kind AIIOModBuild -Metadata ([ordered]@{PakSha256=$pakHash;PakBytes=$pakBytes;OutputFileName=[string]$contract.OutputFileName})}catch{}}
    return [pscustomobject]@{SessionId=$SessionId;SolutionId=$SolutionId;OutputPath=$outputPak;OutputDirectory=$outputRoot;FileName=[string]$contract.OutputFileName;PakSha256=$pakHash;PakBytes=$pakBytes;Status='LOCAL_BUILD_UNPROVEN';AttributionEntry=$Script:PMMAIIOModAttributionEntry;RequiredPublicDescription=$Script:PMMAIIOModPublicAttribution}
  }catch{
    if($journal){try{Fail-PMMJournalOperation -OperationId $journal -Kind AIIOModBuild -Message $_.Exception.Message}catch{}}
    throw
  }finally{
    Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
    Remove-PMMTransientStageOwner $tempRoot
  }
}
