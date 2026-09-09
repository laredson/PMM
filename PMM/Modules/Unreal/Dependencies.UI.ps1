. (Join-Path $PSScriptRoot 'Setup.Tutorial.UI.ps1')
. (Join-Path $PSScriptRoot 'Dependency.Locations.UI.ps1')

. (Join-Path $PSScriptRoot 'Dependencies.Service.ps1')
function Start-PMMDependencyScan {
    $id=[guid]::NewGuid().ToString('N')
    $path=Get-PMMDependencyJobPath $id
    Write-PMMAIIOJsonAtomic $path @{id=$id;operation='scan';status='QUEUED';cancel=$false;message='Detecting installed components'} 6
    Start-PMMDependencyWorker $id
    $Script:PMMDependencyScan=$id
}
function Show-PMMInstallConsent($Job){
    $v=New-PMMThemedDialog (L 'Install modding tools' 'Instalar herramientas de modding')
    $card=[Windows.Controls.Border]::new();$card.Padding=[Windows.Thickness]::new(16);$card.CornerRadius=[Windows.CornerRadius]::new(7);$card.BorderThickness=[Windows.Thickness]::new(1)
    $card.SetResourceReference([Windows.Controls.Border]::BackgroundProperty,'CardBackground');$card.SetResourceReference([Windows.Controls.Border]::BorderBrushProperty,'CardBorder')
    $content=[Windows.Controls.StackPanel]::new();$card.Child=$content;[void]$v.body.Children.Add($card)
    $label=[Windows.Controls.TextBlock]::new();$label.TextWrapping='Wrap'
    $names=@(Get-PMMDependencyDefinitions|Where-Object{$Job.component -eq 'all' -or $_.id -eq $Job.component}|ForEach-Object{$_.name+' '+$_.version})
    $label.Text=(L 'PMM proposes installing: ' 'PMM propone instalar: ')+($names -join ', ')
    [void]$content.Children.Add($label)
    $all=[Windows.Controls.RadioButton]::new();$all.Content=L 'Install everything needed without asking again' 'Instalar todo lo necesario sin volver a preguntar';$all.GroupName='Permission';$all.IsChecked=$true;$all.Margin=[Windows.Thickness]::new(0,18,0,8)
    $ask=[Windows.Controls.RadioButton]::new();$ask.Content=L 'Ask before each installation' 'Preguntar en cada instalacion';$ask.GroupName='Permission'
    [void]$content.Children.Add($all);[void]$content.Children.Add($ask)
    $hint=[Windows.Controls.TextBlock]::new();$hint.TextWrapping='Wrap';$hint.Margin=[Windows.Thickness]::new(0,16,0,0)
    $hint.Text=L 'Only the PMM dependency catalog is covered. Official account, license and Windows prompts remain. You can revoke this permission in Settings.' 'Solo se autoriza el catalogo de dependencias PMM. Se conservan los pasos de cuenta, licencia y Windows. Puedes revocar el permiso en Settings.'
    [void]$content.Children.Add($hint)
    $state=@{accepted=$false;mode='ask';window=$v.window;all=$all}
    $cancel=[Windows.Controls.Button]::new();$cancel.Content=L 'Cancel' 'Cancelar';$cancel.MinWidth=110;$cancel.IsCancel=$true
    $ok=[Windows.Controls.Button]::new();$ok.Content=L 'Accept' 'Aceptar';$ok.MinWidth=110;$ok.Margin=[Windows.Thickness]::new(8,0,0,0)
    $cancel.Add_Click({$state.window.Close()}.GetNewClosure())
    $ok.Add_Click({$state.accepted=$true;$state.mode=if($state.all.IsChecked){'automatic'}else{'ask'};$state.window.Close()}.GetNewClosure())
    [void]$v.actions.Children.Add($cancel);[void]$v.actions.Children.Add($ok)
    [void]$v.window.ShowDialog()
    return $state
}
function New-PMMDependencyPanel {
    $scroll=[Windows.Controls.ScrollViewer]::new();$scroll.VerticalScrollBarVisibility='Auto'
    $panel=[Windows.Controls.StackPanel]::new();$panel.Margin=[Windows.Thickness]::new(16);$scroll.Content=$panel
    $title=[Windows.Controls.TextBlock]::new();$title.Text=L 'Optional modding tools' 'Herramientas opcionales de modding';$title.FontSize=22;$title.Margin=[Windows.Thickness]::new(0,0,0,14);[void]$panel.Children.Add($title)
    $tutorial=[Windows.Controls.Button]::new();$tutorial.Content=L 'Installation tutorial' 'Tutorial de instalacion';$tutorial.HorizontalAlignment='Left';$tutorial.Margin=[Windows.Thickness]::new(0,0,0,14)
    $tutorial.Add_Click({try{Show-PMMSetupTutorial}catch{Handle-UIError $_ 'Tutorial'}});[void]$panel.Children.Add($tutorial)
    $guide=[Windows.Controls.TextBlock]::new();$guide.TextWrapping='Wrap';$guide.Margin=[Windows.Thickness]::new(0,0,0,14)
    $guide.Text=L 'Unreal requires version 5.1.1 for the supported Palworld kit. PMM opens Epic Launcher; in Unreal Engine > Library, add/select 5.1.1 manually, then Install. The launcher may suggest a newer version. Quixel Bridge is optional and is not required by PMM.' 'Unreal requiere la version 5.1.1 para el kit de Palworld compatible. PMM abre Epic Launcher; en Unreal Engine > Biblioteca, agrega/selecciona manualmente 5.1.1 y pulsa Instalar. El launcher puede proponer una version mas reciente. Quixel Bridge es opcional y PMM no lo necesita.'
    [void]$panel.Children.Add($guide)
    $offline=[Windows.Controls.TextBlock]::new();$offline.TextWrapping='Wrap';$offline.Margin=[Windows.Thickness]::new(0,0,0,8)
    $offline.Text=L 'Wwise 2021.1.11: PMM detects the installed SDK and offline downloads separately. Downloading an offline package does not install the SDK. Use Install / complete to open the official installer, or Locate to select an existing folder or executable. The Unreal integration is a separate package.' 'Wwise 2021.1.11: PMM distingue el SDK instalado del paquete offline descargado. Descargar el paquete no instala el SDK. Usa Instalar / completar para abrir el instalador oficial, o Localizar para elegir una carpeta o ejecutable existente. La integracion Unreal es un paquete separado.'

    [void]$panel.Children.Add($offline)
    $offlineButton=[Windows.Controls.Button]::new();$offlineButton.Content=L 'Open Wwise offline folder' 'Abrir carpeta offline de Wwise';$offlineButton.HorizontalAlignment='Left';$offlineButton.Margin=[Windows.Thickness]::new(0,0,0,14)
    $offlineButton.Add_Click({try{Open-PMMWwiseOfflineFolder}catch{Handle-UIError $_ 'Wwise offline'}})
    [void]$panel.Children.Add($offlineButton)
    $integrationHelp=[Windows.Controls.TextBlock]::new();$integrationHelp.TextWrapping='Wrap';$integrationHelp.Margin=[Windows.Thickness]::new(0,0,0,8)
    $integrationHelp.Text=L 'Wwise Unreal integration: in Audiokinetic Launcher, open Unreal Engine > Download > Offline integration files, choose 2021.1.11 and save in the integration folder below. PMM detects Unreal.5.0.tar.xz automatically; Locate also accepts a download saved elsewhere.' 'Integracion Wwise Unreal: en Audiokinetic Launcher abre Unreal Engine > Download > Offline integration files, elige 2021.1.11 y guarda en la carpeta de integracion de abajo. PMM detecta Unreal.5.0.tar.xz automaticamente; Localizar permite elegir otra ubicacion.'
    [void]$panel.Children.Add($integrationHelp)
    $integrationFolder=[Windows.Controls.Button]::new();$integrationFolder.Content=L 'Open integration download folder' 'Abrir carpeta de descarga de integracion';$integrationFolder.HorizontalAlignment='Left';$integrationFolder.Margin=[Windows.Thickness]::new(0,0,0,14)
    $integrationFolder.Add_Click({try{Open-PMMWwiseIntegrationDownloadFolder}catch{Handle-UIError $_ 'Wwise integration'}});[void]$panel.Children.Add($integrationFolder)
    $Script:PMMDependencySelectedJob=''
    $Script:PMMDependencyLabels=@{}
    foreach($d in Get-PMMDependencyDefinitions){
        $row=[Windows.Controls.DockPanel]::new();$row.Margin=[Windows.Thickness]::new(0,5,0,5)
        $button=[Windows.Controls.Button]::new();$button.Content=L 'Install / complete' 'Instalar / completar';$button.Tag=$d.id;$button.MinWidth=155
        [Windows.Controls.DockPanel]::SetDock($button,'Right');[void]$row.Children.Add($button)
        if($d.id -in @('unreal','wwise','wwiseintegration')){
            $locate=[Windows.Controls.Button]::new();$locate.Content=L 'Locate...' 'Localizar...';$locate.Tag=$d.id;$locate.Margin=[Windows.Thickness]::new(8,0,8,0)
            [Windows.Controls.DockPanel]::SetDock($locate,'Right');[void]$row.Children.Add($locate)
            $locate.Add_Click({param($sender,$args)
                $Script:PMMDependencyModal=$true
                try{$result=Show-PMMDependencyLocation ([string]$sender.Tag);if($result){$Script:PMMDependencySelectedJob='';Start-PMMDependencyScan}}catch{Handle-UIError $_ 'Locate'}finally{$Script:PMMDependencyModal=$false}
            })
        }
        $label=[Windows.Controls.TextBlock]::new();$label.Text=$d.name+' ('+$d.version+')';$label.TextWrapping='Wrap';$label.VerticalAlignment='Center';[void]$row.Children.Add($label)
        $Script:PMMDependencyLabels[$d.id]=@{label=$label;button=$button;name=$d.name;version=$d.version}
        $button.Add_Click({param($sender,$eventArgs)
            try{if($sender.Content -eq (L 'Open' 'Abrir')){Open-PMMDependencyComponent ([string]$sender.Tag);return};$case=Get-PMMAIIOSelectedCase;$caseId='';if($case){$caseId=$case.CaseId};$job=Request-PMMDependencyInstall ([string]$sender.Tag) $caseId;$Script:PMMDependencySelectedJob=$job.id;$Script:PMMDependencyStatus.Text=$job.status}catch{Handle-UIError $_ 'Dependencies'}
        })
        [void]$panel.Children.Add($row)
    }
    $Script:PMMDependencyStatus=[Windows.Controls.TextBlock]::new();$Script:PMMDependencyStatus.TextWrapping='Wrap';$Script:PMMDependencyStatus.Margin=[Windows.Thickness]::new(0,16,0,0);[void]$panel.Children.Add($Script:PMMDependencyStatus)
    $buttons=[Windows.Controls.WrapPanel]::new()
    foreach($entry in @(@('detect',(L 'Detect installed tools' 'Detectar herramientas instaladas')),@('all',(L 'Install missing components' 'Instalar componentes pendientes')),@('revoke',(L 'Ask before installing again' 'Volver a preguntar antes de instalar')),@('cancel',(L 'Cancel pending installations' 'Cancelar instalaciones pendientes')))){
        $b=[Windows.Controls.Button]::new();$b.Content=$entry[1];$b.Tag=$entry[0];$b.Margin=[Windows.Thickness]::new(0,10,8,0)
        $b.Add_Click({param($sender,$eventArgs)
            try{
                switch([string]$sender.Tag){
                    'detect' {$Script:PMMDependencySelectedJob='';Start-PMMDependencyScan}
                    'all' {$requested=Request-PMMDependencyInstall 'all';$Script:PMMDependencySelectedJob=$requested.id}
                    'revoke' {Set-PMMDependencyPolicy 'ask';$Script:PMMDependencyStatus.Text=L 'Installation permission revoked.' 'Permiso de instalacion revocado.'}
                    'cancel' {foreach($f in @(Get-ChildItem (Join-Path (Get-PMMDependencyRoot) 'Jobs') -Filter *.json -ErrorAction SilentlyContinue)){$j=Read-PMMMCPJson $f.FullName;if($j.operation -eq 'install' -and $j.status -in @('QUEUED','RUNNING','AWAITING_CONSENT','WAITING_EXTERNAL')){Cancel-PMMDependencyInstall $j.id|Out-Null}}}
                }
            }catch{Handle-UIError $_ 'Dependencies'}
        })
        [void]$buttons.Children.Add($b)
    }
    [void]$panel.Children.Add($buttons)
    $Script:PMMDependencyModal=$false;$Script:PMMDependencyScan=''
    Start-PMMDependencyScan
    $Script:PMMDependencyTimer=[Windows.Threading.DispatcherTimer]::new()
    $Script:PMMDependencyTimer.Interval=[TimeSpan]::FromSeconds(2)
    $Script:PMMDependencyTimer.Add_Tick({Update-PMMDependencyPanel})
    $Script:PMMDependencyTimer.Start()
    $Window.Add_Closed({$Script:PMMDependencyTimer.Stop()})
    return $scroll
}
function Update-PMMDependencyPanel {
    if($Script:PMMDependencyModal){return}
    try{
        $catalog=Join-Path (Get-PMMDependencyRoot) 'catalog.json'
        if(Test-Path $catalog){
            $c=Read-PMMMCPJson $catalog
            foreach($r in $c.components){
                if(-not $Script:PMMDependencyLabels.ContainsKey($r.id)){continue}
                $view=$Script:PMMDependencyLabels[$r.id]
                $statusText=switch($r.status){
                    'OFFLINE_READY' {L 'Offline package ready; SDK not installed' 'Paquete offline preparado; SDK pendiente de instalar'}
                    'OFFLINE_INVALID' {L 'Offline package rejected; inspect location' 'Paquete offline rechazado; revisa su ubicacion'}
                    'MISSING' {L 'Not detected' 'No detectado'}
                    'DETECTED' {L 'Detected' 'Detectado'}
                    default {$r.status}
                }
                $view.label.Text=$view.name+' '+$view.version+' - '+$statusText
                if($r.PSObject.Properties['path']){$view.label.ToolTip=$r.path}

                $view.button.Content=if($r.installed){L 'Open' 'Abrir'}else{L 'Install / complete' 'Instalar / completar'}
                $view.button.IsEnabled=$true
            }
        }
        $scan=Read-PMMMCPJson (Get-PMMDependencyJobPath $Script:PMMDependencyScan)
        if($scan.status -notin @('QUEUED','RUNNING') -and ((-not(Test-Path $catalog)) -or (Get-Item $catalog).LastWriteTimeUtc -lt [DateTime]::UtcNow.AddSeconds(-30))){Start-PMMDependencyScan}
        $jobs=@(Get-ChildItem (Join-Path (Get-PMMDependencyRoot) 'Jobs') -Filter *.json|Sort-Object LastWriteTime -Descending|ForEach-Object{Read-PMMMCPJson $_.FullName}|Where-Object{$_.operation -eq 'install'})
        $selected=@($jobs|Where-Object{$_.id -eq $Script:PMMDependencySelectedJob}|Select-Object -First 1)
        $pending=@($jobs|Where-Object{$_.status -eq 'AWAITING_CONSENT'})
        if($pending.Count){$jobs=$pending}elseif($selected.Count){$jobs=$selected}else{
            $active=@($jobs|Where-Object{$_.status -in @('RUNNING','QUEUED')}|Select-Object -First 1)
            if($active.Count){$jobs=$active}else{$jobs=@($jobs|Select-Object -First 1)}
        }
        foreach($job in $jobs){
            if($job.status -eq 'AWAITING_CONSENT'){
                $Script:PMMDependencyModal=$true
                try{$decision=Show-PMMInstallConsent $job;if($decision.accepted){Approve-PMMDependencyInstall $job.id $decision.mode}else{Cancel-PMMDependencyInstall $job.id|Out-Null}}finally{$Script:PMMDependencyModal=$false}
                break
            }
            $Script:PMMDependencyStatus.Text=$job.status+' - '+$job.message
            break
        }
    }catch{$Script:PMMDependencyStatus.Text=$_.Exception.Message}
}
