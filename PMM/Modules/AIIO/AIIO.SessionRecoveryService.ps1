<#
AIIO session recovery packages
==============================

A terminal AI response (for example PMM_BUG) can be diagnostically correct while
leaving a durable AIIO session with no pending work. A recovery package may add
one new validated request iteration to that SAME existing session without
rewriting or deleting any earlier request/response history.

This is intentionally narrow:
  * recovery packages are data-only ZIPs with one root response.json;
  * the target session must already exist locally;
  * this build supports recovery only for CREATE_MOD sessions;
  * only the normal requestable AIIO capabilities may be queued;
  * previous iterations remain immutable;
  * each recoveryId is accepted at most once per session.

Compatibility note:
  Recovery ZIPs may use the native PMM_AIIO_SESSION_RECOVERY_V1 schema or a
  PMM_AI_RESPONSE_V2 transport envelope carrying recoverySchema. The latter is
  intentionally accepted by the pre-recovery UI router, so an updated worker can
  recover a terminal session even if the WPF process still has the older lightweight
  response router loaded.
#>

$Script:PMMAIIOSessionRecoverySchema='PMM_AIIO_SESSION_RECOVERY_V1'

function Test-PMMAIIOSessionRecoveryDocument($Response) {
  if(-not$Response){return $false}
  $schema=[string]$Response.schema
  if($schema -eq $Script:PMMAIIOSessionRecoverySchema){return $true}
  if($schema -notin @('PMM_AI_RESPONSE_V2','PMM_AIIO_RESPONSE_V2')){return $false}

  # ConvertFrom-Json returns PSCustomObject. Under Set-StrictMode, directly
  # reading a property that is not present (for example recoverySchema on a
  # normal candidate-ready response) is a terminating error. Recovery is an
  # optional transport marker, so inspect the property bag before reading it.
  $markerProperty=$Response.PSObject.Properties['recoverySchema']
  if(-not$markerProperty){return $false}
  return ([string]$markerProperty.Value -eq $Script:PMMAIIOSessionRecoverySchema)
}

function Get-PMMAIIOResponsePackageHint([string]$ZipPath) {
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
      if(Test-PMMAIIOSessionRecoveryDocument $response){
        $sessionId=[string]$response.sessionId
        if(-not(Test-PMMAIIOSessionId $sessionId)){throw 'AIIO recovery package contains an invalid session id.'}
        return [pscustomobject]@{Kind='SessionRecovery';SessionId=$sessionId;CaseId=''}
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

function Test-PMMAIIOSessionRecoveryArchive([string]$ZipPath) {
  $envelope=Test-PMMAIIOResponseArchiveEnvelope $ZipPath
  $response=$envelope.Response
  if(-not(Test-PMMAIIOSessionRecoveryDocument $response)){throw 'Unsupported AIIO recovery schema.'}

  Add-Type -AssemblyName System.IO.Compression.FileSystem
  $archive=[IO.Compression.ZipFile]::OpenRead((Get-Item -LiteralPath $ZipPath).FullName)
  try{
    foreach($entry in @($archive.Entries)){
      if([string]::IsNullOrWhiteSpace([string]$entry.Name)){continue}
      $name=([string]$entry.FullName).Replace([char]92,[char]47)
      if($name -cne 'response.json'){throw ('AIIO recovery packages cannot contain payload files: '+$name)}
    }
  }finally{$archive.Dispose()}

  $sessionId=[string]$response.sessionId
  if(-not(Test-PMMAIIOSessionId $sessionId)){throw 'AIIO recovery package contains an invalid session id.'}
  $recoveryId=[string]$response.recoveryId
  if($recoveryId -notmatch '^[A-Za-z0-9][A-Za-z0-9._-]{7,79}$'){throw 'AIIO recoveryId must be 8-80 safe ASCII characters.'}
  $summary=[string]$response.summary
  if($summary.Length -gt 4000 -or $summary.IndexOf([char]0) -ge 0){throw 'AIIO recovery summary is invalid.'}
  $requests=@($response.requests)
  if($requests.Count -lt 1 -or $requests.Count -gt 64){throw 'AIIO recovery package must declare 1-64 data requests.'}
  if(@($response.candidates).Count -gt 0){throw 'AIIO recovery packages cannot stage candidates.'}
  return [pscustomobject]@{Response=$response;SessionId=$sessionId;RecoveryId=$recoveryId;Summary=$summary;Requests=$requests}
}

function Import-PMMAIIOSessionRecoveryZip {
  [CmdletBinding()]
  param([Parameter(Mandatory=$true)][string]$ZipPath,[string]$ExpectedSessionId='')

  $recovery=Test-PMMAIIOSessionRecoveryArchive $ZipPath
  $sessionId=[string]$recovery.SessionId
  if($ExpectedSessionId -and $sessionId -ne $ExpectedSessionId){throw 'AIIO recovery package belongs to another session.'}
  $session=Get-PMMAIIOSession $sessionId
  if(-not$session){throw ('AIIO recovery target session was not found: '+$sessionId)}
  if([string]$session.TaskType -ne 'CREATE_MOD'){throw 'This recovery transport is currently enabled only for CREATE_MOD sessions.'}
  if([bool]$session.Archived){throw 'Archive state must be cleared before recovering this AIIO session.'}

  $sessionBefore=($session|ConvertTo-Json -Depth 60|ConvertFrom-Json)
  $sessionRoot=Get-PMMAIIOSessionPath $sessionId
  $recoveryRoot=Join-Path $sessionRoot 'recoveries'
  New-Item -ItemType Directory -Force -Path $recoveryRoot|Out-Null
  $marker=Join-Path $recoveryRoot ([string]$recovery.RecoveryId+'.json')
  if(Test-Path -LiteralPath $marker -PathType Leaf){throw ('This AIIO recovery package was already applied: '+[string]$recovery.RecoveryId)}

  $iteration=[int]$session.Iteration+1
  if($iteration -lt 1){$iteration=1}
  $responseDir=Join-Path $sessionRoot ('responses\response-{0:D4}' -f $iteration)
  if(Test-Path -LiteralPath $responseDir){throw ('AIIO recovery cannot append iteration '+$iteration+' because that response directory already exists.')}

  $createdResponse=$false;$createdMarker=$false
  try{
    $seen=@{};$requests=[Collections.Generic.List[object]]::new()
    foreach($request in @($recovery.Requests)){$requests.Add((Test-PMMAIIOCapabilityRequest $request $seen $session))}
    if($requests.Count -eq 0){throw 'AIIO recovery produced no validated data requests.'}

    $bundleId=Get-PMMStableTextId ('AIIO_RECOVERY|'+$sessionId+'|'+$iteration+'|'+[string]$recovery.RecoveryId+'|'+((@($requests.ToArray()|ForEach-Object{[string]$_.RequestId}|Sort-Object)) -join '|'))
    $stored=[ordered]@{
      Schema='PMM_AIIO_RECOVERY_APPLIED_V1'
      SessionId=$sessionId
      RecoveryId=[string]$recovery.RecoveryId
      Iteration=$iteration
      BundleId=$bundleId
      Summary=[string]$recovery.Summary
      PreviousStatus=[string]$session.Status
      Requests=@($recovery.Requests)
      AppliedUtc=[DateTime]::UtcNow.ToString('o')
      Safety='Previous AIIO iterations were preserved. This recovery only appended validated Level-A data work.'
    }

    New-Item -ItemType Directory -Force -Path $responseDir|Out-Null;$createdResponse=$true
    Write-PMMAIIOJsonAtomic (Join-Path $responseDir 'response.json') $stored 40
    Write-PMMAIIOJsonAtomic (Join-Path $responseDir 'validated-requests.json') ([ordered]@{Schema='PMM_AIIO_REQUEST_SET_V1';Requests=@($requests.ToArray())}) 30
    Write-PMMAIIOJsonAtomic (Join-Path $responseDir 'validated-candidates.json') ([ordered]@{Schema='PMM_AIIO_CANDIDATE_SET_V1';Candidates=@()}) 20

    $session.Iteration=$iteration
    $session.LastBundleId=$bundleId
    $session.Status='NeedsData'
    $session.AttentionRequired=$true
    $session.OperationState='NeedsData'
    Save-PMMAIIOSession $session|Out-Null

    Write-PMMAIIOJsonAtomic $marker ([ordered]@{Schema='PMM_AIIO_RECOVERY_MARKER_V1';SessionId=$sessionId;RecoveryId=[string]$recovery.RecoveryId;Iteration=$iteration;BundleId=$bundleId;ZipSha256=(Get-Sha256 $ZipPath);AppliedUtc=[DateTime]::UtcNow.ToString('o')}) 20
    $createdMarker=$true
    try{Add-PMMAIIOHistoryEvent -SessionId $sessionId -Event SESSION_RECOVERED -Message ([string]$recovery.Summary) -Data ([ordered]@{RecoveryId=[string]$recovery.RecoveryId;Iteration=$iteration;Requests=$requests.Count;PreviousStatus=[string]$stored.PreviousStatus})|Out-Null}catch{Write-PMMLog ('AIIO session recovery succeeded but its optional history event could not be written: '+$_.Exception.Message)}

    return [pscustomobject]@{SessionId=$sessionId;Status='NeedsData';RequestCount=$requests.Count;CandidateCount=0;Requests=@($requests.ToArray());RecoveryId=[string]$recovery.RecoveryId;Iteration=$iteration;BundleId=$bundleId}
  }catch{
    if($createdMarker){Remove-Item -LiteralPath $marker -Force -ErrorAction SilentlyContinue}
    if($createdResponse){Remove-Item -LiteralPath $responseDir -Recurse -Force -ErrorAction SilentlyContinue}
    try{Save-PMMAIIOSession $sessionBefore|Out-Null}catch{}
    throw
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
    $response=$null
    if($roots.Count -eq 1 -and $roots[0] -ceq 'response.json'){$response=Read-PMMAIIOZipJsonEntry $archive 'response.json' 2097152}
  }finally{$archive.Dispose()}
  if($roots.Count -ne 1){throw 'AI response ZIP must contain exactly one root response.json or solution.json.'}
  if($roots[0] -ceq 'solution.json'){return (Import-PMMAIIOManualSolutionCandidate -ZipPath $ZipPath -SessionId $ExpectedSessionId)}
  if(Test-PMMAIIOSessionRecoveryDocument $response){return (Import-PMMAIIOSessionRecoveryZip -ZipPath $ZipPath -ExpectedSessionId $ExpectedSessionId)}
  return (Import-PMMAIIOResponseZip -ZipPath $ZipPath -ExpectedSessionId $ExpectedSessionId)
}
