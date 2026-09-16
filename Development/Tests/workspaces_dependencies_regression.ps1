param([string]$Repository=([IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))),[ValidateSet('en','es')][string]$Language='en',[switch]$Render,[string]$VerifyPersistedRoot='')
Set-StrictMode -Version 2.0;$ErrorActionPreference='Stop'
if($VerifyPersistedRoot){
    $Script:Root=$VerifyPersistedRoot
    . (Join-Path $Repository 'PMM\Modules\Shared\Paths.ps1')
    Initialize-PMMPaths $Script:Root|Out-Null
    . (Join-Path $Repository 'PMM\Modules\AIIO\AIIO.CaseWorkspaceService.ps1')
    $cases=@(Get-PMMAIIOCases)
    if($cases.Count -ne 8 -or @($cases.CaseId|Select-Object -Unique).Count -ne 8){throw 'Cases lost after process restart'}
    foreach($case in $cases){if(-not @(Get-PMMAIIOCaseSteps $case.CaseId).Count){throw 'History lost after process restart'}}
    'RESTART_CASES_OK';exit 0
}
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
function L([string]$English,[string]$Spanish){if($Language -eq 'es'){return $Spanish};return $English}
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
foreach($preview in @('AIIO.CaseWorkspace.UI.Preview2.ps1','AIIO.CaseWorkspace.UI.Preview3.ps1','AIIO.CaseWorkspace.UI.Preview4.ps1','AIIO.CaseWorkspace.Preview5.ps1','AIIO.CaseWorkspace.UI.Preview6.ps1')){. (Join-Path $Script:Root ('Modules\AIIO\'+$preview))}
. (Join-Path $Script:Root 'Modules\Shared\Dialogs.ps1')
. (Join-Path $Script:Root 'Modules\Unreal\Dependencies.UI.ps1')
. (Join-Path $Script:Root 'Modules\AIIO\AIIO.Workspaces.UI.ps1')
# Load the current Desktop-options extension that production loads through the UI module registry.
. (Join-Path $Script:Root 'Modules\Presentation\Desktop.Options.UI.ps1')
# This regression validates PMM workspace/dependency behavior, not the runner's installed AppX inventory.
# Keep Desktop package discovery deterministic so hosted-runner software cannot change the result.
function Get-PMMDesktopPackages { return @() }
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

    # Real runtime chain: Preview3 grid + Preview4 save + section filtering.
    $c2=New-PMMAIIOCase -Title $c.Title -Type NEW_MOD
    $c3=New-PMMAIIOCase -Title $c.Title -Type NEW_MOD
    Refresh-PMMAIIOCaseList $c.CaseId
    $grid=Get-PMMAIIOCaseControl 'DgCases'
    if($grid.Items.Count -ne 3){throw 'Multiple cases collapsed into one row'}
    foreach($row in $grid.Items){if($row -is [array] -or -not(Test-PMMAIIOCaseId $row.CaseId)){throw 'Invalid case row'}}
    (Get-PMMAIIOCaseControl 'TxtDescription').Text='Keep the first draft'
    $Script:FixtureDialog=[pscustomobject]@{Title='Fourth';Type='NEW_MOD';Description='Independent'}
    function Show-PMMAIIONewCaseDialog {return $Script:FixtureDialog}
    Invoke-PMMNewCaseUI
    $fourth=Get-PMMAIIOSelectedCase
    if($grid.Items.Count -ne 4 -or $fourth.Title -ne 'Fourth'){throw 'New case not selected'}
    if((Get-PMMAIIOCase $c.CaseId).Description -ne 'Keep the first draft'){throw 'Previous draft lost'}
    if((Get-PMMAIIOCase $c2.CaseId).Description){throw 'Another case was overwritten'}
    $before=(Get-PMMAIIOCases).Count;$Script:FixtureDialog=$null;Invoke-PMMNewCaseUI
    if((Get-PMMAIIOCases).Count -ne $before){throw 'Cancel created a case'}
    # A view for A must never save into B, nor save during a refresh.
    $Script:PMMAIIOCaseSelectedId=$c2.CaseId
    if(Save-PMMAIIOCaseEditor){throw 'Mismatched editor identity was saved'}
    Refresh-PMMAIIOCaseList $fourth.CaseId
    $Script:PMMCaseRefreshing=$true
    try{if(Save-PMMAIIOCaseEditor){throw 'Refresh saved the editor'}}finally{$Script:PMMCaseRefreshing=$false}
    $Script:FixtureDialog=[pscustomobject]@{Title='Research from creation';Type='UNDEFINED';Description='Routed'}
    Invoke-PMMNewCaseUI
    if($Script:PMMCaseArea -ne 'HELP' -or (Get-PMMAIIOSelectedCase).Title -ne 'Research from creation'){throw 'New case type did not navigate'}
    Switch-PMMCaseArea 'CREATE'
    if($Script:PMMAIIOCaseSelectedId -ne $fourth.CaseId){throw 'Section selection lost'}
    $rejected=$false;try{New-PMMAIIOCase -CaseId $c.CaseId -Title 'Overwrite'|Out-Null}catch{$rejected=$true}
    if(-not $rejected -or (Get-PMMAIIOCase $c.CaseId).Title -ne $c.Title){throw 'Duplicate ID allowed overwrite'}

    $Script:SavedRows=${function:Get-PMMAIIOCaseRows}
    function Get-PMMAIIOCaseRows {return @()}
    Refresh-PMMAIIOCaseList
    if($grid.Items.Count -ne 0 -or $Script:PMMEditorCaseId -or (Save-PMMAIIOCaseEditor)){throw 'Empty list retained editable identity'}
    ${function:Get-PMMAIIOCaseRows}=$Script:SavedRows
    Refresh-PMMAIIOCaseList $fourth.CaseId
    $timer=$Script:PMMDependencyTimer;Initialize-PMMWorkspaces
    if($Script:PMMDependencyTimer -ne $timer){throw 'Duplicate timer after initialization'}
    & (Join-Path $env:WINDIR 'System32\WindowsPowerShell\v1.0\powershell.exe') -NoProfile -File $PSCommandPath -VerifyPersistedRoot $Script:Root
    if($LASTEXITCODE){throw 'Restart verification failed'}

    $binding=New-PMMDesktopBinding
    [void](Confirm-PMMDesktopBinding ([pscustomobject]@{nonce=$binding.nonce}))
    $Script:FixtureDialog=[pscustomobject]@{Title='Desktop case';Type='NEW_MOD';Description='Plan first'}
    Invoke-PMMNewCaseUI
    $desktopCase=Get-PMMAIIOSelectedCase
    if($desktopCase.AIClient -ne 'CODEX_DESKTOP' -or $desktopCase.Transport -ne 'MCP'){throw 'New case does not default to Codex Desktop MCP'}
    if((Get-PMMAIIOCaseControl 'BtnHandoff').Content -ne (L 'Open in Codex Desktop' 'Abrir en Codex Desktop')){throw 'Wrong Codex Desktop handoff label'}
    (Get-PMMAIIOCaseControl 'CmbClient').SelectedValue='EXTERNAL'
    [void](Save-PMMAIIOCaseEditor);Refresh-PMMAIIOCaseList $desktopCase.CaseId
    if((Get-PMMAIIOSelectedCase).AIClient -ne 'EXTERNAL'){throw 'Client selector did not persist'}
    if((Get-PMMAIIOCase $c.CaseId).PSObject.Properties['AIClient']){throw 'Pairing changed old case'}
    $ids=@($Script:PMMSettingsTabs.Items|ForEach-Object {$_.Tag})
    if(($ids -join ',') -ne 'GENERAL,AI,INSTALLATIONS,MERGE,CREATE,HELP'){throw 'Wrong Settings organization'}
    Open-PMMSettings 'TabModdingTools'
    if($Script:PMMSettingsTabs.SelectedItem.Tag -ne 'INSTALLATIONS'){throw 'Legacy tools navigation broken'}
    if($Script:PMMSettingsTabs.Items.Count -ne 6){throw 'Duplicate Settings panel'}
    # Exercise the actual modal, with a synthetic accept/cancel click once loaded.
    $Script:DialogChoice='automatic';$Script:DialogAccept=$true
    $Script:MakeDialog=${function:New-PMMThemedDialog}
    function New-PMMThemedDialog([string]$Title){
        $v=& $Script:MakeDialog $Title
        $choice=$Script:DialogChoice;$accept=$Script:DialogAccept
        $v.window.Add_ContentRendered({
            $radio=$v.body.Children | Where-Object {$_.Name -eq $(if($choice -eq 'automatic'){'Automatic'}else{'Ask'})} | Select-Object -First 1
            $radio.IsChecked=$true
            if($accept){($v.actions.Children|Where-Object {$_.Name -eq 'Accept'}).RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Button]::ClickEvent))}else{$v.window.Close()}
        }.GetNewClosure())
        return $v
    }
    Show-PMMDependencyPermissions
    if((Get-PMMDependencyPolicy).mode -ne 'automatic'){throw 'Could not restore automatic permission'}
    $Script:DialogChoice='ask';$Script:DialogAccept=$false;Show-PMMDependencyPermissions
    if((Get-PMMDependencyPolicy).mode -ne 'automatic'){throw 'Cancel changed permission'}
    $Script:DialogAccept=$true;Show-PMMDependencyPermissions
    if((Get-PMMDependencyPolicy).mode -ne 'ask'){throw 'Could not revoke automatic permission'}
    # Pending consent is handled even when the installations panel is hidden.
    $job=Request-PMMDependencyInstall 'wwise' $fourth.CaseId
    function Get-PMMDependencySnapshot {return [pscustomobject]@{jobs=@((Read-PMMMCPJson (Get-PMMDependencyJobPath $job.id)));catalog=$null}}
    function Show-PMMInstallConsent($request){$Script:ConsentSeen=$request.id;return @{accepted=$false;mode='ask'}}
    Open-PMMSettings 'GENERAL'
    Update-PMMDependencyPanel
    if($Script:ConsentSeen -ne $job.id -or (Get-PMMDependencyJob $job.id).status -ne 'CANCELLED'){throw 'Hidden panel did not handle consent'}

    if($Render){
        $Window.WindowState='Normal';$Window.Width=1200;$Window.Height=800
        Open-PMMSettings 'INSTALLATIONS';$Window.Show();$Window.UpdateLayout()
        $bitmap=[Windows.Media.Imaging.RenderTargetBitmap]::new([int]$Window.ActualWidth,[int]$Window.ActualHeight,96,96,[Windows.Media.PixelFormats]::Pbgra32)
        $bitmap.Render($Window);$encoder=[Windows.Media.Imaging.PngBitmapEncoder]::new();$encoder.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($bitmap))
        $image=Join-Path $Script:Root ('settings-'+$Language+'.png');$stream=[IO.File]::Create($image);try{$encoder.Save($stream)}finally{$stream.Dispose()}
        'RENDER: '+$image
        Refresh-PMMAIIOCaseList $desktopCase.CaseId
        $Script:MainTabs.SelectedItem=@($Script:MainTabs.Items|Where-Object {$_.Tag -eq 'CREATE'})[0]
        Switch-PMMCaseArea 'CREATE'
        (Get-PMMAIIOCaseControl 'CmbClient').SelectedValue='CHATGPT';[void](Save-PMMAIIOCaseEditor);Refresh-PMMAIIOCaseList $desktopCase.CaseId;$Window.UpdateLayout()
        $bitmap=[Windows.Media.Imaging.RenderTargetBitmap]::new([int]$Window.ActualWidth,[int]$Window.ActualHeight,96,96,[Windows.Media.PixelFormats]::Pbgra32)
        $bitmap.Render($Window);$encoder=[Windows.Media.Imaging.PngBitmapEncoder]::new();$encoder.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($bitmap))
        $image=Join-Path $Script:Root ('case-'+$Language+'.png');$stream=[IO.File]::Create($image);try{$encoder.Save($stream)}finally{$stream.Dispose()}
        'CASE_RENDER: '+$image
        function New-PMMThemedDialog([string]$Title){
            $v=& $Script:MakeDialog $Title
            $renderPath=Join-Path $Script:Root ('desktop-setup-'+$Language+'.png')
            $v.window.Add_ContentRendered({
                $v.window.UpdateLayout()
                $bitmap=[Windows.Media.Imaging.RenderTargetBitmap]::new([int]$v.window.ActualWidth,[int]$v.window.ActualHeight,96,96,[Windows.Media.PixelFormats]::Pbgra32)
                $bitmap.Render($v.window);$encoder=[Windows.Media.Imaging.PngBitmapEncoder]::new();$encoder.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($bitmap))
                $image=$renderPath;$stream=[IO.File]::Create($image);try{$encoder.Save($stream)}finally{$stream.Dispose();$v.window.Close()}
            }.GetNewClosure())
            return $v
        }
        Show-PMMDesktopSetup
        'DESKTOP_RENDER: '+(Join-Path $Script:Root ('desktop-setup-'+$Language+'.png'))
    }
    'CASE_SETTINGS_OK: multiple identical titles, isolated edits, cancel, cross-section routing, collision rejection, settings routes, real permission dialog and hidden consent.'
    'WORKSPACES_OK: six tabs, area classification/selection, consent, idempotence, case ownership and revocation; no installers executed.'
}finally{$Window.Close();if(Get-Variable PMMDependencyTimer -Scope Script -ErrorAction SilentlyContinue){$Script:PMMDependencyTimer.Stop()}}
