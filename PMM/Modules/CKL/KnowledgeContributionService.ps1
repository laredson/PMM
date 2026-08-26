<#
PMM community Knowledge contribution packaging
==============================================

This service creates a portable evidence bundle after a user has tested an
accepted AI/manual solution in Palworld.  A contribution is evidence for review;
it NEVER self-promotes into a production recipe on the submitting machine.
#>

function Get-PMMKnowledgeContributionRoot {
  $root=Get-PMMPath 'KnowledgeContributions'
  if(-not(Test-Path -LiteralPath $root -PathType Container)){New-Item -ItemType Directory -Force -Path $root|Out-Null}
  return $root
}

function Find-PMMReviewFolderByCaseId([string]$CaseId) {
  $reviewRoot=Get-PMMPath 'Review'
  if(-not(Test-Path -LiteralPath $reviewRoot -PathType Container)){return ''}
  foreach($caseFile in @(Get-ChildItem -LiteralPath $reviewRoot -Filter case.json -File -Recurse -ErrorAction SilentlyContinue)){
    try{$case=Get-Content -LiteralPath $caseFile.FullName -Raw|ConvertFrom-Json}catch{continue}
    if([string]$case.CaseId -eq $CaseId){return $caseFile.Directory.FullName}
  }
  return ''
}

function Get-PMMKnowledgeContributionCandidates {
  $root=Get-PMMPath 'ManualSolutions'
  if(-not(Test-Path -LiteralPath $root -PathType Container)){return @()}
  $result=[System.Collections.Generic.List[object]]::new()
  foreach($dir in @(Get-ChildItem -LiteralPath $root -Directory -ErrorAction SilentlyContinue|Sort-Object Name)){
    $validationPath=Join-Path $dir.FullName 'validation.json'
    if(-not(Test-Path -LiteralPath $validationPath -PathType Leaf)){continue}
    try{$v=Get-Content -LiteralPath $validationPath -Raw|ConvertFrom-Json}catch{continue}
    if([string]$v.Schema -ne 'PMM_VALIDATED_MANUAL_SOLUTION_V1' -or -not [bool]$v.AcceptedExperimental){continue}
    $review=Find-PMMReviewFolderByCaseId ([string]$v.CaseId)
    $result.Add([pscustomobject]@{CaseId=[string]$v.CaseId;Asset=[string]$v.Asset;Imported=[string]$v.Imported;RuntimeStatus=[string]$v.RuntimeStatus;SolutionRoot=$dir.FullName;ReviewFolder=$review;Display=([string]$v.CaseId+'  |  '+[IO.Path]::GetFileName([string]$v.Asset))})
  }
  return $result.ToArray()
}

function New-PMMKnowledgeArchive([string]$SourceDirectory,[string]$OutputZip) {
  if(-not(Test-Path -LiteralPath $SourceDirectory -PathType Container)){throw ('Knowledge archive source directory is missing: '+$SourceDirectory)}
  $runtime=Get-PMMRuntimePath
  if(-not(Test-Path -LiteralPath $runtime -PathType Leaf)){throw 'PMMRuntime.exe is required to create Knowledge ZIPs.'}
  $partial=$OutputZip+'.partial'
  try{
    Remove-Item -LiteralPath $partial -Force -ErrorAction SilentlyContinue
    $output=@(& $runtime archive create $partial $SourceDirectory 2>&1|ForEach-Object{[string]$_})
    $exit=$LASTEXITCODE
    if($exit -ne 0 -or -not(Test-Path -LiteralPath $partial -PathType Leaf)){
      throw ('PMMRuntime archive create failed with exit '+$exit+'. '+($output -join ' '))
    }
    if([int64](Get-Item -LiteralPath $partial).Length -le 0){throw 'PMMRuntime created an empty Knowledge ZIP.'}
    Remove-Item -LiteralPath $OutputZip -Force -ErrorAction SilentlyContinue
    Move-Item -LiteralPath $partial -Destination $OutputZip -Force
  }finally{Remove-Item -LiteralPath $partial -Force -ErrorAction SilentlyContinue}
}

function New-PMMReconstructedSolutionZip([string]$SolutionRoot,[string]$OutputZip) {
  $stage=Join-Path (Get-PMMPath 'Cache') ('ContributionSolution_'+[guid]::NewGuid().ToString('N'))
  try{
    New-Item -ItemType Directory -Force -Path $stage|Out-Null
    Set-PMMTransientStageOwner $stage 'ContributionSolution'
    Copy-Item -LiteralPath (Join-Path $SolutionRoot 'solution.json') -Destination (Join-Path $stage 'solution.json') -Force
    Copy-Item -LiteralPath (Join-Path $SolutionRoot 'cooked') -Destination (Join-Path $stage 'cooked') -Recurse -Force
    New-PMMKnowledgeArchive $stage $OutputZip
  }finally{
    Remove-Item -LiteralPath $stage -Recurse -Force -ErrorAction SilentlyContinue
    Remove-PMMTransientStageOwner $stage
  }
}

function Export-PMMKnowledgeContribution([string]$CaseId,[string]$RuntimeNotes='') {
  if([string]::IsNullOrWhiteSpace($CaseId)){throw 'Contribution case ID is required.'}
  $solutionRoot=Join-Path (Get-PMMPath 'ManualSolutions') $CaseId
  $validationPath=Join-Path $solutionRoot 'validation.json'
  if(-not(Test-Path -LiteralPath $validationPath -PathType Leaf)){throw 'No validated manual/AI solution exists for this case.'}
  $validation=Get-Content -LiteralPath $validationPath -Raw|ConvertFrom-Json
  if([string]$validation.Schema -ne 'PMM_VALIDATED_MANUAL_SOLUTION_V1' -or -not [bool]$validation.AcceptedExperimental){throw 'The stored solution is not an accepted PMM manual/AI solution.'}
  foreach($part in @($validation.OutputFiles)){
    $p=Join-Path (Join-Path $solutionRoot 'cooked') ([string]$part.Name)
    if(-not(Test-Path -LiteralPath $p -PathType Leaf) -or (Get-Sha256 $p) -ne ([string]$part.Sha256).ToLowerInvariant()){throw 'Stored solution bytes no longer match validation.json.'}
  }
  $review=Find-PMMReviewFolderByCaseId $CaseId
  if(-not$review){throw 'The original review case is unavailable. Keep the PMM Review workspace until a tested contribution is exported.'}
  $case=Read-PMMReviewCase $review
  if(-not$case -or [string]$case.CaseId -ne $CaseId){throw 'Original review case metadata is unavailable or mismatched.'}

  $outRoot=Get-PMMKnowledgeContributionRoot
  $stage=Join-Path (Get-PMMPath 'Cache') ('KnowledgeContribution_'+[guid]::NewGuid().ToString('N'))
  $zip=Join-Path $outRoot ('PMM_KNOWLEDGE_CONTRIBUTION_'+$CaseId+'.zip')
  try{
    New-Item -ItemType Directory -Force -Path $stage|Out-Null
    Set-PMMTransientStageOwner $stage 'KnowledgeContribution'
    Copy-Item -LiteralPath (Join-Path $review 'case.json') -Destination (Join-Path $stage 'case.json') -Force
    Copy-Item -LiteralPath $validationPath -Destination (Join-Path $stage 'validation.json') -Force
    Copy-Item -LiteralPath (Join-Path $solutionRoot 'solution.json') -Destination (Join-Path $stage 'solution.json') -Force

    # Preserve the CKL starting point that was relevant to this exact tested
    # fixture. This allows maintainers to reproduce why Analyze/AIIO considered
    # prior knowledge relevant even when the original handoff ZIP is gone.
    if(Get-Command Get-PMMCKLContextForPlanItem -ErrorAction SilentlyContinue){
      $cklProbe=[pscustomobject]@{Asset=[string]$case.Asset;Providers=@($case.Providers|ForEach-Object{[string]$_.Name});Case=$case}
      $cklContext=@(Get-PMMCKLContextForPlanItem $cklProbe)
      [ordered]@{Schema='PMM_KNOWLEDGE_CONTRIBUTION_CKL_CONTEXT_V1';CaseId=$CaseId;Asset=[string]$case.Asset;Matches=$cklContext}|ConvertTo-Json -Depth 30|Set-Content -LiteralPath (Join-Path $stage 'ckl-context.json') -Encoding UTF8
      $channels=Join-PMMPath 'CKL' 'channels.json'
      if(Test-Path -LiteralPath $channels -PathType Leaf){Copy-Item -LiteralPath $channels -Destination (Join-Path $stage 'ckl-channels.json') -Force}
    }

    $handoffPath=''
    if(Get-Command Find-PMMAIHandoffForCaseId -ErrorAction SilentlyContinue){$handoffPath=Find-PMMAIHandoffForCaseId $CaseId}
    if([string]::IsNullOrWhiteSpace($handoffPath)){
      # Compatibility only: preserve access to an old pre-AIIO per-case handoff if one
      # already exists, but never create another legacy handoff here.
      $legacy=@(Get-ChildItem -LiteralPath $review -Filter ('AI_HANDOFF_'+$CaseId+'*.zip') -File -ErrorAction SilentlyContinue|Select-Object -First 1)
      if($legacy.Count -gt 0){$handoffPath=$legacy[0].FullName}
    }
    if($handoffPath){Copy-Item -LiteralPath $handoffPath -Destination (Join-Path $stage 'original-handoff.zip') -Force}
    $storedSource=Join-Path $solutionRoot 'source-solution.zip'
    $solutionZip=Join-Path $stage 'returned-solution.zip'
    $solutionOrigin='reconstructed-from-validated-storage'
    if(Test-Path -LiteralPath $storedSource -PathType Leaf){Copy-Item -LiteralPath $storedSource -Destination $solutionZip -Force;$solutionOrigin='original-imported-zip'}else{New-PMMReconstructedSolutionZip $solutionRoot $solutionZip}

    $versionPath=Get-PMMMetadataPath 'VERSION.txt';$pmmVersion=if(Test-Path -LiteralPath $versionPath -PathType Leaf){(Get-Content -LiteralPath $versionPath -Raw).Trim()}else{'unknown'}
    $runtime=[ordered]@{
      Schema='PMM_RUNTIME_RESULT_V1';CaseId=$CaseId;Asset=[string]$case.Asset;Result='PASS';ReportedUtc=[DateTime]::UtcNow.ToString('o');
      PmmVersion=$pmmVersion;Notes=$(if([string]::IsNullOrWhiteSpace($RuntimeNotes)){'User explicitly reported an in-game PASS before exporting this contribution.'}else{$RuntimeNotes});
      Trust='User-reported runtime evidence for this exact fixture. Maintainer/community validation is required before promotion into a production recipe.'
    }
    $runtime|ConvertTo-Json -Depth 12|Set-Content -LiteralPath (Join-Path $stage 'runtime-result.json') -Encoding UTF8

    $contribution=[ordered]@{
      Schema='PMM_KNOWLEDGE_CONTRIBUTION_V1';CaseId=$CaseId;Asset=[string]$case.Asset;CreatedUtc=[DateTime]::UtcNow.ToString('o');
      OriginalHandoffIncluded=[bool]$handoffPath;OriginalHandoffSha256=$(if($handoffPath){Get-Sha256 (Join-Path $stage 'original-handoff.zip')}else{''});
      ReturnedSolutionSha256=Get-Sha256 $solutionZip;ReturnedSolutionOrigin=$solutionOrigin;ValidationSha256=Get-Sha256 (Join-Path $stage 'validation.json');RuntimeResult='PASS';
      Safety='Submission evidence only. Importing/uploading this contribution must never activate a production writer automatically. Promotion requires independent validation and an explicitly trusted Knowledge release/pack.'
    }
    $contribution|ConvertTo-Json -Depth 16|Set-Content -LiteralPath (Join-Path $stage 'contribution.json') -Encoding UTF8
    @"
# PMM Knowledge contribution

This ZIP is ready to upload to a future PMM community Knowledge service or send
to the PMM maintainer. It is self-contained evidence for one tested case.

Contains:
- exact case metadata;
- relevant CKL catalog matches and channel metadata;
- original AI_HANDOFF when still available;
- returned/validated PMM_MANUAL_SOLUTION_V1 ZIP;
- PMM validation metadata;
- explicit user-reported runtime PASS.

IMPORTANT: this package is evidence, not executable merge permission. A website,
maintainer or future validator should quarantine it, verify hashes/provenance,
review the structural lesson and only then publish an approved Knowledge update.
"@|Set-Content -LiteralPath (Join-Path $stage 'README.md') -Encoding UTF8
    Remove-Item -LiteralPath $zip -Force -ErrorAction SilentlyContinue
    New-PMMKnowledgeArchive $stage $zip
    Write-PMMLog ('Knowledge contribution exported for case '+$CaseId+': '+$zip)
    return $zip
  }finally{
    Remove-Item -LiteralPath $stage -Recurse -Force -ErrorAction SilentlyContinue
    Remove-PMMTransientStageOwner $stage
  }
}
