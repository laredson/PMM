param([ValidateSet('UI','Worker','MCP')][string]$Profile='UI')
# Explicit extension graph; legacy adapters are loaded by their established hosts.
. (Join-Path $Script:Root 'Modules\Operations\ModuleRuntime.ps1')
foreach($pmmExtension in @(Get-PMMModuleLoadPaths -Root $Script:Root -Profile $Profile -Stage Extension)){
  . $pmmExtension
}
