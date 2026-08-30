param([string]$Root,[string[]]$Arguments,[string]$SessionDir)
Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
$Script:Root=[IO.Path]::GetFullPath($Root)
. (Join-Path $Script:Root 'Modules\Shared\Paths.ps1')
Initialize-PMMPaths $Script:Root|Out-Null
. (Join-Path $Script:Root 'Modules\Shared\Common.ps1')
. (Join-Path $Script:Root 'Modules\Merge\PakService.ps1')
. (Join-Path $Script:Root 'Modules\Library\LibraryService.ps1')
. (Join-Path $Script:Root 'Modules\GameReference\GameReferenceService.ps1')
. (Join-Path $Script:Root 'Modules\FixLab\FixLabService.ps1')
Start-PMMLogSession 'Runner-FixLab'
Initialize-PMM
Initialize-PMMFixLab

function Emit-Json($Value){$Value|ConvertTo-Json -Depth 40 -Compress|Write-Output}

$cmd=if(@($Arguments).Count -gt 0){[string]$Arguments[0]}else{'status'}
$rest=if(@($Arguments).Count -gt 1){@($Arguments|Select-Object -Skip 1)}else{@()}
switch($cmd.ToLowerInvariant()){
  'list-jobs' { Emit-Json @(Get-PMMFixLabJobs); break }
  'new' {
    if($rest.Count -lt 1){throw 'Usage: fixlab new <pak|archive>'}
    Emit-Json (New-PMMFixLabJob ([string]$rest[0])); break
  }
  'add-related' {
    if($rest.Count -lt 2){throw 'Usage: fixlab add-related <jobId> <pak|archive>'}
    Emit-Json (Add-PMMFixLabRelatedSource ([string]$rest[0]) ([string]$rest[1])); break
  }
  'analyze' {
    if($rest.Count -lt 1){throw 'Usage: fixlab analyze <jobId>'}
    Emit-Json (Invoke-PMMFixLabAnalyze ([string]$rest[0])); break
  }
  'handoff' {
    if($rest.Count -lt 1){throw 'Usage: fixlab handoff <jobId>'}
    Emit-Json ([ordered]@{Path=(Export-PMMFixLabHandoff ([string]$rest[0]))}); break
  }
  'build' {
    if($rest.Count -lt 1){throw 'Usage: fixlab build <jobId>'}
    Emit-Json (Invoke-PMMFixLabBuild ([string]$rest[0])); break
  }
  'status' {
    $job=if($rest.Count -gt 0){Get-PMMFixLabJob ([string]$rest[0])}else{Get-PMMFixLabCurrentJob}
    Emit-Json $job; break
  }
  default {throw ('Unknown Fix Lab command: '+$cmd)}
}
Stop-PMMLogSession 'Normal'
exit 0
