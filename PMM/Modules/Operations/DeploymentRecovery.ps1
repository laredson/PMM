<# Durable deployment recovery. A manifest is a recovery record, never permission
   to write an arbitrary path. Resolve every target against current PMM roots. #>
function Assert-PMMRecoveryPath([string]$Path,[string]$Root,[switch]$DirectChild) {
  $full=[IO.Path]::GetFullPath($Path);$base=[IO.Path]::GetFullPath($Root).TrimEnd('\','/')
  if(-not$full.StartsWith($base+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)){throw "Recovery path escapes its expected root: $full"}
  if($DirectChild -and [IO.Path]::GetDirectoryName($full) -ine $base){throw 'Recovery target must be a direct child of its expected root.'}
  $cursor=$full
  while($cursor){
    if(Test-Path -LiteralPath $cursor){if(([IO.File]::GetAttributes($cursor) -band [IO.FileAttributes]::ReparsePoint) -ne 0){throw "Recovery cannot traverse a reparse point: $cursor"}}
    $parent=[IO.Path]::GetDirectoryName($cursor);if($parent -eq $cursor){break};$cursor=$parent
  }
  return $full
}
function Get-PMMDeploymentBackupRoot {return (Join-PMMPath 'Builds' 'DeploymentBackups')}
function Get-PMMRecoveryHash([string]$Path) {return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()}
function Open-PMMDeploymentLock {
  $path=Join-PMMPath 'Cache' 'PMM.deployment.lock'
  try{return [IO.File]::Open($path,[IO.FileMode]::OpenOrCreate,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)}catch{throw 'Another PMM deployment or recovery is in progress.'}
}
function Get-PMMPendingDeploymentRecovery {
  $root=Get-PMMDeploymentBackupRoot
  if(-not(Test-Path -LiteralPath $root -PathType Container)){return @()}
  foreach($dir in @(Get-ChildItem -LiteralPath $root -Directory | Sort-Object Name)){
    try{
      [void](Assert-PMMRecoveryPath $dir.FullName $root -DirectChild)
      $path=Join-Path $dir.FullName 'transaction.json'
      if(-not(Test-Path -LiteralPath $path -PathType Leaf)){continue} # old staging-only folders never entered commit
      $record=Read-PMMJsonFile $path
      if([string]$record.State -notin @('Committed','RolledBack','Aborted')){[pscustomobject]@{Path=$path;State=[string]$record.State;Record=$record;Error=''}}
    }catch{[pscustomobject]@{Path=(Join-Path $dir.FullName 'transaction.json');State='Invalid';Record=$null;Error=$_.Exception.Message}}
  }
}
function Assert-PMMDeploymentRecoveryComplete {
  $pending=@(Get-PMMPendingDeploymentRecovery)
  if($pending.Count){throw ('Deployment is blocked until interrupted deployment recovery completes: '+(($pending|ForEach-Object{$_.Path+' ['+$_.State+']'}) -join '; '))}
}
function Save-PMMDeploymentCheckpoint($Transaction,[string]$Path,[string]$Phase,[int]$Step=-1) {
  $Transaction.State=$Phase;$Transaction.UpdatedUtc=[DateTime]::UtcNow.ToString('o');$Transaction.Step=$Step
  Write-PMMJsonAtomic -Path $Path -Value $Transaction -Depth 30 -Schema 'PMM_DEPLOYMENT_TRANSACTION_V2'
}
function Convert-PMMLegacyDeploymentRecord($Record,[string]$Path,[string]$GameMods) {
  # V1 Prepared is the only old format retaining the full rollback contract.
  # V1 RollbackIncomplete lost that metadata and must remain visibly blocked.
  if([int]$Record.SchemaVersion -ne 1 -or [string]$Record.State -ne 'Prepared'){throw 'Legacy recovery metadata is incomplete; preserve the folder for manual recovery.'}
  $backupRoot=Split-Path -Parent $Path;$id=Split-Path -Leaf $backupRoot
  $files=@(foreach($target in @($Record.Touched)){
    [void](Assert-PMMRecoveryPath ([string]$target) $GameMods -DirectChild)
    $old=@($Record.Backups|Where-Object{[string]$_.Original -ieq [string]$target}|Select-Object -First 1)
    $new=@($Record.Copies|Where-Object{[string]$_.Destination -ieq [string]$target}|Select-Object -First 1)
    $backup=if($old.Count){[string]$old[0].Backup}else{''}
    if($backup){[void](Assert-PMMRecoveryPath $backup $backupRoot -DirectChild)}
    [pscustomobject]@{Target=[string]$target;Existed=($old.Count -gt 0);Backup=$backup;BeforeHash=$(if($backup){Get-PMMRecoveryHash $backup}else{''});AfterHash=$(if($new.Count){[string]$new[0].ExpectedHash}else{''})}
  })
  $states=@(foreach($item in @(@('deployment-state.json','deployment-state.before.json',[bool]$Record.DeploymentStateExisted),@('pending-removals.json','pending-removals.before.json',[bool]$Record.PendingRemovalsExisted))){
    $backup=Join-Path $backupRoot $item[1]
    [pscustomobject]@{Target=(Join-PMMPath 'State' $item[0]);Existed=[bool]$item[2];Backup=$(if($item[2]){$backup}else{''});BeforeHash=$(if($item[2]){Get-PMMRecoveryHash $backup}else{''});AfterHash='';Legacy=$true}
  })
  return [pscustomobject]@{Schema='PMM_DEPLOYMENT_TRANSACTION_V2';SchemaVersion=2;Id=$id;State='Committing';CreatedUtc=[DateTime]::UtcNow.ToString('o');UpdatedUtc='';Step=-1;Workspace=(Get-PMMPath 'Workspace');GameMods=$GameMods;StageRoot=(Join-Path $GameMods ('.pmm-stage-'+$id));Files=$files;StateFiles=$states;RollbackErrors=@();Error='';OwnerPid=0;OwnerStartedUtc=''}
}
function Restore-PMMRecoveryFile($Record,[string]$BackupRoot,[string]$ExpectedRoot,[switch]$StateFile) {
  $target=Assert-PMMRecoveryPath ([string]$Record.Target) $ExpectedRoot -DirectChild
  if($StateFile -and [IO.Path]::GetFileName($target) -notin @('deployment-state.json','pending-removals.json')){throw 'Recovery state target is not supported.'}
  if([bool]$Record.Existed){
    $backup=Assert-PMMRecoveryPath ([string]$Record.Backup) $BackupRoot -DirectChild
    if((Get-PMMRecoveryHash $backup) -ne [string]$Record.BeforeHash){throw "Recovery backup is missing or corrupted: $backup"}
  }
  if([IO.File]::Exists($target)){
    $current=Get-PMMRecoveryHash $target
    if([bool]$Record.Existed -and $current -eq [string]$Record.BeforeHash){return}
    $legacyState=$StateFile -and ($Record.PSObject.Properties.Name -contains 'Legacy') -and [bool]$Record.Legacy
    if(-not$legacyState -and ($current -ne [string]$Record.AfterHash -or -not[string]$Record.AfterHash)){throw "Recovery found externally modified bytes; preserved target: $target"}
  }
  if([bool]$Record.Existed){
    $temp=$target+'.pmmrestore.'+[guid]::NewGuid().ToString('N')
    try{
      # Flush the complete old bytes before the atomic replacement.
      $source=[IO.File]::OpenRead($backup);$dest=[IO.File]::Open($temp,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
      try{$source.CopyTo($dest);$dest.Flush($true)}finally{$source.Dispose();$dest.Dispose()}
      if([IO.File]::Exists($target)){[IO.File]::Replace($temp,$target,[NullString]::Value,$true)}else{[IO.File]::Move($temp,$target)}
      if((Get-PMMRecoveryHash $target) -ne [string]$Record.BeforeHash){throw 'Restored bytes failed verification.'}
    }finally{if([IO.File]::Exists($temp)){[IO.File]::Delete($temp)}}
  }elseif([IO.File]::Exists($target)){[IO.File]::Delete($target)}
}
function Repair-PMMDeploymentRecord {
  param([string]$Path,[string]$GameMods)
  $backupRoot=Split-Path -Parent $Path
  [void](Assert-PMMRecoveryPath $backupRoot (Get-PMMDeploymentBackupRoot) -DirectChild)
  [void](Assert-PMMRecoveryPath $Path $backupRoot -DirectChild)
  $record=Read-PMMJsonFile $Path
  $actualGame=[IO.Path]::GetFullPath($GameMods).TrimEnd('\','/')
  if([IO.Path]::GetFullPath([string]$record.GameMods).TrimEnd('\','/') -ine $actualGame){throw 'Recovery belongs to another game installation; select that installation before recovering.'}
  if(-not($record.PSObject.Properties.Name -contains 'Schema') -or [string]$record.Schema -ne 'PMM_DEPLOYMENT_TRANSACTION_V2'){$record=Convert-PMMLegacyDeploymentRecord $record $Path $actualGame}
  if([string]$record.Workspace -ine (Get-PMMPath 'Workspace')){throw 'Recovery workspace does not match the current PMM workspace.'}
  $stage=Assert-PMMRecoveryPath ([string]$record.StageRoot) $actualGame -DirectChild
  if([IO.Path]::GetFileName($stage) -cne ('.pmm-stage-'+[string]$record.Id)){throw 'Recovery stage identity does not match its transaction.'}
  # Validate every path and backup before the first mutation.
  foreach($file in @($record.Files)){
    [void](Assert-PMMRecoveryPath ([string]$file.Target) $actualGame -DirectChild)
    if([bool]$file.Existed){[void](Assert-PMMRecoveryPath ([string]$file.Backup) $backupRoot -DirectChild)}
  }
  foreach($file in @($record.StateFiles)){
    [void](Assert-PMMRecoveryPath ([string]$file.Target) (Get-PMMPath 'State') -DirectChild)
    if([IO.Path]::GetFileName([string]$file.Target) -notin @('deployment-state.json','pending-removals.json')){throw 'Unexpected recovery state target.'}
    if([bool]$file.Existed){[void](Assert-PMMRecoveryPath ([string]$file.Backup) $backupRoot -DirectChild)}
  }
  if([string]$record.State -in @('Committed','RolledBack','Aborted')){return $record}
  if([string]$record.State -in @('Preparing','Prepared')){
    Save-PMMDeploymentCheckpoint $record $Path 'Aborted'
  }else{
    Save-PMMDeploymentCheckpoint $record $Path 'RollingBack'
    $errors=[Collections.Generic.List[string]]::new()
    foreach($file in @($record.Files)){try{Restore-PMMRecoveryFile $file $backupRoot $actualGame}catch{$errors.Add($_.Exception.Message)}}
    foreach($file in @($record.StateFiles)){try{Restore-PMMRecoveryFile $file $backupRoot (Get-PMMPath 'State') -StateFile}catch{$errors.Add($_.Exception.Message)}}
    $record.RollbackErrors=$errors.ToArray()
    $phase=if($errors.Count){'RollbackIncomplete'}else{'RolledBack'}
    Save-PMMDeploymentCheckpoint $record $Path $phase
    if($errors.Count){throw ('Deployment rollback incomplete: '+($errors -join '; '))}
  }
  if(Test-Path -LiteralPath $stage -PathType Container){
    try{Assert-PMMRecoveryFlatDirectory $stage $actualGame;Remove-Item -LiteralPath $stage -Recurse -Force -ErrorAction Stop}
    catch{if(Get-Command Write-PMMLog -ErrorAction SilentlyContinue){Write-PMMLog ('Recovery completed; stage preserved after cleanup warning: '+$_.Exception.Message)}}
  }
  return $record
}
function Invoke-PMMDeploymentRecovery {
  $results=[Collections.Generic.List[object]]::new();$pending=@(Get-PMMPendingDeploymentRecovery)
  if(-not$pending.Count){return @()}
  $lock=$null;$gameLock=$null;$processingGate=$null
  try{
    $processingGate=[IO.File]::Open((Join-PMMPath 'Cache' 'PMM.background-operation.lock'),[IO.FileMode]::OpenOrCreate,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)
    $lock=Open-PMMDeploymentLock
    $game=Get-GameModsPath
    if(-not$game -or -not(Test-Path -LiteralPath $game -PathType Container)){throw 'Configure the original game installation to recover interrupted deployment.'}
    $install=$game;1..4|ForEach-Object{$install=Split-Path -Parent $install}
    foreach($process in @(Get-Process -Name 'Palworld-Win64-Shipping','Palworld' -ErrorAction SilentlyContinue)){
      $exe='';try{$exe=[string]$process.Path}catch{}
      if(-not$exe -or $exe.StartsWith(([IO.Path]::GetFullPath($install).TrimEnd('\','/')+[IO.Path]::DirectorySeparatorChar),[StringComparison]::OrdinalIgnoreCase)){throw 'Close the selected Palworld installation before recovering its interrupted deployment.'}
    }
    $gameLockPath=Assert-PMMRecoveryPath (Join-Path $game '.pmm-deployment.lock') $game -DirectChild
    $gameLock=[IO.File]::Open($gameLockPath,[IO.FileMode]::OpenOrCreate,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)
    foreach($item in $pending){
      try{
        if($item.Error){throw $item.Error}
        $record=Repair-PMMDeploymentRecord -Path $item.Path -GameMods $game
        $results.Add([pscustomobject]@{Path=$item.Path;State=$record.State;Recovered=$true;Error=''})
      }catch{$results.Add([pscustomobject]@{Path=$item.Path;State='Blocked';Recovered=$false;Error=$_.Exception.Message})}
    }
  }catch{foreach($item in $pending){$results.Add([pscustomobject]@{Path=$item.Path;State='Blocked';Recovered=$false;Error=$_.Exception.Message})}}
  finally{if($gameLock){$gameLock.Dispose()};if($lock){$lock.Dispose()};if($processingGate){$processingGate.Dispose()}}
  return $results.ToArray()
}

function Assert-PMMRecoveryFlatDirectory([string]$Path,[string]$Root) {
  [void](Assert-PMMRecoveryPath $Path $Root -DirectChild)
  foreach($child in @(Get-ChildItem -LiteralPath $Path -Force)){
    [void](Assert-PMMRecoveryPath $child.FullName $Path -DirectChild)
    if($child.PSIsContainer){throw 'Recovery cleanup preserves unexpected nested directories.'}
  }
}
