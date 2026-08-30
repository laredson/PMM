<#
PMM local color-scheme editor service
=====================================

Drafts, image assets, local installation and offline AI requests are all data
operations.  The WPF layer renders the editor rows and preview, while this
module owns the durable/safe contracts.  No theme package may contain code or
refer to an absolute, UNC or remote asset.
#>

function Get-PMMThemeEditorFields {
  $surface=@('AppBackground','HeaderBackground','CardBackground','CardAltBackground','InputBackground','StatusBackground','SoftBlue','SoftGreen','SoftAmber','SoftRed','SoftGray','FixHeaderBackground','NoticeBackground','DecisionNoticeBackground','SourceBackground','ConfigureBackground','BuildBackground','OutputBackground','BackupBackground','AdvancedBackground')
  $text=@('PrimaryText','MutedText','SelectionText','DecisionNoticeHeading','AccentHeadingBlue','AccentHeadingAmber','AccentHeadingPurple','AccentHeadingGreen','WarmHeading','ButtonForeground')
  $border=@('CardBorder','InputBorder','GridLine','Splitter','FixHeaderBorder','NoticeBorder','DecisionNoticeBorder','SourceBorder','ConfigureBorder','BuildBorder','OutputBorder','BackupBorder','ButtonBorder')
  $interaction=@('SelectionBackground','ButtonBackground','ButtonHover')
  $rows=[Collections.Generic.List[object]]::new()
  foreach($key in @($surface+$text+$border+$interaction)){
    $group=if($surface -contains $key){'Surfaces'}elseif($text -contains $key){'Text and headings'}elseif($border -contains $key){'Borders and dividers'}else{'Selection and buttons'}
    $rows.Add([pscustomobject]@{Key=$key;Group=$group;Kind='Palette';Affected=(Get-PMMThemeFieldAffectedText $key)})
  }
  foreach($state in @('Import','Analyze','Build','Deploy','Play')){
    foreach($part in @('Progress','Border')){$key=('ColorFlow.'+$state+'.'+$part);$rows.Add([pscustomobject]@{Key=$key;Group='ColorFlow';Kind='ColorFlow';State=$state;Part=$part;Affected=('Guided '+$state+' workflow '+$part.ToLowerInvariant())})}
  }
  return @($rows.ToArray())
}

function Get-PMMThemeFieldAffectedText([string]$Key) {
  $known=@{
    AppBackground='Main window and outer workspace';HeaderBackground='Product header';CardBackground='Tabs, cards and grids';CardAltBackground='Secondary cards and detected installation';InputBackground='Text boxes, combo boxes and lists';PrimaryText='Normal text throughout PMM';MutedText='Descriptions, metadata and secondary text';SelectionBackground='Selected rows and tabs';SelectionText='Text on selected rows';ButtonBackground='Normal buttons';ButtonHover='Hovered buttons';ButtonForeground='Button labels';ButtonBorder='Button outlines';SourceBackground='Fix Lab source card';ConfigureBackground='Fix Lab configuration card';BuildBackground='Build cards';OutputBackground='Output/success cards';BackupBackground='Backup cards';AdvancedBackground='Advanced cards';StatusBackground='Bottom status strip'
  }
  if($known.ContainsKey($Key)){return [string]$known[$Key]}
  return ('All controls that use the shared '+$Key+' brush')
}

function ConvertTo-PMMThemeDraftHashtable($Value) {
  if($null -eq $Value){return [ordered]@{}}
  $copy=[ordered]@{}
  if($Value -is [Collections.IDictionary]){foreach($key in $Value.Keys){$copy[[string]$key]=$Value[$key]};return $copy}
  foreach($prop in $Value.PSObject.Properties){$copy[[string]$prop.Name]=$prop.Value}
  return $copy
}

function Get-PMMThemeDraftRoot([string]$DraftId) {
  if($DraftId -cnotmatch '^draft-[a-f0-9]{32}$'){throw 'Invalid theme draft ID.'}
  return (Join-Path (Get-PMMPath 'ThemeDrafts') $DraftId)
}

function New-PMMThemeDraft {
  [CmdletBinding()]
  param([Parameter(Mandatory=$true)]$SourceDefinition,[string]$Name='',[string]$Id='')
  if(-not$SourceDefinition){throw 'Choose a source color scheme first.'}
  if([string]::IsNullOrWhiteSpace($Name)){$Name=([string]$SourceDefinition.Name+' Copy')}
  if([string]::IsNullOrWhiteSpace($Id)){$Id=([regex]::Replace($Name.ToLowerInvariant(),'[^a-z0-9._-]+','-').Trim('-'))}
  if($Id -cnotmatch '^[a-z0-9][a-z0-9._-]{0,63}$'){throw 'Theme ID must use lowercase letters, digits, dot, underscore or hyphen.'}
  $draftId='draft-'+[guid]::NewGuid().ToString('N');$root=Get-PMMThemeDraftRoot $draftId
  New-Item -ItemType Directory -Force -Path (Join-Path $root 'assets')|Out-Null
  $palette=ConvertTo-PMMThemeDraftHashtable $SourceDefinition.Palette
  $flow=[ordered]@{}
  foreach($state in @('Import','Analyze','Build','Deploy','Play')){$source=$SourceDefinition.ColorFlow[$state];$flow[$state]=[ordered]@{Progress=[string]$source.Progress;Border=[string]$source.Border}}
  $draft=[pscustomobject][ordered]@{Schema='PMM_THEME_DRAFT_V1';DraftId=$draftId;ThemeId=$Id;Name=$Name;Base=[string]$SourceDefinition.Base;SourceThemeId=[string]$SourceDefinition.Id;Palette=$palette;ColorFlow=$flow;Brushes=[ordered]@{};CreatedUtc=[DateTime]::UtcNow.ToString('o');UpdatedUtc=[DateTime]::UtcNow.ToString('o')}
  Save-PMMThemeDraft $draft|Out-Null
  return $draft
}

function Save-PMMThemeDraft($Draft) {
  if(-not$Draft -or [string]$Draft.Schema -ne 'PMM_THEME_DRAFT_V1'){throw 'Invalid theme draft.'}
  $Draft.UpdatedUtc=[DateTime]::UtcNow.ToString('o')
  $root=Get-PMMThemeDraftRoot ([string]$Draft.DraftId)
  New-Item -ItemType Directory -Force -Path $root|Out-Null
  Write-PMMAIIOJsonAtomic (Join-Path $root 'draft.json') $Draft 40
  return $Draft
}

function Get-PMMThemeDraft([string]$DraftId) {
  try{$path=Join-Path (Get-PMMThemeDraftRoot $DraftId) 'draft.json';$doc=Get-Content -LiteralPath $path -Raw -Encoding UTF8|ConvertFrom-Json -ErrorAction Stop;if([string]$doc.Schema -eq 'PMM_THEME_DRAFT_V1' -and [string]$doc.DraftId -eq $DraftId){return $doc}}catch{}
  return $null
}

function Get-PMMThemeDrafts {
  $rows=[Collections.Generic.List[object]]::new()
  foreach($dir in @(Get-ChildItem -LiteralPath (Get-PMMPath 'ThemeDrafts') -Directory -ErrorAction SilentlyContinue|Sort-Object LastWriteTimeUtc -Descending)){
    $draft=Get-PMMThemeDraft $dir.Name;if(-not$draft){continue}
    $rows.Add([pscustomobject]@{DraftId=[string]$draft.DraftId;ThemeId=[string]$draft.ThemeId;Name=[string]$draft.Name;UpdatedUtc=[string]$draft.UpdatedUtc;Display=([string]$draft.Name+'  —  '+[string]$draft.ThemeId)})
  }
  return @($rows.ToArray())
}

function Test-PMMThemeImageFile([string]$Path) {
  $item=Get-Item -LiteralPath $Path -ErrorAction Stop
  if($item.Extension.ToLowerInvariant() -notin @('.png','.jpg','.jpeg')){throw 'Theme images must be PNG or JPEG.'}
  if([int64]$item.Length -gt 8388608){throw 'Theme image exceeds 8 MiB.'}
  $stream=$null;$decoder=$null
  try{
    $stream=[IO.File]::Open($item.FullName,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::Read)
    $decoder=[System.Windows.Media.Imaging.BitmapDecoder]::Create($stream,[System.Windows.Media.Imaging.BitmapCreateOptions]::PreservePixelFormat,[System.Windows.Media.Imaging.BitmapCacheOption]::OnLoad)
    $frame=$decoder.Frames[0];$w=[int]$frame.PixelWidth;$h=[int]$frame.PixelHeight
    if($w -le 0 -or $h -le 0 -or $w -gt 4096 -or $h -gt 4096 -or ([int64]$w*[int64]$h) -gt 32000000){throw 'Theme image dimensions exceed 4096 x 4096 or 32 megapixels.'}
    return [pscustomobject]@{Path=$item.FullName;Width=$w;Height=$h;Bytes=[int64]$item.Length;Sha256=(Get-Sha256 $item.FullName);Extension=$item.Extension.ToLowerInvariant()}
  }finally{if($stream){$stream.Dispose()}}
}

function Set-PMMThemeDraftImage {
  [CmdletBinding()]
  param([Parameter(Mandatory=$true)]$Draft,[Parameter(Mandatory=$true)][string]$FieldKey,[Parameter(Mandatory=$true)][string]$ImagePath)
  $validKeys=@(Get-PMMThemeEditorFields|ForEach-Object{[string]$_.Key});if($FieldKey -notin $validKeys){throw ('Unknown theme brush: '+$FieldKey)}
  $info=Test-PMMThemeImageFile $ImagePath;$root=Get-PMMThemeDraftRoot ([string]$Draft.DraftId);$assets=Join-Path $root 'assets';New-Item -ItemType Directory -Force -Path $assets|Out-Null
  $safe=[regex]::Replace($FieldKey.ToLowerInvariant(),'[^a-z0-9._-]','-')+$info.Extension;$dest=Join-Path $assets $safe;Copy-Item -LiteralPath $info.Path -Destination $dest -Force
  $brushes=ConvertTo-PMMThemeDraftHashtable $Draft.Brushes
  $brushes[$FieldKey]=[ordered]@{type='image';source=('assets/'+$safe);stretch='UniformToFill';alignment='Center';tileMode='None';opacity=1.0;overlay='#00000000';sha256=$info.Sha256;width=$info.Width;height=$info.Height}
  $Draft.Brushes=$brushes;Save-PMMThemeDraft $Draft|Out-Null
  return $Draft
}

function Remove-PMMThemeDraftImage {
  param([Parameter(Mandatory=$true)]$Draft,[Parameter(Mandatory=$true)][string]$FieldKey)
  $brushes=ConvertTo-PMMThemeDraftHashtable $Draft.Brushes
  if($brushes.Contains($FieldKey)){$entry=$brushes[$FieldKey];try{$relative=[string]$entry.source;if($relative -match '^assets/[a-z0-9._-]+$'){Remove-Item -LiteralPath (Join-Path (Get-PMMThemeDraftRoot ([string]$Draft.DraftId)) $relative.Replace([char]47,[IO.Path]::DirectorySeparatorChar)) -Force -ErrorAction SilentlyContinue}}catch{};$brushes.Remove($FieldKey)}
  $Draft.Brushes=$brushes;Save-PMMThemeDraft $Draft|Out-Null;return $Draft
}

function Convert-PMMThemeDraftToDefinition($Draft) {
  if(-not$Draft -or [string]$Draft.Schema -ne 'PMM_THEME_DRAFT_V1'){throw 'Invalid theme draft.'}
  $id=[string]$Draft.ThemeId;if($id -cnotmatch '^[a-z0-9][a-z0-9._-]{0,63}$'){throw 'Theme ID is invalid.'}
  $name=[string]$Draft.Name;if([string]::IsNullOrWhiteSpace($name)){throw 'Theme name is required.'}
  $base=[string]$Draft.Base;if($base -notin @('Light','Night')){throw 'Theme base must be Light or Night.'}
  $palette=ConvertTo-PMMThemeDraftHashtable $Draft.Palette;$flow=ConvertTo-PMMThemeDraftHashtable $Draft.ColorFlow;$brushes=ConvertTo-PMMThemeDraftHashtable $Draft.Brushes
  foreach($field in @(Get-PMMThemeEditorFields)){
    $fieldKey=[string]$field.Key
    if([string]$field.Kind -eq 'Palette'){if(-not$palette.Contains($fieldKey) -or -not(Test-PMMThemeHexColor ([string]$palette[$fieldKey]))){throw ('Invalid or missing color: '+$fieldKey)}}
    else{$state=[string]$field.State;$part=[string]$field.Part;$row=$flow[$state];$values=ConvertTo-PMMThemeDraftHashtable $row;if(-not(Test-PMMThemeHexColor ([string]$values[$part]))){throw ('Invalid ColorFlow value: '+$fieldKey)}}
  }
  $contrast=Test-PMMThemeContrast ([pscustomobject]@{Palette=$palette;ColorFlow=$flow});if(-not[bool]$contrast.Valid){throw ('Theme contrast validation failed: '+(@($contrast.Errors)-join ' | '))}
  return [ordered]@{schema=$(if($brushes.Count -gt 0){'PMM_COLOR_SCHEME_V2'}else{'PMM_COLOR_SCHEME_V1'});id=$id;name=$name;base=$base;palette=$palette;colorFlow=$flow;brushes=$brushes}
}

function Install-PMMThemeDraft {
  [CmdletBinding()]
  param([Parameter(Mandatory=$true)]$Draft,[switch]$AllowReplace)
  $definition=Convert-PMMThemeDraftToDefinition $Draft;$id=[string]$definition.id
  $official=@(Get-PMMBundledThemeFiles|ForEach-Object{Read-PMMThemeFileIdentity $_.FullName}|Where-Object{$_})
  if($id -in @('Night','Light') -or @($official|Where-Object{[string]$_.Id -ieq $id}).Count -gt 0){throw 'Official PMM theme IDs cannot be replaced.'}
  $existing=@(Get-PMMUserThemeFiles|ForEach-Object{Read-PMMThemeFileIdentity $_.FullName}|Where-Object{$_ -and [string]$_.Id -ieq $id}|Select-Object -First 1)
  if($existing.Count -gt 0 -and -not$AllowReplace){throw 'A user theme with this ID already exists. Confirm replacement first.'}
  $root=Get-PMMPath 'Themes';$dest=Join-Path $root ([regex]::Replace($id,'[^a-z0-9._-]','-'));$backup=''
  if($existing.Count -gt 0){
    $oldPath=[string]$existing[0].Path;$oldRoot=if([string]$existing[0].Schema -eq 'PMM_COLOR_SCHEME_V2'){$existing[0].Root}else{$oldPath}
    $backup=Join-Path (Join-Path $root 'Backups') (([DateTime]::UtcNow.ToString('yyyyMMdd_HHmmss_fff'))+'_'+$id);New-Item -ItemType Directory -Force -Path (Split-Path -Parent $backup)|Out-Null
    Move-Item -LiteralPath $oldRoot -Destination $backup
  }elseif(Test-Path -LiteralPath $dest){$backup=Join-Path (Join-Path $root 'Backups') (([DateTime]::UtcNow.ToString('yyyyMMdd_HHmmss_fff'))+'_'+$id);New-Item -ItemType Directory -Force -Path (Split-Path -Parent $backup)|Out-Null;Move-Item -LiteralPath $dest -Destination $backup}
  try{
    New-Item -ItemType Directory -Force -Path $dest|Out-Null
    $draftRoot=Get-PMMThemeDraftRoot ([string]$Draft.DraftId);if(Test-Path -LiteralPath (Join-Path $draftRoot 'assets') -PathType Container){Copy-Item -LiteralPath (Join-Path $draftRoot 'assets') -Destination $dest -Recurse -Force}
    Write-PMMAIIOJsonAtomic (Join-Path $dest 'theme.json') $definition 45
    $parsed=Convert-PMMThemeJson (Join-Path $dest 'theme.json');if(-not$parsed){throw 'Installed theme did not pass the runtime parser.'}
    return [pscustomobject]@{Id=$id;Path=(Join-Path $dest 'theme.json');Replaced=($existing.Count -gt 0);BackupPath=$backup}
  }catch{Remove-Item -LiteralPath $dest -Recurse -Force -ErrorAction SilentlyContinue;if($backup -and (Test-Path -LiteralPath $backup)){if($existing.Count -gt 0 -and [string]$existing[0].Schema -eq 'PMM_COLOR_SCHEME_V1'){Move-Item -LiteralPath $backup -Destination ([string]$existing[0].Path)}else{Move-Item -LiteralPath $backup -Destination $dest}};throw}
}

function Export-PMMThemeDraft {
  [CmdletBinding()]
  param([Parameter(Mandatory=$true)]$Draft,[Parameter(Mandatory=$true)][string]$DestinationDirectory)
  $definition=Convert-PMMThemeDraftToDefinition $Draft;New-Item -ItemType Directory -Force -Path $DestinationDirectory|Out-Null
  $safe=[regex]::Replace([string]$definition.id,'[^a-z0-9._-]','-')
  if([string]$definition.schema -eq 'PMM_COLOR_SCHEME_V1'){$path=Join-Path $DestinationDirectory ('PMM_COLOR_SCHEME_'+$safe+'.json');Write-PMMAIIOJsonAtomic $path $definition 40;return [pscustomobject]@{Path=$path;Schema=[string]$definition.schema;Sha256=(Get-Sha256 $path)}}
  $stage=Join-Path (Get-PMMPath 'Temp') ('ThemeExport_'+[guid]::NewGuid().ToString('N'));$partial=$stage+'.zip.partial';$zip=Join-Path $DestinationDirectory ('PMM_THEME_PACK_'+$safe+'.zip')
  try{
    New-Item -ItemType Directory -Force -Path $stage|Out-Null;Set-PMMTransientStageOwner $stage 'ThemeExport';Write-PMMAIIOJsonAtomic (Join-Path $stage 'theme.json') $definition 45
    $draftRoot=Get-PMMThemeDraftRoot ([string]$Draft.DraftId);if(Test-Path -LiteralPath (Join-Path $draftRoot 'assets')){Copy-Item -LiteralPath (Join-Path $draftRoot 'assets') -Destination $stage -Recurse -Force}
    Write-PMMAIIOJsonAtomic (Join-Path $stage 'theme-pack.json') ([ordered]@{schema='PMM_THEME_PACK_V1';theme='theme.json';themeId=[string]$definition.id;assets=@($definition.brushes.Values|ForEach-Object{[string]$_.source}|Sort-Object -Unique);createdUtc=[DateTime]::UtcNow.ToString('o')}) 20
    $runtime=Get-PMMRuntimePath;$output=@(& $runtime archive create $partial $stage 2>&1|ForEach-Object{[string]$_});if($LASTEXITCODE -ne 0 -or -not(Test-Path -LiteralPath $partial)){throw ('Could not create theme pack. '+($output -join ' '))};Move-Item -LiteralPath $partial -Destination $zip -Force
    return [pscustomobject]@{Path=$zip;Schema=[string]$definition.schema;Sha256=(Get-Sha256 $zip)}
  }finally{Remove-Item -LiteralPath $stage -Recurse -Force -ErrorAction SilentlyContinue;Remove-PMMTransientStageOwner $stage;Remove-Item -LiteralPath $partial -Force -ErrorAction SilentlyContinue}
}

function New-PMMThemeAIRequest {
  [CmdletBinding()]
  param([Parameter(Mandatory=$true)]$Draft,[string]$Prompt='',[string[]]$ReferenceImages=@())
  if($Prompt.Length -gt 12000){throw 'Theme inspiration prompt exceeds 12,000 characters.'}
  $definition=Convert-PMMThemeDraftToDefinition $Draft;$requestId='THEME-'+[DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss')+'-'+[guid]::NewGuid().ToString('N').Substring(0,8)
  $stage=Join-Path (Get-PMMPath 'Temp') ('ThemeAI_'+[guid]::NewGuid().ToString('N'));$partial=$stage+'.zip.partial';$zip=Join-Path (Get-PMMPath 'ThemeHandoffs') ('PMM_THEME_AI_REQUEST_'+$requestId+'.zip')
  try{
    New-Item -ItemType Directory -Force -Path $stage|Out-Null
    Set-PMMTransientStageOwner $stage 'ThemeAIRequest'
    Write-PMMAIIOJsonAtomic (Join-Path $stage 'request.json') ([ordered]@{schema='PMM_THEME_AI_REQUEST_V1';requestId=$requestId;product='Palworld Manager Merger';creator='laredson';prompt=$Prompt;requestedResponse='PMM_THEME_AI_RESPONSE_V1';createdUtc=[DateTime]::UtcNow.ToString('o')}) 20
    Write-PMMAIIOJsonAtomic (Join-Path $stage 'current-theme.json') $definition 45
    Write-PMMAIIOJsonAtomic (Join-Path $stage 'theme-ui-contract.json') ([ordered]@{schema='PMM_THEME_UI_CONTRACT_V1';fields=@(Get-PMMThemeEditorFields);imageRules=[ordered]@{formats=@('PNG','JPEG');maximumBytes=8388608;maximumWidth=4096;maximumHeight=4096;maximumPixels=32000000;externalUrlsAllowed=$false}}) 35
    $refDir=Join-Path $stage 'references';New-Item -ItemType Directory -Force -Path $refDir|Out-Null;$count=0
    foreach($path in @($ReferenceImages|Select-Object -Unique)){$info=Test-PMMThemeImageFile $path;$count++;Copy-Item -LiteralPath $info.Path -Destination (Join-Path $refDir ('reference-{0:D2}{1}' -f $count,$info.Extension)) -Force}
    if(Test-Path -LiteralPath (Join-Path $Script:Root 'Documentation\PMM_COLOR_SCHEME_CREATION_GUIDE.md')){Copy-Item -LiteralPath (Join-Path $Script:Root 'Documentation\PMM_COLOR_SCHEME_CREATION_GUIDE.md') -Destination (Join-Path $stage 'COLOR_SCHEME_CREATION_GUIDE.md') -Force}
    $runtime=Get-PMMRuntimePath;$output=@(& $runtime archive create $partial $stage 2>&1|ForEach-Object{[string]$_});if($LASTEXITCODE -ne 0 -or -not(Test-Path -LiteralPath $partial)){throw ('Could not create theme AI request. '+($output -join ' '))};Move-Item -LiteralPath $partial -Destination $zip -Force
    return [pscustomobject]@{RequestId=$requestId;Path=$zip;Sha256=(Get-Sha256 $zip)}
  }finally{Remove-Item -LiteralPath $stage -Recurse -Force -ErrorAction SilentlyContinue;Remove-PMMTransientStageOwner $stage;Remove-Item -LiteralPath $partial -Force -ErrorAction SilentlyContinue}
}

function Import-PMMThemeAIResponse {
  [CmdletBinding()]
  param([Parameter(Mandatory=$true)][string]$ZipPath)
  $item=Get-Item -LiteralPath $ZipPath -ErrorAction Stop
  if($item.Extension -ine '.zip' -or [int64]$item.Length -gt 31457280){throw 'Theme AI response must be a ZIP no larger than 30 MiB.'}
  Add-Type -AssemblyName System.IO.Compression.FileSystem
  $stage=Join-Path (Get-PMMPath 'Temp') ('ThemeAIResponse_'+[guid]::NewGuid().ToString('N'))
  $archive=$null;$draft=$null;$complete=$false
  try{
    New-Item -ItemType Directory -Force -Path $stage|Out-Null
    Set-PMMTransientStageOwner $stage 'ThemeAIResponse'
    $archive=[IO.Compression.ZipFile]::OpenRead($item.FullName);$entries=@($archive.Entries)
    if($entries.Count -gt 300){throw 'Theme AI response contains more than 300 entries.'}
    [int64]$expanded=0
    $seenEntries=[Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach($entry in $entries){
      $name=([string]$entry.FullName).Replace([char]92,[char]47)
      if(-not(Test-PMMThemeArchiveEntryPath $name)){throw ('Unsafe theme response path: '+$name)}
      if(-not$seenEntries.Add($name)){throw ('Duplicate theme response path: '+$name)}
      $expanded+=[int64]$entry.Length;if($expanded -gt 62914560){throw 'Theme AI response expands beyond 60 MiB.'}
      $unixType=(([int64]$entry.ExternalAttributes -shr 16) -band 0xF000);if($unixType -eq 0xA000){throw ('Symbolic links are forbidden: '+$name)}
      if([string]::IsNullOrWhiteSpace([string]$entry.Name)){continue}
      if($name -notin @('response.json','theme.json') -and $name -cnotmatch '^assets/[a-zA-Z0-9._-]+\.(png|jpg|jpeg)$'){throw ('Theme response contains an unrecognized file: '+$name)}
      $target=Join-Path $stage $name.Replace([char]47,[IO.Path]::DirectorySeparatorChar);$parent=Split-Path -Parent $target;New-Item -ItemType Directory -Force -Path $parent|Out-Null
      $source=$entry.Open();$dest=$null;try{$dest=[IO.File]::Open($target,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None);$source.CopyTo($dest)}finally{if($dest){$dest.Dispose()};$source.Dispose()}
    }
    $responsePath=Join-Path $stage 'response.json';$themePath=Join-Path $stage 'theme.json'
    if(-not(Test-Path -LiteralPath $responsePath -PathType Leaf) -or -not(Test-Path -LiteralPath $themePath -PathType Leaf)){throw 'Theme AI response requires response.json and theme.json at the root.'}
    $response=Get-Content -LiteralPath $responsePath -Raw -Encoding UTF8|ConvertFrom-Json -ErrorAction Stop
    if([string]$response.schema -ne 'PMM_THEME_AI_RESPONSE_V1'){throw 'Unsupported theme AI response schema.'}
    $definition=Convert-PMMThemeJson $themePath;if(-not$definition){throw 'Returned theme failed schema, image or contrast validation.'}
    $draft=New-PMMThemeDraft -SourceDefinition $definition -Name ([string]$definition.Name) -Id ([string]$definition.Id)
    if([string]$definition.Schema -eq 'PMM_COLOR_SCHEME_V2'){
      $entriesByKey=ConvertTo-PMMThemeDraftHashtable $definition.Brushes
      foreach($key in @($entriesByKey.Keys)){
        $source=[string]$entriesByKey[$key].source;$asset=Join-Path $stage $source.Replace([char]47,[IO.Path]::DirectorySeparatorChar)
        $draft=Set-PMMThemeDraftImage $draft ([string]$key) $asset
        $brushKey=[string]$key;$draftBrushes=ConvertTo-PMMThemeDraftHashtable $draft.Brushes;$installed=$draftBrushes[$brushKey];$original=$entriesByKey[$key]
        foreach($prop in @('stretch','alignment','tileMode','opacity','overlay')){try{if($original.PSObject.Properties.Name -contains $prop){$installed[$prop]=$original.$prop}elseif($original -is [Collections.IDictionary] -and $original.Contains($prop)){$installed[$prop]=$original[$prop]}}catch{}}
        $draftBrushes[$brushKey]=$installed;$draft.Brushes=$draftBrushes
      }
      Save-PMMThemeDraft $draft|Out-Null
    }
    $complete=$true
    return [pscustomobject]@{Draft=$draft;RequestId=[string]$response.requestId;Summary=[string]$response.summary;ZipSha256=(Get-Sha256 $item.FullName)}
  }finally{
    if($archive){$archive.Dispose()}
    if(-not$complete -and $draft -and -not[string]::IsNullOrWhiteSpace([string]$draft.DraftId)){try{Remove-PMMThemeDraft ([string]$draft.DraftId)}catch{}}
    Remove-Item -LiteralPath $stage -Recurse -Force -ErrorAction SilentlyContinue
    Remove-PMMTransientStageOwner $stage
  }
}

function Remove-PMMThemeDraft([string]$DraftId) {
  $root=Get-PMMThemeDraftRoot $DraftId;if(Test-Path -LiteralPath $root){Remove-Item -LiteralPath $root -Recurse -Force}
}
