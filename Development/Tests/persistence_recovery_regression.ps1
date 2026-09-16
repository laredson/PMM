param([string]$Repository=([IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))))
Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
$testRoot=Join-Path $Repository ('Development\TestResults\Persistence-'+[guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($testRoot)
. (Join-Path $Repository 'PMM\Modules\Shared\Persistence.ps1')
function Assert-True($condition,[string]$message){if(-not$condition){throw $message}}
$doc=Join-Path $testRoot 'state.json'
Write-PMMJsonAtomic $doc ([pscustomobject]@{Schema='TEST';Value=1}) -Schema TEST
Write-PMMJsonAtomic $doc ([pscustomobject]@{Schema='TEST';Value=2}) -Schema TEST
Assert-True ((Read-PMMJsonFile $doc -Schema TEST).Value -eq 2) 'Atomic replacement did not publish new bytes.'
Assert-True ((Read-PMMJsonFile ($doc+'.bak') -Schema TEST).Value -eq 1) 'Previous valid bytes were not backed up.'
$rejected=$false;try{Write-PMMJsonAtomic $doc ([pscustomobject]@{Schema='WRONG';Value=3}) -Schema TEST}catch{$rejected=$true}
Assert-True $rejected 'Wrong schema accepted.'
Assert-True ((Read-PMMJsonFile $doc).Value -eq 2) 'Rejected document changed valid state.'
[IO.File]::WriteAllText($doc,'{truncated')
Assert-True ((Read-PMMJsonFile $doc -Schema TEST -RecoverBackup).Value -eq 1) 'Corrupt JSON backup was not recovered.'
Write-PMMJsonAtomic -Path (Join-Path $testRoot 'empty.json') -Value @()
Assert-True (([IO.File]::ReadAllText((Join-Path $testRoot 'empty.json'))).Trim() -eq '[]') 'Empty array was lost.'
$schema=Join-Path $testRoot 'migrate.json'
Write-PMMJsonAtomic $schema ([pscustomobject]@{Schema='MIGRATE';SchemaVersion=1;Old='retained'})
$updated=Update-PMMJsonSchema -Path $schema -Schema MIGRATE -TargetVersion 2 -Migrations @{1={param($value)$value|Add-Member -NotePropertyName New -NotePropertyValue $value.Old;$value.SchemaVersion=2;return $value}}
Assert-True ($updated.New -eq 'retained' -and $updated.SchemaVersion -eq 2) 'Schema migration lost data.'
$child=Join-Path $testRoot 'crash-worker.ps1'
@'
param([string]$Repository,[string]$Fixture,[string]$Phase,[int]$Step=-1)
Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
. (Join-Path $Repository 'PMM\Modules\Shared\Paths.ps1')
Initialize-PMMPaths $Fixture|Out-Null
. (Join-Path $Repository 'PMM\Modules\Library\LibraryService.ps1')
function Get-GameModsPath {return (Join-Path $Script:Root 'Game\Pal\Content\Paks\~mods')}
function Write-PMMLog($message){}
function Get-PMMText($english,$spanish){return $english}
function Invoke-PMMProgressCallback($callback,$progress,$message){}
function Copy-PMMFileWithProgress($source,$dest,$callback,$start,$end,$message){[IO.File]::Copy($source,$dest)}
$Script:ActualCheckpoint=(Get-Command Save-PMMDeploymentCheckpoint).ScriptBlock
function Save-PMMDeploymentCheckpoint($Transaction,[string]$Path,[string]$CurrentPhase,[int]$CurrentStep=-1){
  & $Script:ActualCheckpoint $Transaction $Path $CurrentPhase $CurrentStep
  if($CurrentPhase -eq $Phase -and $CurrentStep -eq $Step){Stop-Process -Id $PID -Force}
}
if($Phase -eq 'AfterState'){
  $Script:ActualWriteState=(Get-Command Write-PMMDeploymentState).ScriptBlock
  function Write-PMMDeploymentState($State){& $Script:ActualWriteState $State;Stop-Process -Id $PID -Force}
}
$game=Get-GameModsPath
$ops=[pscustomobject]@{BlockingConflicts=@();RemoveActions=@([pscustomobject]@{Path=(Join-Path $game 'remove.pak')});CopyActions=@([pscustomobject]@{Name='one.pak';Source=(Join-Path $Fixture 'one.new');Destination=(Join-Path $game 'one.pak');ExpectedHash=(Get-PMMRecoveryHash (Join-Path $Fixture 'one.new'))},[pscustomobject]@{Name='two.pak';Source=(Join-Path $Fixture 'two.new');Destination=(Join-Path $game 'two.pak');ExpectedHash=(Get-PMMRecoveryHash (Join-Path $Fixture 'two.new'))})}
Invoke-PMMDeploymentTransaction ([pscustomobject]@{GameMods=$game}) $ops ([pscustomobject]@{SchemaVersion=3;Marker='new'})|Out-Null
'@ | Set-Content -LiteralPath $child -Encoding UTF8
. (Join-Path $Repository 'PMM\Modules\Shared\Paths.ps1')
. (Join-Path $Repository 'PMM\Modules\Library\LibraryService.ps1')
function Get-GameModsPath {return (Join-Path $Script:Root 'Game\Pal\Content\Paks\~mods')}
function Write-PMMLog($message){}
$phases=@(@('Preparing',-1),@('Prepared',-1),@('Committing',0),@('Committing',1),@('Committing',2),@('Verifying',-1),@('WritingState',-1),@('AfterState',-1),@('Committed',-1))
foreach($phase in $phases){
  $fixture=Join-Path $testRoot ($phase[0]+'-'+$phase[1])
  Initialize-PMMPaths $fixture|Out-Null
  $game=Get-GameModsPath;[void][IO.Directory]::CreateDirectory($game)
  [IO.File]::WriteAllText((Join-Path $game 'remove.pak'),'remove-original')
  [IO.File]::WriteAllText((Join-Path $game 'one.pak'),'one-original')
  [IO.File]::WriteAllText((Join-Path $game 'unmanaged.pak'),'never-touch')
  [IO.File]::WriteAllText((Join-Path $fixture 'one.new'),'one-new')
  [IO.File]::WriteAllText((Join-Path $fixture 'two.new'),'two-new')
  Write-PMMJsonAtomic (Get-PMMDeploymentStatePath) ([pscustomobject]@{SchemaVersion=3;Marker='old'}) -Depth 20
  Write-PMMJsonAtomic (Get-PMMPendingRemovalPath) @([pscustomobject]@{Name='remove.pak';Hash='old'}) -Depth 5
  $process=Start-Process -FilePath (Join-Path $PSHOME 'powershell.exe') -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-File',('"'+$child+'"'),'-Repository',('"'+$Repository+'"'),'-Fixture',('"'+$fixture+'"'),'-Phase',$phase[0],'-Step',$phase[1]) -PassThru -Wait -WindowStyle Hidden -RedirectStandardError (Join-Path $fixture 'error.txt')
  $stderr=[IO.File]::ReadAllText((Join-Path $fixture 'error.txt'))
  Assert-True ([string]::IsNullOrWhiteSpace($stderr)) ('Child failed before intended crash: '+$stderr)
  Assert-True ($process.ExitCode -ne 0) 'Crash worker did not terminate at the requested durable checkpoint.'
  $results=@(Invoke-PMMDeploymentRecovery)
  Assert-True (@($results|Where-Object{-not$_.Recovered}).Count -eq 0) ('Recovery failed at '+$phase[0]+'-'+$phase[1]+': '+($results|ConvertTo-Json -Depth 6))
  Assert-PMMDeploymentRecoveryComplete
  if($phase[0] -eq 'Committed'){
    Assert-True ([IO.File]::ReadAllText((Join-Path $game 'one.pak')) -eq 'one-new') 'Committed deployment was incorrectly reverted.'
    Assert-True (-not[IO.File]::Exists((Join-Path $game 'remove.pak'))) 'Committed removal lost.'
  }else{
    Assert-True ([IO.File]::ReadAllText((Join-Path $game 'one.pak')) -eq 'one-original') ('Old bytes not recovered at '+$phase[0])
    Assert-True ([IO.File]::ReadAllText((Join-Path $game 'remove.pak')) -eq 'remove-original') 'Removed original not restored.'
    Assert-True (-not[IO.File]::Exists((Join-Path $game 'two.pak'))) 'New file survived rollback.'
    Assert-True ((Read-PMMJsonFile (Get-PMMDeploymentStatePath)).Marker -eq 'old') 'Old deployment state not restored.'
    Assert-True (@(Read-PMMJsonFile (Get-PMMPendingRemovalPath)).Count -eq 1) 'Pending removals not restored.'
  }
  Assert-True ([IO.File]::ReadAllText((Join-Path $game 'unmanaged.pak')) -eq 'never-touch') 'Unmanaged file changed.'
  Assert-True (@(Invoke-PMMDeploymentRecovery).Count -eq 0) 'Recovery was not idempotent.'
}
'PERSISTENCE_RECOVERY_OK: atomic writes, schema guard, backup recovery, migration and 9 forced process termination checkpoints, idempotent recovery. Fixtures: '+$testRoot

# Recovery metadata and backups remain inspectable after failures; malformed
# paths cannot authorize writes outside this temporary fake game/workspace.
foreach($scenario in @('ExternalEdit','CorruptBackup','PathEscape','StatePathEscape','InvalidManifest','WrongGame')){
  $fixture=Join-Path $testRoot ('Failure-'+$scenario)
  Initialize-PMMPaths $fixture|Out-Null
  $game=Get-GameModsPath;[void][IO.Directory]::CreateDirectory($game)
  [IO.File]::WriteAllText((Join-Path $game 'remove.pak'),'remove-original')
  [IO.File]::WriteAllText((Join-Path $game 'one.pak'),'one-original')
  [IO.File]::WriteAllText((Join-Path $fixture 'one.new'),'one-new')
  [IO.File]::WriteAllText((Join-Path $fixture 'two.new'),'two-new')
  [IO.File]::WriteAllText((Join-Path $fixture 'outside.pak'),'outside-protected')
  Write-PMMJsonAtomic (Get-PMMDeploymentStatePath) ([pscustomobject]@{SchemaVersion=3;Marker='old'}) -Depth 20
  Write-PMMJsonAtomic (Get-PMMPendingRemovalPath) @([pscustomobject]@{Name='remove.pak';Hash='old'}) -Depth 5
  $process=Start-Process -FilePath (Join-Path $PSHOME 'powershell.exe') -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-File',('"'+$child+'"'),'-Repository',('"'+$Repository+'"'),'-Fixture',('"'+$fixture+'"'),'-Phase','Committing','-Step','2') -PassThru -Wait -WindowStyle Hidden -RedirectStandardError (Join-Path $fixture 'error.txt')
  Assert-True ([string]::IsNullOrWhiteSpace([IO.File]::ReadAllText((Join-Path $fixture 'error.txt')))) 'Failure fixture did not reach its crash checkpoint.'
  $pending=@(Get-PMMPendingDeploymentRecovery)
  Assert-True ($pending.Count -eq 1) 'Interrupted transaction was not detected.'
  $path=$pending[0].Path;$originalJson=[IO.File]::ReadAllText($path);$record=$originalJson|ConvertFrom-Json
  switch($scenario){
    'ExternalEdit' {[IO.File]::WriteAllText((Join-Path $game 'one.pak'),'foreign-user-change')}
    'CorruptBackup' {$backup=@($record.Files|Where-Object{[IO.Path]::GetFileName($_.Target) -eq 'one.pak'})[0].Backup;[IO.File]::WriteAllText($backup,'corrupt')}
    'PathEscape' {$record.Files[0].Target=Join-Path $fixture 'outside.pak';Write-PMMJsonAtomic $path $record}
    'StatePathEscape' {$record.StateFiles[0].Target=Join-Path $fixture 'outside.pak';Write-PMMJsonAtomic $path $record}
    'InvalidManifest' {[IO.File]::WriteAllText($path,'{bad')}
    'WrongGame' {$record.GameMods=Join-Path $fixture 'DifferentGame';Write-PMMJsonAtomic $path $record}
  }
  $results=@(Invoke-PMMDeploymentRecovery)
  Assert-True (@($results|Where-Object{-not$_.Recovered}).Count -ge 1) ('Unsafe recovery did not block: '+$scenario)
  $blocked=$false;try{Assert-PMMDeploymentRecoveryComplete}catch{$blocked=$true}
  Assert-True $blocked 'Unresolved recovery did not block subsequent deployment.'
  Assert-True ([IO.File]::ReadAllText((Join-Path $fixture 'outside.pak')) -eq 'outside-protected') 'Recovery escaped its validated roots.'
  if($scenario -eq 'ExternalEdit'){Assert-True ([IO.File]::ReadAllText((Join-Path $game 'one.pak')) -eq 'foreign-user-change') 'Recovery overwrote externally changed bytes.'}
  if($scenario -in @('ExternalEdit','CorruptBackup')){
    $failed=Read-PMMJsonFile $path
    Assert-True ($failed.State -eq 'RollbackIncomplete' -and @($failed.Files).Count -eq 3 -and @($failed.RollbackErrors).Count -gt 0) 'Failed rollback discarded recovery metadata.'
  }
  # Correct only the injected failure and retry the same durable record.
  [IO.File]::WriteAllText($path,$originalJson)
  if($scenario -eq 'ExternalEdit'){[IO.File]::WriteAllText((Join-Path $game 'one.pak'),'one-new')}
  if($scenario -eq 'CorruptBackup'){[IO.File]::WriteAllText($backup,'one-original')}
  $retry=@(Invoke-PMMDeploymentRecovery)
  Assert-True (@($retry|Where-Object{-not$_.Recovered}).Count -eq 0) ('Corrected recovery could not resume: '+$scenario)
  Assert-PMMDeploymentRecoveryComplete
  Assert-True ([IO.File]::ReadAllText((Join-Path $game 'one.pak')) -eq 'one-original') 'Retry did not recover original bytes.'
}
'RECOVERY_FAILURE_GUARDS_OK: external edits, corrupt backup, game/state traversal, malformed journal and wrong installation block safely; corrected records recover.'

$gatePath=Join-PMMPath 'Cache' 'PMM.background-operation.lock'
$gate=[IO.File]::Open($gatePath,[IO.FileMode]::OpenOrCreate,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)
try{
  $blocked=$false
  try{Deploy-PMMManagedState|Out-Null}catch{$blocked=$_.Exception.Message -like '*Another PMM processing operation*'}
  Assert-True $blocked 'Foreground deployment ignored the worker/MCP operation gate.'
}finally{$gate.Dispose()}
$Script:FixtureLeaseHeld=$false
function Start-PMMModuleOperation($Operation){$Script:FixtureLeaseHeld=$true;return [pscustomobject]@{Id='fixture';Snapshot=@{Generation=1}}}
function Complete-PMMModuleOperation($LeaseId){$Script:FixtureLeaseHeld=$false}
function Get-PMMText($English,$Spanish){return $English}
function Get-PMMDeploymentContext {throw 'fixture-stop-before-any-game-access'}
$failed=$false;try{Deploy-PMMManagedState|Out-Null}catch{$failed=$_.Exception.Message -eq 'fixture-stop-before-any-game-access'}
Assert-True ($failed -and -not$Script:FixtureLeaseHeld) 'Failed deployment leaked a module generation lease.'
$gate=[IO.File]::Open($gatePath,[IO.FileMode]::OpenOrCreate,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None);$gate.Dispose()
'DEPLOYMENT_OPERATION_GATE_OK: active workers block foreground deploy and preflight failure releases its generation lease and file lock.'

# Exercise the real library move through its shared generated activation hook.
$normalDir=Join-Path (Get-PMMDisabledModRoot) 'OrdinaryFixture'
[void][IO.Directory]::CreateDirectory($normalDir);[IO.File]::WriteAllText((Join-Path $normalDir 'ordinary.pak'),'ordinary')
$Script:ActivationFixture=[pscustomobject]@{Name='ordinary.pak';Path=(Join-Path $normalDir 'ordinary.pak');Enabled=$false}
function Find-PMMLibraryMod($Name){return $Script:ActivationFixture}
function Remove-PMMPendingRemoval($Name){}
function Clear-PakEntryCache {}
Set-PMMLibraryModEnabled 'ordinary.pak' $true
Assert-True ([IO.File]::Exists((Join-Path (Get-LibraryRoot) 'OrdinaryFixture\ordinary.pak'))) 'Ordinary source activation changed behavior.'
$generatedDir=Join-Path (Get-PMMDisabledModRoot) 'GeneratedFixture'
[void][IO.Directory]::CreateDirectory($generatedDir);[IO.File]::WriteAllText((Join-Path $generatedDir 'PMM_Generated_fixture_P.pak'),'generated')
$Script:ActivationFixture=[pscustomobject]@{Name='PMM_Generated_fixture_P.pak';Path=(Join-Path $generatedDir 'PMM_Generated_fixture_P.pak');Enabled=$false}
$blocked=$false;try{Set-PMMLibraryModEnabled $Script:ActivationFixture.Name $true}catch{$blocked=$true}
Assert-True ($blocked -and [IO.Directory]::Exists($generatedDir)) 'Generated activation bypassed missing Knowledge validation.'
$Script:ReceivedTrialProof=''
function Assert-PMMGeneratedLibraryActivation($Mod,$TrialAuthorization){
  if([string]$TrialAuthorization -ne 'fixture-validated-proof'){throw 'Trial proof required'}
  $Script:ReceivedTrialProof=[string]$TrialAuthorization
}
$blocked=$false;try{Set-PMMLibraryModEnabled $Script:ActivationFixture.Name $true}catch{$blocked=$true}
Assert-True ($blocked -and [IO.Directory]::Exists($generatedDir)) 'Generated activation moved files before proof validation.'
Set-PMMLibraryModEnabled $Script:ActivationFixture.Name $true -TrialAuthorization 'fixture-validated-proof'
Assert-True ($Script:ReceivedTrialProof -eq 'fixture-validated-proof' -and [IO.File]::Exists((Join-Path (Get-LibraryRoot) 'GeneratedFixture\PMM_Generated_fixture_P.pak'))) 'Library activation did not forward the validated proof before its move.'
'LIBRARY_ACTIVATION_CONTRACT_OK: ordinary sources still enable; generated sources stay inactive without a validation service/proof; validated proof forwarded before move.'