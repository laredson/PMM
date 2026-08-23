<#
Palworld Manager Merger v1.1 dependency verification and repair.

Public-release rule:
  - repak, mappings, PMMCore and AssetReader are bundled with PMM.
  - PMM requires the exact Windows x64 .NET Runtime 8.0.30. Setup reuses an
    exact available host or downloads the pinned Microsoft runtime archive,
    verifies SHA-512 and installs it portably under Tools/dotnet when needed.
  - network access is only used when a required redistributable payload must be
    installed or repaired. PMMCore/AssetReader are never rebuilt on an end-user
    machine.
#>
param([switch]$RefreshMappings,[switch]$IfNeeded)
$ErrorActionPreference='Stop'
$ProgressPreference='SilentlyContinue'
$Root=Split-Path -Parent $MyInvocation.MyCommand.Path
$ExpectedCoreVersion='0.9.0'
$ExpectedDotnetRuntimeVersion='8.0.30'
$ExpectedDotnetRuntimeArchiveSha512='99e61c9a2d15dbb280db98bfc3ee45dfeda25fdb91e3d3c167789dd74328957a4f791c57ad13e8a3344df64a27d6ef8332dd91a773072541789a1d11ee3b4439'
$ExpectedRepakSha256='fcd538e5994b9bb833622d425ae346f4e0692f02d4b0025114a559f9b6286022'
$ExpectedOodleSha256='6f5d41a7892ea6b2db420f2458dad2f84a63901c9a93ce9497337b16c195f457'
$Tools=Join-Path $Root 'Tools'
$MappingsDir=Join-Path $Root 'Mappings'
$DotnetRoot=Join-Path $Tools 'dotnet'
$BundledRuntimeDir=Join-Path $DotnetRoot $ExpectedDotnetRuntimeVersion
$BundledDotnet=Join-Path $BundledRuntimeDir 'dotnet.exe'
$RuntimeInventory=Join-Path $DotnetRoot ('runtime-'+$ExpectedDotnetRuntimeVersion+'-win-x64.sha256.txt')
$DotnetMarker=Join-Path $Tools 'dotnet-host.txt'
$ManifestPath=Join-Path $Root 'RELEASE_MANIFEST.json'
New-Item -ItemType Directory -Force -Path $Tools,$MappingsDir,$DotnetRoot | Out-Null

try {[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12}catch{}

function Log([string]$Message){
  Write-Host "[PMM1.1] $Message"
  try {
    New-Item -ItemType Directory -Force -Path (Join-Path $Root 'Logs')|Out-Null
    Add-Content -LiteralPath (Join-Path $Root 'Logs\PalModMerger.log') -Value ('['+(Get-Date -Format 'yyyy-MM-dd HH:mm:ss.fff')+'] [Setup] '+$Message) -Encoding UTF8
  } catch {}
}
function Read-ReleaseManifest {
  if(-not(Test-Path -LiteralPath $ManifestPath -PathType Leaf)){return $null}
  try{return (Get-Content -LiteralPath $ManifestPath -Raw|ConvertFrom-Json)}catch{return $null}
}
$ReleaseManifest=Read-ReleaseManifest
if($ReleaseManifest -and ($ReleaseManifest.PSObject.Properties.Name -contains 'sourceTreeRequiresReleaseBuild') -and [bool]$ReleaseManifest.sourceTreeRequiresReleaseBuild){
  Write-Host ''
  Write-Host 'This is the v1.1 release-builder source tree, not the end-user package.' -ForegroundColor Yellow
  Write-Host 'Run BUILD_FINAL_RELEASE.cmd (or simply Start.cmd) to create:' -ForegroundColor Yellow
  Write-Host '  dist\Palworld-Manager-Merger-v1.1.zip' -ForegroundColor Cyan
  Write-Host 'The generated public ZIP includes the verified portable .NET runtime.' -ForegroundColor Yellow
  exit 10
}
function Get-ManifestText([string]$Name){
  if(-not $ReleaseManifest){return ''}
  if($ReleaseManifest.PSObject.Properties.Name -notcontains $Name){return ''}
  return [string]$ReleaseManifest.$Name
}
function Get-FileSha256([string]$Path){
  if(-not(Test-Path -LiteralPath $Path -PathType Leaf)){return ''}
  try{return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()}catch{return ''}
}
function Test-Hash([string]$Path,[string]$Expected){
  if(-not(Test-Path -LiteralPath $Path -PathType Leaf)){return $false}
  if([string]::IsNullOrWhiteSpace($Expected)){return $true}
  return ((Get-FileSha256 $Path) -eq $Expected.Trim().ToLowerInvariant())
}
function Test-ExactRepak([string]$Exe){return (Test-Hash $Exe $ExpectedRepakSha256)}
function Test-ExactRuntimeHost([string]$Exe){
  if(-not $Exe -or -not(Test-Path -LiteralPath $Exe -PathType Leaf)){return $false}
  try{
    $lines=@(& $Exe --list-runtimes 2>$null|ForEach-Object{[string]$_})
    foreach($line in $lines){if($line -match ('^Microsoft\.NETCore\.App\s+'+[regex]::Escape($ExpectedDotnetRuntimeVersion)+'\s+\[')){return $true}}
  }catch{}
  return $false
}
function Test-StandardPackageRequiresBundledRuntime {
  return [bool]($ReleaseManifest -and ($ReleaseManifest.PSObject.Properties.Name -contains 'standardPackageDotnetBundled') -and [bool]$ReleaseManifest.standardPackageDotnetBundled)
}
function Test-RuntimeInventoryMetadata {
  $mustHaveInventory=Test-StandardPackageRequiresBundledRuntime
  if(-not(Test-Path -LiteralPath $RuntimeInventory -PathType Leaf)){return (-not $mustHaveInventory)}
  $expectedInventoryHash=Get-ManifestText 'dotnetRuntimeInventorySha256'
  if(-not [string]::IsNullOrWhiteSpace($expectedInventoryHash)){
    return (Test-Hash $RuntimeInventory $expectedInventoryHash)
  }
  return (-not $mustHaveInventory)
}
function Test-RuntimeInventory([string]$RuntimeDir){
  if(-not(Test-Path -LiteralPath $RuntimeDir -PathType Container)){return $false}
  $mustHaveInventory=Test-StandardPackageRequiresBundledRuntime
  if(-not(Test-RuntimeInventoryMetadata)){return $false}
  if(-not(Test-Path -LiteralPath $RuntimeInventory -PathType Leaf)){return (-not $mustHaveInventory)}

  $rootFull=[IO.Path]::GetFullPath($RuntimeDir).TrimEnd([IO.Path]::DirectorySeparatorChar,[IO.Path]::AltDirectorySeparatorChar)
  $expected=@{}
  try{
    foreach($line in @(Get-Content -LiteralPath $RuntimeInventory)){
      if([string]::IsNullOrWhiteSpace($line)){continue}
      if($line -notmatch '^([0-9a-fA-F]{64})\s{2}(.+)$'){return $false}
      $hash=$Matches[1].ToLowerInvariant();$rel=$Matches[2].Replace('/',[IO.Path]::DirectorySeparatorChar)
      if([IO.Path]::IsPathRooted($rel)){return $false}
      $target=[IO.Path]::GetFullPath((Join-Path $RuntimeDir $rel))
      if(-not($target.StartsWith($rootFull+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase))){return $false}
      $expected[$rel.ToLowerInvariant()]=$hash
      if(-not(Test-Hash $target $hash)){return $false}
    }
  }catch{return $false}
  if($expected.Count -lt 20){return $false}
  $actual=@(Get-ChildItem -LiteralPath $RuntimeDir -Recurse -File -ErrorAction SilentlyContinue)
  if($actual.Count -ne $expected.Count){return $false}
  foreach($f in $actual){
    $rel=$f.FullName.Substring($rootFull.Length+1).ToLowerInvariant()
    if(-not $expected.ContainsKey($rel)){return $false}
  }
  return $true
}
function Test-BundledRuntime {
  # Never execute the bundled host until its complete file inventory has been
  # authenticated against the manifest-pinned inventory.
  if(-not(Test-RuntimeInventory $BundledRuntimeDir)){return $false}
  return (Test-ExactRuntimeHost $BundledDotnet)
}
function Read-DotnetMarker {
  if(-not(Test-Path -LiteralPath $DotnetMarker -PathType Leaf)){return $null}
  try{$p=(Get-Content -LiteralPath $DotnetMarker -Raw).Trim();if(Test-ExactRuntimeHost $p){return $p}}catch{}
  return $null
}
function Save-DotnetSelection([string]$Dotnet){
  try{
    $bundledResolved='';$selectedResolved=''
    if(Test-Path -LiteralPath $BundledDotnet -PathType Leaf){$bundledResolved=(Resolve-Path -LiteralPath $BundledDotnet).Path}
    if($Dotnet -and (Test-Path -LiteralPath $Dotnet -PathType Leaf)){$selectedResolved=(Resolve-Path -LiteralPath $Dotnet).Path}
    if($bundledResolved -and $selectedResolved -and $bundledResolved -eq $selectedResolved){Remove-Item -LiteralPath $DotnetMarker -Force -ErrorAction SilentlyContinue;return}
    if($Dotnet){Set-Content -LiteralPath $DotnetMarker -Value $Dotnet -Encoding UTF8}
  }catch{}
}
function Get-PreferredDotnetHost {
  if(Test-BundledRuntime){return $BundledDotnet}
  $marked=Read-DotnetMarker;if($marked){return $marked}
  if($env:PMM_DOTNET -and (Test-ExactRuntimeHost $env:PMM_DOTNET)){return $env:PMM_DOTNET}
  $system=Get-Command dotnet.exe -ErrorAction SilentlyContinue
  if($system -and (Test-ExactRuntimeHost $system.Source)){return $system.Source}
  return $null
}
function Get-PMMCoreAssemblyVersion([string]$Dll){
  if(-not(Test-Path -LiteralPath $Dll -PathType Leaf)){return $null}
  try{$v=[Reflection.AssemblyName]::GetAssemblyName($Dll).Version;if($null -eq $v){return $null};return ("{0}.{1}.{2}" -f $v.Major,$v.Minor,$v.Build)}catch{return $null}
}
function Invoke-PMMCoreProbe([string]$Dotnet,[string]$Dll){
  if(-not(Test-ExactRuntimeHost $Dotnet) -or -not(Test-Path -LiteralPath $Dll -PathType Leaf)){
    return [pscustomobject]@{Ok=$false;ExitCode=-1;Output='.NET runtime host or PMMCore DLL is missing'}
  }
  $assembly=Get-PMMCoreAssemblyVersion $Dll
  if($assembly -ne $ExpectedCoreVersion){return [pscustomobject]@{Ok=$false;ExitCode=-1;Output=('assembly version '+$assembly+' does not match '+$ExpectedCoreVersion)}}
  $dir=Split-Path -Parent $Dll
  foreach($sidecar in @('pmmcore.runtimeconfig.json','pmmcore.deps.json','PMM.Core.dll')){
    if(-not(Test-Path -LiteralPath (Join-Path $dir $sidecar) -PathType Leaf)){return [pscustomobject]@{Ok=$false;ExitCode=-1;Output=('missing '+$sidecar)}}
  }
  try{
    $lines=@(& $Dotnet $Dll 'self-test' 2>&1);$exit=$LASTEXITCODE
    $text=(@($lines|ForEach-Object{[string]$_}) -join "`n").Trim()
    $ok=($exit -eq 0 -and $text -match ('(?m)^PMMCORE_SELFTEST_OK\s+'+[regex]::Escape($ExpectedCoreVersion)+'\s*$'))
    return [pscustomobject]@{Ok=$ok;ExitCode=$exit;Output=$text}
  }catch{return [pscustomobject]@{Ok=$false;ExitCode=-1;Output=$_.Exception.Message}}
}
function Test-PMMCoreRuntime([string]$Dotnet,[string]$Dll){
  $probe=Invoke-PMMCoreProbe $Dotnet $Dll
  return [bool]$probe.Ok
}
function Test-AssetReaderRuntime([string]$Dotnet,[string]$Dll){
  if(-not(Test-ExactRuntimeHost $Dotnet) -or -not(Test-Path -LiteralPath $Dll -PathType Leaf)){return $false}
  $dir=Split-Path -Parent $Dll
  foreach($dep in @('PMM.AssetReader.deps.json','PMM.AssetReader.runtimeconfig.json','UAssetAPI.dll','Newtonsoft.Json.dll','ZstdSharp.dll')){if(-not(Test-Path -LiteralPath (Join-Path $dir $dep) -PathType Leaf)){return $false}}
  try{& $Dotnet $Dll self-test-deps | Out-Null;return ($LASTEXITCODE -eq 0)}catch{return $false}
}
function Test-ManagedRuntimeHashes {
  if(-not $ReleaseManifest -or ($ReleaseManifest.PSObject.Properties.Name -notcontains 'managedRuntimeSha256')){return $true}
  $map=$ReleaseManifest.managedRuntimeSha256
  if(-not $map){return $true}
  foreach($p in $map.PSObject.Properties){
    $relative=([string]$p.Name).Replace('/',[IO.Path]::DirectorySeparatorChar)
    if(-not(Test-Hash (Join-Path $Root $relative) ([string]$p.Value))){return $false}
  }
  return $true
}
function Test-ExactMappings([string]$Path){
  if(-not(Test-Path -LiteralPath $Path -PathType Leaf)){return $false}
  if((Get-Item -LiteralPath $Path).Length -le 1024){return $false}
  $expected=Get-ManifestText 'mappingsSha256'
  if([string]::IsNullOrWhiteSpace($expected)){return $true}
  return (Test-Hash $Path $expected)
}
function Test-PMMPrepared([string]$Dotnet){
  if(-not(Test-ExactRuntimeHost $Dotnet)){return $false}
  $coreDll=Join-Path $Tools 'PMMCore\bin\pmmcore.dll'
  $readerDll=Join-Path $Tools 'AssetReader\bin\PMM.AssetReader.dll'
  $repakPath=Join-Path $Tools 'repak.exe'
  $mappingPath=Join-Path $MappingsDir 'Mappings.usmap'
  if(-not(Test-ExactRepak $repakPath)){return $false}
  if(-not(Test-ExactMappings $mappingPath)){return $false}
  if(-not(Test-ManagedRuntimeHashes)){return $false}
  return ((Test-PMMCoreRuntime $Dotnet $coreDll) -and (Test-AssetReaderRuntime $Dotnet $readerDll))
}
function Repair-OodleIfUnexpected {
  $oodle=Join-Path $Tools 'oo2core_9_win64.dll'
  if(-not(Test-Path -LiteralPath $oodle -PathType Leaf)){return}
  $actual=Get-FileSha256 $oodle
  if($actual -ne $ExpectedOodleSha256){
    Log ('Removing unexpected Oodle runtime hash. repak will reacquire its pinned runtime on demand. Found: '+$actual)
    Remove-Item -LiteralPath $oodle -Force -ErrorAction Stop
  }
}
function Get-NearbyPMMRoots {
  $result=New-Object System.Collections.Generic.List[string]
  $parent=Split-Path -Parent $Root
  if(-not $parent -or -not(Test-Path -LiteralPath $parent -PathType Container)){return @()}
  foreach($dir in @(Get-ChildItem -LiteralPath $parent -Directory -ErrorAction SilentlyContinue)){
    if($dir.FullName -eq $Root){continue}
    $result.Add($dir.FullName)
    foreach($child in @(Get-ChildItem -LiteralPath $dir.FullName -Directory -ErrorAction SilentlyContinue | Where-Object {$_.Name -like 'PalModMerger*' -or $_.Name -like 'Palworld*Manager*Merger*'})){$result.Add($child.FullName)}
  }
  return $result.ToArray()
}
$NearbyRoots=@(Get-NearbyPMMRoots)
function Find-NearbyRelative([string[]]$Relatives,[scriptblock]$Accept){
  foreach($rootCandidate in $NearbyRoots){foreach($relative in $Relatives){$p=Join-Path $rootCandidate $relative;if(Test-Path -LiteralPath $p -PathType Leaf){if(& $Accept $p){return $p}}}}
  return $null
}
function Install-OfficialBundledRuntime {
  $runtimeUrl='https://builds.dotnet.microsoft.com/dotnet/Runtime/8.0.30/dotnet-runtime-8.0.30-win-x64.zip'
  $zip=Join-Path $env:TEMP ('PMM1_1_dotnet_runtime_'+[guid]::NewGuid().ToString('N')+'.zip')
  $stage=Join-Path $env:TEMP ('PMM1_1_dotnet_runtime_'+[guid]::NewGuid().ToString('N'))
  Log ('Installing/repairing portable .NET Runtime '+$ExpectedDotnetRuntimeVersion+' from the pinned Microsoft package...')
  try{
    Invoke-WebRequest $runtimeUrl -OutFile $zip -UseBasicParsing -TimeoutSec 120
    $actual=(Get-FileHash -LiteralPath $zip -Algorithm SHA512).Hash.ToLowerInvariant()
    if($actual -ne $ExpectedDotnetRuntimeArchiveSha512){throw ('Portable .NET Runtime checksum mismatch: '+$actual)}
    New-Item -ItemType Directory -Force -Path $stage|Out-Null
    Expand-Archive -LiteralPath $zip -DestinationPath $stage -Force
    Remove-Item -LiteralPath $BundledRuntimeDir -Recurse -Force -ErrorAction SilentlyContinue
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $BundledRuntimeDir)|Out-Null
    Move-Item -LiteralPath $stage -Destination $BundledRuntimeDir -Force
    $stage=$null
  }finally{
    Remove-Item -LiteralPath $zip -Force -ErrorAction SilentlyContinue
    if($stage){Remove-Item -LiteralPath $stage -Recurse -Force -ErrorAction SilentlyContinue}
  }
  if(-not(Test-BundledRuntime)){throw 'Repaired .NET runtime failed PMM inventory/version verification.'}
}
function Repair-ManagedPayloadFromNearby {
  if(-not $ReleaseManifest -or ($ReleaseManifest.PSObject.Properties.Name -notcontains 'managedRuntimeSha256')){return}
  foreach($p in $ReleaseManifest.managedRuntimeSha256.PSObject.Properties){
    $rel=([string]$p.Name).Replace('/',[IO.Path]::DirectorySeparatorChar);$expected=[string]$p.Value;$dst=Join-Path $Root $rel
    if(Test-Hash $dst $expected){continue}
    $near=Find-NearbyRelative @($rel) { param($candidate) Test-Hash $candidate $expected }
    if($near){New-Item -ItemType Directory -Force -Path (Split-Path -Parent $dst)|Out-Null;Copy-Item -LiteralPath $near -Destination $dst -Force;Log ('Repaired managed PMM payload from verified nearby copy: '+$rel)}
  }
}

Repair-OodleIfUnexpected
$RequiresBundledRuntime=Test-StandardPackageRequiresBundledRuntime
$dotnet=if($RequiresBundledRuntime){if(Test-BundledRuntime){$BundledDotnet}else{$null}}else{Get-PreferredDotnetHost}
if($IfNeeded -and $dotnet -and (Test-PMMPrepared $dotnet)){
  Save-DotnetSelection $dotnet
  Log 'Dependencies verified; startup setup skipped with no network access.'
  return
}

# repak: bundled first; upstream download is repair fallback only.
$repak=Join-Path $Tools 'repak.exe'
if((Test-Path -LiteralPath $repak -PathType Leaf) -and -not(Test-ExactRepak $repak)){
  Log ('Bundled repak.exe hash mismatch ('+(Get-FileSha256 $repak)+'); removing it before repair.')
  Remove-Item -LiteralPath $repak -Force
}
if(-not(Test-ExactRepak $repak)){
  $near=Find-NearbyRelative @('Tools\repak.exe') { param($p) Test-ExactRepak $p }
  if($near){Log ('Reusing verified nearby repak.exe: '+$near);Copy-Item -LiteralPath $near -Destination $repak -Force}
}
if(-not(Test-ExactRepak $repak)){
  Log 'Repairing pinned repak 0.2.3 from upstream...'
  $url='https://github.com/trumank/repak/releases/download/v0.2.3/repak_cli-x86_64-pc-windows-msvc.zip'
  $zip=Join-Path $env:TEMP ('PMM1_1_repak_'+[guid]::NewGuid().ToString('N')+'.zip');$stage=Join-Path $env:TEMP ('PMM1_1_repak_'+[guid]::NewGuid().ToString('N'))
  try{
    Invoke-WebRequest $url -OutFile $zip -UseBasicParsing -TimeoutSec 120
    Expand-Archive -LiteralPath $zip -DestinationPath $stage -Force
    $found=Get-ChildItem -LiteralPath $stage -Filter repak.exe -File -Recurse|Select-Object -First 1
    if(-not$found){throw 'Downloaded repak archive contains no repak.exe.'}
    if(-not(Test-ExactRepak $found.FullName)){throw 'Downloaded repak.exe does not match the pinned PMM SHA-256.'}
    Copy-Item -LiteralPath $found.FullName -Destination $repak -Force
  }finally{Remove-Item -LiteralPath $zip -Force -ErrorAction SilentlyContinue;Remove-Item -LiteralPath $stage -Recurse -Force -ErrorAction SilentlyContinue}
}
if(-not(Test-ExactRepak $repak)){throw 'Pinned repak 0.2.3 verification failed.'}

# mappings: the public package carries the exact mapping file used by this build.
$mappings=Join-Path $MappingsDir 'Mappings.usmap'
if($RefreshMappings){
  Log 'Checking current Palworld mappings explicitly against this release pin...'
  $expected=Get-ManifestText 'mappingsSha256'
  $tmp=Join-Path $env:TEMP ('PMM1_1_Mappings_'+[guid]::NewGuid().ToString('N')+'.usmap')
  try{
    Invoke-WebRequest 'https://raw.githubusercontent.com/PalworldModding/UsefulFiles/master/Mappings.usmap' -OutFile $tmp -UseBasicParsing -TimeoutSec 120
    if((Get-Item -LiteralPath $tmp).Length -lt 1024){throw 'Downloaded mappings file is unexpectedly small.'}
    if($expected -and -not(Test-Hash $tmp $expected)){
      throw 'Upstream mappings have changed since this PMM release. They were NOT installed because that would invalidate the release compatibility contract. Use a PMM release built for the new mappings.'
    }
    Copy-Item -LiteralPath $tmp -Destination $mappings -Force
    Log ('Release-pinned mappings reverified/refreshed: '+(Get-FileSha256 $mappings))
  }finally{Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue}
} elseif(-not(Test-ExactMappings $mappings)){
  $expected=Get-ManifestText 'mappingsSha256'
  $near=Find-NearbyRelative @('Mappings\Mappings.usmap') { param($p) Test-Hash $p $expected }
  if($near){Log ('Reusing verified nearby Mappings.usmap: '+$near);Copy-Item -LiteralPath $near -Destination $mappings -Force}
  if(-not(Test-ExactMappings $mappings)){
    Log 'Repairing release-pinned Palworld mappings...'
    $tmp=Join-Path $env:TEMP ('PMM1_1_Mappings_'+[guid]::NewGuid().ToString('N')+'.usmap')
    try{
      Invoke-WebRequest 'https://raw.githubusercontent.com/PalworldModding/UsefulFiles/master/Mappings.usmap' -OutFile $tmp -UseBasicParsing -TimeoutSec 120
      if((Get-Item -LiteralPath $tmp).Length -lt 1024){throw 'Downloaded mappings file is unexpectedly small.'}
      if($expected -and -not(Test-Hash $tmp $expected)){throw 'Current upstream mappings differ from the release-pinned mapping. Re-extract the PMM package or use -RefreshMappings explicitly.'}
      Copy-Item -LiteralPath $tmp -Destination $mappings -Force
    }finally{Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue}
  }
}

# .NET Runtime: a public release MUST keep its bundled runtime healthy. Do not
# silently bypass a damaged public payload just because the machine happens to
# have a matching system runtime. Development/source trees may still use an exact
# system host when their manifest says the standard runtime is not yet bundled.
if($RequiresBundledRuntime){
  if(-not(Test-RuntimeInventoryMetadata)){
    throw 'The bundled .NET runtime inventory is missing or modified. Re-extract the official PMM package before continuing.'
  }
  if(-not(Test-BundledRuntime)){Install-OfficialBundledRuntime}
  if(-not(Test-BundledRuntime)){throw ('Bundled .NET Runtime '+$ExpectedDotnetRuntimeVersion+' failed verification after repair.')}
  $dotnet=$BundledDotnet
} else {
  $dotnet=Get-PreferredDotnetHost
  if(-not $dotnet){
    Install-OfficialBundledRuntime
    $dotnet=Get-PreferredDotnetHost
  }
}
if(-not $dotnet -or -not(Test-ExactRuntimeHost $dotnet)){throw ('Exact .NET Runtime '+$ExpectedDotnetRuntimeVersion+' is unavailable.')}
Save-DotnetSelection $dotnet
Log ('Using .NET runtime host: '+$dotnet)

# PMMCore/AssetReader are prebuilt release payloads. End-user setup never invokes
# dotnet publish and therefore never needs the SDK or NuGet restore.
Repair-ManagedPayloadFromNearby
if(-not(Test-ManagedRuntimeHashes)){throw 'PMMCore/AssetReader release payload is missing or modified. Re-extract the official PMM package.'}
$coreDll=Join-Path $Tools 'PMMCore\bin\pmmcore.dll'
$readerDll=Join-Path $Tools 'AssetReader\bin\PMM.AssetReader.dll'
$coreProbe=Invoke-PMMCoreProbe $dotnet $coreDll
if(-not$coreProbe.Ok){throw ('PMMCore startup self-test failed. Expected '+$ExpectedCoreVersion+', assembly='+(Get-PMMCoreAssemblyVersion $coreDll)+', exit='+$coreProbe.ExitCode+"`n"+$coreProbe.Output)}
if(-not(Test-AssetReaderRuntime $dotnet $readerDll)){throw 'AssetReader dependency self-test failed.'}
Log ('Setup complete. mappings SHA-256: '+(Get-FileSha256 $mappings))
Write-Host ''
Write-Host 'Palworld Manager Merger v1.1 dependencies are ready.' -ForegroundColor Green
