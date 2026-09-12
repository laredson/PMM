param(
  [string]$Repository=([IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))),
  [ValidateSet('en','es')][string]$Language='es',
  [switch]$InsideBootstrap
)
Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
if($InsideBootstrap){
  $Script:ActionAssertions=0
  function Assert-WorkbenchAction([bool]$Condition,[string]$Message){
    if(-not$Condition){throw $Message};$Script:ActionAssertions++
  }
  function Set-WorkbenchActionPhase([string]$Phase){
    [IO.File]::WriteAllText((Join-Path $Script:Root 'actions-phase.txt'),$Phase)
  }
  function Invoke-WorkbenchDispatcherSlice{
    $frame=[Windows.Threading.DispatcherFrame]::new()
    $timer=[Windows.Threading.DispatcherTimer]::new();$timer.Interval=[TimeSpan]::FromMilliseconds(50)
    $timer.Add_Tick({$timer.Stop();$frame.Continue=$false}.GetNewClosure());$timer.Start()
    [Windows.Threading.Dispatcher]::PushFrame($frame)
  }
  function Wait-WorkbenchAction([string]$ExpectedMode,[string]$ExpectedStatus='Complete'){
    $resultPath=$Script:PMMWorkbench.ToolResult
    $deadline=[DateTime]::UtcNow.AddSeconds(35)
    while($Script:PMMWorkbench.ToolLease -and [DateTime]::UtcNow -lt $deadline){Invoke-WorkbenchDispatcherSlice}
    Assert-WorkbenchAction (-not$Script:PMMWorkbench.ToolLease) ('Worker did not release lease: '+$ExpectedMode+' / '+$Script:TxtStatus.Text)
    Assert-WorkbenchAction (-not(Get-PMMModuleRuntimeSnapshot).Busy) ('Runtime still busy after '+$ExpectedMode)
    Assert-WorkbenchAction ($null -eq $Script:PMMWorkbench.ToolProcess -and $null -eq $Script:PMMWorkbench.ToolHandle) ('Worker resources retained after '+$ExpectedMode)
    Assert-WorkbenchAction (-not$Script:PMMWorkbench.ToolTimer.IsEnabled) ('Worker timer retained after '+$ExpectedMode)
    $result=Read-PMMJsonFile -Path $resultPath
    Assert-WorkbenchAction ($result.Schema -ceq 'PMM_TOOL_WORKER_RESULT_V1') 'Worker result lost contract'
    Assert-WorkbenchAction ($result.Mode -ceq $ExpectedMode -and $result.Status -ceq $ExpectedStatus) ('Unexpected worker result: '+($result|ConvertTo-Json -Depth 5 -Compress))
    return $result
  }
  try{
    Set-WorkbenchActionPhase 'bootstrap'
    $Script:StartupDetectionDone=$true
    $Window.ShowInTaskbar=$false;$Window.ShowActivated=$false;$Window.Opacity=0
    $Window.WindowStartupLocation=[Windows.WindowStartupLocation]::Manual;$Window.Left=-32000;$Window.Top=-32000
    $Window.Show();$Window.UpdateLayout()
    if($Script:PMMWorkbench.ObservationTimer){$Script:PMMWorkbench.ObservationTimer.Stop()}
    Assert-WorkbenchAction ([string]::IsNullOrWhiteSpace([string](Get-PMMConfig).GamePath)) 'Fixture discovered a real game installation'
    Assert-WorkbenchAction ($Script:PMMWorkbench.ActivePage -eq 'Library') 'Real bootstrap did not start in Library'

    Set-WorkbenchActionPhase 'capabilities'
    # Real CLI, intentionally no CaseId. Hold the real dispatcher callback until
    # after the process exits to verify the result-consumption ownership boundary.
    Start-PMMWorkbenchTool -Mode Capabilities
    $Script:PMMWorkbench.ToolTimer.Stop()
    $firstJob=$Script:PMMWorkbench.ToolJob;$firstLease=$Script:PMMWorkbench.ToolLease.Id
    $child=$Script:PMMWorkbench.ToolProcess;$null=$child.Handle
    if(-not$child.WaitForExit(30000)){throw 'Capabilities worker timed out'}
    $child.WaitForExit();$child.Refresh()
    Assert-WorkbenchAction ($child.ExitCode -eq 0) ('Capabilities CLI failed: '+[IO.File]::ReadAllText((Join-Path $firstJob 'stderr.txt')))
    Assert-WorkbenchAction ([bool]$Script:PMMWorkbench.ToolLease -and (Get-PMMModuleRuntimeSnapshot).Busy) 'Exited worker released its lease before consuming its result'
    $blocked=$false
    try{Start-PMMWorkbenchTool -Mode ScanKnowledge}catch{$blocked=$true}
    Assert-WorkbenchAction $blocked 'A second click replaced an unconsumed worker result'
    Assert-WorkbenchAction ($Script:PMMWorkbench.ToolJob -ceq $firstJob -and $Script:PMMWorkbench.ToolLease.Id -ceq $firstLease) 'Blocked click changed the active worker'
    $Script:ActionCapabilityCallbackCount=0
    $Script:OriginalActionCapabilities=(Get-Command Set-PMMWorkbenchCapabilities).ScriptBlock
    function Set-PMMWorkbenchCapabilities($Rows){
      $Script:ActionCapabilityCallbackCount++
      # Simulate dispatcher reentry from a nested modal callback. Real callback
      # ownership must prevent this same completed result from being consumed twice.
      if($Script:ActionCapabilityCallbackCount -eq 1){Update-PMMWorkbenchTool}
      & $Script:OriginalActionCapabilities $Rows
    }
    $Script:PMMWorkbench.ToolTimer.Start()
    $capabilities=Wait-WorkbenchAction 'Capabilities'
    Assert-WorkbenchAction ($Script:ActionCapabilityCallbackCount -eq 1) 'Dispatcher reentry consumed the same capabilities result twice'
    Assert-WorkbenchAction (@($capabilities.Result).Count -gt 0) 'No real adapter capabilities returned'
    Assert-WorkbenchAction ($Script:PMMWorkbench.ToolGrid.Items.Count -eq @($capabilities.Result).Count) 'Capabilities callback did not populate the grid'
    foreach($capability in @($capabilities.Result)){
      Assert-WorkbenchAction ($capability.ContractVersion -eq 1 -and [bool]$capability.Id) 'Capabilities lost adapter provenance'
    }

    Set-WorkbenchActionPhase 'knowledge'
    $Script:ActionKnowledgeCallbackCount=0
    $Script:OriginalActionKnowledge=(Get-Command Set-PMMWorkbenchKnowledgeRows).ScriptBlock
    function Set-PMMWorkbenchKnowledgeRows($Candidates,$Imports){
      $Script:ActionKnowledgeCallbackCount++
      & $Script:OriginalActionKnowledge $Candidates $Imports
    }
    Start-PMMWorkbenchTool -Mode ScanKnowledge
    $knowledge=Wait-WorkbenchAction 'ScanKnowledge'
    Assert-WorkbenchAction (@($knowledge.Result.Candidates).Count -eq 0 -and @($knowledge.Result.Imports).Count -eq 0) 'New fixture has unexpected shared knowledge'
    Assert-WorkbenchAction ($Script:PMMWorkbench.KnowledgeGrid.Items.Count -eq 0) 'Knowledge callback did not refresh its empty grid'

    Set-WorkbenchActionPhase 'context-multiple'
    $inputRoot=Join-Path $Script:Root 'Workspace\TestInputs';[void][IO.Directory]::CreateDirectory($inputRoot)
    $mods=@(foreach($index in @(1,2)){
      $path=Join-Path $inputRoot ('selected-'+$index+'.pak');[IO.File]::WriteAllText($path,('Synthetic case reference '+$index))
      [pscustomobject]@{Name=[IO.Path]::GetFileName($path);Path=$path;Hash=(Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant();Priority=$index;Enabled=$true}
    })
    Start-PMMWorkbenchTool -Mode CreateContextCase -Request ([pscustomobject]@{Type='Compat';Mods=$mods;Title='Async compatibility';Description='Context from two selected mods';Origin='Jugar'})
    $context=Wait-WorkbenchAction 'CreateContextCase'
    $firstCase=Get-PMMAIIOCase ([string]$context.Result.CaseId)
    Assert-WorkbenchAction ($firstCase.Type -ceq 'COMPATIBILITY' -and $firstCase.Origin -ceq 'Jugar') 'Context worker lost case kind or origin'
    Assert-WorkbenchAction (@($firstCase.References.Mods).Count -eq 2 -and [bool]$firstCase.CurrentEvidenceRevision) 'Context worker lost providers or evidence revision'
    Assert-WorkbenchAction ($Script:PMMWorkbench.Mode -ceq 'Create' -and $Script:PMMWorkbench.ActivePage -ceq 'Cases' -and $Script:PMMAIIOCaseSelectedId -ceq $firstCase.CaseId) 'Context result did not select its case in Create'
    foreach($mod in $mods){
      $reference=@($firstCase.References.Mods|Where-Object Name -CEQ $mod.Name)
      Assert-WorkbenchAction ($reference.Count -eq 1 -and $reference[0].Path -ceq $mod.Path -and $reference[0].Sha256 -ceq $mod.Hash) 'Context lost exact selected-file provenance'
    }
    Start-PMMWorkbenchTool -Mode CreateContextCase -Request ([pscustomobject]@{Type='Query';Mods=@($mods[1]);Title='Separate async question';Description='Independent question';Origin='Crear'})
    $context2=Wait-WorkbenchAction 'CreateContextCase'
    $secondCase=Get-PMMAIIOCase ([string]$context2.Result.CaseId)
    Assert-WorkbenchAction ($secondCase.CaseId -cne $firstCase.CaseId -and $secondCase.Type -ceq 'QUERY' -and @($secondCase.References.Mods).Count -eq 1) 'Independent context case was deduplicated or lost its type'
    Assert-WorkbenchAction (@(Get-PMMAIIOCases).Count -eq 2) 'Context callbacks created extra cases'
    Show-PMMWorkbenchPage 'Settings'
    Assert-WorkbenchAction ($Script:PMMWorkbench.Mode -ceq 'Create') 'Shared Settings page changed Create mode'
    Show-PMMWorkbenchPage 'Cases'
    Assert-WorkbenchAction ($Script:PMMAIIOCaseSelectedId -ceq $secondCase.CaseId) 'Settings navigation lost case selection'

    Set-WorkbenchActionPhase 'failure-cleanup'
    Start-PMMWorkbenchTool -Mode CreateContextCase -Request ([pscustomobject]@{Type='Query';Mods=@();Title='Rejected';Description='Invalid fields';Origin='Crear';Forbidden='must reject'})
    $failed=Wait-WorkbenchAction 'CreateContextCase' 'Failed'
    Assert-WorkbenchAction ([bool]$failed.Error -and $Script:PMMWorkbench.ToolOutput.Text -ceq [string]$failed.Error) 'Failed callback did not expose its actual worker diagnostic'
    Assert-WorkbenchAction (@(Get-PMMAIIOCases).Count -eq 2) 'Failed context worker published a partial case'

    Set-WorkbenchActionPhase 'sync-follow-up'
    Start-PMMWorkbenchTool -CaseId $firstCase.CaseId -SyncCandidates
    $syncJob=$Script:PMMWorkbench.ToolJob
    $synchronized=Wait-WorkbenchAction 'SyncCandidates'
    Assert-WorkbenchAction (@($synchronized.Result).Count -eq 0) 'Empty fixture synchronized unexpected candidates'
    Assert-WorkbenchAction ($Script:PMMWorkbench.ToolJob -cne $syncJob) 'Candidate synchronization did not queue knowledge refresh'
    $followUp=Read-PMMJsonFile -Path $Script:PMMWorkbench.ToolResult
    Assert-WorkbenchAction ($followUp.Mode -ceq 'ScanKnowledge' -and $followUp.Status -ceq 'Complete') 'Queued knowledge refresh failed'
    Assert-WorkbenchAction ($Script:ActionKnowledgeCallbackCount -eq 2) 'Candidate synchronization queued zero or duplicate knowledge callbacks'
    $preservedOutput=$Script:PMMWorkbench.ToolOutput.Text|ConvertFrom-Json
    Assert-WorkbenchAction ($preservedOutput.Mode -ceq 'SyncCandidates') 'Automatic refresh erased the original operation result'

    Set-WorkbenchActionPhase 'drafts'
    $draftA=[pscustomobject]@{logicalPath='Pal/Content/First.uasset';query='First property';path='/First';expected='1';value='2';candidateId=''}
    $draftB=[pscustomobject]@{logicalPath='Pal/Content/Second.uasset';query='Second property';path='/Second';expected='3';value='4';candidateId=''}
    Save-PMMWorkbenchToolDraft $firstCase.CaseId $draftA
    Save-PMMWorkbenchToolDraft $secondCase.CaseId $draftB
    Assert-WorkbenchAction ((Get-PMMWorkbenchToolDraft $firstCase.CaseId).query -ceq 'First property') 'First case draft failed persistence'
    Assert-WorkbenchAction ((Get-PMMWorkbenchToolDraft $secondCase.CaseId).query -ceq 'Second property') 'Second case draft overwrote first'
    $Script:OriginalActionDialog=(Get-Command New-PMMThemedDialog).ScriptBlock
    $Script:ModalActionState=$null
    # Only the window factory is decorated: the actual editor builds controls,
    # enters ShowDialog, reads the saved draft and persists through Closing.
    function New-PMMThemedDialog([string]$Title){
      $dialog=& $Script:OriginalActionDialog $Title
      $view=$dialog.window;$body=$dialog.body;$state=$Script:ModalActionState
      $view.ShowInTaskbar=$false;$view.ShowActivated=$false;$view.Opacity=0
      $view.WindowStartupLocation=[Windows.WindowStartupLocation]::Manual;$view.Left=-32000;$view.Top=-32000
      $timer=[Windows.Threading.DispatcherTimer]::new();$timer.Interval=[TimeSpan]::FromMilliseconds(100)
      $state.Timer=$timer
      $timer.Add_Tick({
        $timer.Stop()
        try{
          $boxes=@($body.Children|Where-Object{$_ -is [Windows.Controls.TextBox]})
          $state.Values=@($boxes|ForEach-Object{[string]$_.Text})
          if($boxes.Count -ne 6){throw 'Actual structured editor did not construct all six inputs'}
          if($state.Change){$boxes[1].Text=[string]$state.Change;$boxes[4].Text='99'}
          $state.Opened=$view.IsVisible
        }catch{$state.Error=$_.Exception.Message}
        finally{$view.Close()}
      }.GetNewClosure())
      $timer.Start()
      return $dialog
    }
    $Script:PMMWorkbench.LastCandidate='only-first-case-candidate';$Script:PMMWorkbench.LastCandidateCase=$firstCase.CaseId
    Select-PMMCaseLocation $firstCase
    $Script:ModalActionState=@{Opened=$false;Values=@();Change='Edited first property';Error='';Timer=$null}
    Show-PMMWorkbenchToolEditor
    Assert-WorkbenchAction ($Script:ModalActionState.Opened -and -not$Script:ModalActionState.Error) ('First modal failed: '+$Script:ModalActionState.Error)
    Assert-WorkbenchAction ($Script:ModalActionState.Values[0] -ceq $draftA.logicalPath -and $Script:ModalActionState.Values[1] -ceq 'First property') 'First modal did not restore its draft'
    Assert-WorkbenchAction ($Script:ModalActionState.Values[5] -ceq 'only-first-case-candidate') 'Candidate provenance was not restored to its originating case'
    Assert-WorkbenchAction ((Get-PMMWorkbenchToolDraft $firstCase.CaseId).query -ceq 'Edited first property' -and (Get-PMMWorkbenchToolDraft $firstCase.CaseId).value -ceq '99') 'Modal Closing did not persist edits'
    Select-PMMCaseLocation $secondCase
    $Script:ModalActionState=@{Opened=$false;Values=@();Change='';Error='';Timer=$null}
    Show-PMMWorkbenchToolEditor
    Assert-WorkbenchAction ($Script:ModalActionState.Opened -and -not$Script:ModalActionState.Error) ('Second modal failed: '+$Script:ModalActionState.Error)
    Assert-WorkbenchAction ($Script:ModalActionState.Values[0] -ceq $draftB.logicalPath -and $Script:ModalActionState.Values[1] -ceq 'Second property') 'Second modal restored another case draft'
    Assert-WorkbenchAction ($Script:ModalActionState.Values[5] -ceq '') 'Candidate from another case leaked into the editor'
    Assert-WorkbenchAction ((Get-PMMWorkbenchToolDraft $firstCase.CaseId).query -ceq 'Edited first property') 'Second modal Closing overwrote first case draft'
    $fresh=New-PMMContextCase -Type NewMod -Title 'No saved draft' -Origin Crear
    Select-PMMCaseLocation $fresh
    $Script:ModalActionState=@{Opened=$false;Values=@();Change='Fresh property';Error='';Timer=$null}
    Show-PMMWorkbenchToolEditor
    Assert-WorkbenchAction ($Script:ModalActionState.Opened -and -not$Script:ModalActionState.Error -and $Script:ModalActionState.Values[0] -ceq '') 'Fresh modal failed without a saved draft'
    Assert-WorkbenchAction ((Get-PMMWorkbenchToolDraft $fresh.CaseId).query -ceq 'Fresh property') 'Fresh draft was not persisted by Closing'
    Set-WorkbenchActionPhase 'feedback-modal'
    $Script:FeedbackActionState=@{Calls=0;GuardObserved=$false;ObservationPaused=$false;Error='';Timer=$null}
    $Script:FeedbackActionGroup=[pscustomobject]@{SessionId='fixture-empty-group';Candidates=@()}
    function New-PMMThemedDialog([string]$Title){
      $state=$Script:FeedbackActionState;$state.Calls++
      if($state.Calls -gt 1){throw 'Nested feedback call constructed a duplicate window'}
      $dialog=& $Script:OriginalActionDialog $Title
      $view=$dialog.window;$workbench=$Script:PMMWorkbench;$group=$Script:FeedbackActionGroup
      $view.ShowInTaskbar=$false;$view.ShowActivated=$false;$view.Opacity=0
      $view.WindowStartupLocation=[Windows.WindowStartupLocation]::Manual;$view.Left=-32000;$view.Top=-32000
      $timer=[Windows.Threading.DispatcherTimer]::new();$timer.Interval=[TimeSpan]::FromMilliseconds(100);$state.Timer=$timer
      $timer.Add_Tick({
        $timer.Stop()
        try{
          $state.GuardObserved=[bool]$workbench.FeedbackDialogOpen
          $state.ObservationPaused=-not$workbench.ObservationTimer.IsEnabled
          Show-PMMWorkbenchFeedback $group
        }catch{$state.Error=$_.Exception.Message}
        finally{$view.Close()}
      }.GetNewClosure())
      $timer.Start();return $dialog
    }
    # An empty synthetic group isolates modal lifetime. Observation/candidate
    # evidence is covered by the service suite; this test creates no game session.
    $Script:PMMWorkbench.ObservationTimer.Start()
    Show-PMMWorkbenchFeedback $Script:FeedbackActionGroup
    Assert-WorkbenchAction ($Script:FeedbackActionState.Calls -eq 1 -and -not$Script:FeedbackActionState.Error) ('Feedback modal reentered: '+$Script:FeedbackActionState.Error)
    Assert-WorkbenchAction ($Script:FeedbackActionState.GuardObserved -and $Script:FeedbackActionState.ObservationPaused) 'Feedback did not guard and pause observation while its modal dispatcher ran'
    Assert-WorkbenchAction (-not$Script:PMMWorkbench.FeedbackDialogOpen -and $Script:PMMWorkbench.ObservationTimer.IsEnabled) 'Feedback did not clear its guard and resume observation on close'
    $Script:PMMWorkbench.ObservationTimer.Stop()
    Assert-WorkbenchAction ([string]::IsNullOrWhiteSpace([string](Get-PMMConfig).GamePath)) 'Fixture unexpectedly configured a real game'
    [IO.File]::WriteAllText((Join-Path $Script:Root 'actions-ok.txt'),('WORKBENCH_ACTIONS_OK '+$Script:ActionAssertions+' assertions; real worker lifecycle, context provenance, failure cleanup, four actual modal dialogs, persistent case drafts and feedback reentry guard, shared Settings mode.'))
    Set-WorkbenchActionPhase 'complete'
    $Window.Close()
  }catch{
    [IO.File]::WriteAllText((Join-Path $Script:Root 'actions-error.txt'),($_|Out-String)+[Environment]::NewLine+$_.ScriptStackTrace)
    if($Script:PMMWorkbench.ToolProcess -and -not$Script:PMMWorkbench.ToolProcess.HasExited){$Script:PMMWorkbench.ToolProcess.Kill()}
    [Environment]::Exit(1)
  }
  return
}
$fixture=Join-Path $Repository ('Development\TestResults\WorkbenchActions-'+[guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($fixture)
foreach($name in @('Modules','Resources','CKL','Engine')){Copy-Item -LiteralPath (Join-Path $Repository ('PMM\'+$name)) -Destination (Join-Path $fixture $name) -Recurse -Force}
. (Join-Path $Repository 'PMM\Modules\Shared\Paths.ps1')
Initialize-PMMPaths $fixture|Out-Null
. (Join-Path $Repository 'PMM\Modules\Shared\Common.ps1')
Initialize-PMM
$cfg=Get-PMMConfig;$cfg.Language=$Language;Save-PMMConfig $cfg
$bootstrap=Join-Path $fixture 'Modules\Bootstrap\Start-PalModMerger.ps1'
$source=[IO.File]::ReadAllText($bootstrap)
$source=$source.Replace('$autoDepsOk = Initialize-PMMDependenciesIfNeeded','$autoDepsOk = $true')
if(-not$source.Contains('[void]$Window.ShowDialog()')){throw 'Real bootstrap test hook changed'}
$hook=". '"+$PSCommandPath.Replace("'","''")+"' -InsideBootstrap"
$source=$source.Replace('[void]$Window.ShowDialog()',$hook)
[IO.File]::WriteAllText($bootstrap,$source,[Text.UTF8Encoding]::new($true))
$process=Start-Process -FilePath (Join-Path $PSHOME 'powershell.exe') -ArgumentList @('-NoProfile','-STA','-ExecutionPolicy','Bypass','-File',('"'+$bootstrap+'"')) -PassThru -WindowStyle Hidden -RedirectStandardError (Join-Path $fixture 'stderr.txt') -RedirectStandardOutput (Join-Path $fixture 'stdout.txt')
$null=$process.Handle
if(-not$process.WaitForExit(120000)){$process.Kill();$process.WaitForExit();throw ('Isolated workbench actions exceeded 120 seconds: '+$fixture)}
$process.WaitForExit();$process.Refresh()
if($process.ExitCode -ne 0 -or -not(Test-Path -LiteralPath (Join-Path $fixture 'actions-ok.txt'))){
  $diagnostic=[IO.File]::ReadAllText((Join-Path $fixture 'stderr.txt'))
  if(Test-Path -LiteralPath (Join-Path $fixture 'actions-error.txt')){$diagnostic+=[IO.File]::ReadAllText((Join-Path $fixture 'actions-error.txt'))}
  throw ('Isolated workbench actions failed: '+$diagnostic+' Fixture: '+$fixture)
}
Get-Content -LiteralPath (Join-Path $fixture 'actions-ok.txt')
'Fixture: '+$fixture
