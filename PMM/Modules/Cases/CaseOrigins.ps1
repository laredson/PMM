# Origin adapters keep module assistance inside the same persistent case model.
function Get-OrCreate-PMMOriginCase {
  param([string]$Origin,[string]$SourceId,[string]$Type='QUERY',[string]$Title,[string]$Description='',[array]$Mods=@(),$Context=$null,[string]$LegacySessionId='')
  if(-not$Origin -or -not$SourceId){throw 'A case origin and source identity are required.'}
  $key='origin-'+(Get-PMMCaseDigest ([ordered]@{Origin=$Origin;SourceId=$SourceId}))
  $mutex=[Threading.Mutex]::new($false,(Get-PMMStorageMutexName (Join-Path (Get-PMMAIIOCaseRoot) $key)));$owned=$false
  try{
    try{$owned=$mutex.WaitOne(15000)}catch [Threading.AbandonedMutexException]{$owned=$true}
    if(-not$owned){throw 'Another window is updating this module case.'}
  $matches=@(Get-PMMAIIOCases|Where-Object{[string](Get-PMMCaseValue $_ 'LogicalKey' '') -ceq $key -or ($LegacySessionId -and [string]$_.LegacySessionId -ceq $LegacySessionId)})
  if($matches.Count -gt 1){throw 'Duplicate origin case requires recovery.'}
  $case=if($matches.Count){Get-PMMCaseContract $matches[0]}else{Get-PMMCaseContract (New-PMMAIIOCase -Title $Title -Type $Type -Description $Description -LegacySessionId $LegacySessionId -NoInitialStep)}
  $case.LogicalKey=$key;$case.Origin=$Origin
  $refs=@(foreach($mod in $Mods){[pscustomobject]@{Kind='MOD';Name=[string]$mod.Name;Path=[string](Get-PMMCaseValue $mod 'Path' '');Sha256=[string](Get-PMMCaseValue $mod 'Hash' (Get-PMMCaseValue $mod 'Sha256' ''));Mode='FULL_PAK';Families=@()}})
  if($refs.Count){
    $merged=@(foreach($reference in $refs){
      $prior=@($case.References.Mods|Where-Object{[string]$_.Name -ceq [string]$reference.Name}|Select-Object -First 1)
      if($prior.Count){$keep=Copy-PMMAIIOCaseObject $prior[0];$keep.Path=$reference.Path;$keep.Sha256=$reference.Sha256;$keep}else{$reference}
    })
    $case.References.Mods=$merged+@($case.References.Mods|Where-Object{[string]$_.Name -notin @($refs.Name)})
  }
  $prior=[string]$case.CurrentEvidenceRevision;Save-PMMAIIOCase $case|Out-Null
  $evidence=[ordered]@{Kind='ModuleContext';Origin=$Origin;SourceId=$SourceId;Context=$Context;CaseContext=(Get-PMMCaseContextSnapshot $case);Mods=@($case.References.Mods|Select-Object Name,Sha256);LegacySessionId=$LegacySessionId}
  $revision=Add-PMMCaseEvidenceRevision $case.CaseId $evidence
  if($prior -cne $revision){$case=Get-PMMAIIOCase $case.CaseId;Add-PMMAIIOCaseStep $case 'MODULE_CONTEXT' ('Context: '+$Origin) 'EDIT_OR_CREATE_HANDOFF' @((Join-Path (Get-PMMAIIOCasePath $case.CaseId) ('revisions/'+$revision+'.json'))) ([ordered]@{EvidenceRevision=$revision;SourceId=$SourceId})|Out-Null}
  return Get-PMMAIIOCase $case.CaseId
  }finally{if($owned){$mutex.ReleaseMutex()};$mutex.Dispose()}
}
function Sync-PMMDiagnosticToCase($Diagnostic) {
  $context=[ordered]@{}
  foreach($name in @('CaseId','Type','SelectedTargets','SuspectedTargets','CurrentDeployment','CurrentBuild','AvailableLogs','RuntimeEvidence','CauseConfirmed','PalworldLogSummary','OccurrenceCount','Status')){$context[$name]=Get-PMMCaseValue $Diagnostic $name $null}
  $legacy=''
  if(Get-Command Get-PMMAIIOSessionForDiagnostic -ErrorAction SilentlyContinue){$session=Get-PMMAIIOSessionForDiagnostic ([string]$Diagnostic.CaseId);if($session){$legacy=[string]$session.SessionId}}
  return (Get-OrCreate-PMMOriginCase -Origin Diagnostics -SourceId ([string]$Diagnostic.CaseId) -Title ([string]$Diagnostic.Title) -Description ([string](Get-PMMCaseValue $Diagnostic 'UserDescription' '')) -Context $context -LegacySessionId $legacy)
}
function Initialize-PMMOriginCases {
  if(Get-Command Get-PMMDiagnosticCases -ErrorAction SilentlyContinue){foreach($row in @(Get-PMMDiagnosticCases)){
    try{$diagnostic=Get-Content -LiteralPath (Get-PMMDiagnosticCasePath $row.CaseId) -Raw -Encoding UTF8|ConvertFrom-Json;Sync-PMMDiagnosticToCase $diagnostic|Out-Null}catch{Write-PMMLog ('Diagnostic case migration: '+$_.Exception.Message)}
  }}
}
