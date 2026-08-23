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

function Backup-PMMSave($Selected){
  $s=if($Selected -and $Selected.PSObject.Properties['Path']){$Selected}else{throw (Get-PMMText 'Invalid world selection.' 'Selección de mundo inválida.')}
  $dir=Join-Path $Script:Root ('Saves\Backups\'+$s.Name)
  New-Item -ItemType Directory -Force -Path $dir|Out-Null
  $zip=Join-Path $dir ((Get-Date -Format 'yyyyMMdd_HHmmss')+'.zip')
  Compress-Archive -Path (Join-Path $s.Path '*') -DestinationPath $zip -CompressionLevel Optimal
  Write-PMMLog "Save backup: $zip"
  return $zip
}

function Restore-PMMSaveInteractive($Selected){
  Add-Type -AssemblyName System.Windows.Forms
  $dlg=New-Object System.Windows.Forms.OpenFileDialog
  $dlg.Filter=(Get-PMMText 'Save backups (*.zip)|*.zip' 'Backups de save (*.zip)|*.zip')
  $dlg.InitialDirectory=Join-Path $Script:Root ('Saves\Backups\'+$Selected.Name)
  if($dlg.ShowDialog()-ne[System.Windows.Forms.DialogResult]::OK){return}
  Stop-PalworldForDeployment
  $s=$Selected
  $safety=Backup-PMMSave $s
  Get-ChildItem -LiteralPath $s.Path -Force -ErrorAction SilentlyContinue|Remove-Item -Recurse -Force -ErrorAction Stop
  Expand-Archive -LiteralPath $dlg.FileName -DestinationPath $s.Path -Force
  Write-PMMLog "Save restored from $($dlg.FileName); safety backup $safety"
}
