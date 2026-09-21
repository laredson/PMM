param([string]$Repository=([IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))))
$ErrorActionPreference='Stop';Set-StrictMode -Version 2
$updates=Join-Path $Repository 'PMM\Modules\Presentation\Updates.UI.ps1';$guided=Join-Path $Repository 'PMM\Modules\Workflow\GuidedFlow.ps1'
function Assert-True($Value,[string]$Message){if(-not$Value){throw $Message}}
$updateText=Get-Content $updates -Raw
$guidedText=Get-Content $guided -Raw
foreach($name in @('BtnCheckUpdates','BtnUpdateSelected','BtnUpdateSafe','BtnCancelUpdates','BtnRestoreUpdate','BtnDeleteUpdateArchive')){Assert-True ($updateText -match ('\$Script:'+ $name +'=\$null')) ('Updates does not predeclare '+$name+' for StrictMode startup.')}
Assert-True ($guidedText -match 'Get-Variable -Scope Script -Name BtnCheckUpdates -ValueOnly -ErrorAction SilentlyContinue') 'ColorFlow does not safely read the pre-initialization Check Updates control.'
Assert-True ($guidedText -match 'Get-Variable -Scope Script -Name BtnUpdateSafe -ValueOnly -ErrorAction SilentlyContinue') 'ColorFlow does not safely read the pre-initialization Update Safe control.'
Assert-True ($updateText -match 'Refresh-PMMUpdatesUI;Restore-PMMPendingNxmUI\s*\r?\n\s*try\{Update-PMMGuidedActionState\}') 'Updates does not refresh ColorFlow after its controls are initialized.'
'Startup Updates order regression: PASS'