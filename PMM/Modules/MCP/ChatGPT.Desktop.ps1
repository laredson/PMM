. (Join-Path $PSScriptRoot 'Desktop.Binding.ps1')
. (Join-Path $PSScriptRoot 'Desktop.Runtime.ps1')
function Confirm-PMMDesktopConnection($Arguments){
    [void](Get-PMMMCPCase $Arguments.caseId)
    $path=Resolve-PMMMCPPath (Get-PMMMCPRoot) ('Desktop\'+$Arguments.caseId+'\connection.json')
    $challenge=Read-PMMMCPJson $path
    if($challenge.nonce -cne $Arguments.nonce -or [DateTime]::Parse($challenge.expiresUtc).ToUniversalTime() -lt [DateTime]::UtcNow){throw 'Connection challenge expired or does not match.'}
    $challenge.verifiedUtc=[DateTime]::UtcNow.ToString('o')
    Write-PMMAIIOJsonAtomic $path $challenge 5
    return @{status='CONNECTION_VERIFIED';caseId=$Arguments.caseId;scope='PMM MCP operations only; other client tools have separate permissions.'}
}

function Show-PMMDesktopSetup {
    Initialize-PMMDesktopProject
    $app=Get-PMMChatGPTDesktop
    $binding=Get-PMMDesktopBinding
    if(-not $binding -or -not $binding.verifiedUtc){$binding=New-PMMDesktopBinding}
    & (Join-Path $Script:Root 'Modules\MCP\Export-PMMMCPConfig.ps1') -Root $Script:Root -Enable | Out-Null
    $prompt='Sincronizar con PMM. Call pmm_desktop_pair with nonce '+$binding.nonce+'. Installation root: '+$binding.root+'. Project and working directory: '+$binding.workspace+'. Do not start or change a case yet. Report the connection result.'
    $v=New-PMMThemedDialog (L 'Connect ChatGPT Desktop' 'Conectar ChatGPT Desktop');Set-PMMDesktopDialogActions $v
    $hint=[Windows.Controls.TextBlock]::new();$hint.TextWrapping='Wrap'
    $hint.Text=L 'Sign in and add the PMM Workspace folder shown below as a local project. PMM installs its project MCP entry in Workspace/.codex/config.toml and preserves other entries. Restart the server once, then send the synchronization text. Folder access and MCP are separate. PMM does not accept client permission dialogs. Free account validation is pending.' 'Inicia sesion y agrega la carpeta Workspace de PMM que se muestra abajo como proyecto local. PMM instala su entrada MCP de proyecto en Workspace/.codex/config.toml y conserva las demas entradas. Reinicia el servidor una vez y despues envia el texto de sincronizacion. El acceso a carpetas y MCP son independientes. PMM no acepta los permisos del cliente. La validacion con una cuenta Free esta pendiente.'
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
            'reconnect'{$value=New-PMMDesktopBinding;$box.Text='Sincronizar con PMM. Call pmm_desktop_pair with nonce '+$value.nonce+'. Installation root: '+$value.root+'. Project and working directory: '+$value.workspace+'. Do not start any case yet.'}
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
    $hint.Text=L 'The request is already prepared. Send it in the existing chat. A new chat will only be opened if you choose the button below. ChatGPT must investigate and ask for your approval before changes. If the project is missing, add the PMM Workspace folder as a local project.' 'La solicitud ya esta preparada. Enviala en el chat existente. Solo se abrira otro chat si pulsas el boton de abajo. ChatGPT debe investigar y pedir tu aprobacion antes de realizar cambios. Si falta el proyecto, agrega la carpeta Workspace de PMM como proyecto local.'
    [void]$v.body.Children.Add($hint)
    foreach($action in @('copy','open','setup')){
        $b=[Windows.Controls.Button]::new();$b.Margin=[Windows.Thickness]::new(4);$b.Content=switch($action){'copy'{L 'Copy request' 'Copiar solicitud'}'open'{L 'Open new chat' 'Abrir chat nuevo'}'setup'{L 'Connection settings' 'Configurar conexion'}}
        if($action -eq 'open'){$b.IsEnabled=$CanOpen}
        $b.Tag=@{Action=$action;Dispatch=$Dispatch};$b.Add_Click({param($sender,$eventArgs)
          $d=$sender.Tag.Dispatch
          switch($sender.Tag.Action){
            'copy'{[Windows.Clipboard]::SetText($d.prompt)}
            'open'{$destination=if($d.PSObject.Properties['destination']){$d.destination}else{'CHATGPT'};[void](Open-PMMDesktopLink (New-PMMDesktopLink $d.prompt '' (Get-PMMCaseDesktopMode ([pscustomobject]@{DesktopMode=$(if($d.PSObject.Properties['mode']){$d.mode}else{'chat'})}))) $destination);$sender.IsEnabled=$false}
            'setup'{Show-PMMDesktopSetup}
          }
        });[void]$v.actions.Children.Add($b)
    }
    $v.body.Children.Remove($v.actions);[void]$v.body.Children.Add($v.actions)
    [void]$v.window.ShowDialog()
}
function Show-PMMChatGPTCase {
    [void](Save-PMMAIIOCaseEditor)
    $case=Get-PMMAIIOSelectedCase
    if(-not $case){throw 'Select a case first.'}
    if($case.SelectedStep -gt 0 -and $case.SelectedStep -lt $case.CurrentStep){throw 'Select the latest case step first.'}
    if($case.Type -in @('FIX_MOD','COMPATIBILITY') -and -not@($case.References.Mods).Count){throw (L 'Attach the mod with Add PAK before sending the case.' 'Adjunta el mod con Agregar PAK antes de enviar el caso.')}
    if($case.ActiveOperation.Running){throw 'A PMM worker is already processing this case.'}
    $destination=Get-PMMCaseClient $case
    if($destination -notin @('CHATGPT','CODEX_DESKTOP')){$destination='CHATGPT'}
    $session=if(Get-Command Get-PMMCaseRepairSession -ErrorAction SilentlyContinue){Get-PMMCaseRepairSession $case.CaseId}else{$null}
    if($session -and (Test-PMMRepairWorkerAlive $session)){throw 'Stop the internal request before handing control to Desktop.'}
    $installed=Get-PMMChatGPTDesktop $destination
    if(-not $installed){
        if((Show-PMMThemedMessage @((L 'Install ChatGPT Desktop to continue?' 'Instalar ChatGPT Desktop para continuar?'),'ChatGPT','YesNo')) -eq [Windows.MessageBoxResult]::Yes){[void](Request-PMMDependencyInstall 'chatgpt' $case.CaseId);Open-PMMSettings 'INSTALLATIONS'}
        return
    }
    if(-not $installed.SupportsLocalChats){Show-Info (L 'This installed ChatGPT version cannot open local MCP chats. Select Codex Desktop for PMM control, or update ChatGPT to a version supporting local MCP. No internal AI request was started.' 'Esta version instalada de ChatGPT no permite abrir chats MCP locales. Selecciona Codex Desktop para controlar PMM, o actualiza ChatGPT a una version con MCP local. No se inicio ninguna peticion IA interna.');return}
    $mode=Get-PMMCaseDesktopMode $case
    if((Get-PMMCaseDesktopSendMode $case) -eq 'SEND'){throw (L 'This Desktop exposes prompt preparation, but no verified automatic-send interface. Choose Prepare question; no message was sent.' 'Este Desktop permite preparar el texto, pero no ofrece un canal de envio automatico verificado. Elige Escribir pregunta; no se envio ningun mensaje.')}
    if($mode -notin @(Get-PMMDesktopModes $installed)){throw (L 'The selected mode is not exposed by this installed Desktop. Refresh the connection; PMM will not change to Work automatically.' 'El modo elegido no esta disponible en este Desktop. Actualiza la conexion; PMM no cambiara a Work automaticamente.')}
    $binding=Get-PMMDesktopBinding
    if(-not $binding -or -not $binding.verifiedUtc -or -not(Get-PMMMCPEnabled)){Show-PMMDesktopSetup;return}
    Initialize-PMMDesktopProject
    $previous=Get-PMMDesktopDispatch $case.CaseId
    $reply=Get-PMMMCPReplyView $case
    if($reply -and $reply.status -eq 'PROCESSING'){
        if($previous -and $previous.requestId -eq $reply.requestId -and $previous.threadId){[void](Open-PMMDesktopLink (New-PMMDesktopLink '' $previous.threadId) $destination);return}
        throw 'An AI is processing this request. Continue in its chat; no second client was started.'
    }
    $case.Transport='MCP';$case|Add-Member -NotePropertyName AIClient -NotePropertyValue $destination -Force;Save-PMMAIIOCase $case|Out-Null
    $published=Publish-PMMAIIOCaseMCP $case.CaseId
    if($previous -and $previous.requestId -eq $published.RequestId -and $previous.phase -eq 'CANCELLED'){throw 'This request was cancelled. Edit the case and publish a follow-up.'}
    if($previous -and $previous.requestId -eq $published.RequestId -and $previous.PSObject.Properties['mode'] -and $previous.mode -ne $mode){throw (L 'This request already has a prepared conversation in another mode. Continue that conversation or create a separate case.' 'Esta solicitud ya tiene una conversacion preparada en otro modo. Continua esa conversacion o crea otro caso.')}
    if($previous -and $previous.requestId -eq $published.RequestId){
        if($previous.threadId){[void](Open-PMMDesktopLink (New-PMMDesktopLink '' $previous.threadId) $destination)}else{Show-PMMDesktopDispatchHelp $previous (-not [bool]$reply)}
        return
    }
    $prompt='PMM case '+$case.CaseId+', request '+$published.RequestId+'. Installation root: '+$binding.root+'. Project Workspace: '+$binding.workspace+'. Call pmm_status first and verify that installationRoot equals the installation root above. If it does not match, stop and correct the project MCP connection; do not create or modify cases in another installation. First state your actual mode and which PMM tools are available in this conversation. If local PMM tools are unavailable in Chat, explain that limitation and let the user choose Work; do not change modes yourself. If tools are available, read pmm_case_get and claim this request using pmm_request_claim before working. You control the investigation in this Desktop conversation. First explain what the user seems to want and offer concrete outcomes: an updated mod ready for publication, a reusable functional Fix Lab KL recipe, or another user-chosen outcome. Ask only for missing decisions; respect the already authorized scope. After the user chooses, use PMM tools to inspect the exact case PAK, compare the current game reference, build and validate the chosen output. Do not substitute a merge of the entire active library for this case. If PMM lacks a tool, identify that specific missing capability; do not spend more reasoning or delegate to additional chats to compensate. Do not start an internal PMM AI runner. Mod changes go through PMM. Publication and game tests require their own authorization. Use pmm_desktop_case_link with the lease token to report RECEIVED, RESEARCHING and AWAITING_APPROVAL; include your actual local threadId if available, never invent it. Renew the lease with pmm_request_progress while researching. Work in the project Workspace'+$(if($binding.extraFolder){' or user-selected '+$binding.extraFolder}else{''})+'. Preserve normal saves. After approval, reclaim the request if the lease expired, then proceed within the approved scope. Return results using pmm_request_complete. Report built and game-tested separately.'
    $d=[pscustomobject]@{caseId=$case.CaseId;requestId=$published.RequestId;root=$binding.root;prompt=$prompt;threadId='';phase='PREPARED';updatedUtc=[DateTime]::UtcNow.ToString('o');packageRoot=[string]$installed.InstallLocation;destination=$destination;mode=$mode;delivery='DRAFT';projectPath=$binding.workspace}
    # An old internal Work session is reopened only by Open conversation, never as a new Chat request.
    $path=Get-PMMDesktopFile ($case.CaseId+'\dispatch.json')
    Write-PMMAIIOJsonAtomic $path $d 8
    if(Get-Command Add-PMMCaseChatEvent -ErrorAction SilentlyContinue){Add-PMMCaseChatEvent $case.CaseId 'Desktop request prepared' @{Destination=$destination;Prompt=$prompt;RequestId=$published.RequestId} $published.RequestId|Out-Null}
    Refresh-PMMAIIOCaseList $case.CaseId
    if(($previous -and $previous.threadId) -or $d.threadId){if($previous -and $previous.threadId){$d.threadId=$previous.threadId};Write-PMMAIIOJsonAtomic $path $d 8;[void](Open-PMMDesktopLink (New-PMMDesktopLink '' $d.threadId) $destination);Show-PMMDesktopDispatchHelp $d $false;return}
    if(Open-PMMDesktopLink (New-PMMDesktopLink $prompt '' $mode) $destination){
        Set-PMMAIIOCaseUiStatus (L 'Chat prepared. Send the request in Desktop; connection is confirmed when MCP receives it.' 'Chat preparado. Envia la solicitud en Desktop; la conexion se confirma al recibirla por MCP.')
    }else{Show-PMMDesktopDispatchHelp $d}

}

function Set-PMMDesktopDialogActions($View) {
    $close=[Windows.Controls.Button]::new();$close.Content=L 'Close' 'Cerrar';$close.IsCancel=$true;$close.MinWidth=110
    $dialog=$View.window;$close.Add_Click({$dialog.Close()}.GetNewClosure());[void]$View.actions.Children.Add($close)
    $wrap=[Windows.Controls.WrapPanel]::new();$wrap.Margin=[Windows.Thickness]::new(0,14,0,0)
    # Buttons share the scrolling body, so narrow windows never clip setup actions.
    [void]$View.body.Children.Add($wrap);$View.actions=$wrap
}


function Initialize-PMMDesktopProject {
  & (Join-Path $Script:Root 'Modules/MCP/Export-PMMMCPConfig.ps1') -Root $Script:Root -Enable|Out-Null
  $generated=[IO.File]::ReadAllText((Join-Path (Get-PMMMCPRoot) 'codex-mcp.toml'))
  $folder=Resolve-PMMMCPPath (Get-PMMDesktopProjectPath) '.codex'
  $path=Resolve-PMMMCPPath $folder 'config.toml'
  $existing=if(Test-Path -LiteralPath $path){[IO.File]::ReadAllText($path)}else{''}
  if($existing -match '(?m)^\s*\[mcp_servers\.pmm\]\s*$'){
    if(-not$existing.Contains($generated.Trim())){throw 'This Workspace project already has a different PMM MCP entry. Review Workspace/.codex/config.toml and Workspace/MCP/codex-mcp.toml; it was preserved.'}
    return
  }
  [void][IO.Directory]::CreateDirectory($folder)
  $expected=$existing
  if((Test-Path -LiteralPath $path) -and [IO.File]::ReadAllText($path) -cne $expected){throw 'Project configuration changed during setup.'}
  [IO.File]::WriteAllText($path,($existing+[Environment]::NewLine+'# PMM local tools; this does not authorize AI inference.'+[Environment]::NewLine+$generated),[Text.UTF8Encoding]::new($false))
}
