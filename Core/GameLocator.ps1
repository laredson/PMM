<#
GameLocator.ps1 - discovers and validates Palworld installations.
Windows paths are normalized case-insensitively because C:\Game and c:\Game
refer to the same location. Detection supports Steam discovery plus a generic
manual Palworld folder; launcher-specific adapters can be added here later.
#>

# Canonicalize one user/registry path. Drive-letter case and trailing slashes
# must never create duplicate installations in the UI.
function Normalize-PMMWindowsPath([string]$Path){
  if(-not $Path){return $null}
  try{$p=[IO.Path]::GetFullPath($Path)}catch{return $null}
  if($p.Length -gt 3){
    $trimChars=[char[]]@([char]92,[char]47)
    $p=$p.TrimEnd($trimChars)
  }
  if($p -match '^[a-zA-Z]:'){ $p=$p.Substring(0,1).ToUpperInvariant()+$p.Substring(1) }
  return $p
}

function Get-UniqueWindowsPaths([object[]]$Paths){
  $seen=@{}
  $out=New-Object System.Collections.Generic.List[string]
  foreach($raw in @($Paths)){
    if(-not $raw){continue}
    $p=Normalize-PMMWindowsPath ([string]$raw)
    if(-not $p){continue}
    $key=$p.ToLowerInvariant()
    if(-not $seen.ContainsKey($key)){$seen[$key]=$true;$out.Add($p)}
  }
  return $out.ToArray()
}

# Accept a Palworld folder, Palworld.exe, or a nearby parent and return the
# validated game root only when both Palworld.exe and Pal\Content\Paks exist.
function Resolve-PalworldRoot([string]$Candidate){
  if(-not $Candidate){return $null}
  try { $p=[IO.Path]::GetFullPath($Candidate) } catch { return $null }
  if(Test-Path -LiteralPath $p -PathType Leaf){$p=Split-Path -Parent $p}
  $tests=Get-UniqueWindowsPaths @($p,(Split-Path -Parent $p),(Split-Path -Parent (Split-Path -Parent $p)))
  foreach($t in $tests){
    if((Test-Path -LiteralPath (Join-Path $t 'Palworld.exe') -PathType Leaf) -and (Test-Path -LiteralPath (Join-Path $t 'Pal\Content\Paks') -PathType Container)){return $t}
  }
  return $null
}

# Fast path: ask Windows where Steam is installed before scanning any drive.
function Get-SteamRootsFromRegistry {
  $roots=New-Object System.Collections.Generic.List[string]
  foreach($key in @('HKCU:\Software\Valve\Steam','HKLM:\SOFTWARE\WOW6432Node\Valve\Steam','HKLM:\SOFTWARE\Valve\Steam')){
    try{
      $p=Get-ItemProperty -LiteralPath $key -ErrorAction Stop
      foreach($prop in @('SteamPath','InstallPath')){
        if($p.PSObject.Properties.Name -contains $prop){
          $v=[string]$p.$prop
          if($v -and (Test-Path -LiteralPath $v -PathType Container)){$roots.Add([IO.Path]::GetFullPath($v))}
        }
      }
    }catch{}
  }
  return Get-UniqueWindowsPaths $roots
}

function Get-FixedDriveRoots {
  $drives=@([IO.DriveInfo]::GetDrives()|Where-Object{$_.DriveType -eq [IO.DriveType]::Fixed -and $_.IsReady}|ForEach-Object{$_.RootDirectory.FullName})
  return @($drives|Sort-Object @{Expression={if($_ -match '^C:\\'){0}else{1}}},@{Expression={$_}})
}

# Slow fallback: breadth-first search for Steam/steamapps on one fixed drive.
# System directories are skipped to keep startup bounded and avoid access noise.
function Find-SteamRootsOnDrive([string]$DriveRoot,[int]$MaxDepth=6){
  $found=New-Object System.Collections.Generic.List[string]
  $direct=@(
    (Join-Path $DriveRoot 'Steam'),
    (Join-Path $DriveRoot 'SteamLibrary'),
    (Join-Path $DriveRoot 'Games\Steam'),
    (Join-Path $DriveRoot 'Program Files\Steam'),
    (Join-Path $DriveRoot 'Program Files (x86)\Steam')
  )
  foreach($p in $direct){
    if((Test-Path -LiteralPath (Join-Path $p 'steamapps') -PathType Container) -or (Test-Path -LiteralPath (Join-Path $p 'steam.exe') -PathType Leaf)){$found.Add($p)}
  }

  $skip=@('$Recycle.Bin','System Volume Information','Recovery','Windows','WinSxS','ProgramData')
  $queue=New-Object 'System.Collections.Generic.Queue[object]'
  $queue.Enqueue([pscustomobject]@{Path=$DriveRoot;Depth=0})
  while($queue.Count -gt 0){
    $node=$queue.Dequeue()
    if($node.Depth -ge $MaxDepth){continue}
    $dirs=@(Get-ChildItem -LiteralPath $node.Path -Directory -Force -ErrorAction SilentlyContinue)
    foreach($d in $dirs){
      if($skip -contains $d.Name){continue}
      if($d.Name -ieq 'Steam'){
        if((Test-Path -LiteralPath (Join-Path $d.FullName 'steamapps') -PathType Container) -or (Test-Path -LiteralPath (Join-Path $d.FullName 'steam.exe') -PathType Leaf)){$found.Add($d.FullName)}
      }
      if($d.Name -ieq 'steamapps'){
        $parent=Split-Path -Parent $d.FullName
        if($parent){$found.Add($parent)}
        continue
      }
      $queue.Enqueue([pscustomobject]@{Path=$d.FullName;Depth=([int]$node.Depth+1)})
    }
  }
  return Get-UniqueWindowsPaths $found
}

function Get-SteamLibraryRootsFromSteamRoot([string]$SteamRoot){
  $roots=New-Object System.Collections.Generic.List[string]
  if(-not $SteamRoot){return @()}
  try{$root=[IO.Path]::GetFullPath($SteamRoot)}catch{return @()}
  if(Test-Path -LiteralPath $root -PathType Leaf){$root=Split-Path -Parent $root}
  $roots.Add($root)
  $vdf=Join-Path $root 'steamapps\libraryfolders.vdf'
  if(Test-Path -LiteralPath $vdf -PathType Leaf){
    try{
      $txt=Get-Content -LiteralPath $vdf -Raw
      [regex]::Matches($txt,'"path"\s+"([^"]+)"')|ForEach-Object{
        $lib=$_.Groups[1].Value -replace '\\\\','\\'
        if($lib -and (Test-Path -LiteralPath $lib -PathType Container)){$roots.Add([IO.Path]::GetFullPath($lib))}
      }
    }catch{Write-PMMLog "Could not parse Steam libraryfolders.vdf: $($_.Exception.Message)"}
  }
  return Get-UniqueWindowsPaths $roots
}

function Get-PalworldInstallationsFromSteamRoot([string]$SteamRoot){
  $games=New-Object System.Collections.Generic.List[string]
  $direct=Resolve-PalworldRoot $SteamRoot
  if($direct){$games.Add($direct)}
  foreach($lib in (Get-SteamLibraryRootsFromSteamRoot $SteamRoot)){
    foreach($candidate in @((Join-Path $lib 'steamapps\common\Palworld'),(Join-Path $lib 'common\Palworld'))){
      $r=Resolve-PalworldRoot $candidate
      if($r){$games.Add($r)}
    }
  }
  return Get-UniqueWindowsPaths $games
}

function Resolve-PalworldFromSteamRoot([string]$SteamRoot){
  $games=@(Get-PalworldInstallationsFromSteamRoot $SteamRoot)
  if($games.Count -gt 0){return $games[0]}
  return $null
}

# Detection order is deliberate: registry/common locations -> C: fallback scan
# -> remaining fixed drives. Return every distinct validated Palworld root so the
# UI can ask the user only when genuinely multiple installations exist.
function Find-PalworldInstallations {
  $results=New-Object System.Collections.Generic.List[string]
  $checkedSteam=@{}

  $seed=@(Get-SteamRootsFromRegistry)
  if($env:ProgramFiles){$seed+=Join-Path $env:ProgramFiles 'Steam'}
  if(${env:ProgramFiles(x86)}){$seed+=Join-Path ${env:ProgramFiles(x86)} 'Steam'}
  foreach($steam in (Get-UniqueWindowsPaths $seed)){
    $key=$steam.ToLowerInvariant()
    if(-not $checkedSteam.ContainsKey($key)){
      $checkedSteam[$key]=$true
      foreach($g in (Get-PalworldInstallationsFromSteamRoot $steam)){$results.Add($g)}
    }
  }
  $unique=@(Get-UniqueWindowsPaths $results)
  if($unique.Count -gt 0){return $unique}

  $drives=@(Get-FixedDriveRoots)
  foreach($drive in @($drives|Where-Object{$_ -match '^C:\\'})){
    Write-PMMLog "Searching Steam folders on $drive"
    foreach($steam in (Find-SteamRootsOnDrive $drive)){
      $key=$steam.ToLowerInvariant()
      if(-not $checkedSteam.ContainsKey($key)){$checkedSteam[$key]=$true;foreach($g in (Get-PalworldInstallationsFromSteamRoot $steam)){$results.Add($g)}}
    }
  }
  $unique=@(Get-UniqueWindowsPaths $results)
  if($unique.Count -gt 0){return $unique}

  foreach($drive in @($drives|Where-Object{$_ -notmatch '^C:\\'})){
    Write-PMMLog "Searching Steam folders on $drive"
    foreach($steam in (Find-SteamRootsOnDrive $drive)){
      $key=$steam.ToLowerInvariant()
      if(-not $checkedSteam.ContainsKey($key)){$checkedSteam[$key]=$true;foreach($g in (Get-PalworldInstallationsFromSteamRoot $steam)){$results.Add($g)}}
    }
  }
  return Get-UniqueWindowsPaths $results
}

function Find-PalworldInstallation {
  $all=@(Find-PalworldInstallations)
  if($all.Count -gt 0){return $all[0]}
  return $null
}

function Set-PMMGameFromSteamRoot([string]$SteamRoot){
  $game=Resolve-PalworldFromSteamRoot $SteamRoot
  if(-not $game){
    throw (Get-PMMText "Palworld was not found in that Steam installation/library. Expected <Steam library>\steamapps\common\Palworld." "No se encontro Palworld en esa instalacion/biblioteca de Steam. Se esperaba <biblioteca Steam>\steamapps\common\Palworld.")
  }
  $cfg=Get-PMMConfig
  if(-not($cfg.PSObject.Properties.Name -contains 'SteamRoot')){$cfg|Add-Member -NotePropertyName SteamRoot -NotePropertyValue ''}
  $cfg.SteamRoot=Normalize-PMMWindowsPath $SteamRoot
  $cfg.GamePath=$game
  $cfg.SaveRoot=Find-PalworldSaveRoot
  Save-PMMConfig $cfg
  Ensure-GameModsFolder
  Write-PMMLog "Steam root set: $($cfg.SteamRoot); game path resolved: $game"
  return $game
}

# Everything below this point deals with the selected installation, not Steam
# discovery. Manual/non-Steam installations use the exact same validated root.
function Get-GameModsPath {
  $cfg=Get-PMMConfig
  if(-not $cfg.GamePath){return $null}
  Join-Path $cfg.GamePath 'Pal\Content\Paks\~mods'
}

function Ensure-GameModsFolder {
  $p=Get-GameModsPath
  if($p -and -not(Test-Path -LiteralPath $p)){
    New-Item -ItemType Directory -Force -Path $p|Out-Null
    Write-PMMLog "Created ~mods: $p"
  }
}

function Start-Palworld {
  $cfg=Get-PMMConfig
  if(-not $cfg.GamePath){throw (Get-PMMText 'Configure the Palworld location first.' 'Configura primero la ubicacion de Palworld.')}
  $exe=Join-Path $cfg.GamePath 'Palworld.exe'
  if(-not(Test-Path -LiteralPath $exe -PathType Leaf)){throw (Get-PMMText 'Palworld.exe was not found.' 'No se encontro Palworld.exe.')}
  Start-Process -FilePath $exe -WorkingDirectory $cfg.GamePath
}
