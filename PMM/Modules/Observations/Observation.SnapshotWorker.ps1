param([Parameter(Mandatory)][string]$Root,[Parameter(Mandatory)][string]$GameRoot)
$ErrorActionPreference='Stop'
$Script:Root=[IO.Path]::GetFullPath($Root)
$Script:PMMPaths=[ordered]@{Workspace=(Join-Path $Root 'Workspace');State=(Join-Path $Root 'Workspace\State')}
. (Join-Path $Root 'Modules\Shared\Paths.ps1')
. (Join-Path $Root 'Modules\Shared\Persistence.ps1')
. (Join-Path $Root 'Modules\Knowledge\Knowledge.Service.ps1')
. (Join-Path $Root 'Modules\Observations\Observation.Service.ps1')
try { New-PMMObservationDeploymentSnapshot -GameRoot $GameRoot|Out-Null }
catch {
    $path=Get-PMMObservationSnapshotPath $GameRoot
    Write-PMMKnowledgeJson $path ([pscustomobject]@{Schema='PMM_OBSERVATION_DEPLOYMENT_V1';GameRoot=$GameRoot;Verified=$false;VerifiedUtc=[DateTime]::UtcNow.ToString('o');Error=$_.Exception.Message})
    exit 1
}

