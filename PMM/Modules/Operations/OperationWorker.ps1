param(
  [Parameter(Mandatory=$true)][string]$Root,
  [Parameter(Mandatory=$true)][ValidateSet('Analyze','Build','AIHandoff','AIIOPrepare','AIIOPendingData','AIIOImportResponse','AIIOUseCandidate','AIIOModBuild','AIIOArtifactRefresh','FixLabBuild','MappingsImport','DeepAnalysis','DeepCase','DeepSource','UpdateCheck','UpdateApply','UpdateRestore','Recovery')][string]$Operation,
  [Parameter(Mandatory=$true)][string]$ProgressPath,
  [Parameter(Mandatory=$true)][string]$ResultPath,
  [switch]$Force,
  [switch]$AllowOversize,
  [ValidateSet('ConflictGroups')][string]$Mode='ConflictGroups',
  [string]$SessionId='',
  [string]$InputZip='',
  [string]$MappingsFile='',
  [string]$RequestPath='',
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
. (Join-Path $Script:Root 'Modules\AIIO\AIIO.ModCreationService.ps1')
. (Join-Path $Script:Root 'Modules\AIIO\AIIO.ResponseService.ps1')
. (Join-Path $Script:Root 'Modules\AIIO\AIIO.ArtifactService.ps1')
. (Join-Path $Script:Root 'Modules\CKL\KnowledgeContributionService.ps1')
if($Operation -eq 'FixLabBuild'){
  . (Join-Path $Script:Root 'Modules\FixLab\FixLabService.ps1')
}
. (Join-Path $Script:Root 'Modules/MCP/MCP.Service.ps1')
. (Join-Path $Script:Root 'Modules/Workbench.Services.ps1') -Profile Worker
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
$journalId='';$moduleLease=$null
try{
  # All heavy operations share one coherent Workspace/State snapshot. Serialize
  # them across separate PMM windows and workers. The WPF process remains free
  # to navigate and render while this child owns the operation slot.
  $operationLockPath=Join-PMMPath 'Cache' 'PMM.background-operation.lock'
  if($Operation -ne 'Recovery'){try{$operationLockStream=[IO.File]::Open($operationLockPath,[IO.FileMode]::OpenOrCreate,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)}catch{
    throw 'Another PMM processing operation is already running for this installation.'
  }}
  $journalTarget=if($Operation -eq 'FixLabBuild'){$FixLabJobId}elseif($Operation -in @('AIIOPrepare','AIIOPendingData','AIIOImportResponse','AIIOUseCandidate','AIIOModBuild')){$SessionId}else{'Workspace'}
  $journalId=Start-PMMJournalOperation -Kind $Operation -Target $journalTarget -Metadata ([ordered]@{Force=[bool]$Force;Mode=$Mode;WorkerProcessId=$PID;SessionId=$SessionId;SolutionId=$SolutionId})

  $moduleLease=Start-PMMModuleOperation $Operation
  $startMessage=switch($Operation){
    'MappingsImport' {'Selecting local mappings...'}
    'Analyze' {'Starting Analyze in background...'}
    'Build' {'Starting Build in background...'}
    'AIHandoff' {'Creating one AIIO handoff bundle for the current Unsupported set...'}
    'AIIOPrepare' {'Preparing the selected AIIO session in the background...'}
    'AIIOPendingData' {'Preparing validated requested data in the background...'}
    'AIIOImportResponse' {'Validating the AIIO response in the background...'}
    'AIIOUseCandidate' {'Validating the selected staged candidate in the background...'}
    'AIIOModBuild' {'Building the selected standalone mod candidate without deploying it...'}
    'AIIOArtifactRefresh' {'Refreshing the local artifact inventory in the background...'}
    'FixLabBuild' {'Starting Fix Lab repair in background...'}
    'UpdateCheck' {'Checking mod updates...'}
    'UpdateApply' {'Downloading, analyzing and applying safe updates...'}
    'UpdateRestore' {'Restoring the archived mod version...'}
  }
  Write-PMMOperationProgress 0 0 $startMessage $true
  Write-PMMJournalStep -OperationId $journalId -Kind $Operation -Step 'WorkerStarted' -Status Running

  $resultText=''
  $extra=[ordered]@{}
  if($Operation -in @('UpdateCheck','UpdateApply','UpdateRestore')){
    [void](Assert-PMMRecoveryPath $RequestPath (Join-PMMPath 'Cache' 'UpdateRequests') -DirectChild)
    $request=Read-PMMJsonFile $RequestPath
    if($Operation -eq 'UpdateCheck'){
      $plan=Invoke-PMMUpdateCheck
      $extra['PlanPath']=Get-PMMUpdatePlanPath;$extra['UpdateCount']=@($plan.Results|Where-Object{$_.Status -eq 'UPDATE_AVAILABLE'}).Count
      $resultText='Update check complete: '+$extra['UpdateCount']+' candidate(s).'
    }elseif($Operation -eq 'UpdateApply'){
      $plan=Read-PMMUpdatePlan;if(-not$plan -or -not$plan.IsCurrent){throw 'The update plan is stale.'}
      $applied=0;$skipped=0;$waiting=0;$deferred=[Collections.Generic.List[object]]::new()
      $resumeItems=@(Get-PMMAnalysisValue $request 'DeferredItems' @())
      if($resumeItems.Count){
        foreach($item in $resumeItems){
          $candidate=$null
          try{
            $currentPlan=Read-PMMUpdatePlan;if(-not$currentPlan -or -not$currentPlan.IsCurrent -or [string]$currentPlan.Id -cne [string]$plan.Id){throw 'The deferred update plan is stale.'}
            $update=@($currentPlan.Results|Where-Object{[string]$_.LocalSha256 -ceq [string]$item.LocalSha256 -and $_.Status -eq 'UPDATE_AVAILABLE'}|Select-Object -First 1);if(-not$update.Count){$skipped++;continue}
            $candidatePath=Assert-PMMRecoveryPath ([string]$item.CandidatePath) (Join-Path (Get-PMMUpdateRoot) 'Candidates')
            if([IO.Path]::GetFileName($candidatePath) -cne 'candidate.json'){throw 'Deferred candidate path is invalid.'}
            $candidate=Read-PMMJsonFile $candidatePath -Schema PMM_MOD_UPDATE_CANDIDATE_V2
            if([string]$candidate.OriginalSha256 -cne [string]$item.LocalSha256){throw 'Deferred candidate identity changed.'}
            if([string]$candidate.LibraryFingerprint -cne (Get-PMMUpdateFingerprint)){$candidate=Test-PMMUpdateCandidate $update ([pscustomobject]@{Path=[string]$candidate.ArchivePath;Sha256=[string]$candidate.ArchiveSha256})}
            if([bool]$request.Auto -and -not$candidate.AutomaticEligible){$skipped++;continue}
            $transaction=Invoke-PMMUpdateApply $candidate -Auto:([bool]$request.Auto);Update-PMMUpdatePlanAfterApply $candidate $transaction;$applied++
          }catch{
            if($_.Exception.Message -eq 'GAME_RUNNING_DEFERRED' -and $candidate){$deferred.Add([pscustomobject]@{LocalSha256=[string]$item.LocalSha256;CandidatePath=[string]$candidate.CandidatePath});continue}
            if([bool]$request.Auto){$skipped++;Write-PMMLog ('AUTO skipped deferred update '+[string]$item.LocalSha256+': '+$_.Exception.Message);continue}
            throw
          }
        }
      }else{
        $selected=@($plan.Results|Where-Object{$_.Status -eq 'UPDATE_AVAILABLE' -and ($request.LocalSha256 -eq '*' -or $_.LocalSha256 -eq $request.LocalSha256)})
        foreach($update in $selected){
          $candidate=$null
          try{
            $nxm=@(Receive-PMMNxmQueue ([string]$update.Origin.ModId) ([string]$update.Candidate.FileId)|Select-Object -First 1)
            $download=Receive-PMMUpdateArchive $update $(if($nxm.Count){$nxm[0]}else{$null})
            $candidate=Test-PMMUpdateCandidate $update $download
            if([bool]$request.Auto -and -not$candidate.AutomaticEligible){$skipped++;continue}
            $transaction=Invoke-PMMUpdateApply $candidate -Auto:([bool]$request.Auto);Update-PMMUpdatePlanAfterApply $candidate $transaction;$applied++
          }catch{
            if($_.Exception.Message -in @('NEXUS_WEB_CONFIRMATION_REQUIRED','AUTHENTICATION_REQUIRED')){$waiting++;continue}
            if($_.Exception.Message -eq 'GAME_RUNNING_DEFERRED' -and $candidate){$deferred.Add([pscustomobject]@{LocalSha256=[string]$update.LocalSha256;CandidatePath=[string]$candidate.CandidatePath});continue}
            if([bool]$request.Auto){$skipped++;Write-PMMLog ('AUTO skipped update for '+$update.Mod+': '+$_.Exception.Message);continue}
            throw
          }
        }
      }
      $extra['Applied']=$applied;$extra['Skipped']=$skipped;$extra['Waiting']=$waiting;$extra['Deferred']=$deferred.Count
      if($deferred.Count){Set-PMMPendingUpdateApply ([string]$plan.Id) $deferred.ToArray() ([bool]$request.Auto)}else{Clear-PMMPendingUpdateApply}
      Write-PMMJsonAtomic (Join-PMMPath 'State' 'update-attempt.json') ([ordered]@{Schema='PMM_UPDATE_ATTEMPT_V1';PlanId=$plan.Id;Applied=$applied;Skipped=$skipped;Waiting=$waiting;Deferred=$deferred.Count;CompletedUtc=[DateTime]::UtcNow.ToString('o')})
      $resultText='Updates complete: applied='+$applied+', skipped='+$skipped+', waiting='+$waiting+', deferred='+$deferred.Count+'.'
    }else{
      $restored=Restore-PMMArchivedUpdate ([string]$request.TransactionId);$extra['TransactionId']=[string]$restored.Id;$resultText='Archived mod version restored.'
    }
  }elseif($Operation -eq 'Recovery'){
    $recovered=@(Invoke-PMMDeploymentRecovery)
    $blocked=@($recovered|Where-Object{-not$_.Recovered})
    if($blocked.Count){throw (($blocked|ForEach-Object{$_.Error}) -join '; ')}
    $resultText='Deployment recovery complete; external changes were preserved.'
  }elseif($Operation -in @('DeepAnalysis','DeepCase','DeepSource')){
    [void](Assert-PMMRecoveryPath $RequestPath (Join-PMMPath 'Cache' 'DeepRequests') -DirectChild)
    $request=Read-PMMJsonFile $RequestPath
    if($Operation -eq 'DeepAnalysis'){
      $result=Invoke-PMMDeepAnalysis $request.Options
      $extra['AnalysisId']=$result.Id;$extra['RepairSessionId']=$result.RepairSessionId
      $resultText=$result.Summary
    }elseif($Operation -eq 'DeepCase'){
      $case=New-PMMCaseFromDeepAnalysis $request.AnalysisId @($request.FindingIds) ([string](Get-PMMAnalysisValue $request ExistingCaseId ''))
      if(Get-PMMAnalysisValue $request StartRepair $false){
        $options=$request.Options;$options.AutomaticSolution=$true
        $session=New-PMMRepairSession $case.CaseId $options;if((Get-PMMCaseClient $case) -eq 'CODEX' -and (Get-PMMAnalysisValue (Get-PMMAIPolicy) InternalEnabled $false)){Start-PMMRepairAgentJob $session.Id|Out-Null}else{$session.LastMessage='Continue this case in Desktop; internal AI is disabled.';Save-PMMRepairSession $session}
        $extra['RepairSessionId']=$session.Id
        $viewPath=Join-Path (Get-PMMAnalysisPath $request.AnalysisId) 'view.json'
        $view=Read-PMMJsonFile $viewPath;$view.CaseId=$case.CaseId;$view.RepairSessionId=$session.Id;Write-PMMJsonAtomic $viewPath $view -Depth 20
      }
      $extra['CaseId']=$case.CaseId;$resultText='Persistent case created: '+$case.CaseId
    }elseif((Get-PMMAnalysisValue $request Action '') -eq 'ReadConversation'){
      $chat=Sync-PMMCaseChat ([string]$request.CaseId)
      $resultText=$chat.ResultText
    }elseif((Get-PMMAnalysisValue $request Action '') -eq 'RefreshAI'){
      $client=$null
      try{
        $client=Start-PMMAppServer
        Invoke-PMMAppServerRequest $client initialize @{clientInfo=@{name='pmm';version='1.3.3'};capabilities=@{experimentalApi=$true}}|Out-Null
        Send-PMMAppServer $client initialized @{} -Notification
        $capabilities=Get-PMMAICapabilities $client
        $resultText='AI plan: '+$capabilities.Plan+'; '+$capabilities.Models.Count+' models. No inference request was sent.'
      }finally{Stop-PMMAppServer $client}
    }else{
      $mod=Find-PMMLibraryMod $request.ModName
      if(-not$mod){throw 'Mod no longer exists.'}
      Set-PMMModOrigin $mod $request.Origin;$resultText='Update source saved. / Origen guardado.'
    }
  }elseif($Operation -eq 'MappingsImport'){
    $selection=Import-PMMLocalMappings $MappingsFile
    $resultText='Mappings selected ('+[string]$selection.Mode+'). Run Analyze again.'
  }elseif($Operation -eq 'Analyze'){
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
  }elseif($Operation -eq 'AIIOModBuild'){
    if(-not(Test-PMMAIIOSessionId $SessionId)){throw 'AIIOModBuild requires a valid persistent session id.'}
    if($SolutionId -notmatch '^[a-f0-9]{64}$'){throw 'AIIOModBuild requires an exact candidate solution id.'}
    $built=Build-PMMAIIOModCandidate -SessionId $SessionId -SolutionId $SolutionId
    $resultText='Standalone mod PAK built locally and left undeployed.'
    $extra['SessionId']=$SessionId
    $extra['SolutionId']=$SolutionId
    $extra['OutputPath']=[string]$built.OutputPath
    $extra['OutputDirectory']=[string]$built.OutputDirectory
    $extra['FileName']=[string]$built.FileName
    $extra['PakSha256']=[string]$built.PakSha256
    $extra['PakBytes']=[int64]$built.PakBytes
    $extra['Status']=[string]$built.Status
    $extra['AttributionEntry']=[string]$built.AttributionEntry
    $extra['RequiredPublicDescription']=[string]$built.RequiredPublicDescription
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
    'AIIOModBuild' {'Standalone mod PAK built locally and left undeployed.'}
    'AIIOArtifactRefresh' {'Local artifact inventory refreshed.'}
    'FixLabBuild' {'Fix Lab repair build complete.'}
    'UpdateCheck' {'Update check complete.'}
    'UpdateApply' {'Safe update batch complete.'}
    'UpdateRestore' {'Archived version restored.'}
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
  if($moduleLease){Complete-PMMModuleOperation $moduleLease.Id}
  try{if($operationLockStream){$operationLockStream.Dispose()}}catch{}
}
