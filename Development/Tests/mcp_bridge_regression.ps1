param([string]$Repository=([IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))))
Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
$app=Join-Path $Repository 'PMM'
$fixture=Join-Path $Repository ('Development\TestResults\MCP-'+[guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($fixture)
[void][IO.Directory]::CreateDirectory((Join-Path $fixture 'Modules'))
Copy-Item (Join-Path $app 'Modules\*') (Join-Path $fixture 'Modules') -Recurse -Force
[void][IO.Directory]::CreateDirectory((Join-Path $fixture 'Resources\Unreal'))
Copy-Item (Join-Path $app 'Resources\Unreal\profile.json') (Join-Path $fixture 'Resources\Unreal\profile.json')

foreach($module in @('Shared\Paths.ps1','Shared\Common.ps1','GameReference\GameReferenceService.ps1','AIIO\AIIO.SessionService.ps1','AIIO\AIIO.ModCreationService.ps1','AIIO\AIIO.CaseWorkspaceService.ps1','MCP\MCP.Reference.ps1','MCP\MCP.Exchange.ps1','MCP\MCP.Service.ps1','MCP\Export-PMMMCPConfig.ps1')){
    $dest=Join-Path $fixture ('Modules\'+$module)
    [void][IO.Directory]::CreateDirectory((Split-Path $dest -Parent))
    Copy-Item -LiteralPath (Join-Path $app ('Modules\'+$module)) -Destination $dest
}
& (Join-Path $fixture 'Modules\MCP\Export-PMMMCPConfig.ps1') -Root $fixture -Enable | Out-Null
$info=[Diagnostics.ProcessStartInfo]::new()
$info.FileName=Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
$info.Arguments='-NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "'+(Join-Path $app 'Modules\MCP\Start-PMMMCP.ps1')+'" -Root "'+$fixture+'"'
$info.UseShellExecute=$false;$info.CreateNoWindow=$true
$info.RedirectStandardInput=$true;$info.RedirectStandardOutput=$true;$info.RedirectStandardError=$true
$info.StandardOutputEncoding=[Text.UTF8Encoding]::new($false)
$info.StandardErrorEncoding=[Text.UTF8Encoding]::new($false)
$process=[Diagnostics.Process]::Start($info)
$writer=[IO.StreamWriter]::new($process.StandardInput.BaseStream,[Text.UTF8Encoding]::new($false))
$stderr=$process.StandardError.ReadToEndAsync()
$script:count=0;$script:id=0
function Assert([bool]$Condition,[string]$Message){
    if(-not $Condition){throw ('FAIL: '+$Message)}
    $script:count++;Write-Output ('PASS: '+$Message)
}
function Send($Message){$writer.WriteLine(($Message | ConvertTo-Json -Depth 12 -Compress));$writer.Flush()}
function Receive {
    $read=$process.StandardOutput.ReadLineAsync()
    if(-not $read.Wait(15000)){throw 'MCP response timed out.'}
    if($null -eq $read.Result){throw ('MCP exited: '+$stderr.Result)}
    return ($read.Result | ConvertFrom-Json)
}
function Request([string]$Method,$Params){
    $script:id++;Send @{jsonrpc='2.0';id=$script:id;method=$Method;params=$Params}
    $result=Receive
    if($result.id -ne $script:id){throw ('Response ID mismatch: '+($result | ConvertTo-Json -Depth 6 -Compress))}
    return $result
}
function Call([string]$Name,$Arguments=@{}){
    $response=Request 'tools/call' @{name=$Name;arguments=$Arguments}
    if($response.PSObject.Properties.Name -contains 'error'){throw $response.error.message}
    return $response.result
}
function Get-ResultData($Result){
    if($Result.isError){throw $Result.content[0].text}
    return ($Result.content[0].text | ConvertFrom-Json)
}
try{
    $early=Request 'tools/list' @{}
    Assert ($early.error.code -eq -32602) 'Initialization is required'
    $hello=Request 'initialize' @{protocolVersion='2025-11-25';capabilities=@{};clientInfo=@{name='PMM regression';version='1'}}
    Assert ($hello.result.protocolVersion -eq '2025-11-25') 'MCP handshake'
    Send @{jsonrpc='2.0';method='notifications/initialized'}
    $catalog=Request 'tools/list' @{}
    Assert ($catalog.result.tools.Count -eq 34 -and $catalog.result.tools.name -contains 'pmm_connection_check') 'Thirty-four declared bounded tools including Desktop pairing'
    $empty=Get-ResultData (Call 'pmm_cases_list')
    Assert ($empty.cases -is [array] -and $empty.cases.Count -eq 0) 'Zero cases remains an array'
    $case=Get-ResultData (Call 'pmm_case_create' @{title='MCP test';description='Compatibility request';type='COMPATIBILITY'})
    Assert ($case.caseId -match '^AICASE-' -and $case.status -eq 'DRAFT') 'Creates an inactive real AIIO case'
    $one=Get-ResultData (Call 'pmm_cases_list')
    Assert ($one.cases -is [array] -and $one.cases.Count -eq 1) 'One case remains an array'
    [void](Get-ResultData (Call 'pmm_case_create' @{title='Second';description='New mod request';type='NEW_MOD'}))
    $many=Get-ResultData (Call 'pmm_cases_list')
    Assert ($many.cases.Count -eq 2) 'Multiple cases'
    $payload=[Text.Encoding]::UTF8.GetBytes('proposal: no execution')
    $artifact=Get-ResultData (Call 'pmm_artifact_put' @{caseId=$case.caseId;extension='.txt';base64=[Convert]::ToBase64String($payload)})
    $read=Get-ResultData (Call 'pmm_artifact_read' @{caseId=$case.caseId;artifactId=$artifact.artifactId})
    Assert ($read.eof -and [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($read.base64)) -eq 'proposal: no execution') 'Artifact byte round-trip'
    $large=New-Object byte[] 70000
    $chunked=Get-ResultData (Call 'pmm_artifact_put' @{caseId=$case.caseId;extension='.ubulk';base64=[Convert]::ToBase64String($large)})
    $chunk=Get-ResultData (Call 'pmm_artifact_read' @{caseId=$case.caseId;artifactId=$chunked.artifactId})
    Assert (-not $chunk.eof -and $chunk.nextOffset -eq 65536) 'Bounded chunk reads'
    $chunk=Get-ResultData (Call 'pmm_artifact_read' @{caseId=$case.caseId;artifactId=$chunked.artifactId;offset=65536})
    Assert ($chunk.eof -and $chunk.totalBytes -eq 70000) 'Chunk completion'
    foreach($attack in @(
        @('pmm_case_get',@{caseId='..\..\State\config.json'}),
        @('pmm_artifact_read',@{caseId=$case.caseId;artifactId='C:\Windows\win.ini'}),
        @('pmm_artifact_put',@{caseId=$case.caseId;extension='.ps1';base64='YQ=='}),
        @('pmm_artifact_put',@{caseId=$case.caseId;extension='.txt';base64='not base64'}),
        @('pmm_artifact_read',@{caseId=$case.caseId;artifactId=$artifact.artifactId;offset=-1}),
        @('pmm_artifact_read',@{caseId=$case.caseId;artifactId=$artifact.artifactId;offset=0.5}),
        @('pmm_status',@{command='whoami'}),
        @('pmm_deploy',@{}),
        @('pmm_case_create',@{title='x';description='x';type='INVALID'})
    )){
        Assert ((Call $attack[0] $attack[1]).isError) ('Rejects hostile/unsupported request: '+$attack[0])
    }
    Assert ((Call 'pmm_reference_search' @{query='Technology'}).isError) 'Missing reference fails closed'
    $writer.WriteLine('{invalid');$writer.Flush()
    Assert ((Receive).error.code -eq -32700) 'Malformed JSON recovers'
    $unknown=Request 'not/a/method' @{}
    Assert ($unknown.error.code -eq -32601) 'Unknown RPC method'
    & (Join-Path $fixture 'Modules\MCP\Export-PMMMCPConfig.ps1') -Root $fixture -Disable | Out-Null
    Assert ((Call 'pmm_status').isError) 'Disable revokes an existing connection'
    $writer.Close()
    Assert ($process.WaitForExit(15000) -and $process.ExitCode -eq 0) 'Clean EOF and process exit'
    Assert ([string]::IsNullOrWhiteSpace($stderr.Result)) 'Protocol produces no startup errors'
    # Direct boundary tests against real filesystem junctions and reference hash checks.
    $Script:Root=$fixture
    . (Join-Path $app 'Modules\MCP\MCP.Service.ps1')
    . (Join-Path $app 'Modules\AIIO\AIIO.SessionService.ps1')
    . (Join-Path $app 'Modules\AIIO\AIIO.CaseWorkspaceService.ps1')
    Set-PMMMCPEnabled $true
    foreach($relative in @('..\outside','x:stream','CON.txt','folder\..\x','x.','\\server\share')){
        $rejected=$false;try{[void](Resolve-PMMMCPPath $fixture $relative)}catch{$rejected=$true}
        Assert $rejected ('Path guard: '+$relative)
    }
    $outside=Join-Path $Repository ('Development\TestResults\Outside-'+[guid]::NewGuid().ToString('N'))
    [void][IO.Directory]::CreateDirectory($outside)
    $link=Join-Path $fixture 'junction'
    New-Item -ItemType Junction -Path $link -Target $outside | Out-Null
    $rejected=$false;try{[void](Resolve-PMMMCPPath $fixture 'junction\payload.txt')}catch{$rejected=$true}
    Assert $rejected 'Junction escape rejected'
    # Fixture reference: export real bytes, then mutate them to test stale-evidence rejection.
    $cooked=Join-Path $fixture 'Workspace\GameReference\current\cooked'
    [void][IO.Directory]::CreateDirectory((Join-Path $cooked 'Pal\Content'))
    $asset=Join-Path $cooked 'Pal\Content\Test.uasset'
    [IO.File]::WriteAllBytes($asset,[byte[]]@(1,2,3))
    $script:families=@([pscustomobject]@{Asset='Pal/Content/Test.uasset';Parts=@([pscustomobject]@{RelativePath='Pal/Content/Test.uasset';Size=3;Sha256=(Get-FileHash $asset).Hash.ToLowerInvariant()})})
    function Get-PMMMCPReferenceFamilies {return $script:families}
    $export=Invoke-PMMMCPTool 'pmm_reference_export' ([pscustomobject]@{caseId=$case.caseId;logicalPath='Pal/Content/Test.uasset'})
    Assert ($export.artifacts.Count -eq 1 -and $export.artifacts[0].sha256 -eq $script:families[0].Parts[0].Sha256) 'Hash-bound family export'
    [IO.File]::WriteAllBytes($asset,[byte[]]@(3,2,1))
    $rejected=$false;try{Invoke-PMMMCPTool 'pmm_reference_export' ([pscustomobject]@{caseId=$case.caseId;logicalPath='Pal/Content/Test.uasset'}) | Out-Null}catch{$rejected=$true}
    Assert $rejected 'Changed Vanilla bytes rejected'
    $dir=Get-PMMMCPArtifactDir $case.caseId
    $existing=@(Get-ChildItem -LiteralPath $dir -File).Count
    for($i=$existing;$i -lt 256;$i++){[IO.File]::WriteAllBytes((Join-Path $dir ([guid]::NewGuid().ToString('N')+'.txt')),[byte[]]@())}
    $rejected=$false;try{Invoke-PMMMCPTool 'pmm_artifact_put' ([pscustomobject]@{caseId=$case.caseId;extension='.txt';base64='YQ=='}) | Out-Null}catch{$rejected=$true}
    Assert $rejected 'Artifact count quota enforced'
    $audit=Get-Content (Join-Path (Get-PMMMCPRoot) 'audit.jsonl') -Raw
    Assert (-not $audit.Contains('proposal:') -and $audit.Contains('STARTED')) 'Audit excludes file payloads'
    Write-Output ("PASS: {0} assertions. Fixture: {1}" -f $script:count,$fixture)
}finally{
    if(-not $process.HasExited){$process.Kill()}
    $process.Dispose()
}

