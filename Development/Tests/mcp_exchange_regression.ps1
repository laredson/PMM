param([string]$Repository=([IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))))
Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
$app=Join-Path $Repository 'PMM'
$Script:Root=Join-Path $Repository ('Development\TestResults\MCP-Exchange-'+[guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($Script:Root)
Copy-Item (Join-Path $app 'Modules') (Join-Path $Script:Root 'Modules') -Recurse
. (Join-Path $Script:Root 'Modules\Shared\Paths.ps1')
Initialize-PMMPaths $Script:Root | Out-Null
. (Join-Path $Script:Root 'Modules\AIIO\AIIO.SessionService.ps1')
. (Join-Path $Script:Root 'Modules\AIIO\AIIO.CaseWorkspaceService.ps1')
. (Join-Path $Script:Root 'Modules\MCP\MCP.Service.ps1')
Set-PMMMCPEnabled $true
$script:count=0
function Assert($ok,$message){if(-not $ok){throw $message};$script:count++;"PASS: $message"}
function Reject($action,$message){$blocked=$false;try{& $action | Out-Null}catch{$blocked=$true};Assert $blocked $message}
$c=New-PMMAIIOCase -Title 'Exchange fixture' -Description 'Synthetic test' -Transport MCP
$r=New-PMMAIIOCaseHandoff $c.CaseId
$a=[pscustomobject]@{caseId=$c.CaseId;requestId=$r.RequestId}
$lease=Invoke-PMMMCPTool 'pmm_request_claim' $a
Assert ($lease.token.Length -eq 32) 'Claim returns lease'
Reject {Invoke-PMMMCPTool 'pmm_request_claim' $a} 'Concurrent claim rejected'
$b=[pscustomobject]@{caseId=$c.CaseId;requestId=$r.RequestId;token='wrong';message='Test';response='Inert text';status='RESPONSE_RECEIVED'}
Reject {Invoke-PMMMCPTool 'pmm_request_complete' $b} 'Wrong token rejected'
$b.token=$lease.token
$wire=@(
(@{jsonrpc='2.0';id=1;method='initialize';params=@{protocolVersion='2025-11-25';capabilities=@{};clientInfo=@{name='exchange-test';version='1'}}}|ConvertTo-Json -Depth 10 -Compress),
'{"jsonrpc":"2.0","method":"notifications/initialized"}',
(@{jsonrpc='2.0';id=2;method='tools/call';params=@{name='pmm_request_complete';arguments=$b}}|ConvertTo-Json -Depth 10 -Compress)
)
$out=@($wire | & powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File (Join-Path $app 'Modules\MCP\Start-PMMMCP.ps1') -Root $Script:Root)
$result=$out[-1]|ConvertFrom-Json
Assert (-not $result.result.isError) 'Completion through real stdio MCP'
$view=ConvertTo-PMMMCPCase (Get-PMMMCPCase $c.CaseId)
Assert ($view.aiReply.response -eq 'Inert text' -and $view.aiReply.status -eq 'RESPONSE_RECEIVED') 'Response returned with case'
Assert (-not ($view.aiReply.Keys -contains 'token')) 'Lease is not exposed in case'
Reject {Invoke-PMMMCPTool 'pmm_request_complete' $b} 'Duplicate completion rejected'
Reject {Invoke-PMMMCPTool 'pmm_request_claim' $a} 'Completed request cannot rerun'
Add-Type -AssemblyName PresentationFramework,PresentationCore,WindowsBase
. (Join-Path $app 'Modules\AIIO\AIIO.CaseWorkspace.UI.ps1')
$tab=New-PMMAIIOCaseWorkspaceTab
$Script:PMMAIIOCaseSelectedId=$c.CaseId
$panel=Get-PMMAIIOCaseControl 'PnlMCPReply'
$text=Get-PMMAIIOCaseControl 'TxtMCPResponse'
$status=Get-PMMAIIOCaseControl 'TxtMCPReplyStatus'
. (Join-Path $app 'Modules\MCP\MCP.Reply.UI.ps1')
Update-PMMMCPReplyUI
Assert ($text.Text -eq 'Inert text' -and $status.Text -match 'RESPONSE_RECEIVED') 'Response displayed in WPF'
$c=Get-PMMMCPCase $c.CaseId
$c.Description='Changed'
Save-PMMAIIOCase $c | Out-Null
Assert ($null -eq (ConvertTo-PMMMCPCase $c).aiReply) 'Edited goal hides old response'
Reject {Invoke-PMMMCPTool 'pmm_request_complete' $b} 'Stale completion rejected'
$other=New-PMMAIIOCase -Title 'Other' -Transport MCP
$Script:PMMMCPScopeCase=$c.CaseId
Reject {Invoke-PMMMCPTool 'pmm_case_get' ([pscustomobject]@{caseId=$other.CaseId})} 'Scoped client cannot read another case'
Reject {Invoke-PMMMCPTool 'pmm_case_create' ([pscustomobject]@{title='x';description='x';type='NEW_MOD'})} 'Scoped client cannot create cases'
Assert ((Invoke-PMMMCPTool 'pmm_cases_list' ([pscustomobject]@{})).cases.Count -eq 1) 'Scoped listing'
$Script:PMMMCPScopeCase=''
Set-PMMMCPEnabled $false
Reject {Invoke-PMMMCPTool 'pmm_request_claim' $a} 'Disable revokes exchange'
"MCP_EXCHANGE_OK: $script:count assertions"
