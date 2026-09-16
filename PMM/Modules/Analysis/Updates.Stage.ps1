function Receive-PMMUpdateBytes([Uri]$Uri,[string]$Path,[string]$SessionId) {
  Add-Type -AssemblyName System.Net.Http
  $session=Get-PMMRepairSession $SessionId
  $used=0L;foreach($file in @(Get-ChildItem -LiteralPath (Get-PMMRepairSessionRoot $SessionId) -Recurse -File)){$used+=$file.Length}
  $limit=[long]($session.Options.MaxDiskGiB*1GB)-$used
  if($limit -le 0){throw 'Session storage limit reached.'}
  $handler=[Net.Http.HttpClientHandler]::new();$http=[Net.Http.HttpClient]::new($handler)
  $http.Timeout=[TimeSpan]::FromSeconds(120);$response=$null;$stream=$null;$output=$null;$created=$false;$complete=$false
  try{
    $response=$http.GetAsync($Uri,[Net.Http.HttpCompletionOption]::ResponseHeadersRead).GetAwaiter().GetResult()
    [void]$response.EnsureSuccessStatusCode()
    if($response.RequestMessage.RequestUri.Scheme -ne 'https'){throw 'An update redirect left HTTPS.'}
    if($response.Content.Headers.ContentLength -gt $limit){throw 'Update exceeds remaining session storage.'}
    $stream=$response.Content.ReadAsStreamAsync().GetAwaiter().GetResult()
    $output=[IO.File]::Open($Path,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
    $created=$true
    $buffer=New-Object byte[] 65536;$received=0L;$watch=[Diagnostics.Stopwatch]::StartNew()
    while($true){
      $read=$stream.ReadAsync($buffer,0,$buffer.Length)
      while(-not$read.IsCompleted){
        if(Test-Path -LiteralPath (Join-Path (Get-PMMRepairSessionRoot $SessionId) 'cancel')){throw 'Update cancelled.'}
        if($watch.Elapsed.TotalSeconds -gt 120){throw 'Update download timed out.'}
        Start-Sleep -Milliseconds 50
      }
      $n=$read.GetAwaiter().GetResult();if($n -eq 0){break}
      $received+=$n;if($received -gt $limit){throw 'Update exceeds remaining session storage.'}
      $output.Write($buffer,0,$n)
    }
    $output.Flush($true);$complete=$true
  }finally{if($output){$output.Dispose()};if($created -and -not$complete -and [IO.File]::Exists($Path)){[IO.File]::Delete($Path)};if($stream){$stream.Dispose()};if($response){$response.Dispose()};$http.Dispose();$handler.Dispose()}
}
function Test-PMMStagedUpdate($Record,[string]$SessionId) {
  $s=Assert-PMMRepairAuthorization $SessionId $Record.CaseId $Record.EvidenceRevision Download
  if((Get-Sha256 $Record.Path) -cne $Record.Sha256){throw 'Staged update archive changed.'}
  $root=Join-Path (Get-PMMRepairSessionRoot $SessionId) ('UpdateCandidates/'+$Record.Sha256)
  if(Test-Path -LiteralPath $root){throw 'Update candidate staging already exists. Its files are preserved; inspect the recorded attempt instead of overwriting it.'}
  [void][IO.Directory]::CreateDirectory($root)
  $filesRoot=Join-Path $root 'files';[void][IO.Directory]::CreateDirectory($filesRoot)
  $ext=[IO.Path]::GetExtension($Record.Path)
  if($ext -eq '.pak'){
    Copy-Item -LiteralPath $Record.Path -Destination (Join-Path $filesRoot ([IO.Path]::GetFileName($Record.Update.Candidate.AssetName)))
  }elseif($ext -eq '.zip'){
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zip=[IO.Compression.ZipFile]::OpenRead($Record.Path)
    try{
      $entries=@($zip.Entries|Where-Object{$_.Name -and [IO.Path]::GetExtension($_.Name) -eq '.pak'})
      $bytes=0L;foreach($entry in $zip.Entries){$bytes+=$entry.Length}
      $available=[long]($s.Options.MaxDiskGiB*1GB)
      $used=0L;foreach($file in @(Get-ChildItem -LiteralPath (Get-PMMRepairSessionRoot $SessionId) -Recurse -File)){$used+=$file.Length}
      if($bytes -gt ($available-$used) -or $zip.Entries.Count -gt 10000){throw 'Update extraction exceeds the session budget.'}
      $names=@{}
      foreach($entry in $entries){
        if([IO.Path]::GetFileName($entry.Name) -cne $entry.Name -or $entry.Name.IndexOfAny([IO.Path]::GetInvalidFileNameChars()) -ge 0){throw 'An update member is not a safe file name.'}
        if(Test-Path -LiteralPath (Join-Path (Get-PMMRepairSessionRoot $SessionId) 'cancel')){throw 'Update cancelled.'}
        if($names.ContainsKey($entry.Name)){throw 'Archive contains ambiguous PAK variants with the same name.'};$names[$entry.Name]=$true
        $target=Join-Path $filesRoot $entry.Name
        $input=$entry.Open();$output=[IO.File]::Open($target,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
        try{$input.CopyTo($output);$output.Flush($true)}finally{$input.Dispose();$output.Dispose()}
      }
    }finally{$zip.Dispose()}
  }else{throw 'This staged format requires a verified extraction adapter. The original remains unchanged.'}
  $paks=@(Get-ChildItem -LiteralPath $filesRoot -Filter *.pak -File)
  if($paks.Count -ne 1){throw 'The update contains multiple or no PAK variants. Select the intended author variant before continuing.'}
  $pak=$paks[0];$original=Find-PMMLibraryMod $Record.Update.Mod
  $hash=Get-Sha256 $pak.FullName
  $entries=@(Get-PakEntriesCached $pak.FullName|ForEach-Object{Normalize-PakLogicalPath $_})
  $before=@(Get-PakEntriesCached $original.Path|ForEach-Object{Normalize-PakLogicalPath $_})
  $removed=@($before|Where-Object{$_ -notin $entries})
  $resources=[Collections.Generic.List[object]]::new()
  $parsed=0
  foreach($header in @($entries|Where-Object{$_ -like '*.uasset'})){
    if($parsed -ge $s.Options.MaxSemanticFamilies){break}
    Assert-PMMRepairAuthorization $SessionId $s.CaseId $s.EvidenceRevision Download|Out-Null
    $family=Export-PakAssetFamilyExact $pak.FullName $header (Join-Path $root 'cooked')
    $resources.Add((Read-PMMResourceEvidence $family.HeaderPath $header $pak.Name $hash 1));$parsed++
    try{
      $vanilla=Export-VanillaAssetFamilyExact $header (Join-Path $root 'vanilla')
      if($vanilla){$resources.Add((Read-PMMResourceEvidence $vanilla.HeaderPath $header Vanilla (Get-Sha256 $vanilla.HeaderPath) 0))}
    }catch{}
  }
  $findings=@(Get-PMMResourceFindings $resources.ToArray() $entries $false $false)
  $id=(Get-PMMAnalysisHash @($Record.Sha256,$hash,$s.EvidenceRevision)).Substring(0,32)
  Register-PMMRepairCandidate $SessionId $hash $id|Out-Null
  $analysisOptions=$s.Options|ConvertTo-Json|ConvertFrom-Json
  $analysisOptions.AutomaticSolution=$false;$analysisOptions.CheckUpdates=$false
  $proposed=Invoke-PMMDeepAnalysis $analysisOptions @{OriginalSha256=$Record.OriginalSha256;Path=$pak.FullName;Hash=$hash}
  Assert-PMMRepairAuthorization $SessionId $s.CaseId $s.EvidenceRevision Download|Out-Null
  $candidate=[ordered]@{ProposedAnalysisId=$proposed.Id;ProposedFindings=$proposed.Findings;Schema='PMM_AUTHOR_UPDATE_CANDIDATE_V1';CandidateId=$id;SessionId=$SessionId;CaseId=$s.CaseId;EvidenceRevision=$s.EvidenceRevision;OriginalPath=$original.Path;OriginalSha256=$Record.OriginalSha256;ArchivePath=$Record.Path;ArchiveSha256=$Record.Sha256;PakPath=$pak.FullName;PakSha256=$hash;RemovedResources=$removed;Resources=$resources.ToArray();Findings=$findings;Status='STAGED_REANALYZED';Runtime='UNPROVEN';FunctionsPreserved='Pending review';Applied=$false;Limitations=@('Complete proposed set analyzed with explicit reader and mount-order coverage. Activation remains a separate operation.','Author recency does not prove compatibility.')}
  Write-PMMJsonAtomic (Join-Path $root 'candidate.json') $candidate -Depth 60
  Save-PMMRepairProcedure $SessionId AuthorUpdate @($candidate.PakPath) @{OriginalSha256=$Record.OriginalSha256;Origin=$Record.Update;ProposedAnalysisId=$proposed.Id} StagedReanalyzedNeedsReview|Out-Null
  Add-PMMRepairAttempt $SessionId AuthorUpdate @{Archive=$Record.Sha256;Pak=$hash} NeedsFunctionalTest 'Author update staged and re-read; original preserved.'|Out-Null
  return $candidate
}
