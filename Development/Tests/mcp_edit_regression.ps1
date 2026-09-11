param([string]$Repository=([IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))))
Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
$app=Join-Path $Repository 'PMM'
$Script:Root=Join-Path $Repository ('Development\TestResults\AssetInspect-'+[guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory((Join-Path $Script:Root 'Modules'))
Copy-Item (Join-Path $app 'Modules\*') (Join-Path $Script:Root 'Modules') -Recurse
foreach($dir in @('Engine\AssetReader','Engine\AssetTools','Engine\dotnet','Resources\Mappings','Workspace\State','Workspace\GameReference\current\cooked','Workspace\GameReference\current\index')){[void][IO.Directory]::CreateDirectory((Join-Path $Script:Root $dir))}
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

Copy-Item (Join-Path $app 'Engine\AssetTools\*') (Join-Path $Script:Root 'Engine\AssetTools')
Copy-Item (Join-Path $app 'Engine\repak.exe') (Join-Path $Script:Root 'Engine\repak.exe')
$a=[pscustomobject]@{caseId=$c.CaseId;logicalPath=$asset;path='/Exports/0/Table/Data/0/Value/0/Value';expected='100';value='101'}
$r=Invoke-PMMMCPTool 'pmm_asset_edit' $a
if($r.status -ne 'EDITED'){throw 'Edit failed'}
$b=[pscustomobject]@{caseId=$c.CaseId;candidateId=$r.candidateId}
$built=Invoke-PMMMCPTool 'pmm_candidate_build' $b
if($built.status -ne 'CANDIDATE_BUILT' -or $built.deployed){throw 'Build contract failed'}
$items=Invoke-PMMMCPTool 'pmm_candidates_list' ([pscustomobject]@{caseId=$c.CaseId})
if(@($items.candidates).Count -ne 1 -or $items.candidates[0].status -ne 'CANDIDATE_BUILT'){throw 'Candidate not listed'}
$a.expected='999';$failed=$false
try{Invoke-PMMMCPTool 'pmm_asset_edit' $a|Out-Null}catch{$failed=$true}
if(-not $failed){throw 'Wrong expected value accepted'}
$dir=Get-PMMMCPAssetCandidate $c.CaseId $r.candidateId
[IO.File]::AppendAllText((Join-Path $dir ('cooked\'+$asset)),'tampered')
$failed=$false
try{Invoke-PMMMCPTool 'pmm_candidate_build' $b|Out-Null}catch{$failed=$true}
if(-not $failed){throw 'Tampered candidate accepted'}
'ASSET_EDIT_BUILD_PASS: isolated real DataTable, scalar edit, serialized export check, PAK readback hashes, stale-value rejection and tamper rejection. Not an inventory mod.'
