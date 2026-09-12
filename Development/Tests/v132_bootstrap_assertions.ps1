$ErrorActionPreference='Stop';$checks=0
function Assert-Fixture($ok,[string]$why){if(-not$ok){throw $why};$script:checks++}
function Click-Fixture([string]$name){$control=$Window.FindName($name);if(-not$control){throw ('Control absent: '+$name)};$control.RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Button]::ClickEvent))}
try{
  Assert-Fixture ($Script:MainTabs.Items.Count -eq 6) 'Current bootstrap lost the six workspaces.'
  Assert-Fixture ([string]$Script:BtnOpenAIHandoff.Content -match 'CASE|CASO') 'Merge still exposes legacy handoff action.'
  Assert-Fixture ($null -ne $Window.FindName('BtnImportMappings')) 'Mappings import is absent.'
  Assert-Fixture ($null -ne $Window.FindName('BtnBundledMappings')) 'Bundled mapping reset is absent.'
  $Script:TestOperations=@()
  function Start-PMMBackgroundOperation {param([string]$Operation,[string]$MappingsFile,[scriptblock]$OnSuccess);$Script:TestOperations+=,[pscustomobject]@{Operation=$Operation;MappingsFile=$MappingsFile};return $true}
  Click-Fixture 'BtnBundledMappings'
  Assert-Fixture ($Script:TestOperations.Count -eq 1 -and $Script:TestOperations[0].Operation -eq 'MappingsImport' -and -not$Script:TestOperations[0].MappingsFile) 'Mappings reset must use the shared worker.'
  $Script:TestOperations=@()
  Assert-Fixture (Initialize-PMMFixLabFeature) 'Lazy Fix Lab initialization failed.'
  function Get-PMMFixLabSelectedCandidate {return [pscustomobject]@{CaseId='fixture-repair';Name='Fixture repair';Description='Keep original intent';Sources=@();RecipeId='fixture-recipe'}}
  $Script:FixLabSelectedVariantId='fixture-variant'
  Click-Fixture 'BtnFixLabCreateHandoff'
  $repair=Get-PMMAIIOSelectedCase
  Assert-Fixture ($repair.Type -eq 'FIX_MOD' -and $repair.Origin -eq 'FixLab') 'Fix Lab did not route to its repair case.'
  Click-Fixture 'BtnFixLabCreateHandoff'
  Assert-Fixture ((Get-PMMAIIOSelectedCase).CaseId -eq $repair.CaseId) 'Fix Lab duplicated its case.'
  function Show-PMMStyledDialog($form){
    Assert-Fixture ([string]$form.FindName('BtnModProjectPrepare').Content -match 'case|caso') 'Mod project dialog still requests an immediate AI ZIP.'
    Assert-Fixture ($null -eq $form.FindName('BtnModProjectSave')) 'Mod project dialog has duplicate creation choices.'
    $form.Tag=[pscustomobject]@{Title='Fixture project';Description='New mod goal';TargetHint='test'};return $true
  }
  Click-Fixture 'BtnAIHelpNewModProject'
  Assert-Fixture ((Get-PMMAIIOSelectedCase).Type -eq 'NEW_MOD') 'Mod creation did not route to a case.'
  function Update-PMMThemeEditorDraftFromUi {param([switch]$Save);return [pscustomobject]@{DraftId='fixture-theme';Name='Fixture theme'}}
  $Script:TxtThemeEditorPrompt.Text='A theme goal'
  Click-Fixture 'BtnThemeEditorCreateAI'
  Assert-Fixture ((Get-PMMAIIOSelectedCase).Origin -eq 'Theme') 'Theme did not route to a case.'
  $Script:TxtAIIOTitle.Text='A help question';$Script:TxtAIIODescription.Text='User context'
  Click-Fixture 'BtnAIIONewSession'
  Assert-Fixture ((Get-PMMAIIOSelectedCase).Origin -eq 'Help') 'Legacy help entrance did not route to a case.'
  Assert-Fixture ($Script:TestOperations.Count -eq 0) 'Opening a case started a heavy operation.'
  Assert-Fixture (@(Get-PMMAIIOSessions).Count -eq 0) 'Opening a case eagerly created a transport session.'
  Assert-Fixture (@(Get-PMMAIIOCases).Count -eq 4) 'Origins lost or duplicated cases.'
  $diagnostic=New-PMMDiagnosticCase -Type UNKNOWN -Title 'Fixture diagnostic' -UserDescription 'Investigate PMM' -AttentionEligible $false
  $case=Sync-PMMDiagnosticToCase $diagnostic;Select-PMMCaseLocation $case
  Assert-Fixture ((Get-PMMAIIOSelectedCase).Origin -eq 'Diagnostics') 'Diagnostics did not use the same workspace.'
  Assert-Fixture (@(Get-PMMAIIOCases).Count -eq 5) 'Diagnostic migration duplicated a case.'
  $compat=New-PMMAIIOCase -Title 'Compatibility fixture' -Type COMPATIBILITY
  $Script:LstUnsupportedAssets.ItemsSource=@([pscustomobject]@{Asset='Pal/Fixture.uasset';AssetKey='pal/fixture.uasset';Reason='Fixture blocked';Mode='Unsupported';ReviewFolder='';Providers=@('fixture');PersistentCaseId=$compat.CaseId})
  $Script:LstUnsupportedAssets.SelectedIndex=0
  Click-Fixture 'BtnOpenAIHandoff'
  Assert-Fixture ((Get-PMMAIIOSelectedCase).CaseId -eq $compat.CaseId) 'Unsupported button did not select its persistent case.'
  Assert-Fixture ($Script:TestOperations.Count -eq 0) 'Unsupported case entry created a transport eagerly.'
  'PASS bootstrap132 '+$lang+': '+$checks+' real bootstrap/runtime assertions; no external processes or game.'
}finally{
  foreach($entry in @(Get-Variable -Scope Script|Where-Object{$_.Value -is [Windows.Threading.DispatcherTimer]})){$entry.Value.Stop()}
  $Window.Close()
}
