function Set-PMMMCPClient([bool]$Enabled) {
    $path=Resolve-PMMMCPPath (Get-PMMMCPRoot) 'client.json'
    $executable=''
    if($Enabled){
        $command=Get-Command codex.exe -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
        if(-not $command){throw 'Codex CLI is not installed or is not on PATH. Install/sign in to Codex first.'}
        $executable=$command.Source
    }
    Write-PMMAIIOJsonAtomic $path @{schema='PMM_MCP_CLIENT_V1';enabled=$Enabled;executable=$executable} 5
}
function Get-PMMMCPClient {
    $path=Resolve-PMMMCPPath (Get-PMMMCPRoot) 'client.json'
    if(-not(Test-Path -LiteralPath $path)){return $null}
    $client=Read-PMMMCPJson $path
    if(-not $client.enabled){return $null}
    if($client.schema -ne 'PMM_MCP_CLIENT_V1' -or [IO.Path]::GetFileName($client.executable) -ine 'codex.exe' -or -not(Test-Path -LiteralPath $client.executable -PathType Leaf)){throw 'Local Codex configuration is invalid. Reconnect it in AI Settings.'}
    return $client
}
function ConvertTo-PMMMCPNativeArgument([string]$Value) {
    # Windows CommandLineToArgvW quoting, including backslashes before quotes/end.
    $escaped=[regex]::Replace($Value,'(\\*)"', '$1$1\"')
    $escaped=[regex]::Replace($escaped,'(\\+)$','$1$1')
    return ('"'+$escaped+'"')
}
function Invoke-PMMMCPClient([string]$CaseId) {
    if(-not(Get-PMMMCPClient)){return 'Available via MCP. Waiting for a connected AI to read the case.'}
    $options=New-PMMDeepAnalysisOptions;$options.AutomaticSolution=$true
    $session=New-PMMRepairSession $CaseId $options
    Start-PMMRepairAgentJob $session.Id|Out-Null
    return ('Persistent GPTD session started: '+$session.Id)
}
