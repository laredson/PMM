# Preserved 1.3.2 definitions; extracted for 1.3.3.
function Update-PMMSavePaneRows {
  try{
    $a=[bool]$Script:ExpSelectedSave.IsExpanded;$b=[bool]$Script:ExpSaveBackups.IsExpanded
    if($a -and $b){$Script:RowSelectedSave.Height=[System.Windows.GridLength]::new(1,[System.Windows.GridUnitType]::Star);$Script:RowSaveBackups.Height=[System.Windows.GridLength]::new(1,[System.Windows.GridUnitType]::Star);$Script:RowSavePaneSplitter.Height=[System.Windows.GridLength]::new(6);$Script:SplSavePanes.Visibility=[System.Windows.Visibility]::Visible}
    elseif($a){$Script:RowSelectedSave.Height=[System.Windows.GridLength]::new(1,[System.Windows.GridUnitType]::Star);$Script:RowSaveBackups.Height=[System.Windows.GridLength]::Auto;$Script:RowSavePaneSplitter.Height=[System.Windows.GridLength]::new(0);$Script:SplSavePanes.Visibility=[System.Windows.Visibility]::Collapsed}
    elseif($b){$Script:RowSelectedSave.Height=[System.Windows.GridLength]::Auto;$Script:RowSaveBackups.Height=[System.Windows.GridLength]::new(1,[System.Windows.GridUnitType]::Star);$Script:RowSavePaneSplitter.Height=[System.Windows.GridLength]::new(0);$Script:SplSavePanes.Visibility=[System.Windows.Visibility]::Collapsed}
    else{$Script:RowSelectedSave.Height=[System.Windows.GridLength]::Auto;$Script:RowSaveBackups.Height=[System.Windows.GridLength]::Auto;$Script:RowSavePaneSplitter.Height=[System.Windows.GridLength]::new(0);$Script:SplSavePanes.Visibility=[System.Windows.Visibility]::Collapsed}
  }catch{}
}

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
  $intro=$form.FindName('TxtModProjectIntro');$intro.Text=L 'PMM saves your idea as a local case. Choose its references and how to work on it: ZIP, MCP or a client. Returned files remain staged until you review and build them.' 'PMM guarda tu idea como un caso local. Elige sus referencias y como trabajar en el: ZIP, MCP o un cliente. Los archivos devueltos quedan preparados hasta que los revises y construyas.'
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
  $prepare=$form.FindName('BtnModProjectPrepare');$prepare.Content=L 'Create and open case' 'Crear y abrir caso'
  try{
    [System.Windows.Automation.AutomationProperties]::SetName($title,[string]$titleLabel.Text)
    [System.Windows.Automation.AutomationProperties]::SetName($idea,[string]$ideaLabel.Text)
    [System.Windows.Automation.AutomationProperties]::SetName($target,[string]$targetLabel.Text)
  }catch{}

  $complete={
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
    $form.Tag=[pscustomobject]@{Title=$projectTitle;Description=$description;TargetHint=$hint}
    $form.DialogResult=$true
  }.GetNewClosure()
  $prepareHandler={& $complete}.GetNewClosure()
  $focusHandler={[void]$title.Focus()}.GetNewClosure()
  $prepare.Add_Click($prepareHandler)
  $form.Add_ContentRendered($focusHandler)

  $result=(Show-PMMStyledDialog $form)
  if($result -ne $true){return $null}
  return $form.Tag
}

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