param([string]$Repository=([IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))))
Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
. (Join-Path $Repository 'PMM\Modules\Operations\ModuleRuntime.ps1')
$testRoot=Join-Path $Repository ('Development\TestResults\Modules-'+[guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory((Join-Path $testRoot 'Modules'))
function Assert-True($condition,[string]$message){if(-not$condition){throw $message}}
$base=Join-Path $testRoot 'Modules\base.ps1';$feature=Join-Path $testRoot 'Modules\feature.ps1';$manifest=Join-Path $testRoot 'Modules\modules.json'
[IO.File]::WriteAllText($base,"function Get-PMMFixtureBase { return 'base' }")
[IO.File]::WriteAllText($feature,"function Get-PMMFixtureValue { return 'v1' }")
$data=[pscustomobject]@{Schema='PMM_MODULE_MANIFEST_V1';ContractVersion=1;Modules=@(
[pscustomobject]@{Id='base';Path='Modules/base.ps1';Version='1.0.0';ContractVersion=1;Dependencies=@();Capabilities=@('fixture.base');Profiles=@('UI');Stage='Legacy';Reload='Restart'},
[pscustomobject]@{Id='feature';Path='Modules/feature.ps1';Version='1.0.0';ContractVersion=1;Dependencies=@('base');Capabilities=@('fixture.feature');Profiles=@('UI');Stage='Extension';Reload='Functions'})}
function Save-Manifest {$data|ConvertTo-Json -Depth 10|Set-Content -LiteralPath $manifest -Encoding UTF8}
Save-Manifest
$paths=@(Get-PMMModuleLoadPaths -Root $testRoot -Profile UI)
Assert-True ($paths.Count -eq 2 -and $paths[0] -eq $base -and $paths[1] -eq $feature) 'Dependency order incorrect.'
Assert-True (@(Get-PMMModuleLoadPaths -Root $testRoot -Profile UI -Stage Extension).Count -eq 1) 'Extension loader re-sources legacy modules.'
foreach($path in $paths){. $path}
Initialize-PMMModuleRuntime -Root $testRoot|Out-Null
$lease=Start-PMMModuleOperation Analyze
[IO.File]::WriteAllText($feature,"function Get-PMMFixtureValue { return 'v2' }")
Assert-True ((Request-PMMModuleReload).Status -eq 'Queued') 'Busy runtime reloaded live functions.'
Assert-True ((Get-PMMFixtureValue) -eq 'v1') 'Running operation lost its pinned version.'
Assert-True ($lease.Snapshot.Generation -eq 1) 'Operation generation was not pinned.'
Complete-PMMModuleOperation $lease.Id
$result=Invoke-PMMPendingModuleReload
Assert-True ($result.Status -eq 'Activated') ('Reload failed: '+$result.Reason)
Assert-True ((Get-PMMFixtureValue) -eq 'v2') 'Activated definitions were lost in function scope.'
Assert-True ((Get-PMMModuleRuntimeSnapshot).Generation -eq 2) 'Generation was not advanced.'
[IO.File]::WriteAllText($feature,'function Get-PMMFixtureValue { broken(')
Assert-True ((Request-PMMModuleReload).Status -eq 'Rejected') 'Malformed module was accepted.'
Assert-True ((Get-PMMFixtureValue) -eq 'v2') 'Rejected parse destroyed working definition.'
[IO.File]::WriteAllText($feature,"function Get-PMMFixtureValue { return 'v3' }")
Assert-True ((Request-PMMModuleReload -Busy $true).Status -eq 'Queued') 'External worker busy guard was ignored.'
[IO.File]::WriteAllText($feature,"function Get-PMMFixtureValue { return 'v4' }")
Assert-True ((Invoke-PMMPendingModuleReload).Status -eq 'Rejected') 'Changed staged files were activated.'
Assert-True ((Get-PMMFixtureValue) -eq 'v2') 'Stale staged reload changed old function.'
[IO.File]::WriteAllText($feature,"function Get-PMMFixtureValue { return 'v3' }")
$data.Modules[1].ContractVersion=2;Save-Manifest
Assert-True ((Request-PMMModuleReload).Status -eq 'Rejected') 'Unsupported contract accepted.'
$data.Modules[1].ContractVersion=1;$data.Modules[0].Dependencies=@('feature');Save-Manifest
$rejected=$false;try{Get-PMMModuleCatalog -Root $testRoot|Out-Null}catch{$rejected=$true}
Assert-True $rejected 'Dependency cycle accepted.'
$data.Modules[0].Dependencies=@();Save-Manifest
[IO.File]::WriteAllText($base,"function Get-PMMFixtureBase { return 'new-native-wrapper' }")
Assert-True ((Request-PMMModuleReload).Status -eq 'RestartRequired') 'Initialization module changed without restart.'
[IO.File]::WriteAllText($base,"function Get-PMMFixtureBase { return 'base' }")
[IO.File]::WriteAllText($feature,"function Get-PMMFixtureValue { return 'v3' }"+[Environment]::NewLine+'Register-EngineEvent -SourceIdentifier Unsafe -Action {}')
Assert-True ((Request-PMMModuleReload).Status -eq 'Rejected') 'Reload accepted top-level event registration.'
Assert-True ((Get-PMMFixtureValue) -eq 'v2') 'Invalid event module changed current behavior.'
'MODULE_RUNTIME_OK: dependency graph, extension-only paths, operation generation pinning, queued reload, parser/contract/cycle/event rejection, stale staged bytes rejected and old functions preserved.'

[IO.File]::WriteAllText($feature,'function Get-PMMFixtureValue { return $PSScriptRoot }')
Assert-True ((Request-PMMModuleReload).Status -eq 'Activated') 'Source-path reload could not activate.'
Assert-True ((Get-PMMFixtureValue) -eq (Join-Path $testRoot 'Modules')) 'Reload lost the source directory needed by editable module resources.'
[IO.File]::WriteAllText((Join-Path $testRoot 'PMM.exe'),'fixture-bytes-not-an-executable')
Assert-True ((Request-PMMModuleReload).Status -eq 'RestartRequired') 'Native component changed without controlled restart.'
'NATIVE_RELOAD_GUARD_OK: compiled changes require restart and reloaded functions retain source resource paths.'

[IO.File]::Delete((Join-Path $testRoot 'PMM.exe'))
[IO.File]::WriteAllText($feature,"function Get-PMMFixtureValue { return 'staged-native-test' }")
Assert-True ((Request-PMMModuleReload -Busy $true).Status -eq 'Queued') 'Could not stage native activation test.'
[IO.File]::WriteAllText((Join-Path $testRoot 'PMM.exe'),'changed-native-fixture')
Assert-True ((Invoke-PMMPendingModuleReload).Status -eq 'Rejected') 'Queued reload ignored a native change before activation.'
[IO.File]::Delete((Join-Path $testRoot 'PMM.exe'))
Assert-True ((Request-PMMModuleReload -Busy $true).Status -eq 'Queued') 'Could not stage manifest activation test.'
$data.Modules[1].Version='1.1.0';Save-Manifest
Assert-True ((Invoke-PMMPendingModuleReload).Status -eq 'Rejected') 'Queued reload ignored changed manifest bytes.'
Assert-True ((Get-PMMFixtureValue) -eq (Join-Path $testRoot 'Modules')) 'Activation rejection replaced the previous implementation.'
'QUEUED_RELOAD_REVALIDATION_OK: native/manifest edits after staging preserve the active implementation.'
