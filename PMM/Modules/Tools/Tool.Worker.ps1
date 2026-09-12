param(
    [Parameter(Mandatory)][string]$Root,
    [string]$RequestPath='',
    [Parameter(Mandatory)][string]$ResultPath,
    [ValidateSet('Tool','SyncCandidates','Capabilities','ValidateCandidate','ScanKnowledge','CreateContextCase')][string]$Mode='Tool',
    [string]$CaseId='',
    [string]$CandidateId='',
    [string]$CancelPath='',
    [string]$ProgressPath=''
)
Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
$ProgressPreference='SilentlyContinue'
$Script:Root=[IO.Path]::GetFullPath($Root)
. (Join-Path $Root 'Modules\MCP\MCP.Service.ps1')
$workspace=Resolve-PMMMCPPath $Root 'Workspace'
function Assert-ToolWorkerPath([string]$Path) {
    $full=Resolve-PMMMCPPath $Path
    if(-not$full.StartsWith($workspace+'\',[StringComparison]::OrdinalIgnoreCase)){throw 'Tool worker files must stay in PMM Workspace.'}
    return $full
}
$ResultPath=Assert-ToolWorkerPath $ResultPath
if($RequestPath){$RequestPath=Assert-ToolWorkerPath $RequestPath}
if($CancelPath){$CancelPath=Assert-ToolWorkerPath $CancelPath}
if($ProgressPath){$ProgressPath=Assert-ToolWorkerPath $ProgressPath}
$Script:PMMPaths=[ordered]@{App=$Root}
foreach($pair in @(
    @('State','Workspace\State'),@('AIIO','Workspace\AIIO'),@('AIIOSessions','Workspace\AIIO\Sessions'),
    @('GameReference','Workspace\GameReference'),@('Mappings','Resources\Mappings'),@('Metadata','Resources\Metadata'),
    @('Engine','Engine'),@('Cache','Workspace\Cache'),@('Logs','Workspace\Logs'),@('Workspace','Workspace'),@('Mods','Workspace\Mods'),
    @('Builds','Workspace\Builds'),@('ManualSolutions','Workspace\ManualSolutions'),@('Temp','Workspace\Temp'),
    @('CKL','CKL'),@('CKLStable','CKL\Stable'),@('CKLExperimental','CKL\Experimental'))){
    $Script:PMMPaths[$pair[0]]=Resolve-PMMMCPPath $Root $pair[1]
}
foreach($module in @(
    'Shared\Paths.ps1','Shared\Common.ps1','Shared\Persistence.ps1','GameReference\GameReferenceService.ps1',
    'AIIO\AIIO.SessionService.ps1','AIIO\AIIO.ModCreationService.ps1','AIIO\AIIO.CaseWorkspaceService.ps1',
    'Cases\CaseService.ps1','Library\LibraryService.ps1','Knowledge/Knowledge.Service.ps1','Tools/Tools.Service.ps1','Operations\ModuleRuntime.ps1')){
    . (Join-Path $Root ('Modules\'+$module))|Out-Null
}
$operationLock=$null;$moduleLease=$null
try{
    Initialize-PMMModuleRuntime -Root $Root|Out-Null
    if($Mode -ne 'Capabilities'){$operationLock=Enter-PMMToolBackgroundLock -CancelPath $CancelPath;$moduleLease=Start-PMMModuleOperation ('ToolWorker:'+$Mode)}
    if($CancelPath -and (Test-Path -LiteralPath $CancelPath)){throw [OperationCanceledException]::new('Cancelled before starting.')}
    switch($Mode){
        'SyncCandidates' {$output=@(Sync-PMMGeneratedCandidateLibrary $CaseId)}
        'Capabilities' {$output=@(Get-PMMToolCapabilities)}
        'CreateContextCase' {
            $input=Read-PMMKnowledgeJson $RequestPath
            Assert-PMMKnowledgeFields $input @('Type','Mods','Title','Description','Origin') @('Type','Mods','Title','Description','Origin')
            if(@($input.Mods).Count -gt 256){throw 'A context case may reference at most 256 selected mods.'}
            foreach($mod in @($input.Mods)){Assert-PMMKnowledgeFields $mod @('Name','Path','Hash','Priority','Enabled') @('Name','Path','Hash')}
            $output=New-PMMContextCase -Type $input.Type -Mods @($input.Mods) -Title $input.Title -Description $input.Description -Origin $input.Origin
        }
        'ScanKnowledge' {$output=[pscustomobject]@{Candidates=@(Get-PMMKnowledgeCandidates);Imports=@(Get-PMMImportedKnowledgeContributions)}}
        'ValidateCandidate' {
            $record=Get-PMMKnowledgeCandidate $CaseId $CandidateId
            if(-not$record){throw 'Candidate not found.'}
            $case=Get-PMMCaseContract (Get-PMMAIIOCase $CaseId)
            $matches=@(Get-PMMKnowledgeSuggestions -CaseId $CaseId -EvidenceRevisionId ([string]$case.CurrentEvidenceRevision)|Where-Object CandidateId -CEQ $CandidateId)
            if($matches.Count -ne 1){throw 'Candidate no longer matches current inputs or its provenance cannot be verified. Analyze or rebuild before a trial.'}
            $output=$matches[0]
            $output|Add-Member -NotePropertyName TrialAuthorization -NotePropertyValue (New-PMMGeneratedTrialAuthorization -CaseId $CaseId -CandidateId $CandidateId) -Force
        }
        default {
            $input=Read-PMMKnowledgeJson $RequestPath
            if(-not$input){throw 'Tool request is missing.'}
            if((Get-PMMKnowledgeField $input 'Schema' '') -eq 'PMM_TOOL_REQUEST_V1'){
                $request=$input
            }else{
                # UI can submit a minimal request; resolve provider and revision here.
                Assert-PMMKnowledgeFields $input @('AdapterId','Operation','CaseId','Arguments') @('AdapterId','Operation','CaseId','Arguments')
                $request=New-PMMToolRequest $input.AdapterId $input.Operation $input.CaseId $input.Arguments
            }
            $output=Invoke-PMMToolOperation -Request $request -ProgressCallback {
                param($progress)
                if($ProgressPath){Write-PMMKnowledgeJson $ProgressPath $progress}
            } -CancellationRequested {return ($CancelPath -and (Test-Path -LiteralPath $CancelPath))}
        }
    }
    Write-PMMKnowledgeJson $ResultPath ([pscustomobject]@{Schema='PMM_TOOL_WORKER_RESULT_V1';Status=$(if((Get-PMMKnowledgeField $output 'Status' '') -eq 'Cancelled'){'Cancelled'}else{'Complete'});Mode=$Mode;Result=$output;CompletedUtc=[DateTime]::UtcNow.ToString('o')})
}catch{
    $cancelled=$_.Exception -is [OperationCanceledException] -or ($CancelPath -and (Test-Path -LiteralPath $CancelPath))
    Write-PMMKnowledgeJson $ResultPath ([pscustomobject]@{Schema='PMM_TOOL_WORKER_RESULT_V1';Status=$(if($cancelled){'Cancelled'}else{'Failed'});Mode=$Mode;Error=$_.Exception.Message;CompletedUtc=[DateTime]::UtcNow.ToString('o')})
    exit 1
}
finally{if($moduleLease){Complete-PMMModuleOperation $moduleLease.Id};if($operationLock){$operationLock.Dispose()}}
