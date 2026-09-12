<# Module graph and transactional reload for editable service functions.
   Initial script paths are returned so callers dot-source in their own scope. #>
if(-not(Get-Variable PMMModuleRuntime -Scope Script -ErrorAction SilentlyContinue)){$Script:PMMModuleRuntime=$null}
function Get-PMMModuleCatalog {
  param([string]$Root=$Script:Root,[string]$ManifestPath='')
  $rootPath=[IO.Path]::GetFullPath($Root).TrimEnd('\','/')
  if(-not$ManifestPath){$ManifestPath=Join-Path $rootPath 'Modules\modules.json'}
  $manifest=Get-Content -LiteralPath $ManifestPath -Raw -Encoding UTF8|ConvertFrom-Json
  if([string]$manifest.Schema -cne 'PMM_MODULE_MANIFEST_V1' -or [int]$manifest.ContractVersion -ne 1){throw 'Unsupported module manifest contract; restart with a compatible PMM host.'}
  $byId=@{};$rows=[Collections.Generic.List[object]]::new()
  foreach($entry in @($manifest.Modules)){
    $id=[string]$entry.Id
    if($id -notmatch '^[a-z][a-z0-9.-]+$' -or $byId.ContainsKey($id)){throw "Invalid or duplicate module identity: $id"}
    if([string]$entry.Version -notmatch '^\d+\.\d+\.\d+$' -or [int]$entry.ContractVersion -ne 1){throw "Unsupported module version/contract: $id"}
    if([string]$entry.Reload -notin @('Functions','Restart')){throw "Unsupported reload policy: $id"}
    if([IO.Path]::IsPathRooted([string]$entry.Path)){throw 'Module paths must be relative to PMM.'}
    $path=[IO.Path]::GetFullPath((Join-Path $rootPath ([string]$entry.Path)))
    if(-not$path.StartsWith($rootPath+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)){throw 'Module path escapes the PMM root.'}
    if(-not(Test-Path -LiteralPath $path -PathType Leaf)){throw "Module script is missing: $path"}
    $tokens=$null;$errors=$null;$ast=[Management.Automation.Language.Parser]::ParseFile($path,[ref]$tokens,[ref]$errors)
    if(@($errors).Count){throw ('Module parse failed: '+$id+' | '+(($errors|ForEach-Object{$_.Message}) -join '; '))}
    if($entry.Reload -eq 'Functions'){
      if($ast.ParamBlock -or $ast.BeginBlock -or $ast.ProcessBlock -or $ast.DynamicParamBlock -or @($ast.EndBlock.Statements|Where-Object{$_ -isnot [Management.Automation.Language.FunctionDefinitionAst]}).Count){throw "Reloadable modules must contain only top-level functions and no event registrations: $id"}
    }
    $functions=@($ast.EndBlock.Statements|Where-Object{$_ -is [Management.Automation.Language.FunctionDefinitionAst]})
    $row=[pscustomobject]@{Id=$id;Version=[string]$entry.Version;ContractVersion=[int]$entry.ContractVersion;Path=$path;RelativePath=[string]$entry.Path;Dependencies=@($entry.Dependencies);Capabilities=@($entry.Capabilities);Profiles=@($entry.Profiles);Stage=$(if($entry.PSObject.Properties.Name -contains 'Stage'){[string]$entry.Stage}else{'Legacy'});Reload=[string]$entry.Reload;Hash=(Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant();Functions=$functions}
    $byId[$id]=$row;$rows.Add($row)
  }
  foreach($row in $rows){foreach($dependency in $row.Dependencies){if(-not$byId.ContainsKey([string]$dependency)){throw "Unknown module dependency $dependency in $($row.Id)."}}}
  $ordered=[Collections.Generic.List[object]]::new();$done=@{}
  while($ordered.Count -lt $rows.Count){
    $progress=$false
    foreach($row in $rows){
      if($done.ContainsKey($row.Id)){continue}
      if(@($row.Dependencies|Where-Object{-not$done.ContainsKey([string]$_)}).Count){continue}
      $ordered.Add($row);$done[$row.Id]=$true;$progress=$true
    }
    if(-not$progress){throw 'The module dependency graph contains a cycle.'}
  }
  return $ordered.ToArray()
}
function Get-PMMModuleLoadPaths {
  param([string]$Root=$Script:Root,[ValidateSet('UI','Worker','MCP','All')][string]$Profile='All',[string]$ManifestPath='',[ValidateSet('All','Legacy','Extension')][string]$Stage='All')
  $catalog=@(Get-PMMModuleCatalog -Root $Root -ManifestPath $ManifestPath);$selected=@{}
  foreach($item in $catalog){if($Profile -eq 'All' -or $Profile -in $item.Profiles){$selected[$item.Id]=$true}}
  do{
    $added=$false
    foreach($item in $catalog){if($selected.ContainsKey($item.Id)){foreach($dependency in $item.Dependencies){if(-not$selected.ContainsKey([string]$dependency)){$selected[[string]$dependency]=$true;$added=$true}}}}
  }while($added)
  foreach($item in $catalog){if($selected.ContainsKey($item.Id) -and ($Stage -eq 'All' -or $item.Stage -eq $Stage)){$item.Path}}
}
function Initialize-PMMModuleRuntime {
  param([string]$Root=$Script:Root,[string]$ManifestPath='')
  $catalog=@(Get-PMMModuleCatalog -Root $Root -ManifestPath $ManifestPath)
  $Script:PMMModuleRuntime=[pscustomobject]@{Root=$Root;ManifestPath=$ManifestPath;Catalog=$catalog;Native=@(Get-PMMNativeModuleSnapshot $Root);Operations=@{};Pending=$null;Generation=1;LastResult='Initialized'}
  return Get-PMMModuleRuntimeSnapshot
}
function Get-PMMModuleRuntimeSnapshot {
  if(-not$Script:PMMModuleRuntime){return $null}
  return [pscustomobject]@{Schema='PMM_MODULE_SNAPSHOT_V1';Generation=$Script:PMMModuleRuntime.Generation;Busy=($Script:PMMModuleRuntime.Operations.Count -gt 0);Pending=($null -ne $Script:PMMModuleRuntime.Pending);LastResult=$Script:PMMModuleRuntime.LastResult;Native=@($Script:PMMModuleRuntime.Native);Modules=@($Script:PMMModuleRuntime.Catalog|ForEach-Object{[pscustomobject]@{Id=$_.Id;Version=$_.Version;ContractVersion=$_.ContractVersion;Hash=$_.Hash}})}
}
function Start-PMMModuleOperation([string]$Operation) {
  if(-not$Script:PMMModuleRuntime){return $null}
  $lease=[pscustomobject]@{Id=[guid]::NewGuid().ToString('N');Operation=$Operation;StartedUtc=[DateTime]::UtcNow.ToString('o');Snapshot=(Get-PMMModuleRuntimeSnapshot)}
  $Script:PMMModuleRuntime.Operations[$lease.Id]=$lease
  return $lease
}
function Complete-PMMModuleOperation([string]$LeaseId) {
  if($Script:PMMModuleRuntime -and $LeaseId){[void]$Script:PMMModuleRuntime.Operations.Remove($LeaseId)}
}
function Request-PMMModuleReload {
  param([bool]$Busy=$false)
  if(-not$Script:PMMModuleRuntime){throw 'Initialize the module runtime before requesting reload.'}
  $Script:PMMModuleRuntime.Pending=$null
  try{
    $native=@(Get-PMMNativeModuleSnapshot $Script:PMMModuleRuntime.Root)
    if(($native|ConvertTo-Json -Compress) -cne ($Script:PMMModuleRuntime.Native|ConvertTo-Json -Compress)){$Script:PMMModuleRuntime.LastResult='RestartRequired';return [pscustomobject]@{Status='RestartRequired';Reason='A compiled component changed; restart before using its new contract.'}}
    $catalog=@(Get-PMMModuleCatalog -Root $Script:PMMModuleRuntime.Root -ManifestPath $Script:PMMModuleRuntime.ManifestPath)
    $old=@{};foreach($item in $Script:PMMModuleRuntime.Catalog){$old[$item.Id]=$item}
    if($catalog.Count -ne $old.Count){$Script:PMMModuleRuntime.LastResult='RestartRequired';return [pscustomobject]@{Status='RestartRequired';Reason='The set of modules changed.'}}
    $changed=[Collections.Generic.List[object]]::new()
    foreach($item in $catalog){
      if(-not$old.ContainsKey($item.Id)){$Script:PMMModuleRuntime.LastResult='RestartRequired';return [pscustomobject]@{Status='RestartRequired';Reason='Module identity changed.'}}
      $previous=$old[$item.Id]
      $contractChanged=($item.ContractVersion -ne $previous.ContractVersion -or $item.RelativePath -cne $previous.RelativePath -or ($item.Dependencies -join '|') -cne ($previous.Dependencies -join '|') -or ($item.Capabilities -join '|') -cne ($previous.Capabilities -join '|'))
      if($contractChanged -or (($item.Hash -ne $previous.Hash -or $item.Version -ne $previous.Version) -and ($item.Reload -ne 'Functions' -or $previous.Reload -ne 'Functions'))){$Script:PMMModuleRuntime.LastResult='RestartRequired';return [pscustomobject]@{Status='RestartRequired';Reason=('Module '+$item.Id+' changes initialization, native integration or its contract.')}}
      if($item.Hash -ne $previous.Hash -or $item.Version -ne $previous.Version){$changed.Add($item)}
    }
    if(-not$changed.Count){return [pscustomobject]@{Status='Unchanged';Reason='No module bytes or versions changed.'}}
    # Export names may be added/removed within a module, but never steal another
    # module's function. Staging does not invoke any source code.
    $owners=@{}
    foreach($item in $Script:PMMModuleRuntime.Catalog){foreach($fn in $item.Functions){$owners[$fn.Name]=$item.Id}}
    foreach($item in $changed){foreach($fn in $item.Functions){if($owners.ContainsKey($fn.Name) -and $owners[$fn.Name] -ne $item.Id){throw ('Reload would replace another module function: '+$fn.Name)};$owners[$fn.Name]=$item.Id}}
    $Script:PMMModuleRuntime.Pending=[pscustomobject]@{Catalog=$catalog;Changed=$changed.ToArray();Previous=$old;ManifestHash=(Get-PMMModuleManifestHash $Script:PMMModuleRuntime.Root $Script:PMMModuleRuntime.ManifestPath);StagedUtc=[DateTime]::UtcNow.ToString('o')}
    if($Busy -or $Script:PMMModuleRuntime.Operations.Count){$Script:PMMModuleRuntime.LastResult='Queued';return [pscustomobject]@{Status='Queued';Reason='Existing operations retain their loaded module versions.'}}
    return Invoke-PMMPendingModuleReload
  }catch{$Script:PMMModuleRuntime.Pending=$null;$Script:PMMModuleRuntime.LastResult='Rejected';return [pscustomobject]@{Status='Rejected';Reason=$_.Exception.Message}}
}
function Invoke-PMMPendingModuleReload {
  param([bool]$Busy=$false)
  if(-not$Script:PMMModuleRuntime -or -not$Script:PMMModuleRuntime.Pending){return [pscustomobject]@{Status='Unchanged';Reason='No staged reload.'}}
  if($Busy -or $Script:PMMModuleRuntime.Operations.Count){return [pscustomobject]@{Status='Queued';Reason='An operation is still using the current generation.'}}
  $pending=$Script:PMMModuleRuntime.Pending;$saved=@{};$names=[Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
  try{
    # Recheck both contracts and native bytes at activation, even when they
    # changed after an earlier request queued a valid service-only reload.
    if((Get-PMMModuleManifestHash $Script:PMMModuleRuntime.Root $Script:PMMModuleRuntime.ManifestPath) -ne $pending.ManifestHash){throw 'Module manifest changed after staging; request reload again.'}
    if((@(Get-PMMNativeModuleSnapshot $Script:PMMModuleRuntime.Root)|ConvertTo-Json -Compress) -cne ($Script:PMMModuleRuntime.Native|ConvertTo-Json -Compress)){throw 'A compiled component changed after staging; restart is required.'}
    # Reject any change made after staging so the reviewed AST/hash stays exact.
    foreach($item in $pending.Catalog){if((Get-FileHash -LiteralPath $item.Path -Algorithm SHA256).Hash.ToLowerInvariant() -ne $item.Hash){throw 'Module files changed after staging; request reload again.'}}
    foreach($item in $pending.Changed){
      foreach($fn in @($pending.Previous[$item.Id].Functions)+@($item.Functions)){[void]$names.Add([string]$fn.Name)}
    }
    foreach($name in $names){$command=Get-Command -Name $name -CommandType Function -ErrorAction SilentlyContinue;$saved[$name]=if($command){$command.ScriptBlock}else{$null}}
    foreach($item in $pending.Changed){
      foreach($fn in $pending.Previous[$item.Id].Functions){Remove-Item -LiteralPath ('Function:script:'+ $fn.Name) -ErrorAction SilentlyContinue}
      foreach($fn in $item.Functions){Set-Item -LiteralPath ('Function:script:'+ $fn.Name) -Value ($fn.Body.GetScriptBlock()) -ErrorAction Stop}
    }
    $Script:PMMModuleRuntime.Catalog=$pending.Catalog;$Script:PMMModuleRuntime.Generation++;$Script:PMMModuleRuntime.LastResult='Activated';$Script:PMMModuleRuntime.Pending=$null
    return [pscustomobject]@{Status='Activated';Reason='Validated service functions activated while idle.';Generation=$Script:PMMModuleRuntime.Generation}
  }catch{
    foreach($name in $names){if($saved.ContainsKey($name) -and $null -ne $saved[$name]){Set-Item -LiteralPath ('Function:script:'+ $name) -Value $saved[$name]}else{Remove-Item -LiteralPath ('Function:script:'+ $name) -ErrorAction SilentlyContinue}}
    $Script:PMMModuleRuntime.LastResult='Rejected';$Script:PMMModuleRuntime.Pending=$null
    return [pscustomobject]@{Status='Rejected';Reason=$_.Exception.Message}
  }
}

function Get-PMMNativeModuleSnapshot([string]$Root) {
  foreach($relative in @('PMM.exe','Engine/PMMRuntime.exe','Engine/PMMFixLab.exe','Engine/repak.exe','Engine/PMMCore/pmmcore.dll','Engine/AssetReader/PMM.AssetReader.dll')){
    $path=Join-Path $Root $relative
    [pscustomobject]@{Path=$relative;Hash=$(if(Test-Path -LiteralPath $path -PathType Leaf){(Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()}else{'absent'})}
  }
}

function Get-PMMModuleManifestHash([string]$Root,[string]$ManifestPath='') {
  if(-not$ManifestPath){$ManifestPath=Join-Path $Root 'Modules\modules.json'}
  return (Get-FileHash -LiteralPath $ManifestPath -Algorithm SHA256).Hash.ToLowerInvariant()
}
