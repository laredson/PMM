param()
Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
$repo=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$fixture=Join-Path ([IO.Path]::GetTempPath()) ('PMM-cases-v4-'+[guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($fixture)
$Script:Fixture=$fixture
$Script:Assertions=0
function Assert-CaseTest([bool]$Condition,[string]$Message){$Script:Assertions++;if(-not$Condition){throw ('FAIL: '+$Message)}}
function Assert-CaseThrows([scriptblock]$Body,[string]$Message){$threw=$false;try{&$Body|Out-Null}catch{$threw=$true};Assert-CaseTest $threw $Message}
function Join-PMMPath([string]$Root,[string]$Child){return (Join-Path (Join-Path $Script:Fixture $Root) $Child)}
function Get-PMMPath([string]$Name){return (Join-Path $Script:Fixture $Name)}
function Get-Sha256([string]$Path){return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()}
function Get-PMMStableTextId([string]$Text){return (Get-PMMCaseDigest $Text).Substring(0,32)}
function Get-PMMEngineId{return 'fixture-engine'}
function Get-PMMMappingsPath{return (Join-Path $Script:Fixture 'mapping.usmap')}
function Write-PMMLog([string]$Message){}
function Test-PMMPathInside([string]$Path,[string]$Root){return ([IO.Path]::GetFullPath($Path).StartsWith([IO.Path]::GetFullPath($Root).TrimEnd('\')+'\',[StringComparison]::OrdinalIgnoreCase))}
function Read-PMMReviewCase([string]$Root){$path=Join-Path $Root 'case.json';if(Test-Path $path){return (Get-Content -LiteralPath $path -Raw|ConvertFrom-Json)};return $null}
function Get-LibraryMods{return $Script:TestMods}
try{
  . (Join-Path $repo 'PMM/Modules/Shared/Persistence.ps1')
  . (Join-Path $repo 'PMM/Modules/AIIO/AIIO.ps1')
  . (Join-Path $repo 'PMM/Modules/AIIO/AIIO.CaseWorkspaceService.ps1')
  . (Join-Path $repo 'PMM/Modules/AIIO/AIIO.CaseWorkspace.Preview5.ps1')
  . (Join-Path $repo 'PMM/Modules/Cases/CaseService.ps1')
  [IO.File]::WriteAllText((Get-PMMMappingsPath),'mappings')
  $mods=@(foreach($name in @('Alpha.pak','Beta.pak','Gamma.pak')){
    $path=Join-Path $fixture $name;[IO.File]::WriteAllText($path,$name)
    [pscustomobject]@{Name=$name;Path=$path;Hash=(Get-Sha256 $path);Priority=([array]::IndexOf(@('Alpha.pak','Beta.pak','Gamma.pak'),$name)+1);Size=(Get-Item $path).Length}
  })
  $Script:TestMods=$mods
  $vanilla=Join-Path $fixture 'vanilla.txt';[IO.File]::WriteAllText($vanilla,'vanilla')
  function New-TestAsset([string]$Asset,[array]$Providers=@('Alpha.pak','Beta.pak')){
    $root=Join-Path (Get-PMMPath 'Review') ([IO.Path]::GetFileNameWithoutExtension($Asset));[void][IO.Directory]::CreateDirectory($root)
    $inputs=@([pscustomobject]@{Role='Vanilla';Provider='Vanilla';Part='.txt';Sha256=(Get-Sha256 $vanilla);Size=(Get-Item $vanilla).Length})
    foreach($name in $Providers){$mod=@($mods|Where-Object Name -eq $name)[0];$inputs+=,[pscustomobject]@{Role='Provider';Provider=$name;Part='.txt';Sha256=$mod.Hash;Size=$mod.Size}}
    $key=$Asset.ToLowerInvariant()
    $signature=$key+'|'+(($inputs|ForEach-Object{"$($_.Role):$($_.Provider):$($_.Part):$($_.Sha256)"}) -join '|')
    $review=[pscustomobject]@{Schema='PMM_REVIEW_CASE_V1';CaseId=(Get-PMMStableTextId $signature);Asset=$Asset;AssetKey=$key;Mode='Unsupported';CaseKind='PlainFile';VanillaAvailable=$true;Providers=@($Providers|ForEach-Object{$mod=@($mods|Where-Object Name -eq $_)[0];[pscustomobject]@{Name=$mod.Name;PakSha256=$mod.Hash}});InputFiles=$inputs}
    Write-PMMCaseDocument (Join-Path $root 'case.json') $review
    return [pscustomobject]@{Asset=$Asset;AssetKey=$key;Mode='Unsupported';Providers=$Providers;ReviewFolder=$root;CaseId=$review.CaseId;Reason='Fixture unsupported file'}
  }
  $first=New-TestAsset 'Pal/Content/first.txt'
  $second=New-TestAsset 'Pal/Content/second.txt'
  $plan=[pscustomobject]@{Assets=@($first,$second);SourceMods=$mods;MappingsSha256=(Get-Sha256 (Get-PMMMappingsPath));VanillaSourceSignature='vanilla-v1';Engine='fixture';EngineProfile='UE5_1';MergeOrder=@('Alpha.pak','Beta.pak','Gamma.pak');KnowledgeRulesSha256=('a'*64)}
  Assert-CaseTest (@(Sync-PMMCasesFromAnalysis $plan).Count -eq 0) 'unfinished analysis publishes nothing'
  Assert-CaseTest (@(Sync-PMMCasesFromAnalysis $plan -Completed -Cancelled).Count -eq 0) 'cancelled analysis publishes nothing'
  Assert-CaseTest (@(Get-PMMAIIOCases).Count -eq 0) 'no partial cases'
  $results=@(Sync-PMMCasesFromAnalysis $plan -Completed)
  Assert-CaseTest ($results.Count -eq 2) 'one case per unsupported asset'
  $id=$results[0].CaseId;$initial=$results[0].EvidenceRevision
  $repeat=@(Sync-PMMCasesFromAnalysis $plan -Completed)
  Assert-CaseTest ($repeat[0].CaseId -eq $id -and $repeat[0].EvidenceRevision -eq $initial) 'repeat is stable'
  Assert-CaseTest (@(Get-PMMAIIOCases).Count -eq 2) 'repeat does not duplicate'
  Assert-CaseTest ((Get-PMMCaseForAsset $first).CaseId -eq $id) 'asset resolves its persistent case'
  $plan.MergeOrder=@('Beta.pak','Alpha.pak','Gamma.pak')
  $reordered=@(Sync-PMMCasesFromAnalysis $plan -Completed)
  Assert-CaseTest ($reordered[0].CaseId -eq $id -and $reordered[0].EvidenceRevision -ne $initial) 'provider order creates new revision'
  Assert-CaseThrows {Assert-PMMCaseResponseRevision $id $initial} 'stale response rejected'
  Assert-CaseThrows {Assert-PMMCaseResponseRevision $id '' $first.CaseId} 'ambiguous legacy review cannot bind new order'
  Assert-CaseTest ((Get-PMMCaseEvidenceRevision $id $initial).Evidence.MergeOrder[0] -eq 'Alpha.pak') 'prior evidence immutable'
  $plan.MappingsSha256='b'*64
  $mapped=@(Sync-PMMCasesFromAnalysis $plan -Completed)
  Assert-CaseTest ($mapped[0].EvidenceRevision -ne $reordered[0].EvidenceRevision) 'mapping changes evidence'
  $other=New-TestAsset 'Pal/Content/third.txt' @('Alpha.pak','Gamma.pak')
  $plan.Assets=@($other)
  $new=@(Sync-PMMCasesFromAnalysis $plan -Completed)
  Assert-CaseTest ($new[0].CaseId -ne $id) 'different providers use different case'
  $count=@(Get-PMMAIIOCases).Count
  $bad=[pscustomobject]@{Asset='Pal/Content/broken.txt';Mode='Unsupported';ReviewFolder=(Join-Path $fixture 'missing');Providers=@('Alpha.pak')}
  $plan.Assets=@((New-TestAsset 'Pal/Content/fourth.txt'),$bad)
  Assert-CaseThrows {Sync-PMMCasesFromAnalysis $plan -Completed} 'invalid analysis fails preflight'
  Assert-CaseTest (@(Get-PMMAIIOCases).Count -eq $count) 'preflight failure publishes no partial batch'
  $manual=New-PMMContextCase -Type Compat -Mods @($mods[0],$mods[1]) -Origin Jugar -RelatedCaseIds @($id)
  Assert-CaseTest ($manual.Type -eq 'COMPATIBILITY' -and @($manual.References.Mods).Count -eq 2) 'multi-mod context'
  $manual.Transport='MCP';Save-PMMAIIOCase $manual|Out-Null
  Assert-CaseTest ((Get-PMMAIIOCase $manual.CaseId).CurrentEvidenceRevision -eq $manual.CurrentEvidenceRevision) 'transport preserves revision'
  $query=New-PMMContextCase -Type Query -Description 'What changes?' -Origin Crear
  Assert-CaseTest ($query.Type -eq 'QUERY' -and $query.CurrentEvidenceRevision) 'query gets identity and revision'
  Initialize-PMMCaseContracts;Initialize-PMMCaseContracts
  Assert-CaseTest (@(Get-PMMAIIOCases).Count -eq ($count+2)) 'migration is idempotent'
  $document=[pscustomobject]@{schema='PMM_AIIO_WORK_ORDER_V1';case=[pscustomobject]@{caseId=$manual.CaseId;evidenceRevision=$initial};actions=@([pscustomobject]@{action='include_log'})}
  $workorder=Join-Path $fixture 'workorder.json';Write-PMMCaseDocument $workorder $document
  Assert-CaseThrows {Import-PMMAIIOWorkOrder $workorder $document} 'work order guards revision before intake'
  $document.case.evidenceRevision=$manual.CurrentEvidenceRevision;Write-PMMCaseDocument $workorder $document
  $imported=Import-PMMAIIOWorkOrder $workorder $document
  Assert-CaseTest ($imported.PendingActions[0].EvidenceRevision -eq $manual.CurrentEvidenceRevision) 'intake pins action revision'
  Add-PMMCaseEvidenceRevision $manual.CaseId ([ordered]@{Kind='ManualContext';Changed=$true})|Out-Null
  Assert-CaseThrows {Assert-PMMCasePendingActionRevisions $manual.CaseId} 'queued actions cannot silently use changed evidence'
  $stable=(Get-PMMAIIOCase $query.CaseId).CurrentEvidenceRevision
  Assert-CaseTest ((Update-PMMCaseContextRevision $query.CaseId) -eq $stable) 'unchanged editor save is idempotent'
  $query.Description='Different objective';Save-PMMAIIOCase $query|Out-Null
  Assert-CaseTest ((Update-PMMCaseContextRevision $query.CaseId) -ne $stable) 'objective change revises context'
  $beforeCount=@(Get-PMMAIIOCases).Count;$beforeRevision=(Get-PMMAIIOCase $id).CurrentEvidenceRevision
  $plan.Assets=@($first,(New-TestAsset 'Pal/Content/fifth.txt'));$plan.MappingsSha256='c'*64
  $Script:CaseRealWriter=(Get-Command Write-PMMCaseDocument).ScriptBlock
  function Write-PMMCaseDocument([string]$Path,$Value){if($Path -match '[\\/]\.publications[\\/]'){throw 'Injected publication commit failure'};&$Script:CaseRealWriter $Path $Value}
  Assert-CaseThrows {Sync-PMMCasesFromAnalysis $plan -Completed} 'injected batch commit failure'
  Set-Item -Path function:Write-PMMCaseDocument -Value $Script:CaseRealWriter
  Assert-CaseTest (@(Get-PMMAIIOCases).Count -eq $beforeCount) 'uncommitted new case stays hidden'
  Assert-CaseTest ((Get-PMMAIIOCase $id).CurrentEvidenceRevision -eq $beforeRevision) 'uncommitted update leaves prior revision visible'
  $resumed=@(Sync-PMMCasesFromAnalysis $plan -Completed)
  Assert-CaseTest ($resumed.Count -eq 2 -and @(Get-PMMAIIOCases).Count -eq ($beforeCount+1)) 'retry publishes batch without duplicate case'
  $contextCase=New-PMMContextCase -Type Fix -Mods @($mods[0])
  Assert-CaseTest (Assert-PMMCaseInputsCurrent $contextCase.CaseId) 'current files are revalidated before trial'
  [IO.File]::WriteAllText($mods[0].Path,'changed after analysis')
  Assert-CaseThrows {Assert-PMMCaseInputsCurrent $contextCase.CaseId} 'actual file change rejects trial even without Analyze'
  [IO.File]::WriteAllText($mods[0].Path,$mods[0].Name)
  $handoff=New-PMMAIIOCaseHandoff $contextCase.CaseId
  $archive=[IO.Compression.ZipFile]::OpenRead($handoff.ZipPath)
  try{
    Assert-CaseTest (@($archive.Entries|Where-Object FullName -eq 'evidence-revision.json').Count -eq 1) 'context ZIP includes immutable revision'
    Assert-CaseTest (@($archive.Entries|Where-Object {([string]$_.FullName).Replace([char]92,[char]47) -like 'sources/provider-1/*.pak'}).Count -eq 1) 'context ZIP includes selected verified mod'
  }finally{$archive.Dispose()}
  # Exercise the actual vanilla+provider extraction branch that used to overwrite $Item.
  function Export-VanillaFileExact([string]$Asset,[string]$Root){$target=Join-Path $Root $Asset;[void][IO.Directory]::CreateDirectory((Split-Path $target -Parent));Copy-Item $vanilla $target;return $target}
  function Export-PakFileExact([string]$Pak,[string]$Asset,[string]$Root){$target=Join-Path $Root $Asset;[void][IO.Directory]::CreateDirectory((Split-Path $target -Parent));Copy-Item $Pak $target;return $target}
  $first|Add-Member -NotePropertyName Case -NotePropertyValue (Read-PMMReviewCase $first.ReviewFolder) -Force
  $bytes=0L;$stage=Join-Path $fixture 'sources-test'
  $rows=@(Export-PMMAIIOAssetSources $first $stage $mods @{} ([ref]$bytes) $false)
  Assert-CaseTest ($rows.Count -eq 3 -and @($rows|Where-Object Role -eq Provider).Count -eq 2) 'vanilla extraction preserves provider collection'
  Assert-CaseTest ($bytes -eq ((Get-Item $vanilla).Length+$mods[0].Size+$mods[1].Size)) 'source bytes account for all providers'
  $recovery=New-PMMContextCase -Type Query -Description 'Recovery fixture'
  Save-PMMAIIOCase $recovery|Out-Null
  $casePath=Join-Path (Get-PMMAIIOCasePath $recovery.CaseId) 'case.json'
  [IO.File]::WriteAllText($casePath,'{truncated')
  Assert-CaseTest ((Get-PMMAIIOCase $recovery.CaseId).CaseId -eq $recovery.CaseId) 'truncated case recovers verified backup'
  Assert-CaseTest ((Get-Content -LiteralPath $casePath -Raw|ConvertFrom-Json).CaseId -eq $recovery.CaseId) 'backup recovery repairs the current file'
  Write-Output ('PASS cases_v4_regression: '+$Script:Assertions+' assertions; PS '+$PSVersionTable.PSVersion)
}finally{
  $resolved=[IO.Path]::GetFullPath($fixture)
  $tempRoot=[IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\')+'\'
  if($resolved.StartsWith($tempRoot,[StringComparison]::OrdinalIgnoreCase) -and [IO.Path]::GetFileName($resolved).StartsWith('PMM-cases-v4-')){Remove-Item -LiteralPath $resolved -Recurse -Force}
}
