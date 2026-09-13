# Observation reports only the coverage PMM actually saw. No save content is read.
if(-not(Get-Variable PMMGameObservation -Scope Script -ErrorAction SilentlyContinue)){$Script:PMMGameObservation=$null}
if(-not(Get-Variable PMMObservationSnapshotWorker -Scope Script -ErrorAction SilentlyContinue)){$Script:PMMObservationSnapshotWorker=$null}
function New-PMMObservationSession {
    param([string]$GameRoot,[int]$ProcessId,[string]$ProcessStartUtc,$Deployment,[datetime]$Utc=[DateTime]::UtcNow,[array]$CrashBaseline=@())
    if(-not$Deployment -or -not$Deployment.Verified -or -not$Deployment.DeploymentId){throw 'An exact, verified deployment snapshot is required.'}
    return [pscustomobject]@{Schema='PMM_GAME_OBSERVATION_V1';SessionId=[guid]::NewGuid().ToString('N');GameRoot=[IO.Path]::GetFullPath($GameRoot);ProcessId=$ProcessId;ProcessStartUtc=$ProcessStartUtc;DeploymentId=$Deployment.DeploymentId;DeploymentFiles=@($Deployment.Files);Candidates=@($Deployment.Candidates);StartedUtc=$Utc.ToString('o');LastSampleUtc=$Utc.ToString('o');EndedUtc='';ObservedSeconds=0.0;GapSeconds=0.0;Coverage='Partial';Observation='ExecutionObserved';PlayedEvidence='';CrashBaseline=@($CrashBaseline);NewCrashes=@();CrashAssessment='Not assessed';CrashCoverage='Installation-local crash directory; shared crash reports are not attributed';EndReason='';Status='Observing'}
}
function Update-PMMObservationSample {
    param($Session,[datetime]$Utc,[bool]$ProcessAlive=$true,[bool]$IdentityMatches=$true,[array]$CrashMarkers=@(),[double]$MaximumGapSeconds=45,[string]$DeploymentId='')
    if($Session.Status -ne 'Observing'){return $Session}
    $delta=($Utc.ToUniversalTime()-([datetime]$Session.LastSampleUtc).ToUniversalTime()).TotalSeconds
    if($delta -lt 0){
        $Session.Coverage='ClockChanged';$Session.Status='Closed';$Session.EndReason='ClockChanged';$Session.EndedUtc=$Utc.ToString('o')
        $Session.CrashAssessment='Observation interrupted by a clock change';return $Session
    }
    if($delta -gt $MaximumGapSeconds){$Session.GapSeconds+=$delta;$Session.Coverage='GapsExcluded'}
    elseif($ProcessAlive -and $IdentityMatches -and (-not$DeploymentId -or $DeploymentId -ceq $Session.DeploymentId)){$Session.ObservedSeconds+=$delta}
    # The final interval after exit is not credited: its actual runtime is unknown.
    $Session.LastSampleUtc=$Utc.ToString('o')
    $new=@($CrashMarkers|Where-Object{$_ -and $_ -cnotin @($Session.CrashBaseline)}|Select-Object -Unique)
    $Session.NewCrashes=@(@($Session.NewCrashes)+$new|Select-Object -Unique)
    if(-not$IdentityMatches -or ($DeploymentId -and $DeploymentId -cne $Session.DeploymentId)){
        $Session.Status='Closed';$Session.EndReason='IdentityOrDeploymentChanged';$Session.EndedUtc=$Utc.ToString('o')
    }elseif(-not$ProcessAlive){
        $Session.Status='Closed';$Session.EndReason='ProcessExited';$Session.EndedUtc=$Utc.ToString('o')
    }
    if($Session.Status -eq 'Closed'){$Session.CrashAssessment=if(@($Session.NewCrashes).Count){'New crash report detected during session; causation unknown'}else{'No crash detected'}}
    return $Session
}
function Add-PMMObservationPlayedEvidence($Session,[string]$AdapterId,[string]$EvidenceId) {
    # No validated gameplay adapter ships in v1. Process uptime cannot assert played.
    throw 'No validated gameplay-activity adapter is installed. Use ExecutionObserved.'
}
function Get-PMMObservationCrashMarkers([string]$GameRoot) {
    # Directory identities only. LocalAppData crash reports may belong to any install;
    # shared reports are intentionally excluded rather than attributed speculatively.
    $crashRoot=Join-Path $GameRoot 'Pal\Saved\Crashes'
    foreach($item in @(Get-ChildItem -LiteralPath $crashRoot -Directory -ErrorAction SilentlyContinue)){
        $item.Name+'|'+$item.CreationTimeUtc.ToString('o')
    }
}
function Save-PMMObservationSession($Session) {
    if($Session.Schema -ne 'PMM_GAME_OBSERVATION_V1' -or $Session.SessionId -cnotmatch '^[a-f0-9]{32}$'){throw 'Invalid observation session.'}
    Write-PMMKnowledgeJson (Join-Path (Get-PMMKnowledgeRoot) ('Observations\'+$Session.SessionId+'.json')) $Session
    if($Session.Status -ne 'Closed'){return}
    foreach($candidate in @($Session.Candidates)){
        Invoke-PMMKnowledgeLock ($candidate.CaseId+'|'+$candidate.CandidateId) {
            $record=Get-PMMKnowledgeCandidate $candidate.CaseId $candidate.CandidateId
            if(-not$record -or $record.PakSha256 -cne $candidate.PakSha256){return}
            if($Session.SessionId -cnotin @($record.Observations)){$record.Observations=@($record.Observations)+@($Session.SessionId)}
            if($Session.ObservedSeconds -gt 0){$record.Observation='ExecutionObserved'}
            # Crashes stay on the session. They never set Failed on every mod.
            Write-PMMKnowledgeJson (Get-PMMKnowledgeCandidatePath $record.CaseId $record.CandidateId) $record
        }
    }
}
function Get-PMMPendingCandidateFeedback {
    if(-not(Get-PMMKnowledgePreferences).FeedbackEnabled){return @()}
    $seen=@{}
    foreach($file in @(Get-ChildItem -LiteralPath (Join-Path (Get-PMMKnowledgeRoot) 'Observations') -Filter '*.json' -File -ErrorAction SilentlyContinue|Sort-Object LastWriteTimeUtc -Descending)){
        $session=Read-PMMKnowledgeJson $file.FullName
        if($session.Status -ne 'Closed' -or $session.EndReason -ne 'ProcessExited' -or $session.ObservedSeconds -lt 600){continue}
        $candidates=@()
        foreach($item in @($session.Candidates)){
            $key=$item.CaseId+'|'+$item.CandidateId
            if($seen.ContainsKey($key)){continue};$seen[$key]=$true
            $record=Get-PMMKnowledgeCandidate $item.CaseId $item.CandidateId
            if($record -and -not$record.FeedbackPrompted -and $record.PakSha256 -ceq $item.PakSha256){$candidates+=,[pscustomobject]@{CaseId=$record.CaseId;CandidateId=$record.CandidateId;Objective=$record.Objective;PakSha256=$record.PakSha256}}
        }
        if($candidates.Count){[pscustomobject]@{SessionId=$session.SessionId;ObservedSeconds=$session.ObservedSeconds;CrashAssessment=$session.CrashAssessment;Candidates=$candidates;Question='Did the solution work?';Choices=@('Worked','Failed','NotTested')}}
    }
}
function Set-PMMCandidateFeedback {
    param([string]$SessionId,[string]$CaseId,[string]$CandidateId,[ValidateSet('Worked','Failed','NotTested')][string]$Answer)
    if($SessionId -cnotmatch '^[a-f0-9]{32}$'){throw 'Invalid observation identity.'}
    $session=Read-PMMKnowledgeJson (Join-Path (Get-PMMKnowledgeRoot) ('Observations\'+$SessionId+'.json'))
    $match=@($session.Candidates|Where-Object{$_.CaseId -ceq $CaseId -and $_.CandidateId -ceq $CandidateId})
    if(-not$session -or $match.Count -ne 1 -or $session.Status -ne 'Closed'){throw 'Candidate does not belong to this observation.'}
    Invoke-PMMKnowledgeLock ($CaseId+'|'+$CandidateId) {
        $record=Get-PMMKnowledgeCandidate $CaseId $CandidateId
        if(-not$record -or $record.PakSha256 -cne $match[0].PakSha256){throw 'Feedback cannot transfer to another candidate output.'}
        $record.UserConfirmation=$Answer;$record.FeedbackPrompted=$true
        Write-PMMKnowledgeJson (Get-PMMKnowledgeCandidatePath $CaseId $CandidateId) $record;return $record
    }
}
function Set-PMMCandidateFeedbackPrompted($Group) {
    # Call immediately before showing a grouped UI. Closing it counts as No test.
    foreach($candidate in @($Group.Candidates)){Set-PMMCandidateFeedback -SessionId $Group.SessionId -CaseId $candidate.CaseId -CandidateId $candidate.CandidateId -Answer NotTested|Out-Null}
}
function Get-PMMObservationSnapshotPath([string]$GameRoot) {
    return (Join-Path (Get-PMMKnowledgeRoot) ('DeploymentSnapshots\'+(Get-PMMKnowledgeHash ([IO.Path]::GetFullPath($GameRoot).ToLowerInvariant()))+'.json'))
}
function New-PMMObservationDeploymentSnapshot([string]$GameRoot) {
    # Runs in the snapshot worker, not the WPF dispatcher.
    $GameRoot=[IO.Path]::GetFullPath($GameRoot)
    $statePath=Join-Path (Get-PMMPath 'State') 'deployment-state.json';$state=Read-PMMKnowledgeJson $statePath
    if(-not$state){throw 'There is no committed PMM deployment to observe.'}
    $stateHash=(Get-FileHash -LiteralPath $statePath).Hash.ToLowerInvariant()
    $rows=@($state.SourceMods|Where-Object{[bool](Get-PMMKnowledgeField $_ 'Deployed' $true)})
    if($state.Patch){$rows+=,$state.Patch}
    $files=@()
    foreach($row in $rows){
        $name=[string]$row.Name
        if([IO.Path]::GetFileName($name) -cne $name -or $name -notmatch '\.pak$' -or $row.Hash -notmatch '^[a-fA-F0-9]{64}$'){throw 'Invalid deployed file identity.'}
        $path=Join-Path (Join-Path $GameRoot 'Pal\Content\Paks\~mods') $name
        $file=Get-Item -LiteralPath $path -ErrorAction Stop
        $hash=(Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()
        if($hash -ine $row.Hash){throw 'Deployment differs from the committed hashes.'}
        $files+=,[pscustomobject]@{Name=$name;Sha256=$hash;Bytes=$file.Length;WriteTicks=$file.LastWriteTimeUtc.Ticks}
    }
    if((Get-FileHash -LiteralPath $statePath).Hash.ToLowerInvariant() -cne $stateHash){throw 'Deployment changed during verification.'}
    $candidates=@()
    foreach($record in @(Get-PMMKnowledgeCandidates)){
        if($record.PakSha256 -and $record.PakSha256 -cin @($files|ForEach-Object{$_.Sha256})){$candidates+=,[pscustomobject]@{CaseId=$record.CaseId;CandidateId=$record.CandidateId;PakSha256=$record.PakSha256}}
    }
    $stateFile=Get-Item -LiteralPath $statePath
    $identity=Get-PMMKnowledgeHash ($stateHash+'|'+$GameRoot.ToLowerInvariant()+'|'+(($files|Sort-Object Name|ForEach-Object{$_.Name+'|'+$_.Sha256}) -join ';'))
    $snapshot=[pscustomobject]@{Schema='PMM_OBSERVATION_DEPLOYMENT_V1';DeploymentId=$identity;GameRoot=$GameRoot;Verified=$true;VerifiedUtc=[DateTime]::UtcNow.ToString('o');StateSha256=$stateHash;StateBytes=$stateFile.Length;StateWriteTicks=$stateFile.LastWriteTimeUtc.Ticks;Files=$files;Candidates=$candidates}
    Write-PMMKnowledgeJson (Get-PMMObservationSnapshotPath $GameRoot) $snapshot;return $snapshot
}
function Test-PMMObservationSnapshotCurrent($Snapshot,[string]$GameRoot) {
    if(-not$Snapshot -or $Snapshot.Schema -ne 'PMM_OBSERVATION_DEPLOYMENT_V1' -or -not$Snapshot.Verified -or $Snapshot.GameRoot -ine [IO.Path]::GetFullPath($GameRoot)){return $false}
    $state=Get-Item -LiteralPath (Join-Path (Get-PMMPath 'State') 'deployment-state.json') -ErrorAction SilentlyContinue
    if(-not$state -or $state.Length -ne $Snapshot.StateBytes -or $state.LastWriteTimeUtc.Ticks -ne $Snapshot.StateWriteTicks){return $false}
    foreach($entry in @($Snapshot.Files)){
        if([IO.Path]::GetFileName([string]$entry.Name) -cne [string]$entry.Name){return $false}
        $file=Get-Item -LiteralPath (Join-Path (Join-Path $GameRoot 'Pal\Content\Paks\~mods') $entry.Name) -ErrorAction SilentlyContinue
        if(-not$file -or $file.Length -ne $entry.Bytes -or $file.LastWriteTimeUtc.Ticks -ne $entry.WriteTicks){return $false}
    }
    return $true
}
function Start-PMMObservationSnapshotRefresh([string]$GameRoot) {
    if(-not(Get-Variable PMMObservationSnapshotRetryAfter -Scope Script -ErrorAction SilentlyContinue)){$Script:PMMObservationSnapshotRetryAfter=[datetime]::MinValue}
    if([DateTime]::UtcNow -lt $Script:PMMObservationSnapshotRetryAfter){return}
    if($Script:PMMObservationSnapshotWorker){
        if(-not$Script:PMMObservationSnapshotWorker.HasExited){return}
        $Script:PMMObservationSnapshotWorker.Dispose();$Script:PMMObservationSnapshotWorker=$null
    }
    $Script:PMMObservationSnapshotRetryAfter=[DateTime]::UtcNow.AddSeconds(60)
    $worker=Join-Path $PSScriptRoot 'Observation.SnapshotWorker.ps1'
    $hostExe=Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
    $arguments=@('-NoProfile','-NonInteractive','-ExecutionPolicy','Bypass','-File',$worker,'-Root',$Script:Root,'-GameRoot',$GameRoot)
    $line=(@($arguments|ForEach-Object{ConvertTo-PMMNativeArgument $_}) -join ' ')
    $Script:PMMObservationSnapshotWorker=Start-Process -FilePath $hostExe -ArgumentList $line -WindowStyle Hidden -PassThru
}
function Complete-PMMGameObservation([string]$Reason='PMMClosed') {
    if(-not$Script:PMMGameObservation){return}
    $session=$Script:PMMGameObservation;$session.Status='Closed';$session.EndReason=$Reason;$session.EndedUtc=[DateTime]::UtcNow.ToString('o')
    $session.CrashAssessment=if(@($session.NewCrashes).Count){'New crash report detected during session; causation unknown'}else{'No crash detected'}
    Save-PMMObservationSession $session;$Script:PMMGameObservation=$null;return $session
}
function Update-PMMGameObservation([string]$GameRoot='') {
    if(-not$GameRoot -and (Get-Command Get-PMMConfig -ErrorAction SilentlyContinue)){$GameRoot=[string](Get-PMMConfig).GamePath}
    if(-not$GameRoot){return $null}
    $now=[DateTime]::UtcNow;$match=$null
    foreach($process in @(Get-Process -Name 'Palworld-Win64-Shipping','Palworld-WinGDK-Shipping' -ErrorAction SilentlyContinue)){
        try{
            $allowed=@((Join-Path $GameRoot 'Pal\Binaries\Win64\Palworld-Win64-Shipping.exe'),(Join-Path $GameRoot 'Pal\Binaries\WinGDK\Palworld-WinGDK-Shipping.exe'))
            if($process.Path -iin $allowed){$match=[pscustomobject]@{Id=$process.Id;StartUtc=$process.StartTime.ToUniversalTime().ToString('o')};break}
        }catch{}finally{$process.Dispose()}
    }
    $markers=@(Get-PMMObservationCrashMarkers $GameRoot)
    if($Script:PMMGameObservation){
        $session=$Script:PMMGameObservation
        $same=($session.GameRoot -ieq [IO.Path]::GetFullPath($GameRoot))
        if($match){$same=$same -and $session.ProcessId -eq $match.Id -and $session.ProcessStartUtc -ceq $match.StartUtc}
        $snapshot=Read-PMMKnowledgeJson (Get-PMMObservationSnapshotPath $session.GameRoot)
        if(-not(Test-PMMObservationSnapshotCurrent $snapshot $session.GameRoot)){$same=$false}
        $session=Update-PMMObservationSample -Session $session -Utc $now -ProcessAlive ([bool]$match) -IdentityMatches $same -CrashMarkers $markers
        if($session.Status -eq 'Closed'){Save-PMMObservationSession $session;$Script:PMMGameObservation=$null;return $session}
        $Script:PMMGameObservation=$session;Save-PMMObservationSession $session;return $session
    }
    if(-not$match){return $null}
    $snapshot=Read-PMMKnowledgeJson (Get-PMMObservationSnapshotPath $GameRoot)
    # Rehash once for each new game process, asynchronously, even if metadata is unchanged.
    if(-not(Test-PMMObservationSnapshotCurrent $snapshot $GameRoot) -or ([datetime]$snapshot.VerifiedUtc).ToUniversalTime() -lt ([datetime]$match.StartUtc).ToUniversalTime()){
        Start-PMMObservationSnapshotRefresh $GameRoot;return [pscustomobject]@{Status='VerifyingDeployment'}
    }
    $Script:PMMGameObservation=New-PMMObservationSession -GameRoot $GameRoot -ProcessId $match.Id -ProcessStartUtc $match.StartUtc -Deployment $snapshot -Utc $now -CrashBaseline $markers
    Save-PMMObservationSession $Script:PMMGameObservation
    return $Script:PMMGameObservation
}
