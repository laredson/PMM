<#
PMM artifact registry and conservative cleanup classification.

The registry is advisory metadata.  Cleanup only accepts exact paths generated
by this scanner and revalidates that every target is inside a narrowly allowed
PMM root immediately before deletion.
#>

function Get-PMMArtifactRegistryPath {
  return (Join-PMMPath 'AIIOArtifacts' 'artifacts.json')
}

function Get-PMMArtifactPathBytes([string]$Path) {
  if(Test-Path -LiteralPath $Path -PathType Leaf){return [int64](Get-Item -LiteralPath $Path).Length}
  if(-not(Test-Path -LiteralPath $Path -PathType Container)){return [int64]0}
  [int64]$total=0
  foreach($file in @(Get-ChildItem -LiteralPath $Path -Recurse -File -ErrorAction SilentlyContinue)){$total+=[int64]$file.Length}
  return $total
}

function New-PMMArtifactRecord([string]$Kind,[string]$Category,[string]$Path,[bool]$Active,[bool]$Protected,[bool]$Reproducible,[array]$Dependencies=@()) {
  $full=[IO.Path]::GetFullPath($Path)
  $identity=Get-PMMStableTextId ('PMM_ARTIFACT_V1|'+$Kind+'|'+$full.ToLowerInvariant())
  $item=$null;try{$item=Get-Item -LiteralPath $full -ErrorAction Stop}catch{}
  return [pscustomobject]@{
    Schema='PMM_ARTIFACT_V1';ArtifactId=$identity;Kind=$Kind;Category=$Category;CreatedUtc=$(if($item){$item.CreationTimeUtc.ToString('o')}else{''});LastUsedUtc=$(if($item){$item.LastWriteTimeUtc.ToString('o')}else{''});Size=(Get-PMMArtifactPathBytes $full);Active=$Active;ProtectedByDefault=$Protected;Reproducible=$Reproducible;Dependencies=@($Dependencies);Paths=@($full)
  }
}

function Update-PMMArtifactRegistry {
  $records=[Collections.Generic.List[object]]::new()
  $activeSession='';try{$activeSession=[string](Get-PMMConfig).AIIOActiveSession}catch{}
  foreach($dir in @(Get-ChildItem -LiteralPath (Get-PMMPath 'AIIOSessions') -Directory -ErrorAction SilentlyContinue)){
    $session=Get-PMMAIIOSession $dir.Name;$active=($dir.Name -eq $activeSession -or ($session -and -not[bool]$session.Archived));$category=if($active){'CURRENT_PROTECTED'}else{'VALUABLE'}
    $records.Add((New-PMMArtifactRecord 'AIIO_SESSION' $category $dir.FullName $active $active $false))
  }
  $deployment=Get-PMMAIIOCurrentDeploymentSnapshot
  foreach($file in @(Get-ChildItem -LiteralPath (Get-PMMPath 'Builds') -Filter '*.pak' -File -Recurse -ErrorAction SilentlyContinue)){
    $active=$false
    try{$active=(@($deployment.ManagedFiles|Where-Object{[string]$_.Sha256 -eq (Get-Sha256 $file.FullName)}).Count -gt 0)}catch{}
    $records.Add((New-PMMArtifactRecord 'COMPATIBILITY_BUILD' $(if($active){'CURRENT_PROTECTED'}else{'REBUILDABLE'}) $file.FullName $active $active $true))
  }
  foreach($file in @(Get-ChildItem -LiteralPath (Get-PMMPath 'Handoffs') -Filter '*.zip' -File -Recurse -ErrorAction SilentlyContinue)){
    $records.Add((New-PMMArtifactRecord 'HANDOFF_EXPORT' 'DISPOSABLE' $file.FullName $false $false $true))
  }
  $reference=Get-PMMGameReferenceCurrentRoot
  if(Test-Path -LiteralPath $reference -PathType Container){$records.Add((New-PMMArtifactRecord 'GAME_REFERENCE' 'REBUILDABLE' $reference $false $false $true))}
  foreach($file in @(Get-ChildItem -LiteralPath (Get-PMMPath 'KnowledgeContributions') -Filter '*.zip' -File -ErrorAction SilentlyContinue)){$records.Add((New-PMMArtifactRecord 'KNOWLEDGE_CONTRIBUTION' 'VALUABLE' $file.FullName $false $true $false))}
  foreach($file in @(Get-ChildItem -LiteralPath (Get-PMMPath 'Logs') -File -ErrorAction SilentlyContinue|Where-Object{$_.LastWriteTimeUtc -lt [DateTime]::UtcNow.AddDays(-14)})){$records.Add((New-PMMArtifactRecord 'OLD_LOG' 'DISPOSABLE' $file.FullName $false $false $true))}
  $tempRoot=Get-PMMPath 'Temp';$activeTempStage=$false
  foreach($owner in @(Get-ChildItem -LiteralPath $tempRoot -Recurse -File -ErrorAction SilentlyContinue|Where-Object{$_.Name -eq 'owner.json' -or $_.Name -like '*.owner.json'})){
    $stagePath=if($owner.Name -eq 'owner.json'){$owner.DirectoryName}else{$owner.FullName.Substring(0,$owner.FullName.Length-('.owner.json').Length)}
    if(Test-PMMTransientStageActive $stagePath){$activeTempStage=$true;break}
  }
  foreach($item in @(Get-ChildItem -LiteralPath $tempRoot -Force -ErrorAction SilentlyContinue)){
    # Partial archives may be siblings of their active stage. If any owner in
    # Temp is live, defer every Temp deletion until that operation completes.
    if($activeTempStage -or (Test-PMMTransientStageActive $item.FullName)){continue}
    $records.Add((New-PMMArtifactRecord 'TEMP_STAGE' 'DISPOSABLE' $item.FullName $false $false $true))
  }
  $registry=[ordered]@{Schema='PMM_ARTIFACT_REGISTRY_V1';GeneratedUtc=[DateTime]::UtcNow.ToString('o');Artifacts=@($records.ToArray())}
  Write-PMMAIIOJsonAtomic (Get-PMMArtifactRegistryPath) $registry 35
  return $registry
}

function Read-PMMArtifactRegistry {
  $path=Get-PMMArtifactRegistryPath
  if(-not(Test-Path -LiteralPath $path -PathType Leaf)){return $null}
  try{
    $registry=Get-Content -LiteralPath $path -Raw -Encoding UTF8|ConvertFrom-Json -ErrorAction Stop
    if([string]$registry.Schema -eq 'PMM_ARTIFACT_REGISTRY_V1'){return $registry}
  }catch{}
  return $null
}

function Get-PMMArtifactStorageSummary {
  [CmdletBinding()]
  param([switch]$Refresh)
  $registry=if($Refresh){Update-PMMArtifactRegistry}else{Read-PMMArtifactRegistry}
  if(-not$registry){return [pscustomobject]@{TotalBytes=0;Categories=@();ArtifactCount=0;Available=$false;GeneratedUtc=''}}
  $rows=[Collections.Generic.List[object]]::new();[int64]$total=0
  foreach($group in @($registry.Artifacts|Group-Object -Property Category)){
    [int64]$size=0;foreach($item in @($group.Group)){$size+=[int64]$item.Size}
    $total+=$size;$rows.Add([pscustomobject]@{Category=[string]$group.Name;Count=$group.Count;Bytes=$size})
  }
  return [pscustomobject]@{TotalBytes=$total;Categories=@($rows.ToArray()|Sort-Object Category);ArtifactCount=@($registry.Artifacts).Count;Available=$true;GeneratedUtc=[string]$registry.GeneratedUtc}
}

function Remove-PMMDisposableArtifacts {
  [CmdletBinding(SupportsShouldProcess=$true)]
  param([int]$OlderThanDays=0)
  $registry=Update-PMMArtifactRegistry
  $allowedRoots=@((Get-PMMPath 'Temp'),(Get-PMMPath 'Logs'),(Get-PMMPath 'Handoffs'))
  $removed=[Collections.Generic.List[object]]::new();$skipped=[Collections.Generic.List[object]]::new()
  foreach($artifact in @($registry.Artifacts|Where-Object{[string]$_.Category -eq 'DISPOSABLE' -and -not[bool]$_.ProtectedByDefault})){
    foreach($path in @($artifact.Paths|ForEach-Object{[string]$_})){
      $inside=$false;foreach($root in $allowedRoots){if(Test-PMMPathInside $path $root){$inside=$true;break}}
      if(-not$inside){$skipped.Add([pscustomobject]@{Path=$path;Reason='Outside disposable allowlist'});continue}
      if($OlderThanDays -gt 0){try{if((Get-Item -LiteralPath $path).LastWriteTimeUtc -gt [DateTime]::UtcNow.AddDays(-$OlderThanDays)){$skipped.Add([pscustomobject]@{Path=$path;Reason='Too recent'});continue}}catch{}}
      if(-not(Test-Path -LiteralPath $path)){$skipped.Add([pscustomobject]@{Path=$path;Reason='Already absent'});continue}
      if($PSCmdlet.ShouldProcess($path,'Delete disposable PMM artifact')){
        Remove-Item -LiteralPath $path -Recurse -Force -ErrorAction Stop
        $removed.Add([pscustomobject]@{Path=$path;ArtifactId=[string]$artifact.ArtifactId;Bytes=[int64]$artifact.Size})
      }
    }
  }
  return [pscustomobject]@{Removed=@($removed.ToArray());Skipped=@($skipped.ToArray());RemovedBytes=[int64](($removed|Measure-Object -Property Bytes -Sum).Sum)}
}

# Load additive AIIO extensions after the base ModCreation/Response services so
# their runtime overrides are active.
. (Join-Path $Script:Root 'Modules\AIIO\AIIO.GameReferenceHydrationService.ps1')
. (Join-Path $Script:Root 'Modules\AIIO\AIIO.PendingDataService.ps1')
. (Join-Path $Script:Root 'Modules\AIIO\AIIO.SessionRecoveryService.ps1')

# AIIO V3 Case Workspace preview. This remains additive: v2 sessions and
# response routing stay underneath it for migration/backward compatibility.
. (Join-Path $Script:Root 'Modules\AIIO\AIIO.CaseWorkspaceService.ps1')
. (Join-Path $Script:Root 'Modules\AIIO\AIIO.CaseWorkspace.UI.ps1')
. (Join-Path $Script:Root 'Modules\AIIO\AIIO.CaseWorkspace.UI.Preview2.ps1')
. (Join-Path $Script:Root 'Modules\AIIO\AIIO.CaseWorkspace.UI.Preview3.ps1')
. (Join-Path $Script:Root 'Modules\AIIO\AIIO.CaseWorkspace.UI.Preview4.ps1')
. (Join-Path $Script:Root 'Modules\AIIO\AIIO.CaseWorkspace.Preview5.ps1')
