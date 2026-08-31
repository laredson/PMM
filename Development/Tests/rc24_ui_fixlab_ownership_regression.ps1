param([string]$Root=([IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))))

Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$Root=[IO.Path]::GetFullPath($Root)
$App=Join-Path $Root 'PMM'

function Assert-RC24([bool]$Condition,[string]$Message){if(-not$Condition){throw $Message}}
function Read-App([string]$Relative){return (Get-Content -LiteralPath (Join-Path $App $Relative) -Raw -Encoding UTF8)}
function Get-FunctionText([string]$Path,[string]$Name){
  $tokens=$null;$errors=$null
  $ast=[System.Management.Automation.Language.Parser]::ParseFile($Path,[ref]$tokens,[ref]$errors)
  Assert-RC24 (@($errors).Count -eq 0) ('PowerShell parse failure: '+$Path)
  $node=$ast.Find({param($candidate)
    if(-not($candidate -is [System.Management.Automation.Language.FunctionDefinitionAst])){return $false}
    return ([string]$candidate.Name -eq $Name -or [string]$candidate.Name -eq ('script:'+$Name))
  },$true)
  Assert-RC24 ($null -ne $node) ('Function not found: '+$Name)
  return [string]$node.Extent.Text
}

$fixPath=Join-Path $App 'Modules\FixLab\FixLabService.ps1'
$libraryPath=Join-Path $App 'Modules\Library\LibraryService.ps1'
$mergePath=Join-Path $App 'Modules\Merge\MergeEngine.ps1'
$bootstrap=Read-App 'Modules\Bootstrap\Start-PalModMerger.ps1'
$mergeEngine=Get-Content -LiteralPath $mergePath -Raw -Encoding UTF8
$deployFix=Get-FunctionText $fixPath 'Deploy-PMMFixLabBuiltOutput'
$restoreFix=Get-FunctionText $fixPath 'Restore-PMMFixLabCase'
$toggleMod=Get-FunctionText $libraryPath 'Set-PMMLibraryModEnabled'
$deleteMod=Get-FunctionText $libraryPath 'Remove-PMMLibraryMod'

foreach($row in @(
  [pscustomobject]@{Name='Deploy Fix';Text=$deployFix},
  [pscustomobject]@{Name='Restore Fix';Text=$restoreFix},
  [pscustomobject]@{Name='Enable/disable source mod';Text=$toggleMod},
  [pscustomobject]@{Name='Delete source mod';Text=$deleteMod}
)){
  Assert-RC24 ($row.Text -notmatch 'zzzzzzzzzz_PMM_Merge_') ($row.Name+' still addresses the reserved merge namespace.')
}
Assert-RC24 ($deployFix -match [regex]::Escape('belongs exclusively to Mods & Merge')) 'Deploy Fix ownership boundary missing.'
Assert-RC24 ($restoreFix -match [regex]::Escape('deployed compatibility merge preserved')) 'Restore Fix preservation marker missing.'
Assert-RC24 ($deleteMod -notmatch [regex]::Escape('$state.Patch=$null')) 'Delete source mod still clears deployed patch state.'
Assert-RC24 ($deleteMod -notmatch [regex]::Escape("Set-PMMSelectedPatchName ''")) 'Delete source mod still clears merge selection.'
Assert-RC24 ($deleteMod -match [regex]::Escape('deployedMergePreserved=true')) 'Delete source preservation marker missing.'
Assert-RC24 ($mergeEngine -notmatch '(?im)^function\s+Restore-PMMDeployment\b') 'Legacy non-UI undeploy entry point still exists.'

foreach($marker in @(
  'function Queue-PMMFixLabUiRefresh',
  'DispatcherPriority]::ContextIdle',
  '$Script:FixLabRefreshIntervalSeconds=60',
  'Get-PMMFixLabDiscoveryCandidates -IncludeBackups -BackupRows $backups'
)){
  Assert-RC24 ($bootstrap -match [regex]::Escape($marker)) ('Deferred Fix Lab UI marker missing: '+$marker)
}

$xamlNamespace='http://schemas.microsoft.com/winfx/2006/xaml'
$reference=$null
foreach($name in @('MainWindow.xaml','MainWindow.en.xaml','MainWindow.es.xaml')){
  $path=Join-Path $App ('Resources\UI\'+$name)
  $text=Get-Content -LiteralPath $path -Raw -Encoding UTF8
  Assert-RC24 ($text -match [regex]::Escape('<ColumnDefinition Width="245"/>')) ('Responsive title column missing: '+$name)
  Assert-RC24 ($text -match [regex]::Escape('x:Name="GrdHeaderActions" Grid.Column="2" MinWidth="0" HorizontalAlignment="Stretch"')) ('Responsive controls column missing: '+$name)
  [xml]$doc=$text
  $manager=New-Object System.Xml.XmlNamespaceManager($doc.NameTable)
  $manager.AddNamespace('x',$xamlNamespace)
  $names=@($doc.SelectNodes('//*[@x:Name]',$manager)|ForEach-Object{$_.GetAttribute('Name',$xamlNamespace)})
  Assert-RC24 (@($names|Where-Object{$_ -eq 'BtnFixLabRefreshDashboard'}).Count -eq 1) ('Fix Lab Refresh button count mismatch: '+$name)
  Assert-RC24 (@($names|Group-Object|Where-Object Count -gt 1).Count -eq 0) ('Duplicate x:Name: '+$name)
  if($null -eq $reference){$reference=@($names|Sort-Object -Unique)}
  else{Assert-RC24 (@(Compare-Object $reference @($names|Sort-Object -Unique)).Count -eq 0) ('Localized XAML parity mismatch: '+$name)}
}

# Exercise the real RC24 Deploy/Restore functions against an isolated miniature
# game/library. The fake compatibility PAK and sidecar are sentinels: their
# bytes and hashes must survive both transactions unchanged.
$sandbox=Join-Path ([IO.Path]::GetTempPath()) ('PMM_RC24_OWNERSHIP_'+[guid]::NewGuid().ToString('N'))
try{
  $Script:Rc24GameMods=Join-Path $sandbox 'game-mods'
  $Script:Rc24Library=Join-Path $sandbox 'library'
  $Script:Rc24Disabled=Join-Path $sandbox 'disabled'
  $Script:Rc24FixLab=Join-Path $sandbox 'fixlab'
  $Script:Rc24LegacyDir=Join-Path $Script:Rc24Library 'GawrGura_v5_P'
  foreach($dir in @($Script:Rc24GameMods,$Script:Rc24Library,$Script:Rc24Disabled,$Script:Rc24FixLab,$Script:Rc24LegacyDir)){New-Item -ItemType Directory -Force -Path $dir|Out-Null}

  $legacyName='GawrGura_v5_P.pak'
  $repairName='GawrGura_hooded-gura_P.pak'
  $legacyLibraryPak=Join-Path $Script:Rc24LegacyDir $legacyName
  $legacyGamePak=Join-Path $Script:Rc24GameMods $legacyName
  $builtPak=Join-Path $sandbox $repairName
  $mergePak=Join-Path $Script:Rc24GameMods 'zzzzzzzzzz_PMM_Merge_SENTINEL_P.pak'
  $mergeSidecar=$mergePak+'.manifest.json'
  [IO.File]::WriteAllBytes($legacyLibraryPak,[byte[]](1,2,3,4,5))
  Copy-Item -LiteralPath $legacyLibraryPak -Destination $legacyGamePak -Force
  [IO.File]::WriteAllBytes($builtPak,[byte[]](9,8,7,6,5,4))
  [IO.File]::WriteAllBytes($mergePak,[byte[]](21,22,23,24,25))
  [IO.File]::WriteAllBytes($mergeSidecar,[byte[]](31,32,33,34))
  $mergeHashBefore=(Get-FileHash -LiteralPath $mergePak -Algorithm SHA256).Hash
  $sidecarHashBefore=(Get-FileHash -LiteralPath $mergeSidecar -Algorithm SHA256).Hash

  . $fixPath
  function script:Get-PMMText([string]$English,[string]$Spanish){return $English}
  function script:Get-Sha256([string]$Path){return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()}
  function script:Get-PMMPath([string]$Key){if($Key -eq 'FixLab'){return $Script:Rc24FixLab};return (Join-Path $sandbox $Key)}
  function script:Get-LibraryRoot{return $Script:Rc24Library}
  function script:Get-PMMDisabledModRoot{return $Script:Rc24Disabled}
  function script:Get-PMMConfig{return [pscustomobject]@{GamePath=(Join-Path $sandbox 'game')}}
  function script:Ensure-GameModsFolder{}
  function script:Stop-PalworldForDeployment{}
  function script:Get-GameModsPath{return $Script:Rc24GameMods}
  function script:Test-Pak([string]$Path){return (Test-Path -LiteralPath $Path -PathType Leaf)}
  function script:Assert-PakAssetFamiliesComplete([string]$Path){}
  function script:Write-PMMLog([string]$Message){}
  function script:Clear-PMMLibraryHashCache{}
  function script:Clear-PakEntryCache{}
  function script:Clear-PMMAnalysisState{}
  function script:Remove-PMMPendingRemoval([string]$Name){}
  function script:Add-PMMPendingRemoval([string]$Name,[string]$Hash){}
  function script:Get-PMMModPriorityOrder{return @($legacyName)}
  function script:Write-PMMModPriorityOrder([array]$Names){}
  function script:Test-PMMPathInside([string]$Child,[string]$Parent){
    $trimChars=[char[]]@([IO.Path]::DirectorySeparatorChar,[IO.Path]::AltDirectorySeparatorChar)
    $c=[IO.Path]::GetFullPath($Child).TrimEnd($trimChars)+[IO.Path]::DirectorySeparatorChar
    $p=[IO.Path]::GetFullPath($Parent).TrimEnd($trimChars)+[IO.Path]::DirectorySeparatorChar
    return $c.StartsWith($p,[StringComparison]::OrdinalIgnoreCase)
  }
  function script:Get-LibraryMods{
    $pak=Join-Path $Script:Rc24LegacyDir $legacyName
    if(Test-Path -LiteralPath $pak -PathType Leaf){return ,([pscustomobject]@{Name=$legacyName;Hash=(Get-Sha256 $pak);Path=$pak;Enabled=$true;Priority=1})}
    return @()
  }
  function script:Get-PMMDisabledMods{return @()}
  $recipe=[pscustomobject]@{
    id='fixlab-case-001-gawr-gura-v5';caseId='FIXLAB-CASE-001-GAWR-GURA';
    match=[pscustomobject]@{signatures=@([pscustomobject]@{kind='pak-sha256';sha256=(Get-Sha256 $legacyLibraryPak)})}
  }
  function script:Get-PMMFixLabRecipe([string]$RecipeId){return $recipe}

  $built=[pscustomobject]@{
    BuildId='FIXLAB-CASE-001-GAWR-GURA__hooded_locked';CaseId='FIXLAB-CASE-001-GAWR-GURA';
    RecipeId='fixlab-case-001-gawr-gura-v5';VariantId='hooded_locked';Path=$builtPak;Hash=(Get-Sha256 $builtPak)
  }
  [void](Deploy-PMMFixLabBuiltOutput $built)
  Assert-RC24 (Test-Path -LiteralPath $mergePak -PathType Leaf) 'Deploy Fix removed the sentinel compatibility PAK.'
  Assert-RC24 (Test-Path -LiteralPath $mergeSidecar -PathType Leaf) 'Deploy Fix removed the sentinel compatibility sidecar.'
  Assert-RC24 ((Get-FileHash -LiteralPath $mergePak -Algorithm SHA256).Hash -eq $mergeHashBefore) 'Deploy Fix changed the sentinel compatibility PAK.'
  Assert-RC24 ((Get-FileHash -LiteralPath $mergeSidecar -Algorithm SHA256).Hash -eq $sidecarHashBefore) 'Deploy Fix changed the sentinel compatibility sidecar.'

  $backup=@(Get-PMMFixLabBackups|Where-Object{[string]$_.CaseId -eq 'FIXLAB-CASE-001-GAWR-GURA'}|Select-Object -First 1)
  Assert-RC24 ($backup.Count -eq 1) 'Deploy Fix did not preserve the legacy source backup fixture.'
  [void](Restore-PMMFixLabCase 'FIXLAB-CASE-001-GAWR-GURA')
  Assert-RC24 (Test-Path -LiteralPath $mergePak -PathType Leaf) 'Restore Fix removed the sentinel compatibility PAK.'
  Assert-RC24 (Test-Path -LiteralPath $mergeSidecar -PathType Leaf) 'Restore Fix removed the sentinel compatibility sidecar.'
  Assert-RC24 ((Get-FileHash -LiteralPath $mergePak -Algorithm SHA256).Hash -eq $mergeHashBefore) 'Restore Fix changed the sentinel compatibility PAK.'
  Assert-RC24 ((Get-FileHash -LiteralPath $mergeSidecar -Algorithm SHA256).Hash -eq $sidecarHashBefore) 'Restore Fix changed the sentinel compatibility sidecar.'
  Assert-RC24 (Test-Path -LiteralPath $legacyGamePak -PathType Leaf) 'Restore Fix did not restore the legacy game PAK.'
}finally{
  if(Test-Path -LiteralPath $sandbox -PathType Container){Remove-Item -LiteralPath $sandbox -Recurse -Force}
}

$manifest=Get-Content -LiteralPath (Join-Path $App 'Resources\Metadata\RELEASE_MANIFEST.json') -Raw -Encoding UTF8|ConvertFrom-Json
Assert-RC24 ([string]$manifest.buildId -eq 'PMM-v1.3.0-RC30-LEAN-AI-VALIDATION-FLOW') 'Current build identity mismatch while checking RC24 ownership.'
Assert-RC24 ([string]$manifest.releaseCandidate -eq 'rc30-lean-ai-validation-flow') 'Current release-candidate identity mismatch while checking RC24 ownership.'

Write-Output 'RC24_UI_FIXLAB_OWNERSHIP_REGRESSION_OK'
