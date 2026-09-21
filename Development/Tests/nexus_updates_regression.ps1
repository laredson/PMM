param([string]$Repository=(Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path)
$ErrorActionPreference='Stop';Set-StrictMode -Version 2
$testRoot=Join-Path ([IO.Path]::GetTempPath()) ('pmm-nexus-'+[Guid]::NewGuid().ToString('N'));$Script:Root=Join-Path $Repository 'PMM'
[void][IO.Directory]::CreateDirectory((Join-Path $testRoot 'Workspace\State'));[void][IO.Directory]::CreateDirectory((Join-Path $testRoot 'Workspace\Cache'))
function Assert-True($Value,[string]$Message){if(-not$Value){throw $Message}}
function Join-PMMPath([string]$Kind,[string]$Child){$base=if($Kind -eq 'State'){Join-Path $testRoot 'Workspace\State'}elseif($Kind -eq 'Cache'){Join-Path $testRoot 'Workspace\Cache'}elseif($Kind -eq 'ModUpdates'){Join-Path $testRoot 'Workspace\ModUpdates'}else{Join-Path $testRoot ('Workspace\'+$Kind)};if($Child){Join-Path $base $Child}else{$base}}
function Get-PMMAnalysisValue($Object,[string]$Name,$Default=$null){if($null -ne $Object -and $Object.PSObject.Properties.Name -contains $Name){return $Object.$Name};$Default}
function Write-PMMJsonAtomic([string]$Path,$Value,[int]$Depth=40,[string]$Schema=''){[void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($Path));$tmp=$Path+'.tmp';[IO.File]::WriteAllText($tmp,($Value|ConvertTo-Json -Depth $Depth),[Text.UTF8Encoding]::new($false));if(Test-Path $Path){Remove-Item $Path -Force};[IO.File]::Move($tmp,$Path)}
function Read-PMMJsonFile([string]$Path,[string]$Schema=''){if(-not(Test-Path $Path)){throw 'missing'};$v=Get-Content $Path -Raw|ConvertFrom-Json;if($Schema -and $v.Schema -ne $Schema){throw 'schema'};$v}
function Get-Sha256([string]$Path){(Get-FileHash $Path -Algorithm SHA256).Hash.ToLowerInvariant()}
function Get-PMMAnalysisHash($Value){$json=$Value|ConvertTo-Json -Depth 30 -Compress;$sha=[Security.Cryptography.SHA256]::Create();try{(($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($json))|ForEach-Object{$_.ToString('x2')}) -join '')}finally{$sha.Dispose()}}
function Test-PMMPathInside([string]$Path,[string]$Root){$p=[IO.Path]::GetFullPath($Path).TrimEnd('\')+'\';$r=[IO.Path]::GetFullPath($Root).TrimEnd('\')+'\';$p.StartsWith($r,[StringComparison]::OrdinalIgnoreCase)}
$Script:active=@();$Script:disabled=@()
function Get-LibraryMods {$Script:active}
function Get-PMMDisabledMods {$Script:disabled}
. (Join-Path $Script:Root 'Modules\Analysis\Nexus.Client.ps1')
. (Join-Path $Script:Root 'Modules\Analysis\Updates.Service.ps1')
. (Join-Path $Script:Root 'Modules\Analysis\Updates.Transaction.ps1')
try{
  $parsed=ConvertFrom-PMMNexusModUrl 'https://www.nexusmods.com/palworld/mods/123?tab=files&file_id=456'
  Assert-True ($parsed.ModId -eq '123' -and $parsed.FileId -eq '456') 'Nexus URL identity failed.'
  try{[void](ConvertFrom-PMMNexusModUrl 'https://example.com/palworld/mods/123');throw 'foreign URL accepted'}catch{Assert-True ($_.Exception.Message -ne 'foreign URL accepted') 'Foreign URL was accepted.'}

  $expires=[DateTimeOffset]::UtcNow.AddMinutes(10).ToUnixTimeSeconds()
  $nxm=ConvertFrom-PMMNxmUri ('nxm://palworld/mods/123/files/456?key=abcdefghijk&expires='+$expires)
  Assert-True ($nxm.ModId -eq '123' -and $nxm.FileId -eq '456') 'NXM parsing failed.'
  $protected=Protect-PMMNxmRequest $nxm;Assert-True (-not$protected.Contains('abcdefghijk')) 'NXM secret remained plaintext.'
  Assert-True ((Unprotect-PMMNxmRequest $protected).FileId -eq '456') 'NXM DPAPI roundtrip failed.'
  try{[void](ConvertFrom-PMMNxmUri ('nxm://palworld/mods/123/files/456?key=abcdefghijk&key=duplicated&expires='+$expires));throw 'duplicate query accepted'}catch{Assert-True ($_.Exception.Message -ne 'duplicate query accepted') 'Repeated NXM query field was accepted.'}
  try{[void](ConvertFrom-PMMNxmUri ('nxm://other/mods/123/files/456?key=abcdefghijk&expires='+$expires));throw 'foreign NXM accepted'}catch{Assert-True ($_.Exception.Message -ne 'foreign NXM accepted') 'Foreign-game NXM was accepted.'}
  foreach($case in @(@(401,'NEXUS_UNAUTHORIZED'),@(403,'NEXUS_FORBIDDEN'),@(429,'NEXUS_RATE_LIMITED'),@(500,'NEXUS_UNAVAILABLE'))){$exception=[Exception]::new('fixture');$exception|Add-Member Response ([pscustomobject]@{StatusCode=$case[0]});Assert-True ((Get-PMMNexusFailureCode $exception) -eq $case[1]) ('Wrong Nexus status mapping for '+$case[0])}

  $handlerRoot=Join-Path $testRoot 'handler';$handlerDir=Join-Path $handlerRoot 'Modules\Analysis';[void][IO.Directory]::CreateDirectory($handlerDir);[void][IO.Directory]::CreateDirectory((Join-Path $handlerRoot 'Workspace\State'))
  Copy-Item (Join-Path $Script:Root 'Modules\Analysis\Nxm.Handler.ps1') (Join-Path $handlerDir 'Nxm.Handler.ps1')
  $handlerPlan=[ordered]@{Schema='PMM_UPDATE_PLAN_V1';Results=@([ordered]@{Status='UPDATE_AVAILABLE';Origin=[ordered]@{ModId='123'};Candidate=[ordered]@{FileId='456'}})}
  [IO.File]::WriteAllText((Join-Path $handlerRoot 'Workspace\State\update-plan.json'),($handlerPlan|ConvertTo-Json -Depth 8),[Text.UTF8Encoding]::new($false))
  $handler=Join-Path $handlerDir 'Nxm.Handler.ps1';$hostExe=Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe';$validUri='nxm://palworld/mods/123/files/456?key=abcdefghijk&expires='+$expires
  & $hostExe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $handler -Uri $validUri;Assert-True ($LASTEXITCODE -eq 0) 'Valid pending NXM request was rejected.'
  & $hostExe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $handler -Uri $validUri;Assert-True ($LASTEXITCODE -eq 0) 'Duplicate NXM request did not exit cleanly.'
  $queued=@(Get-ChildItem (Join-Path $handlerRoot 'Workspace\State\IncomingNxm') -Filter *.nxmq -File);Assert-True ($queued.Count -eq 1) 'Duplicate NXM request was queued twice.';Assert-True (-not([IO.File]::ReadAllText($queued[0].FullName).Contains('abcdefghijk'))) 'NXM handler stored a secret in plaintext.'
  & $hostExe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $handler -Uri ('nxm://palworld/mods/123/files/457?key=abcdefghijk&expires='+$expires);Assert-True ($LASTEXITCODE -eq 6) 'NXM request for a different file was accepted.'

  $secure=ConvertTo-SecureString ('a'*32) -AsPlainText -Force;Set-PMMNexusCredential $secure
  $disk=[IO.File]::ReadAllText((Get-PMMNexusCredentialPath));Assert-True (-not$disk.Contains('aaaaaaaa')) 'API key stored as plaintext.'
  Assert-True ((Get-PMMNexusCredential).Length -eq 32) 'API key DPAPI roundtrip failed.';Disconnect-PMMNexusAccount

  $mod=[pscustomobject]@{Name='Example_P.pak';Hash=('1'*64);Path='x';Enabled=$true;Priority=1}
  $origin=[pscustomobject]@{Schema='PMM_MOD_ORIGIN_V1';LocalSha256=$mod.Hash;Name=$mod.Name;Provider='Nexus';ModId='10';FileId='100';IdentityStatus='UserLinked';Variant='Main'}
  Assert-True ((ConvertTo-PMMModOriginV2 $origin $mod).Schema -eq 'PMM_MOD_ORIGIN_V2') 'V1 origin migration failed.'
  $files=@([pscustomobject]@{file_id=102;version='3';file_name='main.zip';category_name='MAIN';changelog_html=''})
  $single=[pscustomobject]@{files=$files;file_updates=@([pscustomobject]@{old_file_id=100;new_file_id=101},[pscustomobject]@{old_file_id=101;new_file_id=102})}
  $result=Resolve-PMMUpdateResult $mod $origin $single;Assert-True ($result.Status -eq 'UPDATE_AVAILABLE' -and $result.Candidate.FileId -eq '102') 'Unique successor chain failed.'
  $fork=[pscustomobject]@{files=$files;file_updates=@([pscustomobject]@{old_file_id=100;new_file_id=101},[pscustomobject]@{old_file_id=100;new_file_id=102})}
  Assert-True ((Resolve-PMMUpdateResult $mod $origin $fork).Status -eq 'VARIANT_AMBIGUOUS') 'Forked successor chain was not blocked.'
  $cycle=[pscustomobject]@{files=$files;file_updates=@([pscustomobject]@{old_file_id=100;new_file_id=101},[pscustomobject]@{old_file_id=101;new_file_id=100})}
  Assert-True ((Resolve-PMMUpdateResult $mod $origin $cycle).Status -eq 'VARIANT_AMBIGUOUS') 'Cyclic successor chain was not blocked.'

  Add-Type -AssemblyName System.IO.Compression;Add-Type -AssemblyName System.IO.Compression.FileSystem
  $zip=Join-Path $testRoot 'valid.zip';$archive=[IO.Compression.ZipFile]::Open($zip,[IO.Compression.ZipArchiveMode]::Create)
  try{$entry=$archive.CreateEntry('folder/Example_P.pak');$s=$entry.Open();try{$bytes=[byte[]](1,2,3,4);$s.Write($bytes,0,$bytes.Length)}finally{$s.Dispose()}}finally{$archive.Dispose()}
  $expanded=Join-Path $testRoot 'valid';$pak=Expand-PMMUpdateArchiveSafe $zip $expanded;Assert-True ($pak.Name -eq 'Example_P.pak') 'Safe ZIP extraction failed.'
  $bad=Join-Path $testRoot 'traversal.zip';$archive=[IO.Compression.ZipFile]::Open($bad,[IO.Compression.ZipArchiveMode]::Create)
  try{$entry=$archive.CreateEntry('../escape.pak');$s=$entry.Open();$s.Dispose()}finally{$archive.Dispose()}
  try{[void](Expand-PMMUpdateArchiveSafe $bad (Join-Path $testRoot 'bad'));throw 'traversal accepted'}catch{Assert-True ($_.Exception.Message -ne 'traversal accepted') 'ZIP traversal was accepted.'}
  $linkZip=Join-Path $testRoot 'link.zip';$archive=[IO.Compression.ZipFile]::Open($linkZip,[IO.Compression.ZipArchiveMode]::Create);try{$entry=$archive.CreateEntry('linked.pak');$entry.ExternalAttributes=(0xA000 -shl 16)}finally{$archive.Dispose()};try{[void](Expand-PMMUpdateArchiveSafe $linkZip (Join-Path $testRoot 'link'));throw 'link accepted'}catch{Assert-True ($_.Exception.Message -ne 'link accepted') 'ZIP symbolic link was accepted.'}

  $Script:active=@([pscustomobject]@{Name='A.pak';Hash=('a'*64);Enabled=$true;Priority=1})
  Assert-True ((Get-PMMUpdateWorkflowAction) -eq 'Check') 'Workflow did not request an initial update check.'
  Skip-PMMUpdatesForCurrentLibrary;Assert-True ((Get-PMMUpdateWorkflowAction) -eq 'None') 'Offline skip was not tied to the current fingerprint.'
  'Nexus updates regression: PASS'
}finally{if(Test-Path $testRoot){Remove-Item $testRoot -Recurse -Force}}