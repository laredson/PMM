Set-StrictMode -Version 2
function Get-PMMUpdateRoot {
  $root=Join-PMMPath 'ModUpdates' '';[void][IO.Directory]::CreateDirectory($root)
  foreach($name in @('Downloads','Candidates','Archive')){[void][IO.Directory]::CreateDirectory((Join-Path $root $name))}
  $root
}
function Get-PMMUpdatePlanPath { Join-PMMPath 'State' 'update-plan.json' }
function Get-PMMUpdateLibraryRows {
  @(foreach($mod in @(@(Get-LibraryMods)+@(Get-PMMDisabledMods))|Sort-Object Name){[pscustomobject][ordered]@{Name=$mod.Name;Hash=$mod.Hash;Enabled=[bool]$mod.Enabled;Priority=[int]$mod.Priority}})
}
function Get-PMMUpdateFingerprintFromRows($Rows) { Get-PMMAnalysisHash @($Rows) }
function Get-PMMUpdateFingerprint { Get-PMMUpdateFingerprintFromRows @(Get-PMMUpdateLibraryRows) }
function Get-PMMPendingUpdateApplyPath { Join-PMMPath 'State' 'pending-update-apply.json' }
function Get-PMMPendingUpdateApply { $path=Get-PMMPendingUpdateApplyPath;if(Test-Path $path){try{return Read-PMMJsonFile $path -Schema PMM_PENDING_UPDATE_APPLY_V1}catch{}};$null }
function Set-PMMPendingUpdateApply([string]$PlanId,[array]$Items,[bool]$Auto) {
  $safe=@($Items|Where-Object{[string]$_.LocalSha256 -match '^[a-f0-9]{64}$' -and -not[string]::IsNullOrWhiteSpace([string]$_.CandidatePath)}|Group-Object LocalSha256|ForEach-Object{$_.Group[0]});if(-not$safe.Count){return}
  Write-PMMJsonAtomic (Get-PMMPendingUpdateApplyPath) ([ordered]@{Schema='PMM_PENDING_UPDATE_APPLY_V1';PlanId=$PlanId;Items=$safe;Auto=$Auto;Reason='GAME_RUNNING';CreatedUtc=[DateTime]::UtcNow.ToString('o')}) -Depth 20
}
function Clear-PMMPendingUpdateApply { $path=Get-PMMPendingUpdateApplyPath;if(Test-Path $path){Remove-Item $path -Force} }
function Read-PMMUpdatePlan {
  $path=Get-PMMUpdatePlanPath;if(-not(Test-Path $path)){return $null}
  $plan=Read-PMMJsonFile $path -Schema PMM_UPDATE_PLAN_V1
  $plan|Add-Member IsCurrent ([string]$plan.LibraryFingerprint -ceq (Get-PMMUpdateFingerprint)) -Force
  $plan
}
function Invoke-PMMUpdateCheck {
  $results=[Collections.Generic.List[object]]::new()
  foreach($mod in @(@(Get-LibraryMods)+@(Get-PMMDisabledMods))|Sort-Object Priority,Name){$results.Add((Find-PMMModUpdate $mod))}
  $plan=[pscustomobject][ordered]@{Schema='PMM_UPDATE_PLAN_V1';Id=('UP-'+[Guid]::NewGuid().ToString('N'));CreatedUtc=[DateTime]::UtcNow.ToString('o');LibraryFingerprint=(Get-PMMUpdateFingerprint);Results=$results.ToArray();ReadOnly=$true}
  Write-PMMJsonAtomic (Get-PMMUpdatePlanPath) $plan -Depth 30 -Schema PMM_UPDATE_PLAN_V1;$plan|Add-Member IsCurrent $true;$plan
}
function Get-PMMUpdateWorkflowRequirement {
  if(-not@(@(Get-LibraryMods)+@(Get-PMMDisabledMods)).Count){return [pscustomobject]@{Required=$false;Reason='EmptyLibrary'}}
  $plan=Read-PMMUpdatePlan;if(-not$plan -or -not$plan.IsCurrent){return [pscustomobject]@{Required=$true;Reason='NotChecked'}}
  [pscustomobject]@{Required=$false;Reason='Current'}
}
function Set-PMMNexusOriginFromUrl($Mod,[string]$Url,[string]$FileId,[string]$Variant,[string]$Version='') {
  $parsed=ConvertFrom-PMMNexusModUrl $Url;if(-not$FileId){$FileId=$parsed.FileId}
  if($FileId -notmatch '^\d+$'){throw 'Select the exact installed Nexus file.'}
  $origin=Get-PMMModOrigin $Mod;$origin.Provider='Nexus';$origin.SourceUrl=$parsed.SourceUrl;$origin.ModId=$parsed.ModId;$origin.FileId=$FileId;$origin.Variant=$Variant;$origin.Version=$Version;$origin.AssetName=$Variant
  Set-PMMModOrigin $Mod $origin
}
function Test-PMMUpdateDownloadUri([Uri]$Uri) { $Uri.Scheme -eq 'https' -and $Uri.Host -match '(^|\.)nexusmods\.com$|(^|\.)github\.com$|(^|\.)githubusercontent\.com$' }
function Receive-PMMUpdateArchive($Update,$NxmRequest=$null) {
  if($Update.Status -ne 'UPDATE_AVAILABLE'){throw 'The selected row has no update.'}
  $plan=Read-PMMUpdatePlan;if(-not$plan -or -not$plan.IsCurrent){throw 'The update plan is stale.'}
  $url=[string]$Update.Candidate.Url
  if($Update.Candidate.Provider -eq 'Nexus'){$links=@(Get-PMMNexusDownloadLinks $Update.Origin.ModId $Update.Candidate.FileId $NxmRequest);if(-not$links.Count){throw 'NEXUS_WEB_CONFIRMATION_REQUIRED'};$url=[string]$links[0].URI}
  $uri=[Uri]$url;if(-not(Test-PMMUpdateDownloadUri $uri)){throw 'The provider returned an untrusted download URL.'}
  $leaf=[IO.Path]::GetFileName([string]$Update.Candidate.AssetName);if($leaf -notmatch '\.(pak|zip|7z|rar)$'){throw 'Unsupported update archive format.'}
  $path=Join-Path (Join-Path (Get-PMMUpdateRoot) 'Downloads') (($Update.Candidate.Provider)+'-'+$Update.Candidate.FileId+'-'+$leaf);$part=$path+'.part'
  if(Test-Path $part){Remove-Item $part -Force}
  Add-Type -AssemblyName System.Net.Http;$handler=[Net.Http.HttpClientHandler]::new();$handler.AllowAutoRedirect=$false
  $http=[Net.Http.HttpClient]::new($handler);$http.Timeout=[TimeSpan]::FromMinutes(10);$response=$null;$input=$null;$output=$null;$complete=$false
  try{
    $current=$uri
    foreach($redirect in 0..5){
      $response=$http.GetAsync($current,[Net.Http.HttpCompletionOption]::ResponseHeadersRead).GetAwaiter().GetResult();$status=[int]$response.StatusCode
      if($status -ge 300 -and $status -lt 400){if($redirect -eq 5 -or -not$response.Headers.Location){throw 'The provider exceeded the redirect limit.'};$next=if($response.Headers.Location.IsAbsoluteUri){$response.Headers.Location}else{[Uri]::new($current,$response.Headers.Location)};if(-not(Test-PMMUpdateDownloadUri $next)){throw 'A redirect left an approved HTTPS host.'};$response.Dispose();$response=$null;$current=$next;continue}
      break
    }
    [void]$response.EnsureSuccessStatusCode();if(-not(Test-PMMUpdateDownloadUri $response.RequestMessage.RequestUri)){throw 'A redirect left an approved HTTPS host.'}
    $length=[long](Get-PMMAnalysisValue $response.Content.Headers 'ContentLength' 0);if($length -gt 8GB){throw 'Update exceeds 8 GiB.'}
    $drive=[IO.DriveInfo]::new([IO.Path]::GetPathRoot($path));$free=[int64]$drive.AvailableFreeSpace;if($free -lt 1GB -or ($length -and $free -lt ($length+1GB))){throw 'Not enough free space.'}
    $input=$response.Content.ReadAsStreamAsync().GetAwaiter().GetResult();$output=[IO.File]::Open($part,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
    $buffer=New-Object byte[] 1048576;$total=0L
    while(($read=$input.Read($buffer,0,$buffer.Length)) -gt 0){if(Get-Command Assert-PMMOperationNotCancelled -ErrorAction SilentlyContinue){Assert-PMMOperationNotCancelled};$total+=$read;if($total -gt 8GB){throw 'Update exceeds 8 GiB.'};if($total -gt ($free-1GB)){throw 'Not enough free space.'};$output.Write($buffer,0,$read)}
    $output.Flush($true);$complete=$true
  }finally{if($output){$output.Dispose()};if($input){$input.Dispose()};if($response){$response.Dispose()};$http.Dispose();$handler.Dispose();if(-not$complete -and (Test-Path $part)){Remove-Item $part -Force}}
  $hash=Get-Sha256 $part;if($Update.Candidate.Sha256 -and $hash -cne $Update.Candidate.Sha256){Remove-Item $part -Force;throw 'Provider checksum mismatch.'}
  if(Test-Path $path){if((Get-Sha256 $path) -cne $hash){throw 'Cached archive collision.'};Remove-Item $part}else{[IO.File]::Move($part,$path)}
  [pscustomobject]@{Path=$path;Sha256=$hash;Bytes=(Get-Item $path).Length}
}
function Assert-PMMUpdateExtractedTree([string]$Root) {
  $seen=@{};foreach($item in @(Get-ChildItem $Root -Recurse -Force)){
    $full=[IO.Path]::GetFullPath($item.FullName);if(-not(Test-PMMPathInside $full $Root)){throw 'Archive traversal was rejected.'}
    if(($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0){throw 'Archive links are not accepted.'}
    $relative=$full.Substring(([IO.Path]::GetFullPath($Root)).Length).TrimStart('\','/')
    if($relative.Contains(':') -or $seen.ContainsKey($relative.ToLowerInvariant())){throw 'Archive contains an ADS or case collision.'};$seen[$relative.ToLowerInvariant()]=$true
    if(-not$item.PSIsContainer -and $item.Extension -match '^\.(exe|dll|msi|bat|cmd|ps1|vbs|js|lnk|url)$'){throw 'Archive contains an executable.'}
  }
}
function Expand-PMMUpdateArchiveSafe([string]$ArchivePath,[string]$Destination) {
  [void][IO.Directory]::CreateDirectory($Destination);$ext=[IO.Path]::GetExtension($ArchivePath).ToLowerInvariant()
  if($ext -eq '.pak'){Copy-Item $ArchivePath (Join-Path $Destination ([IO.Path]::GetFileName($ArchivePath)))}
  elseif($ext -eq '.zip'){
    Add-Type -AssemblyName System.IO.Compression.FileSystem;$zip=[IO.Compression.ZipFile]::OpenRead($ArchivePath)
    try{
      if($zip.Entries.Count -gt 10000){throw 'Archive contains too many entries.'};$names=@{};$total=0L
      foreach($entry in $zip.Entries){
        $name=$entry.FullName.Replace('/','\');$total+=$entry.Length
        if($name.StartsWith('\') -or $name -match '^[A-Za-z]:' -or $name.Split('\') -contains '..' -or $name.Contains(':')){throw 'Archive traversal or ADS was rejected.'}
        $unixType=(($entry.ExternalAttributes -shr 16) -band 0xF000);if($unixType -eq 0xA000){throw 'Archive links are not accepted.'}
        $key=$name.ToLowerInvariant();if($names.ContainsKey($key)){throw 'Archive contains case-colliding paths.'};$names[$key]=$true
        if($entry.Name -and [IO.Path]::GetExtension($entry.Name) -match '^\.(exe|dll|msi|bat|cmd|ps1|vbs|js|lnk|url|zip|7z|rar)$'){throw 'Archive contains nested dangerous content.'}
        if($total -gt 16GB){throw 'Extracted archive exceeds 16 GiB.'}
        if($entry.Name){$target=Join-Path $Destination $name;[void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($target));$i=$entry.Open();$o=[IO.File]::Open($target,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None);try{$i.CopyTo($o);$o.Flush($true)}finally{$i.Dispose();$o.Dispose()}}
      }
    }finally{$zip.Dispose()}
  }elseif($ext -in @('.7z','.rar')){
    $seven=Get-Command 7z.exe -ErrorAction SilentlyContinue;if(-not$seven){throw '7-Zip is required to inspect 7z/RAR updates.'}
    $listing=@(& $seven.Source l -slt -- $ArchivePath);if($LASTEXITCODE -ne 0){throw '7-Zip could not inspect the update.'}
    $names=@{};$count=0;$declaredBytes=0L
    foreach($line in $listing){
      if($line -match '^(?:Symbolic|Hard) Link = .+$'){throw 'Archive links are not accepted.'}
      if($line -match '^Size = (\d+)$'){$declaredBytes+=[int64]$matches[1];if($declaredBytes -gt 16GB){throw 'Extracted archive exceeds 16 GiB.'};continue}
      if($line -notmatch '^Path = (.+)$'){continue};$name=[string]$matches[1]
      if($name -eq $ArchivePath -or $name -eq [IO.Path]::GetFileName($ArchivePath)){continue};$count++
      if($count -gt 10000 -or $name.StartsWith('\') -or $name -match '^[A-Za-z]:' -or $name.Replace('/','\').Split('\') -contains '..' -or $name.Contains(':')){throw 'Unsafe 7z/RAR member path.'}
      $key=$name.ToLowerInvariant();if($names.ContainsKey($key)){throw 'Archive contains case-colliding paths.'};$names[$key]=$true
      if([IO.Path]::GetExtension($name) -match '^\.(exe|dll|msi|bat|cmd|ps1|vbs|js|lnk|url|zip|7z|rar)$'){throw 'Archive contains nested dangerous content.'}
    }
    & $seven.Source x -y ('-o'+$Destination) -- $ArchivePath|Out-Null;if($LASTEXITCODE -ne 0){throw '7-Zip could not safely extract the update.'}
    $bytes=[int64](@(Get-ChildItem $Destination -Recurse -File|Measure-Object Length -Sum).Sum);if($bytes -gt 16GB){throw 'Extracted archive exceeds 16 GiB.'}
  }else{throw 'Unsupported update archive format.'}
  Assert-PMMUpdateExtractedTree $Destination;$paks=@(Get-ChildItem $Destination -Filter *.pak -Recurse -File);if($paks.Count -ne 1){throw 'Automatic updates require exactly one PAK.'};$paks[0]
}
function Test-PMMUpdateCandidate($Update,$Download) {
  $mod=Find-PMMLibraryMod $Update.Mod;if(-not$mod -or (Get-Sha256 $mod.Path) -cne $Update.LocalSha256){throw 'The installed mod changed.'}
  $root=Join-Path (Join-Path (Get-PMMUpdateRoot) 'Candidates') $Download.Sha256;if(Test-Path $root){Remove-Item $root -Recurse -Force};[void][IO.Directory]::CreateDirectory($root)
  $pak=Expand-PMMUpdateArchiveSafe $Download.Path (Join-Path $root 'Files');$hash=Get-Sha256 $pak.FullName
  $before=@(Get-PakEntriesCached $mod.Path|ForEach-Object{Normalize-PakLogicalPath $_});$after=@(Get-PakEntriesCached $pak.FullName|ForEach-Object{Normalize-PakLogicalPath $_});$removed=@($before|Where-Object{$_ -notin $after})
  $blockers=[Collections.Generic.List[string]]::new();$baseline=$null;$proposed=$null
  if(-not$mod.Enabled){$blockers.Add('Disabled mod is outside the active analysis set.')}else{
    $options=New-PMMDeepAnalysisOptions;$options.CheckUpdates=$false;$options.AutomaticSolution=$false
    $baseline=Invoke-PMMDeepAnalysis $options;$proposed=Invoke-PMMDeepAnalysis $options @{OriginalSha256=$mod.Hash;Path=$pak.FullName;Hash=$hash}
    if(-not$proposed.Coverage.ContainerIndexComplete){$blockers.Add('Container index coverage is incomplete.')}
    if($proposed.Coverage.BudgetReached){$blockers.Add('Semantic analysis reached its budget.')}
    $base=@($baseline.Findings|Where-Object{$_.Severity -in @('High','Critical')}|ForEach-Object{$_.Rule+'|'+$_.Resource})
    if(@($proposed.Findings|Where-Object{$_.Severity -in @('High','Critical') -and ($_.Rule+'|'+$_.Resource) -notin $base}).Count){$blockers.Add('New blocking findings were detected.')}
  }
  if($removed.Count){$blockers.Add('The new PAK removes resources from the installed variant.')}
  $deployedState=Read-PMMDeploymentState;if($deployedState -and $deployedState.Patch -and @($deployedState.SourceMods|Where-Object{[string]$_.Name -ieq [string]$mod.Name -and [string]$_.Hash -ceq [string]$mod.Hash}).Count){$blockers.Add('A deployed compatibility patch must be rebuilt for the updated source set.')}
  if(@(Get-PMMPendingRemovalRecords).Count){$blockers.Add('Pending managed removals must be deployed before an automatic update.')}
  $candidatePath=Join-Path $root 'candidate.json';$candidate=[pscustomobject][ordered]@{Schema='PMM_MOD_UPDATE_CANDIDATE_V2';Id=('UC-'+[Guid]::NewGuid().ToString('N'));CandidatePath=$candidatePath;CreatedUtc=[DateTime]::UtcNow.ToString('o');PlanId=(Read-PMMUpdatePlan).Id;LibraryFingerprint=(Get-PMMUpdateFingerprint);Update=$Update;ArchivePath=$Download.Path;ArchiveSha256=$Download.Sha256;PakPath=$pak.FullName;PakSha256=$hash;OriginalPath=$mod.Path;OriginalSha256=$mod.Hash;OriginalEnabled=[bool]$mod.Enabled;Priority=[int]$mod.Priority;LibraryRows=@(Get-PMMUpdateLibraryRows);RemovedResources=$removed;BaselineAnalysisId=$(if($baseline){$baseline.Id}else{''});ProposedAnalysisId=$(if($proposed){$proposed.Id}else{''});Blockers=$blockers.ToArray();AutomaticEligible=($blockers.Count -eq 0);Runtime='UNPROVEN';Applied=$false}
  Write-PMMJsonAtomic $candidatePath $candidate -Depth 40 -Schema PMM_MOD_UPDATE_CANDIDATE_V2;$candidate
}
function Test-PMMPalworldRunning { @(Get-Process -Name 'Palworld-Win64-Shipping','Palworld' -ErrorAction SilentlyContinue).Count -gt 0 }
function Open-PMMUpdateLock { try{[IO.File]::Open((Join-PMMPath 'State' 'mod-update.lock'),[IO.FileMode]::OpenOrCreate,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)}catch{throw 'Another mod update is running.'} }
function Invoke-PMMUpdateApply($Candidate,[switch]$Auto) {
  if(-not$Candidate.AutomaticEligible){throw 'UPDATE_REVIEW_REQUIRED: '+(@($Candidate.Blockers) -join '; ')};if($Candidate.LibraryFingerprint -cne (Get-PMMUpdateFingerprint)){throw 'The update plan is stale.'};if(Test-PMMPalworldRunning){throw 'GAME_RUNNING_DEFERRED'}
  $mod=Find-PMMLibraryMod $Candidate.Update.Mod;if(-not$mod -or (Get-Sha256 $mod.Path) -cne $Candidate.OriginalSha256){throw 'The installed mod changed before commit.'}
  $lock=Open-PMMUpdateLock;$id=(Get-Date -Format 'yyyyMMdd_HHmmss')+'_'+[Guid]::NewGuid().ToString('N').Substring(0,8);$root=Join-Path (Join-Path (Get-PMMUpdateRoot) 'Archive') $id;[void][IO.Directory]::CreateDirectory($root)
  $oldDir=Split-Path $mod.Path -Parent;$leaf=[IO.Path]::GetFileName($mod.Path);$backup=Join-Path $root 'LibraryBefore';$stage=$oldDir+'.pmm-update-'+$id;$game='';$gameBackup='';$gameExisted=$false;$deploymentBackup='';$statePath=Get-PMMDeploymentStatePath;$stateBackup='';$origin=Get-PMMModOrigin $mod;$stateBefore=Read-PMMDeploymentState;$managedSource=@();if($stateBefore -and ($stateBefore.PSObject.Properties.Name -contains 'SourceMods')){$managedSource=@($stateBefore.SourceMods|Where-Object{[string]$_.Name -ieq $leaf -and [string]$_.Hash -ceq [string]$mod.Hash}|Select-Object -First 1)}
  $tx=[pscustomobject][ordered]@{Schema='PMM_MOD_UPDATE_TRANSACTION_V1';Id=$id;State='Preparing';CreatedUtc=[DateTime]::UtcNow.ToString('o');UpdatedUtc='';Mod=$mod.Name;OldHash=$mod.Hash;NewHash=$Candidate.PakSha256;Enabled=[bool]$mod.Enabled;Priority=[int]$mod.Priority;LibraryPath=$oldDir;LibraryBackup=$backup;GamePath='';GameBackup='';GameExisted=$false;DeploymentStateBackup='';DeploymentTransactionBackup='';ResultingLibraryFingerprint='';OriginNewPath='';OriginNewBackup='';Candidate=$Candidate;OriginBefore=$origin;Error=''}
  $manifest=Join-Path $root 'transaction.json';Write-PMMJsonAtomic $manifest $tx -Depth 50
  try{
    [void][IO.Directory]::CreateDirectory($stage);Copy-Item $Candidate.PakPath (Join-Path $stage $leaf)
    if((Get-Sha256 (Join-Path $stage $leaf)) -cne $Candidate.PakSha256){throw 'Library staging hash mismatch.'}
    Write-PMMJsonAtomic (Join-Path $stage 'metadata.json') ([ordered]@{Schema='PMM_LIBRARY_MOD_V2';Name=$leaf;ContentPath=$leaf;ContentSha256=$Candidate.PakSha256;Source=$Candidate.ArchivePath;ArchiveSha256=$Candidate.ArchiveSha256;ImportedUtc=[DateTime]::UtcNow.ToString('o');UpdatedFrom=$Candidate.OriginalSha256})
    $wasDeployed=($managedSource.Count -eq 1 -and (-not($managedSource[0].PSObject.Properties.Name -contains 'Deployed') -or [bool]$managedSource[0].Deployed))
    $gameMods=Get-GameModsPath;if($mod.Enabled -and $gameMods -and $wasDeployed){$possible=Join-Path $gameMods $leaf;$game=$possible;$gameExisted=Test-Path $possible;if($gameExisted){if((Get-Sha256 $possible) -cne $mod.Hash){throw 'PMM will not overwrite an unrecognized game PAK.'};$gameBackup=Join-Path $root 'GameBefore.pak';Copy-Item $possible $gameBackup};$tx.GamePath=$game;$tx.GameBackup=$gameBackup;$tx.GameExisted=$gameExisted}
    if(Test-Path $statePath){$stateBackup=Join-Path $root 'deployment-state.before.json';Copy-Item $statePath $stateBackup;$tx.DeploymentStateBackup=$stateBackup}
    $tx.State='Prepared';Write-PMMJsonAtomic $manifest $tx -Depth 50;Move-Item $oldDir $backup;Move-Item $stage $oldDir;$tx.State='LibraryCommitted';Write-PMMJsonAtomic $manifest $tx -Depth 50
    $newMod=Find-PMMLibraryMod $leaf;$newOrigin=ConvertTo-PMMModOriginV2 $Candidate.Update.Origin $newMod;$newOrigin.FileId=$Candidate.Update.Candidate.FileId;$newOrigin.Version=$Candidate.Update.Candidate.Version;$newOrigin.AssetName=$Candidate.Update.Candidate.AssetName;$newOrigin.ArchivePath=$Candidate.ArchivePath;$newOrigin.ArchiveSha256=$Candidate.ArchiveSha256;$newOrigin.PreviousLocalSha256=$Candidate.OriginalSha256;$newOrigin.LocalSha256=$Candidate.PakSha256;$newOrigin.IdentityStatus='UpdateTransaction'
    $newOriginPath=Get-PMMModOriginPath $Candidate.PakSha256;$newOriginBackup='';if(Test-Path $newOriginPath){$newOriginBackup=Join-Path $root 'new-origin.before.json';Copy-Item $newOriginPath $newOriginBackup};$tx.OriginNewPath=$newOriginPath;$tx.OriginNewBackup=$newOriginBackup;Write-PMMJsonAtomic $manifest $tx -Depth 50
    Write-PMMJsonAtomic $newOriginPath $newOrigin -Depth 20 -Schema PMM_MOD_ORIGIN_V2
    if($stateBackup -and $managedSource.Count -eq 1){
      $state=Read-PMMDeploymentState
      foreach($source in @($state.SourceMods)){if([string]$source.Name -ieq $leaf -and [string]$source.Hash -ceq [string]$Candidate.OriginalSha256){$source.Hash=[string]$Candidate.PakSha256}}
      $state.SourceSignature=Get-PMMLibrarySignature @(Get-LibraryMods);$state.Deployed=[DateTime]::UtcNow.ToString('o')
      $copyActions=@();if($game){$copyActions=@([pscustomobject]@{Kind='Source';Name=$leaf;Source=$Candidate.PakPath;Destination=$game;ExpectedHash=$Candidate.PakSha256})}
      $deployContext=[pscustomobject]@{GameMods=$gameMods};$deployOps=[pscustomobject]@{RemoveActions=@();CopyActions=$copyActions;BlockingConflicts=@();Unchanged=@()}
      $deploymentBackup=Invoke-PMMDeploymentTransaction $deployContext $deployOps $state;$tx.DeploymentTransactionBackup=$deploymentBackup;Write-PMMJsonAtomic $manifest $tx -Depth 50
    }
    Clear-PMMLibraryHashCache;Clear-PakEntryCache;Clear-PMMAnalysisState
    $replaced=0;$expectedRows=@(foreach($row in @($Candidate.LibraryRows)){$hash=[string]$row.Hash;if([string]$row.Name -ieq [string]$Candidate.Update.Mod -and $hash -ceq [string]$Candidate.OriginalSha256){$hash=[string]$Candidate.PakSha256;$replaced++};[pscustomobject][ordered]@{Name=[string]$row.Name;Hash=$hash;Enabled=[bool]$row.Enabled;Priority=[int]$row.Priority}})
    if($replaced -ne 1){throw 'The update library snapshot does not identify exactly one source mod.'}
    $expectedFingerprint=Get-PMMUpdateFingerprintFromRows $expectedRows;$currentFingerprint=Get-PMMUpdateFingerprint
    if($currentFingerprint -cne $expectedFingerprint){throw 'The library changed concurrently while the update was being committed.'}
    $tx.ResultingLibraryFingerprint=$currentFingerprint;$tx.State='Committed';$tx.UpdatedUtc=[DateTime]::UtcNow.ToString('o');Write-PMMJsonAtomic $manifest $tx -Depth 50;$Candidate.Applied=$true;$tx
  }catch{
    $tx.Error=$_.Exception.Message
    try{if($tx.OriginNewBackup -and (Test-Path $tx.OriginNewBackup)){Copy-Item $tx.OriginNewBackup $tx.OriginNewPath -Force}elseif($tx.OriginNewPath -and (Test-Path $tx.OriginNewPath)){Remove-Item $tx.OriginNewPath -Force};if($gameBackup -and (Test-Path $gameBackup)){Copy-Item $gameBackup $game -Force}elseif($game -and -not$gameExisted -and (Test-Path $game)){Remove-Item $game -Force};if($stateBackup -and (Test-Path $stateBackup)){Copy-Item $stateBackup $statePath -Force};if(Test-Path $oldDir){Remove-Item $oldDir -Recurse -Force};if(Test-Path $backup){Move-Item $backup $oldDir};Clear-PMMLibraryHashCache;Clear-PakEntryCache;$tx.State='RolledBack'}catch{$tx.State='RecoveryRequired';$tx.Error+=' | rollback: '+$_.Exception.Message}
    $tx.UpdatedUtc=[DateTime]::UtcNow.ToString('o');Write-PMMJsonAtomic $manifest $tx -Depth 50;throw
  }finally{if(Test-Path $stage){Remove-Item $stage -Recurse -Force};$lock.Dispose()}
}
function Update-PMMUpdatePlanAfterApply($Candidate,$Transaction) {
  $path=Get-PMMUpdatePlanPath;$plan=Read-PMMJsonFile $path -Schema PMM_UPDATE_PLAN_V1
  if([string]$plan.Id -cne [string]$Candidate.PlanId -or [string]$plan.LibraryFingerprint -cne [string]$Candidate.LibraryFingerprint){throw 'The update plan changed before it could be advanced.'}
  $current=Get-PMMUpdateFingerprint;if($current -cne [string]$Transaction.ResultingLibraryFingerprint){throw 'The resulting library no longer matches the committed update.'}
  $matches=@($plan.Results|Where-Object{[string]$_.LocalSha256 -ceq [string]$Candidate.OriginalSha256});if($matches.Count -ne 1){throw 'The applied update is not unique in the saved plan.'}
  $matches[0].Status='APPLIED';$matches[0].Message='The verified successor was installed and the previous version was archived.';$matches[0].CompatibilityProven=$true
  $plan.LibraryFingerprint=$current;Write-PMMJsonAtomic $path $plan -Depth 30 -Schema PMM_UPDATE_PLAN_V1
}
function Repair-PMMIncompleteUpdateTransactions {
  foreach($dir in @(Get-ChildItem (Join-Path (Get-PMMUpdateRoot) 'Archive') -Directory -ErrorAction SilentlyContinue)){
    $path=Join-Path $dir.FullName 'transaction.json';if(-not(Test-Path $path)){continue};$tx=Read-PMMJsonFile $path -Schema PMM_MOD_UPDATE_TRANSACTION_V1
    if($tx.State -in @('Committed','RolledBack','Restored') -or (Test-PMMPalworldRunning)){continue}
    try{if(($tx.PSObject.Properties.Name -contains 'OriginNewBackup') -and $tx.OriginNewBackup -and (Test-Path $tx.OriginNewBackup)){Copy-Item $tx.OriginNewBackup $tx.OriginNewPath -Force}elseif(($tx.PSObject.Properties.Name -contains 'OriginNewPath') -and $tx.OriginNewPath -and (Test-Path $tx.OriginNewPath)){Remove-Item $tx.OriginNewPath -Force};if($tx.GameBackup -and (Test-Path $tx.GameBackup)){Copy-Item $tx.GameBackup $tx.GamePath -Force}elseif(($tx.PSObject.Properties.Name -contains 'GameExisted') -and -not[bool]$tx.GameExisted -and $tx.GamePath -and (Test-Path $tx.GamePath)){Remove-Item $tx.GamePath -Force};if($tx.DeploymentStateBackup -and (Test-Path $tx.DeploymentStateBackup)){Copy-Item $tx.DeploymentStateBackup (Get-PMMDeploymentStatePath) -Force};if(Test-Path $tx.LibraryBackup){if(Test-Path $tx.LibraryPath){Remove-Item $tx.LibraryPath -Recurse -Force};Move-Item $tx.LibraryBackup $tx.LibraryPath};$tx.State='RolledBack'}catch{$tx.State='RecoveryRequired';$tx.Error=$_.Exception.Message};$tx.UpdatedUtc=[DateTime]::UtcNow.ToString('o');Write-PMMJsonAtomic $path $tx -Depth 50
  }
}
function Get-PMMUpdateArchives {
  foreach($dir in @(Get-ChildItem (Join-Path (Get-PMMUpdateRoot) 'Archive') -Directory -ErrorAction SilentlyContinue|Sort-Object Name -Descending)){
    $path=Join-Path $dir.FullName 'transaction.json';if(Test-Path $path){$tx=Read-PMMJsonFile $path -Schema PMM_MOD_UPDATE_TRANSACTION_V1;$measure=Get-ChildItem $dir.FullName -Recurse -File|Measure-Object Length -Sum;$bytes=if($measure -and $null -ne $measure.Sum){[int64]$measure.Sum}else{0L};[pscustomobject]@{Id=$tx.Id;Mod=$tx.Mod;State=$tx.State;OldHash=$tx.OldHash;NewHash=$tx.NewHash;CreatedUtc=$tx.CreatedUtc;Bytes=[int64]$bytes;Path=$dir.FullName}}
  }
}
function Remove-PMMUpdateArchive([string]$TransactionId) {
  if($TransactionId -notmatch '^[0-9]{8}_[0-9]{6}_[a-f0-9]{8}$'){throw 'Invalid update archive id.'}
  $archiveRoot=[IO.Path]::GetFullPath((Join-Path (Get-PMMUpdateRoot) 'Archive')).TrimEnd('\','/')
  $target=Assert-PMMRecoveryPath (Join-Path $archiveRoot $TransactionId) $archiveRoot -DirectChild
  $manifest=Join-Path $target 'transaction.json';if(-not(Test-Path $manifest)){throw 'Update archive was not found.'}
  $tx=Read-PMMJsonFile $manifest -Schema PMM_MOD_UPDATE_TRANSACTION_V1
  if([string]$tx.State -notin @('Committed','RolledBack','Restored')){throw 'Incomplete update archives cannot be deleted.'}
  Remove-Item -LiteralPath $target -Recurse -Force
}
function Restore-PMMArchivedUpdate([string]$TransactionId) {
  $dir=Join-Path (Join-Path (Get-PMMUpdateRoot) 'Archive') $TransactionId;$tx=Read-PMMJsonFile (Join-Path $dir 'transaction.json') -Schema PMM_MOD_UPDATE_TRANSACTION_V1
  if($tx.State -ne 'Committed' -or -not(Test-Path $tx.LibraryBackup)){throw 'This archive cannot be restored.'};$pak=@(Get-ChildItem $tx.LibraryBackup -Filter *.pak -File);if($pak.Count -ne 1){throw 'Archived library version is incomplete.'}
  $current=Find-PMMLibraryMod $tx.Mod;if(-not$current -or $current.Hash -cne $tx.NewHash){throw 'Current library no longer matches this transaction.'}
  $candidate=[pscustomobject]@{Schema='PMM_MOD_UPDATE_CANDIDATE_V2';Id=('RESTORE-'+$TransactionId);LibraryFingerprint=(Get-PMMUpdateFingerprint);Update=[pscustomobject]@{Mod=$current.Name;Origin=$tx.OriginBefore;Candidate=[pscustomobject]@{FileId=$tx.OriginBefore.FileId;Version=$tx.OriginBefore.Version;AssetName=$tx.OriginBefore.AssetName}};ArchivePath=$pak[0].FullName;ArchiveSha256=(Get-Sha256 $pak[0].FullName);PakPath=$pak[0].FullName;PakSha256=(Get-Sha256 $pak[0].FullName);OriginalSha256=$current.Hash;LibraryRows=@(Get-PMMUpdateLibraryRows);AutomaticEligible=$true;Applied=$false}
  Invoke-PMMUpdateApply $candidate
}
function Skip-PMMUpdatesForCurrentLibrary {
  Write-PMMJsonAtomic (Join-PMMPath 'State' 'update-skip.json') ([ordered]@{Schema='PMM_UPDATE_SKIP_V1';LibraryFingerprint=(Get-PMMUpdateFingerprint);SkippedUtc=[DateTime]::UtcNow.ToString('o')})
}
function Get-PMMUpdateWorkflowAction {
  $fingerprint=Get-PMMUpdateFingerprint;$skipPath=Join-PMMPath 'State' 'update-skip.json'
  if(Test-Path $skipPath){try{$skip=Read-PMMJsonFile $skipPath -Schema PMM_UPDATE_SKIP_V1;if($skip.LibraryFingerprint -ceq $fingerprint){return 'None'}}catch{}}
  $plan=Read-PMMUpdatePlan;if(-not$plan -or -not$plan.IsCurrent){return 'Check'}
  if(@($plan.Results|Where-Object{$_.Status -eq 'UPDATE_AVAILABLE'}).Count){
    $attemptPath=Join-PMMPath 'State' 'update-attempt.json'
    if(Test-Path $attemptPath){try{$attempt=Read-PMMJsonFile $attemptPath -Schema PMM_UPDATE_ATTEMPT_V1;if($attempt.PlanId -ceq $plan.Id){return 'None'}}catch{}}
    return 'Apply'
  }
  'None'
}