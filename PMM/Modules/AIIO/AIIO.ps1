<#
AIIO.ps1 - AI handoff input/output packaging for Palworld Manager Merger.

AIIO is intentionally separate from Analyze. Analyze produces exact review cases
and a merge plan. AIIO runs only on explicit user request and packages every
current Unsupported case into ONE bounded handoff ZIP for the current mod set.

Hard safety rules:
  * Never copy whole source PAK files into an AI handoff.
  * Extract only the exact conflicting file/family from each provider and Vanilla.
  * Keep provider/Vanilla sources in separate folders with their logical game path.
  * Default raw-input budget: 5 GiB.
  * Target compressed handoff size: 512 MiB (10:1 planning estimate).
  * Oversize work requires explicit caller approval.
  * Stage directories and partial ZIPs are deleted in finally blocks.
#>

$Script:PMMAIIOSoftZipTargetBytes = [int64](512MB)
$Script:PMMAIIODefaultRawLimitBytes = [int64](5GB)
$Script:PMMAIIOCompressionPlanningRatio = 0.10

function Invoke-PMMAIIOProgress([int]$Current,[int]$Total,[string]$Message,[switch]$Indeterminate) {
  $callback=Get-Command Set-PMMAnalyzeProgress -ErrorAction SilentlyContinue
  if($callback){try{Set-PMMAnalyzeProgress -Current $Current -Total $Total -Message $Message -Indeterminate:$Indeterminate}catch{}}
}

function Get-PMMAIIOStageRoot {
  return (Join-PMMPath 'Temp' 'AIIO')
}

function Get-PMMAIHandoffRoot {
  $root=Get-PMMPath 'Handoffs'
  if(-not(Test-Path -LiteralPath $root -PathType Container)){New-Item -ItemType Directory -Force -Path $root|Out-Null}
  return $root
}

function ConvertTo-PMMAIIOSafeSourceName([string]$Name) {
  $leaf=[IO.Path]::GetFileNameWithoutExtension($Name)
  if([string]::IsNullOrWhiteSpace($leaf)){$leaf='UnknownProvider'}
  $safe=($leaf -replace '[^A-Za-z0-9_. -]','_').Trim().TrimEnd([char]46)
  if([string]::IsNullOrWhiteSpace($safe) -or $safe -in @('.','..')){$safe='UnknownProvider'}
  $device=([string]$safe.Split([char]46)[0]).TrimEnd([char]32,[char]46).ToUpperInvariant()
  if($device -in @('CON','PRN','AUX','NUL','COM1','COM2','COM3','COM4','COM5','COM6','COM7','COM8','COM9','LPT1','LPT2','LPT3','LPT4','LPT5','LPT6','LPT7','LPT8','LPT9')){$safe='Mod_'+$safe}
  # sources/Vanilla is reserved for the game baseline. A source mod can legally
  # be named Vanilla.pak, so disambiguate it before any extraction happens.
  if($safe -ieq 'Vanilla'){$safe='Mod_Vanilla'}
  # Keep provider folders short enough to leave room for long Unreal logical
  # paths on Windows. The hash suffix preserves stable identity when truncated.
  if($safe.Length -gt 56){
    $tag=(Get-PMMStableTextId $safe).Substring(0,10)
    $safe=$safe.Substring(0,44).TrimEnd()+'_'+$tag
  }
  return $safe
}

function Get-PMMAIIOVanillaQuickSignature {
  $shared=Get-Command Get-PMMVanillaPakSetQuickSignature -ErrorAction SilentlyContinue
  if($shared){return (Get-PMMVanillaPakSetQuickSignature)}
  $parts=@(Get-VanillaPakFiles|ForEach-Object{('{0}:{1}:{2}' -f $_.Name,[int64]$_.Length,$_.LastWriteTimeUtc.Ticks)})
  return (Get-PMMStableTextId ('VANILLA_PAK_SET_V1|'+($parts -join '|')))
}

function Get-PMMAIHandoffBundleId($Plan) {
  if(-not$Plan){throw 'AIIO requires a current merge plan. Run Analyze first.'}
  $mappings=if($Plan.PSObject.Properties.Name -contains 'MappingsSha256'){[string]$Plan.MappingsSha256}else{''}
  $source=if($Plan.PSObject.Properties.Name -contains 'SourceSignature'){[string]$Plan.SourceSignature}else{''}
  $order=if($Plan.PSObject.Properties.Name -contains 'MergeOrderSignature'){[string]$Plan.MergeOrderSignature}else{''}
  $effective=if($Plan.PSObject.Properties.Name -contains 'EffectiveMergeOrderSignature'){[string]$Plan.EffectiveMergeOrderSignature}else{''}
  $engine=if($Plan.PSObject.Properties.Name -contains 'Engine'){[string]$Plan.Engine}else{Get-PMMEngineId}
  $vanilla=Get-PMMAIIOVanillaQuickSignature
  $caseSignature=(@($Plan.Assets|Where-Object{[string]$_.Mode -eq 'Unsupported'}|Sort-Object Asset|ForEach-Object{
    $caseId=if($_.PSObject.Properties.Name -contains 'CaseId'){[string]$_.CaseId}else{''}
    ([string]$_.AssetKey)+':'+$caseId+':'+((@($_.Providers|ForEach-Object{[string]$_}|Sort-Object)) -join ',')
  }) -join '|')
  return (Get-PMMStableTextId ('AIIO_BUNDLE_V1|'+$source+'|'+$order+'|'+$effective+'|'+$mappings+'|'+$engine+'|'+$vanilla+'|'+$caseSignature))
}

function Get-PMMAIHandoffBundlePath($Plan) {
  $id=Get-PMMAIHandoffBundleId $Plan
  return (Join-Path (Get-PMMAIHandoffRoot) ('AI_HANDOFF_'+$id+'.zip'))
}

function Assert-PMMAIIOCaseMetadata($Item,[string]$ReviewRoot) {
  if(-not$Item){throw 'AIIO case item is missing.'}
  $review=[string]$Item.ReviewFolder
  if([string]::IsNullOrWhiteSpace($review) -or -not(Test-Path -LiteralPath $review -PathType Container)){
    throw ('AIIO review metadata is missing for '+[string]$Item.Asset+'. Run Analyze again.')
  }
  if(-not(Test-PMMPathInside $review $ReviewRoot)){
    throw ('AIIO refused a review folder outside PMM Review workspace for '+[string]$Item.Asset+'. Run Analyze again.')
  }
  $case=$Item.Case
  if(-not$case){throw ('AIIO case.json is missing or invalid for '+[string]$Item.Asset+'. Run Analyze again.')}
  if([string]$case.Schema -ne 'PMM_REVIEW_CASE_V1'){throw ('AIIO case schema is invalid for '+[string]$Item.Asset+'. Run Analyze again.')}
  if([string]$case.Mode -ne 'Unsupported'){throw ('AIIO case mode is not Unsupported for '+[string]$Item.Asset+'. Run Analyze again.')}
  if([string]$case.Asset -cne [string]$Item.Asset -or [string]$case.AssetKey -cne [string]$Item.AssetKey){
    throw ('AIIO case identity does not match the current merge plan for '+[string]$Item.Asset+'. Run Analyze again.')
  }
  $assetExtension=[IO.Path]::GetExtension([string]$case.Asset).ToLowerInvariant()
  $isFamily=($assetExtension -eq '.uasset')
  if($case.PSObject.Properties.Name -contains 'CaseKind'){
    $kind=[string]$case.CaseKind
    if($isFamily -and $kind -notin @('','CookedFamily')){throw ('AIIO case kind does not match the Unreal cooked family '+[string]$Item.Asset+'. Run Analyze again.')}
    if(-not$isFamily -and $kind -notin @('','PlainFile')){throw ('AIIO case kind does not match the plain file '+[string]$Item.Asset+'. Run Analyze again.')}
  }

  $planProviders=@($Item.Providers|ForEach-Object{[string]$_}|Sort-Object)
  $caseProviders=@($case.Providers|ForEach-Object{[string]$_.Name}|Sort-Object)
  $providerDiff=@(Compare-Object -ReferenceObject $planProviders -DifferenceObject $caseProviders -CaseSensitive)
  if($planProviders.Count -ne $caseProviders.Count -or $providerDiff.Count -gt 0){
    throw ('AIIO case providers do not match the current merge plan for '+[string]$Item.Asset+'. Run Analyze again.')
  }
  foreach($provider in @($case.Providers)){
    if([string]::IsNullOrWhiteSpace([string]$provider.Name) -or [string]$provider.PakSha256 -notmatch '^[0-9a-fA-F]{64}$'){
      throw ('AIIO case provider identity/hash is invalid for '+[string]$Item.Asset+'. Run Analyze again.')
    }
  }

  $inputs=@($case.InputFiles)
  if($inputs.Count -eq 0){throw ('AIIO case has no pinned input files for '+[string]$Item.Asset+'. Run Analyze again.')}
  $inputKeys=@{}
  foreach($input in $inputs){
    $role=[string]$input.Role;$part=[string]$input.Part;$hash=[string]$input.Sha256;$inputProvider=[string]$input.Provider
    $partValid=if($isFamily){$part -in @('.uasset','.uexp','.ubulk')}else{$part -ceq $assetExtension}
    if($role -notin @('Vanilla','Provider') -or -not$partValid -or $hash -notmatch '^[0-9a-fA-F]{64}$' -or [int64]$input.Size -lt 0){
      throw ('AIIO case contains an invalid pinned input row for '+[string]$Item.Asset+'. Run Analyze again.')
    }
    if($role -eq 'Provider' -and -not($caseProviders -contains $inputProvider)){
      throw ('AIIO case contains an unknown provider input for '+[string]$Item.Asset+'. Run Analyze again.')
    }
    if($role -eq 'Vanilla' -and $inputProvider -ne 'Vanilla'){
      throw ('AIIO case contains an invalid Vanilla input identity for '+[string]$Item.Asset+'. Run Analyze again.')
    }
    $inputKey=($role+'|'+$inputProvider+'|'+$part).ToLowerInvariant()
    if($inputKeys.ContainsKey($inputKey)){
      throw ('AIIO case contains duplicate pinned input rows for '+[string]$Item.Asset+'. Run Analyze again.')
    }
    $inputKeys[$inputKey]=$true
  }
  foreach($providerName in $caseProviders){
    $providerInputs=@($inputs|Where-Object{[string]$_.Role -eq 'Provider' -and [string]$_.Provider -eq $providerName})
    if($isFamily){
      if(@($providerInputs|Where-Object{[string]$_.Part -eq '.uasset'}).Count -ne 1){
        throw ('AIIO case is missing or duplicates the provider .uasset header for '+$providerName+' in '+[string]$Item.Asset+'. Run Analyze again.')
      }
    }elseif($providerInputs.Count -ne 1){
      throw ('AIIO plain-file case must contain exactly one pinned provider file for '+$providerName+' in '+[string]$Item.Asset+'. Run Analyze again.')
    }
  }
  if([bool]$case.VanillaAvailable){
    $vanillaInputs=@($inputs|Where-Object{[string]$_.Role -eq 'Vanilla'})
    if($isFamily -and @($vanillaInputs|Where-Object{[string]$_.Part -eq '.uasset'}).Count -ne 1){
      throw ('AIIO case has inconsistent Vanilla topology for '+[string]$Item.Asset+'. Run Analyze again.')
    }
    if(-not$isFamily -and $vanillaInputs.Count -ne 1){
      throw ('AIIO plain-file case must contain exactly one pinned Vanilla file for '+[string]$Item.Asset+'. Run Analyze again.')
    }
  }
  if(-not [bool]$case.VanillaAvailable -and @($inputs|Where-Object{[string]$_.Role -eq 'Vanilla'}).Count -ne 0){
    throw ('AIIO case says Vanilla is unavailable but contains Vanilla hashes for '+[string]$Item.Asset+'. Run Analyze again.')
  }

  $signature=([string]$case.AssetKey)+'|'+(($inputs|ForEach-Object{"$($_.Role):$($_.Provider):$($_.Part):$($_.Sha256)"}) -join '|')
  if((Get-PMMStableTextId $signature) -ne [string]$case.CaseId){
    throw ('AIIO caseId no longer matches its pinned inputs for '+[string]$Item.Asset+'. Run Analyze again.')
  }
  return $true
}

function Get-PMMAIIOCurrentCases($Plan) {
  if(-not$Plan){return @()}
  $reviewRoot=Get-PMMPath 'Review'
  $items=[System.Collections.Generic.List[object]]::new()
  foreach($asset in @($Plan.Assets|Where-Object{[string]$_.Mode -eq 'Unsupported'}|Sort-Object Asset)){
    $review=if($asset.PSObject.Properties.Name -contains 'ReviewFolder'){[string]$asset.ReviewFolder}else{''}
    $case=$null
    if($review -and (Test-Path -LiteralPath (Join-Path $review 'case.json') -PathType Leaf)){
      try{$case=Get-Content -LiteralPath (Join-Path $review 'case.json') -Raw|ConvertFrom-Json}catch{$case=$null}
    }
    $item=[pscustomobject]@{
      AssetPlan=$asset
      ReviewFolder=$review
      Case=$case
      Asset=[string]$asset.Asset
      AssetKey=[string]$asset.AssetKey
      Providers=@($asset.Providers|ForEach-Object{[string]$_})
      Reason=[string]$asset.Reason
    }
    [void](Assert-PMMAIIOCaseMetadata $item $reviewRoot)
    $items.Add($item)
  }
  return $items.ToArray()
}

function Get-PMMAIIOKnownRawBytes([array]$Cases) {
  $seen=@{}
  [int64]$bytes=0
  [int]$files=0
  foreach($item in @($Cases)){
    if(-not$item.Case -or -not($item.Case.PSObject.Properties.Name -contains 'InputFiles')){continue}
    foreach($input in @($item.Case.InputFiles)){
      $key=('{0}|{1}|{2}|{3}|{4}' -f [string]$item.Asset,[string]$input.Role,[string]$input.Provider,[string]$input.Part,[string]$input.Sha256).ToLowerInvariant()
      if($seen.ContainsKey($key)){continue}
      $seen[$key]=$true
      $bytes+=[int64]$input.Size
      $files++
    }
  }
  return [pscustomobject]@{Bytes=$bytes;Files=$files}
}

function Get-PMMAIIODirectoryBytes([string]$Path) {
  if(-not(Test-Path -LiteralPath $Path -PathType Container)){return [int64]0}
  [int64]$total=0
  foreach($file in @(Get-ChildItem -LiteralPath $Path -Recurse -File -ErrorAction SilentlyContinue)){$total+=[int64]$file.Length}
  return $total
}

function Get-PMMAIIOFreeBytes([string]$Path) {
  try{
    $probe=$Path
    while($probe -and -not(Test-Path -LiteralPath $probe -PathType Container)){$probe=Split-Path -Parent $probe}
    if(-not$probe){return [int64]-1}
    $item=Get-Item -LiteralPath $probe -ErrorAction Stop
    if($item.PSDrive -and $null -ne $item.PSDrive.Free){return [int64]$item.PSDrive.Free}
  }catch{}
  try{
    $root=[IO.Path]::GetPathRoot([IO.Path]::GetFullPath($Path))
    if($root){return [int64]([IO.DriveInfo]::new($root).AvailableFreeSpace)}
  }catch{}
  return [int64]-1
}

function Get-PMMAIIOWorstCaseZipBytes([int64]$UncompressedBytes) {
  if($UncompressedBytes -lt 0){$UncompressedBytes=0}
  # Deflate can slightly expand incompressible data. Reserve 1% plus 64 MiB for
  # ZIP headers/central directory instead of assuming the optimistic 10:1 ratio.
  return [int64]([Math]::Ceiling([double]$UncompressedBytes*1.01)+64MB)
}

function Get-PMMAIIOWorkingSpaceRequirement([int64]$UncompressedBytes) {
  return [int64]($UncompressedBytes+(Get-PMMAIIOWorstCaseZipBytes $UncompressedBytes)+512MB)
}

function Assert-PMMAIIOFreeSpace([int64]$RequiredBytes,[string]$Path,[string]$Phase) {
  $free=Get-PMMAIIOFreeBytes $Path
  if($free -ge 0 -and $free -lt $RequiredBytes){
    throw ('PMM_AIIO_INSUFFICIENT_DISK|phase='+$Phase+'|requiredBytes='+$RequiredBytes+'|freeBytes='+$free)
  }
  if($free -lt 0){Write-PMMLog ('AIIO free-space preflight unavailable for '+$Path+'; continuing with runtime budget enforcement.')}
  return $free
}

function Get-PMMAIIOMetadataBytes([array]$Cases) {
  [int64]$bytes=0
  $seen=@{}
  foreach($item in @($Cases)){
    $review=[string]$item.ReviewFolder
    if(-not$review -or -not(Test-Path -LiteralPath $review -PathType Container)){continue}
    foreach($file in @(Get-ChildItem -LiteralPath $review -File -ErrorAction SilentlyContinue)){
      if($file.Name -like 'AI_HANDOFF_*.zip'){continue}
      $key=$file.FullName.ToLowerInvariant()
      if($seen.ContainsKey($key)){continue}
      $seen[$key]=$true;$bytes+=[int64]$file.Length
    }
  }
  $knowledge=Get-PMMPath 'CKL'
  if(Test-Path -LiteralPath $knowledge -PathType Container){
    foreach($file in @(Get-ChildItem -LiteralPath $knowledge -Recurse -File -ErrorAction SilentlyContinue)){$bytes+=[int64]$file.Length}
  }
  return $bytes
}

function Get-PMMAIHandoffEstimate {
  $plan=Read-PMMMergePlan
  if(-not$plan){throw (Get-PMMText 'No analysis exists. Run Analyze first.' 'No existe un analisis. Ejecuta Analizar primero.')}
  if(Get-Command Test-PMMMergePlanCurrent -ErrorAction SilentlyContinue){
    if(-not(Test-PMMMergePlanCurrent)){throw (Get-PMMText 'The analysis is stale. Run Analyze again before creating an AI handoff.' 'El analisis esta desactualizado. Ejecuta Analizar de nuevo antes de crear una entrega para IA.')}
  }
  $cases=@(Get-PMMAIIOCurrentCases $plan)
  if($cases.Count -eq 0){throw (Get-PMMText 'There are no Unsupported assets in the current analysis.' 'No hay assets no soportados en el analisis actual.')}
  $known=Get-PMMAIIOKnownRawBytes $cases
  $meta=Get-PMMAIIOMetadataBytes $cases
  [int64]$raw=[int64]$known.Bytes
  [int64]$estimatedUncompressed=$raw+[int64]$meta
  [int64]$estimatedZip=[int64][Math]::Ceiling([double]$estimatedUncompressed*$Script:PMMAIIOCompressionPlanningRatio)
  $unknown=0
  $needs=($estimatedUncompressed -gt $Script:PMMAIIODefaultRawLimitBytes -or $estimatedZip -gt $Script:PMMAIIOSoftZipTargetBytes)
  [int64]$requiredWorking=Get-PMMAIIOWorkingSpaceRequirement $estimatedUncompressed
  [int64]$freeBytes=Get-PMMAIIOFreeBytes $Script:Root
  $bundleId=Get-PMMAIHandoffBundleId $plan
  $zip=Get-PMMAIHandoffBundlePath $plan
  return [pscustomobject]@{
    Schema='PMM_AIIO_ESTIMATE_V1'
    BundleId=$bundleId
    VanillaQuickSignature=(Get-PMMAIIOVanillaQuickSignature)
    CaseCount=$cases.Count
    KnownInputFiles=[int]$known.Files
    UnknownSizeCaseCount=$unknown
    RawBytes=$raw
    MetadataBytes=[int64]$meta
    EstimatedUncompressedBytes=$estimatedUncompressed
    EstimatedZipBytes=$estimatedZip
    CompressionPlanningRatio=$Script:PMMAIIOCompressionPlanningRatio
    SoftZipTargetBytes=$Script:PMMAIIOSoftZipTargetBytes
    DefaultRawLimitBytes=$Script:PMMAIIODefaultRawLimitBytes
    RequiredWorkingBytes=$requiredWorking
    AvailableFreeBytes=$freeBytes
    InsufficientDiskSpace=($freeBytes -ge 0 -and $freeBytes -lt $requiredWorking)
    NeedsOversizeConfirmation=[bool]$needs
    ZipPath=$zip
    Existing=(Test-Path -LiteralPath $zip -PathType Leaf)
  }
}

function Assert-PMMAIIOWithinBudget([int64]$CurrentBytes,[bool]$AllowOversize) {
  if($AllowOversize){return}
  if($CurrentBytes -gt $Script:PMMAIIODefaultRawLimitBytes){
    throw ('PMM_AIIO_OVERSIZE_CONFIRMATION_REQUIRED|rawBytes='+$CurrentBytes+'|limit='+$Script:PMMAIIODefaultRawLimitBytes)
  }
}

function Get-PMMAIIOActiveProvider([string]$Name,[string]$ExpectedHash,[array]$Mods) {
  $match=@($Mods|Where-Object{[string]$_.Name -eq $Name}|Select-Object -First 1)
  if($match.Count -eq 0){throw ('AIIO cannot find active source mod: '+$Name+'. Run Analyze again.')}
  $mod=$match[0]
  if($ExpectedHash -and [string]$mod.Hash -ne $ExpectedHash.ToLowerInvariant()){
    throw ('AIIO source mod changed after Analyze: '+$Name+'. Run Analyze again.')
  }
  return $mod
}

function Test-PMMAIIOExtractedPart([string]$Path,$Expected,[string]$Description) {
  if(-not(Test-Path -LiteralPath $Path -PathType Leaf)){throw ('AIIO extraction is missing '+$Description+': '+$Path)}
  if($Expected){
    $item=Get-Item -LiteralPath $Path
    if([long]$item.Length -ne [long]$Expected.Size){throw ('AIIO extracted size does not match Analyze for '+$Description)}
    if((Get-Sha256 $Path) -ne ([string]$Expected.Sha256).ToLowerInvariant()){throw ('AIIO extracted SHA-256 does not match Analyze for '+$Description)}
  }
}

function Copy-PMMAIIOCaseMetadata($Item,[string]$StageRoot) {
  $caseId=''
  if($Item.Case -and ($Item.Case.PSObject.Properties.Name -contains 'CaseId')){$caseId=[string]$Item.Case.CaseId}
  if([string]::IsNullOrWhiteSpace($caseId)){$caseId=Get-PMMStableTextId ([string]$Item.AssetKey+'|'+([string]$Item.Asset))}
  $dest=Join-Path $StageRoot ('cases\'+$caseId)
  New-Item -ItemType Directory -Force -Path $dest|Out-Null
  $review=[string]$Item.ReviewFolder
  if($review -and (Test-Path -LiteralPath $review -PathType Container)){
    foreach($file in @(Get-ChildItem -LiteralPath $review -File -ErrorAction SilentlyContinue)){
      if($file.Name -like 'AI_HANDOFF_*.zip' -or $file.Name -eq 'case.json'){continue}
      Copy-Item -LiteralPath $file.FullName -Destination (Join-Path $dest $file.Name) -Force
    }
  }
  # case.json is the validated in-memory snapshot captured from the same merge
  # plan, not a second read from the Review workspace. This prevents a concurrent Analyze
  # in another PMM instance from swapping the authoritative case mid-bundle.
  $Item.Case|ConvertTo-Json -Depth 30|Set-Content -LiteralPath (Join-Path $dest 'case.json') -Encoding UTF8
  return $caseId
}

function Export-PMMAIIOAssetSources($Item,[string]$StageRoot,[array]$Mods,[hashtable]$ProviderFolderMap,[ref]$RawBytes,[bool]$AllowOversize,[string]$RoleFilter='',[string]$ProviderFilter='') {
  $asset=([string]$Item.Asset).Replace([char]92,[char]47)
  $isFamily=([IO.Path]::GetExtension($asset) -ieq '.uasset')
  $case=$Item.Case
  $expectedInputs=@()
  if($case -and ($case.PSObject.Properties.Name -contains 'InputFiles')){$expectedInputs=@($case.InputFiles)}

  $providerHashes=@{}
  if($case -and ($case.PSObject.Properties.Name -contains 'Providers')){
    foreach($p in @($case.Providers)){$providerHashes[[string]$p.Name]=[string]$p.PakSha256}
  }

  $sourceRows=[System.Collections.Generic.List[object]]::new()
  if($RoleFilter -and $RoleFilter -notin @('Vanilla','Provider')){throw ('Unknown AIIO source role filter: '+$RoleFilter)}
  if($ProviderFilter -and $RoleFilter -ne 'Provider'){throw 'AIIO provider filter requires the Provider role.'}
  $includeVanilla=([string]::IsNullOrWhiteSpace($RoleFilter) -or $RoleFilter -eq 'Vanilla')
  $includeProviders=([string]::IsNullOrWhiteSpace($RoleFilter) -or $RoleFilter -eq 'Provider')

  $hasVanilla=$false
  if($case -and ($case.PSObject.Properties.Name -contains 'VanillaAvailable')){$hasVanilla=[bool]$case.VanillaAvailable}
  elseif($expectedInputs.Count -gt 0){$hasVanilla=(@($expectedInputs|Where-Object{[string]$_.Role -eq 'Vanilla'}).Count -gt 0)}
  else{$hasVanilla=$true}

  if($includeVanilla -and $hasVanilla){
    $vanillaRoot=Join-Path $StageRoot 'sources\Vanilla'
    $vanillaFiles=[System.Collections.Generic.List[object]]::new()
    try{
      if($isFamily){
        $export=Export-VanillaAssetFamilyExact $asset $vanillaRoot
        if(-not$export){throw ('Vanilla does not contain '+$asset)}
        foreach($ext in @('.uasset','.uexp','.ubulk')){
          $path=Get-PMMFamilyPartPath $export $ext
          $exists=Test-Path -LiteralPath $path -PathType Leaf
          $expected=@($expectedInputs|Where-Object{[string]$_.Role -eq 'Vanilla' -and [string]$_.Part -eq $ext})
          if($expected.Count -eq 0){
            if($exists){throw ('AIIO Vanilla cooked-family topology changed after Analyze ('+$ext+' appeared): '+$asset)}
            continue
          }
          if($expected.Count -ne 1 -or -not$exists){throw ('AIIO Vanilla cooked-family topology changed after Analyze ('+$ext+'): '+$asset)}
          Test-PMMAIIOExtractedPart $path $expected[0] ('Vanilla '+$asset+$ext)
          $item=Get-Item -LiteralPath $path
          $RawBytes.Value+=[int64]$item.Length
          Assert-PMMAIIOWithinBudget $RawBytes.Value $AllowOversize
          $vanillaFiles.Add([pscustomobject]@{LogicalPath=((Get-PakLogicalStem $asset)+$ext);Part=$ext;Size=[int64]$item.Length;Sha256=(Get-Sha256 $path)})
        }
      }else{
        $path=Export-VanillaFileExact $asset $vanillaRoot
        $expected=@($expectedInputs|Where-Object{[string]$_.Role -eq 'Vanilla'})
        if($expected.Count -ne 1 -or -not$path){throw ('AIIO Vanilla plain-file availability/topology changed after Analyze: '+$asset)}
        Test-PMMAIIOExtractedPart $path $expected[0] ('Vanilla '+$asset)
        $item=Get-Item -LiteralPath $path
        $RawBytes.Value+=[int64]$item.Length
        Assert-PMMAIIOWithinBudget $RawBytes.Value $AllowOversize
        $vanillaFiles.Add([pscustomobject]@{LogicalPath=$asset;Part=[IO.Path]::GetExtension($asset).ToLowerInvariant();Size=[int64]$item.Length;Sha256=(Get-Sha256 $path)})
      }
      $sourceRows.Add([pscustomobject]@{Role='Vanilla';Name='Vanilla';Asset=$asset;Files=$vanillaFiles.ToArray()})
    }catch{
      if($expectedInputs.Count -gt 0){throw}
      Write-PMMLog ('AIIO Vanilla source not available for '+$asset+': '+$_.Exception.Message)
    }
  }elseif($includeVanilla){
    # Vanilla absence is part of the analyzed fixture too. A game update that
    # introduces this family must invalidate the handoff instead of silently
    # packaging a different baseline.
    $probeRoot=Join-Path $StageRoot ('_vanilla_probe\'+(Get-PMMStableTextId $asset))
    try{
      $probe=if($isFamily){Export-VanillaAssetFamilyExact $asset $probeRoot}else{Export-VanillaFileExact $asset $probeRoot}
      if($probe){throw ('AIIO Vanilla availability changed after Analyze for '+$asset+'. Run Analyze again.')}
    }finally{Remove-Item -LiteralPath $probeRoot -Recurse -Force -ErrorAction SilentlyContinue}
  }

  foreach($providerName in @($Item.Providers)){
    if(-not$includeProviders){continue}
    if($ProviderFilter -and [string]$providerName -cne $ProviderFilter){continue}
    $providerKey=[string]$providerName
    $expectedHash=if($providerHashes.ContainsKey($providerKey)){[string]$providerHashes[$providerKey]}else{''}
    $mod=Get-PMMAIIOActiveProvider $providerKey $expectedHash $Mods
    if(-not$ProviderFolderMap.ContainsKey($providerKey)){
      $base=ConvertTo-PMMAIIOSafeSourceName ([string]$providerName)
      $safe=$base;$suffix=1
      while($ProviderFolderMap.Values -contains $safe){$suffix++;$safe=$base+'_'+$suffix}
      $ProviderFolderMap[$providerKey]=$safe
    }
    $folder=[string]$ProviderFolderMap[$providerKey]
    $providerRoot=Join-Path $StageRoot ('sources\'+$folder)
    $providerFiles=[System.Collections.Generic.List[object]]::new()
    if($isFamily){
      $export=Export-PakAssetFamilyExact ([string]$mod.Path) $asset $providerRoot
      foreach($ext in @('.uasset','.uexp','.ubulk')){
        $path=Get-PMMFamilyPartPath $export $ext
        $exists=Test-Path -LiteralPath $path -PathType Leaf
        $expected=@($expectedInputs|Where-Object{[string]$_.Role -eq 'Provider' -and [string]$_.Provider -eq [string]$providerName -and [string]$_.Part -eq $ext})
        if($expected.Count -eq 0){
          if($exists){throw ('AIIO provider cooked-family topology changed after Analyze ('+$ext+' appeared): '+[string]$providerName+' / '+$asset)}
          continue
        }
        if($expected.Count -ne 1 -or -not$exists){throw ('AIIO provider cooked-family topology changed after Analyze ('+$ext+'): '+[string]$providerName+' / '+$asset)}
        Test-PMMAIIOExtractedPart $path $expected[0] ([string]$providerName+' '+$asset+$ext)
        $item=Get-Item -LiteralPath $path
        $RawBytes.Value+=[int64]$item.Length
        Assert-PMMAIIOWithinBudget $RawBytes.Value $AllowOversize
        $providerFiles.Add([pscustomobject]@{LogicalPath=((Get-PakLogicalStem $asset)+$ext);Part=$ext;Size=[int64]$item.Length;Sha256=(Get-Sha256 $path)})
      }
    }else{
      $path=Export-PakFileExact ([string]$mod.Path) $asset $providerRoot
      $expected=@($expectedInputs|Where-Object{[string]$_.Role -eq 'Provider' -and [string]$_.Provider -eq [string]$providerName})
      if($expected.Count -ne 1){throw ('AIIO plain-file provider topology changed after Analyze: '+[string]$providerName+' / '+$asset)}
      Test-PMMAIIOExtractedPart $path $expected[0] ([string]$providerName+' '+$asset)
      $item=Get-Item -LiteralPath $path
      $RawBytes.Value+=[int64]$item.Length
      Assert-PMMAIIOWithinBudget $RawBytes.Value $AllowOversize
      $providerFiles.Add([pscustomobject]@{LogicalPath=$asset;Part=[IO.Path]::GetExtension($asset).ToLowerInvariant();Size=[int64]$item.Length;Sha256=(Get-Sha256 $path)})
    }
    $sourceRows.Add([pscustomobject]@{Role='Provider';Name=[string]$providerName;Folder=$folder;PakSha256=[string]$mod.Hash;PakBytes=[int64]$mod.Size;Asset=$asset;Files=$providerFiles.ToArray()})
  }
  if($ProviderFilter -and @($sourceRows|Where-Object{[string]$_.Role -eq 'Provider' -and [string]$_.Name -ceq $ProviderFilter}).Count -ne 1){throw ('AIIO provider filter did not resolve exactly one current source: '+$ProviderFilter)}
  return $sourceRows.ToArray()
}

function Write-PMMAIIOReadme([string]$StageRoot,$Plan,[array]$Cases,[string]$BundleId) {
  $versionPath=Get-PMMMetadataPath 'VERSION.txt'
  $version=if(Test-Path -LiteralPath $versionPath -PathType Leaf){(Get-Content -LiteralPath $versionPath -Raw).Trim()}else{'unknown'}
  @"
# Palworld Manager Merger - AIIO bundle

Bundle ID: $BundleId
PMM version: $version
Unsupported cases: $($Cases.Count)

This is ONE handoff for the current analyzed mod list.

What is included
----------------
- cases/<caseId>/ contains PMM's exact analysis metadata/reports for each Unsupported case.
- sources/Vanilla/<logical game path> contains the exact Vanilla file/family when available.
- sources/<mod name>/<logical game path> contains ONLY the exact conflicting file/family extracted from that source mod.
- source-map.json maps source folders back to the original active mod names and hashes.
- knowledge/ contains PMM's bundled explanatory/regression knowledge.
- merge-plan.json records the complete analyzed source graph and current PMM results.

Whole source PAKs are intentionally NOT included. AIIO never needs to duplicate a multi-GB PAK simply to investigate one conflicting asset.

Task for the receiving AI/modder
--------------------------------
Assume zero previous chat/project context. Review every case and preserve independent provider intent. Do not select an entire mod as a winner merely because providers share one file.

For Unreal cooked-family cases that can be solved, return one PMM_MANUAL_SOLUTION_V1 ZIP PER CASE. Each returned ZIP must contain solution.json at the root and cooked/<asset family files>. PMM imports/validates returned solutions per exact case ID, so cases can be solved independently even though they were delivered together in this single bundle. Plain/non-Unreal cases are included for complete investigation evidence, but PMM does not yet auto-import a replacement for those formats; report the safe resolution instead of pretending they use the cooked-family contract.

Do not alter unrelated assets. If evidence is insufficient, report that instead of inventing a speculative merge.
"@|Set-Content -LiteralPath (Join-Path $StageRoot 'AI_READ_FIRST.md') -Encoding UTF8
}

function Test-PMMAIIOZip([string]$ZipPath,[string]$BundleId) {
  Add-Type -AssemblyName System.IO.Compression.FileSystem
  $archive=[IO.Compression.ZipFile]::OpenRead($ZipPath)
  try{
    $entries=@($archive.Entries)
    foreach($entry in $entries){
      $entryName=([string]$entry.FullName).Replace([char]92,[char]47)
      if([IO.Path]::GetExtension($entryName) -ieq '.pak'){
        throw ('AIIO ZIP verification failed: whole/source PAK payload is forbidden: '+$entryName)
      }
    }
    $bundle=@($entries|Where-Object{([string]$_.FullName).Replace([char]92,[char]47) -eq 'bundle.json'}|Select-Object -First 1)
    if($bundle.Count -eq 0){throw 'AIIO ZIP verification failed: bundle.json is missing.'}
    $reader=New-Object IO.StreamReader($bundle[0].Open())
    try{$text=$reader.ReadToEnd()}finally{$reader.Dispose()}
    $meta=$text|ConvertFrom-Json
    if([string]$meta.BundleId -ne $BundleId){throw 'AIIO ZIP verification failed: bundle ID mismatch.'}
    if($entries.Count -lt 4){throw 'AIIO ZIP verification failed: archive contains too few entries.'}
  }finally{$archive.Dispose()}
  return $true
}

function Find-PMMAIHandoffForCaseId([string]$CaseId) {
  if([string]::IsNullOrWhiteSpace($CaseId)){return ''}
  $root=Get-PMMAIHandoffRoot
  foreach($statePath in @(Get-ChildItem -LiteralPath $root -Filter 'AI_HANDOFF_*.json' -File -ErrorAction SilentlyContinue|Sort-Object LastWriteTimeUtc -Descending|ForEach-Object{$_.FullName})){
    try{$state=Get-Content -LiteralPath $statePath -Raw|ConvertFrom-Json}catch{continue}
    if([string]$state.Schema -ne 'PMM_AIIO_BUNDLE_STATE_V1'){continue}
    if(-not($state.PSObject.Properties.Name -contains 'CaseIds')){continue}
    if(-not(@($state.CaseIds|ForEach-Object{[string]$_}) -contains $CaseId)){continue}
    $zipName=[string]$state.Zip
    if([string]::IsNullOrWhiteSpace($zipName)){continue}
    $zip=Join-Path $root $zipName
    if(-not(Test-Path -LiteralPath $zip -PathType Leaf)){continue}
    try{
      if((Get-Sha256 $zip) -ne ([string]$state.ZipSha256).ToLowerInvariant()){continue}
      [void](Test-PMMAIIOZip $zip ([string]$state.BundleId))
      return $zip
    }catch{continue}
  }
  return ''
}

function Test-PMMAIIOExistingBundle([string]$ZipPath,[string]$BundleId) {
  if(-not(Test-Path -LiteralPath $ZipPath -PathType Leaf)){return $null}
  $statePath=[IO.Path]::ChangeExtension($ZipPath,'.json')
  if(-not(Test-Path -LiteralPath $statePath -PathType Leaf)){return $null}
  try{$state=Get-Content -LiteralPath $statePath -Raw|ConvertFrom-Json}catch{return $null}
  if([string]$state.Schema -ne 'PMM_AIIO_BUNDLE_STATE_V1' -or [string]$state.BundleId -ne $BundleId){return $null}
  if([string]$state.Zip -ne [IO.Path]::GetFileName($ZipPath) -or [string]$state.ZipSha256 -notmatch '^[0-9a-fA-F]{64}$'){return $null}
  if((Get-Sha256 $ZipPath) -ne ([string]$state.ZipSha256).ToLowerInvariant()){return $null}
  [void](Test-PMMAIIOZip $ZipPath $BundleId)
  return $state
}

function New-PMMAIHandoffBundle {
  param([switch]$AllowOversize,[switch]$Force)

  $estimate=Get-PMMAIHandoffEstimate
  if([bool]$estimate.NeedsOversizeConfirmation -and -not$AllowOversize){
    throw ('PMM_AIIO_OVERSIZE_CONFIRMATION_REQUIRED|rawBytes='+[string]$estimate.RawBytes+'|estimatedZipBytes='+[string]$estimate.EstimatedZipBytes+'|rawLimit='+[string]$estimate.DefaultRawLimitBytes+'|zipTarget='+[string]$estimate.SoftZipTargetBytes)
  }

  $bundleId=[string]$estimate.BundleId
  $zip=[string]$estimate.ZipPath
  $stageRoot=Get-PMMAIIOStageRoot
  New-Item -ItemType Directory -Force -Path $stageRoot|Out-Null

  # Serialize ALL AIIO writers for this PMM installation, not only identical
  # bundle IDs. Two different handoffs running concurrently could otherwise both
  # pass disk preflight and together exhaust the same volume.
  $lockPath=Join-Path $stageRoot 'AIIO.global.lock'
  $lockStream=$null
  try{$lockStream=[IO.File]::Open($lockPath,[IO.FileMode]::OpenOrCreate,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)}catch{
    throw 'AIIO handoff creation is already running in another PMM process.'
  }

  $stage='';$partial='';$ownerPath=''
  try{
    # The estimate was generated before the cross-process lock. Re-read the plan
    # now and fail closed if another PMM instance changed Analyze in that window.
    $plan=Read-PMMMergePlan
    if(-not$plan -or (Get-PMMAIHandoffBundleId $plan) -ne $bundleId){
      throw 'The PMM analysis changed while AIIO was starting. Run/finish Analyze and create the handoff again.'
    }
    if(Get-Command Test-PMMMergePlanCurrent -ErrorAction SilentlyContinue){
      if(-not(Test-PMMMergePlanCurrent)){throw 'The PMM analysis became stale while AIIO was starting. Run Analyze again.'}
    }
    $cases=@(Get-PMMAIIOCurrentCases $plan)

    if((Test-Path -LiteralPath $zip -PathType Leaf) -and -not$Force){
      try{
        $state=Test-PMMAIIOExistingBundle $zip $bundleId
        if($state){
          return [pscustomobject]@{BundleId=$bundleId;ZipPath=$zip;CaseCount=$cases.Count;RawBytes=[int64]$state.RawSourceBytes;UncompressedBytes=[int64]$state.UncompressedBundleBytes;ZipBytes=[int64]$state.ZipBytes;Existing=$true;OverSoftZipTarget=([int64]$state.ZipBytes -gt $Script:PMMAIIOSoftZipTargetBytes)}
        }
      }catch{}
      Remove-Item -LiteralPath $zip -Force -ErrorAction SilentlyContinue
      Remove-Item -LiteralPath ([IO.Path]::ChangeExtension($zip,'.json')) -Force -ErrorAction SilentlyContinue
    }

    [void](Assert-PMMAIIOFreeSpace ([int64]$estimate.RequiredWorkingBytes) $stageRoot 'preflight')
    $runId=[guid]::NewGuid().ToString('N')
    $stage=Join-Path $stageRoot $runId
    # Keep the partial archive beside (not inside) the stage. It shares the same
    # owner marker, so another PMM instance will never delete an active ZIP write.
    $partial=$stage+'.zip.partial'
    Remove-Item -LiteralPath $partial -Force -ErrorAction SilentlyContinue
    New-Item -ItemType Directory -Force -Path $stage|Out-Null
    $ownerPath=$stage+'.owner.json'
    $processStart=$(try{(Get-Process -Id $PID -ErrorAction Stop).StartTime.ToUniversalTime().ToString('o')}catch{''})
    [ordered]@{Schema='PMM_TRANSIENT_OWNER_V1';Pid=$PID;ProcessStartUtc=$processStart;Kind='AIIO';BundleId=$bundleId;CreatedUtc=[DateTime]::UtcNow.ToString('o')}|ConvertTo-Json -Depth 5|Set-Content -LiteralPath $ownerPath -Encoding UTF8
    $mods=@(Get-LibraryMods)
    $providerFolderMap=@{}
    [int64]$rawBytes=0
    $allSources=[System.Collections.Generic.List[object]]::new()
    $bundleCases=[System.Collections.Generic.List[object]]::new()

    Write-PMMLog ('AIIO bundle START: '+$bundleId+' cases='+$cases.Count)
    Invoke-PMMAIIOProgress 0 ([Math]::Max(1,$cases.Count+1)) (Get-PMMText 'Preparing AI handoff sources...' 'Preparando fuentes para la entrega de IA...') -Indeterminate
    $plan|ConvertTo-Json -Depth 80|Set-Content -LiteralPath (Join-Path $stage 'merge-plan.json') -Encoding UTF8
    Write-PMMAIIOReadme $stage $plan $cases $bundleId

    $index=0
    foreach($item in $cases){
      $index++
      Invoke-PMMAIIOProgress $index ([Math]::Max(1,$cases.Count+1)) ((Get-PMMText 'AIIO extracting {0}' 'AIIO extrayendo {0}') -f [string]$item.Asset)
      $caseId=Copy-PMMAIIOCaseMetadata $item $stage
      $sources=@(Export-PMMAIIOAssetSources $item $stage $mods $providerFolderMap ([ref]$rawBytes) ([bool]$AllowOversize))
      foreach($s in $sources){$allSources.Add($s)}
      $caseSourcesPath=Join-Path $stage ('cases\'+$caseId+'\sources.json')
      [ordered]@{Schema='PMM_AIIO_CASE_SOURCES_V1';CaseId=$caseId;Asset=[string]$item.Asset;Sources=$sources}|ConvertTo-Json -Depth 20|Set-Content -LiteralPath $caseSourcesPath -Encoding UTF8
      $bundleCases.Add([pscustomobject]@{CaseId=$caseId;Asset=[string]$item.Asset;AssetKey=[string]$item.AssetKey;CaseKind=$(if($item.Case.PSObject.Properties.Name -contains 'CaseKind'){[string]$item.Case.CaseKind}else{if([IO.Path]::GetExtension([string]$item.Asset) -ieq '.uasset'){'CookedFamily'}else{'PlainFile'}});Providers=@($item.Providers);Reason=[string]$item.Reason})
      Write-PMMLog ("AIIO bundled case {0}/{1}: {2}" -f $index,$cases.Count,[string]$item.Asset)
    }

    Assert-PMMAIIOWithinBudget $rawBytes ([bool]$AllowOversize)

    $sourceMap=[System.Collections.Generic.List[object]]::new()
    $sourceMap.Add([pscustomobject]@{Role='Vanilla';Folder='Vanilla';Name='Installed Vanilla'})
    foreach($name in @($providerFolderMap.Keys|Sort-Object)){
      $providerKey=[string]$name
      $mod=Get-PMMAIIOActiveProvider $providerKey '' $mods
      $sourceMap.Add([pscustomobject]@{Role='Provider';Folder=[string]$providerFolderMap[$providerKey];Name=$providerKey;PakSha256=[string]$mod.Hash;PakBytes=[int64]$mod.Size})
    }
    [ordered]@{Schema='PMM_AIIO_SOURCE_MAP_V1';Sources=$sourceMap.ToArray();ExtractedAssets=$allSources.ToArray()}|ConvertTo-Json -Depth 30|Set-Content -LiteralPath (Join-Path $stage 'source-map.json') -Encoding UTF8

    $knowledge=Get-PMMPath 'CKL'
    if(Test-Path -LiteralPath $knowledge -PathType Container){
      Copy-Item -LiteralPath $knowledge -Destination (Join-Path $stage 'knowledge') -Recurse -Force
      $relevant=[System.Collections.Generic.List[object]]::new()
      if(Get-Command Get-PMMCKLContextForPlanItem -ErrorAction SilentlyContinue){
        foreach($item in $cases){
          foreach($entry in @(Get-PMMCKLContextForPlanItem $item)){
            $relevant.Add([pscustomobject]@{CaseId=[string]$item.Case.CaseId;Asset=[string]$item.Asset;KnowledgeId=[string]$entry.knowledgeId;Kind=[string]$entry.kind;Channel=[string]$entry.channel;MatchType=[string]$entry.matchType;Source=[string]$entry.source;RuntimeStatus=[string]$entry.runtimeStatus;ProductionEnabled=[bool]$entry.productionEnabled})
          }
        }
      }
      [ordered]@{Schema='PMM_AIIO_CKL_CONTEXT_V1';Matches=@($relevant.ToArray()|Sort-Object KnowledgeId,CaseId -Unique);Channels='knowledge/channels.json';Safety='CKL references are starting evidence. Only production-enabled entries whose exact validation contract matches may authorize an automatic writer.'}|ConvertTo-Json -Depth 20|Set-Content -LiteralPath (Join-Path (Join-Path $stage 'knowledge') 'relevant-knowledge.json') -Encoding UTF8
    }
    foreach($doc in @('Documentation\MANUAL_SOLUTION_CONTRACT.md','Documentation\COMMUNITY_KNOWLEDGE_WORKFLOW.md')){
      $src=Join-Path $Script:Root $doc
      if(Test-Path -LiteralPath $src -PathType Leaf){Copy-Item -LiteralPath $src -Destination (Join-Path $stage ([IO.Path]::GetFileName($src))) -Force}
    }

    $versionPath=Get-PMMMetadataPath 'VERSION.txt'
    $pmmVersion=if(Test-Path -LiteralPath $versionPath -PathType Leaf){(Get-Content -LiteralPath $versionPath -Raw).Trim()}else{'unknown'}
    [ordered]@{
      Schema='PMM_AI_HANDOFF_BUNDLE_V1';BundleId=$bundleId;CreatedUtc=[DateTime]::UtcNow.ToString('o');PmmVersion=$pmmVersion;
      SourceSignature=[string]$plan.SourceSignature;VanillaSourceSignature=[string]$plan.VanillaSourceSignature;MergeOrderSignature=[string]$plan.MergeOrderSignature;MappingsSha256=[string]$plan.MappingsSha256;VanillaQuickSignature=(Get-PMMAIIOVanillaQuickSignature);
      CaseCount=$bundleCases.Count;Cases=$bundleCases.ToArray();RawSourceBytes=$rawBytes;
      SoftZipTargetBytes=$Script:PMMAIIOSoftZipTargetBytes;DefaultRawLimitBytes=$Script:PMMAIIODefaultRawLimitBytes;
      OversizeApproved=[bool]$AllowOversize;WholeSourcePaksIncluded=$false;
      Safety='Only exact conflicting source files/families were extracted. Whole PAKs are never included.'
    }|ConvertTo-Json -Depth 40|Set-Content -LiteralPath (Join-Path $stage 'bundle.json') -Encoding UTF8

    # Do not publish a handoff if another PMM instance changed the modlist or
    # merge plan while these sources were being extracted. Exact file hashes above
    # protect each input; this final guard protects bundle-level completeness.
    $latestPlan=Read-PMMMergePlan
    if(-not$latestPlan -or (Get-PMMAIHandoffBundleId $latestPlan) -ne $bundleId){
      throw 'The PMM analysis changed while AIIO was creating the handoff. The partial bundle was discarded; run Analyze again.'
    }
    if(Get-Command Test-PMMMergePlanCurrent -ErrorAction SilentlyContinue){
      if(-not(Test-PMMMergePlanCurrent)){throw 'The PMM source set changed while AIIO was creating the handoff. The partial bundle was discarded; run Analyze again.'}
    }

    [int64]$stageBytes=Get-PMMAIIODirectoryBytes $stage
    Assert-PMMAIIOWithinBudget $stageBytes ([bool]$AllowOversize)

    [int64]$zipPhaseRequired=(Get-PMMAIIOWorstCaseZipBytes $stageBytes)+512MB
    [void](Assert-PMMAIIOFreeSpace $zipPhaseRequired $stageRoot 'compress')
    Invoke-PMMAIIOProgress ($cases.Count+1) ($cases.Count+1) (Get-PMMText 'Compressing and verifying AI handoff...' 'Comprimiendo y verificando la entrega para IA...') -Indeterminate
    $runtime=Get-PMMRuntimePath
    if(-not(Test-Path -LiteralPath $runtime -PathType Leaf)){throw 'PMMRuntime.exe is required to create the AIIO ZIP.'}
    $output=@(& $runtime archive create $partial $stage 2>&1|ForEach-Object{[string]$_})
    $exit=$LASTEXITCODE
    if($exit -ne 0 -or -not(Test-Path -LiteralPath $partial -PathType Leaf)){
      throw ('PMMRuntime archive create failed with exit '+$exit+'. '+($output -join ' '))
    }
    [void](Test-PMMAIIOZip $partial $bundleId)
    $partialBytes=[int64](Get-Item -LiteralPath $partial).Length
    if(-not$AllowOversize -and $partialBytes -gt $Script:PMMAIIOSoftZipTargetBytes){
      throw ('PMM_AIIO_OVERSIZE_CONFIRMATION_REQUIRED|actualZipBytes='+$partialBytes+'|zipTarget='+$Script:PMMAIIOSoftZipTargetBytes)
    }
    Remove-Item -LiteralPath $zip -Force -ErrorAction SilentlyContinue
    Move-Item -LiteralPath $partial -Destination $zip -Force
    $zipBytes=[int64](Get-Item -LiteralPath $zip).Length

    $summaryPath=[IO.Path]::ChangeExtension($zip,'.json')
    [ordered]@{Schema='PMM_AIIO_BUNDLE_STATE_V1';BundleId=$bundleId;Zip=[IO.Path]::GetFileName($zip);ZipSha256=(Get-Sha256 $zip);ZipBytes=$zipBytes;RawSourceBytes=$rawBytes;UncompressedBundleBytes=$stageBytes;CaseCount=$cases.Count;CaseIds=@($bundleCases|ForEach-Object{[string]$_.CaseId});SourceSignature=[string]$plan.SourceSignature;VanillaSourceSignature=[string]$plan.VanillaSourceSignature;CreatedUtc=[DateTime]::UtcNow.ToString('o')}|ConvertTo-Json -Depth 20|Set-Content -LiteralPath $summaryPath -Encoding UTF8
    Write-PMMLog ("AIIO bundle created: {0} | cases={1} | raw={2} | zip={3}" -f $zip,$cases.Count,$rawBytes,$zipBytes)
    return [pscustomobject]@{BundleId=$bundleId;ZipPath=$zip;CaseCount=$cases.Count;RawBytes=$rawBytes;UncompressedBytes=$stageBytes;ZipBytes=$zipBytes;Existing=$false;OverSoftZipTarget=($zipBytes -gt $Script:PMMAIIOSoftZipTargetBytes)}
  }finally{
    if($stage){Remove-Item -LiteralPath $stage -Recurse -Force -ErrorAction SilentlyContinue}
    if($ownerPath){Remove-Item -LiteralPath $ownerPath -Force -ErrorAction SilentlyContinue}
    if($partial){Remove-Item -LiteralPath $partial -Force -ErrorAction SilentlyContinue}
    try{if($lockStream){$lockStream.Dispose()}}catch{}
    if($lockPath){Remove-Item -LiteralPath $lockPath -Force -ErrorAction SilentlyContinue}
  }
}
