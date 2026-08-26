<#
Palworld Manager Merger v1.2.1 merge engine
====================================

The writer used by preview 14-16 has been removed from the build path.
Palworld Manager Merger v1.2.1 preserves the proven conservative composition adapters and adds exact runtime-proven Knowledge recipes as a strict hash-pinned fallback:

  1. BinaryRangeMergeAdapter for N providers on the current cooked layout.
     Independent byte deltas are combined; only overlapping different values
     become per-byte decisions.
  2. StaticItemDataAssetAdapter for DA_StaticItemDataAsset. It transfers stale
     semantic intent into a current cooked base via fixed-size byte patches.
  3. DataTableScalarTransfer for DataTables. The largest provider is the cooked
     anchor and independent fixed-size scalar properties are transplanted into it.
  4. ContainedDeltaSuperset for variable-size cooked families where one real
     provider strictly contains every other provider's executable delta and
     compatible package metadata; that cooked provider is preserved unchanged.
  5. RelocatableDelta for small variable-size cooked families where secondary
     providers contain disjoint .uexp edits plus provable relocation metadata.

No adapter calls UAsset.Write(). UAssetAPI is a read-only semantic/offset reader.

A shared Unreal asset is never silently degraded to a whole-asset winner when an adapter fails. Infrastructure failures stop Analyze; unsupported structures are reported as unsupported. Only true same-property conflicts are intended to require a user choice.
#>

function Get-PMMCorePath { return (Join-PMMPath 'Engine' 'PMMCore\pmmcore.dll') }
function Get-PMMExpectedCoreVersion { return '0.9.0' }
function Get-PMMEngineId { return 'PMMCore-v0.9.0' }
function Get-PMMPlanSchemaVersion { return 15 }
function Get-PMMAssetReaderPath { return (Join-PMMPath 'Engine' 'AssetReader\PMM.AssetReader.dll') }
function Get-PMMMergePlanPath { return (Join-PMMPath 'State' 'merge-plan.json') }
function Get-PMMLastScanPath { return (Join-PMMPath 'State' 'last-scan.json') }
function Get-PMMPackageRulesPath { return (Get-PMMCKLStablePath 'package-rules.json') }

function Assert-PMMEngineReady {
  $missing = New-Object System.Collections.Generic.List[string]
  foreach ($path in @((Get-PMMCorePath),(Get-PMMAssetReaderPath),(Get-RepakPath),(Get-PMMMappingsPath))) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { $missing.Add($path) }
  }
  if ($missing.Count -gt 0) {
    throw (Get-PMMText ("Palworld Manager Merger dependencies are not prepared. Restart PMM.exe or use Settings > Prepare / repair dependencies.`n`nMissing:`n" + ($missing -join "`n")) ("Las dependencias de Palworld Manager Merger no estan preparadas. Reinicia PMM.exe o usa Configuracion > Preparar / reparar dependencias.`n`nFalta:`n" + ($missing -join "`n")))
  }
  $dotnet = Get-PMMDotnetHostPath
  if(-not $dotnet){throw (Get-PMMText 'Portable .NET host is not prepared. Restart PMM.exe or use Settings > Prepare / repair dependencies.' 'El host .NET portatil no esta preparado. Reinicia PMM.exe o usa Configuracion > Preparar / reparar dependencias.')}
  $core = Get-PMMCorePath
  try{
    $v=[Reflection.AssemblyName]::GetAssemblyName($core).Version
    $assembly=("{0}.{1}.{2}" -f $v.Major,$v.Minor,$v.Build)
  }catch{$assembly=''}
  if($assembly -ne (Get-PMMExpectedCoreVersion)) {
    throw (Get-PMMText ("PMMCore runtime is stale or incompatible. Expected " + (Get-PMMExpectedCoreVersion) + ", assembly='" + $assembly + "'. Restart PMM.exe or use Settings > Prepare / repair dependencies before Analyze.") ("El runtime PMMCore esta desactualizado o es incompatible. Se esperaba " + (Get-PMMExpectedCoreVersion) + ", assembly='" + $assembly + "'. Reinicia PMM.exe o usa Configuracion > Preparar / reparar dependencias antes de Analizar."))
  }
  $coreProbe=@(& $dotnet $core 'self-test' 2>&1);$coreExit=$LASTEXITCODE;$coreProbeText=(@($coreProbe|ForEach-Object{[string]$_}) -join "`n")
  if($coreExit -ne 0 -or $coreProbeText -notmatch ('(?m)^PMMCORE_SELFTEST_OK\s+'+[regex]::Escape((Get-PMMExpectedCoreVersion))+'\s*$')){
    throw (Get-PMMText ("PMMCore could not execute under the prepared .NET host.
"+$coreProbeText) ("PMMCore no pudo ejecutarse con el host .NET preparado.
"+$coreProbeText))
  }
  $reader = Get-PMMAssetReaderPath
  $null = & $dotnet $reader 'self-test-deps' 2>&1
  if ($LASTEXITCODE -ne 0) {
    throw (Get-PMMText 'AssetReader runtime dependencies are incomplete. Restart PMM.exe or use Settings > Prepare / repair dependencies; Analyze will not discard mod changes as a fallback.' 'Faltan dependencias de AssetReader. Reinicia PMM.exe o usa Configuracion > Preparar / reparar dependencias; Analizar no descartara cambios de mods como fallback.')
  }
}

function Get-PMMStableTextId ([string]$Text) {
  $sha = [Security.Cryptography.SHA256]::Create()
  try {
    $bytes = [Text.Encoding]::UTF8.GetBytes($Text)
    $hash = $sha.ComputeHash($bytes)
    return (($hash | ForEach-Object { $_.ToString('x2') }) -join '').Substring(0,24)
  } finally { $sha.Dispose() }
}

function Get-PMMProviderSignature([array]$Providers) {
  return ((@($Providers) | ForEach-Object { "$($_.Name):$($_.Hash)" } | Sort-Object) -join '|')
}

function Get-PMMLibrarySignature([array]$Mods) {
  return ((@($Mods) | ForEach-Object { "$($_.Name):$($_.Hash)" } | Sort-Object) -join '|')
}

function Get-PMMResolutionToken($Row) {
  $choice=[string]$Row.SelectedChoice
  if($choice -eq 'Custom'){
    $raw=[string]$Row.CustomValue
    if([string]::IsNullOrWhiteSpace($raw)){return 'Custom:'}
    return ('Custom:'+$raw.Trim())
  }
  return $choice
}


function Get-PMMPriorityDefaultChoice([array]$ProviderRecords,[array]$CompetingMods,[array]$Choices) {
  $competing=[System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
  foreach($name in @($CompetingMods)){if(-not[string]::IsNullOrWhiteSpace([string]$name)){[void]$competing.Add([string]$name)}}
  $allowed=[System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
  foreach($choice in @($Choices)){if(-not[string]::IsNullOrWhiteSpace([string]$choice)){[void]$allowed.Add([string]$choice)}}
  $candidates=@($ProviderRecords|Where-Object{
    $name=[string]$_.Mod.Name
    $competing.Contains($name) -and $allowed.Contains($name)
  }|Sort-Object @{Expression={if($_.Mod.PSObject.Properties.Name -contains 'Priority'){[int]$_.Mod.Priority}else{0}}},@{Expression={[string]$_.Mod.Name}})
  if($candidates.Count -eq 0){return ''}
  return [string]$candidates[-1].Mod.Name
}

function Get-PMMConflictInitialSelection($Previous,[array]$Choices,[array]$ProviderRecords,[array]$CompetingMods) {
  if($Previous){
    $previousChoice=[string]$Previous.SelectedChoice
    $previousValid=($previousChoice -in @($Choices))
    $previousOrigin=if($Previous.PSObject.Properties.Name -contains 'ResolutionOrigin'){[string]$Previous.ResolutionOrigin}else{'Manual'}
    if($previousValid -and $previousOrigin -ne 'Priority'){
      return [pscustomobject]@{Choice=$previousChoice;Custom=[string]$Previous.CustomValue;Origin='Manual';Status=(Get-PMMText 'Resolved' 'Resuelto')}
    }
  }
  $priorityChoice=Get-PMMPriorityDefaultChoice $ProviderRecords $CompetingMods $Choices
  if(-not[string]::IsNullOrWhiteSpace($priorityChoice)){
    return [pscustomobject]@{Choice=$priorityChoice;Custom='';Origin='Priority';Status=(Get-PMMText 'Resolved by priority' 'Resuelto por prioridad')}
  }
  return [pscustomobject]@{Choice='';Custom='';Origin='';Status=(Get-PMMText 'Decision required' 'Decision requerida')}
}

function Read-PMMPackageRules {
  $path=Get-PMMPackageRulesPath
  if(-not(Test-Path -LiteralPath $path -PathType Leaf)){return @()}
  try{
    $doc=Get-Content -LiteralPath $path -Raw|ConvertFrom-Json -ErrorAction Stop
    if(-not$doc -or [string]$doc.schema -ne 'PMM_PACKAGE_RULES_V1'){return @()}
    return @($doc.rules)
  }catch{
    Write-PMMLog ("Package rules could not be read: {0}" -f $_.Exception.Message)
    return @()
  }
}

function Get-PMMPackageChoiceAnalyses([array]$Mods,$PreviousMap) {
  $result=[System.Collections.Generic.List[object]]::new()
  foreach($rule in @(Read-PMMPackageRules)){
    $members=@($rule.members|ForEach-Object{[string]$_}|Where-Object{$_})
    if($members.Count -lt 2){continue}
    $present=@($Mods|Where-Object{[string]$_.Name -in $members}|Sort-Object Priority,Name)

    # Package rules are deliberately conservative.  This first rule only
    # activates when every declared alternative/component is simultaneously
    # active, which is an installation state the package author says not to use.
    if([string]$rule.trigger -eq 'allMembersActive' -and $present.Count -ne $members.Count){continue}
    if($present.Count -lt 2){continue}

    $packageChoices=[System.Collections.Generic.List[object]]::new()
    foreach($choice in @($rule.choices)){
      $enabled=@($choice.enabled|ForEach-Object{[string]$_}|Where-Object{$_})
      if($enabled.Count -eq 0){continue}
      $allAvailable=$true
      foreach($name in $enabled){if($name -notin @($present.Name)){$allAvailable=$false;break}}
      if(-not$allAvailable){continue}
      $packageChoices.Add([pscustomobject]@{
        Id=[string]$choice.id
        Choice=[string]$choice.label
        Enabled=$enabled
        Suppressed=@($choice.suppressed|ForEach-Object{[string]$_}|Where-Object{$_})
      })
    }
    if($packageChoices.Count -lt 2){continue}

    $assetKey='package:'+[string]$rule.id
    $providerSignature=Get-PMMProviderSignature $present
    $decisionId=New-PMMDecisionId $assetKey 'PackageVariant' $providerSignature
    $previous=$null
    if($PreviousMap -and $PreviousMap.ContainsKey($decisionId)){$previous=$PreviousMap[$decisionId]}
    $choiceLabels=@($packageChoices|ForEach-Object{[string]$_.Choice})
    $selected='';$origin='';$status=Get-PMMText 'Decision required' 'Decision requerida'
    if($previous){
      $previousChoice=[string]$previous.SelectedChoice
      $previousOrigin=if($previous.PSObject.Properties.Name -contains 'ResolutionOrigin'){[string]$previous.ResolutionOrigin}else{'Manual'}
      if($previousChoice -in $choiceLabels -and $previousOrigin -ne 'Priority'){
        $selected=$previousChoice;$origin='Manual';$status=Get-PMMText 'Resolved' 'Resuelto'
      }
    }

    $options=[ordered]@{}
    foreach($name in @($present.Name)){
      $belongs=@($packageChoices|Where-Object{[string]$name -in @($_.Enabled)}|ForEach-Object{[string]$_.Choice})
      $role=if($belongs.Count -gt 0){$belongs -join ' / '}else{Get-PMMText 'Alternative component' 'Componente alternativo'}
      $options[[string]$name]=ConvertTo-Json -InputObject $role -Compress
    }
    $reason=if([string]::IsNullOrWhiteSpace($selected)){
      Get-PMMText 'These PAKs are alternative components of one mod package. Choose one valid package variant, then run Analyze again. PMM will keep every PAK in the library but exclude the unselected alternative from analysis and deployment.' 'Estos PAK son componentes alternativos de un mismo paquete de mod. Elige una variante valida y vuelve a ejecutar Analizar. PMM conservara todos los PAK en la biblioteca, pero excluira la alternativa no elegida del analisis y del despliegue.'
    }else{
      $picked=@($packageChoices|Where-Object{[string]$_.Choice -eq $selected}|Select-Object -First 1)[0]
      $suppressedText=@($picked.Suppressed) -join ', '
      (Get-PMMText 'Package variant selected: {0}. PMM will exclude from analysis/deployment: {1}.' 'Variante de paquete seleccionada: {0}. PMM excluira del analisis/despliegue: {1}.') -f $selected,$suppressedText
    }
    $asset=[pscustomobject]@{
      AssetKey=$assetKey
      Asset=[string]$rule.title
      Providers=@($present.Name)
      Mode='PackageChoice'
      ConflictCount=1
      ChangedPathCount=0
      Reason=$reason
      ReviewFolder=''
      PackageRuleId=[string]$rule.id
      PackageSource=[string]$rule.source
    }
    $row=[pscustomobject]@{
      DecisionId=$decisionId
      DecisionKind='PackageChoice'
      PackageRuleId=[string]$rule.id
      AssetKey=$assetKey
      Asset=[string]$asset.Asset
      Property='PackageVariant'
      DisplayProperty=(Get-PMMText 'Package variant' 'Variante del paquete')
      VanillaJson=(ConvertTo-Json -InputObject (Get-PMMText 'Choose one valid installation set' 'Elige un conjunto de instalacion valido') -Compress)
      Options=[pscustomobject]$options
      Choices=$choiceLabels
      PackageChoices=$packageChoices.ToArray()
      CompetingMods=@($present.Name)
      SelectedChoice=$selected
      CustomValue=''
      ResolutionOrigin=$origin
      Status=$status
    }
    $result.Add([pscustomobject]@{Asset=$asset;Row=$row})
  }
  return $result.ToArray()
}

function Get-PMMPackageChoiceSuppressions([array]$Rows) {
  $suppressed=[System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
  foreach($row in @($Rows|Where-Object{($_.PSObject.Properties.Name -contains 'DecisionKind') -and [string]$_.DecisionKind -eq 'PackageChoice'})){
    $selected=[string]$row.SelectedChoice
    if([string]::IsNullOrWhiteSpace($selected) -or -not($row.PSObject.Properties.Name -contains 'PackageChoices')){continue}
    $choice=@($row.PackageChoices|Where-Object{[string]$_.Choice -eq $selected}|Select-Object -First 1)[0]
    if(-not$choice){continue}
    foreach($name in @($choice.Suppressed)){
      if(-not[string]::IsNullOrWhiteSpace([string]$name)){[void]$suppressed.Add([string]$name)}
    }
  }
  return @($suppressed|Sort-Object)
}

function Get-PMMDecisionSignature([array]$Rows) {
  $parts=@($Rows|ForEach-Object{
    $choice=[string]$_.SelectedChoice
    $custom=[string]$_.CustomValue
    ("{0}:{1}:{2}" -f [string]$_.DecisionId,$choice,$custom)
  }|Sort-Object)
  return (Get-PMMStableTextId ($parts -join '|'))
}

function Get-PMMBuildEvidenceSignature([array]$Evidence) {
  $parts=[System.Collections.Generic.List[string]]::new()
  foreach($asset in @($Evidence|Sort-Object @{Expression={[string]$_.AssetKey}},@{Expression={[string]$_.Asset}})){
    foreach($part in @($asset.OutputParts|Sort-Object @{Expression={[string]$_.Part}})){
      $parts.Add(("{0}|{1}|{2}|{3}" -f [string]$asset.AssetKey,[string]$part.Part,[int64]$part.Bytes,[string]$part.Sha256))
    }
  }
  return (Get-PMMStableTextId ($parts -join ';'))
}

function Read-PMMMergePlan {
  $path = Get-PMMMergePlanPath
  if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { return $null }
  try { return (Get-Content -LiteralPath $path -Raw | ConvertFrom-Json) } catch { return $null }
}

function Write-PMMMergePlan($Plan) {
  $Plan | ConvertTo-Json -Depth 80 | Set-Content -LiteralPath (Get-PMMMergePlanPath) -Encoding UTF8
}

function Get-PMMAssetGroups([array]$Mods) {
  $groups = @{}
  foreach ($mod in @($Mods)) {
    foreach ($entry in @(Get-PakEntriesCached $mod.Path)) {
      $normalized = ([string]$entry).Replace([char]92,[char]47)
      if($normalized -match '(?i)\.(uasset|uexp|ubulk)\.bak$'){continue}
      $ext = [IO.Path]::GetExtension($normalized).ToLowerInvariant()
      if ($ext -in @('.uasset','.uexp','.ubulk')) {
        $base = Get-PakLogicalStem $normalized
        $logical = $base + '.uasset'
        $key = $logical.ToLowerInvariant()
        $kind = 'AssetFamily'
      } else {
        $logical = $normalized
        $key = $normalized.ToLowerInvariant()
        $kind = 'File'
      }
      if (-not $groups.ContainsKey($key)) {
        $groups[$key] = [pscustomobject]@{Key=$key;Asset=$logical;Kind=$kind;Providers=@{}}
      }
      if ($ext -eq '.uasset') { $groups[$key].Asset = $normalized }
      $groups[$key].Providers[$mod.Name] = $true
    }
  }
  $result = New-Object System.Collections.Generic.List[object]
  foreach ($group in $groups.Values) {
    $result.Add([pscustomobject]@{
      Key=[string]$group.Key
      Asset=[string]$group.Asset
      Kind=[string]$group.Kind
      Providers=@($Mods|Where-Object{$group.Providers.ContainsKey([string]$_.Name)}|Sort-Object @{Expression={if($_.PSObject.Properties.Name -contains 'Priority'){[int]$_.Priority}else{2147483647}}},Name|ForEach-Object{[string]$_.Name})
    })
  }
  return @($result.ToArray() | Sort-Object Asset)
}

function Get-VanillaPakFiles {
  $cfg = Get-PMMConfig
  if (-not $cfg.GamePath) { return @() }
  $pakRoot = Join-Path $cfg.GamePath 'Pal\Content\Paks'
  if (-not (Test-Path -LiteralPath $pakRoot -PathType Container)) { return @() }
  return @(Get-ChildItem -LiteralPath $pakRoot -Filter *.pak -File -ErrorAction SilentlyContinue |
    Sort-Object @{Expression={ if ($_.Name -ieq 'Pal-Windows.pak') { 0 } else { 1 } }},Name)
}

function Get-PMMVanillaPakSetQuickSignature {
  # Cheap staleness sentinel for Analyze/Build/patch validity. Hashing the
  # complete Palworld PAK set on every UI refresh would be prohibitively slow;
  # exact per-file SHA-256 validation is still performed by AIIO where needed.
  $parts=@(Get-VanillaPakFiles|ForEach-Object{
    ('{0}:{1}:{2}' -f $_.Name,[int64]$_.Length,$_.LastWriteTimeUtc.Ticks)
  })
  return (Get-PMMStableTextId ('VANILLA_PAK_SET_V1|'+($parts -join '|')))
}

function Export-VanillaAssetFamilyExact([string]$Asset,[string]$OutRoot) {
  foreach ($pak in @(Get-VanillaPakFiles)) {
    $entries = @(Get-PakEntriesCached $pak.FullName)
    if (-not (Find-PakEntryExact $entries $Asset)) { continue }
    return (Export-PakAssetFamilyExact $pak.FullName $Asset $OutRoot)
  }
  return $null
}

function Export-VanillaFileExact([string]$LogicalPath,[string]$OutRoot) {
  foreach ($pak in @(Get-VanillaPakFiles)) {
    $entries = @(Get-PakEntriesCached $pak.FullName)
    if (-not (Find-PakEntryExact $entries $LogicalPath)) { continue }
    return (Export-PakFileExact $pak.FullName $LogicalPath $OutRoot)
  }
  return $null
}

function ConvertTo-PMMDisplayValue([string]$Json) {
  if ([string]::IsNullOrWhiteSpace($Json)) { return '' }
  try {
    $value = $Json | ConvertFrom-Json -ErrorAction Stop
    if ($null -eq $value) { return 'null' }
    if ($value -is [string]) { return [string]$value }
    return [string]$value
  } catch { return $Json }
}

function Invoke-PMMProgress([int]$Current,[int]$Total,[string]$Message,[switch]$Indeterminate) {
  $callback = Get-Command Set-PMMAnalyzeProgress -ErrorAction SilentlyContinue
  if ($callback) {
    try { Set-PMMAnalyzeProgress -Current $Current -Total $Total -Message $Message -Indeterminate:$Indeterminate } catch {}
  }
}

function Invoke-PMMBuildProgress([int]$Current,[int]$Total,[string]$Message,[switch]$Indeterminate) {
  $callback = Get-Command Set-PMMBuildProgress -ErrorAction SilentlyContinue
  if ($callback) {
    try { Set-PMMBuildProgress -Current $Current -Total $Total -Message $Message -Indeterminate:$Indeterminate } catch {}
  }
}
function Get-PMMPreviousDecisionMap {
  $map = @{}
  $previous = Read-PMMMergePlan
  if ($previous) {
    foreach ($row in @($previous.Rows)) {
      if ($row.DecisionId) { $map[[string]$row.DecisionId] = $row }
    }
  }
  return $map
}

function New-PMMDecisionId([string]$AssetKey,[string]$Property,[string]$ProviderSignature) {
  return (Get-PMMStableTextId ($AssetKey + '|' + $Property + '|' + $ProviderSignature))
}

function Get-PMMFamilyPartPath($Export,[string]$Extension) {
  # Under StrictMode, a polluted/array return from an extraction helper used to
  # surface as the opaque "property HeaderPath was not found" error.  Validate
  # the contract here so Analyze either unwraps the one valid export record or
  # reports exactly what was malformed.
  $candidate=$Export
  if($candidate -is [System.Array]){
    $withHeader=@($candidate|Where-Object{$_ -and ($_.PSObject.Properties.Name -contains 'HeaderPath')})
    if($withHeader.Count -eq 1){$candidate=$withHeader[0]}
  }
  if(-not$candidate -or -not($candidate.PSObject.Properties.Name -contains 'HeaderPath')){
    $type=if($null -eq $candidate){'<null>'}else{$candidate.GetType().FullName}
    $props=if($null -eq $candidate){''}else{(@($candidate.PSObject.Properties.Name) -join ', ')}
    throw ("PMM internal asset-family record is missing HeaderPath. Type={0}; Properties={1}" -f $type,$props)
  }
  $header=[string]$candidate.HeaderPath
  if([string]::IsNullOrWhiteSpace($header)){throw 'PMM internal asset-family record contains an empty HeaderPath.'}
  return [IO.Path]::ChangeExtension($header,$Extension)
}

function Get-PMMAssetFamilyCacheFingerprint([string]$HeaderPath) {
  # Semantic data lives in the complete cooked family, not only in the .uasset
  # header. FlyMode and FoodNeverSpoils are a real regression case: their
  # .uasset files are byte-identical while their .uexp payloads are different.
  # A cache keyed only by .uasset therefore aliases two different mods and
  # erases the very delta PMM is supposed to merge.
  $parts=New-Object System.Collections.Generic.List[string]
  foreach($ext in @('.uasset','.uexp','.ubulk')){
    $path=[IO.Path]::ChangeExtension($HeaderPath,$ext)
    if(Test-Path -LiteralPath $path -PathType Leaf){
      $item=Get-Item -LiteralPath $path
      $parts.Add(("{0}:{1}:{2}" -f $ext,$item.Length,(Get-Sha256 $path)))
    }else{
      $parts.Add(("{0}:missing" -f $ext))
    }
  }
  return (Get-PMMStableTextId ($parts -join '|'))
}

function Test-PMMFamiliesIdentical($Left,$Right) {
  foreach ($ext in @('.uasset','.uexp','.ubulk')) {
    $a = Get-PMMFamilyPartPath $Left $ext
    $b = Get-PMMFamilyPartPath $Right $ext
    $ae = Test-Path -LiteralPath $a -PathType Leaf
    $be = Test-Path -LiteralPath $b -PathType Leaf
    if ($ae -ne $be) { return $false }
    if ($ae -and ((Get-Sha256 $a) -ne (Get-Sha256 $b))) { return $false }
  }
  return $true
}

function Test-PMMCurrentLayoutProvider($Vanilla,$Provider) {
  $vu = Get-PMMFamilyPartPath $Vanilla '.uasset'
  $pu = Get-PMMFamilyPartPath $Provider '.uasset'
  if ((Get-Sha256 $vu) -ne (Get-Sha256 $pu)) { return $false }
  foreach ($ext in @('.uexp','.ubulk')) {
    $a = Get-PMMFamilyPartPath $Vanilla $ext
    $b = Get-PMMFamilyPartPath $Provider $ext
    $ae = Test-Path -LiteralPath $a -PathType Leaf
    $be = Test-Path -LiteralPath $b -PathType Leaf
    if ($ae -ne $be) { return $false }
    if ($ae -and ((Get-Item -LiteralPath $a).Length -ne (Get-Item -LiteralPath $b).Length)) { return $false }
  }
  return $true
}

function Copy-PMMExtractedFamily($Export,[string]$OutRoot,[string]$Asset) {
  $stem = Get-PakLogicalStem $Asset
  foreach ($ext in @('.uasset','.uexp','.ubulk')) {
    $src = Get-PMMFamilyPartPath $Export $ext
    if (-not (Test-Path -LiteralPath $src -PathType Leaf)) { continue }
    $dst = Join-Path $OutRoot (($stem + $ext).Replace([char]47,[char]92))
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $dst) | Out-Null
    Copy-Item -LiteralPath $src -Destination $dst -Force
  }
}

function Invoke-PMMCore([array]$Arguments,[string]$Context) {
  $dll = Get-PMMCorePath
  $dotnet = Get-PMMDotnetHostPath
  if(-not $dotnet){throw 'Portable .NET host is unavailable.'}
  $output = & $dotnet $dll @Arguments 2>&1
  $exit = $LASTEXITCODE
  Write-PMMProcessOutputLog -Prefix ("PMMCore {0}" -f $Context) -Output @($output)
  return [pscustomobject]@{ExitCode=$exit;Output=@($output)}
}

function Invoke-PMMBinaryMerge([string]$Asset,$Vanilla,[array]$ProviderRecords,[string]$OutRoot,$ResolutionRows=$null,[string]$Transaction='') {
  if ($ProviderRecords.Count -eq 0) {
    Copy-PMMExtractedFamily $Vanilla $OutRoot $Asset
    return [pscustomobject]@{ExitCode=0;Output=@('Vanilla base copied')}
  }
  $args = @('binary-merge','--vanilla-root',[string]$Vanilla.Root,'--asset',$Asset,'--out-root',$OutRoot)
  foreach ($record in $ProviderRecords) {
    $args += @('--provider',("{0}={1}" -f [string]$record.Mod.Name,[string]$record.Export.Root))
  }
  if($ResolutionRows){
    if([string]::IsNullOrWhiteSpace($Transaction)){throw 'Binary conflict build requires a transaction directory.'}
    $resolutionPath=Join-Path $Transaction ('BinaryResolutions\'+(Get-PMMStableTextId $Asset)+'.json')
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $resolutionPath)|Out-Null
    $resolutionObject=[ordered]@{}
    foreach($row in @($ResolutionRows)){$resolutionObject[[string]$row.Property]=(Get-PMMResolutionToken $row)}
    $resolutionObject|ConvertTo-Json -Depth 10|Set-Content -LiteralPath $resolutionPath -Encoding UTF8
    $args += @('--resolutions',$resolutionPath)
  }
  return (Invoke-PMMCore $args ("binary-merge $Asset"))
}

function Invoke-PMMBinaryPlan([string]$Asset,$Vanilla,[array]$ProviderRecords,[string]$Transaction) {
  $report=Join-Path $Transaction ('BinaryReports\'+(Get-PMMStableTextId $Asset)+'.json')
  New-Item -ItemType Directory -Force -Path (Split-Path -Parent $report)|Out-Null
  $args=@('binary-plan','--vanilla-root',[string]$Vanilla.Root,'--asset',$Asset,'--report',$report)
  foreach($record in $ProviderRecords){$args += @('--provider',("{0}={1}" -f [string]$record.Mod.Name,[string]$record.Export.Root))}
  $run=Invoke-PMMCore $args ("binary-plan $Asset")
  $reportObject=$null
  if(Test-Path -LiteralPath $report -PathType Leaf){$reportObject=Get-Content -LiteralPath $report -Raw|ConvertFrom-Json}
  return [pscustomobject]@{Run=$run;ReportPath=$report;Report=$reportObject}
}

function Get-PMMSemanticJsonCached([string]$HeaderPath) {
  $reader = Get-PMMAssetReaderPath
  $mappings = Get-PMMMappingsPath
  $mappingHash = Get-Sha256 $mappings
  $familyKey = Get-PMMAssetFamilyCacheFingerprint $HeaderPath
  $cache = Join-Path (Get-PMMPath 'Cache') ('SemanticJson\v2_UE5_1_' + $mappingHash.Substring(0,12) + '_' + $familyKey + '.json')
  if (Test-Path -LiteralPath $cache -PathType Leaf) { return $cache }
  New-Item -ItemType Directory -Force -Path (Split-Path -Parent $cache) | Out-Null
  $dotnet = Get-PMMDotnetHostPath
  if(-not $dotnet){throw 'Portable .NET host is unavailable.'}
  $output = & $dotnet $reader 'export-json' '--asset' $HeaderPath '--output' $cache '--mappings' $mappings '--engine' 'UE5_1' 2>&1
  $exit = $LASTEXITCODE
  Write-PMMProcessOutputLog -Prefix 'AssetReader' -Output @($output)
  if ($exit -ne 0 -or -not (Test-Path -LiteralPath $cache -PathType Leaf)) {
    Remove-Item -LiteralPath $cache -Force -ErrorAction SilentlyContinue
    throw "AssetReader could not export semantic JSON for $HeaderPath (exit $exit)."
  }
  return $cache
}


function Get-PMMDataTableMapCached([string]$HeaderPath) {
  $reader = Get-PMMAssetReaderPath
  $mappings = Get-PMMMappingsPath
  $mappingHash = Get-Sha256 $mappings
  $familyKey = Get-PMMAssetFamilyCacheFingerprint $HeaderPath
  $cache = Join-Path (Get-PMMPath 'Cache') ('DataTableMaps\v2_UE5_1_' + $mappingHash.Substring(0,12) + '_' + $familyKey + '.json')
  if (Test-Path -LiteralPath $cache -PathType Leaf) { return $cache }
  New-Item -ItemType Directory -Force -Path (Split-Path -Parent $cache) | Out-Null
  $dotnet = Get-PMMDotnetHostPath
  if(-not $dotnet){throw 'Portable .NET host is unavailable.'}
  $output = & $dotnet $reader 'export-datatable' '--asset' $HeaderPath '--output' $cache '--mappings' $mappings '--engine' 'UE5_1' 2>&1
  $exit = $LASTEXITCODE
  Write-PMMProcessOutputLog -Prefix 'AssetReader DataTable' -Output @($output)
  if ($exit -ne 0 -or -not (Test-Path -LiteralPath $cache -PathType Leaf)) {
    Remove-Item -LiteralPath $cache -Force -ErrorAction SilentlyContinue
    throw "DataTable semantic reader could not map $HeaderPath (exit $exit)."
  }
  return $cache
}

function Get-PMMExtractedFamilySize($Export) {
  $total = [int64]0
  foreach($ext in @('.uasset','.uexp','.ubulk')){
    $path=Get-PMMFamilyPartPath $Export $ext
    if(Test-Path -LiteralPath $path -PathType Leaf){$total += (Get-Item -LiteralPath $path).Length}
  }
  return $total
}

function Invoke-PMMContainedSupersetMerge($Group,$Vanilla,[array]$ProviderRecords,[string]$Transaction,[string]$OutRoot) {
  $assetId = Get-PMMStableTextId ([string]$Group.Key)
  $report = Join-Path $Transaction ('ContainedSupersetReports\' + $assetId + '.json')
  New-Item -ItemType Directory -Force -Path (Split-Path -Parent $report) | Out-Null
  $args=@('contained-superset-merge','--vanilla-root',[string]$Vanilla.Root,'--asset',[string]$Group.Asset,'--out-root',$OutRoot,'--report',$report)
  foreach($record in $ProviderRecords){$args += @('--provider',("{0}={1}" -f [string]$record.Mod.Name,[string]$record.Export.Root))}
  $run=Invoke-PMMCore $args ("contained-superset-merge $($Group.Asset)")
  $reportObject=$null
  if(Test-Path -LiteralPath $report -PathType Leaf){$reportObject=Get-Content -LiteralPath $report -Raw|ConvertFrom-Json}
  return [pscustomobject]@{Run=$run;ReportPath=$report;Report=$reportObject}
}

function Invoke-PMMRelocatableMerge($Group,$Vanilla,[array]$ProviderRecords,[string]$Transaction,[string]$OutRoot,$ResolutionRows=$null) {
  $assetId = Get-PMMStableTextId ([string]$Group.Key)
  $report = Join-Path $Transaction ('RelocatableReports\' + $assetId + '.json')
  New-Item -ItemType Directory -Force -Path (Split-Path -Parent $report) | Out-Null
  $args=@('relocatable-merge','--vanilla-root',[string]$Vanilla.Root,'--asset',[string]$Group.Asset,'--out-root',$OutRoot,'--report',$report)
  foreach($record in $ProviderRecords){$args += @('--provider',("{0}={1}" -f [string]$record.Mod.Name,[string]$record.Export.Root))}
  if($ResolutionRows){
    $resolutionPath=Join-Path $Transaction ('RelocatableResolutions\'+$assetId+'.json')
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $resolutionPath)|Out-Null
    $resolutionObject=[ordered]@{}
    foreach($row in @($ResolutionRows)){$resolutionObject[[string]$row.Property]=(Get-PMMResolutionToken $row)}
    $resolutionObject|ConvertTo-Json -Depth 10|Set-Content -LiteralPath $resolutionPath -Encoding UTF8
    $args += @('--resolutions',$resolutionPath)
  }
  $run=Invoke-PMMCore $args ("relocatable-merge $($Group.Asset)")
  $reportObject=$null
  if(Test-Path -LiteralPath $report -PathType Leaf){$reportObject=Get-Content -LiteralPath $report -Raw|ConvertFrom-Json}
  return [pscustomobject]@{Run=$run;ReportPath=$report;Report=$reportObject}
}

function Invoke-PMMSupersetMerge($Group,$Vanilla,[array]$ProviderRecords,[string]$Transaction,[string]$OutRoot) {
  $assetId = Get-PMMStableTextId ([string]$Group.Key)
  $report = Join-Path $Transaction ('SupersetReports\' + $assetId + '.json')
  New-Item -ItemType Directory -Force -Path (Split-Path -Parent $report) | Out-Null
  $args=@('superset-merge','--vanilla-root',[string]$Vanilla.Root,'--asset',[string]$Group.Asset,'--out-root',$OutRoot,'--report',$report)
  foreach($record in $ProviderRecords){$args += @('--provider',("{0}={1}" -f [string]$record.Mod.Name,[string]$record.Export.Root))}
  $run=Invoke-PMMCore $args ("superset-merge $($Group.Asset)")
  $reportObject=$null
  if(Test-Path -LiteralPath $report -PathType Leaf){$reportObject=Get-Content -LiteralPath $report -Raw|ConvertFrom-Json}
  return [pscustomobject]@{Run=$run;ReportPath=$report;Report=$reportObject}
}

function Invoke-PMMDataTableMerge($Group,$Vanilla,[array]$ProviderRecords,[string]$Transaction,[string]$OutRoot,$ResolutionRows=$null) {
  $assetId=Get-PMMStableTextId ([string]$Group.Key)
  $vanillaMap=Get-PMMDataTableMapCached ([string]$Vanilla.HeaderPath)
  $maps=New-Object System.Collections.Generic.List[object]
  foreach($record in $ProviderRecords){
    $maps.Add([pscustomobject]@{Record=$record;Map=(Get-PMMDataTableMapCached ([string]$record.Export.HeaderPath))})
  }
  $baseRecord=@($ProviderRecords|Sort-Object @{Expression={Get-PMMExtractedFamilySize $_.Export};Descending=$true},@{Expression={$_.Mod.Name}}|Select-Object -First 1)[0]
  if(-not$baseRecord){throw 'DataTable adapter could not choose a cooked base provider.'}
  $baseMapRecord=@($maps.ToArray()|Where-Object{$_.Record.Mod.Name -eq $baseRecord.Mod.Name}|Select-Object -First 1)[0]
  if(-not$baseMapRecord){throw 'DataTable adapter could not locate the selected base provider semantic map.'}
  $baseMap=[string]$baseMapRecord.Map
  $stem=Get-PakLogicalStem ([string]$Group.Asset)
  $baseUasset=Get-PMMFamilyPartPath $baseRecord.Export '.uasset'
  $baseUexp=Get-PMMFamilyPartPath $baseRecord.Export '.uexp'
  if(-not(Test-Path -LiteralPath $baseUexp -PathType Leaf)){throw 'DataTable adapter requires a .uexp sidecar.'}
  $outUasset=Join-Path $OutRoot (($stem+'.uasset').Replace([char]47,[char]92))
  $outUexp=Join-Path $OutRoot (($stem+'.uexp').Replace([char]47,[char]92))
  $report=Join-Path $Transaction ('DataTableReports\'+$assetId+'.json')
  New-Item -ItemType Directory -Force -Path (Split-Path -Parent $report)|Out-Null
  $args=@('datatable-merge','--vanilla-map',$vanillaMap,'--base-provider',[string]$baseRecord.Mod.Name,'--base-map',$baseMap,'--base-uasset',$baseUasset,'--base-uexp',$baseUexp,'--out-uasset',$outUasset,'--out-uexp',$outUexp,'--report',$report)
  foreach($m in $maps.ToArray()){$args += @('--provider-map',("{0}={1}" -f [string]$m.Record.Mod.Name,[string]$m.Map))}
  if($ResolutionRows){
    $resolutionPath=Join-Path $Transaction ('DataTableResolutions\'+$assetId+'.json')
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $resolutionPath)|Out-Null
    $resolutionObject=[ordered]@{}
    foreach($row in @($ResolutionRows)){$resolutionObject[[string]$row.Property]=(Get-PMMResolutionToken $row)}
    $resolutionObject|ConvertTo-Json -Depth 10|Set-Content -LiteralPath $resolutionPath -Encoding UTF8
    $args += @('--resolutions',$resolutionPath)
  }
  $run=Invoke-PMMCore $args ("datatable-merge $($Group.Asset)")
  $reportObject=$null
  if(Test-Path -LiteralPath $report -PathType Leaf){$reportObject=Get-Content -LiteralPath $report -Raw|ConvertFrom-Json}
  if($run.ExitCode -eq 0){
    $baseUbulk=Get-PMMFamilyPartPath $baseRecord.Export '.ubulk'
    if(Test-Path -LiteralPath $baseUbulk -PathType Leaf){
      $outUbulk=Join-Path $OutRoot (($stem+'.ubulk').Replace([char]47,[char]92))
      New-Item -ItemType Directory -Force -Path (Split-Path -Parent $outUbulk)|Out-Null
      Copy-Item -LiteralPath $baseUbulk -Destination $outUbulk -Force
    }
  }
  return [pscustomobject]@{Run=$run;ReportPath=$report;Report=$reportObject;BaseRecord=$baseRecord}
}

function New-PMMUnsupportedAnalysis($Group,[array]$ProviderRecords,[string]$Reason,[string]$ReviewFolder='',[string]$AIHandoff='',[string]$CaseId='') {
  $asset=[pscustomobject]@{AssetKey=[string]$Group.Key;Asset=[string]$Group.Asset;Providers=@($ProviderRecords|ForEach-Object{$_.Mod.Name});Mode='Unsupported';ConflictCount=0;ChangedPathCount=0;Reason=$Reason;ReviewFolder=$ReviewFolder;AIHandoff=$AIHandoff;CaseId=$CaseId}
  return [pscustomobject]@{Asset=$asset;Rows=@()}
}

function New-PMMKnownRecipeAnalysis($Group,[array]$ProviderRecords,$RecipeMatch,[string]$ReviewFolder='') {
  if(-not$RecipeMatch -or -not$RecipeMatch.Recipe){throw 'Known production recipe match is missing recipe metadata.'}
  if($ReviewFolder -and (Test-Path -LiteralPath $ReviewFolder -PathType Container)){
    try{
      [pscustomobject]@{
        Schema='PMM_PRODUCTION_RECIPE_MATCH_V1';RecipeId=[string]$RecipeMatch.RecipeId;CaseId=[string]$RecipeMatch.CaseId;
        Asset=[string]$Group.Asset;OutputProvider=[string]$RecipeMatch.OutputProvider;RuntimeStatus=[string]$RecipeMatch.RuntimeStatus;
        Safety='Exact runtime-proven fallback. Asset, mappings, Vanilla family, complete provider PAK set and every provider family hash matched the pinned production recipe.'
      }|ConvertTo-Json -Depth 12|Set-Content -LiteralPath (Join-Path $ReviewFolder 'production-recipe-match.json') -Encoding UTF8
    }catch{Write-PMMLog ('Could not write production recipe review evidence: '+$_.Exception.Message)}
  }
  $reason=('Runtime-proven exact Knowledge recipe matched. Recipe={0}; case={1}; reusing verified cooked provider={2}. Every pinned Vanilla/provider family hash and the complete provider set matched before authorization.' -f [string]$RecipeMatch.RecipeId,[string]$RecipeMatch.CaseId,[string]$RecipeMatch.OutputProvider)
  $asset=[pscustomobject]@{
    AssetKey=[string]$Group.Key;Asset=[string]$Group.Asset;Providers=@($ProviderRecords|ForEach-Object{$_.Mod.Name});
    Mode='KnownRecipeAuto';ConflictCount=0;ChangedPathCount=1;Reason=$reason;ReviewFolder=$ReviewFolder;
    RecipeId=[string]$RecipeMatch.RecipeId;RecipeCaseId=[string]$RecipeMatch.CaseId;RecipeOutputProvider=[string]$RecipeMatch.OutputProvider
  }
  return [pscustomobject]@{Asset=$asset;Rows=@()}
}

function New-PMMBinaryConflictAnalysis($Group,[array]$ProviderRecords,$Vanilla,$BinaryResult,$PreviousMap,[string]$ReviewFolder) {
  $providerSignature=Get-PMMProviderSignature @($ProviderRecords|ForEach-Object{$_.Mod})
  $rows=New-Object System.Collections.Generic.List[object]
  foreach($conflict in @($BinaryResult.Report.conflicts)){
    $path=[string]$conflict.key
    $decisionId=New-PMMDecisionId ([string]$Group.Key) $path $providerSignature
    $previous=if($PreviousMap.ContainsKey($decisionId)){$PreviousMap[$decisionId]}else{$null}
    $choices=New-Object System.Collections.Generic.List[string];$choices.Add('Vanilla')
    $options=[ordered]@{}
    foreach($record in $ProviderRecords){
      $prop=$conflict.requestedValues.PSObject.Properties[[string]$record.Mod.Name]
      if($prop){
        $choices.Add([string]$record.Mod.Name)
        $options[[string]$record.Mod.Name]=(ConvertTo-Json -InputObject ([int]$prop.Value) -Compress)
      }
    }
    $choices.Add('Custom')
    $competing=@($conflict.requestedValues.PSObject.Properties.Name)
    $initial=Get-PMMConflictInitialSelection $previous $choices.ToArray() $ProviderRecords $competing
    $rows.Add([pscustomobject]@{
      DecisionId=$decisionId;AssetKey=[string]$Group.Key;Asset=[string]$Group.Asset;Property=$path;DisplayProperty=("{0} byte 0x{1:X}" -f [string]$conflict.part,[int]$conflict.offset);
      VanillaJson=(ConvertTo-Json -InputObject ([int]$conflict.vanilla) -Compress);Options=[pscustomobject]$options;Choices=$choices.ToArray();CompetingMods=$competing;
      SelectedChoice=[string]$initial.Choice;CustomValue=[string]$initial.Custom;ResolutionOrigin=[string]$initial.Origin;Status=[string]$initial.Status
    })
  }
  $asset=[pscustomobject]@{AssetKey=[string]$Group.Key;Asset=[string]$Group.Asset;Providers=@($ProviderRecords|ForEach-Object{$_.Mod.Name});Mode='BinaryConflict';ConflictCount=$rows.Count;ChangedPathCount=$rows.Count;Reason='Providers use the same cooked layout but write different bytes at the listed overlaps. Choose only those overlapping bytes; every non-conflicting change is still merged.';ReviewFolder=$ReviewFolder}
  return [pscustomobject]@{Asset=$asset;Rows=$rows.ToArray()}
}

function New-PMMRelocatableConflictAnalysis($Group,[array]$ProviderRecords,$RelocatableResult,$PreviousMap,[string]$ReviewFolder) {
  $providerSignature=Get-PMMProviderSignature @($ProviderRecords|ForEach-Object{$_.Mod})
  $rows=New-Object System.Collections.Generic.List[object]
  foreach($conflict in @($RelocatableResult.Report.conflicts)){
    $path=[string]$conflict.key
    $decisionId=New-PMMDecisionId ([string]$Group.Key) $path $providerSignature
    $previous=if($PreviousMap.ContainsKey($decisionId)){$PreviousMap[$decisionId]}else{$null}
    $choices=New-Object System.Collections.Generic.List[string]
    $options=[ordered]@{}
    $supportsVanilla=($conflict.PSObject.Properties.Name -contains 'supportsVanilla' -and [bool]$conflict.supportsVanilla)
    $supportsCustom=(-not($conflict.PSObject.Properties.Name -contains 'supportsCustom')) -or [bool]$conflict.supportsCustom
    if($supportsVanilla){$choices.Add('Vanilla')}
    foreach($prop in @($conflict.requestedValues.PSObject.Properties | Sort-Object Name)){
      $choices.Add([string]$prop.Name)
      $options[[string]$prop.Name]=(ConvertTo-Json -InputObject ([int]$prop.Value) -Compress)
    }
    if($supportsCustom){$choices.Add('Custom')}
    $vanillaMeaning=if($supportsVanilla -and ($conflict.PSObject.Properties.Name -contains 'vanillaMeaning')){[string]$conflict.vanillaMeaning}else{''}
    $competing=@($conflict.requestedValues.PSObject.Properties.Name)
    $initial=Get-PMMConflictInitialSelection $previous $choices.ToArray() $ProviderRecords $competing
    $rows.Add([pscustomobject]@{
      DecisionId=$decisionId;AssetKey=[string]$Group.Key;Asset=[string]$Group.Asset;Property=$path;DisplayProperty=("{0} byte 0x{1:X} (same structural field, different value)" -f [string]$conflict.part,[int]$conflict.offset);
      VanillaJson=$(if($supportsVanilla){ConvertTo-Json -InputObject $vanillaMeaning -Compress}else{''});Options=[pscustomobject]$options;Choices=$choices.ToArray();CompetingMods=$competing;
      SelectedChoice=[string]$initial.Choice;CustomValue=[string]$initial.Custom;ResolutionOrigin=[string]$initial.Origin;Status=[string]$initial.Status
    })
  }
  $asset=[pscustomobject]@{AssetKey=[string]$Group.Key;Asset=[string]$Group.Asset;Providers=@($ProviderRecords|ForEach-Object{$_.Mod.Name});Mode='RelocatableConflict';ConflictCount=$rows.Count;ChangedPathCount=$rows.Count;Reason='Mods request different values inside the same structural variant. Resolve only those values; every independent change from this asset is still merged afterwards.';ReviewFolder=$ReviewFolder}
  return [pscustomobject]@{Asset=$asset;Rows=$rows.ToArray()}
}

function New-PMMDataTableConflictAnalysis($Group,[array]$ProviderRecords,$Vanilla,$DataTableResult,$PreviousMap,[string]$ReviewFolder) {
  $providerSignature=Get-PMMProviderSignature @($ProviderRecords|ForEach-Object{$_.Mod})
  $rows=New-Object System.Collections.Generic.List[object]
  foreach($conflict in @($DataTableResult.Report.conflicts)){
    $path=[string]$conflict.Path
    $decisionId=New-PMMDecisionId ([string]$Group.Key) $path $providerSignature
    $previous=if($PreviousMap.ContainsKey($decisionId)){$PreviousMap[$decisionId]}else{$null}
    $choices=New-Object System.Collections.Generic.List[string];$choices.Add('Vanilla')
    $options=[ordered]@{}
    foreach($record in $ProviderRecords){
      $prop=$conflict.Providers.PSObject.Properties[[string]$record.Mod.Name]
      if($prop){
        $choices.Add([string]$record.Mod.Name)
        $options[[string]$record.Mod.Name]=($prop.Value.Value|ConvertTo-Json -Compress -Depth 10)
      }
    }
    $choices.Add('Custom')
    $competing=@($conflict.Providers.PSObject.Properties.Name)
    $initial=Get-PMMConflictInitialSelection $previous $choices.ToArray() $ProviderRecords $competing
    $rows.Add([pscustomobject]@{
      DecisionId=$decisionId;AssetKey=[string]$Group.Key;Asset=[string]$Group.Asset;Property=$path;DisplayProperty=$path;
      VanillaJson=($conflict.Vanilla.Value|ConvertTo-Json -Compress -Depth 10);Options=[pscustomobject]$options;Choices=$choices.ToArray();CompetingMods=$competing;
      SelectedChoice=[string]$initial.Choice;CustomValue=[string]$initial.Custom;ResolutionOrigin=[string]$initial.Origin;Status=[string]$initial.Status
    })
  }
  $asset=[pscustomobject]@{AssetKey=[string]$Group.Key;Asset=[string]$Group.Asset;Providers=@($ProviderRecords|ForEach-Object{$_.Mod.Name});Mode='DataTableConflict';ConflictCount=$rows.Count;ChangedPathCount=$rows.Count;Reason='Mods change the same DataTable property to different values; choose only those true conflicts.';ReviewFolder=$ReviewFolder}
  return [pscustomobject]@{Asset=$asset;Rows=$rows.ToArray()}
}

function New-PMMStaticItemConflictAnalysis($Group,[array]$ProviderRecords,$StaticResult,$PreviousMap,[string]$ReviewFolder) {
  $providerSignature=Get-PMMProviderSignature @($ProviderRecords|ForEach-Object{$_.Mod})
  $rows=New-Object System.Collections.Generic.List[object]
  foreach($conflict in @($StaticResult.Report.inference.ambiguities)){
    $path=[string]$conflict.path
    $decisionId=New-PMMDecisionId ([string]$Group.Key) $path $providerSignature
    $previous=if($PreviousMap.ContainsKey($decisionId)){$PreviousMap[$decisionId]}else{$null}
    $choices=New-Object System.Collections.Generic.List[string]
    $options=[ordered]@{}
    if((-not($conflict.PSObject.Properties.Name -contains 'supportsVanilla')) -or [bool]$conflict.supportsVanilla){$choices.Add('Vanilla')}
    foreach($prop in @($conflict.providers.PSObject.Properties|Sort-Object Name)){
      $choices.Add([string]$prop.Name)
      $options[[string]$prop.Name]=($prop.Value|ConvertTo-Json -Compress -Depth 20)
    }
    if($conflict.PSObject.Properties.Name -contains 'supportsCustom' -and [bool]$conflict.supportsCustom){$choices.Add('Custom')}
    $competing=@($conflict.providers.PSObject.Properties.Name)
    $initial=Get-PMMConflictInitialSelection $previous $choices.ToArray() $ProviderRecords $competing
    $rows.Add([pscustomobject]@{
      DecisionId=$decisionId;AssetKey=[string]$Group.Key;Asset=[string]$Group.Asset;Property=$path;DisplayProperty=$path;
      VanillaJson=($conflict.vanilla|ConvertTo-Json -Compress -Depth 20);Options=[pscustomobject]$options;Choices=$choices.ToArray();CompetingMods=$competing;
      SelectedChoice=[string]$initial.Choice;CustomValue=[string]$initial.Custom;ResolutionOrigin=[string]$initial.Origin;Status=[string]$initial.Status
    })
  }
  $asset=[pscustomobject]@{AssetKey=[string]$Group.Key;Asset=[string]$Group.Asset;Providers=@($ProviderRecords|ForEach-Object{$_.Mod.Name});Mode='StaticItemConflict';ConflictCount=$rows.Count;ChangedPathCount=$rows.Count;Reason='Mods request different values for the same StaticItem property. Resolve only those properties; every other independent item-table change is still merged.';ReviewFolder=$ReviewFolder}
  return [pscustomobject]@{Asset=$asset;Rows=$rows.ToArray()}
}

function Invoke-PMMStaticItemMerge($Group,$Vanilla,[array]$ProviderRecords,[string]$Transaction,[string]$OutRoot,$ResolutionRows=$null) {
  $currentProviders = @($ProviderRecords | Where-Object { Test-PMMCurrentLayoutProvider $Vanilla $_.Export })
  $staleProviders = @($ProviderRecords | Where-Object { -not (Test-PMMCurrentLayoutProvider $Vanilla $_.Export) })
  $currentNames = (@($currentProviders | ForEach-Object { $_.Mod.Name }) -join ', ')
  $staleNames = (@($staleProviders | ForEach-Object { $_.Mod.Name }) -join ', ')
  Write-PMMLog ("StaticItem providers: current=[{0}] stale=[{1}]" -f $currentNames,$staleNames)
  if ($staleProviders.Count -lt 2) {
    return [pscustomobject]@{Success=$false;SafeUnsupported=$true;Reason='StaticItemDataAsset has stale-layout providers but fewer than two same-baseline providers; intent cannot be separated safely from game-version drift.';ReportPath='';Report=$null;CurrentProviders=$currentProviders;StaleProviders=$staleProviders}
  }

  $baselineGroups = @($staleProviders | Group-Object { Get-Sha256 (Get-PMMFamilyPartPath $_.Export '.uasset') })
  if ($baselineGroups.Count -ne 1 -or @($baselineGroups[0].Group).Count -ne $staleProviders.Count) {
    return [pscustomobject]@{Success=$false;SafeUnsupported=$true;Reason='StaticItemDataAsset contains more than one stale cooked baseline. PMM will not combine unrelated stale layouts automatically without a baseline adapter.';ReportPath='';Report=$null;CurrentProviders=$currentProviders;StaleProviders=$staleProviders}
  }

  $assetId = Get-PMMStableTextId ([string]$Group.Key)
  $baseRoot = Join-Path $Transaction ('StaticBase\' + $assetId)
  New-Item -ItemType Directory -Force -Path $baseRoot | Out-Null

  if($currentProviders.Count -gt 0){
    $binaryPlan=Invoke-PMMBinaryPlan ([string]$Group.Asset) $Vanilla $currentProviders $Transaction
    if($binaryPlan.Run.ExitCode -eq 5){
      return [pscustomobject]@{Success=$false;SafeUnsupported=$true;Reason='Current-layout providers contain true overlapping byte conflicts inside StaticItemDataAsset. Compound static-item conflict resolution is not yet implemented; PMM did not discard either provider.';ReportPath=[string]$binaryPlan.ReportPath;Report=$binaryPlan.Report;CurrentProviders=$currentProviders;StaleProviders=$staleProviders}
    }
    if($binaryPlan.Run.ExitCode -ne 0){
      throw "Binary planner infrastructure failure while preparing StaticItemDataAsset (exit $($binaryPlan.Run.ExitCode))."
    }
  }

  $binary = Invoke-PMMBinaryMerge ([string]$Group.Asset) $Vanilla $currentProviders $baseRoot
  if ($binary.ExitCode -ne 0) {
    throw "Binary base construction failed unexpectedly while preparing StaticItemDataAsset (exit $($binary.ExitCode))."
  }

  $currentJson = Get-PMMSemanticJsonCached ([string]$Vanilla.HeaderPath)
  $staleJson = New-Object System.Collections.Generic.List[object]
  foreach ($provider in $staleProviders) {
    $staleJson.Add([pscustomobject]@{Name=[string]$provider.Mod.Name;Json=(Get-PMMSemanticJsonCached ([string]$provider.Export.HeaderPath))})
  }

  $stem = Get-PakLogicalStem ([string]$Group.Asset)
  $currentUasset = Get-PMMFamilyPartPath $Vanilla '.uasset'
  $currentUexp = Get-PMMFamilyPartPath $Vanilla '.uexp'
  $baseUasset = Join-Path $baseRoot (($stem + '.uasset').Replace([char]47,[char]92))
  $baseUexp = Join-Path $baseRoot (($stem + '.uexp').Replace([char]47,[char]92))
  if (-not (Test-Path -LiteralPath $currentUexp -PathType Leaf) -or -not (Test-Path -LiteralPath $baseUexp -PathType Leaf)) {
    return [pscustomobject]@{Success=$false;SafeUnsupported=$true;Reason='StaticItemDataAsset adapter requires a .uexp sidecar.';ReportPath='';Report=$null;CurrentProviders=$currentProviders;StaleProviders=$staleProviders}
  }

  $outUasset = Join-Path $OutRoot (($stem + '.uasset').Replace([char]47,[char]92))
  $outUexp = Join-Path $OutRoot (($stem + '.uexp').Replace([char]47,[char]92))
  $report = Join-Path $Transaction ('StaticReports\' + $assetId + '.json')
  New-Item -ItemType Directory -Force -Path (Split-Path -Parent $report) | Out-Null

  $args = @(
    'staticitem-merge',
    '--current-json',$currentJson,
    '--current-uasset',$currentUasset,
    '--current-uexp',$currentUexp,
    '--base-uasset',$baseUasset,
    '--base-uexp',$baseUexp,
    '--behavior','auto',
    '--out-uasset',$outUasset,
    '--out-uexp',$outUexp,
    '--report',$report
  )
  foreach ($provider in $staleJson.ToArray()) {
    $args += @('--stale-provider',("{0}={1}" -f $provider.Name,$provider.Json))
  }
  if($ResolutionRows){
    $resolutionPath=Join-Path $Transaction ('StaticItemResolutions\'+$assetId+'.json')
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $resolutionPath)|Out-Null
    $resolutionObject=[ordered]@{}
    foreach($row in @($ResolutionRows)){$resolutionObject[[string]$row.Property]=(Get-PMMResolutionToken $row)}
    $resolutionObject|ConvertTo-Json -Depth 20|Set-Content -LiteralPath $resolutionPath -Encoding UTF8
    $args += @('--resolutions',$resolutionPath)
  }
  $run = Invoke-PMMCore $args ("staticitem-merge $($Group.Asset)")
  $reportObject=$null
  if(Test-Path -LiteralPath $report -PathType Leaf){$reportObject=Get-Content -LiteralPath $report -Raw | ConvertFrom-Json}
  if ($run.ExitCode -eq 5) {
    if($reportObject){
      $ambiguityCount=@($reportObject.inference.ambiguities).Count
      $shapeCount=@($reportObject.inference.shapeObservations).Count
      $unsupportedCount=@($reportObject.plan.unsupported).Count
      $planConflictCount=@($reportObject.plan.conflicts).Count
      if($ambiguityCount -gt 0 -and $shapeCount -eq 0 -and $unsupportedCount -eq 0 -and $planConflictCount -eq 0){
        return [pscustomobject]@{Success=$false;Conflict=$true;SafeUnsupported=$false;Reason=('StaticItem has '+$ambiguityCount+' true property conflict(s).');ReportPath=$report;Report=$reportObject;CurrentProviders=$currentProviders;StaleProviders=$staleProviders}
      }
    }
    $reason='StaticItem semantic transfer rejected this provider set safely.'
    if($reportObject){
      $bits=New-Object System.Collections.Generic.List[string]
      if(@($reportObject.inference.ambiguities).Count -gt 0){$bits.Add(('ambiguities='+@($reportObject.inference.ambiguities).Count))}
      if(@($reportObject.inference.shapeObservations).Count -gt 0){$bits.Add(('shape='+@($reportObject.inference.shapeObservations).Count))}
      if(@($reportObject.plan.unsupported).Count -gt 0){$bits.Add(('unsupported='+@($reportObject.plan.unsupported).Count))}
      if(@($reportObject.plan.conflicts).Count -gt 0){$bits.Add(('conflicts='+@($reportObject.plan.conflicts).Count))}
      if($bits.Count -gt 0){$reason += ' '+($bits -join ', ')+'.'}
    }
    return [pscustomobject]@{Success=$false;Conflict=$false;SafeUnsupported=$true;Reason=$reason;ReportPath=$report;Report=$reportObject;CurrentProviders=$currentProviders;StaleProviders=$staleProviders}
  }
  if ($run.ExitCode -ne 0) {
    $details = if ($reportObject) { $reportObject|ConvertTo-Json -Depth 30 -Compress } else { ($run.Output -join "`n") }
    throw "StaticItemDataAsset adapter infrastructure failure (exit $($run.ExitCode)).`n$details"
  }

  if(-not $reportObject){throw 'StaticItemDataAsset adapter returned success without a report.'}
  $patchCount=[int]$reportObject.patches
  $stalePayloadFingerprints=@($staleProviders|ForEach-Object{Get-PMMAssetFamilyCacheFingerprint ([string]$_.Export.HeaderPath)}|Sort-Object -Unique)
  if($stalePayloadFingerprints.Count -gt 1 -and $patchCount -le 0){
    throw 'StaticItemDataAsset adapter produced zero patches even though stale providers have different cooked payloads. Refusing to deploy an unchanged base that would mask the other mods.'
  }
  if($patchCount -gt 0){
    if(-not(Test-Path -LiteralPath $outUexp -PathType Leaf)){throw 'StaticItemDataAsset adapter reported patches but produced no .uexp output.'}
    if((Get-Sha256 $outUexp) -eq (Get-Sha256 $baseUexp)){
      throw 'StaticItemDataAsset adapter reported patches but output is byte-identical to the cooked base. Refusing to deploy.'
    }
  }
  $intentCount=[int]$reportObject.inference.intents
  $behaviorName=[string]$reportObject.behaviorApplied
  $outputHash=Get-Sha256 $outUexp
  Write-PMMLog ("StaticItem merged: intents={0}; patches={1}; behavior={2}; output={3}" -f $intentCount,$patchCount,$behaviorName,$outputHash)

  # Preserve optional current-layout ubulk if the binary base had one.
  $baseUbulk = Join-Path $baseRoot (($stem + '.ubulk').Replace([char]47,[char]92))
  if (Test-Path -LiteralPath $baseUbulk -PathType Leaf) {
    $outUbulk = Join-Path $OutRoot (($stem + '.ubulk').Replace([char]47,[char]92))
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $outUbulk) | Out-Null
    Copy-Item -LiteralPath $baseUbulk -Destination $outUbulk -Force
  }

  return [pscustomobject]@{Success=$true;SafeUnsupported=$false;Reason='';ReportPath=$report;Report=$reportObject;CurrentProviders=$currentProviders;StaleProviders=$staleProviders}
}

function New-PMMReviewCaseManifest($Group,$Vanilla,[array]$ProviderRecords,[string]$Mode='Review',[string]$Reason='') {
  $inputs=[System.Collections.Generic.List[object]]::new()
  if($Vanilla){
    foreach($ext in @('.uasset','.uexp','.ubulk')){
      $path=Get-PMMFamilyPartPath $Vanilla $ext
      if(Test-Path -LiteralPath $path -PathType Leaf){$inputs.Add([pscustomobject]@{Role='Vanilla';Provider='Vanilla';Part=$ext;Sha256=(Get-Sha256 $path);Size=(Get-Item -LiteralPath $path).Length})}
    }
  }
  foreach($record in @($ProviderRecords|Sort-Object {$_.Mod.Name})){
    foreach($ext in @('.uasset','.uexp','.ubulk')){
      $path=Get-PMMFamilyPartPath $record.Export $ext
      if(Test-Path -LiteralPath $path -PathType Leaf){$inputs.Add([pscustomobject]@{Role='Provider';Provider=[string]$record.Mod.Name;Part=$ext;Sha256=(Get-Sha256 $path);Size=(Get-Item -LiteralPath $path).Length})}
    }
  }
  $signature=([string]$Group.Key)+'|'+((@($inputs.ToArray())|ForEach-Object{"$($_.Role):$($_.Provider):$($_.Part):$($_.Sha256)"}) -join '|')
  $caseId=Get-PMMStableTextId $signature
  return [pscustomobject]@{
    Schema='PMM_REVIEW_CASE_V1';CaseId=$caseId;Created=(Get-Date).ToString('o');Engine=(Get-PMMEngineId);EngineProfile='UE5_1';CaseKind='CookedFamily';
    MappingsSha256=$(try{Get-Sha256 (Get-PMMMappingsPath)}catch{''});VanillaAvailable=[bool]$Vanilla;
    AssetKey=[string]$Group.Key;Asset=[string]$Group.Asset;Mode=$Mode;Reason=$Reason;
    Providers=@($ProviderRecords|ForEach-Object{[pscustomobject]@{Name=[string]$_.Mod.Name;PakSha256=[string]$_.Mod.Hash}});
    InputFiles=$inputs.ToArray();
    SolutionContract='PMM_MANUAL_SOLUTION_V1'
  }
}

function New-PMMPlainReviewCaseManifest($Group,[string]$VanillaPath,[array]$ProviderRecords,[string]$Mode='Review',[string]$Reason='') {
  $inputs=[System.Collections.Generic.List[object]]::new()
  $part=[IO.Path]::GetExtension([string]$Group.Asset).ToLowerInvariant()
  if(-not[string]::IsNullOrWhiteSpace($VanillaPath) -and (Test-Path -LiteralPath $VanillaPath -PathType Leaf)){
    $inputs.Add([pscustomobject]@{Role='Vanilla';Provider='Vanilla';Part=$part;Sha256=(Get-Sha256 $VanillaPath);Size=(Get-Item -LiteralPath $VanillaPath).Length})
  }
  foreach($record in @($ProviderRecords|Sort-Object {$_.Mod.Name})){
    if(-not(Test-Path -LiteralPath ([string]$record.Path) -PathType Leaf)){throw ('Plain review provider input is missing: '+[string]$record.Mod.Name+' / '+[string]$Group.Asset)}
    $inputs.Add([pscustomobject]@{Role='Provider';Provider=[string]$record.Mod.Name;Part=$part;Sha256=(Get-Sha256 ([string]$record.Path));Size=(Get-Item -LiteralPath ([string]$record.Path)).Length})
  }
  $signature=([string]$Group.Key)+'|'+((@($inputs.ToArray())|ForEach-Object{"$($_.Role):$($_.Provider):$($_.Part):$($_.Sha256)"}) -join '|')
  $caseId=Get-PMMStableTextId $signature
  return [pscustomobject]@{
    Schema='PMM_REVIEW_CASE_V1';CaseId=$caseId;Created=(Get-Date).ToString('o');Engine=(Get-PMMEngineId);EngineProfile='UE5_1';CaseKind='PlainFile';
    MappingsSha256=$(try{Get-Sha256 (Get-PMMMappingsPath)}catch{''});VanillaAvailable=(-not[string]::IsNullOrWhiteSpace($VanillaPath) -and (Test-Path -LiteralPath $VanillaPath -PathType Leaf));
    AssetKey=[string]$Group.Key;Asset=[string]$Group.Asset;Mode=$Mode;Reason=$Reason;
    Providers=@($ProviderRecords|ForEach-Object{[pscustomobject]@{Name=[string]$_.Mod.Name;PakSha256=[string]$_.Mod.Hash}});
    InputFiles=$inputs.ToArray();
    SolutionContract='REVIEW_ONLY_PLAIN_FILE'
  }
}

function Publish-PMMPlainReviewFolder($Group,[string]$VanillaPath,[array]$ProviderRecords,[string]$Mode,[string]$Reason) {
  $id=Get-PMMStableTextId ([string]$Group.Key)
  $root=Join-Path (Get-PMMPath 'Review') $id
  $savedContextNotes=$null
  $oldContext=Join-Path $root 'CONTEXT_NOTES.md'
  if(Test-Path -LiteralPath $oldContext -PathType Leaf){try{$savedContextNotes=Get-Content -LiteralPath $oldContext -Raw}catch{}}
  Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
  New-Item -ItemType Directory -Force -Path $root|Out-Null
  if($null -ne $savedContextNotes){Set-Content -LiteralPath (Join-Path $root 'CONTEXT_NOTES.md') -Value $savedContextNotes -Encoding UTF8}
  $case=New-PMMPlainReviewCaseManifest $Group $VanillaPath $ProviderRecords $Mode $Reason
  $case|ConvertTo-Json -Depth 30|Set-Content -LiteralPath (Join-Path $root 'case.json') -Encoding UTF8
  @"
# Palworld Manager Merger review case

Case ID: $($case.CaseId)
Asset: $($case.Asset)
PMM status: $Mode
Case kind: shared plain/non-Unreal file

Why this case exists
--------------------
$Reason

Analyze stores metadata only. When the user explicitly creates an AI handoff,
AIIO re-extracts this exact file from Vanilla (when present) and every provider,
checks each pinned size/SHA-256, and includes it in the single current bundle.
Whole PAK files are never copied.

PMM does not currently have a format-aware automatic import/build contract for
this plain-file type. A receiving AI/modder may still inspect it and explain a
safe resolution, but must not return a PMM_MANUAL_SOLUTION_V1 cooked-family ZIP
for this case unless PMM later gains a validator for that format.
"@|Set-Content -LiteralPath (Join-Path $root 'README_FOR_HUMAN_OR_AI.md') -Encoding UTF8
  $notesPath=Join-Path $root 'CONTEXT_NOTES.md'
  if(-not(Test-Path -LiteralPath $notesPath -PathType Leaf)){
    @"
# Optional human context for this review case

Asset: $($case.Asset)
Providers: $((@($case.Providers|ForEach-Object{[string]$_.Name})) -join ', ')

Observed behavior / creator notes:
-
"@|Set-Content -LiteralPath $notesPath -Encoding UTF8
  }
  return [pscustomobject]@{Root=$root;Case=$case}
}

function Write-PMMReviewCaseMetadata([string]$ReviewFolder,$Group,$Vanilla,[array]$ProviderRecords,[string]$Mode,[string]$Reason) {
  if(-not$ReviewFolder -or -not(Test-Path -LiteralPath $ReviewFolder -PathType Container)){return $null}
  $case=New-PMMReviewCaseManifest $Group $Vanilla $ProviderRecords $Mode $Reason
  $casePath=Join-Path $ReviewFolder 'case.json'
  $case|ConvertTo-Json -Depth 30|Set-Content -LiteralPath $casePath -Encoding UTF8

  $readme=@"
# Palworld Manager Merger review case

Case ID: $($case.CaseId)
Asset: $($case.Asset)
PMM status: $Mode

Why this case exists
--------------------
$Reason

This folder is Analyze evidence, not an AI handoff archive. Analyze never copies
whole source PAKs and never creates AI_HANDOFF ZIPs. When the user explicitly
chooses CREATE AI HANDOFF, Modules/AIIO/AIIO.ps1 builds ONE bundle for every current
Unsupported case and extracts only the exact conflicting files/families from
Vanilla and each involved source mod.

Return contract: PMM_MANUAL_SOLUTION_V1
---------------------------------------
For this Unreal cooked-family case, a returned solution ZIP contains:
  solution.json
  cooked/<asset-leaf>.uasset
  cooked/<asset-leaf>.uexp
  cooked/<asset-leaf>.ubulk     (only when required)

solution.json must contain:
{
  "schema": "PMM_MANUAL_SOLUTION_V1",
  "caseId": "$($case.CaseId)",
  "asset": "$($case.Asset)",
  "mode": "replacement-cooked-family",
  "notes": "short explanation of what was combined"
}

PMM pins every Vanilla/provider input hash in case.json and revalidates the exact
active source set before accepting an experimental returned solution.
"@
  Set-Content -LiteralPath (Join-Path $ReviewFolder 'README_FOR_HUMAN_OR_AI.md') -Value $readme -Encoding UTF8
  $template=[ordered]@{schema='PMM_MANUAL_SOLUTION_V1';caseId=[string]$case.CaseId;asset=[string]$case.Asset;mode='replacement-cooked-family';notes='Describe the intended composition here.'}
  $template|ConvertTo-Json -Depth 10|Set-Content -LiteralPath (Join-Path $ReviewFolder 'solution-template.json') -Encoding UTF8
  $notesPath=Join-Path $ReviewFolder 'CONTEXT_NOTES.md'
  if(-not(Test-Path -LiteralPath $notesPath -PathType Leaf)){
    @"
# Optional human context for this review case

Asset: $($case.Asset)
Providers: $((@($case.Providers|ForEach-Object{[string]$_.Name})) -join ', ')

Use this file for creator descriptions, links, observed in-game behavior, or reproduction
notes that may help a human/AI understand intent. These notes are evidence only: PMM never
treats them as structural permission to merge.

Observed behavior / creator notes:
-
"@ | Set-Content -LiteralPath $notesPath -Encoding UTF8
  }
  return $case
}

# Compatibility shim for old callers/scripts. Since v1.2 AIIO separation this
# function MUST NOT create a ZIP or copy source PAKs. It only refreshes the case
# metadata and returns an empty path. New handoffs are created explicitly by
# New-PMMAIHandoffBundle in Modules/AIIO/AIIO.ps1.
function Write-PMMAIHandoff([string]$ReviewFolder,$Group,$Vanilla,[array]$ProviderRecords,[string]$Mode,[string]$Reason) {
  [void](Write-PMMReviewCaseMetadata $ReviewFolder $Group $Vanilla $ProviderRecords $Mode $Reason)
  Write-PMMLog ('Legacy Write-PMMAIHandoff request redirected to review metadata only for '+[string]$Group.Asset+'. AIIO packaging is explicit/user-triggered.')
  return ''
}

function Get-PMMManualSolutionsRoot {
  $root=Get-PMMPath 'ManualSolutions'
  if(-not(Test-Path -LiteralPath $root -PathType Container)){New-Item -ItemType Directory -Force -Path $root|Out-Null}
  return $root
}

function Read-PMMReviewCase([string]$ReviewFolder) {
  if(-not$ReviewFolder){return $null}
  $path=Join-Path $ReviewFolder 'case.json'
  if(-not(Test-Path -LiteralPath $path -PathType Leaf)){return $null}
  try{return Get-Content -LiteralPath $path -Raw|ConvertFrom-Json}catch{return $null}
}

function Test-PMMReviewCaseIntegrity([string]$ReviewFolder,$Case) {
  if(-not$Case){throw 'Review case metadata is missing.'}
  if([string]$Case.Schema -ne 'PMM_REVIEW_CASE_V1'){throw 'Review case schema is not PMM_REVIEW_CASE_V1.'}
  if([string]::IsNullOrWhiteSpace([string]$Case.CaseId) -or [string]::IsNullOrWhiteSpace([string]$Case.Asset)){
    throw 'Review case is missing its caseId or asset identity.'
  }

  $inputList=@($Case.InputFiles)
  $signature=([string]$Case.AssetKey)+'|'+(($inputList|ForEach-Object{"$($_.Role):$($_.Provider):$($_.Part):$($_.Sha256)"}) -join '|')
  $calculated=Get-PMMStableTextId $signature
  if($calculated -ne [string]$Case.CaseId){
    throw 'Review caseId no longer matches its pinned input manifest. Run Analyze again.'
  }

  if($Case.PSObject.Properties.Name -contains 'MappingsSha256' -and -not[string]::IsNullOrWhiteSpace([string]$Case.MappingsSha256)){
    $mappings=Get-PMMMappingsPath
    if(-not(Test-Path -LiteralPath $mappings -PathType Leaf) -or (Get-Sha256 $mappings) -ne ([string]$Case.MappingsSha256).ToLowerInvariant()){
      throw 'Mappings changed after this review case was analyzed. Run Analyze again.'
    }
  }

  # A case stores hashes/sizes, not duplicated cooked payload. Revalidate those
  # exact bytes against the CURRENT Vanilla installation and active source PAKs
  # whenever a returned solution is imported/used. This keeps Analyze metadata-
  # only while preserving the old exact-input safety guarantee.
  $active=@(Get-LibraryMods)
  $activeByName=@{}
  foreach($mod in $active){$activeByName[[string]$mod.Name]=$mod}
  foreach($provider in @($Case.Providers)){
    $name=[string]$provider.Name
    if(-not$activeByName.ContainsKey($name)){throw ('The active source set no longer contains provider '+$name+' pinned by this review case. Run Analyze again.')}
    $mod=$activeByName[$name]
    if([string]$mod.Hash -ne ([string]$provider.PakSha256).ToLowerInvariant()){
      throw ('The active source PAK changed after Analyze: '+$name+'. Run Analyze again.')
    }
  }

  $asset=[string]$Case.Asset
  if([IO.Path]::GetExtension($asset) -ine '.uasset'){
    throw 'PMM_REVIEW_CASE_V1 currently validates Unreal cooked-family cases only.'
  }
  $stage=Join-Path (Get-PMMPath 'Cache') ('ReviewIntegrity_'+[guid]::NewGuid().ToString('N'))
  try{
    New-Item -ItemType Directory -Force -Path $stage|Out-Null
    Set-PMMTransientStageOwner $stage 'ReviewIntegrity'

    $verifyFamily={
      param($Export,[array]$Expected,[string]$Label)
      if(-not$Export){throw ($Label+' is no longer available. Run Analyze again.')}
      foreach($ext in @('.uasset','.uexp','.ubulk')){
        $matches=@($Expected|Where-Object{[string]$_.Part -eq $ext})
        $path=Get-PMMFamilyPartPath $Export $ext
        $exists=Test-Path -LiteralPath $path -PathType Leaf
        if($matches.Count -eq 0){
          if($exists){throw ($Label+' cooked-family topology changed after Analyze ('+$ext+' appeared). Run Analyze again.')}
          continue
        }
        if($matches.Count -ne 1 -or -not$exists){throw ($Label+' cooked-family topology changed after Analyze ('+$ext+'). Run Analyze again.')}
        $expected=$matches[0]
        $item=Get-Item -LiteralPath $path
        if([long]$item.Length -ne [long]$expected.Size){throw ($Label+' size changed after Analyze ('+$ext+'). Run Analyze again.')}
        if((Get-Sha256 $path) -ne ([string]$expected.Sha256).ToLowerInvariant()){throw ($Label+' SHA-256 changed after Analyze ('+$ext+'). Run Analyze again.')}
      }
    }

    $expectedVanilla=@($inputList|Where-Object{[string]$_.Role -eq 'Vanilla'})
    if([bool]$Case.VanillaAvailable){
      $vanilla=Export-VanillaAssetFamilyExact $asset (Join-Path $stage 'Vanilla')
      & $verifyFamily $vanilla $expectedVanilla 'Vanilla input'
    }elseif($expectedVanilla.Count -gt 0){
      throw 'Review case says Vanilla is unavailable but contains Vanilla input hashes. Run Analyze again.'
    }else{
      $nowVanilla=Export-VanillaAssetFamilyExact $asset (Join-Path $stage 'VanillaProbe')
      if($nowVanilla){throw 'Vanilla availability changed after Analyze. Run Analyze again.'}
    }

    foreach($provider in @($Case.Providers)){
      $name=[string]$provider.Name
      $mod=$activeByName[$name]
      $expected=@($inputList|Where-Object{[string]$_.Role -eq 'Provider' -and [string]$_.Provider -eq $name})
      $root=Join-Path $stage ('Provider_'+(Get-PMMStableTextId $name))
      $export=Export-PakAssetFamilyExact ([string]$mod.Path) $asset $root
      & $verifyFamily $export $expected ('Provider '+$name)
    }
  }finally{
    Remove-Item -LiteralPath $stage -Recurse -Force -ErrorAction SilentlyContinue
    Remove-PMMTransientStageOwner $stage
  }
  return $true
}

function Invoke-PMMManualSolutionProbe([string]$UassetPath) {
  $dotnet=Get-PMMDotnetHostPath
  $reader=Get-PMMAssetReaderPath
  $mappings=Get-PMMMappingsPath
  if(-not$dotnet -or -not(Test-Path -LiteralPath $reader -PathType Leaf) -or -not(Test-Path -LiteralPath $mappings -PathType Leaf)){
    return [pscustomobject]@{Ok=$false;Reason='AssetReader/.NET/mappings dependency is unavailable.';Output=''}
  }
  try{
    $lines=@(& $dotnet $reader 'probe' '--asset' $UassetPath '--mappings' $mappings '--engine' 'UE5_1' 2>&1)
    $exit=$LASTEXITCODE;$text=(@($lines|ForEach-Object{[string]$_}) -join [Environment]::NewLine)
    return [pscustomobject]@{Ok=($exit -eq 0);Reason=$(if($exit -eq 0){''}else{"AssetReader probe failed with exit $exit."});Output=$text}
  }catch{return [pscustomobject]@{Ok=$false;Reason=$_.Exception.Message;Output=''}}
}

function Get-PMMManualSolutionForReview([string]$ReviewFolder) {
  $case=Read-PMMReviewCase $ReviewFolder
  if(-not$case -or [string]::IsNullOrWhiteSpace([string]$case.CaseId)){return $null}
  $root=Join-Path (Get-PMMManualSolutionsRoot) ([string]$case.CaseId)
  $metaPath=Join-Path $root 'validation.json'
  $cooked=Join-Path $root 'cooked'
  if(-not(Test-Path -LiteralPath $metaPath -PathType Leaf) -or -not(Test-Path -LiteralPath $cooked -PathType Container)){return $null}
  try{$meta=Get-Content -LiteralPath $metaPath -Raw|ConvertFrom-Json}catch{return $null}
  try{[void](Test-PMMReviewCaseIntegrity $ReviewFolder $case)}catch{Write-PMMLog ('Stored manual solution ignored because its review case is stale: '+$_.Exception.Message);return $null}
  if([string]$meta.Schema -ne 'PMM_VALIDATED_MANUAL_SOLUTION_V1' -or -not [bool]$meta.AcceptedExperimental){return $null}
  if([string]$meta.CaseId -ne [string]$case.CaseId -or [string]$meta.Asset -ne [string]$case.Asset){return $null}
  foreach($part in @($meta.OutputFiles)){
    $path=Join-Path $cooked ([string]$part.Name)
    if(-not(Test-Path -LiteralPath $path -PathType Leaf)){return $null}
    if((Get-Sha256 $path) -ne ([string]$part.Sha256).ToLowerInvariant()){return $null}
  }
  return [pscustomobject]@{Case=$case;Metadata=$meta;Root=$root;Cooked=$cooked}
}

function Expand-PMMSafeSolutionZip([string]$ZipPath,[string]$Destination) {
  Add-Type -AssemblyName System.IO.Compression.FileSystem
  $archive=[IO.Compression.ZipFile]::OpenRead($ZipPath)
  [int64]$expandedBytes=0
  $entryNames=@{}
  try{
    foreach($entry in $archive.Entries){
      $name=([string]$entry.FullName).Replace([char]92,[char]47)
      if([string]::IsNullOrWhiteSpace($name)){continue}
      # Colons are forbidden anywhere because PMM targets Windows and an embedded
      # colon can address an NTFS alternate data stream even when it is not a drive.
      if($name.StartsWith('/') -or $name.Contains(':') -or $name -match '(^|/)\.\.(/|$)'){
        throw "Unsafe path in solution ZIP: $name"
      }
      if(-not$name.EndsWith('/')){
        $key=$name.ToLowerInvariant()
        if($entryNames.ContainsKey($key)){throw "Duplicate/case-colliding path in solution ZIP: $name"}
        $entryNames[$key]=$true
        if([int64]$entry.Length -lt 0 -or $expandedBytes -gt ([int64]::MaxValue-[int64]$entry.Length)){throw 'Solution ZIP size metadata is invalid.'}
        $expandedBytes+=[int64]$entry.Length
        if($expandedBytes -gt [int64](5GB)){throw 'Returned solution ZIP expands beyond the 5 GiB safety limit.'}
      }
    }
  }finally{$archive.Dispose()}

  [int64]$free=-1
  try{
    $root=[IO.Path]::GetPathRoot([IO.Path]::GetFullPath($Destination))
    if($root){$free=[int64]([IO.DriveInfo]::new($root).AvailableFreeSpace)}
  }catch{Write-PMMLog ('Solution ZIP free-space preflight unavailable: '+$_.Exception.Message)}
  [int64]$required=[int64]($expandedBytes+512MB)
  if($free -ge 0 -and $free -lt $required){
    throw ('Returned solution needs about '+$required+' bytes of safe working space but only '+$free+' bytes are free.')
  }

  Remove-Item -LiteralPath $Destination -Recurse -Force -ErrorAction SilentlyContinue
  New-Item -ItemType Directory -Force -Path $Destination|Out-Null
  Set-PMMTransientStageOwner $Destination 'ManualSolutionImport'
  $runtime=Get-PMMRuntimePath
  if(-not(Test-Path -LiteralPath $runtime -PathType Leaf)){throw 'PMMRuntime.exe is required to extract returned solution ZIPs.'}
  $output=@(& $runtime archive extract $ZipPath $Destination 2>&1|ForEach-Object{[string]$_})
  $exit=$LASTEXITCODE
  if($exit -ne 0){throw ('PMMRuntime archive extract failed with exit '+$exit+'. '+($output -join ' '))}
}

function Import-PMMManualSolutionZip([string]$ZipPath,[string]$ReviewFolder,[bool]$AcceptExperimental) {
  if(-not$AcceptExperimental){throw 'Manual/AI cooked solutions are experimental and require explicit user acceptance before they can enter a merge plan.'}
  if(-not(Test-Path -LiteralPath $ZipPath -PathType Leaf)){throw "Solution ZIP not found: $ZipPath"}
  $case=Read-PMMReviewCase $ReviewFolder
  if(-not$case){throw 'The selected review folder has no current case.json. Run Analyze again.'}
  [void](Test-PMMReviewCaseIntegrity $ReviewFolder $case)
  $stage=Join-Path (Get-PMMPath 'Cache') ('ManualSolutionImport_'+[guid]::NewGuid().ToString('N'))
  try{
    Expand-PMMSafeSolutionZip $ZipPath $stage
    $solutionPath=Join-Path $stage 'solution.json'
    $cooked=Join-Path $stage 'cooked'
    if(-not(Test-Path -LiteralPath $solutionPath -PathType Leaf)){throw 'The returned ZIP must contain solution.json at its root.'}
    if(-not(Test-Path -LiteralPath $cooked -PathType Container)){throw 'The returned ZIP must contain a cooked/ folder.'}
    $solution=Get-Content -LiteralPath $solutionPath -Raw|ConvertFrom-Json
    if([string]$solution.schema -ne 'PMM_MANUAL_SOLUTION_V1'){throw 'solution.json schema must be PMM_MANUAL_SOLUTION_V1.'}
    if([string]$solution.mode -ne 'replacement-cooked-family'){throw 'PMM accepts only mode=replacement-cooked-family for cooked-family manual solutions.'}
    if([string]$solution.caseId -ne [string]$case.CaseId){throw 'The solution caseId does not match the current exact Vanilla/provider hashes. The solution is stale or belongs to another case.'}
    if([string]$solution.asset -ne [string]$case.Asset){throw 'The solution asset does not match this review case.'}

    $assetLeaf=[IO.Path]::GetFileNameWithoutExtension([string]$case.Asset)
    $expectedParts=@($case.InputFiles|ForEach-Object{[string]$_.Part}|Where-Object{$_ -in @('.uasset','.uexp','.ubulk')}|Sort-Object -Unique)
    if('.uasset' -notin $expectedParts){$expectedParts=@('.uasset')+$expectedParts}
    $actualFiles=@(Get-ChildItem -LiteralPath $cooked -File -ErrorAction Stop)
    foreach($file in $actualFiles){
      $ext=[IO.Path]::GetExtension($file.Name).ToLowerInvariant()
      if($file.BaseName -ne $assetLeaf -or $ext -notin @('.uasset','.uexp','.ubulk')){throw "Unexpected cooked solution file: $($file.Name). Only the selected asset family is allowed."}
    }
    foreach($ext in $expectedParts){
      $required=Join-Path $cooked ($assetLeaf+$ext)
      if(-not(Test-Path -LiteralPath $required -PathType Leaf)){throw "Cooked solution is missing required family part: $assetLeaf$ext"}
    }
    if($actualFiles.Count -ne $expectedParts.Count){throw 'Cooked solution topology differs from the analyzed asset-family topology.'}

    $probe=Invoke-PMMManualSolutionProbe (Join-Path $cooked ($assetLeaf+'.uasset'))
    if(-not$probe.Ok){throw ('The returned cooked asset does not pass the read-only AssetReader probe. '+$probe.Reason+' '+$probe.Output)}

    $outFiles=[System.Collections.Generic.List[object]]::new()
    foreach($ext in $expectedParts){
      $file=Join-Path $cooked ($assetLeaf+$ext)
      $outFiles.Add([pscustomobject]@{Name=($assetLeaf+$ext);Part=$ext;Size=(Get-Item -LiteralPath $file).Length;Sha256=(Get-Sha256 $file)})
    }
    $dest=Join-Path (Get-PMMManualSolutionsRoot) ([string]$case.CaseId)
    $tempDest=$dest+'.incoming'
    Remove-Item -LiteralPath $tempDest -Recurse -Force -ErrorAction SilentlyContinue
    New-Item -ItemType Directory -Force -Path (Join-Path $tempDest 'cooked')|Out-Null
    foreach($file in $actualFiles){Copy-Item -LiteralPath $file.FullName -Destination (Join-Path $tempDest 'cooked') -Force}
    Copy-Item -LiteralPath $solutionPath -Destination (Join-Path $tempDest 'solution.json') -Force
    # Preserve the exact returned archive so a later runtime PASS can be exported
    # as a self-contained PMM_KNOWLEDGE_CONTRIBUTION_V1 without asking the user
    # to find the original AI response again.
    Copy-Item -LiteralPath $ZipPath -Destination (Join-Path $tempDest 'source-solution.zip') -Force
    $validation=[ordered]@{
      Schema='PMM_VALIDATED_MANUAL_SOLUTION_V1';CaseId=[string]$case.CaseId;Asset=[string]$case.Asset;
      Imported=(Get-Date).ToString('o');AcceptedExperimental=$true;RuntimeStatus='UNPROVEN';
      Notes=[string]$solution.notes;SourceZipSha256=(Get-Sha256 $ZipPath);OutputFiles=$outFiles.ToArray();
      Validation='Exact caseId/asset, safe ZIP paths, exact cooked-family topology, SHA-256 pinning and read-only AssetReader probe passed. Gameplay semantics are not proven by this validation.'
    }
    $validation|ConvertTo-Json -Depth 30|Set-Content -LiteralPath (Join-Path $tempDest 'validation.json') -Encoding UTF8
    Remove-Item -LiteralPath $dest -Recurse -Force -ErrorAction SilentlyContinue
    Move-Item -LiteralPath $tempDest -Destination $dest
    Write-PMMLog ('Validated experimental manual solution imported for case '+[string]$case.CaseId+': '+$ZipPath)
    return [pscustomobject]@{CaseId=[string]$case.CaseId;Asset=[string]$case.Asset;Root=$dest;RuntimeStatus='UNPROVEN'}
  }finally{
    Remove-Item -LiteralPath $stage -Recurse -Force -ErrorAction SilentlyContinue
    Remove-PMMTransientStageOwner $stage
  }
}

function Copy-PMMManualSolutionToBuild($AssetPlan,[string]$OutDir) {
  if([string]::IsNullOrWhiteSpace([string]$AssetPlan.ManualCaseId)){throw "Manual solution case ID is missing for $($AssetPlan.Asset)."}
  $root=Join-Path (Get-PMMManualSolutionsRoot) ([string]$AssetPlan.ManualCaseId)
  $metaPath=Join-Path $root 'validation.json';$cooked=Join-Path $root 'cooked'
  if(-not(Test-Path -LiteralPath $metaPath -PathType Leaf)){throw 'The validated manual solution disappeared. Run Analyze again.'}
  $meta=Get-Content -LiteralPath $metaPath -Raw|ConvertFrom-Json
  if(-not [bool]$meta.AcceptedExperimental -or [string]$meta.Asset -ne [string]$AssetPlan.Asset){throw 'The manual solution is not approved for this exact asset/case.'}
  $leaf=[IO.Path]::GetFileNameWithoutExtension([string]$AssetPlan.Asset)
  foreach($part in @($meta.OutputFiles)){
    $src=Join-Path $cooked ([string]$part.Name)
    if(-not(Test-Path -LiteralPath $src -PathType Leaf) -or (Get-Sha256 $src) -ne ([string]$part.Sha256).ToLowerInvariant()){throw 'The stored manual solution changed after validation. Re-import it.'}
  }
  $probe=Invoke-PMMManualSolutionProbe (Join-Path $cooked ($leaf+'.uasset'))
  if(-not$probe.Ok){throw ('Stored manual solution no longer passes AssetReader probe: '+$probe.Reason)}
  $stem=Get-PakLogicalStem ([string]$AssetPlan.Asset)
  foreach($part in @($meta.OutputFiles)){
    $ext=[string]$part.Part;$src=Join-Path $cooked ([string]$part.Name)
    $dst=Join-Path $OutDir (($stem+$ext).Replace([char]47,[char]92))
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $dst)|Out-Null
    Copy-Item -LiteralPath $src -Destination $dst -Force
  }
}

function Resolve-PMMUnsupportedOrManual($Group,$Vanilla,[array]$ProviderRecords,[string]$Reason,[string]$ReviewFolder) {
  # Analyze records the exact case only. AIIO packaging is deliberately deferred
  # until the user explicitly requests one bundle for the complete Unsupported set.
  $case=Write-PMMReviewCaseMetadata $ReviewFolder $Group $Vanilla $ProviderRecords 'Unsupported' $Reason
  $manual=Get-PMMManualSolutionForReview $ReviewFolder
  if($manual){
    $asset=[pscustomobject]@{
      AssetKey=[string]$Group.Key;Asset=[string]$Group.Asset;Providers=@($ProviderRecords|ForEach-Object{$_.Mod.Name});
      Mode='ManualSolutionExperimental';ConflictCount=0;ChangedPathCount=@($manual.Metadata.OutputFiles).Count;
      Reason=('EXPERIMENTAL manual/AI cooked solution accepted for exact case '+[string]$manual.Case.CaseId+'. Structural/provenance checks passed, but gameplay behavior is runtime-unproven. Original unsupported reason: '+$Reason);
      ReviewFolder=$ReviewFolder;AIHandoff='';ManualCaseId=[string]$manual.Case.CaseId;RuntimeStatus='UNPROVEN'
    }
    return [pscustomobject]@{Asset=$asset;Rows=@()}
  }
  $caseId=if($case){[string]$case.CaseId}else{''}
  $unsupported=New-PMMUnsupportedAnalysis $Group $ProviderRecords $Reason $ReviewFolder '' $caseId
  if($unsupported -and $unsupported.Asset -and (Get-Command Get-PMMCKLContextForPlanItem -ErrorAction SilentlyContinue)){
    $probe=[pscustomobject]@{Asset=[string]$Group.Asset;Providers=@($ProviderRecords|ForEach-Object{[string]$_.Mod.Name});Case=$case}
    $matches=@(Get-PMMCKLContextForPlanItem $probe)
    $unsupported.Asset|Add-Member -NotePropertyName CKLMatches -NotePropertyValue @($matches|ForEach-Object{[pscustomobject]@{KnowledgeId=[string]$_.knowledgeId;Kind=[string]$_.kind;Channel=[string]$_.channel;MatchType=[string]$_.matchType}}) -Force
  }
  return $unsupported
}

function Publish-PMMReviewFolder($Group,$Vanilla,[array]$ProviderRecords,[string]$ReportPath='') {
  # Review is persistent ANALYSIS EVIDENCE only. Source cooked payload remains in
  # the short-lived Analyze transaction and is deleted when Analyze completes.
  # AIIO re-extracts exact files from Vanilla/provider PAKs only on explicit user
  # request, preventing Workspace\Review from becoming a second asset cache.
  $id = Get-PMMStableTextId ([string]$Group.Key)
  $root = Join-Path (Get-PMMPath 'Review') $id
  # Preserve the supported human-note surface across re-analysis. Cooked payload
  # and generated reports are rebuilt, but a user's CONTEXT_NOTES.md is evidence
  # they explicitly added and must not disappear just because Analyze ran again.
  $savedContextNotes=$null
  $oldContext=Join-Path $root 'CONTEXT_NOTES.md'
  if(Test-Path -LiteralPath $oldContext -PathType Leaf){try{$savedContextNotes=Get-Content -LiteralPath $oldContext -Raw}catch{}}
  Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
  New-Item -ItemType Directory -Force -Path $root | Out-Null
  if($null -ne $savedContextNotes){Set-Content -LiteralPath (Join-Path $root 'CONTEXT_NOTES.md') -Value $savedContextNotes -Encoding UTF8}
  if ($ReportPath -and (Test-Path -LiteralPath $ReportPath -PathType Leaf)) {
    Copy-Item -LiteralPath $ReportPath -Destination (Join-Path $root 'pmmcore-report.json') -Force
  }
  if(Get-Command Write-PMMSemanticEvidence -ErrorAction SilentlyContinue){
    [void](Write-PMMSemanticEvidence $Group $Vanilla $ProviderRecords $root)
  }
  return $root
}

function Invoke-PMMSharedAssetAnalysis($Group,[array]$ProviderMods,[string]$Transaction,$PreviousMap) {
  $records = New-Object System.Collections.Generic.List[object]
  foreach ($mod in $ProviderMods) {
    $root = Join-Path $Transaction ('Providers\' + (Get-PMMStableTextId ([string]$mod.Name + '|' + [string]$Group.Key)))
    $export = Export-PakAssetFamilyExact ([string]$mod.Path) ([string]$Group.Asset) $root
    $records.Add([pscustomobject]@{Mod=$mod;Export=$export})
  }
  $providerRecords = $records.ToArray()

  $first = $providerRecords[0].Export
  $allIdentical = $true
  foreach ($record in $providerRecords | Select-Object -Skip 1) {
    if (-not (Test-PMMFamiliesIdentical $first $record.Export)) { $allIdentical = $false; break }
  }
  if ($allIdentical) {
    $review = Publish-PMMReviewFolder $Group $null $providerRecords
    return [pscustomobject]@{Asset=[pscustomobject]@{AssetKey=$Group.Key;Asset=$Group.Asset;Providers=@($ProviderMods.Name);Mode='Identical';ConflictCount=0;ChangedPathCount=0;Reason='All providers contain the same cooked asset family.';ReviewFolder=$review};Rows=@()}
  }

  $vanillaRoot = Join-Path $Transaction ('Vanilla\' + (Get-PMMStableTextId ([string]$Group.Key)))
  $vanilla = Export-VanillaAssetFamilyExact ([string]$Group.Asset) $vanillaRoot
  if (-not $vanilla) {
    $review = Publish-PMMReviewFolder $Group $null $providerRecords
    return (Resolve-PMMUnsupportedOrManual $Group $null $providerRecords 'No matching Vanilla asset exists; PMM cannot prove a common baseline for a true merge.' $review)
  }

  $safe = @($providerRecords | Where-Object { Test-PMMCurrentLayoutProvider $vanilla $_.Export })
  if ($safe.Count -eq $providerRecords.Count) {
    $binaryPlan=Invoke-PMMBinaryPlan ([string]$Group.Asset) $vanilla $safe $Transaction
    $review = Publish-PMMReviewFolder $Group $vanilla $providerRecords ([string]$binaryPlan.ReportPath)
    if ($binaryPlan.Run.ExitCode -eq 0) {
      return [pscustomobject]@{Asset=[pscustomobject]@{AssetKey=$Group.Key;Asset=$Group.Asset;Providers=@($ProviderMods.Name);Mode='BinaryAuto';ConflictCount=0;ChangedPathCount=[int]$binaryPlan.Report.patchedBytes;Reason='All providers use the current Vanilla layout; every non-overlapping byte delta was merged.';ReviewFolder=$review};Rows=@()}
    }
    if($binaryPlan.Run.ExitCode -eq 5 -and $binaryPlan.Report -and @($binaryPlan.Report.conflicts).Count -gt 0){
      return (New-PMMBinaryConflictAnalysis $Group $providerRecords $vanilla $binaryPlan $PreviousMap $review)
    }
    throw "Binary merge planner failed unexpectedly for $($Group.Asset) (exit $($binaryPlan.Run.ExitCode))."
  }

  # Runtime-proven Knowledge recipes are a strict fallback for exact historical
  # fixtures that required an AI/manual solution. They do not match by filename:
  # exact mappings + Vanilla family + complete provider PAK hashes + provider
  # family hashes must all match. If anything changed, normal adapters continue.
  $knownRecipe=Get-PMMProductionRecipeMatch $Group $vanilla $providerRecords
  if($knownRecipe){
    $review=Publish-PMMReviewFolder $Group $vanilla $providerRecords
    return (New-PMMKnownRecipeAnalysis $Group $providerRecords $knownRecipe $review)
  }

  if ([string]$Group.Asset -ieq 'Pal/Content/Pal/DataAsset/Item/DA_StaticItemDataAsset.uasset') {
    $probeRoot = Join-Path $Transaction ('StaticProbe\' + (Get-PMMStableTextId ([string]$Group.Key)))
    $static = Invoke-PMMStaticItemMerge $Group $vanilla $providerRecords $Transaction $probeRoot
    $review = Publish-PMMReviewFolder $Group $vanilla $providerRecords ([string]$static.ReportPath)
    if(-not $static.Success){
      if($static.PSObject.Properties.Name -contains 'Conflict' -and [bool]$static.Conflict){
        return (New-PMMStaticItemConflictAnalysis $Group $providerRecords $static $PreviousMap $review)
      }
      return (Resolve-PMMUnsupportedOrManual $Group $vanilla $providerRecords ([string]$static.Reason) $review)
    }
    $reason = ('StaticItem true merge succeeded: intents={0}; byte patches={1}.' -f [int]$static.Report.inference.intents,[int]$static.Report.patches)
    if ($static.Report.behaviorApplied) { $reason += ' Behavior=' + [string]$static.Report.behaviorApplied + '.' }
    return [pscustomobject]@{Asset=[pscustomobject]@{AssetKey=$Group.Key;Asset=$Group.Asset;Providers=@($ProviderMods.Name);Mode='StaticItemAuto';ConflictCount=0;ChangedPathCount=[int]$static.Report.patches;Reason=$reason;ReviewFolder=$review};Rows=@()}
  }

  # DataTables first try a stronger/no-rewrite proof: if the largest cooked
  # provider already contains every byte requested by each current-layout
  # secondary provider, keep that anchor unchanged. This is a true merge because
  # the secondary changes are proven present, not discarded. Only if that proof
  # fails do we invoke the property-level DataTable adapter.
  $leafName=[IO.Path]::GetFileName([string]$Group.Asset)
  if(([string]$Group.Asset -match '/DataTable/') -or $leafName.StartsWith('DT_',[StringComparison]::OrdinalIgnoreCase)){
    $supersetRoot=Join-Path $Transaction ('SupersetProbe\'+(Get-PMMStableTextId ([string]$Group.Key)))
    $superset=Invoke-PMMSupersetMerge $Group $vanilla $providerRecords $Transaction $supersetRoot
    if($superset.Run.ExitCode -eq 0){
      $review=Publish-PMMReviewFolder $Group $vanilla $providerRecords ([string]$superset.ReportPath)
      return [pscustomobject]@{Asset=[pscustomobject]@{AssetKey=$Group.Key;Asset=$Group.Asset;Providers=@($ProviderMods.Name);Mode='SupersetAuto';ConflictCount=0;ChangedPathCount=[int]$superset.Report.requestedBytes;Reason=('Largest cooked provider already subsumes every independent byte requested by the other provider(s). Base='+[string]$superset.Report.baseProvider+'; requested='+[string]$superset.Report.requestedBytes+'; residual-anchor='+[string]$superset.Report.residualAnchorBytes+'.');ReviewFolder=$review};Rows=@()}
    }
    if($superset.Run.ExitCode -ne 5){throw "Superset-anchor merger infrastructure failure for $($Group.Asset) (exit $($superset.Run.ExitCode))."}

    $probeRoot=Join-Path $Transaction ('DataTableProbe\'+(Get-PMMStableTextId ([string]$Group.Key)))
    try{
      $dt=Invoke-PMMDataTableMerge $Group $vanilla $providerRecords $Transaction $probeRoot
    }catch{
      # A semantic reader failure means this particular cooked DataTable cannot
      # currently be mapped safely. It is Unsupported, not a request to discard
      # one mod. Dependency failures are caught earlier by Assert-PMMEngineReady.
      $review=Publish-PMMReviewFolder $Group $vanilla $providerRecords ([string]$superset.ReportPath)
      return (Resolve-PMMUnsupportedOrManual $Group $vanilla $providerRecords ('Neither SupersetAnchor nor the DataTable semantic reader could safely merge this cooked family. Superset reason: '+[string]$superset.Report.reason+'. DataTable reader: '+$_.Exception.Message) $review)
    }
    $review=Publish-PMMReviewFolder $Group $vanilla $providerRecords ([string]$dt.ReportPath)
    if($dt.Run.ExitCode -eq 0){
      return [pscustomobject]@{Asset=[pscustomobject]@{AssetKey=$Group.Key;Asset=$Group.Asset;Providers=@($ProviderMods.Name);Mode='DataTableAuto';ConflictCount=0;ChangedPathCount=[int]$dt.Report.patches;Reason=('DataTable property merge succeeded. Base='+[string]$dt.Report.baseProvider+'.');ReviewFolder=$review};Rows=@()}
    }
    if($dt.Run.ExitCode -eq 5 -and $dt.Report){
      if(@($dt.Report.unsupported).Count -gt 0){
        $why=@($dt.Report.unsupported|ForEach-Object{"$($_.Path): $($_.Reason)"}) -join ' | '
        return (Resolve-PMMUnsupportedOrManual $Group $vanilla $providerRecords ('DataTable has unsupported structural/property changes: '+$why) $review)
      }
      if(@($dt.Report.conflicts).Count -gt 0){
        return (New-PMMDataTableConflictAnalysis $Group $providerRecords $vanilla $dt $PreviousMap $review)
      }
    }
    throw "DataTable merger infrastructure failure for $($Group.Asset) (exit $($dt.Run.ExitCode))."
  }

  # First try a stricter no-rewrite structural-superset proof. This catches
  # additive Blueprint variants where the largest cooked provider already
  # contains every Vanilla-relative executable hunk of each smaller provider,
  # while extending its metadata only by insertion/prefix growth. The anchor is
  # preserved byte-for-byte; no Blueprint is reserialized. Fly + Wing is the
  # first real fixture for this adapter.
  $containedRoot=Join-Path $Transaction ('ContainedSupersetProbe\'+(Get-PMMStableTextId ([string]$Group.Key)))
  $contained=Invoke-PMMContainedSupersetMerge $Group $vanilla $providerRecords $Transaction $containedRoot
  if($contained.Run.ExitCode -eq 0){
    $review=Publish-PMMReviewFolder $Group $vanilla $providerRecords ([string]$contained.ReportPath)
    return [pscustomobject]@{Asset=[pscustomobject]@{AssetKey=$Group.Key;Asset=$Group.Asset;Providers=@($ProviderMods.Name);Mode='ContainedSupersetAuto';ConflictCount=0;ChangedPathCount=[int]$contained.Report.provenUexpHunks;Reason=('Contained structural superset proved. Base='+[string]$contained.Report.baseProvider+' already contains every executable hunk requested by the other provider(s); metadata insertions are prefix-contained.');ReviewFolder=$review};Rows=@()}
  }
  if($contained.Run.ExitCode -ne 5){throw "Contained-superset merger infrastructure failure for $($Group.Asset) (exit $($contained.Run.ExitCode))."}
  $containedWhy=if($contained.Report){[string]$contained.Report.reason}else{'No contained structural superset proof was found.'}

  # Generic variable-size composition path. It deliberately chooses the
  # largest cooked provider as anchor and can transplant smaller providers whose
  # .uasset differences are proven to be relocation arithmetic caused by
  # disjoint .uexp edits. This is the pattern in EasyBreeding + NoCollision.
  $relocRoot=Join-Path $Transaction ('RelocatableProbe\'+(Get-PMMStableTextId ([string]$Group.Key)))
  $reloc=Invoke-PMMRelocatableMerge $Group $vanilla $providerRecords $Transaction $relocRoot
  $review=Publish-PMMReviewFolder $Group $vanilla $providerRecords ([string]$reloc.ReportPath)
  if($reloc.Run.ExitCode -eq 0){
    return [pscustomobject]@{Asset=[pscustomobject]@{AssetKey=$Group.Key;Asset=$Group.Asset;Providers=@($ProviderMods.Name);Mode='RelocatableAuto';ConflictCount=0;ChangedPathCount=[int]$reloc.Report.appliedHunks;Reason=('Relocatable delta merge succeeded. Base='+[string]$reloc.Report.baseProvider+'.');ReviewFolder=$review};Rows=@()}
  }
  if($reloc.Run.ExitCode -ne 5){throw "Relocatable merger infrastructure failure for $($Group.Asset) (exit $($reloc.Run.ExitCode))."}
  if($reloc.Report -and [string]$reloc.Report.status -eq 'CONFLICT' -and @($reloc.Report.conflicts).Count -gt 0){
    return (New-PMMRelocatableConflictAnalysis $Group $providerRecords $reloc $PreviousMap $review)
  }
  $why=if($reloc.Report){[string]$reloc.Report.reason}else{'No safe relocatable composition was found.'}
  return (Resolve-PMMUnsupportedOrManual $Group $vanilla $providerRecords ('No safe automatic adapter accepted this shared asset. Contained-superset proof: '+$containedWhy+'. Relocatable proof: '+$why) $review)
}

function Invoke-PMMSharedPlainFileAnalysis($Group,[array]$ProviderMods,[string]$Transaction,$PreviousMap) {
  $records = New-Object System.Collections.Generic.List[object]
  foreach ($mod in $ProviderMods) {
    $root = Join-Path $Transaction ('Files\' + (Get-PMMStableTextId ([string]$mod.Name + '|' + [string]$Group.Key)))
    $path = Export-PakFileExact ([string]$mod.Path) ([string]$Group.Asset) $root
    $records.Add([pscustomobject]@{Mod=$mod;Path=$path})
  }
  $providerRecords = $records.ToArray()
  $hashes = @($providerRecords | ForEach-Object { Get-Sha256 $_.Path } | Select-Object -Unique)
  if ($hashes.Count -eq 1) {
    return [pscustomobject]@{Asset=[pscustomobject]@{AssetKey=$Group.Key;Asset=$Group.Asset;Providers=@($ProviderMods.Name);Mode='Identical';ConflictCount=0;ChangedPathCount=0;Reason='All providers contain the same file.';ReviewFolder=''};Rows=@()}
  }

  # PMM does not pretend that selecting one whole arbitrary non-Unreal file is a
  # merge. Until a format adapter exists, differing shared plain files are
  # explicit Unsupported and block Build instead of silently discarding mods.
  # Still create an exact metadata case so AIIO can include ALL Unsupported work
  # in the one user-requested handoff bundle.
  $reason='Shared non-Unreal file differs. No format-aware adapter is available, so PMM will not choose a whole-file winner and discard the other changes.'
  $vanillaRoot=Join-Path $Transaction ('VanillaFile\'+(Get-PMMStableTextId ([string]$Group.Key)))
  $vanillaPath=Export-VanillaFileExact ([string]$Group.Asset) $vanillaRoot
  $published=Publish-PMMPlainReviewFolder $Group $vanillaPath $providerRecords 'Unsupported' $reason
  $asset=[pscustomobject]@{
    AssetKey=$Group.Key;Asset=$Group.Asset;Providers=@($ProviderMods.Name);Mode='Unsupported';ConflictCount=0;ChangedPathCount=0;
    Reason=$reason;ReviewFolder=[string]$published.Root;AIHandoff='';CaseId=[string]$published.Case.CaseId
  }
  return [pscustomobject]@{Asset=$asset;Rows=@()}
}

function Invoke-PMMScan {
  param([switch]$Force)
  Assert-Repak
  Assert-PMMEngineReady
  $mods = @(Get-LibraryMods)
  if ($mods.Count -eq 0) { throw (Get-PMMText 'The library contains no mods.' 'La biblioteca no contiene mods.') }
  if (-not (Get-PMMConfig).GamePath) { throw (Get-PMMText 'Detect or configure Palworld first.' 'Detecta o configura Palworld primero.') }

  # Package-choice rules run before asset analysis.  They describe installer
  # alternatives declared by a mod package (not byte-level merge semantics).
  # An unresolved package choice must stop here so PMM never attempts to merge
  # mutually exclusive variants as if they were independent mods.
  $previous = Get-PMMPreviousDecisionMap
  $packageAnalyses=@(Get-PMMPackageChoiceAnalyses $mods $previous)
  $packageAssets=@($packageAnalyses|ForEach-Object{$_.Asset})
  $packageRows=@($packageAnalyses|ForEach-Object{$_.Row})
  $packageUnresolved=@($packageRows|Where-Object{[string]::IsNullOrWhiteSpace([string]$_.SelectedChoice)})

  if($packageUnresolved.Count -gt 0){
    $plan=[pscustomobject]@{
      SchemaVersion=(Get-PMMPlanSchemaVersion)
      Engine=(Get-PMMEngineId)
      EngineProfile='UE5_1'
      MappingsSha256=(Get-Sha256 (Get-PMMMappingsPath))
      Created=(Get-Date).ToString('o')
      SourceSignature=(Get-PMMLibrarySignature $mods)
      VanillaSourceSignature=(Get-PMMVanillaPakSetQuickSignature)
      MergeOrderSignature=(Get-PMMMergeOrderSignature $mods)
      EffectiveMergeOrderSignature=(Get-PMMEffectivePatchOrderSignature $packageAssets $mods $packageRows)
      MergeOrder=@($mods|Sort-Object Priority,Name|ForEach-Object{[string]$_.Name})
      SourceMods=@($mods|Sort-Object Priority,Name|ForEach-Object{[pscustomobject]@{Name=$_.Name;Hash=$_.Hash;Size=$_.Size;Priority=$_.Priority}})
      EffectiveSourceMods=@()
      AlreadyPatched=$false
      ActivePatch=''
      PatchedMods=@()
      PackageChoicePendingReanalysis=$true
      DeploymentSuppressions=@()
      Assets=$packageAssets
      Rows=$packageRows
    }
    Write-PMMMergePlan $plan
    $report=[pscustomobject]@{SchemaVersion=(Get-PMMPlanSchemaVersion);Created=(Get-Date).ToString('o');Groups=@();SharedAssetGroups=$packageAssets.Count;Assets=$packageAssets;AlreadyPatched=$false;ActivePatch='';PackageChoicePendingReanalysis=$true}
    $report|ConvertTo-Json -Depth 40|Set-Content -LiteralPath (Get-PMMLastScanPath) -Encoding UTF8
    $summary=(Get-PMMText 'Package choice required: {0} package decision(s). Choose a valid variant in Resolution & Review, then run Analyze again.' 'Se requiere elegir paquete: {0} decision(es) de paquete. Elige una variante valida en Resolucion y revision y vuelve a ejecutar Analizar.') -f $packageUnresolved.Count
    Write-PMMLog "Analyze paused for package choice. $summary"
    Invoke-PMMProgress 1 1 (Get-PMMText 'Analyze paused - choose a package variant.' 'Analisis pausado - elige una variante del paquete.')
    return [pscustomobject]@{Summary=$summary;Shared=$packageAssets.Count;Binary=0;Semantic=0;Relocatable=0;Experimental=0;Decisions=$packageRows.Count;Unsupported=0;Identical=0;AlreadyPatched=$false;ActivePatch='';PackageChoicePendingReanalysis=$true}
  }

  $packageSuppressions=@(Get-PMMPackageChoiceSuppressions $packageRows)
  $analysisMods=@($mods|Where-Object{[string]$_.Name -notin $packageSuppressions})

  if (-not $Force) {
    $currentPatch = Get-PMMCurrentManagedPatch $mods
    if ($currentPatch) {
      Invoke-PMMProgress 1 2 (Get-PMMText 'Validating current PMM compatibility patch...' 'Validando el parche de compatibilidad PMM actual...')
      $patchedMods = @($currentPatch.PatchedMods | Sort-Object -Unique)
      $assetCount = [int]$currentPatch.AssetCount
      $patchSuppressions=@()
      if($currentPatch.Manifest){
        if($currentPatch.Manifest.PSObject.Properties.Name -contains 'DeploymentSuppressions'){
          $patchSuppressions=@($currentPatch.Manifest.DeploymentSuppressions|ForEach-Object{[string]$_}|Where-Object{$_}|Sort-Object -Unique)
        }elseif(($currentPatch.Manifest.PSObject.Properties.Name -contains 'Assets') -and ($currentPatch.Manifest.PSObject.Properties.Name -contains 'Decisions')){
          $legacySuppressionPlan=[pscustomobject]@{Assets=@($currentPatch.Manifest.Assets);Rows=@($currentPatch.Manifest.Decisions)}
          $patchSuppressions=@(Get-PMMDeploymentSuppressions $mods $legacySuppressionPlan)
        }
      }
      foreach($name in $packageSuppressions){if($name -notin $patchSuppressions){$patchSuppressions+=,$name}}
      $patchSuppressions=@($patchSuppressions|Sort-Object -Unique)
      $patchState=if($currentPatch.PSObject.Properties.Name -contains 'Deployed' -and [bool]$currentPatch.Deployed){Get-PMMText 'deployed' 'desplegado'}else{Get-PMMText 'built locally; Deploy pending' 'creado localmente; Deploy pendiente'}
      $patchDecisions=if($currentPatch.Manifest -and ($currentPatch.Manifest.PSObject.Properties.Name -contains 'Decisions')){@($currentPatch.Manifest.Decisions)}else{@()}
      $summary = (Get-PMMText "Up to date: {0} already reconciles {1} shared asset(s) for this exact source-mod set ({2}). No unresolved compatibility work is pending. Patched mods: {3}" "Al dia: {0} ya reconcilia {1} asset(s) compartidos para este conjunto exacto de mods fuente ({2}). No hay trabajo de compatibilidad pendiente. Mods parcheados: {3}") -f $currentPatch.Name,$assetCount,$patchState,$(if($patchedMods.Count -gt 0){$patchedMods -join ', '}else{'metadata unavailable'})

      $plan = [pscustomobject]@{
        SchemaVersion=(Get-PMMPlanSchemaVersion)
        Engine=(Get-PMMEngineId)
        EngineProfile='UE5_1'
        MappingsSha256=(Get-Sha256 (Get-PMMMappingsPath))
        Created=(Get-Date).ToString('o')
        SourceSignature=(Get-PMMLibrarySignature $mods)
        VanillaSourceSignature=(Get-PMMVanillaPakSetQuickSignature)
        MergeOrderSignature=(Get-PMMMergeOrderSignature $mods)
        EffectiveMergeOrderSignature=(Get-PMMEffectivePatchOrderSignature @($currentPatch.Manifest.Assets) $mods $patchDecisions)
        MergeOrder=@($mods|Sort-Object Priority,Name|ForEach-Object{[string]$_.Name})
        SourceMods=@($mods | Sort-Object Priority,Name | ForEach-Object { [pscustomobject]@{Name=$_.Name;Hash=$_.Hash;Size=$_.Size;Priority=$_.Priority} })
        EffectiveSourceMods=@($analysisMods|Sort-Object Priority,Name|ForEach-Object{[string]$_.Name})
        AlreadyPatched=$true
        ActivePatch=$currentPatch.Name
        ActivePatchHash=$currentPatch.Hash
        PatchDeployed=$(if($currentPatch.PSObject.Properties.Name -contains 'Deployed'){[bool]$currentPatch.Deployed}else{$true})
        PatchedMods=$patchedMods
        PackageChoicePendingReanalysis=$false
        DeploymentSuppressions=$patchSuppressions
        Assets=@()
        Rows=@()
      }
      Write-PMMMergePlan $plan
      $report = [pscustomobject]@{SchemaVersion=(Get-PMMPlanSchemaVersion);Created=(Get-Date).ToString('o');Groups=@();SharedAssetGroups=$assetCount;Assets=@();AlreadyPatched=$true;ActivePatch=$currentPatch.Name;PatchedMods=$patchedMods}
      $report | ConvertTo-Json -Depth 40 | Set-Content -LiteralPath (Get-PMMLastScanPath) -Encoding UTF8
      Write-PMMLog "Analyze short-circuit: PMM patch is current. $($currentPatch.Name)"
      Invoke-PMMProgress 2 2 (Get-PMMText 'Analyze complete - compatibility patch is current.' 'Analisis terminado - el parche de compatibilidad esta al dia.')
      return [pscustomobject]@{Summary=$summary;Shared=$assetCount;Binary=0;Semantic=0;Relocatable=0;Decisions=0;Unsupported=0;Identical=0;AlreadyPatched=$true;ActivePatch=$currentPatch.Name}
    }
  }

  $groups = @(Get-PMMAssetGroups $analysisMods)
  $shared = @($groups | Where-Object { @($_.Providers).Count -gt 1 })
  $transaction = Join-Path (Get-PMMPath 'Cache') ('Analyze_' + [guid]::NewGuid().ToString('N'))
  New-Item -ItemType Directory -Force -Path $transaction | Out-Null
  $processStart=$(try{(Get-Process -Id $PID -ErrorAction Stop).StartTime.ToUniversalTime().ToString('o')}catch{''})
  [ordered]@{Schema='PMM_TRANSIENT_OWNER_V1';Pid=$PID;ProcessStartUtc=$processStart;Kind='Analyze';CreatedUtc=[DateTime]::UtcNow.ToString('o')}|ConvertTo-Json -Depth 5|Set-Content -LiteralPath (Join-Path $transaction 'owner.json') -Encoding UTF8
  $assets = New-Object System.Collections.Generic.List[object]
  $rows = New-Object System.Collections.Generic.List[object]
  foreach($asset in $packageAssets){$assets.Add($asset)}
  foreach($row in $packageRows){$rows.Add($row)}

  try {
    $index = 0
    $totalSteps = [Math]::Max(1,($shared.Count + 1))
    foreach ($group in $shared) {
      $index++
      Invoke-PMMProgress $index $totalSteps ((Get-PMMText 'Analyzing {0}' 'Analizando {0}') -f [string]$group.Asset)
      $providerMods = @($analysisMods | Where-Object { [string]$_.Name -in @($group.Providers) } | Sort-Object Priority,Name)
      Write-PMMLog ("PMM v1.2.1 analyzing shared {0}: {1} ({2})" -f $group.Kind,$group.Asset,($providerMods.Name -join ', '))

      # Keep Analyze disk usage bounded by one shared asset at a time. Older
      # builds passed the session transaction root to every analysis, so exact
      # provider/Vanilla extractions accumulated until the complete mod list
      # finished. A large conflict set could therefore consume many times the
      # space actually needed to analyze any individual asset.
      $groupTransaction=Join-Path $transaction ('Group_'+(Get-PMMStableTextId ([string]$group.Key)))
      New-Item -ItemType Directory -Force -Path $groupTransaction|Out-Null
      try{
        if ([string]$group.Kind -eq 'AssetFamily') {
          $analysis = Invoke-PMMSharedAssetAnalysis $group $providerMods $groupTransaction $previous
        } else {
          $analysis = Invoke-PMMSharedPlainFileAnalysis $group $providerMods $groupTransaction $previous
        }
        $assets.Add($analysis.Asset)
        foreach ($row in @($analysis.Rows)) { $rows.Add($row) }
      }finally{
        # All durable evidence was copied to metadata-only Workspace\Review before an
        # analysis result returns. The cooked scratch is never needed by the next
        # group and must be reclaimed immediately.
        Remove-Item -LiteralPath $groupTransaction -Recurse -Force -ErrorAction SilentlyContinue
      }
    }

    $plan = [pscustomobject]@{
      SchemaVersion=(Get-PMMPlanSchemaVersion)
      Engine=(Get-PMMEngineId)
      EngineProfile='UE5_1'
      MappingsSha256=(Get-Sha256 (Get-PMMMappingsPath))
      Created=(Get-Date).ToString('o')
      SourceSignature=(Get-PMMLibrarySignature $mods)
      VanillaSourceSignature=(Get-PMMVanillaPakSetQuickSignature)
      MergeOrderSignature=(Get-PMMMergeOrderSignature $mods)
      EffectiveMergeOrderSignature=(Get-PMMEffectivePatchOrderSignature @($assets.ToArray()) $mods @($rows.ToArray()))
      MergeOrder=@($mods|Sort-Object Priority,Name|ForEach-Object{[string]$_.Name})
      SourceMods=@($mods | Sort-Object Priority,Name | ForEach-Object { [pscustomobject]@{Name=$_.Name;Hash=$_.Hash;Size=$_.Size;Priority=$_.Priority} })
      EffectiveSourceMods=@($analysisMods|Sort-Object Priority,Name|ForEach-Object{[string]$_.Name})
      AlreadyPatched=$false
      ActivePatch=''
      PatchedMods=@()
      PackageChoicePendingReanalysis=$false
      Assets=$assets.ToArray()
      Rows=$rows.ToArray()
      DeploymentSuppressions=$packageSuppressions
    }
    Write-PMMMergePlan $plan

    $sharedTotal=$shared.Count+$packageAssets.Count
    $report = [pscustomobject]@{SchemaVersion=(Get-PMMPlanSchemaVersion);Created=(Get-Date).ToString('o');Groups=$groups;SharedAssetGroups=$sharedTotal;Assets=$assets.ToArray();AlreadyPatched=$false;ActivePatch='';DeploymentSuppressions=$packageSuppressions}
    $report | ConvertTo-Json -Depth 40 | Set-Content -LiteralPath (Get-PMMLastScanPath) -Encoding UTF8

    $binary = @($assets | Where-Object {$_.Mode -eq 'BinaryAuto'}).Count
    $semantic = @($assets | Where-Object {$_.Mode -in @('StaticItemAuto','DataTableAuto','SupersetAuto','ContainedSupersetAuto','KnownRecipeAuto')}).Count
    $relocatable = @($assets | Where-Object {$_.Mode -eq 'RelocatableAuto'}).Count
    $experimental = @($assets | Where-Object {$_.Mode -eq 'ManualSolutionExperimental'}).Count
    $decisions = $rows.Count
    $unsupported = @($assets | Where-Object {$_.Mode -eq 'Unsupported'}).Count
    $identical = @($assets | Where-Object {$_.Mode -eq 'Identical'}).Count
    $summary = (Get-PMMText "Shared/package items: {0} | merged automatically: {1} | decisions: {2} | unsupported: {3} | identical: {4}" "Elementos compartidos/paquete: {0} | fusionados automaticamente: {1} | decisiones: {2} | no soportados: {3} | identicos: {4}") -f $sharedTotal,($binary+$semantic+$relocatable),$decisions,$unsupported,$identical
    if($experimental -gt 0){$summary += (Get-PMMText " | experimental manual solutions: $experimental" " | soluciones manuales experimentales: $experimental")}
    Write-PMMLog "Analyze complete. $summary"
    Invoke-PMMProgress $totalSteps $totalSteps (Get-PMMText 'Analyze complete.' 'Analisis terminado.')
    return [pscustomobject]@{Summary=$summary;Shared=$sharedTotal;Binary=$binary;Semantic=$semantic;Relocatable=$relocatable;Experimental=$experimental;Decisions=$decisions;Unsupported=$unsupported;Identical=$identical;AlreadyPatched=$false;ActivePatch='';PackageChoicePendingReanalysis=$false}
  } finally {
    Remove-Item -LiteralPath $transaction -Recurse -Force -ErrorAction SilentlyContinue
  }
}

function Get-PMMLastScanReport {
  $path = Get-PMMLastScanPath
  if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { return $null }
  try { return (Get-Content -LiteralPath $path -Raw | ConvertFrom-Json) } catch { return $null }
}

function Test-PMMMergePlanCurrent {
  $plan = Read-PMMMergePlan
  if (-not $plan) { return $false }
  if (-not($plan.PSObject.Properties.Name -contains 'SchemaVersion') -or [int]$plan.SchemaVersion -ne (Get-PMMPlanSchemaVersion)) { return $false }
  if ([string]$plan.Engine -ne (Get-PMMEngineId)) { return $false }
  if ([string]$plan.EngineProfile -ne 'UE5_1') { return $false }
  $currentMods=@(Get-LibraryMods)
  if ([string]$plan.SourceSignature -ne (Get-PMMLibrarySignature $currentMods)) { return $false }
  if(-not($plan.PSObject.Properties.Name -contains 'VanillaSourceSignature') -or [string]$plan.VanillaSourceSignature -ne (Get-PMMVanillaPakSetQuickSignature)){return $false}
  if(-not($plan.PSObject.Properties.Name -contains 'MergeOrderSignature') -or [string]$plan.MergeOrderSignature -ne (Get-PMMMergeOrderSignature $currentMods)){return $false}
  $mappings = Get-PMMMappingsPath
  if (-not (Test-Path -LiteralPath $mappings -PathType Leaf)) { return $false }
  return ([string]$plan.MappingsSha256 -eq (Get-Sha256 $mappings))
}

function Get-PMMDecisionRows { $plan=Read-PMMMergePlan; if(-not$plan){return @()}; return @($plan.Rows) }

function Get-PMMConflictAssets {
  $plan=Read-PMMMergePlan; if(-not$plan){return @()}
  $result=New-Object System.Collections.Generic.List[object]
  foreach($asset in @($plan.Assets | Where-Object {[int]$_.ConflictCount -gt 0})){
    $rows=@($plan.Rows | Where-Object {[string]$_.AssetKey -eq [string]$asset.AssetKey})
    $providers=@($asset.Providers)
    $competingSet=[System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach($name in @($rows|ForEach-Object{@($_.CompetingMods)}|ForEach-Object{[string]$_}|Where-Object{$_})){[void]$competingSet.Add($name)}
    $mods=@($providers|Where-Object{$competingSet.Contains([string]$_)})
    foreach($name in @($competingSet|Sort-Object)){if([string]$name -notin $mods){$mods+=,[string]$name}}
    if($mods.Count -eq 0){$mods=$providers}
    $result.Add([pscustomobject]@{AssetKey=$asset.AssetKey;Asset=$asset.Asset;Mode=[string]$asset.Mode;Providers=$providers;ConflictMods=$mods;ConflictCount=$rows.Count;ReviewFolder=$asset.ReviewFolder;Reason=$asset.Reason;Display=((Get-PMMText '{0} decision(s) - {1}' '{0} decision(es) - {1}') -f $rows.Count,[IO.Path]::GetFileName([string]$asset.Asset))})
  }
  return $result.ToArray()
}

function Get-PMMUnsupportedAssets { $plan=Read-PMMMergePlan; if(-not$plan){return @()}; return @($plan.Assets|Where-Object{$_.Mode -eq 'Unsupported'}) }

function Save-PMMDecisionRows([array]$Rows) {
  $plan=Read-PMMMergePlan; if(-not$plan){return}
  $map=@{}; foreach($row in @($Rows)){if($row -and $row.DecisionId){$map[[string]$row.DecisionId]=$row}}
  foreach($stored in @($plan.Rows)){
    $id=[string]$stored.DecisionId
    if($map.ContainsKey($id)){
      $incoming=$map[$id]
      $oldChoice=[string]$stored.SelectedChoice;$oldCustom=[string]$stored.CustomValue
      $newChoice=[string]$incoming.SelectedChoice;$newCustom=[string]$incoming.CustomValue
      $changed=($oldChoice -cne $newChoice -or $oldCustom -cne $newCustom)
      $stored.SelectedChoice=$newChoice
      $stored.CustomValue=$newCustom
      if($changed){$stored.ResolutionOrigin='Manual'}elseif($incoming.PSObject.Properties.Name -contains 'ResolutionOrigin'){$stored.ResolutionOrigin=[string]$incoming.ResolutionOrigin}
      $isReady=(-not[string]::IsNullOrWhiteSpace([string]$stored.SelectedChoice)) -and (($stored.SelectedChoice -ne 'Custom') -or (-not[string]::IsNullOrWhiteSpace([string]$stored.CustomValue)))
      if(-not$isReady){$stored.ResolutionOrigin=''}
      $stored.Status=if(-not$isReady){Get-PMMText 'Decision required' 'Decision requerida'}elseif([string]$stored.ResolutionOrigin -eq 'Priority'){Get-PMMText 'Resolved by priority' 'Resuelto por prioridad'}else{Get-PMMText 'Resolved' 'Resuelto'}
    }
  }
  Write-PMMMergePlan $plan
}

function Convert-PMMCustomValueToJson([string]$Raw) {
  if([string]::IsNullOrWhiteSpace($Raw)){throw 'Custom value is empty.'}
  try{$null=$Raw|ConvertFrom-Json -ErrorAction Stop;return $Raw}catch{return (ConvertTo-Json -InputObject $Raw -Compress)}
}

function Test-PMMDecisionRowsReady([array]$Rows,[switch]$ThrowOnError) {
  $missing=New-Object System.Collections.Generic.List[string]
  foreach($row in @($Rows)){
    if(-not$row){continue};$choice=[string]$row.SelectedChoice
    if([string]::IsNullOrWhiteSpace($choice)){$missing.Add(("{0} :: {1}" -f $row.Asset,$row.DisplayProperty));continue}
    if($choice -eq 'Custom' -and [string]::IsNullOrWhiteSpace([string]$row.CustomValue)){$missing.Add(("{0} :: {1} :: enter a Custom value" -f $row.Asset,$row.DisplayProperty))}
  }
  if($missing.Count -gt 0){if($ThrowOnError){throw((Get-PMMText 'Resolve these decisions before Build:' 'Resuelve estas decisiones antes de Build:')+"`n`n"+($missing -join "`n"))};return $false}
  return $true
}

function Assert-PMMPlanMatchesLibrary([array]$Mods) {
  $plan=Read-PMMMergePlan
  if(-not $plan){throw (Get-PMMText 'Run Analyze before Build.' 'Ejecuta Analizar antes de Build.')}
  if(-not($plan.PSObject.Properties.Name -contains 'SchemaVersion') -or [int]$plan.SchemaVersion -ne (Get-PMMPlanSchemaVersion)){throw (Get-PMMText 'The Analyze plan belongs to an older PMM contract. Run Analyze again.' 'El plan de Analizar pertenece a un contrato anterior de PMM. Ejecuta Analizar de nuevo.')}
  if([string]$plan.Engine -ne (Get-PMMEngineId)){throw (Get-PMMText 'The Analyze plan was created by a different PMMCore version. Run Analyze again.' 'El plan de Analizar fue creado por otra version de PMMCore. Ejecuta Analizar de nuevo.')}
  if([string]$plan.SourceSignature -ne (Get-PMMLibrarySignature $Mods)){throw (Get-PMMText 'The mod library changed after Analyze. Run Analyze again.' 'La biblioteca cambio despues de Analizar. Ejecuta Analizar de nuevo.')}
  if(-not($plan.PSObject.Properties.Name -contains 'VanillaSourceSignature') -or [string]$plan.VanillaSourceSignature -ne (Get-PMMVanillaPakSetQuickSignature)){throw (Get-PMMText 'Palworld game PAKs changed after Analyze. Run Analyze again.' 'Los PAK de Palworld cambiaron despues de Analizar. Ejecuta Analizar de nuevo.')}
  if(-not($plan.PSObject.Properties.Name -contains 'MergeOrderSignature') -or [string]$plan.MergeOrderSignature -ne (Get-PMMMergeOrderSignature $Mods)){throw (Get-PMMText 'The mod priority order changed after Analyze. Run Analyze again.' 'El orden de prioridad de mods cambio despues de Analizar. Ejecuta Analizar de nuevo.')}
  if($plan.PSObject.Properties.Name -contains 'AlreadyPatched' -and [bool]$plan.AlreadyPatched){throw (Get-PMMText 'The current PMM compatibility patch already matches this exact source set; no rebuild is needed.' 'El parche de compatibilidad PMM actual ya coincide exactamente con este conjunto de fuentes; no hace falta reconstruirlo.')}
  if([string]$plan.EngineProfile -ne 'UE5_1'){throw (Get-PMMText 'The Analyze plan uses a different engine profile. Run Analyze again.' 'El plan de Analizar usa otro perfil de engine. Ejecuta Analizar de nuevo.')}
  $mappings=Get-PMMMappingsPath
  if(-not(Test-Path -LiteralPath $mappings -PathType Leaf)){throw (Get-PMMText 'Mappings.usmap is missing.' 'Falta Mappings.usmap.')}
  if([string]$plan.MappingsSha256 -ne (Get-Sha256 $mappings)){throw (Get-PMMText 'Mappings.usmap changed after Analyze. Run Analyze again.' 'Mappings.usmap cambio despues de Analizar. Ejecuta Analizar de nuevo.')}
  $unsupported=@($plan.Assets|Where-Object{$_.Mode -eq 'Unsupported'})
  if($unsupported.Count -gt 0){throw ((Get-PMMText 'Build is blocked because some shared assets do not yet have a proven merge adapter:' 'Build esta bloqueado porque algunos assets compartidos aun no tienen un adapter de merge probado:')+"`n`n"+(@($unsupported|ForEach-Object{"$($_.Asset): $($_.Reason)"}) -join "`n"))}
  Test-PMMDecisionRowsReady @($plan.Rows) -ThrowOnError | Out-Null
  return $plan
}

function Assert-OutputAssetFamiliesComplete([string]$Dest) {
  foreach($uexp in @(Get-ChildItem -LiteralPath $Dest -Filter *.uexp -File -Recurse -ErrorAction SilentlyContinue)){
    if(-not(Test-Path -LiteralPath ([IO.Path]::ChangeExtension($uexp.FullName,'.uasset')) -PathType Leaf)){throw "Build staging contains orphan .uexp: $($uexp.FullName)"}
  }
}

function Get-PMMProviderRecordsForBuild($Group,[array]$Mods,[string]$Transaction) {
  $records=New-Object System.Collections.Generic.List[object]
  foreach($name in @($Group.Providers)){
    $mod=@($Mods|Where-Object{$_.Name -eq $name}|Select-Object -First 1)[0]
    if(-not$mod){throw "Provider missing from library: $name"}
    $root=Join-Path $Transaction ('BuildProviders\'+(Get-PMMStableTextId ($name+'|'+$Group.AssetKey)))
    $export=Export-PakAssetFamilyExact $mod.Path $Group.Asset $root
    $records.Add([pscustomobject]@{Mod=$mod;Export=$export})
  }
  return $records.ToArray()
}

function Build-PMMAutoAsset($AssetPlan,[array]$Mods,[string]$Transaction,[string]$OutDir,$ResolutionRows=$null) {
  $group=[pscustomobject]@{Key=$AssetPlan.AssetKey;Asset=$AssetPlan.Asset;Providers=@($AssetPlan.Providers);Kind='AssetFamily'}
  if($AssetPlan.Mode -eq 'ManualSolutionExperimental'){
    Copy-PMMManualSolutionToBuild $AssetPlan $OutDir
    return
  }
  $records=Get-PMMProviderRecordsForBuild $AssetPlan $Mods $Transaction
  $vanillaRoot=Join-Path $Transaction ('BuildVanilla\'+(Get-PMMStableTextId ([string]$AssetPlan.AssetKey)))
  $vanilla=Export-VanillaAssetFamilyExact ([string]$AssetPlan.Asset) $vanillaRoot
  if(-not$vanilla){throw "Vanilla asset disappeared: $($AssetPlan.Asset)"}

  if($AssetPlan.Mode -eq 'KnownRecipeAuto'){
    $knownRecipe=Get-PMMProductionRecipeMatch $group $vanilla $records
    if(-not$knownRecipe){throw "Runtime-proven Knowledge recipe no longer matches for $($AssetPlan.Asset). Run Analyze again."}
    if(($AssetPlan.PSObject.Properties.Name -contains 'RecipeId') -and [string]$AssetPlan.RecipeId -ne [string]$knownRecipe.RecipeId){throw "Knowledge recipe identity changed for $($AssetPlan.Asset). Run Analyze again."}
    Copy-PMMExtractedFamily $knownRecipe.OutputRecord.Export $OutDir ([string]$AssetPlan.Asset)
    return
  }

  if($AssetPlan.Mode -in @('BinaryAuto','BinaryConflict')){
    $run=Invoke-PMMBinaryMerge ([string]$AssetPlan.Asset) $vanilla $records $OutDir $ResolutionRows $Transaction
    if($run.ExitCode -ne 0){throw "Binary merge no longer validates for $($AssetPlan.Asset). Run Analyze again."}
    return
  }
  if($AssetPlan.Mode -in @('StaticItemAuto','StaticItemConflict')){
    $staticBuild=Invoke-PMMStaticItemMerge $group $vanilla $records $Transaction $OutDir $ResolutionRows
    if(-not$staticBuild.Success){throw "StaticItem merge no longer validates for $($AssetPlan.Asset). Run Analyze again. $($staticBuild.Reason)"}
    return
  }
  if($AssetPlan.Mode -eq 'SupersetAuto'){
    $superset=Invoke-PMMSupersetMerge $group $vanilla $records $Transaction $OutDir
    if($superset.Run.ExitCode -ne 0){
      $detail=if($superset.Report){$superset.Report|ConvertTo-Json -Depth 30 -Compress}else{($superset.Run.Output -join "`n")}
      throw "Superset-anchor merge no longer validates for $($AssetPlan.Asset). Run Analyze again.`n$detail"
    }
    return
  }
  if($AssetPlan.Mode -in @('DataTableAuto','DataTableConflict')){
    $dt=Invoke-PMMDataTableMerge $group $vanilla $records $Transaction $OutDir $ResolutionRows
    if($dt.Run.ExitCode -ne 0){
      $detail=if($dt.Report){$dt.Report|ConvertTo-Json -Depth 30 -Compress}else{($dt.Run.Output -join "`n")}
      throw "DataTable merge no longer validates for $($AssetPlan.Asset). Run Analyze again.`n$detail"
    }
    return
  }
  if($AssetPlan.Mode -eq 'ContainedSupersetAuto'){
    $contained=Invoke-PMMContainedSupersetMerge $group $vanilla $records $Transaction $OutDir
    if($contained.Run.ExitCode -ne 0){
      $detail=if($contained.Report){[string]$contained.Report.reason}else{($contained.Run.Output -join [Environment]::NewLine)}
      throw "Contained-superset merge no longer validates for $($AssetPlan.Asset). Run Analyze again.`n$detail"
    }
    return
  }
  if($AssetPlan.Mode -in @('RelocatableAuto','RelocatableConflict')){
    $reloc=Invoke-PMMRelocatableMerge $group $vanilla $records $Transaction $OutDir $ResolutionRows
    if($reloc.Run.ExitCode -ne 0){
      $detail=if($reloc.Report){$reloc.Report|ConvertTo-Json -Depth 30 -Compress}else{($reloc.Run.Output -join "`n")}
      throw "Relocatable merge no longer validates for $($AssetPlan.Asset). Run Analyze again.`n$detail"
    }
    return
  }
  throw "Unsupported automatic build mode: $($AssetPlan.Mode)"
}

function Get-PMMBuildAssetEvidence($Plan,[string]$OutDir) {
  $evidence=[System.Collections.Generic.List[object]]::new()
  foreach($asset in @($Plan.Assets|Where-Object{$_.Mode -notin @('Identical','Unsupported','PackageChoice')})){
    $logical=[string]$asset.Asset
    $parts=[System.Collections.Generic.List[object]]::new()
    if($logical.ToLowerInvariant().EndsWith('.uasset')){
      $stem=$logical.Substring(0,$logical.Length-7)
      foreach($ext in @('.uasset','.uexp','.ubulk')){
        $relative=($stem+$ext).Replace([char]47,[char]92)
        $path=Join-Path $OutDir $relative
        if(Test-Path -LiteralPath $path -PathType Leaf){
          $file=Get-Item -LiteralPath $path
          $parts.Add([pscustomobject]@{Part=$ext;Bytes=$file.Length;Sha256=(Get-Sha256 $path)})
        }
      }
    }else{
      $path=Join-Path $OutDir $logical.Replace([char]47,[char]92)
      if(Test-Path -LiteralPath $path -PathType Leaf){$file=Get-Item -LiteralPath $path;$parts.Add([pscustomobject]@{Part='file';Bytes=$file.Length;Sha256=(Get-Sha256 $path)})}
    }
    $evidence.Add([pscustomobject]@{AssetKey=[string]$asset.AssetKey;Asset=$logical;Mode=[string]$asset.Mode;OutputParts=$parts.ToArray()})
  }
  return $evidence.ToArray()
}

function Build-PMMMerge {
  param([ValidateSet('ConflictGroups')][string]$Mode='ConflictGroups')
  Assert-PMMEngineReady;Assert-Repak
  $mods=@(Get-LibraryMods);if($mods.Count -eq 0){throw(Get-PMMText 'The library contains no mods.' 'La biblioteca no contiene mods.')}
  $plan=Assert-PMMPlanMatchesLibrary $mods
  $transaction=Join-Path (Get-PMMPath 'Cache') ('Build_'+[guid]::NewGuid().ToString('N'));$outDir=Join-Path $transaction 'PatchRoot';New-Item -ItemType Directory -Force -Path $outDir|Out-Null
  Set-PMMTransientStageOwner $transaction 'Build'
  try{
    $buildAssets = @($plan.Assets | Where-Object { $_.Mode -in @('BinaryAuto','StaticItemAuto','StaticItemConflict','SupersetAuto','ContainedSupersetAuto','KnownRecipeAuto','ManualSolutionExperimental','DataTableAuto','RelocatableAuto','BinaryConflict','DataTableConflict','RelocatableConflict') })
    $buildTotal = [Math]::Max(4,($buildAssets.Count + 3))
    $buildStep = 0
    Invoke-PMMBuildProgress $buildStep $buildTotal (Get-PMMText 'Preparing build...' 'Preparando build...')

    foreach($asset in $buildAssets){
      $buildStep++
      Invoke-PMMBuildProgress $buildStep $buildTotal ((Get-PMMText 'Merging {0}' 'Fusionando {0}') -f [string]$asset.Asset)
      if($asset.Mode -in @('BinaryAuto','StaticItemAuto','SupersetAuto','ContainedSupersetAuto','KnownRecipeAuto','ManualSolutionExperimental','DataTableAuto','RelocatableAuto')){Build-PMMAutoAsset $asset $mods $transaction $outDir;continue}
      if($asset.Mode -in @('BinaryConflict','StaticItemConflict','DataTableConflict','RelocatableConflict')){$assetRows=@($plan.Rows|Where-Object{$_.AssetKey -eq $asset.AssetKey});Build-PMMAutoAsset $asset $mods $transaction $outDir $assetRows;continue}
      if($asset.Mode -eq 'Unsupported'){throw "Unsupported shared asset reached Build unexpectedly: $($asset.Asset)"}
    }
    $files=@(Get-ChildItem -LiteralPath $outDir -File -Recurse -ErrorAction SilentlyContinue)
    if($files.Count -eq 0){
      Invoke-PMMBuildProgress $buildTotal $buildTotal (Get-PMMText 'Build complete.' 'Build terminado.')
      return (Get-PMMText 'No compatibility overlay is needed; shared files are identical.' 'No hace falta overlay de compatibilidad; los archivos compartidos son identicos.')
    }
    Assert-OutputAssetFamiliesComplete $outDir
    $stamp=Get-Date -Format 'yyyyMMdd_HHmmss';$name="zzzzzzzzzz_PMM_Merge_${stamp}_P.pak";$build=Join-Path (Join-PMMPath 'Builds' 'Current') $name
    $buildStep++
    Invoke-PMMBuildProgress $buildStep $buildTotal (Get-PMMText 'Packing output PAK...' 'Empaquetando el PAK de salida...')
    Pack-Pak $outDir $build;if(-not(Test-Pak $build)){throw 'Generated PAK failed index verification.'};Assert-PakAssetFamiliesComplete $build
    $patchedAssets=@($plan.Assets|Where-Object{$_.Mode -notin @('Identical','Unsupported','PackageChoice')})
    $patchedMods=@($patchedAssets|ForEach-Object{@($_.Providers)}|ForEach-Object{[string]$_}|Sort-Object -Unique)
    $experimentalManual=@($patchedAssets|Where-Object{[string]$_.Mode -eq 'ManualSolutionExperimental'}|ForEach-Object{
      [pscustomobject]@{Asset=[string]$_.Asset;CaseId=[string]$_.ManualCaseId;RuntimeStatus='UNPROVEN'}
    })
    $buildEvidence=@(Get-PMMBuildAssetEvidence $plan $outDir)
    $manifest=[pscustomobject]@{
      SchemaVersion=8
      Engine='PMMCore-v0.9.0'
      Created=(Get-Date).ToString('o')
      Mode=$Mode
      OverlayPolicy='KeepSourceModsInstalled'
      Output=$name
      OutputHash=(Get-Sha256 $build)
      OutputBytes=(Get-Item $build).Length
      SourceSignature=(Get-PMMLibrarySignature $mods)
      VanillaSourceSignature=(Get-PMMVanillaPakSetQuickSignature)
      MergeOrderSignature=(Get-PMMMergeOrderSignature $mods)
      EffectiveMergeOrderSignature=(Get-PMMEffectivePatchOrderSignature $patchedAssets $mods @($plan.Rows))
      MergeOrder=@($mods|Sort-Object Priority,Name|ForEach-Object{[string]$_.Name})
      MappingsSha256=(Get-Sha256 (Get-PMMMappingsPath))
      PatchedMods=$patchedMods
      PatchedModCount=$patchedMods.Count
      AssetCount=$patchedAssets.Count
      DeploymentSuppressions=@(Get-PMMDeploymentSuppressions $mods $plan)
      ExperimentalManualSolutions=$experimentalManual
      Assets=@($patchedAssets|ForEach-Object{[pscustomobject]@{AssetKey=$_.AssetKey;Asset=$_.Asset;Mode=$_.Mode;Providers=@($_.Providers)}})
      Sources=@($mods|Sort-Object Priority,Name|ForEach-Object{[pscustomobject]@{Name=$_.Name;Hash=$_.Hash;Priority=$_.Priority}})
      BuildAssetEvidence=$buildEvidence
      PatchContentSignature=(Get-PMMBuildEvidenceSignature $buildEvidence)
      DecisionSignature=(Get-PMMDecisionSignature @($plan.Rows))
      Decisions=@($plan.Rows)
    }
    $manifestPath=$build+'.manifest.json'
    $manifest|ConvertTo-Json -Depth 40|Set-Content -LiteralPath $manifestPath -Encoding UTF8
    $previousRoot=Join-PMMPath 'Builds' 'Previous'
    New-Item -ItemType Directory -Force -Path $previousRoot|Out-Null
    foreach($old in @(Get-ChildItem (Join-PMMPath 'Builds' 'Current') -Filter 'zzzzzzzzzz_PMM_Merge_*_P.pak' -File -ErrorAction SilentlyContinue)){
      if($old.FullName -eq $build){continue}
      $previousPak=Join-Path $previousRoot $old.Name
      $oldSidecar=$old.FullName+'.manifest.json'
      Move-Item $old.FullName $previousPak -Force
      if(Test-Path -LiteralPath $oldSidecar -PathType Leaf){Move-Item $oldSidecar ($previousPak+'.manifest.json') -Force}
    }
    $cfg=Get-PMMConfig;$cfg.LastBuild=$name;if(-not($cfg.PSObject.Properties.Name -contains 'SelectedPatchName')){$cfg|Add-Member -NotePropertyName SelectedPatchName -NotePropertyValue ''};$cfg.SelectedPatchName=$name;Save-PMMConfig $cfg
    Invoke-PMMBuildProgress $buildTotal $buildTotal (Get-PMMText 'Build complete - ready to Deploy.' 'Build terminado - listo para Deploy.')
    return((Get-PMMText "Compatibility overlay built locally:`n{0}`n`nShared assets reconciled: {1}`nPAK: {2:N1} KB`nSHA-256:`n{3}`n`nNo game files were changed. Press DEPLOY to synchronize active source mods and this patch to Palworld." "Overlay de compatibilidad creado localmente:`n{0}`n`nAssets compartidos reconciliados: {1}`nPAK: {2:N1} KB`nSHA-256:`n{3}`n`nNo se modifico ningun archivo del juego. Pulsa DEPLOY para sincronizar los mods fuente activos y este parche con Palworld.") -f $name,@($plan.Assets|Where-Object{$_.Mode -ne 'Identical'}).Count,((Get-Item $build).Length/1KB),(Get-Sha256 $build))
  }finally{
    Remove-Item -LiteralPath $transaction -Recurse -Force -ErrorAction SilentlyContinue
    Remove-PMMTransientStageOwner $transaction
  }
}
function Restore-PMMDeployment {
  param([switch]$Silent)
  Stop-PalworldForDeployment;Ensure-GameModsFolder;$count=0
  foreach($pak in @(Get-ChildItem (Get-GameModsPath) -Filter 'zzzzzzzzzz_PMM_Merge_*_P.pak' -File -ErrorAction SilentlyContinue)){
    $previousPak=Join-Path (Join-PMMPath 'Builds' 'Previous') $pak.Name
    $sidecar=$pak.FullName+'.manifest.json'
    Move-Item $pak.FullName $previousPak -Force
    if(Test-Path -LiteralPath $sidecar -PathType Leaf){Move-Item $sidecar ($previousPak+'.manifest.json') -Force}
    $count++
  }
  if(-not$Silent){return((Get-PMMText 'PMM overlays removed: {0}. Original mods were left untouched.' 'Overlays PMM retirados: {0}. Los mods originales no se tocaron.') -f $count)}
}
