<#
Read-only save activity registry for AIIO diagnostics.

Only relative file names, sizes and timestamps are used to create local
snapshots.  Save contents, world names, Steam IDs and absolute paths are never
written to diagnostic or feedback records.
#>

function Get-PMMSaveActivitySignature([string]$WorldPath) {
  if(-not(Test-Path -LiteralPath $WorldPath -PathType Container)){return $null}
  $rows=[Collections.Generic.List[string]]::new();[int64]$bytes=0;[int]$count=0;$last=[DateTime]::MinValue
  foreach($file in @(Get-ChildItem -LiteralPath $WorldPath -Recurse -File -ErrorAction SilentlyContinue|Where-Object{-not(Test-IsBackupSavePath $_.FullName)}|Sort-Object FullName)){
    $relative=$file.FullName.Substring($WorldPath.TrimEnd([char]92,[char]47).Length).TrimStart([char]92,[char]47).Replace([char]92,[char]47)
    $rows.Add(($relative+'|'+[int64]$file.Length+'|'+$file.LastWriteTimeUtc.Ticks))
    $bytes+=[int64]$file.Length;$count++
    if($file.LastWriteTimeUtc -gt $last){$last=$file.LastWriteTimeUtc}
  }
  $text='PMM_SAVE_ACTIVITY_V1|'+($rows -join "`n")
  $sha=[Security.Cryptography.SHA256]::Create()
  try{$signature=([BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($text)))).Replace('-','').ToLowerInvariant()}
  finally{$sha.Dispose()}
  return [pscustomobject]@{Signature=$signature;TotalBytes=$bytes;FileCount=$count;LastWriteUtc=$(if($last -eq [DateTime]::MinValue){''}else{$last.ToString('o')})}
}

function Get-PMMSaveActivityStatePath([string]$SaveInstanceId) {
  if($SaveInstanceId -notmatch '^[0-9a-f]{64}$'){throw 'Invalid save activity ID.'}
  return (Join-PMMPath 'SaveActivity' ($SaveInstanceId+'.json'))
}

function Get-PMMSaveActivityInstanceId([string]$WorldPath) {
  $normalized=([IO.Path]::GetFullPath($WorldPath)).TrimEnd([char]92,[char]47).ToLowerInvariant()
  $sha=[Security.Cryptography.SHA256]::Create()
  try{return ([BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes('PMM_SAVE_INSTANCE_V1|'+$normalized)))).Replace('-','').ToLowerInvariant()}
  finally{$sha.Dispose()}
}

function Update-PMMSaveActivityRegistry {
  $updates=[Collections.Generic.List[object]]::new()
  foreach($world in @(Get-PMMSaveWorlds)){
    if(-not$world -or [string]::IsNullOrWhiteSpace([string]$world.Path)){continue}
    $snapshot=Get-PMMSaveActivitySignature ([string]$world.Path)
    if(-not$snapshot){continue}
    $id=Get-PMMSaveActivityInstanceId ([string]$world.Path)
    $path=Get-PMMSaveActivityStatePath $id
    $prior=$null
    try{if(Test-Path -LiteralPath $path -PathType Leaf){$prior=Get-Content -LiteralPath $path -Raw -Encoding UTF8|ConvertFrom-Json}}catch{}
    $now=[DateTime]::UtcNow.ToString('o')
    $first=if($prior -and $prior.PSObject.Properties.Name -contains 'FirstSeenUtc'){[string]$prior.FirstSeenUtc}else{$now}
    $created='';try{$created=(Get-Item -LiteralPath ([string]$world.Path)).CreationTimeUtc.ToString('o')}catch{}
    $changed=(-not$prior -or [string]$prior.SnapshotSignature -ne [string]$snapshot.Signature)
    $delta=if($prior){[int64]$snapshot.TotalBytes-[int64]$prior.TotalBytes}else{[int64]0}
    $state=[pscustomobject][ordered]@{
      Schema='PMM_SAVE_ACTIVITY_V1'
      SaveInstanceId=$id
      FirstSeenUtc=$first
      FilesystemCreatedUtc=$created
      LastObservedWriteUtc=[string]$snapshot.LastWriteUtc
      TotalBytes=[int64]$snapshot.TotalBytes
      FileCount=[int]$snapshot.FileCount
      SnapshotSignature=[string]$snapshot.Signature
      SnapshotUtc=$now
      PreviousSignature=$(if($prior){[string]$prior.SnapshotSignature}else{''})
      SizeDeltaBytes=$delta
      Changed=[bool]$changed
      Privacy=[ordered]@{ContainsWorldName=$false;ContainsAbsolutePath=$false;ContainsSaveContents=$false;ContainsSteamId=$false}
    }
    Write-PMMAIIOJsonAtomic $path $state 12
    $updates.Add($state)
  }
  return @($updates.ToArray())
}

function Get-PMMSaveActivityRegistry {
  $rows=[Collections.Generic.List[object]]::new()
  $root=Get-PMMPath 'SaveActivity'
  foreach($file in @(Get-ChildItem -LiteralPath $root -Filter '*.json' -File -ErrorAction SilentlyContinue|Sort-Object LastWriteTimeUtc -Descending)){
    try{
      $row=Get-Content -LiteralPath $file.FullName -Raw -Encoding UTF8|ConvertFrom-Json
      if([string]$row.Schema -eq 'PMM_SAVE_ACTIVITY_V1'){$rows.Add($row)}
    }catch{}
  }
  return @($rows.ToArray())
}

