function Enter-PMMAnalysisLock([string]$Path,[int]$TimeoutSeconds=10) {
  [void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($Path))
  $watch=[Diagnostics.Stopwatch]::StartNew()
  do{try{return [IO.File]::Open($Path,[IO.FileMode]::OpenOrCreate,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)}catch [IO.IOException]{if($watch.Elapsed.TotalSeconds -ge $TimeoutSeconds){throw 'The operation is busy. Retry with the same request identifier.'};Start-Sleep -Milliseconds 50}}while($true)
}
function Get-PMMArchiveContentProof([string]$Archive,[string]$ContentHash) {
  # Older path metadata is only a clue. Prove the extracted bytes before MD5 lookup.
  if(-not$Archive -or [IO.Path]::GetExtension($Archive) -ine '.zip' -or -not[IO.File]::Exists($Archive)){return $null}
  Add-Type -AssemblyName System.IO.Compression.FileSystem
  $zip=$null
  try{
    $archiveHash=Get-Sha256 $Archive
    $zip=[IO.Compression.ZipFile]::OpenRead($Archive)
    if($zip.Entries.Count -gt 10000){return $null}
    $readBytes=0L
    foreach($entry in $zip.Entries){
      if([IO.Path]::GetExtension($entry.FullName) -ine '.pak'){continue}
      $readBytes+=$entry.Length;if($readBytes -gt 2GB){return $null}
      $stream=$entry.Open();$sha=[Security.Cryptography.SHA256]::Create()
      try{$hash=[BitConverter]::ToString($sha.ComputeHash($stream)).Replace('-','').ToLowerInvariant()}finally{$sha.Dispose();$stream.Dispose()}
      if($hash -ceq $ContentHash){
        $zip.Dispose();$zip=$null
        $md5=(Get-FileHash -LiteralPath $Archive -Algorithm MD5).Hash.ToLowerInvariant()
        if((Get-Sha256 $Archive) -cne $archiveHash){return $null}
        return @{ArchiveSha256=$archiveHash;ArchiveMd5=$md5;Content=@{Path=$entry.FullName;Sha256=$hash}}
      }
    }
  }catch{return $null}finally{if($zip){$zip.Dispose()}}
  return $null
}
function Assert-PMMRepairEvidenceCurrent($Session) {
  $revision=Get-PMMCaseEvidenceRevision $Session.CaseId
  $case=Get-PMMAIIOCase $Session.CaseId
  foreach($reference in @($case.References.Mods)){
    if(-not[IO.File]::Exists($reference.Path) -or (Get-Sha256 $reference.Path) -cne $reference.Sha256){throw 'A referenced mod changed or disappeared. Refresh the case references before investigating.'}
  }
  $evidence=Get-PMMAnalysisValue $revision Evidence $null
  if((Get-PMMAnalysisValue $evidence Kind '') -eq 'DeepAnalysis'){
    $reportPath=Join-Path (Get-PMMAnalysisPath $evidence.AnalysisId) 'report.json'
    if((Get-Sha256 $reportPath) -cne $evidence.ReportSha256){throw 'Case report evidence changed on disk.'}
    $current=Get-PMMAnalysisSnapshot $evidence.Snapshot.Options
    if($current.Fingerprint -cne $evidence.Snapshot.Fingerprint){throw 'Game, mappings, tools, priorities, patch or deployed inputs changed. Analyze again before repairing.'}
    foreach($mod in @($evidence.Snapshot.Active)+@($evidence.Snapshot.Patch)){
      if($mod -and (-not[IO.File]::Exists($mod.Path) -or (Get-Sha256 $mod.Path) -cne $mod.Hash)){throw 'A source changed since this repair session was authorized. Analyze again.'}
    }
  }
}
function Save-PMMRepairSession($Session) {
  $path=Join-Path (Get-PMMRepairSessionRoot $Session.Id) 'session.json'
  $lock=Enter-PMMAnalysisLock ($path+'.lock')
  try{
    if(Test-Path -LiteralPath $path){
      $current=Read-PMMJsonFile $path
      $Session.ActiveSeconds=[Math]::Max([int]$current.ActiveSeconds,[int]$Session.ActiveSeconds)
      foreach($field in @('Candidates','TestRuns','Attempts','Recovery')){
        $seen=@{}
        $Session.$field=@(foreach($item in @($current.$field)+@($Session.$field)){$key=if($field -in @('Candidates','Attempts')){[string]$item.Fingerprint}else{Get-PMMAnalysisHash $item};if(-not$seen.ContainsKey($key)){$seen[$key]=$true;$item}})
      }
      if($current.Revoked){$Session.Revoked=$true;$Session.Status=$current.Status}
    }
    Write-PMMJsonAtomic $path $Session -Depth 40 -Schema PMM_REPAIR_SESSION_V1
  }finally{$lock.Dispose()}
}
function Register-PMMRepairCandidate([string]$SessionId,[string]$Fingerprint,[string]$CandidateId) {
  $candidateLock=Enter-PMMAnalysisLock (Join-Path (Get-PMMRepairSessionRoot $SessionId) 'candidate-registration.lock')
  try{
  $s=Get-PMMRepairSession $SessionId
  $existing=@($s.Candidates|Where-Object{$_.Fingerprint -eq $Fingerprint})
  if($existing.Count){return $existing[0]}
  if(@($s.Candidates).Count -ge $s.Options.MaxCandidates){throw 'Candidate limit reached; previous attempts are preserved.'}
  Assert-PMMRepairAuthorization $SessionId $s.CaseId $s.EvidenceRevision Build|Out-Null
  $candidate=@{Fingerprint=$Fingerprint;CandidateId=$CandidateId;Utc=[DateTime]::UtcNow.ToString('o')}
  $s.Candidates=@($s.Candidates)+@($candidate);Save-PMMRepairSession $s
  return $candidate
  }finally{$candidateLock.Dispose()}
}
