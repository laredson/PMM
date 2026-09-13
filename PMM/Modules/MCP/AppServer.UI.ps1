function Show-PMMChatGPTCase {
  [void](Save-PMMAIIOCaseEditor)
  $case=Get-PMMAIIOSelectedCase
  if(-not$case){throw (L 'Select a case first.' 'Selecciona primero un caso.')}
  if($case.SelectedStep -gt 0 -and $case.SelectedStep -lt $case.CurrentStep){throw (L 'Return to the current case step before starting an investigation.' 'Vuelve al paso actual del caso antes de iniciar la investigacion.')}
  if($case.Type -in @('FIX_MOD','COMPATIBILITY') -and -not@($case.References.Mods).Count){
    throw (L 'Attach the mod with Add PAK, or create the case from the library context menu, before sending it to GPT.' 'Adjunta el mod con Agregar PAK, o crea el caso desde el menu contextual de la biblioteca, antes de enviarlo a GPT.')
  }
  $options=New-PMMDeepAnalysisOptions;$options.AutomaticSolution=$true
  $session=Get-OrCreate-PMMCaseRepairSession $case.CaseId $options
  Set-PMMMCPEnabled $true
  try{
    Start-PMMRepairAgentJob $session.Id|Out-Null
  }finally{
    $Script:DeepRepairSessionId=$session.Id
    Update-PMMMCPReplyUI
  }
}
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
    if($session -and $session.ThreadId){[void](Open-PMMDesktopLink ('codex://threads/'+$session.ThreadId))}
  }catch{Handle-UIError $_ 'GPTD'}})
  $Script:PMMAIIOCaseUI['BtnAgentOpen']=$open
  $policy=[Windows.Controls.Button]::new();$policy.Content=L 'AI level / connection...' 'Nivel de IA / conexion...';$policy.Margin=[Windows.Thickness]::new(6,0,0,0)
  $policy.Add_Click({try{Show-PMMAIPolicyDialog}catch{Handle-UIError $_ 'AI policy'}})
  [void]$actions.Children.Add($open);[void]$actions.Children.Add($policy);[void]$replyPanel.Children.Add($actions)
  (Get-PMMAIIOCaseControl 'BtnCancel').Add_Click({try{
    $case=Get-PMMAIIOSelectedCase;if(-not$case){return}
    $session=Get-PMMCaseRepairSession $case.CaseId
    if($session){Stop-PMMRepairSession $session.Id|Out-Null;Update-PMMMCPReplyUI}
  }catch{Handle-UIError $_ 'Stop GPT'}})
}
