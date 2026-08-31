<#
Exact compatibility-build validation and local feedback export.

Validation belongs to a deterministic buildId, not a display filename.  Events
are immutable and remain local.  This release has no feedback API and performs
no upload; Generate feedback file only creates inspectable JSON.
#>

function Get-PMMValidationIdentityLocations {
  $primary='';$recovery=''
  try{$primary=Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'PalworldManagerMerger\identity.dat'}catch{}
  try{$recovery=Join-Path ([Environment]::GetFolderPath('ApplicationData')) 'PalworldManagerMerger\identity-recovery.dat'}catch{}
  return [pscustomobject]@{Primary=$primary;Recovery=$recovery}
}

function Protect-PMMIdentityBytes([byte[]]$Bytes) {
  try{return [Security.Cryptography.ProtectedData]::Protect($Bytes,[Text.Encoding]::UTF8.GetBytes('laredson.PMM.validation.identity.v1'),[Security.Cryptography.DataProtectionScope]::CurrentUser)}catch{return $null}
}

function Unprotect-PMMIdentityBytes([byte[]]$Bytes) {
  try{return [Security.Cryptography.ProtectedData]::Unprotect($Bytes,[Text.Encoding]::UTF8.GetBytes('laredson.PMM.validation.identity.v1'),[Security.Cryptography.DataProtectionScope]::CurrentUser)}catch{return $null}
}

function Get-PMMValidationInstallationIdentity {
  $locations=Get-PMMValidationIdentityLocations;$secret=$null
  foreach($path in @([string]$locations.Primary,[string]$locations.Recovery)){
    if([string]::IsNullOrWhiteSpace($path) -or -not(Test-Path -LiteralPath $path -PathType Leaf)){continue}
    try{$candidate=Unprotect-PMMIdentityBytes ([IO.File]::ReadAllBytes($path));if($candidate -and $candidate.Length -eq 32){$secret=$candidate;break}}catch{}
  }
  if(-not$secret){$secret=New-Object byte[] 32;$rng=[Security.Cryptography.RandomNumberGenerator]::Create();try{$rng.GetBytes($secret)}finally{$rng.Dispose()}}
  $protected=Protect-PMMIdentityBytes $secret
  if($protected){
    foreach($path in @([string]$locations.Primary,[string]$locations.Recovery)){
      if([string]::IsNullOrWhiteSpace($path)){continue}
      try{$parent=Split-Path -Parent $path;New-Item -ItemType Directory -Force -Path $parent|Out-Null;[IO.File]::WriteAllBytes($path,$protected)}catch{}
    }
  }
  $sha=[Security.Cryptography.SHA256]::Create()
  try{$id=([BitConverter]::ToString($sha.ComputeHash($secret))).Replace('-','').ToLowerInvariant()}finally{$sha.Dispose()}
  return [pscustomobject]@{Schema='PMM_INSTALLATION_IDENTITY_V1';InstallationId=$id;ProtectedBy='Windows DPAPI CurrentUser';HardwareFingerprintUsed=$false;AccountIdentifierUsed=$false;ResetAvailable=$false}
}

function Get-PMMBuildIdentitySha256([string]$Text) {
  $sha=[Security.Cryptography.SHA256]::Create()
  try{
    $value=if($null -eq $Text){''}else{[string]$Text}
    $bytes=[Text.Encoding]::UTF8.GetBytes($value)
    return ([BitConverter]::ToString($sha.ComputeHash($bytes))).Replace('-','').ToLowerInvariant()
  }finally{$sha.Dispose()}
}

function Get-PMMBuildManifestHash($Patch) {
  if($Patch -and $Patch.ManifestPath -and (Test-Path -LiteralPath ([string]$Patch.ManifestPath) -PathType Leaf)){return (Get-Sha256 ([string]$Patch.ManifestPath))}
  if($Patch -and $Patch.Manifest){return (Get-PMMBuildIdentitySha256 (($Patch.Manifest|ConvertTo-Json -Depth 100 -Compress)))}
  return ''
}

function Get-PMMDeterministicBuildId($Patch) {
  if(-not$Patch){throw 'Select a compatibility patch first.'}
  $manifest=$Patch.Manifest
  if(-not$manifest){throw 'The selected patch has no readable build manifest.'}
  $outputHash=([string]$Patch.Hash).ToLowerInvariant()
  if($outputHash -notmatch '^[0-9a-f]{64}$'){throw 'The selected patch has no valid output hash.'}
  $sourceRows=@()
  try{
    foreach($row in @($manifest.Sources)){
      $priority=[int]$row.Priority
      $value=([string]$row.Name)+':'+([string]$row.Hash)+':'+$priority.ToString([Globalization.CultureInfo]::InvariantCulture)
      $sourceRows+=,$value
    }
  }catch{}
  if($sourceRows.Count -eq 0){
    try{
      foreach($row in @($manifest.SourceMods)){
        $sourceRows+=,((([string]$row.Name)+':'+([string]$row.Sha256)))
      }
    }catch{}
  }
  if($sourceRows.Count -eq 0){
    try{
      foreach($name in @($manifest.PatchedMods|ForEach-Object{[string]$_}|Sort-Object)){$sourceRows+=,([string]$name)}
    }catch{}
  }
  $solutions=@()
  try{
    foreach($row in @($manifest.IncludedSolutions)){$solutions+=,([string]$row.SolutionId)}
  }catch{}
  try{
    foreach($row in @($manifest.ExperimentalManualSolutions)){
      $solutions+=,('manual:'+([string]$row.CaseId)+':'+([string]$row.Asset))
    }
  }catch{}
  try{
    foreach($row in @($manifest.Assets)){
      if(-not($row.PSObject.Properties.Name -contains 'RecipeId')){continue}
      if([string]::IsNullOrWhiteSpace([string]$row.RecipeId)){continue}
      $solutions+=,('recipe:'+([string]$row.RecipeId)+':'+([string]$row.RecipeCaseId)+':'+([string]$row.Asset))
    }
  }catch{}
  $parts=@(
    'PMM_BUILD_ID_V1',
    $outputHash,
    (@($sourceRows|Sort-Object) -join '|'),
    [string]$manifest.SourceSignature,
    [string]$manifest.MergeOrderSignature,
    $(if($manifest.PSObject.Properties.Name -contains 'EffectiveMergeOrderSignature'){[string]$manifest.EffectiveMergeOrderSignature}else{''}),
    $(if($manifest.PSObject.Properties.Name -contains 'DecisionSignature'){[string]$manifest.DecisionSignature}else{''}),
    [string]$manifest.MappingsSha256,
    $(if($manifest.PSObject.Properties.Name -contains 'VanillaSourceSignature'){[string]$manifest.VanillaSourceSignature}else{''}),
    [string]$manifest.Engine,
    (@($solutions|Sort-Object -Unique) -join '|')
  )
  return (Get-PMMBuildIdentitySha256 ($parts -join "`n"))
}

function Get-PMMBuildValidationSummaryPath([string]$BuildId) {
  if($BuildId -notmatch '^[0-9a-f]{64}$'){throw 'Invalid build ID.'}
  return (Join-PMMPath 'Validation' ('Summaries\'+$BuildId+'.json'))
}

function Get-PMMBuildValidationEvents([string]$BuildId='') {
  $rows=[Collections.Generic.List[object]]::new();$root=Get-PMMPath 'ValidationEvents'
  foreach($file in @(Get-ChildItem -LiteralPath $root -Filter '*.json' -File -ErrorAction SilentlyContinue|Sort-Object LastWriteTimeUtc)){
    try{$event=Get-Content -LiteralPath $file.FullName -Raw -Encoding UTF8|ConvertFrom-Json;if([string]$event.Schema -ne 'PMM_BUILD_VALIDATION_V1'){continue};if($BuildId -and [string]$event.BuildId -ne $BuildId){continue};$rows.Add($event)}catch{}
  }
  return @($rows.ToArray())
}

function Update-PMMBuildValidationSummary([string]$BuildId) {
  $events=@(Get-PMMBuildValidationEvents $BuildId);$status='UNVALIDATED';$latest=$null
  if($events.Count -gt 0){
    $latest=$events[-1]
    switch([string]$latest.Result.Status){
      'PASS' {$status='LOCAL_PASS'}
      'PASS_RECONFIRMED' {$status='LOCAL_PASS'}
      'PARTIAL' {$status='LOCAL_PARTIAL'}
      default {$status='LOCAL_FAIL'}
    }
  }
  $summary=[ordered]@{Schema='PMM_BUILD_VALIDATION_SUMMARY_V1';BuildId=$BuildId;Status=$status;EventCount=$events.Count;LatestEventId=$(if($latest){[string]$latest.EventId}else{''});LatestUtc=$(if($latest){[string]$latest.ReportedUtc}else{''});History=@($events|ForEach-Object{[pscustomobject]@{EventId=[string]$_.EventId;EventType=[string]$_.EventType;Status=[string]$_.Result.Status;ReportedUtc=[string]$_.ReportedUtc}})}
  Write-PMMAIIOJsonAtomic (Get-PMMBuildValidationSummaryPath $BuildId) $summary 25
  return [pscustomobject]$summary
}

function Get-PMMBuildValidationSummary($Patch) {
  if(-not$Patch){return [pscustomobject]@{Status='NOT_DEPLOYED';BuildId='';EventCount=0}}
  try{if(-not[bool]$Patch.Deployed){return [pscustomobject]@{Status='NOT_DEPLOYED';BuildId=(Get-PMMDeterministicBuildId $Patch);EventCount=0}}}catch{return [pscustomobject]@{Status='NOT_DEPLOYED';BuildId='';EventCount=0}}
  try{$id=Get-PMMDeterministicBuildId $Patch}catch{return [pscustomobject]@{Status='STALE';BuildId='';EventCount=0}}
  $path=Get-PMMBuildValidationSummaryPath $id
  if(Test-Path -LiteralPath $path -PathType Leaf){try{return (Get-Content -LiteralPath $path -Raw -Encoding UTF8|ConvertFrom-Json)}catch{}}
  return (Update-PMMBuildValidationSummary $id)
}

function New-PMMBuildValidationEvent {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory=$true)]$Patch,
    [Parameter(Mandatory=$true)][ValidateSet('PASS','PASS_RECONFIRMED','PARTIAL','FAIL','CRASH')][string]$Result,
    [string]$Category='',
    [string]$Notes=''
  )
  if($Notes.Length -gt 4000){throw 'Validation notes exceed 4,000 characters.'}
  $buildId=Get-PMMDeterministicBuildId $Patch;$identity=Get-PMMValidationInstallationIdentity;$manifest=$Patch.Manifest;$product=Get-PMMAIIOProductIdentity
  $eventId=[guid]::NewGuid().ToString('N');$sources=[Collections.Generic.List[object]]::new()
  try{foreach($row in @($manifest.Sources)){$sources.Add([pscustomobject]@{PakName=[string]$row.Name;PakSha256=[string]$row.Hash;Priority=[int]$row.Priority})}}catch{}
  if($sources.Count -eq 0){try{foreach($row in @($manifest.SourceMods)){$sources.Add([pscustomobject]@{PakName=[string]$row.Name;PakSha256=[string]$row.Sha256;Priority=0})}}catch{}}
  $solutions=[Collections.Generic.List[object]]::new()
  try{foreach($row in @($manifest.IncludedSolutions)){$solutions.Add([pscustomobject]@{SolutionId=[string]$row.SolutionId;Origin=[string]$row.Origin;ChannelAtBuild=[string]$row.Channel;CaseIds=@($row.CaseIds)})}}catch{}
  try{foreach($row in @($manifest.ExperimentalManualSolutions)){$solutions.Add([pscustomobject]@{SolutionId=('manual:'+[string]$row.CaseId);Origin='MANUAL_OR_AIIO';ChannelAtBuild='EXPERIMENTAL_UNPROVEN';CaseIds=@([string]$row.CaseId);Asset=[string]$row.Asset})}}catch{}
  try{
    foreach($row in @($manifest.Assets)){
      if(-not($row.PSObject.Properties.Name -contains 'RecipeId') -or [string]::IsNullOrWhiteSpace([string]$row.RecipeId)){continue}
      $solutions.Add([pscustomobject]@{SolutionId=[string]$row.RecipeId;Origin='PMM_KNOWLEDGE';ChannelAtBuild='RUNTIME_PROVEN_RECIPE';CaseIds=@([string]$row.RecipeCaseId);Asset=[string]$row.Asset})
    }
  }catch{}
  $event=[ordered]@{
    Schema='PMM_BUILD_VALIDATION_V1';EventId=$eventId;EventType=$Result;ReportedUtc=[DateTime]::UtcNow.ToString('o');AnonymousInstallationId=[string]$identity.InstallationId;FeedbackConsentVersion=0;BuildId=$buildId;BuildManifestSha256=(Get-PMMBuildManifestHash $Patch);OutputPakSha256=([string]$Patch.Hash).ToLowerInvariant();PmmVersion=[string]$product.Version;EngineId=[string]$manifest.Engine;GameBuild='';VanillaSignature=$(if($manifest.PSObject.Properties.Name -contains 'VanillaSourceSignature'){[string]$manifest.VanillaSourceSignature}else{''});MappingsSha256=[string]$manifest.MappingsSha256;SourceSignature=[string]$manifest.SourceSignature;MergeOrderSignature=[string]$manifest.MergeOrderSignature;DecisionSignature=$(if($manifest.PSObject.Properties.Name -contains 'DecisionSignature'){[string]$manifest.DecisionSignature}else{''});Sources=@($sources.ToArray());IncludedSolutions=@($solutions.ToArray());Result=[ordered]@{Status=$Result;Category=$Category;Notes=$Notes};Privacy=[ordered]@{ContainsSaveData=$false;ContainsPakContents=$false;StructuredAbsolutePaths=$false;ContainsLogs=$false;UserNotesMayContainPersonalData=(-not[string]::IsNullOrWhiteSpace($Notes))};Remote=[ordered]@{UploadAttempted=$false;UploadAvailable=$false}
  }
  Write-PMMAIIOJsonAtomic (Join-PMMPath 'ValidationEvents' ($eventId+'.json')) $event 45
  $summary=Update-PMMBuildValidationSummary $buildId
  try{if($Result -in @('PASS','PASS_RECONFIRMED')){Set-PMMMergeValidated $Patch|Out-Null}else{Remove-PMMMergeValidationByHash ([string]$Patch.Hash)|Out-Null}}catch{}
  Write-PMMLog ('Build validation recorded locally: '+$Result+' | buildId='+$buildId)
  return [pscustomobject]@{Event=[pscustomobject]$event;Summary=$summary}
}

function Export-PMMBuildValidationFeedback([string]$EventId) {
  if($EventId -notmatch '^[a-f0-9]{32}$'){throw 'Invalid validation event ID.'}
  $source=Join-PMMPath 'ValidationEvents' ($EventId+'.json')
  if(-not(Test-Path -LiteralPath $source -PathType Leaf)){throw 'Validation event was not found.'}
  $event=Get-Content -LiteralPath $source -Raw -Encoding UTF8|ConvertFrom-Json
  if([string]$event.Schema -ne 'PMM_BUILD_VALIDATION_V1'){throw 'Validation event schema is invalid.'}
  $dest=Join-PMMPath 'ValidationFeedback' ('PMM_FEEDBACK_'+$EventId+'.json')
  Copy-Item -LiteralPath $source -Destination $dest -Force
  return [pscustomobject]@{Path=$dest;Sha256=(Get-Sha256 $dest);RemoteUploadAvailable=$false}
}

function New-PMMUserFeedbackFile {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory=$true)][ValidateSet('GENERAL_COMMENT','PMM_ISSUE','MERGE_COMMENT','KNOWLEDGE_CKL_COMMENT')][string]$Kind,
    [string]$Title='',
    [string]$Comments='',
    $Patch=$null
  )
  $Title=([string]$Title).Trim();$Comments=([string]$Comments).Trim()
  if([string]::IsNullOrWhiteSpace($Title) -and [string]::IsNullOrWhiteSpace($Comments)){throw 'Write a title or comment before creating feedback.'}
  if($Title.Length -gt 160){throw 'Feedback title exceeds 160 characters.'}
  if($Comments.Length -gt 20000){throw 'Feedback comments exceed 20,000 characters.'}
  $safeTitle=$Title;$safeComments=$Comments
  try{$safeTitle=Protect-PMMAIIODiagnosticText $Title;$safeComments=Protect-PMMAIIODiagnosticText $Comments}catch{}
  $build=$null
  if($Patch){
    $buildId='';$summary=$null
    try{$buildId=Get-PMMDeterministicBuildId $Patch}catch{}
    try{$summary=Get-PMMBuildValidationSummary $Patch}catch{}
    $build=[ordered]@{
      BuildId=$buildId
      PatchName=[IO.Path]::GetFileName([string]$Patch.Name)
      OutputPakSha256=$(try{([string]$Patch.Hash).ToLowerInvariant()}catch{''})
      BuildManifestSha256=$(try{Get-PMMBuildManifestHash $Patch}catch{''})
      ValidationStatus=$(if($summary){[string]$summary.Status}else{'UNAVAILABLE'})
      LatestValidationEventId=$(if($summary -and $summary.PSObject.Properties.Name -contains 'LatestEventId'){[string]$summary.LatestEventId}else{''})
    }
  }
  $knowledge=$null
  if($Kind -eq 'KNOWLEDGE_CKL_COMMENT'){
    try{$summary=Get-PMMKnowledgeSummary;$knowledge=[ordered]@{BehaviorCases=[int]$summary.BehaviorCases;Fixtures=[int]$summary.Fixtures;RuntimeProven=[int]$summary.RuntimeProven;ProductionRecipes=[int]$summary.ProductionRecipes}}catch{}
  }
  $id=[guid]::NewGuid().ToString('N');$identity=Get-PMMValidationInstallationIdentity;$product=Get-PMMAIIOProductIdentity
  $record=[ordered]@{
    Schema='PMM_USER_FEEDBACK_V1'
    FeedbackId=$id
    Kind=$Kind
    CreatedUtc=[DateTime]::UtcNow.ToString('o')
    Title=$safeTitle
    Comments=$safeComments
    AnonymousInstallationId=[string]$identity.InstallationId
    PMM=$product
    ExactBuild=$build
    KnowledgeSummary=$knowledge
    Privacy=[ordered]@{ContainsPakContents=$false;ContainsSaveData=$false;ContainsLogs=$false;ContainsStructuredAbsolutePaths=$false;UserTextSanitizedForKnownLocalPaths=$true;UserTextMayContainPersonalData=(-not[string]::IsNullOrWhiteSpace($safeTitle+$safeComments))}
    Sharing=[ordered]@{Mode='ManualOnly';InspectableJson=$true;UploadAttempted=$false;UploadAvailable=$false;FutureConnectionBoundary='PMM_FEEDBACK_TRANSPORT_V1'}
  }
  $path=Join-PMMPath 'ValidationFeedback' ('PMM_COMMENT_'+$id+'.json')
  Write-PMMAIIOJsonAtomic $path $record 45
  Write-PMMLog ('Manual feedback file created: '+[IO.Path]::GetFileName($path)+' | kind='+$Kind)
  return [pscustomobject]@{Path=$path;Sha256=(Get-Sha256 $path);FeedbackId=$id;RemoteUploadAvailable=$false}
}

function Get-PMMUserFeedbackFiles {
  $rows=[Collections.Generic.List[object]]::new()
  foreach($file in @(Get-ChildItem -LiteralPath (Get-PMMPath 'ValidationFeedback') -Filter '*.json' -File -ErrorAction SilentlyContinue|Sort-Object LastWriteTimeUtc -Descending)){
    $rows.Add([pscustomobject]@{Name=$file.Name;Path=$file.FullName;Bytes=[int64]$file.Length;UpdatedUtc=$file.LastWriteTimeUtc.ToString('o')})
  }
  return @($rows.ToArray())
}
