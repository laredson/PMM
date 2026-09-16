param([switch]$Quiet)

Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$Root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..'))
$App=Join-Path $Root 'PMM'
$Failures=[System.Collections.Generic.List[string]]::new()

function Pass([string]$Message){if(-not $Quiet){Write-Output ('[PASS] '+$Message)}}
function Fail([string]$Message){$Failures.Add($Message);Write-Output ('[FAIL] '+$Message)}
function Assert-PMM([bool]$Condition,[string]$Message){if($Condition){Pass $Message}else{Fail $Message}}
function Need-File([string]$Relative){Assert-PMM (Test-Path -LiteralPath (Join-Path $Root $Relative) -PathType Leaf) ('File: '+$Relative)}
function Need-Dir([string]$Relative){Assert-PMM (Test-Path -LiteralPath (Join-Path $Root $Relative) -PathType Container) ('Directory: '+$Relative)}
function Parse-Json([string]$Path){
  try{
    $text=[IO.File]::ReadAllText($Path,[Text.Encoding]::UTF8)
    $doc=[System.Text.Json.JsonDocument]::Parse($text)
    return $doc
  }catch{Fail ('Invalid JSON: '+$Path+' | '+$_.Exception.Message);return $null}
}

foreach($d in @('PMM','PMM\Engine','PMM\Modules','PMM\Resources','PMM\CKL','PMM\Documentation','Development\Localization','Development\Tests')){Need-Dir $d}
foreach($f in @(
  'PMM\PMM.exe','PMM\Engine\PMMRuntime.exe','PMM\Resources\Metadata\VERSION.txt','PMM\Resources\Metadata\BUILD_ID.txt',
  'PMM\Resources\Metadata\RELEASE_MANIFEST.json','PMM\Resources\Metadata\SHA256SUMS.txt','PMM\Resources\Localization\languages.json',
  'PMM\Modules\Shared\Localization.ps1','Development\Localization\Test-PowerShell51.ps1','Development\Localization\Test-Localization.ps1',
  'Development\Localization\audit_localization.py'
)){Need-File $f}

$rootFiles=@(Get-ChildItem -LiteralPath $App -File -Force)
Assert-PMM ($rootFiles.Count -eq 1 -and $rootFiles[0].Name -eq 'PMM.exe') 'PMM root exposes only PMM.exe'
Assert-PMM (-not(Test-Path -LiteralPath (Join-Path $App 'Workspace'))) 'Workspace is not committed or shipped'
foreach($pattern in @('*.pak','*.ucas','*.utoc')){
  $payloads=@(Get-ChildItem -LiteralPath $Root -Recurse -File -Filter $pattern -ErrorAction SilentlyContinue)
  Assert-PMM ($payloads.Count -eq 0) ('No '+$pattern+' payloads committed')
}
Assert-PMM (@(Get-ChildItem -LiteralPath $Root -Recurse -File -Filter 'oo2core_9_win64.dll' -ErrorAction SilentlyContinue).Count -eq 0) 'No proprietary Oodle DLL committed'

# JSON is case-sensitive. System.Text.Json is used deliberately instead of ConvertFrom-Json,
# because localization catalogs legitimately contain keys that differ only by letter casing.
foreach($json in @(Get-ChildItem -LiteralPath $App -Recurse -File -Filter '*.json')){
  $doc=Parse-Json $json.FullName
  if($doc){$doc.Dispose()}
}

$version=(Get-Content -LiteralPath (Join-Path $App 'Resources\Metadata\VERSION.txt') -Raw).Trim()
$buildId=(Get-Content -LiteralPath (Join-Path $App 'Resources\Metadata\BUILD_ID.txt') -Raw).Trim()
$manifestPath=Join-Path $App 'Resources\Metadata\RELEASE_MANIFEST.json'
$manifestDoc=Parse-Json $manifestPath
if($manifestDoc){
  $root=$manifestDoc.RootElement
  $manifestVersion=$root.GetProperty('version').GetString()
  $manifestBuildId=$root.GetProperty('buildId').GetString()
  $mergePlanSchema=$root.GetProperty('mergePlanSchema').GetInt32()
  $buildManifestSchema=$root.GetProperty('buildManifestSchema').GetInt32()
  Assert-PMM ($manifestVersion -eq $version) ('Manifest version matches VERSION.txt ('+$version+')')
  Assert-PMM ($manifestBuildId -eq $buildId) 'Manifest buildId matches BUILD_ID.txt'
  Assert-PMM ($mergePlanSchema -ge 19) ('Merge plan schema is current ('+$mergePlanSchema+')')
  Assert-PMM ($buildManifestSchema -ge 9) ('Build manifest schema is current ('+$buildManifestSchema+')')
  $manifestDoc.Dispose()
}

$languagesPath=Join-Path $App 'Resources\Localization\languages.json'
$languagesDoc=Parse-Json $languagesPath
if($languagesDoc){
  $expectedNative=@{'en'='English';'es'='Español';'zh-CN'='简体中文'}
  $seen=@{}
  foreach($lang in $languagesDoc.RootElement.GetProperty('languages').EnumerateArray()){
    $code=$lang.GetProperty('code').GetString()
    $native=$lang.GetProperty('nativeName').GetString()
    $seen[$code]=$true
    if($expectedNative.ContainsKey($code)){Assert-PMM ($native -ceq $expectedNative[$code]) ("Native language name $code = $native")}
    $catalog=Join-Path $App ('Resources\Localization\'+$code+'.json')
    Assert-PMM (Test-Path -LiteralPath $catalog -PathType Leaf) ('Catalog exists: '+$code)
    if($lang.TryGetProperty('xaml',[ref]([System.Text.Json.JsonElement]$xamlElement)) -and $xamlElement.ValueKind -eq [System.Text.Json.JsonValueKind]::String){
      $xamlName=$xamlElement.GetString()
      if($xamlName){
        $xamlPath=Join-Path $App ('Resources\UI\'+$xamlName)
        Assert-PMM (Test-Path -LiteralPath $xamlPath -PathType Leaf) ('Localized XAML exists: '+$xamlName)
        if(Test-Path -LiteralPath $xamlPath -PathType Leaf){try{[xml]$null=Get-Content -LiteralPath $xamlPath -Raw -Encoding UTF8;Pass ('Valid XAML: '+$xamlName)}catch{Fail ('Invalid XAML '+$xamlName+' | '+$_.Exception.Message)}}
      }
    }
  }
  foreach($code in $expectedNative.Keys){Assert-PMM $seen.ContainsKey($code) ('Language registry contains '+$code)}
  $languagesDoc.Dispose()
}

# The shipped Windows UI remains Windows PowerShell 5.1 compatible.
$ps7Only=@(Get-ChildItem -LiteralPath (Join-Path $App 'Modules') -Recurse -File -Filter '*.ps1' | Select-String -Pattern 'ConvertFrom-Json\s+-AsHashtable')
Assert-PMM ($ps7Only.Count -eq 0) 'Shipped PowerShell contains no ConvertFrom-Json -AsHashtable'

# Validate the package integrity inventory. SHA256SUMS.txt intentionally does not hash itself.
$sumPath=Join-Path $App 'Resources\Metadata\SHA256SUMS.txt'
$expected=[System.Collections.Generic.Dictionary[string,string]]::new([StringComparer]::OrdinalIgnoreCase)
foreach($line in Get-Content -LiteralPath $sumPath){
  if([string]::IsNullOrWhiteSpace($line)){continue}
  if($line -notmatch '^([0-9a-fA-F]{64})  (.+)$'){Fail ('Malformed SHA256SUMS line: '+$line);continue}
  $expected[$Matches[2].Replace('\','/')]=($Matches[1].ToLowerInvariant())
}
$actualFiles=@(Get-ChildItem -LiteralPath $App -Recurse -File | Where-Object{$_.FullName -ne $sumPath})
Assert-PMM ($expected.Count -eq $actualFiles.Count) ("SHA256SUMS covers package files ($($actualFiles.Count))")
foreach($file in $actualFiles){
  $relative=$file.FullName.Substring($App.Length).TrimStart('\','/').Replace('\','/')
  if(-not $expected.ContainsKey($relative)){Fail ('SHA256SUMS missing: '+$relative);continue}
  $hash=(Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
  if($hash -ne $expected[$relative]){Fail ('SHA-256 mismatch: '+$relative)}
}

if($Failures.Count){Write-Output ('PMM_CURRENT_VALIDATION_FAILED count='+$Failures.Count);exit 1}
Write-Output ('PMM_CURRENT_VALIDATION_OK version='+$version)
exit 0
