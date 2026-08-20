<#
Common.ps1 - shared configuration, logging, dependencies and process safety.
All other PowerShell modules may call these helpers. Keep this file free of UI
controls so the core can later be reused by a CLI or another front-end.
#>

# Start-PalModMerger.ps1 enables StrictMode before dot-sourcing this module.
# Initialize the bundled-runtime verification cache before any function reads it.
if (-not (Get-Variable -Name 'PMMBundledRuntimeInventoryVerified' -Scope Script -ErrorAction SilentlyContinue)) {
  $Script:PMMBundledRuntimeInventoryVerified = $false
}

function Initialize-PMM {
  $dirs=@('Data','Mods','Builds\Current','Builds\Previous','Builds\DeploymentBackups','Saves\Backups','Cache','Logs','Mappings','Tools')
  foreach($d in $dirs){$p=Join-Path $Script:Root $d;if(-not(Test-Path -LiteralPath $p)){New-Item -ItemType Directory -Force -Path $p|Out-Null}}
  if(-not(Test-Path -LiteralPath (Get-PMMConfigPath))){
    $cfg=[pscustomobject]@{GamePath='';SteamRoot='';CloseGameBeforeDeploy=$true;ForceCloseOnTimeout=$false;CloseTimeoutSeconds=12;MergeMode='ConflictGroups';LastBuild='';SaveRoot='';Language='en';UiWindowWidth=1580;UiWindowHeight=940;UiWindowState='Normal';UiLibraryWidth=470;UiAnalysisHeight=300;UiResolutionHeight=220;UiConflictListWidth=250;UiPatchHeight=145;SelectedPatchName=''}
    Save-PMMConfig $cfg
  } else {
    # Non-destructive config migration for older previews.
    $cfg=Get-PMMConfig;$changed=$false
    $defaults=[ordered]@{SteamRoot='';CloseGameBeforeDeploy=$true;ForceCloseOnTimeout=$false;CloseTimeoutSeconds=12;MergeMode='ConflictGroups';LastBuild='';SaveRoot='';Language='en';UiWindowWidth=1580;UiWindowHeight=940;UiWindowState='Normal';UiLibraryWidth=470;UiAnalysisHeight=300;UiResolutionHeight=220;UiConflictListWidth=250;UiPatchHeight=145;SelectedPatchName=''}
    foreach($kv in $defaults.GetEnumerator()){
      if(-not($cfg.PSObject.Properties.Name -contains $kv.Key)){$cfg|Add-Member -NotePropertyName $kv.Key -NotePropertyValue $kv.Value;$changed=$true}
    }
    if($changed){Save-PMMConfig $cfg}
  }
  Write-PMMLog 'Application initialized.'
}

function Get-PMMConfigPath { Join-Path $Script:Root 'Data\config.json' }
function Get-PMMConfig { Get-Content -LiteralPath (Get-PMMConfigPath) -Raw | ConvertFrom-Json }
function Save-PMMConfig($Config){$Config|ConvertTo-Json -Depth 10|Set-Content -LiteralPath (Get-PMMConfigPath) -Encoding UTF8}

function Get-PMMText([string]$English,[string]$Spanish){
  $cfg=Get-PMMConfig
  if($cfg.Language -eq 'es'){return $Spanish}
  return $English
}

function Set-PMMGamePath([string]$Path){
  $resolved=Resolve-PalworldRoot $Path
  if(-not $resolved){throw (Get-PMMText 'The selected path is not a valid Palworld installation.' 'La ruta seleccionada no parece una instalacion valida de Palworld.')}
  $cfg=Get-PMMConfig
  $cfg.GamePath=$resolved
  $cfg.SaveRoot=Find-PalworldSaveRoot
  Save-PMMConfig $cfg
  Ensure-GameModsFolder
  Write-PMMLog "Game path set: $resolved"
}

function Write-PMMLog([string]$Message){
  $line="{0}  {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'),$Message
  Add-Content -LiteralPath (Join-Path $Script:Root 'Logs\PalModMerger.log') -Value $line -Encoding UTF8
}
function Get-PMMRecentLog {$p=Join-Path $Script:Root 'Logs\PalModMerger.log';if(Test-Path -LiteralPath $p){(Get-Content -LiteralPath $p -Tail 100)-join [Environment]::NewLine}else{''}}
function Get-Sha256([string]$Path){(Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash.ToLowerInvariant()}

function Get-PMMDependencyCoreVersion { return '0.9.0' }

function Get-PMMReleaseManifest {
  $path=Join-Path $Script:Root 'RELEASE_MANIFEST.json'
  if(-not(Test-Path -LiteralPath $path -PathType Leaf)){return $null}
  try{return (Get-Content -LiteralPath $path -Raw|ConvertFrom-Json)}catch{return $null}
}

function Test-PMMExpectedFileHash([string]$Path,[string]$ExpectedHash) {
  if(-not(Test-Path -LiteralPath $Path -PathType Leaf)){return $false}
  if([string]::IsNullOrWhiteSpace($ExpectedHash)){return $true}
  try{return ((Get-Sha256 $Path) -eq $ExpectedHash.Trim().ToLowerInvariant())}catch{return $false}
}

function Test-PMMDotnetHost([string]$Exe) {
  if(-not $Exe -or -not(Test-Path -LiteralPath $Exe -PathType Leaf)){return $false}
  try{
    foreach($line in @(& $Exe --list-runtimes 2>$null|ForEach-Object{[string]$_})){
      if($line -match '^Microsoft\.NETCore\.App\s+8\.0\.30\s+\['){return $true}
    }
  }catch{}
  return $false
}

function Test-PMMBundledRuntimeInventory($Manifest,[string]$RuntimeDir) {
  if(-not $Manifest -or -not([bool]$Manifest.standardPackageDotnetBundled)){return $true}
  # Setup-Dependencies performs the authoritative full verification before the
  # GUI opens. Cache only a successful verification inside this PowerShell
  # process so status refreshes do not repeatedly hash the whole runtime.
  if($Script:PMMBundledRuntimeInventoryVerified){return $true}
  if(-not(Test-Path -LiteralPath $RuntimeDir -PathType Container)){return $false}
  $inventoryRelative=[string]$Manifest.dotnetRuntimeInventory
  $inventoryHash=[string]$Manifest.dotnetRuntimeInventorySha256
  if([string]::IsNullOrWhiteSpace($inventoryRelative) -or [string]::IsNullOrWhiteSpace($inventoryHash)){return $false}
  $inventory=Join-Path $Script:Root $inventoryRelative.Replace('/',[IO.Path]::DirectorySeparatorChar)
  if(-not(Test-PMMExpectedFileHash $inventory $inventoryHash)){return $false}
  $rootFull=[IO.Path]::GetFullPath($RuntimeDir).TrimEnd([IO.Path]::DirectorySeparatorChar,[IO.Path]::AltDirectorySeparatorChar)
  $expected=@{}
  try{
    foreach($line in @(Get-Content -LiteralPath $inventory)){
      if([string]::IsNullOrWhiteSpace($line)){continue}
      if($line -notmatch '^([0-9a-fA-F]{64})\s{2}(.+)$'){return $false}
      $hash=$Matches[1].ToLowerInvariant();$rel=$Matches[2].Replace('/',[IO.Path]::DirectorySeparatorChar)
      if([IO.Path]::IsPathRooted($rel)){return $false}
      $target=[IO.Path]::GetFullPath((Join-Path $RuntimeDir $rel))
      if(-not($target.StartsWith($rootFull+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase))){return $false}
      $expected[$rel.ToLowerInvariant()]=$hash
      if(-not(Test-PMMExpectedFileHash $target $hash)){return $false}
    }
  }catch{return $false}
  if($expected.Count -lt 20){return $false}
  $actual=@(Get-ChildItem -LiteralPath $RuntimeDir -Recurse -File -ErrorAction SilentlyContinue)
  if($actual.Count -ne $expected.Count){return $false}
  foreach($f in $actual){
    $rel=$f.FullName.Substring($rootFull.Length+1).ToLowerInvariant()
    if(-not $expected.ContainsKey($rel)){return $false}
  }
  $Script:PMMBundledRuntimeInventoryVerified=$true
  return $true
}

function Get-PMMDotnetHostPath {
  $manifest=Get-PMMReleaseManifest
  $requiresBundled=[bool]($manifest -and ($manifest.PSObject.Properties.Name -contains 'standardPackageDotnetBundled') -and [bool]$manifest.standardPackageDotnetBundled)
  $runtimeDir=Join-Path $Script:Root 'Tools\dotnet\8.0.30'
  $local=Join-Path $runtimeDir 'dotnet.exe'
  # Authenticate the bundled runtime before executing dotnet.exe from it.
  if((Test-PMMBundledRuntimeInventory $manifest $runtimeDir) -and (Test-PMMDotnetHost $local)){return $local}

  # Public packages must repair their own pinned portable runtime instead of
  # silently accepting an incomplete package because a machine runtime exists.
  if($requiresBundled){return ''}

  # Development/source trees may use an exact external host until Build-Release
  # creates the self-contained public distribution.
  $marker=Join-Path $Script:Root 'Tools\dotnet-host.txt'
  if(Test-Path -LiteralPath $marker -PathType Leaf){
    try{$p=(Get-Content -LiteralPath $marker -Raw).Trim();if(Test-PMMDotnetHost $p){return $p}}catch{}
  }
  if($env:PMM_DOTNET -and (Test-PMMDotnetHost $env:PMM_DOTNET)){return $env:PMM_DOTNET}
  $system=Get-Command dotnet.exe -ErrorAction SilentlyContinue
  if($system -and (Test-PMMDotnetHost $system.Source)){return $system.Source}
  return ''
}

function Test-PMMManagedRuntimeHashes($Manifest) {
  if(-not $Manifest -or ($Manifest.PSObject.Properties.Name -notcontains 'managedRuntimeSha256')){return $true}
  if(-not $Manifest.managedRuntimeSha256){return $true}
  foreach($p in $Manifest.managedRuntimeSha256.PSObject.Properties){
    $relative=([string]$p.Name).Replace('/',[IO.Path]::DirectorySeparatorChar)
    if(-not(Test-PMMExpectedFileHash (Join-Path $Script:Root $relative) ([string]$p.Value))){return $false}
  }
  return $true
}

function Test-PMMDependencies {
  $repak=Join-Path $Script:Root 'Tools\repak.exe'
  $mapping=Join-Path $Script:Root 'Mappings\Mappings.usmap'
  $core=Join-Path $Script:Root 'Tools\PMMCore\bin\pmmcore.dll'
  $manifest=Get-PMMReleaseManifest
  $expectedRepak='';$expectedMappings='';$expectedOodle=''
  if($manifest -and ($manifest.PSObject.Properties.Name -contains 'repakSha256')){$expectedRepak=[string]$manifest.repakSha256}
  if($manifest -and ($manifest.PSObject.Properties.Name -contains 'mappingsSha256')){$expectedMappings=[string]$manifest.mappingsSha256}
  if($manifest -and ($manifest.PSObject.Properties.Name -contains 'oodleExpectedSha256')){$expectedOodle=[string]$manifest.oodleExpectedSha256}
  $oodle=Join-Path $Script:Root 'Tools\oo2core_9_win64.dll'
  $oodleOk=(-not(Test-Path -LiteralPath $oodle -PathType Leaf)) -or (Test-PMMExpectedFileHash $oodle $expectedOodle)
  $readerDir=Join-Path $Script:Root 'Tools\AssetReader\bin'
  $reader=Join-Path $readerDir 'PMM.AssetReader.dll'
  $dotnet=Get-PMMDotnetHostPath
  $readerRuntimeOk=$false;$coreOk=$false
  $managedHashesOk=Test-PMMManagedRuntimeHashes $manifest
  if($managedHashesOk -and $dotnet -and (Test-Path -LiteralPath $reader -PathType Leaf)){
    $depsPresent=$true
    foreach($dll in @('UAssetAPI.dll','Newtonsoft.Json.dll','ZstdSharp.dll')){if(-not(Test-Path -LiteralPath (Join-Path $readerDir $dll) -PathType Leaf)){$depsPresent=$false}}
    if($depsPresent){try{& $dotnet $reader self-test-deps | Out-Null;$readerRuntimeOk=($LASTEXITCODE -eq 0)}catch{$readerRuntimeOk=$false}}
  }
  if($managedHashesOk -and $dotnet -and (Test-Path -LiteralPath $core -PathType Leaf)){
    try{
      $v=[Reflection.AssemblyName]::GetAssemblyName($core).Version
      $assembly=("{0}.{1}.{2}" -f $v.Major,$v.Minor,$v.Build)
      $expectedCore=Get-PMMDependencyCoreVersion
      if($assembly -eq $expectedCore){
        $lines=@(& $dotnet $core self-test 2>&1);$exit=$LASTEXITCODE;$text=(@($lines|ForEach-Object{[string]$_}) -join "`n")
        $coreOk=($exit -eq 0 -and $text -match ('(?m)^PMMCORE_SELFTEST_OK\s+'+[regex]::Escape($expectedCore)+'\s*$'))
      }
    }catch{$coreOk=$false}
  }
  [pscustomobject]@{
    Repak=((Test-PMMExpectedFileHash $repak $expectedRepak) -and $oodleOk)
    Mappings=((Test-Path -LiteralPath $mapping -PathType Leaf) -and ((Get-Item -LiteralPath $mapping).Length -gt 1024) -and (Test-PMMExpectedFileHash $mapping $expectedMappings))
    PMMCore=$coreOk
    AssetReader=$readerRuntimeOk
    Dotnet=([bool]$dotnet)
    SevenZip=([bool](Get-Command 7z.exe -ErrorAction SilentlyContinue))
  }
}

function Initialize-PMMDependenciesIfNeeded {
  $dep=Test-PMMDependencies
  if($dep.Repak -and $dep.Mappings -and $dep.PMMCore -and $dep.AssetReader){return $true}
  # Start.cmd normally performs this before the GUI opens. Keep the same
  # behavior here as a safety net for users who launch Start-PalModMerger.ps1
  # directly: setup runs only when something is actually missing.
  try{
    Write-PMMLog 'Missing dependency detected at startup; running conditional setup.'
    & (Join-Path $Script:Root 'Setup-Dependencies.ps1') -IfNeeded
    $dep=Test-PMMDependencies
    return ($dep.Repak -and $dep.Mappings -and $dep.PMMCore -and $dep.AssetReader)
  }catch{
    Write-PMMLog ('Conditional dependency setup failed: '+$_.Exception.Message)
    return $false
  }
}

function Get-PMMStatusLine {
  $cfg=Get-PMMConfig;$dep=Test-PMMDependencies
  $g=if($cfg.GamePath -and (Test-Path -LiteralPath $cfg.GamePath)){Get-PMMText 'Game OK' 'Juego OK'}else{Get-PMMText 'Game not configured' 'Juego sin configurar'}
  $r=if($dep.Repak){'repak OK'}else{Get-PMMText 'repak missing' 'repak falta'}
  $m=if($dep.Mappings){'mappings OK'}else{Get-PMMText 'mappings missing' 'mappings faltan'}
  $c=if($dep.PMMCore){'PMMCore OK'}else{Get-PMMText 'PMMCore not prepared' 'PMMCore sin preparar'}
  $a=if($dep.AssetReader){'AssetReader OK'}else{Get-PMMText 'AssetReader not prepared' 'AssetReader sin preparar'}
  $d=if($dep.Dotnet){'.NET 8.0.30 OK'}else{Get-PMMText '.NET runtime missing' 'runtime .NET faltante'}
  return "$g | $r | $m | $d | $c | $a"
}

function Stop-PalworldForDeployment {
  $cfg=Get-PMMConfig
  $p=Get-Process -Name 'Palworld-Win64-Shipping','Palworld' -ErrorAction SilentlyContinue
  if(-not $p){return}
  if(-not $cfg.CloseGameBeforeDeploy){throw (Get-PMMText 'Palworld is running. Close it or enable automatic close before deployment.' 'Palworld esta abierto. Cierralo o activa el cierre automatico antes del despliegue.')}
  Write-PMMLog 'Requesting graceful Palworld shutdown.'
  foreach($proc in $p){try{$null=$proc.CloseMainWindow()}catch{}}
  $until=(Get-Date).AddSeconds([int]$cfg.CloseTimeoutSeconds)
  do{Start-Sleep -Milliseconds 400;$p=Get-Process -Name 'Palworld-Win64-Shipping','Palworld' -ErrorAction SilentlyContinue}while($p -and (Get-Date)-lt$until)
  if($p){
    if($cfg.ForceCloseOnTimeout){Write-PMMLog 'Graceful shutdown timed out; forcing Palworld process termination.';$p|Stop-Process -Force}
    else{throw (Get-PMMText 'Palworld did not close within the configured timeout. Close it manually or enable forced close.' 'Palworld no se cerro dentro del tiempo configurado. Cierralo manualmente o activa el cierre forzado.')}
  }
}
