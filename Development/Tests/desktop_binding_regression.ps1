param([string]$Repository=([IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))))
Set-StrictMode -Version 2.0;$ErrorActionPreference='Stop'
$app=Join-Path $Repository 'PMM'
$Script:Root=Join-Path $Repository ('Development\TestResults\Desktop binding '+[guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($Script:Root)
Copy-Item (Join-Path $app 'Modules') (Join-Path $Script:Root 'Modules') -Recurse
foreach($module in @('Shared\Paths.ps1','AIIO\AIIO.SessionService.ps1','AIIO\AIIO.CaseWorkspaceService.ps1','MCP\MCP.Service.ps1','MCP\MCP.Client.ps1')){. (Join-Path $Script:Root ('Modules\'+$module))}
Initialize-PMMPaths $Script:Root|Out-Null
function L($en,$es){return $en}
$script:checks=0
function Assert($ok,$message){if(-not $ok){throw $message};$script:checks++;"PASS: $message"}
function Reject($work,$message){$failed=$false;try{& $work|Out-Null}catch{$failed=$true};Assert $failed $message}
$case=New-PMMAIIOCase -Title 'Desktop fixture' -Transport MCP
Assert ((Get-PMMCaseClient $case) -eq 'EXTERNAL') 'Legacy case stays external without configured runner'
$b=New-PMMDesktopBinding
Reject {Invoke-PMMMCPTool 'pmm_desktop_pair' ([pscustomobject]@{nonce='wrong'})} 'Wrong pairing code rejected'
$b.expiresUtc=[DateTime]::UtcNow.AddMinutes(-1).ToString('o');Write-PMMAIIOJsonAtomic (Get-PMMDesktopFile) $b 6
Reject {Invoke-PMMMCPTool 'pmm_desktop_pair' ([pscustomobject]@{nonce=$b.nonce})} 'Expired pairing rejected'
$b=New-PMMDesktopBinding
$Script:PMMMCPScopeCase=$case.CaseId
Reject {Invoke-PMMMCPTool 'pmm_desktop_pair' ([pscustomobject]@{nonce=$b.nonce})} 'Case-scoped pairing rejected'
$Script:PMMMCPScopeCase=''
$wire=@(
    (@{jsonrpc='2.0';id=1;method='initialize';params=@{protocolVersion='2025-11-25';capabilities=@{};clientInfo=@{name='pairing-test';version='1'}}}|ConvertTo-Json -Depth 8 -Compress),
    '{"jsonrpc":"2.0","method":"notifications/initialized"}',
    (@{jsonrpc='2.0';id=2;method='tools/call';params=@{name='pmm_desktop_pair';arguments=@{nonce=$b.nonce}}}|ConvertTo-Json -Depth 8 -Compress)
)
$rpc=@($wire| & $env:WINDIR\System32\WindowsPowerShell\v1.0\powershell.exe -NoProfile -NonInteractive -File (Join-Path $Script:Root 'Modules\MCP\Start-PMMMCP.ps1') -Root $Script:Root)
if($LASTEXITCODE){throw 'Pairing server failed'}
$response=$rpc[-1]|ConvertFrom-Json
if($response.result.isError){throw $response.result.content[0].text}
$r=$response.result.content[0].text|ConvertFrom-Json
Assert ($r.status -eq 'CONNECTION_VERIFIED' -and (Get-PMMDesktopBinding).verifiedUtc) 'Installation pairing persisted'
Reject {Invoke-PMMMCPTool 'pmm_desktop_pair' ([pscustomobject]@{nonce=$b.nonce})} 'Pairing code cannot be replayed'
Assert ((Get-PMMCaseClient (Get-PMMMCPCase $case.CaseId)) -eq 'EXTERNAL') 'Pairing does not change existing case destination'
$bindingCopy=Get-PMMDesktopFile
$savedRoot=$Script:Root;$Script:Root=Join-Path $Script:Root 'moved'
[void][IO.Directory]::CreateDirectory((Split-Path (Get-PMMDesktopFile) -Parent));Copy-Item -LiteralPath $bindingCopy -Destination (Get-PMMDesktopFile)
Assert ($null -eq (Get-PMMDesktopBinding)) 'Different installation is not implicitly paired'
$Script:Root=$savedRoot
$link=New-PMMDesktopLink 'Plan +100 & preserve "items"'
Assert ($link -match 'path=.*%20' -and $link -match '%2B100%20%26') 'Workspace and prompt URI-encoded'
Reject {New-PMMDesktopLink '' '../other'} 'Malformed thread link rejected'
# Mock only desktop side effects. Real PMM publication and persistence stay active.
function Save-PMMAIIOCaseEditor{return $false}
$Script:PMMAIIOCaseSelectedId=$case.CaseId
function Get-PMMAIIOSelectedCase{return (Get-PMMMCPCase $Script:PMMAIIOCaseSelectedId)}
function Refresh-PMMAIIOCaseList($id){}
function Set-PMMAIIOCaseUiStatus($message){}
$Script:opened=0;$Script:helpers=0;$Script:setup=0;$Script:installed=$true;$Script:started=0
function Get-PMMChatGPTDesktop{if($Script:installed){return [pscustomobject]@{InstallLocation='C:\synthetic desktop';SupportsLocalChats=$true}};return $null}
function Open-PMMDesktopLink($link){$Script:opened++;return $true}
function Show-PMMDesktopDispatchHelp($Dispatch,$CanOpen){$Script:helpers++}
function Show-PMMDesktopSetup{$Script:setup++}
function Start-Process {param($FilePath,$ArgumentList,$WindowStyle);$Script:started++}
Show-PMMChatGPTCase
$d=Get-PMMDesktopDispatch $case.CaseId
Assert ($Script:opened -eq 1 -and $Script:started -eq 1 -and $d.phase -eq 'PREPARED') 'First send opens one chat and one verification worker'
Show-PMMChatGPTCase
Assert ($Script:opened -eq 1 -and $Script:helpers -eq 1) 'Repeated send does not duplicate a chat'
$case=Get-PMMMCPCase $case.CaseId
Assert ((Get-PMMCaseClient $case) -eq 'CHATGPT' -and $case.Transport -eq 'MCP') 'Destination separate from MCP transport'
Assert ((Invoke-PMMMCPClient $case.CaseId) -match 'Desktop' -and $Script:started -eq 1) 'Desktop never starts Codex CLI'
Assert ((Get-PMMDesktopCaseStatus $case) -match 'prepared') 'Opening is not receipt or research'
$lease=Invoke-PMMMCPTool 'pmm_request_claim' ([pscustomobject]@{caseId=$case.CaseId;requestId=$d.requestId})
Reject {Show-PMMChatGPTCase} 'Busy unknown chat never starts another client'
$a=[pscustomobject]@{caseId=$case.CaseId;requestId=$d.requestId;token='wrong';phase='RESEARCHING';threadId='11111111-1111-1111-1111-111111111111'}
Reject {Invoke-PMMMCPTool 'pmm_desktop_case_link' $a} 'Thread association requires request lease'
$a.token=$lease.token
[void](Invoke-PMMMCPTool 'pmm_desktop_case_link' $a)
Assert ((Get-PMMDesktopCaseStatus $case) -match 'investigating') 'Research status requires MCP signal'
$a.phase='AWAITING_APPROVAL';[void](Invoke-PMMMCPTool 'pmm_desktop_case_link' $a)
Assert ((Get-PMMDesktopCaseStatus $case) -match 'approval') 'Plan approval status is distinct'
Show-PMMChatGPTCase
Assert ($Script:opened -eq 2 -and $Script:started -eq 1) 'Known active thread reopens without another worker'
[void](Invoke-PMMMCPTool 'pmm_request_complete' ([pscustomobject]@{caseId=$case.CaseId;requestId=$d.requestId;token=$lease.token;message='Plan ready';response='Synthetic result';status='NEEDS_INPUT'}))
Assert ((Get-PMMDesktopCaseStatus $case) -match 'NEEDS_INPUT') 'Terminal result overrides stale research status'
# A real lock denies another operation before acquisition.
$lock=[IO.File]::Open(((Get-PMMMCPExchangePath $d.requestId)+'.lock'),[IO.FileMode]::OpenOrCreate,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)
try{Reject {Invoke-PMMMCPTool 'pmm_request_claim' ([pscustomobject]@{caseId=$case.CaseId;requestId=$d.requestId})} 'Concurrent exchange lock honored'}finally{$lock.Dispose()}
Cancel-PMMDesktopDispatch $case.CaseId
Assert ((Get-PMMDesktopCaseStatus $case) -match 'cancelled') 'Cancellation shown independently of chat state'
Reject {Show-PMMChatGPTCase} 'Cancelled request does not reopen or restart'
Set-PMMMCPEnabled $false
Show-PMMChatGPTCase
Assert ($Script:setup -eq 1) 'Disabled connection returns to setup'
Set-PMMMCPEnabled $true
$Script:installed=$false
Add-Type -AssemblyName PresentationFramework
function Show-PMMThemedMessage($args){return [Windows.MessageBoxResult]::No}
Show-PMMChatGPTCase
Assert ($Script:started -eq 1) 'Declined missing-app install starts nothing'
function Show-PMMThemedMessage($args){return [Windows.MessageBoxResult]::Yes}
$Script:installRequests=0
function Request-PMMDependencyInstall($component,$caseId){if($component -ne 'chatgpt'){throw 'Wrong component'};$Script:installRequests++}
function Open-PMMSettings($id){}
Show-PMMChatGPTCase
Assert ($Script:installRequests -eq 1 -and $Script:started -eq 1) 'Missing app uses installation consent service only'
"DESKTOP_BINDING_OK: $Script:checks checks; no real installers or chat messages."
