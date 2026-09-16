param([string]$Repository=([IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))))
Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
$app=Join-Path $Repository 'PMM'
$Script:Root=Join-Path $Repository ('Development\TestResults\MCP-Reference-'+[guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($Script:Root)
Copy-Item (Join-Path $app 'Modules') (Join-Path $Script:Root 'Modules') -Recurse
foreach($dir in @('Engine','Resources\Mappings','Resources\Metadata','CKL\Stable','Workspace\State','Workspace\GameReference','Workspace\Cache','Workspace\Logs','Game\Pal\Content\Paks','Fixture\Pal\Content\Pal\DataTable')){
 [void][IO.Directory]::CreateDirectory((Join-Path $Script:Root $dir))
}
Copy-Item (Join-Path $app 'Engine\repak.exe') (Join-Path $Script:Root 'Engine\repak.exe')
Copy-Item (Join-Path $app 'Resources\Metadata\RELEASE_MANIFEST.json') (Join-Path $Script:Root 'Resources\Metadata\RELEASE_MANIFEST.json')
[IO.File]::WriteAllText((Join-Path $Script:Root 'Resources\Mappings\Mappings.usmap'),'synthetic mappings')
[IO.File]::WriteAllText((Join-Path $Script:Root 'Fixture\Pal\Content\Pal\DataTable\Inventory.uasset'),'synthetic asset')
& (Join-Path $Script:Root 'Engine\repak.exe') pack (Join-Path $Script:Root 'Fixture') (Join-Path $Script:Root 'Game\Pal\Content\Paks\Pal-Windows.pak')
if($LASTEXITCODE){throw 'Fixture pack failed'}
. (Join-Path $app 'Modules\Shared\Paths.ps1')
Initialize-PMMPaths $Script:Root | Out-Null
. (Join-Path $app 'Modules\Shared\Common.ps1')
. (Join-Path $app 'Modules\GameReference\GameReferenceService.ps1')
. (Join-Path $app 'Modules\AIIO\AIIO.SessionService.ps1')
. (Join-Path $app 'Modules\MCP\MCP.Service.ps1')
@{GamePath=(Join-Path $Script:Root 'Game');Language='en'} | ConvertTo-Json | Set-Content (Join-Path $Script:Root 'Workspace\State\config.json') -Encoding UTF8
Set-PMMMCPEnabled $true
$before=(Get-FileHash (Join-Path $Script:Root 'Game\Pal\Content\Paks\Pal-Windows.pak')).Hash
$r=Invoke-PMMMCPTool 'pmm_reference_prepare' ([pscustomobject]@{})
if($r.status -ne 'RUNNING'){throw 'Expected running'}
$r2=Invoke-PMMMCPTool 'pmm_reference_prepare' ([pscustomobject]@{})
if($r2.status -notin @('RUNNING','Current')){throw 'Duplicate prepare failed'}
for($i=0;$i -lt 6;$i++){
 $r=Invoke-PMMMCPTool 'pmm_reference_status' ([pscustomobject]@{waitSeconds=20})
 if($r.status -ne 'RUNNING'){break}
}
if($r.status -ne 'Current'){$r | ConvertTo-Json;Get-Content (Join-Path $Script:Root 'Workspace\MCP\ReferenceJob\stderr.txt');throw 'Reference did not finish'}
$prepared=Invoke-PMMMCPTool 'pmm_reference_prepare' ([pscustomobject]@{})
if($prepared.status -ne 'Current'){throw 'Current reference was not reused'}
if((Get-FileHash (Join-Path $Script:Root 'Game\Pal\Content\Paks\Pal-Windows.pak')).Hash -ne $before){throw 'Source PAK changed'}
$blocked=$false
try{Invoke-PMMMCPTool 'pmm_reference_prepare' ([pscustomobject]@{path='C:\Windows'}) | Out-Null}catch{$blocked=$true}
if(-not $blocked){throw 'Arbitrary path accepted'}
Set-PMMMCPEnabled $false
$blocked=$false;try{Invoke-PMMMCPTool 'pmm_reference_prepare' ([pscustomobject]@{})|Out-Null}catch{$blocked=$true}
if(-not $blocked){throw 'Disabled prepare accepted'}
'MCP_REFERENCE_OK: real repak, background preparation, progress, reuse, unchanged source, path rejection, revocation.'
