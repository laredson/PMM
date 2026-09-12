# Isolated guards: no game, library or proprietary fixtures required.
Set-StrictMode -Version 2;$ErrorActionPreference='Stop'
$repo=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$fixture=Join-Path $repo ('Development/TestResults/DataTableGuards132-'+[guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($fixture)
. (Join-Path $repo 'PMM/Modules/Shared/Persistence.ps1')
. (Join-Path $repo 'PMM/Modules/CKL/KnowledgeRecipeService.ps1')
. (Join-Path $repo 'PMM/Modules/Merge/DataTableLayout.ps1')
function Get-Sha256([string]$Path){(Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()}
function Get-PMMMappingsPath{Join-Path $fixture 'test.usmap'}
function Get-PMMProductionRecipeDocument{$script:document}
$checks=0
function Assert($condition,[string]$message){if(-not$condition){throw $message};$script:checks++}
function Reject([scriptblock]$action,[string]$message){$failed=$false;try{& $action|Out-Null}catch{$failed=$true};Assert $failed $message}
function Family([string]$name){
  $header=Join-Path $fixture ($name+'.uasset');$payload=[IO.Path]::ChangeExtension($header,'.uexp')
  [IO.File]::WriteAllText($header,($name+' header'));[IO.File]::WriteAllText($payload,($name+' payload'))
  [pscustomobject]@{HeaderPath=$header}
}
function Pin($family){[pscustomobject]@{uasset=[pscustomobject]@{sha256=(Get-Sha256 $family.HeaderPath);size=(Get-Item $family.HeaderPath).Length};uexp=[pscustomobject]@{sha256=(Get-Sha256 ([IO.Path]::ChangeExtension($family.HeaderPath,'.uexp')));size=(Get-Item ([IO.Path]::ChangeExtension($family.HeaderPath,'.uexp'))).Length}}}
[IO.File]::WriteAllText((Get-PMMMappingsPath),'test mapping')
$vanilla=Family 'current';$records=@();$pins=@()
foreach($name in @('one','two')){
  $family=Family $name;$pak=Join-Path $fixture ($name+'.pak');[IO.File]::WriteAllText($pak,($name+' source'))
  $hash=Get-Sha256 $pak;$records+=,[pscustomobject]@{Mod=[pscustomobject]@{Name=$name;Path=$pak;Hash=$hash};Export=$family}
  $pins+=,[pscustomobject]@{pakSha256=$hash;family=(Pin $family)}
}
$rule=[pscustomobject]@{schema='PMM_DATATABLE_CURRENT_LAYOUT_TRANSFER_V1';id='test';mappingsSha256=(Get-Sha256 (Get-PMMMappingsPath));vanilla=(Pin $vanilla);preserveCurrentOnlyProperties=@('NewField')}
$group=[pscustomobject]@{Asset='Test/Table.uasset'}
$script:document=[pscustomobject]@{recipes=@([pscustomobject]@{asset=$group.Asset;providers=$pins;currentLayoutTransfer=$rule})}
Assert ($null -ne (Get-PMMDataTableLayoutTransfer $group $vanilla $records)) 'Exact fixture did not match.'
$records[0].Mod.Name='renamed';Assert ($null -ne (Get-PMMDataTableLayoutTransfer $group $vanilla $records)) 'Identity incorrectly depends on filename.'
Assert ($null -eq (Get-PMMDataTableLayoutTransfer $group $vanilla @($records[0]))) 'Incomplete provider set was accepted.'
Assert ($null -eq (Get-PMMDataTableLayoutTransfer $group $vanilla @($records+$records[0]))) 'Additional provider was accepted.'
$original=[IO.File]::ReadAllText($records[0].Mod.Path);[IO.File]::WriteAllText($records[0].Mod.Path,'changed')
Assert ($null -eq (Get-PMMDataTableLayoutTransfer $group $vanilla $records)) 'Stale PAK metadata authorized changed bytes.'
[IO.File]::WriteAllText($records[0].Mod.Path,$original)
$bulk=[IO.Path]::ChangeExtension($records[0].Export.HeaderPath,'.ubulk');[IO.File]::WriteAllText($bulk,'unexpected')
Assert ($null -eq (Get-PMMDataTableLayoutTransfer $group $vanilla $records)) 'Unexpected family part was accepted.'
# Exact local fixture file only; no recursive cleanup or external mutation.
[IO.File]::Delete($bulk)
[IO.File]::WriteAllText($vanilla.HeaderPath,'changed current header')
Assert ($null -eq (Get-PMMDataTableLayoutTransfer $group $vanilla $records)) 'Changed Vanilla was accepted.'
$vanilla=Family 'current';[IO.File]::WriteAllText((Get-PMMMappingsPath),'different mapping')
Assert ($null -eq (Get-PMMDataTableLayoutTransfer $group $vanilla $records)) 'Changed mappings were accepted.'
$current=Join-Path $fixture 'current.json';$provider=Join-Path $fixture 'provider.json';$out=Join-Path $fixture 'projected.json'
function Map([string]$path,[array]$rows){Write-PMMJsonAtomic $path ([ordered]@{rows=$rows}) -Depth 10}
function Row([string]$id,[array]$properties){[pscustomobject]@{id=$id;properties=@($properties|ForEach-Object{[pscustomobject]@{name=$_;value=0}})}}
Map $current @((Row 'A' @('OldField','NewField')),(Row 'A' @('OldField','NewField')))
Map $provider @((Row 'A' @('OldField')),(Row 'A' @('OldField')))
Reject {Assert-PMMDataTableAnchorPreservesCurrent $current $provider} 'Old anchor dropped a current property.'
New-PMMDataTableCurrentProjection $current @([pscustomobject]@{Map=$provider}) $rule $out|Out-Null
Assert (Test-Path $out) 'Declared exact projection failed.'
Map $provider @((Row 'A' @('OldField','NewField')))
Reject {Assert-PMMDataTableAnchorPreservesCurrent $current $provider} 'Duplicate row occurrence was lost.'
Reject {New-PMMDataTableCurrentProjection $current @([pscustomobject]@{Map=$provider}) $rule $out} 'Projection accepted row deletion.'
Map $provider @((Row 'A' @('OldField','OtherField')),(Row 'A' @('OldField','OtherField')))
Reject {New-PMMDataTableCurrentProjection $current @([pscustomobject]@{Map=$provider}) $rule $out} 'Projection accepted undeclared schema changes.'
Reject {Set-PMMTableHeaderPayloadSize ([byte[]]::new(64)) 20 24 ([pscustomobject]@{headerOffsets=[pscustomobject]@{bulkDataStart=0;exportSerialSize=8}})} 'Unproven header sizes were accepted.'
'PASS datatable guards132: '+$checks+' assertions; exact identities, family topology, schema/row preservation and header checks.'
