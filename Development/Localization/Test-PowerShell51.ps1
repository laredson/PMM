param([string]$Language='zh-CN')
$ErrorActionPreference='Stop'

if($PSVersionTable.PSVersion.Major -ne 5){
  throw "This regression test must run under Windows PowerShell 5.1. Current version: $($PSVersionTable.PSVersion)"
}

$RepoRoot=(Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$Script:Root=(Resolve-Path (Join-Path $RepoRoot 'PMM')).Path

$unsupported=@(
  Get-ChildItem -LiteralPath $Script:Root -Recurse -File -Filter *.ps1 |
    Select-String -Pattern 'ConvertFrom-Json\s+-AsHashtable'
)
if($unsupported.Count){
  $details=($unsupported|ForEach-Object{"$($_.Path):$($_.LineNumber): $($_.Line.Trim())"}) -join [Environment]::NewLine
  throw "PowerShell 7-only ConvertFrom-Json -AsHashtable remains in the shipped PMM tree:`n$details"
}

. (Join-Path $Script:Root 'Modules\Shared\Localization.ps1')

$resolved=Resolve-PMMLanguageCode $Language
if($resolved -cne $Language){throw "Language resolver returned '$resolved' instead of '$Language'."}

$catalog=Get-PMMLanguageCatalog $Language
if(-not $catalog -or $catalog.Count -lt 1200){throw "Localization catalog did not load correctly under Windows PowerShell 5.1. Count=$($catalog.Count)"}

$translated=Get-PMMLocalizedText 'Settings' $Language
if([string]::IsNullOrWhiteSpace($translated) -or $translated -ceq 'Settings'){
  throw "Catalog lookup did not return a translated value for Settings. Value='$translated'"
}

Add-Type -AssemblyName PresentationFramework,PresentationCore,WindowsBase
$xamlPath=Get-PMMLanguageXamlPath $Language
[xml]$xml=Get-Content -LiteralPath $xamlPath -Raw -Encoding UTF8
$reader=New-Object System.Xml.XmlNodeReader $xml
$window=[Windows.Markup.XamlReader]::Load($reader)
if(-not $window){throw 'Localized WPF window did not load.'}
Invoke-PMMLocalizeVisualTree $window $Language
Set-PMMLanguageDirection $window $Language
$window.Close()

Write-Host "Windows PowerShell 5.1 localization OK: language=$Language strings=$($catalog.Count) settings='$translated'"
