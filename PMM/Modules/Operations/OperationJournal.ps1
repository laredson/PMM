<#
PMM operation and recovery journal
==================================

AIIO, Fix Lab, Deploy, save restore and development staging can all change
persistent state.  This append-only journal gives every mutating operation a
common recovery trail without replacing the module-specific transactional
manifests that already exist.

The journal contains metadata only.  It never stores PAK bytes, save contents,
credentials or arbitrary command lines.
#>

function Get-PMMOperationJournalPath {
  return (Join-PMMPath 'State' 'operations.jsonl')
}

function Get-PMMOperationJournalMutexName {
  $root=([IO.Path]::GetFullPath([string]$Script:Root)).ToLowerInvariant()
  $sha=[Security.Cryptography.SHA256]::Create()
  try{$hash=([BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($root)))).Replace('-','').ToLowerInvariant()}
  finally{$sha.Dispose()}
  return ('Local\PMM_OperationJournal_'+$hash.Substring(0,24))
}

function ConvertTo-PMMOperationJournalMetadata($Metadata) {
  if($null -eq $Metadata){return [ordered]@{}}
  try{
    # Round-trip through JSON to detach live WPF/FileInfo/process objects and
    # keep a bounded data-only record.
    $json=$Metadata|ConvertTo-Json -Depth 12 -Compress
    if($json.Length -gt 131072){return [ordered]@{Truncated=$true;Reason='Metadata exceeded 128 KiB.'}}
    return ($json|ConvertFrom-Json)
  }catch{return [ordered]@{SerializationError=$_.Exception.Message}}
}

function Write-PMMOperationJournalEvent {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory=$true)][string]$OperationId,
    [Parameter(Mandatory=$true)][string]$Event,
    [string]$Kind='',
    [string]$Step='',
    [string]$Status='',
    $Metadata=$null
  )
  if([string]::IsNullOrWhiteSpace($OperationId)){throw 'Operation journal requires an operation ID.'}
  if($Event -notin @('START','STEP','END','FAIL','ROLLBACK','ABANDON','RECOVERY_REQUIRED')){throw ('Unsupported operation journal event: '+$Event)}
  $path=Get-PMMOperationJournalPath
  $parent=Split-Path -Parent $path
  if(-not(Test-Path -LiteralPath $parent -PathType Container)){New-Item -ItemType Directory -Force -Path $parent|Out-Null}
  $record=[ordered]@{
    Schema='PMM_OPERATION_EVENT_V1'
    OperationId=$OperationId
    Event=$Event
    Kind=$Kind
    Step=$Step
    Status=$Status
    Utc=[DateTime]::UtcNow.ToString('o')
    ProcessId=$PID
    Metadata=(ConvertTo-PMMOperationJournalMetadata $Metadata)
  }
  $line=$record|ConvertTo-Json -Depth 16 -Compress
  $mutex=[Threading.Mutex]::new($false,(Get-PMMOperationJournalMutexName))
  $locked=$false;$stream=$null;$writer=$null
  try{
    try{$locked=$mutex.WaitOne(5000)}catch [Threading.AbandonedMutexException]{$locked=$true}
    if(-not$locked){throw 'Timed out waiting for the PMM operation journal.'}
    $stream=[IO.File]::Open($path,[IO.FileMode]::Append,[IO.FileAccess]::Write,[IO.FileShare]::Read)
    $writer=[IO.StreamWriter]::new($stream,[Text.UTF8Encoding]::new($false))
    $writer.WriteLine($line);$writer.Flush();$stream.Flush($true)
  }finally{
    if($writer){$writer.Dispose()}elseif($stream){$stream.Dispose()}
    if($locked){try{$mutex.ReleaseMutex()}catch{}}
    $mutex.Dispose()
  }
  return [pscustomobject]$record
}

function Start-PMMJournalOperation {
  [CmdletBinding()]
  param([Parameter(Mandatory=$true)][string]$Kind,[string]$Target='',$Metadata=$null)
  $id=('op-'+[DateTime]::UtcNow.ToString('yyyyMMddHHmmssfff')+'-'+[guid]::NewGuid().ToString('N').Substring(0,12))
  $details=[ordered]@{Target=$Target;Details=(ConvertTo-PMMOperationJournalMetadata $Metadata)}
  [void](Write-PMMOperationJournalEvent -OperationId $id -Event START -Kind $Kind -Status Running -Metadata $details)
  return $id
}

function Write-PMMJournalStep {
  [CmdletBinding()]
  param([Parameter(Mandatory=$true)][string]$OperationId,[string]$Kind='',[Parameter(Mandatory=$true)][string]$Step,[string]$Status='Complete',$Metadata=$null)
  [void](Write-PMMOperationJournalEvent -OperationId $OperationId -Event STEP -Kind $Kind -Step $Step -Status $Status -Metadata $Metadata)
}

function Complete-PMMJournalOperation {
  [CmdletBinding()]
  param([Parameter(Mandatory=$true)][string]$OperationId,[string]$Kind='',$Metadata=$null)
  [void](Write-PMMOperationJournalEvent -OperationId $OperationId -Event END -Kind $Kind -Status Success -Metadata $Metadata)
}

function Fail-PMMJournalOperation {
  [CmdletBinding()]
  param([Parameter(Mandatory=$true)][string]$OperationId,[string]$Kind='',[string]$Message='',$Metadata=$null)
  $details=[ordered]@{Message=$Message;Details=(ConvertTo-PMMOperationJournalMetadata $Metadata)}
  [void](Write-PMMOperationJournalEvent -OperationId $OperationId -Event FAIL -Kind $Kind -Status Failed -Metadata $details)
}

function Write-PMMJournalRollback {
  [CmdletBinding()]
  param([Parameter(Mandatory=$true)][string]$OperationId,[string]$Kind='',[string]$Message='',$Metadata=$null)
  [void](Write-PMMOperationJournalEvent -OperationId $OperationId -Event ROLLBACK -Kind $Kind -Status Restored -Metadata ([ordered]@{Message=$Message;Details=(ConvertTo-PMMOperationJournalMetadata $Metadata)}))
}

function Get-PMMOperationJournalEvents {
  $path=Get-PMMOperationJournalPath
  if(-not(Test-Path -LiteralPath $path -PathType Leaf)){return @()}
  $rows=[Collections.Generic.List[object]]::new()
  foreach($line in @(Get-Content -LiteralPath $path -Encoding UTF8 -ErrorAction SilentlyContinue)){
    if([string]::IsNullOrWhiteSpace([string]$line)){continue}
    try{
      $row=[string]$line|ConvertFrom-Json
      if($row -and [string]$row.Schema -eq 'PMM_OPERATION_EVENT_V1'){$rows.Add($row)}
    }catch{}
  }
  return @($rows.ToArray())
}

function Get-PMMInterruptedOperations {
  $result=[Collections.Generic.List[object]]::new()
  foreach($group in @(Get-PMMOperationJournalEvents|Group-Object -Property OperationId)){
    $events=@($group.Group)
    if($events.Count -eq 0){continue}
    $start=@($events|Where-Object{[string]$_.Event -eq 'START'}|Select-Object -First 1)
    if($start.Count -eq 0){continue}
    $terminal=@($events|Where-Object{[string]$_.Event -in @('END','FAIL','ROLLBACK','ABANDON')})
    if($terminal.Count -gt 0){continue}
    $last=@($events|Select-Object -Last 1)[0]
    $running=$false
    try{$running=Test-PMMProcessIdRunning ([int]$last.ProcessId)}catch{$running=$false}
    if($running){continue}
    $result.Add([pscustomobject]@{
      OperationId=[string]$group.Name
      Kind=[string]$start[0].Kind
      StartedUtc=[string]$start[0].Utc
      LastEvent=[string]$last.Event
      LastStep=[string]$last.Step
      LastStatus=[string]$last.Status
      LastUtc=[string]$last.Utc
      Metadata=$start[0].Metadata
      EventCount=$events.Count
    })
  }
  return @($result.ToArray()|Sort-Object StartedUtc -Descending)
}

function Acknowledge-PMMInterruptedOperation {
  [CmdletBinding()]
  param([Parameter(Mandatory=$true)][string]$OperationId,[string]$Kind='',[string]$Reason='User acknowledged after recovery review.')
  [void](Write-PMMOperationJournalEvent -OperationId $OperationId -Event ABANDON -Kind $Kind -Status Acknowledged -Metadata ([ordered]@{Reason=$Reason}))
}

