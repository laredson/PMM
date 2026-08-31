param([string]$Root=([IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))))

Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$Root=[IO.Path]::GetFullPath($Root)
$App=Join-Path $Root 'PMM'

function Assert-RC29([bool]$Condition,[string]$Message){if(-not$Condition){throw ('RC29 regression failed: '+$Message)}}

$fixtureRoot=Join-Path ([IO.Path]::GetTempPath()) ('PMM-RC29-'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force -Path $fixtureRoot|Out-Null
$Script:Root=$fixtureRoot

function Get-PMMPath([string]$Category){$path=Join-Path $fixtureRoot $Category;New-Item -ItemType Directory -Force -Path $path|Out-Null;return $path}
function Join-PMMPath([string]$Category,[string]$Child=''){$path=Get-PMMPath $Category;if($Child){$path=Join-Path $path $Child;$parent=Split-Path -Parent $path;if($parent){New-Item -ItemType Directory -Force -Path $parent|Out-Null}};return $path}
function Write-PMMAIIOJsonAtomic([string]$Path,$Value,[int]$Depth=50){$parent=Split-Path -Parent $Path;if($parent){New-Item -ItemType Directory -Force -Path $parent|Out-Null};$Value|ConvertTo-Json -Depth $Depth|Set-Content -LiteralPath $Path -Encoding UTF8}
function Get-PMMStableTextId([string]$Text){$sha=[Security.Cryptography.SHA256]::Create();try{return ([BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($Text)))).Replace('-','').ToLowerInvariant()}finally{$sha.Dispose()}}
function Get-Sha256([string]$Path){$sha=[Security.Cryptography.SHA256]::Create();$stream=[IO.File]::OpenRead($Path);try{return ([BitConverter]::ToString($sha.ComputeHash($stream))).Replace('-','').ToLowerInvariant()}finally{$stream.Dispose();$sha.Dispose()}}
function Write-PMMLog([string]$Message){}

try{
  . (Join-Path $App 'Modules\AIIO\AIIO.DiagnosticService.ps1')
  $fingerprint=Get-PMMDiagnosticFingerprint 'PMM_ERROR' 'Fixture action' 'Fixture action: deterministic failure'
  $case=[pscustomobject][ordered]@{Schema='PMM_DIAGNOSTIC_CASE_V1';CaseId='DIAG-20260830-220000-11111111';Type='PMM_ERROR';Origin='AutomaticError';AttentionEligible=$true;Fingerprint=$fingerprint;OccurrenceCount=1;Title='Fixture action';UserDescription='Fixture action: deterministic failure';Status='Open';CreatedUtc=[DateTime]::UtcNow.ToString('o');UpdatedUtc=[DateTime]::UtcNow.ToString('o')}
  Write-PMMAIIOJsonAtomic (Join-Path (Get-PMMPath 'AIIODiagnostics') ($case.CaseId+'.json')) $case 20
  $first=Register-PMMAutomaticErrorCase -Title 'Fixture action' -Message 'deterministic failure'
  $second=Register-PMMAutomaticErrorCase -Title 'Fixture action' -Message 'deterministic failure'
  Assert-RC29 ([string]$first.CaseId -ceq [string]$second.CaseId) 'Repeated automatic errors did not reuse one case.'
  Assert-RC29 ([int]$second.OccurrenceCount -eq 3) 'Automatic error occurrence count was not incremented.'

  $legacy=[pscustomobject][ordered]@{Schema='PMM_DIAGNOSTIC_CASE_V1';CaseId='DIAG-20260830-220001-22222222';Type='PMM_ERROR';Title='AIIOPrepare completion';UserDescription="AIIOPrepare completion: La propiedad 'SelectedValue' no se encuentra en este objeto.";Status='Open';CreatedUtc=[DateTime]::UtcNow.ToString('o');UpdatedUtc=[DateTime]::UtcNow.ToString('o')}
  $legacyPath=Join-Path (Get-PMMPath 'AIIODiagnostics') ($legacy.CaseId+'.json');Write-PMMAIIOJsonAtomic $legacyPath $legacy 20
  $legacyFeedback=[pscustomobject][ordered]@{Schema='PMM_DIAGNOSTIC_CASE_V1';CaseId='DIAG-20260830-220002-33333333';Type='PMM_ERROR';Title='Generate local validation feedback';UserDescription='Generate local validation feedback: Select a compatibility merge in Mods & Merge first.';Status='Open';CreatedUtc=[DateTime]::UtcNow.ToString('o');UpdatedUtc=[DateTime]::UtcNow.ToString('o')}
  $legacyFeedbackPath=Join-Path (Get-PMMPath 'AIIODiagnostics') ($legacyFeedback.CaseId+'.json');Write-PMMAIIOJsonAtomic $legacyFeedbackPath $legacyFeedback 20
  $resolved=@(Resolve-PMMKnownLegacyUiDiagnostics)
  $legacyAfter=Get-Content -LiteralPath $legacyPath -Raw -Encoding UTF8|ConvertFrom-Json
  $legacyFeedbackAfter=Get-Content -LiteralPath $legacyFeedbackPath -Raw -Encoding UTF8|ConvertFrom-Json
  Assert-RC29 ($legacy.CaseId -in $resolved -and $legacyFeedback.CaseId -in $resolved) 'Known RC28 callback/selection diagnostics were not migrated.'
  Assert-RC29 ([string]$legacyAfter.Status -ceq 'ResolvedByUpgrade' -and -not[bool]$legacyAfter.AttentionEligible) 'Migrated diagnostic still requires attention.'
  Assert-RC29 ([string]$legacyFeedbackAfter.Status -ceq 'ResolvedByUpgrade' -and -not[bool]$legacyFeedbackAfter.AttentionEligible) 'Migrated validation-feedback diagnostic still requires attention.'

  . (Join-Path $App 'Modules\AIIO\AIIO.ValidationService.ps1')
  function Get-PMMValidationInstallationIdentity {[pscustomobject]@{InstallationId=('a'*64)}}
  function Get-PMMAIIOProductIdentity {[pscustomobject]@{Product='Palworld Manager Merger';Creator='laredson';Version='1.3.0';BuildId='PMM-v1.3.0-RC30-LEAN-AI-VALIDATION-FLOW'}}
  $feedback=New-PMMUserFeedbackFile -Kind GENERAL_COMMENT -Title 'Fixture feedback' -Comments 'Inspectable and local.'
  $record=Get-Content -LiteralPath $feedback.Path -Raw -Encoding UTF8|ConvertFrom-Json
  Assert-RC29 ([string]$record.Schema -ceq 'PMM_USER_FEEDBACK_V1') 'Feedback schema mismatch.'
  Assert-RC29 ([string]$record.Sharing.Mode -ceq 'ManualOnly') 'Feedback is not manual-only.'
  Assert-RC29 (-not[bool]$record.Sharing.UploadAttempted -and -not[bool]$record.Sharing.UploadAvailable) 'Feedback unexpectedly enables upload.'

  $bootstrap=Get-Content -LiteralPath (Join-Path $App 'Modules\Bootstrap\Start-PalModMerger.ps1') -Raw -Encoding UTF8
  Assert-RC29 ($bootstrap -notmatch [regex]::Escape('$Script:LstAIIOSessions.SelectedValue')) 'AIIO callback still writes ListBox.SelectedValue.'
  Assert-RC29 ($bootstrap -notmatch [regex]::Escape('$Script:LstAIHelpDiagnostics.SelectedValue')) 'Diagnostic callback still writes ListBox.SelectedValue.'
  foreach($marker in @('Complete-PMMAIIOPrepareUi','Repair-PMMDuplicateDiagnosticSessions','Register-PMMAutomaticErrorCase','PMM_USER_FEEDBACK_V1')){Assert-RC29 (($bootstrap+(Get-Content -LiteralPath (Join-Path $App 'Modules\AIIO\AIIO.ValidationService.ps1') -Raw)) -match [regex]::Escape($marker)) ('Missing RC29 marker: '+$marker)}

  $referenceNames=$null
  foreach($name in @('MainWindow.xaml','MainWindow.en.xaml','MainWindow.es.xaml')){
    [xml]$xml=Get-Content -LiteralPath (Join-Path $App ('Resources\UI\'+$name)) -Raw -Encoding UTF8
    $manager=[Xml.XmlNamespaceManager]::new($xml.NameTable);$manager.AddNamespace('x','http://schemas.microsoft.com/winfx/2006/xaml')
    $names=@($xml.SelectNodes('//*[@x:Name]',$manager)|ForEach-Object{[string]$_.GetAttribute('Name','http://schemas.microsoft.com/winfx/2006/xaml')})
    Assert-RC29 ($names.Count -eq 288 -and @($names|Sort-Object -Unique).Count -eq 288) ('Localized XAML name count mismatch: '+$name)
    if($null -eq $referenceNames){$referenceNames=@($names|Sort-Object)}else{Assert-RC29 ((@($names|Sort-Object) -join '|') -ceq ($referenceNames -join '|')) ('Localized XAML parity mismatch: '+$name)}
  }

  $dialog=[regex]::Match($bootstrap,'(?s)function Show-PMMBuildValidationDialog\b.*?(?=\r?\n# Action-required hint duration:)').Value
  Assert-RC29 ($dialog -match [regex]::Escape('$buttonWidth=230')) 'Validation buttons were not enlarged.'
  Assert-RC29 ($dialog -match [regex]::Escape('$button.Height=76')) 'Validation button height is too small.'
  Write-Output 'RC29_AIHELP_FEEDBACK_UI_REGRESSION_OK'
}finally{
  Remove-Item -LiteralPath $fixtureRoot -Recurse -Force -ErrorAction SilentlyContinue
}
