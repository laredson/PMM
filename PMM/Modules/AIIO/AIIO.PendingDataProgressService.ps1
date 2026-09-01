<#
AIIO requested-data progress wrapper
====================================

Keep the existing exporter as the authority, but expose request-level progress
from background workers. This makes a multi-request CREATE_MOD handoff show
which exact query/extraction is running instead of one indefinite banner.
#>

if(-not$Script:PMMAIIOBaseExportRequestedData){
  $base=Get-Command Export-PMMAIIORequestedData -CommandType Function -ErrorAction Stop
  $Script:PMMAIIOBaseExportRequestedData=$base.ScriptBlock
}

function Export-PMMAIIORequestedData {
  param($Request,[string]$Destination,[string]$SessionId)

  $pending=@(Get-PMMAIIOPendingRequests $SessionId)
  $total=[Math]::Max(1,$pending.Count)
  $index=1
  for($i=0;$i -lt $pending.Count;$i++){
    if([string]$pending[$i].RequestId -eq [string]$Request.RequestId){$index=$i+1;break}
  }
  $detail=if(-not[string]::IsNullOrWhiteSpace([string]$Request.LogicalPath)){[IO.Path]::GetFileName([string]$Request.LogicalPath)}elseif(-not[string]::IsNullOrWhiteSpace([string]$Request.Query)){[string]$Request.Query}else{[string]$Request.Capability}
  if($detail.Length -gt 88){$detail=$detail.Substring(0,85)+'...'}
  $message=('AIIO data {0}/{1}: {2} - {3}' -f $index,$total,[string]$Request.Capability,$detail)
  if(Get-Command Write-PMMOperationProgress -ErrorAction SilentlyContinue){Write-PMMOperationProgress ($index-1) $total $message $false}

  $watch=[Diagnostics.Stopwatch]::StartNew()
  try{
    & $Script:PMMAIIOBaseExportRequestedData $Request $Destination $SessionId
  }finally{
    $watch.Stop()
    Write-PMMLog ('AIIO requested data '+$index+'/'+$total+' '+[string]$Request.Capability+' completed in '+$watch.Elapsed.ToString())
    if(Get-Command Write-PMMOperationProgress -ErrorAction SilentlyContinue){Write-PMMOperationProgress $index $total ('AIIO data {0}/{1} complete.' -f $index,$total) $false}
  }
}
