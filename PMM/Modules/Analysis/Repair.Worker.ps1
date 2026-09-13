param([Parameter(Mandatory=$true)][string]$Root,[Parameter(Mandatory=$true)][string]$SessionId)
Set-StrictMode -Version 2;$ErrorActionPreference='Stop'
$Script:Root=[IO.Path]::GetFullPath($Root)
. (Join-Path $Script:Root 'Modules/Analysis/Services.ps1')
Set-PMMMCPEnabled $true
$workerLock=$null
try{
  $workerLock=Enter-PMMAnalysisLock (Join-Path (Get-PMMRepairSessionRoot $SessionId) 'worker.lock') 1
  $s=Get-PMMRepairSession $SessionId;$s.OwnerPid=$PID;$s.OwnerStart=(Get-Process -Id $PID).StartTime.ToUniversalTime().ToString('o');$s.Status='Starting';Save-PMMRepairSession $s
  Invoke-PMMPersistentAgent $SessionId|Out-Null
}catch{Write-Error $_;exit 1}finally{if($workerLock){$workerLock.Dispose()}}
