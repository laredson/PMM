param([string]$Root,[string[]]$Arguments,[string]$SessionDir)
$shell=$env:PMM_HOST_POWERSHELL;if([string]::IsNullOrWhiteSpace($shell)){$shell='powershell.exe'}
& $shell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root 'SmokeTest.ps1') -Quiet
exit $LASTEXITCODE
