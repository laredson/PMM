<# AIIO Case Workspace action parser hardening.
   Work-order action fields are optional unless the capability explicitly needs
   them. Never access untrusted PSCustomObject properties directly under
   Set-StrictMode. This module is UI-free and must be loaded by both the WPF host
   and the background CaseWorker. #>

function Get-PMMAIIOActionValue($Object,[string]$Name,$Default=$null){
  if($null -eq $Object){return $Default}
  try{$p=$Object.PSObject.Properties[$Name];if($p){return $p.Value}}catch{}
  return $Default
}

function Get-PMMAIIOActionArray($Object,[string]$Name){
  $v=Get-PMMAIIOActionValue $Object $Name $null
  if($null -eq $v){return @()}
  return @($v)
}

function Resolve-PMMAIIOActionPath([string]$Path,[string]$ImportRoot=''){
  if([string]::IsNullOrWhiteSpace($Path)){return ''}
  if([IO.Path]::IsPathRooted($Path)){return [IO.Path]::GetFullPath($Path)}
  if($ImportRoot){
    $candidate=[IO.Path]::GetFullPath((Join-Path $ImportRoot $Path))
    if(Test-Path -LiteralPath $candidate){return $candidate}
  }
  return [IO.Path]::GetFullPath((Join-Path $Script:Root $Path))
}

function Resolve-PMMAIIOActionPak($Raw,[string]$ImportRoot){
  $packagePath=[string](Get-PMMAIIOActionValue $Raw 'packagePath' '')
  if($packagePath){
    $candidate=Resolve-PMMAIIOActionPath $packagePath $ImportRoot
    if(Test-Path -LiteralPath $candidate -PathType Leaf){return $candidate}
  }
  $path=[string](Get-PMMAIIOActionValue $Raw 'path' '')
  if($path){
    $candidate=Resolve-PMMAIIOActionPath $path $ImportRoot
    if(Test-Path -LiteralPath $candidate -PathType Leaf){return $candidate}
  }
  $name=[string](Get-PMMAIIOActionValue $Raw 'name' '')
  if(-not$name){$name=[string](Get-PMMAIIOActionValue $Raw 'providerName' '')}
  foreach($m in @(Get-LibraryMods)){
    foreach($prop in @('Name','FileName','DisplayName')){
      if($m.PSObject.Properties.Name -contains $prop -and [string]$m.$prop -ieq $name){
        foreach($pp in @('Path','FullName','SourcePath','PakPath')){
          if($m.PSObject.Properties.Name -contains $pp){
            $candidate=[string]$m.$pp
            if($candidate -and (Test-Path -LiteralPath $candidate -PathType Leaf)){return [IO.Path]::GetFullPath($candidate)}
          }
        }
      }
    }
  }
  throw ('Could not resolve mod: '+$name)
}

function Invoke-PMMAIIOTrustedProcess([string]$Id,$Raw,[string]$ImportRoot,[string]$Evidence,[switch]$Command){
  $case=Get-PMMAIIOCase $Id
  if(-not[bool](Get-PMMAIIOActionValue $case 'TrustedInbound' $false)){throw 'Program/command execution requires an explicitly trusted inbound file.'}

  $timeout=300
  $timeoutRaw=Get-PMMAIIOActionValue $Raw 'timeoutSeconds' $null
  if($null -ne $timeoutRaw){try{$timeout=[Math]::Min(3600,[Math]::Max(1,[int]$timeoutRaw))}catch{}}

  $working=[string](Get-PMMAIIOActionValue $Raw 'workingDirectory' '')
  if([string]::IsNullOrWhiteSpace($working)){$working=Get-PMMPath 'App'}
  elseif(-not[IO.Path]::IsPathRooted($working)){
    $fromImport=$(if($ImportRoot){[IO.Path]::GetFullPath((Join-Path $ImportRoot $working))}else{''})
    if($fromImport -and (Test-Path -LiteralPath $fromImport -PathType Container)){$working=$fromImport}
    else{$working=[IO.Path]::GetFullPath((Join-Path $Script:Root $working))}
  }
  if(-not(Test-Path -LiteralPath $working -PathType Container)){throw ('Working directory not found: '+$working)}

  $psi=[Diagnostics.ProcessStartInfo]::new()
  $psi.UseShellExecute=$false
  $psi.CreateNoWindow=$true
  $psi.RedirectStandardOutput=$true
  $psi.RedirectStandardError=$true

  if($Command){
    $cmd=[string](Get-PMMAIIOActionValue $Raw 'command' '')
    if(-not$cmd){$cmd=[string](Get-PMMAIIOActionValue $Raw 'commandLine' '')}
    if(-not$cmd){throw 'run_command requires command text.'}
    $psi.FileName=$(if($env:ComSpec){$env:ComSpec}else{'cmd.exe'})
    $psi.Arguments='/d /s /c "'+$cmd+'"'
  }else{
    $program=[string](Get-PMMAIIOActionValue $Raw 'packagePath' '')
    if($program){$program=Resolve-PMMAIIOActionPath $program $ImportRoot}
    else{
      $program=[string](Get-PMMAIIOActionValue $Raw 'path' '')
      if(-not$program){$program=[string](Get-PMMAIIOActionValue $Raw 'program' '')}
      if($program -and (Test-Path -LiteralPath $program -PathType Leaf)){$program=[IO.Path]::GetFullPath($program)}
      elseif($program -and -not[IO.Path]::IsPathRooted($program)){
        $candidate=Resolve-PMMAIIOActionPath $program $ImportRoot
        if(Test-Path -LiteralPath $candidate -PathType Leaf){$program=$candidate}
      }
    }
    if(-not(Test-Path -LiteralPath $program -PathType Leaf)){try{$program=(Get-Command $program -ErrorAction Stop).Source}catch{}}
    if(-not(Test-Path -LiteralPath $program -PathType Leaf)){throw ('Program not found: '+$program)}

    $args=@(Get-PMMAIIOActionArray $Raw 'arguments'|ForEach-Object{[string]$_})
    $ext=[IO.Path]::GetExtension($program).ToLowerInvariant()
    if($ext -in @('.cmd','.bat')){
      $psi.FileName=$(if($env:ComSpec){$env:ComSpec}else{'cmd.exe'})
      $psi.Arguments='/d /c "'+$program+'" '+($args -join ' ')
    }elseif($ext -eq '.ps1'){
      $psi.FileName='powershell.exe'
      $psi.Arguments='-NoProfile -ExecutionPolicy Bypass -File "'+$program+'" '+($args -join ' ')
    }else{
      $psi.FileName=$program
      $psi.Arguments=($args -join ' ')
    }
  }

  $psi.WorkingDirectory=$working
  New-Item -ItemType Directory -Force -Path $Evidence|Out-Null
  $proc=[Diagnostics.Process]::new();$proc.StartInfo=$psi
  [void]$proc.Start()
  $stdoutTask=$proc.StandardOutput.ReadToEndAsync();$stderrTask=$proc.StandardError.ReadToEndAsync()
  if(-not$proc.WaitForExit($timeout*1000)){try{$proc.Kill()}catch{};throw 'Requested process timed out.'}
  $proc.WaitForExit()
  $stdoutTask.Result|Set-Content (Join-Path $Evidence 'stdout.txt') -Encoding UTF8
  $stderrTask.Result|Set-Content (Join-Path $Evidence 'stderr.txt') -Encoding UTF8
  Write-PMMAIIOCaseJson (Join-Path $Evidence 'execution.json') ([ordered]@{Program=$psi.FileName;Arguments=$psi.Arguments;WorkingDirectory=$working;ExitCode=$proc.ExitCode;Utc=[DateTime]::UtcNow.ToString('o')}) 12
  if($proc.ExitCode -ne 0){throw ('Requested process exited '+$proc.ExitCode+'. See stdout/stderr evidence.')}
  return [pscustomobject]@{Summary=('Process exited '+$proc.ExitCode);Artifacts=@((Join-Path $Evidence 'stdout.txt'),(Join-Path $Evidence 'stderr.txt'),(Join-Path $Evidence 'execution.json'))}
}

function Invoke-PMMAIIOCaseAction([string]$Id,$Action){
  $raw=Get-PMMAIIOActionValue $Action 'Original' $null
  $actionId=[string](Get-PMMAIIOActionValue $Action 'Id' ([guid]::NewGuid().ToString('N')))
  $importRoot=[string](Get-PMMAIIOActionValue $Action 'ImportRoot' '')
  $root=Join-Path (Get-PMMAIIOCaseEvidencePath $Id) $actionId
  New-Item -ItemType Directory -Force -Path $root|Out-Null
  $name=([string](Get-PMMAIIOActionValue $Action 'Action' '')).ToLowerInvariant()

  switch($name){
    'ensure_game_reference'{Ensure-PMMAIIOCaseGameReference $Id;return [pscustomobject]@{Summary='Game Reference is current';Artifacts=@()}}
    'extract_game_reference_asset'{$name='include_game_reference_family'}
    'include_vanilla_family'{$name='include_game_reference_family'}
  }
  if($name -eq 'include_game_reference_family'){
    $logical=[string](Get-PMMAIIOActionValue $raw 'logicalPath' '')
    if(-not$logical){$logical=[string](Get-PMMAIIOActionValue $raw 'path' '')}
    if(-not$logical){throw 'include_game_reference_family requires logicalPath.'}
    $files=Copy-PMMAIIOCaseVanillaFamily $Id $logical (Join-Path $root 'vanilla')
    return [pscustomobject]@{Summary=('Collected Vanilla family '+$logical);Artifacts=@($files)}
  }
  if($name -eq 'query_game_reference'){
    Ensure-PMMAIIOCaseGameReference $Id
    $q=[string](Get-PMMAIIOActionValue $raw 'query' '')
    if(-not$q){$q=[string](Get-PMMAIIOActionValue $raw 'logicalPath' '')}
    if(-not$q){throw 'query_game_reference requires query.'}
    $hits=@(Search-PMMAIIOGameReferenceFamilies -Query $q -MaximumResults 100)
    $p=Join-Path $root 'query.json';Write-PMMAIIOCaseJson $p ([ordered]@{Query=$q;Results=$hits}) 40
    return [pscustomobject]@{Summary=('Queried Game Reference for '+$q);Artifacts=@($p)}
  }
  if($name -in @('read_pmm_log','include_log')){
    $logs=Get-PMMPath 'Logs';$p=Join-Path $logs 'PalModMerger.log'
    if(-not(Test-Path $p)){$first=@(Get-ChildItem $logs -File|Sort-Object LastWriteTimeUtc -Descending|Select-Object -First 1);if($first.Count){$p=$first[0].FullName}else{$p=''}}
    if(-not$p){throw 'PMM log not found.'};$d=Join-Path $root 'PalModMerger.log';Get-Content $p -Tail 2000|Set-Content $d -Encoding UTF8
    return [pscustomobject]@{Summary='Collected PMM log';Artifacts=@($d)}
  }
  if($name -in @('include_full_pak','include_mod_full')){
    $pak=Resolve-PMMAIIOActionPak $raw $importRoot;$d=Join-Path $root ([IO.Path]::GetFileName($pak));Copy-Item $pak $d -Force
    return [pscustomobject]@{Summary=('Collected '+[IO.Path]::GetFileName($pak));Artifacts=@($d)}
  }
  if($name -in @('extract_provider_asset','include_mod_family')){
    $pak=Resolve-PMMAIIOActionPak $raw $importRoot;$logical=[string](Get-PMMAIIOActionValue $raw 'logicalPath' '')
    if(-not$logical){throw 'include_mod_family requires logicalPath.'}
    $d=Join-Path $root 'family';Export-PakAssetFamilyExact $pak $logical $d|Out-Null
    $files=@(Get-ChildItem $d -File -Recurse|ForEach-Object{$_.FullName})
    return [pscustomobject]@{Summary=('Collected mod family '+$logical);Artifacts=$files}
  }
  if($name -eq 'include_file'){
    $case=Get-PMMAIIOCase $Id;if(-not[bool](Get-PMMAIIOActionValue $case 'TrustedInbound' $false)){throw 'External file read requires trusted inbound.'}
    $path=[string](Get-PMMAIIOActionValue $raw 'path' '')
    if(-not$path){throw 'include_file requires path.'}
    $path=Resolve-PMMAIIOActionPath $path $importRoot
    if(-not(Test-Path $path -PathType Leaf)){throw ('Requested file not found: '+$path)}
    $d=Join-Path $root ([IO.Path]::GetFileName($path));Copy-Item $path $d -Force
    return [pscustomobject]@{Summary=('Collected file '+[IO.Path]::GetFileName($path));Artifacts=@($d)}
  }
  if($name -eq 'run_program'){return (Invoke-PMMAIIOTrustedProcess $Id $raw $importRoot $root)}
  if($name -eq 'run_command'){return (Invoke-PMMAIIOTrustedProcess $Id $raw $importRoot $root -Command)}
  throw ('Unsupported work-order action: '+$name)
}
