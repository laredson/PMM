param(
  [Parameter(Mandatory=$true)][string]$Code,
  [Parameter(Mandatory=$true)][string]$NativeName,
  [Parameter(Mandatory=$true)][string]$EnglishName,
  [ValidateSet('ltr','rtl')][string]$Direction='ltr',
  [string]$Fallback='en'
)
$ErrorActionPreference='Stop'
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$loc=Join-Path $root 'PMM\Resources\Localization'
$target=Join-Path $loc ($Code+'.json')
if(Test-Path -LiteralPath $target){throw "Language catalog already exists: $target"}
$en=Get-Content (Join-Path $loc 'en.json') -Raw -Encoding UTF8|ConvertFrom-Json -AsHashtable
$strings=[ordered]@{}
foreach($key in @($en['strings'].Keys|Sort-Object)){$strings[[string]$key]=''}
$doc=[ordered]@{schema='PMM_LANGUAGE_V1';language=$Code;nativeName=$NativeName;fallback=$Fallback;strings=$strings}
$doc|ConvertTo-Json -Depth 20|Set-Content -LiteralPath $target -Encoding UTF8
Write-Host "Created $target with $($strings.Count) source strings."
Write-Host 'Add this object to languages.json:'
[ordered]@{code=$Code;nativeName=$NativeName;englishName=$EnglishName;fallback=$Fallback;direction=$Direction;xaml=$null}|ConvertTo-Json -Depth 5|Write-Host
Write-Host "Then translate all values and run: Development/Localization/Test-Localization.ps1 -Language $Code"
