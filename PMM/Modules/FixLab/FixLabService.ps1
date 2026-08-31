<#
FixLabService.ps1 - isolated repair workspace for legacy/broken Palworld mods
============================================================================

Fix Lab is intentionally separate from the normal Mods & Merge pipeline.
A broken/legacy mod is snapshotted into Workspace\FixLab\Jobs and analyzed
without enabling or deploying it.  A successful repaired output can later be
imported into the normal PMM library and then behaves like any other source mod.

This v1.3.0 integration establishes the durable job/recipe/output
contract and the UI workflow.  Recipe execution is pluggable.  Case 001
(Gawr Gura v5 -> Palworld 1.0.3) is registered as runtime-proven research,
but its binary reconstruction executor still needs to be ported from the
validated research implementation into PMM's standalone runtime path.
#>

$Script:PMMFixLabRecipeCache = $null
$Script:PMMFixLabRecipeCacheStamp = ''

function script:Initialize-PMMFixLab {
  foreach($key in @('FixLab','FixLabJobs','FixLabCache','FixLabHandoffs')){
    $p=Get-PMMPath $key
    if(-not(Test-Path -LiteralPath $p -PathType Container)){New-Item -ItemType Directory -Force -Path $p|Out-Null}
  }
}

function script:Get-PMMFixLabRecipePath { return (Join-Path (Get-PMMPath 'CKLFixLabStable') 'fix-recipes.json') }
function script:Get-PMMFixLabCurrentStatePath { return (Join-PMMPath 'State' 'fixlab-current.json') }

function script:Get-PMMFixLabRecipeDocument {
  $path=Get-PMMFixLabRecipePath
  if(-not(Test-Path -LiteralPath $path -PathType Leaf)){return $null}
  try{
    $stamp=(Get-Item -LiteralPath $path).LastWriteTimeUtc.ToString('o')
    if($Script:PMMFixLabRecipeCache -and $Script:PMMFixLabRecipeCacheStamp -eq $stamp){return $Script:PMMFixLabRecipeCache}
    $doc=Get-Content -LiteralPath $path -Raw|ConvertFrom-Json
    if(-not$doc -or [string]$doc.schema -ne 'PMM_FIXLAB_RECIPES_V1'){throw 'Unsupported Fix Lab recipe schema.'}
    $Script:PMMFixLabRecipeCache=$doc
    $Script:PMMFixLabRecipeCacheStamp=$stamp
    return $doc
  }catch{
    Write-PMMLog ('Fix Lab recipe library could not be read: '+$_.Exception.Message)
    return $null
  }
}

function script:Get-PMMFixLabRecipes {
  $doc=Get-PMMFixLabRecipeDocument
  if(-not$doc){return @()}
  return @($doc.recipes)
}

function script:Get-PMMFixLabRecipe([string]$RecipeId) {
  if([string]::IsNullOrWhiteSpace($RecipeId)){return $null}
  return @(Get-PMMFixLabRecipes|Where-Object{[string]$_.id -ieq $RecipeId}|Select-Object -First 1)[0]
}

function script:Get-PMMFixLabJobPath([string]$JobId) {
  if([string]::IsNullOrWhiteSpace($JobId)){return ''}
  if($JobId -notmatch '^FL_[A-Za-z0-9_-]{6,100}$'){throw 'Unsafe Fix Lab job id.'}
  return (Join-Path (Get-PMMPath 'FixLabJobs') $JobId)
}

function script:Get-PMMFixLabJobStatePath([string]$JobId) {
  $root=Get-PMMFixLabJobPath $JobId
  if([string]::IsNullOrWhiteSpace($root)){return ''}
  return (Join-Path $root 'job.json')
}

function script:Write-PMMFixLabJson([string]$Path,$Value) {
  $dir=Split-Path -Parent $Path
  if($dir -and -not(Test-Path -LiteralPath $dir -PathType Container)){New-Item -ItemType Directory -Force -Path $dir|Out-Null}
  $tmp=$Path+'.tmp'
  $Value|ConvertTo-Json -Depth 40|Set-Content -LiteralPath $tmp -Encoding UTF8
  Move-Item -LiteralPath $tmp -Destination $Path -Force
}

function script:Save-PMMFixLabJob($Job) {
  if(-not$Job){throw 'Fix Lab job is required.'}
  if(-not($Job.PSObject.Properties.Name -contains 'JobId')){throw 'Invalid Fix Lab job object.'}
  if(-not($Job.PSObject.Properties.Name -contains 'UpdatedUtc')){$Job|Add-Member -NotePropertyName UpdatedUtc -NotePropertyValue ''}
  $Job.UpdatedUtc=[DateTime]::UtcNow.ToString('o')
  Write-PMMFixLabJson (Get-PMMFixLabJobStatePath ([string]$Job.JobId)) $Job
  return $Job
}

function script:Get-PMMFixLabJob([string]$JobId) {
  $path=Get-PMMFixLabJobStatePath $JobId
  if(-not$path -or -not(Test-Path -LiteralPath $path -PathType Leaf)){return $null}
  try{return (Get-Content -LiteralPath $path -Raw|ConvertFrom-Json)}catch{return $null}
}

function script:Get-PMMFixLabJobs {
  Initialize-PMMFixLab
  $items=[System.Collections.Generic.List[object]]::new()
  foreach($dir in @(Get-ChildItem -LiteralPath (Get-PMMPath 'FixLabJobs') -Directory -ErrorAction SilentlyContinue|Sort-Object LastWriteTimeUtc -Descending)){
    $path=Join-Path $dir.FullName 'job.json'
    if(-not(Test-Path -LiteralPath $path -PathType Leaf)){continue}
    try{
      $job=Get-Content -LiteralPath $path -Raw|ConvertFrom-Json
      $primary=if($job.Primary){[string]$job.Primary.Name}else{''}
      $status=if($job.Analysis){[string]$job.Analysis.Status}else{'New'}
      $items.Add([pscustomobject]@{JobId=[string]$job.JobId;Primary=$primary;Status=$status;UpdatedUtc=[string]$job.UpdatedUtc;Display=([string]$job.JobId+' | '+$primary+' | '+$status)})
    }catch{}
  }
  return $items.ToArray()
}

function script:Set-PMMFixLabCurrentJobId([string]$JobId) {
  if(-not[string]::IsNullOrWhiteSpace($JobId)){[void](Get-PMMFixLabJobPath $JobId)}
  Write-PMMFixLabJson (Get-PMMFixLabCurrentStatePath) ([ordered]@{Schema='PMM_FIXLAB_CURRENT_V1';JobId=$JobId;UpdatedUtc=[DateTime]::UtcNow.ToString('o')})
}

function script:Get-PMMFixLabCurrentJobId {
  $path=Get-PMMFixLabCurrentStatePath
  if(-not(Test-Path -LiteralPath $path -PathType Leaf)){return ''}
  try{return [string](Get-Content -LiteralPath $path -Raw|ConvertFrom-Json).JobId}catch{return ''}
}

function script:Get-PMMFixLabCurrentJob {
  $id=Get-PMMFixLabCurrentJobId
  if([string]::IsNullOrWhiteSpace($id)){return $null}
  return (Get-PMMFixLabJob $id)
}

function script:Get-PMMFixLabLibrarySources {
  $all=[System.Collections.Generic.List[object]]::new()
  foreach($m in @(Get-LibraryMods)){[void]$all.Add($m)}
  foreach($m in @(Get-PMMDisabledMods)){[void]$all.Add($m)}
  return @($all.ToArray()|Sort-Object Name)
}

function script:Test-PMMFixLabSupportedInputExtension([string]$Path) {
  $ext=[IO.Path]::GetExtension($Path).ToLowerInvariant()
  return ($ext -in @('.pak','.zip','.7z','.rar'))
}

function script:Assert-PMMFixLabSnapshotSpace([string]$SourcePath,[string]$DestinationRoot) {
  $item=Get-Item -LiteralPath $SourcePath -ErrorAction Stop
  [int64]$required=[int64]$item.Length+256MB
  [int64]$free=-1
  try{
    $driveRoot=[IO.Path]::GetPathRoot([IO.Path]::GetFullPath($DestinationRoot))
    if($driveRoot){$free=[int64]([IO.DriveInfo]::new($driveRoot).AvailableFreeSpace)}
  }catch{}
  if($free -ge 0 -and $free -lt $required){
    throw ((Get-PMMText 'Fix Lab needs about {0:N1} GB free to snapshot this source safely; only {1:N1} GB are available.' 'Fix Lab necesita unos {0:N1} GB libres para guardar esta fuente con seguridad; solo hay {1:N1} GB disponibles.') -f ($required/1GB),($free/1GB))
  }
}

function script:New-PMMFixLabSourceRecord([string]$Path,[string]$Role,[string]$DestinationRoot) {
  if(-not(Test-Path -LiteralPath $Path -PathType Leaf)){throw "Fix Lab source file was not found:`n$Path"}
  if(-not(Test-PMMFixLabSupportedInputExtension $Path)){throw (Get-PMMText 'Fix Lab accepts .pak, .zip, .7z and .rar inputs.' 'Fix Lab acepta entradas .pak, .zip, .7z y .rar.')}
  $item=Get-Item -LiteralPath $Path
  $hash=Get-Sha256 $item.FullName
  $safeName=($item.Name -replace '[^A-Za-z0-9_.() -]','_')
  $roleRoot=Join-Path $DestinationRoot $Role
  if(-not(Test-Path -LiteralPath $roleRoot -PathType Container)){New-Item -ItemType Directory -Force -Path $roleRoot|Out-Null}
  $snap=Join-Path $roleRoot $safeName
  if(-not(Test-Path -LiteralPath $snap -PathType Leaf) -or (Get-Sha256 $snap) -ne $hash){Assert-PMMFixLabSnapshotSpace $item.FullName $roleRoot;Copy-Item -LiteralPath $item.FullName -Destination $snap -Force}
  return [pscustomobject]@{
    Name=$item.Name;OriginalPath=$item.FullName;SnapshotPath=$snap;SnapshotRelative=$snap.Substring($Script:Root.Length).TrimStart([char]92,[char]47);Extension=$item.Extension.ToLowerInvariant();
    Sha256=$hash;Size=[int64]$item.Length;Role=$Role
  }
}

function script:New-PMMFixLabJob([string]$PrimaryPath) {
  Initialize-PMMFixLab
  if(-not(Test-Path -LiteralPath $PrimaryPath -PathType Leaf)){throw (Get-PMMText 'Choose a source mod/archive first.' 'Elige primero un mod/archivo fuente.')}
  $hash=Get-Sha256 $PrimaryPath
  $stamp=Get-Date -Format 'yyyyMMdd_HHmmss'
  $jobId=('FL_'+$stamp+'_'+$hash.Substring(0,8))
  $root=Get-PMMFixLabJobPath $jobId
  foreach($name in @('Input','Related','Work','Output','Reports')){New-Item -ItemType Directory -Force -Path (Join-Path $root $name)|Out-Null}
  $primary=New-PMMFixLabSourceRecord $PrimaryPath 'Primary' (Join-Path $root 'Input')
  $job=[pscustomobject]@{
    Schema='PMM_FIXLAB_JOB_V1';JobId=$jobId;CreatedUtc=[DateTime]::UtcNow.ToString('o');UpdatedUtc=[DateTime]::UtcNow.ToString('o');
    Primary=$primary;Related=@();
    GameReference=$null;
    Analysis=[pscustomobject]@{Status='NotAnalyzed';Summary='';RecipeMatches=@();PakInventory=@();Signals=@()};
    SelectedRecipeId='';SelectedVariantId='';
    Build=[pscustomobject]@{Status='NotBuilt';OutputPath='';OutputSha256='';RecipeId='';VariantId='';Validation='';BuiltUtc=''}
  }
  Save-PMMFixLabJob $job|Out-Null
  Set-PMMFixLabCurrentJobId $jobId
  Write-PMMLog ('Fix Lab job created: '+$jobId+' | '+$primary.Name)
  return (Get-PMMFixLabJob $jobId)
}

function script:Add-PMMFixLabRelatedSource([string]$JobId,[string]$Path) {
  $job=Get-PMMFixLabJob $JobId
  if(-not$job){throw 'Fix Lab job not found.'}
  $root=Get-PMMFixLabJobPath $JobId
  $record=New-PMMFixLabSourceRecord $Path 'Related' $root
  $items=[System.Collections.Generic.List[object]]::new()
  foreach($x in @($job.Related)){if([string]$x.Sha256 -ne [string]$record.Sha256){[void]$items.Add($x)}}
  [void]$items.Add($record)
  $job.Related=$items.ToArray()
  $job.Analysis.Status='NotAnalyzed';$job.Analysis.Summary='';$job.Analysis.RecipeMatches=@();$job.Analysis.PakInventory=@();$job.Analysis.Signals=@()
  Save-PMMFixLabJob $job|Out-Null
  return (Get-PMMFixLabJob $JobId)
}

function script:Remove-PMMFixLabRelatedSource([string]$JobId,[string]$Sha256) {
  $job=Get-PMMFixLabJob $JobId
  if(-not$job){throw 'Fix Lab job not found.'}
  $job.Related=@($job.Related|Where-Object{[string]$_.Sha256 -ne $Sha256})
  $job.Analysis.Status='NotAnalyzed';$job.Analysis.Summary='';$job.Analysis.RecipeMatches=@();$job.Analysis.PakInventory=@();$job.Analysis.Signals=@()
  Save-PMMFixLabJob $job|Out-Null
  return (Get-PMMFixLabJob $JobId)
}

function script:Get-PMMFixLabSourceSnapshotPath($Source) {
  if(-not$Source){return ''}
  if(($Source.PSObject.Properties.Name -contains 'SnapshotRelative') -and -not[string]::IsNullOrWhiteSpace([string]$Source.SnapshotRelative)){return (Join-Path $Script:Root ([string]$Source.SnapshotRelative))}
  return [string]$Source.SnapshotPath
}

function script:Expand-PMMFixLabSourceToPaks($Source,[string]$JobRoot) {
  if(-not$Source){return @()}
  $path=Get-PMMFixLabSourceSnapshotPath $Source
  if(-not(Test-Path -LiteralPath $path -PathType Leaf)){throw ('Fix Lab snapshot is missing: '+$path)}
  $ext=[IO.Path]::GetExtension($path).ToLowerInvariant()
  if($ext -eq '.pak'){return @((Get-Item -LiteralPath $path))}
  $stage=Join-Path (Join-Path $JobRoot 'Work\Expanded') ([string]$Source.Sha256).Substring(0,16)
  if(Test-Path -LiteralPath $stage -PathType Container){Remove-Item -LiteralPath $stage -Recurse -Force}
  New-Item -ItemType Directory -Force -Path $stage|Out-Null
  if($ext -eq '.zip'){
    $runtime=Get-PMMRuntimePath
    if(-not(Test-Path -LiteralPath $runtime -PathType Leaf)){throw 'PMMRuntime.exe is required to extract Fix Lab ZIP inputs.'}
    $output=@(& $runtime archive extract $path $stage 2>&1|ForEach-Object{[string]$_})
    if($LASTEXITCODE -ne 0){throw ('PMMRuntime archive extract failed. '+($output -join ' '))}
  }elseif($ext -in @('.7z','.rar')){
    $seven=Get-Command 7z.exe -ErrorAction SilentlyContinue
    if(-not$seven){throw (Get-PMMText '7-Zip is required to inspect .7z/.rar Fix Lab inputs. You can also provide the contained .pak directly.' 'Se necesita 7-Zip para inspeccionar entradas .7z/.rar de Fix Lab. Tambien puedes proporcionar directamente el .pak contenido.')}
    & $seven.Source x '-y' ('-o'+$stage) $path|Out-Null
    if($LASTEXITCODE -ne 0){throw '7-Zip could not extract the Fix Lab source archive.'}
  }else{throw 'Unsupported Fix Lab source extension.'}
  return @(Get-ChildItem -LiteralPath $stage -Filter *.pak -File -Recurse -ErrorAction SilentlyContinue)
}

function script:Get-PMMFixLabPakInventory([IO.FileInfo]$Pak,[string]$ReportRoot) {
  $entries=@(Get-PakEntriesCached $Pak.FullName)
  $normalized=@($entries|ForEach-Object{Normalize-PakLogicalPath ([string]$_)}|Where-Object{$_})
  $uassets=@($normalized|Where-Object{[IO.Path]::GetExtension($_) -ieq '.uasset'})
  $stems=[System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
  foreach($u in $uassets){[void]$stems.Add((Get-PakLogicalStem $u))}
  $signals=[ordered]@{
    Blueprint=@($normalized|Where-Object{$_ -match '/Blueprint/'}).Count
    ImpHair=@($normalized|Where-Object{$_ -match '/Imp_Hair/'}).Count
    HairAttachAccessory=@($normalized|Where-Object{$_ -match '/HairAttachAccessory/'}).Count
    Outfit=@($normalized|Where-Object{$_ -match '/Model/Character/Player/Outfit/'}).Count
    Head=@($normalized|Where-Object{$_ -match '/Model/Character/Player/Head/'}).Count
    Hair=@($normalized|Where-Object{$_ -match '/Model/Character/Player/Hair/'}).Count
    Weapon=@($normalized|Where-Object{$_ -match '/Model/Weapon/'}).Count
    CustomStarfelll=@($normalized|Where-Object{$_ -match '/Starfelll/'}).Count
    KawaiiPhysics=@($normalized|Where-Object{$_ -match '(?i)Kawaii'}).Count
  }
  $hash=Get-Sha256 $Pak.FullName
  $safe=($Pak.BaseName -replace '[^A-Za-z0-9_.-]','_')
  $indexPath=Join-Path $ReportRoot ('pak-index_'+$safe+'_'+$hash.Substring(0,8)+'.txt')
  [IO.File]::WriteAllLines($indexPath,$normalized,[Text.UTF8Encoding]::new($false))
  return [pscustomobject]@{
    Name=$Pak.Name;Path=$Pak.FullName;Sha256=$hash;Size=[int64]$Pak.Length;EntryCount=$normalized.Count;UassetCount=$uassets.Count;FamilyCount=$stems.Count;Signals=[pscustomobject]$signals;IndexReport=$indexPath
  }
}

function script:Test-PMMFixLabRecipeSignature($Recipe,$Job,[array]$PakInventory) {
  $hits=[System.Collections.Generic.List[object]]::new()
  $exact=$false
  $allSources=@($Job.Primary)+@($Job.Related)
  foreach($sig in @($Recipe.match.signatures)){
    $kind=[string]$sig.kind;$expected=([string]$sig.sha256).ToLowerInvariant();$label=[string]$sig.label
    if([string]::IsNullOrWhiteSpace($expected)){continue}
    if($kind -eq 'source-sha256'){
      foreach($src in $allSources){if(([string]$src.Sha256).ToLowerInvariant() -eq $expected){$exact=$true;$hits.Add([pscustomobject]@{Kind=$kind;Label=$label;Matched=[string]$src.Name;Sha256=$expected})}}
    }elseif($kind -eq 'pak-sha256'){
      foreach($pak in $PakInventory){if(([string]$pak.Sha256).ToLowerInvariant() -eq $expected){$exact=$true;$hits.Add([pscustomobject]@{Kind=$kind;Label=$label;Matched=[string]$pak.Name;Sha256=$expected})}}
    }
  }
  $hint=$false
  foreach($pattern in @($Recipe.match.filenameHints)){
    if([string]::IsNullOrWhiteSpace([string]$pattern)){continue}
    foreach($src in $allSources){if(([string]$src.Name).IndexOf([string]$pattern,[StringComparison]::OrdinalIgnoreCase) -ge 0){$hint=$true}}
    foreach($pak in $PakInventory){if(([string]$pak.Name).IndexOf([string]$pattern,[StringComparison]::OrdinalIgnoreCase) -ge 0){$hint=$true}}
  }
  return [pscustomobject]@{Exact=[bool]$exact;Hint=[bool]$hint;Hits=$hits.ToArray()}
}

function script:Test-PMMFixLabBuildProviderPresent($Recipe,$Job,[array]$PakInventory) {
  if(-not$Recipe -or -not($Recipe.PSObject.Properties.Name -contains 'sourcePolicy') -or -not$Recipe.sourcePolicy -or -not$Recipe.sourcePolicy.buildProvider){return $true}
  $policy=$Recipe.sourcePolicy.buildProvider
  if(-not[bool]$policy.required){return $true}
  $allSources=@($Job.Primary)+@($Job.Related)
  foreach($sig in @($policy.acceptedSignatures)){
    $kind=[string]$sig.kind;$expected=([string]$sig.sha256).ToLowerInvariant()
    if([string]::IsNullOrWhiteSpace($expected)){continue}
    if($kind -eq 'source-sha256'){
      foreach($src in $allSources){if(([string]$src.Sha256).ToLowerInvariant() -eq $expected){return $true}}
    }elseif($kind -eq 'pak-sha256'){
      foreach($pak in @($PakInventory)){if(([string]$pak.Sha256).ToLowerInvariant() -eq $expected){return $true}}
    }
  }
  return $false
}

function script:Find-PMMFixLabRecipeMatches($Job,[array]$PakInventory) {
  $rows=[System.Collections.Generic.List[object]]::new()
  foreach($recipe in @(Get-PMMFixLabRecipes)){
    $m=Test-PMMFixLabRecipeSignature $recipe $Job $PakInventory
    if(-not$m.Exact -and -not$m.Hint){continue}
    $providerPresent=Test-PMMFixLabBuildProviderPresent $recipe $Job $PakInventory
    $rows.Add([pscustomobject]@{
      RecipeId=[string]$recipe.id;Name=[string]$recipe.name;Exact=[bool]$m.Exact;Hint=[bool]$m.Hint;BuildProviderPresent=[bool]$providerPresent;Confidence=$(if($m.Exact){'Exact'}else{'Candidate'});Hits=@($m.Hits);
      RuntimeStatus=$(if(($recipe.PSObject.Properties.Name -contains 'status') -and $recipe.status -and ($recipe.status.PSObject.Properties.Name -contains 'runtime')){[string]$recipe.status.runtime}else{'documented'});ImplementationStatus=$(if(($recipe.PSObject.Properties.Name -contains 'implementation') -and $recipe.implementation -and ($recipe.implementation.PSObject.Properties.Name -contains 'status')){[string]$recipe.implementation.status}else{'unknown'})
    })
  }
  return @($rows.ToArray()|Sort-Object @{Expression={if($_.Exact){0}else{1}}},@{Expression={if($_.BuildProviderPresent){0}else{1}}},Name)
}

function script:Invoke-PMMFixLabAnalyze([string]$JobId) {
  Initialize-PMMFixLab
  $job=Get-PMMFixLabJob $JobId
  if(-not$job){throw 'Fix Lab job not found.'}
  $root=Get-PMMFixLabJobPath $JobId
  $reportRoot=Join-Path $root 'Reports'
  New-Item -ItemType Directory -Force -Path $reportRoot|Out-Null
  $paks=[System.Collections.Generic.List[object]]::new()
  foreach($source in @($job.Primary)+@($job.Related)){
    foreach($pak in @(Expand-PMMFixLabSourceToPaks $source $root)){[void]$paks.Add($pak)}
  }
  if($paks.Count -eq 0){throw (Get-PMMText 'No .pak file was found in the selected Fix Lab inputs.' 'No se encontro ningun .pak en las entradas seleccionadas de Fix Lab.')}
  $inventory=[System.Collections.Generic.List[object]]::new()
  foreach($pak in @($paks.ToArray())){[void]$inventory.Add((Get-PMMFixLabPakInventory $pak $reportRoot))}
  $inv=@($inventory.ToArray())
  $matches=@(Find-PMMFixLabRecipeMatches $job $inv)
  $gr=Get-PMMGameReferenceState
  $job.GameReference=$gr
  $signals=[ordered]@{}
  foreach($key in @('Blueprint','ImpHair','HairAttachAccessory','Outfit','Head','Hair','Weapon','CustomStarfelll','KawaiiPhysics')){
    $total=0;foreach($p in $inv){try{$total+=[int]$p.Signals.$key}catch{}}
    $signals[$key]=$total
  }
  $exact=@($matches|Where-Object{$_.Exact})
  $status=if($exact.Count -gt 0){'RecipeMatched'}elseif($matches.Count -gt 0){'CandidateOnly'}else{'NeedsResearch'}
    $familyTotal=0;foreach($p in $inv){$familyTotal+=[int]$p.FamilyCount}
  $summary=(Get-PMMText ('{0} PAK(s), {1} cooked families. Recipe matches: {2} exact / {3} candidate. Game Reference: {4}.') ('{0} PAK, {1} familias cooked. Coincidencias de receta: {2} exacta(s) / {3} candidata(s). Game Reference: {4}.')) -f $inv.Count,$familyTotal,$exact.Count,(@($matches|Where-Object{-not$_.Exact}).Count),[string]$gr.Status
  $job.Analysis=[pscustomobject]@{Status=$status;Summary=$summary;RecipeMatches=$matches;PakInventory=$inv;Signals=[pscustomobject]$signals;AnalyzedUtc=[DateTime]::UtcNow.ToString('o')}
  if($exact.Count -eq 1){
    $job.SelectedRecipeId=[string]$exact[0].RecipeId
    $recipe=Get-PMMFixLabRecipe $job.SelectedRecipeId
    if($recipe -and @($recipe.variants).Count -gt 0){$job.SelectedVariantId=[string]$recipe.variants[0].id}
  }
  Save-PMMFixLabJob $job|Out-Null
  Write-PMMFixLabJson (Join-Path $reportRoot 'analysis.json') $job.Analysis
  Write-PMMLog ('Fix Lab Analyze: '+$JobId+' | '+$status+' | '+$summary)
  return (Get-PMMFixLabJob $JobId)
}

function script:Get-PMMFixLabVariantItems($Job) {
  if(-not$Job -or [string]::IsNullOrWhiteSpace([string]$Job.SelectedRecipeId)){return @()}
  $recipe=Get-PMMFixLabRecipe ([string]$Job.SelectedRecipeId)
  if(-not$recipe){return @()}
  $items=[System.Collections.Generic.List[object]]::new()
  foreach($v in @($recipe.variants)){
    $items.Add([pscustomobject]@{Id=[string]$v.id;Label=[string]$v.label;Description=[string]$v.description;RuntimeStatus=[string]$v.runtimeStatus;BuildStatus=[string]$v.buildStatus;Display=([string]$v.label+' | '+[string]$v.runtimeStatus)})
  }
  return $items.ToArray()
}

function script:Set-PMMFixLabSelection([string]$JobId,[string]$RecipeId,[string]$VariantId) {
  $job=Get-PMMFixLabJob $JobId
  if(-not$job){throw 'Fix Lab job not found.'}
  $recipe=Get-PMMFixLabRecipe $RecipeId
  if(-not$recipe){throw 'Fix Lab recipe not found.'}
  $variant=@($recipe.variants|Where-Object{[string]$_.id -ieq $VariantId}|Select-Object -First 1)[0]
  if(-not$variant){throw 'Fix Lab output variant not found.'}
  $job.SelectedRecipeId=[string]$recipe.id;$job.SelectedVariantId=[string]$variant.id
  Save-PMMFixLabJob $job|Out-Null
  return (Get-PMMFixLabJob $JobId)
}

function script:Get-PMMFixLabBuildState($Job) {
  if(-not$Job){return [pscustomobject]@{Ready=$false;Reason=(Get-PMMText 'Create or open a Fix Lab job.' 'Crea o abre un trabajo de Fix Lab.')}}
  if(-not$Job.Analysis -or [string]$Job.Analysis.Status -eq 'NotAnalyzed'){return [pscustomobject]@{Ready=$false;Reason=(Get-PMMText 'Run Repair Analysis first.' 'Ejecuta primero Analisis de reparacion.')}}
  if([string]::IsNullOrWhiteSpace([string]$Job.SelectedRecipeId)){return [pscustomobject]@{Ready=$false;Reason=(Get-PMMText 'No exact repair recipe is selected.' 'No hay una receta de reparacion exacta seleccionada.')}}
  $recipe=Get-PMMFixLabRecipe ([string]$Job.SelectedRecipeId)
  if(-not$recipe){return [pscustomobject]@{Ready=$false;Reason='Recipe metadata is unavailable.'}}
  $selectedMatch=@($Job.Analysis.RecipeMatches|Where-Object{[string]$_.RecipeId -ieq [string]$Job.SelectedRecipeId}|Select-Object -First 1)[0]
  $exactSelected=($selectedMatch -and [bool]$selectedMatch.Exact)
  if(-not$exactSelected){return [pscustomobject]@{Ready=$false;Reason=(Get-PMMText 'This recipe is only a filename/structure candidate. Exact source identity is required before automatic Build.' 'Esta receta solo es una candidata por nombre/estructura. Se requiere identidad exacta de la fuente antes de Build automatico.')}}
  if(($selectedMatch.PSObject.Properties.Name -contains 'BuildProviderPresent') -and -not[bool]$selectedMatch.BuildProviderPresent){
    return [pscustomobject]@{Ready=$false;Reason=(Get-PMMText 'The repair case is recognized, but the required build provider is missing. For Gura Case 001 the proven provider is FullReplacement; Normal-only reconstruction is not yet proven.' 'El caso de reparacion esta reconocido, pero falta el proveedor necesario para construirlo. Para Gura Case 001 el proveedor demostrado es FullReplacement; la reconstruccion usando solo Normal aun no esta demostrada.')}
  }
  $gr=Get-PMMGameReferenceState
  if($recipe.referencePolicy -and [bool]$recipe.referencePolicy.currentRequired -and [string]$gr.Status -ne 'Current'){
    return [pscustomobject]@{Ready=$false;Reason=(Get-PMMText 'This recipe requires a Current Game Reference.' 'Esta receta requiere una Game Reference actual.')}
  }
  if(-not$recipe.implementation -or [string]$recipe.implementation.status -ne 'ready'){
    return [pscustomobject]@{Ready=$false;Reason=(Get-PMMText 'Recipe recognized and documented, but its standalone executor has not been ported into this PMM build yet. Create a repair handoff or continue the engine port.' 'La receta esta reconocida y documentada, pero su ejecutor standalone aun no se ha portado a esta build de PMM. Crea un handoff de reparacion o continua el port del motor.')}
  }
  if([string]::IsNullOrWhiteSpace([string]$Job.SelectedVariantId)){return [pscustomobject]@{Ready=$false;Reason=(Get-PMMText 'Choose an output variant.' 'Elige una variante de salida.')}}
  return [pscustomobject]@{Ready=$true;Reason=(Get-PMMText 'Ready to build the selected repaired output.' 'Listo para construir la salida reparada seleccionada.')}
}

function script:Invoke-PMMFixLabBuild([string]$JobId) {
  Publish-PMMFixLabProgress 2 100 (Get-PMMText 'Opening the Fix Lab job...' 'Abriendo el trabajo de Fix Lab...')
  $job=Get-PMMFixLabJob $JobId
  if(-not$job){throw 'Fix Lab job not found.'}
  $state=Get-PMMFixLabBuildState $job
  if(-not$state.Ready){throw [string]$state.Reason}
  $recipe=Get-PMMFixLabRecipe ([string]$job.SelectedRecipeId)
  $impl=$recipe.implementation
  if([string]$impl.mode -ne 'powershell-script'){throw 'Unsupported Fix Lab executor mode.'}
  $script=Join-Path $Script:Root ([string]$impl.script).Replace('/',[IO.Path]::DirectorySeparatorChar)
  if(-not(Test-Path -LiteralPath $script -PathType Leaf)){throw ('Fix Lab executor script is missing: '+$script)}
  . $script
  $fn=[string]$impl.function
  $command=Get-Command $fn -ErrorAction SilentlyContinue
  if(-not$command){throw ('Fix Lab executor function is missing: '+$fn)}
  $job.Build.Status='Building';$job.Build.RecipeId=[string]$recipe.id;$job.Build.VariantId=[string]$job.SelectedVariantId
  Save-PMMFixLabJob $job|Out-Null
  try{
    $result=& $fn -Job (Get-PMMFixLabJob $JobId) -Recipe $recipe -VariantId ([string]$job.SelectedVariantId)
    if(-not$result -or [string]::IsNullOrWhiteSpace([string]$result.OutputPath)){throw 'Fix Lab recipe returned no output PAK.'}
    $out=[string]$result.OutputPath
    if(-not(Test-Path -LiteralPath $out -PathType Leaf)){throw ('Fix Lab output was not created: '+$out)}
    Publish-PMMFixLabProgress 90 100 (Get-PMMText 'Running independent PAK readback and family validation...' 'Ejecutando readback independiente y validacion de familias...')
    if(-not(Test-Pak $out)){throw 'Fix Lab output PAK failed the repak verification check.'}
    Assert-PakAssetFamiliesComplete $out
    $job=Get-PMMFixLabJob $JobId
    $job.Build=[pscustomobject]@{Status='Built';OutputPath=$out;OutputSha256=(Get-Sha256 $out);RecipeId=[string]$recipe.id;VariantId=[string]$job.SelectedVariantId;Validation='Static PASS; runtime test required';BuiltUtc=[DateTime]::UtcNow.ToString('o')}
    Save-PMMFixLabJob $job|Out-Null
    return (Get-PMMFixLabJob $JobId)
  }catch{
    $job=Get-PMMFixLabJob $JobId
    $job.Build.Status='Failed';$job.Build.Validation=$_.Exception.Message
    Save-PMMFixLabJob $job|Out-Null
    throw
  }
}

function script:Export-PMMFixLabHandoff([string]$JobId) {
  $job=Get-PMMFixLabJob $JobId
  if(-not$job){throw 'Fix Lab job not found.'}
  $root=Get-PMMFixLabJobPath $JobId
  $stage=Join-Path (Get-PMMPath 'Temp') ('FixLabHandoff_'+$JobId+'_'+[guid]::NewGuid().ToString('N'))
  $zip=Join-Path (Get-PMMPath 'FixLabHandoffs') ($JobId+'_REPAIR_HANDOFF.zip')
  $partial=$zip+'.partial'
  New-Item -ItemType Directory -Force -Path $stage|Out-Null
  try{
    Copy-Item -LiteralPath (Join-Path $root 'job.json') -Destination (Join-Path $stage 'job.json') -Force
    $analysis=Join-Path $root 'Reports\analysis.json'
    if(Test-Path -LiteralPath $analysis -PathType Leaf){Copy-Item -LiteralPath $analysis -Destination (Join-Path $stage 'analysis.json') -Force}
    $indexes=Join-Path $stage 'pak-indexes';New-Item -ItemType Directory -Force -Path $indexes|Out-Null
    foreach($idx in @(Get-ChildItem -LiteralPath (Join-Path $root 'Reports') -Filter 'pak-index_*.txt' -File -ErrorAction SilentlyContinue)){Copy-Item -LiteralPath $idx.FullName -Destination (Join-Path $indexes $idx.Name) -Force}

    $recipe=$null
    if(-[string]::IsNullOrWhiteSpace([string]$job.SelectedRecipeId)){
      $recipe=Get-PMMFixLabRecipe ([string]$job.SelectedRecipeId)
      if($recipe){Write-PMMFixLabJson (Join-Path $stage 'selected-recipe.json') $recipe}
    }
    $knowledge=Join-Path $stage 'knowledge';New-Item -ItemType Directory -Force -Path $knowledge|Out-Null
    $recipeLibrary=Get-PMMFixLabRecipePath
    if(Test-Path -LiteralPath $recipeLibrary -PathType Leaf){Copy-Item -LiteralPath $recipeLibrary -Destination (Join-Path $knowledge 'fix-recipes.json') -Force}
    if($recipe -and ($recipe.PSObject.Properties.Name -contains 'caseId')){
      $caseRoot=Join-Path (Get-PMMPath 'CKLFixLabCases') ([string]$recipe.caseId)
      if(Test-Path -LiteralPath $caseRoot -PathType Container){Copy-Item -LiteralPath $caseRoot -Destination (Join-Path $knowledge ([string]$recipe.caseId)) -Recurse -Force}
    }
    $gr=Get-PMMGameReferenceState
    Write-PMMFixLabJson (Join-Path $stage 'game-reference-state.json') $gr
    $readme=@"
PMM FIX LAB REPAIR HANDOFF
==========================
Job: $JobId
Primary: $([string]$job.Primary.Name)
Primary SHA256: $([string]$job.Primary.Sha256)

This handoff contains the repair job, PAK indexes, selected recipe, Fix Lab CKL
case evidence and current Game Reference identity. Whole source PAKs/archives are
NOT duplicated. The original source identity is pinned by SHA-256 in job.json.

If more bytes are needed, use the indexes to request/extract only the exact
families required for research. Never modify the Fix Lab source snapshot in place.
"@
    Set-Content -LiteralPath (Join-Path $stage 'README_FIXLAB_HANDOFF.txt') -Value $readme -Encoding UTF8

    $runtime=Get-PMMRuntimePath
    if(-not(Test-Path -LiteralPath $runtime -PathType Leaf)){throw 'PMMRuntime.exe is required to create Fix Lab handoffs safely.'}
    Remove-Item -LiteralPath $partial -Force -ErrorAction SilentlyContinue
    $output=@(& $runtime archive create $partial $stage 2>&1|ForEach-Object{[string]$_})
    $exit=$LASTEXITCODE
    if($exit -ne 0 -or -not(Test-Path -LiteralPath $partial -PathType Leaf)){throw ('PMMRuntime archive create failed for Fix Lab handoff. '+($output -join ' '))}
    Move-Item -LiteralPath $partial -Destination $zip -Force
    Write-PMMLog ('Fix Lab handoff created: '+$zip)
    return $zip
  }finally{
    Remove-Item -LiteralPath $partial -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $stage -Recurse -Force -ErrorAction SilentlyContinue
  }
}

function script:Add-PMMFixLabOutputToLibrary([string]$JobId) {
  $job=Get-PMMFixLabJob $JobId
  if(-not$job -or -not$job.Build -or [string]$job.Build.Status -ne 'Built'){throw (Get-PMMText 'This Fix Lab job has no built output yet.' 'Este trabajo de Fix Lab aun no tiene una salida construida.')}
  $path=[string]$job.Build.OutputPath
  if(-not(Test-Path -LiteralPath $path -PathType Leaf)){throw 'Fix Lab output file is missing.'}
  Import-PMMMod $path
  Clear-PMMAnalysisState
  Write-PMMLog ('Fix Lab output imported to PMM library: '+[IO.Path]::GetFileName($path))
  return [IO.Path]::GetFileName($path)
}

function script:Get-PMMFixLabStatusSummary($Job) {
  if(-not$Job){return (Get-PMMText 'No Fix Lab job selected.' 'No hay ningun trabajo de Fix Lab seleccionado.')}
  $primary=if($Job.Primary){[string]$Job.Primary.Name}else{'?'}
  $analysis=if($Job.Analysis){[string]$Job.Analysis.Status}else{'NotAnalyzed'}
  $build=if($Job.Build){[string]$Job.Build.Status}else{'NotBuilt'}
  return ((Get-PMMText 'Job {0} | {1} | Analysis: {2} | Build: {3}' 'Trabajo {0} | {1} | Analisis: {2} | Build: {3}') -f [string]$Job.JobId,$primary,$analysis,$build)
}

# ===========================================================================
# Fix Lab workflow V2 dashboard + source backup / built-output library
# ===========================================================================

function script:Get-PMMFixLabFixedSourcesRoot {
  $p=Join-Path (Get-PMMPath 'FixLab') 'FixedSources'
  if(-not(Test-Path -LiteralPath $p -PathType Container)){New-Item -ItemType Directory -Force -Path $p|Out-Null}
  return $p
}

function script:Get-PMMFixLabBuiltRoot {
  $p=Join-Path (Get-PMMPath 'FixLab') 'Built'
  if(-not(Test-Path -LiteralPath $p -PathType Container)){New-Item -ItemType Directory -Force -Path $p|Out-Null}
  return $p
}

function script:Get-PMMFixLabWorkshopRoot {
  # Workspace is PMM's disposable/private working area. Repair providers,
  # temporary extraction and developer fixtures live here, never beside the
  # distributable application files and never in the public repository.
  $p=Join-Path (Get-PMMPath 'FixLab') 'Workshop'
  if(-not(Test-Path -LiteralPath $p -PathType Container)){New-Item -ItemType Directory -Force -Path $p|Out-Null}
  return $p
}

function script:Get-PMMFixLabFixturesRoot {
  # Compatibility alias for older internal callers. New code uses Workshop.
  return (Get-PMMFixLabWorkshopRoot)
}

function script:Assert-PMMFixLabNotCancelled {
  # Fix Lab currently runs in the editable WPF process. Pumping the message
  # queue at safe copy/checkpoint boundaries lets the existing CANCEL button
  # set PMM's cooperative cancellation flag without corrupting a transaction.
  try{[System.Windows.Forms.Application]::DoEvents()}catch{}
  try{
    if((Get-Command Test-PMMOperationCancellationRequested -ErrorAction SilentlyContinue) -and (Test-PMMOperationCancellationRequested)){
      throw [System.OperationCanceledException]::new('PMM_OPERATION_CANCELLED')
    }
  }catch{
    if($_.Exception -is [System.OperationCanceledException]){throw}
  }
}

function script:Copy-PMMFixLabStreamCancelable($InputStream,$OutputStream) {
  $buffer=New-Object byte[] (1024*1024)
  while($true){
    Assert-PMMFixLabNotCancelled
    $read=$InputStream.Read($buffer,0,$buffer.Length)
    if($read -le 0){break}
    $OutputStream.Write($buffer,0,$read)
  }
}

function script:Copy-PMMFixLabFileCancelable([string]$Source,[string]$Destination) {
  $src=$null;$dst=$null
  try{
    $src=[IO.File]::Open($Source,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::Read)
    $dst=[IO.File]::Open($Destination,[IO.FileMode]::Create,[IO.FileAccess]::Write,[IO.FileShare]::None)
    Copy-PMMFixLabStreamCancelable $src $dst
    $dst.Flush()
  }finally{if($dst){$dst.Dispose()};if($src){$src.Dispose()}}
}

function script:Get-PMMFixLabRecipePakHashes($Recipe) {
  $set=[System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
  if($Recipe -and ($Recipe.PSObject.Properties.Name -contains 'match') -and $Recipe.match){
    foreach($sig in @($Recipe.match.signatures)){
      if([string]$sig.kind -eq 'pak-sha256' -and -not[string]::IsNullOrWhiteSpace([string]$sig.sha256)){[void]$set.Add(([string]$sig.sha256).ToLowerInvariant())}
    }
  }
  return @($set)
}

function script:Get-PMMFixLabIgnoredSourcesPath { return (Join-PMMPath 'State' 'fixlab-ignored-sources.json') }

function script:Get-PMMFixLabIgnoredSourceRecords {
  $path=Get-PMMFixLabIgnoredSourcesPath
  if(-not(Test-Path -LiteralPath $path -PathType Leaf)){return @()}
  try{
    $raw=Get-Content -LiteralPath $path -Raw
    if([string]::IsNullOrWhiteSpace($raw)){return @()}
    return @($raw|ConvertFrom-Json)
  }catch{Write-PMMLog ('Could not read Fix Lab ignored-source state: '+$_.Exception.Message);return @()}
}

function script:Write-PMMFixLabIgnoredSourceRecords([array]$Records) {
  $path=Get-PMMFixLabIgnoredSourcesPath
  $temp=$path+'.tmp'
  $normalized=@($Records|Where-Object{$_ -and -not[string]::IsNullOrWhiteSpace([string]$_.Hash)}|Sort-Object Hash -Unique)
  ConvertTo-Json -InputObject @($normalized) -Depth 8|Set-Content -LiteralPath $temp -Encoding UTF8
  Move-Item -LiteralPath $temp -Destination $path -Force
}

function script:Test-PMMFixLabSourceIgnored([string]$Hash) {
  if([string]::IsNullOrWhiteSpace($Hash)){return $false}
  $h=$Hash.ToLowerInvariant()
  return (@(Get-PMMFixLabIgnoredSourceRecords|Where-Object{([string]$_.Hash).ToLowerInvariant() -eq $h}).Count -gt 0)
}

function script:Ignore-PMMFixLabCandidate($Candidate) {
  if(-not$Candidate){throw (Get-PMMText 'Select a repairable legacy source first.' 'Selecciona primero una fuente antigua reparable.')}
  $rows=[System.Collections.Generic.List[object]]::new()
  foreach($r in @(Get-PMMFixLabIgnoredSourceRecords)){$rows.Add($r)}
  foreach($src in @($Candidate.Sources)){
    if(-not$src){continue}
    if([string]$src.Origin -eq 'FixLabBackup' -or [string]$src.Origin -eq 'Backup'){continue}
    $hash=([string]$src.Hash).ToLowerInvariant()
    if([string]::IsNullOrWhiteSpace($hash)){continue}
    if(@($rows.ToArray()|Where-Object{([string]$_.Hash).ToLowerInvariant() -eq $hash}).Count -eq 0){
      $rows.Add([pscustomobject]@{Schema='PMM_FIXLAB_IGNORED_SOURCE_V1';Hash=$hash;Name=[string]$src.Name;RecipeId=[string]$Candidate.RecipeId;IgnoredUtc=[DateTime]::UtcNow.ToString('o')})
    }
  }
  Write-PMMFixLabIgnoredSourceRecords @($rows.ToArray())
  Write-PMMLog ('Fix Lab ignored exact source(s) for recipe '+[string]$Candidate.RecipeId)
  return @($rows.ToArray())
}

function script:Clear-PMMFixLabIgnoredSources {
  $path=Get-PMMFixLabIgnoredSourcesPath
  Remove-Item -LiteralPath $path -Force -ErrorAction SilentlyContinue
}

function script:Get-PMMFixLabDiscoveryCandidates([switch]$IncludeBackups,[array]$BackupRows=$null) {
  Initialize-PMMFixLab
  # A repair case remains discoverable after Apply.  At that point the legacy
  # source PAKs intentionally no longer live in the normal PMM library; they
  # live in FixLab\FixedSources so the user can rebuild another output or
  # revert later.  Treat those backups as valid recipe sources as well.
  # Read ignored-source state once per dashboard snapshot. RC23 called the JSON
  # reader once for every imported mod, and Refresh-PMMFixLabUI performed two
  # complete discovery scans. On a real 50-mod library that made opening the tab
  # and expanding Advanced feel coupled to filesystem work.
  $ignoredHashes=[System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
  foreach($ignored in @(Get-PMMFixLabIgnoredSourceRecords)){
    if($ignored -and -not[string]::IsNullOrWhiteSpace([string]$ignored.Hash)){[void]$ignoredHashes.Add(([string]$ignored.Hash).ToLowerInvariant())}
  }
  $sourcePool=[System.Collections.Generic.List[object]]::new()
  foreach($m in @(Get-LibraryMods)){
    if($m -and -not$ignoredHashes.Contains(([string]$m.Hash).ToLowerInvariant())){$sourcePool.Add([pscustomobject]@{Name=[string]$m.Name;Hash=[string]$m.Hash;Path=[string]$m.Path;Enabled=[bool]$m.Enabled;Origin='Library'})}
  }
  if($IncludeBackups){
    $resolvedBackups=@()
    if($PSBoundParameters.ContainsKey('BackupRows')){$resolvedBackups=@($BackupRows)}else{$resolvedBackups=@(Get-PMMFixLabBackups)}
    foreach($b in $resolvedBackups){
      if($b){$sourcePool.Add([pscustomobject]@{Name=[string]$b.Name;Hash=[string]$b.Hash;Path=[string]$b.Path;Enabled=$false;Origin='FixLabBackup'})}
    }
  }
  $mods=@($sourcePool.ToArray()|Sort-Object Path -Unique)
  $rows=[System.Collections.Generic.List[object]]::new()
  foreach($recipe in @(Get-PMMFixLabRecipes)){
    $hashes=@(Get-PMMFixLabRecipePakHashes $recipe)
    if($hashes.Count -eq 0){continue}
    $sources=@($mods|Where-Object{([string]$_.Hash).ToLowerInvariant() -in $hashes})
    if($sources.Count -eq 0){continue}
    $provider=$true
    if(($recipe.PSObject.Properties.Name -contains 'sourcePolicy') -and $recipe.sourcePolicy -and $recipe.sourcePolicy.buildProvider -and [bool]$recipe.sourcePolicy.buildProvider.required){
      $accepted=@($recipe.sourcePolicy.buildProvider.acceptedSignatures|Where-Object{[string]$_.kind -eq 'pak-sha256'}|ForEach-Object{([string]$_.sha256).ToLowerInvariant()})
      $provider=(@($sources|Where-Object{([string]$_.Hash).ToLowerInvariant() -in $accepted}).Count -gt 0)
    }
    $caseId=if($recipe.PSObject.Properties.Name -contains 'caseId'){[string]$recipe.caseId}else{[string]$recipe.id}
    $rows.Add([pscustomobject]@{
      RecipeId=[string]$recipe.id;CaseId=$caseId;Name=[string]$recipe.name;Description=[string]$recipe.description;
      SourceCount=$sources.Count;Sources=@($sources);SourceNames=(@($sources|ForEach-Object{if([string]$_.Origin -eq 'FixLabBackup'){[string]$_.Name+' [backup]'}else{[string]$_.Name}}) -join ', ');
      BuildProviderPresent=[bool]$provider;Exact=$true;
      Display=(([string]$recipe.name)+' | '+$sources.Count+' source mod(s) | Exact')
    })
  }
  return $rows.ToArray()
}

function script:Get-PMMFixLabCandidateByRecipeId([string]$RecipeId) {
  # Selection inside Fix Lab may legitimately come from preserved source backups.
  return @(Get-PMMFixLabDiscoveryCandidates -IncludeBackups|Where-Object{[string]$_.RecipeId -ieq $RecipeId}|Select-Object -First 1)[0]
}

function script:Get-PMMFixLabJobSourceHashes($Job) {
  if(-not$Job){return @()}
  return @((@($Job.Primary)+@($Job.Related))|ForEach-Object{([string]$_.Sha256).ToLowerInvariant()}|Where-Object{$_}|Sort-Object -Unique)
}

function script:Ensure-PMMFixLabJobForCandidate($Candidate,[switch]$Analyze) {
  if(-not$Candidate){throw (Get-PMMText 'Choose a repairable mod first.' 'Elige primero un mod reparable.')}
  $candidateHashes=@($Candidate.Sources|ForEach-Object{([string]$_.Hash).ToLowerInvariant()}|Sort-Object -Unique)
  $job=$null
  foreach($row in @(Get-PMMFixLabJobs)){
    $candidateJob=Get-PMMFixLabJob ([string]$row.JobId)
    if(-not$candidateJob){continue}
    $jobHashes=@(Get-PMMFixLabJobSourceHashes $candidateJob)
    if(($jobHashes -join '|') -ceq ($candidateHashes -join '|')){$job=$candidateJob;break}
  }
  if(-not$job){
    $sources=@($Candidate.Sources)
    if($sources.Count -eq 0){throw 'Fix Lab candidate contains no source mods.'}
    $job=New-PMMFixLabJob ([string]$sources[0].Path)
    foreach($src in @($sources|Select-Object -Skip 1)){Add-PMMFixLabRelatedSource ([string]$job.JobId) ([string]$src.Path)|Out-Null}
    $job=Get-PMMFixLabJob ([string]$job.JobId)
  }else{Set-PMMFixLabCurrentJobId ([string]$job.JobId)}
  if($Analyze -and ([string]$job.Analysis.Status -eq 'NotAnalyzed' -or [string]$job.Analysis.Status -eq 'NeedsResearch')){$job=Invoke-PMMFixLabAnalyze ([string]$job.JobId)}
  return $job
}

function script:Get-PMMFixLabKnownOutputBundle {
  # Case providers are internal Workshop material. The normal user workflow
  # must never open a file picker or search arbitrary application directories.
  $caseRoot=Join-Path (Get-PMMFixLabWorkshopRoot) 'FIXLAB-CASE-001-GAWR-GURA'
  $p=Join-Path $caseRoot 'GawrGura_v7.zip'
  if(Test-Path -LiteralPath $p -PathType Leaf){return [IO.Path]::GetFullPath($p)}
  return ''
}

function script:Get-PMMFixLabGuraFixtureVariant([string]$VariantId) {
  switch($VariantId){
    'original_fullreplacement' {return [pscustomobject]@{Zip='GawrGura_fullreplacement-3skins.zip';Pak='GawrGura_fullreplacement-3skins.pak'}}
    'normal_locked' {return [pscustomobject]@{Zip='GawrGura_gura.zip';Pak='GawrGura_gura.pak'}}
    'red_locked' {return [pscustomobject]@{Zip='GawrGura_red-gura.zip';Pak='GawrGura_red-gura.pak'}}
    'hooded_locked' {return [pscustomobject]@{Zip='GawrGura_hooded-gura.zip';Pak='GawrGura_hooded-gura.pak'}}
    'hair2_panties' {return [pscustomobject]@{Zip='GawrGura_hair2-panties-3skins.zip';Pak='GawrGura_hair2-panties-3skins.pak'}}
    default {return $null}
  }
}

function script:Test-PMMFixLabKnownOutputFixtureAvailable($Recipe,[string]$VariantId) {
  if(-not$Recipe -or [string]$Recipe.id -ne 'fixlab-case-001-gawr-gura-v5'){return $false}
  $map=Get-PMMFixLabGuraFixtureVariant $VariantId
  if(-not$map){return $false}
  $bundle=Get-PMMFixLabKnownOutputBundle
  if([string]::IsNullOrWhiteSpace($bundle)){return $false}
  # Validate the nested ZIP contract up front. This prevents an empty/corrupt
  # GawrGura_v7.zip from making Repair look ready and failing only after click.
  Add-Type -AssemblyName System.IO.Compression -ErrorAction SilentlyContinue
  Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction SilentlyContinue
  $outer=$null;$inner=$null;$memory=$null;$entryStream=$null
  try{
    $outer=[IO.Compression.ZipFile]::OpenRead($bundle)
    $entry=@($outer.Entries|Where-Object{[string]$_.FullName -eq [string]$map.Zip}|Select-Object -First 1)[0]
    if(-not$entry){return $false}
    $memory=[IO.MemoryStream]::new()
    $entryStream=$entry.Open();$entryStream.CopyTo($memory);$entryStream.Dispose();$entryStream=$null
    $memory.Position=0
    $inner=[IO.Compression.ZipArchive]::new($memory,[IO.Compression.ZipArchiveMode]::Read,$true)
    $pakEntry=@($inner.Entries|Where-Object{[string]$_.FullName -eq [string]$map.Pak}|Select-Object -First 1)[0]
    return ($null -ne $pakEntry -and [int64]$pakEntry.Length -gt 0)
  }catch{return $false}
  finally{
    if($entryStream){$entryStream.Dispose()};if($inner){$inner.Dispose()};if($memory){$memory.Dispose()};if($outer){$outer.Dispose()}
  }
}

function script:Invoke-PMMFixLabKnownOutputFixtureBuild($Job,$Recipe,[string]$VariantId) {
  $bundle=Get-PMMFixLabKnownOutputBundle
  if([string]::IsNullOrWhiteSpace($bundle)){throw (Get-PMMText 'The Case 001 developer fixture bundle GawrGura_v7.zip was not found. This test bridge validates workflow only; the real reconstruction executor is still being ported.' 'No se encontro el bundle de prueba GawrGura_v7.zip del Caso 001. Este puente solo valida el flujo; el ejecutor real de reconstruccion aun se esta portando.')}
  $map=Get-PMMFixLabGuraFixtureVariant $VariantId
  if(-not$map){throw 'Unknown Case 001 fixture variant.'}
  $variant=@($Recipe.variants|Where-Object{[string]$_.id -ieq $VariantId}|Select-Object -First 1)[0]
  if(-not$variant){throw 'Recipe variant metadata is missing.'}
  $jobRoot=Get-PMMFixLabJobPath ([string]$Job.JobId)
  $outRoot=Join-Path $jobRoot 'Output'
  $work=Join-Path $jobRoot 'Work\FixtureBridge'
  New-Item -ItemType Directory -Force -Path $outRoot,$work|Out-Null
  $nested=Join-Path $work ([string]$map.Zip)
  $out=Join-Path $outRoot ([string]$map.Pak)
  Remove-Item -LiteralPath $nested,$out -Force -ErrorAction SilentlyContinue
  Add-Type -AssemblyName System.IO.Compression -ErrorAction SilentlyContinue
  Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction SilentlyContinue
  $outer=$null;$inner=$null
  try{
    $outer=[IO.Compression.ZipFile]::OpenRead($bundle)
    $entry=@($outer.Entries|Where-Object{[string]$_.FullName -eq [string]$map.Zip}|Select-Object -First 1)[0]
    if(-not$entry){throw ('Fixture bundle is missing '+[string]$map.Zip)}
    $src=$entry.Open();$dst=[IO.File]::Create($nested)
    try{Copy-PMMFixLabStreamCancelable $src $dst}finally{$dst.Dispose();$src.Dispose()}
    $inner=[IO.Compression.ZipFile]::OpenRead($nested)
    $pakEntry=@($inner.Entries|Where-Object{[string]$_.FullName -eq [string]$map.Pak}|Select-Object -First 1)[0]
    if(-not$pakEntry){throw ('Fixture variant is missing '+[string]$map.Pak)}
    $src2=$pakEntry.Open();$dst2=[IO.File]::Create($out)
    try{Copy-PMMFixLabStreamCancelable $src2 $dst2}finally{$dst2.Dispose();$src2.Dispose()}
  }finally{
    if($inner){$inner.Dispose()};if($outer){$outer.Dispose()};Remove-Item -LiteralPath $nested -Force -ErrorAction SilentlyContinue
  }
  $hash=Get-Sha256 $out
  $expected=([string]$variant.knownOutputSha256).ToLowerInvariant()
  if(-not[string]::IsNullOrWhiteSpace($expected) -and $hash.ToLowerInvariant() -ne $expected){Remove-Item -LiteralPath $out -Force -ErrorAction SilentlyContinue;throw ('Fixture output hash mismatch. Expected '+$expected+' got '+$hash)}
  return [pscustomobject]@{OutputPath=$out;Mode='fixture-bridge';Validation='Golden output SHA-256 matched runtime-proven Case 001 fixture. Workflow validation only; no reconstruction was executed.'}
}

function script:Get-PMMFixLabAppliedOutputs {
  $rows=[System.Collections.Generic.List[object]]::new()
  $roots=@((Get-LibraryRoot),(Get-PMMDisabledModRoot))
  foreach($root in $roots){
    if(-not(Test-Path -LiteralPath $root -PathType Container)){continue}
    foreach($meta in @(Get-ChildItem -LiteralPath $root -Filter 'fixlab-output.json' -File -Recurse -ErrorAction SilentlyContinue)){
      try{
        $m=Get-Content -LiteralPath $meta.FullName -Raw|ConvertFrom-Json
        $dir=Split-Path -Parent $meta.FullName
        $pak=@(Get-ChildItem -LiteralPath $dir -Filter *.pak -File -ErrorAction SilentlyContinue|Select-Object -First 1)[0]
        if($pak){$rows.Add([pscustomobject]@{CaseId=[string]$m.CaseId;RecipeId=[string]$m.RecipeId;VariantId=[string]$m.VariantId;Name=$pak.Name;Path=$pak.FullName;Hash=(Get-Sha256 $pak.FullName);Enabled=(-not(Test-PMMPathInside $dir (Get-PMMDisabledModRoot)))})}
      }catch{}
    }
  }
  return $rows.ToArray()
}

function script:Register-PMMFixLabBuiltOutput($Job,[string]$OutputPath,[string]$Validation='') {
  if(-not$Job){throw 'Fix Lab job is required.'}
  $recipe=Get-PMMFixLabRecipe ([string]$Job.SelectedRecipeId)
  if(-not$recipe){throw 'Fix Lab recipe is unavailable.'}
  $variant=@($recipe.variants|Where-Object{[string]$_.id -ieq [string]$Job.SelectedVariantId}|Select-Object -First 1)[0]
  if(-not$variant){throw 'Fix Lab variant is unavailable.'}
  $caseId=if($recipe.PSObject.Properties.Name -contains 'caseId'){[string]$recipe.caseId}else{[string]$recipe.id}
  $destRoot=Join-Path (Join-Path (Get-PMMFixLabBuiltRoot) $caseId) ([string]$variant.id)
  New-Item -ItemType Directory -Force -Path $destRoot|Out-Null
  $dest=Join-Path $destRoot ([IO.Path]::GetFileName($OutputPath))
  Copy-Item -LiteralPath $OutputPath -Destination $dest -Force
  $hash=Get-Sha256 $dest
  $deployAllowed=$true
  if($variant.PSObject.Properties.Name -contains 'deployAllowed'){$deployAllowed=[bool]$variant.deployAllowed}
  $deploymentNote=''
  if($variant.PSObject.Properties.Name -contains 'deploymentNote'){$deploymentNote=[string]$variant.deploymentNote}
  $outputClass=if($variant.PSObject.Properties.Name -contains 'outputClass'){[string]$variant.outputClass}else{if($deployAllowed){'experimental-repair'}else{'engine-test'}}
  $runtimeStatus=if($variant.PSObject.Properties.Name -contains 'runtimeStatus'){[string]$variant.runtimeStatus}else{''}
  $buildStatus=if($variant.PSObject.Properties.Name -contains 'buildStatus'){[string]$variant.buildStatus}else{''}
  $record=[ordered]@{
    Schema='PMM_FIXLAB_BUILT_OUTPUT_V1';BuildId=($caseId+'__'+[string]$variant.id);CaseId=$caseId;RecipeId=[string]$recipe.id;VariantId=[string]$variant.id;
    VariantLabel=[string]$variant.label;Description=[string]$variant.description;Path=$dest;Hash=$hash;BuiltUtc=[DateTime]::UtcNow.ToString('o');
    SourceNames=@((@($Job.Primary)+@($Job.Related))|ForEach-Object{[string]$_.Name});SourceHashes=@((@($Job.Primary)+@($Job.Related))|ForEach-Object{[string]$_.Sha256});Validation=$Validation;
    DeployAllowed=$deployAllowed;DeploymentNote=$deploymentNote;OutputClass=$outputClass;RuntimeStatus=$runtimeStatus;BuildStatus=$buildStatus
  }
  Write-PMMFixLabJson (Join-Path $destRoot 'build.json') $record
  return [pscustomobject]$record
}

function script:Get-PMMFixLabBuiltOutputs {
  $root=Get-PMMFixLabBuiltRoot
  $applied=@(Get-PMMFixLabAppliedOutputs)
  $rows=[System.Collections.Generic.List[object]]::new()
  foreach($meta in @(Get-ChildItem -LiteralPath $root -Filter build.json -File -Recurse -ErrorAction SilentlyContinue|Sort-Object LastWriteTimeUtc -Descending)){
    try{
      $m=Get-Content -LiteralPath $meta.FullName -Raw|ConvertFrom-Json
      if(-not(Test-Path -LiteralPath ([string]$m.Path) -PathType Leaf)){continue}
      $isApplied=(@($applied|Where-Object{[string]$_.CaseId -ieq [string]$m.CaseId -and [string]$_.VariantId -ieq [string]$m.VariantId}).Count -gt 0)
      $fi=Get-Item -LiteralPath ([string]$m.Path) -ErrorAction SilentlyContinue
      $sizeMb=if($fi){('{0:N2} MB' -f ($fi.Length/1MB))}else{'-'}
      $builtDisplay=''
      try{$builtDisplay=([datetime]$m.BuiltUtc).ToLocalTime().ToString('yyyy-MM-dd HH:mm')}catch{$builtDisplay=[string]$m.BuiltUtc}
      $deployAllowed=$true
      if($m.PSObject.Properties.Name -contains 'DeployAllowed'){$deployAllowed=[bool]$m.DeployAllowed}
      $deploymentNote=''
      if($m.PSObject.Properties.Name -contains 'DeploymentNote'){$deploymentNote=[string]$m.DeploymentNote}
      $outputClass=if($m.PSObject.Properties.Name -contains 'OutputClass'){[string]$m.OutputClass}else{if($deployAllowed){'experimental-repair'}else{'engine-test'}}
      $runtimeStatus=if($m.PSObject.Properties.Name -contains 'RuntimeStatus'){[string]$m.RuntimeStatus}else{''}
      $buildStatus=if($m.PSObject.Properties.Name -contains 'BuildStatus'){[string]$m.BuildStatus}else{''}
      $validation=if($m.PSObject.Properties.Name -contains 'Validation'){[string]$m.Validation}else{''}
      $confidenceLevel='MEDIUM'
      $confidenceText=(Get-PMMText 'Confidence: MEDIUM - deployable repair; runtime validation not recorded.' 'Confianza: MEDIA - reparacion desplegable; no hay validacion runtime registrada.')
      $confidenceDetails=$confidenceText
      if($isApplied){
        $confidenceLevel='APPLIED'
        $confidenceText=(Get-PMMText 'Confidence: applied output' 'Confianza: salida aplicada')
        $confidenceDetails=(Get-PMMText 'This exact built output is currently applied.' 'Esta salida construida exacta esta aplicada actualmente.')
      }elseif(-not$deployAllowed){
        $confidenceLevel='ENGINE TEST'
        $confidenceText=(Get-PMMText 'Confidence: ENGINE TEST - not deployable' 'Confianza: PRUEBA DE MOTOR - no desplegable')
        $confidenceDetails=if([string]::IsNullOrWhiteSpace($deploymentNote)){$confidenceText}else{$deploymentNote}
      }elseif($outputClass -ieq 'runtime-proven-repair'){
        $confidenceLevel='VERY HIGH'
        $confidenceText=(Get-PMMText 'Confidence: VERY HIGH - runtime proven' 'Confianza: MUY ALTA - probada en runtime')
        $confidenceDetails=(Get-PMMText 'This repair has recorded in-game runtime acceptance evidence.' 'Esta reparacion tiene evidencia registrada de aceptacion runtime dentro del juego.')
      }elseif($buildStatus -match 'validated-structural-output|validated-research-output'){
        $confidenceLevel='HIGH'
        if($validation -match 'Known research output SHA-256 reproduced exactly|known research output.*reproduced'){
          $confidenceText=(Get-PMMText 'Confidence: HIGH - validated + known research output reproduced' 'Confianza: ALTA - validada + salida de investigacion conocida reproducida')
          $confidenceDetails=(Get-PMMText 'The exact output passed Fix Lab structural validation and reproduced the known research-output hash. It is deployable; a runtime user result has not been recorded yet.' 'La salida exacta paso la validacion estructural de Fix Lab y reprodujo el hash de la salida de investigacion conocida. Es desplegable; aun no se ha registrado un resultado runtime del usuario.')
        }else{
          $confidenceText=(Get-PMMText 'Confidence: HIGH - structurally validated' 'Confianza: ALTA - validada estructuralmente')
          $confidenceDetails=(Get-PMMText 'The exact output passed Fix Lab structural validation and is deployable. A runtime user result has not been recorded yet.' 'La salida exacta paso la validacion estructural de Fix Lab y es desplegable. Aun no se ha registrado un resultado runtime del usuario.')
        }
      }
      $statusSuffix=if($isApplied){'  [APPLIED]'}elseif(-not$deployAllowed){'  [ENGINE TEST - NOT DEPLOYABLE]'}elseif($outputClass -ieq 'runtime-proven-repair'){'  [VERY HIGH CONFIDENCE]'}elseif($confidenceLevel -eq 'HIGH'){'  [HIGH CONFIDENCE]'}else{'  [DEPLOYABLE]'}
      $statusGlyph=if($isApplied){'●'}elseif(-not$deployAllowed){'⚙'}elseif($outputClass -ieq 'runtime-proven-repair'){'✓'}elseif($confidenceLevel -eq 'HIGH'){'◆'}else{'◇'}
      $statusColor=if($isApplied){'#2563EB'}elseif(-not$deployAllowed){'#D97706'}elseif($outputClass -ieq 'runtime-proven-repair'){'#2E9D50'}elseif($confidenceLevel -eq 'HIGH'){'#3B82F6'}else{'#64748B'}
      $rows.Add([pscustomobject]@{BuildId=[string]$m.BuildId;CaseId=[string]$m.CaseId;RecipeId=[string]$m.RecipeId;VariantId=[string]$m.VariantId;VariantLabel=[string]$m.VariantLabel;Description=[string]$m.Description;Path=[string]$m.Path;Hash=[string]$m.Hash;BuiltUtc=[string]$m.BuiltUtc;BuiltDisplay=$builtDisplay;SizeMb=$sizeMb;Applied=$isApplied;DeployAllowed=$deployAllowed;DeploymentNote=$deploymentNote;OutputClass=$outputClass;RuntimeStatus=$runtimeStatus;BuildStatus=$buildStatus;Validation=$validation;ConfidenceLevel=$confidenceLevel;ConfidenceText=$confidenceText;ConfidenceDetails=$confidenceDetails;StatusGlyph=$statusGlyph;StatusColor=$statusColor;Display=([string]$m.VariantLabel+$statusSuffix)})
    }catch{}
  }
  return $rows.ToArray()
}

function script:Get-PMMFixLabBackups {
  $root=Get-PMMFixLabFixedSourcesRoot
  $rows=[System.Collections.Generic.List[object]]::new()
  foreach($meta in @(Get-ChildItem -LiteralPath $root -Filter fixlab-backup.json -File -Recurse -ErrorAction SilentlyContinue|Sort-Object LastWriteTimeUtc -Descending)){
    try{
      $m=Get-Content -LiteralPath $meta.FullName -Raw|ConvertFrom-Json
      $dir=Split-Path -Parent $meta.FullName
      $pak=@(Get-ChildItem -LiteralPath $dir -Filter *.pak -File -ErrorAction SilentlyContinue|Select-Object -First 1)[0]
      if($pak){
        $sizeMb=('{0:N2} MB' -f ($pak.Length/1MB))
        $createdDisplay=''
        try{$createdDisplay=([datetime]$m.BackedUpUtc).ToLocalTime().ToString('yyyy-MM-dd HH:mm')}catch{$createdDisplay=[string]$m.BackedUpUtc}
        $rows.Add([pscustomobject]@{CaseId=[string]$m.CaseId;RecipeId=[string]$m.RecipeId;Name=[string]$m.Name;Hash=[string]$m.Hash;Path=$pak.FullName;OriginalEnabled=[bool]$m.OriginalEnabled;OriginalPriority=$(if($m.PSObject.Properties.Name -contains 'OriginalPriority'){[int]$m.OriginalPriority}else{2147483647});BackedUpUtc=[string]$m.BackedUpUtc;CreatedDisplay=$createdDisplay;SizeMb=$sizeMb;Display=([string]$m.Name+' | '+[string]$m.CaseId)})
      }
    }catch{}
  }
  return $rows.ToArray()
}

function script:Backup-PMMFixLabCaseSources($Recipe) {
  if(-not$Recipe){throw 'Fix Lab recipe is required.'}
  $caseId=if($Recipe.PSObject.Properties.Name -contains 'caseId'){[string]$Recipe.caseId}else{[string]$Recipe.id}
  $hashes=@(Get-PMMFixLabRecipePakHashes $Recipe)
  $allMods=@((Get-LibraryMods)+@(Get-PMMDisabledMods))
  $mods=@($allMods|Where-Object{([string]$_.Hash).ToLowerInvariant() -in $hashes})
  $caseRoot=Join-Path (Get-PMMFixLabFixedSourcesRoot) $caseId
  New-Item -ItemType Directory -Force -Path $caseRoot|Out-Null
  foreach($mod in $mods){
    $srcDir=Split-Path -Parent ([string]$mod.Path)
    $folder=Split-Path -Leaf $srcDir
    $safe=($folder -replace '[^A-Za-z0-9_.-]','_')
    $dest=Join-Path $caseRoot (([string]$mod.Hash).Substring(0,8)+'_'+$safe)
    if(Test-Path -LiteralPath $dest -PathType Container){
      $existing=@(Get-ChildItem -LiteralPath $dest -Filter *.pak -File -ErrorAction SilentlyContinue|Select-Object -First 1)[0]
      if(-not$existing -or (Get-Sha256 $existing.FullName).ToLowerInvariant() -ne ([string]$mod.Hash).ToLowerInvariant()){throw ('Fix Lab backup destination already exists with different content: '+$dest)}
      Remove-Item -LiteralPath $srcDir -Recurse -Force
    }else{Move-Item -LiteralPath $srcDir -Destination $dest}
    $meta=[ordered]@{Schema='PMM_FIXLAB_SOURCE_BACKUP_V2';CaseId=$caseId;RecipeId=[string]$Recipe.id;Name=[string]$mod.Name;Hash=[string]$mod.Hash;OriginalFolderName=$folder;OriginalEnabled=[bool]$mod.Enabled;OriginalPriority=[int]$mod.Priority;BackedUpUtc=[DateTime]::UtcNow.ToString('o')}
    Write-PMMFixLabJson (Join-Path $dest 'fixlab-backup.json') $meta
    Add-PMMPendingRemoval ([string]$mod.Name) ([string]$mod.Hash)
  }
  if($mods.Count -gt 0){Clear-PMMLibraryHashCache;Clear-PakEntryCache;Clear-PMMAnalysisState;[void](Get-PMMModPriorityOrder)}
  return @(Get-PMMFixLabBackups|Where-Object{[string]$_.CaseId -ieq $caseId})
}

function script:Remove-PMMFixLabAppliedCaseOutputs([string]$CaseId) {
  foreach($row in @(Get-PMMFixLabAppliedOutputs|Where-Object{[string]$_.CaseId -ieq $CaseId})){
    $dir=Split-Path -Parent ([string]$row.Path)
    Add-PMMPendingRemoval ([string]$row.Name) ([string]$row.Hash)
    Remove-Item -LiteralPath $dir -Recurse -Force -ErrorAction Stop
  }
}

function script:Apply-PMMFixLabBuiltOutput($Built) {
  if(-not$Built){throw (Get-PMMText 'Choose a built fix first.' 'Elige primero un fix construido.')}
  if(-not(Test-Path -LiteralPath ([string]$Built.Path) -PathType Leaf)){throw 'Built Fix Lab output is missing.'}
  if((Get-Sha256 ([string]$Built.Path)).ToLowerInvariant() -ne ([string]$Built.Hash).ToLowerInvariant()){throw 'Built Fix Lab output hash changed.'}
  $recipe=Get-PMMFixLabRecipe ([string]$Built.RecipeId)
  if(-not$recipe){throw 'Fix Lab recipe is unavailable.'}
  [void](Backup-PMMFixLabCaseSources $recipe)
  Remove-PMMFixLabAppliedCaseOutputs ([string]$Built.CaseId)
  $pakName=[IO.Path]::GetFileName([string]$Built.Path)
  if(-not$pakName.EndsWith('_P.pak',[StringComparison]::OrdinalIgnoreCase)){
    throw ('Refusing to deploy a Fix Lab repair without Unreal patch priority suffix _P.pak: '+$pakName)
  }
  $slug=([IO.Path]::GetFileNameWithoutExtension($pakName) -replace '[^A-Za-z0-9_.-]','_')
  $dest=Join-Path (Get-LibraryRoot) $slug
  if(Test-Path -LiteralPath $dest -PathType Container){throw ('PMM library destination already exists: '+$dest)}
  New-Item -ItemType Directory -Force -Path $dest|Out-Null
  Copy-Item -LiteralPath ([string]$Built.Path) -Destination (Join-Path $dest $pakName) -Force
  [ordered]@{Name=$pakName;Hash=[string]$Built.Hash;Imported=(Get-Date).ToString('o');Source='FixLab';FixLabCaseId=[string]$Built.CaseId;FixLabVariantId=[string]$Built.VariantId}|ConvertTo-Json -Depth 8|Set-Content -LiteralPath (Join-Path $dest 'metadata.json') -Encoding UTF8
  Write-PMMFixLabJson (Join-Path $dest 'fixlab-output.json') ([ordered]@{Schema='PMM_FIXLAB_APPLIED_OUTPUT_V1';CaseId=[string]$Built.CaseId;RecipeId=[string]$Built.RecipeId;VariantId=[string]$Built.VariantId;BuildId=[string]$Built.BuildId;AppliedUtc=[DateTime]::UtcNow.ToString('o')})
  Remove-PMMPendingRemoval $pakName
  Clear-PMMLibraryHashCache;Clear-PakEntryCache;Clear-PMMAnalysisState;[void](Get-PMMModPriorityOrder)
  Write-PMMLog ('Fix Lab applied built output to PMM library: '+$pakName+' | case '+[string]$Built.CaseId)
  return $pakName
}

function script:Get-PMMFixLabCaseSourceRecords($Recipe) {
  if(-not$Recipe){return @()}
  $hashes=@(Get-PMMFixLabRecipePakHashes $Recipe)
  $rows=[System.Collections.Generic.List[object]]::new()
  foreach($m in @((Get-LibraryMods)+@(Get-PMMDisabledMods))){
    if($m -and ([string]$m.Hash).ToLowerInvariant() -in $hashes){$rows.Add([pscustomobject]@{Name=[string]$m.Name;Hash=[string]$m.Hash;Path=[string]$m.Path;Origin='Library'})}
  }
  $caseId=if($Recipe.PSObject.Properties.Name -contains 'caseId'){[string]$Recipe.caseId}else{[string]$Recipe.id}
  foreach($b in @(Get-PMMFixLabBackups|Where-Object{[string]$_.CaseId -ieq $caseId})){
    if($b){$rows.Add([pscustomobject]@{Name=[string]$b.Name;Hash=[string]$b.Hash;Path=[string]$b.Path;Origin='Backup'})}
  }
  return @($rows.ToArray()|Sort-Object Name,Hash -Unique)
}

function script:Deploy-PMMFixLabBuiltOutput($Built) {
  if(-not$Built){throw (Get-PMMText 'Choose a built fix first.' 'Elige primero un fix construido.')}
  $builtPath=[string]$Built.Path
  if(-not(Test-Path -LiteralPath $builtPath -PathType Leaf)){throw 'Built Fix Lab output is missing.'}
  $builtHash=(Get-Sha256 $builtPath).ToLowerInvariant()
  if($builtHash -ne ([string]$Built.Hash).ToLowerInvariant()){throw 'Built Fix Lab output hash changed.'}
  if(-not(Test-Pak $builtPath)){throw 'Built Fix Lab output PAK failed verification.'}
  Assert-PakAssetFamiliesComplete $builtPath
  $recipe=Get-PMMFixLabRecipe ([string]$Built.RecipeId)
  if(-not$recipe){throw 'Fix Lab recipe is unavailable.'}

  $cfg=Get-PMMConfig
  if(-not$cfg.GamePath){throw (Get-PMMText 'Detect or configure Palworld before Apply Fix.' 'Detecta o configura Palworld antes de Aplicar Fix.')}
  Ensure-GameModsFolder
  Stop-PalworldForDeployment
  $gameMods=Get-GameModsPath
  $pakName=[IO.Path]::GetFileName($builtPath)
  $gameDest=Join-Path $gameMods $pakName
  $caseId=[string]$Built.CaseId
  $sources=@(Get-PMMFixLabCaseSourceRecords $recipe)
  $appliedBefore=@(Get-PMMFixLabAppliedOutputs|Where-Object{[string]$_.CaseId -ieq $caseId})

  $txRoot=Join-Path (Join-Path (Get-PMMPath 'FixLab') 'Deployments') ((Get-Date -Format 'yyyyMMdd_HHmmss')+'_'+[guid]::NewGuid().ToString('N').Substring(0,8))
  $gameBackup=Join-Path $txRoot 'GameBefore'
  $libraryBackup=Join-Path $txRoot 'LibraryBefore'
  New-Item -ItemType Directory -Force -Path $gameBackup,$libraryBackup|Out-Null
  $gameRecords=[System.Collections.Generic.List[object]]::new()
  $libraryRecords=[System.Collections.Generic.List[object]]::new()
  $staged=Join-Path $gameMods ('.pmm_fixlab_stage_'+[guid]::NewGuid().ToString('N')+'_'+$pakName)
  $libraryChanged=$false;$gameChanged=$false

  try{
    Assert-PMMFixLabNotCancelled
    # Validate every legacy/applied PAK PMM intends to retire. Same-name foreign
    # files block the operation instead of being overwritten or deleted.
    $retire=[System.Collections.Generic.List[object]]::new()
    foreach($src in $sources){
      $gp=Join-Path $gameMods ([string]$src.Name)
      if(Test-Path -LiteralPath $gp -PathType Leaf){
        $h=(Get-Sha256 $gp).ToLowerInvariant()
        if($h -ne ([string]$src.Hash).ToLowerInvariant()){throw ((Get-PMMText "Apply Fix will not remove '{0}' because its game-folder hash is not the recognized legacy source." "Aplicar Fix no eliminara '{0}' porque su hash en la carpeta del juego no coincide con la fuente antigua reconocida.") -f [string]$src.Name)}
        $retire.Add([pscustomobject]@{Path=$gp;Name=[string]$src.Name;Hash=$h;Reason='legacy-source'})
      }
    }
    foreach($old in $appliedBefore){
      $gp=Join-Path $gameMods ([string]$old.Name)
      if(Test-Path -LiteralPath $gp -PathType Leaf){
        $h=(Get-Sha256 $gp).ToLowerInvariant()
        if($h -ne ([string]$old.Hash).ToLowerInvariant()){throw ((Get-PMMText "Apply Fix will not replace '{0}' because its game-folder hash is not the PMM-managed repaired output." "Aplicar Fix no reemplazara '{0}' porque su hash en la carpeta del juego no coincide con la salida reparada gestionada por PMM.") -f [string]$old.Name)}
        $retire.Add([pscustomobject]@{Path=$gp;Name=[string]$old.Name;Hash=$h;Reason='previous-fix'})
      }
    }
    # Fix Lab owns only the recognized legacy source and repaired output. A
    # deployed PMM compatibility merge belongs exclusively to Mods & Merge and
    # must remain byte-for-byte untouched until an explicit merge Deploy,
    # Undeploy or Delete merge action changes it.
    if(Test-Path -LiteralPath $gameDest -PathType Leaf){
      $existing=(Get-Sha256 $gameDest).ToLowerInvariant()
      if($existing -ne $builtHash){
        $known=@($appliedBefore|Where-Object{[string]$_.Name -ieq $pakName -and ([string]$_.Hash).ToLowerInvariant() -eq $existing})
        if($known.Count -eq 0){throw ((Get-PMMText "Apply Fix will not overwrite '{0}' because an unrecognized PAK with that name already exists in ~mods." "Aplicar Fix no sobrescribira '{0}' porque ya existe en ~mods un PAK no reconocido con ese nombre.") -f $pakName)}
      }
    }

    # Snapshot library folders that Apply may move/remove, so a later game-file
    # failure can restore the library exactly rather than reverting to a
    # different logical state. Existing FixedSources are also preserved so a
    # failed variant switch never destroys the original archived legacy source.
    $caseBackup=Join-Path (Get-PMMFixLabFixedSourcesRoot) $caseId
    $caseBackupSnapshot=''
    if(Test-Path -LiteralPath $caseBackup -PathType Container){
      $caseBackupSnapshot=Join-Path $libraryBackup 'FixedSourcesCaseBefore'
      Copy-Item -LiteralPath $caseBackup -Destination $caseBackupSnapshot -Recurse -Force
    }
    $dirs=[System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach($src in $sources){if([string]$src.Origin -eq 'Library' -and $src.Path){[void]$dirs.Add((Split-Path -Parent ([string]$src.Path)))}}
    foreach($old in $appliedBefore){if($old.Path){[void]$dirs.Add((Split-Path -Parent ([string]$old.Path)))}}
    $li=0
    foreach($dir in $dirs){
      if(-not(Test-Path -LiteralPath $dir -PathType Container)){continue}
      $li++;$copy=Join-Path $libraryBackup ('L'+$li)
      Copy-Item -LiteralPath $dir -Destination $copy -Recurse -Force
      $libraryRecords.Add([pscustomobject]@{Original=$dir;Backup=$copy})
    }

    # Stage and verify the repaired PAK before changing either state.
    Assert-PMMFixLabNotCancelled
    Copy-PMMFixLabFileCancelable $builtPath $staged
    if((Get-Sha256 $staged).ToLowerInvariant() -ne $builtHash){throw 'Apply Fix staging hash mismatch.'}

    # Update PMM library: source -> FixedSources, selected repair -> Mods.
    Assert-PMMFixLabNotCancelled
    $appliedName=Apply-PMMFixLabBuiltOutput $Built
    $libraryChanged=$true

    # Backup game files, then commit the small Fix Lab transaction.
    $ri=0
    foreach($r in @($retire.ToArray()|Sort-Object Path -Unique)){
      if(-not(Test-Path -LiteralPath ([string]$r.Path) -PathType Leaf)){continue}
      $ri++;$backup=Join-Path $gameBackup ('G'+$ri+'_'+[IO.Path]::GetFileName([string]$r.Path))
      Copy-PMMFixLabFileCancelable ([string]$r.Path) $backup
      $gameRecords.Add([pscustomobject]@{Original=[string]$r.Path;Backup=$backup;Hash=[string]$r.Hash})
    }
    Assert-PMMFixLabNotCancelled
    foreach($r in @($retire.ToArray()|Sort-Object Path -Unique)){if(Test-Path -LiteralPath ([string]$r.Path) -PathType Leaf){Remove-Item -LiteralPath ([string]$r.Path) -Force}}
    if(Test-Path -LiteralPath $gameDest -PathType Leaf){Remove-Item -LiteralPath $gameDest -Force}
    Move-Item -LiteralPath $staged -Destination $gameDest -Force
    $gameChanged=$true
    if((Get-Sha256 $gameDest).ToLowerInvariant() -ne $builtHash){throw 'Apply Fix committed PAK hash mismatch.'}

    # Preserve transaction evidence and force the normal pipeline to re-analyze.
    [ordered]@{Schema='PMM_FIXLAB_DEPLOY_V1';CaseId=$caseId;VariantId=[string]$Built.VariantId;Pak=$pakName;Hash=$builtHash;CommittedUtc=[DateTime]::UtcNow.ToString('o');GameBackups=@($gameRecords);LibraryBackups=@($libraryRecords)}|ConvertTo-Json -Depth 12|Set-Content -LiteralPath (Join-Path $txRoot 'transaction.json') -Encoding UTF8
    Clear-PMMLibraryHashCache;Clear-PakEntryCache;Clear-PMMAnalysisState;[void](Get-PMMModPriorityOrder)
    Write-PMMLog ('Fix Lab Apply Fix committed: '+$pakName+' | case '+$caseId+' | transaction '+$txRoot)
    return [pscustomobject]@{Name=$appliedName;Path=$gameDest;Hash=$builtHash;Transaction=$txRoot}
  }catch{
    $caught=$_
    $failure=$_.Exception.Message
    $cancelled=($caught.Exception -is [System.OperationCanceledException] -or $failure -eq 'PMM_OPERATION_CANCELLED')
    try{if(Test-Path -LiteralPath $staged -PathType Leaf){Remove-Item -LiteralPath $staged -Force}}catch{}
    if($gameChanged -or $gameRecords.Count -gt 0){
      try{if(Test-Path -LiteralPath $gameDest -PathType Leaf){Remove-Item -LiteralPath $gameDest -Force}}catch{}
      foreach($r in @($gameRecords)){
        try{Copy-Item -LiteralPath ([string]$r.Backup) -Destination ([string]$r.Original) -Force}catch{Write-PMMLog ('Fix Lab game rollback warning: '+$_.Exception.Message)}
      }
    }
    if($libraryChanged){
      try{
        foreach($row in @(Get-PMMFixLabAppliedOutputs|Where-Object{[string]$_.CaseId -ieq $caseId})){
          $dir=Split-Path -Parent ([string]$row.Path);if(Test-Path -LiteralPath $dir -PathType Container){Remove-Item -LiteralPath $dir -Recurse -Force}
        }
        # Remove newly-created source backup folders for this case, then restore
        # the pre-transaction library directory snapshots.
        $caseBackup=Join-Path (Get-PMMFixLabFixedSourcesRoot) $caseId
        if(Test-Path -LiteralPath $caseBackup -PathType Container){Remove-Item -LiteralPath $caseBackup -Recurse -Force}
        if(-not[string]::IsNullOrWhiteSpace([string]$caseBackupSnapshot) -and (Test-Path -LiteralPath $caseBackupSnapshot -PathType Container)){Copy-Item -LiteralPath $caseBackupSnapshot -Destination $caseBackup -Recurse -Force}
        foreach($r in @($libraryRecords)){
          if(Test-Path -LiteralPath ([string]$r.Original)){Remove-Item -LiteralPath ([string]$r.Original) -Recurse -Force}
          Copy-Item -LiteralPath ([string]$r.Backup) -Destination ([string]$r.Original) -Recurse -Force
        }
        Clear-PMMLibraryHashCache;Clear-PakEntryCache;Clear-PMMAnalysisState;[void](Get-PMMModPriorityOrder)
      }catch{Write-PMMLog ('Fix Lab library rollback warning: '+$_.Exception.Message)}
    }
    try{[ordered]@{Schema='PMM_FIXLAB_DEPLOY_V1';State='RolledBack';FailedUtc=[DateTime]::UtcNow.ToString('o');Error=$failure;Cancelled=[bool]$cancelled}|ConvertTo-Json|Set-Content -LiteralPath (Join-Path $txRoot 'transaction.json') -Encoding UTF8}catch{}
    if($cancelled){throw [System.OperationCanceledException]::new('PMM_OPERATION_CANCELLED')}
    throw ((Get-PMMText 'Apply Fix failed. PMM attempted to restore both the game folder and library state. Details: ' 'Aplicar Fix fallo. PMM intento restaurar tanto la carpeta del juego como el estado de la biblioteca. Detalles: ')+$failure)
  }
}

function script:Restore-PMMFixLabCase([string]$CaseId) {
  if([string]::IsNullOrWhiteSpace($CaseId)){throw 'Fix Lab case id is required.'}
  $cfg=Get-PMMConfig
  $gameMods=''
  if($cfg.GamePath){try{Ensure-GameModsFolder;$gameMods=Get-GameModsPath}catch{}}

  # Retire the currently applied repair from the game only when it is exactly
  # the PMM-managed repair. Never remove a foreign same-name file.
  $applied=@(Get-PMMFixLabAppliedOutputs|Where-Object{[string]$_.CaseId -ieq $CaseId})
  foreach($row in $applied){
    if(-not[string]::IsNullOrWhiteSpace($gameMods)){
      $gp=Join-Path $gameMods ([string]$row.Name)
      if(Test-Path -LiteralPath $gp -PathType Leaf){
        $actual=(Get-Sha256 $gp).ToLowerInvariant();$expected=([string]$row.Hash).ToLowerInvariant()
        if($actual -ne $expected){throw ((Get-PMMText "Restore will not remove '{0}' because the game-folder hash is not the PMM-managed repaired output." "Restore no eliminara '{0}' porque el hash de la carpeta del juego no coincide con la reparacion gestionada por PMM.") -f [string]$row.Name)}
        Remove-Item -LiteralPath $gp -Force
      }
    }
  }
  Remove-PMMFixLabAppliedCaseOutputs $CaseId

  $backupRows=@(Get-PMMFixLabBackups|Where-Object{[string]$_.CaseId -ieq $CaseId}|Sort-Object OriginalPriority,Name)
  $restoredPriority=@{}
  foreach($row in $backupRows){
    $backupDir=Split-Path -Parent ([string]$row.Path)
    $metaPath=Join-Path $backupDir 'fixlab-backup.json'
    $meta=Get-Content -LiteralPath $metaPath -Raw|ConvertFrom-Json
    $destRoot=if([bool]$meta.OriginalEnabled){Get-LibraryRoot}else{Get-PMMDisabledModRoot}
    New-Item -ItemType Directory -Force -Path $destRoot|Out-Null
    $dest=Join-Path $destRoot ([string]$meta.OriginalFolderName)
    if(Test-Path -LiteralPath $dest){throw ('Cannot restore Fix Lab source because destination already exists: '+$dest)}
    $priority=2147483647
    if($meta.PSObject.Properties.Name -contains 'OriginalPriority'){$priority=[int]$meta.OriginalPriority}
    $restoredPriority[[string]$meta.Name]=$priority
    Remove-Item -LiteralPath $metaPath -Force -ErrorAction SilentlyContinue
    Move-Item -LiteralPath $backupDir -Destination $dest
    $pak=Join-Path $dest ([string]$meta.Name)
    if(-not(Test-Path -LiteralPath $pak -PathType Leaf)){$pak=@(Get-ChildItem -LiteralPath $dest -Filter *.pak -File -ErrorAction SilentlyContinue|Select-Object -First 1).FullName}
    if([bool]$meta.OriginalEnabled){
      Remove-PMMPendingRemoval ([string]$meta.Name)
      if(-not[string]::IsNullOrWhiteSpace($gameMods) -and (Test-Path -LiteralPath $pak -PathType Leaf)){
        $gameDest=Join-Path $gameMods ([string]$meta.Name)
        if(Test-Path -LiteralPath $gameDest -PathType Leaf){
          $existing=(Get-Sha256 $gameDest).ToLowerInvariant()
          if($existing -ne ([string]$meta.Hash).ToLowerInvariant()){throw ((Get-PMMText "Restore will not overwrite '{0}' because an unrecognized PAK already exists in ~mods." "Restore no sobrescribira '{0}' porque ya existe en ~mods un PAK no reconocido.") -f [string]$meta.Name)}
        }else{Copy-Item -LiteralPath $pak -Destination $gameDest -Force}
      }
    }else{Add-PMMPendingRemoval ([string]$meta.Name) ([string]$meta.Hash)}
  }

  # Restore source priority as closely as possible. Old backups without the V2
  # priority field fall back to deterministic alphabetical placement.
  if($restoredPriority.Count -gt 0){
    $current=@(Get-PMMModPriorityOrder)
    $ranked=[System.Collections.Generic.List[object]]::new();$fallback=1000000
    foreach($name in $current){
      $rank=$fallback
      if($restoredPriority.ContainsKey([string]$name)){$rank=[int]$restoredPriority[[string]$name]}else{$fallback++}
      $ranked.Add([pscustomobject]@{Name=[string]$name;Rank=$rank})
    }
    Write-PMMModPriorityOrder @($ranked.ToArray()|Sort-Object Rank,Name|ForEach-Object{[string]$_.Name})
  }

  Clear-PMMLibraryHashCache;Clear-PakEntryCache;Clear-PMMAnalysisState;[void](Get-PMMModPriorityOrder)
  Write-PMMLog ('Fix Lab restored original sources to library/game; deployed compatibility merge preserved: '+$CaseId)
  return [pscustomobject]@{CaseId=$CaseId;Restored=@($backupRows).Count;GameMods=$gameMods}
}

function script:Get-PMMFixLabCandidateBuildState {
  param($Candidate,[string]$VariantId)
  if(-not $Candidate){
    return [pscustomobject]@{Ready=$false;Mode='';Reason=(Get-PMMText 'Select a repairable mod case.' 'Selecciona un caso reparable.')}
  }
  $recipe=Get-PMMFixLabRecipe ([string]$Candidate.RecipeId)
  if(-not $recipe){
    return [pscustomobject]@{Ready=$false;Mode='';Reason='Recipe metadata is unavailable.'}
  }
  if([string]::IsNullOrWhiteSpace($VariantId)){
    return [pscustomobject]@{Ready=$false;Mode='';Reason=(Get-PMMText 'Choose an output variant.' 'Elige una variante de salida.')}
  }

  $requiresCurrent=$false
  if(($recipe.PSObject.Properties.Name -contains 'referencePolicy') -and $null -ne $recipe.referencePolicy){
    if($recipe.referencePolicy.PSObject.Properties.Name -contains 'currentRequired'){$requiresCurrent=[bool]$recipe.referencePolicy.currentRequired}
  }
  if($requiresCurrent){
    $gr=Get-PMMGameReferenceState
    if([string]$gr.Status -ne 'Current'){
      return [pscustomobject]@{Ready=$false;Mode='';Reason=(Get-PMMText 'Build or refresh the Current Game Reference first.' 'Crea o actualiza primero la Game Reference actual.')}
    }
  }

  $implementationStatus=''
  if(($recipe.PSObject.Properties.Name -contains 'implementation') -and $null -ne $recipe.implementation){
    if($recipe.implementation.PSObject.Properties.Name -contains 'status'){$implementationStatus=[string]$recipe.implementation.status}
  }
  if($implementationStatus -eq 'ready'){
    return [pscustomobject]@{Ready=$true;Mode='native';Reason=(Get-PMMText 'Ready to reconstruct the selected output.' 'Listo para reconstruir la salida seleccionada.')}
  }
  if(Test-PMMFixLabKnownOutputFixtureAvailable $recipe $VariantId){
    return [pscustomobject]@{Ready=$true;Mode='fixture';Reason=(Get-PMMText 'Runtime-proven workflow fixture is available for this output.' 'La fixture de flujo probada en runtime esta disponible para esta salida.')}
  }
  if([string]$recipe.id -eq 'fixlab-case-001-gawr-gura-v5'){
    return [pscustomobject]@{Ready=$false;Mode='internal-provider-missing';Reason=(Get-PMMText 'The Case 001 internal Workshop provider is unavailable or invalid. Repair will not ask the user to locate developer files.' 'El proveedor interno de Workshop para el Caso 001 no esta disponible o no es valido. Repair no pedira al usuario localizar archivos de desarrollo.')}
  }
  return [pscustomobject]@{Ready=$false;Mode='';Reason=(Get-PMMText 'Recipe recognized, but the reconstruction executor is still port-pending.' 'Receta reconocida, pero el ejecutor de reconstruccion sigue pendiente.')}
}

# Override the earlier build state so a runtime-proven developer fixture can
# exercise the full workflow without pretending that the reconstruction port is done.
function script:Get-PMMFixLabBuildState($Job) {
  if(-not$Job){return [pscustomobject]@{Ready=$false;Mode='';Reason=(Get-PMMText 'Create or open a Fix Lab job.' 'Crea o abre un trabajo de Fix Lab.')}}
  if(-not$Job.Analysis -or [string]$Job.Analysis.Status -eq 'NotAnalyzed'){return [pscustomobject]@{Ready=$false;Mode='';Reason=(Get-PMMText 'Run Repair Analysis first.' 'Ejecuta primero Analisis de reparacion.')}}
  if([string]::IsNullOrWhiteSpace([string]$Job.SelectedRecipeId)){return [pscustomobject]@{Ready=$false;Mode='';Reason=(Get-PMMText 'No exact repair recipe is selected.' 'No hay una receta exacta seleccionada.')}}
  $recipe=Get-PMMFixLabRecipe ([string]$Job.SelectedRecipeId)
  if(-not$recipe){return [pscustomobject]@{Ready=$false;Mode='';Reason='Recipe metadata is unavailable.'}}
  $match=@($Job.Analysis.RecipeMatches|Where-Object{[string]$_.RecipeId -ieq [string]$Job.SelectedRecipeId}|Select-Object -First 1)[0]
  if(-not$match -or -not[bool]$match.Exact){return [pscustomobject]@{Ready=$false;Mode='';Reason=(Get-PMMText 'Exact source identity is required before automatic repair.' 'Se requiere identidad exacta de la fuente antes de reparar automaticamente.')}}
  if(($match.PSObject.Properties.Name -contains 'BuildProviderPresent') -and -not[bool]$match.BuildProviderPresent){return [pscustomobject]@{Ready=$false;Mode='';Reason=(Get-PMMText 'The recognized repair case is missing an accepted build provider.' 'Al caso reconocido le falta un proveedor de build aceptado.')}}
  $candidate=[pscustomobject]@{RecipeId=[string]$Job.SelectedRecipeId}
  return (Get-PMMFixLabCandidateBuildState $candidate ([string]$Job.SelectedVariantId))
}

# Override the earlier build function. Native mode keeps the original executor
# contract; fixture mode is explicitly developer-only and hash-validated.
function script:Invoke-PMMFixLabBuild([string]$JobId) {
  $job=Get-PMMFixLabJob $JobId
  if(-not$job){throw 'Fix Lab job not found.'}
  $state=Get-PMMFixLabBuildState $job
  if(-not$state.Ready){throw [string]$state.Reason}
  $recipe=Get-PMMFixLabRecipe ([string]$job.SelectedRecipeId)
  $job.Build.Status='Building';$job.Build.RecipeId=[string]$recipe.id;$job.Build.VariantId=[string]$job.SelectedVariantId
  Save-PMMFixLabJob $job|Out-Null
  try{
    if([string]$state.Mode -eq 'fixture'){
      $result=Invoke-PMMFixLabKnownOutputFixtureBuild (Get-PMMFixLabJob $JobId) $recipe ([string]$job.SelectedVariantId)
    }else{
      $impl=$recipe.implementation
      if([string]$impl.mode -ne 'powershell-script'){throw 'Unsupported Fix Lab executor mode.'}
      $script=Join-Path $Script:Root ([string]$impl.script).Replace('/',[IO.Path]::DirectorySeparatorChar)
      if(-not(Test-Path -LiteralPath $script -PathType Leaf)){throw ('Fix Lab executor script is missing: '+$script)}
      . $script
      $fn=[string]$impl.function
      if(-not(Get-Command $fn -ErrorAction SilentlyContinue)){throw ('Fix Lab executor function is missing: '+$fn)}
      $result=& $fn -Job (Get-PMMFixLabJob $JobId) -Recipe $recipe -VariantId ([string]$job.SelectedVariantId)
    }
    if(-not$result -or [string]::IsNullOrWhiteSpace([string]$result.OutputPath)){throw 'Fix Lab recipe returned no output PAK.'}
    $out=[string]$result.OutputPath
    if(-not(Test-Path -LiteralPath $out -PathType Leaf)){throw ('Fix Lab output was not created: '+$out)}
    if(-not(Test-Pak $out)){throw 'Fix Lab output PAK failed the repak verification check.'}
    Assert-PakAssetFamiliesComplete $out
    $validation=if($result.PSObject.Properties.Name -contains 'Validation'){[string]$result.Validation}else{'Static PASS; runtime test required'}
    $job=Get-PMMFixLabJob $JobId
    $job.Build=[pscustomobject]@{Status='Built';OutputPath=$out;OutputSha256=(Get-Sha256 $out);RecipeId=[string]$recipe.id;VariantId=[string]$job.SelectedVariantId;Validation=$validation;BuiltUtc=[DateTime]::UtcNow.ToString('o')}
    Save-PMMFixLabJob $job|Out-Null
    Publish-PMMFixLabProgress 96 100 (Get-PMMText 'Registering the built output in Fix Lab...' 'Registrando la salida construida en Fix Lab...')
    $builtRecord=Register-PMMFixLabBuiltOutput (Get-PMMFixLabJob $JobId) $out $validation
    # Built/ is the canonical repair output library. Job/Output is only staging.
    $job=Get-PMMFixLabJob $JobId
    $job.Build.OutputPath=[string]$builtRecord.Path
    $job.Build.OutputSha256=[string]$builtRecord.Hash
    Save-PMMFixLabJob $job|Out-Null
    return (Get-PMMFixLabJob $JobId)
  }catch{
    $job=Get-PMMFixLabJob $JobId
    $job.Build.Status='Failed';$job.Build.Validation=$_.Exception.Message
    Save-PMMFixLabJob $job|Out-Null
    throw
  }
}

# =============================================================================
# PMM 1.3 native recipe-engine overrides
# =============================================================================
# These definitions intentionally supersede the temporary fixture-bridge build
# functions above. Fix Lab now builds from the user's exact source PAK + Current
# Game Reference + a small CKL recipe. Golden repaired PAKs are never required.

function script:Publish-PMMFixLabProgress([int]$Current,[int]$Total,[string]$Message,[switch]$Indeterminate) {
  # The UI process does not own heavy Fix Lab work. When this service runs in
  # OperationWorker.ps1, that worker exposes Set-PMMFixLabProgress and writes
  # small atomic JSON progress samples for WPF to poll.
  $cmd=Get-Command Set-PMMFixLabProgress -ErrorAction SilentlyContinue
  if($cmd){
    try{Set-PMMFixLabProgress -Current $Current -Total $Total -Message $Message -Indeterminate:$Indeterminate}catch{}
  }
}

function script:Get-PMMFixLabVariantExecutorConfig($Recipe,[string]$VariantId) {
  if(-not$Recipe -or [string]::IsNullOrWhiteSpace($VariantId)){return $null}
  if(-not($Recipe.PSObject.Properties.Name -contains 'implementation') -or $null -eq $Recipe.implementation){return $null}
  $impl=$Recipe.implementation
  if(-not($impl.PSObject.Properties.Name -contains 'variantExecutors') -or $null -eq $impl.variantExecutors){return $null}
  $prop=@($impl.variantExecutors.PSObject.Properties|Where-Object{$_.Name -ieq $VariantId}|Select-Object -First 1)[0]
  if(-not$prop){return $null}
  return $prop.Value
}

function script:Get-PMMFixLabRecipeEnginePath($Recipe) {
  if(-not$Recipe -or -not($Recipe.PSObject.Properties.Name -contains 'implementation')){return ''}
  $impl=$Recipe.implementation
  if(-not$impl -or -not($impl.PSObject.Properties.Name -contains 'engine')){return ''}
  $rel=[string]$impl.engine
  if([string]::IsNullOrWhiteSpace($rel)){return ''}
  return (Join-Path $Script:Root ($rel.Replace('/',[IO.Path]::DirectorySeparatorChar)))
}

function script:Get-PMMFixLabAcceptedPakSource($Job,$Recipe) {
  if(-not$Job -or -not$Recipe){return $null}
  $accepted=[System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
  if(($Recipe.PSObject.Properties.Name -contains 'sourcePolicy') -and $Recipe.sourcePolicy -and ($Recipe.sourcePolicy.PSObject.Properties.Name -contains 'buildProvider')){
    foreach($sig in @($Recipe.sourcePolicy.buildProvider.acceptedSignatures)){
      if([string]$sig.kind -ieq 'pak-sha256' -and -not[string]::IsNullOrWhiteSpace([string]$sig.sha256)){[void]$accepted.Add(([string]$sig.sha256).ToLowerInvariant())}
    }
  }
  if($accepted.Count -eq 0 -and ($Recipe.PSObject.Properties.Name -contains 'match')){
    foreach($sig in @($Recipe.match.signatures)){
      if([string]$sig.kind -ieq 'pak-sha256' -and -not[string]::IsNullOrWhiteSpace([string]$sig.sha256)){[void]$accepted.Add(([string]$sig.sha256).ToLowerInvariant())}
    }
  }
  foreach($src in @($Job.Primary)+@($Job.Related)){
    if(-not$src){continue}
    if([string]$src.Extension -ine '.pak'){continue}
    $hash=([string]$src.Sha256).ToLowerInvariant()
    if($accepted.Count -gt 0 -and -not$accepted.Contains($hash)){continue}
    $path=Get-PMMFixLabSourceSnapshotPath $src
    if(Test-Path -LiteralPath $path -PathType Leaf){return [pscustomobject]@{Source=$src;Path=$path;Sha256=$hash}}
  }
  return $null
}

function script:Invoke-PMMFixLabNativeRecipeEngineBuild($Job,$Recipe,[string]$VariantId) {
  Publish-PMMFixLabProgress 5 100 (Get-PMMText 'Validating recipe, engine and exact source PAK...' 'Validando receta, motor y PAK fuente exacto...')
  $cfg=Get-PMMFixLabVariantExecutorConfig $Recipe $VariantId
  if(-not$cfg){throw (Get-PMMText 'The selected output does not have a native recipe-engine executor yet.' 'La salida seleccionada aun no tiene un ejecutor nativo del motor de recetas.')}
  $engine=Get-PMMFixLabRecipeEnginePath $Recipe
  if([string]::IsNullOrWhiteSpace($engine) -or -not(Test-Path -LiteralPath $engine -PathType Leaf)){throw ('PMM Fix Lab recipe engine is missing: '+$engine)}
  $recipePath=Join-Path $Script:Root (([string]$cfg.recipe).Replace('/',[IO.Path]::DirectorySeparatorChar))
  if(-not(Test-Path -LiteralPath $recipePath -PathType Leaf)){throw ('Fix Lab native recipe is missing: '+$recipePath)}
  $provider=Get-PMMFixLabAcceptedPakSource $Job $Recipe
  if(-not$provider){throw (Get-PMMText 'An exact supported source PAK is required for this recipe. Re-import the recognized legacy PAK if necessary.' 'Se necesita un PAK fuente exacto y compatible para esta receta. Vuelve a importar el PAK antiguo reconocido si es necesario.')}
  $gr=Get-PMMGameReferenceState
  if([string]$gr.Status -ne 'Current'){throw (Get-PMMText 'Current Game Reference is required.' 'Se requiere la Game Reference actual.')}
  $gameRefRoot=Get-PMMGameReferenceCurrentRoot
  if(-not(Test-Path -LiteralPath $gameRefRoot -PathType Container)){throw 'Current Game Reference folder is missing.'}

  # Let the recipe declare exact current families it needs. Game Reference can
  # extend itself on demand instead of forcing every possible Vanilla asset into
  # the initial reference build. Added families stay cached locally.
  if(Get-Command Ensure-PMMGameReferenceFamilies -ErrorAction SilentlyContinue){
    Publish-PMMFixLabProgress 12 100 (Get-PMMText 'Reading the recipe requirements...' 'Leyendo los requisitos de la receta...')
    $reqText=@(& $engine 'requirements' '--recipe' $recipePath 2>&1|ForEach-Object{[string]$_})
    if($LASTEXITCODE -ne 0){throw ('PMMFixLab.exe could not read recipe requirements. '+($reqText -join ' '))}
    try{$req=($reqText -join "`n")|ConvertFrom-Json}catch{throw ('PMMFixLab requirements JSON is invalid: '+$_.Exception.Message)}
    $families=@($req.referenceFamilies|Where-Object{$_})
    if($families.Count -gt 0){
      Publish-PMMFixLabProgress 18 100 (Get-PMMText 'Ensuring the required current Game Reference families...' 'Comprobando las familias actuales necesarias de Game Reference...')
      [void](Ensure-PMMGameReferenceFamilies -Assets $families -Reason ('FixLab '+[string]$Recipe.id+' / '+$VariantId))}
  }

  $jobRoot=Get-PMMFixLabJobPath ([string]$Job.JobId)
  $workRoot=Join-Path (Join-Path $jobRoot 'Work\RecipeEngine') $VariantId
  $sourceRoot=Join-Path $workRoot 'Source'
  $outRoot=Join-Path $jobRoot 'Output'
  $reportRoot=Join-Path $jobRoot 'Reports'
  New-Item -ItemType Directory -Force -Path $workRoot,$outRoot,$reportRoot|Out-Null
  Assert-PMMFixLabNotCancelled
  Publish-PMMFixLabProgress 28 100 (Get-PMMText 'Expanding the legacy source into the job Workshop...' 'Extrayendo la fuente antigua al Workshop del trabajo...')
  # Workshop is ephemeral construction state. The user's source snapshot remains
  # untouched; repak expands it into this job-local source tree.
  Expand-Pak ([string]$provider.Path) $sourceRoot
  Assert-PMMFixLabNotCancelled

  $outName=[string]$cfg.output
  if([string]::IsNullOrWhiteSpace($outName)){$outName=('PMMFixLab_'+$VariantId+'_P.pak')}
  if([IO.Path]::GetFileName($outName) -ne $outName){throw 'Unsafe Fix Lab recipe output filename.'}
  # Fix Lab repairs override same-path cooked game assets. Unreal patch PAKs
  # need the _P.pak suffix to receive patch mount priority over Pal-Windows.pak.
  # A byte-correct repair with a plain .pak filename can therefore appear broken
  # at runtime because the vanilla asset provider wins the mount order.
  if(-not$outName.EndsWith('_P.pak',[StringComparison]::OrdinalIgnoreCase)){
    throw ('Fix Lab repair output must end with _P.pak for Unreal patch priority: '+$outName)
  }
  $output=Join-Path $outRoot $outName
  $report=Join-Path $reportRoot ('recipe-engine_'+$VariantId+'.json')
  Remove-Item -LiteralPath $output,$report -Force -ErrorAction SilentlyContinue

  Publish-PMMFixLabProgress 42 100 (Get-PMMText 'Running the native recipe engine...' 'Ejecutando el motor nativo de recetas...') -Indeterminate
  Write-PMMLog ('Fix Lab native recipe START: '+[string]$Recipe.id+' / '+$VariantId+' | source='+[IO.Path]::GetFileName([string]$provider.Path))
  $nativeOutput=@(& $engine 'build' '--recipe' $recipePath '--source-root' $sourceRoot '--game-reference' $gameRefRoot '--output' $output '--report' $report 2>&1|ForEach-Object{[string]$_})
  $exit=$LASTEXITCODE
  if($exit -ne 0){throw ('PMMFixLab.exe failed (exit '+$exit+'). '+($nativeOutput -join ' '))}
  if(-not(Test-Path -LiteralPath $output -PathType Leaf)){throw 'PMMFixLab.exe completed without creating an output PAK.'}
  if(-not(Test-Path -LiteralPath $report -PathType Leaf)){throw 'PMMFixLab.exe completed without creating its build report.'}
  Assert-PMMFixLabNotCancelled

  Publish-PMMFixLabProgress 78 100 (Get-PMMText 'Reading and validating the native build report...' 'Leyendo y validando el informe de build nativo...')
  $buildReport=$null
  try{$buildReport=Get-Content -LiteralPath $report -Raw|ConvertFrom-Json}catch{throw ('Fix Lab recipe-engine report is invalid JSON: '+$_.Exception.Message)}
  if(-not[bool]$buildReport.validation.readback -or -not[bool]$buildReport.validation.byteExact){throw 'Fix Lab recipe-engine readback validation did not pass.'}
  Publish-PMMFixLabProgress 84 100 (Get-PMMText 'Hashing and checking the reconstructed PAK...' 'Calculando hash y comprobando el PAK reconstruido...')
  $hash=Get-Sha256 $output
  $known=@($Recipe.variants|Where-Object{[string]$_.id -ieq $VariantId}|Select-Object -First 1)[0]
  $knownHash=if($known -and ($known.PSObject.Properties.Name -contains 'knownOutputSha256')){([string]$known.knownOutputSha256).ToLowerInvariant()}else{''}
  $hashNote=if($knownHash -and $hash.ToLowerInvariant() -eq $knownHash){' Known research output SHA-256 reproduced exactly.'}elseif($knownHash){' Output SHA-256 differs from the historical research artifact; this is not automatically a failure because current game/reference inputs may differ.'}else{''}
  $validation=if($cfg.PSObject.Properties.Name -contains 'validation'){[string]$cfg.validation}else{'Native recipe-engine readback PASS; runtime validation required.'}
  Write-PMMLog ('Fix Lab native recipe PASS: '+[IO.Path]::GetFileName($output)+' | sha256='+$hash)
  return [pscustomobject]@{OutputPath=$output;Mode='native-recipe-engine';Validation=($validation+$hashNote);ReportPath=$report;EngineOutput=($nativeOutput -join "`n")}
}

# Native recipe readiness. The old GawrGura_v7.zip fixture bridge is no longer
# part of the product path and is intentionally ignored even if present.
function script:Get-PMMFixLabCandidateBuildState {
  param($Candidate,[string]$VariantId)
  if(-not$Candidate){return [pscustomobject]@{Ready=$false;Mode='';Reason=(Get-PMMText 'Select a repairable mod case.' 'Selecciona un caso reparable.')}}
  $recipe=Get-PMMFixLabRecipe ([string]$Candidate.RecipeId)
  if(-not$recipe){return [pscustomobject]@{Ready=$false;Mode='';Reason='Recipe metadata is unavailable.'}}
  if([string]::IsNullOrWhiteSpace($VariantId)){return [pscustomobject]@{Ready=$false;Mode='';Reason=(Get-PMMText 'Choose an output variant.' 'Elige una variante de salida.')}}
  $requiresCurrent=$false
  if(($recipe.PSObject.Properties.Name -contains 'referencePolicy') -and $recipe.referencePolicy -and ($recipe.referencePolicy.PSObject.Properties.Name -contains 'currentRequired')){$requiresCurrent=[bool]$recipe.referencePolicy.currentRequired}
  if($requiresCurrent){$gr=Get-PMMGameReferenceState;if([string]$gr.Status -ne 'Current'){return [pscustomobject]@{Ready=$false;Mode='';Reason=(Get-PMMText 'Build or refresh the Current Game Reference first.' 'Crea o actualiza primero la Game Reference actual.')}}}
  $cfg=Get-PMMFixLabVariantExecutorConfig $recipe $VariantId
  if($cfg){
    $engine=Get-PMMFixLabRecipeEnginePath $recipe
    $recipePath=Join-Path $Script:Root (([string]$cfg.recipe).Replace('/',[IO.Path]::DirectorySeparatorChar))
    if(-not(Test-Path -LiteralPath $engine -PathType Leaf)){return [pscustomobject]@{Ready=$false;Mode='native-recipe-engine-missing';Reason=(Get-PMMText 'The native Fix Lab recipe engine is missing from this build.' 'Falta el motor nativo de recetas de Fix Lab en esta build.')}}
    if(-not(Test-Path -LiteralPath $recipePath -PathType Leaf)){return [pscustomobject]@{Ready=$false;Mode='native-recipe-missing';Reason=(Get-PMMText 'The native recipe file for this output is missing.' 'Falta el archivo de receta nativa para esta salida.')}}
    return [pscustomobject]@{Ready=$true;Mode='native-recipe-engine';Reason=(Get-PMMText 'Ready: local source PAK + Current Game Reference + native recipe.' 'Listo: PAK fuente local + Game Reference actual + receta nativa.')}
  }
  return [pscustomobject]@{Ready=$false;Mode='variant-port-pending';Reason=(Get-PMMText 'This output is documented, but its remaining SkeletalMesh/material primitives have not been ported to the native recipe engine yet.' 'Esta salida esta documentada, pero sus primitivas restantes de SkeletalMesh/material aun no se han portado al motor nativo de recetas.')}
}

function script:Invoke-PMMFixLabBuild([string]$JobId) {
  Publish-PMMFixLabProgress 2 100 (Get-PMMText 'Opening the Fix Lab job...' 'Abriendo el trabajo de Fix Lab...')
  $job=Get-PMMFixLabJob $JobId
  if(-not$job){throw 'Fix Lab job not found.'}
  $state=Get-PMMFixLabBuildState $job
  if(-not$state.Ready){throw [string]$state.Reason}
  $recipe=Get-PMMFixLabRecipe ([string]$job.SelectedRecipeId)
  $job.Build.Status='Building';$job.Build.RecipeId=[string]$recipe.id;$job.Build.VariantId=[string]$job.SelectedVariantId
  Save-PMMFixLabJob $job|Out-Null
  try{
    if([string]$state.Mode -ne 'native-recipe-engine'){throw ('Unsupported Fix Lab build mode: '+[string]$state.Mode)}
    $result=Invoke-PMMFixLabNativeRecipeEngineBuild (Get-PMMFixLabJob $JobId) $recipe ([string]$job.SelectedVariantId)
    if(-not$result -or [string]::IsNullOrWhiteSpace([string]$result.OutputPath)){throw 'Fix Lab recipe returned no output PAK.'}
    $out=[string]$result.OutputPath
    if(-not(Test-Path -LiteralPath $out -PathType Leaf)){throw ('Fix Lab output was not created: '+$out)}
    Publish-PMMFixLabProgress 90 100 (Get-PMMText 'Running independent PAK readback and family validation...' 'Ejecutando readback independiente y validacion de familias...')
    if(-not(Test-Pak $out)){throw 'Fix Lab output PAK failed the repak verification check.'}
    Assert-PakAssetFamiliesComplete $out
    $validation=if($result.PSObject.Properties.Name -contains 'Validation'){[string]$result.Validation}else{'Static PASS; runtime test required'}
    $job=Get-PMMFixLabJob $JobId
    $job.Build=[pscustomobject]@{Status='Built';OutputPath=$out;OutputSha256=(Get-Sha256 $out);RecipeId=[string]$recipe.id;VariantId=[string]$job.SelectedVariantId;Validation=$validation;BuiltUtc=[DateTime]::UtcNow.ToString('o');ReportPath=[string]$result.ReportPath;EngineMode='native-recipe-engine'}
    Save-PMMFixLabJob $job|Out-Null
    Publish-PMMFixLabProgress 96 100 (Get-PMMText 'Registering the built output in Fix Lab...' 'Registrando la salida construida en Fix Lab...')
    $builtRecord=Register-PMMFixLabBuiltOutput (Get-PMMFixLabJob $JobId) $out $validation
    $job=Get-PMMFixLabJob $JobId;$job.Build.OutputPath=[string]$builtRecord.Path;$job.Build.OutputSha256=[string]$builtRecord.Hash;Save-PMMFixLabJob $job|Out-Null
    Publish-PMMFixLabProgress 100 100 (Get-PMMText 'Fix Lab repair build complete.' 'Build de reparacion Fix Lab terminado.')
    return (Get-PMMFixLabJob $JobId)
  }catch{
    $job=Get-PMMFixLabJob $JobId;$job.Build.Status='Failed';$job.Build.Validation=$_.Exception.Message;Save-PMMFixLabJob $job|Out-Null;throw
  }
}
