param()
Set-StrictMode -Version 2;$ErrorActionPreference='Stop'
$repo=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$fixture=Join-Path $repo ('Development/TestResults/Reference132-'+[guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($fixture)
. (Join-Path $repo 'PMM/Modules/Shared/Common.ps1')
. (Join-Path $repo 'PMM/Modules/Merge/PakService.ps1')
. (Join-Path $repo 'PMM/Modules/GameReference/GameReferenceService.ps1')
function Write-PMMLog([string]$Message){}
function Get-PMMText($English,$Spanish){return $English}
function Get-PMMRepakExecutablePath{return (Join-Path $repo 'PMM/Engine/repak.exe')}
function Get-PMMMetadataPath($Name){return (Join-Path $repo ('PMM/Resources/Metadata/'+$Name))}
function Get-PMMPath($Name){return (Join-Path $fixture $Name)}
function Join-PMMPath($Name,$Child){return (Join-Path (Get-PMMPath $Name) $Child)}
$Script:Checks=0
function Assert-Test($Condition,$Message){$Script:Checks++;if(-not$Condition){throw ('FAIL: '+$Message)}}
function Assert-Fails([scriptblock]$Body,$Message){$failed=$false;try{&$Body|Out-Null}catch{$failed=$true};Assert-Test $failed $Message}
$logical='Pal/Content/Pal/Blueprint/Action/Waza/AmaterasuWolf_Dark_DarkCharge/BP_UniqueSkillModule_Tackle_AmaterasuWolf_Dark_DarkCharge.uasset'
$inputRoot=Join-Path $fixture 'input';$inputPath=Get-PMMSafePakOutputPath $inputRoot $logical
$bytes=[byte[]](0,1,2,3,128,255,33)
$stream=Open-PMMFile $inputPath -Write;try{$stream.Write($bytes,0,$bytes.Length)}finally{$stream.Dispose()}
$pak=Join-Path $fixture 'fixture.pak'
& (Get-PMMRepakExecutablePath) pack $inputRoot $pak --mount-point '../../../' --version V11 |Out-Null
if($LASTEXITCODE){throw 'Could not build synthetic PAK'}
$Script:Identity=[pscustomobject]@{PakPath=$pak;PakSize=(Get-Item $pak).Length;PakLastWriteUtc=(Get-Item $pak).LastWriteTimeUtc.ToString('o');MappingsSha256=('a'*64);ScopeVersion=$Script:PMMGameReferenceScopeVersion}
function Get-PMMGameReferenceQuickIdentity{return $Script:Identity}
# Force the real exact-extraction fallback by simulating a bulk include miss.
function Invoke-RepakText {param([array]$Arguments,[string]$Context);if($Arguments[0] -eq 'list'){return $logical};if($Script:FailPhase -eq 'bulk'){throw 'injected extraction failure'}}
$Script:FailPhase=''
Initialize-PMMNativePaths
# Emulate the .NET Framework long-path policy of affected PS 5.1 installations,
# inside this disposable test process only. No machine registry changes.
$t=[IO.File].Assembly.GetType('System.AppContextSwitches')
$fields=@('_useLegacyPathHandling','_blockLongPaths')
$original=@{}
foreach($name in $fields){$field=$t.GetField($name,[Reflection.BindingFlags]'Static,NonPublic');$original[$name]=$field.GetValue($null);$field.SetValue($null,1)}
try{
  $deep=Join-Path $fixture ((('d'*85)+'\')*3+'probe.bin')
  Assert-Fails {$f=[IO.File]::Open($deep,[IO.FileMode]::Create,[IO.FileAccess]::Write,[IO.FileShare]::None);$f.Dispose()} 'legacy host reproduces long path failure'
  $f=Open-PMMFile $deep -Write;try{$f.Write($bytes,0,$bytes.Length)}finally{$f.Dispose()}
  Assert-Test ((Get-Sha256 $deep) -eq (Get-Sha256 $inputPath)) 'native long path write and hash'
  $copy=$deep+'.copy';Copy-PMMFile $deep $copy;Assert-Test (Test-PMMFile $copy) 'native long path copy'
  Assert-Fails {Remove-PMMDirectory $fixture $fixture} 'recursive deletion refuses its root'
  Assert-Test ((Get-PMMFullPath 'C:\') -eq 'C:\') 'drive root remains absolute'
  $built=Build-PMMGameReferenceLibrary
  Assert-Test ($built.Status -eq 'Current' -and $built.FileCount -eq 1) 'long path exact fallback publishes complete reference'
  $output=Get-PMMSafePakOutputPath (Get-PMMGameReferenceCookedRoot) $logical
  Assert-Test ((Get-Sha256 $output) -eq (Get-Sha256 $inputPath)) 'extracted bytes are exact'
  $stateHash=Get-Sha256 (Get-PMMGameReferenceStatePath)
  $Script:FailPhase='bulk'
  Assert-Fails {Build-PMMGameReferenceLibrary} 'extraction failure reported'
  Assert-Test ((Get-Sha256 (Get-PMMGameReferenceStatePath)) -eq $stateHash -and (Test-PMMFile $output)) 'failure before swap preserves current reference and metadata'
  $Script:FailPhase=''
  $savedWriter=${function:Write-PMMJsonAtomic};$Script:FailMetadata=$true
  function Write-PMMJsonAtomic {param($Path,$Value,$Depth=30);if($Script:FailMetadata -and $Path -eq (Get-PMMGameReferenceStatePath)){$Script:FailMetadata=$false;throw 'injected root metadata failure'};&$savedWriter -Path $Path -Value $Value -Depth $Depth}
  Assert-Fails {Build-PMMGameReferenceLibrary} 'metadata failure reported after swap'
  Assert-Test ((Get-Sha256 (Get-PMMGameReferenceStatePath)) -eq $stateHash -and (Test-PMMFile $output)) 'failure after swap restores prior complete reference'
  Set-Item Function:Write-PMMJsonAtomic $savedWriter
  # A crash after moving current away is recovered before a new build can mutate it.
  Move-PMMDirectory (Get-PMMGameReferenceCurrentRoot) (Join-Path (Get-PMMGameReferenceRoot) '_previous')
  Repair-PMMGameReferencePublication
  Assert-Test (Test-PMMFile $output) 'interrupted publication restores prior reference'
  # Successful repeated builds clean identical history and preserve reference.
  $repeat=Build-PMMGameReferenceLibrary
  Assert-Test ($repeat.Status -eq 'Current' -and -not(Test-PMMDirectory (Join-Path (Get-PMMGameReferenceRoot) '_previous'))) 'repeat build completes cleanly'
  # A required fallback file that was never created must not publish.
  $extractor=${function:Get-PakEntry};function Get-PakEntry{}
  Assert-Fails {Build-PMMGameReferenceLibrary} 'missing fallback output rejected'
  Assert-Test (Test-PMMFile $output) 'missing fallback does not replace valid reference'
  Set-Item Function:Get-PakEntry $extractor
  'PASS reference132: '+$Script:Checks+' assertions; real repak + PS '+$PSVersionTable.PSVersion+'; restrictive long-path policy.'
}finally{
  foreach($name in $fields){$t.GetField($name,[Reflection.BindingFlags]'Static,NonPublic').SetValue($null,$original[$name])}
  Remove-PMMDirectory $fixture (Join-Path $repo 'Development/TestResults')
}
