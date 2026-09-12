param([string]$Root=([IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))))
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$App=Join-Path $Root 'PMM'
$Script:Fixture=Join-Path ([IO.Path]::GetTempPath()) ('PMM-Knowledge-'+[guid]::NewGuid().ToString('N'))
$Script:Root=$App
$Script:Count=0
function Assert-K([bool]$Condition,[string]$Message){$Script:Count++;if(-not$Condition){throw $Message}}
function Reject-K([scriptblock]$Action,[string]$Message){$rejected=$false;try{& $Action|Out-Null}catch{$rejected=$true};Assert-K $rejected $Message}
function Get-PMMPath([string]$Key){if($Key -eq 'Workspace'){return $Script:Fixture};if($Key -eq 'State'){return (Join-Path $Script:Fixture 'State')};if($Key -eq 'Cache'){return (Join-Path $Script:Fixture 'Cache')};throw 'Unexpected path'}
function Get-LibraryRoot{return (Join-Path $Script:Fixture 'Mods')}
function Get-PMMDisabledModRoot{return (Join-Path (Get-LibraryRoot) '_Disabled')}
. (Join-Path $App 'Modules\Shared\Persistence.ps1')
. (Join-Path $App 'Modules\Knowledge\Knowledge.Service.ps1')
. (Join-Path $App 'Modules\Observations\Observation.Service.ps1')
. (Join-Path $App 'Modules\Tools\Tools.Service.ps1')
[void][IO.Directory]::CreateDirectory($Script:Fixture)
try{
    $case='AICASE-20260912-120000-abcdef12';$case2='AICASE-20260912-120000-abcdef34';$rev='EV-'+('b'*64)
    $pak=Join-Path $Script:Fixture 'candidate.pak';[IO.File]::WriteAllText($pak,'fixture candidate data')
    $recipe=@([pscustomobject]@{kind='scalar-set';asset='Pal/Content/Test.uasset';property='/Exports/0/Data/Health';expected='1';value='2'})
    $evidence=[pscustomobject]@{Sources=@([pscustomobject]@{Sha256=('a'*64);Path='C:\private\game\asset.uasset'});Conversation='must not export';Password='must not export'}
    $record=Register-PMMKnowledgeCandidate -CaseId $case -CandidateId candidate1 -EvidenceRevisionId $rev -PakPath $pak -TechnicalStatus Valid -Objective "Balance test. token=sk-privatesecretvalue" -Procedure $recipe -Evidence $evidence -Outcome Built
    Assert-K ($record.Review -eq 'Pending' -and $record.UserConfirmation -eq 'NotTested' -and $record.Observation -eq 'Unobserved') 'New candidate must remain unapproved and untested.'
    $record=Register-PMMKnowledgeCandidate -CaseId $case -CandidateId candidate1 -EvidenceRevisionId $rev -PakPath $pak -TechnicalStatus Valid -Outcome Built
    Assert-K (@($record.Attempts).Count -eq 1) 'Repeated registration should be idempotent.'
    Register-PMMKnowledgeCandidate -CaseId $case -CandidateId failed -EvidenceRevisionId $rev -TechnicalStatus Rejected -Outcome 'Build failed'|Out-Null
    Assert-K (@(Get-PMMKnowledgeCandidates $case).Count -eq 2) 'Failed attempts must be retained.'
    Assert-K (@(Get-PMMKnowledgeSuggestions $rev $case).Count -eq 0) 'A matching revision alone must not imply current source applicability.'
    $Script:KnowledgeFixtureRevision=$rev
    $Script:KnowledgeFixtureInput=Join-Path $Script:Fixture 'source.uasset'
    [IO.File]::WriteAllText($Script:KnowledgeFixtureInput,'fixture verified source')
    $Script:KnowledgeFixtureHash=(Get-FileHash -LiteralPath $Script:KnowledgeFixtureInput).Hash
    function Assert-PMMCaseInputsCurrent([string]$CaseId,[string]$RevisionId){
        if($RevisionId -cne $Script:KnowledgeFixtureRevision){throw 'Obsolete evidence.'}
        if((Get-FileHash -LiteralPath $Script:KnowledgeFixtureInput).Hash -cne $Script:KnowledgeFixtureHash){throw 'Changed source input.'}
        return $true
    }
    function Assert-PMMMCPAssetCandidate($Manifest,[string]$CaseId,[string]$Id,[string]$Dir){
        if($Manifest.caseId -cne $CaseId -or $Manifest.candidateId -cne $Id){throw 'Candidate ownership mismatch.'}
        if((Get-FileHash -LiteralPath $Script:KnowledgeFixtureInput).Hash -cne $Script:KnowledgeFixtureHash){throw 'Changed native source family.'}
    }
    Write-PMMKnowledgeJson (Join-Path $Script:Fixture 'candidate.json') ([pscustomobject]@{schema='PMM_STRUCTURED_ASSET_CANDIDATE_V1';caseId=$case;candidateId='candidate1';EvidenceRevisionId=$rev})
    Assert-K (@(Get-PMMKnowledgeSuggestions $rev $case).Count -eq 1) 'Exact evidence and verified actual source inputs should expose the experimental candidate.'
    [IO.File]::WriteAllText($Script:KnowledgeFixtureInput,'modified source')
    Assert-K (@(Get-PMMKnowledgeSuggestions $rev $case).Count -eq 0) 'Changed real source bytes must withdraw a suggestion even when saved revision did not change.'
    [IO.File]::WriteAllText($Script:KnowledgeFixtureInput,'fixture verified source')

    Assert-K (-not(Get-PMMKnowledgeSuggestions $rev $case).AutomaticEligible) 'Experimental suggestion must never enter Auto.'
    Assert-K (@(Get-PMMKnowledgeSuggestions ('EV-'+('c'*64)) $case).Count -eq 0) 'Other evidence must not match.'
    Reject-K {Register-PMMKnowledgeCandidate -CaseId $case -CandidateId candidate1 -EvidenceRevisionId 'EV-new'} 'Revision binding must be immutable.'
    Reject-K {Set-PMMKnowledgeReview $case candidate1 Approved '' ''} 'Reviews need identity and scope.'
    $review=Set-PMMKnowledgeReview $case candidate1 Approved 'fixture reviewer' 'Exact revision only'
    Assert-K ($review.Review -eq 'Approved' -and $review.UserConfirmation -eq 'NotTested') 'Review and gameplay confirmation must remain independent.'
    $published=Publish-PMMGeneratedCandidateToLibrary $case candidate1
    Assert-K (Test-Path -LiteralPath $published.LibraryPath) 'Built candidates must appear in library.'
    Assert-K ($published.LibraryPath.StartsWith((Get-PMMDisabledModRoot))) 'Generated candidate must be inactive.'
    $before=$published.LibraryPath
    Publish-PMMGeneratedCandidateToLibrary $case candidate1|Out-Null
    Assert-K (@(Get-ChildItem (Get-LibraryRoot) -Filter '*.pak' -Recurse).Count -eq 1) 'Projection must not duplicate.'
    $export=Join-Path $Script:Fixture 'contribution.json'
    $result=Export-PMMLocalKnowledgeContribution $case candidate1 $export
    Assert-K $result.Reproducible 'Scalar procedure with required hash should be reproducible with supplied inputs.'
    $json=[IO.File]::ReadAllText($export)
    Assert-K ($json -notmatch 'privatesecret|private\\|Conversation|Password|PakPath|token=|asset\.uasset') 'Export leaked private content.'
    $import=Import-PMMLocalKnowledgeContribution $export
    Assert-K (-not$import.Duplicate -and $import.Review -eq 'Pending') 'Import must remain pending despite approved original.'
    Assert-K (Import-PMMLocalKnowledgeContribution $export).Duplicate 'Import must deduplicate.'
    $importRows=@(Get-PMMImportedKnowledgeContributions -AvailableInputHashes @('a'*64))
    Assert-K ($importRows.Count -eq 1 -and $importRows[0].ReferenceMatch -eq 'Matches' -and $importRows[0].Applicability -eq 'Unknown' -and -not$importRows[0].AutomaticEligible -and $importRows[0].Review -eq 'Pending') 'Imported matching references are research leads, never approved executable recipes.'

    $reordered=$json|ConvertFrom-Json;$properties=@($reordered.contribution.PSObject.Properties)
    $reverse=[ordered]@{};for($ri=$properties.Count-1;$ri -ge 0;$ri--){$reverse[$properties[$ri].Name]=$properties[$ri].Value}
    $reordered.contribution=[pscustomobject]$reverse
    Assert-PMMKnowledgeContribution $reordered
    $reorderedPath=Join-Path $Script:Fixture 'reordered.json';Write-PMMKnowledgeJson $reorderedPath $reordered
    Assert-K (Import-PMMLocalKnowledgeContribution $reorderedPath).Duplicate 'Property order must not bypass deduplication.'
    $wrongType=$json|ConvertFrom-Json;$wrongType.contribution.outputSha256=@($wrongType.contribution.outputSha256)
    Reject-K {Assert-PMMKnowledgeContribution $wrongType} 'Scalar schema fields must reject arrays.'
    Reject-K {Get-PMMKnowledgeCandidate $case '../candidate'} 'Candidate identities must not traverse directories.'
    $envelope=$json|ConvertFrom-Json
    $envelope.contribution|Add-Member -NotePropertyName command -NotePropertyValue 'powershell' -Force
    Write-PMMKnowledgeJson (Join-Path $Script:Fixture 'malicious.json') $envelope
    Reject-K {Import-PMMLocalKnowledgeContribution (Join-Path $Script:Fixture 'malicious.json')} 'Unknown contribution fields must be rejected.'
    Reject-K {ConvertTo-PMMSafeKnowledgeProcedure @([pscustomobject]@{kind='execute';asset='Pal/Content/Test.uasset';property='x';expected='1';value='2'})} 'Executable recipes must be rejected.'
    Reject-K {ConvertTo-PMMSafeKnowledgeProcedure @([pscustomobject]@{kind='scalar-set';asset='Pal/Content/../Test.uasset';property='x';expected='1';value='2'})} 'Recipe traversal must be rejected.'
    Reject-K {ConvertTo-PMMSafeKnowledgeProcedure @([pscustomobject]@{kind='scalar-set';asset='Pal/Content/Test.uasset';property='x';expected='1';value='C:\secret'})} 'String values must not leak paths.'
    $tampered=$json|ConvertFrom-Json;$tampered.contribution.objective='changed'
    Reject-K {Assert-PMMKnowledgeContribution $tampered} 'Contribution integrity must be checked.'
    $record2=Register-PMMKnowledgeCandidate -CaseId $case2 -CandidateId candidate2 -EvidenceRevisionId $rev -PakPath $pak -TechnicalStatus Valid -Outcome Built
    $deployment=[pscustomobject]@{Verified=$true;DeploymentId='deploy1';Files=@([pscustomobject]@{Name='candidate.pak';Sha256=$record.PakSha256});Candidates=@([pscustomobject]@{CaseId=$case;CandidateId='candidate1';PakSha256=$record.PakSha256},[pscustomobject]@{CaseId=$case2;CandidateId='candidate2';PakSha256=$record.PakSha256})}
    $realUtc=[DateTime]::UtcNow
    $realSession=New-PMMObservationSession -GameRoot $Script:Fixture -ProcessId 4321 -ProcessStartUtc $realUtc.ToString('o') -Deployment $deployment -Utc $realUtc
    $realSession=Update-PMMObservationSample $realSession $realUtc.AddSeconds(15)
    Assert-K ($realSession.ObservedSeconds -eq 15) 'Real UTC samples must not gain or lose the Windows local timezone offset.'
    $utc=[datetime]'2026-09-12T12:00:00Z';$session=New-PMMObservationSession -GameRoot $Script:Fixture -ProcessId 4321 -ProcessStartUtc $utc.ToString('o') -Deployment $deployment -Utc $utc -CrashBaseline @('old-crash')
    for($i=1;$i -le 40;$i++){$session=Update-PMMObservationSample $session $utc.AddSeconds($i*15)}
    Assert-K ($session.ObservedSeconds -eq 600 -and $session.Observation -eq 'ExecutionObserved') 'Uptime must not be mislabeled played.'
    $session=Update-PMMObservationSample $session $utc.AddSeconds(1800)
    Assert-K ($session.ObservedSeconds -eq 600 -and $session.GapSeconds -eq 1200) 'Suspended/unobserved gaps must be excluded.'
    $session=Update-PMMObservationSample -Session $session -Utc $utc.AddSeconds(1815) -ProcessAlive $false -CrashMarkers @('old-crash','new-crash')
    Assert-K ($session.ObservedSeconds -eq 600 -and @($session.NewCrashes).Count -eq 1) 'Exit interval or baseline crash was incorrectly credited.'
    Save-PMMObservationSession $session
    Assert-K ((Get-PMMKnowledgeCandidate $case candidate1).UserConfirmation -eq 'NotTested') 'Crash must not accuse all candidates.'
    $pending=@(Get-PMMPendingCandidateFeedback)
    Assert-K ($pending.Count -eq 1 -and @($pending[0].Candidates).Count -eq 2) 'Feedback should group all candidates for one session.'
    Set-PMMCandidateFeedbackPrompted $pending[0]
    Assert-K (@(Get-PMMPendingCandidateFeedback).Count -eq 0) 'Feedback must only be offered once per candidate.'
    Set-PMMCandidateFeedback -SessionId $session.SessionId -CaseId $case -CandidateId candidate1 -Answer Worked|Out-Null
    $confirmed=Get-PMMKnowledgeCandidate $case candidate1
    Assert-K ($confirmed.UserConfirmation -eq 'Worked' -and $confirmed.Observation -eq 'ExecutionObserved' -and $confirmed.Review -eq 'Approved') 'Feedback changed independent evidence states.'
    Reject-K {Set-PMMCandidateFeedback -SessionId $session.SessionId -CaseId $case -CandidateId failed -Answer Worked} 'Feedback ownership must be checked.'
    Reject-K {Add-PMMObservationPlayedEvidence $session 'unverified' 'arbitrary'} 'Unvalidated adapters must not assert played.'
    $partial=New-PMMObservationSession -GameRoot $Script:Fixture -ProcessId 4321 -ProcessStartUtc $utc.ToString('o') -Deployment $deployment -Utc $utc
    $partial=Update-PMMObservationSample $partial $utc.AddSeconds(30)
    $partial=Update-PMMObservationSample -Session $partial -Utc $utc.AddSeconds(45) -IdentityMatches $false
    Assert-K ($partial.EndReason -eq 'IdentityOrDeploymentChanged' -and $partial.ObservedSeconds -eq 30) 'Process identity change must stop observation.'
    Save-PMMObservationSession $partial
    Assert-K (@(Get-PMMPendingCandidateFeedback).Count -eq 0) 'Partial sessions must not request feedback.'
    $clockSession=New-PMMObservationSession -GameRoot $Script:Fixture -ProcessId 4321 -ProcessStartUtc $utc.ToString('o') -Deployment $deployment -Utc $utc
    $clockSession=Update-PMMObservationSample $clockSession $utc.AddSeconds(15)
    $clockSession=Update-PMMObservationSample $clockSession $utc
    Assert-K ($clockSession.EndReason -eq 'ClockChanged' -and $clockSession.ObservedSeconds -eq 15) 'Clock rollback must not double count observed time.'
    $ended=New-PMMObservationSession -GameRoot $Script:Fixture -ProcessId 4321 -ProcessStartUtc $utc.ToString('o') -Deployment $deployment -Utc $utc
    $ended=Update-PMMObservationSample -Session $ended -Utc $utc.AddSeconds(15) -ProcessAlive $false
    Assert-K ($ended.ObservedSeconds -eq 0 -and $ended.CrashAssessment -eq 'No crash detected') 'Exit should retain uncertain duration and truthful crash label.'
    $preferences=Set-PMMKnowledgePreferences -FeedbackEnabled $false
    Assert-K (-not$preferences.RemoteEnabled -and $preferences.ExchangeMode -eq 'Local' -and $preferences.AutomaticContribution) 'Preferences must keep remote disabled while preserving future opt-in default.'
    Assert-K (@(Get-PMMPendingCandidateFeedback).Count -eq 0) 'Feedback disable preference was ignored.'
    $game=Join-Path $Script:Fixture 'Game';$gameMods=Join-Path $game 'Pal\Content\Paks\~mods';[void][IO.Directory]::CreateDirectory($gameMods)
    Copy-Item -LiteralPath $pak -Destination (Join-Path $gameMods 'candidate.pak')
    $state=[pscustomobject]@{SchemaVersion=3;Deployed=$utc.ToString('o');SourceMods=@([pscustomobject]@{Name='candidate.pak';Hash=$record.PakSha256;Deployed=$true});Patch=$null}
    Write-PMMKnowledgeJson (Join-Path (Get-PMMPath 'State') 'deployment-state.json') $state
    $snapshot=New-PMMObservationDeploymentSnapshot $game
    Assert-K ($snapshot.Verified -and @($snapshot.Candidates).Count -eq 2) 'Deployment must link exact installed hash to candidates.'
    Assert-K (Test-PMMObservationSnapshotCurrent $snapshot $game) 'Current snapshot rejected.'
    [IO.File]::WriteAllText((Join-Path $gameMods 'candidate.pak'),'different')
    Assert-K (-not(Test-PMMObservationSnapshotCurrent $snapshot $game)) 'Changed deployed files must invalidate the snapshot.'
    Reject-K {New-PMMObservationDeploymentSnapshot $game} 'Deployment hash mismatch must not be accepted.'
    function Get-PMMMCPEnabled{return $false}
    $capabilities=@(Get-PMMToolCapabilities)
    Assert-K ($capabilities.Count -eq 2 -and @($capabilities|Where-Object Status -ne 'PendingConfiguration').Count -eq 0) 'Unavailable tools must be shown as pending configuration.'
    Assert-K ('models' -in $capabilities[1].Unsupported -and 'animations' -in $capabilities[1].Unsupported) 'Unreal adapter must not promise unimplemented authoring.'
    $slot=Enter-PMMToolBackgroundLock -TimeoutSeconds 0
    try{Reject-K {Enter-PMMToolBackgroundLock -TimeoutSeconds 0} 'Tools must not overlap another PMM operation.'}finally{$slot.Dispose()}
    $cancelFile=Join-Path $Script:Fixture 'cancel-tool';[IO.File]::WriteAllText($cancelFile,'cancel')
    Reject-K {Enter-PMMToolBackgroundLock -CancelPath $cancelFile -TimeoutSeconds 0} 'Cancel must stop waiting for the shared operation slot.'
    Write-Output ('PASS: '+$Script:Count+' local knowledge, candidate, observation and adapter assertions (PowerShell '+$PSVersionTable.PSVersion+').')
}finally{
    $target=[IO.Path]::GetFullPath($Script:Fixture);$tempRoot=[IO.Path]::GetFullPath([IO.Path]::GetTempPath())
    if($target.StartsWith($tempRoot,[StringComparison]::OrdinalIgnoreCase) -and [IO.Path]::GetFileName($target).StartsWith('PMM-Knowledge-')){Remove-Item -LiteralPath $target -Recurse -Force}
}

