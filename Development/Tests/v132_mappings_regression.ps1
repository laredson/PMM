Set-StrictMode -Version 2;$ErrorActionPreference='Stop'
$repo=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$Script:Root=Join-Path $repo ('Development/TestResults/Mappings132-'+[guid]::NewGuid().ToString('N'))
. (Join-Path $repo 'PMM/Modules/Shared/Paths.ps1');Initialize-PMMPaths $Script:Root|Out-Null
. (Join-Path $repo 'PMM/Modules/Shared/Persistence.ps1')
function Get-Sha256([string]$Path){return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()}
$checks=0
function Assert($ok,[string]$why){if(-not$ok){throw $why};$script:checks++}
Assert ((Get-PMMMappingsPath) -eq (Get-PMMBundledMappingsPath)) 'Default mapping path changed.'
$source=Join-Path $Script:Root 'mapping.usmap';[byte[]]$bytes=0xC4,0x30,0,0,0,0,0,0,0,0,0,0,0,0,0,0
[IO.File]::WriteAllBytes($source,$bytes)
$selected=Import-PMMLocalMappings $source;$path=Get-PMMMappingsPath
Assert ($selected.Mode -eq 'Local' -and (Get-Sha256 $path) -eq $selected.Sha256) 'Import did not commit exact local mapping bytes.'
[IO.File]::WriteAllBytes($source,[byte[]]@(1,2,3,4))
Assert ((Get-Sha256 $path) -eq $selected.Sha256) 'External source changes modified the selected copy.'
$before=[IO.File]::ReadAllText((Get-PMMMappingsSelectionPath));$failed=$false
try{Import-PMMLocalMappings $source|Out-Null}catch{$failed=$true}
Assert ($failed -and [IO.File]::ReadAllText((Get-PMMMappingsSelectionPath)) -ceq $before) 'Invalid import changed the selected mapping.'
[IO.File]::WriteAllBytes($source,$bytes);$same=Import-PMMLocalMappings $source
Assert ($same.Sha256 -eq $selected.Sha256 -and @(Get-ChildItem (Split-Path $path) -File).Count -eq 1) 'Repeated import duplicated stored mapping bytes.'
$malformed=[ordered]@{Schema='PMM_MAPPINGS_SELECTION_V1';Mode='Local';Sha256='../escape'}
Write-PMMJsonAtomic (Get-PMMMappingsSelectionPath) $malformed -Depth 4
$failed=$false;try{Get-PMMMappingsPath|Out-Null}catch{$failed=$true}
Assert $failed 'Malformed selection escaped the local mapping store.'
$reset=Import-PMMLocalMappings
Assert ($reset.Mode -eq 'Bundled' -and (Get-PMMMappingsPath) -eq (Get-PMMBundledMappingsPath)) 'Bundled reset did not recover malformed state.'
Assert (Test-Path -LiteralPath $path) 'Reset deleted previously imported local data.'
'PASS mappings132: '+$checks+' assertions; local selection, atomic failures, immutable copy, malformed-state recovery.'
