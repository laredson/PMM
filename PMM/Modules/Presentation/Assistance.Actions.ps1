# ---------------------------------------------------------------------------
# Save backup controls.
# ---------------------------------------------------------------------------
function Update-PMMSavePaneRows {
  try{
    $a=[bool]$Script:ExpSelectedSave.IsExpanded;$b=[bool]$Script:ExpSaveBackups.IsExpanded
    if($a -and $b){$Script:RowSelectedSave.Height=[System.Windows.GridLength]::new(1,[System.Windows.GridUnitType]::Star);$Script:RowSaveBackups.Height=[System.Windows.GridLength]::new(1,[System.Windows.GridUnitType]::Star);$Script:RowSavePaneSplitter.Height=[System.Windows.GridLength]::new(6);$Script:SplSavePanes.Visibility=[System.Windows.Visibility]::Visible}
    elseif($a){$Script:RowSelectedSave.Height=[System.Windows.GridLength]::new(1,[System.Windows.GridUnitType]::Star);$Script:RowSaveBackups.Height=[System.Windows.GridLength]::Auto;$Script:RowSavePaneSplitter.Height=[System.Windows.GridLength]::new(0);$Script:SplSavePanes.Visibility=[System.Windows.Visibility]::Collapsed}
    elseif($b){$Script:RowSelectedSave.Height=[System.Windows.GridLength]::Auto;$Script:RowSaveBackups.Height=[System.Windows.GridLength]::new(1,[System.Windows.GridUnitType]::Star);$Script:RowSavePaneSplitter.Height=[System.Windows.GridLength]::new(0);$Script:SplSavePanes.Visibility=[System.Windows.Visibility]::Collapsed}
    else{$Script:RowSelectedSave.Height=[System.Windows.GridLength]::Auto;$Script:RowSaveBackups.Height=[System.Windows.GridLength]::Auto;$Script:RowSavePaneSplitter.Height=[System.Windows.GridLength]::new(0);$Script:SplSavePanes.Visibility=[System.Windows.Visibility]::Collapsed}
  }catch{}
}
$Script:ExpSelectedSave.Add_Expanded({Update-PMMSavePaneRows});$Script:ExpSelectedSave.Add_Collapsed({Update-PMMSavePaneRows})
$Script:ExpSaveBackups.Add_Expanded({Update-PMMSavePaneRows});$Script:ExpSaveBackups.Add_Collapsed({Update-PMMSavePaneRows})
Update-PMMSavePaneRows
function Refresh-PMMSaveBackupPane {
  try{
    $save=$Script:LstSaves.SelectedItem;$Script:LstSaveBackups.ItemsSource=$null;$Script:TxtSaveBackupDetails.Text=''
    if(-not$save){return}
    $rows=@(Get-PMMSaveBackups $save);$Script:LstSaveBackups.ItemsSource=$rows
    $Script:BtnOpenSaveBackupFolder.IsEnabled=$true;$Script:BtnRestoreSave.IsEnabled=$false
    if($rows.Count -gt 0){$Script:LstSaveBackups.SelectedIndex=0}
    $Script:ExpSaveBackups.Header=((L 'PMM backups made ({0})' 'Backups PMM creados ({0})') -f $rows.Count)
  }catch{Write-PMMLog ('Save backup pane refresh warning: '+$_.Exception.Message)}
}
$Script:LstSaves.Add_SelectionChanged({try{$save=$Script:LstSaves.SelectedItem;if($save){$Script:TxtSaveDetails.Text=(Get-PMMSaveDetails $save|Out-String);$Script:ExpSelectedSave.Header=((L 'Selected save - {0}' 'Save seleccionado - {0}') -f [string]$save.WorldName)};Refresh-PMMSaveBackupPane}catch{$Script:TxtSaveDetails.Text=$_.Exception.Message}})
$Script:LstSaveBackups.Add_SelectionChanged({try{$row=$Script:LstSaveBackups.SelectedItem;$Script:TxtSaveBackupDetails.Text=Get-PMMSaveBackupDetails $row $Script:LstSaves.SelectedItem;$Script:BtnRestoreSave.IsEnabled=($null -ne $row);$Script:BtnOpenSaveBackupFolder.IsEnabled=($null -ne $row)}catch{$Script:TxtSaveBackupDetails.Text=$_.Exception.Message}})
$Script:BtnBackupSave.Add_Click({try{$save=$Script:LstSaves.SelectedItem;if(-not$save){throw(L 'Select a world.' 'Selecciona un mundo.')};$path=Backup-PMMSave $save;$when=(Get-Date).ToString('yyyy-MM-dd HH:mm:ss');$msg=((L 'Backup created successfully' 'Backup creado correctamente')+' - '+$when+' | '+[IO.Path]::GetFileName($path));$Script:TxtStatus.Text=$msg;$Script:TxtSaveBackupStatus.Text=$msg;$Script:TxtSaveBackupStatus.Foreground=$Window.Resources['AccentHeadingGreen'];$Script:TxtSaveBackupStatus.ToolTip=$path;Refresh-PMMSaveBackupPane;Notify-PMMWorkflowStepComplete}catch{Handle-UIError $_ (L 'Save backup' 'Backup de save')}})
$Script:BtnRestoreSave.Add_Click({try{$save=$Script:LstSaves.SelectedItem;if(-not$save){throw(L 'Select a world.' 'Selecciona un mundo.')};$row=$Script:LstSaveBackups.SelectedItem;if(-not$row){throw(L 'Select a PMM backup from the Backups made panel.' 'Selecciona un backup PMM en el panel Backups creados.')};if(Confirm(L 'Restoring this backup will replace the current world. PMM will create a safety backup first. Continue?' 'Restaurar este backup reemplazara el mundo actual. PMM creara antes un backup de seguridad. Continuar?')){[void](Restore-PMMSaveFromArchive $save ([string]$row.Path));Refresh-UI;$Script:TxtStatus.Text=L 'Save restored. A safety backup was created automatically before restore.' 'Save restaurado. Se creo automaticamente un backup de seguridad antes de restaurar.';Notify-PMMWorkflowStepComplete}}catch{Handle-UIError $_ (L 'Save restore' 'Restaurar save')}})
$Script:BtnOpenSaveBackupFolder.Add_Click({try{$row=$Script:LstSaveBackups.SelectedItem;if($row){Start-Process explorer.exe -ArgumentList ('/select,"'+[string]$row.Path+'"')}else{$save=$Script:LstSaves.SelectedItem;if(-not$save){return};$dir=Join-Path (Join-PMMPath 'Saves' 'Backups') ([string]$save.Name);New-Item -ItemType Directory -Force -Path $dir|Out-Null;Start-Process explorer.exe -ArgumentList ('"'+$dir+'"')}}catch{Handle-UIError $_ (L 'Open backup folder' 'Abrir carpeta de backups')}})


# ---------------------------------------------------------------------------
# AI & Help.
# ---------------------------------------------------------------------------
function Select-PMMAIIOUiSession([string]$SessionId) {
  Refresh-PMMAIIOSessions
  if(-not[string]::IsNullOrWhiteSpace($SessionId)){
    [void](Select-PMMSelectorItemId $Script:LstAIIOSessions 'SessionId' $SessionId)
    [void](Set-PMMAIIOActiveSession $SessionId)
    Refresh-PMMAIIOCandidates $SessionId
  }
}

function Get-PMMAIIOSessionForDiagnostic([string]$CaseId) {
  if([string]::IsNullOrWhiteSpace($CaseId)){return $null}
  foreach($row in @(Get-PMMAIIOSessions|Where-Object{-not[bool]$_.Archived})){
    $session=Get-PMMAIIOSession ([string]$row.SessionId)
    if(-not$session){continue}
    $linked=$false
    try{$linked=($CaseId -in @($session.CaseIds|ForEach-Object{[string]$_}))}catch{}
    if(-not$linked){try{$linked=([string]$session.PrimaryTarget.Kind -eq 'DiagnosticCase' -and [string]$session.PrimaryTarget.Id -eq $CaseId)}catch{}}
    if($linked){return $session}
  }
  return $null
}

function Complete-PMMAIIOPrepareUi($Result,[string]$SessionId,[bool]$ExplainManualShare=$false) {
  Select-PMMAIIOUiSession $SessionId
  $template=if($ExplainManualShare){
    L 'AI request ready: {0}. Give this ZIP to the AI yourself. Nothing was uploaded.' 'Peticion para IA lista: {0}. Entrega tu mismo este ZIP a la IA. No se subio nada.'
  }else{
    L 'AI request ready: {0}. Nothing was uploaded.' 'Peticion para IA lista: {0}. No se subio nada.'
  }
  $Script:TxtAIIOStatus.Text=($template -f [string]$Result.ZipPath)
  if(-not[string]::IsNullOrWhiteSpace([string]$Result.ZipPath)){Start-Process explorer.exe -ArgumentList ('/select,"'+[string]$Result.ZipPath+'"')}
}

function Complete-PMMAIIOImportResponseUi($Result,[string]$SessionId) {
  Select-PMMAIIOUiSession $SessionId
  $Script:TxtAIIOStatus.Text=((L 'Response validated: {0} data request(s), {1} staged candidate(s). No candidate was run, applied or deployed.' 'Respuesta validada: {0} peticion(es) de datos, {1} candidato(s) en staging. No se ejecuto, aplico ni desplego ningun candidato.') -f $Result.RequestCount,$Result.CandidateCount)
}

function Complete-PMMAIIOPendingDataUi($Result,[string]$SessionId) {
  Select-PMMAIIOUiSession $SessionId
  $Script:TxtAIIOStatus.Text=((L 'Requested-data ZIP ready: {0}' 'ZIP de datos solicitados listo: {0}') -f [string]$Result.ZipPath)
  if(-not[string]::IsNullOrWhiteSpace([string]$Result.ZipPath)){Start-Process explorer.exe -ArgumentList ('/select,"'+[string]$Result.ZipPath+'"')}
}

function Complete-PMMAIIOCandidateAnalyzeUi($Result) {
  Refresh-UI
  $Script:MainTabs.SelectedItem=$Script:PMMMergeTab
}

function Start-PMMAIIOCandidateAnalyze {
  try{
    [void](Start-PMMBackgroundOperation -Operation Analyze -Force -OnSuccess {param($result) Complete-PMMAIIOCandidateAnalyzeUi $result})
  }catch{Handle-UIError $_ (L 'Analyze AI candidate' 'Analizar candidato IA')}
}

function Complete-PMMAIIOUseCandidateUi($Result,[string]$SessionId) {
  Select-PMMAIIOUiSession $SessionId
  $Script:TxtAIIOStatus.Text=((L 'Experimental candidate validated for case {0}. Analyze is refreshing the plan; Build and Deploy remain explicit.' 'Candidato experimental validado para el caso {0}. Analizar esta actualizando el plan; Build y Deploy siguen siendo explicitos.') -f [string]$Result.CaseId)
  [void]$Window.Dispatcher.BeginInvoke([System.Windows.Threading.DispatcherPriority]::ContextIdle,{Start-PMMAIIOCandidateAnalyze})
}

function Complete-PMMAIIOModBuildUi($Result,[string]$SessionId) {
  Select-PMMAIIOUiSession $SessionId
  $Script:TxtAIIOStatus.Text=((L 'Standalone mod built: {0}. It was not deployed or published. Runtime remains UNPROVEN until you test it in Palworld. If shared, its description must include: {1}' 'Mod independiente creado: {0}. No se desplego ni publico. El runtime sigue UNPROVEN hasta que lo pruebes en Palworld. Si se comparte, su descripcion debe incluir: {1}') -f [string]$Result.OutputPath,[string]$Result.RequiredPublicDescription)
  if(-not[string]::IsNullOrWhiteSpace([string]$Result.OutputPath)){Start-Process explorer.exe -ArgumentList ('/select,"'+[string]$Result.OutputPath+'"')}
}

function Show-PMMModCreationProjectDialog {
  # This dialog belongs to the WPF application. Dynamic layout is required:
  # Windows text scaling may grow typography independently from physical DPI.
  # Fixed WinForms coordinates made labels overlap and pushed actions offscreen.
  $dialogMarkup=@'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Width="780" MinWidth="620" SizeToContent="Height"
        WindowStartupLocation="CenterOwner" ResizeMode="CanResizeWithGrip"
        ShowInTaskbar="False" FontFamily="Segoe UI" FontSize="14"
        UseLayoutRounding="True" SnapsToDevicePixels="True">
  <ScrollViewer VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled">
    <Grid Margin="24">
      <Grid.RowDefinitions>
        <RowDefinition Height="Auto"/><RowDefinition Height="Auto"/>
        <RowDefinition Height="Auto"/><RowDefinition Height="Auto"/>
        <RowDefinition Height="Auto"/><RowDefinition Height="Auto"/>
        <RowDefinition Height="Auto"/><RowDefinition Height="Auto"/>
        <RowDefinition Height="Auto"/><RowDefinition Height="Auto"/>
        <RowDefinition Height="Auto"/>
      </Grid.RowDefinitions>
      <TextBlock x:Name="TxtModProjectHeading" Grid.Row="0" FontSize="22" FontWeight="SemiBold" TextWrapping="Wrap"/>
      <TextBlock x:Name="TxtModProjectIntro" Grid.Row="1" Margin="0,6,0,18" TextWrapping="Wrap" Foreground="{DynamicResource MutedText}"/>
      <TextBlock x:Name="LblModProjectTitle" Grid.Row="2" FontWeight="SemiBold" Margin="0,0,0,5"/>
      <TextBox x:Name="TxtModProjectTitle" Grid.Row="3" MinHeight="34" VerticalContentAlignment="Center"/>
      <TextBlock x:Name="LblModProjectIdea" Grid.Row="4" FontWeight="SemiBold" Margin="0,15,0,5"/>
      <TextBox x:Name="TxtModProjectIdea" Grid.Row="5" MinHeight="170" MaxHeight="280"
               AcceptsReturn="True" TextWrapping="Wrap" VerticalScrollBarVisibility="Auto"/>
      <TextBlock x:Name="LblModProjectTarget" Grid.Row="6" FontWeight="SemiBold" Margin="0,15,0,5" TextWrapping="Wrap"/>
      <TextBox x:Name="TxtModProjectTarget" Grid.Row="7" MinHeight="34" VerticalContentAlignment="Center"/>
      <Border Grid.Row="8" Margin="0,15,0,0" Padding="10,8" CornerRadius="6"
              Background="{DynamicResource CardAltBackground}" BorderBrush="{DynamicResource CardBorder}" BorderThickness="1">
        <TextBlock x:Name="TxtModProjectReference" TextWrapping="Wrap" Foreground="{DynamicResource MutedText}"/>
      </Border>
      <TextBlock x:Name="TxtModProjectValidation" Grid.Row="9" Margin="0,9,0,0" TextWrapping="Wrap"
                 Foreground="#B91C1C" FontWeight="SemiBold" Visibility="Collapsed"/>
      <Grid Grid.Row="10" Margin="0,18,0,0">
        <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
        <StackPanel Grid.Column="1" Orientation="Horizontal">
          <Button x:Name="BtnModProjectCancel" MinWidth="110" IsCancel="True"/>
          <Button x:Name="BtnModProjectSave" MinWidth="135"/>
          <Button x:Name="BtnModProjectPrepare" MinWidth="145" IsDefault="True" FontWeight="SemiBold"/>
        </StackPanel>
      </Grid>
    </Grid>
  </ScrollViewer>
</Window>
'@
  [xml]$dialogXaml=$dialogMarkup
  $dialogReader=[System.Xml.XmlNodeReader]::new($dialogXaml)
  try{$form=[Windows.Markup.XamlReader]::Load($dialogReader)}finally{$dialogReader.Dispose()}

  # Window-local PMM resources keep the modal legible in every installed theme.
  foreach($key in @($Window.Resources.Keys)){try{$form.Resources[$key]=$Window.Resources[$key]}catch{}}
  try{$form.Background=$form.Resources['CardBackground'];$form.Foreground=$form.Resources['PrimaryText']}catch{}
  try{$form.Owner=$Window}catch{}
  try{$form.Icon=$Window.Icon}catch{}
  $work=[System.Windows.SystemParameters]::WorkArea
  $form.MaxWidth=[Math]::Max(520.0,[double]$work.Width-48.0)
  $form.MaxHeight=[Math]::Max(480.0,[double]$work.Height-48.0)
  $form.MinWidth=[Math]::Min(620.0,[double]$form.MaxWidth)
  $form.Width=[Math]::Min(780.0,[double]$form.MaxWidth)
  $form.Title=L 'New standalone mod project' 'Nuevo proyecto independiente de mod'

  $heading=$form.FindName('TxtModProjectHeading');$heading.Text=L 'Describe the mod you want to create' 'Describe el mod que quieres crear'
  $intro=$form.FindName('TxtModProjectIntro');$intro.Text=L 'PMM creates a local AIIO exchange. An external AI may query your indexed Vanilla GameReference and ask PMM for exact, bounded asset families. Returned files stay inactive until you inspect and explicitly build them.' 'PMM crea un intercambio AIIO local. Una IA externa puede consultar tu GameReference Vanilla indexada y pedir a PMM familias exactas y acotadas. Los archivos devueltos quedan inactivos hasta que los inspecciones y los crees expresamente.'
  $titleLabel=$form.FindName('LblModProjectTitle');$titleLabel.Text=L 'Project title' 'Titulo del proyecto'
  $title=$form.FindName('TxtModProjectTitle')
  $ideaLabel=$form.FindName('LblModProjectIdea');$ideaLabel.Text=L 'What should the mod do?' 'Que debe hacer el mod?'
  $idea=$form.FindName('TxtModProjectIdea')
  $targetLabel=$form.FindName('LblModProjectTarget');$targetLabel.Text=L 'Optional exact asset or search hint (for example: BP_PlayerBase)' 'Asset exacto o pista de busqueda opcional (por ejemplo: BP_PlayerBase)'
  $target=$form.FindName('TxtModProjectTarget')
  $reference=$form.FindName('TxtModProjectReference')
  try{$proof=Get-PMMAIIOGameReferenceProof;$reference.Text=((L 'Vanilla GameReference: {0} ({1} indexed families)' 'GameReference Vanilla: {0} ({1} familias indexadas)') -f [string]$proof.Status,[int]$proof.FamilyCount)}catch{$reference.Text=L 'Vanilla GameReference status could not be read.' 'No se pudo leer el estado de la GameReference Vanilla.'}
  $validation=$form.FindName('TxtModProjectValidation')
  $cancel=$form.FindName('BtnModProjectCancel');$cancel.Content=L 'Cancel' 'Cancelar'
  $save=$form.FindName('BtnModProjectSave');$save.Content=L 'Save project' 'Guardar proyecto'
  $prepare=$form.FindName('BtnModProjectPrepare');$prepare.Content=L 'Create AI ZIP' 'Crear ZIP IA'
  try{
    [System.Windows.Automation.AutomationProperties]::SetName($title,[string]$titleLabel.Text)
    [System.Windows.Automation.AutomationProperties]::SetName($idea,[string]$ideaLabel.Text)
    [System.Windows.Automation.AutomationProperties]::SetName($target,[string]$targetLabel.Text)
  }catch{}

  $complete={
    param([bool]$Prepare)
    $projectTitle=([string]$title.Text).Trim();$description=([string]$idea.Text).Trim();$hint=([string]$target.Text).Trim()
    if([string]::IsNullOrWhiteSpace($projectTitle)){
      $validation.Text=L 'Enter a project title.' 'Introduce un titulo de proyecto.'
      $validation.Visibility=[System.Windows.Visibility]::Visible
      [void]$title.Focus();return
    }
    if([string]::IsNullOrWhiteSpace($description)){
      $validation.Text=L 'Describe what the mod should do.' 'Describe que debe hacer el mod.'
      $validation.Visibility=[System.Windows.Visibility]::Visible
      [void]$idea.Focus();return
    }
    $form.Tag=[pscustomobject]@{Title=$projectTitle;Description=$description;TargetHint=$hint;Prepare=$Prepare}
    $form.DialogResult=$true
  }.GetNewClosure()
  $saveHandler={& $complete $false}.GetNewClosure()
  $prepareHandler={& $complete $true}.GetNewClosure()
  $focusHandler={[void]$title.Focus()}.GetNewClosure()
  $save.Add_Click($saveHandler)
  $prepare.Add_Click($prepareHandler)
  $form.Add_ContentRendered($focusHandler)

  $result=(Show-PMMStyledDialog $form)
  if($result -ne $true){return $null}
  return $form.Tag
}

$Script:BtnAIHelpRefresh.Add_Click({try{Refresh-PMMAIHelpDiagnostics;Refresh-PMMAIHelpBadge;$Script:TxtAIHelpDiagnosticStatus.Text=L 'Cases refreshed.' 'Casos actualizados.'}catch{Handle-UIError $_ (L 'Refresh AI assistance' 'Actualizar ayuda IA')}})
$Script:LstAIHelpDiagnostics.Add_SelectionChanged({try{if(-not[bool]$Script:AIHelpUiRefreshing){$Script:AIHelpNewCaseMode=$false;Update-PMMAIHelpDiagnosticSelection}}catch{}})
$Script:BtnAIHelpNewCase.Add_Click({try{Set-PMMAIHelpNewCaseMode $true -Clear;try{$Script:TxtAIHelpDiagnosticTitle.Focus()|Out-Null}catch{}}catch{Handle-UIError $_ (L 'Open new AI assistance case' 'Abrir nuevo caso de ayuda IA')}})
$Script:BtnAIHelpNewModProject.Add_Click({
  try{
    $project=Show-PMMModCreationProjectDialog;if(-not$project){return}
    $targets=@();if(-not[string]::IsNullOrWhiteSpace([string]$project.TargetHint)){$targets=@([pscustomobject]@{Kind='GameReferenceSearchHint';Id=[string]$project.TargetHint;UserSuspects=$false;CauseConfirmed=$false})}
    $session=New-PMMAIIOSession -Title ([string]$project.Title) -Description ([string]$project.Description) -TaskType CREATE_MOD -TargetKind GameReference -TargetId ([string]$project.TargetHint) -SelectedTargets $targets
    $sessionId=[string]$session.SessionId;Select-PMMAIIOUiSession $sessionId;$Script:AIHelpTabs.SelectedItem=$Script:PMMHelpCaseTab
    if([bool]$project.Prepare){$done={param($result) Complete-PMMAIIOPrepareUi $result $sessionId $true}.GetNewClosure();[void](Start-PMMBackgroundOperation -Operation AIIOPrepare -SessionId $sessionId -OnSuccess $done)}
    else{$Script:TxtAIIOStatus.Text=((L 'Standalone mod project saved locally: {0}. It has not been uploaded.' 'Proyecto independiente de mod guardado localmente: {0}. No se ha subido.') -f $sessionId)}
  }catch{Handle-UIError $_ (L 'Create standalone mod project' 'Crear proyecto independiente de mod')}
})
$Script:BtnAIHelpCancelNewCase.Add_Click({try{Set-PMMAIHelpNewCaseMode $false}catch{}})
$Script:BtnAIHelpRefreshKnowledge.Add_Click({try{$done={param($result) Refresh-PMMAIHelpKnowledge;Refresh-PMMAIHelpBadge};[void](Start-PMMBackgroundOperation -Operation AIIOArtifactRefresh -OnSuccess $done)}catch{Handle-UIError $_ (L 'Refresh Knowledge and storage' 'Actualizar Knowledge y almacenamiento')}})
function New-PMMAIHelpCaseFromUi {
  $option=$Script:CmbAIHelpDiagnosticType.SelectedItem
  $type=if($option){[string]$option.Id}else{'UNKNOWN'}
  $feature=if($option){[string]$option.Feature}else{'Other'}
  $targets=@([pscustomobject]@{Kind='PMMFeature';Id=$feature;UserSuspects=$true;CauseConfirmed=$false})
  $case=New-PMMDiagnosticCase -Type $type -Title ([string]$Script:TxtAIHelpDiagnosticTitle.Text) -UserDescription ([string]$Script:TxtAIHelpDiagnosticDescription.Text) -SelectedTargets $targets -AttentionEligible $false -IncludePalworldLogSummary:([bool]$Script:ChkAIHelpIncludePalLog.IsChecked)
  Refresh-PMMAIHelpDiagnostics
  [void](Select-PMMSelectorItemId $Script:LstAIHelpDiagnostics 'CaseId' ([string]$case.CaseId))
  Set-PMMAIHelpNewCaseMode $false
  $Script:TxtAIHelpDiagnosticStatus.Text=((L 'Diagnostic case created locally: {0}. It has not been uploaded.' 'Caso de diagnostico creado localmente: {0}. No se ha subido.') -f [string]$case.CaseId)
  return $case
}
$Script:BtnAIHelpCreateCase.Add_Click({try{[void](New-PMMAIHelpCaseFromUi)}catch{Handle-UIError $_ (L 'Create diagnostic case' 'Crear caso de diagnostico')}})
$Script:BtnAIHelpCreateAndPrepareCase.Add_Click({
  try{
    $case=New-PMMAIHelpCaseFromUi
    if($case){$Script:BtnAIHelpPrepareDiagnostic.RaiseEvent([System.Windows.RoutedEventArgs]::new([System.Windows.Controls.Button]::ClickEvent))}
  }catch{Handle-UIError $_ (L 'Create AI assistance ZIP' 'Crear ZIP de ayuda IA')}
})
$Script:BtnAIHelpPrepareDiagnostic.Add_Click({
  try{
    $row=$Script:LstAIHelpDiagnostics.SelectedItem;if(-not$row){throw (L 'Select a diagnostic case.' 'Selecciona un caso de diagnostico.')}
    $casePath=Get-PMMDiagnosticCasePath ([string]$row.CaseId);$case=Get-Content -LiteralPath $casePath -Raw -Encoding UTF8|ConvertFrom-Json
    if([string]$case.Status -ne 'Open'){$Script:TxtAIHelpDiagnosticStatus.Text=L 'This is resolved history. Create or select an open diagnostic before preparing an AI task.' 'Este es un historial resuelto. Crea o selecciona un diagnostico abierto antes de preparar una tarea para IA.';return}
    $session=Get-PMMAIIOSessionForDiagnostic ([string]$case.CaseId)
    if(-not$session){$session=New-PMMAIIOSessionFromDiagnostic $case}
    $sessionId=[string]$session.SessionId
    Select-PMMAIIOUiSession $sessionId;$Script:AIHelpTabs.SelectedItem=$Script:PMMHelpCaseTab
    if([string]$session.Status -ne 'Draft'){
      $Script:TxtAIIOStatus.Text=((L 'This diagnostic already uses session {0} ({1}). PMM opened the existing session instead of creating another one.' 'Este diagnostico ya usa la sesion {0} ({1}). PMM abrio la sesion existente en lugar de crear otra.') -f $sessionId,[string]$session.Status)
      return
    }
    $done={param($result) Complete-PMMAIIOPrepareUi $result $sessionId $true}.GetNewClosure()
    [void](Start-PMMBackgroundOperation -Operation AIIOPrepare -SessionId $sessionId -OnSuccess $done)
  }catch{Handle-UIError $_ (L 'Prepare diagnostic for AI' 'Preparar diagnostico para IA')}
})
$Script:LstAIIOSessions.Add_SelectionChanged({
  try{
    if([bool]$Script:AIHelpUiRefreshing){return}
    $session=Get-PMMSelectedAIIOSession
    if($session){Refresh-PMMAIIOCandidates ([string]$session.SessionId);$Script:TxtAIIOStatus.Text=((L 'Session {0} - {1} - iteration {2}. Returned candidates remain staged until you explicitly review and act.' 'Sesion {0} - {1} - iteracion {2}. Los candidatos devueltos quedan en staging hasta que los revises y actues expresamente.') -f [string]$session.SessionId,[string]$session.Status,[int]$session.Iteration)}
    Update-PMMAIIOHandoffButton
  }catch{}
})
$Script:LstAIIOCandidates.Add_SelectionChanged({try{Update-PMMAIIOCandidateSelection}catch{}})
$Script:BtnAIIONewSession.Add_Click({
  try{
    $type=[string]$Script:CmbAIIOType.SelectedValue;if(-not$type){$type='UNKNOWN'}
    $title=[string]$Script:TxtAIIOTitle.Text;if([string]::IsNullOrWhiteSpace($title)){$title=(L 'AI & Help task' 'Tarea de IA y ayuda')}
    $targetKind=[string]$Script:CmbAIOTargetKind.SelectedValue;if(-not$targetKind){$targetKind='Palworld'}
    $targetId=[string]$Script:TxtAIOTargetId.Text
    $targets=@();if($targetId){$targets=@([pscustomobject]@{Kind=$targetKind;Id=$targetId;UserSuspects=$true;CauseConfirmed=$false})}
    $session=New-PMMAIIOSession -Title $title -Description ([string]$Script:TxtAIIODescription.Text) -TaskType $type -TargetKind $targetKind -TargetId $targetId -SelectedTargets $targets
    Select-PMMAIIOUiSession ([string]$session.SessionId)
    $Script:TxtAIIOStatus.Text=((L 'Local session created: {0}. Press Prepare for AI when the description is ready.' 'Sesion local creada: {0}. Pulsa Preparar para IA cuando la descripcion este lista.') -f [string]$session.SessionId)
  }catch{Handle-UIError $_ (L 'Create AIIO session' 'Crear sesion AIIO')}
})
$Script:BtnAIIOPrepare.Add_Click({
  try{
    $session=Get-PMMSelectedAIIOSession
    if(-not$session){
      $Script:BtnAIIONewSession.RaiseEvent([System.Windows.RoutedEventArgs]::new([System.Windows.Controls.Button]::ClickEvent));$session=Get-PMMSelectedAIIOSession
    }
    if(-not$session){throw (L 'Create or select a session first.' 'Crea o selecciona primero una sesion.')}
    $sessionId=[string]$session.SessionId
    if([string]$session.Status -ne 'Draft'){
      $Script:TxtAIIOStatus.Text=((L 'Session {0} is already {1}; PMM will not create a duplicate request. Import its response, prepare requested data, or create a new session.' 'La sesion {0} ya esta en estado {1}; PMM no creara una peticion duplicada. Importa su respuesta, prepara los datos solicitados o crea otra sesion.') -f $sessionId,[string]$session.Status)
      return
    }
    $done={param($result) Complete-PMMAIIOPrepareUi $result $sessionId $false}.GetNewClosure()
    [void](Start-PMMBackgroundOperation -Operation AIIOPrepare -SessionId $sessionId -OnSuccess $done)
  }catch{Handle-UIError $_ (L 'Prepare task for AI' 'Preparar tarea para IA')}
})
$Script:BtnAIIOImportResponse.Add_Click({
  try{
    $dialog=[Microsoft.Win32.OpenFileDialog]::new();$dialog.Title=L 'Import AI response ZIP' 'Importar ZIP de respuesta IA';$dialog.Filter='PMM AI response (*.zip)|*.zip'
    if($dialog.ShowDialog() -ne $true){return}
    $zipPath=[string]$dialog.FileName;$hint=Get-PMMAIIOResponsePackageHint $zipPath;$session=$null
    if([string]$hint.Kind -eq 'ThemeResponse'){
      $result=Import-PMMThemeAIResponse $zipPath
      $Script:ActiveThemeDraft=$result.Draft;Refresh-PMMThemeEditorCatalog -Force;$Script:LstThemeDrafts.SelectedValue=[string]$result.Draft.DraftId;Show-PMMThemeDraft $result.Draft
      $Script:AIHelpTabs.SelectedItem=$Script:PMMHelpThemeTab
      $Script:TxtThemeEditorStatus.Text=((L 'Standalone AI theme validated into draft {0}. It remains uninstalled until you review and explicitly install it.' 'Tema IA independiente validado como borrador {0}. Sigue sin instalar hasta que lo revises y lo instales expresamente.') -f [string]$result.Draft.Name)
      return
    }
    if([string]$hint.SessionId){$session=Get-PMMAIIOSession ([string]$hint.SessionId)}
    elseif([string]$hint.CaseId){
      foreach($candidate in @(Get-PMMAIIOSessions|Where-Object{-not[bool]$_.Archived})){
        $full=Get-PMMAIIOSession ([string]$candidate.SessionId)
        if($full -and [string]$hint.CaseId -in @($full.CaseIds|ForEach-Object{[string]$_})){$session=$full;break}
      }
      if(-not$session){$session=Get-PMMSelectedAIIOSession}
    }
    if(-not$session){throw (L 'PMM could not match this package to a known AI exchange. Standard responses route themselves by their embedded session id; standalone cooked solutions still require their exact existing case.' 'PMM no pudo relacionar este paquete con un intercambio IA conocido. Las respuestas estandar se enrutan solas por su id de sesion; las soluciones cooked independientes aun necesitan su caso exacto existente.')}
    $sessionId=[string]$session.SessionId
    Select-PMMAIIOUiSession $sessionId
    $done={param($result) Complete-PMMAIIOImportResponseUi $result $sessionId}.GetNewClosure()
    [void](Start-PMMBackgroundOperation -Operation AIIOImportResponse -SessionId $sessionId -InputZip $zipPath -OnSuccess $done)
  }catch{Handle-UIError $_ (L 'Import AI response' 'Importar respuesta IA')}
})
$Script:BtnAIIOContinue.Add_Click({
  try{$session=Get-PMMSelectedAIIOSession;if(-not$session){throw (L 'Select a session.' 'Selecciona una sesion.')};$sessionId=[string]$session.SessionId;$done={param($result) Complete-PMMAIIOPendingDataUi $result $sessionId}.GetNewClosure();[void](Start-PMMBackgroundOperation -Operation AIIOPendingData -SessionId $sessionId -OnSuccess $done)}catch{Handle-UIError $_ (L 'Prepare requested AI data' 'Preparar datos pedidos por IA')}
})
$Script:BtnAIIOArchive.Add_Click({try{$session=Get-PMMSelectedAIIOSession;if(-not$session){return};if(Confirm ((L 'Archive session {0}? Its history and artifacts remain on disk.' 'Archivar la sesion {0}? Su historial y artefactos seguiran guardados.') -f [string]$session.SessionId)){Set-PMMAIIOSessionArchived ([string]$session.SessionId) $true|Out-Null;Refresh-PMMAIHelpUi}}catch{Handle-UIError $_ (L 'Archive AIIO session' 'Archivar sesion AIIO')}})
$Script:BtnAIIOOpenWorkspace.Add_Click({try{$session=Get-PMMSelectedAIIOSession;$path=if($session){Get-PMMAIIOSessionPath ([string]$session.SessionId)}else{Get-PMMPath 'AIIO'};Start-Process explorer.exe -ArgumentList ('"'+$path+'"')}catch{Handle-UIError $_ (L 'Open AI workspace' 'Abrir espacio de IA')}})
$Script:BtnAIIOOpenHandoff.Add_Click({try{$session=Get-PMMSelectedAIIOSession;if(-not$session){throw (L 'Select an AI exchange first.' 'Selecciona primero un intercambio IA.')};$path=[string](Get-PMMAIIOLatestHandoffPath ([string]$session.SessionId));if([string]::IsNullOrWhiteSpace($path)){throw (L 'The selected exchange does not have an available handoff ZIP.' 'El intercambio seleccionado no tiene un ZIP handoff disponible.')};Start-Process explorer.exe -ArgumentList ('/select,"'+$path+'"')}catch{Handle-UIError $_ (L 'Open latest AI handoff' 'Abrir ultimo handoff IA')}})
$Script:BtnAIIOOpenCandidate.Add_Click({try{$row=$Script:LstAIIOCandidates.SelectedItem;if(-not$row){return};Start-Process explorer.exe -ArgumentList ('"'+[string]$row.Root+'"')}catch{Handle-UIError $_ (L 'Inspect AI candidate' 'Inspeccionar candidato IA')}})
$Script:BtnAIIOUseCandidate.Add_Click({
  try{
    $session=Get-PMMSelectedAIIOSession;$row=$Script:LstAIIOCandidates.SelectedItem
    if(-not$session -or -not$row){throw (L 'Select a session and candidate.' 'Selecciona una sesion y un candidato.')}
    if([string]$row.InputSchema -eq 'PMM_MOD_CREATION_CANDIDATE_V1'){
      $warning=L "Build this standalone mod candidate?`n`nPMM will verify the staged bytes again, require the exact current Vanilla GameReference identity, run a read-only AssetReader probe on every returned asset header, pack only the declared cooked tree plus inert PMM attribution metadata, and verify every PAK entry. The PAK will remain local, undeployed, unpublished and runtime UNPROVEN.`n`nYou must test it in Palworld. If you share or publish it, its public description must include: This mod was created with PMM assistance.`n`nContinue?" "Crear este candidato de mod independiente?`n`nPMM volvera a verificar los bytes en staging, exigira la identidad exacta de la GameReference Vanilla vigente, ejecutara una prueba de solo lectura con AssetReader sobre cada cabecera devuelta, empaquetara solo el arbol cooked declarado mas metadatos inertes de atribucion PMM y verificara cada entrada del PAK. El PAK quedara local, sin desplegar, sin publicar y runtime UNPROVEN.`n`nDebes probarlo en Palworld. Si lo compartes o publicas, su descripcion publica debe incluir: This mod was created with PMM assistance.`n`nContinuar?"
      if(-not(Confirm $warning)){return}
      $sessionId=[string]$session.SessionId;$solutionId=[string]$row.SolutionId
      $done={param($result) Complete-PMMAIIOModBuildUi $result $sessionId}.GetNewClosure()
      [void](Start-PMMBackgroundOperation -Operation AIIOModBuild -SessionId $sessionId -SolutionId $solutionId -OnSuccess $done)
      return
    }
    $warning=L "Use this returned cooked-family candidate in Merge?`n`nPMM will revalidate the exact current case, source hashes, ZIP paths, cooked-family topology, output hashes and a read-only AssetReader parse. This cannot prove gameplay semantics. The candidate remains experimental and runtime UNPROVEN until you test the resulting exact build in Palworld.`n`nNothing will be deployed automatically. Continue?" "Usar este candidato cooked devuelto en Merge?`n`nPMM volvera a validar el caso exacto vigente, hashes fuente, rutas ZIP, topologia de la familia cooked, hashes de salida y una lectura con AssetReader. Esto no puede demostrar la semantica de gameplay. El candidato seguira experimental y runtime UNPROVEN hasta probar el build exacto en Palworld.`n`nNo se desplegara nada automaticamente. Continuar?"
    if(-not(Confirm $warning)){return}
    $sessionId=[string]$session.SessionId;$solutionId=[string]$row.SolutionId
    $done={param($result) Complete-PMMAIIOUseCandidateUi $result $sessionId}.GetNewClosure()
    [void](Start-PMMBackgroundOperation -Operation AIIOUseCandidate -SessionId $sessionId -SolutionId $solutionId -OnSuccess $done)
  }catch{Handle-UIError $_ (L 'Use AI candidate in Merge' 'Usar candidato IA en Merge')}
})
$Script:BtnAIHelpOpenKnowledge.Add_Click({try{Start-Process explorer.exe -ArgumentList ('"'+(Get-PMMPath 'CKL')+'"')}catch{Handle-UIError $_ (L 'Open Knowledge library' 'Abrir biblioteca Knowledge')}})
$Script:CmbAIHelpFeedbackBuild.Add_SelectionChanged({try{Update-PMMAIHelpFeedbackSelection}catch{}})
$Script:BtnAIHelpCreateFeedback.Add_Click({
  try{
    $kind=[string]$Script:CmbAIHelpFeedbackType.SelectedValue;if([string]::IsNullOrWhiteSpace($kind)){$kind='GENERAL_COMMENT'}
    $patch=Get-PMMAIHelpFeedbackPatch
    $result=New-PMMUserFeedbackFile -Kind $kind -Title ([string]$Script:TxtAIHelpFeedbackTitle.Text) -Comments ([string]$Script:TxtAIHelpFeedbackComments.Text) -Patch $patch
    $message=((L 'Inspectable feedback file created: {0}. Share it manually if you want; nothing was uploaded.' 'Archivo de feedback inspeccionable creado: {0}. Compartelo manualmente si quieres; no se subio nada.') -f [string]$result.Path)
    $Script:TxtAIHelpFeedbackStatus.Text=$message;$Script:TxtStatus.Text=$message
    Start-Process explorer.exe -ArgumentList ('/select,"'+[string]$result.Path+'"')
  }catch{Handle-UIError $_ (L 'Create manual feedback file' 'Crear archivo de feedback manual') -NoDiagnostic}
})
$Script:BtnAIHelpGenerateFeedback.Add_Click({
  try{
    $patch=Get-PMMAIHelpFeedbackPatch
    if(-not$patch){throw (L 'Choose a compatibility merge in this Feedback tab first.' 'Elige primero un merge de compatibilidad en esta pestana Feedback.')}
    $summary=Get-PMMBuildValidationSummary $patch
    if([string]::IsNullOrWhiteSpace([string]$summary.LatestEventId)){throw (L 'Validate this exact deployed merge first. Feedback is tied to a deterministic build and validation event.' 'Valida primero este merge desplegado exacto. El feedback queda ligado a un build determinista y a su evento de validacion.')}
    $result=Export-PMMBuildValidationFeedback ([string]$summary.LatestEventId)
    $message=((L 'Exact validation feedback created: {0}. Share it manually if you want; nothing was uploaded.' 'Feedback de validacion exacta creado: {0}. Compartelo manualmente si quieres; no se subio nada.') -f [string]$result.Path)
    $Script:TxtAIHelpFeedbackStatus.Text=$message;$Script:TxtStatus.Text=$message
    Start-Process explorer.exe -ArgumentList ('/select,"'+[string]$result.Path+'"')
  }catch{Handle-UIError $_ (L 'Generate local validation feedback' 'Generar feedback local de validacion') -NoDiagnostic}
})
$Script:BtnAIHelpOpenFeedback.Add_Click({try{Start-Process explorer.exe -ArgumentList ('"'+(Get-PMMPath 'ValidationFeedback')+'"')}catch{Handle-UIError $_ (L 'Open local feedback files' 'Abrir feedback local')}})
$Script:BtnAIHelpUploadFeedback.Add_Click({Show-Info (L 'Online upload is not connected in this release. Create an inspectable file and share it manually.' 'La subida online no esta conectada en esta version. Crea un archivo inspeccionable y compartelo manualmente.')})
$Script:BtnAIHelpCleanup.Add_Click({
  try{
    $registry=Update-PMMArtifactRegistry;$disposable=@($registry.Artifacts|Where-Object{[string]$_.Category -eq 'DISPOSABLE' -and -not[bool]$_.ProtectedByDefault});[int64]$bytes=0;foreach($row in $disposable){$bytes+=[int64]$row.Size}
    if($disposable.Count -eq 0){Show-Info (L 'No disposable artifact is currently eligible for cleanup.' 'No hay artefactos desechables disponibles para limpiar.');return}
    $mib=1048576.0
    $question=((L 'Delete {0} allowlisted disposable item(s), approximately {1:N1} MiB? Current builds, sessions, fixes, saves, Knowledge and protected evidence are excluded.' 'Eliminar {0} elemento(s) desechables permitidos, aproximadamente {1:N1} MiB? Se excluyen builds actuales, sesiones, fixes, saves, Knowledge y evidencia protegida.') -f $disposable.Count,([double]$bytes/$mib))
    if(Confirm $question){$result=Remove-PMMDisposableArtifacts -Confirm:$false;[void](Get-PMMArtifactStorageSummary -Refresh);Refresh-PMMAIHelpKnowledge;Show-Info ((L 'Disposable cleanup removed {0:N1} MiB.' 'La limpieza elimino {0:N1} MiB desechables.') -f ([double]$result.RemovedBytes/$mib))}
  }catch{Handle-UIError $_ (L 'Disposable cleanup' 'Limpieza desechable')}
})

$Script:BtnThemeEditorNew.Add_Click({try{$source=$Script:CmbThemeEditorSource.SelectedItem;if(-not$source){throw (L 'Choose a source scheme.' 'Elige un esquema de origen.')};$draft=New-PMMThemeDraft -SourceDefinition $source;Refresh-PMMThemeEditorCatalog;$Script:LstThemeDrafts.SelectedValue=[string]$draft.DraftId;Show-PMMThemeDraft $draft}catch{Handle-UIError $_ (L 'Create color-scheme draft' 'Crear borrador de esquema')}})
$Script:BtnThemeEditorLoad.Add_Click({try{$row=$Script:LstThemeDrafts.SelectedItem;if(-not$row){throw (L 'Select a draft.' 'Selecciona un borrador.')};$draft=Get-PMMThemeDraft ([string]$row.DraftId);if(-not$draft){throw (L 'Draft could not be read.' 'No se pudo leer el borrador.')};Show-PMMThemeDraft $draft}catch{Handle-UIError $_ (L 'Load color-scheme draft' 'Cargar borrador de esquema')}})
$Script:BtnThemeEditorSave.Add_Click({try{$Script:ActiveThemeDraft=Update-PMMThemeEditorDraftFromUi -Save;$Script:TxtThemeEditorStatus.Text=L 'Draft saved and validated locally.' 'Borrador guardado y validado localmente.'}catch{Handle-UIError $_ (L 'Save color-scheme draft' 'Guardar borrador de esquema')}})
$Script:BtnThemeEditorPreview.Add_Click({try{$Script:ActiveThemeDraft=Update-PMMThemeEditorDraftFromUi -Save;$definition=Get-PMMThemeDraftPreviewDefinition $Script:ActiveThemeDraft;Apply-PMMThemeDefinition $definition;$Script:ThemePreviewActive=$true;$Script:TxtThemeEditorStatus.Text=L 'Temporary whole-app preview is active. Revert or install it before closing.' 'Vista previa temporal activa en toda la aplicacion. Revierte o instala antes de cerrar.'}catch{Handle-UIError $_ (L 'Preview color scheme' 'Vista previa del esquema')}})
$Script:BtnThemeEditorRevert.Add_Click({try{Apply-PMMTheme ([string](Get-PMMConfig).Theme);$Script:ThemePreviewActive=$false;$Script:TxtThemeEditorStatus.Text=L 'Preview reverted to the saved Settings scheme.' 'Vista previa revertida al esquema guardado en Opciones.'}catch{Handle-UIError $_ (L 'Revert theme preview' 'Revertir vista previa')}})
$Script:BtnThemeEditorInstall.Add_Click({
  try{
    $draft=Update-PMMThemeEditorDraftFromUi -Save;$id=[string]$draft.ThemeId;$existing=@(Get-PMMUserThemeFiles|ForEach-Object{Read-PMMThemeFileIdentity $_.FullName}|Where-Object{$_ -and [string]$_.Id -ieq $id})
    $replace=$false;if($existing.Count -gt 0){$replace=Confirm ((L 'Replace the installed user scheme "{0}"? PMM will keep a backup.' 'Reemplazar el esquema del usuario "{0}"? PMM guardara un backup.') -f $id);if(-not$replace){return}}
    $result=Install-PMMThemeDraft $draft -AllowReplace:$replace;Refresh-PMMThemeOptions $id;Refresh-PMMThemeEditorCatalog;$Script:TxtThemeEditorStatus.Text=((L 'Scheme installed locally: {0}. It is now available in Settings under user schemes.' 'Esquema instalado localmente: {0}. Ya esta disponible en Opciones dentro de esquemas del usuario.') -f [string]$result.Path)
  }catch{Handle-UIError $_ (L 'Install color scheme' 'Instalar esquema de color')}
})
$Script:BtnThemeEditorExport.Add_Click({try{$draft=Update-PMMThemeEditorDraftFromUi -Save;$dialog=[System.Windows.Forms.FolderBrowserDialog]::new();$dialog.Description=L 'Choose the export folder' 'Elige la carpeta de exportacion';if($dialog.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK){return};$result=Export-PMMThemeDraft $draft ([string]$dialog.SelectedPath);$Script:TxtThemeEditorStatus.Text=((L 'Theme export created: {0}' 'Exportacion de tema creada: {0}') -f [string]$result.Path);Start-Process explorer.exe -ArgumentList ('/select,"'+[string]$result.Path+'"')}catch{Handle-UIError $_ (L 'Export color scheme' 'Exportar esquema de color')}})
$Script:BtnThemeEditorCreateAI.Add_Click({try{$draft=Update-PMMThemeEditorDraftFromUi -Save;$result=New-PMMThemeAIRequest $draft ([string]$Script:TxtThemeEditorPrompt.Text);$Script:TxtThemeEditorStatus.Text=((L 'Offline theme AI request created: {0}. Nothing was uploaded.' 'Peticion offline de tema para IA creada: {0}. No se subio nada.') -f [string]$result.Path);Start-Process explorer.exe -ArgumentList ('/select,"'+[string]$result.Path+'"')}catch{Handle-UIError $_ (L 'Create theme with AI' 'Crear tema con IA')}})
$Script:BtnThemeEditorImportAI.Add_Click({try{$dialog=[Microsoft.Win32.OpenFileDialog]::new();$dialog.Title=L 'Import AI theme response' 'Importar respuesta IA de tema';$dialog.Filter='PMM theme AI response (*.zip)|*.zip';if($dialog.ShowDialog() -ne $true){return};$result=Import-PMMThemeAIResponse ([string]$dialog.FileName);$Script:ActiveThemeDraft=$result.Draft;Refresh-PMMThemeEditorCatalog;$Script:LstThemeDrafts.SelectedValue=[string]$result.Draft.DraftId;Show-PMMThemeDraft $result.Draft;$Script:TxtThemeEditorStatus.Text=((L 'AI theme response validated into draft {0}. It is not installed; review and preview it first.' 'Respuesta IA de tema validada como borrador {0}. No esta instalada; revisala y previsualizala primero.') -f [string]$result.Draft.Name)}catch{Handle-UIError $_ (L 'Import AI theme response' 'Importar respuesta IA de tema')}})
$Script:BtnThemeEditorDelete.Add_Click({try{$row=$Script:LstThemeDrafts.SelectedItem;if(-not$row){return};if(Confirm ((L 'Delete draft "{0}" and its copied image assets? Installed themes are not affected.' 'Eliminar el borrador "{0}" y sus imagenes copiadas? No afecta a temas instalados.') -f [string]$row.Name)){Remove-PMMThemeDraft ([string]$row.DraftId);if($Script:ActiveThemeDraft -and [string]$Script:ActiveThemeDraft.DraftId -eq [string]$row.DraftId){$Script:ActiveThemeDraft=$null;$Script:PnlThemeEditorRows.Children.Clear()};Refresh-PMMThemeEditorCatalog}}catch{Handle-UIError $_ (L 'Delete theme draft' 'Eliminar borrador de tema')}})


# ---------------------------------------------------------------------------
# AI & Help Settings / Knowledge actions.
# ---------------------------------------------------------------------------
$Script:BtnBuildGameReference.Add_Click({
  try{
    $cfg=Get-PMMConfig
    if(-not$cfg.GamePath){throw (L 'Configure Palworld first.' 'Configura Palworld primero.')}
    $gr=Get-PMMGameReferenceState
    if([string]$gr.Status -eq 'Current'){
      $question=L 'Rebuild the local Game Reference now? This reads Pal-Windows.pak in the background and replaces only PMM Workspace\GameReference. Palworld is never modified.' 'Volver a crear Game Reference local? Esto lee Pal-Windows.pak en segundo plano y solo sustituye PMM Workspace\GameReference. Palworld no se modifica.'
      if(-not(Confirm $question)){return}
    }
    # Game Reference is itself a workflow step. With SemiAUTO, a manual click
    # arms continuation; with one-shot AUTO already running, it preserves that
    # run and completion resumes from the new reference state.
    if(-not$Script:AutoPipelineActive -and [bool]$Script:TglAutoMode.IsChecked){Start-PMMAutoPipeline}
    $Script:GameReferenceResumeAuto=[bool]$Script:AutoPipelineActive
    $started=Start-PMMGameReferenceBuild
    if(-not$started -and $Script:GameReferenceResumeAuto){Write-PMMLog 'Manual Game Reference did not start; AUTO remains armed for the next valid workflow action.'}
  }catch{Handle-UIError $_ (L 'Build Game Reference' 'Crear Game Reference')}
})
$Script:BtnOpenGameReference.Add_Click({try{$p=Get-PMMGameReferenceRoot;if(-not(Test-Path -LiteralPath $p -PathType Container)){New-Item -ItemType Directory -Force -Path $p|Out-Null};Start-Process explorer.exe -ArgumentList ('"'+$p+'"')}catch{Handle-UIError $_ (L 'Open Game Reference' 'Abrir Game Reference')}})
$Script:BtnOpenKnowledge.Add_Click({try{Start-Process explorer.exe -ArgumentList ('"'+(Get-PMMPath 'CKL')+'"')}catch{Handle-UIError $_ (L 'Open Knowledge library' 'Abrir biblioteca Knowledge')}})
$Script:BtnOpenReviewCases.Add_Click({try{$p=Get-PMMPath 'Review';if(-not(Test-Path -LiteralPath $p -PathType Container)){New-Item -ItemType Directory -Force -Path $p|Out-Null};Start-Process explorer.exe -ArgumentList ('"'+$p+'"')}catch{Handle-UIError $_ (L 'Open AI review cases' 'Abrir casos para IA')}})
$Script:BtnExportKnowledgeContribution.Add_Click({
  try{
    $items=@(Get-PMMKnowledgeContributionCandidates)
    if($items.Count -eq 0){Show-Info (L 'No imported AI/manual solution is available yet. This button is used after PMM validates a returned solution and you test it successfully in Palworld.' 'Todavia no hay ninguna solucion IA/manual importada. Este boton se usa despues de que PMM valide una solucion devuelta y la pruebes correctamente en Palworld.');return}
    $chosen=$null
    if($items.Count -eq 1){$chosen=$items[0]}else{
      Add-Type -AssemblyName System.Windows.Forms
      $form=New-Object System.Windows.Forms.Form;$form.Text=L 'Choose tested AI/manual case' 'Elegir caso IA/manual probado';$form.Width=850;$form.Height=390;$form.StartPosition='CenterScreen'
      $label=New-Object System.Windows.Forms.Label;$label.Left=14;$label.Top=14;$label.Width=800;$label.Height=40;$label.Text=L 'Choose the solution you have already tested successfully in Palworld.' 'Elige la solucion que ya has probado correctamente dentro de Palworld.'
      $list=New-Object System.Windows.Forms.ListBox;$list.Left=14;$list.Top=58;$list.Width=805;$list.Height=235;$list.DisplayMember='Display'
      foreach($x in $items){[void]$list.Items.Add($x)};$list.SelectedIndex=0
      $ok=New-Object System.Windows.Forms.Button;$ok.Text='OK';$ok.Left=650;$ok.Top=305;$ok.Width=75;$ok.DialogResult=[System.Windows.Forms.DialogResult]::OK
      $cancel=New-Object System.Windows.Forms.Button;$cancel.Text=L 'Cancel' 'Cancelar';$cancel.Left=735;$cancel.Top=305;$cancel.Width=85;$cancel.DialogResult=[System.Windows.Forms.DialogResult]::Cancel
      $form.Controls.AddRange(@($label,$list,$ok,$cancel));$form.AcceptButton=$ok;$form.CancelButton=$cancel
      if((Show-PMMStyledDialog $form) -ne [System.Windows.Forms.DialogResult]::OK){return};$chosen=$list.SelectedItem
    }
    if(-not$chosen){return}
    $warning=L "Only create a runtime contribution after you tested this exact imported solution in Palworld and the expected behaviors worked. Mark this case as a user-reported runtime PASS and package it for maintainer/community validation?`n`nThe package can contain the original AIIO handoff, returned solution and validation/runtime evidence. Whole source mod PAKs are not copied into it. Send it to the PMM maintainer/approved private intake.`n`nThis does NOT auto-authorize a Knowledge recipe on this PC." "Crea una contribucion runtime solo despues de probar esta solucion importada exacta dentro de Palworld y confirmar los comportamientos esperados. Marcar este caso como PASS runtime reportado por el usuario y empaquetarlo para validacion comunitaria/mantenedor?`n`nEl paquete puede contener la entrega AIIO original, la solucion devuelta y la evidencia de validacion/runtime. No se copian PAK fuente completos dentro del paquete. Envialo al mantenedor/servicio privado aprobado de PMM.`n`nEsto NO autoriza automaticamente una receta Knowledge en este PC."
    if(-not(Confirm $warning)){return}
    $zip=Export-PMMKnowledgeContribution ([string]$chosen.CaseId)
    $Script:TxtStatus.Text=((L 'Contribution package created: {0}' 'Paquete de contribucion creado: {0}') -f $zip)
    Start-Process explorer.exe -ArgumentList ('/select,"'+$zip+'"')
  }catch{Handle-UIError $_ (L 'Create Knowledge contribution' 'Crear contribucion Knowledge')}
})
$Script:BtnOpenKnowledgeContributions.Add_Click({try{$p=Get-PMMKnowledgeContributionRoot;Start-Process explorer.exe -ArgumentList ('"'+$p+'"')}catch{Handle-UIError $_ (L 'Open contribution folder' 'Abrir carpeta de contribuciones')}})
$Script:BtnSetupDeps.Add_Click({ try { & (Join-Path $Script:Root 'Modules\Bootstrap\Setup-Dependencies.ps1'); Refresh-UI; $Script:TxtStatus.Text=L 'Dependency preparation finished.' 'Proceso de dependencias terminado.' } catch { Handle-UIError $_ (L 'Dependency preparation' 'Preparacion de dependencias') } })
$Script:BtnApplyLanguage.Add_Click({
  try {
    $cfg = Get-PMMConfig
    $selectedCode = [string]$Script:CmbLanguage.SelectedValue
    $cfg.Language = if ($selectedCode -eq 'es') { 'es' } else { 'en' }
    Save-PMMConfig $cfg
    $Script:TxtStatus.Text=L 'Language saved. Restart Palworld Manager Merger to apply it to the entire interface.' 'Idioma guardado. Reinicia Palworld Manager Merger para aplicarlo a toda la interfaz.'
  } catch { Handle-UIError $_ 'Language' }
})

$Script:BtnResetLayout.Add_Click({
  try {
    Reset-PMMLayout
    $Script:TxtStatus.Text=L 'Workspace layout reset. The new divider positions will be remembered.' 'Distribucion restablecida. Las nuevas posiciones de los divisores se recordaran.'
  } catch { Handle-UIError $_ (L 'Reset workspace layout' 'Restablecer distribucion') }
})

