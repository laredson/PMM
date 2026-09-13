# Preserved 1.3.2 definitions; extracted for 1.3.3.
function New-PMMTextColumn([string]$Header,[string]$Property,[double]$Width,[bool]$ReadOnly=$true) {
  $column = New-Object System.Windows.Controls.DataGridTextColumn
  $column.Header = $Header
  $column.Width = $Width
  $column.IsReadOnly = $ReadOnly
  $binding = New-Object System.Windows.Data.Binding -ArgumentList $Property
  if (-not $ReadOnly) {
    $binding.Mode = [System.Windows.Data.BindingMode]::TwoWay
    $binding.UpdateSourceTrigger = [System.Windows.Data.UpdateSourceTrigger]::PropertyChanged
  }
  $column.Binding = $binding
  return $column
}

function Configure-ConflictColumns([array]$ModNames) {
  <#
  Columns are dynamic because a shared asset may involve 2, 3 or more mods.

  IMPORTANT: Source choice uses a DataGridTemplateColumn with an always-live ComboBox.
  Previous previews used DataGridComboBoxColumn, whose edit lifecycle could
  close the popup while WPF committed a cell.  The template ComboBox is not
  tied to DataGrid edit mode, so it remains open until the user chooses/closes.
  #>
  $Script:DgDecisions.Columns.Clear()
  [void]$Script:DgDecisions.Columns.Add((New-PMMTextColumn (L 'Parameter' 'Parametro') 'DisplayProperty' 360 $true))
  [void]$Script:DgDecisions.Columns.Add((New-PMMTextColumn 'Vanilla' 'VanillaDisplay' 190 $true))

  $index = 0
  foreach ($modName in @($ModNames)) {
    $index++
    [void]$Script:DgDecisions.Columns.Add((New-PMMTextColumn $modName ("ModValue{0}" -f $index) 190 $true))
  }

  $winner = New-Object System.Windows.Controls.DataGridTemplateColumn
  $winner.Header = L 'Use value from' 'Usar valor de'
  $winner.Width = 200

  $template = New-Object System.Windows.DataTemplate
  $comboFactory = New-Object System.Windows.FrameworkElementFactory([System.Windows.Controls.ComboBox])
  $itemsBinding = New-Object System.Windows.Data.Binding -ArgumentList 'WinnerChoices'
  $comboFactory.SetBinding([System.Windows.Controls.ItemsControl]::ItemsSourceProperty,$itemsBinding)
  $selectedBinding = New-Object System.Windows.Data.Binding -ArgumentList 'SelectedChoice'
  $selectedBinding.Mode = [System.Windows.Data.BindingMode]::TwoWay
  $selectedBinding.UpdateSourceTrigger = [System.Windows.Data.UpdateSourceTrigger]::PropertyChanged
  $comboFactory.SetBinding([System.Windows.Controls.Primitives.Selector]::SelectedItemProperty,$selectedBinding)
  $comboFactory.SetValue([System.Windows.Controls.Control]::MinWidthProperty,[double]165)
  $comboFactory.SetValue([System.Windows.FrameworkElement]::HeightProperty,[double]30)
  $comboFactory.SetValue([System.Windows.Controls.Control]::FontSizeProperty,[double]13)
  $comboFactory.SetValue([System.Windows.Controls.Control]::PaddingProperty,[System.Windows.Thickness]::new(7,2,7,2))
  $comboFactory.SetValue([System.Windows.Controls.Control]::VerticalContentAlignmentProperty,[System.Windows.VerticalAlignment]::Center)
  $comboFactory.SetValue([System.Windows.Controls.Control]::HorizontalContentAlignmentProperty,[System.Windows.HorizontalAlignment]::Stretch)
  $template.VisualTree = $comboFactory
  $winner.CellTemplate = $template
  $winner.CellEditingTemplate = $template
  [void]$Script:DgDecisions.Columns.Add($winner)
  [void]$Script:DgDecisions.Columns.Add((New-PMMTextColumn (L 'Custom value' 'Valor custom') 'CustomValue' 120 $false))

  [void]$Script:DgDecisions.Columns.Add((New-PMMTextColumn (L 'Status' 'Estado') 'Status' 125 $true))
}

function Save-DecisionGridToPlan {
  param([switch]$Silent)

  if ($Script:LoadingConflictView) { return }
  try {
    [void]$Script:DgDecisions.CommitEdit([System.Windows.Controls.DataGridEditingUnit]::Cell,$true)
    [void]$Script:DgDecisions.CommitEdit([System.Windows.Controls.DataGridEditingUnit]::Row,$true)
    $rows = @()
    if ($null -ne $Script:DgDecisions.ItemsSource) { $rows = @($Script:DgDecisions.ItemsSource) }
    if ($rows.Count -gt 0) { Save-PMMDecisionRows $rows }
  } catch {
    if (-not $Silent) { throw }
    Write-PMMLog ("Background decision save failed: {0}" -f $_.Exception.Message)
  }
}

function Show-SelectedConflictAsset {
  param($AssetSummary)

  $Script:LoadingConflictView = $true
  try {
    if (-not $AssetSummary) {
      $Script:CurrentConflictAssetKey = ''
$Script:LastConflictPlanCreated = ''
$Script:CurrentUnsupportedAssetKey = ''
      $Script:TxtConflictMods.Text = L 'No true overlapping-change decisions.' 'No hay decisiones de cambios solapados.'
      $Script:TxtConflictAsset.Text = ''
      $Script:CmbBulkWinner.ItemsSource = @()
      $Script:TxtBulkCustom.Text = ''
      $Script:BtnOpenReview.IsEnabled = $false
      $Script:BtnOpenReview.Tag = $null
      $Script:DgDecisions.ItemsSource = @()
      $Script:DgDecisions.Columns.Clear()
      return
    }

    $assetKey = [string]$AssetSummary.AssetKey
    $Script:CurrentConflictAssetKey = $assetKey
    $modNames = @($AssetSummary.ConflictMods)
    $allProviders=@($AssetSummary.Providers)
    $compatibleProviders=@($allProviders|Where-Object{[string]$_ -notin $modNames})
    $isPackageChoice=(($AssetSummary.PSObject.Properties.Name -contains 'Mode') -and [string]$AssetSummary.Mode -eq 'PackageChoice')
    if($isPackageChoice){
      $conflictText=(L 'Alternative package components detected: ' 'Componentes alternativos de paquete detectados: ') + ($modNames -join '  <->  ')
    }else{
      $conflictText=(L 'Competing mods for this parameter: ' 'Mods que compiten por este parametro: ') + ($modNames -join '  <->  ')
      if($compatibleProviders.Count -gt 0){
        $conflictText += "`n" + (L 'Other changes in this same file are still merged automatically: ' 'Los demas cambios de este mismo archivo se fusionan automaticamente: ') + ($compatibleProviders -join ', ')
      }
    }
    $Script:TxtConflictMods.Text=$conflictText
    $reason = if ($AssetSummary.PSObject.Properties['Reason']) { [string]$AssetSummary.Reason } else { '' }
    $prefix=if($isPackageChoice){L 'Package: ' 'Paquete: '}else{L 'File: ' 'Archivo: '}
    $Script:TxtConflictAsset.Text = ($prefix + [string]$AssetSummary.Asset + $(if($reason){"`n" + (L 'Reason: ' 'Motivo: ') + $reason}else{''}))

    Configure-ConflictColumns $modNames

    $Script:CmbBulkWinner.ItemsSource = @()
    $Script:TxtBulkCustom.Text = ''
    $reviewFolder = if ($AssetSummary.PSObject.Properties['ReviewFolder']) { [string]$AssetSummary.ReviewFolder } else { '' }
    $Script:BtnOpenReview.Tag = $reviewFolder
    $Script:BtnOpenReview.IsEnabled = (-not [string]::IsNullOrWhiteSpace($reviewFolder)) -and (Test-Path -LiteralPath $reviewFolder -PathType Container)

    $planRows = @(Get-PMMDecisionRows | Where-Object { [string]$_.AssetKey -eq $assetKey })
    if ($planRows.Count -gt 0) {
      $bulk = @($planRows[0].Choices)
      foreach ($other in @($planRows | Select-Object -Skip 1)) { $bulk = @($bulk | Where-Object { $_ -in @($other.Choices) }) }
      $Script:CmbBulkWinner.ItemsSource = $bulk
      if ($bulk.Count -gt 0) { $Script:CmbBulkWinner.SelectedIndex = 0 }
    }
    $viewRows = New-Object System.Collections.Generic.List[object]
    foreach ($row in $planRows) {
      $properties = [ordered]@{
        DecisionId = [string]$row.DecisionId
        AssetKey = [string]$row.AssetKey
        DisplayProperty = [string]$row.DisplayProperty
        VanillaJson = [string]$row.VanillaJson
        VanillaDisplay = ConvertTo-PMMDisplayValue ([string]$row.VanillaJson)
        SelectedChoice = [string]$row.SelectedChoice
        WinnerChoices = @($row.Choices)
        CustomValue = [string]$row.CustomValue
        ResolutionOrigin = $(if($row.PSObject.Properties.Name -contains 'ResolutionOrigin'){[string]$row.ResolutionOrigin}else{'Manual'})
        Status = $(if ([string]::IsNullOrWhiteSpace([string]$row.SelectedChoice) -or ([string]$row.SelectedChoice -eq 'Custom' -and [string]::IsNullOrWhiteSpace([string]$row.CustomValue))) { L 'Decision required' 'Decision requerida' } elseif(($row.PSObject.Properties.Name -contains 'ResolutionOrigin') -and [string]$row.ResolutionOrigin -eq 'Priority') { L 'Resolved by priority' 'Resuelto por prioridad' } else { L 'Resolved' 'Resuelto' })
      }

      $i = 0
      foreach ($modName in $modNames) {
        $i++
        $value = Get-OptionJson $row.Options $modName
        if ($null -eq $value) { $value = '-' }
        $properties[("ModValue{0}" -f $i)] = ConvertTo-PMMDisplayValue ([string]$value)
      }
      $viewRows.Add([pscustomobject]$properties)
    }
    $Script:DgDecisions.ItemsSource = $viewRows.ToArray()
  } finally {
    $Script:LoadingConflictView = $false
  }
}

function Get-PMMUnsupportedDisableRanking($UnsupportedAsset) {
  if(-not$UnsupportedAsset){return @()}
  $plan=Read-PMMMergePlan
  if(-not$plan){return @()}
  $providers=@($UnsupportedAsset.Providers|ForEach-Object{[string]$_}|Where-Object{$_}|Sort-Object -Unique)
  $rank=[System.Collections.Generic.List[object]]::new()
  foreach($provider in $providers){
    $otherCompatible=@($plan.Assets|Where-Object{
      [string]$_.AssetKey -ne [string]$UnsupportedAsset.AssetKey -and
      [string]$_.Mode -notin @('Unsupported','Identical') -and
      [string]$provider -in @($_.Providers|ForEach-Object{[string]$_})
    }).Count
    $otherShared=@($plan.Assets|Where-Object{
      [string]$_.AssetKey -ne [string]$UnsupportedAsset.AssetKey -and
      [string]$provider -in @($_.Providers|ForEach-Object{[string]$_})
    }).Count
    $rank.Add([pscustomobject]@{Name=$provider;CompatibleImpact=$otherCompatible;SharedImpact=$otherShared})
  }
  return @($rank|Sort-Object CompatibleImpact,SharedImpact,Name)
}

function Show-SelectedUnsupportedAsset {
  $item=$Script:LstUnsupportedAssets.SelectedItem
  $Script:CmbUnsupportedDisable.Items.Clear()
  $Script:BtnDisableUnsupported.IsEnabled=$false
  $Script:BtnOpenAIHandoff.IsEnabled=$false;$Script:BtnOpenAIHandoff.Tag=$null
  $Script:BtnImportManualSolution.IsEnabled=$false;$Script:BtnImportManualSolution.Tag=$null
  if(-not$item){
    $Script:CurrentUnsupportedAssetKey=''
    $Script:TxtUnsupported.Text=L 'None.' 'Ninguno.'
    $Script:TxtUnsupportedHint.Text=L 'No unsupported shared asset is selected.' 'No hay ningun asset compartido no soportado seleccionado.'
    return
  }
  $Script:CurrentUnsupportedAssetKey=[string]$item.AssetKey
  $Script:TxtUnsupported.Text=("{0}`n{1}" -f [string]$item.Asset,[string]$item.Reason)
  $Script:BtnOpenAIHandoff.Content=L 'OPEN CASE' 'ABRIR CASO'
  $Script:BtnOpenAIHandoff.IsEnabled=$true
  $Script:BtnOpenAIHandoff.Tag=[string]$item.AssetKey
  $Script:BtnImportManualSolution.Tag=[string]$item.ReviewFolder
  $Script:BtnImportManualSolution.IsEnabled=([IO.Path]::GetExtension([string]$item.Asset) -ieq '.uasset' -and -not[string]::IsNullOrWhiteSpace([string]$item.ReviewFolder) -and (Test-Path -LiteralPath (Join-Path ([string]$item.ReviewFolder) 'case.json') -PathType Leaf))
  $ranking=@(Get-PMMUnsupportedDisableRanking $item)
  foreach($r in $ranking){[void]$Script:CmbUnsupportedDisable.Items.Add([string]$r.Name)}
  if($ranking.Count -gt 0){
    $Script:CmbUnsupportedDisable.SelectedIndex=0
    $Script:BtnDisableUnsupported.IsEnabled=$true
    $min=[int]$ranking[0].CompatibleImpact
    $ties=@($ranking|Where-Object{[int]$_.CompatibleImpact -eq $min})
    if($ties.Count -eq 1 -and $ranking.Count -gt 1){
      $Script:TxtUnsupportedHint.Text=((L 'Suggested: disable {0}. It participates in {1} other mergeable shared asset(s), the smallest impact among these providers. This does not predict gameplay preference.' 'Sugerencia: desactiva {0}. Participa en {1} otro(s) asset(s) compartido(s) fusionables, el menor impacto entre estos providers. Esto no predice una preferencia de gameplay.') -f [string]$ranking[0].Name,$min)
    }else{
      $Script:TxtUnsupportedHint.Text=L 'Choose which provider to disable. PMM cannot infer gameplay preference when the structural impact is tied.' 'Elige que provider desactivar. PMM no puede inferir una preferencia de gameplay cuando el impacto estructural esta empatado.'
    }
  }
}

function Refresh-ConflictWorkspace {
  param([string]$PreferAssetKey='')

  Save-DecisionGridToPlan -Silent
  $Script:LoadingConflictView = $true
  try {
    $plan=$null
    $assets=@()
    $unsupported=@()
    if(Test-PMMMergePlanCurrent){
      $plan=Read-PMMMergePlan
      $assets=@(Get-PMMConflictAssets)
      $unsupported=@(Get-PMMUnsupportedAssets)
    }

    $Script:LstConflictAssets.Items.Clear()
    foreach($asset in $assets){[void]$Script:LstConflictAssets.Items.Add($asset)}

    $unresolved=0
    if($plan){$unresolved=@($plan.Rows|Where-Object{-not(Test-PMMDecisionRowResolved $_)}).Count}
    if($assets.Count -eq 0){
      $Script:TxtConflictHeader.Text=L 'Resolution & Review (0)' 'Resolucion y revision (0)'
      $Script:TxtConflictHeader.Foreground=$Window.Resources['PrimaryText']
      $Script:ExpConflicts.IsExpanded=$false
    }elseif($unresolved -gt 0){
      $Script:TxtConflictHeader.Text=((L 'Resolution & Review ({0}) - DECISION REQUIRED' 'Resolucion y revision ({0}) - SE NECESITA DECISION') -f $assets.Count)
      $Script:TxtConflictHeader.Foreground=$Window.Resources['AccentHeadingAmber']
      $created=if($plan -and ($plan.PSObject.Properties.Name -contains 'Created')){[string]$plan.Created}else{''}
      if($created -ne $Script:LastConflictPlanCreated -and $unsupported.Count -eq 0){$Script:ExpConflicts.IsExpanded=$true}
      $Script:LastConflictPlanCreated=$created
    }else{
      $Script:TxtConflictHeader.Text=((L 'Resolution & Review ({0}) - resolved' 'Resolucion y revision ({0}) - resuelto') -f $assets.Count)
      $Script:TxtConflictHeader.Foreground=$Window.Resources['AccentHeadingGreen']
    }

    $Script:LstUnsupportedAssets.Items.Clear()
    foreach($asset in $unsupported){
      [void]$Script:LstUnsupportedAssets.Items.Add([pscustomobject]@{
        AssetKey=[string]$asset.AssetKey;Asset=[string]$asset.Asset;Providers=@($asset.Providers);Reason=[string]$asset.Reason;
        ReviewFolder=$(if($asset.PSObject.Properties.Name -contains 'ReviewFolder'){[string]$asset.ReviewFolder}else{''});
        AIHandoff=$(if($asset.PSObject.Properties.Name -contains 'AIHandoff'){[string]$asset.AIHandoff}else{''});
        CaseId=$(if($asset.PSObject.Properties.Name -contains 'CaseId'){[string]$asset.CaseId}else{''});
        Display=(("{0}  -  {1}" -f [IO.Path]::GetFileName([string]$asset.Asset),(@($asset.Providers)-join ', ')))
      })
    }
    if($unsupported.Count -eq 0){
      $Script:ExpUnsupported.Header=L 'Blocked shared assets (0)' 'Assets compartidos bloqueados (0)'
      $Script:ExpUnsupported.IsExpanded=$false
      $Script:TxtUnsupported.Text=L 'None.' 'Ninguno.'
    }else{
      $Script:ExpUnsupported.Header=((L 'Blocked shared assets ({0}) - Build/Deploy blocked' 'Assets compartidos bloqueados ({0}) - Build/Deploy bloqueados') -f $unsupported.Count)
      $Script:ExpUnsupported.IsExpanded=$true
      $wantedUnsupported=$Script:CurrentUnsupportedAssetKey
      $selectedUnsupported=$null
      if($wantedUnsupported){$selectedUnsupported=@($Script:LstUnsupportedAssets.Items|Where-Object{[string]$_.AssetKey -eq $wantedUnsupported}|Select-Object -First 1)[0]}
      if(-not$selectedUnsupported -and $Script:LstUnsupportedAssets.Items.Count -gt 0){$selectedUnsupported=$Script:LstUnsupportedAssets.Items[0]}
      if($selectedUnsupported){$Script:LstUnsupportedAssets.SelectedItem=$selectedUnsupported}
    }

    $selected=$null
    $wanted=if($PreferAssetKey){$PreferAssetKey}else{$Script:CurrentConflictAssetKey}
    if($wanted){foreach($item in $assets){if([string]$item.AssetKey -eq $wanted){$selected=$item;break}}}
    if(-not$selected -and $assets.Count -gt 0){$selected=$assets[0]}
    if($selected){$Script:LstConflictAssets.SelectedItem=$selected}
  } finally {
    $Script:LoadingConflictView=$false
  }

  Show-SelectedConflictAsset $Script:LstConflictAssets.SelectedItem
  Show-SelectedUnsupportedAsset
  Update-BuildButtonState
  Update-PMMGuidedActionState
}

function Get-PMMUiAncestor($Source,[Type]$TargetType) {
  $current=$Source
  while($null -ne $current){
    if($TargetType.IsInstanceOfType($current)){return $current}
    $next=$null
    try{
      if($current -is [System.Windows.DependencyObject]){$next=[System.Windows.Media.VisualTreeHelper]::GetParent($current)}
    }catch{$next=$null}
    if(-not$next){
      try{
        if($current -is [System.Windows.FrameworkElement]){$next=$current.Parent}
        elseif($current -is [System.Windows.FrameworkContentElement]){$next=$current.Parent}
      }catch{$next=$null}
    }
    if(-not$next -and $current -is [System.Windows.DependencyObject]){
      try{$next=[System.Windows.LogicalTreeHelper]::GetParent($current)}catch{$next=$null}
    }
    $current=$next
  }
  return $null
}

function Get-PMMUiDescendant($Root,[Type]$TargetType) {
  if(-not$Root){return $null}
  $count=0
  try{$count=[System.Windows.Media.VisualTreeHelper]::GetChildrenCount($Root)}catch{return $null}
  for($i=0;$i -lt $count;$i++){
    $child=[System.Windows.Media.VisualTreeHelper]::GetChild($Root,$i)
    if($TargetType.IsInstanceOfType($child)){return $child}
    $found=Get-PMMUiDescendant $child $TargetType
    if($found){return $found}
  }
  return $null
}

function Test-PMMPriorityDragInteractiveSource($Source) {
  foreach($type in @(
    [System.Windows.Controls.TextBox],
    [System.Windows.Controls.CheckBox],
    [System.Windows.Controls.ComboBox],
    [System.Windows.Controls.Primitives.ButtonBase],
    [System.Windows.Controls.Primitives.ScrollBar]
  )){
    if(Get-PMMUiAncestor $Source $type){return $true}
  }
  return $false
}

function Refresh-PMMLibraryAfterPriorityChange([string]$Name) {
  Refresh-UI
  $selected=@($Script:LstMods.ItemsSource|Where-Object{[string]$_.Name -ieq $Name}|Select-Object -First 1)
  if($selected.Count -gt 0){
    $Script:LstMods.SelectedItem=$selected[0]
    $Script:LstMods.ScrollIntoView($selected[0])
  }
}

function Invoke-PMMPriorityEditorCommit([System.Windows.Controls.TextBox]$Editor) {
  if(-not$Editor -or $Script:PriorityEditorCommitInProgress){return $false}
  $name=[string]$Editor.Tag
  if([string]::IsNullOrWhiteSpace($name)){return $false}

  [long]$requested=0
  $raw=([string]$Editor.Text).Trim()
  if(-not[long]::TryParse($raw,[ref]$requested)){
    $map=Get-PMMModPriorityMap
    if($map.ContainsKey($name)){$Editor.Text=[string]$map[$name]}
    $Script:TxtStatus.Text=L 'Order must be a whole number. The previous position was kept.' 'Orden debe ser un numero entero. Se mantuvo la posicion anterior.'
    return $false
  }

  $Script:PriorityEditorCommitInProgress=$true
  try{
    $changed=Set-PMMModPriorityPosition $name $requested
    if($changed){
      Refresh-PMMLibraryAfterPriorityChange $name
    }else{
      # Also normalizes an out-of-range value when it clamps to the current end.
      $map=Get-PMMModPriorityMap
      if($map.ContainsKey($name)){$Editor.Text=[string]$map[$name]}
    }
    return $changed
  }finally{
    $Script:PriorityEditorCommitInProgress=$false
  }
}

function Apply-PMMLibraryFilter {
  $query=[string]$Script:TxtModFilter.Text
  $items=@($Script:LibraryDisplayItems)
  if(-not[string]::IsNullOrWhiteSpace($query)){
    $items=@($items|Where-Object{
      ([string]$_.Name).IndexOf($query,[StringComparison]::OrdinalIgnoreCase) -ge 0 -or
      ([string]$_.State).IndexOf($query,[StringComparison]::OrdinalIgnoreCase) -ge 0
    })
  }
  $Script:LstMods.ItemsSource=$items
  Update-PMMLibraryButtons
}

function Set-PMMLibraryDisplayItems([array]$Items) {
  $Script:LibraryDisplayItems=@($Items)
  Apply-PMMLibraryFilter
}

function Get-PMMAnalysisModeInfo([string]$Mode,[bool]$Resolved=$false) {
  switch($Mode){
    'BinaryAuto' { return [pscustomobject]@{Result=(L 'Auto merged' 'Auto merge');Adapter='Binary range'} }
    'StaticItemAuto' { return [pscustomobject]@{Result=(L 'Auto merged' 'Auto merge');Adapter='Static Item'} }
    'SupersetAuto' { return [pscustomobject]@{Result=(L 'Auto merged' 'Auto merge');Adapter='Superset anchor'} }
    'ContainedSupersetAuto' { return [pscustomobject]@{Result=(L 'Auto merged' 'Auto merge');Adapter='Contained code superset'} }
    'KnownRecipeAuto' { return [pscustomobject]@{Result=(L 'Auto merged' 'Auto merge');Adapter=(L 'Runtime-proven recipe' 'Receta runtime probada')} }
    'ManualSolutionExperimental' { return [pscustomobject]@{Result=(L 'Experimental solution' 'Solucion experimental');Adapter=(L 'Manual/AI cooked family' 'Familia cooked manual/IA')} }
    'DataTableAuto' { return [pscustomobject]@{Result=(L 'Auto merged' 'Auto merge');Adapter='DataTable scalar'} }
    'RelocatableAuto' { return [pscustomobject]@{Result=(L 'Auto merged' 'Auto merge');Adapter='Relocatable delta'} }
    'BinaryConflict' { return [pscustomobject]@{Result=$(if($Resolved){L 'Conflict resolved' 'Conflicto resuelto'}else{L 'Decision required' 'Decision requerida'});Adapter='Binary range'} }
    'StaticItemConflict' { return [pscustomobject]@{Result=$(if($Resolved){L 'Conflict resolved' 'Conflicto resuelto'}else{L 'Decision required' 'Decision requerida'});Adapter='Static Item'} }
    'DataTableConflict' { return [pscustomobject]@{Result=$(if($Resolved){L 'Conflict resolved' 'Conflicto resuelto'}else{L 'Decision required' 'Decision requerida'});Adapter='DataTable scalar'} }
    'RelocatableConflict' { return [pscustomobject]@{Result=$(if($Resolved){L 'Conflict resolved' 'Conflicto resuelto'}else{L 'Decision required' 'Decision requerida'});Adapter='Relocatable delta'} }
    'PackageChoice' { return [pscustomobject]@{Result=$(if($Resolved){L 'Package selected' 'Paquete elegido'}else{L 'Decision required' 'Decision requerida'});Adapter=(L 'Package variant' 'Variante de paquete')} }
    'Unsupported' { return [pscustomobject]@{Result=(L 'Unsupported' 'No soportado');Adapter=(L 'No safe adapter' 'Sin adapter seguro')} }
    'Identical' { return [pscustomobject]@{Result=(L 'Identical' 'Identico');Adapter=(L 'No patch needed' 'No requiere parche')} }
    default { return [pscustomobject]@{Result=$Mode;Adapter=$Mode} }
  }
}

function Test-PMMDecisionRowResolved($Row) {
  if(-not$Row){return $false}
  $choice=[string]$Row.SelectedChoice
  if([string]::IsNullOrWhiteSpace($choice)){return $false}
  if($choice -eq 'Custom' -and [string]::IsNullOrWhiteSpace([string]$Row.CustomValue)){return $false}
  return $true
}

function Refresh-PMMAnalysisWorkspace {
  $Script:TxtSharedCount.Text='0'
  $Script:TxtAutoCount.Text='0'
  $Script:TxtDecisionCount.Text='0'
  $Script:TxtUnsupportedCount.Text='0'
  $Script:TxtExperimentalCount.Text='0'
  $Script:TxtIdenticalCount.Text='0'
  $Script:DgAnalysisAssets.ItemsSource=@()

  $isCurrent=$false
  try{$isCurrent=Test-PMMMergePlanCurrent}catch{$isCurrent=$false}
  if(-not$isCurrent){
    $Script:TxtAnalysisHeadline.Text=L 'Run Analyze to build a compatibility plan for the current mod library.' 'Ejecuta Analizar para crear el plan de compatibilidad de la biblioteca actual.'
    $Script:TxtAnalysisScope.Text=L 'PMM will list every shared asset here, the mods involved, and whether it can be merged automatically or needs a decision.' 'PMM mostrara aqui cada asset compartido, los mods implicados y si puede fusionarse automaticamente o necesita una decision.'
    return
  }

  $plan=Read-PMMMergePlan
  if(-not$plan){return}
  $assets=@($plan.Assets)
  $decisionRows=@($plan.Rows)
  $alreadyPatched=($plan.PSObject.Properties.Name -contains 'AlreadyPatched' -and [bool]$plan.AlreadyPatched)
  $activePatch=$null

  if($alreadyPatched){
    try{$activePatch=Get-PMMCurrentManagedPatch @(Get-LibraryMods)}catch{$activePatch=$null}
    if($activePatch -and $activePatch.Manifest){
      if($activePatch.Manifest.PSObject.Properties.Name -contains 'Assets'){$assets=@($activePatch.Manifest.Assets)}
      if($activePatch.Manifest.PSObject.Properties.Name -contains 'Decisions'){$decisionRows=@($activePatch.Manifest.Decisions)}
    }
  }

  $report=Get-PMMLastScanReport
  $shared=if($alreadyPatched -and $report -and ($report.PSObject.Properties.Name -contains 'SharedAssetGroups')){[int]$report.SharedAssetGroups}else{$assets.Count}
  $autoModes=@('BinaryAuto','StaticItemAuto','SupersetAuto','ContainedSupersetAuto','KnownRecipeAuto','DataTableAuto','RelocatableAuto')
  $auto=@($assets|Where-Object{[string]$_.Mode -in $autoModes}).Count
  $unsupported=@($assets|Where-Object{[string]$_.Mode -eq 'Unsupported'}).Count
  $experimental=@($assets|Where-Object{[string]$_.Mode -eq 'ManualSolutionExperimental'}).Count
  $identical=@($assets|Where-Object{[string]$_.Mode -eq 'Identical'}).Count
  if($alreadyPatched -and $shared -gt $assets.Count){$identical += ($shared-$assets.Count)}
  $decisions=$decisionRows.Count
  $unresolved=@($decisionRows|Where-Object{-not(Test-PMMDecisionRowResolved $_)}).Count
  $requiresPatchCurrent=Test-PMMPlanRequiresPatch $plan

  $Script:TxtSharedCount.Text=[string]$shared
  $Script:TxtAutoCount.Text=[string]$auto
  $Script:TxtDecisionCount.Text=[string]$decisions
  $Script:TxtUnsupportedCount.Text=[string]$unsupported
  $Script:TxtExperimentalCount.Text=[string]$experimental
  $Script:TxtIdenticalCount.Text=[string]$identical

  if($alreadyPatched){
    $state=if($plan.PSObject.Properties.Name -contains 'PatchDeployed' -and [bool]$plan.PatchDeployed){L 'deployed' 'desplegado'}else{L 'built locally; Deploy pending' 'creado localmente; Deploy pendiente'}
    $Script:TxtAnalysisHeadline.Text=((L 'Current compatibility patch is up to date: {0} ({1}).' 'El parche de compatibilidad actual esta al dia: {0} ({1}).') -f [string]$plan.ActivePatch,$state)
  }elseif($unsupported -gt 0){
    $Script:TxtAnalysisHeadline.Text=((L '{0} shared asset(s) analyzed. Build is blocked by {1} unsupported asset(s).' '{0} asset(s) compartidos analizados. Build esta bloqueado por {1} asset(s) no soportados.') -f $shared,$unsupported)
  }elseif($unresolved -gt 0){
    $Script:TxtAnalysisHeadline.Text=((L '{0} shared asset(s) analyzed. {1} decision(s) still require your choice.' '{0} asset(s) compartidos analizados. Todavia faltan {1} decision(es).') -f $shared,$unresolved)
  }elseif($experimental -gt 0){
    $Script:TxtAnalysisHeadline.Text=((L '{0} shared asset(s) analyzed. Ready to build with {1} experimental manual/AI solution(s); in-game validation is required.' '{0} asset(s) compartidos analizados. Listo para Build con {1} solucion(es) manual/IA experimental(es); se requiere validacion dentro del juego.') -f $shared,$experimental)
  }elseif(-not$requiresPatchCurrent){
    $Script:TxtAnalysisHeadline.Text=((L '{0} compatibility/package item(s) analyzed. No compatibility patch is required; Deploy can use the resolved source set.' '{0} elemento(s) de compatibilidad/paquete analizados. No hace falta parche de compatibilidad; Deploy puede usar el conjunto fuente resuelto.') -f $shared)
  }else{
    $Script:TxtAnalysisHeadline.Text=((L '{0} shared asset(s) analyzed. The compatibility plan is ready to build.' '{0} asset(s) compartidos analizados. El plan de compatibilidad esta listo para Build.') -f $shared)
  }

  $participants=@($assets|Where-Object{[string]$_.Mode -notin @('Identical','Unsupported','PackageChoice')}|ForEach-Object{@($_.Providers)}|ForEach-Object{[string]$_}|Where-Object{$_}|Sort-Object -Unique)
  if($participants.Count -eq 0 -and ($plan.PSObject.Properties.Name -contains 'PatchedMods')){$participants=@($plan.PatchedMods|ForEach-Object{[string]$_}|Where-Object{$_}|Sort-Object -Unique)}
  if($participants.Count -gt 0){
    $Script:TxtAnalysisScope.Text=(L 'Compatibility overlay reconciles shared changes from: ' 'El overlay de compatibilidad reconcilia cambios compartidos de: ') + ($participants -join ', ') + '. ' + (L 'Mods with only unique files remain normal source PAKs.' 'Los mods con archivos unicos permanecen como PAK fuente normales.')
  }else{
    $Script:TxtAnalysisScope.Text=L 'No compatibility overlay work is required for the current shared files.' 'No se necesita trabajo de overlay para los archivos compartidos actuales.'
  }

  $view=[System.Collections.Generic.List[object]]::new()
  foreach($asset in @($assets)){
    $assetRows=@($decisionRows|Where-Object{[string]$_.AssetKey -eq [string]$asset.AssetKey})
    $assetResolved=($assetRows.Count -gt 0 -and @($assetRows|Where-Object{-not(Test-PMMDecisionRowResolved $_)}).Count -eq 0)
    $info=Get-PMMAnalysisModeInfo ([string]$asset.Mode) $assetResolved
    $changed=0
    if($asset.PSObject.Properties.Name -contains 'ChangedPathCount'){$changed=[int]$asset.ChangedPathCount}
    $conflicts=if($asset.PSObject.Properties.Name -contains 'ConflictCount'){[int]$asset.ConflictCount}else{$assetRows.Count}
    $changesText=if($conflicts -gt 0){((L '{0} decision(s)' '{0} decision(es)') -f $conflicts)}elseif($changed -gt 0){[string]$changed}elseif([string]$asset.Mode -eq 'Identical'){'-'}else{L 'composed' 'compuesto'}
    $reason=if($asset.PSObject.Properties.Name -contains 'Reason'){[string]$asset.Reason}else{''}
    if($assetRows.Count -gt 0){
      $unresolvedHere=@($assetRows|Where-Object{-not(Test-PMMDecisionRowResolved $_)}).Count
      if($unresolvedHere -gt 0){
        $reason += $(if($reason){'  '}else{''}) + ((L '{0} decision(s) unresolved.' '{0} decision(es) sin resolver.') -f $unresolvedHere)
      }else{
        $choices=@($assetRows|ForEach-Object{if([string]$_.SelectedChoice -eq 'Custom'){('Custom='+[string]$_.CustomValue)}else{[string]$_.SelectedChoice}}|Where-Object{$_}|Sort-Object -Unique)
        if($choices.Count -gt 0){$reason += $(if($reason){'  '}else{''}) + (L 'Resolved value source(s): ' 'Fuente(s) de valor resuelto: ') + ($choices -join ', ') + '.'}
      }
    }
    if([string]::IsNullOrWhiteSpace($reason) -and $alreadyPatched){$reason=L 'Already reconciled in the current compatibility patch.' 'Ya reconciliado en el parche de compatibilidad actual.'}
    $providers=@($asset.Providers|ForEach-Object{[string]$_}|Where-Object{$_})
    $full=[string]$asset.Asset
    $leaf=if([string]::IsNullOrWhiteSpace($full)){'-'}else{[IO.Path]::GetFileName($full)}
    $view.Add([pscustomobject]@{
      Result=[string]$info.Result
      Asset=$leaf
      Adapter=[string]$info.Adapter
      Providers=($providers -join ', ')
      Changes=$changesText
      FullAsset=$full
      Details=$reason
    })
  }
  $Script:DgAnalysisAssets.ItemsSource=$view.ToArray()
}

function Get-SelectedPMMLibraryEntries {
  return @($Script:LstMods.SelectedItems | Where-Object{$_ -and [string]$_.Kind -eq 'Source'})
}

function Get-SelectedPMMLibraryEntry {
  $items=@(Get-SelectedPMMLibraryEntries)
  if($items.Count -eq 0){return $null}
  return $items[0]
}

function Update-PMMLibraryButtons {
  if($Script:ImportBusy -or $Script:AnalyzeBusy -or $Script:BuildBusy -or $Script:DeployBusy -or $Script:AIIOBusy){
    foreach($button in @($Script:BtnSelectAllMods,$Script:BtnClearModSelection,$Script:BtnEnableMods,$Script:BtnDisableMods,$Script:BtnDeleteMod,$Script:BtnPriorityUp,$Script:BtnPriorityDown)){$button.IsEnabled=$false}
    return
  }
  $entries=@(Get-SelectedPMMLibraryEntries)
  $count=$entries.Count
  $single=($count -eq 1)
  $entry=if($single){$entries[0]}else{$null}
  $allSources=@($Script:LstMods.ItemsSource | Where-Object{$_ -and [string]$_.Kind -eq 'Source'})

  $Script:BtnSelectAllMods.IsEnabled=($allSources.Count -gt 0 -and $count -lt $allSources.Count)
  $Script:BtnClearModSelection.IsEnabled=($count -gt 0)
  $Script:BtnEnableMods.IsEnabled=(@($entries|Where-Object{-not[bool]$_.Enabled}).Count -gt 0)
  $Script:BtnDisableMods.IsEnabled=(@($entries|Where-Object{[bool]$_.Enabled}).Count -gt 0)
  $Script:BtnDeleteMod.IsEnabled=($count -gt 0)

  # Selection is presentation-only. The old code enumerated the full portable
  # library twice on every row click via Test-PMMModPriorityMove. Priority is
  # already normalized in the current ItemsSource, so no filesystem access is
  # needed to decide whether Earlier/Later should be enabled.
  if($single){
    $priority=0
    try{$priority=[int]$entry.Priority}catch{$priority=0}
    $Script:BtnPriorityUp.IsEnabled=($priority -gt 1)
    $Script:BtnPriorityDown.IsEnabled=($priority -gt 0 -and $priority -lt $allSources.Count)
  }else{
    $Script:BtnPriorityUp.IsEnabled=$false
    $Script:BtnPriorityDown.IsEnabled=$false
  }
}

function Update-PMMPatchActionButtons {
  if(-not$Script:BtnDeletePatch -or -not$Script:BtnValidatePatch -or -not$Script:BtnUndeployPatch){return}
  $Script:BtnDeletePatch.IsEnabled=$false;$Script:BtnValidatePatch.IsEnabled=$false;$Script:BtnUndeployPatch.IsEnabled=$false
  $Script:BtnValidatePatch.Content=L 'Validate merge' 'Validar merge'
  if($Script:ImportBusy -or $Script:AnalyzeBusy -or $Script:BuildBusy -or $Script:DeployBusy -or $Script:AIIOBusy){return}
  $entry=$Script:LstPatches.SelectedItem
  if(-not$entry -or -not($entry.PSObject.Properties.Name -contains 'Patch') -or -not$entry.Patch){return}
  $patch=$entry.Patch
  $validation=$null;try{$validation=Get-PMMBuildValidationSummary $patch}catch{}
  $state=if($validation){[string]$validation.Status}else{'UNVALIDATED'}
  switch($state){
    'LOCAL_PASS' {$Script:BtnValidatePatch.Content=L 'Working - validate again' 'Funciona - validar de nuevo';$Script:BtnValidatePatch.IsEnabled=$true}
    'LOCAL_PARTIAL' {$Script:BtnValidatePatch.Content=L 'Partial - validate again' 'Parcial - validar de nuevo';$Script:BtnValidatePatch.IsEnabled=$true}
    'LOCAL_FAIL' {$Script:BtnValidatePatch.Content=L 'Failed - validate again' 'Fallo - validar de nuevo';$Script:BtnValidatePatch.IsEnabled=$true}
    'STALE' {$Script:BtnValidatePatch.Content=L 'Validation stale' 'Validacion obsoleta';$Script:BtnValidatePatch.IsEnabled=$false}
    'NOT_DEPLOYED' {$Script:BtnValidatePatch.Content=L 'Deploy before validation' 'Despliega antes de validar';$Script:BtnValidatePatch.IsEnabled=$false}
    default {$Script:BtnValidatePatch.IsEnabled=[bool]$patch.Deployed}
  }
  # Delete is a full lifecycle delete: exact game copy + saved PMM copies.
  $Script:BtnDeletePatch.IsEnabled=$true
  # Undeploy is deliberately independent of source compatibility/selectability.
  $Script:BtnUndeployPatch.IsEnabled=[bool]$patch.Deployed
}

function Get-PMMPatchDecisionDisplay($Patch) {
  if(-not$Patch -or -not$Patch.Manifest){return [pscustomobject]@{Summary=(L 'Unknown' 'Desconocido');Details=''}}
  $manifest=$Patch.Manifest
  $rows=@()
  if($manifest.PSObject.Properties.Name -contains 'Decisions'){$rows=@($manifest.Decisions)}
  if($rows.Count -eq 0){
    $experimental=0
    if($manifest.PSObject.Properties.Name -contains 'ExperimentalManualSolutions'){$experimental=@($manifest.ExperimentalManualSolutions).Count}
    if($experimental -gt 0){return [pscustomobject]@{Summary=(L 'Experimental manual' 'Manual experimental');Details=(L 'Contains an explicitly accepted experimental manual/AI cooked solution.' 'Contiene una solucion cooked manual/IA experimental aceptada explicitamente.')}}
    return [pscustomobject]@{Summary=(L 'Automatic' 'Automatico');Details=(L 'No user conflict decisions are stored in this patch.' 'Este parche no guarda decisiones de conflicto del usuario.')}
  }
  $parts=[System.Collections.Generic.List[string]]::new()
  foreach($row in $rows){
    $choice=[string]$row.SelectedChoice
    if([string]::IsNullOrWhiteSpace($choice)){$choice=L 'unresolved' 'sin resolver'}
    elseif($choice -eq 'Custom'){$choice='Custom='+[string]$row.CustomValue}
    $label=''
    if($row.PSObject.Properties.Name -contains 'DisplayProperty'){$label=[string]$row.DisplayProperty}
    if([string]::IsNullOrWhiteSpace($label) -and ($row.PSObject.Properties.Name -contains 'Property')){$label=[string]$row.Property}
    if([string]::IsNullOrWhiteSpace($label)){$label=L 'decision' 'decision'}
    $parts.Add(($label+' = '+$choice))
  }
  $all=$parts.ToArray()
  $summary=if($all.Count -eq 1){
    $choice=[string]$rows[0].SelectedChoice
    if($choice -eq 'Custom'){'Custom='+[string]$rows[0].CustomValue}elseif([string]::IsNullOrWhiteSpace($choice)){L 'unresolved' 'sin resolver'}else{$choice}
  }else{(L '{0} decisions' '{0} decisiones') -f $all.Count}
  return [pscustomobject]@{Summary=$summary;Details=($all -join "`n")}
}

function Update-BuildButtonState {
  $Script:BtnBuild.IsEnabled=$false
  $Script:BtnDeploy.IsEnabled=$false
  $Script:TxtBuildDeployHint.Text=L 'Analyze the active source set to prepare Build/Deploy.' 'Analiza el conjunto de fuentes activo para preparar Build/Deploy.'
  $sourceMods=@(Get-LibraryMods)
  $noPatchSelected=Test-PMMNoPatchSelected
  $selectedPatch=if($noPatchSelected){$null}else{Get-PMMSelectedManagedPatch $sourceMods}
  $plan=Read-PMMMergePlan
  if(-not$plan -or -not(Test-PMMMergePlanCurrent)){
    if($noPatchSelected -and $sourceMods.Count -gt 0){
      $Script:BtnDeploy.IsEnabled=$true
      $Script:TxtBuildDeployHint.Text=L 'Manager-only mode: Deploy will synchronize active source mods without a compatibility overlay and remove any PMM overlay currently deployed. Analyze is optional in this mode.' 'Modo solo manager: Deploy sincronizara los mods fuente activos sin overlay de compatibilidad y retirara cualquier overlay PMM desplegado. Analizar es opcional en este modo.'
    }elseif($selectedPatch){
      $Script:BtnDeploy.IsEnabled=$true
      $Script:TxtBuildDeployHint.Text=((L 'Selected saved patch matches the exact active source hashes and mappings: {0}. Deploy is ready without Analyze. Run Analyze only if you want to inspect or build a new compatibility plan.' 'El parche guardado seleccionado coincide exactamente con los hashes de fuentes activos y los mappings: {0}. Deploy esta listo sin Analizar. Usa Analizar solo si quieres revisar o crear un nuevo plan de compatibilidad.') -f [string]$selectedPatch.Name)
    }
    return
  }

  $currentDecisionPatch=Get-PMMCurrentManagedPatch $sourceMods
  $unsupported=@(Get-PMMUnsupportedAssets)
  $alreadyPatched=($plan.PSObject.Properties.Name -contains 'AlreadyPatched' -and [bool]$plan.AlreadyPatched)
  $requiresPatch=Test-PMMPlanRequiresPatch $plan
  $unresolved=@($plan.Rows|Where-Object{-not(Test-PMMDecisionRowResolved $_)}).Count
  $unresolvedPackage=@($plan.Rows|Where-Object{($_.PSObject.Properties.Name -contains 'DecisionKind') -and [string]$_.DecisionKind -eq 'PackageChoice' -and -not(Test-PMMDecisionRowResolved $_)}).Count
  $packagePending=(($plan.PSObject.Properties.Name -contains 'PackageChoicePendingReanalysis') -and [bool]$plan.PackageChoicePendingReanalysis)
  $selectedMatchesDecision=($selectedPatch -and (Test-PMMPatchCurrent $selectedPatch $sourceMods))

  # Build always follows the currently displayed Analyze decisions. Deploy can
  # also intentionally roll back to an exact-source patch, or reuse one after
  # current Analyze proves its effective conflict recipe is still identical.
  $Script:BtnBuild.IsEnabled=(-not$alreadyPatched -and -not$packagePending -and $requiresPatch -and $unsupported.Count -eq 0 -and $unresolved -eq 0 -and -not$currentDecisionPatch)
  $Script:BtnDeploy.IsEnabled=(-not$packagePending -and $unresolvedPackage -eq 0 -and ($noPatchSelected -or -not$requiresPatch -or $null -ne $selectedPatch))

  if($packagePending){
    if($unresolvedPackage -gt 0){
      $Script:TxtBuildDeployHint.Text=((L '{0} package variant decision(s) must be resolved. Open Resolution & Review, choose the valid package configuration, then run Analyze again.' 'Debes resolver {0} decision(es) de variante de paquete. Abre Resolucion y revision, elige la configuracion valida y vuelve a ejecutar Analizar.') -f $unresolvedPackage)
    }else{
      $Script:TxtBuildDeployHint.Text=L 'Package variant selected. Run Analyze again so PMM can analyze only the chosen package components before Build/Deploy.' 'Variante de paquete elegida. Ejecuta Analizar de nuevo para que PMM analice solo los componentes elegidos antes de Build/Deploy.'
    }
    return
  }

  if($unsupported.Count -gt 0){
    if($noPatchSelected){
      $Script:TxtBuildDeployHint.Text=((L 'Manager-only mode selected. Analyze found {0} unsupported shared asset(s), but Deploy may still synchronize the active source PAKs without a PMM compatibility overlay. Their conflicts will then follow normal Palworld PAK load order.' 'Modo solo manager seleccionado. Analizar encontro {0} asset(s) compartido(s) no soportado(s), pero Deploy puede sincronizar los PAK fuente activos sin overlay de compatibilidad PMM. Sus conflictos seguiran entonces el orden normal de carga de PAK de Palworld.') -f $unsupported.Count)
    }elseif($selectedPatch){
      $Script:TxtBuildDeployHint.Text=((L 'Current Analyze is blocked by {0} unsupported asset(s), but the selected saved patch was built for this exact source set. Build remains blocked; Deploy can roll back to the selected known patch.' 'El Analisis actual esta bloqueado por {0} asset(s) no soportado(s), pero el parche guardado seleccionado fue creado para este conjunto exacto de fuentes. Build sigue bloqueado; Deploy puede volver al parche conocido seleccionado.') -f $unsupported.Count)
    }else{
      $Script:TxtBuildDeployHint.Text=((L 'Blocked by {0} unsupported shared asset(s). Disable one provider above or open its case. A patch from a different source set cannot be deployed.' 'Bloqueado por {0} asset(s) compartido(s) no soportado(s). Desactiva un provider arriba o abre su caso. No se puede desplegar un parche de otro conjunto de fuentes.') -f $unsupported.Count)
    }
    return
  }

  if($unresolved -gt 0){
    if($noPatchSelected){
      $Script:TxtBuildDeployHint.Text=((L 'Manager-only mode selected. {0} compatibility decision(s) are unresolved, but Deploy can still install the active source mods without a PMM overlay. Normal PAK load order will decide those overlaps.' 'Modo solo manager seleccionado. Hay {0} decision(es) de compatibilidad sin resolver, pero Deploy puede instalar los mods fuente activos sin overlay PMM. El orden normal de carga de PAK decidira esos solapamientos.') -f $unresolved)
    }elseif($selectedPatch){
      $Script:TxtBuildDeployHint.Text=((L '{0} new decision(s) are unresolved, so Build is waiting. The selected saved patch already contains an older resolved choice for this exact source set and may still be deployed as a rollback.' 'Hay {0} decision(es) nuevas sin resolver, asi que Build esta esperando. El parche guardado seleccionado ya contiene una eleccion anterior resuelta para este conjunto exacto y aun puede desplegarse como rollback.') -f $unresolved)
    }else{
      $Script:TxtBuildDeployHint.Text=((L '{0} true-conflict decision(s) still need a value. Expand Resolution & Review and choose the value before Build.' 'Todavia faltan {0} decision(es) de conflicto real. Abre Resolucion y revision y elige el valor antes de Build.') -f $unresolved)
    }
    return
  }

  if($noPatchSelected){
    $resolvedPackageRows=@($plan.Rows|Where-Object{($_.PSObject.Properties.Name -contains 'DecisionKind') -and [string]$_.DecisionKind -eq 'PackageChoice' -and (Test-PMMDecisionRowResolved $_)})
    if($resolvedPackageRows.Count -gt 0){
      $Script:TxtBuildDeployHint.Text=L 'Package choice is resolved. Deploy will keep the chosen package components, exclude the unselected alternative(s), synchronize the other active source mods, and remove any PMM overlay.' 'La eleccion de paquete esta resuelta. Deploy conservara los componentes elegidos, excluira las alternativas no seleccionadas, sincronizara los demas mods fuente activos y retirara cualquier overlay PMM.'
    }else{
      $Script:TxtBuildDeployHint.Text=L 'No compatibility patch selected. Deploy will synchronize active source mods only, remove any deployed PMM overlay, and leave source-mod conflicts to normal Palworld PAK load order. Saved patches are kept in the library.' 'No hay parche de compatibilidad seleccionado. Deploy sincronizara solo los mods fuente activos, retirara cualquier overlay PMM desplegado y dejara los conflictos entre mods fuente al orden normal de carga de PAK de Palworld. Los parches guardados se conservan en la biblioteca.'
    }
    return
  }

  if(@($plan.Assets|Where-Object{[string]$_.Mode -eq 'ManualSolutionExperimental'}).Count -gt 0 -and -not$currentDecisionPatch){
    $Script:TxtBuildDeployHint.Text=L 'The plan contains an experimental manual/AI cooked solution. PMM validated provenance/structure, not gameplay. Build only if you accept an in-game test.' 'El plan contiene una solucion cooked manual/IA experimental. PMM valido procedencia/estructura, no gameplay. Usa Build solo si aceptas probarla dentro del juego.'
    return
  }

  if($alreadyPatched -and ($plan.PSObject.Properties.Name -contains 'PatchReuseKind') -and [string]$plan.PatchReuseKind -eq 'EffectiveConflictSet'){
    $Script:TxtBuildDeployHint.Text=((L 'The effective conflict set is unchanged, so PMM reused {0}. No Build is needed. Deploy will only synchronize the changed active/disabled source PAKs and keep the proven overlay.' 'El conjunto efectivo de conflictos no ha cambiado, asi que PMM reutilizo {0}. No hace falta Build. Deploy solo sincronizara los PAK fuente activados/desactivados y conservara el overlay probado.') -f [string]$plan.ActivePatch)
    return
  }

  if($requiresPatch -and $selectedPatch){
    if($selectedMatchesDecision){
      $Script:TxtBuildDeployHint.Text=((L 'Selected patch matches the active source set and current Analyze decisions: {0}. Deploy is ready.' 'El parche seleccionado coincide con el conjunto activo y las decisiones actuales de Analisis: {0}. Deploy esta listo.') -f [string]$selectedPatch.Name)
    }else{
      $Script:TxtBuildDeployHint.Text=((L 'Selected saved patch matches the exact active source set but contains different earlier conflict decisions: {0}. Deploy will roll back to it. Build creates the currently analyzed decisions instead.' 'El parche guardado seleccionado coincide con el conjunto exacto de fuentes, pero contiene decisiones de conflicto anteriores distintas: {0}. Deploy volvera a ese parche. Build crea en cambio las decisiones analizadas actualmente.') -f [string]$selectedPatch.Name)
    }
  }elseif($requiresPatch){
    $Script:TxtBuildDeployHint.Text=L 'Analysis is compatible and complete. Build a new compatibility patch, then Deploy.' 'El analisis es compatible y esta completo. Crea un nuevo parche de compatibilidad y despues usa Deploy.'
  }else{
    $Script:TxtBuildDeployHint.Text=L 'No compatibility patch is required for the analyzed set. Deploy can synchronize the source mods.' 'No hace falta parche de compatibilidad para el conjunto analizado. Deploy puede sincronizar los mods fuente.'
  }
}

function Update-PMMDeploymentOptionsState {
  $Script:ChkForceClose.IsEnabled=[bool]$Script:ChkCloseGame.IsChecked
}

function Refresh-UI {
  $cfg = Get-PMMConfig
  $gamePath=[string]$cfg.GamePath
  $resolvedGame=$null
  try{if(-not[string]::IsNullOrWhiteSpace($gamePath)){$resolvedGame=Resolve-PalworldRoot $gamePath}}catch{$resolvedGame=$null}
  $gameReady=(-not[string]::IsNullOrWhiteSpace([string]$resolvedGame))
  $Script:TxtGamePath.Text = $gamePath
  $Script:TxtGamePath.ToolTip = $gamePath
  if($gameReady){
    $Script:TxtGamePathStatus.Text=((L 'Palworld detected - {0}' 'Palworld detectado - {0}') -f [string]$resolvedGame)
    $Script:TxtGamePathStatus.Foreground=$Window.Resources['AccentHeadingGreen']
    $Script:TxtGamePathStatus.ToolTip=[string]$resolvedGame
  }elseif(-not[string]::IsNullOrWhiteSpace($gamePath)){
    $Script:TxtGamePathStatus.Text=L 'Configured Palworld path is not valid - click to detect or configure it in Settings.' 'La ruta configurada de Palworld no es válida - pulsa para detectar o configúrala en Opciones.'
    $Script:TxtGamePathStatus.Foreground=$Window.Resources['AccentHeadingAmber']
    $Script:TxtGamePathStatus.ToolTip=$gamePath
  }else{
    $Script:TxtGamePathStatus.Text=L 'Palworld not detected - click to detect' 'Palworld no detectado - pulsa para detectar'
    $Script:TxtGamePathStatus.Foreground=$Window.Resources['MutedText']
    $Script:TxtGamePathStatus.ToolTip=$null
  }
  foreach($button in @($Script:BtnOpenGame,$Script:BtnOpenGameSettings,$Script:BtnOpenModsFolder,$Script:BtnOpenModsSettings,$Script:BtnPlay)){if($button){$button.IsEnabled=$gameReady}}
  if($Script:BtnDetectGame){$Script:BtnDetectGame.Visibility=[System.Windows.Visibility]::Visible;$Script:BtnDetectGame.IsEnabled=(-not $gameReady)}
  $Script:TxtLibraryPath.Text = Get-PMMPath 'Mods'
  $Script:UiSettingsRefreshing=$true
  try{
    $Script:ChkCloseGame.IsChecked = [bool]$cfg.CloseGameBeforeDeploy
    $Script:ChkForceClose.IsChecked = [bool]$cfg.ForceCloseOnTimeout
    $Script:TglAutoMode.IsChecked = [bool]$cfg.AutoMode
    $Script:ChkAutoPlay.IsChecked = [bool]$cfg.AutoIncludePlay
    Update-PMMDeploymentOptionsState
    $Script:CmbLanguage.SelectedValue = if ($cfg.Language -eq 'es') { 'es' } else { 'en' }
    $hintSeconds=5
    try{$hintSeconds=[int]$cfg.ActionHintSeconds}catch{$hintSeconds=5}
    if(-($hintSeconds -eq -1 -or ($hintSeconds -ge 0 -and $hintSeconds -le 120))){$hintSeconds=5}
    $Script:CmbActionHintDuration.SelectedValue=$hintSeconds
    $theme='pmm-crystal';try{$theme=[string]$cfg.Theme}catch{};if($theme -eq 'Dark'){$theme='Night'}
    if($Script:ThemePreviewActive -and $Script:ActiveThemeDraft){Apply-PMMThemeDefinition (Get-PMMThemeDraftPreviewDefinition $Script:ActiveThemeDraft)}else{Apply-PMMTheme $theme}
    Refresh-PMMThemeOptions $theme
    Initialize-PMMSoundSettingsUi $cfg
    $volume=50;try{$volume=[int]$cfg.CompletionVolume}catch{};$volume=[Math]::Max(0,[Math]::Min(100,$volume))
    $Script:SldCompletionVolume.Value=$volume;$Script:TxtCompletionVolume.Text=($volume.ToString()+'%')
    $autoErrorCases=$true;try{$autoErrorCases=[bool]$cfg.AIIOAutoCreateErrorCases}catch{};$Script:ChkAIIOAutoCreateErrorCases.IsChecked=$autoErrorCases
    $Script:TxtAIIOSettingsStatus.Text=L 'PMM never uploads on its own. If MCP is enabled, a connected client can request scoped data.' 'PMM no sube datos por su cuenta. Si habilitas MCP, un cliente conectado puede solicitar datos limitados.'
  }finally{$Script:UiSettingsRefreshing=$false}

  $sourceMods=@(Get-LibraryMods)
  $disabledMods=@(Get-PMMDisabledMods)
  $managedPatches=@(Get-PMMManagedPatches)
  $displayItems=[System.Collections.Generic.List[object]]::new()
  foreach($mod in $sourceMods){
    $displayItems.Add([pscustomobject]@{Kind='Source';Name=[string]$mod.Name;Enabled=$true;State=(L 'active' 'activo');Priority=[int]$mod.Priority;SizeText=("{0:N2}" -f ($mod.Size/1MB));HashShort=$mod.Hash.Substring(0,12)})
  }
  foreach($mod in $disabledMods){
    $displayItems.Add([pscustomobject]@{Kind='Source';Name=[string]$mod.Name;Enabled=$false;State=(L 'disabled' 'desactivado');Priority=[int]$mod.Priority;SizeText=("{0:N2}" -f ($mod.Size/1MB));HashShort=$mod.Hash.Substring(0,12)})
  }
  $Script:TxtLibraryCount.Text=((L '{0} active  |  {1} disabled' '{0} activos  |  {1} desactivados') -f $sourceMods.Count,$disabledMods.Count)
  Set-PMMLibraryDisplayItems @($displayItems|Sort-Object Priority,Name)

  $Script:LstPatches.Items.Clear()
  $selectedPatch=Get-PMMSelectedManagedPatch $sourceMods
  $currentCompatibilityPlan=Get-PMMCurrentPlanForPatchCompatibility $sourceMods
  $noPatchSelected=Test-PMMNoPatchSelected
  $compatibleCount=0
  $deployedCount=0
  $savedCount=0
  foreach($patch in $managedPatches){if($patch.Deployed){$deployedCount++};if([bool]$patch.BackedUp){$savedCount++}}
  $noneStatus=if($noPatchSelected -and $deployedCount -gt 0){L 'SELECTED | OVERLAY REMOVAL PENDING' 'SELECCIONADO | RETIRAR OVERLAY PENDIENTE'}elseif($noPatchSelected){L 'SELECTED | SOURCE MODS ONLY' 'SELECCIONADO | SOLO MODS FUENTE'}else{L 'SOURCE MODS ONLY' 'SOLO MODS FUENTE'}
  [void]$Script:LstPatches.Items.Add([pscustomobject]@{
    Name=(L 'No compatibility patch' 'Sin parche de compatibilidad');SelectionKey=(Get-PMMNoPatchSelectionName);Patch=$null;Selected=[bool]$noPatchSelected;Selectable=$true;
    SelectTip=(L 'Deploy active source mods without a PMM compatibility overlay. Any deployed PMM overlay will be removed; saved patches stay in the library.' 'Despliega los mods fuente activos sin overlay de compatibilidad PMM. Se retirara cualquier overlay PMM desplegado; los parches guardados permanecen en la biblioteca.');
    Status=$noneStatus;Built='';Assets='';DecisionSummary=(L 'None' 'Ninguna');DecisionDetails=(L 'Manager-only deployment. PMM does not apply a compatibility overlay.' 'Deploy solo como manager. PMM no aplica un overlay de compatibilidad.')
  })
  foreach($patch in $managedPatches){
    $exactSourceMatch=Test-PMMPatchSourceSetCompatible $patch $sourceMods
    $effectivePlanMatch=($currentCompatibilityPlan -and (Test-PMMPatchPlanCompatible $patch $currentCompatibilityPlan $sourceMods))
    $sourceMatch=($exactSourceMatch -or $effectivePlanMatch)
    if($sourceMatch){$compatibleCount++}
    $selected=($selectedPatch -and [string]$selectedPatch.Name -ieq [string]$patch.Name)
    $decisionMatch=($sourceMatch -and (Test-PMMPatchCurrent $patch $sourceMods))
    $effectiveOrderMatch=($sourceMatch -and (Test-PMMPatchEffectiveOrderCompatible $patch $sourceMods))
    $status=if($patch.Deployed -and -not[bool]$patch.BackedUp){L 'DEPLOYED | EXTERNAL ONLY' 'DESPLEGADO | SOLO EXTERNO'}elseif($patch.Deployed -and $decisionMatch){L 'DEPLOYED / CURRENT' 'DESPLEGADO / ACTUAL'}elseif($patch.Deployed -and -not$sourceMatch){L 'DEPLOYED | SOURCES NOT IMPORTED' 'DESPLEGADO | FUENTES NO IMPORTADAS'}elseif($patch.Deployed){L 'DEPLOYED | SAVED BUILD' 'DESPLEGADO | BUILD GUARDADO'}elseif($decisionMatch){L 'SAVED | CURRENT BUILD' 'GUARDADO | BUILD ACTUAL'}elseif($sourceMatch -and -not$effectiveOrderMatch){L 'SAVED | EFFECTIVE ORDER CHANGED' 'GUARDADO | CAMBIO DE ORDEN EFECTIVO'}elseif($sourceMatch){L 'SAVED | SAME SOURCE SET' 'GUARDADO | MISMAS FUENTES'}else{L 'SAVED | OTHER SOURCES' 'GUARDADO | OTRAS FUENTES'}
    if($selected -and -not$patch.Deployed){$status=(L 'SELECTED | ' 'SELECCIONADO | ')+$status}
    $validated=$false;$validationStatus='UNVALIDATED'
    try{$validation=Get-PMMBuildValidationSummary $patch;$validationStatus=[string]$validation.Status;$validated=($validationStatus -eq 'LOCAL_PASS')}catch{}
    $validationLabel=switch($validationStatus){
      'LOCAL_PASS' {L 'LOCAL PASS' 'PASS LOCAL'}
      'LOCAL_PARTIAL' {L 'LOCAL PARTIAL' 'PARCIAL LOCAL'}
      'LOCAL_FAIL' {L 'LOCAL FAIL' 'FALLO LOCAL'}
      'STALE' {L 'VALIDATION STALE' 'VALIDACION OBSOLETA'}
      'NOT_DEPLOYED' {L 'NOT DEPLOYED' 'NO DESPLEGADO'}
      default {L 'UNVALIDATED' 'SIN VALIDAR'}
    }
    $baseStatus=$status
    $status=$validationLabel+' | '+$baseStatus
    $tip=if($sourceMatch){
      if($effectivePlanMatch -and -not$exactSourceMatch){L 'Selectable: current Analyze proves that every effective conflict participant, provider hash, adapter, decision, mapping and Vanilla input still matches. Unrelated unique source mods may differ; Deploy will synchronize them without rebuilding the overlay.' 'Seleccionable: el Analisis actual demuestra que siguen coincidiendo todos los participantes efectivos de conflicto, hashes de providers, adapters, decisiones, mappings y Vanilla. Pueden diferir mods fuente unicos no relacionados; Deploy los sincronizara sin reconstruir el overlay.'}
      elseif($decisionMatch){L 'Selectable: exact source hashes, mappings, effective conflict order and current Analyze decisions match.' 'Seleccionable: coinciden hashes fuente, mappings, orden efectivo de conflictos y decisiones actuales de Analisis.'}
      elseif(-not$effectiveOrderMatch){L 'Selectable rollback: source hashes + mappings match, but an output-relevant priority winner changed (or the patch uses a legacy order signature). Select it explicitly only if you want that older output.' 'Rollback seleccionable: coinciden hashes fuente + mappings, pero cambio un ganador de prioridad que afecta al resultado (o el parche usa una firma de orden legacy). Seleccionalo explicitamente solo si quieres esa salida anterior.'}
      else{L 'Selectable rollback: source hashes + mappings + effective conflict order match; this patch may contain different previous manual conflict choices.' 'Rollback seleccionable: coinciden hashes fuente + mappings + orden efectivo de conflictos; este parche puede contener elecciones manuales de conflicto anteriores distintas.'}
    }elseif($patch.Deployed -and -not[bool]$patch.BackedUp){
      L 'External PMM merge detected in Palworld. PMM recognizes its deployment but will not silently recreate a saved build. Undeploy removes it from the game; Delete removes the exact deployed copy and any matching saved copy.' 'Merge PMM externo detectado en Palworld. PMM reconoce su despliegue pero no recreara silenciosamente un build guardado. Undeploy lo retira del juego; Delete borra la copia desplegada exacta y cualquier copia guardada coincidente.'
    }else{L 'Not selectable yet: the current PMM library does not contain the exact source mod hashes + mappings recorded by this patch. Import the source mods first; a deployed copy may remain active in Palworld meanwhile.' 'Aun no seleccionable: la biblioteca PMM actual no contiene los hashes exactos de mods fuente + mappings registrados por este parche. Importa primero los mods fuente; mientras tanto una copia ya desplegada puede seguir activa en Palworld.'}
    $built=''
    try{$built=([datetime]$patch.Modified).ToLocalTime().ToString('yyyy-MM-dd HH:mm')}catch{$built=[string]$patch.Modified}
    $decisionDisplay=Get-PMMPatchDecisionDisplay $patch
    [void]$Script:LstPatches.Items.Add([pscustomobject]@{
      Name=[string]$patch.Name;SelectionKey=[string]$patch.Name;Patch=$patch;Selected=[bool]$selected;Selectable=[bool]$sourceMatch;SelectTip=$tip;Validated=[bool]$validated;
      BaseStatus=$baseStatus;Status=$status;Built=$built;Assets=[string]$patch.AssetCount;DecisionSummary=[string]$decisionDisplay.Summary;DecisionDetails=[string]$decisionDisplay.Details
    })
  }
  $Script:TxtPatchCount.Text=((L '{0} saved  |  {1} selectable for active set  |  {2} deployed' '{0} guardado(s)  |  {1} seleccionable(s) para activos  |  {2} desplegado(s)') -f $savedCount,$compatibleCount,$deployedCount)

  Refresh-PMMAnalysisWorkspace
  Refresh-ConflictWorkspace

  $selectedSaveName='';try{if($Script:LstSaves.SelectedItem){$selectedSaveName=[string]$Script:LstSaves.SelectedItem.Name}}catch{}
  $Script:LstSaves.Items.Clear()
  foreach ($save in @(Get-PMMSaveWorlds)) { [void]$Script:LstSaves.Items.Add($save) }
  if($selectedSaveName){foreach($item in @($Script:LstSaves.Items)){if([string]$item.Name -eq $selectedSaveName){$Script:LstSaves.SelectedItem=$item;break}}}
  $Script:PrgBuild.IsIndeterminate = $false
  $Script:PrgBuild.Visibility = [System.Windows.Visibility]::Collapsed
  $Script:PrgBuild.Value = 0
  $Script:TxtBuildProgress.Text = ''
  $Script:TxtStatus.Text = Get-PMMStatusLine
  $Script:TxtLog.Text = Get-PMMRecentLog
  try{
    $gr=Get-PMMGameReferenceState
    $grSize=if([int64]$gr.Bytes -gt 0){('{0:N1} MiB' -f ([double]$gr.Bytes/1MB))}else{'0 MiB'}
    $grCreated=''
    if(-not [string]::IsNullOrWhiteSpace([string]$gr.CreatedUtc)){try{$grCreated=([datetime]$gr.CreatedUtc).ToLocalTime().ToString('yyyy-MM-dd HH:mm')}catch{$grCreated=[string]$gr.CreatedUtc}}
    if([string]$gr.Status -eq 'Current'){
      $Script:TxtGameReferenceSummary.Text=((L 'Status: Current | {0} families | {1} files | {2} | built {3}. Extracted files are current; semantic decoding and merge support are checked separately for each asset with the selected mappings.' 'Estado: Actual | {0} familias | {1} archivos | {2} | creado {3}. Los archivos extraidos estan al dia; la lectura semantica y el soporte de fusion se comprueban por asset con los mappings seleccionados.') -f [int]$gr.FamilyCount,[int]$gr.FileCount,$grSize,$grCreated)
    }elseif([string]$gr.Status -eq 'Stale'){
      $Script:TxtGameReferenceSummary.Text=((L 'Status: Stale. {0} Build/refresh before using it as case evidence.' 'Estado: Desactualizado. {0} Crea/actualiza la referencia antes de usarla como evidencia de un caso.') -f [string]$gr.Reason)
    }elseif([string]$gr.Status -eq 'NotBuilt'){
      $Script:TxtGameReferenceSummary.Text=L 'Status: Not built. Create a case now and add game references when needed.' 'Estado: No creada. Puedes crear un caso y añadir referencias del juego cuando las necesites.'
    }else{
      $Script:TxtGameReferenceSummary.Text=((L 'Status: {0}. {1}' 'Estado: {0}. {1}') -f [string]$gr.Status,[string]$gr.Reason)
    }
  }catch{$Script:TxtGameReferenceSummary.Text=L 'Game Reference status unavailable.' 'Estado de Game Reference no disponible.'}
  try{
    $ks=Get-PMMKnowledgeSummary
    $Script:TxtKnowledgeSummary.Text=((L 'Bundled knowledge: {0} behavior case(s), {1} exact fixture(s), {2} runtime-proven fixture(s), {3} exact runtime recipe(s). Recipes activate only after exact hash/structure validation.' 'Conocimiento incluido: {0} caso(s) de comportamiento, {1} fixture(s) exactos, {2} fixture(s) probados en runtime, {3} receta(s) runtime exacta(s). Las recetas solo se activan tras validar hashes/estructura exactos.') -f $ks.BehaviorCases,$ks.Fixtures,$ks.RuntimeProven,$ks.ProductionRecipes)
  }catch{$Script:TxtKnowledgeSummary.Text=L 'Knowledge library unavailable.' 'Biblioteca Knowledge no disponible.'}
  Update-PMMLibraryButtons
  Update-PMMPatchActionButtons
  Update-PMMAnalyzeIndicator
  Update-BuildButtonState
  Update-PMMGuidedActionState
  try{Refresh-PMMAIHelpBadge}catch{}
}

function Select-PalworldInstallation([array]$Paths) {
  $items = @(Get-UniqueWindowsPaths $Paths)
  if ($items.Count -eq 0) { return $null }
  if ($items.Count -eq 1) { return $items[0] }

  Add-Type -AssemblyName System.Windows.Forms
  Add-Type -AssemblyName System.Drawing
  $form = New-Object System.Windows.Forms.Form
  $form.Text = L 'Choose Palworld installation' 'Elegir instalacion de Palworld'
  $form.Width = 780; $form.Height = 390; $form.StartPosition = 'CenterScreen'
  $label = New-Object System.Windows.Forms.Label
  $label.Left = 15; $label.Top = 15; $label.Width = 735; $label.Height = 45
  $label.Text = L 'More than one different Palworld installation was found. Choose the one PMM should manage.' 'Se encontro mas de una instalacion diferente de Palworld. Elige la que debe gestionar PMM.'
  $list = New-Object System.Windows.Forms.ListBox
  $list.Left = 15; $list.Top = 65; $list.Width = 735; $list.Height = 220
  foreach ($item in $items) { [void]$list.Items.Add($item) }
  $list.SelectedIndex = 0
  $ok = New-Object System.Windows.Forms.Button; $ok.Text = 'OK'; $ok.Left = 575; $ok.Top = 300; $ok.Width = 80; $ok.DialogResult = [System.Windows.Forms.DialogResult]::OK
  $cancel = New-Object System.Windows.Forms.Button; $cancel.Text = L 'Cancel' 'Cancelar'; $cancel.Left = 665; $cancel.Top = 300; $cancel.Width = 85; $cancel.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
  $form.Controls.AddRange(@($label,$list,$ok,$cancel)); $form.AcceptButton = $ok; $form.CancelButton = $cancel
  if ((Show-PMMStyledDialog $form) -ne [System.Windows.Forms.DialogResult]::OK) { return $null }
  return [string]$list.SelectedItem
}

function Handle-UIError($ErrorRecord,[string]$Action,[switch]$NoDiagnostic) {
  $message = $ErrorRecord.Exception.Message
  Write-PMMLog ("ERROR during {0}: {1}`n{2}" -f $Action,$message,$ErrorRecord.ScriptStackTrace)
  Show-Error (L "$Action failed:`n`n$message`n`nFull details were saved to Workspace\Logs\PalModMerger.log" "$Action fallo:`n`n$message`n`nEl detalle completo se guardo en Workspace\Logs\PalModMerger.log")
  if($Script:HandlingUIError){Write-PMMLog ('Recursive UI error routing suppressed: '+$Action+' | '+$message);return}
  $Script:HandlingUIError=$true
  try{
    $cfg=Get-PMMConfig;$create=$true;try{$create=[bool]$cfg.AIIOAutoCreateErrorCases}catch{}
    if($create -and -not$NoDiagnostic){
      $case=Register-PMMAutomaticErrorCase -Title $Action -Message $message
      Refresh-PMMAIHelpDiagnostics;Refresh-PMMAIHelpBadge;[void](Select-PMMSelectorItemId $Script:LstAIHelpDiagnostics 'CaseId' ([string]$case.CaseId))
      $Script:MainTabs.SelectedItem=$Script:TabAIHelp;$Script:AIHelpTabs.SelectedItem=$Script:PMMHelpCaseTab
      $Script:TxtAIHelpDiagnosticStatus.Text=((L 'PMM recorded this error in diagnostic case {0}. Repeated identical failures reuse the same case.' 'PMM registro este error en el caso de diagnostico {0}. Los fallos identicos repetidos reutilizan el mismo caso.') -f [string]$case.CaseId)
    }
  }catch{Write-PMMLog ('Could not route the error into AI & Help: '+$_.Exception.Message)}
  finally{$Script:HandlingUIError=$false}
  try { Refresh-UI } catch { Write-PMMLog ("Secondary UI refresh failure after {0}: {1}" -f $Action,$_.Exception.Message) }
}

function Select-PMMSteamFolderInteractive {
  Add-Type -AssemblyName System.Windows.Forms
  $dialog=New-Object System.Windows.Forms.FolderBrowserDialog
  $dialog.Description=L 'Select a Steam installation or Steam library. PMM will inspect steamapps and registered Steam libraries.' 'Selecciona una instalacion o biblioteca de Steam. PMM revisara steamapps y las bibliotecas registradas de Steam.'
  if($dialog.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK){return $false}
  $paths=@(Get-PalworldInstallationsFromSteamRoot $dialog.SelectedPath)
  $selected=Select-PalworldInstallation $paths
  if(-not$selected){
    if($paths.Count -eq 0){throw (L 'No valid Palworld installation was found from the selected Steam folder.' 'No se encontro una instalacion valida de Palworld desde la carpeta de Steam seleccionada.')}
    return $false
  }
  $cfg=Get-PMMConfig
  if(-not($cfg.PSObject.Properties.Name -contains 'SteamRoot')){$cfg|Add-Member -NotePropertyName SteamRoot -NotePropertyValue ''}
  $cfg.SteamRoot=[IO.Path]::GetFullPath($dialog.SelectedPath)
  Save-PMMConfig $cfg
  Set-PMMGamePath $selected
  Refresh-UI
  return $true
}

function Select-PMMPalworldFolderInteractive {
  Add-Type -AssemblyName System.Windows.Forms
  $dialog=New-Object System.Windows.Forms.FolderBrowserDialog
  $dialog.Description=L 'Select the Palworld folder, Pal\Content\Paks, or a nearby subfolder. PMM will resolve the actual game root.' 'Selecciona la carpeta de Palworld, Pal\Content\Paks o una subcarpeta cercana. PMM encontrara la raiz real del juego.'
  if($dialog.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK){return $false}
  Set-PMMGamePath $dialog.SelectedPath
  Refresh-UI
  return $true
}

function Show-PMMGameDetectionFallback {
  Add-Type -AssemblyName System.Windows.Forms
  Add-Type -AssemblyName System.Drawing
  $form=New-Object System.Windows.Forms.Form
  $form.Text=L 'Palworld location required' 'Se necesita la ubicacion de Palworld'
  $form.Width=560;$form.Height=235;$form.StartPosition='CenterParent';$form.FormBorderStyle='FixedDialog';$form.MaximizeBox=$false;$form.MinimizeBox=$false
  $label=New-Object System.Windows.Forms.Label
  $label.Left=18;$label.Top=18;$label.Width=510;$label.Height=68
  $label.Text=L 'Palworld could not be detected automatically. Choose the Steam folder or the Palworld folder itself.' 'Palworld no pudo detectarse automaticamente. Elige la carpeta de Steam o la propia carpeta de Palworld.'
  $steam=New-Object System.Windows.Forms.Button;$steam.Text=L 'Choose Steam folder' 'Elegir carpeta de Steam';$steam.Left=18;$steam.Top=108;$steam.Width=165;$steam.Height=34
  $game=New-Object System.Windows.Forms.Button;$game.Text=L 'Choose Palworld folder' 'Elegir carpeta de Palworld';$game.Left=194;$game.Top=108;$game.Width=175;$game.Height=34
  $cancel=New-Object System.Windows.Forms.Button;$cancel.Text=L 'Cancel' 'Cancelar';$cancel.Left=380;$cancel.Top=108;$cancel.Width=145;$cancel.Height=34
  $steam.Add_Click({$form.Tag='Steam';$form.Close()})
  $game.Add_Click({$form.Tag='Palworld';$form.Close()})
  $cancel.Add_Click({$form.Tag='Cancel';$form.Close()})
  $form.Controls.AddRange(@($label,$steam,$game,$cancel));$form.CancelButton=$cancel
  [void](Show-PMMStyledDialog $form)
  return [string]$form.Tag
}

function Invoke-PMMGameDetection([bool]$ShowNotFound=$true) {
  $Script:TxtStatus.Text=L 'Detecting Steam libraries and Palworld installations...' 'Detectando bibliotecas de Steam e instalaciones de Palworld...'
  try{[System.Windows.Forms.Application]::DoEvents()}catch{}
  $paths=@(Find-PalworldInstallations)
  $selected=Select-PalworldInstallation $paths
  if($selected){Set-PMMGamePath $selected;Refresh-UI;return $true}
  if($ShowNotFound){
    $choice=Show-PMMGameDetectionFallback
    switch($choice){
      'Steam' {return [bool](Select-PMMSteamFolderInteractive)}
      'Palworld' {return [bool](Select-PMMPalworldFolderInteractive)}
    }
  }
  Refresh-UI
  return $false
}
function Select-PMMLibraryContextTarget($List,$Target) {
  $row=[Windows.Controls.ItemsControl]::ContainerFromElement($List,$Target)
  if($row -is [Windows.Controls.DataGridRow]){
    if(-not$row.IsSelected){$List.SelectedItem=$row.Item}
    [void]$row.Focus()
  }else{$List.UnselectAll()}
}
function Initialize-PMMLibraryCaseMenu {
  $menu=[Windows.Controls.ContextMenu]::new()
  $create=[Windows.Controls.MenuItem]::new()
  $create.Header=L 'Create new case...' 'Crear nuevo caso...'
  $create.Add_Click({try{Invoke-PMMNewLibraryCaseUI}catch{Handle-UIError $_ (L 'Create mod case' 'Crear caso del mod')}})
  [void]$menu.Items.Add($create)
  $menu.Add_Opened({param($sender,$eventArgs)$sender.Items[0].IsEnabled=(@(Get-SelectedPMMLibraryEntries).Count -gt 0)})
  $Script:LstMods.ContextMenu=$menu
  $Script:LstMods.Add_PreviewMouseRightButtonDown({param($sender,$eventArgs)Select-PMMLibraryContextTarget $sender $eventArgs.OriginalSource})
}
