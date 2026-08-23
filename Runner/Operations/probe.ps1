param([string]$Root,[string[]]$Arguments,[string]$SessionDir)
Write-Output 'PMM_RUNNER_PROBE_OK'
Write-Output ('BUILD_ID='+((Get-Content -LiteralPath (Join-Path $Root 'BUILD_ID.txt') -Raw).Trim()))
Write-Output ('ARGUMENT_COUNT='+@($Arguments).Count)
exit 0
