function Show-PMMChatGPTCase {
  [void](Save-PMMAIIOCaseEditor)
  $case=Get-PMMAIIOSelectedCase
  if(-not$case){throw 'Select a case first.'}
  $options=New-PMMDeepAnalysisOptions;$options.AutomaticSolution=$true
  $session=New-PMMRepairSession $case.CaseId $options
  Set-PMMMCPEnabled $true
  Start-PMMRepairAgentJob $session.Id|Out-Null
  $Script:DeepRepairSessionId=$session.Id
  if($Script:DeepControls){$Script:DeepControls.Status.Text='Persistent GPTD session: '+$session.Id}
}
