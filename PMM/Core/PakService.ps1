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
  return (Join-Path $Script:Root 'Tools\repak.exe')
}

function Assert-Repak {
  if (-not (Test-Path -LiteralPath (Get-RepakPath) -PathType Leaf)) {
    throw (Get-PMMText 'Tools\repak.exe is missing. Restart with Start.cmd or use Settings > Prepare / repair dependencies.' 'Falta Tools\repak.exe. Reinicia con Start.cmd o usa Configuracion > Preparar / reparar dependencias.')
  }
}

function Invoke-RepakText {
  param(
    [Parameter(Mandatory=$true)][string[]]$Arguments,
    [string]$Context='repak'
  )

  Assert-Repak
  Write-PMMLog ("repak {0}" -f ($Arguments -join ' '))
  $out = & (Get-RepakPath) @Arguments 2>&1
  $code = $LASTEXITCODE
  if ($code -ne 0) {
    $text = ($out | Out-String).Trim()
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

function Get-PakEntriesCached([string]$Pak) {
  <#
  Cache an index for the lifetime of the PMM process.  The key includes length
  and LastWriteTimeUtc so replacing a PAK invalidates the entry automatically.

  This matters especially for Pal-Windows.pak: listing the large vanilla PAK
  once is much faster than listing it again for every shared mod asset.
  #>
  if (-not (Test-Path -LiteralPath $Pak -PathType Leaf)) {
    throw "PAK not found:`n$Pak"
  }
  $item = Get-Item -LiteralPath $Pak
  $key = ('{0}|{1}|{2}' -f $item.FullName.ToLowerInvariant(),$item.Length,$item.LastWriteTimeUtc.Ticks)
  if ($Script:PakEntryCache.ContainsKey($key)) {
    return @($Script:PakEntryCache[$key])
  }
  $entries = @(Get-PakEntries $Pak)
  $Script:PakEntryCache[$key] = $entries
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

  $psi = New-Object System.Diagnostics.ProcessStartInfo
  $psi.FileName = Get-RepakPath
  $psi.UseShellExecute = $false
  $psi.CreateNoWindow = $true
  $psi.RedirectStandardOutput = $true
  $psi.RedirectStandardError = $true
  $psi.Arguments = 'get ' + (ConvertTo-NativeQuotedArgument $Pak) + ' ' + (ConvertTo-NativeQuotedArgument $Entry)

  Write-PMMLog "repak get: $Pak :: $Entry"
  $proc = New-Object System.Diagnostics.Process
  $proc.StartInfo = $psi
  [void]$proc.Start()

  try {
    $fs = [IO.File]::Open($OutputFile,[IO.FileMode]::Create,[IO.FileAccess]::Write,[IO.FileShare]::None)
    try {
      $proc.StandardOutput.BaseStream.CopyTo($fs)
    } finally {
      $fs.Dispose()
    }
    $err = $proc.StandardError.ReadToEnd()
    $proc.WaitForExit()
    if ($proc.ExitCode -ne 0) {
      Remove-Item -LiteralPath $OutputFile -Force -ErrorAction SilentlyContinue
      throw "repak get failed (exit $($proc.ExitCode)):`nPAK: $Pak`nEntry: $Entry`nOutput: $OutputFile`n`n$err"
    }
  } finally {
    if (-not $proc.HasExited) {
      try { $proc.Kill() } catch {}
    }
    $proc.Dispose()
  }

  if (-not (Test-Path -LiteralPath $OutputFile -PathType Leaf)) {
    throw "repak get did not create the expected file:`n$OutputFile"
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
    $output = Join-Path $OutRoot $outputLogical.Replace([char]47,[char]92)
    Get-PakEntry $Pak ([string]$entry) $output

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

  Write-PMMLog ("Exact asset-family extraction OK: {0} :: {1} -> {2}" -f ([IO.Path]::GetFileName($Pak)),$requested,($written -join ', '))

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
  $output = Join-Path $OutRoot $logical.Replace([char]47,[char]92)
  Get-PakEntry $Pak $entry $output
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
