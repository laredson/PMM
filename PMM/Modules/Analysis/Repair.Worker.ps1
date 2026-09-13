param([Parameter(Mandatory=$true)][string]$Root,[Parameter(Mandatory=$true)][string]$SessionId)
Set-StrictMode -Version 2;$ErrorActionPreference='Stop'
$Script:Root=[IO.Path]::GetFullPath($Root)
$workerLock=$null
try{
  . (Join-Path $Script:Root 'Modules/Analysis/Services.ps1')
  $workerLock=Enter-PMMAnalysisLock (Join-Path (Get-PMMRepairSessionRoot $SessionId) 'worker.lock') 1
  $handshake=Enter-PMMAnalysisLock (Join-Path (Get-PMMRepairSessionRoot $SessionId) 'launch.lock')
  try{
    $s=Get-PMMRepairSession $SessionId;$s.OwnerPid=$PID;$s.OwnerStart=(Get-Process -Id $PID).StartTime.ToUniversalTime().ToString('o');$s.Status='Starting';Save-PMMRepairSession $s
  }finally{$handshake.Dispose()}
  Set-PMMMCPEnabled $true
  Invoke-PMMPersistentAgent $SessionId|Out-Null
}catch{
  $failure=$_
  if($workerLock -and (Get-Command Get-PMMRepairSession -ErrorAction SilentlyContinue)){
    try{$s=Get-PMMRepairSession $SessionId;if(-not$s.Revoked -and ($s.Status -ne 'Paused' -or -not$s.LastMessage)){$s.Status='Paused';$s.LastMessage=$failure.Exception.Message;Save-PMMRepairSession $s}}catch{}
  }
  [Console]::Error.WriteLine($failure.ToString());exit 1
}finally{if($workerLock){$workerLock.Dispose()}}
