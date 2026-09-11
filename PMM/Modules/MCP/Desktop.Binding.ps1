# Installation-local binding; no account credentials or client databases.
function Get-PMMDesktopFile([string]$Name='binding.json') { return (Resolve-PMMMCPPath (Get-PMMMCPRoot) ('Desktop\'+$Name)) }
function Get-PMMDesktopBinding {
    $p=Get-PMMDesktopFile
    if(-not(Test-Path -LiteralPath $p)){return $null}
    $b=Read-PMMMCPJson $p
    if($b.root -ine [IO.Path]::GetFullPath($Script:Root)){return $null}
    return $b
}
function New-PMMDesktopBinding {
    Set-PMMMCPEnabled $true
    $old=Get-PMMDesktopBinding
    $extra='';if($old){$extra=[string]$old.extraFolder}
    $b=[pscustomobject]@{schema='PMM_DESKTOP_BINDING_V1';root=[IO.Path]::GetFullPath($Script:Root);workspace=(Join-Path $Script:Root 'Workspace');extraFolder=$extra;nonce=[guid]::NewGuid().ToString('N');expiresUtc=[DateTime]::UtcNow.AddMinutes(30).ToString('o');verifiedUtc=''}
    Write-PMMAIIOJsonAtomic (Get-PMMDesktopFile) $b 6
    return $b
}
function Confirm-PMMDesktopBinding($Arguments) {
    if((Get-Variable PMMMCPScopeCase -Scope Script -ErrorAction SilentlyContinue) -and $Script:PMMMCPScopeCase){throw 'Use the installation connection to pair Desktop.'}
    $b=Get-PMMDesktopBinding
    if(-not $b -or -not $b.nonce -or $b.nonce -cne $Arguments.nonce -or [DateTime]::Parse($b.expiresUtc).ToUniversalTime() -lt [DateTime]::UtcNow){throw 'Pairing code invalid or expired. Prepare synchronization in PMM again.'}
    $b.verifiedUtc=[DateTime]::UtcNow.ToString('o');$b.nonce=''
    Write-PMMAIIOJsonAtomic (Get-PMMDesktopFile) $b 6
    return @{status='CONNECTION_VERIFIED';root=$b.root;workspace=$b.workspace;extraFolder=$b.extraFolder;message='PMM connection verified. No account plan, brand or filesystem permission is certified. New UI cases default to Desktop.'}
}
function Get-PMMCaseClient($Case) {
    if($Case -and $Case.PSObject.Properties['AIClient'] -and $Case.AIClient -in @('CHATGPT','EXTERNAL','CODEX')){return [string]$Case.AIClient}
    # Legacy cases preserve the global runner choice until explicitly changed.
    $p=Resolve-PMMMCPPath (Get-PMMMCPRoot) 'client.json'
    if(Test-Path -LiteralPath $p){$c=Read-PMMMCPJson $p;if($c.enabled){return 'CODEX'}}
    return 'EXTERNAL'
}
function Get-PMMDesktopDispatch([string]$CaseId) {
    [void](Get-PMMMCPCase $CaseId)
    $p=Get-PMMDesktopFile ($CaseId+'\dispatch.json')
    if(Test-Path -LiteralPath $p){return (Read-PMMMCPJson $p)}
    return $null
}
function Set-PMMDesktopCaseLink($Arguments) {
    $case=Get-PMMMCPCase $Arguments.caseId
    $view=ConvertTo-PMMMCPCase $case
    $e=Get-PMMMCPExchange $Arguments.requestId
    if(-not $view.mcpRequest -or $view.mcpRequest.requestId -cne $Arguments.requestId -or -not $e -or $e.token -cne $Arguments.token -or $e.status -ne 'PROCESSING' -or [DateTime]::Parse($e.expiresUtc).ToUniversalTime() -le [DateTime]::UtcNow){throw 'A current request lease is required.'}
    $d=Get-PMMDesktopDispatch $Arguments.caseId
    if(-not $d -or $d.phase -eq 'CANCELLED' -or $d.requestId -cne $Arguments.requestId){throw 'No matching active Desktop dispatch.'}
    if($Arguments.phase -cnotin @('RECEIVED','RESEARCHING','AWAITING_APPROVAL')){throw 'Invalid Desktop phase.'}
    if($Arguments.PSObject.Properties['threadId']){
        if($Arguments.threadId -cnotmatch '^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$'){throw 'Invalid local thread ID.'}
        $d.threadId=$Arguments.threadId
    }
    $d.phase=$Arguments.phase;$d.updatedUtc=[DateTime]::UtcNow.ToString('o')
    Write-PMMAIIOJsonAtomic (Get-PMMDesktopFile ($Arguments.caseId+'\dispatch.json')) $d 8
    return @{status=$d.phase;caseId=$Arguments.caseId;threadId=$d.threadId}
}
function Get-PMMDesktopCaseStatus($Case) {
    $reply=Get-PMMMCPReplyView $Case
    $d=Get-PMMDesktopDispatch $Case.CaseId
    if(-not $d -or -not $Case.PSObject.Properties['MCPRequest'] -or $d.requestId -cne $Case.MCPRequest.requestId){return ''}
    if($d.phase -eq 'CANCELLED'){return (L 'PMM request cancelled. A message already sent remains in ChatGPT; stop that chat there.' 'Solicitud PMM cancelada. Un mensaje ya enviado sigue en ChatGPT; deten ese chat alli.')}
    if($reply -and $reply.status -ne 'PROCESSING'){return $reply.status+' - '+$reply.message}
    if($reply){
        if($d.phase -eq 'AWAITING_APPROVAL'){return (L 'Waiting for your plan approval in ChatGPT.' 'Esperando tu aprobacion del plan en ChatGPT.')}
        if($d.phase -eq 'RESEARCHING'){return (L 'ChatGPT is investigating the case.' 'ChatGPT esta investigando el caso.')}
        return (L 'Request received by an AI client.' 'Solicitud recibida por un cliente de IA.')
    }
    $result=Get-PMMDesktopFile ($Case.CaseId+'\send-result.json')
    if(Test-Path -LiteralPath $result){$r=Read-PMMMCPJson $result;if($r.requestId -eq $d.requestId -and $r.status -eq 'SENT'){return (L 'Message sent; waiting for MCP receipt.' 'Mensaje enviado; esperando recepcion por MCP.')}}
    return (L 'Chat prepared. Send the message in ChatGPT; MCP receipt is pending.' 'Chat preparado. Envia el mensaje en ChatGPT; la recepcion por MCP sigue pendiente.')
}
function New-PMMDesktopLink([string]$Prompt,[string]$ThreadId='') {
    if($ThreadId){
        if($ThreadId -cnotmatch '^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$'){throw 'Invalid thread ID.'}
        return 'codex://threads/'+$ThreadId
    }
    return 'codex://threads/new?path='+[Uri]::EscapeDataString([IO.Path]::GetFullPath($Script:Root))+'&prompt='+[Uri]::EscapeDataString($Prompt)
}

function Cancel-PMMDesktopDispatch([string]$CaseId) {
    $d=Get-PMMDesktopDispatch $CaseId
    if(-not $d){return}
    $d.phase='CANCELLED';$d.updatedUtc=[DateTime]::UtcNow.ToString('o')
    Write-PMMAIIOJsonAtomic (Get-PMMDesktopFile ($CaseId+'\dispatch.json')) $d 8
}
