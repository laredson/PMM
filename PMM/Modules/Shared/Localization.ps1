$Script:PMMLanguageRegistryCache=$null
$Script:PMMLanguageCatalogCache=@{}
function Get-PMMLocalizationRoot { Join-Path $Script:Root 'Resources\Localization' }
function Get-PMMLanguageRegistry {
  if($Script:PMMLanguageRegistryCache){return $Script:PMMLanguageRegistryCache}
  $path=Join-Path (Get-PMMLocalizationRoot) 'languages.json'
  if(-not(Test-Path -LiteralPath $path -PathType Leaf)){throw 'Localization registry is missing.'}
  $Script:PMMLanguageRegistryCache=Get-Content -LiteralPath $path -Raw -Encoding UTF8|ConvertFrom-Json
  return $Script:PMMLanguageRegistryCache
}
function Get-PMMLanguageDefinition([string]$Code){
  $registry=Get-PMMLanguageRegistry
  return @($registry.languages|Where-Object{[string]$_.code -ieq $Code}|Select-Object -First 1)[0]
}
function Resolve-PMMLanguageCode([string]$Code){
  $registry=Get-PMMLanguageRegistry
  if(-not [string]::IsNullOrWhiteSpace($Code)){
    $exact=Get-PMMLanguageDefinition $Code;if($exact){return [string]$exact.code}
    $base=($Code -split '-')[0]
    $match=@($registry.languages|Where-Object{([string]$_.code -split '-')[0] -ieq $base}|Select-Object -First 1)[0]
    if($match){return [string]$match.code}
  }
  return [string]$registry.default
}
function Get-PMMCurrentLanguage {try{return Resolve-PMMLanguageCode ([string](Get-PMMConfig).Language)}catch{return Resolve-PMMLanguageCode ''}}
function Get-PMMLanguageOptions {return @(Get-PMMLanguageRegistry).languages|ForEach-Object{[pscustomobject]@{Label=[string]$_.nativeName;Code=[string]$_.code}}}
function Get-PMMLanguageCatalog([string]$Code){
  $code=Resolve-PMMLanguageCode $Code
  if($Script:PMMLanguageCatalogCache.ContainsKey($code)){return $Script:PMMLanguageCatalogCache[$code]}
  $table=[Collections.Hashtable]::new([StringComparer]::Ordinal);$path=Join-Path (Get-PMMLocalizationRoot) ($code+'.json')
  if(Test-Path -LiteralPath $path -PathType Leaf){
    $doc=Get-Content -LiteralPath $path -Raw -Encoding UTF8|ConvertFrom-Json
    if($doc -and ($doc.PSObject.Properties.Name -contains 'strings') -and $doc.strings){
      foreach($property in $doc.strings.PSObject.Properties){$table[[string]$property.Name]=[string]$property.Value}
    }
  }
  $Script:PMMLanguageCatalogCache[$code]=$table;return $table
}
function Get-PMMLocalizedText([string]$English,[string]$LanguageCode=''){
  if([string]::IsNullOrWhiteSpace($English)){return $English}
  $code=if($LanguageCode){Resolve-PMMLanguageCode $LanguageCode}else{Get-PMMCurrentLanguage};if($code -eq 'en'){return $English}
  $visited=@{}
  while($code -and -not$visited.ContainsKey($code)){$visited[$code]=$true;$catalog=Get-PMMLanguageCatalog $code;if($catalog.ContainsKey($English) -and -not[string]::IsNullOrWhiteSpace([string]$catalog[$English])){return [string]$catalog[$English]};$def=Get-PMMLanguageDefinition $code;$code=if($def){[string]$def.fallback}else{'en'};if($code -eq 'en'){break}}
  return $English
}
function Get-PMMLanguageXamlPath([string]$LanguageCode=''){
  $code=if($LanguageCode){Resolve-PMMLanguageCode $LanguageCode}else{Get-PMMCurrentLanguage};$def=Get-PMMLanguageDefinition $code
  if($def -and $def.xaml){$p=Join-Path $Script:Root ('Resources\UI\'+[string]$def.xaml);if(Test-Path -LiteralPath $p -PathType Leaf){return $p}}
  return (Join-Path $Script:Root 'Resources\UI\MainWindow.en.xaml')
}
function Convert-PMMXamlLocalization([string]$Xaml,[string]$LanguageCode=''){
  if([string]::IsNullOrWhiteSpace($Xaml)){return $Xaml};$code=if($LanguageCode){Resolve-PMMLanguageCode $LanguageCode}else{Get-PMMCurrentLanguage};if($code -eq 'en'){return $Xaml}
  $pattern='(?<prefix>\b(?:Text|Content|Header|ToolTip)=\")(?<value>[^\"]*)(?<suffix>\")'
  $eval=[Text.RegularExpressions.MatchEvaluator]{param($m)$raw=[Net.WebUtility]::HtmlDecode([string]$m.Groups['value'].Value);$translated=Get-PMMLocalizedText $raw $code;$escaped=[Security.SecurityElement]::Escape([string]$translated);return [string]$m.Groups['prefix'].Value+$escaped+[string]$m.Groups['suffix'].Value}
  return [Text.RegularExpressions.Regex]::Replace($Xaml,$pattern,$eval)
}
function Invoke-PMMLocalizeVisualTree($Root,[string]$LanguageCode=''){
  if(-not$Root){return};$code=if($LanguageCode){Resolve-PMMLanguageCode $LanguageCode}else{Get-PMMCurrentLanguage};if($code -eq 'en'){return}
  try{
    if($Root -is [Windows.Controls.TextBlock] -and -not[string]::IsNullOrWhiteSpace([string]$Root.Text)){$Root.Text=Get-PMMLocalizedText ([string]$Root.Text) $code}
    if($Root -is [Windows.Documents.Run] -and -not[string]::IsNullOrWhiteSpace([string]$Root.Text)){$Root.Text=Get-PMMLocalizedText ([string]$Root.Text) $code}
    if($Root -is [Windows.Controls.ContentControl] -and $Root.Content -is [string]){$Root.Content=Get-PMMLocalizedText ([string]$Root.Content) $code}
    if($Root -is [Windows.Controls.HeaderedContentControl] -and $Root.Header -is [string]){$Root.Header=Get-PMMLocalizedText ([string]$Root.Header) $code}
    if($Root -is [Windows.Controls.HeaderedItemsControl] -and $Root.Header -is [string]){$Root.Header=Get-PMMLocalizedText ([string]$Root.Header) $code}
    if($Root -is [Windows.FrameworkElement] -and $Root.ToolTip -is [string]){$Root.ToolTip=Get-PMMLocalizedText ([string]$Root.ToolTip) $code}
    if($Root -is [Windows.Controls.ItemsControl] -and $Root.ItemsSource){foreach($item in @($Root.ItemsSource)){try{if($item -and ($item.PSObject.Properties.Name -contains 'Label') -and $item.Label -is [string]){$item.Label=Get-PMMLocalizedText ([string]$item.Label) $code}}catch{}}}
    if($Root -is [Windows.Controls.DataGrid]){foreach($column in @($Root.Columns)){if($column.Header -is [string]){$column.Header=Get-PMMLocalizedText ([string]$column.Header) $code}}}
  }catch{}
  try{foreach($child in [Windows.LogicalTreeHelper]::GetChildren($Root)){if($child -is [Windows.DependencyObject]){Invoke-PMMLocalizeVisualTree $child $code}}}catch{}
}
function Set-PMMLanguageDirection($Element,[string]$LanguageCode=''){
  if(-not$Element){return};$code=if($LanguageCode){Resolve-PMMLanguageCode $LanguageCode}else{Get-PMMCurrentLanguage};$def=Get-PMMLanguageDefinition $code
  try{$Element.FlowDirection=if($def -and [string]$def.direction -eq 'rtl'){[Windows.FlowDirection]::RightToLeft}else{[Windows.FlowDirection]::LeftToRight}}catch{}
}
