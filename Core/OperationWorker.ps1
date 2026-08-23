param(
  [Parameter(Mandatory=$true)][string]$Root,
  [Parameter(Mandatory=$true)][ValidateSet('Analyze','Build')][string]$Operation,
  [Parameter(Mandatory=$true)][string]$ProgressPath,
  [Parameter(Mandatory=$true)][string]$ResultPath,
  [switch]$Force,
  [ValidateSet('ConflictGroups')][string]$Mode='ConflictGroups'
)

Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
$Script:Root=[IO.Path]::GetFullPath($Root)

# Load the same non-UI services as the WPF front-end. The worker owns no WPF
# objects and communicates only through atomic JSON files in Cache.
. (Join-Path $Script:Root 'Core\Common.ps1')
. (Join-Path $Script:Root 'Core\GameLocator.ps1')
. (Join-Path $Script:Root 'Core\PakService.ps1')
. (Join-Path $Script:Root 'Core\LibraryService.ps1')
. (Join-Path $Script:Root 'Core\SaveService.ps1')
. (Join-Path $Script:Root 'Core\SemanticLab.ps1')
. (Join-Path $Script:Root 'Core\GameReferenceService.ps1')
. (Join-Path $Script:Root 'Core\KnowledgeRecipeService.ps1')
. (Join-Path $Script:Root 'Core\MergeEngine.ps1')
. (Join-Path $Script:Root 'Core\KnowledgeContributionService.ps1')
Start-PMMLogSession ('Worker-'+$Operation)
Initialize-PMM

function Write-PMMOperationWorkerJson([string]$Path,$Object){
  $dir=Split-Path -Parent $Path
  if($dir){New-Item -ItemType Directory -Force -Path $dir|Out-Null}
  $tmp=$Path+'.tmp'
  $Object|ConvertTo-Json -Depth 30|Set-Content -LiteralPath $tmp -Encoding UTF8
  Move-Item -LiteralPath $tmp -Destination $Path -Force
}

function Write-PMMOperationProgress([int]$Current,[int]$Total,[string]$Message,[bool]$Indeterminate){
  $percent=if($Total -gt 0){[Math]::Max(0,[Math]::Min(100,[int][Math]::Round((100.0*$Current)/$Total)))}else{0}
  Write-PMMOperationWorkerJson $ProgressPath ([ordered]@{
    Schema='PMM_BACKGROUND_OPERATION_PROGRESS_V1'
    Operation=$Operation
    Status='Running'
    Current=$Current
    Total=$Total
    Percent=$percent
    Indeterminate=$Indeterminate
    Message=$Message
    UpdatedUtc=[DateTime]::UtcNow.ToString('o')
  })
}

function Set-PMMAnalyzeProgress {
  param([int]$Current,[int]$Total,[string]$Message,[switch]$Indeterminate)
  Write-PMMOperationProgress $Current $Total $Message ([bool]$Indeterminate)
}

function Set-PMMBuildProgress {
  param([int]$Current,[int]$Total,[string]$Message,[switch]$Indeterminate)
  Write-PMMOperationProgress $Current $Total $Message ([bool]$Indeterminate)
}

try{
  Write-PMMOperationProgress 0 0 ($(if($Operation -eq 'Analyze'){'Starting Analyze in background...'}else{'Starting Build in background...'})) $true

  $resultText=''
  if($Operation -eq 'Analyze'){
    $result=Invoke-PMMScan -Force:$Force
    if($result -and $result.PSObject.Properties.Name -contains 'Summary'){
      $resultText=[string]$result.Summary
    }else{
      $resultText='Analyze completed.'
    }
  }else{
    $resultText=[string](Build-PMMMerge -Mode $Mode)
  }

  Write-PMMOperationWorkerJson $ResultPath ([ordered]@{
    Schema='PMM_BACKGROUND_OPERATION_RESULT_V1'
    Operation=$Operation
    Success=$true
    ResultText=$resultText
    Error=''
    CompletedUtc=[DateTime]::UtcNow.ToString('o')
  })
  Write-PMMOperationProgress 1 1 ($(if($Operation -eq 'Analyze'){'Analyze complete.'}else{'Build complete.'})) $false
  Stop-PMMLogSession 'Normal'
  exit 0
}catch{
  $message=$_.Exception.Message
  try{Write-PMMLog ("Worker {0} failed: {1}" -f $Operation,$message)}catch{}
  try{Write-PMMOperationProgress 1 1 (($Operation+' failed: ')+$message) $false}catch{}
  Write-PMMOperationWorkerJson $ResultPath ([ordered]@{
    Schema='PMM_BACKGROUND_OPERATION_RESULT_V1'
    Operation=$Operation
    Success=$false
    ResultText=''
    Error=$message
    CompletedUtc=[DateTime]::UtcNow.ToString('o')
  })
  Stop-PMMLogSession 'Failed'
  exit 1
}
