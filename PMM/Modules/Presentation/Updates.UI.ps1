Set-StrictMode -Version 2
$Script:UpdateBusy=$false
$Script:UpdateRows=@()
$Script:PendingFreeUpdateHash=''
$Script:PendingDeferredLaunching=$false
# GuidedFlow can run before WPF creates the Updates tab. Keep early startup passes harmless under StrictMode.
$Script:BtnCheckUpdates=$null
$Script:BtnUpdateSelected=$null
$Script:BtnUpdateSafe=$null
$Script:BtnCancelUpdates=$null
$Script:BtnRestoreUpdate=$null
$Script:BtnDeleteUpdateArchive=$null

function New-PMMUpdateRequest([string]$Operation,$Value) {
  $root=Join-PMMPath 'Cache' 'UpdateRequests';[void][IO.Directory]::CreateDirectory($root)
  $path=Join-Path $root ([Guid]::NewGuid().ToString('N')+'.json');Write-PMMJsonAtomic $path $Value -Depth 30
  $path
}
function Set-PMMUpdateBusy([bool]$Busy) {
  $Script:UpdateBusy=$Busy
  foreach($button in @($Script:BtnCheckUpdates,$Script:BtnUpdateSelected,$Script:BtnUpdateSafe,$Script:BtnRestoreUpdate,$Script:BtnDeleteUpdateArchive)){if($button){$button.IsEnabled=-not$Busy}}
  if($Script:BtnCancelUpdates){$Script:BtnCancelUpdates.IsEnabled=($Busy -or -not[string]::IsNullOrWhiteSpace($Script:PendingFreeUpdateHash))}
  if($Script:PrgUpdates){$Script:PrgUpdates.IsIndeterminate=$Busy;$Script:PrgUpdates.Visibility=if($Busy){'Visible'}else{'Collapsed'}}
  Update-PMMCancelButtonState
}
function Refresh-PMMUpdatesUI {
  if(-not$Script:DgUpdates){return}
  $plan=Read-PMMUpdatePlan;$rows=@()
  if($plan){
    $rows=@($plan.Results|ForEach-Object{
      [pscustomobject]@{Mod=$_.Mod;Provider=$_.Origin.Provider;Installed=$(if($_.Origin.Version){$_.Origin.Version}else{$_.Origin.FileId});Available=$(if($_.Candidate){$_.Candidate.Version}else{''});Variant=$(if($_.Origin.Variant){$_.Origin.Variant}else{$_.Origin.AssetName});Status=$_.Status;Deployment=$(if((Find-PMMLibraryMod $_.Mod).Enabled){'Enabled'}else{'Disabled'});Action=$(if($_.Status -eq 'UPDATE_AVAILABLE'){'Review / Update'}elseif($_.Status -eq 'UNKNOWN'){'Link source'}else{'—'});Record=$_}
    })
  }
  $Script:UpdateRows=$rows;$Script:DgUpdates.ItemsSource=$rows
  $account=Get-PMMNexusAccount;$limits=Get-PMMNexusLimits
  $limitText=if($limits -and ($limits.HourlyRemaining -or $limits.DailyRemaining)){(' · limits H:{0} D:{1}' -f $limits.HourlyRemaining,$limits.DailyRemaining)}else{''}
  $Script:TxtNexusAccount.Text=if($account){'Nexus: '+$account.Name+' · '+$(if($account.IsPremium){'Premium'}else{'Free'})+$limitText}else{L 'Nexus: not connected' 'Nexus: sin conectar'}
  $Script:BtnDisconnectNexus.IsEnabled=[bool]$account
  $Script:BtnConnectNexus.IsEnabled=-not[bool]$account
  $state=Get-PMMNxmHandlerState;$Script:BtnNxmHandler.Content=if($state.Enabled){L 'Restore previous NXM handler' 'Restaurar gestor NXM anterior'}else{L 'Use PMM for NXM links' 'Usar PMM para enlaces NXM'}
  $archives=@(Get-PMMUpdateArchives);$Script:DgUpdateArchives.ItemsSource=$archives
  $measure=$archives|Measure-Object Bytes -Sum;$bytes=if($measure -and $null -ne $measure.Sum){[int64]$measure.Sum}else{0L};$Script:TxtUpdateArchive.Text=((L 'Archived versions: {0} · {1:N1} MiB' 'Versiones archivadas: {0} · {1:N1} MiB') -f $archives.Count,($bytes/1MB))
}
function Start-PMMUpdateCheckUI {
  $request=New-PMMUpdateRequest UpdateCheck @{Schema='PMM_UPDATE_REQUEST_V1';Action='Check'}
  [void](Start-PMMBackgroundOperation -Operation UpdateCheck -RequestPath $request -OnSuccess {param($result)Refresh-PMMUpdatesUI;$Script:TxtUpdatesStatus.Text=$result.ResultText;if($Script:AutoPipelineActive){Invoke-PMMAutoContinue}} -OnFailure {param($message)$Script:TxtUpdatesStatus.Text=$message})
}
function Start-PMMUpdateApplyUI([string]$Hash,[bool]$Auto) {
  $plan=Read-PMMUpdatePlan;if(-not$plan -or -not$plan.IsCurrent){throw 'Check updates again before applying.'}
  $selected=@($plan.Results|Where-Object{$_.Status -eq 'UPDATE_AVAILABLE' -and ($Hash -eq '*' -or $_.LocalSha256 -eq $Hash)})
  if(-not$selected.Count){throw 'No update candidate is selected.'}
  if(-not$Auto -and -not(Confirm ((L 'Apply {0} selected update(s)? PMM will download, analyze, archive and replace only candidates that pass validation.' 'Aplicar {0} actualizacion(es)? PMM descargara, analizara, archivara y reemplazara solo candidatos que superen la validacion.') -f $selected.Count))){return}
  $account=Get-PMMNexusAccount
  if($account -and -not$account.IsPremium){
    $nexus=@($selected|Where-Object{$_.Candidate.Provider -eq 'Nexus'}|Select-Object -First 1)
    if($nexus.Count){
      if(-not(Get-PMMNxmHandlerState).Enabled){throw 'Enable PMM for NXM links before starting a free-account download.'}
      $Script:PendingFreeUpdateHash=[string]$nexus[0].LocalSha256
      if($Script:BtnCancelUpdates){$Script:BtnCancelUpdates.IsEnabled=$true}
      Start-Process ([string]$nexus[0].Candidate.Url)
      $Script:TxtUpdatesStatus.Text=L 'Waiting for Nexus confirmation. Press Download on the Nexus page; PMM will continue automatically.' 'Esperando confirmacion de Nexus. Pulsa Download en Nexus; PMM continuara automaticamente.'
      return
    }
  }
  $request=New-PMMUpdateRequest UpdateApply @{Schema='PMM_UPDATE_REQUEST_V1';Action='Apply';LocalSha256=$Hash;Auto=$Auto}
  [void](Start-PMMBackgroundOperation -Operation UpdateApply -RequestPath $request -OnSuccess {param($result)Refresh-UI;Refresh-PMMUpdatesUI;$Script:TxtUpdatesStatus.Text=$result.ResultText;if($Script:AutoPipelineActive){Invoke-PMMAutoContinue}} -OnFailure {param($message)$Script:TxtUpdatesStatus.Text=$message})
}
function Start-PMMDeferredUpdateApplyUI($Pending) {
  $items=@($Pending.Items);if(-not$items.Count){Clear-PMMPendingUpdateApply;return}
  $request=New-PMMUpdateRequest UpdateApply @{Schema='PMM_UPDATE_REQUEST_V1';Action='ResumeDeferred';DeferredItems=$items;Auto=[bool]$Pending.Auto}
  Clear-PMMPendingUpdateApply;$Script:PendingDeferredLaunching=$true
  try{[void](Start-PMMBackgroundOperation -Operation UpdateApply -RequestPath $request -OnSuccess {param($result)$Script:PendingDeferredLaunching=$false;Refresh-UI;Refresh-PMMUpdatesUI;$Script:TxtUpdatesStatus.Text=$result.ResultText;if($Script:AutoPipelineActive){Invoke-PMMAutoContinue}} -OnFailure {param($message)$Script:PendingDeferredLaunching=$false;$Script:TxtUpdatesStatus.Text=$message})}catch{$Script:PendingDeferredLaunching=$false;throw}
}
function Show-PMMNexusConnectDialog {
  $view=New-PMMThemedDialog (L 'Connect Nexus' 'Conectar Nexus')
  $note=[Windows.Controls.TextBlock]::new();$note.TextWrapping='Wrap';$note.Text=L 'Development mode: paste your personal Nexus API key. It is encrypted for your Windows user and never written to logs.' 'Modo desarrollo: pega tu API key personal de Nexus. Se cifra para tu usuario de Windows y nunca se escribe en registros.';[void]$view.body.Children.Add($note)
  $box=[Windows.Controls.PasswordBox]::new();$box.Margin=[Windows.Thickness]::new(0,8,0,8);[void]$view.body.Children.Add($box)
  $connect=[Windows.Controls.Button]::new();$connect.Content=L 'Connect' 'Conectar';$connect.IsDefault=$true;$cancel=[Windows.Controls.Button]::new();$cancel.Content=L 'Cancel' 'Cancelar';$cancel.IsCancel=$true
  $window=$view.window;$connect.Add_Click({try{[void](Connect-PMMNexusAccount $box.SecurePassword);$window.DialogResult=$true;$window.Close()}catch{Show-Error $_.Exception.Message}}.GetNewClosure())
  [void]$view.actions.Children.Add($connect);[void]$view.actions.Children.Add($cancel);[void]$window.ShowDialog();Refresh-PMMUpdatesUI
}
function Show-PMMUpdateSourceLinkDialog {
  $row=$Script:DgUpdates.SelectedItem;if(-not$row){throw 'Select a mod first.'};$mod=Find-PMMLibraryMod $row.Mod
  $view=New-PMMThemedDialog (L 'Link Nexus source' 'Vincular origen Nexus');$grid=[Windows.Controls.Grid]::new()
  foreach($i in 1..4){[void]$grid.RowDefinitions.Add([Windows.Controls.RowDefinition]::new())}
  $url=[Windows.Controls.TextBox]::new();$url.ToolTip='https://www.nexusmods.com/palworld/mods/123?tab=files&file_id=456'
  $file=[Windows.Controls.TextBox]::new();$variant=[Windows.Controls.TextBox]::new()
  $labels=@(@('Nexus URL',$url),@('Installed FileId',$file),@('Exact variant',$variant));$r=0
  foreach($pair in $labels){$line=[Windows.Controls.StackPanel]::new();$line.Margin=[Windows.Thickness]::new(0,4,0,4);$label=[Windows.Controls.TextBlock]::new();$label.Text=$pair[0];[void]$line.Children.Add($label);[void]$line.Children.Add($pair[1]);[Windows.Controls.Grid]::SetRow($line,$r++);[void]$grid.Children.Add($line)}
  [void]$view.body.Children.Add($grid);$save=[Windows.Controls.Button]::new();$save.Content=L 'Save link' 'Guardar vinculo';$save.IsDefault=$true;$cancel=[Windows.Controls.Button]::new();$cancel.Content=L 'Cancel' 'Cancelar';$cancel.IsCancel=$true;$window=$view.window
  $save.Add_Click({try{[void](Set-PMMNexusOriginFromUrl $mod $url.Text $file.Text $variant.Text);$window.DialogResult=$true;$window.Close();Start-PMMUpdateCheckUI}catch{Show-Error $_.Exception.Message}}.GetNewClosure())
  [void]$view.actions.Children.Add($save);[void]$view.actions.Children.Add($cancel);[void]$window.ShowDialog()
}
function Restore-PMMPendingNxmUI {
  $plan=Read-PMMUpdatePlan;if(-not$plan -or -not$plan.IsCurrent){return}
  $queued=@($plan.Results|Where-Object{$_.Status -eq 'UPDATE_AVAILABLE' -and (Test-PMMNxmQueueMatch ([string]$_.Origin.ModId) ([string]$_.Candidate.FileId))}|Select-Object -First 1)
  if(-not$queued.Count){return}
  $Script:PendingFreeUpdateHash=[string]$queued[0].LocalSha256;$Script:MainTabs.SelectedItem=$Script:PMMMergeTab;$Script:ModsWorkflowTabs.SelectedItem=$Script:TabUpdates
  $Script:TxtUpdatesStatus.Text=L 'Nexus confirmed the file. PMM is continuing the pending update.' 'Nexus confirmo el archivo. PMM continua la actualizacion pendiente.'
}
function Initialize-PMMUpdatesUI {
  if(-not$Script:UpdatesHost){return};Repair-PMMIncompleteUpdateTransactions
  $root=[Windows.Controls.DockPanel]::new();$root.Margin=[Windows.Thickness]::new(8);$Script:UpdatesHost.Content=$root
  $top=[Windows.Controls.StackPanel]::new();[Windows.Controls.DockPanel]::SetDock($top,'Top');[void]$root.Children.Add($top)
  $accountRow=[Windows.Controls.WrapPanel]::new();$Script:TxtNexusAccount=[Windows.Controls.TextBlock]::new();$Script:TxtNexusAccount.Margin=[Windows.Thickness]::new(4,8,12,4);$Script:TxtNexusAccount.VerticalAlignment='Center';[void]$accountRow.Children.Add($Script:TxtNexusAccount)
  $Script:BtnConnectNexus=[Windows.Controls.Button]::new();$Script:BtnConnectNexus.Content=L 'Connect Nexus' 'Conectar Nexus';$Script:BtnDisconnectNexus=[Windows.Controls.Button]::new();$Script:BtnDisconnectNexus.Content=L 'Disconnect' 'Desconectar';$Script:BtnNxmHandler=[Windows.Controls.Button]::new()
  foreach($b in @($Script:BtnConnectNexus,$Script:BtnDisconnectNexus,$Script:BtnNxmHandler)){[void]$accountRow.Children.Add($b)};[void]$top.Children.Add($accountRow)
  $actions=[Windows.Controls.WrapPanel]::new();$Script:BtnCheckUpdates=[Windows.Controls.Button]::new();$Script:BtnCheckUpdates.Content=L 'Check updates' 'Buscar actualizaciones';$Script:BtnUpdateSelected=[Windows.Controls.Button]::new();$Script:BtnUpdateSelected.Content=L 'Update selected' 'Actualizar seleccionado';$Script:BtnUpdateSafe=[Windows.Controls.Button]::new();$Script:BtnUpdateSafe.Content=L 'Update safe candidates' 'Actualizar candidatos seguros';$Script:BtnCancelUpdates=[Windows.Controls.Button]::new();$Script:BtnCancelUpdates.Content=L 'Cancel' 'Cancelar';$Script:BtnCancelUpdates.IsEnabled=$false
  $open=[Windows.Controls.Button]::new();$open.Content=L 'Open Nexus' 'Abrir Nexus';$link=[Windows.Controls.Button]::new();$link.Content=L 'Link source' 'Vincular origen';$skip=[Windows.Controls.Button]::new();$skip.Content=L 'Skip for this library' 'Omitir para esta biblioteca'
  foreach($b in @($Script:BtnCheckUpdates,$link,$open,$Script:BtnUpdateSelected,$Script:BtnUpdateSafe,$Script:BtnCancelUpdates,$skip)){[void]$actions.Children.Add($b)};[void]$top.Children.Add($actions)
  $Script:PrgUpdates=[Windows.Controls.ProgressBar]::new();$Script:PrgUpdates.Height=8;$Script:PrgUpdates.Visibility='Collapsed';[void]$top.Children.Add($Script:PrgUpdates)
  $Script:TxtUpdatesStatus=[Windows.Controls.TextBlock]::new();$Script:TxtUpdatesStatus.TextWrapping='Wrap';$Script:TxtUpdatesStatus.Margin=[Windows.Thickness]::new(4);[void]$top.Children.Add($Script:TxtUpdatesStatus)
  $tabs=[Windows.Controls.TabControl]::new();[void]$root.Children.Add($tabs)
  $current=[Windows.Controls.TabItem]::new();$current.Header=L 'Available updates' 'Actualizaciones disponibles';$Script:DgUpdates=[Windows.Controls.DataGrid]::new();$Script:DgUpdates.IsReadOnly=$true;$Script:DgUpdates.AutoGenerateColumns=$false;$Script:DgUpdates.SelectionMode='Single'
  foreach($c in @(@('Mod','Mod',180),@('Provider','Origin',70),@('Variant','Variant',150),@('Installed','Installed',85),@('Available','Available',85),@('Status','Status',140),@('Deployment','Deployment',90),@('Action','Action',130))){$col=[Windows.Controls.DataGridTextColumn]::new();$col.Header=$c[1];$col.Binding=[Windows.Data.Binding]::new($c[0]);$col.Width=$c[2];[void]$Script:DgUpdates.Columns.Add($col)}
  $current.Content=$Script:DgUpdates;[void]$tabs.Items.Add($current)
  $history=[Windows.Controls.TabItem]::new();$history.Header=L 'History & rollback' 'Historial y restauracion';$historyPanel=[Windows.Controls.DockPanel]::new();$history.Content=$historyPanel
  $historyActions=[Windows.Controls.WrapPanel]::new();[Windows.Controls.DockPanel]::SetDock($historyActions,'Top');$Script:TxtUpdateArchive=[Windows.Controls.TextBlock]::new();$Script:TxtUpdateArchive.Margin=[Windows.Thickness]::new(4,8,12,4);[void]$historyActions.Children.Add($Script:TxtUpdateArchive)
  $Script:BtnRestoreUpdate=[Windows.Controls.Button]::new();$Script:BtnRestoreUpdate.Content=L 'Restore previous version' 'Restaurar version anterior';$Script:BtnDeleteUpdateArchive=[Windows.Controls.Button]::new();$Script:BtnDeleteUpdateArchive.Content=L 'Delete selected archive' 'Borrar archivo seleccionado';$openArchive=[Windows.Controls.Button]::new();$openArchive.Content=L 'Open archive folder' 'Abrir carpeta de archivo';foreach($b in @($Script:BtnRestoreUpdate,$Script:BtnDeleteUpdateArchive,$openArchive)){[void]$historyActions.Children.Add($b)};[void]$historyPanel.Children.Add($historyActions)
  $Script:DgUpdateArchives=[Windows.Controls.DataGrid]::new();$Script:DgUpdateArchives.IsReadOnly=$true;$Script:DgUpdateArchives.AutoGenerateColumns=$true;[void]$historyPanel.Children.Add($Script:DgUpdateArchives);[void]$tabs.Items.Add($history)
  $Script:BtnConnectNexus.Add_Click({Show-PMMNexusConnectDialog});$Script:BtnDisconnectNexus.Add_Click({if(Confirm(L 'Disconnect Nexus and remove the encrypted local credential?' 'Desconectar Nexus y borrar la credencial local cifrada?')){Disconnect-PMMNexusAccount;Refresh-PMMUpdatesUI}})
  $Script:BtnNxmHandler.Add_Click({try{$s=Get-PMMNxmHandlerState;if($s.Enabled){[void](Disable-PMMNxmHandler)}else{if($s.CurrentCommand -and -not(Confirm(L 'Another application currently handles NXM links. PMM will preserve it and can restore it later. Continue?' 'Otra aplicacion gestiona los enlaces NXM. PMM la conservara y podra restaurarla. Continuar?'))){return};[void](Enable-PMMNxmHandler)};Refresh-PMMUpdatesUI}catch{Handle-UIError $_ 'NXM'}})
  $skip.Add_Click({Skip-PMMUpdatesForCurrentLibrary;$Script:TxtUpdatesStatus.Text=L 'Updates skipped for the current library fingerprint.' 'Actualizaciones omitidas para el estado actual de la biblioteca.';Update-PMMGuidedActionState})
  $Script:BtnCheckUpdates.Add_Click({try{Start-PMMUpdateCheckUI}catch{Handle-UIError $_ 'Updates'}});$Script:BtnUpdateSelected.Add_Click({try{$row=$Script:DgUpdates.SelectedItem;if(-not$row){throw 'Select an update.'};Start-PMMUpdateApplyUI $row.Record.LocalSha256 $false}catch{Handle-UIError $_ 'Update'}})
  $Script:BtnUpdateSafe.Add_Click({try{Start-PMMUpdateApplyUI '*' $true}catch{Handle-UIError $_ 'AUTO Updates'}});$Script:BtnCancelUpdates.Add_Click({if($Script:UpdateBusy){Stop-PMMBackgroundOperation}elseif($Script:PendingFreeUpdateHash){$Script:PendingFreeUpdateHash='';$Script:BtnCancelUpdates.IsEnabled=$false;$Script:TxtUpdatesStatus.Text=L 'Nexus confirmation wait cancelled.' 'Espera de confirmacion de Nexus cancelada.'}});$link.Add_Click({try{Show-PMMUpdateSourceLinkDialog}catch{Handle-UIError $_ 'Link source'}})
  $open.Add_Click({$row=$Script:DgUpdates.SelectedItem;if($row -and $row.Record.Candidate){Start-Process $row.Record.Candidate.Url}elseif($row -and $row.Record.Origin.SourceUrl){Start-Process $row.Record.Origin.SourceUrl}})
  $Script:BtnRestoreUpdate.Add_Click({try{$row=$Script:DgUpdateArchives.SelectedItem;if(-not$row){throw 'Select an archived update.'};if(Confirm(L 'Restore this archived version? The current version will also be archived.' 'Restaurar esta version? La version actual tambien se archivara.')){$request=New-PMMUpdateRequest UpdateRestore @{Schema='PMM_UPDATE_REQUEST_V1';Action='Restore';TransactionId=$row.Id};[void](Start-PMMBackgroundOperation -Operation UpdateRestore -RequestPath $request -OnSuccess {param($r)Refresh-UI;Refresh-PMMUpdatesUI;$Script:TxtUpdatesStatus.Text=$r.ResultText})}}catch{Handle-UIError $_ 'Restore'}})
  $Script:BtnDeleteUpdateArchive.Add_Click({try{$row=$Script:DgUpdateArchives.SelectedItem;if(-not$row){throw 'Select an archived update.'};if(Confirm ((L 'Permanently delete the archived version of {0}? This cannot be undone.' 'Borrar permanentemente la version archivada de {0}? No se puede deshacer.') -f $row.Mod)){Remove-PMMUpdateArchive ([string]$row.Id);Refresh-PMMUpdatesUI}}catch{Handle-UIError $_ 'Archive'}})
  $openArchive.Add_Click({Start-Process explorer.exe -ArgumentList ('"'+(Join-Path (Get-PMMUpdateRoot) 'Archive')+'"')})
  $timer=[Windows.Threading.DispatcherTimer]::new();$timer.Interval=[TimeSpan]::FromSeconds(2);$timer.Add_Tick({
    if(-not$Script:PendingFreeUpdateHash){Restore-PMMPendingNxmUI}
    if($Script:PendingFreeUpdateHash){$plan=Read-PMMUpdatePlan;$pending=@($plan.Results|Where-Object{$_.LocalSha256 -eq $Script:PendingFreeUpdateHash -and $_.Status -eq 'UPDATE_AVAILABLE'}|Select-Object -First 1);if($pending.Count -and (Test-PMMNxmQueueMatch ([string]$pending[0].Origin.ModId) ([string]$pending[0].Candidate.FileId))){$hash=$Script:PendingFreeUpdateHash;$Script:PendingFreeUpdateHash='';$Script:BtnCancelUpdates.IsEnabled=$false;try{Start-PMMUpdateApplyUI $hash $true}catch{$Script:TxtUpdatesStatus.Text=$_.Exception.Message}}}
    if(-not$Script:UpdateBusy -and -not$Script:PendingDeferredLaunching -and -not(Test-PMMPalworldRunning)){$deferred=Get-PMMPendingUpdateApply;if($deferred){$plan=Read-PMMUpdatePlan;if(-not$plan -or -not$plan.IsCurrent -or [string]$plan.Id -cne [string]$deferred.PlanId){Clear-PMMPendingUpdateApply;$Script:TxtUpdatesStatus.Text=L 'A deferred update was cancelled because the library changed.' 'Se cancelo una actualizacion aplazada porque cambio la biblioteca.'}else{try{Start-PMMDeferredUpdateApplyUI $deferred}catch{$Script:PendingDeferredLaunching=$false;$Script:TxtUpdatesStatus.Text=$_.Exception.Message}}}}
  });$timer.Start();$Script:UpdateNxmTimer=$timer
  Refresh-PMMUpdatesUI;Restore-PMMPendingNxmUI
  try{Update-PMMGuidedActionState}catch{Write-PMMLog ('Updates guided-flow refresh warning: '+$_.Exception.Message)}
}
