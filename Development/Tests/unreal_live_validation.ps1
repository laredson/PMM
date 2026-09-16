param([string]$Repository=([IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))))
Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
$Script:Root=Join-Path $Repository 'PMM'
. (Join-Path $Script:Root 'Modules\Shared\Paths.ps1')
Initialize-PMMPaths $Script:Root | Out-Null
. (Join-Path $Script:Root 'Modules\AIIO\AIIO.SessionService.ps1')
. (Join-Path $Script:Root 'Modules\AIIO\AIIO.CaseWorkspaceService.ps1')
. (Join-Path $Script:Root 'Modules\MCP\MCP.Service.ps1')
$e=Get-PMMUnrealEnvironment
if(-not $e.enabled -or -not $e.readyToPrepare -or -not(Get-PMMMCPEnabled)){
    Write-Output ('UNREAL_LIVE_SKIPPED: Integration not enabled/ready. Missing: '+($e.missing -join ', '))
    return
}
$c=New-PMMAIIOCase -Title ('Unreal texture validation '+[DateTime]::Now.ToString('yyyy-MM-dd HH:mm')) -Description 'Developer smoke test: isolated texture import, duplication, configuration and Windows candidate. No deployment.' -Transport MCP
function Run-VerifiedJob([string]$Tool,[hashtable]$Values){
    $Values.caseId=$c.CaseId
    $j=Invoke-PMMMCPTool $Tool ([pscustomobject]$Values)
    $watch=[Diagnostics.Stopwatch]::StartNew()
    do{
        $s=Invoke-PMMMCPTool 'pmm_unreal_job' ([pscustomobject]@{caseId=$c.CaseId;jobId=$j.jobId;waitSeconds=20})
        if($watch.Elapsed.TotalMinutes -gt 65){
            Invoke-PMMMCPTool 'pmm_unreal_cancel' ([pscustomobject]@{caseId=$c.CaseId;jobId=$j.jobId}) | Out-Null
            throw 'Live validation timed out; cancellation requested.'
        }
    }while($s.status -in @('QUEUED','RUNNING'))
    if($s.status -ne 'COMPLETE' -or -not $s.verified){throw ($Tool+': '+$s.message)}
    Write-Host ($Tool+': COMPLETE (actual installed editor)')
    return $s
}
Run-VerifiedJob 'pmm_unreal_prepare' @{} | Out-Null
Run-VerifiedJob 'pmm_unreal_texture' @{operation='duplicate';assetName='PMMTextureProof';templateId='PMMProbe'} | Out-Null
Run-VerifiedJob 'pmm_unreal_texture' @{operation='configure';assetName='PMMTextureProof';srgb=$true;filter='nearest'} | Out-Null
$result=Run-VerifiedJob 'pmm_unreal_cook' @{}
$list=Invoke-PMMMCPTool 'pmm_unreal_candidates' ([pscustomobject]@{caseId=$c.CaseId})
$rows=@($list.candidates|Where-Object{$_.candidateId -eq $result.candidate.candidateId})
if($rows.Count -ne 1 -or $rows[0].status -ne 'VALIDATED_CANDIDATE'){throw 'Live candidate integrity check failed.'}
Write-Output ('UNREAL_LIVE_OK: '+$c.CaseId+' / '+$result.candidate.candidateId+'; Windows candidate verified; Palworld runtime UNPROVEN; not deployed.')
