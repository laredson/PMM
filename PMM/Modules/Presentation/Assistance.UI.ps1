# Preserved 1.3.2 definitions; extracted for 1.3.3.
function Get-PMMSelectorItemId($Control,[string]$PropertyName) {
  if(-not$Control){return ''}
  $item=$null;try{$item=$Control.SelectedItem}catch{}
  if(-not$item){return ''}
  try{
    $property=$item.PSObject.Properties[$PropertyName]
    if($property){return [string]$property.Value}
  }catch{}
  return ''
}

function Select-PMMSelectorItemId($Control,[string]$PropertyName,[string]$Value) {
  if(-not$Control -or [string]::IsNullOrWhiteSpace($Value)){return $false}
  try{
    foreach($item in @($Control.Items)){
      $property=$item.PSObject.Properties[$PropertyName]
      if($property -and [string]$property.Value -ceq $Value){$Control.SelectedItem=$item;return $true}
    }
  }catch{}
  return $false
}

function Update-PMMAIHelpDiagnosticSelection {
  $row=$null;try{$row=$Script:LstAIHelpDiagnostics.SelectedItem}catch{}
  $isOpen=($row -and [string]$row.Status -eq 'Open')
  $Script:BtnAIHelpPrepareDiagnostic.IsEnabled=($isOpen -and -not[bool]$Script:AIIOBusy)
  if([bool]$Script:AIHelpNewCaseMode){return}
  $Script:PnlAIHelpNewCase.Visibility=[System.Windows.Visibility]::Collapsed
  $Script:PnlAIHelpSelectedCase.Visibility=[System.Windows.Visibility]::Visible
  if(-not$row){
    $Script:TxtAIHelpSelectedCaseTitle.Text=L 'No case selected' 'Ningun caso seleccionado'
    $Script:TxtAIHelpSelectedCaseMeta.Text=L 'Choose a case on the left, or press New case.' 'Elige un caso a la izquierda o pulsa Nuevo caso.'
    $Script:TxtAIHelpSelectedCaseDescription.Text=''
    return
  }
  try{
    $casePath=Get-PMMDiagnosticCasePath ([string]$row.CaseId)
    $case=Get-Content -LiteralPath $casePath -Raw -Encoding UTF8|ConvertFrom-Json
    $session=Get-PMMAIIOSessionForDiagnostic ([string]$row.CaseId)
    $sessionText=if($session){((L 'AI exchange: {0} ({1})' 'Intercambio IA: {0} ({1})') -f [string]$session.SessionId,[string]$session.Status)}else{L 'AI exchange: not prepared yet' 'Intercambio IA: aun no preparado'}
    $created='';try{$created=([datetime]$case.CreatedUtc).ToLocalTime().ToString('yyyy-MM-dd HH:mm')}catch{$created=[string]$case.CreatedUtc}
    $Script:TxtAIHelpSelectedCaseTitle.Text=[string]$case.Title
    $Script:TxtAIHelpSelectedCaseMeta.Text=((L 'Feature: {0} | Status: {1} | Created: {2} | {3}' 'Funcion: {0} | Estado: {1} | Creado: {2} | {3}') -f [string]$case.Type,[string]$case.Status,$created,$sessionText)
    $Script:TxtAIHelpSelectedCaseDescription.Text=if([string]::IsNullOrWhiteSpace([string]$case.UserDescription)){L 'No description was recorded.' 'No se guardo ninguna descripcion.'}else{[string]$case.UserDescription}
  }catch{
    $Script:TxtAIHelpSelectedCaseTitle.Text=[string]$row.Title
    $Script:TxtAIHelpSelectedCaseMeta.Text=[string]$row.Display
    $Script:TxtAIHelpSelectedCaseDescription.Text=L 'The case details could not be read. Refresh the list or inspect the AI workspace.' 'No se pudieron leer los detalles del caso. Actualiza la lista o inspecciona el espacio de IA.'
  }
}

function Set-PMMAIHelpNewCaseMode([bool]$Enabled,[switch]$Clear) {
  $Script:AIHelpNewCaseMode=$Enabled
  $Script:PnlAIHelpSelectedCase.Visibility=if($Enabled){[System.Windows.Visibility]::Collapsed}else{[System.Windows.Visibility]::Visible}
  $Script:PnlAIHelpNewCase.Visibility=if($Enabled){[System.Windows.Visibility]::Visible}else{[System.Windows.Visibility]::Collapsed}
  if($Enabled -and $Clear){
    $Script:CmbAIHelpDiagnosticType.SelectedIndex=0
    $Script:TxtAIHelpDiagnosticTitle.Text=''
    $Script:TxtAIHelpDiagnosticDescription.Text=''
    $Script:ChkAIHelpIncludePalLog.IsChecked=$false
    $Script:TxtAIHelpDiagnosticStatus.Text=L 'Describe the problem, then create the case or create its safe AI ZIP.' 'Describe el problema y despues crea el caso o su ZIP seguro para IA.'
  }
  if(-not$Enabled){Update-PMMAIHelpDiagnosticSelection}
}

function Refresh-PMMAIHelpBadge {
  $keys=[Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
  # WaitingForAI is a normal, user-initiated handoff state.  Only a returned
  # candidate/data request/decision (or a real error) deserves the main badge.
  try{
    foreach($session in @(Get-PMMAIIOSessions|Where-Object{-not[bool]$_.Archived -and [string]$_.Status -in @('CandidateReady','NeedsData','NeedsUserDecision','PMMBugReported','CandidateAcceptedExperimental')})){
      [void]$keys.Add('SESSION:'+[string]$session.SessionId)
    }
  }catch{}
  try{
    foreach($case in @(Get-PMMDiagnosticCases|Where-Object{[string]$_.Status -eq 'Open' -and [bool]$_.AttentionEligible -and ([string]$_.Origin -eq 'AutomaticError' -or [string]$_.Type -eq 'PMM_ERROR')})){
      $id=if([string]$case.Type -eq 'PMM_ERROR' -and -not[string]::IsNullOrWhiteSpace([string]$case.Fingerprint)){'ERROR:'+[string]$case.Fingerprint}else{'CASE:'+[string]$case.CaseId}
      [void]$keys.Add($id)
    }
  }catch{}
  try{foreach($operation in @(Get-PMMInterruptedOperations)){[void]$keys.Add('OP:'+[string]$operation.OperationId)}}catch{}
  try{
    $plan=Read-PMMMergePlan
    if($plan){foreach($asset in @($plan.Assets|Where-Object{[string]$_.Mode -eq 'Unsupported'})){[void]$keys.Add('UNSUPPORTED:'+[string]$asset.AssetKey)}}
  }catch{}
  $attention=$keys.Count
  $Script:TxtAIHelpBadge.Text=[string]$attention
  $Script:BrdAIHelpBadge.Visibility=if($attention -gt 0){[System.Windows.Visibility]::Visible}else{[System.Windows.Visibility]::Collapsed}
}

function Refresh-PMMAIHelpKnowledge {
  try{
    $summary=Get-PMMKnowledgeSummary
    $Script:TxtAIHelpKnowledgeSummary.Text=((L '{0} behavior cases, {1} exact fixtures, {2} runtime-proven fixtures and {3} production recipes. Local evidence never becomes Proven merely because an AI proposed it.' '{0} casos de comportamiento, {1} fixtures exactos, {2} fixtures probados en runtime y {3} recetas de produccion. La evidencia local nunca pasa a Proven solo porque la propuso una IA.') -f $summary.BehaviorCases,$summary.Fixtures,$summary.RuntimeProven,$summary.ProductionRecipes)
  }catch{$Script:TxtAIHelpKnowledgeSummary.Text=$_.Exception.Message}
  try{
    $storage=Get-PMMArtifactStorageSummary
    if(-not[bool]$storage.Available){
      $Script:TxtAIHelpStorageSummary.Text=L 'Storage inventory has not been refreshed yet. Press Refresh to scan it in the background.' 'El inventario de almacenamiento aun no se ha actualizado. Pulsa Actualizar para escanearlo en segundo plano.'
    }else{
      $mib=1048576.0
      $parts=@($storage.Categories|ForEach-Object{([string]$_.Category+': '+('{0:N1} MiB' -f ([double]$_.Bytes/$mib)))})
      $Script:TxtAIHelpStorageSummary.Text=((L '{0} registered artifacts, {1:N1} MiB total. Current/protected items are never offered as disposable.' '{0} artefactos registrados, {1:N1} MiB en total. Los elementos actuales/protegidos nunca se ofrecen como desechables.') -f $storage.ArtifactCount,([double]$storage.TotalBytes/$mib))+' '+($parts -join ' | ')
    }
  }catch{$Script:TxtAIHelpStorageSummary.Text=$_.Exception.Message}
  try{
    $rows=@(Get-PMMInterruptedOperations|ForEach-Object{[pscustomobject]@{OperationId=[string]$_.OperationId;Kind=[string]$_.Kind;Display=([string]$_.Kind+' - '+[string]$_.LastStep+' - '+[string]$_.LastUtc)}})
    $Script:LstAIHelpInterrupted.ItemsSource=$rows
  }catch{$Script:LstAIHelpInterrupted.ItemsSource=@()}
}

function Get-PMMAIHelpFeedbackPatch {
  try{
    $row=$Script:CmbAIHelpFeedbackBuild.SelectedItem
    if($row -and $row.PSObject.Properties.Name -contains 'NoContext' -and [bool]$row.NoContext){return $null}
    if($row -and $row.Patch){return $row.Patch}
  }catch{}
  try{
    $row=$Script:LstPatches.SelectedItem
    if($row -and $row.Patch){return $row.Patch}
  }catch{}
  try{
    $selected=Get-PMMSelectedManagedPatch @(Get-LibraryMods)
    if($selected){return $selected}
  }catch{}
  $patches=@(Get-PMMManagedPatches)
  $deployed=@($patches|Where-Object{[bool]$_.Deployed}|Select-Object -First 1)
  if($deployed.Count -gt 0){return $deployed[0]}
  if($patches.Count -eq 1){return $patches[0]}
  return $null
}

function Update-PMMAIHelpFeedbackSelection {
  $patch=Get-PMMAIHelpFeedbackPatch;$hasValidation=$false
  if($patch){try{$summary=Get-PMMBuildValidationSummary $patch;$hasValidation=(-not[string]::IsNullOrWhiteSpace([string]$summary.LatestEventId))}catch{}}
  $Script:BtnAIHelpGenerateFeedback.IsEnabled=$hasValidation
}

function Refresh-PMMAIHelpFeedback([switch]$Force) {
  if(-not$Force){try{if([bool]$Script:CmbAIHelpFeedbackBuild.IsDropDownOpen){return}}catch{}}
  $selectedKey=Get-PMMSelectorItemId $Script:CmbAIHelpFeedbackBuild 'Key'
  $rows=[Collections.Generic.List[object]]::new()
  $rows.Add([pscustomobject]@{Key='__NONE__';Patch=$null;BuildId='';NoContext=$true;Display=(L 'No merge context' 'Sin contexto de merge')})
  foreach($patch in @(Get-PMMManagedPatches)){
    $buildId='';$status='UNVALIDATED'
    try{$buildId=Get-PMMDeterministicBuildId $patch}catch{}
    try{$status=[string](Get-PMMBuildValidationSummary $patch).Status}catch{}
    $deployed=if([bool]$patch.Deployed){L 'deployed' 'desplegado'}else{L 'saved' 'guardado'}
    $rows.Add([pscustomobject]@{Key=[string]$patch.Name;Patch=$patch;BuildId=$buildId;NoContext=$false;Display=([string]$patch.Name+'  |  '+$status+'  |  '+$deployed)})
  }
  $items=@($rows.ToArray())
  $Script:CmbAIHelpFeedbackBuild.ItemsSource=$items
  $restored=$false
  if($selectedKey){$restored=Select-PMMSelectorItemId $Script:CmbAIHelpFeedbackBuild 'Key' $selectedKey}
  if(-not$restored){
    $preferred=''
    try{$patchRow=$Script:LstPatches.SelectedItem;if($patchRow -and $patchRow.Patch){$preferred=[string]$patchRow.Patch.Name}}catch{}
    if(-not$preferred){try{$preferred=[string](@(Get-PMMManagedPatches|Where-Object{[bool]$_.Deployed}|Select-Object -First 1)[0].Name)}catch{}}
    if($preferred){$restored=Select-PMMSelectorItemId $Script:CmbAIHelpFeedbackBuild 'Key' $preferred}
  }
  if(-not$restored -and $items.Count -gt 0){$Script:CmbAIHelpFeedbackBuild.SelectedIndex=0}
  Update-PMMAIHelpFeedbackSelection
}

function Refresh-PMMAIIOCandidates([string]$SessionId) {
  $selected=Get-PMMSelectorItemId $Script:LstAIIOCandidates 'SolutionId'
  # Do not assign a collection through an if expression. Windows PowerShell
  # 5.1 unwraps zero/singleton output and StrictMode then makes .Count unsafe.
  $rows=@()
  if($SessionId){$rows=@(Get-PMMAIIOCandidateRecords $SessionId)}
  $Script:LstAIIOCandidates.ItemsSource=$rows
  if($selected){[void](Select-PMMSelectorItemId $Script:LstAIIOCandidates 'SolutionId' $selected)}
  if($Script:LstAIIOCandidates.SelectedIndex -lt 0 -and $rows.Count -gt 0){$Script:LstAIIOCandidates.SelectedIndex=0}
  Update-PMMAIIOCandidateSelection
}

function Update-PMMAIIOHandoffButton {
  if(-not$Script:BtnAIIOOpenHandoff){return}
  $path='';$session=Get-PMMSelectedAIIOSession
  if($session){try{$path=[string](Get-PMMAIIOLatestHandoffPath ([string]$session.SessionId))}catch{$path=''}}
  $Script:BtnAIIOOpenHandoff.Tag=$path
  $Script:BtnAIIOOpenHandoff.IsEnabled=(-not[bool]$Script:AIIOBusy -and -not[string]::IsNullOrWhiteSpace($path))
  $Script:BtnAIIOOpenHandoff.ToolTip=if($path){(L 'Show the latest request ZIP for this exchange in Explorer.' 'Mostrar en el Explorador el ultimo ZIP de peticion de este intercambio.')}else{(L 'This exchange does not have a handoff ZIP yet.' 'Este intercambio aun no tiene un ZIP handoff.')}
}

function Update-PMMAIIOCandidateSelection {
  $row=$Script:LstAIIOCandidates.SelectedItem
  if(-not$row){$Script:BtnAIIOOpenCandidate.IsEnabled=$false;$Script:BtnAIIOUseCandidate.IsEnabled=$false;$Script:BtnAIIOUseCandidate.Content=L 'Use candidate in Merge...' 'Usar candidato en Merge...';$Script:TxtAIIOCandidateStatus.Text=L 'No staged candidate is selected.' 'No hay ningun candidato en staging seleccionado.';return}
  $Script:BtnAIIOOpenCandidate.IsEnabled=$true
  if([string]$row.InputSchema -eq 'PMM_MOD_CREATION_CANDIDATE_V1'){
    $Script:BtnAIIOUseCandidate.Content=L 'Build standalone PAK...' 'Crear PAK independiente...'
    $Script:BtnAIIOUseCandidate.IsEnabled=(-not[bool]$Script:AIIOBusy -and [bool]$row.CanBuildStandalone)
    if([string]$row.Status -eq 'ModBuiltUnproven'){
      $path='';try{$path=[string]$row.BuiltPak.Path}catch{}
      $Script:TxtAIIOCandidateStatus.Text=((L 'Standalone mod built locally and left undeployed. Runtime status: UNPROVEN. Test it in Palworld before contributing Knowledge. Output: {0}' 'Mod independiente creado localmente y dejado sin desplegar. Estado runtime: UNPROVEN. Pruebalo en Palworld antes de aportar Knowledge. Salida: {0}') -f $path)
    }else{
      $Script:TxtAIIOCandidateStatus.Text=L 'The cooked-tree candidate passed structural, hash and current GameReference checks. It is still untrusted and inactive. Build creates a standalone PAK locally; PMM will not deploy it.' 'El candidato cooked-tree supero las comprobaciones estructurales, de hashes y de la GameReference vigente. Sigue sin ser confiable ni estar activo. Crear genera un PAK independiente local; PMM no lo desplegara.'
    }
    return
  }
  $Script:BtnAIIOUseCandidate.Content=L 'Use candidate in Merge...' 'Usar candidato en Merge...'
  $current=$false
  if([bool]$row.CanUseInMerge){try{$ids=@($row.CaseIds|ForEach-Object{[string]$_}|Where-Object{$_});$current=($ids.Count -eq 1 -and -not[string]::IsNullOrWhiteSpace((Get-PMMAIIOCurrentReviewFolderForCaseId $ids[0])))}catch{$current=$false}}
  $Script:BtnAIIOUseCandidate.IsEnabled=(-not[bool]$Script:AIIOBusy -and [bool]$row.CanUseInMerge -and $current)
  $caseText=(@($row.CaseIds|ForEach-Object{[string]$_}|Where-Object{$_}) -join ', ')
  if([string]$row.InputSchema -eq 'PMM_MANUAL_SOLUTION_V1'){
    $state=if([string]$row.Status -eq 'AcceptedExperimental'){L 'Accepted into the local experimental solution store; runtime remains UNPROVEN until you validate the exact build in Palworld.' 'Aceptado en el almacen local de soluciones experimentales; el runtime sigue UNPROVEN hasta validar el build exacto en Palworld.'}elseif($current){L 'Structurally accepted and tied to a current exact case. It is still inactive.' 'Aceptado estructuralmente y ligado a un caso exacto vigente. Sigue inactivo.'}else{L 'The exact review case is stale or unavailable. Run Analyze before using this candidate.' 'El caso exacto de revision ya no esta vigente o disponible. Ejecuta Analizar antes de usar este candidato.'}
  }else{$state=L 'This candidate type is inspectable but cannot enter Merge in this build. It remains inactive.' 'Este tipo de candidato se puede inspeccionar, pero no puede entrar en Merge en este build. Sigue inactivo.'}
  $Script:TxtAIIOCandidateStatus.Text=((L '{0} | case {1} | {2}' '{0} | caso {1} | {2}') -f [string]$row.InputSchema,$caseText,$state)
}

function Refresh-PMMAIHelpDiagnostics {
  $diagnostics=@(Get-PMMDiagnosticCases)
  $selectedDiagnostic=Get-PMMSelectorItemId $Script:LstAIHelpDiagnostics 'CaseId'
  $Script:LstAIHelpDiagnostics.ItemsSource=$diagnostics
  if($selectedDiagnostic){[void](Select-PMMSelectorItemId $Script:LstAIHelpDiagnostics 'CaseId' $selectedDiagnostic)}elseif($diagnostics.Count -gt 0){$Script:LstAIHelpDiagnostics.SelectedIndex=0}
  Update-PMMAIHelpDiagnosticSelection
}

function Refresh-PMMAIIOSessions {
  $sessions=@(Get-PMMAIIOSessions)
  $selectedSession=Get-PMMSelectorItemId $Script:LstAIIOSessions 'SessionId'
  $Script:LstAIIOSessions.ItemsSource=$sessions
  $configured='';try{$configured=[string](Get-PMMConfig).AIIOActiveSession}catch{}
  $sessionRestored=$false
  if($selectedSession){$sessionRestored=Select-PMMSelectorItemId $Script:LstAIIOSessions 'SessionId' $selectedSession}
  if(-not$sessionRestored -and $configured){$sessionRestored=Select-PMMSelectorItemId $Script:LstAIIOSessions 'SessionId' $configured}
  if(-not$sessionRestored -and $sessions.Count -gt 0){$Script:LstAIIOSessions.SelectedIndex=0}
  $activeSessionId=Get-PMMSelectorItemId $Script:LstAIIOSessions 'SessionId'
  Refresh-PMMAIIOCandidates $activeSessionId
  $hasSession=(-not[string]::IsNullOrWhiteSpace($activeSessionId))
  $busy=[bool]$Script:AIIOBusy
  $activeSession=$null;if($hasSession){try{$activeSession=Get-PMMAIIOSession $activeSessionId}catch{}}
  $canPrepare=(-not$hasSession -or ($activeSession -and [string]$activeSession.Status -eq 'Draft'))
  $Script:BtnAIIONewSession.IsEnabled=-not$busy
  $Script:BtnAIIOPrepare.IsEnabled=(-not$busy -and $canPrepare)
  $Script:BtnAIIOImportResponse.IsEnabled=(-not$busy)
  $Script:BtnAIIOArchive.IsEnabled=(-not$busy -and $hasSession)
  $pending=0;if($hasSession -and -not$busy){try{$pending=@(Get-PMMAIIOPendingRequests $activeSessionId).Count}catch{$pending=0}}
  $Script:BtnAIIOContinue.IsEnabled=(-not$busy -and $hasSession -and $pending -gt 0)
  if($busy){$Script:BtnAIIOUseCandidate.IsEnabled=$false}
  Update-PMMAIIOHandoffButton
}

function Refresh-PMMAIHelpUi([switch]$EnsureUnsupported,[switch]$All) {
  if([bool]$Script:AIHelpUiRefreshing){return}
  $Script:AIHelpUiRefreshing=$true
  try{
    # Re-evaluate only when the user explicitly enters AI & Help. A later
    # Analyze may introduce a new Unsupported set after the tab was opened once;
    # AIHelpLoaded must not suppress creation/reuse of that exact session.
    if($EnsureUnsupported){try{[void](Get-PMMAIIOUnsupportedSession)}catch{Write-PMMLog ('AIIO Unsupported session warning: '+$_.Exception.Message)}}
    $tab='CASES';try{$tab=[string]$Script:AIHelpTabs.SelectedItem.Tag}catch{}
    if($All -or $tab -eq 'CASES'){Refresh-PMMAIHelpDiagnostics;Refresh-PMMAIIOSessions}
    if($All -or $tab -eq 'FEEDBACK'){Refresh-PMMAIHelpFeedback;Refresh-PMMAIHelpKnowledge;$Script:BtnAIHelpCleanup.IsEnabled=-not[bool]$Script:AIIOBusy}
    if($All -or $tab -eq 'THEME'){Refresh-PMMThemeEditorCatalog}
    Refresh-PMMAIHelpBadge
    $Script:AIHelpLoaded=$true
  }finally{$Script:AIHelpUiRefreshing=$false}
}

function Get-PMMSelectedAIIOSession {
  $row=$Script:LstAIIOSessions.SelectedItem
  if(-not$row){return $null}
  return (Set-PMMAIIOActiveSession ([string]$row.SessionId))
}

function Refresh-PMMThemeEditorCatalog([switch]$Force) {
  if(-not$Force){
    if([bool]$Script:ThemeEditorUiBuilding){return}
    try{if([bool]$Script:CmbThemeEditorSource.IsDropDownOpen){return}}catch{}
  }
  $selectedSource='';try{$selectedSource=[string]$Script:CmbThemeEditorSource.SelectedValue}catch{}
  $definitions=@(Get-PMMThemeDefinitions)
  $Script:CmbThemeEditorSource.ItemsSource=$definitions
  if($selectedSource){$Script:CmbThemeEditorSource.SelectedValue=$selectedSource}
  if($Script:CmbThemeEditorSource.SelectedIndex -lt 0){$crystal=@($definitions|Where-Object{[string]$_.Id -eq 'pmm-crystal'}|Select-Object -First 1);if($crystal.Count -gt 0){$Script:CmbThemeEditorSource.SelectedValue='pmm-crystal'}elseif($definitions.Count -gt 0){$Script:CmbThemeEditorSource.SelectedIndex=0}}
  $selectedDraft='';try{$selectedDraft=[string]$Script:LstThemeDrafts.SelectedValue}catch{}
  $drafts=@(Get-PMMThemeDrafts);$Script:LstThemeDrafts.SelectedValuePath='DraftId';$Script:LstThemeDrafts.ItemsSource=$drafts
  if($selectedDraft){$Script:LstThemeDrafts.SelectedValue=$selectedDraft}elseif($drafts.Count -gt 0){$Script:LstThemeDrafts.SelectedIndex=0}
}

function Get-PMMThemeDraftFieldValue($Draft,$Field) {
  $fieldKey=[string]$Field.Key
  if([string]$Field.Kind -eq 'Palette'){$palette=ConvertTo-PMMThemeDraftHashtable $Draft.Palette;return [string]$palette[$fieldKey]}
  $stateKey=[string]$Field.State;$partKey=[string]$Field.Part
  $flow=ConvertTo-PMMThemeDraftHashtable $Draft.ColorFlow;$state=ConvertTo-PMMThemeDraftHashtable $flow[$stateKey];return [string]$state[$partKey]
}

function Set-PMMThemeEditorSwatch($Button,[string]$Hex) {
  try{$Button.Background=[System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString((Convert-PMMThemeHexToWpf $Hex)))}catch{$Button.ClearValue([System.Windows.Controls.Control]::BackgroundProperty)}
}

function Show-PMMThemeImageOptions($Entry) {
  if(-not$Entry){return $null}
  $form=[System.Windows.Forms.Form]::new();$form.Text=L 'Image brush options' 'Opciones de imagen del brush';$form.Width=520;$form.Height=310;$form.StartPosition='CenterParent';$form.FormBorderStyle=[System.Windows.Forms.FormBorderStyle]::FixedDialog;$form.MaximizeBox=$false;$form.MinimizeBox=$false
  $labels=@((L 'Fit / stretch' 'Ajuste / stretch'),(L 'Alignment' 'Alineacion'),(L 'Tile mode' 'Modo mosaico'),(L 'Image opacity (%)' 'Opacidad de imagen (%)'),(L 'Overlay / tint (#RRGGBB or #RRGGBBAA)' 'Overlay / tinte (#RRGGBB o #RRGGBBAA)'))
  $controls=[Collections.Generic.List[object]]::new();$top=18
  foreach($text in $labels){$label=[System.Windows.Forms.Label]::new();$label.Left=18;$label.Top=$top+4;$label.Width=245;$label.Text=$text;[void]$form.Controls.Add($label);$top+=40}
  $stretch=[System.Windows.Forms.ComboBox]::new();$stretch.Left=270;$stretch.Top=16;$stretch.Width=210;$stretch.DropDownStyle='DropDownList';[void]$stretch.Items.AddRange(@('None','Fill','Uniform','UniformToFill'));$stretch.SelectedItem=[string]$Entry.stretch;if($stretch.SelectedIndex -lt 0){$stretch.SelectedItem='UniformToFill'}
  $align=[System.Windows.Forms.ComboBox]::new();$align.Left=270;$align.Top=56;$align.Width=210;$align.DropDownStyle='DropDownList';[void]$align.Items.AddRange(@('Center','Left','Right','Top','Bottom','TopLeft','TopRight','BottomLeft','BottomRight'));$align.SelectedItem=[string]$Entry.alignment;if($align.SelectedIndex -lt 0){$align.SelectedItem='Center'}
  $tile=[System.Windows.Forms.ComboBox]::new();$tile.Left=270;$tile.Top=96;$tile.Width=210;$tile.DropDownStyle='DropDownList';[void]$tile.Items.AddRange(@('None','Tile','FlipX','FlipY','FlipXY'));$tile.SelectedItem=[string]$Entry.tileMode;if($tile.SelectedIndex -lt 0){$tile.SelectedItem='None'}
  $opacity=[System.Windows.Forms.NumericUpDown]::new();$opacity.Left=270;$opacity.Top=136;$opacity.Width=210;$opacity.Minimum=0;$opacity.Maximum=100;$opacity.Value=[decimal]([Math]::Round([Math]::Max(0,[Math]::Min(1,[double]$Entry.opacity))*100))
  $overlay=[System.Windows.Forms.TextBox]::new();$overlay.Left=270;$overlay.Top=176;$overlay.Width=210;$overlay.Text=if(Test-PMMThemeHexColor ([string]$Entry.overlay)){[string]$Entry.overlay}else{'#00000000'}
  foreach($control in @($stretch,$align,$tile,$opacity,$overlay)){[void]$form.Controls.Add($control)}
  $ok=[System.Windows.Forms.Button]::new();$ok.Text='OK';$ok.Left=300;$ok.Top=220;$ok.Width=85;$ok.DialogResult=[System.Windows.Forms.DialogResult]::OK;$cancel=[System.Windows.Forms.Button]::new();$cancel.Text=L 'Cancel' 'Cancelar';$cancel.Left=395;$cancel.Top=220;$cancel.Width=85;$cancel.DialogResult=[System.Windows.Forms.DialogResult]::Cancel;[void]$form.Controls.Add($ok);[void]$form.Controls.Add($cancel);$form.AcceptButton=$ok;$form.CancelButton=$cancel
  if((Show-PMMStyledDialog $form) -ne [System.Windows.Forms.DialogResult]::OK){return $null}
  if(-not(Test-PMMThemeHexColor ([string]$overlay.Text))){throw 'Overlay color must be #RRGGBB or #RRGGBBAA.'}
  return [pscustomobject]@{stretch=[string]$stretch.SelectedItem;alignment=[string]$align.SelectedItem;tileMode=[string]$tile.SelectedItem;opacity=([double]$opacity.Value/100.0);overlay=([string]$overlay.Text).ToUpperInvariant()}
}

function Update-PMMThemeEditorDraftFromUi([switch]$Save) {
  $draft=$Script:ActiveThemeDraft;if(-not$draft){throw (L 'Create or load a draft first.' 'Crea o carga primero un borrador.')}
  $draft.Name=[string]$Script:TxtThemeEditorName.Text;$draft.ThemeId=[string]$Script:TxtThemeEditorId.Text;$draft.Base=[string]$Script:CmbThemeEditorBase.SelectedItem
  $palette=ConvertTo-PMMThemeDraftHashtable $draft.Palette;$flow=ConvertTo-PMMThemeDraftHashtable $draft.ColorFlow
  foreach($field in @(Get-PMMThemeEditorFields)){
    $fieldKey=[string]$field.Key;$row=$Script:ThemeEditorRowControls[$fieldKey];if(-not$row){continue}
    # Only copy fields the user actually edited. Dynamic WPF rows can receive
    # presentation TextChanged notifications while a tab/theme catalog is
    # being rebuilt; copying every control back used to turn an untouched
    # PMM Crystal clone into a false low-contrast draft on Windows PS 5.1.
    if($Script:ThemeEditorDirtyFields -and -not$Script:ThemeEditorDirtyFields.Contains($fieldKey)){continue}
    $value=([string]$row.TextBox.Text).Trim()
    if(-not(Test-PMMThemeHexColor $value)){throw ((L 'Invalid color in {0}: {1}' 'Color no valido en {0}: {1}') -f $fieldKey,$value)}
    if([string]$field.Kind -eq 'Palette'){$palette[$fieldKey]=$value}else{$stateKey=[string]$field.State;$partKey=[string]$field.Part;$state=ConvertTo-PMMThemeDraftHashtable $flow[$stateKey];$state[$partKey]=$value;$flow[$stateKey]=$state}
  }
  $draft.Palette=$palette;$draft.ColorFlow=$flow
  [void](Convert-PMMThemeDraftToDefinition $draft)
  if($Save){Save-PMMThemeDraft $draft|Out-Null;[void]$Script:ThemeEditorDirtyFields.Clear();Refresh-PMMThemeEditorCatalog}
  return $draft
}

function Show-PMMThemeDraft($Draft) {
  if(-not$Draft){return}
  $Script:ThemeEditorUiBuilding=$true
  try{
  $Script:ActiveThemeDraft=$Draft;$Script:TxtThemeEditorName.Text=[string]$Draft.Name;$Script:TxtThemeEditorId.Text=[string]$Draft.ThemeId;$Script:CmbThemeEditorBase.SelectedItem=[string]$Draft.Base
  $Script:PnlThemeEditorRows.Children.Clear();$Script:ThemeEditorRowControls=@{};[void]$Script:ThemeEditorDirtyFields.Clear();$lastGroup=''
  $brushes=ConvertTo-PMMThemeDraftHashtable $Draft.Brushes
  foreach($field in @(Get-PMMThemeEditorFields)){
    if([string]$field.Group -ne $lastGroup){$heading=[System.Windows.Controls.TextBlock]::new();$heading.Text=[string]$field.Group;$heading.FontWeight=[System.Windows.FontWeights]::SemiBold;$heading.FontSize=15;$heading.Margin=[System.Windows.Thickness]::new(0,9,0,4);[void]$Script:PnlThemeEditorRows.Children.Add($heading);$lastGroup=[string]$field.Group}
    $border=[System.Windows.Controls.Border]::new();$border.BorderBrush=$Window.Resources['CardBorder'];$border.BorderThickness=[System.Windows.Thickness]::new(1);$border.CornerRadius=[System.Windows.CornerRadius]::new(4);$border.Padding=[System.Windows.Thickness]::new(7);$border.Margin=[System.Windows.Thickness]::new(0,0,0,4)
    $grid=[System.Windows.Controls.Grid]::new();foreach($width in @('185','*','105','70','105','86','78')){$column=[System.Windows.Controls.ColumnDefinition]::new();$column.Width=if($width -eq '*'){[System.Windows.GridLength]::new(1,[System.Windows.GridUnitType]::Star)}else{[System.Windows.GridLength]::new([double]$width)};[void]$grid.ColumnDefinitions.Add($column)}
    $label=[System.Windows.Controls.StackPanel]::new();$name=[System.Windows.Controls.TextBlock]::new();$name.Text=[string]$field.Key;$name.FontWeight=[System.Windows.FontWeights]::SemiBold;$affected=[System.Windows.Controls.TextBlock]::new();$affected.Text=[string]$field.Affected;$affected.FontSize=10.5;$affected.Foreground=$Window.Resources['MutedText'];$affected.TextWrapping=[System.Windows.TextWrapping]::Wrap;[void]$label.Children.Add($name);[void]$label.Children.Add($affected);[System.Windows.Controls.Grid]::SetColumn($label,0);[void]$grid.Children.Add($label)
    $key=[string]$field.Key;$imageText=[System.Windows.Controls.TextBlock]::new();$imageText.VerticalAlignment=[System.Windows.VerticalAlignment]::Center;$imageText.Foreground=$Window.Resources['MutedText'];$imageText.TextTrimming=[System.Windows.TextTrimming]::CharacterEllipsis;$imageText.Margin=[System.Windows.Thickness]::new(5,0,5,0);$entry=$null;if($brushes.Contains($key)){$entry=$brushes[$key]};$imageText.Text=if($entry){[string]$entry.source}else{L 'Solid fallback' 'Color solido'};[System.Windows.Controls.Grid]::SetColumn($imageText,1);[void]$grid.Children.Add($imageText)
    $textBox=[System.Windows.Controls.TextBox]::new();$textBox.Text=Get-PMMThemeDraftFieldValue $Draft $field;$textBox.Margin=[System.Windows.Thickness]::new(2);[System.Windows.Controls.Grid]::SetColumn($textBox,2);[void]$grid.Children.Add($textBox)
    $textBox.Tag=[string]$field.Key
    $textBox.Add_TextChanged({param($sender,$e)if(-not[bool]$Script:ThemeEditorUiBuilding){[void]$Script:ThemeEditorDirtyFields.Add([string]$sender.Tag)}})
    $pick=[System.Windows.Controls.Button]::new();$pick.Content=L 'Color...' 'Color...';$pick.Margin=[System.Windows.Thickness]::new(2);Set-PMMThemeEditorSwatch $pick $textBox.Text;[System.Windows.Controls.Grid]::SetColumn($pick,3);[void]$grid.Children.Add($pick)
    $upload=[System.Windows.Controls.Button]::new();$upload.Content=L 'Upload image' 'Subir imagen';$upload.Margin=[System.Windows.Thickness]::new(2);[System.Windows.Controls.Grid]::SetColumn($upload,4);[void]$grid.Children.Add($upload)
    $options=[System.Windows.Controls.Button]::new();$options.Content=L 'Image...' 'Imagen...';$options.Margin=[System.Windows.Thickness]::new(2);$options.IsEnabled=($null -ne $entry);[System.Windows.Controls.Grid]::SetColumn($options,5);[void]$grid.Children.Add($options)
    $remove=[System.Windows.Controls.Button]::new();$remove.Content=L 'Remove' 'Quitar';$remove.Margin=[System.Windows.Thickness]::new(2);$remove.IsEnabled=($null -ne $entry);[System.Windows.Controls.Grid]::SetColumn($remove,6);[void]$grid.Children.Add($remove)
    $pickHandler={try{$dialog=[System.Windows.Forms.ColorDialog]::new();$dialog.FullOpen=$true;if($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK){$hex=('#{0:X2}{1:X2}{2:X2}' -f $dialog.Color.R,$dialog.Color.G,$dialog.Color.B);$textBox.Text=$hex;Set-PMMThemeEditorSwatch $pick $hex}}catch{Handle-UIError $_ (L 'Choose theme color' 'Elegir color del tema')}}.GetNewClosure();$pick.Add_Click($pickHandler)
    $uploadHandler={try{[void](Update-PMMThemeEditorDraftFromUi -Save);$dialog=[Microsoft.Win32.OpenFileDialog]::new();$dialog.Filter='PNG/JPEG images (*.png;*.jpg;*.jpeg)|*.png;*.jpg;*.jpeg';if($dialog.ShowDialog() -eq $true){$Script:ActiveThemeDraft=Set-PMMThemeDraftImage $Script:ActiveThemeDraft $key ([string]$dialog.FileName);Show-PMMThemeDraft $Script:ActiveThemeDraft;$Script:TxtThemeEditorStatus.Text=(L 'Image copied into the draft. The fallback color remains required.' 'Imagen copiada al borrador. El color de respaldo sigue siendo obligatorio.')}}catch{Handle-UIError $_ (L 'Upload theme image' 'Subir imagen del tema')}}.GetNewClosure();$upload.Add_Click($uploadHandler)
    $optionsHandler={try{[void](Update-PMMThemeEditorDraftFromUi -Save);$all=ConvertTo-PMMThemeDraftHashtable $Script:ActiveThemeDraft.Brushes;if(-not$all.Contains($key)){return};$result=Show-PMMThemeImageOptions $all[$key];if($result){$entry=$all[$key];$entry.stretch=[string]$result.stretch;$entry.alignment=[string]$result.alignment;$entry.tileMode=[string]$result.tileMode;$entry.opacity=[double]$result.opacity;$entry.overlay=[string]$result.overlay;$all[$key]=$entry;$Script:ActiveThemeDraft.Brushes=$all;Save-PMMThemeDraft $Script:ActiveThemeDraft|Out-Null;Show-PMMThemeDraft $Script:ActiveThemeDraft}}catch{Handle-UIError $_ (L 'Edit image brush' 'Editar imagen del brush')}}.GetNewClosure();$options.Add_Click($optionsHandler)
    $removeHandler={try{$Script:ActiveThemeDraft=Remove-PMMThemeDraftImage $Script:ActiveThemeDraft $key;Show-PMMThemeDraft $Script:ActiveThemeDraft}catch{Handle-UIError $_ (L 'Remove theme image' 'Quitar imagen del tema')}}.GetNewClosure();$remove.Add_Click($removeHandler)
    $border.Child=$grid;[void]$Script:PnlThemeEditorRows.Children.Add($border);$Script:ThemeEditorRowControls[$key]=[pscustomobject]@{TextBox=$textBox;Swatch=$pick;ImageText=$imageText;ImageOptions=$options}
  }
  $Script:TxtThemeEditorStatus.Text=((L 'Draft loaded: {0}. Edit colors/images, then Save draft. Preview never changes the saved Settings choice.' 'Borrador cargado: {0}. Edita colores/imagenes y guarda el borrador. Vista previa nunca cambia la eleccion guardada en Opciones.') -f [string]$Draft.Name)
  }finally{$Script:ThemeEditorUiBuilding=$false}
}

function Get-PMMThemeDraftPreviewDefinition($Draft) {
  $raw=Convert-PMMThemeDraftToDefinition $Draft
  return [pscustomobject]@{Id=[string]$raw.id;Name=[string]$raw.name;Schema=[string]$raw.schema;Base=[string]$raw.base;Palette=$raw.palette;ColorFlow=$raw.colorFlow;Brushes=$raw.brushes;ThemeRoot=(Get-PMMThemeDraftRoot ([string]$Draft.DraftId))}
}

function Repair-PMMDuplicateDiagnosticSessions {
  $linked=[Collections.Generic.List[object]]::new()
  $rank=@{Draft=1;WaitingForAI=2;NeedsData=3;NeedsUserDecision=4;CandidateReady=5;CandidateAcceptedExperimental=6}
  foreach($row in @(Get-PMMAIIOSessions|Where-Object{-not[bool]$_.Archived})){
    $session=Get-PMMAIIOSession ([string]$row.SessionId)
    if(-not$session -or [string]$session.PrimaryTarget.Kind -ne 'DiagnosticCase'){continue}
    $caseId=[string]$session.PrimaryTarget.Id;if($caseId -notmatch '^DIAG-'){continue}
    $score=0;if($rank.ContainsKey([string]$session.Status)){$score=[int]$rank[[string]$session.Status]}
    $linked.Add([pscustomobject]@{CaseId=$caseId;Session=$session;Score=$score;Iteration=[int]$session.Iteration;Updated=[string]$session.UpdatedUtc})
  }
  foreach($group in @($linked.ToArray()|Group-Object CaseId|Where-Object{$_.Count -gt 1})){
    $ordered=@($group.Group|Sort-Object @{Expression='Score';Descending=$true},@{Expression='Iteration';Descending=$true},@{Expression='Updated';Descending=$true})
    foreach($duplicate in @($ordered|Select-Object -Skip 1)){
      try{Set-PMMAIIOSessionArchived ([string]$duplicate.Session.SessionId) $true|Out-Null;Write-PMMLog ('Archived duplicate diagnostic AIIO session '+[string]$duplicate.Session.SessionId+'; retained '+[string]$ordered[0].Session.SessionId)}catch{}
    }
  }
}

function Initialize-PMMAIHelpUi {
  try{[void](Resolve-PMMKnownLegacyUiDiagnostics)}catch{}
  try{Repair-PMMDuplicateDiagnosticSessions}catch{}
  $Script:CmbAIHelpDiagnosticType.ItemsSource=@(
    [pscustomobject]@{Id='MOD_NOT_WORKING';Feature='ModLibrary';Label=(L 'Mod import and library' 'Importacion y biblioteca de mods')},
    [pscustomobject]@{Id='BUILD_FAILURE';Feature='Analyze';Label=(L 'Analyze and conflict detection' 'Analisis y deteccion de conflictos')},
    [pscustomobject]@{Id='BUILD_FAILURE';Feature='Decisions';Label=(L 'Conflict decisions' 'Decisiones de conflictos')},
    [pscustomobject]@{Id='BUILD_FAILURE';Feature='BuildMerge';Label=(L 'Build compatibility merge' 'Crear merge de compatibilidad')},
    [pscustomobject]@{Id='DEPLOY_FAILURE';Feature='Deploy';Label=(L 'Deploy / undeploy' 'Deploy / undeploy')},
    [pscustomobject]@{Id='BUILD_FAILURE';Feature='ValidationFeedback';Label=(L 'Merge validation and feedback' 'Validacion y feedback de merge')},
    [pscustomobject]@{Id='FIXLAB_FAILURE';Feature='FixLab';Label=(L 'Fix Lab' 'Fix Lab')},
    [pscustomobject]@{Id='SAVE_PROBLEM';Feature='Saves';Label=(L 'Saves and backups' 'Saves y backups')},
    [pscustomobject]@{Id='BUILD_FAILURE';Feature='GameReference';Label=(L 'Vanilla Game Reference' 'Vanilla Game Reference')},
    [pscustomobject]@{Id='FEATURE_MISSING';Feature='AIHelp';Label=(L 'AI assistance / reception' 'Ayuda / recepcion de IA')},
    [pscustomobject]@{Id='FEATURE_MISSING';Feature='ColorSchemes';Label=(L 'Color schemes and editor' 'Esquemas de color y editor')},
    [pscustomobject]@{Id='FEATURE_MISSING';Feature='Settings';Label=(L 'Settings and interface' 'Opciones e interfaz')},
    [pscustomobject]@{Id='PERFORMANCE_PROBLEM';Feature='Performance';Label=(L 'Performance or high CPU usage' 'Rendimiento o uso alto de CPU')},
    [pscustomobject]@{Id='GAME_CRASH';Feature='PalworldCrash';Label=(L 'Palworld crash' 'Crash de Palworld')},
    [pscustomobject]@{Id='UNKNOWN';Feature='Other';Label=(L 'Other / I am not sure' 'Otro / No estoy seguro')})
  $Script:CmbAIHelpDiagnosticType.SelectedIndex=0
  $Script:CmbAIIOType.ItemsSource=@(
    [pscustomobject]@{Id='MOD_NOT_WORKING';Label=(L 'Investigate a mod' 'Investigar un mod')},[pscustomobject]@{Id='UNSUPPORTED_CONFLICT';Label=(L 'Resolve Unsupported conflicts' 'Resolver conflictos Unsupported')},[pscustomobject]@{Id='CREATE_MOD';Label=(L 'Create a mod' 'Crear un mod')},[pscustomobject]@{Id='MODIFY_MOD';Label=(L 'Modify a mod' 'Modificar un mod')},[pscustomobject]@{Id='PMM_DEVELOPMENT';Label=(L 'Develop or repair PMM' 'Desarrollar o reparar PMM')},[pscustomobject]@{Id='THEME_DESIGN';Label=(L 'Design a color scheme' 'Disenar un esquema de color')},[pscustomobject]@{Id='UNKNOWN';Label=(L 'General task' 'Tarea general')})
  $Script:CmbAIIOType.SelectedIndex=0
  $Script:CmbAIOTargetKind.ItemsSource=@(
    [pscustomobject]@{Id='Palworld';Label='Palworld'},[pscustomobject]@{Id='Mod';Label=(L 'Mod' 'Mod')},[pscustomobject]@{Id='CompatibilityBuild';Label=(L 'Compatibility build' 'Build de compatibilidad')},[pscustomobject]@{Id='FixLabResult';Label='Fix Lab result'},[pscustomobject]@{Id='Save';Label=(L 'Save/world' 'Save/mundo')},[pscustomobject]@{Id='Deployment';Label='Deployment'},[pscustomobject]@{Id='PMM';Label='PMM'},[pscustomobject]@{Id='Unknown';Label=(L "I don't know" 'No lo se')})
  $Script:CmbAIOTargetKind.SelectedIndex=0
  $Script:CmbAIHelpFeedbackType.ItemsSource=@(
    [pscustomobject]@{Id='GENERAL_COMMENT';Label=(L 'General comment' 'Comentario general')},
    [pscustomobject]@{Id='PMM_ISSUE';Label=(L 'PMM issue or suggestion' 'Problema o sugerencia de PMM')},
    [pscustomobject]@{Id='MERGE_COMMENT';Label=(L 'Merge / validation comment' 'Comentario de merge / validacion')},
    [pscustomobject]@{Id='KNOWLEDGE_CKL_COMMENT';Label=(L 'Knowledge / CKL comment' 'Comentario de Knowledge / CKL')}
  )
  $Script:CmbAIHelpFeedbackType.SelectedIndex=0
  $Script:CmbThemeEditorBase.ItemsSource=@('Night','Light');$Script:CmbThemeEditorBase.SelectedItem='Night'
}

function Show-PMMBuildValidationDialog([string]$CurrentStatus) {
  $clientWidth=1040
  $form=[System.Windows.Forms.Form]::new();$form.Text=L 'Validate exact compatibility merge' 'Validar merge de compatibilidad exacto';$form.ClientSize=[System.Drawing.Size]::new($clientWidth,360);$form.StartPosition='CenterParent';$form.FormBorderStyle=[System.Windows.Forms.FormBorderStyle]::FixedDialog;$form.MaximizeBox=$false;$form.MinimizeBox=$false;$form.AutoScaleMode=[System.Windows.Forms.AutoScaleMode]::Dpi;$form.Font=[System.Drawing.Font]::new('Segoe UI',11)
  $label=[System.Windows.Forms.Label]::new();$label.Left=28;$label.Top=24;$label.Width=984;$label.Height=90;$label.Font=[System.Drawing.Font]::new('Segoe UI Semibold',15);$label.AutoEllipsis=$false
  $label.Text=if($CurrentStatus -eq 'LOCAL_PASS'){L 'This exact merge is marked as working. Has it stopped working?' 'Este merge exacto esta marcado como funcional. Ha dejado de funcionar?'}else{L 'Have you tested this exact merge in Palworld?' 'Has probado este merge exacto dentro de Palworld?'}
  $buttons=[Collections.Generic.List[object]]::new()
  $choices=@()
  if($CurrentStatus -eq 'LOCAL_PASS'){
    $choices=@(
      [pscustomobject]@{Result='FAIL';Label=(L 'Report a problem' 'Reportar un problema')},
      [pscustomobject]@{Result='PASS_RECONFIRMED';Label=(L 'No, it still works' 'No, sigue funcionando')},
      [pscustomobject]@{Result='CANCEL';Label=(L 'Cancel' 'Cancelar')}
    )
  }else{
    $choices=@(
      [pscustomobject]@{Result='PASS';Label=(L 'Yes, it works' 'Si, funciona')},
      [pscustomobject]@{Result='PARTIAL';Label=(L 'Partially works' 'Funciona parcialmente')},
      [pscustomobject]@{Result='FAIL';Label=(L 'No, it failed' 'No, fallo')},
      [pscustomobject]@{Result='CANCEL';Label=(L 'Cancel' 'Cancelar')}
    )
  }
  $buttonWidth=230;$buttonGap=14;$totalWidth=($choices.Count*$buttonWidth)+([Math]::Max(0,$choices.Count-1)*$buttonGap);$left=[int](($clientWidth-$totalWidth)/2)
  foreach($choice in $choices){$button=[System.Windows.Forms.Button]::new();$button.Text=[string]$choice.Label;$button.Tag=[string]$choice.Result;$button.Left=$left;$button.Top=126;$button.Width=$buttonWidth;$button.Height=76;$button.Font=[System.Drawing.Font]::new('Segoe UI Semibold',12);$button.AutoEllipsis=$false;$button.UseMnemonic=$false;$button.Add_Click({param($sender,$e)$form.Tag=[string]$sender.Tag;$form.Close()});[void]$form.Controls.Add($button);$buttons.Add($button);if([string]$choice.Result -eq 'CANCEL'){$form.CancelButton=$button};$left+=$buttonWidth+$buttonGap}
  $note=[System.Windows.Forms.Label]::new();$note.Left=28;$note.Top=250;$note.Width=984;$note.Height=70;$note.Font=[System.Drawing.Font]::new('Segoe UI',11);$note.Text=L 'The result is recorded locally against a deterministic buildId. It is not uploaded.' 'El resultado se registra localmente contra un buildId determinista. No se sube.'
  [void]$form.Controls.Add($label);[void]$form.Controls.Add($note);[void](Show-PMMStyledDialog $form);return [string]$form.Tag
}

function Show-PMMValidationContributionDialog {
  $form=[System.Windows.Forms.Form]::new();$form.Text=L 'Share tested knowledge' 'Compartir conocimiento probado';$form.ClientSize=[System.Drawing.Size]::new(760,300);$form.StartPosition='CenterParent';$form.FormBorderStyle=[System.Windows.Forms.FormBorderStyle]::FixedDialog;$form.MaximizeBox=$false;$form.MinimizeBox=$false;$form.AutoScaleMode=[System.Windows.Forms.AutoScaleMode]::Dpi;$form.Font=[System.Drawing.Font]::new('Segoe UI',11)
  $label=[System.Windows.Forms.Label]::new();$label.Left=28;$label.Top=24;$label.Width=704;$label.Height=112;$label.Font=[System.Drawing.Font]::new('Segoe UI Semibold',14);$label.Text=L 'This exact merge works. Would you like to contribute that result to PMM Knowledge? You can review and add comments before creating the share file.' 'Este merge exacto funciona. Quieres aportar ese resultado a PMM Knowledge? Podras revisarlo y anadir comentarios antes de crear el archivo para compartir.'
  $yes=[System.Windows.Forms.Button]::new();$yes.Text=L 'Yes, open feedback' 'Si, abrir feedback';$yes.Left=122;$yes.Top=164;$yes.Width=245;$yes.Height=72;$yes.Font=[System.Drawing.Font]::new('Segoe UI Semibold',12);$yes.DialogResult=[System.Windows.Forms.DialogResult]::Yes
  $later=[System.Windows.Forms.Button]::new();$later.Text=L 'Not now' 'Ahora no';$later.Left=393;$later.Top=164;$later.Width=245;$later.Height=72;$later.Font=[System.Drawing.Font]::new('Segoe UI Semibold',12);$later.DialogResult=[System.Windows.Forms.DialogResult]::No
  $form.Controls.AddRange(@($label,$yes,$later));$form.AcceptButton=$yes;$form.CancelButton=$later
  return ((Show-PMMStyledDialog $form) -eq [System.Windows.Forms.DialogResult]::Yes)
}