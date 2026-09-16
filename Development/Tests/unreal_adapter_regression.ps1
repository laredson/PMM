param([string]$Repository=([IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))))
Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
$app=Join-Path $Repository 'PMM'
$Script:Root=Join-Path $Repository ('Development\TestResults\Unreal-'+[guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory((Join-Path $Script:Root 'Modules'))
Copy-Item (Join-Path $app 'Modules\*') (Join-Path $Script:Root 'Modules') -Recurse
[void][IO.Directory]::CreateDirectory((Join-Path $Script:Root 'Resources\Unreal'))
Copy-Item (Join-Path $app 'Resources\Unreal\profile.json') (Join-Path $Script:Root 'Resources\Unreal\profile.json')
. (Join-Path $app 'Modules\Shared\Paths.ps1')
Initialize-PMMPaths $Script:Root | Out-Null
. (Join-Path $app 'Modules\AIIO\AIIO.SessionService.ps1')
. (Join-Path $app 'Modules\AIIO\AIIO.CaseWorkspaceService.ps1')
. (Join-Path $app 'Modules\MCP\MCP.Service.ps1')
. (Join-Path $app 'Modules\Unreal\Unreal.Files.ps1')
. (Join-Path $app 'Modules\Unreal\Unreal.Install.ps1')
$count=0
function Assert($ok,$message){if(-not $ok){throw $message};$script:count++;"PASS: $message"}
function Reject($action,$message){$rejected=$false;try{& $action|Out-Null}catch{$rejected=$true};Assert $rejected $message}
Set-PMMMCPEnabled $true
$c=New-PMMAIIOCase -Title 'Unreal test' -Transport MCP
Assert (-not(Get-PMMUnrealSettings).enabled) 'Unreal off by default'
$status=Invoke-PMMMCPTool 'pmm_status' ([pscustomobject]@{})
Assert ($status.capabilities.inspect -eq 'pmm_asset_inspect' -and -not $status.unrealEditorAdapter.verified) 'Base inspection advertised; Unreal not falsely verified'
Reject {Invoke-PMMMCPTool 'pmm_unreal_prepare' ([pscustomobject]@{caseId=$c.CaseId})} 'Disabled adapter cannot launch'
Reject {Invoke-PMMMCPTool 'pmm_unreal_texture' ([pscustomobject]@{caseId=$c.CaseId;operation='configure';assetName='Safe';srgb='true'})} 'Boolean type required'
Reject {Invoke-PMMMCPTool 'pmm_unreal_texture' ([pscustomobject]@{caseId=$c.CaseId;operation='duplicate';assetName='../escape';templateId='Safe'})} 'Asset name traversal rejected'
Reject {Invoke-PMMMCPTool 'pmm_unreal_texture' ([pscustomobject]@{caseId=$c.CaseId;operation='configure';assetName='Safe';srgb=$true;script='anything'})} 'No arbitrary scripts'
$engine=Join-Path $Script:Root 'FakeEngine'
[void][IO.Directory]::CreateDirectory((Join-Path $engine 'Engine\Build'))
[void][IO.Directory]::CreateDirectory((Join-Path $engine 'Engine\Binaries\Win64'))
[IO.File]::WriteAllText((Join-Path $engine 'Engine\Binaries\Win64\UnrealEditor-Cmd.exe'),'not executable')
Write-PMMUnrealJson (Join-Path $engine 'Engine\Build\Build.version') @{MajorVersion=5;MinorVersion=8;PatchVersion=0}
$cfg=Get-PMMUnrealSettings;$cfg.engineRoot=$engine;$cfg.enabled=$true;Save-PMMUnrealSettings $cfg
$envInfo=Get-PMMUnrealEnvironment
Assert ($envInfo.installed -and -not $envInfo.compatible) 'Wrong engine version detected (synthetic engine)'
Write-PMMUnrealJson (Join-Path $engine 'Engine\Build\Build.version') @{MajorVersion=5;MinorVersion=1;PatchVersion=1}
$envInfo=Get-PMMUnrealEnvironment
Assert ($envInfo.compatible -and -not $envInfo.readyToPrepare) 'Matching engine version does not bypass missing dependencies'
Reject {Start-PMMUnrealJob 'prepare' ([pscustomobject]@{caseId=$c.CaseId})} 'Missing prerequisites block launch'
$bad=Join-Path $Script:Root 'unsigned.msi';[IO.File]::WriteAllText($bad,'not a signed installer')
Reject {Assert-PMMEpicInstaller $bad} 'Unsigned installer rejected'
function Get-AuthenticodeSignature($LiteralPath){return @{Status='Valid';SignerCertificate=@{Subject='CN=Unrelated Publisher, O=Unrelated Publisher'}}}
Reject {Assert-PMMEpicInstaller $bad} 'Wrong signer rejected (policy fixture)'
function Get-AuthenticodeSignature($LiteralPath){return @{Status='Valid';SignerCertificate=@{Subject='CN="Epic Games, Inc.", O="Epic Games, Inc.", C=US'}}}
Assert ((Assert-PMMEpicInstaller $bad) -eq $bad) 'Expected signer accepted by policy fixture; installer not executed'
Remove-Item Function:\Get-AuthenticodeSignature
$procDir=Join-Path $Script:Root 'ProcessTest';[void][IO.Directory]::CreateDirectory($procDir)
$fail=Join-Path $procDir 'fail.ps1';[IO.File]::WriteAllText($fail,'exit 7')
$ps=Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
Reject {Invoke-PMMBoundedProcess $ps @('-NoProfile','-File',$fail) $procDir 5} 'Failed external tool not reported successful'
$sleep=Join-Path $procDir 'wait.ps1';[IO.File]::WriteAllText($sleep,'Start-Sleep -Seconds 30')
Reject {Invoke-PMMBoundedProcess $ps @('-NoProfile','-File',$sleep) $procDir 1} 'Timeout stops worker process'
$cancel=Join-Path $procDir 'cancel';[IO.File]::WriteAllText($cancel,'cancel')
Reject {Invoke-PMMBoundedProcess $ps @('-NoProfile','-File',$sleep) $procDir 5 $cancel} 'Cancellation stops worker process'
$other=New-PMMAIIOCase -Title 'Other'
$jobId=[guid]::NewGuid().ToString('N');$job=Join-Path (Get-PMMUnrealRoot) ('Jobs\'+$jobId)
Write-PMMAIIOJsonAtomic (Join-Path $job 'request.json') @{caseId=$c.CaseId;jobId=$jobId;operation='cook'} 5
Write-PMMAIIOJsonAtomic (Join-Path $job 'status.json') @{status='FAILED';verified=$false;message='fixture tool failure'} 5
Reject {Get-PMMUnrealJobPath $other.CaseId $jobId} 'Job isolation by case'
Assert ((Get-PMMUnrealJob ([pscustomobject]@{caseId=$c.CaseId;jobId=$jobId})).status -eq 'FAILED') 'Job failure is retained'
Add-Type -AssemblyName System.IO.Compression.FileSystem,System.IO.Compression
$zip=Join-Path $Script:Root 'traversal.zip'
$archive=[IO.Compression.ZipFile]::Open($zip,[IO.Compression.ZipArchiveMode]::Create)
[void]$archive.CreateEntry('PalworldModdingKit-'+(Get-PMMUnrealProfile).kitCommit+'/../../outside')
$archive.Dispose()
Reject {Expand-PMMUnrealKit $zip (Join-Path $Script:Root 'Extract')} 'Traversal archive rejected'
Assert (-not(Test-Path (Join-Path $Script:Root 'outside'))) 'Archive wrote no escaped file'
"UNREAL_REGRESSION_OK: $count checks; no Unreal execution claimed."
