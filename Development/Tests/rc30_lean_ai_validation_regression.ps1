param([string]$Root = '')

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
if ([string]::IsNullOrWhiteSpace($Root)) { $Root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..')) }
$App = Join-Path $Root 'PMM'
$Bootstrap = Get-Content -LiteralPath (Join-Path $App 'Modules\Bootstrap\Start-PalModMerger.ps1') -Raw -Encoding UTF8
$Response = Get-Content -LiteralPath (Join-Path $App 'Modules\AIIO\AIIO.ResponseService.ps1') -Raw -Encoding UTF8
$Manifest = Get-Content -LiteralPath (Join-Path $App 'Resources\Metadata\RELEASE_MANIFEST.json') -Raw -Encoding UTF8 | ConvertFrom-Json

function Require([bool]$Condition,[string]$Message) { if (-not $Condition) { throw $Message } }
function Body([string]$Start,[string]$End) {
  $a = $Bootstrap.IndexOf($Start,[StringComparison]::Ordinal)
  $b = $Bootstrap.IndexOf($End,$a + $Start.Length,[StringComparison]::Ordinal)
  Require ($a -ge 0 -and $b -gt $a) ('Could not isolate block: ' + $Start)
  return $Bootstrap.Substring($a,$b-$a)
}

Require ([string]$Manifest.buildId -eq 'PMM-v1.3.1-MOD-CREATION-PREVIEW') 'Current build identity mismatch while preserving the RC30 regression.'
Require ([string]$Manifest.releaseCandidate -eq '1.3.1-mod-creation-preview') 'Current candidate identity mismatch while preserving the RC30 regression.'
Require (-not[bool]$Manifest.aiioRemoteUploadEnabled) 'Remote upload must remain disabled.'

$namespace = 'http://schemas.microsoft.com/winfx/2006/xaml'
$reference = $null
foreach ($name in @('MainWindow.xaml','MainWindow.en.xaml','MainWindow.es.xaml')) {
  [xml]$document = Get-Content -LiteralPath (Join-Path $App ('Resources\UI\' + $name)) -Raw -Encoding UTF8
  $manager = New-Object System.Xml.XmlNamespaceManager($document.NameTable)
  $manager.AddNamespace('x',$namespace)
  $names = @($document.SelectNodes('//*[@x:Name]',$manager) | ForEach-Object { $_.GetAttribute('Name',$namespace) } | Sort-Object -Unique)
  Require ($names.Count -eq 289) ($name + ' must contain 289 unique controls.')
  if ($null -eq $reference) { $reference = $names }
  else { Require (@(Compare-Object $reference $names).Count -eq 0) ($name + ' control parity mismatch.') }
  foreach ($required in @('BtnAIHelpCreateAndPrepareCase','PnlAIHelpSelectedCase','PnlAIHelpNewCase','TxtGameReferenceSummary')) {
    Require ($required -in $names) ($name + ' missing ' + $required)
  }
}

Require (([regex]::Matches($Bootstrap,[regex]::Escape('$e.OriginalSource -ne $sender'))).Count -ge 2) 'Parent tab routed-event guards are missing.'
$mainTabs = Body '$Script:MainTabs.Add_SelectionChanged' '$Script:AIHelpTabs.Add_SelectionChanged'
Require ($mainTabs -notmatch [regex]::Escape('Refresh-UI')) 'Main tab navigation still performs a global refresh.'
$validation = Body '$Script:BtnValidatePatch.Add_Click' '$Script:BtnDeletePatch.Add_Click'
Require ($validation -notmatch [regex]::Escape('Refresh-UI')) 'Validation still performs a global refresh.'
foreach ($marker in @('Update-PMMValidatedPatchRow','Show-PMMValidationContributionDialog','Open-PMMValidationFeedbackForPatch')) { Require ($validation -match [regex]::Escape($marker)) ('Validation marker missing: ' + $marker) }

$dialog = Body 'function Show-PMMBuildValidationDialog' 'function Show-PMMValidationContributionDialog'
foreach ($marker in @('$clientWidth=1040','$buttonWidth=230','$button.Height=76')) { Require ($dialog -match [regex]::Escape($marker)) ('Validation dialog marker missing: ' + $marker) }

Require ($Bootstrap -notmatch 'UiResponsivenessTimer') 'Permanent UI responsiveness polling remains present.'
Require ($Bootstrap -match [regex]::Escape('$Script:ExternalModsTimer.Interval=[TimeSpan]::FromSeconds(60)')) 'External-mod heartbeat is not 60 seconds.'
Require ($Bootstrap -match [regex]::Escape('TotalSeconds -lt 60')) 'External-mod activation/timer checks are not sharing the 60-second throttle.'
Require ($Bootstrap -match [regex]::Escape('$Script:CmbAIHelpFeedbackBuild.IsDropDownOpen')) 'Feedback selector open-state guard is missing.'
Require ($Bootstrap -match [regex]::Escape('ThemeEditorDirtyFields')) 'Theme draft dirty-field guard is missing.'
Require ($Response -match [regex]::Escape("Kind='ThemeResponse'")) 'Standalone theme response routing is missing.'
Require ($Bootstrap -match [regex]::Escape('Import-PMMThemeAIResponse $zipPath')) 'Theme response intake is missing.'

Write-Output 'RC30_LEAN_AI_VALIDATION_REGRESSION_OK'
