$ErrorActionPreference='Stop'
$repo=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$runtimePath=Join-Path $repo 'Development\Source\Runtime\main.go'
$commonPath=Join-Path $repo 'PMM\Modules\Shared\Common.ps1'
$bootstrapPath=Join-Path $repo 'PMM\Modules\Bootstrap\Start-PalModMerger.ps1'
$runtime=Get-Content -LiteralPath $runtimePath -Raw
$common=Get-Content -LiteralPath $commonPath -Raw
$bootstrap=Get-Content -LiteralPath $bootstrapPath -Raw

function Assert-True([bool]$Condition,[string]$Message){if(-not $Condition){throw $Message}}

$startBegin=$runtime.IndexOf('func startApplication(root string) int {')
$startEnd=$runtime.IndexOf('func has(args []string, w string) bool {',$startBegin)
Assert-True ($startBegin -ge 0 -and $startEnd -gt $startBegin) 'Could not isolate Runtime startApplication.'
$startBody=$runtime.Substring($startBegin,$startEnd-$startBegin)
Assert-True (-not $startBody.Contains('ensureDependencies(')) 'Normal Runtime start must not repair/download dependencies before UI.'
Assert-True ($startBody.Contains('inspectStartupDependencies(')) 'Normal Runtime start must use the read-only startup dependency inspection.'
Assert-True ($startBody.Contains('startup:runtime-ui-dispatch')) 'Runtime startup diagnostics must retain the UI-dispatch stage.'

$initBegin=$common.IndexOf('function Initialize-PMMDependenciesIfNeeded {')
$initEnd=$common.IndexOf('function Get-PMMStatusLine {',$initBegin)
Assert-True ($initBegin -ge 0 -and $initEnd -gt $initBegin) 'Could not isolate PowerShell startup dependency function.'
$initBody=$common.Substring($initBegin,$initEnd-$initBegin)
Assert-True (-not $initBody.Contains('Setup-Dependencies.ps1')) 'PowerShell startup dependency check must not invoke repair.'
Assert-True ($initBody.Contains('Automatic startup repair is disabled')) 'PowerShell startup should document explicit repair policy.'

$contentRendered=$bootstrap.IndexOf('$Window.Add_ContentRendered({')
$depChecks=[regex]::Matches($bootstrap,'Initialize-PMMDependenciesIfNeeded')
Assert-True ($depChecks.Count -eq 1) 'Expected exactly one startup dependency check in the WPF bootstrap.'
Assert-True ($depChecks[0].Index -gt $contentRendered) 'Dependency check must run only after ContentRendered.'
Assert-True ($bootstrap.Contains('$Script:PMMStartupUiVisible=$false')) 'Startup visibility guard is missing.'
Assert-True ($bootstrap.Contains('$Script:PMMStartupUiVisible = $true')) 'ContentRendered must release the startup visibility guard.'
Assert-True (-not $bootstrap.Contains('Some dependencies are still unavailable. Restart PMM.exe')) 'Blocking pre-UI dependency popup must be removed.'
Assert-True ($bootstrap.Contains("Set-PMMHostStartupState 'startup:UI-pre-show-refresh'")) 'Pre-show diagnostic stage is missing.'
Assert-True ($bootstrap.Contains("Set-PMMHostStartupState 'startup:UI-show-dialog'")) 'ShowDialog diagnostic stage is missing.'
Assert-True ($bootstrap.Contains('BtnSetupDeps.Add_Click')) 'Explicit Settings dependency repair button must remain.'
Assert-True ($bootstrap.Contains('Setup-Dependencies.ps1')) 'Explicit Settings dependency repair entrypoint must remain.'

Write-Output 'STARTUP_PRE_UI_REGRESSION_PASS'
