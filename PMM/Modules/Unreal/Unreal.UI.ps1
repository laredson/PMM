. (Join-Path $PSScriptRoot 'Unreal.Install.ps1')
function Update-PMMUnrealUI {
    $label=$Window.FindName('TxtUnrealStatus')
    if(-not $label){return}
    try{
        $cfg=Get-PMMUnrealSettings
        if(-not $cfg.enabled){$label.Text=(L 'Optional Unreal integration is off. AssetReader and PMM research remain available.' 'La integracion opcional con Unreal esta desactivada. AssetReader y las consultas PMM siguen disponibles.');return}
        $e=Get-PMMUnrealEnvironment
        $label.Text=if($e.readyToPrepare){(L 'Dependencies detected. PMM can prepare and verify a case project.' 'Dependencias detectadas. PMM puede preparar y verificar el proyecto del caso.')}else{'Pending: '+($e.missing -join '; ')}
        $case=$null
        if(Get-Command Get-PMMAIIOSelectedCase -ErrorAction SilentlyContinue){$case=Get-PMMAIIOSelectedCase}
        if($case -and $e.readyToPrepare){
            if(-not(Get-Variable PMMUnrealAutoAttempts -Scope Script -ErrorAction SilentlyContinue)){$Script:PMMUnrealAutoAttempts=@{}}
            $key=$case.CaseId+'|'+$e.engineRoot+'|'+$e.engineVersion+'|'+$e.kitCommit
            $verified=Join-Path (Get-PMMUnrealProject $case.CaseId) 'verified.json'
            $matches=$false
            if(Test-Path $verified){$v=Read-PMMMCPJson $verified;$matches=($v.engineRoot -ieq $e.engineRoot -and $v.engineVersion -eq $e.engineVersion -and $v.kitCommit -eq $e.kitCommit)}
            if($matches){$label.Text=(L 'Case project verified. Embedded Python and texture operations are ready.' 'Proyecto del caso verificado. Python integrado y las operaciones de textura estan disponibles.')}
            elseif(-not $Script:PMMUnrealAutoAttempts.ContainsKey($key)){
                $Script:PMMUnrealAutoAttempts[$key]=Start-PMMUnrealJob 'prepare' ([pscustomobject]@{caseId=$case.CaseId})
            }
            if($Script:PMMUnrealAutoAttempts.ContainsKey($key)){
                $id=$Script:PMMUnrealAutoAttempts[$key].jobId
                $state=Get-PMMUnrealJob ([pscustomobject]@{caseId=$case.CaseId;jobId=$id;waitSeconds=0})
                $label.Text=$state.status+' - '+$state.message
            }
        }
    }catch{$label.Text=$_.Exception.Message}
}
function Select-PMMUnrealLocation([string]$Kind) {
    $cfg=Get-PMMUnrealSettings
    if($Kind -eq 'wwiseIntegration'){
        $dialog=[Microsoft.Win32.OpenFileDialog]::new();$dialog.Filter='Wwise offline integration|Unreal.5.0.tar.xz;Wwise.uplugin'
        if($dialog.ShowDialog() -ne $true){return}
        $value=$dialog.FileName
        if([IO.Path]::GetExtension($value) -eq '.uplugin'){$value=Split-Path $value -Parent}
    }else{
        Add-Type -AssemblyName System.Windows.Forms
        $dialog=[Windows.Forms.FolderBrowserDialog]::new()
        try{if($dialog.ShowDialog() -ne 'OK'){return};$value=$dialog.SelectedPath}finally{$dialog.Dispose()}
    }
    [void](Resolve-PMMMCPPath $value);$cfg.$Kind=$value
    Save-PMMUnrealSettings $cfg
    $Script:PMMUnrealAutoAttempts=@{}
    Update-PMMUnrealUI
}
function Open-PMMUnrealCandidatesUI {
    $case=Get-PMMAIIOSelectedCase
    if(-not $case){throw 'Select a case first.'}
    $items=@(Get-PMMUnrealCandidates $case.CaseId)
    if(-not $items.Count){throw 'This case has no cooked candidate yet.'}
    $dir=Resolve-PMMMCPPath $Script:Root ('Workspace\AIIO\Cases\'+$case.CaseId+'\generated')
    Start-Process explorer.exe -ArgumentList ('"'+$dir+'"')
}
$Window.FindName('BtnUnrealPrepare').Add_Click({
    try{
        $cfg=Get-PMMUnrealSettings;$cfg.enabled=$true;Save-PMMUnrealSettings $cfg;Set-PMMMCPEnabled $true
        $Script:PMMUnrealAutoAttempts=@{}
        Update-PMMUnrealUI
    }catch{Handle-UIError $_ 'Unreal'}
})
$Window.FindName('BtnUnrealDisable').Add_Click({try{$cfg=Get-PMMUnrealSettings;$cfg.enabled=$false;Save-PMMUnrealSettings $cfg;Update-PMMUnrealUI}catch{Handle-UIError $_ 'Unreal'}})
$Window.FindName('BtnUnrealInstall').Add_Click({try{Open-PMMUnrealInstaller}catch{Handle-UIError $_ 'Unreal'}})
$Window.FindName('BtnUnrealRunInstaller').Add_Click({
    try{
        $d=[Microsoft.Win32.OpenFileDialog]::new();$d.Filter='Official Epic Games Launcher installer|*.msi'
        if($d.ShowDialog() -eq $true){
            $p=Assert-PMMEpicInstaller $d.FileName
            Start-Process (Join-Path $env:SystemRoot 'System32\msiexec.exe') -ArgumentList ('/i '+(ConvertTo-PMMNativeArgument $p)) -WindowStyle Normal
        }
    }catch{Handle-UIError $_ 'Installer'}
})
$Window.FindName('BtnUnrealEnginePath').Add_Click({try{Select-PMMUnrealLocation 'engineRoot'}catch{Handle-UIError $_ 'Unreal'}})
$Window.FindName('BtnUnrealWwiseSdk').Add_Click({try{Select-PMMUnrealLocation 'wwiseSdk'}catch{Handle-UIError $_ 'Unreal'}})
$Window.FindName('BtnUnrealWwiseIntegration').Add_Click({try{Select-PMMUnrealLocation 'wwiseIntegration'}catch{Handle-UIError $_ 'Unreal'}})
$Window.FindName('BtnUnrealGuide').Add_Click({Start-Process (Get-PMMUnrealProfile).urls.guide})
$Window.FindName('BtnUnrealCandidates').Add_Click({try{Open-PMMUnrealCandidatesUI}catch{Handle-UIError $_ 'Candidate'}})
Update-PMMUnrealUI
$Script:PMMUnrealTimer=[Windows.Threading.DispatcherTimer]::new([Windows.Threading.DispatcherPriority]::Background)
$Script:PMMUnrealTimer.Interval=[TimeSpan]::FromSeconds(20)
$Script:PMMUnrealTimer.Add_Tick({Update-PMMUnrealUI})
$Script:PMMUnrealTimer.Start()
$Window.Add_Closed({$Script:PMMUnrealTimer.Stop()})
