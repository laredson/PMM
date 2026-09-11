param([string]$Root='')

$ErrorActionPreference='Stop'
Set-StrictMode -Version 2.0

if([string]::IsNullOrWhiteSpace($Root)){$Root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))}
$app=Join-Path $Root 'PMM'

if([System.Threading.Thread]::CurrentThread.ApartmentState -ne [System.Threading.ApartmentState]::STA){
  throw 'WPF runtime validation must run in an STA Windows PowerShell process.'
}

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase

foreach($name in @('MainWindow.xaml','MainWindow.en.xaml','MainWindow.es.xaml')){
  $path=Join-Path $app ('Resources\UI\'+$name)
  $window=$null
  try{
    [xml]$document=Get-Content -LiteralPath $path -Raw -Encoding UTF8
    $reader=[System.Xml.XmlNodeReader]::new($document)
    try{$window=[Windows.Markup.XamlReader]::Load($reader)}finally{$reader.Dispose()}
    if(-not$window){throw ($name+' did not create a WPF Window.')}

    # Show off-screen and transparent so WPF materializes deferred templates,
    # Loaded event triggers and storyboard targets without flashing in CI.
    $window.ShowInTaskbar=$false
    $window.ShowActivated=$false
    $window.WindowStartupLocation=[System.Windows.WindowStartupLocation]::Manual
    $window.Left=-32000
    $window.Top=-32000
    $window.Opacity=0
    $window.Show()
    $window.UpdateLayout()

    $auto=$window.FindName('BtnAutoRun')
    if(-not$auto){throw ($name+' does not expose BtnAutoRun.')}
    [void]$auto.ApplyTemplate()
    $auto.UpdateLayout()
    foreach($targetName in @('SparkleMove1','SparkleMove2','SparkleMove3')){
      if(-not$auto.Template.FindName($targetName,$auto)){throw ($name+' cannot resolve AUTO storyboard target '+$targetName+'.')}
    }
  }catch{
    throw ($name+' WPF runtime materialization failed: '+$_.Exception.Message)
  }finally{
    if($window){try{$window.Close()}catch{}}
  }
}

Write-Output 'WPF_XAML_RUNTIME_REGRESSION_OK'
