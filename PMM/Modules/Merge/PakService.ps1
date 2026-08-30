<#
PakService.ps1 - all direct interaction with repak
==================================================

This module is intentionally policy-free.  It knows how to list, extract,
pack and validate PAK files, but it does NOT decide which mod should win a
conflict.  Merge policy belongs in MergeEngine.ps1.

Why exact extraction exists
---------------------------
Older PMM previews used `repak unpack` and then searched the extracted tree for
an asset.  That is convenient for humans, but it introduced two classes of
bugs:
  * mount-point / strip-prefix differences could make PMM look in the wrong
    directory even though the asset existed in the PAK;
  * unpacking an entire mod is slower than necessary when Analyze only needs
    one .uasset family.

Preview 23 uses `repak get` for semantic analysis and patch
building.  PMM asks repak for the exact entry returned by `repak list` and
writes it to the exact logical Pal/... path inside a temporary folder.
#>

$Script:PakEntryCache = @{}

function Get-RepakPath {
  return (Get-PMMRepakExecutablePath)
}

function Assert-Repak {
  if (-not (Test-Path -LiteralPath (Get-RepakPath) -PathType Leaf)) {
    throw (Get-PMMText 'Engine\repak.exe is missing. Restart PMM.exe or use Settings > Prepare / repair dependencies.' 'Falta Engine\repak.exe. Reinicia PMM.exe o usa Configuracion > Preparar / reparar dependencias.')
  }
}

function Invoke-RepakText {
  param(
    [Parameter(Mandatory=$true)][string[]]$Arguments,
    [string]$Context='repak'
  )

  Assert-Repak
  $verb=if($Arguments.Count -gt 0){[string]$Arguments[0]}else{''}
  # `repak list` is the hottest successful command in normal PMM use and was
  # previously written once per indexed PAK on every fresh process. Keep normal
  # logs focused; a failed list is still recorded below with its context.
  $logSuccessfulCommand=($verb -ne 'list')
  if($logSuccessfulCommand){Write-PMMLog ("repak {0}" -f ($Arguments -join ' '))}
  $out = & (Get-RepakPath) @Arguments 2>&1
  $code = $LASTEXITCODE
  if ($code -ne 0) {
    $text = ($out | Out-String).Trim()
    if(-not $logSuccessfulCommand){Write-PMMLog ("repak list FAILED: {0} | exit={1}" -f $Context,$code)}
    throw "$Context failed (exit $code).`n`n$text"
  }
  return @($out)
}

function Get-PakEntries([string]$Pak) {
  if (-not (Test-Path -LiteralPath $Pak -PathType Leaf)) {
    throw "PAK not found:`n$Pak"
  }
  $out = Invoke-RepakText -Arguments @('list',$Pak) -Context "repak list: $Pak"
  return @($out | Where-Object { $_ -and $_ -notmatch '^\s*$' })
}

function Get-PMMPakIndexCacheId([string]$Text) {
  $sha = [Security.Cryptography.SHA256]::Create()
  try {
    $bytes = [Text.Encoding]::UTF8.GetBytes($Text)
    return ([BitConverter]::ToString($sha.ComputeHash($bytes)).Replace('-','').ToLowerInvariant())
  } finally {
    $sha.Dispose()
  }
}

function Get-PakEntriesCached([string]$Pak) {
  <#
  Cache only the entry-name list returned by `repak list`; cooked bytes are
  never cached. The fingerprint includes canonical path, length and UTC write
  time, so replacing or updating a PAK invalidates its index automatically.

  The in-process cache avoids duplicate work during one run. The persistent V1
  cache avoids listing every unchanged source PAK and Pal-Windows.pak again
  after PMM restarts, which is the largest safe reduction in Analyze startup
  cost for an unchanged library.
  #>
  if (-not (Test-Path -LiteralPath $Pak -PathType Leaf)) {
    throw "PAK not found:`n$Pak"
  }

  $item = Get-Item -LiteralPath $Pak
  $fingerprint = ('{0}|{1}|{2}' -f $item.FullName.ToLowerInvariant(),$item.Length,$item.LastWriteTimeUtc.Ticks)
  if ($Script:PakEntryCache.ContainsKey($fingerprint)) {
    return @($Script:PakEntryCache[$fingerprint])
  }

  $diskRoot = Join-PMMPath 'Cache' 'PakIndexesV1'
  if (-not (Test-Path -LiteralPath $diskRoot -PathType Container)) {
    New-Item -ItemType Directory -Force -Path $diskRoot | Out-Null
  }
  $diskPath = Join-Path $diskRoot ((Get-PMMPakIndexCacheId $fingerprint) + '.json')
  if (Test-Path -LiteralPath $diskPath -PathType Leaf) {
    try {
      $document = Get-Content -LiteralPath $diskPath -Raw -Encoding UTF8 | ConvertFrom-Json
      if ($document -and [string]$document.Schema -ceq 'PMM_PAK_INDEX_V1' -and [string]$document.Fingerprint -ceq $fingerprint) {
        $entries = @($document.Entries | ForEach-Object { [string]$_ })
        if ($entries.Count -gt 0) {
          $Script:PakEntryCache[$fingerprint] = $entries
          return $entries
        }
      }
    } catch {
      Write-PMMLog ('Ignoring invalid persistent PAK index: ' + $diskPath)
    }
    Remove-Item -LiteralPath $diskPath -Force -ErrorAction SilentlyContinue
  }

  $entries = @(Get-PakEntries $Pak)
  $Script:PakEntryCache[$fingerprint] = $entries
  try {
    [pscustomobject]@{
      Schema='PMM_PAK_INDEX_V1'
      Fingerprint=$fingerprint
      CreatedUtc=[DateTime]::UtcNow.ToString('o')
      Entries=$entries
    } | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $diskPath -Encoding UTF8
  } catch {
    Write-PMMLog ('Could not persist PAK index cache; continuing with the in-process index. ' + $_.Exception.Message)
  }
  return $entries
}

function Clear-PakEntryCache {
  $Script:PakEntryCache = @{}
}


function Normalize-PakLogicalPath([string]$Path) {
  <#
  Normalize a path as repak exposes it through `list`.

  IMPORTANT: use explicit character operations instead of System.IO helpers
  when manipulating Unreal logical paths.  Windows PowerShell 5.1 can coerce a
  `$null` string argument passed to Path.ChangeExtension into an empty string.
  For ChangeExtension(path, ''), .NET leaves a trailing dot (Foo.) instead of
  returning Foo.  That subtle difference caused preview 12 to search for
  Foo..uasset even though `repak list` had correctly found Foo.uasset.
  #>
  if ($null -eq $Path) { return '' }
  return ([string]$Path).Replace([char]92,[char]47).TrimStart([char]47)
}

function Get-PMMSafePakOutputPath([string]$OutRoot,[string]$LogicalPath) {
  $logical=Normalize-PakLogicalPath $LogicalPath
  if([string]::IsNullOrWhiteSpace($logical)){throw 'Unsafe empty PAK logical path.'}
  foreach($segment in @($logical.Split([char]47))){
    if([string]::IsNullOrWhiteSpace($segment) -or $segment -eq '.' -or $segment -eq '..' -or $segment.Contains(':') -or $segment.EndsWith('.') -or $segment.EndsWith(' ')){
      throw ('Unsafe PAK logical path refused: '+$LogicalPath)
    }
    if($segment.Length -gt 255 -or $segment.IndexOfAny([char[]]'<>"|?*') -ge 0){throw ('Unsafe Windows PAK path component refused: '+$LogicalPath)}
    foreach($ch in $segment.ToCharArray()){if([int][char]$ch -lt 32){throw ('Unsafe control character in PAK logical path: '+$LogicalPath)}}
    $device=([string]$segment.Split([char]46)[0]).TrimEnd([char]32,[char]46).ToUpperInvariant()
    if($device -in @('CON','PRN','AUX','NUL','COM1','COM2','COM3','COM4','COM5','COM6','COM7','COM8','COM9','LPT1','LPT2','LPT3','LPT4','LPT5','LPT6','LPT7','LPT8','LPT9')){
      throw ('Unsafe Windows device name in PAK logical path refused: '+$LogicalPath)
    }
  }
  $rootFull=[IO.Path]::GetFullPath($OutRoot).TrimEnd([char]92,[char]47)
  $candidate=[IO.Path]::GetFullPath((Join-Path $rootFull $logical.Replace([char]47,[char]92)))
  $prefix=$rootFull+[IO.Path]::DirectorySeparatorChar
  if(-not$candidate.StartsWith($prefix,[StringComparison]::OrdinalIgnoreCase)){
    throw ('PAK extraction path escapes its staging root: '+$LogicalPath)
  }
  return $candidate
}

function Get-PakLogicalStem([string]$Path) {
  <#
  Return a logical path with ONLY its final extension removed.

  Example:
    Pal/Content/Foo.uasset -> Pal/Content/Foo

  Do not replace this with Path.ChangeExtension($Path,$null) unless its exact
  Windows PowerShell 5.1 behavior has been regression-tested.
  #>
  $normalized = Normalize-PakLogicalPath $Path
  $ext = [IO.Path]::GetExtension($normalized)
  if ([string]::IsNullOrEmpty($ext)) { return $normalized }
  return $normalized.Substring(0,$normalized.Length-$ext.Length)
}

function Get-PakEntryCandidates([array]$Entries,[string]$LogicalPath) {
  <#
  Diagnostic helper.  Exact logical-path equality is the normal rule.  If it
  fails, return entries with the same leaf filename so logs can show whether a
  mount/prefix difference is involved instead of reporting a misleading
  "missing uasset" message.
  #>
  $wanted = Normalize-PakLogicalPath $LogicalPath
  $leaf = [IO.Path]::GetFileName($wanted)
  if ([string]::IsNullOrWhiteSpace($leaf)) { return @() }
  return @($Entries | Where-Object {
    [IO.Path]::GetFileName((Normalize-PakLogicalPath ([string]$_))) -ieq $leaf
  })
}

function Expand-Pak([string]$Pak, [string]$OutDir) {
  <#
  Full extraction remains available for diagnostics. Semantic
  analysis should normally use Export-PakAssetFamilyExact instead.
  #>
  Assert-Repak
  if (-not (Test-Path -LiteralPath $Pak -PathType Leaf)) {
    throw "PAK to unpack was not found:`n$Pak"
  }

  if (Test-Path -LiteralPath $OutDir) {
    Remove-Item -LiteralPath $OutDir -Recurse -Force -ErrorAction Stop
  }
  $parent = Split-Path -Parent $OutDir
  if ($parent -and -not (Test-Path -LiteralPath $parent)) {
    New-Item -ItemType Directory -Force -Path $parent | Out-Null
  }

  Invoke-RepakText -Arguments @('unpack',$Pak,'--output',$OutDir,'--force','--quiet') -Context "repak unpack: $Pak" | Out-Null

  if (-not (Test-Path -LiteralPath $OutDir -PathType Container)) {
    throw "repak finished without creating the expected extraction folder:`n$OutDir"
  }
}

function Expand-PakEntries([string]$Pak,[string]$OutDir,[array]$Entries) {
  <#
  Kept for compatibility/debugging.  Exact binary extraction below is the
  preferred path because repak --include uses glob matching and therefore is
  easier to misuse when mount points vary between PAKs.
  #>
  Assert-Repak
  if (-not (Test-Path -LiteralPath $Pak -PathType Leaf)) {
    throw "PAK to unpack was not found:`n$Pak"
  }
  if (-not $Entries -or @($Entries).Count -eq 0) {
    throw 'No PAK entries were supplied for selective extraction.'
  }
  if (Test-Path -LiteralPath $OutDir) {
    Remove-Item -LiteralPath $OutDir -Recurse -Force -ErrorAction Stop
  }
  $parent = Split-Path -Parent $OutDir
  if ($parent -and -not (Test-Path -LiteralPath $parent)) {
    New-Item -ItemType Directory -Force -Path $parent | Out-Null
  }
  $args = @('unpack',$Pak,'--output',$OutDir,'--force','--quiet')
  foreach ($entry in @($Entries)) {
    $args += @('--include',[string]$entry)
  }
  Invoke-RepakText -Arguments $args -Context "repak selective unpack: $Pak" | Out-Null
}

function ConvertTo-NativeQuotedArgument([string]$Value) {
  <#
  Windows PowerShell 5.1 does not expose ProcessStartInfo.ArgumentList.  repak
  `get` writes binary data to stdout, so PMM launches it with redirected streams
  and must quote paths itself.
  #>
  if ($null -eq $Value) { return '""' }
  $v = $Value -replace '(\\*)"', '$1$1\"'
  $v = $v -replace '(\\+)$', '$1$1'
  return '"' + $v + '"'
}

function Get-PakEntry([string]$Pak, [string]$Entry, [string]$OutputFile) {
  <#
  Extract exactly one PAK entry without converting binary stdout to text.
  `Entry` should normally come directly from Get-PakEntriesCached.

  repak writes the requested file to stdout and diagnostics to stderr. Both
  redirected streams MUST be drained concurrently. Reading stdout to completion
  before stderr can deadlock if repak fills the stderr pipe while PMM is still
  waiting for stdout. CopyToAsync + ReadToEndAsync also lets PMM enforce a real
  timeout instead of leaving Analyze blocked forever on a damaged/unusual PAK.
  #>
  Assert-Repak
  if (-not (Test-Path -LiteralPath $Pak -PathType Leaf)) {
    throw "PAK not found:`n$Pak"
  }

  $parent = Split-Path -Parent $OutputFile
  if ($parent -and -not (Test-Path -LiteralPath $parent)) {
    New-Item -ItemType Directory -Force -Path $parent | Out-Null
  }
  if (Test-Path -LiteralPath $OutputFile) {
    Remove-Item -LiteralPath $OutputFile -Force -ErrorAction Stop
  }

  # A healthy exact extraction is normally measured in milliseconds/seconds.
  # Keep the ceiling generous for slow disks and large cooked assets, but never
  # allow one repak child process to hold Analyze indefinitely.
  $timeoutSeconds = 180
  $timeoutMs = $timeoutSeconds * 1000

  $psi = New-Object System.Diagnostics.ProcessStartInfo
  $psi.FileName = Get-RepakPath
  $psi.UseShellExecute = $false
  $psi.CreateNoWindow = $true
  $psi.RedirectStandardOutput = $true
  $psi.RedirectStandardError = $true
  $psi.Arguments = 'get ' + (ConvertTo-NativeQuotedArgument $Pak) + ' ' + (ConvertTo-NativeQuotedArgument $Entry)

  $pakName = [IO.Path]::GetFileName($Pak)
  Write-PMMLog ("repak get START: {0} :: {1} | timeout={2}s" -f $pakName,$Entry,$timeoutSeconds)

  $proc = New-Object System.Diagnostics.Process
  $proc.StartInfo = $psi
  $watch = [System.Diagnostics.Stopwatch]::StartNew()
  $fs = $null
  $copyTask = $null
  $errorTask = $null
  $err = ''
  $bytesWritten = [int64]0
  $timedOut = $false
  $started = $false

  try {
    [void]$proc.Start()
    $started = $true

    $fs = [IO.File]::Open($OutputFile,[IO.FileMode]::Create,[IO.FileAccess]::Write,[IO.FileShare]::None)
    try {
      # Start BOTH drains before waiting for process completion. This prevents
      # redirected stdout/stderr pipe backpressure from deadlocking repak.
      $copyTask = $proc.StandardOutput.BaseStream.CopyToAsync($fs)
      $errorTask = $proc.StandardError.ReadToEndAsync()

      $timedOut = -not $proc.WaitForExit($timeoutMs)
      if ($timedOut) {
        try {
          $bytesWritten = [int64]$fs.Length
        } catch {}
        Write-PMMLog ("repak get TIMEOUT after {0:N2}s: {1} :: {2} | partialBytes={3}" -f $watch.Elapsed.TotalSeconds,$pakName,$Entry,$bytesWritten)
        try { $proc.Kill() } catch { Write-PMMLog ("repak get timeout: failed to terminate process: {0}" -f $_.Exception.Message) }
        try { [void]$proc.WaitForExit(5000) } catch {}

        # Best-effort cleanup of the asynchronous readers after terminating the
        # child. Never wait indefinitely here: the timeout path must itself be
        # bounded.
        if ($copyTask) { try { [void]$copyTask.Wait(5000) } catch {} }
        if ($errorTask) {
          try { [void]$errorTask.Wait(5000) } catch {}
          if ($errorTask.IsCompleted -and -not $errorTask.IsFaulted -and -not $errorTask.IsCanceled) {
            try { $err = [string]$errorTask.Result } catch {}
          }
        }
      } else {
        # WaitForExit(Int32) confirms the process exited; the parameterless call
        # completes final process bookkeeping before ExitCode is inspected.
        [void]$proc.WaitForExit()
        $copyTask.GetAwaiter().GetResult()
        $err = [string]$errorTask.GetAwaiter().GetResult()
        $fs.Flush()
        $bytesWritten = [int64]$fs.Length
      }
    } finally {
      if ($fs) {
        try { $fs.Dispose() } catch {}
        $fs = $null
      }
    }

    if ($timedOut) {
      $stderrSuffix = if ([string]::IsNullOrWhiteSpace($err)) { '' } else { "`n`nrepak stderr:`n$err" }
      throw "repak get timed out after $timeoutSeconds seconds.`nPAK: $Pak`nEntry: $Entry`nOutput: $OutputFile$stderrSuffix"
    }

    if ($proc.ExitCode -ne 0) {
      throw "repak get failed (exit $($proc.ExitCode)):`nPAK: $Pak`nEntry: $Entry`nOutput: $OutputFile`n`n$err"
    }

    if (-not (Test-Path -LiteralPath $OutputFile -PathType Leaf)) {
      throw "repak get did not create the expected file:`n$OutputFile"
    }

    # Fast successful exact extractions are intentionally not logged twice. The
    # START line already preserves the last in-flight asset for hang diagnosis.
    # Only unusually slow successes add a completion line.
    if($watch.Elapsed.TotalSeconds -ge 2.0){Write-PMMLog ("repak get SLOW success after {0:N2}s: {1} :: {2} | bytes={3}" -f $watch.Elapsed.TotalSeconds,$pakName,$Entry,$bytesWritten)}
  } catch {
    Remove-Item -LiteralPath $OutputFile -Force -ErrorAction SilentlyContinue
    if (-not $timedOut) {
      Write-PMMLog ("repak get FAILED after {0:N2}s: {1} :: {2} | {3}" -f $watch.Elapsed.TotalSeconds,$pakName,$Entry,$_.Exception.Message)
    }
    throw
  } finally {
    if ($fs) {
      try { $fs.Dispose() } catch {}
    }
    if ($started) {
      try {
        if (-not $proc.HasExited) {
          try { $proc.Kill() } catch {}
          try { [void]$proc.WaitForExit(5000) } catch {}
        }
      } catch {}
    }
    $watch.Stop()
    $proc.Dispose()
  }
}

function Find-PakEntryExact([array]$Entries,[string]$LogicalPath) {
  <# Case-insensitive exact match using normalized forward-slash logical paths. #>
  $wanted = Normalize-PakLogicalPath $LogicalPath
  foreach ($entry in @($Entries)) {
    $candidate = Normalize-PakLogicalPath ([string]$entry)
    if ($candidate -ieq $wanted) {
      return [string]$entry
    }
  }
  return $null
}

function Export-PakAssetFamilyExact([string]$Pak,[string]$RelativeUasset,[string]$OutRoot) {
  <#
  Extract one Unreal asset family exactly: Foo.uasset plus optional Foo.uexp /
  Foo.ubulk sidecars.

  Preview 13 deliberately derives the family stem with Get-PakLogicalStem
  instead of Path.ChangeExtension(...,$null).  The latter was the root cause of
  preview 12's false "Source PAK did not provide the required .uasset header"
  result: on Windows PowerShell 5.1 the null extension could be coerced to an
  empty string, producing Foo. and then Foo..uasset.

  The actual entry spelling returned by `repak list` is used for `repak get`.
  Output files are written using the caller's requested Pal/... logical path so
  vanilla and mod copies have an identical local layout for UAssetAPI.
  #>
  $requested = Normalize-PakLogicalPath $RelativeUasset
  if ([IO.Path]::GetExtension($requested) -ine '.uasset') {
    throw "Export-PakAssetFamilyExact expects a .uasset logical path:`n$RelativeUasset"
  }

  $entries = @(Get-PakEntriesCached $Pak)
  $requestedHeaderEntry = Find-PakEntryExact $entries $requested
  if (-not $requestedHeaderEntry) {
    $candidates = @(Get-PakEntryCandidates $entries $requested)
    $candidateText = if ($candidates.Count -gt 0) {
      "`nEntries with the same filename:`n" + ($candidates -join "`n")
    } else { '' }
    throw "Source PAK does not contain the requested .uasset entry:`n$requested`nPAK: $Pak$candidateText"
  }

  # Use the actual header entry as the source-family stem.  This preserves case
  # and any harmless prefix spelling returned by repak list.
  $sourceHeaderLogical = Normalize-PakLogicalPath ([string]$requestedHeaderEntry)
  $sourceStem = Get-PakLogicalStem $sourceHeaderLogical
  $outputStem = Get-PakLogicalStem $requested

  $written = New-Object System.Collections.Generic.List[string]
  $headerPath = $null

  foreach ($ext in @('.uasset','.uexp','.ubulk')) {
    $sourceLogical = $sourceStem + $ext
    $entry = Find-PakEntryExact $entries $sourceLogical
    if (-not $entry) { continue }

    $outputLogical = $outputStem + $ext
    $output = Get-PMMSafePakOutputPath $OutRoot $outputLogical
    [void](Get-PakEntry $Pak ([string]$entry) $output)

    if (-not (Test-Path -LiteralPath $output -PathType Leaf)) {
      throw "Exact extraction did not create the expected file:`n$outputLogical`nPAK: $Pak"
    }

    $written.Add($outputLogical)
    if ($ext -eq '.uasset') { $headerPath = $output }
  }

  if (-not $headerPath -or -not (Test-Path -LiteralPath $headerPath -PathType Leaf)) {
    # This should only be reachable if repak's index changes between list/get.
    # Keep detailed diagnostics because a missing header makes semantic diff
    # impossible and must never be interpreted as "no property conflicts".
    throw "Source PAK listed the .uasset but exact extraction did not produce its header:`n$requested`nPAK: $Pak`nMatched entry: $requestedHeaderEntry"
  }

  return [pscustomobject]@{
    HeaderPath = $headerPath
    Root = $OutRoot
    Files = $written.ToArray()
  }
}

function Export-PakFileExact([string]$Pak,[string]$LogicalPath,[string]$OutRoot) {
  <# Extract a non-.uasset file by its exact logical path. #>
  $entries = @(Get-PakEntriesCached $Pak)
  $entry = Find-PakEntryExact $entries $LogicalPath
  if (-not $entry) {
    throw "PAK does not contain the expected entry:`n$LogicalPath`nPAK: $Pak"
  }
  $logical = $LogicalPath.Replace([char]92,[char]47)
  $output = Get-PMMSafePakOutputPath $OutRoot $logical
  [void](Get-PakEntry $Pak $entry $output)
  return $output
}

function Pack-Pak([string]$Folder, [string]$OutputPak) {
  <#
  repak currently writes uncompressed PAK payloads.  PMM therefore keeps the
  ConflictGroups build intentionally minimal: only override asset families are
  packed.  Version V11 matches the Palworld 1.0 mod PAKs tested during PMM
  development.
  #>
  Assert-Repak
  if (-not (Test-Path -LiteralPath $Folder -PathType Container)) {
    throw "Folder to pack does not exist:`n$Folder"
  }
  $parent = Split-Path -Parent $OutputPak
  if ($parent -and -not (Test-Path -LiteralPath $parent)) {
    New-Item -ItemType Directory -Force -Path $parent | Out-Null
  }
  if (Test-Path -LiteralPath $OutputPak) {
    Remove-Item -LiteralPath $OutputPak -Force -ErrorAction Stop
  }

  Invoke-RepakText -Arguments @('pack',$Folder,$OutputPak,'--version','V11') -Context "repak pack V11: $OutputPak" | Out-Null

  if (-not (Test-Path -LiteralPath $OutputPak -PathType Leaf)) {
    throw (Get-PMMText 'repak finished without producing the expected PAK.' 'repak termino sin producir el PAK esperado.')
  }

  $info = Invoke-RepakText -Arguments @('info',$OutputPak) -Context "repak info: $OutputPak"
  Write-PMMLog ("Generated PAK info: " + (($info -join ' ') -replace '\s+',' '))
  if (-not (($info -join "`n") -match '(?im)^version:\s*V11\s*$')) {
    throw (Get-PMMText 'Generated PAK is not V11; deployment was stopped.' 'El PAK generado no es V11; se detuvo el despliegue.')
  }
}

function Test-Pak([string]$Pak) {
  try {
    $entries = @(Get-PakEntries $Pak)
    return ($entries.Count -gt 0)
  } catch {
    Write-PMMLog "PAK verification failed: $($_.Exception.Message)"
    return $false
  }
}

function Assert-PakAssetFamiliesComplete([string]$Pak) {
  <# Prevent the exact orphan-.uexp failure that caused early preview black screens. #>
  $entries = @(Get-PakEntries $Pak)
  $lookup = @{}
  foreach ($e in $entries) {
    $lookup[$e.Replace([char]92,[char]47).ToLowerInvariant()] = $true
  }

  $orphans = New-Object System.Collections.Generic.List[string]
  foreach ($e in $entries) {
    $n = $e.Replace([char]92,[char]47)
    if ($n.ToLowerInvariant().EndsWith('.uexp')) {
      $uasset = [IO.Path]::ChangeExtension($n,'.uasset').Replace([char]92,[char]47).ToLowerInvariant()
      if (-not $lookup.ContainsKey($uasset)) {
        $orphans.Add($n)
      }
    }
  }

  if ($orphans.Count -gt 0) {
    throw (Get-PMMText ("Generated PAK contains orphan .uexp files without their .uasset headers. Deployment was stopped.`n`n" + ($orphans -join "`n")) ("El PAK generado contiene archivos .uexp huerfanos sin su cabecera .uasset. Se detuvo el despliegue.`n`n" + ($orphans -join "`n")))
  }
}
