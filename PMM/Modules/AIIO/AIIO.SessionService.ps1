<#
AIIO v2 persistent sessions and capability broker
=================================================

This module turns the original one-shot Unsupported handoff into a durable,
local-first workspace.  It never connects to an AI provider directly: PMM
prepares bounded ZIPs, validates returned data and exposes only declared
capabilities.  Arbitrary commands and returned executable code are forbidden.
#>

$Script:PMMAIIOProtocolVersion=2
$Script:PMMAIIOCapabilitySet='PMM_CAPABILITIES_V1'

function Write-PMMAIIOJsonAtomic([string]$Path,$Value,[int]$Depth=40) {
  $parent=Split-Path -Parent $Path
  if($parent -and -not(Test-Path -LiteralPath $parent -PathType Container)){New-Item -ItemType Directory -Force -Path $parent|Out-Null}
  $tmp=$Path+'.tmp.'+[guid]::NewGuid().ToString('N')
  try{
    $Value|ConvertTo-Json -Depth $Depth|Set-Content -LiteralPath $tmp -Encoding UTF8
    Move-Item -LiteralPath $tmp -Destination $Path -Force
  }finally{Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue}
}

function Get-PMMAIIOProductIdentity {
  $version='1.3.0';$build='unknown'
  $versionPath=Get-PMMMetadataPath 'VERSION.txt';$buildPath=Get-PMMMetadataPath 'BUILD_ID.txt'
  try{if(Test-Path -LiteralPath $versionPath -PathType Leaf){$version=(Get-Content -LiteralPath $versionPath -Raw -Encoding UTF8).Trim()}}catch{}
  try{if(Test-Path -LiteralPath $buildPath -PathType Leaf){$build=(Get-Content -LiteralPath $buildPath -Raw -Encoding UTF8).Trim()}}catch{}
  return [pscustomobject]@{Product='Palworld Manager Merger';Creator='laredson';Version=$version;BuildId=$build;AIIOProtocol=$Script:PMMAIIOProtocolVersion;CapabilitySet=$Script:PMMAIIOCapabilitySet}
}

function Get-PMMAIIOCapabilityRegistry {
  $capabilities=[Collections.Generic.List[object]]::new()
  # Only these Level A capabilities can be requested through the current
  # incremental ZIP transport.  The remaining entries document PMM's broker
  # model, but are not advertised as requestable work until an implementation
  # can enforce their exact target and byte budget.
  $requestable=@(
    'query_game_reference','query_knowledge','query_fixlab','read_pmm_log',
    'read_operation_state','extract_vanilla_asset','extract_provider_asset',
    'extract_asset_family','extract_relevant_log_window'
  )
  foreach($row in @(
    @('list_pak','READ','A','List files in a selected PAK without extracting arbitrary system files.'),
    @('inspect_pak','READ','A','Inspect a selected PAK inventory and metadata.'),
    @('hash_file','READ','A','Hash an allowlisted PMM, Palworld or selected-source file.'),
    @('inspect_asset','READ','A','Inspect an exact cooked asset through PMM readers.'),
    @('compare_asset_family','READ','A','Compare exact Vanilla/provider cooked families.'),
    @('query_game_reference','READ','A','Query the local Game Reference index.'),
    @('query_knowledge','READ','A','Query bundled and local PMM Knowledge.'),
    @('query_fixlab','READ','A','Inspect Fix Lab recipes, jobs and outputs.'),
    @('read_pmm_log','READ','A','Read a bounded and sanitized PMM log window.'),
    @('read_operation_state','READ','A','Read the recoverable operation journal.'),
    @('extract_vanilla_asset','EXTRACT','A','Extract one declared Vanilla file or cooked family.'),
    @('extract_provider_asset','EXTRACT','A','Extract one declared active-provider file or cooked family.'),
    @('extract_asset_family','EXTRACT','A','Extract one exact family already tied to the session.'),
    @('extract_reference_neighborhood','EXTRACT','A','Extract a bounded neighborhood from Game Reference.'),
    @('extract_relevant_log_window','EXTRACT','A','Export a sanitized time-bounded log excerpt.'),
    @('create_zip','CREATE','B','Create a data-only archive inside the AIIO session.'),
    @('create_pak','CREATE','B','Build a staged PAK from an explicitly declared cooked tree.'),
    @('create_mod_from_cooked_tree','CREATE','B','Create a staged user mod candidate; never deploy automatically.'),
    @('create_ai_handoff','CREATE','A','Create an incremental bounded handoff.'),
    @('create_full_pak_solution','CREATE','B','Stage a personal-use full PAK solution with provenance warnings.'),
    @('stage_candidate_solution','CREATE','B','Stage a validated candidate without activating it.'),
    @('create_development_patch','CREATE','B','Stage a PMM development patch against exact base hashes.'),
    @('create_git_diff','GIT','B','Prepare a local diff; no publication.'),
    @('inspect_repository','GIT','A','Inspect an explicitly selected repository.'),
    @('get_current_branch','GIT','A','Read the current local branch.'),
    @('get_base_commit','GIT','A','Read the selected repository base commit.'),
    @('inspect_local_changes','GIT','A','Read local repository status and diff metadata.'),
    @('create_development_branch','GIT','B','Create a local development branch after review.'),
    @('stage_patch','GIT','B','Apply a reviewed patch to staging, not the live PMM installation.'),
    @('prepare_contribution','GIT','B','Export a local contribution package.'),
    @('publish_branch','GIT','C','Publish only after explicit authorization and configured authentication.'),
    @('create_pull_request','GIT','C','Create a pull request only after explicit authorization.'),
    @('request_analyze','REQUEST','C','Ask the user to run Analyze.'),
    @('request_build','REQUEST','C','Ask the user to build the current plan.'),
    @('request_fixlab','REQUEST','C','Ask the user to run Fix Lab.'),
    @('request_apply_fix','REQUEST','C','Apply a Fix Lab result only after explicit confirmation.'),
    @('request_deploy','REQUEST','C','Deploy only after explicit confirmation.'),
    @('request_restore','REQUEST','C','Restore state only after explicit confirmation.')
  )){
    $capabilities.Add([pscustomobject]@{Id=$row[0];Category=$row[1];Level=$row[2];Description=$row[3];Enabled=$true;Requestable=([string]$row[0] -in $requestable)})
  }
  return [pscustomobject]@{
    Schema='PMM_CAPABILITY_REGISTRY_V1'
    Protocol=$Script:PMMAIIOProtocolVersion
    CapabilitySet=$Script:PMMAIIOCapabilitySet
    ActionLevels=[ordered]@{A='Automatic read/inspect/extract inside allowlisted PMM scopes';B='Create or stage only; never activate';C='Requires explicit user confirmation at the moment of action'}
    Capabilities=@($capabilities.ToArray())
    Never=@('execute_arbitrary_code','execute_arbitrary_shell','expose_credentials','write_outside_allowlisted_roots','deploy_returned_pak_without_validation','publish_without_explicit_authorization')
  }
}

function Get-PMMAIIOSessionRoot {
  $root=Get-PMMPath 'AIIOSessions'
  if(-not(Test-Path -LiteralPath $root -PathType Container)){New-Item -ItemType Directory -Force -Path $root|Out-Null}
  return $root
}

function Test-PMMAIIOSessionId([string]$SessionId) {
  return (-not[string]::IsNullOrWhiteSpace($SessionId) -and $SessionId -cmatch '^AIIO-[0-9]{8}-[0-9]{6}-[a-f0-9]{8}$')
}

function Get-PMMAIIOSessionPath([string]$SessionId) {
  if(-not(Test-PMMAIIOSessionId $SessionId)){throw 'Invalid AIIO session ID.'}
  return (Join-Path (Get-PMMAIIOSessionRoot) $SessionId)
}

function Get-PMMAIIOCurrentPlanSnapshot {
  $plan=$null
  try{$plan=Read-PMMMergePlan}catch{}
  if(-not$plan){return $null}
  $assets=[Collections.Generic.List[object]]::new()
  foreach($asset in @($plan.Assets)){
    $assets.Add([pscustomobject]@{
      Asset=[string]$asset.Asset
      AssetKey=[string]$asset.AssetKey
      Mode=[string]$asset.Mode
      Providers=@($asset.Providers|ForEach-Object{[string]$_})
      CaseId=$(if($asset.PSObject.Properties.Name -contains 'CaseId'){[string]$asset.CaseId}else{''})
      Reason=[string]$asset.Reason
    })
  }
  return [pscustomobject]@{
    Schema='PMM_AIIO_PLAN_SNAPSHOT_V1'
    PlanSchema=$(if($plan.PSObject.Properties.Name -contains 'Schema'){[string]$plan.Schema}else{''})
    SourceSignature=[string]$plan.SourceSignature
    MergeOrderSignature=[string]$plan.MergeOrderSignature
    EffectiveMergeOrderSignature=$(if($plan.PSObject.Properties.Name -contains 'EffectiveMergeOrderSignature'){[string]$plan.EffectiveMergeOrderSignature}else{''})
    MappingsSha256=[string]$plan.MappingsSha256
    Engine=[string]$plan.Engine
    KnowledgeRulesSha256=$(if($plan.PSObject.Properties.Name -contains 'KnowledgeRulesSha256'){[string]$plan.KnowledgeRulesSha256}else{''})
    Assets=@($assets.ToArray())
  }
}

function Get-PMMAIIOCurrentDeploymentSnapshot {
  $state=$null
  try{
    $path=Join-PMMPath 'State' 'deployment-state.json'
    if(Test-Path -LiteralPath $path -PathType Leaf){$state=Get-Content -LiteralPath $path -Raw -Encoding UTF8|ConvertFrom-Json}
  }catch{}
  if(-not$state){return [pscustomobject]@{Present=$false}}
  $managed=[Collections.Generic.List[object]]::new()
  foreach($row in @($state.ManagedFiles)){
    $managed.Add([pscustomobject]@{Name=[IO.Path]::GetFileName([string]$row.Path);Sha256=[string]$row.Sha256;Kind=[string]$row.Kind})
  }
  return [pscustomobject]@{Present=$true;UpdatedUtc=[string]$state.UpdatedUtc;SelectedPatch=[string]$state.SelectedPatch;ManagedFiles=@($managed.ToArray())}
}

function Add-PMMAIIOHistoryEvent {
  [CmdletBinding()]
  param([Parameter(Mandatory=$true)][string]$SessionId,[Parameter(Mandatory=$true)][string]$Event,[string]$Message='',$Data=$null)
  $root=Get-PMMAIIOSessionPath $SessionId
  if(-not(Test-Path -LiteralPath $root -PathType Container)){throw ('AIIO session not found: '+$SessionId)}
  $record=[ordered]@{Schema='PMM_AIIO_HISTORY_EVENT_V1';EventId=[guid]::NewGuid().ToString('N');SessionId=$SessionId;Event=$Event;Message=$Message;Utc=[DateTime]::UtcNow.ToString('o');Data=$Data}
  $line=$record|ConvertTo-Json -Depth 20 -Compress
  $path=Join-Path $root 'history.jsonl'
  $stream=[IO.File]::Open($path,[IO.FileMode]::Append,[IO.FileAccess]::Write,[IO.FileShare]::Read)
  try{$writer=[IO.StreamWriter]::new($stream,[Text.UTF8Encoding]::new($false));try{$writer.WriteLine($line);$writer.Flush();$stream.Flush($true)}finally{$writer.Dispose()}}
  finally{if($stream){$stream.Dispose()}}
  return [pscustomobject]$record
}

function Save-PMMAIIOSession($Session) {
  if(-not$Session -or -not(Test-PMMAIIOSessionId ([string]$Session.SessionId))){throw 'Cannot save an invalid AIIO session.'}
  $Session.UpdatedUtc=[DateTime]::UtcNow.ToString('o')
  $path=Join-Path (Get-PMMAIIOSessionPath ([string]$Session.SessionId)) 'session.json'
  Write-PMMAIIOJsonAtomic $path $Session 50
  return $Session
}

function Get-PMMAIIOSession([string]$SessionId) {
  if(-not(Test-PMMAIIOSessionId $SessionId)){return $null}
  $path=Join-Path (Get-PMMAIIOSessionPath $SessionId) 'session.json'
  if(-not(Test-Path -LiteralPath $path -PathType Leaf)){return $null}
  try{
    $session=Get-Content -LiteralPath $path -Raw -Encoding UTF8|ConvertFrom-Json
    if([string]$session.Schema -ne 'PMM_AIIO_SESSION_V2' -or [string]$session.SessionId -ne $SessionId){return $null}
    return $session
  }catch{return $null}
}

function Get-PMMAIIOSessions {
  $rows=[Collections.Generic.List[object]]::new()
  foreach($dir in @(Get-ChildItem -LiteralPath (Get-PMMAIIOSessionRoot) -Directory -ErrorAction SilentlyContinue|Sort-Object LastWriteTimeUtc -Descending)){
    $session=Get-PMMAIIOSession $dir.Name
    if(-not$session){continue}
    $rows.Add([pscustomobject]@{
      SessionId=[string]$session.SessionId
      Title=[string]$session.Title
      TaskType=[string]$session.TaskType
      Status=[string]$session.Status
      Iteration=[int]$session.Iteration
      UpdatedUtc=[string]$session.UpdatedUtc
      UpdatedDisplay=$(try{([DateTime]::Parse([string]$session.UpdatedUtc)).ToLocalTime().ToString('g')}catch{[string]$session.UpdatedUtc})
      Attention=[bool]$session.AttentionRequired
      Archived=[bool]$session.Archived
      Display=([string]$session.Title+'  —  '+[string]$session.Status)
    })
  }
  return @($rows.ToArray())
}

function New-PMMAIIOSession {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory=$true)][string]$Title,
    [string]$Description='',
    [ValidateSet('UNKNOWN','UNSUPPORTED_CONFLICT','MOD_NOT_WORKING','GAME_CRASH','FEATURE_MISSING','BUILD_FAILURE','DEPLOY_FAILURE','SAVE_PROBLEM','FIXLAB_FAILURE','PERFORMANCE_PROBLEM','PMM_ERROR','CREATE_MOD','MODIFY_MOD','PMM_DEVELOPMENT','THEME_DESIGN')][string]$TaskType='UNKNOWN',
    [string]$TargetKind='Palworld',
    [string]$TargetId='',
    [array]$SelectedTargets=@(),
    [array]$CaseIds=@()
  )
  if([string]::IsNullOrWhiteSpace($Title)){$Title='AI & Help task'}
  if($Title.Length -gt 120){$Title=$Title.Substring(0,120)}
  if($Description.Length -gt 20000){throw 'AIIO task description exceeds 20,000 characters.'}
  $sessionId=('AIIO-'+[DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss')+'-'+[guid]::NewGuid().ToString('N').Substring(0,8))
  $root=Get-PMMAIIOSessionPath $sessionId
  foreach($name in @('requests','responses','candidates','test-runs','contributions','artifacts')){New-Item -ItemType Directory -Force -Path (Join-Path $root $name)|Out-Null}
  $identity=Get-PMMAIIOProductIdentity
  $plan=Get-PMMAIIOCurrentPlanSnapshot
  $now=[DateTime]::UtcNow.ToString('o')
  $session=[pscustomobject][ordered]@{
    Schema='PMM_AIIO_SESSION_V2'
    Protocol=$Script:PMMAIIOProtocolVersion
    CapabilitySet=$Script:PMMAIIOCapabilitySet
    SessionId=$sessionId
    Title=$Title
    UserDescription=$Description
    TaskType=$TaskType
    Status='Draft'
    AttentionRequired=$false
    Iteration=0
    LastBundleId=''
    LastPresentedCandidate=''
    SelectedCandidateIds=@()
    SelectedTargets=@($SelectedTargets)
    PrimaryTarget=[pscustomobject]@{Kind=$TargetKind;Id=$TargetId;UserSuspects=$true;CauseConfirmed=$false}
    CaseIds=@($CaseIds|ForEach-Object{[string]$_}|Where-Object{$_}|Sort-Object -Unique)
    SourceSignature=$(if($plan){[string]$plan.SourceSignature}else{''})
    MergeOrderSignature=$(if($plan){[string]$plan.MergeOrderSignature}else{''})
    GameVersion=''
    PmmVersion=[string]$identity.Version
    PmmBuildId=[string]$identity.BuildId
    CurrentDeployment=(Get-PMMAIIOCurrentDeploymentSnapshot)
    OperationState='Idle'
    Archived=$false
    CreatedUtc=$now
    UpdatedUtc=$now
  }
  Save-PMMAIIOSession $session|Out-Null
  try{Add-PMMAIIOHistoryEvent -SessionId $sessionId -Event SESSION_CREATED -Message $Title -Data ([ordered]@{TaskType=$TaskType;TargetKind=$TargetKind;TargetId=$TargetId})|Out-Null}catch{Write-PMMLog ('AIIO session was created, but its auxiliary history event could not be written: '+$_.Exception.Message)}
  try{$cfg=Get-PMMConfig;$cfg.AIIOActiveSession=$sessionId;Save-PMMConfig $cfg}catch{}
  return $session
}

function Set-PMMAIIOSessionStatus {
  [CmdletBinding()]
  param([Parameter(Mandatory=$true)][string]$SessionId,[Parameter(Mandatory=$true)][string]$Status,[bool]$AttentionRequired=$false,[string]$Message='')
  $session=Get-PMMAIIOSession $SessionId
  if(-not$session){throw ('AIIO session not found: '+$SessionId)}
  $session.Status=$Status;$session.AttentionRequired=$AttentionRequired
  Save-PMMAIIOSession $session|Out-Null
  try{Add-PMMAIIOHistoryEvent -SessionId $SessionId -Event STATUS_CHANGED -Message $Message -Data ([ordered]@{Status=$Status;AttentionRequired=$AttentionRequired})|Out-Null}catch{Write-PMMLog ('AIIO session status was saved, but its auxiliary history event could not be written: '+$_.Exception.Message)}
  return $session
}

function Set-PMMAIIOSessionArchived([string]$SessionId,[bool]$Archived) {
  $session=Get-PMMAIIOSession $SessionId
  if(-not$session){throw ('AIIO session not found: '+$SessionId)}
  $session.Archived=$Archived
  if($Archived){$session.Status='Archived';$session.AttentionRequired=$false}
  Save-PMMAIIOSession $session|Out-Null
  try{Add-PMMAIIOHistoryEvent -SessionId $SessionId -Event $(if($Archived){'SESSION_ARCHIVED'}else{'SESSION_REOPENED'}) -Message ''|Out-Null}catch{Write-PMMLog ('AIIO archive state was saved, but its auxiliary history event could not be written: '+$_.Exception.Message)}
  return $session
}

function Get-PMMAIIOActiveSession {
  try{
    $id=[string](Get-PMMConfig).AIIOActiveSession
    $session=Get-PMMAIIOSession $id
    if($session){return $session}
  }catch{}
  $available=@((Get-PMMAIIOSessions)|Where-Object{-not[bool]$_.Archived}|Select-Object -First 1)
  if($available.Count -eq 0){return $null}
  return (Get-PMMAIIOSession ([string]$available[0].SessionId))
}

function Get-PMMAIIOUnsupportedSession {
  $plan=$null;try{$plan=Read-PMMMergePlan}catch{}
  if(-not$plan){return $null}
  $cases=@();try{$cases=@(Get-PMMAIIOCurrentCases $plan)}catch{}
  if($cases.Count -eq 0){return $null}
  $source=[string]$plan.SourceSignature
  $order=[string]$plan.MergeOrderSignature
  $caseIds=@($cases|ForEach-Object{[string]$_.Case.CaseId}|Where-Object{$_}|Sort-Object -Unique)
  foreach($row in @(Get-PMMAIIOSessions|Where-Object{-not[bool]$_.Archived -and [string]$_.TaskType -eq 'UNSUPPORTED_CONFLICT'})){
    $session=Get-PMMAIIOSession ([string]$row.SessionId)
    if(-not$session -or [string]$session.SourceSignature -ne $source -or [string]$session.MergeOrderSignature -ne $order){continue}
    $storedIds=@($session.CaseIds|ForEach-Object{[string]$_}|Where-Object{$_}|Sort-Object -Unique)
    if(($storedIds -join '|') -ceq ($caseIds -join '|')){return $session}
  }
  return (New-PMMAIIOSession -Title ('Unsupported compatibility cases ('+$cases.Count+')') -Description 'Analyze found shared asset families that PMM cannot merge automatically. Investigate exact providers and Vanilla evidence.' -TaskType UNSUPPORTED_CONFLICT -TargetKind CompatibilityPlan -TargetId $source -SelectedTargets @($cases|ForEach-Object{[pscustomobject]@{Kind='UnsupportedAsset';Id=[string]$_.Case.CaseId;LogicalPath=[string]$_.Asset;UserSuspects=$false;CauseConfirmed=$true}}) -CaseIds $caseIds)
}

function Get-PMMAIIOSafeContextManifest {
  $mods=[Collections.Generic.List[object]]::new()
  try{
    foreach($mod in @(Get-LibraryMods|Where-Object{[bool]$_.Enabled})){
      $mods.Add([pscustomobject]@{Name=[string]$mod.Name;Sha256=[string]$mod.Hash;Size=[int64]$mod.Size;Priority=[int]$mod.Priority})
    }
  }catch{}
  $interrupted=@()
  try{if(Get-Command Get-PMMInterruptedOperations -ErrorAction SilentlyContinue){$interrupted=@(Get-PMMInterruptedOperations|ForEach-Object{[pscustomobject]@{OperationId=[string]$_.OperationId;Kind=[string]$_.Kind;StartedUtc=[string]$_.StartedUtc;LastEvent=[string]$_.LastEvent;LastStep=[string]$_.LastStep;LastStatus=[string]$_.LastStatus;LastUtc=[string]$_.LastUtc;EventCount=[int]$_.EventCount}})}}catch{}
  return [pscustomobject]@{
    Schema='PMM_AIIO_CONTEXT_V1'
    Product=(Get-PMMAIIOProductIdentity)
    Plan=(ConvertTo-PMMAIIOExportPlanSnapshot (Get-PMMAIIOCurrentPlanSnapshot))
    Deployment=(ConvertTo-PMMAIIOExportDeploymentSnapshot (Get-PMMAIIOCurrentDeploymentSnapshot))
    ActiveMods=@($mods.ToArray()|ForEach-Object{[pscustomobject]@{Name=(Protect-PMMAIIOExportText ([string]$_.Name));Sha256=[string]$_.Sha256;Size=[int64]$_.Size;Priority=[int]$_.Priority}})
    InterruptedOperations=@($interrupted)
    Privacy=[ordered]@{AbsolutePathsIncluded=$false;CredentialsIncluded=$false;SaveContentsIncluded=$false;WholeSourcePaksIncluded=$false}
  }
}

function Protect-PMMAIIOExportText([string]$Text) {
  if([string]::IsNullOrEmpty($Text)){return ''}
  $value=$Text
  try{if(Get-Command Protect-PMMAIIODiagnosticText -ErrorAction SilentlyContinue){$value=Protect-PMMAIIODiagnosticText $value}}catch{}
  try{if($Script:Root){$value=$value.Replace([string]$Script:Root,'<PMM_ROOT>')}}catch{}
  try{$game=[string](Get-PMMConfig).GamePath;if($game){$value=$value.Replace($game,'<PALWORLD_ROOT>')}}catch{}
  $value=[regex]::Replace($value,'(?i)(?<![A-Za-z0-9_])[A-Z]:\\[^\r\n\t|;,]+','<local-path>')
  $value=[regex]::Replace($value,'(?<!\\)\\\\[^\r\n\t|;,]+','<network-path>')
  return $value
}

function ConvertTo-PMMAIIOExportPlanSnapshot($Plan) {
  if(-not$Plan){return $null}
  $assets=[Collections.Generic.List[object]]::new()
  foreach($asset in @($Plan.Assets)){
    $assets.Add([pscustomobject]@{Asset=(Protect-PMMAIIOExportText ([string]$asset.Asset));AssetKey=(Protect-PMMAIIOExportText ([string]$asset.AssetKey));Mode=[string]$asset.Mode;Providers=@($asset.Providers|ForEach-Object{Protect-PMMAIIOExportText ([string]$_)});CaseId=[string]$asset.CaseId;Reason=(Protect-PMMAIIOExportText ([string]$asset.Reason))})
  }
  return [pscustomobject]@{Schema='PMM_AIIO_PLAN_EXPORT_V1';PlanSchema=[string]$Plan.PlanSchema;SourceSignature=[string]$Plan.SourceSignature;MergeOrderSignature=[string]$Plan.MergeOrderSignature;EffectiveMergeOrderSignature=[string]$Plan.EffectiveMergeOrderSignature;MappingsSha256=[string]$Plan.MappingsSha256;Engine=[string]$Plan.Engine;KnowledgeRulesSha256=[string]$Plan.KnowledgeRulesSha256;Assets=@($assets.ToArray());Privacy=[ordered]@{StructuredAbsolutePathsIncluded=$false}}
}

function ConvertTo-PMMAIIOExportDeploymentSnapshot($Deployment) {
  if(-not$Deployment -or -not[bool]$Deployment.Present){return [pscustomobject]@{Present=$false}}
  return [pscustomobject]@{Present=$true;UpdatedUtc=[string]$Deployment.UpdatedUtc;SelectedPatch=(Protect-PMMAIIOExportText ([string]$Deployment.SelectedPatch));ManagedFiles=@($Deployment.ManagedFiles|ForEach-Object{[pscustomobject]@{Name=(Protect-PMMAIIOExportText ([string]$_.Name));Sha256=[string]$_.Sha256;Kind=[string]$_.Kind}});Privacy=[ordered]@{StructuredAbsolutePathsIncluded=$false}}
}

function Get-PMMAIIOOperationStateExport {
  $interrupted=[Collections.Generic.List[object]]::new()
  $recent=[Collections.Generic.List[object]]::new()
  try{
    foreach($row in @(Get-PMMInterruptedOperations)){
      $interrupted.Add([pscustomobject]@{OperationId=[string]$row.OperationId;Kind=(Protect-PMMAIIOExportText ([string]$row.Kind));StartedUtc=[string]$row.StartedUtc;LastEvent=[string]$row.LastEvent;LastStep=(Protect-PMMAIIOExportText ([string]$row.LastStep));LastStatus=(Protect-PMMAIIOExportText ([string]$row.LastStatus));LastUtc=[string]$row.LastUtc;EventCount=[int]$row.EventCount})
    }
    foreach($row in @(Get-PMMOperationJournalEvents|Select-Object -Last 200)){
      # Operation metadata may contain absolute deployment, source or staging
      # paths.  Incremental handoffs need the lifecycle, not those local paths.
      $recent.Add([pscustomobject]@{OperationId=[string]$row.OperationId;Event=[string]$row.Event;Kind=(Protect-PMMAIIOExportText ([string]$row.Kind));Step=(Protect-PMMAIIOExportText ([string]$row.Step));Status=(Protect-PMMAIIOExportText ([string]$row.Status));Utc=[string]$row.Utc})
    }
  }catch{}
  return [pscustomobject][ordered]@{Schema='PMM_OPERATION_STATE_EXPORT_V1';Interrupted=@($interrupted.ToArray());Recent=@($recent.ToArray());Privacy=[ordered]@{ProcessIdsIncluded=$false;MetadataIncluded=$false;StructuredAbsolutePathsIncluded=$false}}
}

function ConvertTo-PMMAIIOExportTarget($Target) {
  if(-not$Target){return $null}
  return [pscustomobject]@{
    Kind=(Protect-PMMAIIOExportText ([string]$Target.Kind))
    Id=(Protect-PMMAIIOExportText ([string]$Target.Id))
    LogicalPath=$(if($Target.PSObject.Properties.Name -contains 'LogicalPath'){Protect-PMMAIIOExportText ([string]$Target.LogicalPath)}else{''})
    UserSuspects=$(if($Target.PSObject.Properties.Name -contains 'UserSuspects'){[bool]$Target.UserSuspects}else{$false})
    CauseConfirmed=$(if($Target.PSObject.Properties.Name -contains 'CauseConfirmed'){[bool]$Target.CauseConfirmed}else{$false})
  }
}

function Get-PMMAIIOExportSession($Session) {
  if(-not$Session -or [string]$Session.Schema -ne 'PMM_AIIO_SESSION_V2'){throw 'A valid AIIO session is required for export.'}
  return [pscustomobject][ordered]@{
    Schema='PMM_AIIO_SESSION_EXPORT_V2';Protocol=[int]$Session.Protocol;CapabilitySet=[string]$Session.CapabilitySet;SessionId=[string]$Session.SessionId
    Title=(Protect-PMMAIIOExportText ([string]$Session.Title));UserDescription=(Protect-PMMAIIOExportText ([string]$Session.UserDescription));TaskType=[string]$Session.TaskType;Status=[string]$Session.Status
    Iteration=[int]$Session.Iteration;LastBundleId=[string]$Session.LastBundleId;PrimaryTarget=(ConvertTo-PMMAIIOExportTarget $Session.PrimaryTarget);SelectedTargets=@($Session.SelectedTargets|ForEach-Object{ConvertTo-PMMAIIOExportTarget $_})
    CaseIds=@($Session.CaseIds|ForEach-Object{[string]$_});SourceSignature=[string]$Session.SourceSignature;MergeOrderSignature=[string]$Session.MergeOrderSignature;PmmVersion=[string]$Session.PmmVersion;PmmBuildId=[string]$Session.PmmBuildId
    CurrentDeployment=(ConvertTo-PMMAIIOExportDeploymentSnapshot $Session.CurrentDeployment);OperationState=[string]$Session.OperationState;CreatedUtc=[string]$Session.CreatedUtc;UpdatedUtc=[string]$Session.UpdatedUtc
    Privacy=[ordered]@{StructuredAbsolutePathsIncluded=$false;UserTextSanitizedForKnownLocalPaths=$true;CredentialsIncluded=$false;SaveContentsIncluded=$false;WholeSourcePaksIncluded=$false}
  }
}

function Write-PMMAIIOSystemDocuments([string]$Stage,[string]$SessionId,[string]$BundleId,[int]$Iteration) {
  @"
# AI READ FIRST — Palworld Manager Merger

This package belongs to persistent AIIO session $SessionId, iteration $Iteration.
Bundle ID: $BundleId

Palworld Manager Merger (PMM) is a local mod manager, compatibility merger and
repair workbench.  Analyze is the source of truth.  Fix Lab repairs known legacy
mods.  AIIO lets an external AI investigate unknown work through declared
capabilities.  Merge remains responsible for producing the final integral
compatibility PAK, and Deploy is always a separate user-controlled action.

Read request.json, session.json, PMM_SYSTEM_CONTEXT.md, PMM_CAPABILITIES.json and
context.json before answering.  Return data using PMM_AI_RESPONSE_V2.  If more
evidence is required, request only declared capabilities and exact relative
logical paths.  Never return executable code for PMM to run and never ask PMM
to expose credentials or write outside its allowlisted workspaces.
"@|Set-Content -LiteralPath (Join-Path $Stage 'AI_READ_FIRST.md') -Encoding UTF8

  @"
# PMM system context

Product: Palworld Manager Merger
Creator: laredson
AIIO protocol: 2
Capability set: PMM_CAPABILITIES_V1

Normal user flow: Import -> Analyze -> Build -> Deploy -> Play.
Fix Lab creates and applies supported repairs before Analyze.  AI & Help handles
diagnostics, Unsupported conflicts, mod creation/modification, PMM development,
Knowledge research and iterative data exchange.

Safety boundaries:
- source PAKs are not copied wholesale into normal handoffs;
- imported AI content is declarative data and is never executed;
- Level B outputs are staged only;
- Apply Fix, enable/disable/delete, Deploy, restore and publication require an
  explicit action in PMM;
- user selections are suspicions, not confirmed causes;
- no remote upload or online AI connection exists in this build.
"@|Set-Content -LiteralPath (Join-Path $Stage 'PMM_SYSTEM_CONTEXT.md') -Encoding UTF8

  @"
# PMM AIIO response contract

Return one ZIP with response.json at its root. The response schema is
PMM_AI_RESPONSE_V2 and its sessionId, bundleId and iteration must exactly match
this request. A response may ask only for capabilities whose Requestable field
is true in PMM_CAPABILITIES.json.

Cooked-family candidate layout:
  response.json
  solutions/<candidate-id>/solution.json
  solutions/<candidate-id>/cooked/<asset-leaf>.uasset
  solutions/<candidate-id>/cooked/<asset-leaf>.uexp
  solutions/<candidate-id>/cooked/<asset-leaf>.ubulk  (only when required)

response.json candidates[] points to solutions/<candidate-id>. solution.json:
{
  "schema": "PMM_MANUAL_SOLUTION_V1",
  "caseId": "exact ID from cases/*.json",
  "asset": "exact logical asset from that case",
  "mode": "replacement-cooked-family",
  "notes": "short intended composition"
}

PMM stages every returned candidate as untrusted data. It will not execute
returned code, apply a candidate, Build, Deploy or publish anything. Only a
separate explicit user action can submit PMM_MANUAL_SOLUTION_V1 to Merge's
existing exact-case/hash/topology/AssetReader validation. Gameplay semantics
remain UNPROVEN until the user validates the resulting exact build in Palworld.
"@|Set-Content -LiteralPath (Join-Path $Stage 'PMM_RESPONSE_CONTRACT.md') -Encoding UTF8

  [ordered]@{
    schema='PMM_AI_RESPONSE_V2'
    sessionId=$SessionId
    bundleId=$BundleId
    iteration=$Iteration
    responseType='needs-data'
    allowedResponseTypes=@('needs-data','candidate-ready','mixed','not-solvable','insufficient-evidence','PMM_BUG','complete')
    summary=''
    requests=@()
    candidates=@()
  }|ConvertTo-Json -Depth 12|Set-Content -LiteralPath (Join-Path $Stage 'PMM_AI_RESPONSE_V2_TEMPLATE.json') -Encoding UTF8
}

function Test-PMMAIIOZipEntryName([string]$Name) {
  if([string]::IsNullOrWhiteSpace($Name)){return $false}
  $value=$Name.Replace([char]92,[char]47)
  if($value.StartsWith('/') -or $value.Contains([char]0) -or $value.Contains(':') -or $value.Contains('//')){return $false}
  $parts=@($value.TrimEnd([char]47).Split([char]47))
  if($parts.Count -eq 0){return $false}
  foreach($part in $parts){
    if([string]::IsNullOrWhiteSpace($part) -or $part -in @('..','.') -or $part.EndsWith('.') -or $part.EndsWith(' ')){return $false}
    $stem=([IO.Path]::GetFileNameWithoutExtension($part)).ToUpperInvariant()
    if($stem -in @('CON','PRN','AUX','NUL','COM1','COM2','COM3','COM4','COM5','COM6','COM7','COM8','COM9','LPT1','LPT2','LPT3','LPT4','LPT5','LPT6','LPT7','LPT8','LPT9')){return $false}
  }
  return $true
}

function Test-PMMAIIODataArchive([string]$ZipPath,[string]$ExpectedSessionId,[string]$ExpectedBundleId) {
  Add-Type -AssemblyName System.IO.Compression.FileSystem
  $archive=[IO.Compression.ZipFile]::OpenRead($ZipPath)
  try{
    $entries=@($archive.Entries)
    if($entries.Count -gt 2000){throw 'AIIO archive contains more than 2,000 entries.'}
    [int64]$expanded=0
    $seenNames=[Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach($entry in $entries){
      $entryName=([string]$entry.FullName).Replace([char]92,[char]47)
      if(-not(Test-PMMAIIOZipEntryName $entryName)){throw ('Unsafe AIIO archive path: '+[string]$entry.FullName)}
      if(-not$seenNames.Add($entryName)){throw ('Duplicate AIIO archive path: '+$entryName)}
      $expanded+=[int64]$entry.Length
      if($expanded -gt 2147483648){throw 'AIIO archive expands beyond the 2 GiB data-package limit.'}
      $ext=[IO.Path]::GetExtension([string]$entry.FullName).ToLowerInvariant()
      if($ext -in @('.exe','.dll','.com','.bat','.cmd','.ps1','.psm1','.psd1','.js','.jse','.vbs','.vbe','.wsf','.wsh','.hta','.msi','.msp','.scr','.cpl','.reg','.lnk','.url','.py','.pyw','.rb','.pl','.sh','.bash','.zsh','.fish')){throw ('Executable content is forbidden in AIIO data archives: '+[string]$entry.FullName)}
      $unixType=(([int64]$entry.ExternalAttributes -shr 16) -band 0xF000)
      if($unixType -eq 0xA000){throw ('Symbolic links are forbidden in AIIO archives: '+[string]$entry.FullName)}
    }
    $bundle=@($entries|Where-Object{([string]$_.FullName).Replace([char]92,[char]47) -ceq 'bundle.json'})
    if($bundle.Count -ne 1){throw 'AIIO archive must contain exactly one bundle.json at the archive root.'}
    $reader=[IO.StreamReader]::new($bundle[0].Open())
    try{$metadata=$reader.ReadToEnd()|ConvertFrom-Json}finally{$reader.Dispose()}
    if($ExpectedSessionId -and [string]$metadata.SessionId -ne $ExpectedSessionId){throw 'AIIO archive session ID does not match.'}
    if($ExpectedBundleId -and [string]$metadata.BundleId -ne $ExpectedBundleId){throw 'AIIO archive bundle ID does not match.'}
    return $metadata
  }finally{$archive.Dispose()}
}

function New-PMMAIIOGenericHandoff {
  [CmdletBinding()]
  param([Parameter(Mandatory=$true)][string]$SessionId,[switch]$IncludeSanitizedLog)
  $session=Get-PMMAIIOSession $SessionId
  if(-not$session){throw ('AIIO session not found: '+$SessionId)}
  $exportSession=Get-PMMAIIOExportSession $session
  $iteration=[int]$session.Iteration+1
  $context=Get-PMMAIIOSafeContextManifest
  $planSource=if($context.Plan){[string]$context.Plan.SourceSignature}else{''}
  $planOrder=if($context.Plan){[string]$context.Plan.MergeOrderSignature}else{''}
  $fingerprint=($SessionId+'|'+$iteration+'|'+$planSource+'|'+$planOrder+'|'+[string]$session.UserDescription)
  $bundleId=Get-PMMStableTextId ('AIIO_V2|'+$fingerprint)
  $exportSession.Iteration=$iteration;$exportSession.LastBundleId=$bundleId;$exportSession.Status='WaitingForAI';$exportSession.OperationState='WaitingForAI'
  $requestDir=Join-Path (Get-PMMAIIOSessionPath $SessionId) ('requests\request-{0:D4}' -f $iteration)
  if(Test-Path -LiteralPath $requestDir){Remove-Item -LiteralPath $requestDir -Recurse -Force}
  New-Item -ItemType Directory -Force -Path $requestDir|Out-Null
  $stage=Join-Path (Get-PMMPath 'Temp') ('AIIOV2_'+[guid]::NewGuid().ToString('N'))
  $partial=Join-Path (Get-PMMPath 'Temp') ('AIIOV2_'+$bundleId+'.zip.partial')
  $zip=Join-Path $requestDir ('PMM_AIIO_REQUEST_'+$SessionId+'_STEP_{0:D2}.zip' -f $iteration)
  $journal='';$outboxCopy='';$committed=$false
  try{
    if(Get-Command Start-PMMJournalOperation -ErrorAction SilentlyContinue){$journal=Start-PMMJournalOperation -Kind AIIOPrepare -Target $SessionId -Metadata ([ordered]@{BundleId=$bundleId;Iteration=$iteration})}
    New-Item -ItemType Directory -Force -Path $stage|Out-Null
    Set-PMMTransientStageOwner $stage 'AIIOPrepare'
    Write-PMMAIIOSystemDocuments $stage $SessionId $bundleId $iteration
    Write-PMMAIIOJsonAtomic (Join-Path $stage 'PMM_CAPABILITIES.json') (Get-PMMAIIOCapabilityRegistry) 30
    Write-PMMAIIOJsonAtomic (Join-Path $stage 'session.json') $exportSession 40
    Write-PMMAIIOJsonAtomic (Join-Path $stage 'context.json') $context 80
    $request=[ordered]@{Schema='PMM_AIIO_REQUEST_V2';SessionId=$SessionId;BundleId=$bundleId;Iteration=$iteration;TaskType=[string]$session.TaskType;Title=[string]$exportSession.Title;UserDescription=[string]$exportSession.UserDescription;PrimaryTarget=$exportSession.PrimaryTarget;SelectedTargets=@($exportSession.SelectedTargets);RequestedOutput='PMM_AI_RESPONSE_V2';CreatedUtc=[DateTime]::UtcNow.ToString('o')}
    Write-PMMAIIOJsonAtomic (Join-Path $stage 'request.json') $request 30
    $bundle=[ordered]@{Schema='PMM_AI_HANDOFF_BUNDLE_V2';Protocol=2;CapabilitySet=$Script:PMMAIIOCapabilitySet;SessionId=$SessionId;BundleId=$bundleId;Iteration=$iteration;CreatedUtc=[DateTime]::UtcNow.ToString('o');WholeSourcePaksIncluded=$false;SaveContentsIncluded=$false;CredentialsIncluded=$false;Transport='ManualZipTransport'}
    Write-PMMAIIOJsonAtomic (Join-Path $stage 'bundle.json') $bundle 20
    if($context.Plan){Write-PMMAIIOJsonAtomic (Join-Path $stage 'merge-plan-summary.json') $context.Plan 60}
    if(@($session.CaseIds).Count -gt 0){
      $caseDir=Join-Path $stage 'cases';New-Item -ItemType Directory -Force -Path $caseDir|Out-Null
      try{
        $currentPlan=Read-PMMMergePlan
        foreach($item in @(Get-PMMAIIOCurrentCases $currentPlan)){
          $case=$item.Case;if(-not$case -or [string]$case.CaseId -notin @($session.CaseIds|ForEach-Object{[string]$_})){continue}
          $exportCase=[ordered]@{Schema='PMM_AIIO_CASE_EXPORT_V1';CaseId=[string]$case.CaseId;Engine=[string]$case.Engine;EngineProfile=[string]$case.EngineProfile;CaseKind=[string]$case.CaseKind;MappingsSha256=[string]$case.MappingsSha256;VanillaAvailable=[bool]$case.VanillaAvailable;AssetKey=[string]$case.AssetKey;Asset=[string]$case.Asset;Mode=[string]$case.Mode;Reason=[string]$case.Reason;Providers=@($case.Providers);InputFiles=@($case.InputFiles);SolutionContract=[string]$case.SolutionContract}
          Write-PMMAIIOJsonAtomic (Join-Path $caseDir ([string]$case.CaseId+'.json')) $exportCase 35
        }
      }catch{Write-PMMLog ('AIIO case-summary export warning: '+$_.Exception.Message)}
    }
    if([string]$session.PrimaryTarget.Kind -eq 'DiagnosticCase' -and [string]$session.PrimaryTarget.Id -match '^DIAG-[0-9]{8}-[0-9]{6}-[a-f0-9]{8}$'){
      try{
        $diagnosticPath=Get-PMMDiagnosticCasePath ([string]$session.PrimaryTarget.Id)
        $diagnostic=Get-Content -LiteralPath $diagnosticPath -Raw -Encoding UTF8|ConvertFrom-Json -ErrorAction Stop
        $safeDiagnostic=[ordered]@{Schema='PMM_DIAGNOSTIC_CASE_EXPORT_V1';CaseId=[string]$diagnostic.CaseId;Type=[string]$diagnostic.Type;Title=(Protect-PMMAIIOExportText ([string]$diagnostic.Title));UserDescription=(Protect-PMMAIIOExportText ([string]$diagnostic.UserDescription));SelectedTargets=@($diagnostic.SelectedTargets|ForEach-Object{ConvertTo-PMMAIIOExportTarget $_});SuspectedTargets=@($diagnostic.SuspectedTargets|ForEach-Object{ConvertTo-PMMAIIOExportTarget $_});CauseConfirmed=[bool]$diagnostic.CauseConfirmed;PMM=$diagnostic.PMM;CurrentDeployment=(ConvertTo-PMMAIIOExportDeploymentSnapshot $diagnostic.CurrentDeployment);CurrentBuild=$diagnostic.CurrentBuild;Timeline=@($diagnostic.Timeline);AvailableLogs=$diagnostic.AvailableLogs;RuntimeEvidence=$diagnostic.RuntimeEvidence;SaveEvidence=@($diagnostic.SaveEvidence);PalworldLogSummary=@($diagnostic.PalworldLogSummary);KnowledgeMatches=@($diagnostic.KnowledgeMatches);RelatedPreviousErrors=@($diagnostic.RelatedPreviousErrors);Privacy=[ordered]@{StructuredAbsolutePathsIncluded=$false;UserTextSanitizedForKnownLocalPaths=$true;SaveContentsIncluded=$false;FullLogsIncluded=$false}}
        Write-PMMAIIOJsonAtomic (Join-Path $stage 'diagnostic-case.json') $safeDiagnostic 60
      }catch{Write-PMMLog ('AIIO diagnostic-case export warning: '+$_.Exception.Message)}
    }
    $knowledgeDir=Join-Path $stage 'knowledge';New-Item -ItemType Directory -Force -Path $knowledgeDir|Out-Null
    foreach($source in @(
      (Join-PMMPath 'CKLCatalog' 'case-index.json'),
      (Join-PMMPath 'CKL' 'channels.json')
    )){if(Test-Path -LiteralPath $source -PathType Leaf){Copy-Item -LiteralPath $source -Destination (Join-Path $knowledgeDir ([IO.Path]::GetFileName($source))) -Force}}
    if($IncludeSanitizedLog -and (Get-Command Get-PMMAIIOSanitizedLogWindow -ErrorAction SilentlyContinue)){
      New-Item -ItemType Directory -Force -Path (Join-Path $stage 'diagnostics')|Out-Null
      Get-PMMAIIOSanitizedLogWindow -MaximumLines 300|Set-Content -LiteralPath (Join-Path $stage 'diagnostics\pmm-log-sanitized.txt') -Encoding UTF8
    }
    $runtime=Get-PMMRuntimePath
    if(-not(Test-Path -LiteralPath $runtime -PathType Leaf)){throw 'PMMRuntime.exe is required to create AIIO packages.'}
    $output=@(& $runtime archive create $partial $stage 2>&1|ForEach-Object{[string]$_})
    if($LASTEXITCODE -ne 0 -or -not(Test-Path -LiteralPath $partial -PathType Leaf)){throw ('PMMRuntime archive create failed. '+($output -join ' '))}
    [void](Test-PMMAIIODataArchive $partial $SessionId $bundleId)
    Move-Item -LiteralPath $partial -Destination $zip -Force
    $outbox=Get-PMMPath 'AIIOOutbox';$outboxCopy=Join-Path $outbox ([IO.Path]::GetFileName($zip));Copy-Item -LiteralPath $zip -Destination $outboxCopy -Force
    $session.Iteration=$iteration;$session.LastBundleId=$bundleId;$session.Status='WaitingForAI';$session.AttentionRequired=$true;$session.OperationState='WaitingForAI'
    Save-PMMAIIOSession $session|Out-Null
    $committed=$true
    try{Add-PMMAIIOHistoryEvent -SessionId $SessionId -Event HANDOFF_CREATED -Message ([IO.Path]::GetFileName($zip)) -Data ([ordered]@{BundleId=$bundleId;Iteration=$iteration;Sha256=(Get-Sha256 $zip);Bytes=[int64](Get-Item -LiteralPath $zip).Length})|Out-Null}catch{Write-PMMLog ('AIIO handoff history warning: '+$_.Exception.Message)}
    if($journal){try{Complete-PMMJournalOperation -OperationId $journal -Kind AIIOPrepare -Metadata ([ordered]@{Zip=[IO.Path]::GetFileName($zip);Sha256=(Get-Sha256 $zip)})}catch{Write-PMMLog ('AIIO handoff journal warning: '+$_.Exception.Message)}}
    return [pscustomobject]@{SessionId=$SessionId;BundleId=$bundleId;Iteration=$iteration;ZipPath=$zip;OutboxPath=$outboxCopy;ZipSha256=(Get-Sha256 $zip);ZipBytes=[int64](Get-Item -LiteralPath $zip).Length}
  }catch{
    if($journal){try{Fail-PMMJournalOperation -OperationId $journal -Kind AIIOPrepare -Message $_.Exception.Message}catch{}}
    if(-not$committed){
      if($outboxCopy){Remove-Item -LiteralPath $outboxCopy -Force -ErrorAction SilentlyContinue}
      Remove-Item -LiteralPath $requestDir -Recurse -Force -ErrorAction SilentlyContinue
    }
    throw
  }finally{
    Remove-Item -LiteralPath $stage -Recurse -Force -ErrorAction SilentlyContinue
    Remove-PMMTransientStageOwner $stage
    Remove-Item -LiteralPath $partial -Force -ErrorAction SilentlyContinue
  }
}
