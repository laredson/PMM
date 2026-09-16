# Candidate evidence stays local; importing knowledge never authorizes execution.
function Get-PMMKnowledgeField($Object,[string]$Name,$Default=$null) {
    if($null -eq $Object){return $Default}
    if($Object -is [Collections.IDictionary]){if($Object.Contains($Name)){return $Object[$Name]}}
    elseif($Object.PSObject.Properties[$Name]){return $Object.$Name}
    return $Default
}
function Get-PMMKnowledgeRoot { return (Join-Path (Get-PMMPath 'Workspace') 'Knowledge') }
function ConvertTo-PMMKnowledgeCanonicalJson($Value) {
    if($null -eq $Value){return 'null'}
    if($Value -is [string] -or $Value -is [ValueType]){return (ConvertTo-Json -InputObject $Value -Compress)}
    if($Value -is [Collections.IDictionary]){
        $pairs=@(foreach($name in @($Value.Keys|Sort-Object -CaseSensitive)){(ConvertTo-Json -InputObject ([string]$name) -Compress)+':'+(ConvertTo-PMMKnowledgeCanonicalJson $Value[$name])})
        return ('{'+($pairs -join ',')+'}')
    }
    if($Value -is [Collections.IEnumerable]){
        $items=@(foreach($item in $Value){ConvertTo-PMMKnowledgeCanonicalJson $item})
        return ('['+($items -join ',')+']')
    }
    $pairs=@(foreach($name in @($Value.PSObject.Properties.Name|Sort-Object -CaseSensitive)){(ConvertTo-Json -InputObject ([string]$name) -Compress)+':'+(ConvertTo-PMMKnowledgeCanonicalJson $Value.$name)})
    return ('{'+($pairs -join ',')+'}')
}
function Get-PMMKnowledgeHash([string]$Text) {
    $sha=[Security.Cryptography.SHA256]::Create()
    try{return ([BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($Text)))).Replace('-','').ToLowerInvariant()}finally{$sha.Dispose()}
}
function Write-PMMKnowledgeJson([string]$Path,$Value) {
    if(-not(Get-Command Write-PMMJsonAtomic -ErrorAction SilentlyContinue)){throw 'Shared Persistence.ps1 must be loaded before Knowledge.'}
    Write-PMMJsonAtomic -Path $Path -Value $Value -Depth 40
}
function Invoke-PMMKnowledgeLock([string]$Identity,[scriptblock]$Action) {
    $mutex=[Threading.Mutex]::new($false,('Local\PMMKnowledge-'+(Get-PMMKnowledgeHash ((Get-PMMKnowledgeRoot)+$Identity))))
    $held=$false
    try{try{$held=$mutex.WaitOne(10000)}catch [Threading.AbandonedMutexException]{$held=$true};if(-not$held){throw 'Knowledge record is busy.'};& $Action}finally{if($held){$mutex.ReleaseMutex()};$mutex.Dispose()}
}
function Read-PMMKnowledgeJson([string]$Path) {
    if(-not[IO.File]::Exists($Path)){return $null}
    if((Get-Item -LiteralPath $Path).Length -gt 2MB){throw 'Knowledge record exceeds size limit.'}
    return ([IO.File]::ReadAllText($Path)|ConvertFrom-Json)
}
function Get-PMMKnowledgeCandidatePath([string]$CaseId,[string]$CandidateId) {
    if($CaseId -cnotmatch '^AICASE-[0-9]{8}-[0-9]{6}-[a-f0-9]{8}$' -or $CandidateId -cnotmatch '^[A-Za-z0-9][A-Za-z0-9_-]{0,127}$'){throw 'Invalid candidate identity.'}
    return (Join-Path (Get-PMMKnowledgeRoot) ('Candidates\'+(Get-PMMKnowledgeHash ($CaseId+'|'+$CandidateId))+'.json'))
}
function Get-PMMKnowledgeCandidate([string]$CaseId,[string]$CandidateId) {
    $record=Read-PMMKnowledgeJson (Get-PMMKnowledgeCandidatePath $CaseId $CandidateId)
    if($record -and ($record.Schema -ne 'PMM_KNOWLEDGE_CANDIDATE_V1' -or $record.CaseId -cne $CaseId -or $record.CandidateId -cne $CandidateId)){throw 'Candidate ownership mismatch.'}
    return $record
}
function Get-PMMKnowledgeCandidates([string]$CaseId='') {
    foreach($file in @(Get-ChildItem -LiteralPath (Join-Path (Get-PMMKnowledgeRoot) 'Candidates') -Filter '*.json' -File -ErrorAction SilentlyContinue)){
        $record=Read-PMMKnowledgeJson $file.FullName
        if($record.Schema -ne 'PMM_KNOWLEDGE_CANDIDATE_V1'){throw 'Unsupported knowledge candidate schema.'}
        if(-not$CaseId -or $record.CaseId -ceq $CaseId){$record}
    }
}
function Register-PMMKnowledgeCandidate {
    param([Parameter(Mandatory)][string]$CaseId,[Parameter(Mandatory)][string]$CandidateId,
        [string]$EvidenceRevisionId='', [string]$PakPath='',
        [ValidateSet('Pending','Valid','Rejected')][string]$TechnicalStatus='Pending',
        [string]$Objective='', $Procedure=@(), $Evidence=$null, [string]$Outcome='Pending')
    $path=Get-PMMKnowledgeCandidatePath $CaseId $CandidateId;$pakHash=''
    if($PakPath){
        if([IO.Path]::GetExtension($PakPath) -ine '.pak' -or -not(Test-Path -LiteralPath $PakPath -PathType Leaf)){throw 'Candidate must reference an existing PAK.'}
        $PakPath=[IO.Path]::GetFullPath($PakPath);$pakHash=(Get-FileHash -LiteralPath $PakPath -Algorithm SHA256).Hash.ToLowerInvariant()
    }
    Invoke-PMMKnowledgeLock ($CaseId+'|'+$CandidateId) {
        $record=Get-PMMKnowledgeCandidate $CaseId $CandidateId
        if($record){
            if($record.PakSha256 -and $pakHash -and $record.PakSha256 -cne $pakHash){throw 'Candidate content is immutable; register a new candidate ID.'}
            if($record.EvidenceRevisionId -and $EvidenceRevisionId -and $record.EvidenceRevisionId -cne $EvidenceRevisionId){throw 'Candidate evidence revision is immutable.'}
        }else{
            $record=[pscustomobject][ordered]@{Schema='PMM_KNOWLEDGE_CANDIDATE_V1';CaseId=$CaseId;CandidateId=$CandidateId;EvidenceRevisionId=$EvidenceRevisionId;Objective=$Objective;CreatedUtc=[DateTime]::UtcNow.ToString('o');UpdatedUtc='';PakPath=$PakPath;PakSha256=$pakHash;Procedure=@($Procedure);Evidence=$Evidence;TechnicalStatus='Pending';Observation='Unobserved';UserConfirmation='NotTested';Review='Pending';Reviewer='';ReviewedUtc='';ReviewScope='';Applicability='Unknown';Outcome=$Outcome;Attempts=@();Observations=@();FeedbackPrompted=$false;LibraryPath=''}
        }
        if($PakPath){$record.PakPath=$PakPath;$record.PakSha256=$pakHash}
        if($EvidenceRevisionId -and -not$record.EvidenceRevisionId){$record.EvidenceRevisionId=$EvidenceRevisionId}
        $record.TechnicalStatus=$TechnicalStatus;$record.Outcome=$Outcome;$record.UpdatedUtc=[DateTime]::UtcNow.ToString('o')
        $last=@($record.Attempts|Select-Object -Last 1)
        if(-not$last.Count -or $last[0].Outcome -cne $Outcome -or $last[0].TechnicalStatus -cne $TechnicalStatus){$record.Attempts=@($record.Attempts)+@([pscustomobject]@{Utc=$record.UpdatedUtc;Outcome=$Outcome;TechnicalStatus=$TechnicalStatus})}
        Write-PMMKnowledgeJson $path $record;return $record
    }
}
function Set-PMMKnowledgeReview {
    param([string]$CaseId,[string]$CandidateId,[ValidateSet('Pending','Approved','Rejected')][string]$Decision,[string]$Reviewer,[string]$Scope)
    if($Decision -ne 'Pending' -and ([string]::IsNullOrWhiteSpace($Reviewer) -or [string]::IsNullOrWhiteSpace($Scope))){throw 'Review requires a named reviewer and explicit scope.'}
    Invoke-PMMKnowledgeLock ($CaseId+'|'+$CandidateId) {
        $record=Get-PMMKnowledgeCandidate $CaseId $CandidateId;if(-not$record){throw 'Candidate not found.'}
        if($Decision -eq 'Approved' -and $record.TechnicalStatus -ne 'Valid'){throw 'Technical validation is required before approval.'}
        $record.Review=$Decision;$record.Reviewer=$Reviewer;$record.ReviewScope=$Scope;$record.ReviewedUtc=[DateTime]::UtcNow.ToString('o')
        Write-PMMKnowledgeJson (Get-PMMKnowledgeCandidatePath $CaseId $CandidateId) $record;return $record
    }
}
function Get-PMMKnowledgeSuggestions([string]$EvidenceRevisionId,[string]$CaseId='') {
    if([string]::IsNullOrWhiteSpace($EvidenceRevisionId)){return @()}
    foreach($record in @(Get-PMMKnowledgeCandidates $CaseId)){
        if($record.EvidenceRevisionId -cne $EvidenceRevisionId -or $record.TechnicalStatus -ne 'Valid' -or $record.Review -eq 'Rejected' -or -not$record.PakPath){continue}
        if(-not(Test-Path -LiteralPath $record.PakPath -PathType Leaf) -or (Get-FileHash -LiteralPath $record.PakPath).Hash -ine $record.PakSha256){continue}
        if((Test-PMMKnowledgeApplicability $record) -cne 'Matches'){continue}
        [pscustomobject]@{CaseId=$record.CaseId;CandidateId=$record.CandidateId;Applicability='Matches';Experimental=($record.Review -ne 'Approved');RequiresExplicitTrial=$true;AutomaticEligible=$false;TechnicalStatus=$record.TechnicalStatus;UserConfirmation=$record.UserConfirmation;Observation=$record.Observation;Review=$record.Review;PakPath=$record.PakPath;PakSha256=$record.PakSha256}
    }
}
function Protect-PMMContributionText([string]$Text,[int]$MaxLength=1024) {
    if($Text.Length -gt $MaxLength){$Text=$Text.Substring(0,$MaxLength)}
    $Text=[regex]::Replace($Text,'(?i)(?:[a-z]:[\\/]|\\\\)[^\r\n\t<>"'']+','[local path]')
    $Text=[regex]::Replace($Text,'(?i)(?:https?://)\S+','[link omitted]')
    $Text=[regex]::Replace($Text,'(?i)(?:api[_ -]?key|token|password|secret|authorization)\s*[:=]\s*\S+','[credential omitted]')
    $Text=[regex]::Replace($Text,'\b(?:sk-[A-Za-z0-9_-]{12,}|gh[pousr]_[A-Za-z0-9_]{12,}|github_pat_[A-Za-z0-9_]+)\b','[credential omitted]')
    return $Text
}
function Assert-PMMKnowledgeFields($Value,[string[]]$Allowed,[string[]]$Required=@()) {
    if($null -eq $Value -or $Value -is [string] -or $Value -is [ValueType]){throw 'Expected a JSON object.'}
    $names=if($Value -is [Collections.IDictionary]){@($Value.Keys)}else{@($Value.PSObject.Properties.Name)}
    foreach($name in $names){if($name -cnotin $Allowed){throw ('Unrecognized contribution field: '+$name)}}
    foreach($name in $Required){if($name -cnotin $names){throw ('Required contribution field missing: '+$name)}}
}
function ConvertTo-PMMSafeKnowledgeProcedure($Procedure) {
    $items=@($Procedure);if($items.Count -gt 64){throw 'Procedure exceeds 64 steps.'}
    foreach($step in $items){
        Assert-PMMKnowledgeFields $step @('kind','asset','property','expected','value') @('kind','asset','property','expected','value')
        foreach($field in @('kind','asset','property','expected','value')){if($step.$field -isnot [string]){throw ('Recipe field must be text: '+$field)}}
        if($step.kind -cne 'scalar-set'){throw 'Only the verified scalar-set recipe is supported.'}
        if($step.asset -cnotmatch '^Pal/Content/[A-Za-z0-9_./-]+\.uasset$' -or $step.asset -match '(?:^|/)\.{1,2}(?:/|$)' -or $step.asset.Length -gt 512){throw 'Invalid logical asset reference.'}
        if($step.property -cnotmatch '^[A-Za-z0-9_.$\[\]/:-]{1,1024}$'){throw 'Invalid scalar property path.'}
        foreach($name in @('expected','value')){if(([string]$step.$name) -cnotmatch '^(?:true|false|-?(?:0|[1-9][0-9]*)(?:\.[0-9]+)?(?:[eE][+-]?[0-9]+)?)$' -or ([string]$step.$name).Length -gt 64){throw 'Only numeric and Boolean scalar values are exportable.'}}
        [pscustomobject][ordered]@{kind='scalar-set';asset=[string]$step.asset;property=[string]$step.property;expected=[string]$step.expected;value=[string]$step.value}
    }
}
function ConvertTo-PMMKnowledgeContribution($Record) {
    $steps=@(ConvertTo-PMMSafeKnowledgeProcedure $Record.Procedure);$references=@()
    foreach($source in @(Get-PMMKnowledgeField $Record.Evidence 'Sources' @())){
        $hash=[string](Get-PMMKnowledgeField $source 'Sha256' '')
        if($hash -cnotmatch '^[a-fA-F0-9]{64}$'){continue}
        $references+=,[pscustomobject][ordered]@{sha256=$hash.ToLowerInvariant();kind='required-input'}
    }
    $references=@($references|Sort-Object sha256 -Unique)
    $evidenceId=[string]$Record.EvidenceRevisionId;if($evidenceId -cnotmatch '^[A-Za-z0-9_-]{1,128}$'){$evidenceId=''}
    $body=[pscustomobject][ordered]@{schema='PMM_KNOWLEDGE_CONTRIBUTION_V1';objective=(Protect-PMMContributionText ([string]$Record.Objective));procedure=$steps;references=$references;versions=[pscustomobject][ordered]@{contract='1';evidenceRevision=$evidenceId};outputSha256=[string]$Record.PakSha256;result=[pscustomobject][ordered]@{technical=[string]$Record.TechnicalStatus;observation=[string]$Record.Observation;confirmation=[string]$Record.UserConfirmation};reproducible=($steps.Count -gt 0 -and $references.Count -gt 0);limitations='Required inputs must be supplied locally. Hashes identify inputs; they do not contain them.'}
    $id=Get-PMMKnowledgeHash (ConvertTo-PMMKnowledgeCanonicalJson $body)
    return [pscustomobject][ordered]@{schema='PMM_KNOWLEDGE_ENVELOPE_V1';id=$id;contribution=$body}
}
function Assert-PMMKnowledgeContribution($Envelope) {
    Assert-PMMKnowledgeFields $Envelope @('schema','id','contribution') @('schema','id','contribution')
    if($Envelope.schema -isnot [string] -or $Envelope.id -isnot [string] -or $Envelope.schema -cne 'PMM_KNOWLEDGE_ENVELOPE_V1' -or $Envelope.id -cnotmatch '^[a-f0-9]{64}$'){throw 'Unsupported contribution envelope.'}
    $body=$Envelope.contribution;$fields=@('schema','objective','procedure','references','versions','outputSha256','result','reproducible','limitations')
    Assert-PMMKnowledgeFields $body $fields $fields
    if($body.schema -isnot [string] -or $body.schema -cne 'PMM_KNOWLEDGE_CONTRIBUTION_V1'){throw 'Unsupported contribution version.'}
    if($body.objective -isnot [string] -or $body.objective.Length -gt 1024 -or (Protect-PMMContributionText $body.objective) -cne $body.objective){throw 'Contribution objective contains private fields or exceeds limit.'}
    [void]@(ConvertTo-PMMSafeKnowledgeProcedure $body.procedure)
    if(@($body.references).Count -gt 256){throw 'Too many required inputs.'}
    foreach($r in @($body.references)){Assert-PMMKnowledgeFields $r @('sha256','kind') @('sha256','kind');if($r.sha256 -isnot [string] -or $r.kind -isnot [string] -or $r.sha256 -cnotmatch '^[a-f0-9]{64}$' -or $r.kind -cne 'required-input'){throw 'Invalid required input.'}}
    Assert-PMMKnowledgeFields $body.versions @('contract','evidenceRevision') @('contract','evidenceRevision')
    if($body.versions.contract -isnot [string] -or $body.versions.evidenceRevision -isnot [string] -or $body.versions.contract -cne '1' -or ($body.versions.evidenceRevision -and $body.versions.evidenceRevision -cnotmatch '^[A-Za-z0-9_-]{1,128}$')){throw 'Invalid contract version.'}
    if($body.outputSha256 -isnot [string] -or ($body.outputSha256 -and $body.outputSha256 -cnotmatch '^[a-f0-9]{64}$')){throw 'Invalid output hash.'}
    Assert-PMMKnowledgeFields $body.result @('technical','observation','confirmation') @('technical','observation','confirmation')
    foreach($field in @('technical','observation','confirmation')){if($body.result.$field -isnot [string]){throw 'Evidence state must be text.'}}
    if($body.result.technical -cnotin @('Pending','Valid','Rejected') -or $body.result.observation -cnotin @('Unobserved','ExecutionObserved','Played') -or $body.result.confirmation -cnotin @('NotTested','Worked','Failed')){throw 'Invalid evidence state.'}
    if($body.reproducible -isnot [bool] -or $body.reproducible -ne (@($body.procedure).Count -gt 0 -and @($body.references).Count -gt 0) -or $body.limitations -cne 'Required inputs must be supplied locally. Hashes identify inputs; they do not contain them.'){throw 'Invalid reproducibility claim.'}
    if((Get-PMMKnowledgeHash (ConvertTo-PMMKnowledgeCanonicalJson $body)) -cne $Envelope.id){throw 'Contribution content hash mismatch.'}
}
function Export-PMMLocalKnowledgeContribution([string]$CaseId,[string]$CandidateId,[string]$Path) {
    $record=Get-PMMKnowledgeCandidate $CaseId $CandidateId;if(-not$record){throw 'Candidate not found.'}
    $envelope=ConvertTo-PMMKnowledgeContribution $record;Assert-PMMKnowledgeContribution $envelope
    Write-PMMKnowledgeJson $Path $envelope
    return [pscustomobject]@{Id=$envelope.id;Path=$Path;Mode='Local exchange';Reproducible=$envelope.contribution.reproducible}
}
function Import-PMMLocalKnowledgeContribution([string]$Path) {
    $envelope=Read-PMMKnowledgeJson $Path;if(-not$envelope){throw 'Contribution not found.'};Assert-PMMKnowledgeContribution $envelope
    $dest=Join-Path (Get-PMMKnowledgeRoot) ('Contributions\'+$envelope.id+'.json')
    Invoke-PMMKnowledgeLock ('contribution|'+$envelope.id) {
        $existing=Read-PMMKnowledgeJson $dest
        if($existing){return [pscustomobject]@{Id=$envelope.id;Duplicate=$true;Review=$existing.Review}}
        $record=[pscustomobject]@{Schema='PMM_IMPORTED_KNOWLEDGE_V1';Id=$envelope.id;ImportedUtc=[DateTime]::UtcNow.ToString('o');Review='Pending';TechnicalStatus='Pending';Applicability='Unknown';Origin='LocalImport';Contribution=$envelope.contribution}
        Write-PMMKnowledgeJson $dest $record
        return [pscustomobject]@{Id=$envelope.id;Duplicate=$false;Review='Pending'}
    }
}
function Get-PMMKnowledgePreferences {
    $value=Read-PMMKnowledgeJson (Join-Path (Get-PMMKnowledgeRoot) 'preferences.json')
    if(-not$value){return [pscustomobject]@{Schema='PMM_KNOWLEDGE_PREFERENCES_V1';FeedbackEnabled=$true;AutomaticContribution=$true;ExchangeMode='Local';RemoteEnabled=$false}}
    $value.ExchangeMode='Local';$value.RemoteEnabled=$false;return $value
}
function Set-PMMKnowledgePreferences([bool]$FeedbackEnabled,[bool]$AutomaticContribution=$true) {
    $value=[pscustomobject]@{Schema='PMM_KNOWLEDGE_PREFERENCES_V1';FeedbackEnabled=$FeedbackEnabled;AutomaticContribution=$AutomaticContribution;ExchangeMode='Local';RemoteEnabled=$false}
    Write-PMMKnowledgeJson (Join-Path (Get-PMMKnowledgeRoot) 'preferences.json') $value;return $value
}


function Publish-PMMGeneratedCandidateToLibrary([string]$CaseId,[string]$CandidateId) {
    $record=Get-PMMKnowledgeCandidate $CaseId $CandidateId
    if(-not$record -or $record.TechnicalStatus -ne 'Valid' -or -not$record.PakSha256){throw 'A validated built candidate is required.'}
    if((Get-FileHash -LiteralPath $record.PakPath).Hash -ine $record.PakSha256){throw 'Candidate PAK content changed.'}
    # Preserve an explicit enable, move or removal by the user after publication.
    if($record.LibraryPath){return $record}
    $name='PMM_Generated_'+$record.PakSha256.Substring(0,16)+'_P.pak'
    $existing=@(Get-ChildItem -LiteralPath (Get-LibraryRoot) -Filter $name -File -Recurse -ErrorAction SilentlyContinue)
    if($existing.Count){
        if((Get-FileHash -LiteralPath $existing[0].FullName).Hash -ine $record.PakSha256){throw 'Generated library name collision.'}
        $destination=$existing[0].FullName
    }else{
        $directory=Join-Path (Get-PMMDisabledModRoot) ('Generated-'+$record.PakSha256.Substring(0,16))
        [void][IO.Directory]::CreateDirectory($directory);$destination=Join-Path $directory $name
        Copy-Item -LiteralPath $record.PakPath -Destination $destination -ErrorAction Stop
        if((Get-FileHash -LiteralPath $destination).Hash -ine $record.PakSha256){throw 'Generated library copy failed hash verification.'}
        Write-PMMKnowledgeJson (Join-Path $directory 'metadata.json') ([pscustomobject]@{Schema='PMM_GENERATED_LIBRARY_V1';CaseId=$CaseId;CandidateId=$CandidateId;EvidenceRevisionId=$record.EvidenceRevisionId;Generated=$true;Status='Generated - Pending test';Hash=$record.PakSha256;Imported=[DateTime]::UtcNow.ToString('o')})
    }
    Invoke-PMMKnowledgeLock ($CaseId+'|'+$CandidateId) {
        $latest=Get-PMMKnowledgeCandidate $CaseId $CandidateId;$latest.LibraryPath=$destination
        Write-PMMKnowledgeJson (Get-PMMKnowledgeCandidatePath $CaseId $CandidateId) $latest;return $latest
    }
}
function Sync-PMMGeneratedCandidateLibrary([string]$CaseId) {
    [void](Get-PMMKnowledgeCandidatePath $CaseId 'validate')
    # Explicit refresh/completion operation, never called by the observation timer.
    $sources=@(
        @{Root=(Join-Path $Script:Root ('Workspace\MCP\Candidates\'+$CaseId));Schema='PMM_STRUCTURED_ASSET_CANDIDATE_V1';Kind='structured'},
        @{Root=(Join-Path $Script:Root ('Workspace\AIIO\Cases\'+$CaseId+'\generated'));Schema='PMM_GENERATED_MOD_CANDIDATE_V1';Kind='unreal'}
    )
    foreach($source in $sources){
        foreach($directory in @(Get-ChildItem -LiteralPath $source.Root -Directory -ErrorAction SilentlyContinue)){
            $manifestPath=Join-Path $directory.FullName 'candidate.json';$m=Read-PMMKnowledgeJson $manifestPath
            if(-not$m){continue}
            if($m.schema -cne $source.Schema -or $m.caseId -cne $CaseId -or $m.candidateId -cne $directory.Name){throw 'Generated candidate manifest ownership mismatch.'}
            if(-not(Get-PMMKnowledgeField $m 'pakFile' '')){continue}
            $leaf=[string]$m.pakFile
            if([IO.Path]::GetFileName($leaf) -cne $leaf -or $leaf -notmatch '\.pak$'){throw 'Invalid generated PAK name.'}
            $pak=Join-Path $directory.FullName $leaf;$valid=$true;$failure=''
            try{
                if((Get-FileHash -LiteralPath $pak -ErrorAction Stop).Hash -ine $m.pakSha256){throw 'PAK hash mismatch.'}
                if($source.Kind -eq 'structured'){
                    Assert-PMMMCPAssetCandidate $m $CaseId $directory.Name $directory.FullName
                    if($m.status -ne 'CANDIDATE_BUILT'){throw 'Candidate build not completed.'}
                }else{
                    if($m.status -ne 'VALIDATED_CANDIDATE'){throw 'Unreal candidate not validated.'}
                    foreach($file in @($m.files)){
                        $path=Resolve-PMMMCPPath (Join-Path $directory.FullName 'cooked') $file.path
                        if((Get-Item -LiteralPath $path).Length -ne $file.bytes -or (Get-FileHash -LiteralPath $path).Hash -ine $file.sha256){throw 'Cooked output hash mismatch.'}
                    }
                    foreach($input in @($m.generatedSources)){
                        $path=Resolve-PMMMCPPath $directory.FullName $input.sourcePath
                        if((Get-FileHash -LiteralPath $path).Hash -ine $input.sourceSha256){throw 'Authored source hash mismatch.'}
                    }
                }
            }catch{$valid=$false;$failure=$_.Exception.Message}
            $revision=[string](Get-PMMKnowledgeField $m 'EvidenceRevisionId' '')
            $procedure=@();$evidence=[pscustomobject]@{Sources=@()}
            foreach($edit in @(Get-PMMKnowledgeField $m 'edits' @())){
                $procedure+=,[pscustomobject]@{kind='scalar-set';asset=$edit.logicalPath;property=$edit.path;expected=$edit.expected;value=$edit.value}
            }
            foreach($family in @(Get-PMMKnowledgeField $m 'sources' @())){
                foreach($part in @($family.parts)){$evidence.Sources+=,[pscustomobject]@{Sha256=$part.Sha256}}
            }
            $case=if(Get-Command Get-PMMAIIOCase -ErrorAction SilentlyContinue){Get-PMMAIIOCase $CaseId}else{$null}
            $args=@{CaseId=$CaseId;CandidateId=[string]$m.candidateId;EvidenceRevisionId=$revision;TechnicalStatus=$(if($valid){'Valid'}else{'Rejected'});Objective=[string](Get-PMMKnowledgeField $case 'Title' 'Generated candidate');Procedure=$procedure;Evidence=$evidence;Outcome=$(if($valid){'Built'}else{'Validation failed: '+$failure})}
            if($valid -and (Test-Path -LiteralPath $pak -PathType Leaf)){$args.PakPath=$pak}
            $record=Register-PMMKnowledgeCandidate @args
            if($valid){$record=Publish-PMMGeneratedCandidateToLibrary $CaseId $m.candidateId}
            $record
        }
    }
}


function Test-PMMKnowledgeApplicability($Record) {
    try{
        if(-not$Record.EvidenceRevisionId -or -not(Get-Command Assert-PMMCaseInputsCurrent -ErrorAction SilentlyContinue)){return 'Unknown'}
        Assert-PMMCaseInputsCurrent -CaseId $Record.CaseId -RevisionId $Record.EvidenceRevisionId|Out-Null
        if(-not$Record.PakPath -or -not(Test-Path -LiteralPath $Record.PakPath -PathType Leaf)){return 'Unknown'}
        $directory=[IO.Path]::GetDirectoryName($Record.PakPath)
        $manifest=Read-PMMKnowledgeJson (Join-Path $directory 'candidate.json')
        if(-not$manifest){return 'Unknown'}
        if($manifest.caseId -cne $Record.CaseId -or $manifest.candidateId -cne $Record.CandidateId -or [string](Get-PMMKnowledgeField $manifest 'EvidenceRevisionId' '') -cne $Record.EvidenceRevisionId){return 'Obsolete'}
        if($manifest.schema -eq 'PMM_STRUCTURED_ASSET_CANDIDATE_V1'){
            if(-not(Get-Command Assert-PMMMCPAssetCandidate -ErrorAction SilentlyContinue)){return 'Unknown'}
            Assert-PMMMCPAssetCandidate $manifest $Record.CaseId $Record.CandidateId $directory
        }elseif($manifest.schema -eq 'PMM_GENERATED_MOD_CANDIDATE_V1'){
            # Authored PNGs and the producing recipe are additional immutable inputs.
            foreach($source in @($manifest.generatedSources)){
                $file=Resolve-PMMMCPPath $directory $source.sourcePath
                if((Get-FileHash -LiteralPath $file).Hash -ine $source.sourceSha256){return 'Obsolete'}
            }
            $recipe=Join-Path $Script:Root 'Modules\Unreal\editor_bridge.py'
            if((Get-FileHash -LiteralPath $recipe).Hash -ine $manifest.recipeScriptSha256){return 'Obsolete'}
            if(-not(Get-Command Get-PMMUnrealEnvironment -ErrorAction SilentlyContinue)){return 'Unknown'}
            $environment=Get-PMMUnrealEnvironment
            if($environment.engineVersion -cne $manifest.engineVersion -or $environment.kitCommit -cne $manifest.kitCommit){return 'Obsolete'}
        }else{return 'Unknown'}
        if((Get-FileHash -LiteralPath $Record.PakPath).Hash -ine $Record.PakSha256){return 'Obsolete'}
        return 'Matches'
    }catch{return 'Obsolete'}
}
function Get-PMMImportedKnowledgeContributions([string[]]$AvailableInputHashes=@()) {
    foreach($file in @(Get-ChildItem -LiteralPath (Join-Path (Get-PMMKnowledgeRoot) 'Contributions') -Filter '*.json' -File -ErrorAction SilentlyContinue|Sort-Object LastWriteTimeUtc -Descending)){
        $record=Read-PMMKnowledgeJson $file.FullName
        if($record.Schema -cne 'PMM_IMPORTED_KNOWLEDGE_V1' -or $record.Id -cne [IO.Path]::GetFileNameWithoutExtension($file.Name)){throw 'Imported knowledge record identity mismatch.'}
        Assert-PMMKnowledgeContribution ([pscustomobject]@{schema='PMM_KNOWLEDGE_ENVELOPE_V1';id=$record.Id;contribution=$record.Contribution})
        $hashes=@($record.Contribution.references|ForEach-Object{$_.sha256})
        $matches=@($hashes|Where-Object{$_ -cin $AvailableInputHashes}).Count
        # A reference match is only a research lead. No imported procedure is executed.
        [pscustomobject]@{Id=$record.Id;Objective=$record.Contribution.objective;ImportedUtc=$record.ImportedUtc;Review='Pending';TechnicalStatus='Pending';Applicability='Unknown';ReferenceMatch=$(if($hashes.Count -gt 0 -and $matches -eq $hashes.Count){'Matches'}elseif($matches){'Partial'}else{'Unknown'});MatchingReferences=$matches;RequiredReferences=$hashes.Count;Reproducible=$record.Contribution.reproducible;AutomaticEligible=$false;Contribution=$record.Contribution}
    }
}


function Get-PMMGeneratedTrialStampPaths($Record) {
    $paths=[Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach($path in @($Record.PakPath,(Join-Path ([IO.Path]::GetDirectoryName($Record.PakPath)) 'candidate.json'),(Join-Path (Get-PMMPath 'State') 'config.json'),(Join-Path (Get-PMMPath 'State') 'mod-priorities.json'),(Join-Path (Get-PMMAIIOCasePath $Record.CaseId) 'case.json'),(Join-Path (Get-PMMAIIOCasePath $Record.CaseId) ('revisions\'+$Record.EvidenceRevisionId+'.json')))){if($path){[void]$paths.Add([IO.Path]::GetFullPath($path))}}
    foreach($relative in @('Resources\Mappings\Mappings.usmap','Resources\Unreal\profile.json','Modules\Unreal\editor_bridge.py','Engine\AssetTools\PMM.AssetTools.dll','Engine\AssetReader\PMM.AssetReader.dll','Workspace\Unreal\settings.json')){[void]$paths.Add((Join-Path $Script:Root $relative))}
    $library=Get-LibraryRoot;[void]$paths.Add($library)
    # Directory stamps cover additions/removals, file stamps cover replacements.
    foreach($item in @(Get-ChildItem -LiteralPath $library -Recurse -ErrorAction Stop)){if($item.PSIsContainer -or $item.Extension -ieq '.pak'){[void]$paths.Add($item.FullName)}}
    $case=Get-PMMAIIOCase $Record.CaseId
    foreach($reference in @($case.References.Mods)){$path=[string](Get-PMMKnowledgeField $reference 'Path' '');if($path){[void]$paths.Add($path)}}
    if(Get-Command Get-VanillaPakFiles -ErrorAction SilentlyContinue){
        foreach($file in @(Get-VanillaPakFiles)){[void]$paths.Add($file.FullName);[void]$paths.Add($file.DirectoryName)}
    }
    $manifest=Read-PMMKnowledgeJson (Join-Path ([IO.Path]::GetDirectoryName($Record.PakPath)) 'candidate.json')
    if($manifest.schema -eq 'PMM_STRUCTURED_ASSET_CANDIDATE_V1'){
        foreach($source in @($manifest.sources)){
            $family=Get-PMMMCPVerifiedFamily $source.logicalPath $Record.CaseId
            $base=Get-PMMMCPFamilyRoot $family
            foreach($part in @($family.Parts)){[void]$paths.Add((Resolve-PMMMCPPath $base $part.RelativePath))}
        }
    }else{
        foreach($source in @($manifest.generatedSources)){[void]$paths.Add((Resolve-PMMMCPPath ([IO.Path]::GetDirectoryName($Record.PakPath)) $source.sourcePath))}
        $environment=Get-PMMUnrealEnvironment
        if($environment.engineRoot){[void]$paths.Add((Join-Path $environment.engineRoot 'Engine\Build\Build.version'))}
    }
    return @($paths|Sort-Object)
}
function Get-PMMGeneratedTrialStamps([string[]]$Paths) {
    foreach($path in $Paths){
        $item=Get-Item -LiteralPath $path -Force -ErrorAction SilentlyContinue
        if($item -and (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0)){throw 'Candidate trial inputs cannot be links or junctions.'}
        [pscustomobject][ordered]@{Path=[IO.Path]::GetFullPath($path);Exists=[bool]$item;Directory=$(if($item){[bool]$item.PSIsContainer}else{$false});Bytes=$(if($item -and -not$item.PSIsContainer){[long]$item.Length}else{0L});WriteTicks=$(if($item){[long]$item.LastWriteTimeUtc.Ticks}else{0L})}
    }
}
function New-PMMGeneratedTrialAuthorization([string]$CaseId,[string]$CandidateId) {
    $record=Get-PMMKnowledgeCandidate $CaseId $CandidateId
    if(-not$record -or $record.TechnicalStatus -ne 'Valid' -or $record.Review -eq 'Rejected'){throw 'Candidate is not technically admissible.'}
    $name='PMM_Generated_'+$record.PakSha256.Substring(0,16)+'_P.pak'
    $copies=@(Get-ChildItem -LiteralPath (Get-LibraryRoot) -Filter $name -File -Recurse)
    if($copies.Count -ne 1){throw 'Synchronize the candidate into the library before requesting a trial.'}
    if(Get-Command Get-PMMModPriorityOrder -ErrorAction SilentlyContinue){[void]@(Get-PMMModPriorityOrder)}
    $paths=@(Get-PMMGeneratedTrialStampPaths $record)
    $before=@(Get-PMMGeneratedTrialStamps $paths)
    if((Test-PMMKnowledgeApplicability $record) -cne 'Matches'){throw 'Candidate inputs or provenance cannot be verified against the current case.'}
    if((Get-FileHash -LiteralPath $copies[0].FullName).Hash -ine $record.PakSha256){throw 'The library copy differs from the validated candidate.'}
    $after=@(Get-PMMGeneratedTrialStamps $paths)
    $digest=Get-PMMKnowledgeHash (ConvertTo-PMMKnowledgeCanonicalJson $before)
    if($digest -cne (Get-PMMKnowledgeHash (ConvertTo-PMMKnowledgeCanonicalJson $after))){throw 'Inputs changed during trial validation. Retry after the operation finishes.'}
    $token=[guid]::NewGuid().ToString('N')+[guid]::NewGuid().ToString('N')
    $tokenHash=Get-PMMKnowledgeHash $token;$expires=[DateTime]::UtcNow.AddMinutes(5).ToString('o')
    $proof=[pscustomobject]@{Schema='PMM_GENERATED_TRIAL_PROOF_V1';TokenHash=$tokenHash;CaseId=$CaseId;CandidateId=$CandidateId;PakSha256=$record.PakSha256;Name=$name;LibraryPath=$copies[0].FullName;EvidenceRevisionId=$record.EvidenceRevisionId;CreatedUtc=[DateTime]::UtcNow.ToString('o');ExpiresUtc=$expires;Consumed=$false;Stamps=$after;StampDigest=$digest}
    Write-PMMKnowledgeJson (Join-Path (Get-PMMKnowledgeRoot) ('TrialAuthorizations\'+$tokenHash+'.json')) $proof
    return [pscustomobject]@{Schema='PMM_GENERATED_TRIAL_AUTHORIZATION_V1';Token=$token;CaseId=$CaseId;CandidateId=$CandidateId;PakSha256=$record.PakSha256;EvidenceRevisionId=$record.EvidenceRevisionId;ExpiresUtc=$expires}
}
function Assert-PMMGeneratedLibraryActivation($Mod,$TrialAuthorization=$null) {
    $records=@(Get-PMMKnowledgeCandidates|Where-Object{$_.PakSha256 -and $_.PakSha256 -ieq $Mod.Hash})
    $generated=$records.Count -gt 0 -or [string]$Mod.Name -match '^PMM_Generated_[a-f0-9]{16}_P\.pak$'
    $metaPath=Join-Path ([IO.Path]::GetDirectoryName([string]$Mod.Path)) 'metadata.json'
    if(Test-Path -LiteralPath $metaPath -PathType Leaf){$meta=Read-PMMKnowledgeJson $metaPath;if([string](Get-PMMKnowledgeField $meta 'Schema' '') -eq 'PMM_GENERATED_LIBRARY_V1'){$generated=$true}}
    if(-not$generated){return $true}
    if(-not$TrialAuthorization -or [string](Get-PMMKnowledgeField $TrialAuthorization 'Schema' '') -cne 'PMM_GENERATED_TRIAL_AUTHORIZATION_V1' -or [string](Get-PMMKnowledgeField $TrialAuthorization 'Token' '') -cnotmatch '^[a-f0-9]{64}$'){throw 'Generated candidates require an explicit validated trial. Use Probar candidato in Conocimiento.'}
    $tokenHash=Get-PMMKnowledgeHash ([string]$TrialAuthorization.Token)
    Invoke-PMMKnowledgeLock ('trial|'+$tokenHash) {
        $path=Join-Path (Get-PMMKnowledgeRoot) ('TrialAuthorizations\'+$tokenHash+'.json');$proof=Read-PMMKnowledgeJson $path
        if(-not$proof -or $proof.Schema -cne 'PMM_GENERATED_TRIAL_PROOF_V1' -or $proof.TokenHash -cne $tokenHash -or $proof.Consumed -or [DateTime]::UtcNow -gt ([datetime]$proof.ExpiresUtc).ToUniversalTime()){throw 'Trial authorization expired or was already used. Validate the candidate again.'}
        if($proof.CaseId -cne $TrialAuthorization.CaseId -or $proof.CandidateId -cne $TrialAuthorization.CandidateId -or $proof.PakSha256 -ine $Mod.Hash -or $proof.Name -cne $Mod.Name -or $proof.LibraryPath -ine [IO.Path]::GetFullPath([string]$Mod.Path)){throw 'Trial authorization belongs to a different library candidate.'}
        $record=Get-PMMKnowledgeCandidate $proof.CaseId $proof.CandidateId
        if(-not$record -or $record.TechnicalStatus -ne 'Valid' -or $record.Review -eq 'Rejected' -or $record.EvidenceRevisionId -cne $proof.EvidenceRevisionId){throw 'Candidate evidence or validation changed after the trial was prepared.'}
        $stamps=@(Get-PMMGeneratedTrialStamps @($proof.Stamps|ForEach-Object{$_.Path}))
        if((Get-PMMKnowledgeHash (ConvertTo-PMMKnowledgeCanonicalJson $stamps)) -cne $proof.StampDigest){throw 'Candidate, library or input files changed after validation. Request a new trial.'}
        $proof.Consumed=$true;$proof|Add-Member -NotePropertyName ConsumedUtc -NotePropertyValue ([DateTime]::UtcNow.ToString('o')) -Force
        Write-PMMKnowledgeJson $path $proof
        return $true
    }
}
