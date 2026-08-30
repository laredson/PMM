<#
PMM color-scheme service
========================

Release-owned schemes live under Resources\Themes. User imports live under
Workspace\Themes. This module contains the data-only import boundary used by
Settings and the AI & Help color-scheme editor.

Theme packages are data, never code. Settings accepts individual JSON files,
several selected JSON files, or a bounded ZIP containing one or more V1
schemes. Image-backed V2 themes are created, previewed and installed through
the editor so their complete local asset set is validated as one unit.
#>

function Get-PMMBundledThemeStore {
  return (Get-PMMPath 'BundledThemes')
}

function Get-PMMBundledThemeFiles {
  $root=Get-PMMBundledThemeStore
  if(-not(Test-Path -LiteralPath $root -PathType Container)){return @()}
  # Official themes are release resources, not user imports.  Load them from
  # the pinned manifest first so a damaged/missing file is reported precisely
  # and never routed through the Workspace importer (the RC26 Windows failure).
  $manifestPath=Join-Path $root 'BUNDLED_THEME_MANIFEST.json'
  $resolved=[System.Collections.Generic.List[object]]::new()
  if(Test-Path -LiteralPath $manifestPath -PathType Leaf){
    try{
      $manifest=Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8|ConvertFrom-Json -ErrorAction Stop
      if([string]$manifest.schema -ne 'PMM_BUNDLED_THEME_MANIFEST_V1'){throw 'Unsupported bundled-theme manifest schema.'}
      foreach($row in @($manifest.themes)){
        $name=[string]$row.file
        if([string]::IsNullOrWhiteSpace($name) -or [IO.Path]::GetFileName($name) -cne $name -or $name -notlike 'PMM_COLOR_SCHEME_*.json'){throw ('Unsafe bundled theme filename: '+$name)}
        $path=Join-Path $root $name
        if(-not(Test-Path -LiteralPath $path -PathType Leaf)){throw ('Bundled theme is missing: '+$name)}
        $expected=([string]$row.sha256).ToLowerInvariant()
        if($expected -notmatch '^[0-9a-f]{64}$' -or (Get-Sha256 $path) -ne $expected){throw ('Bundled theme hash mismatch: '+$name)}
        $resolved.Add((Get-Item -LiteralPath $path))
      }
      if($resolved.Count -ne [int]$manifest.themeCount){throw 'Bundled theme count does not match its manifest.'}
      return @($resolved.ToArray())
    }catch{
      # Official identity is release-owned. A damaged manifest or hash must not
      # silently downgrade those files into unsigned "official" choices.
      Write-PMMLog ('Bundled theme manifest validation failed; bundled JSON schemes were disabled. '+$_.Exception.Message)
      return @()
    }
  }
  Write-PMMLog 'Bundled theme manifest is missing; bundled JSON schemes were disabled.'
  return @()
}

function Get-PMMUserThemeFiles {
  $root=Get-PMMPath 'Themes'
  if(-not(Test-Path -LiteralPath $root -PathType Container)){return @()}
  # V1 themes are flat JSON files; editor-created V2 themes are self-contained
  # packs below one directory. Drafts and backups are deliberately not part of
  # the installed catalogue.
  return @(Get-ChildItem -LiteralPath $root -Filter '*.json' -File -Recurse -ErrorAction SilentlyContinue|
    Where-Object{$_.FullName -notlike ((Join-Path $root 'Drafts')+'*') -and $_.FullName -notlike ((Join-Path $root 'Backups')+'*')}|
    Sort-Object FullName)
}

function Read-PMMThemeFileIdentity([string]$Path) {
  try{
    $item=Get-Item -LiteralPath $Path -ErrorAction Stop
    if($item.Length -gt 524288){return $null}
    $doc=Get-Content -LiteralPath $Path -Raw -Encoding UTF8|ConvertFrom-Json -ErrorAction Stop
    if(-not$doc -or [string]$doc.schema -notin @('PMM_COLOR_SCHEME_V1','PMM_COLOR_SCHEME_V2')){return $null}
    $id=[string]$doc.id
    if($id -cnotmatch '^[a-z0-9][a-z0-9._-]{0,63}$'){return $null}
    $name=[string]$doc.name
    if([string]::IsNullOrWhiteSpace($name)){$name=$id}
    return [pscustomobject]@{Id=$id;Name=$name;Schema=[string]$doc.schema;Path=$item.FullName;Root=$item.DirectoryName;Hash=(Get-Sha256 $item.FullName)}
  }catch{return $null}
}

function Test-PMMThemeHexColor([string]$ColorText) {
  return (-not[string]::IsNullOrWhiteSpace($ColorText) -and $ColorText -cmatch '^#[0-9A-Fa-f]{6}([0-9A-Fa-f]{2})?$')
}

function Get-PMMThemeRelativeLuminance([string]$ColorText) {
  if(-not(Test-PMMThemeHexColor $ColorText)){throw ('Theme color must be #RRGGBB or #RRGGBBAA: '+$ColorText)}
  # V1 uses #RRGGBB.  For the optional eight-digit form, the final two digits
  # are alpha; contrast is evaluated from the declared RGB fallback.
  $hex=$ColorText.Substring(1,6)
  $red=[double][Convert]::ToInt32($hex.Substring(0,2),16)/255.0
  $green=[double][Convert]::ToInt32($hex.Substring(2,2),16)/255.0
  $blue=[double][Convert]::ToInt32($hex.Substring(4,2),16)/255.0
  $channels=@($red,$green,$blue)
  $linear=@($channels|ForEach-Object{if($_ -le 0.04045){$_/12.92}else{[Math]::Pow(($_+0.055)/1.055,2.4)}})
  return (0.2126*$linear[0]+0.7152*$linear[1]+0.0722*$linear[2])
}

function Get-PMMThemeContrastRatio([string]$Foreground,[string]$Background) {
  $a=Get-PMMThemeRelativeLuminance $Foreground;$b=Get-PMMThemeRelativeLuminance $Background
  return (([Math]::Max($a,$b)+0.05)/([Math]::Min($a,$b)+0.05))
}

function Test-PMMThemeContrast($Definition) {
  $errors=[System.Collections.Generic.List[string]]::new()
  if(-not$Definition -or -not$Definition.Palette){$errors.Add('Theme palette is missing.');return [pscustomobject]@{Valid=$false;Errors=$errors.ToArray()}}
  $p=$Definition.Palette
  $pairs=@(
    @('PrimaryText','AppBackground'),@('PrimaryText','CardBackground'),@('PrimaryText','CardAltBackground'),@('PrimaryText','InputBackground'),
    @('MutedText','AppBackground'),@('MutedText','CardBackground'),@('MutedText','CardAltBackground'),
    @('ButtonForeground','ButtonBackground'),@('ButtonForeground','ButtonHover'),@('SelectionText','SelectionBackground'),
    @('AccentHeadingBlue','SourceBackground'),@('AccentHeadingAmber','ConfigureBackground'),@('AccentHeadingPurple','BuildBackground'),
    @('AccentHeadingGreen','OutputBackground'),@('WarmHeading','BackupBackground'),
    # The detected installation control has a dedicated non-faded neutral
    # surface, so its semantic green is tested against that real surface.
    @('AccentHeadingGreen','CardAltBackground')
  )
  foreach($pair in $pairs){
    $ratio=Get-PMMThemeContrastRatio ([string]$p[$pair[0]]) ([string]$p[$pair[1]])
    if($ratio -lt 4.5){$errors.Add(('{0} / {1}: {2:N2}:1 (minimum 4.50:1)' -f $pair[0],$pair[1],$ratio))}
  }
  foreach($state in @('Import','Analyze','Build','Deploy','Play')){
    $flow=$Definition.ColorFlow[$state]
    $borderRatio=Get-PMMThemeContrastRatio '#FFFFFF' ([string]$flow.Border)
    if($borderRatio -lt 4.5){$errors.Add(('White / ColorFlow.{0}.Border: {1:N2}:1 (minimum 4.50:1)' -f $state,$borderRatio))}
    $progressRatio=Get-PMMThemeContrastRatio ([string]$p['PrimaryText']) ([string]$flow.Progress)
    if($progressRatio -lt 4.5){$errors.Add(('PrimaryText / ColorFlow.{0}.Progress: {1:N2}:1 (minimum 4.50:1)' -f $state,$progressRatio))}
  }
  return [pscustomobject]@{Valid=($errors.Count -eq 0);Errors=$errors.ToArray()}
}

function Test-PMMThemeArchiveEntryPath([string]$Name) {
  if([string]::IsNullOrWhiteSpace($Name)){return $false}
  $value=$Name.Replace([char]92,[char]47)
  if($value.StartsWith('/') -or $value.Contains([char]0) -or $value.Contains(':') -or $value.Contains('//')){return $false}
  foreach($part in @($value.TrimEnd([char]47).Split([char]47))){
    if([string]::IsNullOrWhiteSpace($part) -or $part -in @('..','.') -or $part.EndsWith('.') -or $part.EndsWith(' ')){return $false}
    $stem=([IO.Path]::GetFileNameWithoutExtension($part)).ToUpperInvariant()
    if($stem -in @('CON','PRN','AUX','NUL','COM1','COM2','COM3','COM4','COM5','COM6','COM7','COM8','COM9','LPT1','LPT2','LPT3','LPT4','LPT5','LPT6','LPT7','LPT8','LPT9')){return $false}
  }
  return $true
}

function New-PMMThemeImportResult($Imported,$Skipped,$Warnings,$Errors,$Conflicts) {
  return [pscustomobject]@{
    Success=(@($Errors|ForEach-Object{$_}).Count -eq 0 -and @($Conflicts|ForEach-Object{$_}).Count -eq 0)
    Imported=@($Imported|ForEach-Object{[string]$_})
    Skipped=@($Skipped|ForEach-Object{[string]$_})
    Warnings=@($Warnings|ForEach-Object{[string]$_})
    Errors=@($Errors|ForEach-Object{[string]$_})
    Conflicts=@($Conflicts|ForEach-Object{[string]$_})
  }
}

function Import-PMMThemeInputs {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory=$true)][string[]]$Paths,
    [switch]$AllowReplace
  )

  $imported=[System.Collections.Generic.List[string]]::new()
  $skipped=[System.Collections.Generic.List[string]]::new()
  $warnings=[System.Collections.Generic.List[string]]::new()
  $errors=[System.Collections.Generic.List[string]]::new()
  $conflicts=[System.Collections.Generic.List[string]]::new()
  $candidates=[System.Collections.Generic.List[object]]::new()

  $stage=Join-Path (Get-PMMPath 'Temp') ('ThemeImport_'+[guid]::NewGuid().ToString('N'))
  New-Item -ItemType Directory -Force -Path $stage|Out-Null
  try{
    [ordered]@{Schema='PMM_TRANSIENT_OWNER_V1';Pid=$PID;Kind='ThemeImport';CreatedUtc=[DateTime]::UtcNow.ToString('o')}|ConvertTo-Json|Set-Content -LiteralPath (Join-Path $stage 'owner.json') -Encoding UTF8

    foreach($inputPath in @($Paths|Where-Object{-not[string]::IsNullOrWhiteSpace([string]$_)}|Select-Object -Unique)){
      $item=$null
      try{$item=Get-Item -LiteralPath $inputPath -ErrorAction Stop}catch{$errors.Add(('Input not found: '+[string]$inputPath));continue}
      if(-not$item.PSIsContainer -and $item.Extension -ieq '.json'){
        if($item.Length -gt 524288){$errors.Add(('Theme JSON exceeds 512 KiB: '+$item.Name));continue}
        $candidates.Add([pscustomobject]@{Path=$item.FullName;Origin=$item.Name;Explicit=$true})
        continue
      }
      if(-not$item.PSIsContainer -and $item.Extension -ieq '.zip'){
        if($item.Length -gt 26214400){$errors.Add(('Theme ZIP exceeds 25 MiB: '+$item.Name));continue}
        try{Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction SilentlyContinue}catch{}
        $archive=$null
        try{
          $archive=[System.IO.Compression.ZipFile]::OpenRead($item.FullName)
          $entries=@($archive.Entries)
          if($entries.Count -gt 200){throw 'Archive contains more than 200 entries.'}
          $expanded=[int64]0
          $seenEntries=[Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
          foreach($entry in $entries){
            $entryName=([string]$entry.FullName).Replace([char]92,[char]47)
            if(-not(Test-PMMThemeArchiveEntryPath $entryName)){throw ('Unsafe archive path: '+[string]$entry.FullName)}
            if(-not$seenEntries.Add($entryName)){throw ('Duplicate archive path: '+$entryName)}
            $unixType=(([int64]$entry.ExternalAttributes -shr 16) -band 0xF000)
            if($unixType -eq 0xA000){throw ('Symbolic-link entry is not allowed: '+[string]$entry.FullName)}
            $expanded += [int64]$entry.Length
            if($expanded -gt 78643200){throw 'Archive expands beyond 75 MiB.'}
            $ext=[IO.Path]::GetExtension([string]$entry.FullName).ToLowerInvariant()
            if($ext -in @('.zip','.7z','.rar')){throw ('Nested archives are not allowed: '+[string]$entry.FullName)}
            if($ext -in @('.ps1','.psm1','.psd1','.ps1xml','.bat','.cmd','.com','.exe','.dll','.js','.jse','.vbs','.vbe','.wsf','.wsh','.hta','.msi','.msp','.mst','.scr','.cpl','.reg','.lnk','.url','.py','.pyw','.rb','.pl','.sh','.bash','.zsh','.fish')){throw ('Executable content is not allowed in a theme package: '+[string]$entry.FullName)}
          }
          foreach($entry in $entries){
            if([string]::IsNullOrWhiteSpace([string]$entry.Name)){continue}
            if([IO.Path]::GetExtension([string]$entry.FullName) -ine '.json'){continue}
            if([int64]$entry.Length -gt 524288){$warnings.Add(('Ignored JSON larger than 512 KiB: '+[string]$entry.FullName));continue}
            $dest=Join-Path $stage ('theme_'+[guid]::NewGuid().ToString('N')+'.json')
            $sourceStream=$null;$destStream=$null
            try{
              $sourceStream=$entry.Open()
              $destStream=[IO.File]::Open($dest,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
              $sourceStream.CopyTo($destStream)
            }catch{throw ('Could not read ZIP entry '+[string]$entry.FullName+'. Encrypted or damaged entries are not supported. '+$_.Exception.Message)}
            finally{if($destStream){$destStream.Dispose()};if($sourceStream){$sourceStream.Dispose()}}
            $identity=Read-PMMThemeFileIdentity $dest
            if($identity){$candidates.Add([pscustomobject]@{Path=$dest;Origin=([string]$item.Name+' :: '+[string]$entry.FullName);Explicit=$false})}
            else{$warnings.Add(('Ignored non-theme JSON: '+[string]$entry.FullName))}
          }
        }catch{$errors.Add(([string]$item.Name+': '+$_.Exception.Message))}
        finally{if($archive){$archive.Dispose()}}
        continue
      }
      $errors.Add(('Unsupported theme input. Choose JSON or ZIP: '+$item.Name))
    }

    $validated=[System.Collections.Generic.List[object]]::new()
    foreach($candidate in $candidates){
      $identity=Read-PMMThemeFileIdentity ([string]$candidate.Path)
      $definition=$null
      if($identity -and [string]$identity.Schema -eq 'PMM_COLOR_SCHEME_V1'){$definition=Convert-PMMThemeJson ([string]$candidate.Path)}
      if(-not$identity){
        if([bool]$candidate.Explicit){$errors.Add(('Invalid PMM_COLOR_SCHEME_V1 file: '+[string]$candidate.Origin))}
        continue
      }
      if(-not$definition){
        # A ZIP may contain unrelated JSON, but a document that identifies as a
        # PMM theme is never silently skipped after failing colors/contrast.
        # Treat it as a batch error so parse-all-before-commit remains honest.
        if($identity -and [string]$identity.Schema -eq 'PMM_COLOR_SCHEME_V2'){$errors.Add(('PMM_COLOR_SCHEME_V2 must be installed as a complete image pack from AI & Help; a detached JSON cannot carry its assets: '+[string]$candidate.Origin))}
        else{$errors.Add(('Invalid or unsafe PMM_COLOR_SCHEME_V1 definition: '+[string]$candidate.Origin))}
        continue
      }
      $validated.Add([pscustomobject]@{Identity=$identity;Definition=$definition;Origin=[string]$candidate.Origin})
    }
    if($validated.Count -eq 0 -and $errors.Count -eq 0){$errors.Add('No PMM_COLOR_SCHEME_V1 files were found in the selected input.')}

    $unique=[System.Collections.Generic.List[object]]::new()
    foreach($group in @($validated|Group-Object -Property { [string]$_.Identity.Id })){
      $rows=@($group.Group)
      $hashes=@($rows|ForEach-Object{[string]$_.Identity.Hash}|Sort-Object -Unique)
      if($hashes.Count -gt 1){$errors.Add(('The import contains different definitions for the same id: '+[string]$group.Name));continue}
      $unique.Add($rows[0])
      if($rows.Count -gt 1){$skipped.Add(([string]$group.Name+' (duplicate in selection)'))}
    }

    $reserved=@{}
    foreach($file in @(Get-PMMBundledThemeFiles)){
      $identity=Read-PMMThemeFileIdentity $file.FullName
      if($identity){$reserved[[string]$identity.Id]=$identity}
    }
    $installed=@{}
    foreach($file in @(Get-PMMUserThemeFiles)){
      $identity=Read-PMMThemeFileIdentity $file.FullName
      if($identity -and -not$installed.ContainsKey([string]$identity.Id)){$installed[[string]$identity.Id]=$identity}
    }

    $commit=[System.Collections.Generic.List[object]]::new()
    foreach($row in $unique){
      $id=[string]$row.Identity.Id;$hash=[string]$row.Identity.Hash
      if($id -in @('night','light')){
        $errors.Add(($id+' is a legacy built-in reserved id and cannot be imported.'))
        continue
      }
      if($reserved.ContainsKey($id)){
        if([string]$reserved[$id].Hash -eq $hash){$skipped.Add(($id+' (already bundled)'))}
        else{$errors.Add(($id+' is an official reserved id and cannot be replaced.'))}
        continue
      }
      if($installed.ContainsKey($id)){
        if([string]$installed[$id].Hash -eq $hash){$skipped.Add(($id+' (already installed)'));continue}
        if(-not$AllowReplace){$conflicts.Add($id);continue}
      }
      $commit.Add($row)
    }

    # Import uses a parse-all-before-commit boundary: a bad entry or an
    # unresolved replacement conflict prevents every copy from being committed.
    if($errors.Count -gt 0 -or $conflicts.Count -gt 0){
      return (New-PMMThemeImportResult $imported $skipped $warnings $errors $conflicts)
    }

    $themeRoot=Get-PMMPath 'Themes'
    $backupRoot=Join-Path $themeRoot 'Backups'
    foreach($row in $commit){
      $id=[string]$row.Identity.Id
      $dest=''
      if($installed.ContainsKey($id)){
        New-Item -ItemType Directory -Force -Path $backupRoot|Out-Null
        $existing=[string]$installed[$id].Path
        $stamp=[DateTime]::UtcNow.ToString('yyyyMMdd_HHmmss_fff')
        Copy-Item -LiteralPath $existing -Destination (Join-Path $backupRoot ($stamp+'_'+[IO.Path]::GetFileName($existing))) -Force
        # Preserve the user's existing filename so replacement cannot leave two
        # definitions with the same id and then reload the older one by sort order.
        $dest=$existing
      }
      if([string]::IsNullOrWhiteSpace($dest)){
        $safeId=[regex]::Replace($id,'[^a-z0-9._-]','-')
        $dest=Join-Path $themeRoot ('PMM_COLOR_SCHEME_'+$safeId+'.json')
      }
      Copy-Item -LiteralPath ([string]$row.Identity.Path) -Destination $dest -Force
      $imported.Add($id)
    }
    return (New-PMMThemeImportResult $imported $skipped $warnings $errors $conflicts)
  }finally{
    Remove-Item -LiteralPath $stage -Recurse -Force -ErrorAction SilentlyContinue
  }
}
