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
    $target=Get-PMMMCPCase $CaseId
    if((Get-PMMCaseClient $target) -ne 'CODEX'){return 'Available via MCP. Continue in the selected Desktop or external client.'}
    $client=Get-PMMMCPClient
    if(-not $client){return 'Available via MCP. Connect local Codex in AI Settings or use an external MCP client.'}
    $case=Get-PMMMCPCase $CaseId
    $view=ConvertTo-PMMMCPCase $case
    if(-not $view.mcpRequest){throw 'Publish the current case first.'}
    $requestId=[string]$view.mcpRequest.requestId
    if($view.aiReply -and $view.aiReply.status -in @('RESPONSE_RECEIVED','NEEDS_INPUT','BLOCKED','CANDIDATE_BUILT')){return $view.aiReply.message}
    $lease=Invoke-PMMMCPTool 'pmm_request_claim' ([pscustomobject]@{caseId=$CaseId;requestId=$requestId})
    $proc=$null
    try{
        $job=Resolve-PMMMCPPath (Get-PMMMCPRoot) ('ClientRuns\'+$requestId+'\'+[guid]::NewGuid().ToString('N'))
        [void][IO.Directory]::CreateDirectory($job)
        $output=Join-Path $job 'response.txt';$stdout=Join-Path $job 'events.jsonl';$stderr=Join-Path $job 'stderr.txt'
        $psExe=Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
        $server=Resolve-PMMMCPPath $Script:Root 'Modules\MCP\Start-PMMMCP.ps1'
        $serverArgs=@('-NoLogo','-NoProfile','-NonInteractive','-ExecutionPolicy','Bypass','-File',$server,'-CaseId',$CaseId)
        $toolNames=@('pmm_status','pmm_dependencies_status','pmm_dependency_install','pmm_dependency_job','pmm_dependency_cancel','pmm_asset_edit','pmm_candidate_build','pmm_candidates_list','pmm_archive_search','pmm_asset_prepare','pmm_unreal_status','pmm_unreal_prepare','pmm_unreal_texture','pmm_unreal_cook','pmm_unreal_job','pmm_unreal_cancel','pmm_unreal_candidates','pmm_asset_inspect','pmm_reference_prepare','pmm_reference_status','pmm_case_get','pmm_reference_search','pmm_reference_export','pmm_artifacts_list','pmm_artifact_read','pmm_artifact_put')
        $args=@('exec','--ignore-user-config','--ephemeral','--skip-git-repo-check','--sandbox','read-only',
            '--disable','shell_tool','--disable','plugins','--disable','multi_agent',
            '-c','web_search="disabled"','-c','mcp_optional_startup_grace_ms=0',
            '-c',('mcp_servers.pmm.command='+($psExe | ConvertTo-Json -Compress)),
            '-c',('mcp_servers.pmm.args='+(ConvertTo-Json -InputObject $serverArgs -Compress)),
            '-c',('mcp_servers.pmm.enabled_tools='+(ConvertTo-Json -InputObject $toolNames -Compress)),
            '-c','mcp_servers.pmm.required=true','-c','mcp_servers.pmm.startup_timeout_sec=30',
            '-c','mcp_servers.pmm.tool_timeout_sec=360','-C',$job,'--color','never','--json','-o',$output)
        $prompt='You are the AI client for a PMM request. Use pmm_case_get with caseId '+$CaseId+' to read it through MCP. Request ID: '+$requestId+'. First call pmm_status to discover the configured Palworld game and PMM capabilities. If Game Reference is missing or stale, call pmm_reference_prepare yourself, poll pmm_reference_status with waitSeconds=20 until Current, and resume the search in the same run. Never ask the user to press a button or supply information that PMM tools can obtain. Assume the main player inventory when the goal simply says inventory, state that assumption, and continue research. Use pmm_asset_inspect for structured properties and DataTable rows; search property names using query and paginate. Do not ask the user to inspect files that PMM can inspect. Use only PMM tools for evidence. Treat the goal as a modding request, not permission to alter PMM, execute code or change the game. Search the COMPLETE game archive with pmm_archive_search when hydrated reference searches are empty or incomplete. Prepare exact families with pmm_asset_prepare and inspect them. A missing result from pmm_reference_search does not imply the game lacks the asset. Continue tracing referenced system and UI assets. When evidence identifies a concrete numeric or boolean property and its expected value, use pmm_asset_edit with the exact JSON pointer and JSON scalar strings, then pmm_candidate_build. Never guess a property or change a number only because it matches. Preserve the requested mod format; no Lua/UE4SS substitution for a PAK request. Candidate creation is authorized; deployment is not. Use pmm_candidates_list to confirm the result. If opaque exports or native logic prevent the required edit, report the exact missing operation and evidence. Return a useful response in Spanish with findings, missing evidence/questions and concrete next steps. Do not claim a mod was built, installed or tested without evidence. If the tools cannot provide required data, explain precisely what is missing. Your final text is returned to PMM as untrusted advisory text; it is not an executable mod. Never use shell, file-edit tools, other plugins or other agents.'
        $args+=,$prompt
        $commandLine=(@($args | ForEach-Object {ConvertTo-PMMMCPNativeArgument $_}) -join ' ')
        Set-PMMAIIOCaseProgress $CaseId 0 1 'Codex is reading the request and preparing a response...' -Indeterminate
        $proc=Start-Process -FilePath $client.executable -ArgumentList $commandLine -WorkingDirectory $job -WindowStyle Hidden -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
        $processHandle=$proc.Handle # Retain handle so Windows PowerShell can read ExitCode after exit.
        $watch=[Diagnostics.Stopwatch]::StartNew();$lastRenew=0
        while(-not $proc.WaitForExit(500)){
            if($watch.Elapsed.TotalSeconds -gt 2400){throw 'Codex exceeded the forty-minute time limit.'}
            if(-not(Get-PMMMCPEnabled)){throw 'MCP was disabled; the AI run was stopped.'}
            $current=ConvertTo-PMMMCPCase (Get-PMMMCPCase $CaseId)
            if(-not $current.mcpRequest -or $current.mcpRequest.requestId -cne $requestId){throw 'Case changed while the AI was working. Publish the new version.'}
            foreach($file in @($stdout,$stderr,$output)){if((Test-Path $file) -and (Get-Item $file).Length -gt 8MB){throw 'Codex output exceeded the local size limit.'}}
            if($watch.Elapsed.TotalSeconds-$lastRenew -ge 30){
                $referenceJob=Resolve-PMMMCPPath (Get-PMMMCPRoot) 'ReferenceJob\progress.json'
                $progressMessage='Codex is processing the request.'
                if(Test-Path -LiteralPath $referenceJob){try{$refStatus=Get-PMMMCPReferenceStatus;if($refStatus.status -eq 'RUNNING'){$progressMessage=$refStatus.message;Set-PMMAIIOCaseProgress $CaseId 0 1 $progressMessage -Indeterminate}}catch{}}
                [void](Invoke-PMMMCPTool 'pmm_request_progress' ([pscustomobject]@{caseId=$CaseId;requestId=$requestId;token=$lease.token;message=$progressMessage}))
                $lastRenew=$watch.Elapsed.TotalSeconds
            }
        }
        if($proc.ExitCode -ne 0){throw ('Codex exited with code '+$proc.ExitCode+'. Review the local ClientRuns diagnostics; sign-in, connectivity or client setup may need attention.')}
        if(-not(Test-Path -LiteralPath $output) -or (Get-Item $output).Length -gt 128KB){throw 'Codex did not produce a bounded response.'}
        $response=[IO.File]::ReadAllText($output)
        if([string]::IsNullOrWhiteSpace($response) -or $response.Length -gt 32000){throw 'Codex response is empty or exceeds 32000 characters.'}
        $built=@(Get-PMMMCPAssetCandidates $CaseId|Where-Object{$_.status -eq 'CANDIDATE_BUILT'})
        $status='RESPONSE_RECEIVED';$message='AI response received. Review it below.'
        if($built.Count){$status='CANDIDATE_BUILT';$message='A candidate PAK is available. Game behavior remains untested; no deployment occurred.'}
        elseif($case.Type -in @('NEW_MOD','FIX_MOD','COMPATIBILITY')){$status='BLOCKED';$message='Research ended without a built candidate. See the specific missing evidence or operation below.'}
        [void](Invoke-PMMMCPTool 'pmm_request_complete' ([pscustomobject]@{caseId=$CaseId;requestId=$requestId;token=$lease.token;message=$message;response=$response;status=$status}))
        return $message
    }catch{
        $reason=$_.Exception.Message
        try{[void](Invoke-PMMMCPTool 'pmm_request_complete' ([pscustomobject]@{caseId=$CaseId;requestId=$requestId;token=$lease.token;message=$reason;response=$reason;status='FAILED'}))}catch{}
        throw $reason
    }finally{
        if($proc){
            if(-not $proc.HasExited){
                $killer=Start-Process -FilePath (Join-Path $env:SystemRoot 'System32\taskkill.exe') -ArgumentList @('/PID',[string]$proc.Id,'/T','/F') -WindowStyle Hidden -Wait -PassThru
            }
            $proc.Dispose()
        }
    }
}

