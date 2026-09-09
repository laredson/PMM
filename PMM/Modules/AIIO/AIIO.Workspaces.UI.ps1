
# One reusable editor with per-area selection; no case files are moved.
$Script:PMMCaseArea='HELP'
$Script:PMMAreaSelections=@{}
$Script:PMMAreaHosts=@{}
function Get-PMMCaseArea([string]$Type){
    switch($Type){'NEW_MOD'{'CREATE'};'FIX_MOD'{'FIX'};'COMPATIBILITY'{'MERGE'};default{'HELP'}}
}
function Get-PMMAIIOCaseRows {
    return ,@(Get-PMMAIIOCases|Where-Object{(Get-PMMCaseArea $_.Type) -eq $Script:PMMCaseArea}|ForEach-Object{
        [pscustomobject]@{CaseId=[string]$_.CaseId;Title=[string]$_.Title;LastStep=[string]$_.LastAction;NextStep=(Get-PMMAIIOCaseNextLabel ([string]$_.NextAction))}
    })
}
function Switch-PMMCaseArea([string]$Area){
    if(-not $Script:PMMAreaHosts.ContainsKey($Area)){return}
    if($Script:PMMCaseEditor.Parent -eq $Script:PMMAreaHosts[$Area]){return}
    if($Script:PMMAIIOCaseSelectedId){
        Save-PMMAIIOCaseEditor
        $Script:PMMAreaSelections[$Script:PMMCaseArea]=$Script:PMMAIIOCaseSelectedId
    }
    foreach($hostPanel in $Script:PMMAreaHosts.Values){$hostPanel.Content=$null}
    $Script:PMMCaseArea=$Area
    $Script:PMMAIIOCaseSelectedId=''
    $Script:PMMAreaHosts[$Area].Content=$Script:PMMCaseEditor
    $keep='';if($Script:PMMAreaSelections.ContainsKey($Area)){$keep=$Script:PMMAreaSelections[$Area]}
    Refresh-PMMAIIOCaseList $keep
}
function New-PMMAreaTab([string]$Header,[string]$Area){
    $tab=[Windows.Controls.TabItem]::new();$tab.Header=$Header;$tab.Tag=$Area
    $layout=[Windows.Controls.DockPanel]::new();$tab.Content=$layout
    $actions=[Windows.Controls.StackPanel]::new();$actions.Orientation='Horizontal';$actions.Margin=[Windows.Thickness]::new(8)
    $settings=[Windows.Controls.Button]::new();$settings.Content='AI / MCP Settings'
    $settings.Add_Click({$Script:MainTabs.SelectedItem=$Script:PMMSettingsTab;$Script:PMMSettingsTabs.SelectedItem=$Script:PMMAISettingsTab})
    $candidates=[Windows.Controls.Button]::new();$candidates.Content=L 'Candidates' 'Candidatos';$candidates.Margin=[Windows.Thickness]::new(8,0,0,0)
    $candidates.Add_Click({try{Show-PMMStructuredCandidates}catch{Handle-UIError $_ 'Candidates'}})
    [void]$actions.Children.Add($settings);[void]$actions.Children.Add($candidates)
    [Windows.Controls.DockPanel]::SetDock($actions,'Top');[void]$layout.Children.Add($actions)
    $hostPanel=[Windows.Controls.ContentControl]::new();[void]$layout.Children.Add($hostPanel)
    $Script:PMMAreaHosts[$Area]=$hostPanel
    return $tab
}
function Initialize-PMMWorkspaces {
    if(-not $Script:PMMAIIOCaseWorkspaceInitialized){Initialize-PMMAIIOCaseWorkspaceUI}
    $main=$Script:MainTabs;$help=$Script:TabAIHelp
    $caseTab=$Script:AIHelpTabs.Items[0];$caseTab.Tag='CASES'
    $Script:PMMHelpCaseTab=$caseTab
    $Script:PMMHelpFeedbackTab=$Script:AIHelpTabs.Items[1];$Script:PMMHelpFeedbackTab.Tag='FEEDBACK'
    $Script:PMMHelpThemeTab=$Script:AIHelpTabs.Items[2];$Script:PMMHelpThemeTab.Tag='THEME'
    $Script:PMMCaseEditor=$caseTab.Content;$caseTab.Content=$null
    $helpHost=[Windows.Controls.ContentControl]::new();$caseTab.Content=$helpHost
    $caseTab.Header=L 'Research cases' 'Casos de investigacion'
    $Script:PMMAreaHosts['HELP']=$helpHost
    $help.Header='Help';$help.Tag='HELP'
    $merge=$main.Items[0];$merge.Name='TabMerge';$merge.Tag='MERGE';$Script:PMMMergeTab=$merge
    $fix=$Script:TabFixLab;$fix.Tag='FIX'
    foreach($pair in @(@($merge,'MERGE'),@($fix,'FIX'))){
        $tab=$pair[0];$content=$tab.Content;$tab.Content=$null
        $tabs=[Windows.Controls.TabControl]::new()
        $flow=[Windows.Controls.TabItem]::new();$flow.Header=L 'Workflow' 'Trabajo';$flow.Content=$content
        [void]$tabs.Items.Add($flow);[void]$tabs.Items.Add((New-PMMAreaTab (L 'AI assistant' 'Asistente IA') $pair[1]))
        $tab.Content=$tabs
    }
    $creation=[Windows.Controls.TabItem]::new();$creation.Header='Mod Creation';$creation.Name='TabModCreation';$creation.Tag='CREATE'
    $tabs=[Windows.Controls.TabControl]::new()
    [void]$tabs.Items.Add((New-PMMAreaTab (L 'Projects' 'Proyectos') 'CREATE'))
    $tools=[Windows.Controls.TabItem]::new();$tools.Header=L 'Tools' 'Herramientas';$tools.Name='TabModdingTools'
    $tools.Content=New-PMMDependencyPanel
    [void]$tabs.Items.Add($tools);$creation.Content=$tabs
    $main.Items.Insert($main.Items.IndexOf($help),$creation)
    $settings=$main.Items[$main.Items.Count-1];$settings.Name='TabSettings'
    $generalContent=$settings.Content;$settings.Content=$null
    $settingsTabs=[Windows.Controls.TabControl]::new()
    $general=[Windows.Controls.TabItem]::new();$general.Header=L 'General' 'General';$general.Content=$generalContent
    [void]$settingsTabs.Items.Add($general)
    $aiSettings=$Script:AIHelpTabs.Items[$Script:AIHelpTabs.Items.Count-1]
    $Script:AIHelpTabs.Items.Remove($aiSettings);$aiSettings.Header='AI / MCP';$aiSettings.Name='TabAISettings'
    [void]$settingsTabs.Items.Add($aiSettings);$settings.Content=$settingsTabs
    $permissions=[Windows.Controls.TabItem]::new();$permissions.Header=L 'Installation permissions' 'Permisos de instalacion'
    $panel=[Windows.Controls.StackPanel]::new();$panel.Margin=[Windows.Thickness]::new(20)
    $revoke=[Windows.Controls.Button]::new();$revoke.Content=L 'Ask before future dependency installations' 'Preguntar antes de futuras instalaciones de dependencias';$revoke.HorizontalAlignment='Left'
    $revoke.Add_Click({Set-PMMDependencyPolicy 'ask';$this.Content=L 'Permission revoked' 'Permiso revocado'})
    [void]$panel.Children.Add($revoke);$permissions.Content=$panel;[void]$settingsTabs.Items.Add($permissions)
    $Script:PMMAISettingsTab=$aiSettings;$Script:PMMSettingsTab=$settings;$Script:PMMSettingsTabs=$settingsTabs
    $main.Add_SelectionChanged({
        if($_.OriginalSource -ne $Script:MainTabs){return}
        $tag=[string]$Script:MainTabs.SelectedItem.Tag
        if($tag -in @('MERGE','FIX','CREATE','HELP')){Switch-PMMCaseArea $tag}
    })
    if(-not $main.SelectedItem){$main.SelectedItem=$merge}
    Switch-PMMCaseArea ([string]$main.SelectedItem.Tag)
}

function Show-PMMStructuredCandidates {
    $case=Get-PMMAIIOSelectedCase
    if(-not $case){throw 'Select a case first.'}
    $view=New-PMMThemedDialog (L 'Case candidates' 'Candidatos del caso')
    $items=@(Get-PMMMCPAssetCandidates $case.CaseId)
    $note=[Windows.Controls.TextBlock]::new();$note.TextWrapping='Wrap'
    $note.Text=if($items.Count){L 'Built PAKs remain untested in the game. Open a candidate to review its manifest and hashes.' 'Los PAK construidos siguen sin probarse en el juego. Abre un candidato para revisar su manifiesto y hashes.'}else{L 'No structured candidate has been built for this case.' 'Todavia no hay un candidato estructurado para este caso.'}
    [void]$view.body.Children.Add($note)
    foreach($item in $items){
        $button=[Windows.Controls.Button]::new();$button.Content=$item.candidateId.Substring(0,8)+' - '+$item.status;$button.Margin=[Windows.Thickness]::new(0,8,0,0)
        $button.Tag=Get-PMMMCPAssetCandidate $case.CaseId $item.candidateId
        $button.Add_Click({param($sender,$e)Start-Process explorer.exe -ArgumentList ('"'+[string]$sender.Tag+'"')})
        [void]$view.body.Children.Add($button)
    }
    $close=[Windows.Controls.Button]::new();$close.Content=L 'Close' 'Cerrar';$close.MinWidth=110;$close.IsCancel=$true
    $window=$view.window;$close.Add_Click({$window.Close()}.GetNewClosure());[void]$view.actions.Children.Add($close)
    [void]$view.window.ShowDialog()
}

function Add-PMMCaseAreaContext([string]$CaseId){
    $rows=@()
    if($Script:PMMCaseArea -eq 'MERGE' -and (Get-Command Get-SelectedPMMLibraryEntries -ErrorAction SilentlyContinue)){$rows=@(Get-SelectedPMMLibraryEntries)}
    elseif($Script:PMMCaseArea -eq 'FIX' -and (Get-Command Get-PMMFixLabSelectedCandidate -ErrorAction SilentlyContinue)){$r=Get-PMMFixLabSelectedCandidate;if($r){$rows=@($r)}}
    foreach($row in @($rows|Select-Object -First 32)){
        if($row.PSObject.Properties.Name -contains 'Path' -and [IO.Path]::GetExtension([string]$row.Path) -ieq '.pak' -and (Test-Path -LiteralPath $row.Path)){
            Add-PMMAIIOCaseModReference $CaseId ([string]$row.Path) 'FULL_PAK'|Out-Null
        }
    }
}
