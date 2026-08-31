param(
  [Parameter(Mandatory=$true)][string]$Root,
  [Parameter(Mandatory=$true)][string]$ProgressPath,
  [Parameter(Mandatory=$true)][string]$ResultPath
)

Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
$Script:Root=[IO.Path]::GetFullPath($Root)
. (Join-Path $Script:Root 'Modules\Shared\Paths.ps1')
Initialize-PMMPaths $Script:Root|Out-Null

. (Join-Path $Script:Root 'Modules\Shared\Common.ps1')
. (Join-Path $Script:Root 'Modules\Merge\PakService.ps1')
. (Join-Path $Script:Root 'Modules\GameReference\GameReferenceService.ps1')
Start-PMMLogSession 'Worker-GameReference'
Initialize-PMM

function Write-PMMWorkerJson([string]$Path,$Object){
  $dir=Split-Path -Parent $Path
  if($dir){New-Item -ItemType Directory -Force -Path $dir|Out-Null}
  $tmp=$Path+'.tmp'
  $Object|ConvertTo-Json -Depth 20|Set-Content -LiteralPath $tmp -Encoding UTF8
  Move-Item -LiteralPath $tmp -Destination $Path -Force
}

function Set-PMMGameReferenceProgress {
  param(
    [int]$Current=0,
    [int]$Total=100,
    [string]$Message='',
    [switch]$Indeterminate
  )
  Write-PMMWorkerJson $ProgressPath ([ordered]@{
    Schema='PMM_GAME_REFERENCE_PROGRESS_V1'
    Status='Running'
    Current=$Current
    Total=$Total
    Percent=if($Total -gt 0){[Math]::Max(0,[Math]::Min(100,[int][Math]::Round((100.0*$Current)/$Total)))}else{0}
    Indeterminate=[bool]$Indeterminate
    Message=$Message
    UpdatedUtc=[DateTime]::UtcNow.ToString('o')
  })
}

try{
  Set-PMMGameReferenceProgress -Current 0 -Total 100 -Message 'Starting Game Reference worker...'
  $state=Build-PMMGameReferenceLibrary
  Write-PMMWorkerJson $ResultPath ([ordered]@{
    Schema='PMM_GAME_REFERENCE_WORKER_RESULT_V1'
    Success=$true
    State=$state
    Error=''
    CompletedUtc=[DateTime]::UtcNow.ToString('o')
  })
  Set-PMMGameReferenceProgress -Current 100 -Total 100 -Message 'Game Reference ready.'
  Stop-PMMLogSession 'Normal'
  exit 0
}catch{
  $message=$_.Exception.Message
  try{Write-PMMLog ('Game Reference worker failed: '+$message)}catch{}
  try{Set-PMMGameReferenceProgress -Current 100 -Total 100 -Message ('Game Reference failed: '+$message)}catch{}
  Write-PMMWorkerJson $ResultPath ([ordered]@{
    Schema='PMM_GAME_REFERENCE_WORKER_RESULT_V1'
    Success=$false
    State=$null
    Error=$message
    CompletedUtc=[DateTime]::UtcNow.ToString('o')
  })
  Stop-PMMLogSession 'Failed'
  exit 1
}
