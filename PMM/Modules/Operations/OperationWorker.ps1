param(
  [Parameter(Mandatory=$true)][string]$Root,
  [Parameter(Mandatory=$true)][ValidateSet('Analyze','Build','AIHandoff')][string]$Operation,
  [Parameter(Mandatory=$true)][string]$ProgressPath,
  [Parameter(Mandatory=$true)][string]$ResultPath,
  [switch]$Force,
  [switch]$AllowOversize,
  [ValidateSet('ConflictGroups')][string]$Mode='ConflictGroups'
)

Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
$Script:Root=[IO.Path]::GetFullPath($Root)
. (Join-Path $Script:Root 'Modules\Shared\Paths.ps1')
Initialize-PMMPaths $Script:Root|Out-Null

# Load the same non-UI services as the WPF front-end. The worker owns no WPF
# objects and communicates only through atomic JSON files in Cache.
. (Join-Path $Script:Root 'Modules\Shared\Common.ps1')
. (Join-Path $Script:Root 'Modules\Shared\GameLocator.ps1')
. (Join-Path $Script:Root 'Modules\Merge\PakService.ps1')
. (Join-Path $Script:Root 'Modules\Library\LibraryService.ps1')
. (Join-Path $Script:Root 'Modules\Saves\SaveService.ps1')
. (Join-Path $Script:Root 'Modules\CKL\SemanticLab.ps1')
. (Join-Path $Script:Root 'Modules\GameReference\GameReferenceService.ps1')
. (Join-Path $Script:Root 'Modules\CKL\KnowledgeRecipeService.ps1')
. (Join-Path $Script:Root 'Modules\Merge\MergeEngine.ps1')
. (Join-Path $Script:Root 'Modules\AIIO\AIIO.ps1')
. (Join-Path $Script:Root 'Modules\CKL\KnowledgeContributionService.ps1')
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

$operationLockStream=$null
try{
  # Analyze, Build and AIIO all depend on one coherent merge-plan/Review snapshot.
  # Serialize these writers/readers across separate PMM windows using the same root.
  $operationLockPath=Join-PMMPath 'Cache' 'PMM.background-operation.lock'
  try{$operationLockStream=[IO.File]::Open($operationLockPath,[IO.FileMode]::OpenOrCreate,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)}catch{
    throw 'Another PMM Analyze, Build, or AI handoff operation is already running for this installation.'
  }
  $startMessage=if($Operation -eq 'Analyze'){'Starting Analyze in background...'}elseif($Operation -eq 'Build'){'Starting Build in background...'}else{'Creating one AIIO handoff bundle for the current Unsupported set...'}
  Write-PMMOperationProgress 0 0 $startMessage $true

  $resultText=''
  $extra=[ordered]@{}
  if($Operation -eq 'Analyze'){
    $result=Invoke-PMMScan -Force:$Force
    if($result -and $result.PSObject.Properties.Name -contains 'Summary'){
      $resultText=[string]$result.Summary
    }else{
      $resultText='Analyze completed.'
    }
  }elseif($Operation -eq 'Build'){
    $resultText=[string](Build-PMMMerge -Mode $Mode)
  }else{
    $handoff=New-PMMAIHandoffBundle -AllowOversize:$AllowOversize -Force:$Force
    $resultText='AI handoff ready: '+[string]$handoff.ZipPath
    $extra['ZipPath']=[string]$handoff.ZipPath
    $extra['BundleId']=[string]$handoff.BundleId
    $extra['CaseCount']=[int]$handoff.CaseCount
    $extra['RawBytes']=[int64]$handoff.RawBytes
    if($handoff.PSObject.Properties.Name -contains 'UncompressedBytes'){$extra['UncompressedBytes']=[int64]$handoff.UncompressedBytes}
    $extra['ZipBytes']=[int64]$handoff.ZipBytes
    $extra['Existing']=[bool]$handoff.Existing
    if($handoff.PSObject.Properties.Name -contains 'OverSoftZipTarget'){$extra['OverSoftZipTarget']=[bool]$handoff.OverSoftZipTarget}else{$extra['OverSoftZipTarget']=([int64]$handoff.ZipBytes -gt [int64](512MB))}
  }

  $payload=[ordered]@{
    Schema='PMM_BACKGROUND_OPERATION_RESULT_V1'
    Operation=$Operation
    Success=$true
    ResultText=$resultText
    Error=''
    CompletedUtc=[DateTime]::UtcNow.ToString('o')
  }
  foreach($key in $extra.Keys){$payload[$key]=$extra[$key]}
  Write-PMMOperationWorkerJson $ResultPath $payload
  $doneMessage=if($Operation -eq 'Analyze'){'Analyze complete.'}elseif($Operation -eq 'Build'){'Build complete.'}else{'AI handoff ready.'}
  Write-PMMOperationProgress 1 1 $doneMessage $false
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
}finally{
  try{if($operationLockStream){$operationLockStream.Dispose()}}catch{}
}
