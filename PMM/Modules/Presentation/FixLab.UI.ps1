# Preserved 1.3.2 definitions; extracted for 1.3.3.
function Update-PMMFixLabAttentionFromLibrary([string]$Origin='') {
  try{
    if(-not(Initialize-PMMFixLabFeature)){return}
    $candidates=@(Get-PMMFixLabDiscoveryCandidates)
    if($candidates.Count -gt 0 -and [string]::IsNullOrWhiteSpace([string]$Script:FixLabSelectedRecipeId)){$Script:FixLabSelectedRecipeId=[string]$candidates[0].RecipeId;$Script:FixLabSelectedVariantId=''}
    Set-PMMFixLabAttentionVisual $candidates $Origin
    Refresh-PMMFixLabUI
  }catch{Write-PMMLog ('Fix Lab notification refresh failed: '+$_.Exception.Message)}
}

function New-PMMFixLabUiCollection([array]$Items) {
  $list=[System.Collections.ArrayList]::new()
  foreach($item in @($Items)){if($null -ne $item){[void]$list.Add($item)}}
  # Do not let PowerShell enumerate the ArrayList on function return. Without
  # this, a one-row list is emitted as a scalar PSCustomObject and WPF throws
  # when assigning it to ItemsSource because ItemsSource requires IEnumerable.
  return ,$list
}

function Set-PMMFixLabControlsEnabled([bool]$Enabled) {
  foreach($b in @(
    $Script:BtnFixLabOpenRoot,$Script:BtnFixLabBuildReference,$Script:BtnFixLabOpenReference,$Script:BtnFixLabCreateHandoff,
    $Script:BtnFixLabDiscover,$Script:BtnFixLabRefreshDashboard,$Script:BtnFixLabRevertBackup,$Script:BtnFixLabOpenBackupFolder,$Script:BtnFixLabIgnoreSource,$Script:BtnFixLabDeleteSource,$Script:BtnFixLabClearIgnored,$Script:BtnFixLabApplyBuilt,$Script:BtnFixLabRepair,$Script:BtnFixLabDismissNotice
  )){if($b){$b.IsEnabled=$Enabled}}
}

function Set-PMMFixLabUnavailable([string]$Message) {
  Set-PMMFixLabControlsEnabled $false
  if($Script:TxtFixLabCandidate){$Script:TxtFixLabCandidate.Text=L 'Fix Lab could not be loaded. Mods & Merge remains usable.' 'Fix Lab no pudo cargarse. Mods & Merge sigue disponible.'}
  if($Script:TxtFixLabRepairState){$Script:TxtFixLabRepairState.Text=[string]$Message}
  if($Script:TxtFixLabResult){$Script:TxtFixLabResult.Text=''}
}

function Get-PMMFixLabSelectedCandidate {
  if($Script:LstFixLabCandidates -and $Script:LstFixLabCandidates.SelectedItem){return $Script:LstFixLabCandidates.SelectedItem}
  if(-not[string]::IsNullOrWhiteSpace([string]$Script:FixLabSelectedRecipeId)){
    $cached=@($Script:FixLabCachedCandidates|Where-Object{[string]$_.RecipeId -ieq [string]$Script:FixLabSelectedRecipeId}|Select-Object -First 1)
    if($cached.Count -gt 0){return $cached[0]}
  }
  return $null
}

function Test-PMMFixLabBuiltDeployAllowed($Built) {
  if(-not$Built){return $false}
  if($Built.PSObject.Properties.Name -contains 'DeployAllowed'){return [bool]$Built.DeployAllowed}
  return $true
}

function Get-PMMFixLabBuiltDeploymentNote($Built) {
  if(-not$Built){return ''}
  if($Built.PSObject.Properties.Name -contains 'DeploymentNote'){return [string]$Built.DeploymentNote}
  return ''
}

function Get-PMMFixLabBuiltOutputClass($Built) {
  if(-not$Built){return ''}
  if($Built.PSObject.Properties.Name -contains 'OutputClass'){return [string]$Built.OutputClass}
  if(Test-PMMFixLabBuiltDeployAllowed $Built){return 'experimental-repair'}
  return 'engine-test'
}

function Update-PMMFixLabDeployButtonPresentation($Built) {
  if(-not$Script:BtnFixLabApplyBuilt){return}
  if(-not$Built){
    $Script:BtnFixLabApplyBuilt.Content=L 'Apply Fix' 'Aplicar Fix'
    $Script:BtnFixLabApplyBuilt.ToolTip=L 'Select a deployable built repair output.' 'Selecciona una salida reparada desplegable.'
    return
  }
  if(($Built.PSObject.Properties.Name -contains 'Applied') -and [bool]$Built.Applied){
    $Script:BtnFixLabApplyBuilt.Content=L 'Applied' 'Aplicado'
    $Script:BtnFixLabApplyBuilt.ToolTip=L 'This repaired output is already installed. The next workflow action is Analyze.' 'Esta salida reparada ya esta instalada. La siguiente accion del flujo es Analyze.'
    return
  }
  if(Test-PMMFixLabBuiltDeployAllowed $Built){
    $Script:BtnFixLabApplyBuilt.Content=L 'Apply Fix' 'Aplicar Fix'
    if((Get-PMMFixLabBuiltOutputClass $Built) -ieq 'runtime-proven-repair'){
      $Script:BtnFixLabApplyBuilt.ToolTip=L 'Runtime-proven repair. Archive the recognized legacy source and install this repaired PAK.' 'Reparacion probada en runtime. Archiva la fuente antigua reconocida e instala este PAK reparado.'
    }else{
      $Script:BtnFixLabApplyBuilt.ToolTip=L 'Deployable repair. See the confidence level in Built outputs for the evidence currently recorded by Fix Lab.' 'Reparacion desplegable. Consulta el nivel de confianza en Built outputs para ver la evidencia registrada actualmente por Fix Lab.'
    }
  }else{
    $Script:BtnFixLabApplyBuilt.Content=L 'Engine test - no deploy' 'Prueba de motor - sin deploy'
    $note=Get-PMMFixLabBuiltDeploymentNote $Built
    if([string]::IsNullOrWhiteSpace($note)){$note=L 'This output validates engine primitives only and is not a finished repair.' 'Esta salida solo valida primitivas del motor y no es una reparacion final.'}
    $Script:BtnFixLabApplyBuilt.ToolTip=$note
  }
}

function Refresh-PMMFixLabUI {
  if(-not$Script:FixLabLoaded -or $Script:FixLabUiRefreshing){return}
  $Script:FixLabUiRefreshing=$true
  try{
    $selectedRecipe=[string]$Script:FixLabSelectedRecipeId
    if($Script:LstFixLabCandidates -and $Script:LstFixLabCandidates.SelectedItem){$selectedRecipe=[string]$Script:LstFixLabCandidates.SelectedItem.RecipeId}
    $selectedBuild=if($Script:LstFixLabBuiltFixes -and $Script:LstFixLabBuiltFixes.SelectedItem){[string]$Script:LstFixLabBuiltFixes.SelectedItem.BuildId}else{[string]$Script:FixLabSelectedBuildId}

    # Build one filesystem snapshot and derive the attention subset from it.
    # RC23 performed two complete library discoveries plus a second backup scan
    # every time this dashboard refreshed.
    $backups=@(Get-PMMFixLabBackups)
    $candidates=@(Get-PMMFixLabDiscoveryCandidates -IncludeBackups -BackupRows $backups)
    $attentionCandidates=@($candidates|Where-Object{$row=$_;@($row.Sources|Where-Object{[string]$_.Origin -eq 'Library'}).Count -gt 0})
    $Script:FixLabCachedCandidates=@($candidates)
    $Script:FixLabCachedAttentionCandidates=@($attentionCandidates)
    if($Script:TxtFixLabCandidateCount){$Script:TxtFixLabCandidateCount.Text=((L '{0} candidate(s)' '{0} candidato(s)') -f $candidates.Count)}
    $Script:LstFixLabCandidates.ItemsSource=(New-PMMFixLabUiCollection $candidates)
    if(-not[string]::IsNullOrWhiteSpace($selectedRecipe)){
      $candidate=@($candidates|Where-Object{[string]$_.RecipeId -ieq $selectedRecipe}|Select-Object -First 1)[0]
      if($candidate){$Script:LstFixLabCandidates.SelectedValue=[string]$candidate.RecipeId;$Script:FixLabSelectedRecipeId=[string]$candidate.RecipeId}
    }
    if(-not$Script:LstFixLabCandidates.SelectedItem -and $candidates.Count -gt 0){$Script:LstFixLabCandidates.SelectedIndex=0;$Script:FixLabSelectedRecipeId=[string]$candidates[0].RecipeId}

    $Script:FixLabCachedBackups=@($backups)
    if($Script:TxtFixLabBackupCount){$Script:TxtFixLabBackupCount.Text=((L '{0} case backup(s)' '{0} backup(s) de caso') -f $backups.Count)}
    $Script:LstFixLabBackups.ItemsSource=(New-PMMFixLabUiCollection $backups)
    if($backups.Count -eq 1){$Script:LstFixLabBackups.SelectedIndex=0}
    $hasBackup=($null -ne $Script:LstFixLabBackups.SelectedItem)
    $Script:BtnFixLabRevertBackup.IsEnabled=$hasBackup
    if($Script:BtnFixLabOpenBackupFolder){$Script:BtnFixLabOpenBackupFolder.IsEnabled=$hasBackup}

    $built=@(Get-PMMFixLabBuiltOutputs)
    $Script:FixLabCachedBuilt=@($built)
    if($Script:TxtFixLabBuiltCount){$Script:TxtFixLabBuiltCount.Text=((L '{0} variant(s)' '{0} variante(s)') -f $built.Count)}
    $Script:LstFixLabBuiltFixes.ItemsSource=(New-PMMFixLabUiCollection $built)
    if(-not[string]::IsNullOrWhiteSpace($selectedBuild)){
      $b=@($built|Where-Object{[string]$_.BuildId -ieq $selectedBuild}|Select-Object -First 1)[0]
      if($b){$Script:LstFixLabBuiltFixes.SelectedValue=[string]$b.BuildId;$Script:FixLabSelectedBuildId=[string]$b.BuildId}
    }
    $selectedBuilt=$Script:LstFixLabBuiltFixes.SelectedItem
    $Script:BtnFixLabApplyBuilt.IsEnabled=(-not[bool]$Script:FixLabOperationBusy -and $selectedBuilt -and -not[bool]$selectedBuilt.Applied -and (Test-PMMFixLabBuiltDeployAllowed $selectedBuilt))
    Update-PMMFixLabDeployButtonPresentation $selectedBuilt

    $candidate=Get-PMMFixLabSelectedCandidate
    $candidateBuildState=$null
    if($candidate){
      $recipe=Get-PMMFixLabRecipe ([string]$candidate.RecipeId)
      $Script:TxtFixLabCandidate.Text=((L 'Selected case: {0}`nDetected source mods: {1}' 'Caso seleccionado: {0}`nMods fuente detectados: {1}') -f [string]$candidate.Name,[string]$candidate.SourceNames)
      if($Script:TxtFixLabLegacySource){$Script:TxtFixLabLegacySource.Text=[string]$candidate.SourceNames}
      $strategies=@($recipe.repairStrategies)
      if($Script:TxtFixLabModules){$Script:TxtFixLabModules.Text=((L '{0} repair strategies' '{0} estrategias de reparacion') -f $strategies.Count)}
      $variantRows=[System.Collections.Generic.List[object]]::new()
      foreach($v in @($recipe.variants)){$variantRows.Add([pscustomobject]@{Id=[string]$v.id;Label=[string]$v.label;Description=[string]$v.description;RuntimeStatus=[string]$v.runtimeStatus;BuildStatus=[string]$v.buildStatus;Display=([string]$v.label+' | '+[string]$v.runtimeStatus)})}
      $Script:CmbFixLabVariant.ItemsSource=(New-PMMFixLabUiCollection $variantRows.ToArray())
      $wanted=[string]$Script:FixLabSelectedVariantId
      # A recipe with exactly one output is safe to select automatically. With
      # multiple cosmetic/behavior outputs PMM must stop and let the user pick.
      if([string]::IsNullOrWhiteSpace($wanted) -and $variantRows.Count -eq 1){$wanted=[string]$variantRows[0].Id}
      if(-not[string]::IsNullOrWhiteSpace($wanted)){$Script:CmbFixLabVariant.SelectedValue=$wanted}else{$Script:CmbFixLabVariant.SelectedIndex=-1}
      if($Script:CmbFixLabVariant.SelectedItem){
        $Script:FixLabSelectedVariantId=[string]$Script:CmbFixLabVariant.SelectedItem.Id
        $Script:TxtFixLabVariantDescription.Text=[string]$Script:CmbFixLabVariant.SelectedItem.Description
        if($Script:TxtFixLabOutputSize){
          $existing=@($built|Where-Object{[string]$_.RecipeId -ieq [string]$candidate.RecipeId -and [string]$_.VariantId -ieq [string]$Script:FixLabSelectedVariantId}|Select-Object -First 1)[0]
          $Script:TxtFixLabOutputSize.Text=if($existing){[string]$existing.SizeMb}else{L 'Pending build' 'Pendiente de construir'}
        }
      }else{
        $Script:FixLabSelectedVariantId=''
        $Script:TxtFixLabVariantDescription.Text=if($variantRows.Count -gt 1){L 'Choose one output. PMM will not choose a cosmetic/behavior variant for you.' 'Elige una salida. PMM no elegira por ti una variante cosmetica/de comportamiento.'}else{''}
        if($Script:TxtFixLabOutputSize){$Script:TxtFixLabOutputSize.Text=L 'Pending selection' 'Pendiente de seleccion'}
      }
      $candidateBuildState=Get-PMMFixLabCandidateBuildState $candidate ([string]$Script:FixLabSelectedVariantId)
      $Script:FixLabCachedBuildState=$candidateBuildState
      $Script:TxtFixLabRepairState.Text=[string]$candidateBuildState.Reason
      $Script:BtnFixLabRepair.IsEnabled=[bool]$candidateBuildState.Ready
      $Script:BtnFixLabCreateHandoff.IsEnabled=$true
    }else{
      $Script:TxtFixLabCandidate.Text=L 'No repairable imported mods detected. Press ANALYZE FIXABLE MODS after importing legacy mods.' 'No se detectaron mods importados reparables. Pulsa ANALYZE FIXABLE MODS despues de importar mods antiguos.'
      $Script:CmbFixLabVariant.ItemsSource=(New-PMMFixLabUiCollection @())
      if($Script:TxtFixLabLegacySource){$Script:TxtFixLabLegacySource.Text='-'}
      if($Script:TxtFixLabModules){$Script:TxtFixLabModules.Text='-'}
      if($Script:TxtFixLabOutputSize){$Script:TxtFixLabOutputSize.Text=L 'Pending build' 'Pendiente de construir'}
      $Script:TxtFixLabVariantDescription.Text=''
      $Script:FixLabCachedBuildState=$null
      $Script:TxtFixLabRepairState.Text=L 'Fix Lab Analyze only searches for mods with a known repair recipe.' 'Fix Lab Analyze solo busca mods con una receta de reparacion conocida.'
      $Script:BtnFixLabRepair.IsEnabled=$false;$Script:BtnFixLabCreateHandoff.IsEnabled=$false
    }

    try{
      $gr=Get-PMMGameReferenceState
      $Script:FixLabCachedGameReferenceState=$gr
      if([string]$gr.Status -eq 'Current'){$Script:TxtFixLabGameReference.Text=((L 'Current Game Reference: READY | {0} families | mappings {1}' 'Game Reference actual: LISTA | {0} familias | mappings {1}') -f [int]$gr.FamilyCount,[string]$gr.Identity.MappingsSha256)}
      else{$Script:TxtFixLabGameReference.Text=((L 'Current Game Reference: {0}. Repair recipes may require a fresh reference.' 'Game Reference actual: {0}. Las recetas pueden requerir una referencia actualizada.') -f [string]$gr.Status)}
    }catch{$Script:FixLabCachedGameReferenceState=$null;$Script:TxtFixLabGameReference.Text=L 'Game Reference status unavailable.' 'Estado de Game Reference no disponible.'}

    # The legacy job/debug controls are hidden and can be expensive to hydrate.
    # Populate them only when the Advanced card is actually expanded. Normal
    # navigation must never scan job inventories that the user cannot see.
    if($Script:ExpFixLabAdvanced -and [bool]$Script:ExpFixLabAdvanced.IsExpanded){
      $jobs=@(Get-PMMFixLabJobs);$Script:CmbFixLabJob.ItemsSource=(New-PMMFixLabUiCollection $jobs)
      $job=Get-PMMFixLabCurrentJob
      if($job){
        $Script:TxtFixLabPrimary.Text=[string]$job.Primary.Name
        $Script:LstFixLabRelated.ItemsSource=(New-PMMFixLabUiCollection @($job.Related))
        $Script:TxtFixLabAnalysis.Text=if($job.Analysis){[string]$job.Analysis.Summary}else{''}
        $pakRows=@()
        if($job.Analysis){$pakRows=@($job.Analysis.PakInventory)}
        $Script:DgFixLabPakInventory.ItemsSource=(New-PMMFixLabUiCollection $pakRows)
        $matches=[System.Collections.Generic.List[object]]::new()
        foreach($m in @($job.Analysis.RecipeMatches)){$matches.Add([pscustomobject]@{RecipeId=[string]$m.RecipeId;Name=[string]$m.Name})}
        $Script:CmbFixLabRecipe.ItemsSource=(New-PMMFixLabUiCollection $matches.ToArray())
        $Script:TxtFixLabBuildState.Text=[string](Get-PMMFixLabBuildState $job).Reason
        if($job.Build){$Script:TxtFixLabResult.Text=((L 'Last job result: {0} | {1}' 'Ultimo resultado: {0} | {1}') -f [string]$job.Build.Status,[string]$job.Build.Validation)}
      }
    }

    Set-PMMFixLabControlsEnabled (-not[bool]$Script:FixLabOperationBusy)
    # A shared Game Reference worker can be running while Fix Lab refreshes.
    # Keep the Fix Lab reference button locked and repaint its ColorFlow
    # progress after the generic control refresh so it cannot be started twice.
    $grRunningNow=$false;try{$grRunningNow=($Script:GameReferenceProcess -and -not$Script:GameReferenceProcess.HasExited)}catch{}
    if($grRunningNow -and $Script:BtnFixLabBuildReference){
      $Script:BtnFixLabBuildReference.IsEnabled=$false
      $grFraction=[double]$Script:GameReferenceProgressPercent/100.0
      Set-PMMWorkflowButtonProgress $Script:BtnFixLabBuildReference 'Build' $grFraction ([string]$Script:GameReferenceProgressMessage) -Indeterminate:([bool]$Script:GameReferenceProgressIndeterminate)
    }
    $repairReady=$false;try{if($candidateBuildState){$repairReady=[bool]$candidateBuildState.Ready}}catch{}
    $Script:BtnFixLabRepair.IsEnabled=(-not[bool]$Script:FixLabOperationBusy -and $repairReady)
    $selectedBuilt=$Script:LstFixLabBuiltFixes.SelectedItem
    $Script:BtnFixLabApplyBuilt.IsEnabled=(-not[bool]$Script:FixLabOperationBusy -and $selectedBuilt -and -not[bool]$selectedBuilt.Applied -and (Test-PMMFixLabBuiltDeployAllowed $selectedBuilt))
    Update-PMMFixLabDeployButtonPresentation $selectedBuilt
    $backupSelected=($null -ne $Script:LstFixLabBackups.SelectedItem)
    $Script:BtnFixLabRevertBackup.IsEnabled=(-not[bool]$Script:FixLabOperationBusy -and $backupSelected)
    if($Script:BtnFixLabOpenBackupFolder){$Script:BtnFixLabOpenBackupFolder.IsEnabled=(-not[bool]$Script:FixLabOperationBusy -and $backupSelected)}
    $liveSource=$false
    if($candidate){foreach($src in @($candidate.Sources)){if($src -and [string]$src.Origin -ne 'FixLabBackup' -and [string]$src.Origin -ne 'Backup'){$liveSource=$true;break}}}
    if($Script:BtnFixLabIgnoreSource){$Script:BtnFixLabIgnoreSource.IsEnabled=(-not[bool]$Script:FixLabOperationBusy -and $liveSource)}
    if($Script:BtnFixLabDeleteSource){$Script:BtnFixLabDeleteSource.IsEnabled=(-not[bool]$Script:FixLabOperationBusy -and $liveSource)}
    $ignoredNow=@(Get-PMMFixLabIgnoredSourceRecords)
    if($Script:TxtFixLabIgnoredCount){$Script:TxtFixLabIgnoredCount.Text=((L '{0} ignored source(s)' '{0} fuente(s) ignorada(s)') -f $ignoredNow.Count)}
    if($Script:BtnFixLabClearIgnored){$Script:BtnFixLabClearIgnored.IsEnabled=(-not[bool]$Script:FixLabOperationBusy -and $ignoredNow.Count -gt 0)}
    try{Set-PMMFixLabAttentionVisual $attentionCandidates ''}catch{}
    $Script:FixLabLastRefreshUtc=[datetime]::UtcNow
  }finally{$Script:FixLabUiRefreshing=$false}
}

function Update-PMMFixLabVariantSelectionUi {
  param($Variant=$null)
  if(-not$Script:FixLabLoaded){return}
  $candidate=Get-PMMFixLabSelectedCandidate
  if(-not$candidate){return}
  if(-not$Variant -and $Script:CmbFixLabVariant){$Variant=$Script:CmbFixLabVariant.SelectedItem}
  if($Variant){
    $Script:FixLabSelectedVariantId=[string]$Variant.Id
    if($Script:TxtFixLabVariantDescription){$Script:TxtFixLabVariantDescription.Text=[string]$Variant.Description}
    if($Script:TxtFixLabOutputSize){
      $existing=@($Script:FixLabCachedBuilt|Where-Object{[string]$_.RecipeId -ieq [string]$candidate.RecipeId -and [string]$_.VariantId -ieq [string]$Script:FixLabSelectedVariantId}|Select-Object -First 1)
      $Script:TxtFixLabOutputSize.Text=if($existing.Count -gt 0){[string]$existing[0].SizeMb}else{L 'Pending build' 'Pendiente de construir'}
    }
  }else{
    $Script:FixLabSelectedVariantId=''
    if($Script:TxtFixLabVariantDescription){$Script:TxtFixLabVariantDescription.Text=L 'Choose one output. PMM will not choose a cosmetic/behavior variant for you.' 'Elige una salida. PMM no elegira por ti una variante cosmetica/de comportamiento.'}
    if($Script:TxtFixLabOutputSize){$Script:TxtFixLabOutputSize.Text=L 'Pending selection' 'Pendiente de seleccion'}
  }
  $state=Get-PMMFixLabCandidateBuildState $candidate ([string]$Script:FixLabSelectedVariantId)
  $Script:FixLabCachedBuildState=$state
  if($Script:TxtFixLabRepairState){$Script:TxtFixLabRepairState.Text=[string]$state.Reason}
  if($Script:BtnFixLabRepair){$Script:BtnFixLabRepair.IsEnabled=(-not[bool]$Script:FixLabOperationBusy -and [bool]$state.Ready)}
  try{Set-PMMFixLabAttentionVisual @($Script:FixLabCachedAttentionCandidates) ''}catch{}
}

function Update-PMMFixLabCandidateSelectionUi {
  if(-not$Script:FixLabLoaded){return}
  $candidate=Get-PMMFixLabSelectedCandidate
  if(-not$candidate){return}
  $recipe=Get-PMMFixLabRecipe ([string]$candidate.RecipeId)
  if(-not$recipe){return}
  if($Script:TxtFixLabCandidate){$Script:TxtFixLabCandidate.Text=((L 'Selected case: {0}`nDetected source mods: {1}' 'Caso seleccionado: {0}`nMods fuente detectados: {1}') -f [string]$candidate.Name,[string]$candidate.SourceNames)}
  if($Script:TxtFixLabLegacySource){$Script:TxtFixLabLegacySource.Text=[string]$candidate.SourceNames}
  if($Script:TxtFixLabModules){$Script:TxtFixLabModules.Text=((L '{0} repair strategies' '{0} estrategias de reparacion') -f @($recipe.repairStrategies).Count)}
  $rows=[System.Collections.Generic.List[object]]::new()
  foreach($v in @($recipe.variants)){$rows.Add([pscustomobject]@{Id=[string]$v.id;Label=[string]$v.label;Description=[string]$v.description;RuntimeStatus=[string]$v.runtimeStatus;BuildStatus=[string]$v.buildStatus;Display=([string]$v.label+' | '+[string]$v.runtimeStatus)})}
  $previous=[string]$Script:FixLabSelectedVariantId
  $was=[bool]$Script:FixLabUiRefreshing
  $Script:FixLabUiRefreshing=$true
  try{
    $Script:CmbFixLabVariant.ItemsSource=(New-PMMFixLabUiCollection $rows.ToArray())
    if(-not[string]::IsNullOrWhiteSpace($previous)){$Script:CmbFixLabVariant.SelectedValue=$previous}
    elseif($rows.Count -eq 1){$Script:CmbFixLabVariant.SelectedIndex=0}
    else{$Script:CmbFixLabVariant.SelectedIndex=-1}
  }finally{$Script:FixLabUiRefreshing=$was}
  Update-PMMFixLabVariantSelectionUi $Script:CmbFixLabVariant.SelectedItem
}

function Queue-PMMFixLabUiRefresh {
  param([switch]$Force)
  if($Force){$Script:FixLabRefreshForce=$true}
  if($Script:FixLabRefreshQueued){return}
  $Script:FixLabRefreshQueued=$true
  $callback=[System.Action]{
    $Script:FixLabRefreshQueued=$false
    $forceNow=[bool]$Script:FixLabRefreshForce
    $Script:FixLabRefreshForce=$false
    try{
      # Let WPF paint the selected tab/expanded card first. The refresh still
      # runs on the dispatcher because it binds WPF controls, but navigation is
      # no longer blocked inside SelectionChanged or Expander.Expanded.
      if($Script:MainTabs.SelectedItem -ne $Script:TabFixLab -and -not$forceNow){return}
      $stateUpdated=$false
      if(-not$Script:FixLabLoaded){
        $stateUpdated=[bool](Initialize-PMMFixLabFeature)
      }elseif(-not[bool]$Script:FixLabOperationBusy){
        $age=[TimeSpan]::MaxValue
        try{if($Script:FixLabLastRefreshUtc){$age=[datetime]::UtcNow-[datetime]$Script:FixLabLastRefreshUtc}}catch{}
        if($forceNow -or $age.TotalSeconds -ge [double]$Script:FixLabRefreshIntervalSeconds){Refresh-PMMFixLabUI;$stateUpdated=$true}
        else{try{Set-PMMFixLabAttentionVisual @($Script:FixLabCachedAttentionCandidates) ''}catch{}}
      }
      if($stateUpdated){try{Update-PMMGuidedActionState}catch{}}
    }catch{Set-PMMFixLabUnavailable $_.Exception.Message}
  }
  try{[void]$Window.Dispatcher.BeginInvoke([System.Windows.Threading.DispatcherPriority]::ContextIdle,$callback)}
  catch{
    $Script:FixLabRefreshQueued=$false
    $Script:FixLabRefreshForce=$false
    throw
  }
}

function Register-PMMFixLabHandlers {
  if($Script:FixLabHandlersBound){return}
  $Script:FixLabHandlersBound=$true
  $Script:BtnFixLabOpenRoot.Add_Click({try{Initialize-PMMFixLab;Start-Process explorer.exe -ArgumentList ('"'+(Get-PMMPath 'FixLab')+'"')}catch{Handle-UIError $_ (L 'Open Fix Lab folder' 'Abrir carpeta Fix Lab')}})
  if($Script:ExpFixLabAdvanced){$Script:ExpFixLabAdvanced.Add_Expanded({try{Queue-PMMFixLabUiRefresh -Force}catch{}})}
  $refreshAction={try{$Script:TxtStatus.Text=L 'Refreshing Fix Lab after the interface update...' 'Actualizando Fix Lab despues de mostrar la interfaz...';Queue-PMMFixLabUiRefresh -Force}catch{Handle-UIError $_ (L 'Refresh Fix Lab' 'Actualizar Fix Lab')}}
  $Script:BtnFixLabDiscover.Add_Click({try{$Script:FixLabNoticeDismissed=$false;Queue-PMMFixLabUiRefresh -Force}catch{Handle-UIError $_ (L 'Analyze Fixable Mods' 'Analizar mods reparables')}});$Script:BtnFixLabRefreshDashboard.Add_Click($refreshAction)
  $Script:BtnFixLabDismissNotice.Add_Click({$Script:FixLabNoticeDismissed=$true;if($Script:BrdFixLabNotice){$Script:BrdFixLabNotice.Visibility=[System.Windows.Visibility]::Collapsed}})
  $Script:LstFixLabCandidates.Add_SelectionChanged({if($Script:FixLabUiRefreshing){return};try{$c=$Script:LstFixLabCandidates.SelectedItem;if($c){$Script:FixLabSelectedRecipeId=[string]$c.RecipeId;$Script:FixLabSelectedVariantId='';Update-PMMFixLabCandidateSelectionUi}}catch{Handle-UIError $_ (L 'Choose repairable mod' 'Elegir mod reparable')}})
  $Script:CmbFixLabVariant.Add_SelectionChanged({if($Script:FixLabUiRefreshing){return};try{$v=$Script:CmbFixLabVariant.SelectedItem;Update-PMMFixLabVariantSelectionUi $v;try{Update-PMMGuidedActionState}catch{};if($v){if($Script:AutoPipelineActive){Invoke-PMMAutoContinue}elseif([bool]$Script:TglAutoMode.IsChecked){Start-PMMAutoPipeline;Invoke-PMMAutoContinue}}}catch{Handle-UIError $_ (L 'Choose Fix Lab output' 'Elegir salida Fix Lab')}})
  $Script:LstFixLabBuiltFixes.Add_SelectionChanged({if($Script:FixLabUiRefreshing){return};try{$b=$Script:LstFixLabBuiltFixes.SelectedItem;$Script:FixLabSelectedBuildId=if($b){[string]$b.BuildId}else{''};$Script:BtnFixLabApplyBuilt.IsEnabled=(-not[bool]$Script:FixLabOperationBusy -and $b -and -not[bool]$b.Applied -and (Test-PMMFixLabBuiltDeployAllowed $b));Update-PMMFixLabDeployButtonPresentation $b;if($b -and -not(Test-PMMFixLabBuiltDeployAllowed $b)){$Script:TxtStatus.Text=(Get-PMMFixLabBuiltDeploymentNote $b)}}catch{}})
  $Script:LstFixLabBackups.Add_SelectionChanged({if($Script:FixLabUiRefreshing){return};$has=($null -ne $Script:LstFixLabBackups.SelectedItem);$Script:BtnFixLabRevertBackup.IsEnabled=$has;if($Script:BtnFixLabOpenBackupFolder){$Script:BtnFixLabOpenBackupFolder.IsEnabled=$has}})
  $Script:BtnFixLabOpenBackupFolder.Add_Click({
    try{
      $row=$Script:LstFixLabBackups.SelectedItem;if(-not$row){return}
      $folder=Split-Path -Parent ([string]$row.Path)
      if(-not(Test-Path -LiteralPath $folder -PathType Container)){throw (L 'The backup folder no longer exists.' 'La carpeta del backup ya no existe.')}
      Start-Process explorer.exe -ArgumentList ('/select,"'+[string]$row.Path+'"')
    }catch{Handle-UIError $_ (L 'Open Fix Lab backup folder' 'Abrir carpeta de backup Fix Lab')}
  })
  $Script:BtnFixLabIgnoreSource.Add_Click({
    try{
      $candidate=Get-PMMFixLabSelectedCandidate;if(-not$candidate){return}
      $warning=L 'Ignore Fix Lab for this exact legacy source hash? PMM will allow Analyze/AUTO to continue with the unfixed mod under your responsibility. You can clear ignored repairs from Advanced.' 'Ignorar Fix Lab para este hash exacto del mod antiguo? PMM permitira continuar Analyze/AUTO con el mod sin reparar bajo tu responsabilidad. Puedes borrar los ignorados desde Advanced.'
      if((Show-PMMThemedMessage @($warning,(L 'Ignore repair warning' 'Ignorar aviso de reparacion'),'YesNo')) -ne [System.Windows.MessageBoxResult]::Yes){return}
      [void](Ignore-PMMFixLabCandidate $candidate)
      $Script:FixLabSelectedRecipeId='';$Script:FixLabSelectedVariantId='';$Script:FixLabNoticeDismissed=$true
      Refresh-PMMFixLabUI
      $live=@(Get-PMMFixLabDiscoveryCandidates);$Script:FixLabCachedAttentionCandidates=@($live);Set-PMMFixLabAttentionVisual $live ''
      $Script:MainTabs.SelectedItem=$Script:PMMMergeTab
      $Script:TxtStatus.Text=L 'Fix Lab warning ignored for this exact source. Next action: Analyze.' 'Aviso de Fix Lab ignorado para esta fuente exacta. Siguiente accion: Analyze.'
      Close-PMMRequiredActionPopup;$Script:RequiredActionSignature='';Update-PMMGuidedActionState
      if([bool]$Script:TglAutoMode.IsChecked){Start-PMMAutoPipeline;Invoke-PMMAutoContinue}
    }catch{Handle-UIError $_ (L 'Ignore Fix Lab source' 'Ignorar fuente de Fix Lab')}
  })
  $Script:BtnFixLabDeleteSource.Add_Click({
    try{
      $candidate=Get-PMMFixLabSelectedCandidate;if(-not$candidate){return}
      $live=@($candidate.Sources|Where-Object{[string]$_.Origin -eq 'Library'})
      if($live.Count -eq 0){throw (L 'This Fix Lab case currently has only archived backup sources. There is no imported/live legacy mod to delete.' 'Este caso Fix Lab solo tiene fuentes archivadas en backup. No hay ningun mod antiguo importado/en vivo que borrar.')}
      $names=@($live|ForEach-Object{[string]$_.Name}|Sort-Object -Unique)
      $question=if($names.Count -eq 1){
        (L "Delete {0} everywhere? This is the same operation as Imported Mods > Delete: PMM removes the managed library copy and the exact matching PAK from Palworld ~mods. Any deployed compatibility merge is preserved until you explicitly change it in Mods & Merge." "Borrar {0} de todas partes? Es la misma operacion que Imported Mods > Delete: PMM elimina la copia gestionada de la biblioteca y el PAK exacto de ~mods de Palworld. Cualquier merge de compatibilidad desplegado se conserva hasta que lo cambies explicitamente en Mods & Merge.") -f $names[0]
      }else{
        (L "Delete these {0} Fix Lab source mods everywhere? PMM will use the same transactional Delete operation as Imported Mods." "Borrar de todas partes estos {0} mods fuente de Fix Lab? PMM usara la misma operacion transaccional Delete que Imported Mods.") -f $names.Count
      }
      if(-not(Confirm $question)){return}
      $results=[System.Collections.Generic.List[object]]::new()
      foreach($name in $names){$results.Add((Remove-PMMLibraryMod $name))}
      $Script:FixLabSelectedRecipeId='';$Script:FixLabSelectedVariantId='';$Script:FixLabNoticeDismissed=$true
      Refresh-UI
      try{Check-PMMExternalModChanges -Force}catch{}
      try{Refresh-PMMFixLabUI;Update-PMMFixLabAttentionFromLibrary 'Delete'}catch{}
      try{Close-PMMRequiredActionPopup;$Script:RequiredActionSignature='';Update-PMMGuidedActionState}catch{}
      $gameRemoved=@($results.ToArray()|Where-Object{[bool]$_.DeletedFromGame}).Count
      $Script:TxtStatus.Text=((L 'Deleted {0} Fix Lab source mod(s) from PMM and removed {1} exact matching PAK(s) from Palworld ~mods.' 'Borrados {0} mod(s) fuente de Fix Lab de PMM y eliminados {1} PAK(s) exactos correspondientes de ~mods de Palworld.') -f $results.Count,$gameRemoved)
      if($Script:AutoPipelineActive){Invoke-PMMAutoContinue}elseif([bool]$Script:TglAutoMode.IsChecked){Start-PMMAutoPipeline;Invoke-PMMAutoContinue}
    }catch{Handle-UIError $_ (L 'Delete Fix Lab source mod' 'Borrar mod fuente de Fix Lab')}
  })
  $Script:BtnFixLabClearIgnored.Add_Click({
    try{
      Clear-PMMFixLabIgnoredSources
      $Script:FixLabNoticeDismissed=$false
      Refresh-PMMFixLabUI;Update-PMMFixLabAttentionFromLibrary ''
      $Script:TxtStatus.Text=L 'Ignored Fix Lab repair warnings cleared.' 'Avisos ignorados de Fix Lab borrados.'
      Update-PMMGuidedActionState
    }catch{Handle-UIError $_ (L 'Clear ignored Fix Lab repairs' 'Borrar reparaciones ignoradas de Fix Lab')}
  })
  $Script:BtnFixLabBuildReference.Add_Click({try{$args=[System.Windows.RoutedEventArgs]::new([System.Windows.Controls.Button]::ClickEvent);$Script:BtnBuildGameReference.RaiseEvent($args)}catch{Handle-UIError $_ (L 'Build Game Reference' 'Crear Game Reference')}})
  $Script:BtnFixLabOpenReference.Add_Click({try{$p=Get-PMMGameReferenceRoot;if(-not(Test-Path -LiteralPath $p -PathType Container)){New-Item -ItemType Directory -Force -Path $p|Out-Null};Start-Process explorer.exe -ArgumentList ('"'+$p+'"')}catch{Handle-UIError $_ (L 'Open Game Reference' 'Abrir Game Reference')}})
  $Script:BtnFixLabRepair.Add_Click({
    try{
      $candidate=Get-PMMFixLabSelectedCandidate;if(-not$candidate){throw(L 'Select a repairable mod case first.' 'Selecciona primero un caso reparable.')}
      $variant=[string]$Script:FixLabSelectedVariantId;if([string]::IsNullOrWhiteSpace($variant)){throw(L 'Choose an output variant first.' 'Elige primero una variante de salida.')}
      # Do not perform Game Reference hashing or recipe preflight on the WPF
      # thread. The processing worker is authoritative and validates all of it.
      # The UI only captures stable identities and returns to the dispatcher.

      # The UI passes only stable identities. Job creation, exact source
      # snapshot/analyze, expansion, native execution, packing and readback all
      # run in the shared worker so even a first-time large case cannot block WPF.
      $recipeId=[string]$candidate.RecipeId
      $Script:TxtFixLabRepairState.Text=L 'Starting the Fix Lab processing worker...' 'Iniciando el worker de procesamiento Fix Lab...'
      # The click handler does not parse recipes, inspect source PAKs or touch
      # Game Reference. The discovery row already carries the stable case id;
      # the child processing worker revalidates everything authoritatively.
      $caseId=if($candidate.PSObject.Properties.Name -contains 'CaseId' -and -not[string]::IsNullOrWhiteSpace([string]$candidate.CaseId)){[string]$candidate.CaseId}else{$recipeId}
      $expectedBuildId=$caseId+'__'+$variant

      $done={
        param($result)
        # The worker result is authoritative. A later WPF refresh/selection
        # warning must never relabel a validated build as Failed.
        $Script:FixLabSelectedBuildId=if($result -and -not[string]::IsNullOrWhiteSpace([string]$result.BuildId)){[string]$result.BuildId}else{$expectedBuildId}
        $uiWarning=''
        try{
          Refresh-PMMFixLabUI
          $built=@(Get-PMMFixLabBuiltOutputs|Where-Object{[string]$_.BuildId -ieq [string]$Script:FixLabSelectedBuildId}|Select-Object -First 1)
          if($built.Count -gt 0){
            $builtControl=$Window.FindName('LstFixLabBuiltFixes')
            if($builtControl -is [System.Windows.Controls.Primitives.Selector]){
              $builtControl.SelectedValue=[string]$built[0].BuildId
              $Script:FixLabSelectedBuildId=[string]$built[0].BuildId
            }
          }
        }catch{
          $uiWarning=$_.Exception.Message
          Write-PMMLog ("Fix Lab build succeeded, but its UI refresh/selection raised a warning: {0}`n{1}" -f $uiWarning,$_.ScriptStackTrace)
        }
        try{
          $validation=if($result){[string]$result.Validation}else{''}
          $out=if($result){[string]$result.OutputPath}else{''}
          if($Script:TxtFixLabResult){$Script:TxtFixLabResult.Text=((L 'Repair built in the processing engine: {0}`n{1}' 'Fix construido en el motor de procesamiento: {0}`n{1}') -f $out,$validation)}
          if(-not[string]::IsNullOrWhiteSpace($uiWarning)){$Script:TxtStatus.Text=((L 'Repair built successfully. UI refresh warning: {0}' 'La reparacion se construyo correctamente. Aviso al actualizar la interfaz: {0}') -f $uiWarning)}
          Update-PMMGuidedActionState
        }catch{Write-PMMLog ("Post-build UI continuation warning: {0}`n{1}" -f $_.Exception.Message,$_.ScriptStackTrace)}
      }.GetNewClosure()
      $failed={
        param($message)
        try{
          Refresh-PMMFixLabUI
          $Script:TxtFixLabRepairState.Text=((L 'Fix Lab repair failed: {0}' 'La reparacion Fix Lab fallo: {0}') -f $message)
          Stop-PMMAutoPipeline
        }catch{}
      }.GetNewClosure()
      [void](Start-PMMBackgroundOperation -Operation FixLabBuild -FixLabRecipeId $recipeId -FixLabVariantId $variant -OnSuccess $done -OnFailure $failed)
    }catch{Handle-UIError $_ (L 'Repair mod' 'Reparar mod');try{Refresh-PMMFixLabUI}catch{}}
  })
  $Script:BtnFixLabApplyBuilt.Add_Click({
    try{
      if(-not(Request-PMMProcessingSlot 'DeployFix')){return}
      $built=$Script:LstFixLabBuiltFixes.SelectedItem;if(-not$built){return}
      if(($built.PSObject.Properties.Name -contains 'Applied') -and [bool]$built.Applied){$Script:TxtStatus.Text=L 'This Fix Lab output is already applied. Next action: Analyze.' 'Esta salida de Fix Lab ya esta aplicada. Siguiente accion: Analyze.';Update-PMMGuidedActionState;return}
      if(-not(Test-PMMFixLabBuiltDeployAllowed $built)){
        $note=Get-PMMFixLabBuiltDeploymentNote $built
        if([string]::IsNullOrWhiteSpace($note)){$note=L 'This Fix Lab output is an engine-validation milestone and cannot be deployed.' 'Esta salida de Fix Lab es un hito de validacion del motor y no se puede desplegar.'}
        $Script:TxtStatus.Text=$note
        try{$Script:TxtOperationProgress.Text=$note}catch{}
        Write-PMMLog ('Fix Lab non-deployable output: '+$note)
        return
      }
      $Script:FixLabOperationBusy=$true
      $Script:BtnFixLabApplyBuilt.IsEnabled=$false
      $Script:TxtStatus.Text=L 'Deploying repaired mod and archiving the legacy source. The deployed compatibility merge will be preserved...' 'Desplegando el mod reparado y archivando la fuente antigua. El merge de compatibilidad desplegado se conservara...'
      Update-PMMCancelButtonState
      try{[System.Windows.Forms.Application]::DoEvents()}catch{}
      $result=Deploy-PMMFixLabBuiltOutput $built
      $Script:TxtStatus.Text=((L 'Fix deployed: {0}. Legacy source archived. Next action: Analyze the new mod list.' 'Fix desplegado: {0}. Fuente antigua archivada. Siguiente accion: analizar la nueva lista de mods.') -f [string]$result.Name)
      Refresh-UI;Check-PMMExternalModChanges -Force;Refresh-PMMFixLabUI
      $live=@(Get-PMMFixLabDiscoveryCandidates);$Script:FixLabCachedAttentionCandidates=@($live);$Script:FixLabNoticeDismissed=$true
      try{Set-PMMFixLabAttentionVisual $live ''}catch{}
      Close-PMMRequiredActionPopup;$Script:RequiredActionSignature=''
      $Script:MainTabs.SelectedItem=$Script:PMMMergeTab
      Update-PMMGuidedActionState
      Notify-PMMWorkflowStepComplete
    }catch{if(Test-PMMCancellationError $_){Set-PMMOperationResult 'FixLab' (L 'Apply Fix cancelled. Transaction rolled back.' 'Aplicar Fix cancelado. La transaccion se revirtio.');Stop-PMMAutoPipeline}else{Handle-UIError $_ (L 'Apply Fix' 'Aplicar Fix')}}
    finally{
      $Script:FixLabOperationBusy=$false;Update-PMMCancelButtonState;try{Update-PMMGuidedActionState}catch{}
      if($Script:AutoPipelineActive){try{Invoke-PMMAutoContinue}catch{Write-PMMLog ('AUTO continuation after Apply Fix failed: '+$_.Exception.Message)}}
    }
  })
  $Script:BtnFixLabRevertBackup.Add_Click({
    try{
      $row=$Script:LstFixLabBackups.SelectedItem;if(-not$row){return}
      $answer=Show-PMMThemedMessage @((L 'Restore the original legacy mod? PMM will remove/archive the applied repair and restore the original source to both the PMM library and Palworld ~mods. The deployed compatibility merge will not be changed.' 'Restaurar el mod antiguo original? PMM retirara/archivara el fix aplicado y restaurara la fuente original tanto en la biblioteca PMM como en ~mods de Palworld. El merge de compatibilidad desplegado no se modificara.'),(L 'Restore original mod' 'Restaurar mod original'),'YesNo')
      if($answer -ne [System.Windows.MessageBoxResult]::Yes){return}
      [void](Restore-PMMFixLabCase ([string]$row.CaseId))
      Refresh-UI;Check-PMMExternalModChanges -Force;Refresh-PMMFixLabUI
      $Script:TxtStatus.Text=L 'Original legacy mod restored to the PMM library and Palworld ~mods. Fix Lab will warn again unless you choose Ignore this legacy mod.' 'Mod antiguo original restaurado en la biblioteca PMM y en ~mods de Palworld. Fix Lab volvera a avisar salvo que elijas Ignorar este mod antiguo.'
      Update-PMMGuidedActionState
    }catch{Handle-UIError $_ (L 'Restore original mod' 'Restaurar mod original')}
  })
  $Script:BtnFixLabCreateHandoff.Content=L 'Open repair case' 'Abrir caso de reparacion'
  $Script:BtnFixLabCreateHandoff.Add_Click({
    try{
      $candidate=Get-PMMFixLabSelectedCandidate
      if(-not$candidate){throw (L 'Select a repairable mod first.' 'Selecciona primero un mod reparable.')}
      $case=Get-OrCreate-PMMOriginCase -Origin FixLab -SourceId ([string]$candidate.CaseId) -Type FIX_MOD -Title ([string]$candidate.Name) -Description ([string]$candidate.Description) -Mods @($candidate.Sources) -Context ([ordered]@{RecipeId=$candidate.RecipeId;VariantId=[string]$Script:FixLabSelectedVariantId})
      Select-PMMCaseLocation $case
    }catch{Handle-UIError $_ (L 'Open repair case' 'Abrir caso de reparacion')}
  })
  $Script:BtnFixLabOpenOutput.Add_Click({try{$job=Get-PMMFixLabCurrentJob;if(-not$job){return};$p=Join-Path (Get-PMMFixLabJobPath ([string]$job.JobId)) 'Output';if(-not(Test-Path -LiteralPath $p -PathType Container)){New-Item -ItemType Directory -Force -Path $p|Out-Null};Start-Process explorer.exe -ArgumentList ('"'+$p+'"')}catch{Handle-UIError $_ (L 'Open Fix Lab output' 'Abrir output Fix Lab')}})
}

function Initialize-PMMFixLabFeature {
  if($Script:FixLabLoaded){return $true}
  if($Script:FixLabLoadAttempted){return $false}
  $Script:FixLabLoadAttempted=$true
  Set-PMMFixLabControlsEnabled $false
  $Script:TxtFixLabAnalysis.Text=L 'Loading Fix Lab module...' 'Cargando modulo Fix Lab...'
  try{
    $service=Join-Path $Script:Root 'Modules\FixLab\FixLabService.ps1'
    if(-not(Test-Path -LiteralPath $service -PathType Leaf)){throw 'Modules/FixLab/FixLabService.ps1 is missing.'}
    . $service
    foreach($fn in @('Initialize-PMMFixLab','Get-PMMFixLabRecipes','Get-PMMFixLabJobs','Get-PMMFixLabLibrarySources','Invoke-PMMFixLabAnalyze','Get-PMMFixLabDiscoveryCandidates','Get-PMMFixLabBuiltOutputs','Get-PMMFixLabBackups','Apply-PMMFixLabBuiltOutput','Ignore-PMMFixLabCandidate','Get-PMMFixLabIgnoredSourceRecords')){if(-not(Get-Command $fn -ErrorAction SilentlyContinue)){throw ('Fix Lab function missing after load: '+$fn)}}
    Initialize-PMMFixLab
    $Script:FixLabLoaded=$true
    Register-PMMFixLabHandlers
    Refresh-PMMFixLabUI
    Write-PMMLog 'Fix Lab loaded lazily after the user opened its tab.'
    return $true
  }catch{
    $msg=$_.Exception.Message
    Write-PMMLog ('Fix Lab lazy-load failure (PMM remains usable): '+$msg)
    Set-PMMFixLabUnavailable $msg
    return $false
  }
}