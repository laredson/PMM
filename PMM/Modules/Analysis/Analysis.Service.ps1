function Get-PMMAnalysisSnapshot($Options) {
  $active=@(Get-LibraryMods);$disabled=@(Get-PMMDisabledMods)
  $mods=@(foreach($mod in @($active)+@($disabled)){[pscustomobject]@{Name=$mod.Name;Path=$mod.Path;Hash=(Get-Sha256 $mod.Path);Enabled=[bool]$mod.Enabled;Priority=[int]$mod.Priority;Size=[int64]$mod.Size}})
  $patch=$null
  if($Options.IncludePatch){$patch=Get-PMMSelectedManagedPatch $active}
  $selected=if($patch){[pscustomobject]@{Name=$patch.Name;Path=$patch.Path;Hash=(Get-Sha256 $patch.Path);Priority=2147483647;Enabled=$true;Size=(Get-Item -LiteralPath $patch.Path).Length}}else{$null}
  $gameMods=Get-GameModsPath;$deployed=@()
  if($gameMods -and (Test-Path -LiteralPath $gameMods)){
    $deployed=@(Get-ChildItem -LiteralPath $gameMods -Recurse -File|Where-Object{$_.Extension -in @('.pak','.utoc','.ucas','.dll','.lua')}|ForEach-Object{[ordered]@{Name=$_.Name;RelativePath=$_.FullName.Substring($gameMods.Length).TrimStart('\');Hash=(Get-Sha256 $_.FullName);Size=$_.Length}})
  }
  $identity=Get-PMMGameReferenceQuickIdentity
  $mapping=Get-PMMMappingsPath;if(Test-Path -LiteralPath $mapping -PathType Leaf){$identity.MappingsSha256=Get-Sha256 $mapping}
  $gameRoot=[string](Get-PMMConfig).GamePath
  $steamBuild='';$executableVersion=''
  if($gameRoot -and (Test-Path -LiteralPath $gameRoot)){
    $manifest=Join-Path (Split-Path (Split-Path $gameRoot -Parent) -Parent) 'appmanifest_1623730.acf'
    if(Test-Path -LiteralPath $manifest){$raw=[IO.File]::ReadAllText($manifest);if($raw -match '"buildid"\s+"(\d+)"'){$steamBuild=$matches[1]}}
    $exe=Join-Path $gameRoot 'Pal/Binaries/Win64/Palworld-Win64-Shipping.exe'
    if(Test-Path -LiteralPath $exe){$executableVersion=(Get-Item -LiteralPath $exe).VersionInfo.FileVersion}
  }
  $identity|Add-Member -NotePropertyName SteamBuildId -NotePropertyValue $steamBuild
  $identity|Add-Member -NotePropertyName ExecutableVersion -NotePropertyValue $executableVersion
  $identity|Add-Member -NotePropertyName ArchiveIdentityCoverage -NotePropertyValue 'Primary game archive metadata; extracted resource families are hashed individually. Whole game archive hash is not computed.'
  $identity|Add-Member -NotePropertyName Archives -NotePropertyValue @(Get-VanillaPakFiles|ForEach-Object{[ordered]@{Name=$_.Name;Bytes=$_.Length;LastWriteUtc=$_.LastWriteTimeUtc.ToString('o')}})
  $tools=@(foreach($path in @((Get-PMMAssetReaderPath),(Get-PMMCorePath),(Join-Path $Script:Root 'Engine/repak.exe'))){if(Test-Path -LiteralPath $path){[ordered]@{Name=[IO.Path]::GetFileName($path);Hash=(Get-Sha256 $path)}}})
  $reference=Get-PMMGameReferenceState
  $snapshot=[ordered]@{Schema='PMM_ANALYSIS_SNAPSHOT_V1';Game=$identity;ReferenceStatus=$reference.Status;MappingsSha256=$identity.MappingsSha256;RulesSha256=(Get-PMMProductionRecipeLibrarySha256);Tools=$tools;Library=$mods;Active=@($mods|Where-Object{$_.Enabled});Patch=$selected;Deployed=$deployed;SelectedPatchName=(Get-PMMSelectedPatchName);Options=$Options;MountPriorityVerified=$false}
  $snapshot['Fingerprint']=Get-PMMAnalysisHash $snapshot
  return [pscustomobject]$snapshot
}
function ConvertTo-PMMUnrealName($Value) {
  for($i=0;$i -lt 5;$i++){
    if($null -eq $Value){return ''}
    if($Value -is [string] -or $Value -is [ValueType]){return [string]$Value}
    $next=Get-PMMAnalysisValue $Value 'Value' $null
    if($null -eq $next){return ''};$Value=$next
  }
  return ''
}
function ConvertTo-PMMResourceEvidence($Document,[string]$LogicalPath,[string]$Provider,[string]$Hash,[int]$Priority=0) {
  $definitions=[Collections.Generic.List[string]]::new();$references=[Collections.Generic.List[object]]::new();$rows=[Collections.Generic.List[string]]::new()
  $exports=@(Get-PMMAnalysisValue $Document Exports @());$imports=@(Get-PMMAnalysisValue $Document Imports @());$opaque=0
  foreach($export in $exports){
    $type=[string](Get-PMMAnalysisValue $export '$type' '')
    if($type -match 'RawExport'){$opaque++}
    $name=ConvertTo-PMMUnrealName (Get-PMMAnalysisValue $export ObjectName '')
    if($name){$definitions.Add($name)}
    $table=Get-PMMAnalysisValue $export Table $null
    foreach($row in @(Get-PMMAnalysisValue $table Data @())){$rowName=ConvertTo-PMMUnrealName (Get-PMMAnalysisValue $row Name '');if($rowName){$rows.Add($rowName)}}
  }
  function Resolve-ImportPackage($Index) {
    $value=ConvertTo-PMMUnrealName $Index;$n=0
    if(-not[int]::TryParse($value,[ref]$n)){return $null}
    $seen=@{};$member=''
    while($n -lt 0 -and (-$n-1) -lt $imports.Count){
      if($seen.ContainsKey($n)){return $null};$seen[$n]=$true
      $item=$imports[-$n-1]
      $name=ConvertTo-PMMUnrealName (Get-PMMAnalysisValue $item ObjectName '')
      $class=ConvertTo-PMMUnrealName (Get-PMMAnalysisValue $item ClassName '')
      if($class -eq 'Package' -and $name -like '/Game/*'){return @{Target=(ConvertTo-PMMResourcePath $name);Member=$member}}
      if(-not$member){$member=$name}
      if(-not[int]::TryParse((ConvertTo-PMMUnrealName (Get-PMMAnalysisValue $item OuterIndex 0)),[ref]$n)){return $null}
    }
    return $null
  }
  for($importIndex=0;$importIndex -lt $imports.Count;$importIndex++){
    $import=$imports[$importIndex]
    $kind=ConvertTo-PMMUnrealName (Get-PMMAnalysisValue $import ClassName '')
    if($kind -in @('Class','BlueprintGeneratedClass','DataTable')){
      $resolved=Resolve-ImportPackage (-$importIndex-1)
      if($resolved){$references.Add([pscustomobject]@{Target=$resolved.Target;Kind='Class';Member=$resolved.Member;Required=$true;Source='SerializedObjectImport'})}
    }
  }
  foreach($import in $imports){
    $name=ConvertTo-PMMUnrealName (Get-PMMAnalysisValue $import ObjectName '')
    $class=ConvertTo-PMMUnrealName (Get-PMMAnalysisValue $import ClassName '')
    if($class -eq 'Package' -and $name -like '/Game/*'){
      $references.Add([pscustomobject]@{Target=(ConvertTo-PMMResourcePath $name);Kind='Package';Member='';Required=$true;Source='SerializedImport'})
    }
  }
  # Soft object references are useful leads, but may be optional or loaded dynamically.
  $queue=[Collections.Generic.Queue[object]]::new();$queue.Enqueue($Document);$count=0
  while($queue.Count -and $count -lt 200000){
    $node=$queue.Dequeue();$count++
    if($node -is [string]){
      if($node -match '^/Game/[A-Za-z0-9_/]+\.[A-Za-z0-9_]+$'){$references.Add([pscustomobject]@{Target=(ConvertTo-PMMResourcePath $node);Kind='SoftObject';Member='';Required=$false;Source='SerializedPath'})}
    }elseif($node -is [array]){foreach($child in $node){if($null -ne $child){$queue.Enqueue($child)}}}
    elseif($node -is [pscustomobject]){
      if((ConvertTo-PMMUnrealName (Get-PMMAnalysisValue $node StructType '')) -in @('DataTableRowHandle','DataTableCategoryHandle')){
        $fields=@(Get-PMMAnalysisValue $node Value @())
        $tableField=@($fields|Where-Object{(ConvertTo-PMMUnrealName (Get-PMMAnalysisValue $_ Name '')) -eq 'DataTable'})
        $rowField=@($fields|Where-Object{(ConvertTo-PMMUnrealName (Get-PMMAnalysisValue $_ Name '')) -eq 'RowName'})
        if($tableField.Count -eq 1 -and $rowField.Count -eq 1){
          $resolved=Resolve-ImportPackage (Get-PMMAnalysisValue $tableField[0] Value 0)
          $rowName=ConvertTo-PMMUnrealName (Get-PMMAnalysisValue $rowField[0] Value '')
          if($resolved -and $rowName -and $rowName -ne 'None'){$references.Add([pscustomobject]@{Target=$resolved.Target;Kind='Row';Member=$rowName;Required=$false;Source='SerializedRowHandle'})}
        }
      }
      foreach($property in $node.PSObject.Properties){if($null -ne $property.Value){$queue.Enqueue($property.Value)}}}
  }
  $status=if(-not$exports.Count){'Unsupported'}elseif($opaque -or $queue.Count){'Partial'}else{'Complete'}
  return [pscustomobject]@{LogicalPath=(ConvertTo-PMMResourcePath $LogicalPath);Provider=$Provider;Hash=$Hash;Priority=$Priority;ReaderStatus=$status;DefinitionsComplete=($exports.Count -gt 0 -and $definitions.Count -eq $exports.Count);Definitions=$definitions.ToArray();Rows=$rows.ToArray();References=@($references.ToArray()|Sort-Object Target,Kind,Member -Unique);FamilyHashes=@()}
}
function Read-PMMResourceEvidence([string]$Header,[string]$Logical,[string]$Provider,[string]$Hash,[int]$Priority) {
  try{
    $json=Get-PMMSemanticJsonCached $Header
    if((Get-Item -LiteralPath $json).Length -gt 100MB){throw 'Semantic document exceeds the bounded reader size.'}
    $doc=[IO.File]::ReadAllText($json)|ConvertFrom-Json
    $resource=ConvertTo-PMMResourceEvidence $doc $Logical $Provider $Hash $Priority
    $resource|Add-Member -NotePropertyName RowsComplete -NotePropertyValue $false
    if([IO.Path]::GetFileName($Logical) -like 'DT_*' -or @($doc.Exports|Where-Object{[string](Get-PMMAnalysisValue $_ '$type' '') -match 'DataTableExport'}).Count){
      try{
        $tablePath=Get-PMMDataTableMapCached $Header
        $table=Read-PMMJsonFile $tablePath
        if($table.kind -eq 'DataTable' -and $table.schema -eq 1){
          $resource.Rows=@($table.rows|ForEach-Object{[string]$_.id});$resource.RowsComplete=$true
        }
      }catch{}
    }
    $stem=$Header.Substring(0,$Header.Length-[IO.Path]::GetExtension($Header).Length)
    $resource.FamilyHashes=@(foreach($extension in @('.uasset','.uexp','.ubulk')){$part=$stem+$extension;if(Test-Path -LiteralPath $part){[ordered]@{Part=$extension;Sha256=(Get-Sha256 $part)}}})
    $resource.Hash=Get-PMMAnalysisHash $resource.FamilyHashes
    return $resource
  }catch{
    return [pscustomobject]@{LogicalPath=(ConvertTo-PMMResourcePath $Logical);Provider=$Provider;Hash=$Hash;Priority=$Priority;ReaderStatus=('Unreadable: '+$_.Exception.Message);Definitions=@();Rows=@();References=@();FamilyHashes=@()}
  }
}
function Invoke-PMMDeepAnalysis($Options=$null,$ProposedReplacement=$null) {
  if(-not$Options){$Options=New-PMMDeepAnalysisOptions}
  Assert-PMMDeepOptions $Options
  $snapshot=Get-PMMAnalysisSnapshot $Options
  $originalFingerprint=$snapshot.Fingerprint
  if($ProposedReplacement){
    if((Get-Sha256 $ProposedReplacement.Path) -cne $ProposedReplacement.Hash){throw 'Proposed replacement bytes changed.'}
    $snapshot.Active=@($snapshot.Active|ForEach-Object{$_|ConvertTo-Json|ConvertFrom-Json})
    $matched=@($snapshot.Active|Where-Object{$_.Hash -eq $ProposedReplacement.OriginalSha256})
    if($matched.Count -ne 1){throw 'The original update source is not uniquely active in this configuration.'}
    $matched[0].Path=$ProposedReplacement.Path;$matched[0].Hash=$ProposedReplacement.Hash;$matched[0].Size=(Get-Item -LiteralPath $ProposedReplacement.Path).Length
    $snapshot|Add-Member -NotePropertyName Scenario -NotePropertyValue 'ProposedUpdateNotApplied'
    $snapshot|Add-Member -NotePropertyName ExcludedPreviousPatch -NotePropertyValue $snapshot.Patch
    $snapshot.Patch=$null
    $snapshot.Fingerprint=Get-PMMAnalysisHash @($originalFingerprint,$ProposedReplacement)
  }
  $id='DA-'+[guid]::NewGuid().ToString('N');$root=Get-PMMAnalysisPath $id
  [void][IO.Directory]::CreateDirectory($root)
  Write-PMMJsonAtomic (Join-Path $root 'snapshot.json') $snapshot -Depth 40
  $findings=[Collections.Generic.List[object]]::new();$resources=[Collections.Generic.List[object]]::new();$updates=[Collections.Generic.List[object]]::new()
  $known=[Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
  $indexComplete=$true;$budget=[int]$Options.MaxSemanticFamilies;$parsed=0;$totalFamilies=0;$vanillaParsed=0
  if($ProposedReplacement -and $snapshot.ExcludedPreviousPatch){$findings.Add((New-PMMAnalysisFinding -Rule PATCH_REBUILD_REQUIRED -Severity Medium -Confidence High -Classification ConfigurationMismatch -Message 'The previous patch was excluded because one of its source inputs changed.' -Action 'Rebuild a coherent patch for the proposed source set before any activation.' -Evidence @($snapshot.ExcludedPreviousPatch)))}
  $providers=@($snapshot.Active);if($snapshot.Patch){$providers+=,$snapshot.Patch}
  $expected=@($providers|ForEach-Object{$_.Hash}|Sort-Object);$actual=@($snapshot.Deployed|Where-Object{[IO.Path]::GetExtension($_.Name) -eq '.pak'}|ForEach-Object{$_.Hash}|Sort-Object)
  if(($expected -join ',') -cne ($actual -join ',')){$findings.Add((New-PMMAnalysisFinding -Rule DEPLOYMENT_DIFFERS -Severity Medium -Confidence High -Classification ConfigurationMismatch -Message 'The active library and selected patch differ from the deployed files.' -Action 'Choose which configuration to investigate before attributing a game failure.'))}
  if($snapshot.ReferenceStatus -ne 'Current'){$findings.Add((New-PMMAnalysisFinding -Rule REFERENCE_NOT_CURRENT -Message 'The prepared reference is missing or stale; direct archive comparisons remain available.' -Action 'Prepare the current game reference.'))}
  $archives=@(Get-VanillaPakFiles)
  foreach($archive in $archives){
    try{foreach($entry in @(Get-PakEntriesCached $archive.FullName)){$logical=Normalize-PakLogicalPath $entry;if($logical -match '\.(uasset|umap)$'){[void]$known.Add($logical.ToLowerInvariant())}}}catch{$indexComplete=$false}
  }
  if(-not$archives.Count){$indexComplete=$false}
  $index=0;$modHeaders=[Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
  foreach($provider in $providers){
    $index++;Assert-PMMOperationNotCancelled
    if(Get-Command Set-PMMAnalyzeProgress -ErrorAction SilentlyContinue){Set-PMMAnalyzeProgress $index ([Math]::Max(1,$providers.Count)) ('Deep analysis: '+$provider.Name)}
    try{
      $entries=@(Get-PakEntriesCached $provider.Path|ForEach-Object{Normalize-PakLogicalPath $_})
      foreach($entry in $entries){if($entry -match '\.(uasset|umap)$'){[void]$known.Add($entry.ToLowerInvariant())}}
      foreach($entry in @($entries|Where-Object{$_ -match '\.(uexp|ubulk)$'})){
        $stem=Get-PakLogicalStem $entry
        if(($stem+'.uasset') -notin $entries -and ($stem+'.umap') -notin $entries){$findings.Add((New-PMMAnalysisFinding -Rule ORPHAN_SIDECAR -Mods @($provider.Name) -Resource $entry -Severity Medium -Confidence High -Classification Suspected -Message 'A sidecar is present without its header in this provider.' -Action 'Check the complete effective family; another provider may supply the header.'))}
      }
      foreach($header in @($entries|Where-Object{$_ -match '\.uasset$'})){
        $totalFamilies++;[void]$modHeaders.Add($header)
        if($parsed -ge $budget){
          $resources.Add([pscustomobject]@{LogicalPath=(ConvertTo-PMMResourcePath $header);Provider=$provider.Name;Hash=$provider.Hash;Priority=$provider.Priority;ReaderStatus='BudgetNotRead';Definitions=@();Rows=@();References=@();FamilyHashes=@()})
          continue
        }
        Assert-PMMOperationNotCancelled
        try{
          $extract=Export-PakAssetFamilyExact $provider.Path $header (Join-Path $root ('cooked/'+$provider.Hash))
          $resources.Add((Read-PMMResourceEvidence $extract.HeaderPath $header $provider.Name $provider.Hash $provider.Priority));$parsed++
        }catch{
          $resources.Add([pscustomobject]@{LogicalPath=(ConvertTo-PMMResourcePath $header);Provider=$provider.Name;Hash=$provider.Hash;Priority=$provider.Priority;ReaderStatus=('ExtractionFailed: '+$_.Exception.Message);Definitions=@();Rows=@();References=@();FamilyHashes=@()})
        }
      }
    }catch{$indexComplete=$false;$findings.Add((New-PMMAnalysisFinding -Rule CONTAINER_READ_FAILED -Mods @($provider.Name) -Severity Medium -Message 'The container could not be read completely.' -Action 'Check the container and tool support.' -Limitations @($_.Exception.Message)))}
    if($Options.CheckUpdates -and $provider -ne $snapshot.Patch){$updates.Add((Find-PMMModUpdate $provider))}
  }
  foreach($header in $modHeaders){
    if($parsed -ge $budget){break};Assert-PMMOperationNotCancelled
    try{$extract=Export-VanillaAssetFamilyExact $header (Join-Path $root 'vanilla');if($extract){$resources.Add((Read-PMMResourceEvidence $extract.HeaderPath $header Vanilla (Get-Sha256 $extract.HeaderPath) 0));$parsed++;$vanillaParsed++}}catch{}
  }
  # Inspect the prepared current reference for reverse dependencies, with explicit coverage.
  $reverseTotal=0;$cooked=Get-PMMGameReferenceCookedRoot
  if($snapshot.ReferenceStatus -eq 'Current' -and (Test-Path -LiteralPath $cooked)){
    foreach($file in @(Get-ChildItem -LiteralPath $cooked -Filter *.uasset -Recurse -File)){
      $logical=$file.FullName.Substring($cooked.Length).TrimStart('\').Replace('\','/')
      if($modHeaders.Contains($logical)){continue};$reverseTotal++
      if($parsed -ge $budget){continue};Assert-PMMOperationNotCancelled
      $resources.Add((Read-PMMResourceEvidence $file.FullName $logical Vanilla (Get-Sha256 $file.FullName) 0));$parsed++;$vanillaParsed++
    }
  }
  foreach($finding in @(Get-PMMResourceFindings $resources.ToArray() @($known) $snapshot.MountPriorityVerified $indexComplete)){$findings.Add($finding)}
  foreach($update in $updates){
    $findings.Add((New-PMMAnalysisFinding -Rule ('UPDATE_'+$update.Status) -Mods @($update.Mod) -Severity $(if($update.Status -eq 'UPDATE_AVAILABLE'){'Medium'}else{'Info'}) -Confidence $(if($update.Status -eq 'UPDATE_AVAILABLE'){'High'}else{'Indeterminate'}) -Classification $(if($update.Status -eq 'UPDATE_AVAILABLE'){'UpdateAvailable'}else{'Indeterminate'}) -Message $update.Message -Action $(if($update.Status -eq 'UPDATE_AVAILABLE'){'Review or stage the author update before attempting a repair.'}else{'Check or link the update source.'}) -Evidence @($update)))
  }
  if($ProposedReplacement -and (Get-Sha256 $ProposedReplacement.Path) -cne $ProposedReplacement.Hash){throw 'Proposed update changed during analysis; its report was not published.'}
  $fresh=Get-PMMAnalysisSnapshot $Options
  if($fresh.Fingerprint -cne $originalFingerprint){throw 'Analysis inputs changed while scanning; no current report was published. Run again.'}
  $coverage=[ordered]@{KnownResources=$known.Count;ContainerIndexComplete=$indexComplete;ModFamilies=$totalFamilies;SemanticFamilies=$parsed;CompleteFamilies=@($resources|Where-Object{$_.ReaderStatus -eq 'Complete'}).Count;CompleteDataTables=@($resources|Where-Object{Get-PMMAnalysisValue $_ RowsComplete $false}).Count;CompleteExportMaps=@($resources|Where-Object{Get-PMMAnalysisValue $_ DefinitionsComplete $false}).Count;VanillaFamiliesRead=$vanillaParsed;PreparedReverseFamilies=$reverseTotal;ReverseDependencyScope='Prepared reference only; unhydrated game resources are not semantically covered';SemanticBudget=$budget;BudgetReached=($parsed -ge $budget);RuntimeTested=$false;OtherModFormats='Only the configured Paks/~mods deployment tree is inventoried. UE4SS, external loaders and mods outside that tree require additional adapters; cooked PAK families are the semantic scope.'}
  $report=[pscustomobject]@{Schema='PMM_DEEP_REPORT_V1';Id=$id;CreatedUtc=[DateTime]::UtcNow.ToString('o');Snapshot=$snapshot;Coverage=$coverage;Resources=$resources.ToArray();Findings=@($findings.ToArray()|Sort-Object Id -Unique);Updates=$updates.ToArray();Summary=((Get-PMMText '{0} findings; {1} families inspected. Runtime cause unproven.' '{0} hallazgos; {1} familias inspeccionadas. Causa del fallo en juego sin comprobar.') -f $findings.Count,$parsed);CaseId='';Status='Complete'}
  Write-PMMJsonAtomic (Join-Path $root 'report.json') $report -Depth 60 -Schema PMM_DEEP_REPORT_V1
  Export-PMMDeepAnalysis $id|Out-Null
  if(-not$ProposedReplacement){Write-PMMJsonAtomic (Join-Path (Get-PMMAnalysisRoot) 'latest.json') @{Schema='PMM_DEEP_LATEST_V1';Id=$id}}
  foreach($finding in $report.Findings){
    Write-PMMJsonAtomic (Join-Path $root ('Findings/'+$finding.Id+'.json')) $finding -Depth 30
    $finding|Add-Member -NotePropertyName ModsText -NotePropertyValue ($finding.Mods -join ', ')
  }
  $view=[ordered]@{Id=$id;Summary=$report.Summary;Findings=@($report.Findings|Select-Object Id,Rule,Mods,ModsText,Resource,Severity,Confidence,Classification,Message,Action);CaseId='';RepairSessionId=''}
  if($Options.AutomaticSolution -and -not$ProposedReplacement){$case=New-PMMCaseFromDeepAnalysis $id;$session=New-PMMRepairSession $case.CaseId $Options;$view.CaseId=$case.CaseId;$view.RepairSessionId=$session.Id;Start-PMMRepairAgentJob $session.Id|Out-Null}
  Write-PMMJsonAtomic (Join-Path $root 'view.json') $view -Depth 20
  $report|Add-Member -NotePropertyName RepairSessionId -NotePropertyValue $view.RepairSessionId
  $report.CaseId=$view.CaseId
  return $report
}
function New-PMMCaseFromDeepAnalysis([string]$Id,[string[]]$FindingIds=@(),[string]$ExistingCaseId='') {
  $report=Read-PMMDeepAnalysis $Id
  $fresh=Get-PMMAnalysisSnapshot $report.Snapshot.Options
  if($fresh.Fingerprint -cne $report.Snapshot.Fingerprint){throw 'This report is stale. Analyze the current configuration before creating its case.'}
  $findings=@(if($FindingIds.Count){$report.Findings|Where-Object{$_.Id -in $FindingIds}}else{$report.Findings})
  if($FindingIds.Count -and $findings.Count -ne @($FindingIds|Select-Object -Unique).Count){throw 'A selected finding does not belong to this report.'}
  $key=Get-PMMAnalysisHash @($report.Snapshot.Fingerprint,@($findings|ForEach-Object{$_.Id}|Sort-Object))
  $link=Join-Path (Get-PMMAnalysisRoot) ('case-'+$key+'.json')
  $caseLock=Enter-PMMAnalysisLock ($link+'.lock')
  try{
  if(-not$ExistingCaseId -and (Test-Path -LiteralPath $link)){$ExistingCaseId=(Read-PMMJsonFile $link).CaseId}
  if($ExistingCaseId){$case=Get-PMMAIIOCase $ExistingCaseId;if(-not$case){throw 'Linked case no longer exists.'}}
  else{$case=New-PMMContextCase -Type Query -Mods @($report.Snapshot.Active) -Title 'Deep analysis / Analisis profundo' -Description 'Investigate the attached findings; preserve the intended functions. Check author updates before building repairs.'}
  $evidence=[ordered]@{Kind='DeepAnalysis';AnalysisId=$Id;Snapshot=$report.Snapshot;Findings=$findings;Coverage=$report.Coverage;ReportSha256=(Get-Sha256 (Join-Path (Get-PMMAnalysisPath $Id) 'report.json'))}
  Add-PMMCaseEvidenceRevision $case.CaseId $evidence|Out-Null
  Write-PMMJsonAtomic $link @{Schema='PMM_ANALYSIS_CASE_LINK_V1';CaseId=$case.CaseId;AnalysisId=$Id}
  return (Get-PMMAIIOCase $case.CaseId)
  }finally{$caseLock.Dispose()}
}
