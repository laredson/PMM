<#
SaveService.ps1 - read-only save discovery/metadata plus backup/restore.
Metadata extraction must never mutate a Palworld save. If a field cannot be
read safely, PMM falls back to filesystem/container information. Restore always
creates a safety backup first.
#>

function Find-PalworldSaveRoot {
  $steam=Join-Path $env:LOCALAPPDATA 'Pal\Saved\SaveGames'
  if(Test-Path -LiteralPath $steam -PathType Container){return $steam}
  return ''
}

function Get-PMMSaveHeader([string]$Path){
  if(-not(Test-Path -LiteralPath $Path -PathType Leaf)){return $null}
  try{
    $fs=[IO.File]::Open($Path,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::ReadWrite)
    try{
      $b=New-Object byte[] 12
      $n=$fs.Read($b,0,12)
      if($n -lt 12){return $null}
      $unc=[BitConverter]::ToUInt32($b,0)
      $cmp=[BitConverter]::ToUInt32($b,4)
      $magic=[Text.Encoding]::ASCII.GetString($b,8,4)
      return [pscustomobject]@{Magic=$magic;UncompressedBytes=$unc;CompressedBytes=$cmp}
    } finally {$fs.Dispose()}
  }catch{return $null}
}

function Test-IsBackupSavePath([string]$Path){
  return ($Path -match '(?i)[\\/]backup[\\/]')
}

function Get-DirectorySizeBytes([string]$Path){
  $sum=(Get-ChildItem -LiteralPath $Path -File -Recurse -ErrorAction SilentlyContinue|Where-Object{-not(Test-IsBackupSavePath $_.FullName)}|Measure-Object -Property Length -Sum).Sum
  if($null -eq $sum){return [int64]0}
  return [int64]$sum
}

function Get-PMMLevelMetaLiteralValue([string]$Path,[string]$FieldName){
  # Current PlM LevelMeta files are small and the property-name/string literals normally
  # remain directly visible in the Oodle stream. This read-only fast path lets PMM show
  # the world name without altering or decompressing the save. If a future build no
  # longer exposes the literal, callers simply fall back to the world folder ID.
  if(-not(Test-Path -LiteralPath $Path -PathType Leaf)){return $null}
  try{
    $bytes=[IO.File]::ReadAllBytes($Path)
    if($bytes.Length -lt 16){return $null}
    $latin1=[Text.Encoding]::GetEncoding(28591)
    $raw=$latin1.GetString($bytes)
    $idx=$raw.IndexOf($FieldName,[StringComparison]::Ordinal)
    if($idx -lt 0){return $null}
    $take=[Math]::Min(384,$raw.Length-$idx)
    $segment=$raw.Substring($idx,$take)
    $matches=@([regex]::Matches($segment,'[\x20-\x7E]{1,160}')|ForEach-Object{$_.Value})
    for($i=0;$i -lt $matches.Count;$i++){
      if($matches[$i] -ceq $FieldName){
        for($j=$i+1;$j -lt [Math]::Min($i+7,$matches.Count);$j++){
          $candidate=[string]$matches[$j]
          if($candidate -in @('StrProperty','IntProperty','StructProperty','ByteProperty','NameProperty','BoolProperty')){continue}
          if($candidate -in @('WorldName','HostPlayerName','HostPlayerLevel','InGameDay','None')){continue}
          if([string]::IsNullOrWhiteSpace($candidate)){continue}
          return $candidate.Trim()
        }
      }
    }
  }catch{Write-PMMLog ("LevelMeta literal read failed for {0}: {1}" -f $Path,$_.Exception.Message)}
  return $null
}

function Get-PMMLevelMetaPreview([string]$Path){
  if(-not(Test-Path -LiteralPath $Path -PathType Leaf)){return [pscustomobject]@{WorldName=$null;HostPlayerName=$null}}
  return [pscustomobject]@{
    WorldName=(Get-PMMLevelMetaLiteralValue $Path 'WorldName')
    HostPlayerName=(Get-PMMLevelMetaLiteralValue $Path 'HostPlayerName')
  }
}

function Get-PMMSaveWorlds {
  $cfg=Get-PMMConfig
  $root=$cfg.SaveRoot
  if(-not $root){$root=Find-PalworldSaveRoot}
  if(-not $root -or -not(Test-Path -LiteralPath $root -PathType Container)){return @()}

  $worlds=@(Get-ChildItem -LiteralPath $root -Directory -Recurse -ErrorAction SilentlyContinue|Where-Object{
    -not (Test-IsBackupSavePath $_.FullName) -and (Test-Path -LiteralPath (Join-Path $_.FullName 'Level.sav') -PathType Leaf)
  })
  $result=New-Object System.Collections.Generic.List[object]
  foreach($w in $worlds){
    $size=Get-DirectorySizeBytes $w.FullName
    $levelPath=Join-Path $w.FullName 'Level.sav'
    $levelItem=Get-Item -LiteralPath $levelPath -ErrorAction SilentlyContinue
    $lastWrite=if($levelItem){$levelItem.LastWriteTime}else{$w.LastWriteTime}
    $header=Get-PMMSaveHeader $levelPath
    $metaPath=Join-Path $w.FullName 'LevelMeta.sav'
    $metaPreview=Get-PMMLevelMetaPreview $metaPath
    $worldName=if($metaPreview.WorldName){[string]$metaPreview.WorldName}else{[string]$w.Name}
    $hostName=if($metaPreview.HostPlayerName){[string]$metaPreview.HostPlayerName}else{$null}
    $playersPath=Join-Path $w.FullName 'Players'
    $players=@()
    if(Test-Path -LiteralPath $playersPath -PathType Container){$players=@(Get-ChildItem -LiteralPath $playersPath -Filter *.sav -File -ErrorAction SilentlyContinue|Where-Object{$_.Name -notlike '*_dps.sav'})}
    $backupRoot=Join-Path $w.FullName 'backup\world'
    $backupCount=0
    if(Test-Path -LiteralPath $backupRoot -PathType Container){$backupCount=(@(Get-ChildItem -LiteralPath $backupRoot -Directory -ErrorAction SilentlyContinue)).Count}
    $format=if($header){$header.Magic}else{'Unknown'}
    $display=("{0}  |  {1}  |  {2:N1} MB" -f $worldName,$lastWrite,$($size/1MB))
    $result.Add([pscustomobject]@{
      Name=$w.Name;WorldId=$w.Name;WorldName=$worldName;DisplayName=$worldName;HostPlayerName=$hostName;Path=$w.FullName;LastWrite=$lastWrite;SizeMB=[math]::Round($size/1MB,2);
      SaveFormat=$format;Players=$players.Count;BackupSnapshots=$backupCount;HasLevelMeta=(Test-Path -LiteralPath $metaPath -PathType Leaf);Display=$display
    })
  }
  return @($result.ToArray()|Sort-Object LastWrite -Descending)
}

function Get-PMMSaveDetails($Selected){
  $s=if($Selected -and $Selected.PSObject.Properties['Path']){$Selected}else{$null}
  if(-not $s){return (Get-PMMText 'The selected world could not be resolved.' 'No se pudo resolver el mundo seleccionado.')}
  $level=Join-Path $s.Path 'Level.sav'
  $meta=Join-Path $s.Path 'LevelMeta.sav'
  $local=Join-Path $s.Path 'LocalData.sav'
  $worldOption=Join-Path $s.Path 'WorldOption.sav'
  $header=Get-PMMSaveHeader $level
  $metaHeader=Get-PMMSaveHeader $meta
  $detail=[ordered]@{
    WorldName=$(if($s.PSObject.Properties['WorldName']){$s.WorldName}else{$s.Name})
    WorldId=$(if($s.PSObject.Properties['WorldId']){$s.WorldId}else{$s.Name})
    Folder=$s.Path
    HostPlayer=$(if($s.PSObject.Properties['HostPlayerName'] -and $s.HostPlayerName){$s.HostPlayerName}else{(Get-PMMText 'Unknown' 'Desconocido')})
    LastModified=$s.LastWrite
    SizeMB=$s.SizeMB
    SaveFormat=$(if($header){$header.Magic}else{'Unknown'})
    LevelUncompressedMB=$(if($header){[math]::Round($header.UncompressedBytes/1MB,2)}else{$null})
    PlayerFiles=[int]$s.Players
    BackupSnapshots=[int]$s.BackupSnapshots
    LevelMeta=$(if(Test-Path -LiteralPath $meta -PathType Leaf){'Present'}else{'Missing'})
    LevelMetaFormat=$(if($metaHeader){$metaHeader.Magic}else{$null})
    LocalData=$(if(Test-Path -LiteralPath $local -PathType Leaf){'Present'}else{'Missing'})
    WorldOption=$(if(Test-Path -LiteralPath $worldOption -PathType Leaf){'Present'}else{'Missing'})
  }
  $lines=New-Object System.Collections.Generic.List[string]
  foreach($kv in $detail.GetEnumerator()){$lines.Add(("{0}: {1}" -f $kv.Key,$kv.Value))}
  if(($s.PSObject.Properties['WorldName']) -and $s.WorldName -eq $s.Name){
    $lines.Add('')
    $lines.Add((Get-PMMText 'World name could not be read safely from LevelMeta.sav, so PMM is showing the world-folder ID as a fallback.' 'No se pudo leer con seguridad el nombre desde LevelMeta.sav; PMM muestra como alternativa el ID de la carpeta del mundo.'))
  }
  return ($lines -join [Environment]::NewLine)
}



function Get-PMMSaveBackups($Selected){
  if(-not$Selected -or -not($Selected.PSObject.Properties.Name -contains 'Name')){return @()}
  $dir=Join-Path (Join-PMMPath 'Saves' 'Backups') ([string]$Selected.Name)
  if(-not(Test-Path -LiteralPath $dir -PathType Container)){return @()}
  Add-Type -AssemblyName System.IO.Compression.FileSystem
  $currentBytes=0L;$currentFiles=0
  try{
    $live=@(Get-ChildItem -LiteralPath ([string]$Selected.Path) -File -Recurse -ErrorAction SilentlyContinue|Where-Object{-not(Test-IsBackupSavePath $_.FullName)})
    $currentFiles=$live.Count
    foreach($f in $live){$currentBytes+=[int64]$f.Length}
  }catch{}
  $rows=[System.Collections.Generic.List[object]]::new()
  foreach($zip in @(Get-ChildItem -LiteralPath $dir -Filter '*.zip' -File -ErrorAction SilentlyContinue|Sort-Object LastWriteTime -Descending)){
    [int64]$expanded=0;$files=0;$valid=$true;$error=''
    try{
      $a=[IO.Compression.ZipFile]::OpenRead($zip.FullName)
      try{foreach($e in $a.Entries){if([string]::IsNullOrWhiteSpace([string]$e.FullName) -or ([string]$e.FullName).EndsWith('/')){continue};$files++;$expanded+=[int64]$e.Length}}finally{$a.Dispose()}
    }catch{$valid=$false;$error=$_.Exception.Message}
    $deltaBytes=$expanded-$currentBytes;$deltaFiles=$files-$currentFiles
    $display=('{0}  |  {1:N2} MB  |  {2} files' -f $zip.LastWriteTime,($zip.Length/1MB),$files)
    $rows.Add([pscustomobject]@{
      Name=$zip.Name;Path=$zip.FullName;Created=$zip.LastWriteTime;CreatedDisplay=$zip.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss');
      ZipMB=[math]::Round($zip.Length/1MB,2);ExpandedMB=[math]::Round($expanded/1MB,2);FileCount=$files;Valid=$valid;Error=$error;
      CurrentMB=[math]::Round($currentBytes/1MB,2);CurrentFiles=$currentFiles;DeltaMB=[math]::Round($deltaBytes/1MB,2);DeltaFiles=$deltaFiles;Display=$display
    })
  }
  return @($rows.ToArray())
}

function Get-PMMSaveBackupDetails($Backup,$Selected){
  if(-not$Backup){return (Get-PMMText 'Select a PMM backup to inspect it.' 'Selecciona un backup PMM para inspeccionarlo.')}
  $validText=if([bool]$Backup.Valid){Get-PMMText 'Valid ZIP' 'ZIP valido'}else{Get-PMMText 'Unreadable / invalid ZIP' 'ZIP ilegible / invalido'}
  $deltaSign=if([double]$Backup.DeltaMB -gt 0){'+'}else{''}
  $fileSign=if([int]$Backup.DeltaFiles -gt 0){'+'}else{''}
  $lines=@(
    ((Get-PMMText 'Backup: {0}' 'Backup: {0}') -f [string]$Backup.Name),
    ((Get-PMMText 'Created: {0}' 'Creado: {0}') -f [string]$Backup.CreatedDisplay),
    ((Get-PMMText 'Archive size: {0:N2} MB' 'Tamano del archivo: {0:N2} MB') -f [double]$Backup.ZipMB),
    ((Get-PMMText 'Contents: {0:N2} MB | {1} files' 'Contenido: {0:N2} MB | {1} archivos') -f [double]$Backup.ExpandedMB,[int]$Backup.FileCount),
    ((Get-PMMText 'Current save: {0:N2} MB | {1} files' 'Save actual: {0:N2} MB | {1} archivos') -f [double]$Backup.CurrentMB,[int]$Backup.CurrentFiles),
    ((Get-PMMText 'Difference vs current: {0}{1:N2} MB | {2}{3} files' 'Diferencia frente al actual: {0}{1:N2} MB | {2}{3} archivos') -f $deltaSign,[double]$Backup.DeltaMB,$fileSign,[int]$Backup.DeltaFiles),
    ((Get-PMMText 'Integrity: {0}' 'Integridad: {0}') -f $validText),
    ((Get-PMMText 'Path: {0}' 'Ruta: {0}') -f [string]$Backup.Path)
  )
  if(-not[bool]$Backup.Valid -and -not[string]::IsNullOrWhiteSpace([string]$Backup.Error)){$lines+=((Get-PMMText 'Error: {0}' 'Error: {0}') -f [string]$Backup.Error)}
  return ($lines -join [Environment]::NewLine)
}

function New-PMMSaveArchive([string]$SourceDirectory,[string]$OutputZip){
  if(-not(Test-Path -LiteralPath $SourceDirectory -PathType Container)){throw ('Save backup source directory is missing: '+$SourceDirectory)}
  $runtime=Get-PMMRuntimePath
  if(-not(Test-Path -LiteralPath $runtime -PathType Leaf)){throw 'PMMRuntime.exe is required to create save backups.'}
  $partial=$OutputZip+'.partial'
  try{
    Remove-Item -LiteralPath $partial -Force -ErrorAction SilentlyContinue
    $output=@(& $runtime archive create $partial $SourceDirectory 2>&1|ForEach-Object{[string]$_})
    $exit=$LASTEXITCODE
    if($exit -ne 0 -or -not(Test-Path -LiteralPath $partial -PathType Leaf)){
      throw ('PMMRuntime archive create failed with exit '+$exit+'. '+($output -join ' '))
    }
    if([int64](Get-Item -LiteralPath $partial).Length -le 0){throw 'PMMRuntime created an empty save backup ZIP.'}
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $archive=[IO.Compression.ZipFile]::OpenRead($partial)
    try{if($archive.Entries.Count -eq 0){throw 'PMMRuntime created a save backup ZIP with no files.'}}finally{$archive.Dispose()}
    Remove-Item -LiteralPath $OutputZip -Force -ErrorAction SilentlyContinue
    Move-Item -LiteralPath $partial -Destination $OutputZip -Force
  }finally{Remove-Item -LiteralPath $partial -Force -ErrorAction SilentlyContinue}
}

function Backup-PMMSave($Selected){
  $s=if($Selected -and $Selected.PSObject.Properties['Path']){$Selected}else{throw (Get-PMMText 'Invalid world selection.' 'Selección de mundo inválida.')}
  $dir=Join-Path (Join-PMMPath 'Saves' 'Backups') $s.Name
  New-Item -ItemType Directory -Force -Path $dir|Out-Null
  $zip=Join-Path $dir ((Get-Date -Format 'yyyyMMdd_HHmmss')+'.zip')
  New-PMMSaveArchive $s.Path $zip
  Write-PMMLog "Save backup: $zip"
  return $zip
}

function Assert-PMMSaveArchiveWorkingSpace([string]$ZipPath,[string]$Destination){
  Add-Type -AssemblyName System.IO.Compression.FileSystem
  $archive=[IO.Compression.ZipFile]::OpenRead($ZipPath)
  [int64]$expanded=0
  try{
    foreach($entry in $archive.Entries){
      if([string]::IsNullOrWhiteSpace([string]$entry.FullName) -or ([string]$entry.FullName).EndsWith('/')){continue}
      if([int64]$entry.Length -lt 0 -or $expanded -gt ([int64]::MaxValue-[int64]$entry.Length)){throw 'Save backup ZIP size metadata is invalid.'}
      $expanded+=[int64]$entry.Length
    }
  }finally{$archive.Dispose()}
  [int64]$required=$expanded+256MB
  [int64]$free=-1
  try{
    $probe=$Destination
    while($probe -and -not(Test-Path -LiteralPath $probe -PathType Container)){$probe=Split-Path -Parent $probe}
    if(-not$probe){$probe=$Script:Root}
    $item=Get-Item -LiteralPath $probe -ErrorAction Stop
    if($item.PSDrive -and $null -ne $item.PSDrive.Free){$free=[int64]$item.PSDrive.Free}
  }catch{}
  if($free -lt 0){
    try{$driveRoot=[IO.Path]::GetPathRoot([IO.Path]::GetFullPath($Destination));if($driveRoot){$free=[int64]([IO.DriveInfo]::new($driveRoot).AvailableFreeSpace)}}catch{}
  }
  if($free -ge 0 -and $free -lt $required){
    throw ((Get-PMMText 'The save backup needs about {0:N1} GB of temporary space, but only {1:N1} GB are free. Restore was stopped before extraction.' 'El backup necesita unos {0:N1} GB de espacio temporal, pero solo hay {1:N1} GB libres. La restauracion se detuvo antes de extraer.') -f ($required/1GB),($free/1GB))
  }
  if($free -lt 0){Write-PMMLog ('Save restore free-space preflight unavailable for '+$Destination+'; safe runtime extraction will continue.')}
  return [pscustomobject]@{ExpandedBytes=$expanded;RequiredWorkingBytes=$required;FreeBytes=$free}
}

function Expand-PMMSaveArchiveSafe([string]$ZipPath,[string]$Destination){
  if(-not(Test-Path -LiteralPath $ZipPath -PathType Leaf)){throw ('Save backup ZIP is missing: '+$ZipPath)}
  $runtime=Get-PMMRuntimePath
  if(-not(Test-Path -LiteralPath $runtime -PathType Leaf)){throw 'PMMRuntime.exe is required to restore save backups safely.'}
  [void](Assert-PMMSaveArchiveWorkingSpace $ZipPath $Destination)
  New-Item -ItemType Directory -Force -Path $Destination|Out-Null
  $output=@(& $runtime archive extract $ZipPath $Destination 2>&1|ForEach-Object{[string]$_})
  if($LASTEXITCODE -ne 0){throw ('PMMRuntime archive extract failed while reading the save backup. '+($output -join ' '))}
  if(-not(Test-Path -LiteralPath (Join-Path $Destination 'Level.sav') -PathType Leaf)){
    throw 'The selected ZIP is not a PMM world backup: Level.sav is missing at the archive root.'
  }
}

function Restore-PMMSaveFromArchive($Selected,[string]$ZipPath){
  if(-not$Selected -or -not($Selected.PSObject.Properties.Name -contains 'Path') -or -not(Test-Path -LiteralPath ([string]$Selected.Path) -PathType Container)){
    throw (Get-PMMText 'Invalid world selection.' 'Seleccion de mundo invalida.')
  }
  if([string]::IsNullOrWhiteSpace($ZipPath) -or -not(Test-Path -LiteralPath $ZipPath -PathType Leaf)){throw (Get-PMMText 'The selected backup file does not exist.' 'El backup seleccionado no existe.')}
  $stage=Join-Path (Get-PMMPath 'Cache') ('SaveRestore_'+[guid]::NewGuid().ToString('N'))
  New-Item -ItemType Directory -Force -Path $stage|Out-Null
  Set-PMMTransientStageOwner $stage 'SaveRestore'
  try{
    Expand-PMMSaveArchiveSafe $ZipPath $stage
    Stop-PalworldForDeployment
    $s=$Selected
    $safety=Backup-PMMSave $s
    try{
      Get-ChildItem -LiteralPath $s.Path -Force -ErrorAction SilentlyContinue|Remove-Item -Recurse -Force -ErrorAction Stop
      foreach($entry in @(Get-ChildItem -LiteralPath $stage -Force -ErrorAction Stop)){Copy-Item -LiteralPath $entry.FullName -Destination $s.Path -Recurse -Force -ErrorAction Stop}
      if(-not(Test-Path -LiteralPath (Join-Path $s.Path 'Level.sav') -PathType Leaf)){throw 'Restored save verification failed: Level.sav is missing.'}
      Write-PMMLog "Save restored from $ZipPath; safety backup $safety"
      return $safety
    }catch{
      $restoreError=$_.Exception.Message
      Write-PMMLog ('Save restore failed after safety backup; attempting automatic rollback: '+$restoreError)
      try{
        Get-ChildItem -LiteralPath $s.Path -Force -ErrorAction SilentlyContinue|Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
        Expand-PMMSaveArchiveSafe $safety $s.Path
        Write-PMMLog ('Save restore rollback succeeded from '+$safety)
        throw ('Save restore failed, but PMM restored the original world from its safety backup. '+$restoreError)
      }catch{
        if($_.Exception.Message -like 'Save restore failed, but PMM restored the original world*'){throw}
        throw ('Save restore failed and automatic rollback also failed. The safety backup is preserved at '+$safety+'. Original error: '+$restoreError+' | Rollback error: '+$_.Exception.Message)
      }
    }
  }finally{
    Remove-Item -LiteralPath $stage -Recurse -Force -ErrorAction SilentlyContinue
    Remove-PMMTransientStageOwner $stage
  }
}

function Restore-PMMSaveInteractive($Selected){
  if(-not$Selected -or -not($Selected.PSObject.Properties.Name -contains 'Path') -or -not(Test-Path -LiteralPath ([string]$Selected.Path) -PathType Container)){throw (Get-PMMText 'Invalid world selection.' 'Seleccion de mundo invalida.')}
  Add-Type -AssemblyName System.Windows.Forms
  $dlg=New-Object System.Windows.Forms.OpenFileDialog
  $dlg.Filter=(Get-PMMText 'Save backups (*.zip)|*.zip' 'Backups de save (*.zip)|*.zip')
  $dlg.InitialDirectory=Join-Path (Join-PMMPath 'Saves' 'Backups') $Selected.Name
  if($dlg.ShowDialog()-ne[System.Windows.Forms.DialogResult]::OK){return}
  return (Restore-PMMSaveFromArchive $Selected ([string]$dlg.FileName))
}

