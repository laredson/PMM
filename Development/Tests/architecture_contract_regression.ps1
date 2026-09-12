param([string]$Repository=([IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))))
Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
. (Join-Path $Repository 'PMM\Modules\Operations\ModuleRuntime.ps1')
$app=Join-Path $Repository 'PMM'
$catalog=@(Get-PMMModuleCatalog -Root $app)
$byId=@{};foreach($module in $catalog){$byId[$module.Id]=$module}
foreach($required in @('persistence','deployment-recovery','cases','knowledge','tools','observations','workflow','module-runtime','workbench-loader')){
  if(-not$byId.ContainsKey($required)){throw ('Required module contract missing: '+$required)}
}
if('knowledge' -notin $byId['tools'].Dependencies){throw 'Tool adapters must declare their knowledge helper dependency.'}
foreach($profile in @('UI','Worker','MCP')){
  $paths=@(Get-PMMModuleLoadPaths -Root $app -Profile $profile -Stage Extension)
  if($paths.Count -ne 4){throw ('Unexpected extension set for '+$profile)}
  if(@($paths|Where-Object{$_ -match '\\Presentation\\|\\Bootstrap\\'}).Count){throw 'Headless extension loading included a UI entry point.'}
}
foreach($id in @('cases','knowledge','tools','observations')){
  $module=$byId[$id];$tokens=$null;$errors=$null
  $ast=[Management.Automation.Language.Parser]::ParseFile($module.Path,[ref]$tokens,[ref]$errors)
  $types=@($ast.FindAll({param($node)$node -is [Management.Automation.Language.TypeExpressionAst]},$true))
  foreach($type in $types){if($type.TypeName.FullName -match '(^|\.)(Windows\.Controls|Windows\.Forms|Windows\.MessageBox|Windows\.Markup|PresentationFramework)'){throw ('Domain service references UI framework: '+$id+' '+$type.TypeName.FullName)}}
  $commands=@($ast.FindAll({param($node)$node -is [Management.Automation.Language.CommandAst]},$true)|ForEach-Object{$_.GetCommandName()})
  foreach($forbidden in @('Refresh-UI','Handle-UIError','Show-Info','Show-PMMStyledDialog','Invoke-PMMWorkbenchContextCase','Set-PMMWorkbenchMode','Show-PMMWorkbenchPage')){
    if($forbidden -in $commands){throw ('Domain service depends on presentation: '+$id+' -> '+$forbidden)}
  }
}
$workflowDefinitions=@(foreach($module in $catalog){foreach($function in $module.Functions){if($function.Name -eq 'Get-PMMWorkflowState'){$module.Id}}})
if($workflowDefinitions.Count -ne 1 -or $workflowDefinitions[0] -ne 'workflow'){throw 'Auto and manual workflow state must have one shared definition.'}
foreach($path in @('Modules/MCP/Start-PMMMCP.ps1','Modules/Operations/OperationWorker.ps1')){
  $source=[IO.File]::ReadAllText((Join-Path $app $path))
  if($source -notmatch 'Start-PMMModuleOperation' -or $source -notmatch 'Complete-PMMModuleOperation'){throw ('Headless host is missing paired generation leases: '+$path)}
}
foreach($module in @($catalog|Where-Object{$_.Id -like 'presentation.*' -or $_.Id -in @('workbench-loader','module-runtime')})){
  if($module.Reload -ne 'Restart'){throw ('UI/loader initialization cannot be hot-reloaded as service functions: '+$module.Id)}
}
'ARCHITECTURE_CONTRACT_OK: '+$catalog.Count+' versioned graph nodes, profile/stage separation, explicit tool dependencies, UI-free domain services, single shared workflow state, paired worker/MCP leases and restart-only presentation.'
