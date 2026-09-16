# Preserved 1.3.2 definitions; extracted for 1.3.3.
function Save-PMMAutoPreferences {
  # AUTO controls commit immediately. Keep them isolated from Settings values
  # that deliberately remain a draft until the user presses Apply changes.
  $cfg=Get-PMMConfig
  $cfg.AutoMode=[bool]$Script:TglAutoMode.IsChecked
  $cfg.AutoIncludePlay=[bool]$Script:ChkAutoPlay.IsChecked
  Save-PMMConfig $cfg
}

function Save-PMMAIHelpSettings {
  # AI & Help settings commit independently.  Toggling one must not silently
  # save a theme or sound selection that is still awaiting Apply changes.
  $cfg=Get-PMMConfig
  $value=[bool]$Script:ChkAIIOAutoCreateErrorCases.IsChecked
  if(-not($cfg.PSObject.Properties.Name -contains 'AIIOAutoCreateErrorCases')){$cfg|Add-Member -NotePropertyName AIIOAutoCreateErrorCases -NotePropertyValue $value}else{$cfg.AIIOAutoCreateErrorCases=$value}
  Save-PMMConfig $cfg
}

function Run-Analyze {
  param([switch]$Force)
  Set-PMMAnalyzeBusy $true
  $Script:TxtStatus.Text = L 'Analyzing shared assets against vanilla...' 'Analizando assets compartidos contra vanilla...'
  try {
    $result = Invoke-PMMScan -Force:$Force
    Refresh-PMMAnalysisWorkspace
    Refresh-ConflictWorkspace
    $Script:TxtLog.Text = Get-PMMRecentLog
    $Script:TxtStatus.Text = Get-PMMStatusLine
    return $result
  } finally {
    Set-PMMAnalyzeBusy $false
  }
}