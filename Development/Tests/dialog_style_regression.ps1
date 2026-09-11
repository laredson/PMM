
param([string]$Repository=([IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))))
$ErrorActionPreference='Stop'
Add-Type -AssemblyName PresentationFramework,PresentationCore,WindowsBase,System.Windows.Forms
function L($en,$es){$en}
. (Join-Path $Repository 'PMM/Modules/Shared/Dialogs.ps1')
[xml]$xml=[IO.File]::ReadAllText((Join-Path $Repository 'PMM/Resources/UI/MainWindow.xaml'))
$r=[Xml.XmlNodeReader]::new($xml);$Window=[Windows.Markup.XamlReader]::Load($r);$r.Close()
$view=New-PMMThemedDialog 'Fixture'
if($view.window.Background.ToString() -ne $Window.FindResource('AppBackground').ToString()){throw 'Background does not match'}
if($view.window.FontFamily.Source -ne 'Segoe UI'){throw 'Font mismatch'}
$view.window.Close()
foreach($buttons in @('YesNo','YesNoCancel','OKCancel','OK')){
    $script:choice=$buttons
    $timer=[Windows.Threading.DispatcherTimer]::new();$timer.Interval=[TimeSpan]::FromMilliseconds(80)
    $timer.Add_Tick({
        $this.Stop()
        foreach($w in @([Windows.Application]::Current.Windows)){if($w.Title -eq 'Dialog fixture'){$w.Close()}}
    })
    if(-not [Windows.Application]::Current){[void][Windows.Application]::new();[Windows.Application]::Current.ShutdownMode='OnExplicitShutdown'}
    $timer.Start()
    $actual=Show-PMMThemedMessage @('A decision','Dialog fixture',$buttons)
    $expected=if($buttons -eq 'YesNo'){'No'}elseif($buttons -eq 'OK'){'OK'}else{'Cancel'}
    if($actual.ToString() -ne $expected){throw "Dismiss returned $actual for $buttons"}
}
$Window.Close()
'DIALOG_STYLE_AND_DISMISS_PASS'
