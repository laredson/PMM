function Update-PMMCaseAgentUI($Case,$View) {
  (Get-PMMAIIOCaseControl 'PnlMCPReply').Visibility='Visible'
  $message=$View.Message
  if($message -like 'Codex runtime is unavailable*'){$message=L 'The previous request could not find Codex. Retry with this PMM update; desktop runtime detection is now included.' 'La peticion anterior no encontraba Codex. Reintenta con esta actualizacion de PMM, que ya detecta el runtime de escritorio.'}
  $state=switch($View.Status){
    'Starting'{L 'Connecting' 'Conectando'}
    'Running'{L 'Investigating' 'Investigando'}
    'Paused'{L 'Paused' 'En pausa'}
    'Interrupted'{L 'Interrupted' 'Interrumpido'}
    'Stale'{L 'Evidence changed' 'Evidencia modificada'}
    'AwaitingValidation'{L 'Response ready for review' 'Respuesta lista para revisar'}
    'Cancelled'{L 'Cancelled' 'Cancelado'}
    'NeedsInput'{L 'Input required' 'Necesita una respuesta'}
    default{$View.Status}
  }
  $label='GPT - '+$state+': '+$message
  (Get-PMMAIIOCaseControl 'TxtMCPReplyStatus').Text=$label
  $response=Get-PMMAIIOCaseControl 'TxtMCPResponse'
  if($response.Text -cne $View.Response){$response.Text=$View.Response}
  (Get-PMMAIIOCaseControl 'TxtProgress').Text=$label
  (Get-PMMAIIOCaseControl 'TxtStatus').Text=$label
  (Get-PMMAIIOCaseControl 'TxtListStatus').Text=$Case.Type+' | '+$state
  $bar=Get-PMMAIIOCaseControl 'PrgProgress';$bar.IsIndeterminate=$View.Running
  $bar.Value=if($View.Status -eq 'AwaitingValidation'){100}else{0}
  (Get-PMMAIIOCaseControl 'BtnCancel').IsEnabled=$View.Running
  if($Script:PMMAIIOCaseUI.ContainsKey('BtnAgentOpen')){(Get-PMMAIIOCaseControl 'BtnAgentOpen').IsEnabled=[bool]$View.ThreadId}
}
function Initialize-PMMCaseAgentUI {
  $replyPanel=Get-PMMAIIOCaseControl 'PnlMCPReply'
  $actions=[Windows.Controls.WrapPanel]::new();$actions.Margin=[Windows.Thickness]::new(0,4,0,4)
  $open=[Windows.Controls.Button]::new();$open.Content=L 'Open conversation' 'Abrir conversacion';$open.IsEnabled=$false
  $open.ToolTip=L 'Open the same conversation in GPTD. Shared control while it is open depends on the installed desktop runtime.' 'Abre la misma conversacion en GPTD. El control compartido mientras este abierta depende del runtime de escritorio instalado.'
  $open.Add_Click({try{
    $case=Get-PMMAIIOSelectedCase;if(-not$case){return}
    $session=Get-PMMCaseRepairSession $case.CaseId
    $d=Get-PMMDesktopDispatch $case.CaseId
    if($d -and $d.threadId){[void](Open-PMMDesktopLink (New-PMMDesktopLink '' $d.threadId) (Get-PMMCaseClient $case))}
    elseif($session -and $session.ThreadId){[void](Open-PMMDesktopLink ('codex://threads/'+$session.ThreadId) 'CODEX_DESKTOP')}
  }catch{Handle-UIError $_ 'GPTD'}})
  $Script:PMMAIIOCaseUI['BtnAgentOpen']=$open
  $policy=[Windows.Controls.Button]::new();$policy.Content=L 'AI level / connection...' 'Nivel de IA / conexion...';$policy.Margin=[Windows.Thickness]::new(6,0,0,0)
  $policy.Add_Click({try{Show-PMMAIPolicyDialog}catch{Handle-UIError $_ 'AI policy'}})
  [void]$actions.Children.Add($open);[void]$replyPanel.Children.Add($actions)
  (Get-PMMAIIOCaseControl 'BtnCancel').Add_Click({try{
    $case=Get-PMMAIIOSelectedCase;if(-not$case){return}
    $session=Get-PMMCaseRepairSession $case.CaseId
    if($session){Stop-PMMRepairSession $session.Id|Out-Null;Update-PMMMCPReplyUI}
  }catch{Handle-UIError $_ 'Stop GPT'}})
  Initialize-PMMChatPanel
}


function Update-PMMChatPanel($Case) {
  if(-not$Script:PMMAIIOCaseUI.ContainsKey('ChatTranscript')){return}
  $box=Get-PMMAIIOCaseControl 'ChatTranscript'
  $stamp=$Case.CaseId+'|'+[DateTime]::UtcNow.ToString('yyyyMMddHHmmss')
  if($box.Tag -eq $stamp){return};$box.Tag=$stamp
  $text=Get-PMMCaseChatText $Case.CaseId
  $session=Get-PMMCaseRepairSession $Case.CaseId
  if($session -and (Test-PMMRepairWorkerAlive $session)){
    $view=Get-PMMCaseAgentView $Case
    $text+=[Environment]::NewLine+'Current response:'+ [Environment]::NewLine+$view.Response
  }
  if($box.Text -cne $text){$box.Text=$text}
  $build=Get-PMMAIIOCaseControl 'ChatBuild'
  if($build.Tag -cne $Case.CaseId){$build.Tag=$Case.CaseId;$build.IsChecked=[bool]($session -and $session.Authorization.Build -and $session.Authorization.Download)}
  $policy=Get-PMMAIPolicy
  $stage=[string](Get-PMMAIIOCaseControl 'ChatStage').SelectedItem
  (Get-PMMAIIOCaseControl 'ChatRoute').Text=(L 'Next internal request: ' 'Proxima peticion interna: ')+$policy.($stage+'Model')+' / '+$policy.($stage+'Effort')+' / standard'
  (Get-PMMAIIOCaseControl 'ChatSend').IsEnabled=((Get-PMMCaseClient $Case) -eq 'CODEX' -and [bool](Get-PMMAnalysisValue $policy InternalEnabled $false) -and -not($session -and (Test-PMMRepairWorkerAlive $session)))
  $open=Get-PMMAIIOCaseControl 'BtnAgentOpen'
  if($open){$dispatch=Get-PMMDesktopDispatch $Case.CaseId;$open.IsEnabled=[bool](($session -and $session.ThreadId) -or ($dispatch -and $dispatch.threadId))}
}
function Initialize-PMMChatPanel {
  $reply=Get-PMMAIIOCaseControl 'PnlMCPReply'
  $tabs=[Windows.Controls.TabControl]::new()
  $latest=[Windows.Controls.TabItem]::new();$latest.Header=L 'Latest response' 'Ultima respuesta'
  $old=[Windows.Controls.StackPanel]::new()
  foreach($child in @($reply.Children)){$reply.Children.Remove($child);[void]$old.Children.Add($child)}
  $latest.Content=$old;[void]$tabs.Items.Add($latest)
  $chat=[Windows.Controls.TabItem]::new();$chat.Header=L 'AI chat' 'Chat IA'
  $body=[Windows.Controls.StackPanel]::new();$chat.Content=$body;[void]$tabs.Items.Add($chat);[void]$reply.Children.Add($tabs)
  $Script:PMMAIIOCaseUI['ChatTabs']=$tabs
  $hint=[Windows.Controls.TextBlock]::new();$hint.TextWrapping='Wrap'
  $hint.Text=L 'Desktop controls the conversation by default. Internal requests are optional and use the connected account allowance. This journal shows public messages, model changes and PMM operations; private reasoning is not available.' 'Desktop controla la conversacion por defecto. Las peticiones internas son opcionales y consumen el uso de la cuenta conectada. Este historial muestra mensajes, cambios de modelo y operaciones PMM; el razonamiento privado no esta disponible.'
  [void]$body.Children.Add($hint)
  $transcript=[Windows.Controls.TextBox]::new();$transcript.IsReadOnly=$true;$transcript.AcceptsReturn=$true;$transcript.TextWrapping='Wrap';$transcript.Height=280;$transcript.VerticalScrollBarVisibility='Auto'
  $Script:PMMAIIOCaseUI['ChatTranscript']=$transcript;[void]$body.Children.Add($transcript)
  $refresh=[Windows.Controls.Button]::new();$refresh.Content=L 'Refresh conversation (no inference)' 'Actualizar conversacion (sin inferencia)'
  $refresh.Add_Click({try{
    $case=Get-PMMAIIOSelectedCase;if(-not$case){return}
    $folder=Join-PMMPath 'Cache' 'DeepRequests';[void][IO.Directory]::CreateDirectory($folder)
    $path=Join-Path $folder ([guid]::NewGuid().ToString('N')+'.json')
    Write-PMMJsonAtomic $path @{Action='ReadConversation';CaseId=$case.CaseId}
    $started=Start-PMMBackgroundOperation -Operation DeepSource -RequestPath $path -OnSuccess {param($r)$c=Get-PMMAIIOSelectedCase;if($c){(Get-PMMAIIOCaseControl 'ChatTranscript').Tag='';Update-PMMChatPanel $c};Set-PMMAIIOCaseUiStatus $r.ResultText} -OnFailure {param($message)Set-PMMAIIOCaseUiStatus $message}
    if(-not$started){Set-PMMAIIOCaseUiStatus (L 'Another operation is running; refresh after it finishes.' 'Hay otra operacion en curso; actualiza cuando termine.')}
  }catch{Handle-UIError $_ 'Conversation'}})
  [void]$body.Children.Add($refresh)
  $advanced=[Windows.Controls.Expander]::new();$advanced.Header=L 'Advanced: internal connection and chat' 'Avanzado: conexion y chat internos';$advanced.IsExpanded=$false
  $advancedBody=[Windows.Controls.StackPanel]::new();$advanced.Content=$advancedBody
  [void]$body.Children.Add($advanced);$Script:PMMAIIOCaseUI['ChatAdvanced']=$advanced
  $transport=Get-PMMAIIOCaseControl 'CmbTransport';$row=$transport.Parent;$index=$row.Children.IndexOf($transport)
  $transportLabel=$row.Children[$index-1]
  if($transportLabel -is [Windows.Controls.TextBlock]){$row.Children.Remove($transportLabel);[void]$advancedBody.Children.Add($transportLabel)}
  $row.Children.Remove($transport);[void]$advancedBody.Children.Add($transport)
  $settings=[Windows.Controls.Button]::new();$settings.Content=L 'Internal AI account and model settings...' 'Cuenta y modelos de IA interna...'
  $settings.Add_Click({try{Show-PMMAIPolicyDialog;$c=Get-PMMAIIOSelectedCase;if($c){(Get-PMMAIIOCaseControl 'ChatTranscript').Tag='';Update-PMMChatPanel $c}}catch{Handle-UIError $_ 'AI settings'}})
  [void]$advancedBody.Children.Add($settings)
  $stage=[Windows.Controls.ComboBox]::new();$stage.ItemsSource=@('Routine','Repair','Complex');$stage.SelectedIndex=0;$Script:PMMAIIOCaseUI['ChatStage']=$stage
  $stage.Add_SelectionChanged({$c=Get-PMMAIIOSelectedCase;if($c){(Get-PMMAIIOCaseControl 'ChatTranscript').Tag='';Update-PMMChatPanel $c}})
  [void]$advancedBody.Children.Add($stage)
  $route=[Windows.Controls.TextBlock]::new();$route.TextWrapping='Wrap';$Script:PMMAIIOCaseUI['ChatRoute']=$route;[void]$advancedBody.Children.Add($route)
  $build=[Windows.Controls.CheckBox]::new();$build.Content=L 'Allow candidate builds and update downloads for this session' 'Permitir crear candidatos y descargar actualizaciones en esta sesion';$build.IsChecked=$false;$Script:PMMAIIOCaseUI['ChatBuild']=$build;[void]$advancedBody.Children.Add($build)
  $prompt=[Windows.Controls.TextBox]::new();$prompt.AcceptsReturn=$true;$prompt.TextWrapping='Wrap';$prompt.Height=85;$prompt.MaxLength=16000;$prompt.VerticalScrollBarVisibility='Auto'
  $Script:PMMAIIOCaseUI['ChatPrompt']=$prompt;[void]$advancedBody.Children.Add($prompt)
  $send=[Windows.Controls.Button]::new();$send.Content=L 'Send internal request' 'Enviar peticion interna';$send.IsEnabled=$false;$Script:PMMAIIOCaseUI['ChatSend']=$send
  $send.Add_Click({try{
    [void](Save-PMMAIIOCaseEditor)
    $c=Get-PMMAIIOSelectedCase;if(-not$c){return}
    if((Get-PMMCaseClient $c) -ne 'CODEX'){throw 'Select Advanced: internal agent as the destination first.'}
    if(-not(Get-PMMAnalysisValue (Get-PMMAIPolicy) InternalEnabled $false)){throw 'Enable internal requests in Advanced AI settings first.'}
    $options=New-PMMDeepAnalysisOptions;$options.AutomaticSolution=[bool](Get-PMMAIIOCaseControl 'ChatBuild').IsChecked
    $session=Get-OrCreate-PMMCaseRepairSession $c.CaseId $options
    if(Test-PMMRepairWorkerAlive $session){throw 'Wait for the current response before sending another prompt.'}
    $session.Authorization.Build=$options.AutomaticSolution;$session.Authorization.Download=$options.AutomaticSolution;Save-PMMRepairSession $session
    $box=Get-PMMAIIOCaseControl 'ChatPrompt'
    $retry=$box.Tag
    $stage=[string](Get-PMMAIIOCaseControl 'ChatStage').SelectedItem
    if(-not$retry -or $retry.Text -cne $box.Text -or $retry.Stage -cne $stage){$retry=@{Id=[guid]::NewGuid().ToString('N');Text=$box.Text;Stage=$stage};$box.Tag=$retry}
    $p=New-PMMChatPrompt $session.Id $box.Text ([string](Get-PMMAIIOCaseControl 'ChatStage').SelectedItem) $retry.Id
    Start-PMMRepairAgentJob $session.Id $p.Id|Out-Null
    $box.Text='';$box.Tag=$null
    (Get-PMMAIIOCaseControl 'ChatTranscript').Tag='';Update-PMMChatPanel $c
  }catch{Handle-UIError $_ 'AI chat'}})
  [void]$advancedBody.Children.Add($send)
}
