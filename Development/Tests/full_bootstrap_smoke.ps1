param([string]$Repository=([IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))))
Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
$testRoot=Join-Path $Repository ('Development\TestResults\Bootstrap-'+[guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($testRoot)
foreach($language in @('en','es')){
  $fixture=Join-Path $testRoot $language
  [void][IO.Directory]::CreateDirectory($fixture)
  foreach($name in @('Modules','Resources','CKL','Engine')){Copy-Item -LiteralPath (Join-Path $Repository ('PMM\'+$name)) -Destination (Join-Path $fixture $name) -Recurse -Force}
  . (Join-Path $Repository 'PMM\Modules\Shared\Paths.ps1')
  Initialize-PMMPaths $fixture|Out-Null
  . (Join-Path $Repository 'PMM\Modules\Shared\Common.ps1')
  Initialize-PMM
  $cfg=Get-PMMConfig;$cfg.Language=$language;Save-PMMConfig $cfg
  $bootstrap=Join-Path $fixture 'Modules\Bootstrap\Start-PalModMerger.ps1'
  $source=[IO.File]::ReadAllText($bootstrap)
  # Test-only changes disable dependency provisioning, game discovery, foreground
  # handoff and the unbounded modal lifetime. All actual service/UI loading stays.
  $source=$source.Replace('$autoDepsOk = Initialize-PMMDependenciesIfNeeded','$autoDepsOk = $true')
  $instrument=@'
  $Script:StartupDetectionDone=$true
  $Window.ShowInTaskbar=$false;$Window.ShowActivated=$false;$Window.Opacity=0
  $Window.WindowStartupLocation=[Windows.WindowStartupLocation]::Manual;$Window.Left=-32000;$Window.Top=-32000
  $Window.Show();$Window.UpdateLayout()
  if(-not$Script:PMMWorkbench){throw 'Workbench was not initialized by the real bootstrap.'}
  $expected=@('Play','Create')
  foreach($mode in $expected){Set-PMMWorkbenchMode $mode;$Window.UpdateLayout()}
  foreach($page in @('Library','Saves','History','Cases','Resources','Tools','Knowledge')){[IO.File]::WriteAllText((Join-Path $Script:Root 'last-page.txt'),$page);Show-PMMWorkbenchPage $page;$Window.UpdateLayout()}
  Set-PMMWorkbenchMode 'Play'
  if([string](Get-PMMConfig).GamePath){throw 'Isolated UI unexpectedly discovered a real game installation.'}
  $frame=[Windows.Threading.DispatcherFrame]::new()
  $timer=[Windows.Threading.DispatcherTimer]::new();$timer.Interval=[TimeSpan]::FromMilliseconds(200)
  $timer.Add_Tick({$timer.Stop();$frame.Continue=$false});$timer.Start()
  [Windows.Threading.Dispatcher]::PushFrame($frame)
  # Opening Tools starts a real worker. Drain its result before closing this
  # fixture so no child retains redirected output handles after the host exits.
  $deadline=[DateTime]::UtcNow.AddSeconds(35)
  while($Script:PMMWorkbench.ToolLease -and [DateTime]::UtcNow -lt $deadline){
    $frame=[Windows.Threading.DispatcherFrame]::new()
    $timer=[Windows.Threading.DispatcherTimer]::new();$timer.Interval=[TimeSpan]::FromMilliseconds(100)
    $timer.Add_Tick({$timer.Stop();$frame.Continue=$false}.GetNewClosure());$timer.Start()
    [Windows.Threading.Dispatcher]::PushFrame($frame)
  }
  if($Script:PMMWorkbench.ToolLease){throw 'Real bootstrap worker did not finish before fixture close.'}
  [IO.File]::WriteAllText((Join-Path $Script:Root 'bootstrap-ok.txt'),('FULL_BOOTSTRAP_OK '+[string](Get-PMMConfig).Language))
  $Window.Close()
'@
  if(-not$source.Contains('[void]$Window.ShowDialog()')){throw 'Bootstrap modal hook changed; update the isolated test.'}
  $source=$source.Replace('[void]$Window.ShowDialog()',$instrument)
  [IO.File]::WriteAllText($bootstrap,$source,[Text.UTF8Encoding]::new($true))
  $process=Start-Process -FilePath (Join-Path $PSHOME 'powershell.exe') -ArgumentList @('-NoProfile','-STA','-ExecutionPolicy','Bypass','-File',('"'+$bootstrap+'"')) -PassThru -WindowStyle Hidden -RedirectStandardError (Join-Path $fixture 'stderr.txt') -RedirectStandardOutput (Join-Path $fixture 'stdout.txt')
  $null=$process.Handle
  if(-not$process.WaitForExit(55000)){$process.Kill();$process.WaitForExit();throw ('Isolated bootstrap exceeded 55 seconds: '+$fixture)}
  $process.WaitForExit();$process.Refresh()
  $stderr=[IO.File]::ReadAllText((Join-Path $fixture 'stderr.txt'))
  if($process.ExitCode -ne 0 -or -not(Test-Path -LiteralPath (Join-Path $fixture 'bootstrap-ok.txt'))){throw ('Isolated full bootstrap failed ('+$language+'): '+$stderr+' Fixture: '+$fixture)}
  $log=Join-Path $fixture 'Workspace\Logs\PalModMerger.log'
  if(Test-Path -LiteralPath $log){$errors=@(Get-Content -LiteralPath $log|Where-Object{$_ -match 'UNHANDLED UI exception|Workbench.*(error|failed)|UI ERROR'});if($errors.Count){throw ($errors -join [Environment]::NewLine)}}
  Get-Content -LiteralPath (Join-Path $fixture 'bootstrap-ok.txt')
}
'FULL_BOOTSTRAP_SMOKE_OK: isolated real module graph, both languages, Play/Create and seven pages; no dependency installs or real-game discovery. Fixtures: '+$testRoot
