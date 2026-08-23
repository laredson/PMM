<#
PMM 1.2 native dependency bootstrap wrapper.

This public entrypoint is intentionally compatible with PowerShell ConstrainedLanguage.
All dependency verification/repair that previously required FullLanguage now lives in
PMMRuntime.exe. The previous implementation is preserved under Legacy/ for source history.
#>
param([switch]$RefreshMappings,[switch]$IfNeeded)
Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
$Root=Split-Path -Parent $MyInvocation.MyCommand.Path
$Runtime=Join-Path $Root 'PMMRuntime.exe'
if(-not(Test-Path -LiteralPath $Runtime -PathType Leaf)){
  Write-Output '[PMM1.2] PMMRuntime.exe is missing.'
  exit 20
}
$argsList=@('dependencies','ensure')
if($IfNeeded){$argsList += '--if-needed'}
if($RefreshMappings){$argsList += '--refresh-mappings'}
Write-Output '[PMM1.2] Dependency verification delegated to PMMRuntime.exe.'
& $Runtime @argsList
$rc=$LASTEXITCODE
if($rc -ne 0){Write-Output ('[PMM1.2] PMMRuntime dependency preparation failed with exit code '+$rc)}
exit $rc
