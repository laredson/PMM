param([string]$Root,[string[]]$Arguments,[string]$SessionDir)
$runtime=Join-Path $Root 'Engine\PMMRuntime.exe'
if(-not(Test-Path -LiteralPath $runtime -PathType Leaf)){Write-Output 'PMMRuntime.exe is missing.';exit 20}
& $runtime self-test
exit $LASTEXITCODE
