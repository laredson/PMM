<#
AIIO v2 response validation and incremental exchange
====================================================

AI responses are treated as untrusted data.  This module validates archive
paths, sizes, schemas, session/bundle identity, capability requests and staged
candidate manifests.  It never invokes returned scripts or deploys a returned
PAK.  Candidate activation remains a separate, explicit PMM action.
#>

function Get-PMMAIIOResponseForbiddenExtensions {
  return @('.exe','.dll','.com','.bat','.cmd','.ps1','.psm1','.psd1','.ps1xml','.js','.jse','.vbs','.vbe','.wsf','.wsh','.hta','.msi','.msp','.mst','.scr','.cpl','.reg','.lnk','.url','.py','.pyw','.rb','.pl','.sh','.bash','.zsh','.fish','.jar','.class')
}

function Read-PMMAIIOZipJsonEntry($Archive,[string]$Name,[int64]$MaximumBytes=1048576) {
  $entry=@($Archive.Entries|Where-Object{([string]$_.FullName).Replace([char]92,[char]47) -ceq $Name}|Select-Object -First 1)
  if($entry.Count -eq 0){return $null}
  if([int64]$entry[0].Length -gt $MaximumBytes){throw ($Name+' exceeds the allowed JSON size.')}
  $reader=[IO.StreamReader]::new($entry[0].Open(),[Text.Encoding]::UTF8,$true)
  try{return ($reader.ReadToEnd()|ConvertFrom-Json -ErrorAction Stop)}finally{$reader.Dispose()}
}

function Get-PMMAIIOResponsePackageHint([string]$ZipPath) {
  # Lightweight routing only. The worker still performs the complete archive,
  # identity, size, path, capability and candidate validation before staging.
  if(-not(Test-Path -LiteralPath $ZipPath -PathType Leaf)){throw 'AI response ZIP was not found.'}
  $item=Get-Item -LiteralPath $ZipPath
  if($item.Extension -ine '.zip'){throw 'AI responses must be ZIP archives.'}
  if([int64]$item.Length -gt 2147483648){throw 'AI response ZIP exceeds 2 GiB.'}
  Add-Type -AssemblyName System.IO.Compression.FileSystem
  $archive=[IO.Compression.ZipFile]::OpenRead($item.FullName)
  try{
    if($archive.Entries.Count -gt 5000){throw 'AI response contains more than 5,000 entries.'}
    $entryNames=@($archive.Entries|ForEach-Object{([string]$_.FullName).Replace([char]92,[char]47)})
    $roots=@($entryNames|Where-Object{$_ -in @('response.json','solution.json')})
    if($roots.Count -ne 1){throw 'AI response ZIP must contain exactly one root response.json or solution.json.'}
    if($roots[0] -ceq 'response.json'){
      $response=Read-PMMAIIOZipJsonEntry $archive 'response.json' 2097152
      if($response -and [string]$response.schema -eq 'PMM_THEME_AI_RESPONSE_V1'){
        if(@($entryNames|Where-Object{$_ -ceq 'theme.json'}).Count -ne 1){throw 'Theme AI response requires exactly one root theme.json.'}
        return [pscustomobject]@{Kind='ThemeResponse';SessionId='';CaseId=''}
      }
      if(-not$response -or [string]$response.schema -notin @('PMM_AI_RESPONSE_V2','PMM_AIIO_RESPONSE_V2')){throw 'Unsupported AI response schema.'}
      $sessionId=[string]$response.sessionId
      if(-not(Test-PMMAIIOSessionId $sessionId)){throw 'AI response contains an invalid session id.'}
      return [pscustomobject]@{Kind='Response';SessionId=$sessionId;CaseId=''}
    }
    $solution=Read-PMMAIIOZipJsonEntry $archive 'solution.json' 2097152
    if(-not$solution -or [string]$solution.schema -ne 'PMM_MANUAL_SOLUTION_V1'){throw 'Unsupported standalone AI solution schema.'}
    return [pscustomobject]@{Kind='ManualSolution';SessionId='';CaseId=[string]$solution.caseId}
  }finally{$archive.Dispose()}
}

function Test-PMMAIIOResponseArchiveEnvelope([string]$ZipPath) {
  if(-not(Test-Path -LiteralPath $ZipPath -PathType Leaf)){throw 'AI response ZIP was not found.'}
  $item=Get-Item -LiteralPath $ZipPath
  if($item.Extension -ine '.zip'){throw 'AI responses must be ZIP archives.'}
  if([int64]$item.Length -gt 2147483648){throw 'AI response ZIP exceeds 2 GiB.'}
  Add-Type -AssemblyName System.IO.Compression.FileSystem
  $archive=[IO.Compression.ZipFile]::OpenRead($item.FullName)
  try{
    $entries=@($archive.Entries)
    if($entries.Count -gt 5000){throw 'AI response contains more than 5,000 entries.'}
    [int64]$expanded=0
    $seenNames=[Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach($entry in $entries){
      $name=([string]$entry.FullName).Replace([char]92,[char]47)
      if(-not(Test-PMMAIIOZipEntryName $name)){throw ('Unsafe AI response path: '+$name)}
      if(-not$seenNames.Add($name)){throw ('Duplicate AI response path: '+$name)}
      $expanded+=[int64]$entry.Length
      if($expanded -gt 5368709120){throw 'AI response expands beyond 5 GiB.'}
      $unixType=(([int64]$entry.ExternalAttributes -shr 16) -band 0xF000)
      if($unixType -eq 0xA000){throw ('Symbolic links are forbidden: '+$name)}
      $ext=[IO.Path]::GetExtension($name).ToLowerInvariant()
      if($ext -in (Get-PMMAIIOResponseForbiddenExtensions)){throw ('Executable content is forbidden in AI responses: '+$name)}
      if($ext -in @('.7z','.rar','.tar','.gz','.bz2','.xz')){throw ('Nested/unsupported archive content is forbidden: '+$name)}
      if($ext -eq '.zip'){throw ('Nested ZIP content is forbidden in AI responses: '+$name)}
      if($ext -eq '.pak' -and -not$name.StartsWith('solutions/',[StringComparison]::OrdinalIgnoreCase)){throw ('PAK payload is allowed only inside a declared solution: '+$name)}
    }
    $responseEntries=@($entries|Where-Object{([string]$_.FullName).Replace([char]92,[char]47) -ceq 'response.json'})
    if($responseEntries.Count -ne 1){throw 'AI response must contain exactly one response.json at the archive root.'}
    $response=Read-PMMAIIOZipJsonEntry $archive 'response.json' 2097152
    if(-not$response){throw 'AI response contains an unreadable response.json.'}
    return [pscustomobject]@{Response=$response;EntryCount=$entries.Count;ExpandedBytes=$expanded;ZipBytes=[int64]$item.Length}
  }finally{$archive.Dispose()}
}

function Test-PMMAIIOCapabilityRequest($Request,[hashtable]$Seen,$Session) {
  if(-not$Request){throw 'AI response contains an empty data request.'}
  $capability=[string]$Request.capability
  if([string]::IsNullOrWhiteSpace($capability)){try{$capability=[string]$Request.type}catch{}}
  $registry=Get-PMMAIIOCapabilityRegistry
  $definition=@($registry.Capabilities|Where-Object{[string]$_.Id -ceq $capability}|Select-Object -First 1)
  if($definition.Count -eq 0 -or -not[bool]$definition[0].Enabled){throw ('AI requested an unknown or disabled capability: '+$capability)}
  if(-not[bool]$definition[0].Requestable){throw ('Capability '+$capability+' is documented but is not requestable through this build''s manual ZIP transport.')}
  if([string]$definition[0].Level -eq 'C'){throw ('AI cannot execute confirmation-level capability '+$capability+'. It may describe why the user should perform it, but PMM will not queue it as data work.')}
  $logicalPath='';try{$logicalPath=[string]$Request.logicalPath}catch{}
  if($logicalPath){
    $normalized=$logicalPath.Replace([char]92,[char]47)
    if(-not(Test-PMMAIIOZipEntryName $normalized) -or $normalized.StartsWith('file:',[StringComparison]::OrdinalIgnoreCase)){throw ('Unsafe requested logical path: '+$logicalPath)}
  }
  $providerName='';try{$providerName=[string]$Request.providerName}catch{}
  if($capability -eq 'extract_provider_asset'){
    if([string]::IsNullOrWhiteSpace($providerName)){throw 'extract_provider_asset requires providerName from the exact current Unsupported case.'}
    if($providerName.Length -gt 260 -or $providerName.IndexOfAny([char[]]@([char]0,[char]10,[char]13,[char]47,[char]92)) -ge 0){throw 'extract_provider_asset contains an unsafe providerName.'}
  }elseif($providerName){throw ('providerName is not valid for capability '+$capability+'.')}
  $query='';try{$query=[string]$Request.query}catch{}
  if([string]::IsNullOrWhiteSpace($query) -and $capability -eq 'query_game_reference'){$query=$logicalPath}
  if($query){
    $query=$query.Trim()
    if($query.Length -gt 256 -or $query.IndexOfAny([char[]]@([char]0,[char]10,[char]13)) -ge 0){throw ('Unsafe or oversized query for '+$capability+'.')}
  }
  [int]$maximumResults=100;try{if($Request.maximumResults){$maximumResults=[int]$Request.maximumResults}}catch{$maximumResults=100}
  if($maximumResults -lt 1 -or $maximumResults -gt 200){throw 'maximumResults must be between 1 and 200.'}
  [int]$maximumFamilies=12;try{if($Request.maximumFamilies){$maximumFamilies=[int]$Request.maximumFamilies}}catch{$maximumFamilies=12}
  if($maximumFamilies -lt 1 -or $maximumFamilies -gt 32){throw 'maximumFamilies must be between 1 and 32.'}
  if($capability -eq 'query_game_reference' -and [string]::IsNullOrWhiteSpace($query)){throw 'query_game_reference requires a focused query string.'}
  if($capability -in @('extract_game_reference_asset','extract_reference_neighborhood')){
    if(-not$Session -or [string]$Session.TaskType -ne 'CREATE_MOD'){throw ($capability+' is available only inside a CREATE_MOD AIIO project.')}
    if([string]::IsNullOrWhiteSpace($logicalPath) -or [IO.Path]::GetExtension($logicalPath) -ine '.uasset'){throw ($capability+' requires one exact Game Reference .uasset logicalPath.')}
  }
  [int64]$maximum=0
  try{$maximum=[int64]$Request.maximumExpectedBytes}catch{$maximum=0}
  if($maximum -lt 0 -or $maximum -gt 536870912){throw ('Requested data budget is invalid for '+$capability+'.')}
  $canonical=($Request|ConvertTo-Json -Depth 12 -Compress)
  $id=Get-PMMStableTextId ('AIIO_REQUEST|'+$canonical)
  if($Seen.ContainsKey($id)){throw ('Duplicate AI data request: '+$id)}
  $Seen[$id]=$true
  return [pscustomobject]@{RequestId=$id;Capability=$capability;LogicalPath=$logicalPath;ProviderName=$providerName;Query=$query;MaximumResults=$maximumResults;MaximumFamilies=$maximumFamilies;Reason=[string]$Request.reason;Required=$(try{[bool]$Request.required}catch{$true});MaximumExpectedBytes=$maximum;Original=$Request;Status='Pending'}
}

function Get-PMMAIIOCandidateManifestFromArchive($Archive,[string]$CandidatePath) {
  $prefix=$CandidatePath.Replace([char]92,[char]47).Trim([char]47)
  if([string]::IsNullOrWhiteSpace($prefix) -or -not$prefix.StartsWith('solutions/',[StringComparison]::OrdinalIgnoreCase) -or -not(Test-PMMAIIOZipEntryName $prefix)){throw 'Candidate paths must be safe and below solutions/.'}
  $matches=[Collections.Generic.List[object]]::new()
  foreach($name in @('solution.json','candidate.json','full-pak-solution.json','development-patch.json','mod-creation.json')){
    $path=$prefix+'/'+$name
    $doc=Read-PMMAIIOZipJsonEntry $Archive $path 2097152
    if($doc){$matches.Add([pscustomobject]@{Path=$path;Root=$prefix;Document=$doc})}
  }
  if($matches.Count -eq 0){throw ('Candidate '+$prefix+' has no supported manifest.')}
  if($matches.Count -ne 1){throw ('Candidate '+$prefix+' must contain exactly one supported manifest.')}
  return $matches[0]
}

function Test-PMMAIIOCandidateManifest($Candidate,$Manifest,[string]$SessionId,[array]$AllowedCaseIds,$Session) {
  $schema=[string]$Manifest.schema
  if($schema -notin @('PMM_MANUAL_SOLUTION_V1','PMM_AIIO_CANDIDATE_V2','PMM_FULL_PAK_SOLUTION_V1','PMM_DEVELOPMENT_PATCH_V1','PMM_THEME_AI_RESPONSE_V1','PMM_MOD_CREATION_CANDIDATE_V1')){throw ('Unsupported AI candidate schema: '+$schema)}
  $caseIds=[Collections.Generic.List[string]]::new()
  try{foreach($id in @($Manifest.caseIds)){if($id){$caseIds.Add([string]$id)}}}catch{}
  try{if($Manifest.caseId){$caseIds.Add([string]$Manifest.caseId)}}catch{}
  foreach($id in @($caseIds.ToArray()|Sort-Object -Unique)){
    if($AllowedCaseIds.Count -gt 0 -and -not($AllowedCaseIds -contains $id)){throw ('Candidate references a case outside this session: '+$id)}
  }
  if($schema -eq 'PMM_MANUAL_SOLUTION_V1'){
    $uniqueCases=@($caseIds.ToArray()|Where-Object{$_}|Sort-Object -Unique)
    if($uniqueCases.Count -ne 1){throw 'Manual cooked-family candidates must reference exactly one caseId.'}
    if([string]$Manifest.mode -ne 'replacement-cooked-family'){throw 'Manual cooked-family candidate mode must be replacement-cooked-family.'}
    if([string]::IsNullOrWhiteSpace([string]$Manifest.asset)){throw 'Manual cooked-family candidate is missing its exact logical asset.'}
  }
  if($schema -eq 'PMM_FULL_PAK_SOLUTION_V1'){
    if([string]$Manifest.usagePolicy -ne 'PERSONAL_COMPATIBILITY_USE_ONLY'){throw 'Full PAK solutions must declare usagePolicy PERSONAL_COMPATIBILITY_USE_ONLY.'}
    if([string]$Manifest.pakSha256 -notmatch '^[0-9a-fA-F]{64}$'){throw 'Full PAK solution is missing a valid pakSha256.'}
  }
  if($schema -eq 'PMM_DEVELOPMENT_PATCH_V1'){
    if([string]::IsNullOrWhiteSpace([string]$Manifest.baseVersion)){throw 'Development patch is missing baseVersion.'}
    if(-not$Manifest.baseFileHashes){throw 'Development patch is missing exact baseFileHashes.'}
  }
  $modCreation=$null
  if($schema -eq 'PMM_MOD_CREATION_CANDIDATE_V1'){$modCreation=Test-PMMAIIOModCreationManifest $Manifest $Session}
  $declaredId='';try{$declaredId=[string]$Candidate.solutionId}catch{}
  if(-not$declaredId){try{$declaredId=[string]$Manifest.solutionId}catch{}}
  return [pscustomobject]@{Schema=$schema;DeclaredSolutionId=$declaredId;CaseIds=@($caseIds.ToArray()|Sort-Object -Unique);SessionId=$SessionId;ModCreation=$modCreation}
}

function Copy-PMMAIIOArchivePrefix($Archive,[string]$Prefix,[string]$Destination) {
  $normalized=$Prefix.Replace([char]92,[char]47).Trim([char]47)+'/'
  New-Item -ItemType Directory -Force -Path $Destination|Out-Null
  foreach($entry in @($Archive.Entries)){
    $name=([string]$entry.FullName).Replace([char]92,[char]47)
    if(-not$name.StartsWith($normalized,[StringComparison]::Ordinal)){continue}
    $relative=$name.Substring($normalized.Length)
    if([string]::IsNullOrWhiteSpace($relative)){continue}
    if(-not(Test-PMMAIIOZipEntryName $relative)){throw ('Unsafe candidate relative path: '+$relative)}
    $target=Join-Path $Destination $relative.Replace([char]47,[IO.Path]::DirectorySeparatorChar)
    if([string]::IsNullOrWhiteSpace([string]$entry.Name)){New-Item -ItemType Directory -Force -Path $target|Out-Null;continue}
    $parent=Split-Path -Parent $target;if($parent){New-Item -ItemType Directory -Force -Path $parent|Out-Null}
    $source=$entry.Open();$dest=$null
    try{$dest=[IO.File]::Open($target,[IO.FileMode]::Create,[IO.FileAccess]::Write,[IO.FileShare]::None);$source.CopyTo($dest)}
    finally{if($dest){$dest.Dispose()};$source.Dispose()}
  }
}

function Test-PMMAIIOStagedCandidate([string]$Root,$Info) {
  $files=@(Get-ChildItem -LiteralPath $Root -Recurse -File -ErrorAction Stop)
  if($files.Count -eq 0){throw 'Candidate contains no files.'}
  $allPaks=@($files|Where-Object{$_.Extension -ieq '.pak'})
  if($allPaks.Count -gt 0 -and [string]$Info.Schema -ne 'PMM_FULL_PAK_SOLUTION_V1'){
    throw 'PAK payloads require PMM_FULL_PAK_SOLUTION_V1 with an exact hash and personal-use policy.'
  }
  if([string]$Info.Schema -eq 'PMM_FULL_PAK_SOLUTION_V1'){
    $paks=$allPaks
    if($paks.Count -ne 1){throw 'A full PAK solution must contain exactly one PAK.'}
    $manifestPath=Join-Path $Root 'full-pak-solution.json';$manifest=Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8|ConvertFrom-Json
    if((Get-Sha256 $paks[0].FullName) -ne ([string]$manifest.pakSha256).ToLowerInvariant()){throw 'Full PAK solution hash does not match its manifest.'}
    if($manifest.PSObject.Properties.Name -contains 'pakBytes' -and [int64]$manifest.pakBytes -ne [int64]$paks[0].Length){throw 'Full PAK solution size does not match its manifest.'}
  }
  if([string]$Info.Schema -eq 'PMM_MANUAL_SOLUTION_V1'){
    $manifest=Get-Content -LiteralPath (Join-Path $Root 'solution.json') -Raw -Encoding UTF8|ConvertFrom-Json
    if([string]$manifest.mode -ne 'replacement-cooked-family'){throw 'Manual solution mode must be replacement-cooked-family.'}
    $cooked=Join-Path $Root 'cooked'
    if(-not(Test-Path -LiteralPath $cooked -PathType Container)){throw 'Manual solution is missing cooked/.'}
    foreach($file in $files){
      $relative=$file.FullName.Substring($Root.Length).TrimStart([char]92,[char]47).Replace([char]92,[char]47)
      if($relative -cne 'solution.json' -and $relative -cnotmatch '^cooked/[^/]+\.(uasset|uexp|ubulk)$'){throw ('Unexpected file in manual cooked-family candidate: '+$relative)}
    }
    $headers=@(Get-ChildItem -LiteralPath $cooked -Filter '*.uasset' -File -ErrorAction SilentlyContinue)
    if($headers.Count -ne 1){throw 'Manual solution must contain exactly one .uasset family header.'}
    $family=[IO.Path]::GetFileNameWithoutExtension($headers[0].Name)
    foreach($member in @(Get-ChildItem -LiteralPath $cooked -File -ErrorAction SilentlyContinue)){
      if([IO.Path]::GetFileNameWithoutExtension($member.Name) -cne $family){throw 'Manual solution cooked files must belong to one exact cooked family.'}
    }
  }
  if([string]$Info.Schema -eq 'PMM_MOD_CREATION_CANDIDATE_V1'){
    $manifest=Get-Content -LiteralPath (Join-Path $Root 'mod-creation.json') -Raw -Encoding UTF8|ConvertFrom-Json -ErrorAction Stop
    [void](Test-PMMAIIOModCreationCandidateTree $Root $manifest)
  }
  $hashRows=[Collections.Generic.List[object]]::new()
  foreach($file in $files|Sort-Object FullName){$hashRows.Add([pscustomobject]@{RelativePath=$file.FullName.Substring($Root.Length).TrimStart([char]92,[char]47).Replace([char]92,[char]47);Bytes=[int64]$file.Length;Sha256=(Get-Sha256 $file.FullName)})}
  $solutionId=Get-PMMStableTextId ('AIIO_CANDIDATE_V2|'+(($hashRows|ConvertTo-Json -Depth 6 -Compress)))
  return [pscustomobject]@{SolutionId=$solutionId;Files=@($hashRows.ToArray());Bytes=[int64](($files|Measure-Object -Property Length -Sum).Sum)}
}

function Import-PMMAIIOResponseZip {
  [CmdletBinding()]
  param([Parameter(Mandatory=$true)][string]$ZipPath,[string]$ExpectedSessionId='')
  $envelope=Test-PMMAIIOResponseArchiveEnvelope $ZipPath
  $response=$envelope.Response
  $schema=[string]$response.schema
  if($schema -notin @('PMM_AI_RESPONSE_V2','PMM_AIIO_RESPONSE_V2')){throw ('Unsupported AI response schema: '+$schema)}
  $responseType=[string]$response.responseType
  if($responseType -notin @('needs-data','candidate-ready','mixed','not-solvable','insufficient-evidence','PMM_BUG','complete')){throw ('Unsupported AI response type: '+$responseType)}
  $sessionId=[string]$response.sessionId
  if($ExpectedSessionId -and $sessionId -ne $ExpectedSessionId){throw 'AI response belongs to another session.'}
  $session=Get-PMMAIIOSession $sessionId
  if(-not$session){throw ('AI response session was not found: '+$sessionId)}
  $sessionBefore=($session|ConvertTo-Json -Depth 60|ConvertFrom-Json)
  if([string]$response.bundleId -ne [string]$session.LastBundleId){throw 'AI response bundle ID is stale or does not match the last handoff.'}
  if([int]$response.iteration -ne [int]$session.Iteration){throw 'AI response iteration does not match the current session.'}
  $responseIndex=[int]$session.Iteration
  $responseDir=Join-Path (Get-PMMAIIOSessionPath $sessionId) ('responses\response-{0:D4}' -f $responseIndex)
  if(Test-Path -LiteralPath $responseDir){throw 'This AI response iteration was already imported.'}
  $stage=Join-Path (Get-PMMPath 'Temp') ('AIIOResponse_'+[guid]::NewGuid().ToString('N'))
  $journal='';$responseCreated=$false
  $committedNew=[Collections.Generic.List[string]]::new()
  try{
    if(Get-Command Start-PMMJournalOperation -ErrorAction SilentlyContinue){$journal=Start-PMMJournalOperation -Kind AIIOImportResponse -Target $sessionId -Metadata ([ordered]@{BundleId=[string]$response.bundleId;Iteration=[int]$response.iteration})}
    New-Item -ItemType Directory -Force -Path $stage|Out-Null
    Set-PMMTransientStageOwner $stage 'AIIOImportResponse'
    $seen=@{};$requests=[Collections.Generic.List[object]]::new()
    foreach($request in @($response.requests)){$requests.Add((Test-PMMAIIOCapabilityRequest $request $seen $session))}
    $allowedCaseIds=@($session.CaseIds|ForEach-Object{[string]$_})
    $candidateRows=[Collections.Generic.List[object]]::new();$pending=[Collections.Generic.List[object]]::new()
    $candidateIds=[Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    $declaredCandidateRoots=[Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $archive=[IO.Compression.ZipFile]::OpenRead((Get-Item -LiteralPath $ZipPath).FullName)
    try{
      foreach($candidate in @($response.candidates)){
        $candidatePath=[string]$candidate.path
        if([string]::IsNullOrWhiteSpace($candidatePath)){try{$candidatePath=[string]$candidate.candidatePath}catch{}}
        $manifestInfo=Get-PMMAIIOCandidateManifestFromArchive $archive $candidatePath
        if(-not$declaredCandidateRoots.Add(([string]$manifestInfo.Root).TrimEnd([char]47))){throw ('AI response declares the same candidate path more than once: '+[string]$manifestInfo.Root)}
        $info=Test-PMMAIIOCandidateManifest $candidate $manifestInfo.Document $sessionId $allowedCaseIds $session
        $candidateStage=Join-Path $stage ('candidate_'+[guid]::NewGuid().ToString('N'))
        Copy-PMMAIIOArchivePrefix $archive ([string]$manifestInfo.Root) $candidateStage
        $proof=Test-PMMAIIOStagedCandidate $candidateStage $info
        if([string]$info.DeclaredSolutionId -and [string]$info.DeclaredSolutionId -ne [string]$proof.SolutionId){throw ('Candidate declared solutionId does not match staged bytes: '+[string]$info.DeclaredSolutionId)}
        if(-not$candidateIds.Add([string]$proof.SolutionId)){throw ('AI response declares the same candidate bytes more than once: '+[string]$proof.SolutionId)}
        $dest=Join-Path (Get-PMMAIIOSessionPath $sessionId) ('candidates\'+[string]$proof.SolutionId)
        $candidateAlreadyExists=Test-Path -LiteralPath $dest -PathType Container
        $usagePolicy=if([string]$info.Schema -eq 'PMM_FULL_PAK_SOLUTION_V1'){'PERSONAL_COMPATIBILITY_USE_ONLY'}elseif([string]$info.Schema -eq 'PMM_MOD_CREATION_CANDIDATE_V1'){'STANDALONE_MOD_CREATION_UNPROVEN'}else{'PMM_STAGED_CANDIDATE'}
        $candidateRecord=[ordered]@{Schema='PMM_AIIO_CANDIDATE_RECORD_V1';SolutionId=[string]$proof.SolutionId;InputSchema=[string]$info.Schema;CaseIds=@($info.CaseIds);Status='StructurallyAccepted';RuntimeStatus='RuntimeUnproven';Origin='AIIO_EXTERNAL';RelativePath=('candidates/'+[string]$proof.SolutionId);Bytes=[int64]$proof.Bytes;Files=@($proof.Files);ImportedUtc=[DateTime]::UtcNow.ToString('o');UsagePolicy=$usagePolicy}
        $pending.Add([pscustomobject]@{Stage=$candidateStage;Destination=$dest;AlreadyExists=$candidateAlreadyExists;Record=[pscustomobject]$candidateRecord;SolutionId=[string]$proof.SolutionId})
      }
      # response.json plus the exact declared candidate roots are the complete
      # archive contract.  Reject orphan payloads (including undeclared PAKs)
      # instead of retaining them inside the copied response ZIP.
      foreach($entry in @($archive.Entries)){
        if([string]::IsNullOrWhiteSpace([string]$entry.Name)){continue}
        $name=([string]$entry.FullName).Replace([char]92,[char]47)
        if($name -ceq 'response.json'){continue}
        $owned=$false
        foreach($candidateRoot in @($declaredCandidateRoots)){
          if($name.StartsWith(([string]$candidateRoot+'/'),[StringComparison]::OrdinalIgnoreCase)){$owned=$true;break}
        }
        if(-not$owned){throw ('AI response contains an undeclared payload: '+$name)}
      }
    }finally{$archive.Dispose()}

    # Nothing is committed until every request and candidate in the response
    # has passed validation. New candidate directories are tracked so a later
    # write failure can roll the import back without touching older candidates.
    foreach($item in $pending){
      $candidateRecord=$item.Record;$recordPath=Join-Path ([string]$item.Destination) 'candidate-record.json'
      if([bool]$item.AlreadyExists){
        if(-not(Test-Path -LiteralPath $recordPath -PathType Leaf)){throw 'Existing AIIO candidate directory has no identity record.'}
        $preserved=Get-Content -LiteralPath $recordPath -Raw -Encoding UTF8|ConvertFrom-Json
        if([string]$preserved.Schema -ne 'PMM_AIIO_CANDIDATE_RECORD_V1' -or [string]$preserved.SolutionId -ne [string]$item.SolutionId){throw 'Existing AIIO candidate directory contains an invalid identity record.'}
        $candidateRecord=$preserved
        Remove-Item -LiteralPath ([string]$item.Stage) -Recurse -Force
      }else{
        Move-Item -LiteralPath ([string]$item.Stage) -Destination ([string]$item.Destination)
        $committedNew.Add([string]$item.Destination)
        Write-PMMAIIOJsonAtomic $recordPath $candidateRecord 30
      }
      $candidateRows.Add([pscustomobject]$candidateRecord)
    }
    New-Item -ItemType Directory -Force -Path $responseDir|Out-Null
    $responseCreated=$true
    Copy-Item -LiteralPath $ZipPath -Destination (Join-Path $responseDir 'response.zip') -Force
    Write-PMMAIIOJsonAtomic (Join-Path $responseDir 'response.json') $response 40
    Write-PMMAIIOJsonAtomic (Join-Path $responseDir 'validated-requests.json') ([ordered]@{Schema='PMM_AIIO_REQUEST_SET_V1';Requests=@($requests.ToArray())}) 25
    Write-PMMAIIOJsonAtomic (Join-Path $responseDir 'validated-candidates.json') ([ordered]@{Schema='PMM_AIIO_CANDIDATE_SET_V1';Candidates=@($candidateRows.ToArray())}) 35
    if($candidateRows.Count -gt 0){$session.Status='CandidateReady';$session.AttentionRequired=$true;$session.OperationState='CandidateReady';$session.LastPresentedCandidate=[string]$candidateRows[0].SolutionId}
    elseif($requests.Count -gt 0){$session.Status='NeedsData';$session.AttentionRequired=$true;$session.OperationState='NeedsData'}
    elseif($responseType -in @('not-solvable','insufficient-evidence')){$session.Status='NeedsUserDecision';$session.AttentionRequired=$true;$session.OperationState=$responseType}
    elseif($responseType -eq 'PMM_BUG'){$session.Status='PMMBugReported';$session.AttentionRequired=$true;$session.OperationState='PMMBugReported'}
    else{$session.Status='ResponseImported';$session.AttentionRequired=$false;$session.OperationState='ResponseImported'}
    Save-PMMAIIOSession $session|Out-Null
    try{Add-PMMAIIOHistoryEvent -SessionId $sessionId -Event RESPONSE_IMPORTED -Message ([string]$response.summary) -Data ([ordered]@{ResponseType=$responseType;Requests=$requests.Count;Candidates=$candidateRows.Count;ZipSha256=(Get-Sha256 $ZipPath)})|Out-Null}catch{Write-PMMLog ('AIIO response was committed but its optional history event could not be written: '+$_.Exception.Message)}
    if($journal){try{Complete-PMMJournalOperation -OperationId $journal -Kind AIIOImportResponse -Metadata ([ordered]@{Requests=$requests.Count;Candidates=$candidateRows.Count})}catch{Write-PMMLog ('AIIO response was committed but its operation journal could not be completed: '+$_.Exception.Message)}}
    return [pscustomobject]@{SessionId=$sessionId;Status=[string]$session.Status;RequestCount=$requests.Count;CandidateCount=$candidateRows.Count;Requests=@($requests.ToArray());Candidates=@($candidateRows.ToArray());ResponseDirectory=$responseDir}
  }catch{
    if($journal){try{Fail-PMMJournalOperation -OperationId $journal -Kind AIIOImportResponse -Message $_.Exception.Message}catch{}}
    if($responseCreated){Remove-Item -LiteralPath $responseDir -Recurse -Force -ErrorAction SilentlyContinue}
    foreach($path in @($committedNew.ToArray())){Remove-Item -LiteralPath $path -Recurse -Force -ErrorAction SilentlyContinue}
    try{Save-PMMAIIOSession $sessionBefore|Out-Null}catch{}
    throw
  }finally{Remove-Item -LiteralPath $stage -Recurse -Force -ErrorAction SilentlyContinue;Remove-PMMTransientStageOwner $stage}
}

function Test-PMMAIIOManualSolutionArchiveEnvelope([string]$ZipPath) {
  if(-not(Test-Path -LiteralPath $ZipPath -PathType Leaf)){throw 'Manual AI solution ZIP was not found.'}
  $item=Get-Item -LiteralPath $ZipPath
  if($item.Extension -ine '.zip'){throw 'Manual AI solutions must be ZIP archives.'}
  if([int64]$item.Length -gt 2147483648){throw 'Manual AI solution ZIP exceeds 2 GiB.'}
  Add-Type -AssemblyName System.IO.Compression.FileSystem
  $archive=[IO.Compression.ZipFile]::OpenRead($item.FullName)
  try{
    $entries=@($archive.Entries)
    if($entries.Count -gt 5000){throw 'Manual AI solution contains more than 5,000 entries.'}
    [int64]$expanded=0
    $seenNames=[Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach($entry in $entries){
      $name=([string]$entry.FullName).Replace([char]92,[char]47)
      if(-not(Test-PMMAIIOZipEntryName $name)){throw ('Unsafe manual AI solution path: '+$name)}
      if(-not$seenNames.Add($name)){throw ('Duplicate manual AI solution path: '+$name)}
      $expanded+=[int64]$entry.Length
      if($expanded -gt 5368709120){throw 'Manual AI solution expands beyond 5 GiB.'}
      $unixType=(([int64]$entry.ExternalAttributes -shr 16) -band 0xF000)
      if($unixType -eq 0xA000){throw ('Symbolic links are forbidden: '+$name)}
      if([string]::IsNullOrWhiteSpace([string]$entry.Name)){continue}
      $allowed=($name -ceq 'solution.json' -or $name -cmatch '^cooked/[^/]+\.(uasset|uexp|ubulk)$')
      if(-not$allowed){throw ('Unexpected file in manual AI solution: '+$name)}
    }
    $solutionEntries=@($entries|Where-Object{([string]$_.FullName).Replace([char]92,[char]47) -ceq 'solution.json'})
    if($solutionEntries.Count -ne 1){throw 'Manual AI solution must contain exactly one solution.json at the archive root.'}
    $solution=Read-PMMAIIOZipJsonEntry $archive 'solution.json' 2097152
    if(-not$solution -or [string]$solution.schema -ne 'PMM_MANUAL_SOLUTION_V1'){throw 'The ZIP is neither a PMM AIIO v2 response nor a PMM_MANUAL_SOLUTION_V1 package.'}
    if([string]$solution.mode -ne 'replacement-cooked-family'){throw 'Manual AI solution mode must be replacement-cooked-family.'}
    if([string]::IsNullOrWhiteSpace([string]$solution.caseId)){throw 'Manual AI solution is missing caseId.'}
    return [pscustomobject]@{Solution=$solution;EntryCount=$entries.Count;ExpandedBytes=$expanded;ZipBytes=[int64]$item.Length}
  }finally{$archive.Dispose()}
}

function Import-PMMAIIOManualSolutionCandidate {
  [CmdletBinding()]
  param([Parameter(Mandatory=$true)][string]$ZipPath,[Parameter(Mandatory=$true)][string]$SessionId)
  $session=Get-PMMAIIOSession $SessionId
  if(-not$session){throw ('AIIO session not found: '+$SessionId)}
  $sessionBefore=($session|ConvertTo-Json -Depth 60|ConvertFrom-Json)
  $envelope=Test-PMMAIIOManualSolutionArchiveEnvelope $ZipPath
  $caseId=[string]$envelope.Solution.caseId
  $allowedCaseIds=@($session.CaseIds|ForEach-Object{[string]$_}|Where-Object{$_})
  if($allowedCaseIds.Count -gt 0 -and -not($allowedCaseIds -contains $caseId)){throw ('Manual AI solution belongs to a case outside this session: '+$caseId)}
  $review=Get-PMMAIIOCurrentReviewFolderForCaseId $caseId
  if(-not$review){throw 'Manual AI solution does not match an exact current Unsupported review case. Run Analyze again.'}
  $stage=Join-Path (Get-PMMPath 'Temp') ('AIIOLegacyCandidate_'+[guid]::NewGuid().ToString('N'))
  $journal='';$createdCandidate=''
  try{
    if(Get-Command Start-PMMJournalOperation -ErrorAction SilentlyContinue){$journal=Start-PMMJournalOperation -Kind AIIOImportResponse -Target $SessionId -Metadata ([ordered]@{Schema='PMM_MANUAL_SOLUTION_V1';CaseId=$caseId})}
    Expand-PMMSafeSolutionZip $ZipPath $stage
    $info=Test-PMMAIIOCandidateManifest ([pscustomobject]@{}) $envelope.Solution $SessionId @($caseId)
    $proof=Test-PMMAIIOStagedCandidate $stage $info
    $dest=Join-Path (Get-PMMAIIOSessionPath $SessionId) ('candidates\'+[string]$proof.SolutionId)
    $candidateAlreadyExists=Test-Path -LiteralPath $dest -PathType Container
    if($candidateAlreadyExists){Remove-Item -LiteralPath $stage -Recurse -Force}
    else{Move-Item -LiteralPath $stage -Destination $dest;$createdCandidate=$dest}
    $record=[ordered]@{Schema='PMM_AIIO_CANDIDATE_RECORD_V1';SolutionId=[string]$proof.SolutionId;InputSchema='PMM_MANUAL_SOLUTION_V1';CaseIds=@($caseId);Status='StructurallyAccepted';RuntimeStatus='RuntimeUnproven';Origin='AIIO_V1_IMPORT';RelativePath=('candidates/'+[string]$proof.SolutionId);Bytes=[int64]$proof.Bytes;Files=@($proof.Files);ImportedUtc=[DateTime]::UtcNow.ToString('o');UsagePolicy='PMM_STAGED_CANDIDATE'}
    $recordPath=Join-Path $dest 'candidate-record.json'
    if($candidateAlreadyExists -and (Test-Path -LiteralPath $recordPath -PathType Leaf)){
      $preserved=Get-Content -LiteralPath $recordPath -Raw -Encoding UTF8|ConvertFrom-Json
      if([string]$preserved.Schema -ne 'PMM_AIIO_CANDIDATE_RECORD_V1' -or [string]$preserved.SolutionId -ne [string]$proof.SolutionId){throw 'Existing AIIO candidate directory contains an invalid identity record.'}
      $record=$preserved
    }else{Write-PMMAIIOJsonAtomic $recordPath $record 30}
    $session.Status='CandidateReady';$session.AttentionRequired=$true;$session.OperationState='CandidateReady';$session.LastPresentedCandidate=[string]$proof.SolutionId
    Save-PMMAIIOSession $session|Out-Null
    try{Add-PMMAIIOHistoryEvent -SessionId $SessionId -Event V1_CANDIDATE_IMPORTED -Message $caseId -Data ([ordered]@{SolutionId=[string]$proof.SolutionId;ZipSha256=(Get-Sha256 $ZipPath)})|Out-Null}catch{Write-PMMLog ('AIIO manual candidate was committed but its optional history event could not be written: '+$_.Exception.Message)}
    if($journal){try{Complete-PMMJournalOperation -OperationId $journal -Kind AIIOImportResponse -Metadata ([ordered]@{Candidates=1;Schema='PMM_MANUAL_SOLUTION_V1'})}catch{Write-PMMLog ('AIIO manual candidate was committed but its operation journal could not be completed: '+$_.Exception.Message)}}
    return [pscustomobject]@{SessionId=$SessionId;Status='CandidateReady';RequestCount=0;CandidateCount=1;Candidates=@([pscustomobject]$record)}
  }catch{
    if($journal){try{Fail-PMMJournalOperation -OperationId $journal -Kind AIIOImportResponse -Message $_.Exception.Message}catch{}}
    if($createdCandidate){Remove-Item -LiteralPath $createdCandidate -Recurse -Force -ErrorAction SilentlyContinue}
    try{Save-PMMAIIOSession $sessionBefore|Out-Null}catch{}
    throw
  }finally{
    Remove-Item -LiteralPath $stage -Recurse -Force -ErrorAction SilentlyContinue
    try{Remove-PMMTransientStageOwner $stage}catch{}
  }
}

function Import-PMMAIIOAnyResponseZip {
  [CmdletBinding()]
  param([Parameter(Mandatory=$true)][string]$ZipPath,[Parameter(Mandatory=$true)][string]$ExpectedSessionId)
  if(-not(Test-Path -LiteralPath $ZipPath -PathType Leaf)){throw 'AI response ZIP was not found.'}
  Add-Type -AssemblyName System.IO.Compression.FileSystem
  $archive=[IO.Compression.ZipFile]::OpenRead((Get-Item -LiteralPath $ZipPath).FullName)
  try{
    $roots=@($archive.Entries|ForEach-Object{([string]$_.FullName).Replace([char]92,[char]47)}|Where-Object{$_ -in @('response.json','solution.json')})
  }finally{$archive.Dispose()}
  if($roots.Count -ne 1){throw 'AI response ZIP must contain exactly one root response.json or solution.json.'}
  if($roots[0] -ceq 'solution.json'){return (Import-PMMAIIOManualSolutionCandidate -ZipPath $ZipPath -SessionId $ExpectedSessionId)}
  return (Import-PMMAIIOResponseZip -ZipPath $ZipPath -ExpectedSessionId $ExpectedSessionId)
}

function Get-PMMAIIOCandidateRecords([string]$SessionId) {
  if(-not(Test-PMMAIIOSessionId $SessionId)){return @()}
  $root=Join-Path (Get-PMMAIIOSessionPath $SessionId) 'candidates'
  if(-not(Test-Path -LiteralPath $root -PathType Container)){return @()}
  $rows=[Collections.Generic.List[object]]::new()
  foreach($dir in @(Get-ChildItem -LiteralPath $root -Directory -ErrorAction SilentlyContinue|Sort-Object LastWriteTimeUtc -Descending)){
    $recordPath=Join-Path $dir.FullName 'candidate-record.json'
    if(-not(Test-Path -LiteralPath $recordPath -PathType Leaf)){continue}
    try{
      $record=Get-Content -LiteralPath $recordPath -Raw -Encoding UTF8|ConvertFrom-Json
      if([string]$record.Schema -ne 'PMM_AIIO_CANDIDATE_RECORD_V1' -or [string]$record.SolutionId -ne $dir.Name){continue}
      $canUse=([string]$record.InputSchema -eq 'PMM_MANUAL_SOLUTION_V1' -and [string]$record.Status -ne 'AcceptedExperimental' -and @($record.CaseIds|Where-Object{$_}).Count -eq 1)
      $canBuildStandalone=([string]$record.InputSchema -eq 'PMM_MOD_CREATION_CANDIDATE_V1' -and [string]$record.Status -ne 'ModBuiltUnproven')
      $display=('{0} | {1} | {2}' -f [string]$record.InputSchema,[string]$record.Status,([string]$record.SolutionId).Substring(0,[Math]::Min(12,([string]$record.SolutionId).Length)))
      $record|Add-Member -NotePropertyName Root -NotePropertyValue $dir.FullName -Force
      $record|Add-Member -NotePropertyName RecordPath -NotePropertyValue $recordPath -Force
      $record|Add-Member -NotePropertyName CanUseInMerge -NotePropertyValue $canUse -Force
      $record|Add-Member -NotePropertyName CanBuildStandalone -NotePropertyValue $canBuildStandalone -Force
      $record|Add-Member -NotePropertyName Display -NotePropertyValue $display -Force
      $rows.Add($record)
    }catch{Write-PMMLog ('Ignored invalid AIIO candidate record '+$recordPath+': '+$_.Exception.Message)}
  }
  return @($rows.ToArray())
}

function Get-PMMAIIOCurrentReviewFolderForCaseId([string]$CaseId) {
  if([string]::IsNullOrWhiteSpace($CaseId)){return ''}
  $plan=Read-PMMMergePlan
  if(-not$plan){return ''}
  foreach($asset in @($plan.Assets|Where-Object{[string]$_.Mode -eq 'Unsupported'})){
    $review='';try{$review=[string]$asset.ReviewFolder}catch{}
    if(-not$review -or -not(Test-Path -LiteralPath (Join-Path $review 'case.json') -PathType Leaf)){continue}
    try{$case=Read-PMMReviewCase $review;if($case -and [string]$case.CaseId -eq $CaseId){[void](Test-PMMReviewCaseIntegrity $review $case);return $review}}catch{}
  }
  return ''
}

function New-PMMAIIOCandidateActivationZip([string]$CandidateRoot,[string]$SolutionId) {
  $stage=Join-Path (Get-PMMPath 'Temp') ('AIIOActivate_'+[guid]::NewGuid().ToString('N'))
  $zip=Join-Path (Get-PMMPath 'Temp') ('AIIOCandidate_'+$SolutionId+'.zip')
  $partial=$zip+'.partial';$completed=$false
  try{
    New-Item -ItemType Directory -Force -Path (Join-Path $stage 'cooked')|Out-Null
    Set-PMMTransientStageOwner $stage 'AIIOActivateCandidate'
    Copy-Item -LiteralPath (Join-Path $CandidateRoot 'solution.json') -Destination (Join-Path $stage 'solution.json') -Force
    foreach($file in @(Get-ChildItem -LiteralPath (Join-Path $CandidateRoot 'cooked') -File -ErrorAction Stop)){Copy-Item -LiteralPath $file.FullName -Destination (Join-Path $stage 'cooked') -Force}
    $runtime=Get-PMMRuntimePath
    if(-not(Test-Path -LiteralPath $runtime -PathType Leaf)){throw 'PMMRuntime.exe is required to validate this candidate.'}
    $output=@(& $runtime archive create $partial $stage 2>&1|ForEach-Object{[string]$_})
    if($LASTEXITCODE -ne 0 -or -not(Test-Path -LiteralPath $partial -PathType Leaf)){throw ('Could not prepare candidate validation ZIP. '+($output -join ' '))}
    Move-Item -LiteralPath $partial -Destination $zip -Force
    $completed=$true
    return $zip
  }finally{
    Remove-Item -LiteralPath $stage -Recurse -Force -ErrorAction SilentlyContinue
    Remove-PMMTransientStageOwner $stage
    Remove-Item -LiteralPath $partial -Force -ErrorAction SilentlyContinue
    if(-not$completed){Remove-Item -LiteralPath $zip -Force -ErrorAction SilentlyContinue}
  }
}

function Use-PMMAIIOCandidateForMerge {
  [CmdletBinding()]
  param([Parameter(Mandatory=$true)][string]$SessionId,[Parameter(Mandatory=$true)][string]$SolutionId)
  $session=Get-PMMAIIOSession $SessionId
  if(-not$session){throw ('AIIO session not found: '+$SessionId)}
  $candidate=@(Get-PMMAIIOCandidateRecords $SessionId|Where-Object{[string]$_.SolutionId -eq $SolutionId}|Select-Object -First 1)
  if($candidate.Count -eq 0){throw 'Selected AIIO candidate was not found.'}
  $record=$candidate[0]
  if([string]$record.InputSchema -ne 'PMM_MANUAL_SOLUTION_V1'){throw 'Only PMM_MANUAL_SOLUTION_V1 cooked-family candidates can enter Merge. Other candidate types remain staged for inspection.'}
  $caseIds=@($record.CaseIds|ForEach-Object{[string]$_}|Where-Object{$_}|Sort-Object -Unique)
  if($caseIds.Count -ne 1){throw 'A Merge candidate must reference exactly one current review case.'}
  $review=Get-PMMAIIOCurrentReviewFolderForCaseId $caseIds[0]
  if(-not$review){throw 'This candidate is stale or its exact Unsupported case is no longer current. Run Analyze again.'}
  $zip='';$journal=''
  try{
    if(Get-Command Start-PMMJournalOperation -ErrorAction SilentlyContinue){$journal=Start-PMMJournalOperation -Kind AIIOActivateCandidate -Target $SolutionId -Metadata ([ordered]@{SessionId=$SessionId;CaseId=$caseIds[0]})}
    $zip=New-PMMAIIOCandidateActivationZip ([string]$record.Root) $SolutionId
    $imported=Import-PMMManualSolutionZip $zip $review $true
    $stored=Get-Content -LiteralPath ([string]$record.RecordPath) -Raw -Encoding UTF8|ConvertFrom-Json
    $stored.Status='AcceptedExperimental';$stored.RuntimeStatus='UNPROVEN';$stored|Add-Member -NotePropertyName AcceptedUtc -NotePropertyValue ([DateTime]::UtcNow.ToString('o')) -Force;$stored|Add-Member -NotePropertyName ActivatedCaseId -NotePropertyValue ([string]$imported.CaseId) -Force
    Write-PMMAIIOJsonAtomic ([string]$record.RecordPath) $stored 35
    $session.SelectedCandidateIds=@((@($session.SelectedCandidateIds|ForEach-Object{[string]$_})+$SolutionId)|Sort-Object -Unique)
    $session.Status='CandidateAcceptedExperimental';$session.AttentionRequired=$true;$session.OperationState='AnalyzeRequired';$session.LastPresentedCandidate=$SolutionId
    Save-PMMAIIOSession $session|Out-Null
    try{
      Add-PMMAIIOHistoryEvent -SessionId $SessionId -Event CANDIDATE_ACCEPTED_EXPERIMENTAL -Message ([string]$imported.CaseId) -Data ([ordered]@{SolutionId=$SolutionId;Asset=[string]$imported.Asset;RuntimeStatus='UNPROVEN'})|Out-Null
    }catch{Write-PMMLog ('AIIO candidate was activated, but its auxiliary history event could not be written: '+$_.Exception.Message)}
    if($journal){try{Complete-PMMJournalOperation -OperationId $journal -Kind AIIOActivateCandidate -Metadata ([ordered]@{CaseId=[string]$imported.CaseId;RuntimeStatus='UNPROVEN'})}catch{Write-PMMLog ('AIIO candidate was activated, but its operation journal could not be completed: '+$_.Exception.Message)}}
    return $imported
  }catch{
    if($journal){try{Fail-PMMJournalOperation -OperationId $journal -Kind AIIOActivateCandidate -Message $_.Exception.Message}catch{}}
    throw
  }finally{if($zip){Remove-Item -LiteralPath $zip -Force -ErrorAction SilentlyContinue;Remove-Item -LiteralPath ($zip+'.partial') -Force -ErrorAction SilentlyContinue}}
}

function Get-PMMAIIOPendingRequests([string]$SessionId) {
  $session=Get-PMMAIIOSession $SessionId
  if(-not$session -or [int]$session.Iteration -le 0){return @()}
  $path=Join-Path (Get-PMMAIIOSessionPath $SessionId) ('responses\response-{0:D4}\validated-requests.json' -f [int]$session.Iteration)
  if(-not(Test-Path -LiteralPath $path -PathType Leaf)){return @()}
  try{$set=Get-Content -LiteralPath $path -Raw -Encoding UTF8|ConvertFrom-Json;return @($set.Requests|Where-Object{[string]$_.Status -eq 'Pending'})}catch{return @()}
}

function Export-PMMAIIORequestedData($Request,[string]$Destination,[string]$SessionId) {
  New-Item -ItemType Directory -Force -Path $Destination|Out-Null
  $cap=[string]$Request.Capability
  $session=Get-PMMAIIOSession $SessionId
  if(-not$session){throw ('AIIO requested-data session was not found: '+$SessionId)}
  switch($cap){
    'read_pmm_log' {Get-PMMAIIOSanitizedLogWindow -MaximumLines 500|Set-Content -LiteralPath (Join-Path $Destination 'pmm-log-sanitized.txt') -Encoding UTF8;break}
    'extract_relevant_log_window' {Get-PMMAIIOSanitizedLogWindow -MaximumLines 1000|Set-Content -LiteralPath (Join-Path $Destination 'pmm-log-sanitized.txt') -Encoding UTF8;break}
    'read_operation_state' {Write-PMMAIIOJsonAtomic (Join-Path $Destination 'operation-state.json') (Get-PMMAIIOOperationStateExport) 40;break}
    'query_knowledge' {
      foreach($source in @((Join-PMMPath 'CKLCatalog' 'case-index.json'),(Join-PMMPath 'CKL' 'channels.json'),(Join-PMMPath 'CKLStable' 'production-recipes.json'))){if(Test-Path -LiteralPath $source -PathType Leaf){Copy-Item -LiteralPath $source -Destination (Join-Path $Destination ([IO.Path]::GetFileName($source))) -Force}}
      break
    }
    'query_fixlab' {
      if(-not(Get-Command Get-PMMFixLabBuiltOutputs -ErrorAction SilentlyContinue)){
        $service=Join-Path $Script:Root 'Modules\FixLab\FixLabService.ps1'
        if(-not(Test-Path -LiteralPath $service -PathType Leaf)){throw 'Fix Lab service is unavailable for the validated query.'}
        . $service
        Initialize-PMMFixLab
      }
      $rows=@(Get-PMMFixLabBuiltOutputs|ForEach-Object{[pscustomobject]@{BuildId=[string]$_.BuildId;CaseId=[string]$_.CaseId;RecipeId=[string]$_.RecipeId;VariantId=[string]$_.VariantId;RuntimeStatus=[string]$_.RuntimeStatus;Hash=[string]$_.Hash}})
      Write-PMMAIIOJsonAtomic (Join-Path $Destination 'fixlab-summary.json') ([ordered]@{Schema='PMM_FIXLAB_SUMMARY_V1';BuiltOutputs=$rows}) 25;break
    }
    'query_game_reference' {
      $families=@(Search-PMMAIIOGameReferenceFamilies -Query ([string]$Request.Query) -MaximumResults ([int]$Request.MaximumResults))
      Write-PMMAIIOJsonAtomic (Join-Path $Destination 'game-reference-index.json') ([ordered]@{Schema='PMM_GAME_REFERENCE_QUERY_V2';Query=[string]$Request.Query;MaximumResults=[int]$Request.MaximumResults;Returned=$families.Count;GameReference=(Get-PMMAIIOGameReferenceProof -RequireCurrent);Families=$families}) 45;break
    }
    'extract_game_reference_asset' {
      if([string]$session.TaskType -ne 'CREATE_MOD'){throw 'Exact Game Reference extraction requires a CREATE_MOD project.'}
      [void](Export-PMMAIIOGameReferenceAsset -LogicalPath ([string]$Request.LogicalPath) -Destination $Destination -MaximumBytes ([int64]$Request.MaximumExpectedBytes));break
    }
    'extract_reference_neighborhood' {
      if([string]$session.TaskType -ne 'CREATE_MOD'){throw 'Game Reference neighborhood extraction requires a CREATE_MOD project.'}
      [void](Export-PMMAIIOGameReferenceNeighborhood -LogicalPath ([string]$Request.LogicalPath) -Destination $Destination -MaximumFamilies ([int]$Request.MaximumFamilies) -MaximumBytes ([int64]$Request.MaximumExpectedBytes));break
    }
    {$_ -in @('extract_vanilla_asset','extract_provider_asset','extract_asset_family')} {
      $plan=Read-PMMMergePlan;$cases=@(Get-PMMAIIOCurrentCases $plan);$match=@($cases|Where-Object{[string]$_.Asset -ceq [string]$Request.LogicalPath}|Select-Object -First 1)
      if($match.Count -eq 0){throw ('Requested asset is not an exact current Unsupported case: '+[string]$Request.LogicalPath)}
      $roleFilter='';$providerFilter=''
      if($cap -eq 'extract_vanilla_asset'){
        $roleFilter='Vanilla'
        if(-not[bool]$match[0].Case.VanillaAvailable){throw ('Vanilla is not available for the exact current Unsupported case: '+[string]$Request.LogicalPath)}
      }
      elseif($cap -eq 'extract_provider_asset'){
        $roleFilter='Provider';$providerFilter=[string]$Request.ProviderName
        if([string]::IsNullOrWhiteSpace($providerFilter) -or -not(@($match[0].Providers|ForEach-Object{[string]$_}) -ccontains $providerFilter)){throw ('Requested provider is not part of the exact current Unsupported case: '+$providerFilter)}
      }
      $mods=@(Get-LibraryMods);$map=@{};[int64]$raw=0
      $sources=@(Export-PMMAIIOAssetSources $match[0] $Destination $mods $map ([ref]$raw) $false $roleFilter $providerFilter)
      Write-PMMAIIOJsonAtomic (Join-Path $Destination 'sources.json') ([ordered]@{Schema='PMM_AIIO_REQUESTED_SOURCES_V1';Asset=[string]$Request.LogicalPath;RequestedRole=$roleFilter;RequestedProvider=$providerFilter;Sources=$sources;RawBytes=$raw}) 35
      break
    }
    default {throw ('Capability is declared but not available through the manual ZIP transport in this build: '+$cap)}
  }
}

function New-PMMAIIOPendingDataHandoff {
  [CmdletBinding()]
  param([Parameter(Mandatory=$true)][string]$SessionId)
  $session=Get-PMMAIIOSession $SessionId
  if(-not$session){throw ('AIIO session not found: '+$SessionId)}
  $exportSession=Get-PMMAIIOExportSession $session
  $requests=@(Get-PMMAIIOPendingRequests $SessionId)
  if($requests.Count -eq 0){throw 'This session has no pending validated data requests.'}
  $iteration=[int]$session.Iteration+1
  $bundleId=Get-PMMStableTextId ('AIIO_INCREMENTAL|'+$SessionId+'|'+$iteration+'|'+((@($requests|ForEach-Object{[string]$_.RequestId}|Sort-Object)) -join '|'))
  $exportSession.Iteration=$iteration;$exportSession.LastBundleId=$bundleId;$exportSession.Status='WaitingForAI';$exportSession.OperationState='WaitingForAI'
  $requestDir=Join-Path (Get-PMMAIIOSessionPath $SessionId) ('requests\request-{0:D4}' -f $iteration);New-Item -ItemType Directory -Force -Path $requestDir|Out-Null
  $stage=Join-Path (Get-PMMPath 'Temp') ('AIIOData_'+[guid]::NewGuid().ToString('N'));$partial=$stage+'.zip.partial';$zip=Join-Path $requestDir ('PMM_AIIO_REQUEST_'+$SessionId+'_STEP_{0:D2}.zip' -f $iteration)
  $outboxCopy='';$committed=$false
  try{
    New-Item -ItemType Directory -Force -Path $stage|Out-Null
    Set-PMMTransientStageOwner $stage 'AIIOPendingData'
    Write-PMMAIIOSystemDocuments $stage $SessionId $bundleId $iteration
    Write-PMMAIIOJsonAtomic (Join-Path $stage 'PMM_CAPABILITIES.json') (Get-PMMAIIOCapabilityRegistry) 30
    Write-PMMAIIOJsonAtomic (Join-Path $stage 'session.json') $exportSession 40
    $i=0
    foreach($request in $requests){
      $i++;$dest=Join-Path $stage ('data\request-{0:D3}-{1}' -f $i,[string]$request.RequestId)
      Export-PMMAIIORequestedData $request $dest $SessionId
      [int64]$actualBytes=0;foreach($file in @(Get-ChildItem -LiteralPath $dest -Recurse -File -ErrorAction SilentlyContinue)){$actualBytes+=[int64]$file.Length}
      if([int64]$request.MaximumExpectedBytes -gt 0 -and $actualBytes -gt [int64]$request.MaximumExpectedBytes){throw ('Requested data exceeded the declared per-request budget for '+[string]$request.Capability+'.')}
    }
    Write-PMMAIIOJsonAtomic (Join-Path $stage 'request.json') ([ordered]@{Schema='PMM_AIIO_INCREMENTAL_REQUEST_V2';SessionId=$SessionId;BundleId=$bundleId;Iteration=$iteration;Fulfills=@($requests|ForEach-Object{[string]$_.RequestId});CreatedUtc=[DateTime]::UtcNow.ToString('o')}) 20
    Write-PMMAIIOJsonAtomic (Join-Path $stage 'bundle.json') ([ordered]@{Schema='PMM_AI_HANDOFF_BUNDLE_V2';Protocol=2;SessionId=$SessionId;BundleId=$bundleId;Iteration=$iteration;Incremental=$true;WholeSourcePaksIncluded=$false;CreatedUtc=[DateTime]::UtcNow.ToString('o')}) 20
    $runtime=Get-PMMRuntimePath;$output=@(& $runtime archive create $partial $stage 2>&1|ForEach-Object{[string]$_})
    if($LASTEXITCODE -ne 0 -or -not(Test-Path -LiteralPath $partial -PathType Leaf)){throw ('Could not create incremental AIIO ZIP. '+($output -join ' '))}
    [void](Test-PMMAIIODataArchive $partial $SessionId $bundleId);Move-Item -LiteralPath $partial -Destination $zip -Force
    $outboxCopy=Join-Path (Get-PMMPath 'AIIOOutbox') ([IO.Path]::GetFileName($zip));Copy-Item -LiteralPath $zip -Destination $outboxCopy -Force
    $session.Iteration=$iteration;$session.LastBundleId=$bundleId;$session.Status='WaitingForAI';$session.AttentionRequired=$true;$session.OperationState='WaitingForAI';Save-PMMAIIOSession $session|Out-Null
    $committed=$true
    try{Add-PMMAIIOHistoryEvent -SessionId $SessionId -Event INCREMENTAL_HANDOFF_CREATED -Message ([IO.Path]::GetFileName($zip)) -Data ([ordered]@{BundleId=$bundleId;RequestCount=$requests.Count;Sha256=(Get-Sha256 $zip)})|Out-Null}catch{Write-PMMLog ('AIIO incremental history warning: '+$_.Exception.Message)}
    return [pscustomobject]@{SessionId=$SessionId;BundleId=$bundleId;Iteration=$iteration;ZipPath=$zip;RequestCount=$requests.Count;ZipSha256=(Get-Sha256 $zip)}
  }catch{
    if(-not$committed){if($outboxCopy){Remove-Item -LiteralPath $outboxCopy -Force -ErrorAction SilentlyContinue};Remove-Item -LiteralPath $requestDir -Recurse -Force -ErrorAction SilentlyContinue}
    throw
  }finally{Remove-Item -LiteralPath $stage -Recurse -Force -ErrorAction SilentlyContinue;Remove-PMMTransientStageOwner $stage;Remove-Item -LiteralPath $partial -Force -ErrorAction SilentlyContinue}
}
