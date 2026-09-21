. (Join-Path $PSScriptRoot 'AIIO.CaseNavigation.UI.ps1')
. (Join-Path $PSScriptRoot '../Shared/Settings.Workspaces.UI.ps1')

# One reusable editor with per-area selection; no case files are moved.
$Script:PMMWorkspacesInitialized=$false
$Script:PMMCaseArea='HELP'
$Script:PMMAreaSelections=@{}
$Script:PMMAreaHosts=@{}
function Get-PMMCaseArea([string]$Type){
    switch($Type){'NEW_MOD'{'CREATE'};'FIX_MOD'{'FIX'};'COMPATIBILITY'{'MERGE'};default{'HELP'}}
}
function Get-PMMAIIOCaseRows {
    return @(Get-PMMAIIOCases|Where-Object{(Get-PMMCaseArea $_.Type) -eq $Script:PMMCaseArea}|ForEach-Object{
        [pscustomobject]@{CaseId=[string]$_.CaseId;Title=[string]$_.Title;LastStep=[string]$_.LastAction;NextStep=(Get-PMMAIIOCaseNextLabel ([string]$_.NextAction))}
    })
}
function Switch-PMMCaseArea([string]$Area){
    if(-not $Script:PMMAreaHosts.ContainsKey($Area)){return}
    if($Script:PMMCaseEditor.Parent -eq $Script:PMMAreaHosts[$Area]){return}
    if($Script:PMMAIIOCaseSelectedId){
        [void](Save-PMMAIIOCaseEditor)
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
    $settings=[Windows.Controls.Button]::new();$settings.Content=L 'Options' 'Opciones';$settings.Tag=$Area
    $settings.Add_Click({param($sender,$e) Open-PMMSettings ([string]$sender.Tag)})
    $candidates=[Windows.Controls.Button]::new();$candidates.Content=L 'Candidates' 'Candidatos';$candidates.Margin=[Windows.Thickness]::new(8,0,0,0)
    $candidates.Add_Click({try{Show-PMMStructuredCandidates}catch{Handle-UIError $_ 'Candidates'}})
    $desktop=[Windows.Controls.Button]::new();$desktop.Content=L 'Send to ChatGPT' 'Enviar a ChatGPT';$desktop.Margin=[Windows.Thickness]::new(8,0,0,0)
    $desktop.Add_Click({try{Show-PMMChatGPTCase}catch{Handle-UIError $_ 'ChatGPT'}})
    [void]$actions.Children.Add($desktop)
    [void]$actions.Children.Add($settings);[void]$actions.Children.Add($candidates)
    [Windows.Controls.DockPanel]::SetDock($actions,'Top');[void]$layout.Children.Add($actions)
    $hostPanel=[Windows.Controls.ContentControl]::new();[void]$layout.Children.Add($hostPanel)
    $Script:PMMAreaHosts[$Area]=$hostPanel
    return $tab
}
function Test-PMMFixLabTabSelected { return ($Script:MainTabs.SelectedItem -eq $Script:PMMMergeTab -and $Script:ModsWorkflowTabs.SelectedItem -eq $Script:TabFixLab) }
function Select-PMMFixLabTab {
    $Script:MainTabs.SelectedItem=$Script:PMMMergeTab
    $Script:ModsWorkflowTabs.SelectedItem=$Script:TabFixLab
}
function New-PMMWorkflowTab([string]$Header,$Content,[string]$Tag='MERGE'){
    $tab=[Windows.Controls.TabItem]::new();$tab.Header=$Header;$tab.Tag=$Tag;$tab.Content=$Content;return $tab
}
function Initialize-PMMWorkspaces {
    if($Script:PMMWorkspacesInitialized){return}
    if(-not $Script:PMMAIIOCaseWorkspaceInitialized){Initialize-PMMAIIOCaseWorkspaceUI}
    $main=$Script:MainTabs;$help=$Script:TabAIHelp
    $caseTab=$Script:AIHelpTabs.Items|Where-Object {$_.Name -eq 'TabCaseWorkspace'}|Select-Object -First 1;$caseTab.Tag='CASES';$Script:PMMHelpCaseTab=$caseTab
    $Script:PMMHelpFeedbackTab=$Window.FindName('TabHelpFeedback');$Script:PMMHelpFeedbackTab.Tag='FEEDBACK'
    $Script:PMMHelpThemeTab=$Window.FindName('TabHelpTheme');$Script:PMMHelpThemeTab.Tag='THEME';Initialize-PMMCaseClientSelector
    $Script:PMMCaseEditor=$caseTab.Content;$caseTab.Content=$null;$helpHost=[Windows.Controls.ContentControl]::new();$caseTab.Content=$helpHost
    $caseTab.Header=L 'Research cases' 'Casos de investigacion';$Script:PMMAreaHosts['HELP']=$helpHost;$help.Header=L 'Help' 'Ayuda';$help.Tag='HELP'

    $merge=$Window.FindName('TabMerge');$merge.Name='TabMerge';$merge.Tag='MERGE';$Script:PMMMergeTab=$merge
    $fix=$Script:TabFixLab;$fixContent=$fix.Content;$fix.Content=$null;[void]$main.Items.Remove($fix);$fix.Header=L 'Fix Lab' 'Fix Lab';$fix.Tag='FIX';$fix.Content=$fixContent
    $tabs=[Windows.Controls.TabControl]::new();$Script:ModsWorkflowTabs=$tabs
    # Keep the established library, analysis, build and deploy workspace together.
    # Only auxiliary workflows are split into subtabs.
    $Script:TabLibrary=New-PMMWorkflowTab (L 'Mods & Merge' 'Mods y Merge') $merge.Content
    $Script:UpdatesHost=[Windows.Controls.ContentControl]::new();$Script:TabUpdates=New-PMMWorkflowTab (L 'Updates' 'Actualizaciones') $Script:UpdatesHost
    $Script:TabFixLab=$fix
    $Script:DeepAnalysisHost=[Windows.Controls.ContentControl]::new();$Script:TabDeepAnalysis=New-PMMWorkflowTab (L 'Deep Analysis' 'Analisis profundo') $Script:DeepAnalysisHost
    $Script:TabMergeAI=New-PMMAreaTab (L 'AI Assistant' 'Asistente IA') 'MERGE'
    foreach($tab in @($Script:TabLibrary,$Script:TabUpdates,$Script:TabFixLab,$Script:TabDeepAnalysis,$Script:TabMergeAI)){[void]$tabs.Items.Add($tab)}
    $merge.Content=$tabs

    $creation=[Windows.Controls.TabItem]::new();$creation.Header=L 'Mod Creation' 'Creacion de mods';$creation.Name='TabModCreation';$creation.Tag='CREATE'
    $creationTabs=[Windows.Controls.TabControl]::new();[void]$creationTabs.Items.Add((New-PMMAreaTab (L 'Projects' 'Proyectos') 'CREATE'));$creation.Content=$creationTabs
    $main.Items.Insert($main.Items.IndexOf($help),$creation);Initialize-PMMSettingsWorkspaces
    $main.Add_SelectionChanged({if($_.OriginalSource -ne $Script:MainTabs){return};$tag=[string]$Script:MainTabs.SelectedItem.Tag;if($tag -in @('MERGE','CREATE','HELP')){Switch-PMMCaseArea $tag}})
    $tabs.Add_SelectionChanged({
      if($_.OriginalSource -ne $Script:ModsWorkflowTabs){return}
      if($Script:ModsWorkflowTabs.SelectedItem -eq $Script:TabFixLab){Switch-PMMCaseArea 'FIX';try{Queue-PMMFixLabUiRefresh}catch{}}
      else{Switch-PMMCaseArea 'MERGE'}
    })
    if(-not $main.SelectedItem){$main.SelectedItem=$merge};$tabs.SelectedItem=$Script:TabLibrary
    Switch-PMMCaseArea ([string]$main.SelectedItem.Tag);try{Invoke-PMMLocalizeVisualTree $Window}catch{};$Script:PMMWorkspacesInitialized=$true
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

function Initialize-PMMCaseClientSelector {
    if($Script:PMMAIIOCaseUI.ContainsKey('CmbClient')){return}
    $transport=Get-PMMAIIOCaseControl 'CmbTransport';$row=$transport.Parent
    $label=[Windows.Controls.TextBlock]::new();$label.Text=L 'AI client' 'Cliente IA';$label.VerticalAlignment='Center';$label.Margin=[Windows.Thickness]::new(8,0,3,0)
    $combo=[Windows.Controls.ComboBox]::new();$combo.Width=180;$combo.DisplayMemberPath='Label';$combo.SelectedValuePath='Value'
    $combo.ItemsSource=@([pscustomobject]@{Label='ChatGPT Desktop';Value='CHATGPT'},[pscustomobject]@{Label='Codex Desktop';Value='CODEX_DESKTOP'},[pscustomobject]@{Label=(L 'Advanced: other MCP client' 'Avanzado: otro cliente MCP');Value='EXTERNAL'},[pscustomobject]@{Label=(L 'Advanced: internal agent' 'Avanzado: agente interno');Value='CODEX'})
    $combo.SelectedValue='CODEX_DESKTOP';$Script:PMMAIIOCaseUI['CmbClient']=$combo
    $group=[Windows.Controls.StackPanel]::new();$group.Orientation='Horizontal';$group.Margin=[Windows.Thickness]::new(0,2,4,2)
    [void]$group.Children.Add($label);[void]$group.Children.Add($combo)
    $at=$row.Children.IndexOf($transport)+1;$row.Children.Insert($at,$group)
    (Get-PMMAIIOCaseControl 'BtnCancel').Add_Click({$case=Get-PMMAIIOSelectedCase;if($case -and (Get-PMMCaseClient $case) -in @('CHATGPT','CODEX_DESKTOP')){Cancel-PMMDesktopDispatch $case.CaseId}})
    $combo.Add_SelectionChanged({if(-not $Script:PMMEditorLoading -and -not $Script:PMMCaseRefreshing){(Get-PMMAIIOCaseControl 'CmbTransport').SelectedValue='MCP'};Update-PMMAIIOTransportButton})
}
