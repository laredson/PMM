$Script:PMMLastTerminalReply=''
function Update-PMMMCPReplyUI {
    if(-not(Get-Command Get-PMMAIIOCaseControl -ErrorAction SilentlyContinue)){return}
    $panel=Get-PMMAIIOCaseControl 'PnlMCPReply'
    if(-not $panel){return}
    try{
        $case=Get-PMMAIIOSelectedCase
        if($case -and (Get-Command Update-PMMChatPanel -ErrorAction SilentlyContinue)){Update-PMMChatPanel $case}
        if($case -and (Get-Command Get-PMMCaseAgentView -ErrorAction SilentlyContinue) -and (Get-Command Update-PMMCaseAgentUI -ErrorAction SilentlyContinue)){
            $agentView=Get-PMMCaseAgentView $case
            if($agentView -and (Get-PMMCaseClient $case) -eq 'CODEX' -and ($case.SelectedStep -le 0 -or $case.SelectedStep -eq $case.CurrentStep)){
                Update-PMMCaseAgentUI $case $agentView
                return
            }
        }
        if(-not$case -and $Script:PMMAIIOCaseUI.ContainsKey('BtnAgentOpen')){(Get-PMMAIIOCaseControl 'BtnAgentOpen').IsEnabled=$false}

        if(-not $case -or $case.Transport -ne 'MCP' -or ($case.SelectedStep -gt 0 -and $case.SelectedStep -lt $case.CurrentStep)){$panel.Visibility='Collapsed';return}
        $panel.Visibility='Visible'
        $status=Get-PMMAIIOCaseControl 'TxtMCPReplyStatus'
        $text=Get-PMMAIIOCaseControl 'TxtMCPResponse'
        $reply=Get-PMMMCPReplyView $case
        $newText=''
        if($reply){
            $status.Text=$reply.status+' - '+$reply.message
            $newText=[string]$reply.response
            if($reply.status -in @('BLOCKED','CANDIDATE_BUILT','RESPONSE_RECEIVED','NEEDS_INPUT','INTERRUPTED')){
                $key=$reply.requestId+'|'+$reply.updatedUtc+'|'+$reply.status
                if($Script:PMMLastTerminalReply -ne $key){
                    Set-PMMAIIOCaseProgress $case.CaseId 1 1 $reply.message -Completed
                    $Script:PMMLastTerminalReply=$key
                }
            }
            $listStatus=Get-PMMAIIOCaseControl 'TxtListStatus'
            if($listStatus){$listStatus.Text=$case.Type+' | '+$reply.status}
            $next=Get-PMMAIIOCaseControl 'BtnNext'
            if($next){$next.Content='Current - '+$reply.message}
        }
        else{$status.Text='MCP: publish this version, or wait for a connected AI to claim the published request.'}
        if((Get-PMMCaseClient $case) -in @('CHATGPT','CODEX_DESKTOP')){$desktopStatus=Get-PMMDesktopCaseStatus $case;if($desktopStatus){$status.Text=$desktopStatus;(Get-PMMAIIOCaseControl 'BtnCancel').IsEnabled=$true}}
        if($text.Text -cne $newText){$text.Text=$newText}
    }catch{
        (Get-PMMAIIOCaseControl 'TxtMCPReplyStatus').Text='Unable to read AI response: '+$_.Exception.Message
    }
}
