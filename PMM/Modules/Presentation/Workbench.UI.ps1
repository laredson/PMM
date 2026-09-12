# Jugar / Crear shell. Existing controls stay alive; navigation never reconstructs drafts.
$Script:PMMWorkbench=$null
function New-PMMWorkbenchText([string]$Text,[int]$Size=14){
  $label=[Windows.Controls.TextBlock]::new();$label.Text=$Text;$label.FontSize=$Size;$label.TextWrapping='Wrap';$label.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty,'PrimaryText');return $label
}
function New-PMMWorkbenchButton([string]$Text,[string]$Action){
  $button=[Windows.Controls.Button]::new();$button.Content=$Text;$button.Tag=$Action;$button.Padding=[Windows.Thickness]::new(12,7,12,7);$button.Margin=[Windows.Thickness]::new(3);[Windows.Automation.AutomationProperties]::SetName($button,$Text);return $button
}
function Set-PMMWorkbenchCaseLanguage($Root){
  $labels=@{'Cases'='Casos';'Newest first'='Mas recientes primero';'Title'='Titulo';'Type'='Tipo';'Transport'='Conexion';'Description / goal'='Descripcion / objetivo';'References and evidence'='Referencias y evidencias';'Requested / pending work'='Trabajo pendiente';'History'='Historial';'Newest first. Steps are collapsed by default; jump directly to any point.'='Pasos recientes primero. Abre un paso para consultar sus detalles.';'AI response'='Respuesta de la IA'}
  if($Root -is [Windows.Controls.TextBlock] -and $labels.ContainsKey([string]$Root.Text) -and -not $Root.Name){$Root.Text=L $Root.Text $labels[[string]$Root.Text]}
  if($Root -is [Windows.Controls.Expander] -and $Root.Header -is [string] -and $labels.ContainsKey([string]$Root.Header)){$Root.Header=L $Root.Header $labels[[string]$Root.Header]}
  if($Root -is [Windows.DependencyObject]){foreach($child in [Windows.LogicalTreeHelper]::GetChildren($Root)){if($child -is [Windows.DependencyObject]){Set-PMMWorkbenchCaseLanguage $child}}}
}
function Get-PMMWorkbenchCaseRows {
  $search='';if($Script:PMMWorkbench){$search=[string]$Script:PMMWorkbench.CaseSearch.Text}
  return @(Get-PMMAIIOCases|Where-Object{(-not $search) -or ([string]$_.Title).IndexOf($search,[StringComparison]::OrdinalIgnoreCase) -ge 0 -or ([string]$_.CaseId).IndexOf($search,[StringComparison]::OrdinalIgnoreCase) -ge 0}|ForEach-Object{
    [pscustomobject]@{CaseId=[string]$_.CaseId;Title=[string]$_.Title;LastStep=[string]$_.LastAction;NextStep=(Get-PMMAIIOCaseNextLabel ([string]$_.NextAction));Type=[string]$_.Type}
  })
}
function Get-PMMAIIOCaseRows { return @(Get-PMMWorkbenchCaseRows) }
function Switch-PMMCaseArea([string]$Area){
  # One editor now belongs to Crear regardless of case type. Old route callbacks stay compatible.
  $Script:PMMCaseArea='ALL'
}
function Select-PMMCaseLocation($Case){
  if(-not $Case){return}
  if($Script:PMMWorkbench){if($Script:PMMWorkbench.CaseSearch.Text -and -not @(Get-PMMWorkbenchCaseRows | Where-Object CaseId -eq $Case.CaseId).Count){$Script:PMMWorkbench.CaseSearch.Clear()};Show-PMMWorkbenchPage 'Cases'}
  $Script:PMMAIIOCaseSelectedId=[string]$Case.CaseId
  Refresh-PMMAIIOCaseList ([string]$Case.CaseId)
}
function Get-PMMWorkbenchSelectedMods {
  $rows=@(Get-SelectedPMMLibraryEntries)
  return @($rows|ForEach-Object{if($_.PSObject.Properties['Mod'] -and $_.Mod){$_.Mod}else{$_}})
}
function Invoke-PMMWorkbenchContextCase([string]$Type){
  try{
    [void](Save-PMMAIIOCaseEditor)
    $mods=@(Get-PMMWorkbenchSelectedMods)
    if($mods.Count -eq 0){throw (L 'Select one or more source mods.' 'Selecciona uno o varios mods fuente.')}
    $title=([string]$mods[0].Name);if($mods.Count -gt 1){$title+=' + '+($mods.Count-1)}
    Start-PMMWorkbenchTool -Mode CreateContextCase -Request ([pscustomobject]@{Type=$Type;Mods=@($mods|Select-Object Name,Path,Hash,Priority,Enabled);Title=$title;Description='';Origin='Jugar'})
  }catch{Handle-UIError $_ (L 'Create case' 'Crear caso')}
}
function Open-PMMWorkbenchUnsupportedCase {
  try{
    $row=$Script:LstUnsupportedAssets.SelectedItem
    if(-not $row){$row=Get-PMMUnsupportedAssets|Select-Object -First 1}
    if(-not $row){return}
    $cases=@(Get-PMMCaseForAsset -Asset $row | Where-Object {$_})
    if($cases.Count){Select-PMMCaseLocation $cases[0]}else{Show-PMMWorkbenchPage 'Cases';$Script:TxtStatus.Text=L 'Run Analyze to publish the current case evidence.' 'Ejecuta Analizar para publicar la evidencia actual del caso.'}
  }catch{Handle-UIError $_ (L 'Open case' 'Abrir caso')}
}
function New-PMMWorkbenchPage([string]$Key,[string]$Title){
  $tab=[Windows.Controls.TabItem]::new();$tab.Header=$Title;$tab.Tag='WB_'+$Key
  $panel=[Windows.Controls.DockPanel]::new();$panel.Margin=[Windows.Thickness]::new(18)
  $heading=New-PMMWorkbenchText $Title 23;$heading.Margin=[Windows.Thickness]::new(0,0,0,12);[Windows.Controls.DockPanel]::SetDock($heading,'Top');[void]$panel.Children.Add($heading)
  $tab.Content=$panel;[void]$Script:MainTabs.Items.Add($tab);$Script:PMMWorkbench.Pages[$Key]=$tab;return $panel
}
function Show-PMMWorkbenchPage([string]$Key){
  if(-not $Script:PMMWorkbench -or -not $Script:PMMWorkbench.Pages.ContainsKey($Key)){return}
  if($Script:PMMWorkbench.ActivePage -eq 'Cases' -and $Key -ne 'Cases'){[void](Save-PMMAIIOCaseEditor)}
  $Script:PMMWorkbench.ActivePage=$Key
  if($Key -in @('Cases','Resources','Tools','Knowledge')){$Script:PMMWorkbench.LastCreate=$Key}elseif($Key -in @('Library','Repairs','Saves','History')){$Script:PMMWorkbench.LastPlay=$Key}
  $mode=if($Key -in @('Cases','Resources','Tools','Knowledge')){'Create'}elseif($Key -in @('Settings','Help')){$Script:PMMWorkbench.Mode}else{'Play'}
  Set-PMMWorkbenchMode $mode -KeepPage
  $Script:MainTabs.SelectedItem=$Script:PMMWorkbench.Pages[$Key]
  foreach($button in $Script:PMMWorkbench.NavButtons){$button.FontWeight=if([string]$button.Tag -eq $Key){'SemiBold'}else{'Normal'}}
  if($Key -eq 'Cases'){Refresh-PMMAIIOCaseList}
  if($Key -in @('Tools','Knowledge','History')){Refresh-PMMWorkbenchPageData $Key}
  Update-PMMWorkbenchStatus
}
function Set-PMMWorkbenchMode([ValidateSet('Play','Create')][string]$Mode,[switch]$KeepPage){
  $Script:PMMWorkbench.Mode=$Mode
  foreach($button in $Script:PMMWorkbench.ContextButtons){$button.Visibility=if($Mode -eq 'Play'){'Visible'}else{'Collapsed'}}
  foreach($button in $Script:PMMWorkbench.NavButtons){$page=[string]$button.Tag;$group=if($page -in @('Cases','Resources','Tools','Knowledge')){'Create'}elseif($page -in @('Settings','Help')){'Shared'}else{'Play'};$button.Visibility=if($group -eq 'Shared' -or $group -eq $Mode){'Visible'}else{'Collapsed'}}
  $Script:PMMWorkbench.PlayMode.FontWeight=if($Mode -eq 'Play'){'Bold'}else{'Normal'}
  $Script:PMMWorkbench.CreateMode.FontWeight=if($Mode -eq 'Create'){'Bold'}else{'Normal'}
  if($Script:PMMWorkbench.HeaderActions){$Script:PMMWorkbench.HeaderActions.Visibility=if($Mode -eq 'Play'){'Visible'}else{'Collapsed'}}
  if(-not $KeepPage){Show-PMMWorkbenchPage $(if($Mode -eq 'Play'){$Script:PMMWorkbench.LastPlay}else{$Script:PMMWorkbench.LastCreate})}
}
function Update-PMMWorkbenchStatus {
  if(-not $Script:PMMWorkbench){return}
  try{
    if($Script:PMMWorkbench.Mode -eq 'Create'){$case=Get-PMMAIIOSelectedCase;$Script:PMMWorkbench.Stage.Text=if($case){[string]$case.Title}else{L 'Create a case to begin' 'Crea un caso para empezar'};$Script:PMMWorkbench.Status.Text=L 'Changes, candidates and tests remain linked to the case.' 'Los cambios, candidatos y pruebas permanecen vinculados al caso.';return}
    $state=Get-PMMWorkflowState
    $Script:PMMWorkbench.Status.Text=[string]$state.Detail
    $Script:PMMWorkbench.Stage.Text=(L 'Import / Repair / Analyze / Build / Install / Play' 'Importar / Reparar / Analizar / Construir / Instalar / Jugar')+'  /  '+[string]$state.Action
  }catch{$Script:PMMWorkbench.Status.Text=L 'Library selection and installed game state are tracked separately.' 'La seleccion en biblioteca y el estado instalado se muestran por separado.'}
}
function Refresh-PMMWorkbenchPageData([string]$Key){
  try{
    if($Key -eq 'Tools' -and (Get-Command Start-PMMWorkbenchTool -ErrorAction SilentlyContinue) -and [string]::IsNullOrWhiteSpace((Get-PMMActiveProcessingOperation))){Start-PMMWorkbenchTool -Mode Capabilities}
    if($Key -eq 'Knowledge' -and (Get-Command Start-PMMWorkbenchTool -ErrorAction SilentlyContinue) -and [string]::IsNullOrWhiteSpace((Get-PMMActiveProcessingOperation))){Start-PMMWorkbenchTool -Mode ScanKnowledge}
    if($Key -eq 'History'){$Script:PMMWorkbench.HistoryGrid.ItemsSource=@(Get-PMMOperationJournalEvents|Select-Object -Last 100|Sort-Object Utc -Descending|Select-Object Utc,Kind,Event,Step,Status)}
  }catch{$Script:TxtStatus.Text=$_.Exception.Message}
}
function Set-PMMWorkbenchCapabilities($Rows){
  $Script:PMMWorkbench.ToolGrid.ItemsSource=@($Rows | Select-Object *,@{n='CapabilityText';e={$_.Capabilities -join ', '}},@{n='UnsupportedText';e={$_.Unsupported -join ', '}})
}
function Set-PMMWorkbenchKnowledgeRows($Candidates,$Imports){
  $grid=$Script:PMMWorkbench.KnowledgeGrid;$selection=$grid.SelectedItem
  $grid.ItemsSource=@($Candidates)
  if($selection){$grid.SelectedItem=$grid.ItemsSource|Where-Object {$_.CaseId -eq $selection.CaseId -and $_.CandidateId -eq $selection.CandidateId}|Select-Object -First 1}
  $Script:PMMWorkbench.ImportGrid.ItemsSource=@($Imports)
}
function New-PMMWorkbenchGrid {
  $grid=[Windows.Controls.DataGrid]::new();$grid.IsReadOnly=$true;$grid.AutoGenerateColumns=$true;$grid.CanUserAddRows=$false;$grid.HeadersVisibility='Column';$grid.EnableRowVirtualization=$true;$grid.SetResourceReference([Windows.Controls.Control]::BackgroundProperty,'CardBackground');$grid.SetResourceReference([Windows.Controls.Control]::ForegroundProperty,'PrimaryText');return $grid
}
function Set-PMMWorkbenchGridColumns($Grid,[array]$Columns){
  $Grid.AutoGenerateColumns=$false
  foreach($entry in $Columns){$column=[Windows.Controls.DataGridTextColumn]::new();$column.Header=L $entry[0] $entry[1];$column.Binding=[Windows.Data.Binding]::new([string]$entry[2]);$column.Width=[double]$entry[3];[void]$Grid.Columns.Add($column)}
}
function Set-PMMWorkbenchAppearance {
  if(-not $Script:PMMWorkbench){return}
  $high=[Windows.SystemParameters]::HighContrast
  $Script:PMMWorkbench.ReducedMotion=(-not [Windows.SystemParameters]::ClientAreaAnimation)
  if($high){
    foreach($key in @('AppBackground','CardBackground','CardAltBackground','HeaderBackground','WindowBackground','InputBackground','StatusBackground')){$Window.Resources[$key]=[Windows.SystemColors]::WindowBrush}
    foreach($key in @('PrimaryText','MutedText')){$Window.Resources[$key]=[Windows.SystemColors]::WindowTextBrush}
    $Window.Resources['ButtonBackground']=[Windows.SystemColors]::ControlBrush;$Window.Resources['ButtonForeground']=[Windows.SystemColors]::ControlTextBrush;$Window.Resources['ButtonBorder']=[Windows.SystemColors]::WindowTextBrush
    $Window.Resources['SelectionBackground']=[Windows.SystemColors]::HighlightBrush;$Window.Resources['SelectionText']=[Windows.SystemColors]::HighlightTextBrush
    $Window.Resources['CardBorder']=[Windows.SystemColors]::WindowTextBrush;$Window.Resources['InputBorder']=[Windows.SystemColors]::WindowTextBrush
    $Window.Background=[Windows.SystemColors]::WindowBrush;$Window.Foreground=[Windows.SystemColors]::WindowTextBrush
    foreach($child in $Script:PnlHeaderTitle.Children){if($child -is [Windows.Controls.TextBlock]){$child.Foreground=[Windows.SystemColors]::WindowTextBrush}}
    $Script:PMMWorkbench.Artwork.Background=[Windows.SystemColors]::WindowBrush
  }else{
    $art=Join-Path $Script:Root 'Resources\UI\PMMArtwork.png'
    if(Test-Path -LiteralPath $art){
      $bitmap=[Windows.Media.Imaging.BitmapImage]::new();$bitmap.BeginInit();$bitmap.CacheOption='OnLoad';$bitmap.UriSource=[uri]$art;$bitmap.EndInit();$bitmap.Freeze()
      $photo=[Windows.Media.ImageBrush]::new($bitmap);$photo.Stretch='UniformToFill';$photo.Viewbox=[Windows.Rect]::new(0.26,0.18,0.68,0.58)
      $group=[Windows.Media.DrawingGroup]::new();$base=[Windows.Media.GeometryDrawing]::new([Windows.Media.BrushConverter]::new().ConvertFromString('#091A2B'),$null,[Windows.Media.RectangleGeometry]::new([Windows.Rect]::new(0,0,100,24)));$group.Children.Add($base)
      $group.Children.Add([Windows.Media.GeometryDrawing]::new($photo,$null,[Windows.Media.RectangleGeometry]::new([Windows.Rect]::new(20,0,80,24))))
      $shade=[Windows.Media.LinearGradientBrush]::new();$shade.StartPoint=[Windows.Point]::new(0,0.5);$shade.EndPoint=[Windows.Point]::new(1,0.5);$shade.GradientStops.Add([Windows.Media.GradientStop]::new([Windows.Media.ColorConverter]::ConvertFromString('#FF091A2B'),0));$shade.GradientStops.Add([Windows.Media.GradientStop]::new([Windows.Media.ColorConverter]::ConvertFromString('#DA091A2B'),0.45));$shade.GradientStops.Add([Windows.Media.GradientStop]::new([Windows.Media.ColorConverter]::ConvertFromString('#95091A2B'),1))
      $group.Children.Add([Windows.Media.GeometryDrawing]::new($shade,$null,[Windows.Media.RectangleGeometry]::new([Windows.Rect]::new(0,0,100,24))))
      $brush=[Windows.Media.DrawingBrush]::new($group);$brush.Stretch='Fill';$brush.Freeze();$Script:PMMWorkbench.Artwork.Background=$brush
      foreach($child in $Script:PnlHeaderTitle.Children){if($child -is [Windows.Controls.TextBlock]){$child.Foreground=[Windows.Media.Brushes]::White}}
    }
  }
}
function Initialize-PMMWorkbench {
  if($Script:PMMWorkbench){return}
  $Script:PMMWorkbench=@{Mode='Play';ActivePage='';Pages=@{};NavButtons=[Collections.Generic.List[object]]::new();ContextButtons=[Collections.Generic.List[object]]::new();ReducedMotion=$false;LastPlay='Library';LastCreate='Cases';LastCandidate='';LastCandidateCase='';ToolDrafts=@{};ToolProcess=$null;ToolTimer=$null;ToolLease=$null;ToolResult='';ToolOutput=$null;ObservationTimer=$null;ToolHandle=$null;ToolCancel='';ToolProgress='';ToolCompletionBusy=$false;ToolPreserveOutput=$false;ToolRequestOperation='';ToolCaseId='';ToolMode='';Closing=$false;FeedbackDialogOpen=$false;HeaderActions=$Window.FindName('GrdHeaderActions')}
  $wb=$Script:PMMWorkbench
  # Preserve the original workflow controls and their single state machine.
  $wb.Pages['Library']=$Script:PMMMergeTab;$wb.Pages['Repairs']=$Script:TabFixLab
  $wb.Pages['Saves']=$Window.FindName('TabSaves');if(-not $wb.Pages['Saves']){$wb.Pages['Saves']=@($Script:MainTabs.Items|Where-Object{$_.Header -match 'Save|Partida'})[0]}
  $wb.Pages['Settings']=$Window.FindName('TabSettings');$wb.Pages['Help']=$Script:TabAIHelp
  foreach($tab in @($Script:PMMMergeTab,$Script:TabFixLab)){
    if($tab.Content -is [Windows.Controls.TabControl]){$tabs=$tab.Content;$first=$tabs.Items[0];$flow=$first.Content;$first.Content=$null;$tab.Content=$flow}
  }
  $creation=@($Script:MainTabs.Items|Where-Object{$_.Tag -eq 'CREATE'})[0]
  $oldParent=$Script:PMMCaseEditor.Parent;if($oldParent -is [Windows.Controls.ContentControl]){$oldParent.Content=$null}
  $casePanel=[Windows.Controls.DockPanel]::new();$casePanel.Margin=[Windows.Thickness]::new(10)
  $caseSearch=[Windows.Controls.TextBox]::new();$caseSearch.Margin=[Windows.Thickness]::new(0,0,0,8);$caseSearch.ToolTip=L 'Find a case by title or ID' 'Buscar caso por titulo o ID';[Windows.Automation.AutomationProperties]::SetName($caseSearch,[string]$caseSearch.ToolTip)
  $searchBar=[Windows.Controls.DockPanel]::new();[Windows.Controls.DockPanel]::SetDock($searchBar,'Top');$searchLabel=New-PMMWorkbenchText (L 'Find cases' 'Buscar casos');$searchLabel.Margin=[Windows.Thickness]::new(0,5,12,0);[Windows.Controls.DockPanel]::SetDock($searchLabel,'Left');[void]$searchBar.Children.Add($searchLabel);[void]$searchBar.Children.Add($caseSearch);[void]$casePanel.Children.Add($searchBar);$wb.CaseSearch=$caseSearch
  [void]$casePanel.Children.Add($Script:PMMCaseEditor);$creation.Content=$casePanel;$wb.Pages['Cases']=$creation;$Script:PMMCaseArea='ALL'
  $Script:PMMCaseEditor.ColumnDefinitions[0].MinWidth=250;$Script:PMMCaseEditor.ColumnDefinitions[2].MinWidth=500
  $caseGrid=Get-PMMAIIOCaseControl 'DgCases';$caseGrid.Columns.Clear();$caseGrid.RowHeight=52
  $column=[Windows.Controls.DataGridTemplateColumn]::new();$column.Header=L 'Cases' 'Casos';$column.Width=[Windows.Controls.DataGridLength]::new(1,[Windows.Controls.DataGridLengthUnitType]::Star)
  $column.CellTemplate=[Windows.Markup.XamlReader]::Parse('<DataTemplate xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"><StackPanel Margin="6,5"><TextBlock Text="{Binding Title}" ToolTip="{Binding Title}" FontWeight="SemiBold" TextTrimming="CharacterEllipsis"/><TextBlock Text="{Binding NextStep}" ToolTip="{Binding LastStep}" Foreground="{DynamicResource MutedText}" FontSize="11" TextTrimming="CharacterEllipsis" Margin="0,3,0,0"/></StackPanel></DataTemplate>');[void]$caseGrid.Columns.Add($column)
  Set-PMMWorkbenchCaseLanguage $Script:PMMCaseEditor
  foreach($entry in @(@('BtnNew','New case','Nuevo caso'),@('BtnReceive','Receive result','Recibir resultado'),@('BtnHandoff','Export context ZIP','Exportar contexto ZIP'),@('BtnSave','Save','Guardar'),@('BtnRefresh','Refresh','Actualizar'),@('BtnFolder','Case folder','Carpeta del caso'),@('BtnDelete','Delete case','Eliminar caso'))){$button=Get-PMMAIIOCaseControl $entry[0];if($button){$button.Content=L $entry[1] $entry[2]}}
  $caseSearch.Add_TextChanged({if($Script:PMMWorkbench){Refresh-PMMAIIOCaseList}})
  $history=New-PMMWorkbenchPage 'History' (L 'Activity history' 'Historial de actividad');$wb.HistoryGrid=New-PMMWorkbenchGrid;[void]$history.Children.Add($wb.HistoryGrid)
  $resources=New-PMMWorkbenchPage 'Resources' (L 'Project resources' 'Recursos del proyecto')
  $resourceStack=[Windows.Controls.StackPanel]::new();[void]$resources.Children.Add($resourceStack)
  [void]$resourceStack.Children.Add((New-PMMWorkbenchText (L 'References, candidates and external tools remain linked to the selected case.' 'Las referencias, candidatos y herramientas permanecen vinculados al caso seleccionado.')))
  foreach($entry in @(@('Case files','Archivos del caso','CaseFiles'),@('Candidates','Candidatos','Candidates'),@('Game reference','Referencia del juego','Reference'),@('Appearance editor','Editor de apariencia','Theme'))){$button=New-PMMWorkbenchButton (L $entry[0] $entry[1]) $entry[2];$button.HorizontalAlignment='Left';$button.Add_Click({param($sender,$e) Invoke-PMMWorkbenchResource ([string]$sender.Tag)});[void]$resourceStack.Children.Add($button)}
  $tools=New-PMMWorkbenchPage 'Tools' (L 'Tools and capabilities' 'Herramientas y capacidades');$toolBar=[Windows.Controls.WrapPanel]::new();[Windows.Controls.DockPanel]::SetDock($toolBar,'Top');[void]$tools.Children.Add($toolBar)
  foreach($entry in @(@('Configure tools','Configurar herramientas','ConfigureTools'),@('Inspect / edit case','Inspeccionar / editar caso','Inspect'),@('Unreal workshop','Taller Unreal','Unreal'),@('Cancel tool','Cancelar herramienta','CancelTool'),@('Refresh','Actualizar','RefreshTools'))){$button=New-PMMWorkbenchButton (L $entry[0] $entry[1]) $entry[2];$button.Add_Click({param($sender,$e) Invoke-PMMWorkbenchResource ([string]$sender.Tag)});[void]$toolBar.Children.Add($button)}
  $wb.ToolOutput=[Windows.Controls.TextBox]::new();$wb.ToolOutput.IsReadOnly=$true;$wb.ToolOutput.AcceptsReturn=$true;$wb.ToolOutput.TextWrapping='Wrap';$wb.ToolOutput.VerticalScrollBarVisibility='Auto';$wb.ToolOutput.Height=230;$wb.ToolOutput.Margin=[Windows.Thickness]::new(0,8,0,0);$wb.ToolOutput.Text=L 'Tool results and inspected properties appear here.' 'Aqui aparecen los resultados y propiedades inspeccionadas.';[Windows.Controls.DockPanel]::SetDock($wb.ToolOutput,'Bottom');[void]$tools.Children.Add($wb.ToolOutput)
  $wb.ToolGrid=New-PMMWorkbenchGrid;Set-PMMWorkbenchGridColumns $wb.ToolGrid @(@('Tool','Herramienta','Label',200),@('Status','Estado','Status',140),@('Supported capabilities','Capacidades soportadas','CapabilityText',280),@('Limitations','Limitaciones','UnsupportedText',260),@('Details','Detalles','Detail',460));[void]$tools.Children.Add($wb.ToolGrid)
  $knowledge=New-PMMWorkbenchPage 'Knowledge' (L 'Local knowledge' 'Conocimiento local');$klBar=[Windows.Controls.WrapPanel]::new();[Windows.Controls.DockPanel]::SetDock($klBar,'Top');[void]$knowledge.Children.Add($klBar)
  foreach($entry in @(@('Import contribution','Importar contribucion','ImportKL'),@('Export selected','Exportar seleccion','ExportKL'),@('Try selected candidate','Probar candidato','TryCandidate'),@('Review selected','Revisar seleccion','ReviewKL'),@('Open case','Abrir caso','OpenCandidateCase'),@('Preferences','Preferencias','KLPreferences'),@('Refresh','Actualizar','RefreshKL'))){$button=New-PMMWorkbenchButton (L $entry[0] $entry[1]) $entry[2];$button.Add_Click({param($sender,$e) Invoke-PMMWorkbenchResource ([string]$sender.Tag)});[void]$klBar.Children.Add($button)}
  $klNote=New-PMMWorkbenchText (L 'Local exchange. Automatic observations, user reports and reviewer approval are separate. No uploads.' 'Intercambio local. Observaciones, confirmaciones y aprobacion se muestran por separado. Sin envios.');$klNote.Margin=[Windows.Thickness]::new(4,8,4,12);[Windows.Controls.DockPanel]::SetDock($klNote,'Top');[void]$knowledge.Children.Add($klNote)
  $imports=[Windows.Controls.DockPanel]::new();$imports.Height=145;$imports.Margin=[Windows.Thickness]::new(0,12,0,0);[Windows.Controls.DockPanel]::SetDock($imports,'Bottom');[void]$knowledge.Children.Add($imports)
  $importTitle=New-PMMWorkbenchText (L 'Imported procedures - pending review' 'Procedimientos importados - pendientes de revision');[Windows.Controls.DockPanel]::SetDock($importTitle,'Top');[void]$imports.Children.Add($importTitle)
  $wb.ImportGrid=New-PMMWorkbenchGrid;Set-PMMWorkbenchGridColumns $wb.ImportGrid @(@('Objective','Objetivo','Objective',250),@('Review','Revision','Review',100),@('Input references','Referencias','ReferenceMatch',160),@('Reproducible','Reproducible','Reproducible',130));[void]$imports.Children.Add($wb.ImportGrid)
  $wb.KnowledgeGrid=New-PMMWorkbenchGrid;Set-PMMWorkbenchGridColumns $wb.KnowledgeGrid @(@('Candidate','Candidato','Objective',220),@('Technical','Tecnica','TechnicalStatus',110),@('Observation','Observacion','Observation',170),@('User','Usuario','UserConfirmation',120),@('Review','Revision','Review',110),@('Applicability','Aplicabilidad','Applicability',140),@('Outcome','Resultado','Outcome',260));[void]$knowledge.Children.Add($wb.KnowledgeGrid)
  # Keep MainTabs alive but replace tab headers with one consistent side navigation.
  $parent=$Script:MainTabs.Parent;$row=[Windows.Controls.Grid]::GetRow($Script:MainTabs);[void]$parent.Children.Remove($Script:MainTabs)
  $shell=[Windows.Controls.DockPanel]::new();$shell.Margin=[Windows.Thickness]::new(0,10,0,8);[Windows.Controls.Grid]::SetRow($shell,$row);[void]$parent.Children.Add($shell)
  $top=[Windows.Controls.WrapPanel]::new();$top.Margin=[Windows.Thickness]::new(0,0,0,6);[Windows.Controls.DockPanel]::SetDock($top,'Top');[void]$shell.Children.Add($top)
  $wb.PlayMode=New-PMMWorkbenchButton (L 'PLAY' 'JUGAR') 'Play';$wb.CreateMode=New-PMMWorkbenchButton (L 'CREATE' 'CREAR') 'Create'
  $wb.PlayMode.Add_Click({Set-PMMWorkbenchMode 'Play'});$wb.CreateMode.Add_Click({Set-PMMWorkbenchMode 'Create'});[void]$top.Children.Add($wb.PlayMode);[void]$top.Children.Add($wb.CreateMode)
  foreach($entry in @(@('Repair case','Caso de reparacion','Fix'),@('Compatibility case','Caso de compatibilidad','Compat'),@('Ask about selection','Consultar seleccion','Query'))){$button=New-PMMWorkbenchButton (L $entry[0] $entry[1]) $entry[2];$button.Add_Click({param($sender,$e) Invoke-PMMWorkbenchContextCase ([string]$sender.Tag)});[void]$top.Children.Add($button);$wb.ContextButtons.Add($button)}
    $linkedButton=New-PMMWorkbenchButton (L 'Open origin case' 'Abrir caso de origen') 'Origin';$linkedButton.Add_Click({$row=$Script:LstMods.SelectedItem;if($row -and $row.PSObject.Properties['CaseId'] -and $row.CaseId){Select-PMMCaseLocation (Get-PMMAIIOCase $row.CaseId)}});[void]$top.Children.Add($linkedButton);$wb.ContextButtons.Add($linkedButton)
  $trialButton=New-PMMWorkbenchButton (L 'Try generated candidate' 'Probar candidato generado') 'Trial';$trialButton.Add_Click({Invoke-PMMWorkbenchLibraryTrial});[void]$top.Children.Add($trialButton);$wb.ContextButtons.Add($trialButton)
  $reload=New-PMMWorkbenchButton (L 'Reload modules' 'Recargar modulos') 'Reload';$reload.Add_Click({Invoke-PMMWorkbenchReload});[void]$top.Children.Add($reload)
  $footer=[Windows.Controls.StackPanel]::new();$footer.Margin=[Windows.Thickness]::new(10,8,10,4);$wb.Stage=New-PMMWorkbenchText '' 13;$wb.Status=New-PMMWorkbenchText '' 12;[void]$footer.Children.Add($wb.Stage);[void]$footer.Children.Add($wb.Status);[Windows.Controls.DockPanel]::SetDock($footer,'Bottom');[void]$shell.Children.Add($footer)
  $nav=[Windows.Controls.StackPanel]::new();$nav.Width=158;$nav.Margin=[Windows.Thickness]::new(0,0,10,0);$wb.Nav=$nav;[Windows.Controls.DockPanel]::SetDock($nav,'Left');[void]$shell.Children.Add($nav)
  foreach($entry in @(@('Library','Biblioteca','Library'),@('Repairs','Reparaciones','Repairs'),@('Saves','Partidas','Saves'),@('History','Historial','History'),@('Cases','Casos','Cases'),@('Resources','Recursos','Resources'),@('Tools','Herramientas','Tools'),@('Knowledge','Conocimiento','Knowledge'),@('Settings','Ajustes','Settings'),@('Help','Ayuda','Help'))){$button=New-PMMWorkbenchButton (L $entry[0] $entry[1]) $entry[2];$button.HorizontalContentAlignment='Left';$button.Add_Click({param($sender,$e) Show-PMMWorkbenchPage ([string]$sender.Tag)});[void]$nav.Children.Add($button);$wb.NavButtons.Add($button)}
  $template='<ControlTemplate xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" TargetType="TabControl"><ContentPresenter Content="{TemplateBinding SelectedContent}" ContentTemplate="{TemplateBinding SelectedContentTemplate}" /></ControlTemplate>'
  $Script:MainTabs.Template=[Windows.Markup.XamlReader]::Parse($template);$Script:MainTabs.Margin=[Windows.Thickness]::new(0);[void]$shell.Children.Add($Script:MainTabs)
  $Script:MainTabs.Add_SelectionChanged({param($sender,$e) if($e.OriginalSource -ne $sender -or -not $Script:PMMWorkbench){return};foreach($key in $Script:PMMWorkbench.Pages.Keys){if($Script:PMMWorkbench.Pages[$key] -eq $Script:MainTabs.SelectedItem -and $Script:PMMWorkbench.ActivePage -ne $key){$Script:PMMWorkbench.ActivePage=$key;Set-PMMWorkbenchMode $(if($key -in @('Cases','Resources','Tools','Knowledge')){'Create'}elseif($key -in @('Settings','Help')){$Script:PMMWorkbench.Mode}else{'Play'}) -KeepPage;break}};Update-PMMWorkbenchStatus})
  $context=[Windows.Controls.ContextMenu]::new();$create=[Windows.Controls.MenuItem]::new();$create.Header=L 'Create case' 'Crear caso'
  foreach($entry in @(@('Repair','Reparacion','Fix'),@('Compatibility','Compatibilidad','Compat'),@('Question','Consulta','Query'))){$item=[Windows.Controls.MenuItem]::new();$item.Header=L $entry[0] $entry[1];$item.Tag=$entry[2];$item.Add_Click({param($sender,$e) Invoke-PMMWorkbenchContextCase ([string]$sender.Tag)});[void]$create.Items.Add($item)};[void]$context.Items.Add($create)
  $linked=[Windows.Controls.MenuItem]::new();$linked.Header=L 'Open originating case' 'Abrir caso de origen';$linked.Add_Click({$row=$Script:LstMods.SelectedItem;if($row -and $row.PSObject.Properties['CaseId'] -and $row.CaseId){Select-PMMCaseLocation (Get-PMMAIIOCase $row.CaseId)}});[void]$context.Items.Add($linked)
  $trial=[Windows.Controls.MenuItem]::new();$trial.Header=L 'Review and try generated candidate' 'Revisar y probar candidato generado';$trial.Add_Click({Invoke-PMMWorkbenchLibraryTrial});[void]$context.Items.Add($trial);$Script:LstMods.ContextMenu=$context
  $Script:LstMods.Add_PreviewMouseRightButtonDown({param($sender,$e) $item=[Windows.Controls.ItemsControl]::ContainerFromElement($sender,$e.OriginalSource);if($item -is [Windows.Controls.ListBoxItem] -and -not $item.IsSelected){$sender.SelectedItems.Clear();$item.IsSelected=$true}})
  $header=$Script:GrdHeaderLayout.Parent;$wb.Artwork=$header;$Script:ImgPMMLogo.Width=68;$Script:ImgPMMLogo.Height=68
  foreach($child in $Script:PnlHeaderTitle.Children){if($child -is [Windows.Controls.TextBlock]){$child.FontSize=19;$child.LineHeight=22}}
  $Script:BtnAutoRun.ToolTip=L 'Run the known compatible steps through installation. Stops when a decision or investigation is needed.' 'Ejecuta los pasos conocidos hasta instalar. Se detiene cuando hace falta decidir o investigar.'
  $Script:BtnOpenAIHandoff.Content=L 'Open case in Create' 'Abrir caso en Crear'
  $Window.Add_SizeChanged({if($Script:PMMWorkbench){$compact=$Window.ActualWidth -lt 1150;$Script:PMMWorkbench.Nav.Width=if($compact){55}else{158};foreach($b in $Script:PMMWorkbench.NavButtons){$label=[Windows.Automation.AutomationProperties]::GetName($b);$b.Content=if($compact){$label.Substring(0,[Math]::Min(2,$label.Length))}else{$label};$b.ToolTip=$label}}})
  $Window.Add_PreviewKeyDown({param($sender,$eventArgs)
    if(([Windows.Input.Keyboard]::Modifiers -band [Windows.Input.ModifierKeys]::Control) -eq 0){return}
    switch($eventArgs.Key){
      'D1' {Set-PMMWorkbenchMode 'Play';$eventArgs.Handled=$true}
      'D2' {Set-PMMWorkbenchMode 'Create';$eventArgs.Handled=$true}
      'F' {if($Script:PMMWorkbench.Mode -eq 'Create'){Show-PMMWorkbenchPage 'Cases';[void]$Script:PMMWorkbench.CaseSearch.Focus()}else{Show-PMMWorkbenchPage 'Library';[void]$Window.FindName('TxtModFilter').Focus()};$eventArgs.Handled=$true}
    }
  })
  Set-PMMWorkbenchAppearance
  Show-PMMWorkbenchPage 'Library'
}
