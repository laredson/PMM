function Get-PMMRepairSessionRoot([string]$Id) {
  if($Id -notmatch '^RS-[a-f0-9]{32}$'){throw 'Invalid repair session.'}
  return (Join-PMMPath 'Workspace' ('RepairSessions/'+$Id))
}
function Get-PMMRepairSession([string]$Id){return (Read-PMMJsonFile (Join-Path (Get-PMMRepairSessionRoot $Id) 'session.json') -Schema PMM_REPAIR_SESSION_V1)}

function New-PMMRepairSession([string]$CaseId,$Options) {
  Assert-PMMDeepOptions $Options
  $case=Get-PMMAIIOCase $CaseId
  if(-not$case -or -not$case.CurrentEvidenceRevision){throw 'A case with current evidence is required.'}
  $session=[pscustomobject]@{Schema='PMM_REPAIR_SESSION_V1';Id=('RS-'+[guid]::NewGuid().ToString('N'));CaseId=$CaseId;EvidenceRevision=$case.CurrentEvidenceRevision;Status='Ready';Phase='CheckUpdates';CreatedUtc=[DateTime]::UtcNow.ToString('o');Options=$Options;Authorization=@{Research=$true;Download=[bool]$Options.AutomaticSolution;Build=[bool]$Options.AutomaticSolution;Deploy=[bool]$Options.AllowDeploy;Game=[bool]$Options.AllowGame;World=[bool]$Options.TestWorld;Isolate=[bool]$Options.Isolate;Dependencies=[bool]$Options.AllowDependencies;PublishRemote=[bool]$Options.PublishRemote};ActiveSeconds=0;Candidates=@();TestRuns=@();Attempts=@();Recovery=@();ThreadId='';LastMessage='';OwnerPid=0;OwnerStart='';Revoked=$false;PreserveFunctions=$true}
  Save-PMMRepairSession $session
  return $session
}
function Assert-PMMRepairAuthorization([string]$Id,[string]$CaseId,[string]$Revision,[string]$Capability) {
  $s=Get-PMMRepairSession $Id;$case=Get-PMMAIIOCase $CaseId
  if($s.CaseId -cne $CaseId -or $s.EvidenceRevision -cne $Revision -or $case.CurrentEvidenceRevision -cne $Revision){throw 'Case evidence changed; renew the repair session from current evidence.'}
  Assert-PMMRepairEvidenceCurrent $s
  if($s.Revoked -or $s.Status -in @('Cancelled','Restoring','Restored','RecoveryBlocked','Complete')){throw 'Repair authorization is no longer active.'}
  if(-not[bool](Get-PMMAnalysisValue $s.Authorization $Capability $false)){throw ('Session does not authorize '+$Capability+'.')}
  if($s.ActiveSeconds -ge ([int]$s.Options.MaxActiveMinutes*60)){throw 'Session time limit reached; work is preserved.'}
  if($Capability -eq 'Game' -and @($s.TestRuns).Count -ge $s.Options.MaxTestRuns){throw 'Game execution limit reached.'}
  $bytes=(@(Get-ChildItem -LiteralPath (Get-PMMRepairSessionRoot $Id) -Recurse -File|Measure-Object Length -Sum)[0]).Sum
  if($bytes -gt [double]$s.Options.MaxDiskGiB*1GB){throw 'Session disk limit reached; recovery data is preserved.'}
  return $s
}
function Add-PMMRepairAttempt([string]$Id,[string]$Kind,$Inputs,[string]$Outcome,[string]$Detail='') {
  $s=Get-PMMRepairSession $Id;$fingerprint=Get-PMMAnalysisHash @($s.EvidenceRevision,$Kind,$Inputs)
  $existing=@($s.Attempts|Where-Object{$_.Fingerprint -eq $fingerprint})
  if($existing.Count){return $existing[0]}
  $attempt=[pscustomobject]@{Fingerprint=$fingerprint;Kind=$Kind;Inputs=$Inputs;Outcome=$Outcome;Detail=$Detail;Utc=[DateTime]::UtcNow.ToString('o')}
  $s.Attempts=@($s.Attempts)+@($attempt);Save-PMMRepairSession $s;return $attempt
}
function Get-PMMRuntimeCapabilities {
  return [pscustomobject]@{Schema='PMM_RUNTIME_CAPABILITIES_V1';ObserveUserSession=$true;Launch=$false;TemporaryWorld=$false;AutomaticWorldEntry=$false;AutomaticIsolation=$false;Reason='No adapter has yet proved isolated saves, configuration and cloud synchronization for this game build. Manual observation and staged candidates are available.';RequiredEvidence=@('Isolated save and configuration paths','Cloud-sync isolation','Verified menu/world signals','Original configuration restored');RemoteKnowledgeReceiver=$false}
}
function New-PMMTestRun([string]$SessionId,[string[]]$SourceHashes,[string]$PatchHash='', [string]$Scenario='World') {
  $s=Get-PMMRepairSession $SessionId
  Assert-PMMRepairAuthorization $SessionId $s.CaseId $s.EvidenceRevision Research|Out-Null
  if(@($s.TestRuns).Count -ge $s.Options.MaxTestRuns){throw 'Test run limit reached; history was preserved.'}
  $run=[pscustomobject]@{Schema='PMM_TEST_RUN_V1';Id=('TR-'+[guid]::NewGuid().ToString('N'));SessionId=$SessionId;EvidenceRevision=$s.EvidenceRevision;SourceHashes=@($SourceHashes|Sort-Object);PatchHash=$PatchHash;Scenario=$Scenario;ProcessId=0;ProcessStartUtc='';StartedUtc=[DateTime]::UtcNow.ToString('o');EndedUtc='';State='Prepared';FailureSignature='';Signals=@();FunctionsVerified=$false;Observer='PMM';RequestedStop=$false}
  $s.TestRuns=@($s.TestRuns)+@($run.Id);Save-PMMRepairSession $s
  Write-PMMJsonAtomic (Join-Path (Get-PMMRepairSessionRoot $SessionId) ($run.Id+'.json')) $run
  return $run
}
function Update-PMMTestRun($Run,[ValidateSet('ProcessStarted','Menu','WorldLoading','WorldLoaded','FunctionPassed','Crash','Exit','Timeout','Cancel','Restoring','Restored')][string]$Signal,[string]$EvidenceId,[string]$Utc,[string]$FailureSignature='',[switch]$Manual) {
  if(-not$EvidenceId){throw 'A runtime signal requires evidence.'}
  if([DateTime]$Utc -lt [DateTime]$Run.StartedUtc){throw 'Old evidence cannot be attached to this execution.'}
  if($Run.State -in @('Restored','Crash','Timeout','Cancelled','ExitedUnknown') -and $Signal -notin @('Restoring','Restored')){throw 'This execution is already terminal.'}
  if($Signal -eq 'FunctionPassed' -and $Run.State -ne 'FunctionalCheckPending'){throw 'Verify world entry before its gameplay function.'}
  $Run.Signals=@($Run.Signals)+@(@{Signal=$Signal;EvidenceId=$EvidenceId;Utc=$Utc;Manual=[bool]$Manual})
  switch($Signal){
    ProcessStarted {$Run.State='ProcessStarted'}
    Menu {$Run.State='MenuDetected'}
    WorldLoading {$Run.State='LoadingWorld'}
    WorldLoaded {$Run.State='FunctionalCheckPending'}
    FunctionPassed {if($Run.State -ne 'FunctionalCheckPending'){throw 'Verify world entry before its gameplay function.'};$Run.State='ScenarioPassed';$Run.FunctionsVerified=$true}
    Crash {if($Run.RequestedStop){$Run.State='StoppedByPMM'}else{$Run.State='Crash';$Run.FailureSignature=$FailureSignature};$Run.EndedUtc=$Utc}
    Exit {$Run.State=if($Run.RequestedStop){'StoppedByPMM'}else{'ExitedUnknown'};$Run.EndedUtc=$Utc}
    Timeout {$Run.State='Timeout';$Run.EndedUtc=$Utc}
    Cancel {$Run.State='Cancelled';$Run.RequestedStop=$true;$Run.EndedUtc=$Utc}
    Restoring {$Run.State='Restoring'}
    Restored {$Run.State='Restored';$Run.EndedUtc=$Utc}
  }
  return $Run
}
function Get-PMMIsolationSubsets([string[]]$Mods,$Dependencies) {
  $ordered=@($Mods|Sort-Object -Unique)
  function Expand-PMMDependencyClosure([string[]]$Seeds) {
    $set=[Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    $queue=[Collections.Generic.Queue[string]]::new();foreach($seed in $Seeds){$queue.Enqueue($seed)}
    while($queue.Count){$name=$queue.Dequeue();if(-not$set.Add($name)){continue};foreach($dep in @(Get-PMMAnalysisValue $Dependencies $name @())){if($dep -notin $ordered){throw ('Missing dependency '+$dep+' required by '+$name)};$queue.Enqueue([string]$dep)}}
    return @($set|Sort-Object)
  }
  $seen=@{}
  for($parts=2;$parts -le [Math]::Max(2,$ordered.Count);$parts*=2){
    $size=[Math]::Max(1,[int][Math]::Ceiling($ordered.Count/[double]$parts))
    for($start=0;$start -lt $ordered.Count;$start+=$size){
      $chunk=@($ordered[$start..([Math]::Min($ordered.Count-1,$start+$size-1))])
      foreach($seeds in @(@($chunk),@($ordered|Where-Object{$_ -notin $chunk}))){
        $subset=@(Expand-PMMDependencyClosure $seeds);$key=$subset -join '|'
        if(-not$seen.ContainsKey($key)){$seen[$key]=$true;[pscustomobject]@{Mods=$subset;Fingerprint=(Get-PMMAnalysisHash $subset);PatchPolicy='RebuildForExactSubset';Outcome='Untested'}}
      }
    }
    if($size -eq 1){break}
  }
}
function Stop-PMMRepairSession([string]$Id) {
  $s=Get-PMMRepairSession $Id;$s.Revoked=$true;$s.Status='Cancelled';$s.LastMessage='Cancellation requested. New mutations are blocked; preserved recovery records must finish.'
  Save-PMMRepairSession $s
  [IO.File]::WriteAllText((Join-Path (Get-PMMRepairSessionRoot $Id) 'cancel'),'cancel')
  foreach($recovery in @($s.Recovery)){
    try{Repair-PMMDeploymentRecord -Path $recovery.Path -GameMods $recovery.GameMods|Out-Null}
    catch{$s.Status='RecoveryBlocked';$s.LastMessage=$_.Exception.Message;Save-PMMRepairSession $s;throw}
  }
  return $s
}
function Start-PMMRepairAgentJob([string]$SessionId) {
  $s=Get-PMMRepairSession $SessionId
  if($s.OwnerPid){
    $p=Get-Process -Id $s.OwnerPid -ErrorAction SilentlyContinue
    if($p -and $p.StartTime.ToUniversalTime().ToString('o') -eq $s.OwnerStart){return $s}
  }
  $worker=Join-Path $Script:Root 'Modules/Analysis/Repair.Worker.ps1'
  $arguments=@('-NoProfile','-ExecutionPolicy','Bypass','-File',$worker,'-Root',$Script:Root,'-SessionId',$SessionId)
  $line=(@($arguments|ForEach-Object{ConvertTo-NativeQuotedArgument $_}) -join ' ')
  $proc=Start-Process -FilePath (Join-Path $env:SystemRoot 'System32/WindowsPowerShell/v1.0/powershell.exe') -ArgumentList $line -WindowStyle Hidden -PassThru
  return (Get-PMMRepairSession $SessionId)
}

function Save-PMMRepairProcedure([string]$SessionId,[string]$Kind,[array]$Outputs,$Procedure,[string]$StructuralStatus) {
  $session=Get-PMMRepairSession $SessionId
  $revision=Get-PMMCaseEvidenceRevision $session.CaseId
  if((Get-PMMAnalysisValue $revision.Evidence Kind '') -ne 'DeepAnalysis'){return $null}
  $files=@(foreach($path in $Outputs){[pscustomobject]@{Path=[string]$path;Sha256=(Get-Sha256 $path)}})
  if(-not$files.Count){return $null}
  $snapshot=$revision.Evidence.Snapshot
  $id=Get-PMMAnalysisHash @($snapshot.Fingerprint,$Kind,$files,$Procedure)
  $path=Join-Path (Get-PMMKnowledgeRoot) ('RepairProcedures/'+$id+'.json')
  $lock=Enter-PMMAnalysisLock ($path+'.lock')
  try{
    if(Test-Path -LiteralPath $path){return (Read-PMMJsonFile $path)}
    $record=[ordered]@{Schema='PMM_REPAIR_PROCEDURE_V1';Id=$id;CaseId=$session.CaseId;SessionId=$SessionId;EvidenceRevision=$session.EvidenceRevision;SnapshotFingerprint=$snapshot.Fingerprint;Kind=$Kind;Procedure=$Procedure;Outputs=$files;StructuralStatus=$StructuralStatus;Runtime='UNPROVEN';Functions='Pending scenario validation';AutomaticEligible=$false;CreatedUtc=[DateTime]::UtcNow.ToString('o')}
    Write-PMMJsonAtomic $path $record -Depth 40
    return $record
  }finally{$lock.Dispose()}
}
function Get-PMMRepairProcedures([string]$CaseId) {
  $revision=Get-PMMCaseEvidenceRevision $CaseId
  if((Get-PMMAnalysisValue $revision.Evidence Kind '') -ne 'DeepAnalysis'){return @()}
  $snapshot=$revision.Evidence.Snapshot
  if((Get-PMMAnalysisSnapshot $snapshot.Options).Fingerprint -cne $snapshot.Fingerprint){return @()}
  foreach($file in @(Get-ChildItem -LiteralPath (Join-Path (Get-PMMKnowledgeRoot) 'RepairProcedures') -Filter *.json -File -ErrorAction SilentlyContinue)){
    try{
      $record=Read-PMMJsonFile $file.FullName -Schema PMM_REPAIR_PROCEDURE_V1
      if($record.SnapshotFingerprint -cne $snapshot.Fingerprint){continue}
      $valid=$true
      foreach($output in $record.Outputs){if(-not(Test-Path -LiteralPath $output.Path) -or (Get-Sha256 $output.Path) -cne $output.Sha256){$valid=$false;break}}
      if($valid){$record}
    }catch{continue}
  }
}
function Get-PMMDeepKnowledgeContext([string]$CaseId) {
  $revision=Get-PMMCaseEvidenceRevision $CaseId
  if((Get-PMMAnalysisValue $revision.Evidence Kind '') -ne 'DeepAnalysis'){return @()}
  $report=Read-PMMDeepAnalysis $revision.Evidence.AnalysisId
  if((Get-Sha256 (Join-Path (Get-PMMAnalysisPath $report.Id) 'report.json')) -cne $revision.Evidence.ReportSha256){throw 'Case report evidence changed on disk.'}
  foreach($group in @($report.Resources|Where-Object{$_.Provider -ne 'Vanilla'}|Group-Object LogicalPath)){
    $names=@($group.Group|ForEach-Object{$_.Provider}|Sort-Object -Unique)
    $pins=@($report.Snapshot.Active|Where-Object{$_.Name -in $names}|ForEach-Object{[pscustomobject]@{Name=$_.Name;PakSha256=$_.Hash}})
    $item=[pscustomobject]@{Asset=$group.Name;Providers=$names;Case=[pscustomobject]@{Providers=$pins}}
    foreach($context in @(Get-PMMCKLContextForPlanItem $item)){
      [pscustomobject]@{Context=$context;AutomaticEligible=$false;Requirement='Provider identity is context only. The normal merge service must still prove current mappings, Vanilla and all cooked input parts.'}
    }
  }
}
