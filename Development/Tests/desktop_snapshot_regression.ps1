param([string]$Repository=([IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))))
Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
$testRoot=Join-Path $Repository ('Development\TestResults\Desktop-'+[guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory((Join-Path $testRoot 'Jobs'))
function Get-PMMDependencyRoot {return $testRoot}
. (Join-Path $Repository 'PMM\Modules\Unreal\Dependencies.Snapshot.ps1')
foreach($i in 1..478){[IO.File]::WriteAllText((Join-Path $testRoot ('Jobs\'+$i+'.json')),('{"id":"'+$i+'","operation":"install","status":"COMPLETE"}'))}
[IO.File]::WriteAllText((Join-Path $testRoot 'catalog.json'),'{"components":[]}')
$watch=[Diagnostics.Stopwatch]::StartNew();$initial=Get-PMMDependencySnapshot;$watch.Stop()
if($initial){throw 'Initial call must not block for IO.'}
$deadline=[DateTime]::UtcNow.AddSeconds(15)
do{Start-Sleep -Milliseconds 50;$snapshot=Get-PMMDependencySnapshot}while(-not $snapshot -and [DateTime]::UtcNow -lt $deadline)
if(-not $snapshot -or @($snapshot.jobs).Count -ne 478){throw 'Background snapshot incomplete.'}
Stop-PMMDependencySnapshot
. (Join-Path $Repository 'PMM\Modules\MCP\ChatGPT.Desktop.ps1')
function Get-PMMMCPCase($id){if($id -ne 'fixture'){throw 'Case outside scope'};return @{CaseId=$id}}
function Get-PMMMCPRoot{return $testRoot}
function Resolve-PMMMCPPath($root,$relative){return Join-Path $root $relative}
function Read-PMMMCPJson($path){return [IO.File]::ReadAllText($path)|ConvertFrom-Json}
function Write-PMMAIIOJsonAtomic($path,$value,$depth){[IO.File]::WriteAllText($path,($value|ConvertTo-Json -Depth $depth))}
$challenge=Join-Path $testRoot 'Desktop\fixture\connection.json'
[void][IO.Directory]::CreateDirectory((Split-Path $challenge))
Write-PMMAIIOJsonAtomic $challenge @{nonce='correct';expiresUtc=[DateTime]::UtcNow.AddMinutes(5).ToString('o');verifiedUtc=''} 5
foreach($argsFixture in @(@{caseId='other';nonce='correct'},@{caseId='fixture';nonce='wrong'})){
 $rejected=$false;try{Confirm-PMMDesktopConnection $argsFixture|Out-Null}catch{$rejected=$true};if(-not $rejected){throw 'Invalid connection challenge accepted'}
}
$r=Confirm-PMMDesktopConnection @{caseId='fixture';nonce='correct'}
if($r.status -ne 'CONNECTION_VERIFIED'){throw 'Connection not confirmed'}
Write-PMMAIIOJsonAtomic $challenge @{nonce='correct';expiresUtc=[DateTime]::UtcNow.AddMinutes(-5).ToString('o');verifiedUtc=''} 5
$rejected=$false;try{Confirm-PMMDesktopConnection @{caseId='fixture';nonce='correct'}|Out-Null}catch{$rejected=$true};if(-not $rejected){throw 'Expired challenge accepted'}
'DESKTOP_SNAPSHOT_OK: 478 cached jobs, initial dispatch '+$watch.ElapsedMilliseconds+'ms; invalid case, nonce and expiry rejected. No application installed.'

function Get-AppxPackageManifest {param($Package) return [xml]'<Package><Applications><Application><Extensions><Protocol Name="codex" /></Extensions></Application></Applications></Package>'}
function Get-AppxPackage {return [pscustomobject]@{Name='OpenAI.ChatGPT-Desktop';PackageFullName='fixture-chatgpt';Publisher='CN=50BDFD77-8903-4850-9FFE-6E8522F64D5B'}}
if(-not(Get-PMMChatGPTDesktop)){throw 'Official ChatGPT identity not detected'}
function Get-AppxPackage {return [pscustomobject]@{Name='OpenAI.ChatGPT-Desktop';PackageFullName='fixture-chatgpt';Publisher='CN=untrusted'}}
if(Get-PMMChatGPTDesktop){throw 'Untrusted publisher accepted'}
'CHATGPT_IDENTITY_OK'
