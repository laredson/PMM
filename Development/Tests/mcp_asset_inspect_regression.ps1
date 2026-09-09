param([string]$Repository=([IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))))
Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
$app=Join-Path $Repository 'PMM'
$Script:Root=Join-Path $Repository ('Development\TestResults\AssetInspect-'+[guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory((Join-Path $Script:Root 'Modules'))
Copy-Item (Join-Path $app 'Modules\*') (Join-Path $Script:Root 'Modules') -Recurse
foreach($dir in @('Engine\AssetReader','Engine\dotnet','Resources\Mappings','Workspace\State','Workspace\GameReference\current\cooked','Workspace\GameReference\current\index')){[void][IO.Directory]::CreateDirectory((Join-Path $Script:Root $dir))}
Copy-Item (Join-Path $app 'Engine\AssetReader\*') (Join-Path $Script:Root 'Engine\AssetReader') -Recurse
Copy-Item (Join-Path $app 'Engine\dotnet\*') (Join-Path $Script:Root 'Engine\dotnet') -Recurse
Copy-Item (Join-Path $app 'Resources\Mappings\Mappings.usmap') (Join-Path $Script:Root 'Resources\Mappings\Mappings.usmap')
Copy-Item (Join-Path $app 'Workspace\State\config.json') (Join-Path $Script:Root 'Workspace\State\config.json')
Copy-Item (Join-Path $app 'Workspace\GameReference\current.json') (Join-Path $Script:Root 'Workspace\GameReference\current.json')
$asset='Pal/Content/Pal/DataTable/Character/DT_PalPlayerParameter.uasset'
$lines=@(Get-Content (Join-Path $app 'Workspace\GameReference\current\index\families.jsonl') | Where-Object{($_|ConvertFrom-Json).Asset -eq $asset})
if($lines.Count -ne 1){throw 'Real reference fixture missing.'}
$family=$lines[0]|ConvertFrom-Json
$lines | Set-Content (Join-Path $Script:Root 'Workspace\GameReference\current\index\families.jsonl') -Encoding UTF8
foreach($part in $family.Parts){
 $dest=Join-Path $Script:Root ('Workspace\GameReference\current\cooked\'+$part.RelativePath)
 [void][IO.Directory]::CreateDirectory((Split-Path $dest -Parent))
 Copy-Item (Join-Path $app ('Workspace\GameReference\current\cooked\'+$part.RelativePath)) $dest
}
. (Join-Path $app 'Modules\Shared\Paths.ps1')
Initialize-PMMPaths $Script:Root | Out-Null
. (Join-Path $app 'Modules\Shared\Common.ps1')
. (Join-Path $app 'Modules\GameReference\GameReferenceService.ps1')
. (Join-Path $app 'Modules\AIIO\AIIO.SessionService.ps1')
. (Join-Path $app 'Modules\AIIO\AIIO.ModCreationService.ps1')
. (Join-Path $app 'Modules\AIIO\AIIO.CaseWorkspaceService.ps1')
. (Join-Path $app 'Modules\MCP\MCP.Service.ps1')
Set-PMMMCPEnabled $true
$c=New-PMMAIIOCase -Title 'Inspect test'
$a=[pscustomobject]@{caseId=$c.CaseId;logicalPath=$asset;mode='datatable';limit=5}
$r=Invoke-PMMMCPTool 'pmm_asset_inspect' $a
if($r.values.Count -ne 5 -or $r.nextOffset -ne 5 -or $r.cached){throw 'First inspection or pagination failed'}
$r2=Invoke-PMMMCPTool 'pmm_asset_inspect' $a
if(-not $r2.cached -or ($r.values|ConvertTo-Json -Depth 8 -Compress) -cne ($r2.values|ConvertTo-Json -Depth 8 -Compress)){throw 'Cache failed'}
$a|Add-Member -NotePropertyName offset -NotePropertyValue 5
$r3=Invoke-PMMMCPTool 'pmm_asset_inspect' $a
if($r3.values[0].path -eq $r.values[0].path){throw 'Second page repeated'}
$a|Add-Member -NotePropertyName query -NotePropertyValue 'supportedScalar'
$r4=Invoke-PMMMCPTool 'pmm_asset_inspect' $a
if($r4.total -le 0){throw 'Query failed'}
$header=Join-Path $Script:Root ('Workspace\GameReference\current\cooked\'+$asset)
[IO.File]::AppendAllText($header,'tampered')
$blocked=$false;try{Invoke-PMMMCPTool 'pmm_asset_inspect' $a | Out-Null}catch{$blocked=$true}
if(-not $blocked){throw 'Cache bypassed source integrity'}
$a.logicalPath='../outside.uasset'
$blocked=$false;try{Invoke-PMMMCPTool 'pmm_asset_inspect' $a | Out-Null}catch{$blocked=$true}
if(-not $blocked){throw 'Unscoped asset accepted'}
'ASSET_INSPECT_OK: real AssetReader without Unreal, JSON pages, query, cache, source integrity, path boundary.'
