param(
  [Parameter(Position=0)][string]$Operation='start',
  [Parameter(ValueFromRemainingArguments=$true)][string[]]$Arguments
)
Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
$RunnerRoot=Split-Path -Parent $MyInvocation.MyCommand.Path
$Root=[IO.Path]::GetFullPath((Join-Path $RunnerRoot '..\..'))
$SessionDir=$env:PMM_HOST_SESSION_DIR
function Emit([string]$Type,[string]$Message){Write-Output ((Get-Date).ToString('yyyy-MM-dd HH:mm:ss.fff')+' [PMMR]['+$Type+'] '+$Message)}
function State([string]$Value){if($SessionDir){try{Set-Content -LiteralPath (Join-Path $SessionDir 'state.txt') -Value $Value -Encoding UTF8}catch{}}}
try{
  if([string]::IsNullOrWhiteSpace($Operation)){$Operation='start'}
  $op=$Operation.Trim().ToLowerInvariant()
  if($op -notmatch '^[a-z0-9][a-z0-9._-]{0,63}$'){throw 'Invalid operation name: '+$Operation}
  $path=Join-Path $RunnerRoot ('Operations\\'+$op+'.ps1')
  if(-not(Test-Path -LiteralPath $path -PathType Leaf)){Emit 'REJECTED' ("Unknown operation '$op'. Add Runner\\Operations\\$op.ps1 to extend PMM."); exit 64}
  State ('runner:operation='+$op)
  Emit 'START' ('operation='+$op+' hostSession='+$env:PMM_HOST_SESSION_ID)
  & $path -Root $Root -Arguments @($Arguments) -SessionDir $SessionDir
  $rc=if($null -eq $LASTEXITCODE){0}else{[int]$LASTEXITCODE}
  if($rc -ne 0){State ('runner:failed operation='+$op+' exit='+$rc);Emit 'END' ('operation='+$op+' status=failed exit='+$rc);exit $rc}
  State ('runner:complete operation='+$op)
  Emit 'END' ('operation='+$op+' status=success exit=0');exit 0
}catch{State ('runner:exception '+$_.Exception.Message);Emit 'EXCEPTION' $_.Exception.Message;exit 1}
