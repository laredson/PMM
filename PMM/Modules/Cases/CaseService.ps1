<# Shared persistent case contract. Load after AIIO CaseWorkspace and Preview5.
The V3 envelope stays readable; ContractVersion 4 adds immutable input binding. #>

function Get-PMMCaseValue($Object,[string]$Name,$Default=$null) {
  if($null -eq $Object){return $Default}
  if($Object -is [Collections.IDictionary]){if($Object.Contains($Name)){return $Object[$Name]};return $Default}
  $property=$Object.PSObject.Properties[$Name];if($property){return $property.Value};return $Default
}
function ConvertTo-PMMCaseCanonicalJson($Value) {
  if($null -eq $Value){return 'null'}
  if($Value -is [string] -or $Value -is [ValueType]){return (ConvertTo-Json -InputObject $Value -Compress)}
  if($Value -is [Collections.IDictionary]){
    return ('{'+(@(foreach($key in @($Value.Keys|Sort-Object)){(ConvertTo-Json -InputObject ([string]$key) -Compress)+':'+(ConvertTo-PMMCaseCanonicalJson $Value[$key])}) -join ',')+'}')
  }
  if($Value -is [Collections.IEnumerable]){return ('['+(@(foreach($entry in $Value){ConvertTo-PMMCaseCanonicalJson $entry}) -join ',')+']')}
  return ('{'+(@(foreach($property in @($Value.PSObject.Properties|Sort-Object Name)){(ConvertTo-Json -InputObject ([string]$property.Name) -Compress)+':'+(ConvertTo-PMMCaseCanonicalJson $property.Value)}) -join ',')+'}')
}
function Get-PMMCaseDigest($Value) {
  $json=ConvertTo-PMMCaseCanonicalJson $Value;$sha=[Security.Cryptography.SHA256]::Create()
  try{return ([BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($json))).Replace('-','').ToLowerInvariant())}finally{$sha.Dispose()}
}
function Write-PMMCaseDocument([string]$Path,$Value) {
  if(Get-Command Write-PMMJsonAtomic -ErrorAction SilentlyContinue){Write-PMMJsonAtomic -Path $Path -Value $Value -Depth 90;return}
  $parent=Split-Path -Parent $Path;[void][IO.Directory]::CreateDirectory($parent)
  $temporary=Join-Path $parent ('.case-'+[guid]::NewGuid().ToString('N')+'.tmp')
  try{
    $json=ConvertTo-Json -InputObject $Value -Depth 90;[void]($json|ConvertFrom-Json)
    [IO.File]::WriteAllText($temporary,$json,[Text.UTF8Encoding]::new($false))
    $stream=[IO.File]::Open($temporary,[IO.FileMode]::Open,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)
    try{$stream.Flush($true)}finally{$stream.Dispose()}
    if([IO.File]::Exists($Path)){[IO.File]::Replace($temporary,$Path,$Path+'.bak')}else{[IO.File]::Move($temporary,$Path)}
  }finally{if([IO.File]::Exists($temporary)){[IO.File]::Delete($temporary)}}
}
function Get-PMMCaseContract($Case) {
  if(-not$Case){throw 'Case not found.'}
  $activePublication=Get-Variable -Name PMMCaseActivePublication -Scope Script -ErrorAction SilentlyContinue
  $defaults=[ordered]@{ContractVersion=4;LogicalKey='';Origin='Crear';CurrentEvidenceRevision='';EvidenceRevisions=@();LegacyReviewCaseIds=@();RelatedCaseIds=@();Candidates=@();Observations=@();Reviews=@();PublicationId=$(if($activePublication){[string]$activePublication.Value}else{''})}
  foreach($key in $defaults.Keys){if(-not$Case.PSObject.Properties[$key]){$Case|Add-Member -NotePropertyName $key -NotePropertyValue $defaults[$key]}}
  return $Case
}
function Initialize-PMMCaseContracts {
  foreach($stored in @(Get-PMMAIIOCases)){
    $needsSave=(-not$stored.PSObject.Properties['ContractVersion']);$case=Get-PMMCaseContract $stored
    $session=$null
    if($case.LegacySessionId -and (Get-Command Get-PMMAIIOSession -ErrorAction SilentlyContinue)){$session=Get-PMMAIIOSession ([string]$case.LegacySessionId)}
    if($session){$priorIds=Get-PMMCaseDigest @($case.LegacyReviewCaseIds);$case.LegacyReviewCaseIds=@(@($case.LegacyReviewCaseIds)+@(Get-PMMCaseValue $session 'CaseIds' @())|Sort-Object -Unique);if((Get-PMMCaseDigest @($case.LegacyReviewCaseIds)) -cne $priorIds){$needsSave=$true}}
    if($needsSave){Save-PMMAIIOCase $case|Out-Null}
    if(-not$case.CurrentEvidenceRevision){
      Add-PMMCaseEvidenceRevision ([string]$case.CaseId) ([ordered]@{
        Kind='LegacyContext';Context=(Get-PMMCaseContextSnapshot $case);LegacySessionId=[string]$case.LegacySessionId
        LegacyReviewCaseIds=@($case.LegacyReviewCaseIds);SourceSignature=[string](Get-PMMCaseValue $session 'SourceSignature' '')
        MergeOrderSignature=[string](Get-PMMCaseValue $session 'MergeOrderSignature' '');InputCompleteness='Legacy snapshot; full family hashes were not inferred'
      })|Out-Null
    }
  }
}
function Get-PMMCaseLogicalProvider($Mod) {
  foreach($key in @('LogicalId','ModId','Id','Name')){$value=[string](Get-PMMCaseValue $Mod $key '');if($value){return $value.Trim().ToLowerInvariant()}}
  throw 'A case provider requires a logical identity or a name.'
}
function Get-PMMConflictCaseKey([string]$Asset,[array]$Providers) {
  $normalized=$Asset.Trim().Replace('\','/').TrimStart('/').ToLowerInvariant()
  if(-not$normalized -or $normalized -match '(^|/)\.\.(/|$)'){throw 'Invalid case asset path.'}
  $ids=@($Providers|ForEach-Object{if($_ -is [string]){([string]$_).Trim().ToLowerInvariant()}else{Get-PMMCaseLogicalProvider $_}}|Sort-Object -Unique)
  if($ids.Count -lt 1){throw 'A conflict requires at least one provider.'}
  return ('conflict-'+(Get-PMMCaseDigest ([ordered]@{Asset=$normalized;Providers=$ids})))
}
function Add-PMMCaseEvidenceRevision([string]$CaseId,$Evidence) {
  $case=Get-PMMCaseContract (Get-PMMAIIOCase $CaseId)
  $revision='EV-'+(Get-PMMCaseDigest $Evidence)
  $path=Join-Path (Get-PMMAIIOCasePath $CaseId) ('revisions/'+$revision+'.json')
  if(Test-Path -LiteralPath $path){
    $existing=Get-Content -LiteralPath $path -Raw -Encoding UTF8|ConvertFrom-Json
    if(('EV-'+(Get-PMMCaseDigest $existing.Evidence)) -cne $revision){throw 'Evidence revision integrity check failed.'}
  }else{
    Write-PMMCaseDocument $path ([ordered]@{Schema='PMM_CASE_EVIDENCE_V1';CaseId=$CaseId;RevisionId=$revision;CreatedUtc=[DateTime]::UtcNow.ToString('o');Evidence=$Evidence})
  }
  if(@($case.EvidenceRevisions) -notcontains $revision){$case.EvidenceRevisions=@($case.EvidenceRevisions)+@($revision)}
  $case.CurrentEvidenceRevision=$revision;$case|Add-Member -NotePropertyName ContextFingerprint -NotePropertyValue (Get-PMMCaseDigest (Get-PMMCaseContextSnapshot $case)) -Force;Save-PMMAIIOCase $case|Out-Null
  return $revision
}
function Get-PMMCaseEvidenceRevision([string]$CaseId,[string]$RevisionId='') {
  $case=Get-PMMAIIOCase $CaseId;if(-not$case){throw 'Case not found.'}
  if(-not$RevisionId){$RevisionId=[string](Get-PMMCaseValue $case 'CurrentEvidenceRevision' '')}
  if($RevisionId -cnotmatch '^EV-[a-f0-9]{64}$'){throw 'Invalid evidence revision ID.'}
  $path=Join-Path (Get-PMMAIIOCasePath $CaseId) ('revisions/'+$RevisionId+'.json')
  $record=Get-Content -LiteralPath $path -Raw -Encoding UTF8|ConvertFrom-Json
  if([string]$record.CaseId -cne $CaseId -or ('EV-'+(Get-PMMCaseDigest $record.Evidence)) -cne $RevisionId){throw 'Evidence revision integrity check failed.'}
  return $record
}
function New-PMMContextCase {
  param([ValidateSet('Fix','Compat','Query','NewMod')][string]$Type='Query',[array]$Mods=@(),[string]$Title='',[string]$Description='',[ValidateSet('Jugar','Crear')][string]$Origin='Crear',[array]$RelatedCaseIds=@())
  $caseType=switch($Type){'Fix'{'FIX_MOD'};'Compat'{'COMPATIBILITY'};'Query'{'QUERY'};'NewMod'{'NEW_MOD'}}
  if(-not$Title){$Title=switch($Type){'Fix'{'Repair mod'};'Compat'{'Compatibility investigation'};'Query'{'New question'};'NewMod'{'New mod'}}}
  $references=@(foreach($mod in $Mods){
    $name=[string](Get-PMMCaseValue $mod 'Name' '');$path=[string](Get-PMMCaseValue $mod 'Path' '')
    $hash=[string](Get-PMMCaseValue $mod 'Hash' (Get-PMMCaseValue $mod 'Sha256' ''))
    if($path){if(-not(Test-Path -LiteralPath $path -PathType Leaf)){throw ('Mod reference missing: '+$name)};$hash=Get-Sha256 $path}
    [pscustomobject]@{Kind='MOD';LogicalId=(Get-PMMCaseLogicalProvider $mod);Name=$name;Path=$path;Sha256=$hash;Mode='FULL_PAK';Families=@()}
  })
  foreach($id in $RelatedCaseIds){if(-not(Get-PMMAIIOCase ([string]$id))){throw ('Related case not found: '+$id)}}
  $case=Get-PMMCaseContract (New-PMMAIIOCase -Title $Title -Type $caseType -Description $Description -Transport AUTO -NoInitialStep)
  $case.Type=$caseType;$case.Origin=$Origin;$case.References.Mods=$references;$case.RelatedCaseIds=@($RelatedCaseIds|Sort-Object -Unique)
  Save-PMMAIIOCase $case|Out-Null
  $evidence=[ordered]@{Kind='ManualContext';Objective=$Description;Mods=@($references|ForEach-Object{[ordered]@{LogicalId=$_.LogicalId;Name=$_.Name;Sha256=$_.Sha256}});RelatedCaseIds=$case.RelatedCaseIds}
  $revision=Add-PMMCaseEvidenceRevision $case.CaseId $evidence
  $case=Get-PMMAIIOCase $case.CaseId
  Add-PMMAIIOCaseStep $case 'CASE_CREATED' ('Created from '+$Origin) 'EDIT_OR_CREATE_HANDOFF' @() ([ordered]@{EvidenceRevision=$revision;Origin=$Origin})|Out-Null
  return (Get-PMMAIIOCase $case.CaseId)
}
function Sync-PMMCasesFromAnalysis {
  param($Plan,[switch]$Completed,[switch]$Cancelled)
  if(-not$Completed -or $Cancelled){return @()}
  if(-not$Plan){throw 'A completed analysis requires its published plan.'}
  $prepared=[Collections.Generic.List[object]]::new()
  # Preflight the full result before exposing cases. Analysis failure/cancellation
  # never reaches this API. The legacy review metadata is only an evidence source.
  foreach($asset in @($Plan.Assets|Where-Object{[string]$_.Mode -eq 'Unsupported'})){
    $review=Read-PMMReviewCase ([string]$asset.ReviewFolder)
    if(-not$review){throw ('Missing review evidence: '+[string]$asset.Asset)}
    if(Get-Command Assert-PMMAIIOCaseMetadata -ErrorAction SilentlyContinue){
      $probe=[pscustomobject]@{Asset=$asset.Asset;AssetKey=$asset.AssetKey;ReviewFolder=$asset.ReviewFolder;Providers=$asset.Providers;Case=$review}
      Assert-PMMAIIOCaseMetadata $probe (Get-PMMPath 'Review')|Out-Null
    }
    $providerRecords=@(foreach($name in @($asset.Providers)){
      $match=@($Plan.SourceMods|Where-Object{[string]$_.Name -ceq [string]$name})
      if($match.Count -ne 1){throw ('Ambiguous analysis provider: '+$name)}
      if([string]$match[0].Hash -notmatch '^[a-fA-F0-9]{64}$'){throw ('Analysis provider hash missing: '+$name)}
      [ordered]@{LogicalId=(Get-PMMCaseLogicalProvider $match[0]);Name=[string]$name;Sha256=([string]$match[0].Hash).ToLowerInvariant();Priority=[int](Get-PMMCaseValue $match[0] 'Priority' 0)}
    })
    foreach($inputFile in @($review.InputFiles)){if([string]$inputFile.Sha256 -notmatch '^[a-fA-F0-9]{64}$'){throw 'Analysis input family hash missing.'}}
    $evidence=[ordered]@{
      Kind='UnsupportedAnalysis';Asset=([string]$asset.Asset).Replace('\','/').ToLowerInvariant();LegacyReviewCaseId=[string]$review.CaseId
      Providers=$providerRecords;InputFiles=@($review.InputFiles);VanillaAvailable=[bool]$review.VanillaAvailable
      MappingsSha256=[string]$Plan.MappingsSha256;VanillaSourceSignature=[string]$Plan.VanillaSourceSignature
      Engine=[string]$Plan.Engine;EngineProfile=[string]$Plan.EngineProfile;MergeOrder=@($Plan.MergeOrder)
      KnowledgeRulesSha256=[string](Get-PMMCaseValue $Plan 'KnowledgeRulesSha256' '')
      ReferenceFreshness='CapturedAtAnalysis';SemanticReadability='NotValidated';MergeSupport='Unsupported';Reason=[string]$asset.Reason
    }
    $prepared.Add([pscustomobject]@{Asset=$asset;Review=$review;Evidence=$evidence;Key=(Get-PMMConflictCaseKey ([string]$asset.Asset) $providerRecords)})
  }
  $publicationId='AN-'+(Get-PMMCaseDigest @($prepared.ToArray()|ForEach-Object{$_.Evidence}))
  $results=[Collections.Generic.List[object]]::new()
  $previousPublication=Get-Variable -Name PMMCaseActivePublication -Scope Script -ErrorAction SilentlyContinue
  $previousPublicationId=if($previousPublication){[string]$previousPublication.Value}else{''}
  $mutex=[Threading.Mutex]::new($false,('Local\PMM.CasePublication.'+(Get-PMMCaseDigest (Get-PMMAIIOCaseRoot))))
  $owned=$false
  try{
    try{$owned=$mutex.WaitOne(15000)}catch [Threading.AbandonedMutexException]{$owned=$true}
    if(-not$owned){throw 'Another case publication is still running.'}
    Restore-PMMInterruptedCasePublications $publicationId
    $Script:PMMCaseActivePublication=$publicationId
  foreach($entry in $prepared){
    $allCases=@(Get-PMMAIIOCases);$legacyMatches=@($allCases|Where-Object{@(Get-PMMCaseValue $_ 'LegacyReviewCaseIds' @()) -contains [string]$entry.Review.CaseId});$matches=@($allCases|Where-Object{[string](Get-PMMCaseValue $_ 'LogicalKey' '') -eq $entry.Key});if(-not$matches.Count){$matches=@($legacyMatches|Where-Object{-not[string](Get-PMMCaseValue $_ 'LogicalKey' '') -and @(Get-PMMCaseValue $_ 'LegacyReviewCaseIds' @()).Count -eq 1}|Select-Object -First 1)}
    if($matches.Count -gt 1){throw 'Duplicate logical case identity requires recovery.'}
    $case=if($matches.Count){Get-PMMCaseContract $matches[0]}else{Get-PMMCaseContract (New-PMMAIIOCase -Title ('Compatibility: '+[IO.Path]::GetFileName([string]$entry.Asset.Asset)) -Type COMPATIBILITY -Description ([string]$entry.Asset.Reason) -NoInitialStep)}
    $storedPath=Join-Path (Get-PMMAIIOCasePath ([string]$case.CaseId)) 'case.json'
    $stored=Get-Content -LiteralPath $storedPath -Raw -Encoding UTF8|ConvertFrom-Json
    if([string](Get-PMMCaseValue $stored 'PublicationId' '') -cne $publicationId){
      $previousPath=Join-Path (Get-PMMAIIOCasePath ([string]$case.CaseId)) ('publications/'+$publicationId+'.previous.json')
      if(-not(Test-Path -LiteralPath $previousPath)){Write-PMMCaseDocument $previousPath $stored}
    }
    $case.RelatedCaseIds=@(@($case.RelatedCaseIds)+@($legacyMatches|Where-Object{[string]$_.CaseId -cne [string]$case.CaseId}|ForEach-Object{[string]$_.CaseId})|Sort-Object -Unique);$priorRevision=[string]$case.CurrentEvidenceRevision
    $case.LogicalKey=$entry.Key;$case.Origin='Jugar';$case.PublicationId=$publicationId
    $case.References.Mods=@($entry.Evidence.Providers|ForEach-Object{[pscustomobject]@{Kind='MOD';LogicalId=$_.LogicalId;Name=$_.Name;Path='';Sha256=$_.Sha256;Mode='FAMILY';Families=@([string]$entry.Asset.Asset)}})
    $case.References.VanillaFamilies=@([pscustomobject]@{Kind='VANILLA_FAMILY';LogicalPath=[string]$entry.Asset.Asset;Mode='FAMILY'})
    $case.LegacyReviewCaseIds=@(@($case.LegacyReviewCaseIds)+@([string]$entry.Review.CaseId)|Sort-Object -Unique)
    Save-PMMAIIOCase $case|Out-Null
    $revision=Add-PMMCaseEvidenceRevision ([string]$case.CaseId) $entry.Evidence
    $latest=Get-PMMAIIOCaseStep ([string]$case.CaseId) ([int]$case.CurrentStep);if($revision -cne $priorRevision -or -not$latest -or [string](Get-PMMCaseValue $latest.State 'EvidenceRevision' '') -cne $revision){
      $case=Get-PMMAIIOCase $case.CaseId
      Add-PMMAIIOCaseStep $case 'ANALYSIS_EVIDENCE' 'Unsupported asset recorded. Open in Create to investigate.' 'EDIT_OR_CREATE_HANDOFF' @((Join-Path (Get-PMMAIIOCasePath $case.CaseId) ('revisions/'+$revision+'.json'))) ([ordered]@{EvidenceRevision=$revision;LegacyReviewCaseId=$entry.Review.CaseId})|Out-Null
    }
    $entry.Asset|Add-Member -NotePropertyName PersistentCaseId -NotePropertyValue ([string]$case.CaseId) -Force
    $entry.Asset|Add-Member -NotePropertyName EvidenceRevision -NotePropertyValue $revision -Force
    $results.Add([pscustomobject]@{CaseId=$case.CaseId;EvidenceRevision=$revision;Asset=[string]$entry.Asset.Asset})
  }
  Write-PMMCaseDocument (Get-PMMCasePublicationPath $publicationId) ([ordered]@{Schema='PMM_CASE_PUBLICATION_V1';PublicationId=$publicationId;Cases=@($results.ToArray());CompletedUtc=[DateTime]::UtcNow.ToString('o')})
  return @($results.ToArray())
  }finally{$Script:PMMCaseActivePublication=$previousPublicationId;if($owned){$mutex.ReleaseMutex()};$mutex.Dispose()}
}
function Assert-PMMCaseResponseRevision([string]$CaseId,[string]$EvidenceRevision,[string]$LegacyReviewCaseId='') {
  $case=Get-PMMCaseContract (Get-PMMAIIOCase $CaseId)
  if(-not$case.CurrentEvidenceRevision){return ''}
  if(-not$EvidenceRevision -and $LegacyReviewCaseId){
    $matches=@(foreach($revisionId in $case.EvidenceRevisions){$record=Get-PMMCaseEvidenceRevision $CaseId $revisionId;if([string](Get-PMMCaseValue $record.Evidence 'LegacyReviewCaseId' '') -ceq $LegacyReviewCaseId){$revisionId}})
    if($matches.Count -eq 1){$EvidenceRevision=[string]$matches[0]}
  }
  if(-not$EvidenceRevision){throw 'Response requires evidenceRevision. Re-export the current case context; no action was applied.'}
  Get-PMMCaseEvidenceRevision $CaseId $EvidenceRevision|Out-Null
  if($EvidenceRevision -cne [string]$case.CurrentEvidenceRevision){throw 'Response belongs to an older evidence revision. No action was applied to current inputs.'}
  return $EvidenceRevision
}

function Assert-PMMCasePendingActionRevisions([string]$CaseId) {
  $case=Get-PMMAIIOCase $CaseId
  foreach($action in @($case.PendingActions|Where-Object{[string]$_.Status -eq 'Pending'})){
    Assert-PMMCaseResponseRevision $CaseId ([string](Get-PMMCaseValue $action 'EvidenceRevision' '')) ([string](Get-PMMCaseValue $action 'LegacyReviewCaseId' ''))|Out-Null
  }
}
function Get-PMMCaseForAsset($Asset,[array]$Providers=@()) {
  $persistentId=[string](Get-PMMCaseValue $Asset 'PersistentCaseId' '')
  if($persistentId){$case=Get-PMMAIIOCase $persistentId;if($case){return $case}}
  $logical=if($Asset -is [string]){[string]$Asset}else{[string](Get-PMMCaseValue $Asset 'Asset' '')}
  if(-not$Providers.Count){$Providers=@(Get-PMMCaseValue $Asset 'Providers' @())}
  if(-not$logical -or -not$Providers.Count){return $null}
  $key=Get-PMMConflictCaseKey $logical $Providers
  return @(Get-PMMAIIOCases|Where-Object{[string](Get-PMMCaseValue $_ 'LogicalKey' '') -eq $key}|Select-Object -First 1)|Select-Object -First 1
}
function Add-PMMCaseContextSources($Case,$Snapshot,[string]$StageRoot) {
  $revisionId=[string](Get-PMMCaseValue $Snapshot 'EvidenceRevision' '')
  if(-not$revisionId){return}
  $revision=Get-PMMCaseEvidenceRevision ([string]$Case.CaseId) $revisionId
  Write-PMMCaseDocument (Join-Path $StageRoot 'evidence-revision.json') $revision
  Write-PMMCaseDocument (Join-Path $StageRoot 'workorder-template.json') ([ordered]@{schema='PMM_AIIO_WORK_ORDER_V1';workOrderId=('wo-'+[guid]::NewGuid().ToString('N'));case=[ordered]@{caseId=[string]$Case.CaseId;evidenceRevision=$revisionId};actions=@()})
  $referenceList=@(Get-PMMCaseValue (Get-PMMCaseValue $Snapshot 'References' $null) 'Mods' @())
  if([bool](Get-PMMCaseValue $revision.Evidence 'VanillaAvailable' $false)){
    $logical=[string]$revision.Evidence.Asset
    $vanillaRoot=Join-Path $StageRoot 'sources/Vanilla'
    if([IO.Path]::GetExtension($logical) -ieq '.uasset'){Export-VanillaAssetFamilyExact $logical $vanillaRoot|Out-Null}
    else{Export-VanillaFileExact $logical $vanillaRoot|Out-Null}
    Assert-PMMCaseExtractedEvidence $vanillaRoot $revision.Evidence 'Vanilla' 'Vanilla'
  }
  $sourceNumber=0
  foreach($reference in $referenceList){
    $sourceNumber++;$name=[string](Get-PMMCaseValue $reference 'Name' '');$path=[string](Get-PMMCaseValue $reference 'Path' '')
    $expected=[string](Get-PMMCaseValue $reference 'Sha256' '')
    if(-not$path -and (Get-Command Get-LibraryMods -ErrorAction SilentlyContinue)){
      $matches=@(Get-LibraryMods|Where-Object{[string]$_.Name -ceq $name})
      if($matches.Count -eq 1){$path=[string]$matches[0].Path}
    }
    if(-not$path -or -not(Test-Path -LiteralPath $path -PathType Leaf)){throw ('Case mod source unavailable: '+$name)}
    if($expected -and (Get-Sha256 $path) -ine $expected){throw ('Case mod changed since evidence was captured: '+$name)}
    $destination=Join-Path $StageRoot ('sources/provider-'+$sourceNumber)
    [void][IO.Directory]::CreateDirectory($destination)
    $families=@(Get-PMMCaseValue $reference 'Families' @())
    if([string](Get-PMMCaseValue $reference 'Mode' '') -eq 'FAMILY' -and $families.Count){
      foreach($family in $families){
        if([IO.Path]::GetExtension([string]$family) -ieq '.uasset'){Export-PakAssetFamilyExact $path ([string]$family) $destination|Out-Null}
        else{Export-PakFileExact $path ([string]$family) $destination|Out-Null}
      }
    }else{Copy-Item -LiteralPath $path -Destination (Join-Path $destination ([IO.Path]::GetFileName($path))) -Force}
    Assert-PMMCaseExtractedEvidence $destination $revision.Evidence 'Provider' $name
    Write-PMMCaseDocument (Join-Path $destination 'source.json') ([ordered]@{Name=$name;Sha256=$expected;Mode=[string](Get-PMMCaseValue $reference 'Mode' '');Families=$families})
  }
}

function Update-PMMCaseContextRevision([string]$CaseId) {
  $case=Get-PMMCaseContract (Get-PMMAIIOCase $CaseId)
  $context=[ordered]@{
    Objective=[string]$case.Description;Type=[string]$case.Type
    Mods=@($case.References.Mods|ForEach-Object{[ordered]@{Name=[string]$_.Name;Sha256=[string]$_.Sha256;Mode=[string]$_.Mode;Families=@(Get-PMMCaseValue $_ 'Families' @())}})
    Vanilla=@($case.References.VanillaFamilies|ForEach-Object{[string]$_.LogicalPath})
  }
  $contextHash=Get-PMMCaseDigest $context
  if([string](Get-PMMCaseValue $case 'ContextFingerprint' '') -eq $contextHash){return [string]$case.CurrentEvidenceRevision}
  $evidence=if($case.CurrentEvidenceRevision){Copy-PMMAIIOCaseObject (Get-PMMCaseEvidenceRevision $CaseId).Evidence}else{[pscustomobject]@{Kind='CaseContext'}}
  $evidence|Add-Member -NotePropertyName Context -NotePropertyValue $context -Force
  $revision=Add-PMMCaseEvidenceRevision $CaseId $evidence
  $case=Get-PMMAIIOCase $CaseId;$case|Add-Member -NotePropertyName ContextFingerprint -NotePropertyValue $contextHash -Force
  Save-PMMAIIOCase $case|Out-Null
  return $revision
}
function Assert-PMMCaseExtractedEvidence([string]$Root,$Evidence,[string]$Role,[string]$Provider) {
  $asset=[string](Get-PMMCaseValue $Evidence 'Asset' '')
  $inputs=@(Get-PMMCaseValue $Evidence 'InputFiles' @()|Where-Object{[string]$_.Role -eq $Role -and [string]$_.Provider -eq $Provider})
  foreach($inputFile in $inputs){
    $logical=if([IO.Path]::GetExtension($asset) -ieq '.uasset'){[IO.Path]::ChangeExtension($asset,[string]$inputFile.Part)}else{$asset}
    $path=Join-Path $Root $logical
    if(-not(Test-Path -LiteralPath $path -PathType Leaf) -or (Get-Sha256 $path) -ine [string]$inputFile.Sha256){throw ('Extracted case source differs from captured evidence: '+$Provider+' / '+$logical)}
  }
}

function Get-PMMCaseContextSnapshot($Case) {
  return [ordered]@{
    Objective=[string]$Case.Description;Type=[string]$Case.Type
    Mods=@($Case.References.Mods|ForEach-Object{[ordered]@{Name=[string]$_.Name;Sha256=[string]$_.Sha256;Mode=[string]$_.Mode;Families=@(Get-PMMCaseValue $_ 'Families' @())}})
    Vanilla=@($Case.References.VanillaFamilies|ForEach-Object{[string]$_.LogicalPath})
  }
}
function Get-PMMCasePublicationPath([string]$PublicationId) {
  if($PublicationId -cnotmatch '^AN-[a-f0-9]{64}$'){throw 'Invalid case publication ID.'}
  return (Join-Path (Get-PMMAIIOCaseRoot) ('.publications/'+$PublicationId+'.json'))
}
function Get-PMMCaseVisibleVersion($Case) {
  $publication=[string](Get-PMMCaseValue $Case 'PublicationId' '')
  if(-not$publication){return $Case}
  $active=Get-Variable -Name PMMCaseActivePublication -Scope Script -ErrorAction SilentlyContinue
  if(($active -and [string]$active.Value -ceq $publication) -or (Test-Path -LiteralPath (Get-PMMCasePublicationPath $publication))){return $Case}
  $previous=Join-Path (Get-PMMAIIOCasePath ([string]$Case.CaseId)) ('publications/'+$publication+'.previous.json')
  if(Test-Path -LiteralPath $previous){return (Get-PMMCaseVisibleVersion (Get-Content -LiteralPath $previous -Raw -Encoding UTF8|ConvertFrom-Json))}
  return $null
}
function Assert-PMMCaseWriteAccess($Case) {
  $path=Join-Path (Get-PMMAIIOCasePath ([string]$Case.CaseId)) 'case.json'
  if(-not(Test-Path -LiteralPath $path)){return}
  $stored=Get-Content -LiteralPath $path -Raw -Encoding UTF8|ConvertFrom-Json
  $publication=[string](Get-PMMCaseValue $stored 'PublicationId' '')
  if(-not$publication -or (Test-Path -LiteralPath (Get-PMMCasePublicationPath $publication))){return}
  $active=Get-Variable -Name PMMCaseActivePublication -Scope Script -ErrorAction SilentlyContinue
  if($active -and [string]$active.Value -ceq $publication){return}
  throw 'A case publication was interrupted or is in progress. Repeat Analyze to resume its evidence before editing this case.'
}

function Restore-PMMInterruptedCasePublications([string]$ResumingPublicationId) {
  # Caller owns the workspace publication mutex. Preserve uncommitted new cases
  # for a possible exact retry; restore old snapshots before a different Analyze.
  foreach($directory in @(Get-ChildItem -LiteralPath (Get-PMMAIIOCaseRoot) -Directory)){
    if(-not(Test-PMMAIIOCaseId $directory.Name)){continue}
    $path=Join-Path $directory.FullName 'case.json';if(-not(Test-Path -LiteralPath $path)){continue}
    $case=Get-Content -LiteralPath $path -Raw -Encoding UTF8|ConvertFrom-Json
    $publication=[string](Get-PMMCaseValue $case 'PublicationId' '')
    if(-not$publication -or $publication -ceq $ResumingPublicationId -or (Test-Path -LiteralPath (Get-PMMCasePublicationPath $publication))){continue}
    $visible=Get-PMMCaseVisibleVersion $case
    if($visible){Write-PMMCaseDocument $path $visible}
  }
}
function Assert-PMMCaseInputsCurrent {
  param([Parameter(Mandatory=$true)][string]$CaseId,[string]$RevisionId='')
  $case=Get-PMMCaseContract (Get-PMMAIIOCase $CaseId)
  if(-not$RevisionId){$RevisionId=[string]$case.CurrentEvidenceRevision}
  Assert-PMMCaseResponseRevision $CaseId $RevisionId|Out-Null
  $evidence=(Get-PMMCaseEvidenceRevision $CaseId $RevisionId).Evidence
  $mods=@();if(Get-Command Get-LibraryMods -ErrorAction SilentlyContinue){$mods=@(Get-LibraryMods)}
  $allMods=$mods;if(Get-Command Get-PMMDisabledMods -ErrorAction SilentlyContinue){$allMods+=@(Get-PMMDisabledMods)}
  foreach($reference in @($case.References.Mods)){
    $name=[string]$reference.Name;$path=[string](Get-PMMCaseValue $reference 'Path' '')
    if(-not$path){$matches=@($allMods|Where-Object{[string]$_.Name -ceq $name});if($matches.Count -eq 1){$path=[string]$matches[0].Path}}
    if(-not$path -or -not(Test-Path -LiteralPath $path -PathType Leaf)){throw ('Recorded mod source is unavailable: '+$name)}
    if(-not$reference.Sha256 -or (Get-Sha256 $path) -ine [string]$reference.Sha256){throw ('Recorded mod changed on disk. Analyze or update the case first: '+$name)}
  }
  $mappings=[string](Get-PMMCaseValue $evidence 'MappingsSha256' '')
  if($mappings -and $mappings -ine (Get-Sha256 (Get-PMMMappingsPath))){throw 'Mappings changed after case evidence was captured. Run Analyze again.'}
  $vanillaSignature=[string](Get-PMMCaseValue $evidence 'VanillaSourceSignature' '')
  if($vanillaSignature -and $vanillaSignature -cne (Get-PMMVanillaPakSetQuickSignature)){throw 'The game installation changed after case evidence was captured. Run Analyze again.'}
  $order=@(Get-PMMCaseValue $evidence 'MergeOrder' @())
  if($order.Count){
    $actualOrder=@($mods|Sort-Object Priority,Name|ForEach-Object{[string]$_.Name})
    if(($order -join '|') -cne ($actualOrder -join '|')){throw 'The enabled provider set or merge order changed. Run Analyze again.'}
  }
  $inputs=@(Get-PMMCaseValue $evidence 'InputFiles' @()|Where-Object{[string]$_.Role -eq 'Vanilla'})
  if($inputs.Count){
    $scratch=Join-Path (Get-PMMPath 'Temp') ('CaseEvidenceProbe-'+[guid]::NewGuid().ToString('N'))
    [void][IO.Directory]::CreateDirectory($scratch)
    try{
      $logical=[string]$evidence.Asset
      if([IO.Path]::GetExtension($logical) -ieq '.uasset'){Export-VanillaAssetFamilyExact $logical $scratch|Out-Null}else{Export-VanillaFileExact $logical $scratch|Out-Null}
      Assert-PMMCaseExtractedEvidence $scratch $evidence 'Vanilla' 'Vanilla'
    }finally{
      $root=[IO.Path]::GetFullPath((Get-PMMPath 'Temp')).TrimEnd('\','/')+[IO.Path]::DirectorySeparatorChar
      if([IO.Path]::GetFullPath($scratch).StartsWith($root,[StringComparison]::OrdinalIgnoreCase)){Remove-Item -LiteralPath $scratch -Recurse -Force -ErrorAction SilentlyContinue}
    }
  }
  return $true
}
