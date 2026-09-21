# Move existing controls; handlers, values and names remain attached.
function Move-PMMSettingsElement($Element,$Target){
    if(-not $Element){return}
    $parent=$Element.Parent
    if($parent -is [Windows.Controls.Panel]){$parent.Children.Remove($Element)}
    elseif($parent -is [Windows.Controls.ContentControl]){$parent.Content=$null}
    else{throw 'Unsupported settings container.'}
    [void]$Target.Children.Add($Element)
}
function Move-PMMSettingsCard([string]$Control,$Target){
    $element=$Window.FindName($Control)
    while($element -and $element -isnot [Windows.Controls.Border]){$element=$element.Parent}
    Move-PMMSettingsElement $element $Target
}
function Open-PMMSettings([string]$Id='AI'){
    if($Id -eq 'TabModdingTools'){$Id='INSTALLATIONS'}
    if(-not $Script:PMMSettingsById.ContainsKey($Id)){$Id='AI'}
    $Script:MainTabs.SelectedItem=$Script:PMMSettingsTab
    $Script:PMMSettingsTabs.SelectedItem=$Script:PMMSettingsById[$Id]
}
function New-PMMSettingsSection([string]$Id,[string]$Header){
    $tab=[Windows.Controls.TabItem]::new();$tab.Header=$Header;$tab.Tag=$Id
    $scroll=[Windows.Controls.ScrollViewer]::new();$scroll.VerticalScrollBarVisibility='Auto'
    $panel=[Windows.Controls.StackPanel]::new();$panel.Margin=[Windows.Thickness]::new(12);$scroll.Content=$panel;$tab.Content=$scroll
    [void]$Script:PMMSettingsTabs.Items.Add($tab);$Script:PMMSettingsById[$Id]=$tab
    return $panel
}
function Add-PMMOptionsAccess($Tab,[string]$Area){
    $old=$Tab.Content;$Tab.Content=$null
    $dock=[Windows.Controls.DockPanel]::new()
    $b=[Windows.Controls.Button]::new();$b.Content=L 'Options' 'Opciones';$b.Tag=$Area;$b.HorizontalAlignment='Left';$b.Margin=[Windows.Thickness]::new(8)
    $b.Add_Click({param($sender,$e)Open-PMMSettings ([string]$sender.Tag)})
    [Windows.Controls.DockPanel]::SetDock($b,'Top');[void]$dock.Children.Add($b);[void]$dock.Children.Add($old);$Tab.Content=$dock
}
function Initialize-PMMSettingsWorkspaces {
    $Script:PMMSettingsTab=$Window.FindName('TabSettings')
    $generalContent=$Script:PMMSettingsTab.Content;$Script:PMMSettingsTab.Content=$null
    $Script:PMMSettingsTabs=[Windows.Controls.TabControl]::new();$Script:PMMSettingsTab.Content=$Script:PMMSettingsTabs
    $Script:PMMSettingsById=@{}
    $general=New-PMMSettingsSection 'GENERAL' (L 'General' 'General')
    [void]$general.Children.Add($generalContent)
    $ai=$Window.FindName('TabAISettings');$Script:AIHelpTabs.Items.Remove($ai)
    $ai.Header=L 'AI / MCP' 'IA / MCP';$ai.Tag='AI';[void]$Script:PMMSettingsTabs.Items.Add($ai);$Script:PMMSettingsById['AI']=$ai;$Script:PMMAISettingsTab=$ai
    $install=New-PMMSettingsSection 'INSTALLATIONS' (L 'Installations' 'Instalaciones')
    $Script:PMMInstallationSettingsTab=$Script:PMMSettingsById['INSTALLATIONS']
    $dependency=New-PMMDependencyPanel;$Script:PMMInstallationSettingsTab.Content=$dependency
    Move-PMMSettingsElement ($Window.FindName('PnlBaseDependencySettings')) $Script:PMMDependencyHelpPanel
    $merge=New-PMMSettingsSection 'MERGE' (L 'Mods & Merge' 'Mods y Merge')
    Move-PMMSettingsElement ($Window.FindName('PnlLibrarySettings')) $merge
    $creation=New-PMMSettingsSection 'CREATE' (L 'Mod Creation' 'Creacion de mods')
    Move-PMMSettingsCard 'BtnUnrealPrepare' $creation
    $help=New-PMMSettingsSection 'HELP' (L 'Help' 'Ayuda')
    Move-PMMSettingsCard 'ChkAIIOAutoCreateErrorCases' $help
    Move-PMMSettingsCard 'BtnOpenKnowledge' $help
    $aiPanel=$ai.Content.Content
    $desktopConnect=[Windows.Controls.Button]::new();$desktopConnect.Content=L 'Connect ChatGPT Desktop' 'Conectar ChatGPT Desktop';$desktopConnect.HorizontalAlignment='Left';$desktopConnect.Margin=[Windows.Thickness]::new(0,8,0,12);$desktopConnect.Add_Click({try{Show-PMMDesktopSetup}catch{Handle-UIError $_ 'ChatGPT'}});$aiPanel.Children.Insert(0,$desktopConnect)
    Move-PMMSettingsCard 'BtnBuildGameReference' $aiPanel
    # Remove the obsolete AI settings introduction after moving diagnostics.
    $intro=@($aiPanel.Children|Where-Object {$_ -is [Windows.Controls.TextBlock]}|Select-Object -First 1)
    if($intro.Count){$aiPanel.Children.Remove($intro[0])}
    $extra=[Windows.Controls.WrapPanel]::new()
    foreach($name in @('BtnUnrealInstall','BtnUnrealRunInstaller','BtnUnrealEnginePath','BtnUnrealWwiseSdk','BtnUnrealWwiseIntegration','BtnUnrealGuide')){Move-PMMSettingsElement ($Window.FindName($name)) $extra}
    [void]$Script:PMMDependencyHelpPanel.Children.Add($extra)
    Add-PMMOptionsAccess $Script:PMMHelpCaseTab 'HELP'
    if($Script:TabLibrary){Add-PMMOptionsAccess $Script:TabLibrary 'MERGE'}
}
