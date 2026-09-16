
$ErrorActionPreference='Stop'
Add-Type -AssemblyName PresentationFramework,PresentationCore,WindowsBase,System.Windows.Forms
function L($en,$es){$es}
function Get-PMMUnrealProfile{return @{kitCommit='e6632458b97af0083eb81715775651b08104ef6a'}}
. ./PMM/Modules/Shared/Dialogs.ps1
. ./PMM/Modules/Unreal/Dependencies.UI.ps1
[void][Windows.Application]::new();[Windows.Application]::Current.ShutdownMode='OnExplicitShutdown'
[xml]$xml=[IO.File]::ReadAllText((Join-Path (Get-Location) 'PMM/Resources/UI/MainWindow.es.xaml'))
$r=[Xml.XmlNodeReader]::new($xml);$Window=[Windows.Markup.XamlReader]::Load($r)
$timer=[Windows.Threading.DispatcherTimer]::new();$timer.Interval=[TimeSpan]::FromMilliseconds(300)
$timer.Add_Tick({
 $this.Stop()
 foreach($w in @([Windows.Application]::Current.Windows)){
  if($w.Title -eq 'Instalar herramientas de modding'){
   $bitmap=[Windows.Media.Imaging.RenderTargetBitmap]::new([int]$w.ActualWidth,[int]$w.ActualHeight,96,96,[Windows.Media.PixelFormats]::Pbgra32)
   $bitmap.Render($w);$encoder=[Windows.Media.Imaging.PngBitmapEncoder]::new();$encoder.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($bitmap))
   $out=[IO.File]::Create((Join-Path (Get-Location) 'Development/TestResults/install-consent-style.png'));try{$encoder.Save($out)}finally{$out.Close()}
   $w.Close()
  }
 }
})
$timer.Start()
$result=Show-PMMInstallConsent ([pscustomobject]@{component='all'})
if($result.accepted -or $result.mode -ne 'ask'){throw 'Closing consent authorized installation'}
$Window.Close()
'CONSENT_STYLE_CANCEL_PASS'
