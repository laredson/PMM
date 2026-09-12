# Actions shared by the workbench shell; operations run through existing providers.
function Show-PMMWorkbenchForm([string]$Title,[array]$Fields,[string]$Accept='OK'){
  $dialog=New-PMMThemedDialog $Title;$values=@{Accepted=$false;Inputs=@{}}
  foreach($field in $Fields){$label=New-PMMWorkbenchText ([string]$field.Label);$label.Margin=[Windows.Thickness]::new(0,8,0,3);[void]$dialog.body.Children.Add($label);$input=[Windows.Controls.TextBox]::new();$input.Text=[string]$field.Value;$input.MinWidth=460;$input.Margin=[Windows.Thickness]::new(0,0,0,5);[Windows.Automation.AutomationProperties]::SetName($input,[string]$field.Label);[void]$dialog.body.Children.Add($input);$values.Inputs[$field.Key]=$input}
  $ok=New-PMMWorkbenchButton $Accept 'Accept';$cancel=New-PMMWorkbenchButton (L 'Cancel' 'Cancelar') 'Cancel';$cancel.IsCancel=$true;$ok.IsDefault=$true
  $window=$dialog.window;$ok.Add_Click({$values.Accepted=$true;$window.Close()}.GetNewClosure());$cancel.Add_Click({$window.Close()}.GetNewClosure());[void]$dialog.actions.Children.Add($ok);[void]$dialog.actions.Children.Add($cancel);[void]$window.ShowDialog()
  if(-not $values.Accepted){return $null};$result=@{};foreach($key in $values.Inputs.Keys){$result[$key]=[string]$values.Inputs[$key].Text};return $result
}
function Invoke-PMMWorkbenchResource([string]$Action){
  try{
    $case=Get-PMMAIIOSelectedCase
    switch($Action){
      'CaseFiles' {if(-not $case){throw (L 'Select a case.' 'Selecciona un caso.')};Start-Process explorer.exe -ArgumentList ('"'+(Get-PMMAIIOCasePath $case.CaseId)+'"')}
      'Candidates' {if(-not $case){throw (L 'Select a case.' 'Selecciona un caso.')};Start-PMMWorkbenchTool -CaseId $case.CaseId -SyncCandidates;Show-PMMWorkbenchPage 'Knowledge'}
      'Reference' {Open-PMMSettings 'AI'}
      'Theme' {Show-PMMWorkbenchPage 'Help';$Script:AIHelpTabs.SelectedItem=$Script:PMMHelpThemeTab}
      'ConfigureTools' {Open-PMMSettings 'INSTALLATIONS'}
      'Inspect' {Show-PMMWorkbenchToolEditor}
      'Unreal' {Show-PMMWorkbenchUnrealEditor}
      'CancelTool' {Stop-PMMWorkbenchTool}
      'KLPreferences' {Show-PMMWorkbenchPreferences}
      'TryCandidate' {Start-PMMWorkbenchCandidateTrial}
      'RefreshTools' {Start-PMMWorkbenchTool -Mode Capabilities}
      'RefreshKL' {if($case){Start-PMMWorkbenchTool -CaseId $case.CaseId -SyncCandidates}else{Start-PMMWorkbenchTool -Mode ScanKnowledge}}
      'ImportKL' {$pick=[Microsoft.Win32.OpenFileDialog]::new();$pick.Filter='PMM knowledge (*.json)|*.json';if($pick.ShowDialog() -eq $true){$record=Import-PMMLocalKnowledgeContribution $pick.FileName;Refresh-PMMWorkbenchPageData 'Knowledge';$Script:TxtStatus.Text=L 'Contribution imported as pending local knowledge.' 'Contribucion importada como conocimiento local pendiente.'}}
      'ExportKL' {$record=$Script:PMMWorkbench.KnowledgeGrid.SelectedItem;if(-not $record){throw (L 'Select a candidate.' 'Selecciona un candidato.')};$pick=[Microsoft.Win32.SaveFileDialog]::new();$pick.Filter='PMM knowledge (*.json)|*.json';$pick.FileName='pmm-knowledge.json';if($pick.ShowDialog() -eq $true){Export-PMMLocalKnowledgeContribution $record.CaseId $record.CandidateId $pick.FileName|Out-Null;$Script:TxtStatus.Text=L 'Minimal local contribution exported.' 'Contribucion local minima exportada.'}}
      'ReviewKL' {$record=$Script:PMMWorkbench.KnowledgeGrid.SelectedItem;if(-not $record){throw (L 'Select a candidate.' 'Selecciona un candidato.')};$form=Show-PMMWorkbenchForm (L 'Review candidate' 'Revisar candidato') @(@{Key='Reviewer';Label=(L 'Reviewer name' 'Nombre del revisor');Value=''},@{Key='Scope';Label=(L 'What was verified?' 'Que se verifico?');Value=''},@{Key='Decision';Label='Approved / Rejected / Pending';Value='Pending'});if($form){Set-PMMKnowledgeReview $record.CaseId $record.CandidateId $form.Decision $form.Reviewer $form.Scope|Out-Null;Refresh-PMMWorkbenchPageData 'Knowledge'}}
      'OpenCandidateCase' {$record=$Script:PMMWorkbench.KnowledgeGrid.SelectedItem;if($record){Select-PMMCaseLocation (Get-PMMAIIOCase $record.CaseId)}}
    }
  }catch{Handle-UIError $_ (L 'Workbench' 'Taller')}
}
function Get-PMMWorkbenchToolDraft([string]$CaseId){
  $path=Join-Path (Get-PMMAIIOCasePath $CaseId) 'structured-editor-draft.json'
  if(Test-Path -LiteralPath $path){return (Read-PMMJsonFile -Path $path -RecoverBackup)};return $null
}
function Save-PMMWorkbenchToolDraft([string]$CaseId,$Draft){
  Write-PMMJsonAtomic -Path (Join-Path (Get-PMMAIIOCasePath $CaseId) 'structured-editor-draft.json') -Value $Draft -Depth 8
}
function Show-PMMWorkbenchToolEditor {
  $case=Get-PMMAIIOSelectedCase;if(-not $case){throw (L 'Select or create a case first.' 'Selecciona o crea un caso primero.')}
  [void](Save-PMMAIIOCaseEditor)
  $dialog=New-PMMThemedDialog (L 'Structured editor' 'Editor estructurado');$window=$dialog.window
  $note=New-PMMWorkbenchText (L 'Inspect current reference, edit a supported scalar on a copy, then build a candidate. No installation occurs here.' 'Inspecciona la referencia actual, edita una propiedad soportada en una copia y construye un candidato. Aqui no se instala.');[void]$dialog.body.Children.Add($note)
  $fields=@{};$savedDraft=Get-PMMWorkbenchToolDraft $case.CaseId
  foreach($field in @(@('logicalPath','Asset (Pal/Content/...uasset)',''),@('query',(L 'Find property' 'Buscar propiedad'),''),@('path',(L 'Property pointer from inspection' 'Ruta de propiedad obtenida al inspeccionar'),''),@('expected',(L 'Original value' 'Valor original'),''),@('value',(L 'New numeric or boolean value' 'Nuevo valor numerico o booleano'),''),@('candidateId',(L 'Candidate ID (for Build)' 'ID de candidato (para Construir)'),$(if($Script:PMMWorkbench.LastCandidateCase -eq $case.CaseId){[string]$Script:PMMWorkbench.LastCandidate}else{''})))){[void]$dialog.body.Children.Add((New-PMMWorkbenchText $field[1]));$box=[Windows.Controls.TextBox]::new();$box.Text=$field[2];if($savedDraft -and $savedDraft.PSObject.Properties[[string]$field[0]]){$box.Text=[string]$savedDraft.($field[0])};$box.MinWidth=520;$box.Margin=[Windows.Thickness]::new(0,3,0,8);$fields[$field[0]]=$box;[void]$dialog.body.Children.Add($box)}
  if(-not $fields.candidateId.Text -and $Script:PMMWorkbench.LastCandidateCase -eq $case.CaseId){$fields.candidateId.Text=$Script:PMMWorkbench.LastCandidate}
  $caseId=[string]$case.CaseId
  $window.Add_Closing({$draft=@{};foreach($key in $fields.Keys){$draft[$key]=[string]$fields[$key].Text};Save-PMMWorkbenchToolDraft $caseId $draft}.GetNewClosure())
  foreach($entry in @(@('Prepare','Preparar','prepare'),@('Inspect','Inspeccionar','inspect'),@('Create edit','Crear cambio','edit'),@('Build','Construir','build'))){$button=New-PMMWorkbenchButton (L $entry[0] $entry[1]) $entry[2];$button.Add_Click({param($sender,$e)
    try{$operation=[string]$sender.Tag;$parameters=@{};if($operation -eq 'build'){$parameters.candidateId=$fields.candidateId.Text}else{$parameters.logicalPath=$fields.logicalPath.Text;if($operation -eq 'inspect'){$parameters.query=$fields.query.Text;$parameters.limit=100};if($operation -eq 'edit'){$parameters.path=$fields.path.Text;$parameters.expected=$fields.expected.Text;$parameters.value=$fields.value.Text;if($fields.candidateId.Text){$parameters.candidateId=$fields.candidateId.Text}}}
      $request=New-PMMToolRequest -AdapterId 'scalar' -Operation $operation -CaseId $caseId -Arguments ([pscustomobject]$parameters);Start-PMMWorkbenchTool -CaseId $caseId -Request $request;$window.Close();Show-PMMWorkbenchPage 'Tools'
    }catch{Handle-UIError $_ (L 'Structured editor' 'Editor estructurado')}
  }.GetNewClosure());[void]$dialog.actions.Children.Add($button)}
  [void]$window.ShowDialog()
}
function Start-PMMWorkbenchTool {
  param([string]$CaseId='',$Request=$null,[switch]$SyncCandidates,[ValidateSet('Tool','Capabilities','ScanKnowledge','ValidateCandidate','CreateContextCase')][string]$Mode='Tool',[string]$CandidateId='',[switch]$PreserveOutput)
  if($Script:PMMWorkbench.ToolLease -or -not [string]::IsNullOrWhiteSpace((Get-PMMActiveProcessingOperation))){throw (L 'Wait for the current PMM operation.' 'Espera a que termine la operacion actual de PMM.')}
  $job=Join-Path (Join-PMMPath 'Cache' 'WorkbenchTools') ([guid]::NewGuid().ToString('N'));[void][IO.Directory]::CreateDirectory($job)
  $requestPath=Join-Path $job 'request.json';$resultPath=Join-Path $job 'result.json'
  if($Request){Write-PMMJsonAtomic -Path $requestPath -Value $Request -Depth 30}
  $worker=Join-Path $Script:Root 'Modules\Tools\Tool.Worker.ps1';$exe=Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
  $Script:PMMWorkbench.ToolCancel=Join-Path $job 'cancel.request';$Script:PMMWorkbench.ToolProgress=Join-Path $job 'progress.json'
  $arguments='-NoProfile -ExecutionPolicy Bypass -File "'+$worker+'" -Root "'+$Script:Root+'" -ResultPath "'+$resultPath+'" -CancelPath "'+$Script:PMMWorkbench.ToolCancel+'" -ProgressPath "'+$Script:PMMWorkbench.ToolProgress+'"'
  if($CaseId){if($CaseId -notmatch '^AICASE-[0-9]{8}-[0-9]{6}-[a-f0-9]{8}$'){throw 'Invalid case identity.'};$arguments+=' -CaseId "'+$CaseId+'"'}
  if($SyncCandidates){$arguments+=' -Mode SyncCandidates'}else{$arguments+=' -Mode '+$Mode+' -RequestPath "'+$requestPath+'"'};if($CandidateId){$arguments+=' -CandidateId "'+$CandidateId+'"'}
  $Script:PMMWorkbench.ToolJob=$job;$Script:PMMWorkbench.ToolResult=$resultPath;$Script:PMMWorkbench.ToolHandle=$null
  $Script:PMMWorkbench.ToolMode=if($SyncCandidates){'SyncCandidates'}else{$Mode};$Script:PMMWorkbench.ToolCaseId=$CaseId
  $Script:PMMWorkbench.ToolRequestOperation=[string](Get-PMMKnowledgeField $Request 'Operation' '');$Script:PMMWorkbench.ToolPreserveOutput=[bool]$PreserveOutput
  $Script:PMMWorkbench.ToolLease=Start-PMMModuleOperation 'WorkbenchTool'
  try{$Script:PMMWorkbench.ToolProcess=Start-Process -FilePath $exe -ArgumentList $arguments -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $job 'stdout.txt') -RedirectStandardError (Join-Path $job 'stderr.txt')}
  catch{Complete-PMMModuleOperation $Script:PMMWorkbench.ToolLease.Id;$Script:PMMWorkbench.ToolLease=$null;throw}
  $timer=[Windows.Threading.DispatcherTimer]::new();$timer.Interval=[TimeSpan]::FromMilliseconds(750);$Script:PMMWorkbench.ToolTimer=$timer
  $timer.Add_Tick({Update-PMMWorkbenchTool});$timer.Start()
  if(-not $PreserveOutput){$Script:TxtStatus.Text=L 'Tool running in background...' 'Herramienta en segundo plano...'}
  if(Get-Command Update-PMMLibraryButtons -ErrorAction SilentlyContinue){Update-PMMLibraryButtons}
  if(Get-Command Update-PMMPatchActionButtons -ErrorAction SilentlyContinue){Update-PMMPatchActionButtons}
}
function Set-PMMWorkbenchLastCandidate($Payload,[string]$CaseId){
  # Scalar and Unreal providers retain their native envelopes. Discovery scans
  # must not replace the editor's most recent candidate or its case binding.
  for($level=0;$level -lt 4 -and $Payload;$level++){
    $id=[string](Get-PMMKnowledgeField $Payload 'candidateId' '')
    if($id -and $CaseId){$Script:PMMWorkbench.LastCandidate=$id;$Script:PMMWorkbench.LastCandidateCase=$CaseId;return}
    $nested=Get-PMMKnowledgeField $Payload 'candidate' $null
    if(-not $nested){$nested=Get-PMMKnowledgeField $Payload 'Result' $null}
    $Payload=$nested
  }
}
function Update-PMMWorkbenchTool {
  # Modal WPF dialogs pump the dispatcher. Protect result consumption before
  # invoking any callback, so one completed worker cannot open repeated dialogs.
  if($Script:PMMWorkbench['ToolCompletionBusy'] -or -not $Script:PMMWorkbench.ToolLease){return}
  $Script:PMMWorkbench.ToolCompletionBusy=$true
  $done=$false;$scanNext=$false;$resumePolling=$false
  $preserveOutput=[bool]$Script:PMMWorkbench.ToolPreserveOutput
  try{
    if($Script:PMMWorkbench.ToolHandle){
      $status=Get-PMMToolOperation $Script:PMMWorkbench.ToolHandle
      if(-not $preserveOutput){$Script:PMMWorkbench.ToolOutput.Text=$status|ConvertTo-Json -Depth 18}
      if($status.Status -notin @('COMPLETE','COMPLETED','FAILED','CANCELLED','SUCCEEDED','INTERRUPTED')){return}
      $Script:PMMWorkbench.ToolTimer.Stop();$done=$true;$scanNext=$true
      Set-PMMWorkbenchLastCandidate $status.Result ([string]$Script:PMMWorkbench.ToolHandle.CaseId)
      if(-not $preserveOutput){$Script:TxtStatus.Text=[string]$status.Status+': '+[string]$status.Message}
    }else{
      if(-not $Script:PMMWorkbench.ToolProcess.HasExited){
        if(-not $preserveOutput -and (Test-Path -LiteralPath $Script:PMMWorkbench.ToolProgress)){$progress=Read-PMMJsonFile -Path $Script:PMMWorkbench.ToolProgress;$Script:TxtStatus.Text=[string]$progress.Message}
        return
      }
      $Script:PMMWorkbench.ToolTimer.Stop()
      $result=Read-PMMJsonFile -Path $Script:PMMWorkbench.ToolResult
      if(-not $result -or $result.Schema -cne 'PMM_TOOL_WORKER_RESULT_V1'){throw 'Tool worker exited without a valid result. See '+$Script:PMMWorkbench.ToolJob}
      if(-not $preserveOutput){$Script:PMMWorkbench.ToolOutput.Text=$result|ConvertTo-Json -Depth 18}
      $scanNext=($result.Mode -eq 'SyncCandidates' -or ($result.Mode -eq 'Tool' -and $Script:PMMWorkbench.ToolRequestOperation -eq 'build'))
      if($result.Status -eq 'Complete'){switch($result.Mode){'Capabilities'{Set-PMMWorkbenchCapabilities $result.Result};'ScanKnowledge'{Set-PMMWorkbenchKnowledgeRows $result.Result.Candidates $result.Result.Imports};'ValidateCandidate'{Confirm-PMMWorkbenchCandidateTrial $result.Result};'CreateContextCase'{Select-PMMCaseLocation $result.Result}}}
      if($result.Status -eq 'Failed'){throw [string]$result.Error}
      if($result.PSObject.Properties['Result'] -and $result.Result){
        $payload=$result.Result
        if($payload.PSObject.Properties['Status'] -and $payload.Status -eq 'Running'){$Script:PMMWorkbench.ToolHandle=$payload;$resumePolling=$true;return}
        Set-PMMWorkbenchLastCandidate $payload ([string]$Script:PMMWorkbench.ToolCaseId)
      }
      $done=$true
      if(-not $preserveOutput){$Script:TxtStatus.Text=[string]$result.Status+' / '+(L 'Review the result in Tools.' 'Revisa el resultado en Herramientas.')}
    }
  }catch{$done=$true;$Script:TxtStatus.Text=$_.Exception.Message;if(-not $preserveOutput -and $Script:PMMWorkbench.ToolOutput){$Script:PMMWorkbench.ToolOutput.Text=$_.Exception.Message}}
  finally{
    try{
      if($done){
        $Script:PMMWorkbench.ToolTimer.Stop();if($Script:PMMWorkbench.ToolLease){Complete-PMMModuleOperation $Script:PMMWorkbench.ToolLease.Id}
        if($Script:PMMWorkbench.ToolProcess){$Script:PMMWorkbench.ToolProcess.Dispose()}
        $Script:PMMWorkbench.ToolLease=$null;$Script:PMMWorkbench.ToolProcess=$null;$Script:PMMWorkbench.ToolHandle=$null
        if(Get-Command Refresh-UI -ErrorAction SilentlyContinue){Refresh-UI}
      }elseif($resumePolling){$Script:PMMWorkbench.ToolTimer.Start()}
    }finally{$Script:PMMWorkbench.ToolCompletionBusy=$false}
  }
  # Acquire the next lease only after all resources from the old operation were
  # released. A scan never queues another scan and keeps the provider result visible.
  if($done -and $scanNext -and -not $Script:PMMWorkbench['Closing']){
    try{Start-PMMWorkbenchTool -Mode ScanKnowledge -PreserveOutput}
    catch{Write-PMMLog ('Knowledge refresh: '+$_.Exception.Message)}
  }
}
function Stop-PMMWorkbenchTool {
  if($Script:PMMWorkbench.ToolHandle){Stop-PMMToolOperation $Script:PMMWorkbench.ToolHandle|Out-Null}
  elseif($Script:PMMWorkbench.ToolProcess -and -not $Script:PMMWorkbench.ToolProcess.HasExited){[IO.File]::WriteAllText($Script:PMMWorkbench.ToolCancel,'Cancel')}
  $Script:TxtStatus.Text=L 'Cancellation requested; the tool will stop at its next safe boundary.' 'Cancelacion solicitada; la herramienta se detendra en el siguiente punto seguro.'
}
function Show-PMMWorkbenchUnrealEditor {
  $case=Get-PMMAIIOSelectedCase;if(-not $case){throw (L 'Select a case.' 'Selecciona un caso.')};[void](Save-PMMAIIOCaseEditor)
  $dialog=New-PMMThemedDialog (L 'Unreal texture workshop' 'Taller de texturas Unreal');$window=$dialog.window;$caseId=$case.CaseId
  [void]$dialog.body.Children.Add((New-PMMWorkbenchText (L 'Prepare the case project, import a PNG already added to its files, then cook a disabled candidate. Requires the configured engine and kit.' 'Prepara el proyecto del caso, importa un PNG ya agregado a sus archivos y construye un candidato desactivado. Requiere motor y kit configurados.')))
  $fields=@{}
  foreach($entry in @(@('assetName','Texture name','Nombre de textura'),@('sourceArtifactId','PNG artifact ID from case files','ID de archivo PNG del caso'))){[void]$dialog.body.Children.Add((New-PMMWorkbenchText (L $entry[1] $entry[2])));$box=[Windows.Controls.TextBox]::new();$box.MinWidth=500;$box.Margin=[Windows.Thickness]::new(0,3,0,12);$fields[$entry[0]]=$box;[void]$dialog.body.Children.Add($box)}
  foreach($entry in @(@('Prepare','Preparar','prepare'),@('Import PNG','Importar PNG','texture'),@('Cook candidate','Construir candidato','cook'))){$button=New-PMMWorkbenchButton (L $entry[0] $entry[1]) $entry[2];$button.Add_Click({param($sender,$e)try{$parameters=@{};if($sender.Tag -eq 'texture'){$parameters.operation='import_texture';$parameters.assetName=$fields.assetName.Text;$parameters.sourceArtifactId=$fields.sourceArtifactId.Text};$request=New-PMMToolRequest -AdapterId unreal -Operation $sender.Tag -CaseId $caseId -Arguments $parameters;Start-PMMWorkbenchTool -CaseId $caseId -Request $request;$window.Close();Show-PMMWorkbenchPage 'Tools'}catch{Handle-UIError $_ 'Unreal'}}.GetNewClosure());[void]$dialog.actions.Children.Add($button)}
  [void]$window.ShowDialog()
}
function Show-PMMWorkbenchPreferences {
  $preferences=Get-PMMKnowledgePreferences;$dialog=New-PMMThemedDialog (L 'Local knowledge preferences' 'Preferencias de conocimiento local');$window=$dialog.window
  $feedback=[Windows.Controls.CheckBox]::new();$feedback.Content=L 'Ask after an observed game session' 'Preguntar despues de una sesion observada';$feedback.IsChecked=[bool]$preferences.FeedbackEnabled;$feedback.Margin=[Windows.Thickness]::new(0,10,0,10);[void]$dialog.body.Children.Add($feedback)
  $automatic=[Windows.Controls.CheckBox]::new();$automatic.Content=L 'Allow automatic contributions when a receiver becomes available' 'Permitir contribuciones automaticas cuando exista un receptor';$automatic.IsChecked=[bool]$preferences.AutomaticContribution;[void]$dialog.body.Children.Add($automatic)
  [void]$dialog.body.Children.Add((New-PMMWorkbenchText (L 'Current mode: Local exchange. This version has no receiver and sends nothing.' 'Modo actual: Intercambio local. Esta version no tiene receptor y no envia datos.')))
  $save=New-PMMWorkbenchButton (L 'Save' 'Guardar') 'Save';$save.Add_Click({Set-PMMKnowledgePreferences -FeedbackEnabled ([bool]$feedback.IsChecked) -AutomaticContribution ([bool]$automatic.IsChecked)|Out-Null;$window.Close()}.GetNewClosure());[void]$dialog.actions.Children.Add($save);[void]$window.ShowDialog()
}
function Invoke-PMMWorkbenchLibraryTrial {
  try{$row=$Script:LstMods.SelectedItem;if(-not $row -or -not $row.PSObject.Properties['CaseId'] -or -not $row.CaseId){throw (L 'Select a generated candidate in the library.' 'Selecciona un candidato generado en la biblioteca.')};Start-PMMWorkbenchTool -Mode ValidateCandidate -CaseId $row.CaseId -CandidateId $row.CandidateId}
  catch{Handle-UIError $_ (L 'Candidate trial' 'Prueba de candidato')}
}
function Start-PMMWorkbenchCandidateTrial {
  $record=$Script:PMMWorkbench.KnowledgeGrid.SelectedItem;if(-not $record){throw (L 'Select a candidate.' 'Selecciona un candidato.')}
  Start-PMMWorkbenchTool -Mode ValidateCandidate -CaseId $record.CaseId -CandidateId $record.CandidateId
}
function Confirm-PMMWorkbenchCandidateTrial($Match){
  if($Match.Applicability -ne 'Matches' -or -not $Match.RequiresExplicitTrial){throw 'Candidate trial requires current validated evidence.'}
  $detail=($Match|Select-Object TechnicalStatus,Observation,UserConfirmation,Review|ConvertTo-Json -Depth 6)
  if(-not(Confirm ((L 'Enable this candidate for an explicit trial? Analyze and installation still use the normal workflow.' 'Activar este candidato para una prueba explicita? El analisis y la instalacion seguiran el flujo normal.')+"`n`n"+$detail))){return}
  $name='PMM_Generated_'+$Match.PakSha256.Substring(0,16)+'_P.pak'
  $source=@(@(Get-LibraryMods)+@(Get-PMMDisabledMods)|Where-Object {$_.Name -ceq $name -and $_.Hash -ceq $Match.PakSha256})
  if($source.Count -ne 1){throw (L 'Synchronize the case candidates first.' 'Sincroniza los candidatos del caso primero.')}
  Set-PMMLibraryModEnabled $name $true -TrialAuthorization $Match.TrialAuthorization;Refresh-UI;Show-PMMWorkbenchPage 'Library'
}
function Invoke-PMMWorkbenchReload {
  try{
    $busy=(-not [string]::IsNullOrWhiteSpace((Get-PMMActiveProcessingOperation))) -or [bool]($Script:PMMWorkbench.ToolProcess -and -not $Script:PMMWorkbench.ToolProcess.HasExited)
    $result=Request-PMMModuleReload -Busy:$busy
    if($result.Status -eq 'Staged'){$result=Invoke-PMMPendingModuleReload -Busy:$busy}
    if(-not $busy){$cfg=Get-PMMConfig;Apply-PMMTheme -Force;Set-PMMWorkbenchAppearance}
    $Script:TxtStatus.Text=[string]$result.Status+': '+[string]$result.Reason
  }catch{Handle-UIError $_ (L 'Reload modules' 'Recargar modulos')}
}
function Show-PMMWorkbenchFeedback($Group){
  if($Script:PMMWorkbench['FeedbackDialogOpen'] -or $Script:PMMWorkbench['Closing']){return}
  $Script:PMMWorkbench.FeedbackDialogOpen=$true
  $timer=$Script:PMMWorkbench.ObservationTimer;$resumeObservation=[bool]($timer -and $timer.IsEnabled)
  if($timer){$timer.Stop()}
  try{
    $dialog=New-PMMThemedDialog (L 'Did the solution work?' 'Funciono la solucion?');$window=$dialog.window;$fields=@{}
    [void]$dialog.body.Children.Add((New-PMMWorkbenchText (L 'Execution was observed for at least ten minutes. Confirm only behavior you actually tested.' 'Se observo la ejecucion durante al menos diez minutos. Confirma solo lo que hayas probado.')))
    foreach($candidate in $Group.Candidates){[void]$dialog.body.Children.Add((New-PMMWorkbenchText ([string]$candidate.Objective)));$choice=[Windows.Controls.ComboBox]::new();$choice.DisplayMemberPath='Label';$choice.SelectedValuePath='Value';$choice.ItemsSource=@([pscustomobject]@{Label=(L 'Not tested' 'No lo probe');Value='NotTested'},[pscustomobject]@{Label=(L 'Worked' 'Si, funciono');Value='Worked'},[pscustomobject]@{Label=(L 'Failed' 'No funciono');Value='Failed'});$choice.SelectedIndex=0;[void]$dialog.body.Children.Add($choice);$fields[($candidate.CaseId+'|'+$candidate.CandidateId)]=$choice}
    $disable=[Windows.Controls.CheckBox]::new();$disable.Content=L 'Do not ask again' 'No volver a preguntar';$disable.Margin=[Windows.Thickness]::new(0,12,0,8);[void]$dialog.body.Children.Add($disable)
    $save=New-PMMWorkbenchButton (L 'Save feedback' 'Guardar respuesta') 'Save';$save.Add_Click({foreach($candidate in $Group.Candidates){Set-PMMCandidateFeedback -SessionId $Group.SessionId -CaseId $candidate.CaseId -CandidateId $candidate.CandidateId -Answer ([string]$fields[($candidate.CaseId+'|'+$candidate.CandidateId)].SelectedValue)|Out-Null};if($disable.IsChecked){Set-PMMKnowledgePreferences -FeedbackEnabled $false -AutomaticContribution ([bool](Get-PMMKnowledgePreferences).AutomaticContribution)|Out-Null};$window.Close()}.GetNewClosure());[void]$dialog.actions.Children.Add($save)
    Set-PMMCandidateFeedbackPrompted $Group|Out-Null;[void]$window.ShowDialog()
  }finally{
    $Script:PMMWorkbench.FeedbackDialogOpen=$false
    if($resumeObservation -and -not $Script:PMMWorkbench['Closing']){$timer.Start()}
  }
}
function Start-PMMWorkbenchObservation {
  $timer=[Windows.Threading.DispatcherTimer]::new([Windows.Threading.DispatcherPriority]::Background);$timer.Interval=[TimeSpan]::FromSeconds(15);$Script:PMMWorkbench.ObservationTimer=$timer
  $timer.Add_Tick({
    if($Script:PMMWorkbench['Closing'] -or $Script:PMMWorkbench['FeedbackDialogOpen'] -or $Script:PMMWorkbench['ToolCompletionBusy']){return}
    try{
      $cfg=Get-PMMConfig;if($cfg.GamePath){[void](Update-PMMGameObservation -GameRoot ([string]$cfg.GamePath))}
      if([string]::IsNullOrWhiteSpace((Get-PMMActiveProcessingOperation))){
        foreach($group in @(Get-PMMPendingCandidateFeedback)){
          if($Script:PMMWorkbench['Closing'] -or -not (Get-PMMKnowledgePreferences).FeedbackEnabled){break}
          Show-PMMWorkbenchFeedback $group
        }
        $reload=Invoke-PMMPendingModuleReload -Busy:$false;if($reload -and $reload.Status -eq 'Activated'){$Script:TxtStatus.Text=L 'Staged modules activated.' 'Modulos preparados activados.'}
      }
      Update-PMMWorkbenchStatus
    }catch{Write-PMMLog ('Observation: '+$_.Exception.Message)}
  });$timer.Start()
  $Window.Add_Closing({$Script:PMMWorkbench.Closing=$true;try{$Script:PMMWorkbench.ObservationTimer.Stop();if($Script:PMMWorkbench.ToolLease){Stop-PMMWorkbenchTool};Complete-PMMGameObservation -Reason 'PMMClosed'|Out-Null;if($Script:PMMWorkbench.ToolTimer){$Script:PMMWorkbench.ToolTimer.Stop()}}catch{}})
}
