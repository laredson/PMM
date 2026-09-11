# Request state is separate from case.json: external clients cannot overwrite UI edits.
function Get-PMMMCPExchangePath([string]$RequestId) {
    if($RequestId -cnotmatch '^[a-f0-9]{32}$'){throw 'Invalid request ID.'}
    return (Resolve-PMMMCPPath (Get-PMMMCPRoot) ('Requests\'+$RequestId+'.json'))
}
function Get-PMMMCPExchange([string]$RequestId) {
    $path=Get-PMMMCPExchangePath $RequestId
    if(Test-Path -LiteralPath $path){return (Read-PMMMCPJson $path)}
    return $null
}
function Get-PMMMCPReplyView($Case) {
    if(@($Case.PSObject.Properties | ForEach-Object {$_.Name}) -notcontains 'MCPRequest' -or -not $Case.MCPRequest){return $null}
    $r=$Case.MCPRequest
    if($Case.Transport -ne 'MCP' -or $Case.NextAction -ne 'WAIT_FOR_MCP' -or $r.publishedStep -ne $Case.CurrentStep -or $r.title -cne $Case.Title -or $r.description -cne $Case.Description -or $r.type -cne $Case.Type){return $null}
    $e=Get-PMMMCPExchange $r.requestId
    if(-not $e){return $null}
    $status=[string]$e.status
    if($status -eq 'PROCESSING' -and [DateTime]::Parse($e.expiresUtc).ToUniversalTime() -lt [DateTime]::UtcNow){$status='INTERRUPTED'}
    return [ordered]@{requestId=$r.requestId;status=$status;message=$e.message;response=$e.response;updatedUtc=$e.updatedUtc;runtime='UNPROVEN'}
}
function Invoke-PMMMCPExchangeToolCore([string]$Name,$Arguments) {
    $c=Get-PMMMCPCase $Arguments.caseId
    if((Get-PMMCaseClient $c) -eq 'CHATGPT'){$dispatch=Get-PMMDesktopDispatch $c.CaseId;if($dispatch -and $dispatch.requestId -eq $Arguments.requestId -and $dispatch.phase -eq 'CANCELLED'){throw 'Desktop request cancelled in PMM. Publish a follow-up to continue.'}}
    $view=ConvertTo-PMMMCPCase $c
    if(-not $view.mcpRequest -or $view.mcpRequest.requestId -cne $Arguments.requestId){throw 'Request is stale or unpublished. Read the current case again.'}
    $path=Get-PMMMCPExchangePath $Arguments.requestId
    $e=Get-PMMMCPExchange $Arguments.requestId
    if($Name -eq 'pmm_request_claim'){
        if($e -and $e.status -in @('RESPONSE_RECEIVED','NEEDS_INPUT','BLOCKED','CANDIDATE_BUILT')){throw 'This request already has a response. Edit and publish a follow-up.'}
        if($e -and $e.status -eq 'PROCESSING' -and [DateTime]::Parse($e.expiresUtc).ToUniversalTime() -gt [DateTime]::UtcNow){throw 'Another client is processing this request.'}
        $e=[pscustomobject]@{requestId=$Arguments.requestId;caseId=$Arguments.caseId;token=[guid]::NewGuid().ToString('N');status='PROCESSING';message='AI is processing this request.';response='';updatedUtc=[DateTime]::UtcNow.ToString('o');expiresUtc=[DateTime]::UtcNow.AddMinutes(10).ToString('o')}
        Write-PMMAIIOJsonAtomic $path $e 8
        return @{token=$e.token;expiresUtc=$e.expiresUtc;status=$e.status}
    }
    if(-not $e -or $e.token -cne $Arguments.token -or $e.status -ne 'PROCESSING' -or [DateTime]::Parse($e.expiresUtc).ToUniversalTime() -le [DateTime]::UtcNow){throw 'Invalid or expired request lease.'}
    $e.message=$Arguments.message;$e.updatedUtc=[DateTime]::UtcNow.ToString('o');$e.expiresUtc=[DateTime]::UtcNow.AddMinutes(10).ToString('o')
    if($Name -eq 'pmm_request_complete'){if($Arguments.status -eq 'CANDIDATE_BUILT' -and -not @(Get-PMMMCPAssetCandidates $Arguments.caseId|Where-Object{$_.status -eq 'CANDIDATE_BUILT'}).Count){throw 'No verified built candidate exists.'};$e.status=$Arguments.status;$e.response=$Arguments.response}
    Write-PMMAIIOJsonAtomic $path $e 8
    return (Get-PMMMCPReplyView $c)
}


function Invoke-PMMMCPExchangeTool([string]$Name,$Arguments) {
    $path=Get-PMMMCPExchangePath $Arguments.requestId
    [void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($path))
    $lock=$null
    try{
        try{$lock=[IO.File]::Open(($path+'.lock'),[IO.FileMode]::OpenOrCreate,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)}catch{throw 'This request is being updated. Retry after reading the case.'}
        return (Invoke-PMMMCPExchangeToolCore $Name $Arguments)
    }finally{if($lock){$lock.Dispose()}}
}
