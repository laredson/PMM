
function Update-PMMMCPReplyUI {
    if(-not(Get-Command Get-PMMAIIOCaseControl -ErrorAction SilentlyContinue)){return}
    $panel=Get-PMMAIIOCaseControl 'PnlMCPReply'
    if(-not $panel){return}
    try{
        $case=Get-PMMAIIOSelectedCase
        if(-not $case -or $case.Transport -ne 'MCP' -or ($case.SelectedStep -gt 0 -and $case.SelectedStep -lt $case.CurrentStep)){$panel.Visibility='Collapsed';return}
        $panel.Visibility='Visible'
        $status=Get-PMMAIIOCaseControl 'TxtMCPReplyStatus'
        $text=Get-PMMAIIOCaseControl 'TxtMCPResponse'
        $reply=Get-PMMMCPReplyView $case
        $newText=''
        if($reply){
            $status.Text=$reply.status+' - '+$reply.message
            $newText=[string]$reply.response
            $listStatus=Get-PMMAIIOCaseControl 'TxtListStatus'
            if($listStatus){$listStatus.Text=$case.Type+' | '+$reply.status}
            $next=Get-PMMAIIOCaseControl 'BtnNext'
            if($next){$next.Content='Current - '+$reply.message}
        }
        else{$status.Text='MCP: publish this version, or wait for a connected AI to claim the published request.'}
        if($text.Text -cne $newText){$text.Text=$newText}
    }catch{
        (Get-PMMAIIOCaseControl 'TxtMCPReplyStatus').Text='Unable to read AI response: '+$_.Exception.Message
    }
}
