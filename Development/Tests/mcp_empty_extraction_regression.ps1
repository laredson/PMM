
$ErrorActionPreference='Stop';Set-StrictMode -Version 2
. ./PMM/Modules/MCP/MCP.Service.ps1
function Get-PMMMCPEnabled{return $true}
$folder=Join-Path (Get-Location) ('Development/TestResults/EmptyExtraction-'+[guid]::NewGuid().ToString('N'))
$empty=Join-Path $folder 'empty';[void][IO.Directory]::CreateDirectory($empty)
$r=Invoke-PMMBoundedProcess (Join-Path $env:SystemRoot 'System32/WindowsPowerShell/v1.0/powershell.exe') @('-NoProfile','-Command','Start-Sleep -Milliseconds 1000') $folder 10 -DataDirectory $empty
if($r.exitCode -ne 0){throw 'Empty extraction directory failed'}
'EMPTY_EXTRACTION_MONITOR_PASS'
