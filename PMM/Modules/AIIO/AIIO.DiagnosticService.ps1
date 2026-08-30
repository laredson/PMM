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

function New-PMMDiagnosticCase {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory=$true)][ValidateSet('MOD_NOT_WORKING','GAME_CRASH','FEATURE_MISSING','BUILD_FAILURE','DEPLOY_FAILURE','SAVE_PROBLEM','FIXLAB_FAILURE','PERFORMANCE_PROBLEM','PMM_ERROR','UNKNOWN')][string]$Type,
    [string]$Title='',
    [string]$UserDescription='',
    [array]$SelectedTargets=@(),
    [array]$SuspectedTargets=@(),
    [switch]$IncludePalworldLogSummary
  )
  if([string]::IsNullOrWhiteSpace($Title)){$Title=$Type.Replace('_',' ')}
  if($Title.Length -gt 120){$Title=$Title.Substring(0,120)}
  if($UserDescription.Length -gt 20000){throw 'Diagnostic description exceeds 20,000 characters.'}
  $caseId=('DIAG-'+[DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss')+'-'+[guid]::NewGuid().ToString('N').Substring(0,8))
  $plan=Get-PMMAIIOCurrentPlanSnapshot
  $saveEvidence=@()
  try{$saveEvidence=@(Update-PMMSaveActivityRegistry|ForEach-Object{[pscustomobject]@{SaveInstanceId=[string]$_.SaveInstanceId;SnapshotSignature=[string]$_.SnapshotSignature;LastObservedWriteUtc=[string]$_.LastObservedWriteUtc;TotalBytes=[int64]$_.TotalBytes;FileCount=[int]$_.FileCount;Changed=[bool]$_.Changed;SizeDeltaBytes=[int64]$_.SizeDeltaBytes}})}catch{}
  $case=[pscustomobject][ordered]@{
    Schema='PMM_DIAGNOSTIC_CASE_V1'
    CaseId=$caseId
    Type=$Type
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
  }
  Write-PMMAIIOJsonAtomic (Get-PMMDiagnosticCasePath $caseId) $case 70
  return $case
}

function Get-PMMDiagnosticCases {
  $rows=[Collections.Generic.List[object]]::new()
  foreach($file in @(Get-ChildItem -LiteralPath (Get-PMMPath 'AIIODiagnostics') -Filter 'DIAG-*.json' -File -ErrorAction SilentlyContinue|Sort-Object LastWriteTimeUtc -Descending)){
    try{
      $case=Get-Content -LiteralPath $file.FullName -Raw -Encoding UTF8|ConvertFrom-Json
      if([string]$case.Schema -ne 'PMM_DIAGNOSTIC_CASE_V1'){continue}
      $rows.Add([pscustomobject]@{CaseId=[string]$case.CaseId;Type=[string]$case.Type;Title=[string]$case.Title;Status=[string]$case.Status;CreatedUtc=[string]$case.CreatedUtc;Display=([string]$case.Title+'  —  '+[string]$case.Status)})
    }catch{}
  }
  return @($rows.ToArray())
}

function New-PMMAIIOSessionFromDiagnostic {
  [CmdletBinding()]
  param([Parameter(Mandatory=$true)]$DiagnosticCase)
  if(-not$DiagnosticCase -or [string]$DiagnosticCase.Schema -ne 'PMM_DIAGNOSTIC_CASE_V1'){throw 'A valid PMM diagnostic case is required.'}
  $session=New-PMMAIIOSession -Title ([string]$DiagnosticCase.Title) -Description ([string]$DiagnosticCase.UserDescription) -TaskType ([string]$DiagnosticCase.Type) -TargetKind DiagnosticCase -TargetId ([string]$DiagnosticCase.CaseId) -SelectedTargets @($DiagnosticCase.SelectedTargets) -CaseIds @([string]$DiagnosticCase.CaseId)
  try{Add-PMMAIIOHistoryEvent -SessionId ([string]$session.SessionId) -Event DIAGNOSTIC_ATTACHED -Message ([string]$DiagnosticCase.CaseId)|Out-Null}catch{Write-PMMLog ('AIIO diagnostic session was created, but its auxiliary history event could not be written: '+$_.Exception.Message)}
  return $session
}
