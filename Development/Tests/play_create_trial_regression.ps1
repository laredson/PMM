param([string]$Root=([IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))))
Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
$app=Join-Path $Root 'PMM'
$fixture=Join-Path ([IO.Path]::GetTempPath()) ('PMM-Trial-'+[guid]::NewGuid().ToString('N'))
$count=0
function Assert-G([bool]$Condition,[string]$Message){$script:count++;if(-not$Condition){throw $Message}}
function Reject-G([scriptblock]$Action,[string]$Message){$rejected=$false;try{& $Action|Out-Null}catch{$rejected=$true};Assert-G $rejected $Message}
[void][IO.Directory]::CreateDirectory($fixture)
try{
    Copy-Item -LiteralPath (Join-Path $app 'Modules') -Destination (Join-Path $fixture 'Modules') -Recurse
    $Script:Root=$fixture
    . (Join-Path $fixture 'Modules\Shared\Paths.ps1');Initialize-PMMPaths $fixture|Out-Null
    foreach($module in @('Shared\Common.ps1','Shared\Persistence.ps1','MCP\MCP.Service.ps1','AIIO\AIIO.SessionService.ps1','AIIO\AIIO.CaseWorkspaceService.ps1','Cases\CaseService.ps1','Library\LibraryService.ps1','Merge\PakService.ps1','Merge\MergeEngine.ps1','Knowledge\Knowledge.Service.ps1','Tools\Tools.Service.ps1')){
        . (Join-Path $fixture ('Modules\'+$module))|Out-Null
    }
    Save-PMMConfig ([pscustomobject]@{GamePath='';EngineVersion='UE5_1'})
    $case=New-PMMContextCase -Type NewMod -Title 'Trial fixture' -Description 'Synthetic input family'
    $logical='Pal/Content/Test.uasset';$source=Join-Path $fixture ('Workspace\GameReference\current\cooked\'+$logical)
    [void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($source));[IO.File]::WriteAllText($source,'original scalar fixture')
    $sourceHash=Get-Sha256 $source
    $part=[pscustomobject]@{RelativePath=$logical;Sha256=$sourceHash;Size=(Get-Item $source).Length}
    $Script:TrialFixtureFamilies=@([pscustomobject]@{Asset=$logical;Bytes=(Get-Item $source).Length;Parts=@($part)})
    # Supply a synthetic family catalog; production Get-PMMMCPVerifiedFamily still
    # verifies the actual source bytes, and the real candidate validator is used.
    function Get-PMMMCPReferenceFamilies {return $Script:TrialFixtureFamilies}
    $id='a'*32;$dir=Join-Path $fixture ('Workspace\MCP\Candidates\'+$case.CaseId+'\'+$id)
    $cooked=Join-Path $dir ('cooked\'+$logical);[void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($cooked));[IO.File]::WriteAllText($cooked,'changed scalar fixture')
    $pak=Join-Path $dir 'fixture_P.pak';[IO.File]::WriteAllText($pak,'fixture pak bytes')
    $manifest=[pscustomobject]@{schema='PMM_STRUCTURED_ASSET_CANDIDATE_V1';caseId=$case.CaseId;candidateId=$id;EvidenceRevisionId=$case.CurrentEvidenceRevision;sources=@([pscustomobject]@{logicalPath=$logical;parts=@($part)});files=@([pscustomobject]@{path=$logical;bytes=(Get-Item $cooked).Length;sha256=(Get-Sha256 $cooked)});edits=@([pscustomobject]@{logicalPath=$logical;path='/Value';expected='1';value='2'});status='CANDIDATE_BUILT';pakFile=[IO.Path]::GetFileName($pak);pakSha256=(Get-Sha256 $pak)}
    Write-PMMKnowledgeJson (Join-Path $dir 'candidate.json') $manifest
    Register-PMMKnowledgeCandidate -CaseId $case.CaseId -CandidateId $id -EvidenceRevisionId $case.CurrentEvidenceRevision -PakPath $pak -TechnicalStatus Valid -Outcome Built|Out-Null
    $record=Publish-PMMGeneratedCandidateToLibrary $case.CaseId $id
    $name=[IO.Path]::GetFileName($record.LibraryPath)
    Reject-G {Set-PMMLibraryModEnabled $name $true} 'Ordinary enable must not bypass generated trial validation.'
    Assert-G (-not(Find-PMMLibraryMod $name).Enabled) 'Blocked enable must preserve disabled placement.'
    $auth=New-PMMGeneratedTrialAuthorization $case.CaseId $id
    Assert-G ($auth.Schema -eq 'PMM_GENERATED_TRIAL_AUTHORIZATION_V1') 'Validated candidate must receive a typed trial proof.'
    $wrong=$auth|ConvertTo-Json|ConvertFrom-Json;$wrong.CandidateId='b'*32
    Reject-G {Set-PMMLibraryModEnabled $name $true -TrialAuthorization $wrong} 'Proof ownership must match candidate identity.'
    [IO.File]::WriteAllText($source,'modified scalar fixture')
    [IO.File]::SetLastWriteTimeUtc($source,[DateTime]::UtcNow.AddSeconds(2))
    Reject-G {Set-PMMLibraryModEnabled $name $true -TrialAuthorization $auth} 'Source changes after background validation must invalidate proof cheaply.'
    [IO.File]::WriteAllText($source,'original scalar fixture')
    $auth=New-PMMGeneratedTrialAuthorization $case.CaseId $id
    Set-PMMLibraryModEnabled $name $true -TrialAuthorization $auth
    Assert-G (Find-PMMLibraryMod $name).Enabled 'Confirmed validated proof must enable through the normal library setter.'
    Set-PMMLibraryModEnabled $name $false
    Reject-G {Set-PMMLibraryModEnabled $name $true -TrialAuthorization $auth} 'An activation proof must be consumed once.'
    $auth=New-PMMGeneratedTrialAuthorization $case.CaseId $id
    $proofPath=Join-Path (Get-PMMKnowledgeRoot) ('TrialAuthorizations\'+(Get-PMMKnowledgeHash $auth.Token)+'.json')
    $proof=Read-PMMKnowledgeJson $proofPath;$proof.ExpiresUtc=[DateTime]::UtcNow.AddSeconds(-1).ToString('o');Write-PMMKnowledgeJson $proofPath $proof
    Reject-G {Set-PMMLibraryModEnabled $name $true -TrialAuthorization $auth} 'Expired proof must require a fresh trial.'
    $auth=New-PMMGeneratedTrialAuthorization $case.CaseId $id
    $case.Description='Changed objective';Save-PMMAIIOCase $case|Out-Null
    Reject-G {Set-PMMLibraryModEnabled $name $true -TrialAuthorization $auth} 'Case changes during confirmation must invalidate the proof.'
    $regularDir=Join-Path (Get-PMMDisabledModRoot) 'Regular';[void][IO.Directory]::CreateDirectory($regularDir);[IO.File]::WriteAllText((Join-Path $regularDir 'regular.pak'),'ordinary user mod')
    Set-PMMLibraryModEnabled 'regular.pak' $true
    Assert-G (Find-PMMLibraryMod 'regular.pak').Enabled 'Ordinary mods must retain their existing activation behavior.'
    Write-Output ('PASS: '+$count+' generated trial gate assertions using the real library setter and source-file validator; no game deployment.')
}finally{
    $full=[IO.Path]::GetFullPath($fixture);$temp=[IO.Path]::GetFullPath([IO.Path]::GetTempPath())
    if($full.StartsWith($temp,[StringComparison]::OrdinalIgnoreCase) -and [IO.Path]::GetFileName($full).StartsWith('PMM-Trial-')){Remove-Item -LiteralPath $full -Recurse -Force}
}

