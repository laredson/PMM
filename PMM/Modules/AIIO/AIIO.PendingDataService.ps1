<#
AIIO requested-data batching, progress and partial fulfillment
=============================================================

Loaded after AIIO.ResponseService. This service replaces only the incremental
requested-data handoff function so CREATE_MOD can batch exact Game Reference
hydration, report request-level progress, and preserve successful evidence when
one independent request is unavailable. It never fabricates or aliases bytes.
#>

function Write-PMMAIIOPendingDataProgress([int]$Current,[int]$Total,[string]$Message,[switch]$Indeterminate) {
  $callback=Get-Command Write-PMMOperationProgress -ErrorAction SilentlyContinue
  if($callback){try{Write-PMMOperationProgress $Current $Total $Message ([bool]$Indeterminate)}catch{}}
}

function Get-PMMAIIORequestProgressDetail($Request) {
  $detail=''
  if(-not[string]::IsNullOrWhiteSpace([string]$Request.LogicalPath)){$detail=[IO.Path]::GetFileName([string]$Request.LogicalPath)}
  elseif(-not[string]::IsNullOrWhiteSpace([string]$Request.Query)){$detail=[string]$Request.Query}
  else{$detail=[string]$Request.Capability}
  if($detail.Length -gt 88){$detail=$detail.Substring(0,85)+'...'}
  return $detail
}

function New-PMMAIIOPendingDataHandoff {
  [CmdletBinding()]
  param([Parameter(Mandatory=$true)][string]$SessionId)
  $session=Get-PMMAIIOSession $SessionId
  if(-not$session){throw ('AIIO session not found: '+$SessionId)}
  $exportSession=Get-PMMAIIOExportSession $session
  $requests=@(Get-PMMAIIOPendingRequests $SessionId)
  if($requests.Count -eq 0){throw 'This session has no pending validated data requests.'}
  $iteration=[int]$session.Iteration+1
  $bundleId=Get-PMMStableTextId ('AIIO_INCREMENTAL|'+$SessionId+'|'+$iteration+'|'+((@($requests|ForEach-Object{[string]$_.RequestId}|Sort-Object)) -join '|'))
  $exportSession.Iteration=$iteration;$exportSession.LastBundleId=$bundleId;$exportSession.Status='WaitingForAI';$exportSession.OperationState='WaitingForAI'
  $requestDir=Join-Path (Get-PMMAIIOSessionPath $SessionId) ('requests\request-{0:D4}' -f $iteration);New-Item -ItemType Directory -Force -Path $requestDir|Out-Null
  $stage=Join-Path (Get-PMMPath 'Temp') ('AIIOData_'+[guid]::NewGuid().ToString('N'));$partial=$stage+'.zip.partial';$zip=Join-Path $requestDir ('PMM_AIIO_REQUEST_'+$SessionId+'_STEP_{0:D2}.zip' -f $iteration)
  $outboxCopy='';$committed=$false
  try{
    New-Item -ItemType Directory -Force -Path $stage|Out-Null
    Set-PMMTransientStageOwner $stage 'AIIOPendingData'
    Write-PMMAIIOSystemDocuments $stage $SessionId $bundleId $iteration
    Write-PMMAIIOJsonAtomic (Join-Path $stage 'PMM_CAPABILITIES.json') (Get-PMMAIIOCapabilityRegistry) 30
    Write-PMMAIIOJsonAtomic (Join-Path $stage 'session.json') $exportSession 40

    # CREATE_MOD often asks for several exact families after one broad search.
    # Hydrate all of those missing families in ONE selective repak pass before
    # the per-request export loop. The individual requests still keep their own
    # budgets and manifests; this only removes repeated 40 GiB PAK opens.
    $preFailures=@{};$validExact=[Collections.Generic.List[string]]::new();$validSeen=[Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach($request in @($requests|Where-Object{[string]$_.Capability -eq 'extract_game_reference_asset'})){
      $asset=Normalize-PMMReferenceLogicalPath ([string]$request.LogicalPath)
      try{[void](Get-PMMAIIOIndexedFamilyParts $asset);if($validSeen.Add($asset)){$validExact.Add($asset)}}catch{$preFailures[[string]$request.RequestId]=$_.Exception.Message}
    }
    if($validExact.Count -gt 0 -and (Get-Command Ensure-PMMAIIOGameReferenceFamiliesExact -ErrorAction SilentlyContinue)){
      Write-PMMAIIOPendingDataProgress -Current 0 -Total $requests.Count -Message (('Preparing {0} exact Vanilla Game Reference family/families in one PAK pass...' -f $validExact.Count)) -Indeterminate
      $batchWatch=[Diagnostics.Stopwatch]::StartNew()
      [void](Ensure-PMMAIIOGameReferenceFamiliesExact -LogicalPaths @($validExact.ToArray()))
      $batchWatch.Stop();Write-PMMLog ('AIIO exact Game Reference batch preparation completed in '+$batchWatch.Elapsed.ToString())
    }

    $failures=[Collections.Generic.List[object]]::new();$i=0
    foreach($request in $requests){
      $i++;$dest=Join-Path $stage ('data\request-{0:D3}-{1}' -f $i,[string]$request.RequestId);New-Item -ItemType Directory -Force -Path $dest|Out-Null
      $detail=Get-PMMAIIORequestProgressDetail $request
      Write-PMMAIIOPendingDataProgress -Current ($i-1) -Total $requests.Count -Message (('AIIO data {0}/{1}: {2} - {3}' -f $i,$requests.Count,[string]$request.Capability,$detail))
      $requestWatch=[Diagnostics.Stopwatch]::StartNew();$failureMessage=''
      if($preFailures.ContainsKey([string]$request.RequestId)){$failureMessage=[string]$preFailures[[string]$request.RequestId]}
      else{try{Export-PMMAIIORequestedData $request $dest $SessionId}catch{$failureMessage=$_.Exception.Message}}
      $requestWatch.Stop()
      if($failureMessage){
        $failure=[ordered]@{Schema='PMM_AIIO_REQUEST_FAILURE_V1';RequestId=[string]$request.RequestId;Capability=[string]$request.Capability;LogicalPath=[string]$request.LogicalPath;Query=[string]$request.Query;Required=[bool]$request.Required;Reason=$failureMessage;CreatedUtc=[DateTime]::UtcNow.ToString('o');Safety='No asset bytes were fabricated. Other independent requests in this handoff were allowed to continue.'}
        Write-PMMAIIOJsonAtomic (Join-Path $dest 'request-failure.json') $failure 20;$failures.Add([pscustomobject]$failure)
        Write-PMMLog ('AIIO requested data '+$i+'/'+$requests.Count+' '+[string]$request.Capability+' unavailable after '+$requestWatch.Elapsed.ToString()+': '+$failureMessage)
      }else{Write-PMMLog ('AIIO requested data '+$i+'/'+$requests.Count+' '+[string]$request.Capability+' completed in '+$requestWatch.Elapsed.ToString())}
      [int64]$actualBytes=0;foreach($file in @(Get-ChildItem -LiteralPath $dest -Recurse -File -ErrorAction SilentlyContinue)){$actualBytes+=[int64]$file.Length}
      if([int64]$request.MaximumExpectedBytes -gt 0 -and $actualBytes -gt [int64]$request.MaximumExpectedBytes){throw ('Requested data exceeded the declared per-request budget for '+[string]$request.Capability+'.')}
      Write-PMMAIIOPendingDataProgress -Current $i -Total $requests.Count -Message (('AIIO data {0}/{1} complete.' -f $i,$requests.Count))
    }
    Write-PMMAIIOPendingDataProgress -Current $requests.Count -Total $requests.Count -Message 'Packaging requested AIIO data...'
    $fulfillment=if($failures.Count -eq 0){'Complete'}else{'Partial'}
    Write-PMMAIIOJsonAtomic (Join-Path $stage 'request.json') ([ordered]@{Schema='PMM_AIIO_INCREMENTAL_REQUEST_V2';SessionId=$SessionId;BundleId=$bundleId;Iteration=$iteration;Fulfills=@($requests|ForEach-Object{[string]$_.RequestId});FulfillmentStatus=$fulfillment;Failures=@($failures.ToArray());CreatedUtc=[DateTime]::UtcNow.ToString('o')}) 30
    Write-PMMAIIOJsonAtomic (Join-Path $stage 'bundle.json') ([ordered]@{Schema='PMM_AI_HANDOFF_BUNDLE_V2';Protocol=2;SessionId=$SessionId;BundleId=$bundleId;Iteration=$iteration;Incremental=$true;WholeSourcePaksIncluded=$false;CreatedUtc=[DateTime]::UtcNow.ToString('o')}) 20
    $runtime=Get-PMMRuntimePath;$output=@(& $runtime archive create $partial $stage 2>&1|ForEach-Object{[string]$_})
    if($LASTEXITCODE -ne 0 -or -not(Test-Path -LiteralPath $partial -PathType Leaf)){throw ('Could not create incremental AIIO ZIP. '+($output -join ' '))}
    [void](Test-PMMAIIODataArchive $partial $SessionId $bundleId);Move-Item -LiteralPath $partial -Destination $zip -Force
    $outboxCopy=Join-Path (Get-PMMPath 'AIIOOutbox') ([IO.Path]::GetFileName($zip));Copy-Item -LiteralPath $zip -Destination $outboxCopy -Force
    $session.Iteration=$iteration;$session.LastBundleId=$bundleId;$session.Status='WaitingForAI';$session.AttentionRequired=$true;$session.OperationState='WaitingForAI';Save-PMMAIIOSession $session|Out-Null
    $committed=$true
    Write-PMMAIIOPendingDataProgress -Current $requests.Count -Total $requests.Count -Message 'AIIO requested-data package ready.'
    try{Add-PMMAIIOHistoryEvent -SessionId $SessionId -Event INCREMENTAL_HANDOFF_CREATED -Message ([IO.Path]::GetFileName($zip)) -Data ([ordered]@{BundleId=$bundleId;RequestCount=$requests.Count;Sha256=(Get-Sha256 $zip)})|Out-Null}catch{Write-PMMLog ('AIIO incremental history warning: '+$_.Exception.Message)}
    return [pscustomobject]@{SessionId=$SessionId;BundleId=$bundleId;Iteration=$iteration;ZipPath=$zip;RequestCount=$requests.Count;ZipSha256=(Get-Sha256 $zip)}
  }catch{
    if(-not$committed){if($outboxCopy){Remove-Item -LiteralPath $outboxCopy -Force -ErrorAction SilentlyContinue};Remove-Item -LiteralPath $requestDir -Recurse -Force -ErrorAction SilentlyContinue}
    throw
  }finally{Remove-Item -LiteralPath $stage -Recurse -Force -ErrorAction SilentlyContinue;Remove-PMMTransientStageOwner $stage;Remove-Item -LiteralPath $partial -Force -ErrorAction SilentlyContinue}
}
