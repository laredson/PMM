param([string]$Root,[string[]]$Arguments)
Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
$SessionDir=$env:PMM_HOST_SESSION_DIR
function State([string]$v){if($SessionDir){try{Set-Content -LiteralPath (Join-Path $SessionDir 'state.txt') -Value $v -Encoding UTF8}catch{}}}

$runtime=Join-Path $Root 'PMMRuntime.exe'
if(-not(Test-Path -LiteralPath $runtime -PathType Leaf)){
  State 'startup:runtime-missing'
  Write-Output 'PMMRuntime.exe is missing.'
  exit 20
}

State 'startup:runtime-dependency-verification'
& $runtime dependencies ensure --if-needed
$rc=$LASTEXITCODE
if($rc -ne 0){State ('startup:runtime-dependency-failed:'+$rc);exit $rc}

State 'startup:runtime-ui-dispatch'
& $runtime ui
$rc=$LASTEXITCODE
if($rc -eq 0){State 'startup:UI-closed-normally'}else{State ('startup:UI-runtime-exit:'+ $rc)}
exit $rc
