param([string]$Repository=([IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))))
Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
Add-Type -AssemblyName PresentationFramework,PresentationCore,WindowsBase
$app=Join-Path $Repository 'PMM'
$Script:Root=Join-Path $Repository ('Development\TestResults\MCP-UI-'+[guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory((Join-Path $Script:Root 'Modules\MCP'))
[void][IO.Directory]::CreateDirectory((Join-Path $Script:Root 'Modules\AIIO'))
[void][IO.Directory]::CreateDirectory((Join-Path $Script:Root 'Modules'))
Copy-Item (Join-Path $app 'Modules\*') (Join-Path $Script:Root 'Modules') -Recurse -Force
[void][IO.Directory]::CreateDirectory((Join-Path $Script:Root 'Resources\Unreal'))
Copy-Item (Join-Path $app 'Resources\Unreal\profile.json') (Join-Path $Script:Root 'Resources\Unreal\profile.json')

foreach($name in @('MCP.Reference.ps1','MCP.Exchange.ps1','MCP.Client.ps1','MCP.Reply.UI.ps1','MCP.Service.ps1','Export-PMMMCPConfig.ps1')){Copy-Item (Join-Path $app ('Modules\MCP\'+$name)) (Join-Path $Script:Root ('Modules\MCP\'+$name))}
Copy-Item (Join-Path $app 'Modules\AIIO\AIIO.SessionService.ps1') (Join-Path $Script:Root 'Modules\AIIO\AIIO.SessionService.ps1')
. (Join-Path $app 'Modules\AIIO\AIIO.SessionService.ps1')
function L([string]$English,[string]$Spanish){return $English}
function Handle-UIError($Failure,[string]$Title){throw $Failure}
[xml]$xaml=Get-Content (Join-Path $app 'Resources\UI\MainWindow.xaml') -Raw
$reader=[Xml.XmlNodeReader]::new($xaml)
try{$Window=[Windows.Markup.XamlReader]::Load($reader)}finally{$reader.Dispose()}
try{
    . (Join-Path $app 'Modules\MCP\MCP.UI.ps1')
    if(Get-PMMMCPEnabled){throw 'Expected disabled by default.'}
    $Window.FindName('BtnMCPEnable').RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Button]::ClickEvent))
    if(-not(Get-PMMMCPEnabled)){throw 'Enable button failed.'}
    foreach($file in @('mcp-config.json','codex-mcp.toml')){
        if(-not(Test-Path (Join-Path (Get-PMMMCPRoot) $file))){throw 'Configuration was not generated.'}
    }
    $Window.FindName('BtnMCPDisable').RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Button]::ClickEvent))
    if(Get-PMMMCPEnabled){throw 'Disable button failed.'}
    'invalid json' | Set-Content (Join-Path (Get-PMMMCPRoot) 'settings.json')
    . (Join-Path $app 'Modules\MCP\MCP.UI.ps1')
    if($Window.FindName('TxtMCPStatus').Text -notmatch 'repair'){throw 'Corrupt MCP settings must not prevent startup.'}
    Write-Output 'MCP_UI_REGRESSION_OK: default disabled, enable, config export, disable, corrupt settings.'
}finally{$Window.Close()}

