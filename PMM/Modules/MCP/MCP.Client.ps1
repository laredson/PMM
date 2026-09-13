function Set-PMMMCPClient([bool]$Enabled) {
    $path=Resolve-PMMMCPPath (Get-PMMMCPRoot) 'client.json'
    $executable=''
    if($Enabled){
        $command=Get-PMMCodexRuntime
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
    $session=Get-OrCreate-PMMCaseRepairSession $CaseId $options
    Start-PMMRepairAgentJob $session.Id|Out-Null
    return ('Persistent GPTD session started: '+$session.Id)
}


function Get-PMMCodexRuntime {
    # Explorer-launched PMM does not inherit Codex's task-only PATH.
    $configured=Join-Path (Get-PMMMCPRoot) 'client.json'
    if(Test-Path -LiteralPath $configured){
        $client=Read-PMMMCPJson $configured
        $path=[string](Get-PMMCaseValue $client executable '')
        if($path -and [IO.Path]::GetFileName($path) -ieq 'codex.exe' -and [IO.File]::Exists($path)){
            return [pscustomobject]@{Source=[IO.Path]::GetFullPath($path);Discovery='Configured'}
        }
    }
    $command=Get-Command codex.exe -CommandType Application -ErrorAction SilentlyContinue|Select-Object -First 1
    if($command){return [pscustomobject]@{Source=$command.Source;Discovery='PATH'}}
    $local=[Environment]::GetFolderPath('LocalApplicationData')
    if($local){
        $bin=Join-Path $local 'OpenAI/Codex/bin'
        if(Test-Path -LiteralPath $bin -PathType Container){
            $candidates=@(Get-ChildItem -LiteralPath $bin -Directory -ErrorAction SilentlyContinue|ForEach-Object{
                $candidate=Join-Path $_.FullName 'codex.exe'
                if([IO.File]::Exists($candidate)){Get-Item -LiteralPath $candidate}
            }|Sort-Object LastWriteTimeUtc -Descending)
            if($candidates.Count){return [pscustomobject]@{Source=$candidates[0].FullName;Discovery='Desktop runtime'}}
        }
    }
    throw 'Codex runtime was not found in the configured location, PATH or desktop installation. Install/update Codex Desktop or select its codex.exe in the connection settings.'
}
