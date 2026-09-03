<# Local-source fallback for trusted AIIO work orders.
   This module never changes a user's Git checkout. It only looks for an exact
   requested file name in common local locations and copies it as case evidence.
   RemoteFetch remains the final fallback when the file is not already local. #>

$localSourceInstalled=$false
try{
  $existing=Get-Variable -Name PMMAIIOLocalSourceInstalled -Scope Script -ErrorAction Stop
  $localSourceInstalled=[bool]$existing.Value
}catch{}
if(-not$localSourceInstalled){
  if(-not(Get-Command Copy-PMMAIIOPrivateGitHubRaw -ErrorAction SilentlyContinue)){throw 'LocalSource requires RemoteFetch.'}
  $Script:PMMAIIOLocalSourceBasePrivateGitHubRaw=${function:Copy-PMMAIIOPrivateGitHubRaw}
  $Script:PMMAIIOLocalSourceInstalled=$true
}

function Get-PMMAIIOLocalSearchRoots {
  $roots=[Collections.Generic.List[string]]::new()
  try{
    $app=[IO.Path]::GetFullPath((Get-PMMPath 'App'))
    $repoRoot=Split-Path -Parent $app
    $container=Split-Path -Parent $repoRoot
    if($container){$roots.Add($container)}
    $roots.Add((Get-PMMPath 'Workspace'))
  }catch{}
  if($HOME){
    $roots.Add((Join-Path $HOME 'Downloads'))
    $roots.Add((Join-Path $HOME 'Desktop'))
    $roots.Add((Join-Path $HOME 'Documents\GitHub'))
    $roots.Add((Join-Path $HOME 'Documents'))
  }
  if($env:USERPROFILE){
    $roots.Add((Join-Path $env:USERPROFILE 'Downloads'))
    $roots.Add((Join-Path $env:USERPROFILE 'Desktop'))
    $roots.Add((Join-Path $env:USERPROFILE 'Documents\GitHub'))
  }
  if($env:OneDrive){
    $roots.Add((Join-Path $env:OneDrive 'Desktop'))
    $roots.Add((Join-Path $env:OneDrive 'Documents'))
  }
  $seen=[Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
  $out=[Collections.Generic.List[string]]::new()
  foreach($root in $roots){
    if([string]::IsNullOrWhiteSpace($root)){continue}
    try{$full=[IO.Path]::GetFullPath($root)}catch{continue}
    if($seen.Add($full) -and (Test-Path -LiteralPath $full -PathType Container)){$out.Add($full)}
  }
  return @($out.ToArray())
}

function Find-PMMAIIOExactLocalFile([string]$FileName){
  if([string]::IsNullOrWhiteSpace($FileName)){return ''}
  $name=[IO.Path]::GetFileName($FileName)
  foreach($root in @(Get-PMMAIIOLocalSearchRoots)){
    $direct=Join-Path $root $name
    if(Test-Path -LiteralPath $direct -PathType Leaf){return [IO.Path]::GetFullPath($direct)}
  }

  # Bounded breadth-first search. Exact-name only; avoids crawling an entire
  # drive and skips directories that are irrelevant or potentially enormous.
  $skip=[Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
  foreach($n in @('.git','node_modules','Windows','Program Files','Program Files (x86)','$Recycle.Bin','System Volume Information')){[void]$skip.Add($n)}
  foreach($root in @(Get-PMMAIIOLocalSearchRoots)){
    $queue=[Collections.Generic.Queue[object]]::new()
    $queue.Enqueue([pscustomobject]@{Path=$root;Depth=0})
    $visited=0
    while($queue.Count-gt0 -and $visited-lt2500){
      $item=$queue.Dequeue();$visited++
      try{
        $hit=Get-ChildItem -LiteralPath ([string]$item.Path) -File -Filter $name -ErrorAction SilentlyContinue|Select-Object -First 1
        if($hit){return [IO.Path]::GetFullPath([string]$hit.FullName)}
        if([int]$item.Depth-ge4){continue}
        foreach($dir in @(Get-ChildItem -LiteralPath ([string]$item.Path) -Directory -ErrorAction SilentlyContinue)){
          if($skip.Contains([string]$dir.Name)){continue}
          $queue.Enqueue([pscustomobject]@{Path=[string]$dir.FullName;Depth=([int]$item.Depth+1)})
        }
      }catch{}
    }
  }
  return ''
}

function Copy-PMMAIIOPrivateGitHubRaw([string]$Id,[Uri]$Uri,[string]$Target,[string]$FileName){
  $local=Find-PMMAIIOExactLocalFile $FileName
  if($local){
    Set-PMMAIIOCaseProgress $Id 0 100 ('Found '+$FileName+' locally. Collecting it...') -Indeterminate
    $parent=Split-Path -Parent $Target;if($parent){New-Item -ItemType Directory -Force -Path $parent|Out-Null}
    Copy-Item -LiteralPath $local -Destination $Target -Force
    Set-PMMAIIOCaseProgress $Id 99 100 ('Collected '+$FileName+' from local disk.')
    return $true
  }
  return (& $Script:PMMAIIOLocalSourceBasePrivateGitHubRaw $Id $Uri $Target $FileName)
}
