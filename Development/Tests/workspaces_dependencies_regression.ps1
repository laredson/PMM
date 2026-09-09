param([string]$Repository=([IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))),[ValidateSet('en','es')][string]$Language='en')
Set-StrictMode -Version 2.0;$ErrorActionPreference='Stop'
$app=Join-Path $Repository 'PMM'
$Script:Root=Join-Path $Repository ('Development\TestResults\Workspaces-'+[guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($Script:Root)
Copy-Item (Join-Path $app 'Modules') (Join-Path $Script:Root 'Modules') -Recurse
Copy-Item (Join-Path $app 'Resources') (Join-Path $Script:Root 'Resources') -Recurse
. (Join-Path $Script:Root 'Modules\Shared\Paths.ps1')
Initialize-PMMPaths $Script:Root|Out-Null
. (Join-Path $Script:Root 'Modules\Shared\Common.ps1')
. (Join-Path $Script:Root 'Modules\AIIO\AIIO.SessionService.ps1')
. (Join-Path $Script:Root 'Modules\AIIO\AIIO.CaseWorkspaceService.ps1')
. (Join-Path $Script:Root 'Modules\MCP\MCP.Service.ps1')
function Write-PMMLog([string]$Message){}
function L([string]$English,[string]$Spanish){return $English}
function Handle-UIError($Failure,[string]$Title){throw $Failure}
Add-Type -AssemblyName PresentationFramework,PresentationCore,WindowsBase,System.Windows.Forms
$c=New-PMMAIIOCase -Title 'New mod fixture' -Type NEW_MOD
$f=New-PMMAIIOCase -Title 'Fix fixture' -Type FIX_MOD
$m=New-PMMAIIOCase -Title 'Merge fixture' -Type COMPATIBILITY
$h=New-PMMAIIOCase -Title 'Research fixture' -Type UNDEFINED
[xml]$x=[IO.File]::ReadAllText((Join-Path $app ("Resources\UI\MainWindow."+ $Language +".xaml")))
$r=[Xml.XmlNodeReader]::new($x);try{$Window=[Windows.Markup.XamlReader]::Load($r)}finally{$r.Dispose()}
$Script:MainTabs=$Window.FindName('MainTabs');$Script:AIHelpTabs=$Window.FindName('AIHelpTabs');$Script:TabAIHelp=$Window.FindName('TabAIHelp');$Script:TabFixLab=$Window.FindName('TabFixLab')
. (Join-Path $Script:Root 'Modules\AIIO\AIIO.CaseWorkspace.UI.ps1')
. (Join-Path $Script:Root 'Modules\Unreal\Dependencies.UI.ps1')
. (Join-Path $Script:Root 'Modules\AIIO\AIIO.Workspaces.UI.ps1')
try{
    Initialize-PMMWorkspaces
    if($Script:MainTabs.Items.Count -ne 6){throw 'Expected six main sections'}
    foreach($area in @('CREATE','FIX','MERGE','HELP')){
        Switch-PMMCaseArea $area
        $rows=@(Get-PMMAIIOCaseRows)
        if($rows.Count -ne 1){throw ('Area filter failed: '+$area)}
    }
    Switch-PMMCaseArea 'CREATE'
    if($Script:PMMAIIOCaseSelectedId -ne $c.CaseId){throw 'Per-area selection not restored'}
    Set-PMMMCPEnabled $true
    $job=Invoke-PMMMCPTool 'pmm_dependency_install' ([pscustomobject]@{caseId=$c.CaseId;component='unreal'})
    if($job.status -ne 'AWAITING_CONSENT'){throw 'Missing consent gate'}
    $again=Request-PMMDependencyInstall 'unreal' $c.CaseId
    if($again.id -ne $job.id){throw 'Duplicate installation request'}
    $blocked=$false;try{Get-PMMDependencyJob $job.id $f.CaseId|Out-Null}catch{$blocked=$true};if(-not $blocked){throw 'Job ownership not enforced'}
    Cancel-PMMDependencyInstall $job.id|Out-Null
    if((Get-PMMDependencyPolicy).mode -ne 'ask'){throw 'Cancel granted permission'}
    Set-PMMDependencyPolicy 'automatic'
    if((Get-PMMDependencyPolicy).mode -ne 'automatic'){throw 'Permission not persisted'}
    Set-PMMDependencyPolicy 'ask'
    'WORKSPACES_OK: six tabs, area classification/selection, consent, idempotence, case ownership and revocation; no installers executed.'
}finally{$Window.Close();if(Get-Variable PMMDependencyTimer -Scope Script -ErrorAction SilentlyContinue){$Script:PMMDependencyTimer.Stop()}}
