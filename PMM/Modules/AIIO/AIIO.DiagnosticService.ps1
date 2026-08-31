<#
AIIO diagnostics service
========================

Creates local PMM_DIAGNOSTIC_CASE_V1 records from bounded PMM/Palworld state.
It does not scan the computer generally and does not include complete logs,
crash dumps, save contents, personal paths or account identifiers by default.
#>

function Protect-PMMAIIODiagnosticText([string]$Text) {
  if([string]::IsNullOrEmpty($Text)){return ''}
  $value=$Text
  try{
    $profile=[Environment]::GetFolderPath('UserProfile')
    if($profile){$value=$value.Replace($profile,'%USERPROFILE%')}
  }catch{}
  try{if($env:USERNAME){$value=[regex]::Replace($value,[regex]::Escape([string]$env:USERNAME),'<windows-user>',[Text.RegularExpressions.RegexOptions]::IgnoreCase)}}catch{}
  $value=[regex]::Replace($value,'\b7656[0-9]{13}\b','<steam-id>')
  $value=[regex]::Replace($value,'(?i)\b(?:[a-z]:\\Users\\)[^\\\r\n]+','%USERPROFILE%')
  $value=[regex]::Replace($value,'(?<![0-9])(?:[0-9]{1,3}\.){3}[0-9]{1,3}(?![0-9])','<ip-address>')
  try{if($Script:Root){$value=$value.Replace([string]$Script:Root,'<PMM_ROOT>')}}catch{}
  try{$game=[string](Get-PMMConfig).GamePath;if($game){$value=$value.Replace($game,'<PALWORLD_ROOT>')}}catch{}
  $value=[regex]::Replace($value,'(?i)(?<![A-Za-z0-9_])[A-Z]:\\[^\r\n\t|;,]+','<local-path>')
  $value=[regex]::Replace($value,'(?<!\\)\\\\[^\r\n\t|;,]+','<network-path>')
  return $value
}

function Get-PMMAIIOSanitizedLogWindow {
  [CmdletBinding()]
  param([int]$MaximumLines=300)
  $MaximumLines=[Math]::Max(20,[Math]::Min(2000,$MaximumLines))
  $path=Get-PMMLogPath
  if(-not(Test-Path -LiteralPath $path -PathType Leaf)){return @()}
  $lines=@(Get-Content -LiteralPath $path -Tail $MaximumLines -Encoding UTF8 -ErrorAction SilentlyContinue)
  return @($lines|ForEach-Object{Protect-PMMAIIODiagnosticText ([string]$_)})
}

function Get-PMMPalworldDiagnosticLogCandidates {
  $rows=[Collections.Generic.List[object]]::new()
  $saved=''
  try{if($env:LOCALAPPDATA){$saved=Join-Path $env:LOCALAPPDATA 'Pal\Saved'}}catch{}
  if([string]::IsNullOrWhiteSpace($saved)){return @()}
  foreach($relative in @('Logs\Pal.log','Logs\Pal-backup-2026.01.01-00.00.00.log')){
    if($relative -like '*backup*'){continue}
    $path=Join-Path $saved $relative
    if(Test-Path -LiteralPath $path -PathType Leaf){$rows.Add([pscustomobject]@{Kind='PalworldLog';Path=$path;Name=[IO.Path]::GetFileName($path)})}
  }
  $logRoot=Join-Path $saved 'Logs'
  if(Test-Path -LiteralPath $logRoot -PathType Container){
    foreach($file in @(Get-ChildItem -LiteralPath $logRoot -Filter '*.log' -File -ErrorAction SilentlyContinue|Sort-Object LastWriteTimeUtc -Descending|Select-Object -First 5)){
      if(@($rows|Where-Object{[string]$_.Path -ieq $file.FullName}).Count -eq 0){$rows.Add([pscustomobject]@{Kind='PalworldLog';Path=$file.FullName;Name=$file.Name})}
    }
  }
  return @($rows.ToArray())
}

function Get-PMMPalworldDiagnosticSummary {
  $markers=@('Fatal error','Unhandled Exception','LowLevelFatalError','CrashReportClient','ensure condition failed','out of memory','pak file','failed to load')
  $rows=[Collections.Generic.List[object]]::new()
  foreach($candidate in @(Get-PMMPalworldDiagnosticLogCandidates)){
    try{
      $item=Get-Item -LiteralPath ([string]$candidate.Path) -ErrorAction Stop
      $tail=@(Get-Content -LiteralPath $item.FullName -Tail 1200 -ErrorAction SilentlyContinue)
      $hits=[Collections.Generic.List[object]]::new()
      foreach($line in $tail){
        $text=[string]$line
        foreach($marker in $markers){
          if($text.IndexOf($marker,[StringComparison]::OrdinalIgnoreCase) -ge 0){
            $hits.Add([pscustomobject]@{Marker=$marker;Excerpt=(Protect-PMMAIIODiagnosticText $text)});break
          }
        }
        if($hits.Count -ge 30){break}
      }
      $rows.Add([pscustomobject]@{Kind=[string]$candidate.Kind;FileName=$item.Name;Bytes=[int64]$item.Length;LastWriteUtc=$item.LastWriteTimeUtc.ToString('o');Markers=@($hits.ToArray());FullLogIncluded=$false})
    }catch{}
  }
  return @($rows.ToArray())
}

function Get-PMMAIIODiagnosticTimeline {
  $rows=[Collections.Generic.List[object]]::new()
  try{
    foreach($event in @(Get-PMMOperationJournalEvents|Select-Object -Last 100)){
      $rows.Add([pscustomobject]@{Utc=[string]$event.Utc;Source='PMM_OPERATION';Kind=[string]$event.Kind;Event=[string]$event.Event;Step=[string]$event.Step;Status=[string]$event.Status})
    }
  }catch{}
  return @($rows.ToArray())
}

function Get-PMMDiagnosticCasePath([string]$CaseId) {
  if($CaseId -notmatch '^DIAG-[0-9]{8}-[0-9]{6}-[a-f0-9]{8}$'){throw 'Invalid diagnostic case ID.'}
  return (Join-Path (Get-PMMPath 'AIIODiagnostics') ($CaseId+'.json'))
}

function Get-PMMDiagnosticFingerprint([string]$Type,[string]$Title,[string]$Description='') {
  $normalizedTitle=([string]$Title).Trim().ToLowerInvariant()
  $normalizedDescription=([string]$Description).Trim().ToLowerInvariant()
  return (Get-PMMStableTextId ('PMM_DIAGNOSTIC_FINGERPRINT_V1|'+[string]$Type+'|'+$normalizedTitle+'|'+$normalizedDescription))
}

function New-PMMDiagnosticCase {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory=$true)][ValidateSet('MOD_NOT_WORKING','GAME_CRASH','FEATURE_MISSING','BUILD_FAILURE','DEPLOY_FAILURE','SAVE_PROBLEM','FIXLAB_FAILURE','PERFORMANCE_PROBLEM','PMM_ERROR','UNKNOWN')][string]$Type,
    [string]$Title='',
    [string]$UserDescription='',
    [array]$SelectedTargets=@(),
    [array]$SuspectedTargets=@(),
    [switch]$IncludePalworldLogSummary,
    [ValidateSet('User','AutomaticError')][string]$Origin='User',
    [bool]$AttentionEligible=$true,
    [string]$Fingerprint=''
  )
  if([string]::IsNullOrWhiteSpace($Title)){$Title=$Type.Replace('_',' ')}
  if($Title.Length -gt 120){$Title=$Title.Substring(0,120)}
  if($UserDescription.Length -gt 20000){throw 'Diagnostic description exceeds 20,000 characters.'}
  if([string]::IsNullOrWhiteSpace($Fingerprint)){$Fingerprint=Get-PMMDiagnosticFingerprint $Type $Title $UserDescription}
  $caseId=('DIAG-'+[DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss')+'-'+[guid]::NewGuid().ToString('N').Substring(0,8))
  $plan=Get-PMMAIIOCurrentPlanSnapshot
  $saveEvidence=@()
  try{$saveEvidence=@(Update-PMMSaveActivityRegistry|ForEach-Object{[pscustomobject]@{SaveInstanceId=[string]$_.SaveInstanceId;SnapshotSignature=[string]$_.SnapshotSignature;LastObservedWriteUtc=[string]$_.LastObservedWriteUtc;TotalBytes=[int64]$_.TotalBytes;FileCount=[int]$_.FileCount;Changed=[bool]$_.Changed;SizeDeltaBytes=[int64]$_.SizeDeltaBytes}})}catch{}
  $case=[pscustomobject][ordered]@{
    Schema='PMM_DIAGNOSTIC_CASE_V1'
    CaseId=$caseId
    Type=$Type
    Origin=$Origin
    AttentionEligible=$AttentionEligible
    Fingerprint=$Fingerprint
    OccurrenceCount=1
    Title=$Title
    UserDescription=$UserDescription
    SelectedTargets=@($SelectedTargets)
    SuspectedTargets=@($SuspectedTargets)
    CauseConfirmed=$false
    GameVersion=''
    PMM=(Get-PMMAIIOProductIdentity)
    CurrentDeployment=(Get-PMMAIIOCurrentDeploymentSnapshot)
    CurrentBuild=$(if($plan){[pscustomobject]@{SourceSignature=[string]$plan.SourceSignature;MergeOrderSignature=[string]$plan.MergeOrderSignature;MappingsSha256=[string]$plan.MappingsSha256}}else{$null})
    Timeline=(Get-PMMAIIODiagnosticTimeline)
    AvailableLogs=[ordered]@{PMM=(Test-Path -LiteralPath (Get-PMMLogPath) -PathType Leaf);Palworld=@(Get-PMMPalworldDiagnosticLogCandidates).Count}
    RuntimeEvidence=[ordered]@{ProcessObservationAvailable=$false;UserReportRequired=$true}
    SaveEvidence=@($saveEvidence)
    PalworldLogSummary=$(if($IncludePalworldLogSummary){@(Get-PMMPalworldDiagnosticSummary)}else{@()})
    KnowledgeMatches=@()
    RelatedPreviousErrors=@()
    OperationState=(Get-PMMAIIOOperationStateExport)
    Privacy=[ordered]@{ContainsSaveContents=$false;ContainsWorldNames=$false;ContainsStructuredAbsolutePaths=$false;UserTextMayContainPersonalData=(-not[string]::IsNullOrWhiteSpace($UserDescription));ContainsCredentials=$false;ContainsFullLogs=$false}
    Status='Open'
    CreatedUtc=[DateTime]::UtcNow.ToString('o')
    UpdatedUtc=[DateTime]::UtcNow.ToString('o')
    LastOccurredUtc=[DateTime]::UtcNow.ToString('o')
  }
  Write-PMMAIIOJsonAtomic (Get-PMMDiagnosticCasePath $caseId) $case 70
  return $case
}

function Register-PMMAutomaticErrorCase {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory=$true)][string]$Title,
    [Parameter(Mandatory=$true)][string]$Message
  )
  $description=$Title+': '+$Message
  $fingerprint=Get-PMMDiagnosticFingerprint 'PMM_ERROR' $Title $description
  $root=Get-PMMPath 'AIIODiagnostics'
  foreach($file in @(Get-ChildItem -LiteralPath $root -Filter 'DIAG-*.json' -File -ErrorAction SilentlyContinue|Sort-Object LastWriteTimeUtc -Descending)){
    try{
      $case=Get-Content -LiteralPath $file.FullName -Raw -Encoding UTF8|ConvertFrom-Json
      if([string]$case.Schema -ne 'PMM_DIAGNOSTIC_CASE_V1' -or [string]$case.Type -ne 'PMM_ERROR' -or [string]$case.Status -ne 'Open'){continue}
      $existingFingerprint=''
      if($case.PSObject.Properties.Name -contains 'Fingerprint'){$existingFingerprint=[string]$case.Fingerprint}
      if([string]::IsNullOrWhiteSpace($existingFingerprint)){$existingFingerprint=Get-PMMDiagnosticFingerprint ([string]$case.Type) ([string]$case.Title) ([string]$case.UserDescription)}
      if($existingFingerprint -cne $fingerprint){continue}
      $count=1;try{$count=[Math]::Max(1,[int]$case.OccurrenceCount)}catch{$count=1}
      $case|Add-Member -NotePropertyName Origin -NotePropertyValue 'AutomaticError' -Force
      $case|Add-Member -NotePropertyName AttentionEligible -NotePropertyValue $true -Force
      $case|Add-Member -NotePropertyName Fingerprint -NotePropertyValue $fingerprint -Force
      $case|Add-Member -NotePropertyName OccurrenceCount -NotePropertyValue ($count+1) -Force
      $now=[DateTime]::UtcNow.ToString('o')
      $case|Add-Member -NotePropertyName LastOccurredUtc -NotePropertyValue $now -Force
      $case.UpdatedUtc=$now
      Write-PMMAIIOJsonAtomic $file.FullName $case 70
      Write-PMMLog ('Reused automatic diagnostic case '+[string]$case.CaseId+' | occurrence='+[string]($count+1))
      return $case
    }catch{}
  }
  return (New-PMMDiagnosticCase -Type PMM_ERROR -Title $Title -UserDescription $description -Origin AutomaticError -AttentionEligible $true -Fingerprint $fingerprint)
}

function Get-PMMDiagnosticCases {
  $rows=[Collections.Generic.List[object]]::new()
  foreach($file in @(Get-ChildItem -LiteralPath (Get-PMMPath 'AIIODiagnostics') -Filter 'DIAG-*.json' -File -ErrorAction SilentlyContinue|Sort-Object LastWriteTimeUtc -Descending)){
    try{
      $case=Get-Content -LiteralPath $file.FullName -Raw -Encoding UTF8|ConvertFrom-Json
      if([string]$case.Schema -ne 'PMM_DIAGNOSTIC_CASE_V1'){continue}
      $attentionEligible=$true;if($case.PSObject.Properties.Name -contains 'AttentionEligible'){$attentionEligible=[bool]$case.AttentionEligible}
      $fingerprint='';if($case.PSObject.Properties.Name -contains 'Fingerprint'){$fingerprint=[string]$case.Fingerprint};if([string]::IsNullOrWhiteSpace($fingerprint)){$fingerprint=Get-PMMDiagnosticFingerprint ([string]$case.Type) ([string]$case.Title) ([string]$case.UserDescription)}
      $occurrences=1;try{$occurrences=[Math]::Max(1,[int]$case.OccurrenceCount)}catch{$occurrences=1}
      $suffix=if($occurrences -gt 1){' (x'+[string]$occurrences+')'}else{''}
      $rows.Add([pscustomobject]@{CaseId=[string]$case.CaseId;Type=[string]$case.Type;Origin=$(if($case.PSObject.Properties.Name -contains 'Origin'){[string]$case.Origin}else{'User'});AttentionEligible=$attentionEligible;Fingerprint=$fingerprint;OccurrenceCount=$occurrences;Title=[string]$case.Title;Status=[string]$case.Status;CreatedUtc=[string]$case.CreatedUtc;Display=([string]$case.Title+$suffix+'  -  '+[string]$case.Status)})
    }catch{}
  }
  return @($rows.ToArray())
}

function Resolve-PMMKnownLegacyUiDiagnostics {
  # RC28 could turn two presentation-only faults into open diagnostics: the
  # delayed AIIO callback lost the WPF script scope, and validation feedback
  # looked only at DataGrid row selection instead of the selected/deployed
  # merge. Preserve those records, but retire their attention state after the
  # fixed build starts so they do not keep a misleading main-tab badge.
  $resolved=[Collections.Generic.List[string]]::new()
  foreach($file in @(Get-ChildItem -LiteralPath (Get-PMMPath 'AIIODiagnostics') -Filter 'DIAG-*.json' -File -ErrorAction SilentlyContinue)){
    try{
      $case=Get-Content -LiteralPath $file.FullName -Raw -Encoding UTF8|ConvertFrom-Json
      if([string]$case.Schema -ne 'PMM_DIAGNOSTIC_CASE_V1' -or [string]$case.Status -ne 'Open' -or [string]$case.Type -ne 'PMM_ERROR'){continue}
      $title=[string]$case.Title;$description=[string]$case.UserDescription;$known=$false
      if($title -eq 'AIIOPrepare completion' -and $description -match '(?i)SelectedValue'){$known=$true}
      if($title -eq 'Generate local validation feedback' -and $description -match '(?i)(select a compatibility merge|selecciona primero un merge)'){$known=$true}
      if(-not$known){continue}
      $now=[DateTime]::UtcNow.ToString('o')
      $case.Status='ResolvedByUpgrade';$case.UpdatedUtc=$now
      $case|Add-Member -NotePropertyName AttentionEligible -NotePropertyValue $false -Force
      $case|Add-Member -NotePropertyName Resolution -NotePropertyValue ([pscustomobject]@{Kind='PMM_UPGRADE_FIX';Build='RC29';ResolvedUtc=$now;EvidencePreserved=$true}) -Force
      Write-PMMAIIOJsonAtomic $file.FullName $case 75
      $resolved.Add([string]$case.CaseId)
    }catch{}
  }
  if($resolved.Count -gt 0){Write-PMMLog ('Retired known RC28 UI-only diagnostic(s): '+(@($resolved.ToArray()) -join ', '))}
  return @($resolved.ToArray())
}

function New-PMMAIIOSessionFromDiagnostic {
  [CmdletBinding()]
  param([Parameter(Mandatory=$true)]$DiagnosticCase)
  if(-not$DiagnosticCase -or [string]$DiagnosticCase.Schema -ne 'PMM_DIAGNOSTIC_CASE_V1'){throw 'A valid PMM diagnostic case is required.'}
  $session=New-PMMAIIOSession -Title ([string]$DiagnosticCase.Title) -Description ([string]$DiagnosticCase.UserDescription) -TaskType ([string]$DiagnosticCase.Type) -TargetKind DiagnosticCase -TargetId ([string]$DiagnosticCase.CaseId) -SelectedTargets @($DiagnosticCase.SelectedTargets) -CaseIds @([string]$DiagnosticCase.CaseId)
  try{Add-PMMAIIOHistoryEvent -SessionId ([string]$session.SessionId) -Event DIAGNOSTIC_ATTACHED -Message ([string]$DiagnosticCase.CaseId)|Out-Null}catch{Write-PMMLog ('AIIO diagnostic session was created, but its auxiliary history event could not be written: '+$_.Exception.Message)}
  return $session
}
