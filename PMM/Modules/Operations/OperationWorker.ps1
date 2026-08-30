param(
  [Parameter(Mandatory=$true)][string]$Root,
  [Parameter(Mandatory=$true)][ValidateSet('Analyze','Build','AIHandoff','AIIOPrepare','AIIOPendingData','AIIOImportResponse','AIIOUseCandidate','AIIOArtifactRefresh','FixLabBuild')][string]$Operation,
  [Parameter(Mandatory=$true)][string]$ProgressPath,
  [Parameter(Mandatory=$true)][string]$ResultPath,
  [switch]$Force,
  [switch]$AllowOversize,
  [ValidateSet('ConflictGroups')][string]$Mode='ConflictGroups',
  [string]$SessionId='',
  [string]$InputZip='',
  [string]$SolutionId='',
  [string]$FixLabJobId='',
  [string]$FixLabRecipeId='',
  [string]$FixLabVariantId=''
)

Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
# Processing jobs are deliberately lower priority than the WPF UI. Child
# processes such as PMMFixLab/repak inherit this class on Windows, preventing
# CPU-heavy repair work from starving navigation and rendering.
try{[System.Diagnostics.Process]::GetCurrentProcess().PriorityClass=[System.Diagnostics.ProcessPriorityClass]::BelowNormal}catch{}
$Script:Root=[IO.Path]::GetFullPath($Root)
. (Join-Path $Script:Root 'Modules\Shared\Paths.ps1')
Initialize-PMMPaths $Script:Root|Out-Null

# Load the same non-UI services as the WPF front-end. The worker owns no WPF
# objects and communicates only through atomic JSON files in Cache.
. (Join-Path $Script:Root 'Modules\Shared\Common.ps1')
. (Join-Path $Script:Root 'Modules\Operations\OperationJournal.ps1')
. (Join-Path $Script:Root 'Modules\Shared\GameLocator.ps1')
. (Join-Path $Script:Root 'Modules\Merge\PakService.ps1')
. (Join-Path $Script:Root 'Modules\Library\LibraryService.ps1')
. (Join-Path $Script:Root 'Modules\Saves\SaveService.ps1')
. (Join-Path $Script:Root 'Modules\CKL\SemanticLab.ps1')
. (Join-Path $Script:Root 'Modules\GameReference\GameReferenceService.ps1')
. (Join-Path $Script:Root 'Modules\CKL\KnowledgeRecipeService.ps1')
. (Join-Path $Script:Root 'Modules\Merge\MergeEngine.ps1')
. (Join-Path $Script:Root 'Modules\AIIO\AIIO.ps1')
. (Join-Path $Script:Root 'Modules\AIIO\AIIO.SessionService.ps1')
. (Join-Path $Script:Root 'Modules\Saves\SaveActivityService.ps1')
. (Join-Path $Script:Root 'Modules\AIIO\AIIO.DiagnosticService.ps1')
. (Join-Path $Script:Root 'Modules\AIIO\AIIO.ResponseService.ps1')
. (Join-Path $Script:Root 'Modules\AIIO\AIIO.ArtifactService.ps1')
. (Join-Path $Script:Root 'Modules\CKL\KnowledgeContributionService.ps1')
if($Operation -eq 'FixLabBuild'){
  . (Join-Path $Script:Root 'Modules\FixLab\FixLabService.ps1')
}
Start-PMMLogSession ('Worker-'+$Operation)
Initialize-PMM
if($Operation -eq 'FixLabBuild'){Initialize-PMMFixLab}
$Script:WorkerFixLabJobId=[string]$FixLabJobId

function Write-PMMOperationWorkerJson([string]$Path,$Object){
  $dir=Split-Path -Parent $Path
  if($dir){New-Item -ItemType Directory -Force -Path $dir|Out-Null}
  $tmp=$Path+'.tmp'
  $Object|ConvertTo-Json -Depth 30|Set-Content -LiteralPath $tmp -Encoding UTF8
  Move-Item -LiteralPath $tmp -Destination $Path -Force
}

function Write-PMMOperationProgress([int]$Current,[int]$Total,[string]$Message,[bool]$Indeterminate){
  $percent=if($Total -gt 0){[Math]::Max(0,[Math]::Min(100,[int][Math]::Round((100.0*$Current)/$Total)))}else{0}
  $payload=[ordered]@{
    Schema='PMM_BACKGROUND_OPERATION_PROGRESS_V2'
    Operation=$Operation
    Status='Running'
    Current=$Current
    Total=$Total
    Percent=$percent
    Indeterminate=$Indeterminate
    Message=$Message
    UpdatedUtc=[DateTime]::UtcNow.ToString('o')
  }
  if($Operation -eq 'FixLabBuild' -and -not[string]::IsNullOrWhiteSpace([string]$Script:WorkerFixLabJobId)){$payload['JobId']=[string]$Script:WorkerFixLabJobId}
  Write-PMMOperationWorkerJson $ProgressPath $payload
}

function Set-PMMAnalyzeProgress {
  param([int]$Current,[int]$Total,[string]$Message,[switch]$Indeterminate)
  Write-PMMOperationProgress $Current $Total $Message ([bool]$Indeterminate)
}

function Set-PMMBuildProgress {
  param([int]$Current,[int]$Total,[string]$Message,[switch]$Indeterminate)
  Write-PMMOperationProgress $Current $Total $Message ([bool]$Indeterminate)
}

function Set-PMMFixLabProgress {
  param([int]$Current,[int]$Total,[string]$Message,[switch]$Indeterminate)
  Write-PMMOperationProgress $Current $Total $Message ([bool]$Indeterminate)
}

$operationLockStream=$null
$journalId=''
try{
  # All heavy operations share one coherent Workspace/State snapshot. Serialize
  # them across separate PMM windows and workers. The WPF process remains free
  # to navigate and render while this child owns the operation slot.
  $operationLockPath=Join-PMMPath 'Cache' 'PMM.background-operation.lock'
  try{$operationLockStream=[IO.File]::Open($operationLockPath,[IO.FileMode]::OpenOrCreate,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)}catch{
    throw 'Another PMM processing operation is already running for this installation.'
  }
  $journalTarget=if($Operation -eq 'FixLabBuild'){$FixLabJobId}elseif($Operation -in @('AIIOPrepare','AIIOPendingData','AIIOImportResponse','AIIOUseCandidate')){$SessionId}else{'Workspace'}
  $journalId=Start-PMMJournalOperation -Kind $Operation -Target $journalTarget -Metadata ([ordered]@{Force=[bool]$Force;Mode=$Mode;WorkerProcessId=$PID;SessionId=$SessionId;SolutionId=$SolutionId})

  $startMessage=switch($Operation){
    'Analyze' {'Starting Analyze in background...'}
    'Build' {'Starting Build in background...'}
    'AIHandoff' {'Creating one AIIO handoff bundle for the current Unsupported set...'}
    'AIIOPrepare' {'Preparing the selected AIIO session in the background...'}
    'AIIOPendingData' {'Preparing validated requested data in the background...'}
    'AIIOImportResponse' {'Validating the AIIO response in the background...'}
    'AIIOUseCandidate' {'Validating the selected staged candidate in the background...'}
    'AIIOArtifactRefresh' {'Refreshing the local artifact inventory in the background...'}
    'FixLabBuild' {'Starting Fix Lab repair in background...'}
  }
  Write-PMMOperationProgress 0 0 $startMessage $true
  Write-PMMJournalStep -OperationId $journalId -Kind $Operation -Step 'WorkerStarted' -Status Running

  $resultText=''
  $extra=[ordered]@{}
  if($Operation -eq 'Analyze'){
    $result=Invoke-PMMScan -Force:$Force
    if($result -and $result.PSObject.Properties.Name -contains 'Summary'){$resultText=[string]$result.Summary}else{$resultText='Analyze completed.'}
  }elseif($Operation -eq 'Build'){
    $resultText=[string](Build-PMMMerge -Mode $Mode)
  }elseif($Operation -eq 'AIHandoff'){
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
  }elseif($Operation -eq 'AIIOPrepare'){
    if(-not(Test-PMMAIIOSessionId $SessionId)){throw 'AIIOPrepare requires a valid persistent session id.'}
    $handoff=New-PMMAIIOGenericHandoff -SessionId $SessionId -IncludeSanitizedLog
    $resultText='AIIO request ready: '+[string]$handoff.ZipPath
    $extra['SessionId']=[string]$handoff.SessionId
    $extra['BundleId']=[string]$handoff.BundleId
    $extra['Iteration']=[int]$handoff.Iteration
    $extra['ZipPath']=[string]$handoff.ZipPath
    $extra['OutboxPath']=[string]$handoff.OutboxPath
    $extra['ZipSha256']=[string]$handoff.ZipSha256
    $extra['ZipBytes']=[int64]$handoff.ZipBytes
  }elseif($Operation -eq 'AIIOPendingData'){
    if(-not(Test-PMMAIIOSessionId $SessionId)){throw 'AIIOPendingData requires a valid persistent session id.'}
    $handoff=New-PMMAIIOPendingDataHandoff -SessionId $SessionId
    $resultText='AIIO requested-data package ready: '+[string]$handoff.ZipPath
    $extra['SessionId']=[string]$handoff.SessionId
    $extra['BundleId']=[string]$handoff.BundleId
    $extra['Iteration']=[int]$handoff.Iteration
    $extra['ZipPath']=[string]$handoff.ZipPath
    $extra['RequestCount']=[int]$handoff.RequestCount
    $extra['ZipSha256']=[string]$handoff.ZipSha256
  }elseif($Operation -eq 'AIIOImportResponse'){
    if(-not(Test-PMMAIIOSessionId $SessionId)){throw 'AIIOImportResponse requires a valid persistent session id.'}
    if(-not(Test-Path -LiteralPath $InputZip -PathType Leaf)){throw 'AIIO response ZIP was not found.'}
    $imported=Import-PMMAIIOAnyResponseZip -ZipPath $InputZip -ExpectedSessionId $SessionId
    $resultText='AIIO response validated and staged.'
    $extra['SessionId']=[string]$imported.SessionId
    $extra['Status']=[string]$imported.Status
    $extra['RequestCount']=[int]$imported.RequestCount
    $extra['CandidateCount']=[int]$imported.CandidateCount
  }elseif($Operation -eq 'AIIOUseCandidate'){
    if(-not(Test-PMMAIIOSessionId $SessionId)){throw 'AIIOUseCandidate requires a valid persistent session id.'}
    if($SolutionId -notmatch '^[a-f0-9]{64}$'){throw 'AIIOUseCandidate requires an exact candidate solution id.'}
    $used=Use-PMMAIIOCandidateForMerge -SessionId $SessionId -SolutionId $SolutionId
    $resultText='AIIO candidate passed PMM validation and was submitted to Merge.'
    $extra['SessionId']=$SessionId
    $extra['SolutionId']=$SolutionId
    $extra['CaseId']=[string]$used.CaseId
    $extra['Asset']=[string]$used.Asset
  }elseif($Operation -eq 'AIIOArtifactRefresh'){
    $summary=Get-PMMArtifactStorageSummary -Refresh
    $resultText='Local artifact inventory refreshed.'
    $extra['ArtifactCount']=[int]$summary.ArtifactCount
    $extra['TotalBytes']=[int64]$summary.TotalBytes
  }else{
    Set-PMMFixLabProgress 2 100 'Opening Fix Lab and resolving the exact repair candidate...'
    if([string]::IsNullOrWhiteSpace($FixLabJobId)){
      if([string]::IsNullOrWhiteSpace($FixLabRecipeId) -or [string]::IsNullOrWhiteSpace($FixLabVariantId)){throw 'FixLabBuild requires either FixLabJobId or FixLabRecipeId + FixLabVariantId.'}
      $candidate=Get-PMMFixLabCandidateByRecipeId $FixLabRecipeId
      if(-not$candidate){throw ('Fix Lab candidate is no longer present for recipe: '+$FixLabRecipeId)}
      Set-PMMFixLabProgress 6 100 'Creating/synchronizing the Fix Lab job and exact source snapshot...'
      $prepared=Ensure-PMMFixLabJobForCandidate $candidate -Analyze
      $FixLabJobId=[string]$prepared.JobId
      $Script:WorkerFixLabJobId=$FixLabJobId
      Set-PMMFixLabSelection $FixLabJobId $FixLabRecipeId $FixLabVariantId|Out-Null
    }elseif(-not[string]::IsNullOrWhiteSpace($FixLabVariantId)){
      $existing=Get-PMMFixLabJob $FixLabJobId
      $recipeId=if(-not[string]::IsNullOrWhiteSpace($FixLabRecipeId)){$FixLabRecipeId}else{[string]$existing.SelectedRecipeId}
      Set-PMMFixLabSelection $FixLabJobId $recipeId $FixLabVariantId|Out-Null
    }
    $Script:WorkerFixLabJobId=[string]$FixLabJobId
    Set-PMMFixLabProgress 10 100 'Validating exact sources and starting the native recipe...'
    $job=Invoke-PMMFixLabBuild -JobId $FixLabJobId
    if(-not$job -or -not$job.Build -or [string]$job.Build.Status -ne 'Built'){throw 'Fix Lab worker completed without a Built job result.'}
    $resultText='Fix Lab repair built: '+[string]$job.Build.OutputPath
    $extra['JobId']=[string]$job.JobId
    $extra['OutputPath']=[string]$job.Build.OutputPath
    $extra['OutputSha256']=[string]$job.Build.OutputSha256
    $extra['RecipeId']=[string]$job.Build.RecipeId
    $extra['VariantId']=[string]$job.Build.VariantId
    $extra['Validation']=[string]$job.Build.Validation
    if($job.Build.PSObject.Properties.Name -contains 'ReportPath'){$extra['ReportPath']=[string]$job.Build.ReportPath}
    $recipe=Get-PMMFixLabRecipe ([string]$job.Build.RecipeId)
    $caseId=if($recipe -and ($recipe.PSObject.Properties.Name -contains 'caseId')){[string]$recipe.caseId}else{[string]$job.Build.RecipeId}
    $extra['BuildId']=$caseId+'__'+[string]$job.Build.VariantId
  }

  $payload=[ordered]@{
    Schema='PMM_BACKGROUND_OPERATION_RESULT_V2'
    Operation=$Operation
    Success=$true
    ResultText=$resultText
    Error=''
    CompletedUtc=[DateTime]::UtcNow.ToString('o')
  }
  foreach($key in $extra.Keys){$payload[$key]=$extra[$key]}
  Write-PMMOperationWorkerJson $ResultPath $payload
  try{Complete-PMMJournalOperation -OperationId $journalId -Kind $Operation -Metadata ([ordered]@{ResultText=$resultText;ResultKeys=@($extra.Keys)})}catch{Write-PMMLog ('Worker result committed but journal completion failed: '+$_.Exception.Message)}

  $doneMessage=switch($Operation){
    'Analyze' {'Analyze complete.'}
    'Build' {'Build complete.'}
    'AIHandoff' {'AI handoff ready.'}
    'AIIOPrepare' {'AIIO request ready.'}
    'AIIOPendingData' {'AIIO requested-data package ready.'}
    'AIIOImportResponse' {'AIIO response validated.'}
    'AIIOUseCandidate' {'AIIO candidate validated for Merge.'}
    'AIIOArtifactRefresh' {'Local artifact inventory refreshed.'}
    'FixLabBuild' {'Fix Lab repair build complete.'}
  }
  Write-PMMOperationProgress 1 1 $doneMessage $false
  Stop-PMMLogSession 'Normal'
  exit 0
}catch{
  $message=$_.Exception.Message
  if($journalId){try{Fail-PMMJournalOperation -OperationId $journalId -Kind $Operation -Message $message}catch{}}
  try{Write-PMMLog ("Worker {0} failed: {1}" -f $Operation,$message)}catch{}
  try{Write-PMMOperationProgress 1 1 (($Operation+' failed: ')+$message) $false}catch{}
  Write-PMMOperationWorkerJson $ResultPath ([ordered]@{
    Schema='PMM_BACKGROUND_OPERATION_RESULT_V2'
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
