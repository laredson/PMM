. (Join-Path $PSScriptRoot 'Desktop.Binding.ps1')
# Optional client: installation never implies authentication or a live MCP connection.
function Get-PMMChatGPTDesktop {
    try{
        $packages=@(Get-AppxPackage -ErrorAction Stop | Where-Object {$_.Name -in @('OpenAI.ChatGPT-Desktop','OpenAI.Codex') -and $_.Publisher -eq 'CN=50BDFD77-8903-4850-9FFE-6E8522F64D5B'})
        $fallback=$null
        foreach($p in ($packages|Sort-Object Name)){
            $m=Get-AppxPackageManifest -Package $p.PackageFullName
            $protocols=@($m.SelectNodes('//*[local-name()="Protocol"]')|ForEach-Object {$_.Name})
            $p|Add-Member -NotePropertyName SupportsLocalChats -NotePropertyValue ($protocols -contains 'codex') -Force
            if($p.SupportsLocalChats){return $p}
            if($p.Name -eq 'OpenAI.ChatGPT-Desktop'){$fallback=$p}
        }
        return $fallback
    }catch{return $null}
}
function Open-PMMChatGPTDesktop {
    $p=Get-PMMChatGPTDesktop
    if(-not $p){Start-Process 'ms-windows-store://pdp/?ProductId=9PLM9XGG6VKS';return}
    $manifest=Get-AppxPackageManifest -Package $p.PackageFullName
    $id=@($manifest.Package.Applications.Application)[0].Id
    Start-Process explorer.exe -ArgumentList ('shell:AppsFolder\'+$p.PackageFamilyName+'!'+$id)
}
function Confirm-PMMDesktopConnection($Arguments){
    [void](Get-PMMMCPCase $Arguments.caseId)
    $path=Resolve-PMMMCPPath (Get-PMMMCPRoot) ('Desktop\'+$Arguments.caseId+'\connection.json')
    $challenge=Read-PMMMCPJson $path
    if($challenge.nonce -cne $Arguments.nonce -or [DateTime]::Parse($challenge.expiresUtc).ToUniversalTime() -lt [DateTime]::UtcNow){throw 'Connection challenge expired or does not match.'}
    $challenge.verifiedUtc=[DateTime]::UtcNow.ToString('o')
    Write-PMMAIIOJsonAtomic $path $challenge 5
    return @{status='CONNECTION_VERIFIED';caseId=$Arguments.caseId;scope='PMM MCP operations only; other client tools have separate permissions.'}
}

function Open-PMMDesktopLink([string]$Link) {
    $app=Get-PMMChatGPTDesktop
    if(-not $app -or -not $app.SupportsLocalChats){Open-PMMChatGPTDesktop;return $false}
    if($Link -notmatch '^codex://threads/'){throw 'Unsupported Desktop link.'}
    try{Start-Process -FilePath $Link -ErrorAction Stop;return $true}catch{Open-PMMChatGPTDesktop;return $false}
}
function Show-PMMDesktopSetup {
    $app=Get-PMMChatGPTDesktop
    $binding=Get-PMMDesktopBinding
    if(-not $binding -or -not $binding.verifiedUtc){$binding=New-PMMDesktopBinding}
    & (Join-Path $Script:Root 'Modules\MCP\Export-PMMMCPConfig.ps1') -Root $Script:Root -Enable | Out-Null
    $prompt='Sincronizar con PMM. Call pmm_desktop_pair with nonce '+$binding.nonce+'. Use this installation: '+$binding.root+'. Work in its Workspace directory. Do not start or change a case yet. Report the connection result.'
    $v=New-PMMThemedDialog (L 'Connect ChatGPT Desktop' 'Conectar ChatGPT Desktop');Set-PMMDesktopDialogActions $v
    $hint=[Windows.Controls.TextBlock]::new();$hint.TextWrapping='Wrap'
    $hint.Text=L 'Sign in and add this PMM folder as a local project. In ChatGPT Settings > MCP servers, add the generated configuration and restart the server once. Then send the synchronization text. Folder access and MCP are separate. PMM does not accept client permission dialogs. Free account validation is pending.' 'Inicia sesion y agrega esta carpeta de PMM como proyecto local. En ChatGPT Settings > MCP servers, agrega la configuracion generada y reinicia el servidor una vez. Despues envia el texto de sincronizacion. El acceso a carpetas y MCP son independientes. PMM no acepta los permisos del cliente. La validacion con una cuenta Free esta pendiente.'
    if($app){$hint.Text+="`n"+(L 'Detected application: ' 'Aplicacion detectada: ')+$app.Name+' '+$app.Version;if(-not $app.SupportsLocalChats){$hint.Text+="`n"+(L 'This version does not register local chat links. Update from the official download page.' 'Esta version no registra enlaces de chats locales. Actualiza desde la descarga oficial.')}}
    [void]$v.body.Children.Add($hint)
    $box=[Windows.Controls.TextBox]::new();$box.IsReadOnly=$true;$box.TextWrapping='Wrap';$box.Text=if($binding.verifiedUtc){'MCP verified: '+$binding.verifiedUtc}else{$prompt};$box.Margin=[Windows.Thickness]::new(0,12,0,12);[void]$v.body.Children.Add($box)
    $paths=[Windows.Controls.TextBlock]::new();$paths.TextWrapping='Wrap';$paths.Text=$binding.root+"`n"+$binding.workspace+"`n"+$binding.extraFolder;[void]$v.body.Children.Add($paths)
    foreach($action in @('copy','config','open','extra','check','reconnect','update')){
        $b=[Windows.Controls.Button]::new();$b.Margin=[Windows.Thickness]::new(4)
        $b.Content=switch($action){'copy'{L 'Copy synchronization' 'Copiar sincronizacion'}'config'{L 'MCP configuration' 'Configuracion MCP'}'open'{L 'Open synchronization chat' 'Abrir chat de sincronizacion'}'extra'{L 'Additional folder...' 'Carpeta adicional...'}'check'{L 'Check connection' 'Comprobar conexion'}'reconnect'{L 'Reconnect' 'Volver a vincular'}'update'{L 'Official download' 'Descarga oficial'}}
        $op=$action
        $b.Add_Click({try{switch($op){
            'update'{Start-Process 'https://learn.chatgpt.com/docs/enterprise/windows-deployment'}
            'copy'{[Windows.Clipboard]::SetText($box.Text)}
            'config'{Start-Process explorer.exe -ArgumentList ('"'+(Get-PMMMCPRoot)+'"')}
            'open'{$currentBinding=Get-PMMDesktopBinding;if($currentBinding -and $currentBinding.verifiedUtc){Open-PMMChatGPTDesktop}else{[void](Open-PMMDesktopLink (New-PMMDesktopLink $box.Text))}}
            'extra'{$picker=[Windows.Forms.FolderBrowserDialog]::new();try{if($picker.ShowDialog() -eq 'OK'){$value=Get-PMMDesktopBinding;$value.extraFolder=[IO.Path]::GetFullPath($picker.SelectedPath);Write-PMMAIIOJsonAtomic (Get-PMMDesktopFile) $value 6;$paths.Text=$value.root+"`n"+$value.workspace+"`n"+$value.extraFolder+"`n"+(L 'Add this extra folder in ChatGPT permissions.' 'Agrega esta carpeta adicional en los permisos de ChatGPT.')}}finally{$picker.Dispose()}}
            'check'{$value=Get-PMMDesktopBinding;if($value -and $value.verifiedUtc){$paths.Text='MCP verified: '+$value.verifiedUtc+"`n"+$value.root}else{$paths.Text=L 'Waiting for synchronization. Send the copied text in ChatGPT.' 'Esperando sincronizacion. Envia el texto copiado en ChatGPT.'}}
            'reconnect'{$value=New-PMMDesktopBinding;$box.Text='Sincronizar con PMM. Call pmm_desktop_pair with nonce '+$value.nonce+'. Use '+$value.root+'. Do not start any case yet.'}
        }}catch{$box.Text=$_.Exception.Message}}.GetNewClosure())
        [void]$v.actions.Children.Add($b)
    }
    $v.body.Children.Remove($v.actions);[void]$v.body.Children.Add($v.actions)
    [void]$v.window.ShowDialog()
}
function Show-PMMDesktopDispatchHelp($Dispatch,[bool]$CanOpen=$true) {
    $v=New-PMMThemedDialog (L 'Case in ChatGPT' 'Caso en ChatGPT');Set-PMMDesktopDialogActions $v
    $text=[Windows.Controls.TextBox]::new();$text.IsReadOnly=$true;$text.TextWrapping='Wrap';$text.Text=$Dispatch.prompt;$text.MinHeight=130;[void]$v.body.Children.Add($text)
    $hint=[Windows.Controls.TextBlock]::new();$hint.TextWrapping='Wrap';$hint.Margin=[Windows.Thickness]::new(0,12,0,8)
    $hint.Text=L 'The request is already prepared. Send it in the existing chat. A new chat will only be opened if you choose the button below. ChatGPT must investigate and ask for your approval before changes. If the project is missing, add the PMM folder as a local project.' 'La solicitud ya esta preparada. Enviala en el chat existente. Solo se abrira otro chat si pulsas el boton de abajo. ChatGPT debe investigar y pedir tu aprobacion antes de realizar cambios. Si falta el proyecto, agrega la carpeta de PMM como proyecto local.'
    [void]$v.body.Children.Add($hint)
    foreach($action in @('copy','open','setup')){
        $b=[Windows.Controls.Button]::new();$b.Margin=[Windows.Thickness]::new(4);$b.Content=switch($action){'copy'{L 'Copy request' 'Copiar solicitud'}'open'{L 'Open new chat' 'Abrir chat nuevo'}'setup'{L 'Connection settings' 'Configurar conexion'}}
        if($action -eq 'open'){$b.IsEnabled=$CanOpen}
        $op=$action;$b.Add_Click({switch($op){'copy'{[Windows.Clipboard]::SetText($Dispatch.prompt)}'open'{[void](Open-PMMDesktopLink (New-PMMDesktopLink $Dispatch.prompt))}'setup'{Show-PMMDesktopSetup}}}.GetNewClosure());[void]$v.actions.Children.Add($b)
    }
    $v.body.Children.Remove($v.actions);[void]$v.body.Children.Add($v.actions)
    [void]$v.window.ShowDialog()
}
function Show-PMMChatGPTCase {
    [void](Save-PMMAIIOCaseEditor)
    $case=Get-PMMAIIOSelectedCase
    if(-not $case){throw 'Select a case first.'}
    if($case.SelectedStep -gt 0 -and $case.SelectedStep -lt $case.CurrentStep){throw 'Select the latest case step first.'}
    if($case.ActiveOperation.Running){throw 'A PMM worker is already processing this case.'}
    $installed=Get-PMMChatGPTDesktop
    if(-not $installed){
        if((Show-PMMThemedMessage @((L 'Install ChatGPT Desktop to continue?' 'Instalar ChatGPT Desktop para continuar?'),'ChatGPT','YesNo')) -eq [Windows.MessageBoxResult]::Yes){[void](Request-PMMDependencyInstall 'chatgpt' $case.CaseId);Open-PMMSettings 'INSTALLATIONS'}
        return
    }
    if(-not $installed.SupportsLocalChats){Show-PMMDesktopSetup;return}
    $binding=Get-PMMDesktopBinding
    if(-not $binding -or -not $binding.verifiedUtc -or -not(Get-PMMMCPEnabled)){Show-PMMDesktopSetup;return}
    $previous=Get-PMMDesktopDispatch $case.CaseId
    $reply=Get-PMMMCPReplyView $case
    if($reply -and $reply.status -eq 'PROCESSING'){
        if($previous -and $previous.requestId -eq $reply.requestId -and $previous.threadId){[void](Open-PMMDesktopLink (New-PMMDesktopLink '' $previous.threadId));return}
        throw 'An AI is processing this request. Continue in its chat; no second client was started.'
    }
    $case.Transport='MCP';$case|Add-Member -NotePropertyName AIClient -NotePropertyValue CHATGPT -Force;Save-PMMAIIOCase $case|Out-Null
    $published=Publish-PMMAIIOCaseMCP $case.CaseId
    if($previous -and $previous.requestId -eq $published.RequestId -and $previous.phase -eq 'CANCELLED'){throw 'This request was cancelled. Edit the case and publish a follow-up.'}
    if($previous -and $previous.requestId -eq $published.RequestId){
        if($previous.threadId){[void](Open-PMMDesktopLink (New-PMMDesktopLink '' $previous.threadId))}else{Show-PMMDesktopDispatchHelp $previous (-not [bool]$reply)}
        return
    }
    $prompt='PMM case '+$case.CaseId+', request '+$published.RequestId+'. Workspace: '+$binding.root+'. Read pmm_case_get and claim this request using pmm_request_claim before working. Research first; do not edit assets, build, install, deploy or change PMM before presenting the plan and receiving the user approval in this chat. Use pmm_desktop_case_link with the lease token to report RECEIVED, RESEARCHING and AWAITING_APPROVAL; include your actual local threadId if available, never invent it. Renew the lease with pmm_request_progress while researching. Work in PMM Workspace'+$(if($binding.extraFolder){' or user-selected '+$binding.extraFolder}else{''})+'. Preserve normal saves. After approval, reclaim the request if the lease expired, then proceed within the approved scope. Return results using pmm_request_complete. Report built and game-tested separately.'
    $d=[pscustomobject]@{caseId=$case.CaseId;requestId=$published.RequestId;root=$binding.root;prompt=$prompt;threadId='';phase='PREPARED';updatedUtc=[DateTime]::UtcNow.ToString('o');packageRoot=[string]$installed.InstallLocation}
    $path=Get-PMMDesktopFile ($case.CaseId+'\dispatch.json')
    Write-PMMAIIOJsonAtomic $path $d 8
    Refresh-PMMAIIOCaseList $case.CaseId
    if($previous -and $previous.threadId){$d.threadId=$previous.threadId;Write-PMMAIIOJsonAtomic $path $d 8;[void](Open-PMMDesktopLink (New-PMMDesktopLink '' $d.threadId));Show-PMMDesktopDispatchHelp $d $false;return}
    if(Open-PMMDesktopLink (New-PMMDesktopLink $prompt)){
        $worker=Join-Path $Script:Root 'Modules\MCP\Desktop.SendWorker.ps1'
        $args='-NoProfile -NonInteractive -ExecutionPolicy Bypass -File "'+$worker+'" -DispatchPath "'+$path+'"'
        Start-Process -FilePath (Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe') -ArgumentList $args -WindowStyle Hidden | Out-Null
        Set-PMMAIIOCaseUiStatus (L 'Chat prepared; waiting for verified delivery.' 'Chat preparado; esperando entrega verificada.')
    }else{Show-PMMDesktopDispatchHelp $d}
}

function Set-PMMDesktopDialogActions($View) {
    $close=[Windows.Controls.Button]::new();$close.Content=L 'Close' 'Cerrar';$close.IsCancel=$true;$close.MinWidth=110
    $dialog=$View.window;$close.Add_Click({$dialog.Close()}.GetNewClosure());[void]$View.actions.Children.Add($close)
    $wrap=[Windows.Controls.WrapPanel]::new();$wrap.Margin=[Windows.Thickness]::new(0,14,0,0)
    # Buttons share the scrolling body, so narrow windows never clip setup actions.
    [void]$View.body.Children.Add($wrap);$View.actions=$wrap
}
