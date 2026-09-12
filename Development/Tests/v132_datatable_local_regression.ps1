Set-StrictMode -Version 2;$ErrorActionPreference='Stop'
$repo=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'));$Script:Root=Join-Path $repo 'PMM'
foreach($module in @('Shared/Paths','Shared/Common','Shared/GameLocator','Merge/PakService','Library/LibraryService','CKL/SemanticLab','GameReference/GameReferenceService','CKL/KnowledgeRecipeService','Merge/MergeEngine')){. (Join-Path $Script:Root ('Modules/'+$module+'.ps1'));if($module -eq 'Shared/Paths'){Initialize-PMMPaths $Script:Root|Out-Null}}
$plan=Read-PMMMergePlan;$asset=@($plan.Assets|Where-Object{$_.Asset -like '*DT_PalMonsterParameter_Common.uasset'})[0]
if($asset.Mode -ne 'DataTableAuto'){throw 'Expected the locally analyzed DataTable fixture.'}
$target=Join-Path $repo ('Development/TestResults/DataTable132-'+[guid]::NewGuid().ToString('N'));$transaction=Join-Path $target 'transaction';$output=Join-Path $target 'cooked'
[void][IO.Directory]::CreateDirectory($transaction);[void][IO.Directory]::CreateDirectory($output)
$mods=@(Get-LibraryMods)
Build-PMMAutoAsset $asset $mods $transaction $output
$maps=[ordered]@{Output=(Get-PMMDataTableMapCached (Join-Path $output $asset.Asset))}
$vanilla=Join-Path (Get-PMMGameReferenceRoot) ('current/cooked/'+$asset.Asset);$maps.Vanilla=Get-PMMDataTableMapCached $vanilla
foreach($name in $asset.Providers){$record=@($mods|Where-Object{$_.Name -ceq $name})[0];$family=Export-PakAssetFamilyExact $record.Path $asset.Asset (Join-Path $target $name);$maps[$name]=Get-PMMDataTableMapCached $family.HeaderPath}
$proof=Get-ChildItem (Join-Path $transaction 'DataTableLayout') -Recurse -Filter 'proof.json'|Select-Object -First 1
$evidence=Get-Content $proof.FullName -Raw|ConvertFrom-Json;$maps.Historical=$evidence.HistoricalMap
Write-PMMJsonAtomic -Path (Join-Path $repo 'Development/TestResults/datatable132-validation-inputs.json') -Value $maps -Depth 4
$currentHeader=[IO.File]::ReadAllBytes($vanilla);$outputHeader=[IO.File]::ReadAllBytes((Join-Path $output $asset.Asset))
foreach($offset in @(236,43686)){[Array]::Clear($currentHeader,$offset,8);[Array]::Clear($outputHeader,$offset,8)}
if((Get-PMMTableBytesHash $currentHeader) -cne (Get-PMMTableBytesHash $outputHeader)){throw 'Header changed outside proven size bookkeeping.'}
'PASS current cooked header preserved outside size bookkeeping; zero materialization verified in service. Output: '+$output
