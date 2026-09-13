function Get-PMMDeepUIOptions {
  $o=New-PMMDeepAnalysisOptions
  foreach($name in @('CheckUpdates','IncludePatch','AutomaticSolution','AllowDeploy','AllowGame','TestWorld','Isolate','AllowDependencies')){$o.$name=[bool]$Script:DeepControls[$name].IsChecked}
  foreach($name in @('MaxActiveMinutes','MaxCandidates','MaxTestRuns')){$value=0;if(-not[int]::TryParse($Script:DeepControls[$name].Text,[ref]$value) -or $value -lt 1 -or $value -gt 10000){throw (L 'Limits must be positive numbers.' 'Los limites deben ser numeros positivos.')};$o.$name=$value}
  Write-PMMJsonAtomic (Join-PMMPath 'State' 'deep-analysis-options.json') $o
  return $o
}
function Update-PMMDeepFindingFilter {
  if(-not(Get-Variable DeepReportView -Scope Script -ErrorAction SilentlyContinue) -or -not$Script:DeepReportView){return}
  $query=$Script:DeepControls.Filter.Text.ToLowerInvariant()
  $Script:DeepControls.Findings.ItemsSource=@($Script:DeepReportView.Findings|Where-Object{([string]$_.Severity+' '+[string]$_.Confidence+' '+($_.Mods -join ' ')+' '+[string]$_.Resource+' '+[string]$_.Message).ToLowerInvariant().Contains($query)})
}
function Show-PMMDeepReport([string]$Id) {
  $path=Join-Path (Get-PMMAnalysisPath $Id) 'view.json'
  $Script:DeepReportView=Read-PMMJsonFile $path
  $Script:DeepControls.Status.Text=$Script:DeepReportView.Summary
  $Script:DeepRepairSessionId=[string](Get-PMMAnalysisValue $Script:DeepReportView RepairSessionId '')
  $Script:DeepControls.CreateCase.IsEnabled=$true;$Script:DeepControls.Export.IsEnabled=$true
  Update-PMMDeepFindingFilter
}
function Start-PMMDeepUIOperation([string]$Operation,$Request,[scriptblock]$OnSuccess) {
  $folder=Join-PMMPath 'Cache' 'DeepRequests';[void][IO.Directory]::CreateDirectory($folder)
  $path=Join-Path $folder ([guid]::NewGuid().ToString('N')+'.json')
  Write-PMMJsonAtomic $path $Request -Depth 20
  $started=Start-PMMBackgroundOperation -Operation $Operation -RequestPath $path -OnSuccess $OnSuccess -OnFailure {param($message)$Script:DeepControls.Status.Text=$message}
  if($started){$Script:DeepControls.Status.Text=L 'Processing in background...' 'Procesando en segundo plano...'}
}
function Initialize-PMMDeepAnalysisUI {
  $Script:DeepControls=@{};$Script:DeepReportView=$null;$Script:DeepRepairSessionId=''
  $exp=[Windows.Controls.Expander]::new();$exp.Header=L 'Deep analysis' 'Analisis profundo';$exp.Margin=[Windows.Thickness]::new(0,0,0,6);$exp.Padding=[Windows.Thickness]::new(6)
  $exp.SetResourceReference([Windows.Controls.Control]::BackgroundProperty,'CardBackground')
  $exp.SetResourceReference([Windows.Controls.Control]::ForegroundProperty,'PrimaryText')
  $body=[Windows.Controls.StackPanel]::new();$exp.Content=$body
  $options=[Windows.Controls.WrapPanel]::new()
  $labels=@{
    CheckUpdates=@('Check mod updates','Buscar actualizaciones');IncludePatch=@('Include selected patch','Incluir parche seleccionado')
    AutomaticSolution=@('Automatic solution (preview)','Solucion automatica (preview)');AllowDeploy=@('Allow temporary deployment','Permitir despliegue temporal')
    AllowGame=@('Allow game tests','Permitir pruebas del juego');TestWorld=@('Test temporary world','Probar mundo temporal')
    Isolate=@('Isolate suspects','Aislar sospechosos');AllowDependencies=@('Allow catalog dependencies','Permitir dependencias del catalogo')
  }
  foreach($name in @('CheckUpdates','IncludePatch','AutomaticSolution','AllowDeploy','AllowGame','TestWorld','Isolate','AllowDependencies')){
    $control=[Windows.Controls.CheckBox]::new();$control.Content=L $labels[$name][0] $labels[$name][1];$control.Margin=[Windows.Thickness]::new(4);$control.IsChecked=($name -in @('CheckUpdates','IncludePatch'))
    if($name -eq 'AutomaticSolution'){$control.ToolTip=L 'Persistent local investigation. Shared control of a conversation already open in GPTD is awaiting a supported Windows adapter. Game testing remains disabled.' 'Investigacion local persistente. El control compartido de una conversacion abierta en GPTD requiere un adaptador compatible con Windows. Las pruebas del juego siguen desactivadas.'}
    $Script:DeepControls[$name]=$control;[void]$options.Children.Add($control)
  }
  [void]$body.Children.Add($options)
  $cap=Get-PMMRuntimeCapabilities
  foreach($name in @('AllowGame','TestWorld','Isolate','AllowDeploy')){$Script:DeepControls[$name].IsEnabled=$cap.Launch;$Script:DeepControls[$name].ToolTip=L $cap.Reason 'Pendiente de validar un adaptador que aisle partidas, configuracion y sincronizacion. Los candidatos y el informe estan disponibles.'}
  $limits=[Windows.Controls.WrapPanel]::new()
  foreach($pair in @(@('MaxActiveMinutes',40,'Minutes / Minutos'),@('MaxCandidates',6,'Candidates / Candidatos'),@('MaxTestRuns',12,'Runs / Pruebas'))){
    $label=[Windows.Controls.TextBlock]::new();$label.Text=$pair[2];$label.Margin=[Windows.Thickness]::new(4);[void]$limits.Children.Add($label)
    $box=[Windows.Controls.TextBox]::new();$box.Text=[string]$pair[1];$box.Width=48;$box.Margin=[Windows.Thickness]::new(4);$Script:DeepControls[$pair[0]]=$box;[void]$limits.Children.Add($box)
  }
  [void]$body.Children.Add($limits)
  $actions=[Windows.Controls.WrapPanel]::new()
  foreach($row in @(@('Run','Run deep analysis','Analizar en profundidad'),@('CreateCase','Create case','Crear caso'),@('Export','View/export report','Ver/exportar informe'),@('OpenChat','Open GPTD conversation','Abrir conversacion GPTD'),@('Stop','Stop and restore','Detener y restaurar'),@('History','Candidates and attempts','Candidatos e intentos'),@('Source','Update sources...','Origen de actualizaciones...'),@('AIPolicy','AI level...','Nivel de IA...'),@('ResumeAI','Continue investigation','Continuar investigacion'))){
    $button=[Windows.Controls.Button]::new();$button.Content=L $row[1] $row[2];$button.Margin=[Windows.Thickness]::new(3);$Script:DeepControls[$row[0]]=$button;[void]$actions.Children.Add($button)
  }
  $preference=Join-PMMPath 'State' 'deep-analysis-options.json'
  if(Test-Path -LiteralPath $preference){
    try{$saved=Read-PMMJsonFile $preference -Schema PMM_DEEP_OPTIONS_V1
      foreach($name in @('CheckUpdates','IncludePatch','AutomaticSolution','AllowDependencies')){$Script:DeepControls[$name].IsChecked=[bool]$saved.$name}
      foreach($name in @('MaxActiveMinutes','MaxCandidates','MaxTestRuns')){$Script:DeepControls[$name].Text=[string]$saved.$name}
    }catch{}
  }
  $Script:DeepControls.CreateCase.IsEnabled=$false;$Script:DeepControls.Export.IsEnabled=$false
  [void]$body.Children.Add($actions)
  $status=[Windows.Controls.TextBlock]::new();$status.Text=L 'Report only by default. Game automation requires a validated isolation adapter.' 'Por defecto, solo informe. Automatizar el juego requiere un adaptador de aislamiento validado.';$status.TextWrapping='Wrap';$status.Margin=[Windows.Thickness]::new(4);$Script:DeepControls.Status=$status;[void]$body.Children.Add($status)
  $filter=[Windows.Controls.TextBox]::new();$filter.Margin=[Windows.Thickness]::new(4);$filter.ToolTip=L 'Filter by mod, resource, severity or confidence' 'Filtrar por mod, recurso, gravedad o confianza';$Script:DeepControls.Filter=$filter;[void]$body.Children.Add($filter)
  [Windows.Automation.AutomationProperties]::SetName($filter,(L 'Filter findings' 'Filtrar hallazgos'))
  $grid=[Windows.Controls.DataGrid]::new();$grid.IsReadOnly=$true;$grid.AutoGenerateColumns=$false;$grid.MaxHeight=230;$grid.SelectionMode='Extended';$grid.SelectionUnit='FullRow'
  foreach($col in @(@('Severity','Severity','Gravedad',75),@('Confidence','Confidence','Confianza',115),@('ModsText','Mods','Mods',150),@('Resource','Resource','Recurso',200),@('Message','Finding','Hallazgo',340))){
    $column=[Windows.Controls.DataGridTextColumn]::new();$column.Header=L $col[1] $col[2];$column.Binding=[Windows.Data.Binding]::new($col[0]);$column.Width=$col[3];if($col[0] -eq 'Message'){$column.MinWidth=280;$column.Width=[Windows.Controls.DataGridLength]::new(1,[Windows.Controls.DataGridLengthUnitType]::Star)}[void]$grid.Columns.Add($column)
  }
  $grid.Add_MouseDoubleClick({try{Show-PMMDeepFindingDetail}catch{Handle-UIError $_ 'Finding'}});$grid.Add_KeyDown({if($_.Key -eq 'Enter'){Show-PMMDeepFindingDetail}});$Script:DeepControls.Findings=$grid;[void]$body.Children.Add($grid)
  $analysis=$Window.FindName('ExpAnalysis');$parent=$analysis.Parent;$row=[Windows.Controls.Grid]::GetRow($analysis);$parent.Children.Remove($analysis)
  $dock=[Windows.Controls.DockPanel]::new();[Windows.Controls.Grid]::SetRow($dock,$row);[Windows.Controls.DockPanel]::SetDock($exp,'Top')
  [void]$dock.Children.Add($exp);[void]$dock.Children.Add($analysis);[void]$parent.Children.Add($dock)
  $Script:DeepControls.Run.Add_Click({try{Start-PMMDeepUIOperation DeepAnalysis @{Options=(Get-PMMDeepUIOptions)} {param($r)Show-PMMDeepReport $r.AnalysisId;if($r.RepairSessionId){$Script:DeepRepairSessionId=$r.RepairSessionId}}}catch{Handle-UIError $_ 'Deep analysis'}})
  $Script:DeepControls.CreateCase.Add_Click({try{Show-PMMDeepCaseDialog}catch{Handle-UIError $_ 'Deep case'}})
  $Script:DeepControls.Export.Add_Click({if($Script:DeepReportView){Start-Process (Join-Path (Get-PMMAnalysisPath $Script:DeepReportView.Id) 'report.html')}})
  $Script:DeepControls.Filter.Add_TextChanged({Update-PMMDeepFindingFilter})
  $Script:DeepControls.Stop.Add_Click({try{if($Script:DeepRepairSessionId){Stop-PMMRepairSession $Script:DeepRepairSessionId|Out-Null}else{Stop-PMMBackgroundOperation};$Script:DeepControls.Status.Text=L 'Cancellation requested; recovery records are preserved.' 'Cancelacion solicitada; se conservan los datos de recuperacion.'}catch{Handle-UIError $_ 'Repair cancellation'}})
  $Script:DeepControls.OpenChat.Add_Click({try{if(-not$Script:DeepRepairSessionId){throw (L 'Start an automatic solution from the analysis first.' 'Inicia primero una solucion automatica desde el analisis.')};$s=Get-PMMRepairSession $Script:DeepRepairSessionId;if($s.ThreadId){[void](Open-PMMDesktopLink ('codex://threads/'+$s.ThreadId))}else{$Script:DeepControls.Status.Text=$s.LastMessage}}catch{Handle-UIError $_ 'GPTD'}})
  $Script:DeepControls.History.Add_Click({try{Show-PMMRepairHistory}catch{Handle-UIError $_ 'Repair history'}})
  $Script:DeepControls.Source.Add_Click({Show-PMMUpdateSourceDialog})
  $Script:DeepControls.AIPolicy.Add_Click({try{Show-PMMAIPolicyDialog}catch{Handle-UIError $_ 'AI policy'}})
  $Script:DeepControls.ResumeAI.Add_Click({try{if(-not$Script:DeepRepairSessionId){throw (L 'Create an investigation session first.' 'Crea primero una sesion de investigacion.')};Start-PMMRepairAgentJob $Script:DeepRepairSessionId|Out-Null}catch{Handle-UIError $_ 'Continue investigation'}})
  $timer=[Windows.Threading.DispatcherTimer]::new();$timer.Interval=[TimeSpan]::FromSeconds(2)
  $Script:PMMNextModuleCheck=[DateTime]::UtcNow.AddSeconds(30)
  $timer.Add_Tick({
    if([DateTime]::UtcNow -gt $Script:PMMNextModuleCheck){
      $Script:PMMNextModuleCheck=[DateTime]::UtcNow.AddSeconds(30)
      try{
        if(-not$Script:BackgroundOperationKind -and -not(Get-PMMModuleRuntimeSnapshot).Busy){
          $changed=$false
          foreach($module in $Script:PMMModuleRuntime.Catalog){if((Get-Item -LiteralPath $module.Path).LastWriteTimeUtc -gt $Script:PMMModuleScanUtc){$changed=$true;break}}
          if($changed){$reload=Request-PMMModuleReload;$Script:PMMModuleScanUtc=[DateTime]::UtcNow;if($reload.Status -in @('Rejected','RestartRequired')){$Script:DeepControls.Status.Text=$reload.Reason}}
        }
      }catch{}
    }
    if($Script:DeepRepairSessionId){try{$s=Get-PMMRepairSession $Script:DeepRepairSessionId;$Script:DeepControls.Status.Text=$s.Status+' - '+$s.LastMessage}catch{}}})
  $Script:PMMModuleScanUtc=[DateTime]::UtcNow
  $timer.Start();$Window.Add_Closed({$timer.Stop()}.GetNewClosure())
  $pendingRecovery=@(Get-PMMPendingDeploymentRecovery)
  if($pendingRecovery.Count){
    $Script:DeepControls.Status.Text=L 'Interrupted deployment requires recovery before another deployment.' 'Un despliegue interrumpido requiere recuperacion antes de volver a desplegar.'
    $Window.Add_Loaded({try{Start-PMMBackgroundOperation Recovery -OnSuccess {param($r)$Script:DeepControls.Status.Text=$r.ResultText} -OnFailure {param($message)$Script:DeepControls.Status.Text=$message}|Out-Null}catch{$Script:DeepControls.Status.Text=$_.Exception.Message}})
  }
  $latest=Join-Path (Get-PMMAnalysisRoot) 'latest.json'
  if(Test-Path -LiteralPath $latest){try{Show-PMMDeepReport (Read-PMMJsonFile $latest).Id}catch{}}
}
function Show-PMMUpdateSourceDialog {
  $v=New-PMMThemedDialog (L 'Mod update source' 'Origen de actualizaciones')
  $mods=[Windows.Controls.ComboBox]::new();$mods.ItemsSource=@(Get-LibraryMods);$mods.DisplayMemberPath='Name';[void]$v.body.Children.Add($mods)
  $fields=@{}
  foreach($name in @('Provider','ModId','FileId','Repository','ReleaseTag','AssetName','Variant')){
    $label=[Windows.Controls.TextBlock]::new();$label.Text=$name;[void]$v.body.Children.Add($label)
    $box=[Windows.Controls.TextBox]::new();$box.Margin=[Windows.Thickness]::new(2);$fields[$name]=$box;[void]$v.body.Children.Add($box)
  }
  $hint=[Windows.Controls.TextBlock]::new();$hint.Text=L 'Provider: Nexus or GitHub. Link the installed file, not its replacement. Nexus uses ModId/FileId; GitHub uses Repository, ReleaseTag and AssetName.' 'Proveedor: Nexus o GitHub. Vincula el archivo instalado, no su sustituto. Nexus usa ModId/FileId; GitHub usa Repository, ReleaseTag y AssetName.';$hint.TextWrapping='Wrap';[void]$v.body.Children.Add($hint)
  $password=[Windows.Controls.PasswordBox]::new();$password.ToolTip=L 'Optional Nexus API key (encrypted for this Windows user)' 'Clave API Nexus opcional (cifrada para este usuario de Windows)';[void]$v.body.Children.Add($password)
  $save=[Windows.Controls.Button]::new();$save.Content=L 'Save source' 'Guardar origen';[void]$v.actions.Children.Add($save)
  $save.Tag=@{Mods=$mods;Fields=$fields;Password=$password;Hint=$hint;Window=$v.window}
  $save.Add_Click({param($sender,$e)
    $state=$sender.Tag;$mods=$state.Mods;$fields=$state.Fields;$password=$state.Password
    try{
    if(-not$mods.SelectedItem){throw 'Select a mod.'}
    $origin=[pscustomobject]@{Schema='PMM_MOD_ORIGIN_V1';LocalSha256=$mods.SelectedItem.Hash;IdentityStatus='UserLinked';Name=$mods.SelectedItem.Name;Game='palworld';ArchivePath='';ArchiveSha256='';ArchiveMd5='';SourceUrl='';Version=''}
    foreach($name in $fields.Keys){$origin|Add-Member -NotePropertyName $name -NotePropertyValue $fields[$name].Text.Trim()}
    if($password.SecurePassword.Length){Set-PMMNexusCredential $password.SecurePassword}
    Start-PMMDeepUIOperation DeepSource @{ModName=$mods.SelectedItem.Name;Origin=$origin} {param($r)$Script:DeepControls.Status.Text=$r.ResultText}
    $state.Window.Close()
  }catch{$state.Hint.Text=$_.Exception.Message}})
  [void]$v.window.ShowDialog()
}


function Show-PMMDeepCaseDialog {
  $dialog=New-PMMThemedDialog (L 'Create or link a case' 'Crear o vincular un caso')
  $choices=@([pscustomobject]@{Id='';Label=(L 'New case (reuse matching findings)' 'Nuevo caso (reutilizar hallazgos coincidentes)')})+@(Get-PMMAIIOCases|ForEach-Object{[pscustomobject]@{Id=$_.CaseId;Label=$_.Title+' - '+$_.CaseId}})
  $list=[Windows.Controls.ComboBox]::new();$list.ItemsSource=$choices;$list.DisplayMemberPath='Label';$list.SelectedIndex=0;[void]$dialog.body.Children.Add($list)
  $note=[Windows.Controls.TextBlock]::new();$note.TextWrapping='Wrap';$note.Text=L 'Uses selected findings, or all findings when none are selected. GPTD continues the same case conversation.' 'Utiliza los hallazgos seleccionados, o todos si no hay seleccion. GPTD continua la misma conversacion del caso.';[void]$dialog.body.Children.Add($note)
  foreach($row in @(@('Create / link','Crear / vincular',$false),@('Investigate with GPTD','Investigar con GPTD',$true))){
    $button=[Windows.Controls.Button]::new();$button.Content=L $row[0] $row[1];$button.Tag=@{StartRepair=$row[2];List=$list;Window=$dialog.window;Note=$note};$button.Margin=[Windows.Thickness]::new(4)
    $button.Add_Click({param($sender,$e)
      $state=$sender.Tag
      try{
        $ids=@($Script:DeepControls.Findings.SelectedItems|ForEach-Object{$_.Id})
        $request=@{AnalysisId=$Script:DeepReportView.Id;FindingIds=$ids;ExistingCaseId=$state.List.SelectedItem.Id;StartRepair=[bool]$state.StartRepair;Options=(Get-PMMDeepUIOptions)}
        Start-PMMDeepUIOperation DeepCase $request {
          param($r)
          $Script:DeepControls.Status.Text=(L 'Case: ' 'Caso: ')+$r.CaseId
          if(Get-PMMAnalysisValue $r RepairSessionId ''){$Script:DeepRepairSessionId=$r.RepairSessionId}
          Select-PMMCaseLocation (Get-PMMAIIOCase $r.CaseId)
        }
        $state.Window.Close()
      }catch{$state.Note.Text=$_.Exception.Message}
    })
    [void]$dialog.actions.Children.Add($button)
  }
  [void]$dialog.window.ShowDialog()
}
function Show-PMMDeepFindingDetail {
  $selected=$Script:DeepControls.Findings.SelectedItem;if(-not$selected){return}
  $finding=Read-PMMJsonFile (Join-Path (Get-PMMAnalysisPath $Script:DeepReportView.Id) ('Findings/'+$selected.Id+'.json'))
  $dialog=New-PMMThemedDialog (L 'Finding evidence' 'Evidencia del hallazgo')
  $text=[Windows.Controls.TextBox]::new();$text.IsReadOnly=$true;$text.AcceptsReturn=$true;$text.TextWrapping='Wrap';$text.VerticalScrollBarVisibility='Auto';$text.MaxHeight=500
  $text.Text=$finding.Message+[Environment]::NewLine+$finding.Action+[Environment]::NewLine+($finding.Evidence|ConvertTo-Json -Depth 20)+[Environment]::NewLine+($finding.Limitations -join [Environment]::NewLine)
  [void]$dialog.body.Children.Add($text);[void]$dialog.window.ShowDialog()
}

function Show-PMMRepairHistory {
  if(-not$Script:DeepRepairSessionId){throw (L 'Start or open a repair session first.' 'Inicia o abre una sesion de reparacion primero.')}
  $session=Get-PMMRepairSession $Script:DeepRepairSessionId
  $dialog=New-PMMThemedDialog (L 'Candidates and attempts' 'Candidatos e intentos')
  $text=[Windows.Controls.TextBox]::new();$text.IsReadOnly=$true;$text.AcceptsReturn=$true;$text.TextWrapping='Wrap';$text.VerticalScrollBarVisibility='Auto';$text.MaxHeight=460
  $text.Text=$session.Status+[Environment]::NewLine+$session.LastMessage+[Environment]::NewLine+(@{Candidates=$session.Candidates;Attempts=$session.Attempts;TestRuns=$session.TestRuns;ActiveSeconds=$session.ActiveSeconds;Limits=$session.Options}|ConvertTo-Json -Depth 12)
  [void]$dialog.body.Children.Add($text)
  $root=Get-PMMRepairSessionRoot $session.Id
  $folder=[Windows.Controls.Button]::new();$folder.Content=L 'Open session files' 'Abrir archivos de la sesion'
  $folder.Add_Click({Start-Process explorer.exe -ArgumentList ('"'+$root+'"')}.GetNewClosure());[void]$dialog.actions.Children.Add($folder)
  $response=Join-Path $root 'agent-response.txt'
  if(Test-Path -LiteralPath $response){
    $answer=[Windows.Controls.TextBox]::new();$answer.IsReadOnly=$true;$answer.AcceptsReturn=$true;$answer.TextWrapping='Wrap';$answer.VerticalScrollBarVisibility='Auto';$answer.MaxHeight=180;$answer.Text=[IO.File]::ReadAllText($response);[void]$dialog.body.Children.Add($answer)
  }
  [void]$dialog.window.ShowDialog()
}
