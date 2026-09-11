param([ValidateSet('en','es')][string]$Language='en')
$ErrorActionPreference='Stop'
$repo=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$Script:Root=Join-Path $repo 'PMM'
function L($En,$Es){if($Language -eq 'es'){$Es}else{$En}}
Add-Type -AssemblyName PresentationFramework,PresentationCore,WindowsBase
[xml]$xml=[IO.File]::ReadAllText((Join-Path $Script:Root ('Resources/UI/MainWindow.'+$Language+'.xaml')))
$r=[Xml.XmlNodeReader]::new($xml);try{$Window=[Windows.Markup.XamlReader]::Load($r)}finally{$r.Dispose()}
. (Join-Path $Script:Root 'Modules/Shared/Dialogs.ps1')
. (Join-Path $Script:Root 'Modules/Unreal/Setup.Tutorial.UI.ps1')
$Script:factory=${function:New-PMMThemedDialog};$Script:checked=$false
function New-PMMThemedDialog($Title){
    $v=& $Script:factory $Title
    $v.window.Add_ContentRendered({
        param($sender,$args)
        try{
            $layout=$sender.Content;$actions=$layout.Children[0];$body=$layout.Children[1].Content
            $viewer=$body.Children[1]
            $range=[Windows.Documents.TextRange]::new($viewer.Document.ContentStart,$viewer.Document.ContentEnd)
            if($range.Text -notmatch '5.1.1' -or $range.Text -notmatch '14.38' -or $range.Text -notmatch 'Restore-OfflineBackup' -or $viewer.Document.Blocks.Count -lt 30){throw 'Incomplete tutorial'}
            $expected=L 'Decide whether' 'Decide si'
            if($range.Text -notmatch $expected){throw 'Wrong language'}
            $sender.UpdateLayout()
            $bitmap=[Windows.Media.Imaging.RenderTargetBitmap]::new([int]$sender.ActualWidth,[int]$sender.ActualHeight,96,96,[Windows.Media.PixelFormats]::Pbgra32);$bitmap.Render($sender)
            $encoder=[Windows.Media.Imaging.PngBitmapEncoder]::new();$encoder.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($bitmap))
            $out=Join-Path $repo ('Development/TestResults/setup-tutorial-'+$Language+'.png');$s=[IO.File]::Create($out);try{$encoder.Save($s)}finally{$s.Dispose()}
            $Script:checked=$true
            $actions.Children[0].RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Button]::ClickEvent))
        }catch{$Script:failure=$_;$sender.Close()}
    })
    return $v
}
Show-PMMSetupTutorial
if(Get-Variable failure -Scope Script -ErrorAction SilentlyContinue){throw $Script:failure}
if(-not $Script:checked){throw 'Tutorial did not render'}
$Window.Close()
'TUTORIAL_UI_OK: '+$Language+' common dialog, complete content, scrolling, close'
