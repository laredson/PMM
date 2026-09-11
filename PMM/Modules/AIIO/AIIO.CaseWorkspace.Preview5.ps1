<# AIIO Case Workspace preview 5 runtime corrections.
   - Work orders may create a brand-new case and therefore case.caseId is optional.
   - Other descriptive fields are optional and receive sane defaults under StrictMode.
   - Bring the generated handoff back to the foreground when possible. #>

function Get-PMMAIIOV5Value($Object,[string]$Name,$Default=$null){
  if($null -eq $Object){return $Default}
  try{$property=$Object.PSObject.Properties[$Name];if($property){return $property.Value}}catch{}
  return $Default
}

function Get-PMMAIIOV5Array($Object,[string]$Name){
  $value=Get-PMMAIIOV5Value $Object $Name $null
  if($null -eq $value){return @()}
  return @($value)
}

function Import-PMMAIIOWorkOrder([string]$Path,$Doc,[switch]$Trusted,[switch]$AutoProcess){
  if($null -eq $Doc){throw 'Work order document is empty.'}

  $workOrderId=[string](Get-PMMAIIOV5Value $Doc 'workOrderId' '')
  if([string]::IsNullOrWhiteSpace($workOrderId)){$workOrderId='wo-'+[guid]::NewGuid().ToString('N')}

  $caseDoc=Get-PMMAIIOV5Value $Doc 'case' $null
  $requestedCaseId=[string](Get-PMMAIIOV5Value $caseDoc 'caseId' '')
  $title=[string](Get-PMMAIIOV5Value $caseDoc 'title' 'AIIO work order')
  if([string]::IsNullOrWhiteSpace($title)){$title='AIIO work order'}
  $type=[string](Get-PMMAIIOV5Value $caseDoc 'type' 'UNDEFINED')
  $description=[string](Get-PMMAIIOV5Value $caseDoc 'description' '')
  $transport=[string](Get-PMMAIIOV5Value $caseDoc 'transport' 'AUTO')

  $case=$null
  if(Test-PMMAIIOCaseId $requestedCaseId){$case=Get-PMMAIIOCase $requestedCaseId}
  if(-not$case){
    $hit=@(Get-PMMAIIOCases|Where-Object{[string](Get-PMMAIIOV5Value $_ 'WorkOrderId' '') -eq $workOrderId}|Select-Object -First 1)
    if($hit.Count -gt 0){$case=$hit[0]}
  }
  if(-not$case){
    $case=New-PMMAIIOCase -Title $title -Type $type -Description $description -Transport $transport -WorkOrderId $workOrderId -NoInitialStep
  }

  $caseRoot=Get-PMMAIIOCasePath ([string]$case.CaseId)
  $inbox=Join-Path $caseRoot 'inbox'
  $copy=Join-Path $inbox ([IO.Path]::GetFileName($Path))
  Copy-Item -LiteralPath $Path -Destination $copy -Force

  $import=Join-Path $caseRoot ('imports\'+[DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss-fff'))
  if([IO.Path]::GetExtension($Path) -ieq '.zip'){
    Expand-PMMAIIOTrustedZip $Path $import
  }else{
    New-Item -ItemType Directory -Force -Path $import|Out-Null
    Copy-Item -LiteralPath $Path -Destination (Join-Path $import 'workorder.json') -Force
  }

  $case=Get-PMMAIIOCase ([string]$case.CaseId)
  $case.TrustedInbound=[bool]$Trusted
  $case.LatestInbound=$copy

  $actions=[Collections.Generic.List[object]]::new()
  foreach($rawAction in @(Get-PMMAIIOV5Array $Doc 'actions')){
    if($null -eq $rawAction){continue}
    $name=[string](Get-PMMAIIOV5Value $rawAction 'action' '')
    if([string]::IsNullOrWhiteSpace($name)){$name=[string](Get-PMMAIIOV5Value $rawAction 'capability' '')}
    if([string]::IsNullOrWhiteSpace($name)){continue}
    $actions.Add([pscustomobject]@{
      Id=[guid]::NewGuid().ToString('N')
      Action=$name.Trim().ToLowerInvariant()
      Status='Pending'
      Original=$rawAction
      ImportRoot=$import
    })
  }

  $case.PendingActions=@($actions.ToArray())
  $case.NextAction=$(if($actions.Count -gt 0){'PROCESS_REQUESTS'}else{'CREATE_HANDOFF'})
  Save-PMMAIIOCase $case|Out-Null
  Add-PMMAIIOCaseStep $case 'WORK_ORDER_RECEIVED' ('Received AI work order: '+[IO.Path]::GetFileName($Path)) ([string]$case.NextAction) @($copy) ([pscustomobject]@{WorkOrderId=$workOrderId;ActionCount=$actions.Count})|Out-Null

  if($AutoProcess -and $actions.Count -gt 0){
    Invoke-PMMAIIOCasePendingActions ([string]$case.CaseId)|Out-Null
  }
  return (Get-PMMAIIOCase ([string]$case.CaseId))
}

function Show-PMMAIIOHandoffInExplorerV5([string]$ZipPath){
  if([string]::IsNullOrWhiteSpace($ZipPath) -or -not(Test-Path -LiteralPath $ZipPath -PathType Leaf)){return}
  $full=[IO.Path]::GetFullPath($ZipPath)
  $folder=[IO.Path]::GetDirectoryName($full)
  try{Start-Process explorer.exe -ArgumentList ('/select,"'+$full+'"')|Out-Null}catch{return}

  try{
    if(-not('PMMExplorerFocusV5' -as [type])){
      Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class PMMExplorerFocusV5 {
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
}
'@
    }
  }catch{}

  # Explorer may reuse an existing window. Give it a short moment, then find the
  # window displaying the generated handoff directory and request foreground.
  for($attempt=0;$attempt -lt 8;$attempt++){
    Start-Sleep -Milliseconds 125
    try{
      $shell=New-Object -ComObject Shell.Application
      foreach($window in @($shell.Windows())){
        try{
          $path=[string]$window.Document.Folder.Self.Path
          if($path -and ([IO.Path]::GetFullPath($path).TrimEnd('\') -ieq $folder.TrimEnd('\'))){
            $hwnd=[IntPtr]([int64]$window.HWND)
            try{[void][PMMExplorerFocusV5]::ShowWindow($hwnd,9);[void][PMMExplorerFocusV5]::SetForegroundWindow($hwnd)}catch{}
            return
          }
        }catch{}
      }
    }catch{}
  }
}

function Invoke-PMMAIIOCreateHandoffUi{
  $case=Get-PMMAIIOSelectedCase
  if(-not$case){return}
  Save-PMMAIIOCaseEditor
  $case=Get-PMMAIIOSelectedCase
  $step=[int](Get-PMMAIIOV5Value $case 'SelectedStep' 0)
  if($step -le 0){$step=[int](Get-PMMAIIOV5Value $case 'CurrentStep' 0)}
  $result=New-PMMAIIOCaseHandoff ([string]$case.CaseId) $step
  Refresh-PMMAIIOCaseList ([string]$case.CaseId)
  Set-PMMAIIOCaseUiStatus ('Handoff ready: '+[IO.Path]::GetFileName([string]$result.ZipPath))
  Show-PMMAIIOHandoffInExplorerV5 ([string]$result.ZipPath)
}
