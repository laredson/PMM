param([string]$Repository=([IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))))
Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
$app=Join-Path $Repository 'PMM'
$Script:Root=Join-Path $Repository ('Development\TestResults\MCP-Transport-'+[guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($Script:Root)
Copy-Item -LiteralPath (Join-Path $app 'Modules') -Destination (Join-Path $Script:Root 'Modules') -Recurse
. (Join-Path $Script:Root 'Modules\Shared\Paths.ps1')
Initialize-PMMPaths $Script:Root | Out-Null
. (Join-Path $Script:Root 'Modules\AIIO\AIIO.SessionService.ps1')
. (Join-Path $Script:Root 'Modules\AIIO\AIIO.CaseWorkspaceService.ps1')
. (Join-Path $Script:Root 'Modules\MCP\MCP.Service.ps1')
$script:assertions=0
function Assert([bool]$Test,[string]$Message){if(-not $Test){throw $Message};$script:assertions++;Write-Output ('PASS: '+$Message)}
Assert ((Normalize-PMMAIIOCaseTransport 'mcp') -ceq 'MCP') 'MCP normalization'
$c=New-PMMAIIOCase -Title 'Transport test' -Description 'A request, not an instruction to execute this test.' -Type NEW_MOD -Transport MCP
$blocked=$false;try{New-PMMAIIOCaseHandoff $c.CaseId | Out-Null}catch{$blocked=$true}
Assert $blocked 'Disabled MCP fails without ZIP fallback'
Set-PMMMCPEnabled $true
$r=New-PMMAIIOCaseHandoff $c.CaseId
Assert ($r.Transport -eq 'MCP' -and $r.ZipPath -eq '') 'MCP publishes without a ZIP'
$c=Get-PMMAIIOCase $c.CaseId
Assert ($c.Status -eq 'AVAILABLE_VIA_MCP' -and $c.NextAction -eq 'WAIT_FOR_MCP') 'Available status does not claim delivery'
$step=$c.CurrentStep
$r2=New-PMMAIIOCaseHandoff $c.CaseId
Assert ($r.RequestId -eq $r2.RequestId -and (Get-PMMAIIOCase $c.CaseId).CurrentStep -eq $step) 'Republishing unchanged request is idempotent'
$blocked=$false;try{New-PMMAIIOCaseHandoff $c.CaseId 1 | Out-Null}catch{$blocked=$true}
Assert $blocked 'Historical request cannot silently replace current goal'
$wire=@(
    (@{jsonrpc='2.0';id=1;method='initialize';params=@{protocolVersion='2025-11-25';capabilities=@{};clientInfo=@{name='transport-test';version='1'}}} | ConvertTo-Json -Depth 10 -Compress),
    '{"jsonrpc":"2.0","method":"notifications/initialized"}',
    (@{jsonrpc='2.0';id=2;method='tools/call';params=@{name='pmm_case_get';arguments=@{caseId=$c.CaseId}}} | ConvertTo-Json -Depth 10 -Compress)
)
$responses=@($wire | & $env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File (Join-Path $app 'Modules\MCP\Start-PMMMCP.ps1') -Root $Script:Root)
if($LASTEXITCODE){throw 'MCP process failed'}
$response=$responses[-1] | ConvertFrom-Json
if($response.result.isError){throw $response.result.content[0].text}
$data=$response.result.content[0].text | ConvertFrom-Json
Assert ($data.mcpRequest.requestId -eq $r.RequestId -and $data.description -eq $c.Description) 'Published request read over real MCP'
$c.Description='Edited goal'
Save-PMMAIIOCase $c | Out-Null
Assert ($null -eq (ConvertTo-PMMMCPCase $c).mcpRequest) 'Even unsnapshotted edits invalidate old publication'
$c.NextAction='CREATE_HANDOFF'
Add-PMMAIIOCaseStep $c 'CASE_EDITED' 'Edited goal' 'CREATE_HANDOFF' @() $null | Out-Null
$r3=New-PMMAIIOCaseHandoff $c.CaseId
Assert ($r3.RequestId -ne $r.RequestId) 'Edited goal gets a fresh request'
$manual=New-PMMAIIOCase -Title 'Manual' -Transport MANUAL_ZIP
$zip=New-PMMAIIOCaseHandoff $manual.CaseId
Assert (Test-Path -LiteralPath $zip.ZipPath -PathType Leaf) 'Manual ZIP still works'
foreach($mode in @('HANDOFF','AUTO')){
    $workerCase=New-PMMAIIOCase -Title ('Worker '+$mode) -Transport MCP
    & $env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File (Join-Path $app 'Modules\AIIO\AIIO.CaseWorker.ps1') -Root $Script:Root -CaseId $workerCase.CaseId -Mode $mode
    $result=Get-Content (Join-Path (Get-PMMAIIOCasePath $workerCase.CaseId) 'worker-result.json') -Raw | ConvertFrom-Json
    Assert ($LASTEXITCODE -eq 0 -and $result.Status -eq 'Complete' -and $result.ZipPath -eq '' -and $result.Message -match 'MCP') ('Background '+$mode+' publishes without ZIP')
}
Assert (@(Get-ChildItem (Get-PMMAIIOCasePath $c.CaseId) -Recurse -Filter *.zip).Count -eq 0) 'No ZIP created for MCP case'
Add-Type -AssemblyName PresentationFramework,PresentationCore,WindowsBase
. (Join-Path $Script:Root 'Modules\AIIO\AIIO.CaseWorkspace.UI.ps1')
$combo=[Windows.Controls.ComboBox]::new()
$combo.ItemsSource=@([pscustomobject]@{Value='MCP'},[pscustomobject]@{Value='MANUAL_ZIP'})
$combo.SelectedValuePath='Value'
$button=[Windows.Controls.Button]::new()
$Script:PMMAIIOCaseUI=@{CmbTransport=$combo;BtnHandoff=$button}
$combo.SelectedValue='MCP';Update-PMMAIIOTransportButton
Assert ($button.Content -eq 'Publish to MCP') 'MCP button wording'
$combo.SelectedValue='MANUAL_ZIP';Update-PMMAIIOTransportButton
Assert ($button.Content -eq 'Create handoff') 'Manual button wording'
Write-Output ("MCP_TRANSPORT_OK: {0} assertions" -f $script:assertions)

