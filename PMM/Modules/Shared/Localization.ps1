$Script:PMMLanguageRegistryCache=$null
$Script:PMMLanguageCatalogCache=@{}
$Script:PMMReverseLanguageCatalogCache=@{}
$Script:PMMLocalizationBaseline=[System.Runtime.CompilerServices.ConditionalWeakTable[System.Object,System.Collections.Hashtable]]::new()
$Script:PMMLiveLanguageHandlerRegistered=$false
$Script:PMMLiveLanguageCurrentCode=''
$Script:PMMLiveLanguageWindow=$null
function Get-PMMLocalizationRoot { Join-Path $Script:Root 'Resources\Localization' }
function Get-PMMLanguageRegistry {
  if($Script:PMMLanguageRegistryCache){return $Script:PMMLanguageRegistryCache}
  $path=Join-Path (Get-PMMLocalizationRoot) 'languages.json'
  if(-not(Test-Path -LiteralPath $path -PathType Leaf)){throw 'Localization registry is missing.'}
  $Script:PMMLanguageRegistryCache=Get-Content -LiteralPath $path -Raw -Encoding UTF8|ConvertFrom-Json
  return $Script:PMMLanguageRegistryCache
}
function Test-PMMLanguageEnabled($Language){
  if(-not$Language){return $false}
  if($Language.PSObject.Properties.Name -notcontains 'enabled'){return $true}
  return [bool]$Language.enabled
}
function Get-PMMLanguageDefinition([string]$Code){
  $registry=Get-PMMLanguageRegistry
  return @($registry.languages|Where-Object{([string]$_.code -ieq $Code) -and (Test-PMMLanguageEnabled $_)}|Select-Object -First 1)[0]
}
function Resolve-PMMLanguageCode([string]$Code){
  $registry=Get-PMMLanguageRegistry
  if(-not [string]::IsNullOrWhiteSpace($Code)){
    $exact=Get-PMMLanguageDefinition $Code;if($exact){return [string]$exact.code}
    $base=($Code -split '-')[0]
    $match=@($registry.languages|Where-Object{(Test-PMMLanguageEnabled $_) -and (([string]$_.code -split '-')[0] -ieq $base)}|Select-Object -First 1)[0]
    if($match){return [string]$match.code}
  }
  return [string]$registry.default
}
function Get-PMMCurrentLanguage {try{return Resolve-PMMLanguageCode ([string](Get-PMMConfig).Language)}catch{return Resolve-PMMLanguageCode ''}}
function Get-PMMLanguageOptions {
  return @((Get-PMMLanguageRegistry).languages|Where-Object{Test-PMMLanguageEnabled $_})|ForEach-Object{
    [pscustomobject]@{
      Label=[string]$_.nativeName
      Code=[string]$_.code
      PMMLocalizeLabel=$false
    }
  }
}
function Get-PMMLanguageCatalog([string]$Code){
  $code=Resolve-PMMLanguageCode $Code
  if($Script:PMMLanguageCatalogCache.ContainsKey($code)){return $Script:PMMLanguageCatalogCache[$code]}
  $table=[Collections.Hashtable]::new([StringComparer]::Ordinal);$path=Join-Path (Get-PMMLocalizationRoot) ($code+'.json')
  if(Test-Path -LiteralPath $path -PathType Leaf){
    $json=Get-Content -LiteralPath $path -Raw -Encoding UTF8
    if($PSVersionTable.PSVersion.Major -le 5){
      Add-Type -AssemblyName System.Web.Extensions -ErrorAction Stop
      $serializer=New-Object System.Web.Script.Serialization.JavaScriptSerializer
      $serializer.MaxJsonLength=[int]::MaxValue
      $doc=$serializer.DeserializeObject($json)
      if($doc -and $doc.ContainsKey('strings') -and $doc['strings']){
        $strings=$doc['strings']
        foreach($key in $strings.Keys){$table[[string]$key]=[string]$strings[$key]}
      }
    }else{
      $jsonDoc=[System.Text.Json.JsonDocument]::Parse($json)
      try{
        $stringsElement=$jsonDoc.RootElement.GetProperty('strings')
        foreach($property in $stringsElement.EnumerateObject()){$table[[string]$property.Name]=[string]$property.Value.GetString()}
      }finally{$jsonDoc.Dispose()}
    }
  }
  $Script:PMMLanguageCatalogCache[$code]=$table;return $table
}
function Get-PMMReverseLanguageCatalog([string]$Code){
  $code=Resolve-PMMLanguageCode $Code
  if($Script:PMMReverseLanguageCatalogCache.ContainsKey($code)){return $Script:PMMReverseLanguageCatalogCache[$code]}
  $reverse=[Collections.Hashtable]::new([StringComparer]::Ordinal)
  if($code -ne 'en'){
    $catalog=Get-PMMLanguageCatalog $code
    foreach($key in $catalog.Keys){
      $value=[string]$catalog[$key]
      if([string]::IsNullOrWhiteSpace($value)){continue}
      if($reverse.ContainsKey($value)){$reverse[$value]=$null}else{$reverse[$value]=[string]$key}
    }
  }
  $Script:PMMReverseLanguageCatalogCache[$code]=$reverse
  return $reverse
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
function Get-PMMLocalizationBaselineBag($Target){
  if(-not$Target){return $null}
  try{return $Script:PMMLocalizationBaseline.GetOrCreateValue([object]$Target)}catch{return $null}
}
function Get-PMMLocalizationSourceText($Target,[string]$Slot,[string]$CurrentText,[string]$SourceLanguageCode=''){
  if([string]::IsNullOrWhiteSpace($CurrentText)){return $CurrentText}
  $source=if($SourceLanguageCode){Resolve-PMMLanguageCode $SourceLanguageCode}else{Get-PMMCurrentLanguage}
  $bag=Get-PMMLocalizationBaselineBag $Target
  if($bag -and $bag.ContainsKey($Slot)){
    $baseline=[string]$bag[$Slot]
    $expected=if($source -eq 'en'){$baseline}else{Get-PMMLocalizedText $baseline $source}
    if($CurrentText -ceq $baseline -or $CurrentText -ceq $expected){return $baseline}
  }
  $canonical=$null
  $englishCatalog=Get-PMMLanguageCatalog 'en'
  if($englishCatalog.ContainsKey($CurrentText)){
    $canonical=$CurrentText
  }elseif($source -ne 'en'){
    $reverse=Get-PMMReverseLanguageCatalog $source
    if($reverse.ContainsKey($CurrentText) -and $null -ne $reverse[$CurrentText]){$canonical=[string]$reverse[$CurrentText]}
  }else{
    # Dynamic English text may not be a catalog key. Preserve it as its own
    # baseline; Refresh-UI will regenerate formatted dynamic text after a live
    # language change, while exact catalog strings are translated in-place.
    $canonical=$CurrentText
  }
  if($null -eq $canonical){return $null}
  if($bag){$bag[$Slot]=$canonical}
  return $canonical
}
function Get-PMMLocalizationTargetText($Target,[string]$Slot,[string]$CurrentText,[string]$TargetLanguageCode,[string]$SourceLanguageCode=''){
  $canonical=Get-PMMLocalizationSourceText $Target $Slot $CurrentText $SourceLanguageCode
  if($null -eq $canonical){return $null}
  $target=Resolve-PMMLanguageCode $TargetLanguageCode
  if($target -eq 'en'){return $canonical}
  return Get-PMMLocalizedText $canonical $target
}
function Register-PMMLiveLanguageSwitch($Window,[string]$CurrentLanguageCode=''){
  if(-not$Window){return}
  $resolvedCurrent=if($CurrentLanguageCode){Resolve-PMMLanguageCode $CurrentLanguageCode}else{Get-PMMCurrentLanguage}
  $Script:PMMLiveLanguageWindow=$Window
  $Script:PMMLiveLanguageCurrentCode=$resolvedCurrent
  if($Script:PMMLiveLanguageHandlerRegistered){return}
  $buttonVar=Get-Variable -Name BtnApplyLanguage -Scope Script -ErrorAction SilentlyContinue
  $comboVar=Get-Variable -Name CmbLanguage -Scope Script -ErrorAction SilentlyContinue
  if(-not$buttonVar -or -not$buttonVar.Value -or -not$comboVar -or -not$comboVar.Value){return}
  $buttonVar.Value.Add_Click({
    try{
      $selected=Resolve-PMMLanguageCode ([string]$Script:CmbLanguage.SelectedValue)
      $newCode=Get-PMMCurrentLanguage
      # The original Settings handler persists the selection first. If that save
      # failed, do not pretend the live application succeeded.
      if($selected -cne $newCode){return}
      $oldCode=if([string]::IsNullOrWhiteSpace([string]$Script:PMMLiveLanguageCurrentCode)){$newCode}else{Resolve-PMMLanguageCode ([string]$Script:PMMLiveLanguageCurrentCode)}
      $window=$Script:PMMLiveLanguageWindow
      if(-not$window){return}
      Invoke-PMMLocalizeVisualTree $window $newCode $oldCode
      Set-PMMLanguageDirection $window $newCode
      try{
        $refresh=Get-Command -Name Refresh-UI -CommandType Function -ErrorAction SilentlyContinue
        if($refresh){Refresh-UI}
      }catch{try{Write-PMMLog ('Live language Refresh-UI warning: '+$_.Exception.Message)}catch{}}
      # Refresh-UI regenerates formatted/dynamic labels using the newly saved
      # language. Sweep once more so newly materialized static controls and
      # data-bound labels join the reversible localization baseline too.
      Invoke-PMMLocalizeVisualTree $window $newCode $newCode
      Set-PMMLanguageDirection $window $newCode
      try{$Script:CmbLanguage.SelectedValue=$newCode}catch{}
      $Script:PMMLiveLanguageCurrentCode=$newCode
      try{$Script:TxtStatus.Text=Get-PMMLocalizedText 'Settings applied.' $newCode}catch{}
      try{Write-PMMLog ("Language applied live without restart: $oldCode -> $newCode")}catch{}
    }catch{
      try{Handle-UIError $_ 'Language'}catch{try{Write-PMMLog ('Live language application failed: '+$_.Exception.Message)}catch{}}
    }
  })
  $Script:PMMLiveLanguageHandlerRegistered=$true
}
function Invoke-PMMLocalizeVisualTree($Root,[string]$LanguageCode='',[string]$SourceLanguageCode=''){
  if(-not$Root){return}
  $code=if($LanguageCode){Resolve-PMMLanguageCode $LanguageCode}else{Get-PMMCurrentLanguage}
  $source=if($SourceLanguageCode){Resolve-PMMLanguageCode $SourceLanguageCode}else{Get-PMMCurrentLanguage}
  try{
    if($Root -is [Windows.Controls.TextBlock] -and -not[string]::IsNullOrWhiteSpace([string]$Root.Text)){
      $next=Get-PMMLocalizationTargetText $Root 'Text' ([string]$Root.Text) $code $source
      if($null -ne $next){$Root.Text=[string]$next}
    }
    if($Root -is [Windows.Documents.Run] -and -not[string]::IsNullOrWhiteSpace([string]$Root.Text)){
      $next=Get-PMMLocalizationTargetText $Root 'Text' ([string]$Root.Text) $code $source
      if($null -ne $next){$Root.Text=[string]$next}
    }
    if($Root -is [Windows.Controls.ContentControl] -and $Root.Content -is [string]){
      $next=Get-PMMLocalizationTargetText $Root 'Content' ([string]$Root.Content) $code $source
      if($null -ne $next){$Root.Content=[string]$next}
    }
    if($Root -is [Windows.Controls.HeaderedContentControl] -and $Root.Header -is [string]){
      $next=Get-PMMLocalizationTargetText $Root 'Header' ([string]$Root.Header) $code $source
      if($null -ne $next){$Root.Header=[string]$next}
    }
    if($Root -is [Windows.Controls.HeaderedItemsControl] -and $Root.Header -is [string]){
      $next=Get-PMMLocalizationTargetText $Root 'Header' ([string]$Root.Header) $code $source
      if($null -ne $next){$Root.Header=[string]$next}
    }
    if($Root -is [Windows.FrameworkElement] -and $Root.ToolTip -is [string]){
      $next=Get-PMMLocalizationTargetText $Root 'ToolTip' ([string]$Root.ToolTip) $code $source
      if($null -ne $next){$Root.ToolTip=[string]$next}
    }
    if($Root -is [Windows.Controls.ItemsControl] -and $Root.ItemsSource){
      foreach($item in @($Root.ItemsSource)){
        try{
          if($item -and ($item.PSObject.Properties.Name -contains 'Label') -and $item.Label -is [string]){
            $localizeLabel=$true
            if($item.PSObject.Properties.Name -contains 'PMMLocalizeLabel'){$localizeLabel=[bool]$item.PMMLocalizeLabel}
            if($localizeLabel){
              $next=Get-PMMLocalizationTargetText $item 'Label' ([string]$item.Label) $code $source
              if($null -ne $next){$item.Label=[string]$next}
            }
          }
        }catch{}
      }
    }
    if($Root -is [Windows.Controls.DataGrid]){
      foreach($column in @($Root.Columns)){
        if($column.Header -is [string]){
          $next=Get-PMMLocalizationTargetText $column 'Header' ([string]$column.Header) $code $source
          if($null -ne $next){$column.Header=[string]$next}
        }
      }
    }
  }catch{}
  try{foreach($child in [Windows.LogicalTreeHelper]::GetChildren($Root)){if($child -is [Windows.DependencyObject]){Invoke-PMMLocalizeVisualTree $child $code $source}}}catch{}
  try{if($Root -is [Windows.Window]){Register-PMMLiveLanguageSwitch $Root $code}}catch{}
}
function Set-PMMLanguageDirection($Element,[string]$LanguageCode=''){
  if(-not$Element){return};$code=if($LanguageCode){Resolve-PMMLanguageCode $LanguageCode}else{Get-PMMCurrentLanguage};$def=Get-PMMLanguageDefinition $code
  try{$Element.FlowDirection=if($def -and [string]$def.direction -eq 'rtl'){[Windows.FlowDirection]::RightToLeft}else{[Windows.FlowDirection]::LeftToRight}}catch{}
}
