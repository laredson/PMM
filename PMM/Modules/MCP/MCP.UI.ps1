# Called after the main window exists. No network or background work on the dispatcher.
. (Join-Path $Script:Root 'Modules\MCP\MCP.Service.ps1')
$enable=$Window.FindName('BtnMCPEnable')
$disable=$Window.FindName('BtnMCPDisable')
$open=$Window.FindName('BtnMCPOpen')
$status=$Window.FindName('TxtMCPStatus')
if($status){try{$status.Text=if(Get-PMMMCPEnabled){L 'MCP enabled for this PMM installation.' 'MCP habilitado para esta instalacion de PMM.'}else{L 'MCP disabled.' 'MCP deshabilitado.'}}catch{$status.Text=L 'MCP configuration needs repair; regenerate it below.' 'La configuracion MCP necesita reparacion; regenerala abajo.'}}
if($enable){$enable.Add_Click({
    try{
        & (Join-Path $Script:Root 'Modules\MCP\Export-PMMMCPConfig.ps1') -Enable | Out-Null
        $Window.FindName('TxtMCPStatus').Text=L 'Enabled. Add the generated configuration to your MCP client once, then restart its connection. Files: Workspace\MCP.' 'Habilitado. Agrega la configuracion generada a tu cliente MCP una vez y reinicia su conexion. Archivos: Workspace\MCP.'
    }catch{Handle-UIError $_ 'MCP'}
})}
if($disable){$disable.Add_Click({
    try{
        Set-PMMMCPEnabled $false
        $Window.FindName('TxtMCPStatus').Text=L 'Disabled. Further tool calls are rejected. An operation already running may finish.' 'Deshabilitado. Se rechazaran nuevas llamadas. Una operacion ya iniciada puede terminar.'
    }catch{Handle-UIError $_ 'MCP'}
})}
if($open){$open.Add_Click({
    try{
        $dir=& (Join-Path $Script:Root 'Modules\MCP\Export-PMMMCPConfig.ps1')
        Start-Process explorer.exe -ArgumentList ('"'+$dir+'"')
    }catch{Handle-UIError $_ 'MCP'}
})}


. (Join-Path $Script:Root 'Modules\MCP\MCP.Client.ps1')
function Update-PMMMCPClientStatus {
    $text=$Window.FindName('TxtMCPClientStatus')
    if($text){try{$text.Text=if(Get-PMMMCPClient){'Codex console configured. Only cases targeting Codex console start this runner; Desktop and other MCP clients remain separate.'}else{'External client mode: publishing waits for an AI to read and answer through MCP.'}}catch{$text.Text=$_.Exception.Message}}
}
Update-PMMMCPClientStatus
$connect=$Window.FindName('BtnMCPConnectCodex')
if($connect){$connect.Content=L 'Configure Codex console' 'Configurar Codex por consola';$connect.Add_Click({try{Set-PMMMCPClient $true;Set-PMMMCPEnabled $true;Update-PMMMCPClientStatus}catch{Handle-UIError $_ 'Codex'}})}
$external=$Window.FindName('BtnMCPExternal')
if($external){$external.Content=L 'Other MCP client' 'Otro cliente MCP';$external.Add_Click({try{Set-PMMMCPClient $false;Update-PMMMCPClientStatus}catch{Handle-UIError $_ 'Codex'}})}
. (Join-Path $Script:Root 'Modules\MCP\MCP.Reply.UI.ps1')
if(-not(Get-Variable PMMMMCPReplyTimer -Scope Script -ErrorAction SilentlyContinue)){
    $Script:PMMMMCPReplyTimer=[Windows.Threading.DispatcherTimer]::new()
    $Script:PMMMMCPReplyTimer.Interval=[TimeSpan]::FromSeconds(1)
    $Script:PMMMMCPReplyTimer.Add_Tick({Update-PMMMCPReplyUI})
    $Script:PMMMMCPReplyTimer.Start()
    $Window.Add_Closed({$Script:PMMMMCPReplyTimer.Stop()})
}

. (Join-Path $Script:Root 'Modules\Unreal\Unreal.UI.ps1')
