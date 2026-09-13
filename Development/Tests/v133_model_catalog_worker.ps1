param([switch]$ProbeMetadata)
Set-StrictMode -Version 2;$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'v133_analysis_regression.ps1')
# Verify the same module composition used by normal UI operations, without MCP.UI.
. (Join-Path $fixture 'Modules/Workbench.Services.ps1') -Profile Worker
if(-not(Get-Command Get-PMMCodexRuntime -ErrorAction SilentlyContinue)){throw 'Worker profile lacks runtime discovery.'}
if($ProbeMetadata){
  $request=Join-PMMPath 'Cache' 'DeepRequests/refresh-request.json'
  $result=Join-Path $fixture 'refresh-result.json'
  Write-PMMJsonAtomic $request @{Action='RefreshAI'}
  $hostExe=Join-Path $env:SystemRoot 'System32/WindowsPowerShell/v1.0/powershell.exe'
  & $hostExe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $fixture 'Modules/Operations/OperationWorker.ps1') -Root $fixture -Operation DeepSource -RequestPath $request -ResultPath $result -ProgressPath (Join-Path $fixture 'refresh-progress.json')|Out-Null
  if($LASTEXITCODE -ne 0){throw (Get-Content -LiteralPath $result -Raw)}
  $r=Read-PMMJsonFile $result
  $catalog=Read-PMMJsonFile (Join-PMMPath 'State' 'ai-capabilities.json')
  if(-not$r.Success -or @($catalog.Models).Count -eq 0){throw 'Worker did not persist the model catalog.'}
  Write-Output ('PASS model metadata worker: '+@($catalog.Models).Count+' detected models; no inference turn.')
}
Write-Output 'PASS worker profile provides runtime discovery.'
