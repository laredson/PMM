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

$registry=Get-PMMLanguageRegistry
$expectedNativeNames=@{}
foreach($definition in @($registry.languages)){
  $expectedNativeNames[[string]$definition.code]=[string]$definition.nativeName
}
foreach($requiredCode in @('en','es','zh-CN')){
  if(-not $expectedNativeNames.ContainsKey($requiredCode)){
    throw "Required language '$requiredCode' is missing from languages.json."
  }
}
if([string]$expectedNativeNames['en'] -cne 'English'){
  throw "English nativeName must remain exactly 'English'."
}

$languageOptions=@(Get-PMMLanguageOptions)
foreach($option in $languageOptions){
  $code=[string]$option.Code
  if(-not $expectedNativeNames.ContainsKey($code)){throw "Unexpected language option '$code'."}
  if([string]$option.Label -cne [string]$expectedNativeNames[$code]){
    throw "Language option '$code' lost its nativeName from languages.json."
  }
  if(-not($option.PSObject.Properties.Name -contains 'PMMLocalizeLabel') -or [bool]$option.PMMLocalizeLabel){
    throw "Language option '$code' must opt out of label localization."
  }
}

Add-Type -AssemblyName PresentationFramework,PresentationCore,WindowsBase

$languageCombo=New-Object Windows.Controls.ComboBox
$languageCombo.DisplayMemberPath='Label'
$languageCombo.SelectedValuePath='Code'
$languageCombo.ItemsSource=$languageOptions
Invoke-PMMLocalizeVisualTree $languageCombo $Language 'en'
foreach($option in @($languageCombo.ItemsSource)){
  $code=[string]$option.Code
  if([string]$option.Label -cne [string]$expectedNativeNames[$code]){
    throw "Visual-tree localization changed nativeName for '$code'."
  }
}

$normalItem=[pscustomobject]@{Label='Settings';Value='settings'}
$normalCombo=New-Object Windows.Controls.ComboBox
$normalCombo.DisplayMemberPath='Label'
$normalCombo.ItemsSource=@($normalItem)
Invoke-PMMLocalizeVisualTree $normalCombo $Language 'en'
if([string]$normalItem.Label -ceq 'Settings'){
  throw 'Normal data-bound labels stopped localizing while protecting native language names.'
}
Invoke-PMMLocalizeVisualTree $normalCombo 'en' $Language
if([string]$normalItem.Label -cne 'Settings'){
  throw "Live localization did not restore the canonical English label. Value='$($normalItem.Label)'"
}
Invoke-PMMLocalizeVisualTree $normalCombo $Language 'en'
if([string]$normalItem.Label -cne $translated){
  throw "Live localization did not reapply '$Language' after returning to English. Value='$($normalItem.Label)'"
}

$probe=New-Object Windows.Controls.TextBlock
$probe.Text='Settings'
Invoke-PMMLocalizeVisualTree $probe $Language 'en'
if([string]$probe.Text -cne $translated){
  throw "Live TextBlock translation failed. Value='$($probe.Text)'"
}
Invoke-PMMLocalizeVisualTree $probe 'en' $Language
if([string]$probe.Text -cne 'Settings'){
  throw "Live TextBlock English restore failed. Value='$($probe.Text)'"
}

$xamlPath=Get-PMMLanguageXamlPath $Language
[xml]$xml=Get-Content -LiteralPath $xamlPath -Raw -Encoding UTF8
$reader=New-Object System.Xml.XmlNodeReader $xml
$window=[Windows.Markup.XamlReader]::Load($reader)
if(-not $window){throw 'Localized WPF window did not load.'}
Invoke-PMMLocalizeVisualTree $window $Language $Language
Set-PMMLanguageDirection $window $Language
$definition=Get-PMMLanguageDefinition $Language
$expectedDirection=if($definition -and [string]$definition.direction -eq 'rtl'){[Windows.FlowDirection]::RightToLeft}else{[Windows.FlowDirection]::LeftToRight}
if($window.FlowDirection -ne $expectedDirection){throw "FlowDirection was not applied for '$Language'."}
$window.Close()

Write-Host "Windows PowerShell 5.1 localization OK: language=$Language strings=$($catalog.Count) nativeNames=OK liveSwitch=OK"
