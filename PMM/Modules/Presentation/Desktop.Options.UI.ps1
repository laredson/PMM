function Initialize-PMMDesktopOptionsUI {
    $row=(Get-PMMAIIOCaseControl 'BtnHandoff').Parent
    $panel=[Windows.Controls.WrapPanel]::new()
    foreach($spec in @(@('CmbDesktopMode',(L 'Mode' 'Modo')), @('CmbDesktopSend',(L 'Question' 'Pregunta')))){
        $label=[Windows.Controls.TextBlock]::new();$label.Text=$spec[1];$label.VerticalAlignment='Center';$label.Margin=[Windows.Thickness]::new(8,0,3,0)
        $combo=[Windows.Controls.ComboBox]::new();$combo.Width=175;$combo.DisplayMemberPath='Label';$combo.SelectedValuePath='Value'
        $Script:PMMAIIOCaseUI[$spec[0]]=$combo
        [void]$panel.Children.Add($label);[void]$panel.Children.Add($combo)
    }
    $send=Get-PMMAIIOCaseControl 'CmbDesktopSend'
    $send.ItemsSource=@([pscustomobject]@{Label=(L 'Prepare question' 'Escribir pregunta');Value='DRAFT'},[pscustomobject]@{Label=(L 'Send question' 'Enviar pregunta');Value='SEND'})
    $send.ToolTip=L 'Prepare opens a draft without starting inference. Automatic sending requires a verified Desktop interface; unavailable routes are blocked before publication.' 'Escribir abre un borrador sin iniciar inferencia. El envio automatico requiere un canal Desktop verificado; las rutas no disponibles se bloquean antes de publicar.'
    $refresh=[Windows.Controls.Button]::new();$refresh.Content=L 'Detect modes' 'Detectar modos'
    $refresh.Add_Click({try{$Script:PMMDesktopModesCache=@{Key='';Modes=@()};$Script:PMMDesktopOptionsCase='';Update-PMMDesktopOptionsUI (Get-PMMAIIOSelectedCase)}catch{Handle-UIError $_ 'Desktop modes'}})
    [void]$panel.Children.Add($refresh);[void]$row.Children.Add($panel)
    $hint=[Windows.Controls.TextBlock]::new();$hint.TextWrapping='Wrap';$hint.MaxWidth=750;$hint.Margin=[Windows.Thickness]::new(6,3,6,3)
    $Script:PMMAIIOCaseUI['TxtDesktopConnection']=$hint;[void]$row.Children.Add($hint)
    $Script:PMMDesktopOptionsCase=''
}
function Update-PMMDesktopOptionsUI($Case) {
    if(-not$Case -or -not$Script:PMMAIIOCaseUI.ContainsKey('CmbDesktopMode')){return}
    if($Script:PMMDesktopOptionsCase -eq $Case.CaseId){return}
    $mode=Get-PMMAIIOCaseControl 'CmbDesktopMode'
    $values=@();$app=$null;$reason=''
    try{$app=Get-PMMChatGPTDesktop (Get-PMMCaseClient $Case);$values=@(Get-PMMDesktopModes $app)}catch{$reason=$_.Exception.Message}
    $selected=Get-PMMCaseDesktopMode $Case
    $mode.ItemsSource=@(foreach($value in $values){[pscustomobject]@{Value=$value;Label=$(switch($value){'chat'{'Chat / Quick Chat'}'work'{'ChatGPT Work'}'codex'{'Codex (agent)'}default{$value}})}})
    $mode.SelectedValue=$selected
    # Preserve an unavailable saved preference; never choose a costlier fallback.
    if($selected -notin $values){$mode.ItemsSource=@([pscustomobject]@{Value=$selected;Label=$selected+' ('+(L 'unavailable' 'no disponible')+')'});$mode.SelectedValue=$selected}
    (Get-PMMAIIOCaseControl 'CmbDesktopSend').SelectedValue=Get-PMMCaseDesktopSendMode $Case
    $hint=Get-PMMAIIOCaseControl 'TxtDesktopConnection'
    $hint.Text=if($app){$app.Name+' '+$app.Version+' | '+(L 'Existing Desktop profile; account and limits remain managed there. Automatic send / anonymous instance: unavailable.' 'Perfil Desktop existente; la cuenta y los limites se gestionan alli. Envio automatico / instancia anonima: no disponibles.')}else{(L 'No compatible Desktop detected. ' 'No se detecto un Desktop compatible. ')+$reason}
    $hint.ToolTip=(L 'Project folder: ' 'Carpeta del proyecto: ')+$Script:Root
    $Script:PMMDesktopOptionsCase=$Case.CaseId
}
function Save-PMMDesktopOptionsUI($Case) {
    if(-not$Case -or -not$Script:PMMAIIOCaseUI.ContainsKey('CmbDesktopMode') -or $Script:PMMDesktopOptionsCase -ne $Case.CaseId){return}
    $mode=[string](Get-PMMAIIOCaseControl 'CmbDesktopMode').SelectedValue
    $send=[string](Get-PMMAIIOCaseControl 'CmbDesktopSend').SelectedValue
    if(-not$mode -or $send -notin @('DRAFT','SEND')){return}
    if($mode -ne (Get-PMMCaseDesktopMode $Case) -or $send -ne (Get-PMMCaseDesktopSendMode $Case)){
        $reply=Get-PMMMCPReplyView $Case
        if($Case.ActiveOperation.Running -or ($reply -and $reply.status -eq 'PROCESSING')){throw 'Wait for the active request before changing mode.'}
        $Case|Add-Member -NotePropertyName DesktopMode -NotePropertyValue $mode -Force
        $Case|Add-Member -NotePropertyName DesktopSendMode -NotePropertyValue $send -Force
        Save-PMMAIIOCase $Case|Out-Null
    }
}
function Get-PMMCaseFolderEntries($Case) {
    if(-not$Case){return @()}
    $root=Get-PMMAIIOCasePath $Case.CaseId
    $entries=@(
        [pscustomobject]@{Label=(L 'Case' 'Caso');Path=$root},
        [pscustomobject]@{Label='Handoff';Path=(Get-PMMAIIOCaseHandoffsPath $Case.CaseId)},
        [pscustomobject]@{Label=(L 'Solutions' 'Soluciones');Path=(Join-Path $root 'Solutions')},
        [pscustomobject]@{Label=(L 'Candidates' 'Candidatos');Path=(Join-Path (Get-PMMMCPRoot) ('Candidates/'+$Case.CaseId))},
        [pscustomobject]@{Label=(L 'Fix Lab outputs' 'Resultados Fix Lab');Path=(Join-Path $Script:Root 'Workspace/FixLab/Built')},
        [pscustomobject]@{Label=(L 'Evidence' 'Evidencia');Path=(Get-PMMAIIOCaseEvidencePath $Case.CaseId)},
        [pscustomobject]@{Label=(L 'AI chat history' 'Historial del chat IA');Path=(Join-Path $root 'Chat')}
    )
    if($Case.LegacySessionId){
        $entries+= [pscustomobject]@{Label=(L 'Built mods' 'Mods construidos');Path=(Join-Path (Get-PMMAIIOSessionPath $Case.LegacySessionId) 'artifacts/mod-builds')}
    }
    return $entries
}
function Initialize-PMMCaseFoldersUI {
    $grid=(Get-PMMAIIOCaseControl 'DgCases').Parent
    $footer=@($grid.Children|Where-Object{[Windows.Controls.Grid]::GetRow($_) -eq 2})[0]
    [void]$grid.Children.Remove($footer)
    $stack=[Windows.Controls.StackPanel]::new();[Windows.Controls.Grid]::SetRow($stack,2)
    $box=[Windows.Controls.GroupBox]::new();$box.Header=L 'Folders' 'Carpetas';$box.Margin=[Windows.Thickness]::new(0,6,0,8)
    $links=[Windows.Controls.WrapPanel]::new();$box.Content=$links
    $Script:PMMAIIOCaseUI['CaseFolders']=$links
    [void]$stack.Children.Add($box);[void]$stack.Children.Add($footer);[void]$grid.Children.Add($stack)
    (Get-PMMAIIOCaseControl 'BtnFolder').Visibility='Collapsed'
}
function Update-PMMCaseFoldersUI($Case) {
    $panel=Get-PMMAIIOCaseControl 'CaseFolders';if(-not$panel){return}
    $entries=@(Get-PMMCaseFolderEntries $Case)
    $stamp=(@($entries|ForEach-Object{$_.Path+'|'+[string](Test-Path -LiteralPath $_.Path -PathType Container)}) -join ';')
    if($panel.Tag -ceq $stamp){return};$panel.Tag=$stamp;$panel.Children.Clear()
    foreach($entry in $entries){
        $button=[Windows.Controls.Button]::new();$button.Content=$entry.Label;$button.Tag=$entry.Path;$button.ToolTip=$entry.Path
        $button.Margin=[Windows.Thickness]::new(2);$button.IsEnabled=Test-Path -LiteralPath $entry.Path -PathType Container
        $button.Add_Click({param($sender,$args)try{
            $path=[string]$sender.Tag
            if(-not(Test-Path -LiteralPath $path -PathType Container)){throw 'This folder does not exist yet.'}
            Start-Process explorer.exe -ArgumentList ('"'+$path+'"')
            Set-PMMAIIOCaseUiStatus $path
        }catch{Handle-UIError $_ 'Open case folder'}})
        [void]$panel.Children.Add($button)
    }
}
