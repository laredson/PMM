param([ValidateSet('UI','Worker','MCP')][string]$Profile='UI')
. (Join-Path $PSScriptRoot 'Operations/ModuleRuntime.ps1')
foreach($servicePath in @(Get-PMMModuleLoadPaths -Root $Script:Root -Profile $Profile -Stage Extension)){. $servicePath}
Initialize-PMMModuleRuntime -Root $Script:Root|Out-Null