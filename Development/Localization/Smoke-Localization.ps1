param([string]$Language='zh-CN')
$ErrorActionPreference='Stop'
Add-Type -AssemblyName PresentationFramework,PresentationCore,WindowsBase
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\PMM'))
$Script:Root=$root
. (Join-Path $root 'Modules\Shared\Localization.ps1')

if((Resolve-PMMLanguageCode $Language) -cne $Language){throw ('Language resolver failed: '+(Resolve-PMMLanguageCode $Language))}

if($Language -eq 'zh-CN'){
  $checks=@{
    'Projects'='项目'
    'Mod Creation'='模组创建'
    'Help'='帮助'
    'Research cases'='研究案例'
    'Cases'='案例'
    '+ New case'='+ 新建案例'
    'Receive file...'='接收文件...'
    'Select or create a case'='选择或创建案例'
    'Optional tools and AI clients'='可选工具与 AI 客户端'
    'Installations and status'='安装与状态'
    'Change permissions'='更改权限'
    'Installation tutorial'='安装教程'
    'Locate...'='定位...'
    'Detected'='已检测'
  }
  foreach($key in $checks.Keys){
    $actual=Get-PMMLocalizedText $key $Language
    if($actual -cne $checks[$key]){throw "Translation mismatch [$key] => [$actual]"}
  }
}

$probe='<StackPanel xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"><TextBlock Text="Projects"/><Button Content="Receive file..."/></StackPanel>'
$localized=Convert-PMMXamlLocalization $probe $Language
if($Language -eq 'zh-CN' -and ($localized -notmatch '项目' -or $localized -notmatch '接收文件')){throw 'Embedded XAML localization failed'}

$panel=[Windows.Controls.StackPanel]::new()
$text=[Windows.Controls.TextBlock]::new();$text.Text='Cases'
$button=[Windows.Controls.Button]::new();$button.Content='Options'
$combo=[Windows.Controls.ComboBox]::new();$combo.ItemsSource=@([pscustomobject]@{Label='Candidates';Value='x'})
[void]$panel.Children.Add($text);[void]$panel.Children.Add($button);[void]$panel.Children.Add($combo)
Invoke-PMMLocalizeVisualTree $panel $Language
if($Language -eq 'zh-CN' -and ($text.Text -cne '案例' -or $button.Content -cne '选项' -or $combo.ItemsSource[0].Label -cne '候选')){throw 'Dynamic visual-tree localization failed'}

$xamlPath=Get-PMMLanguageXamlPath $Language
[xml]$xml=Get-Content $xamlPath -Raw -Encoding UTF8
$reader=[System.Xml.XmlNodeReader]::new($xml)
$window=[Windows.Markup.XamlReader]::Load($reader)
if(-not $window){throw 'Localized WPF window did not load'}
Register-PMMLiveLocalization $window $Language
$window.Close()
Write-Host "Localization smoke $Language OK"
