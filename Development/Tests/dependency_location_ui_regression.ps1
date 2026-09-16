param([ValidateSet('en','es')][string]$Language='es')
$ErrorActionPreference='Stop'
$repo=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
Add-Type -AssemblyName PresentationFramework,PresentationCore,WindowsBase,System.Windows.Forms
function L($En,$Es){if($Language -eq 'es'){$Es}else{$En}}
[xml]$x=[IO.File]::ReadAllText((Join-Path $repo ('PMM\Resources\UI\MainWindow.'+$Language+'.xaml')))
$r=[Xml.XmlNodeReader]::new($x);try{$Window=[Windows.Markup.XamlReader]::Load($r)}finally{$r.Dispose()}
. (Join-Path $repo 'PMM\Modules\Shared\Dialogs.ps1')
. (Join-Path $repo 'PMM\Modules\Unreal\Dependency.Locations.UI.ps1')
$Script:factory=${function:New-PMMThemedDialog};$Script:checked=$false
function Set-PMMDependencyLocation {throw 'Invalid test location / Ubicacion de prueba incorrecta'}
function New-PMMThemedDialog($Title){
    $v=& $Script:factory $Title
    $v.window.Add_ContentRendered({param($sender,$args)
        try{
            $layout=$sender.Content;$actions=$layout.Children[0];$body=$layout.Children[1].Content
            if($body.Children[3].Children.Count -ne 2){throw 'Missing folder/file selectors'}
            $actions.Children[1].RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Button]::ClickEvent))
            if(-not $sender.IsVisible -or $body.Children[4].Text -notmatch 'Invalid test'){throw 'Validation failure did not remain in dialog'}
            $sender.UpdateLayout()
            $bitmap=[Windows.Media.Imaging.RenderTargetBitmap]::new([int]$sender.ActualWidth,[int]$sender.ActualHeight,96,96,[Windows.Media.PixelFormats]::Pbgra32);$bitmap.Render($sender)
            $encoder=[Windows.Media.Imaging.PngBitmapEncoder]::new();$encoder.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($bitmap))
            $file=Join-Path $repo ('Development\TestResults\dependency-location-'+$Language+'.png');$stream=[IO.File]::Create($file);try{$encoder.Save($stream)}finally{$stream.Dispose()}
            $Script:checked=$true
            $actions.Children[0].RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Button]::ClickEvent))
        }catch{$Script:failure=$_;$sender.Close()}
    });return $v
}
$result=Show-PMMDependencyLocation 'wwise'
if(Get-Variable failure -Scope Script -ErrorAction SilentlyContinue){throw $Script:failure}
if($result -or -not $Script:checked){throw 'Cancellation returned a saved location'}
$Window.Close()
'LOCATION_UI_OK: '+$Language+' themed dialog, folder/file controls, inline validation and cancel.'
