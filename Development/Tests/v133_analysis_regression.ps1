param([switch]$ProbeAgent)
Set-StrictMode -Version 2;$ErrorActionPreference='Stop'
$repo=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$fixture=Join-Path $repo ('Development/TestResults/Deep133-'+[guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($fixture)
foreach($part in @('Modules','Resources','CKL')){Copy-Item (Join-Path $repo ('PMM/'+$part)) (Join-Path $fixture $part) -Recurse}
$Script:Root=$fixture
. (Join-Path $fixture 'Modules/Shared/Paths.ps1');Initialize-PMMPaths $fixture|Out-Null
. (Join-Path $fixture 'Modules/Shared/Common.ps1');Initialize-PMM
$cfg=Get-PMMConfig;$cfg.GamePath='';Save-PMMConfig $cfg
. (Join-Path $fixture 'Modules/Analysis/Services.ps1')
$script:checks=0
function Assert($Value,[string]$Message){if(-not$Value){throw $Message};$script:checks++}
function Reject([scriptblock]$Code,[string]$Message){$failed=$false;try{& $Code|Out-Null}catch{$failed=$true};Assert $failed $Message}
function Resource([string]$Name,[string]$Provider,[string[]]$Definitions=@('A'),[array]$References=@()){
  [pscustomobject]@{LogicalPath=$Name;Provider=$Provider;Hash=(Get-PMMAnalysisHash @($Name,$Provider));Priority=1;ReaderStatus='Complete';Definitions=$Definitions;Rows=@();References=$References}
}
$r1=Resource 'pal/content/a.uasset' One @('A')
$r2=Resource 'pal/content/a.uasset' Two @('B')
$normal=@(Get-PMMResourceFindings @($r1) @($r1.LogicalPath) $false $true)
Assert ($normal.Count -eq 0) 'An ordinary override became a defect.'
$ambiguous=@(Get-PMMResourceFindings @($r1,$r2) @() $false $true)
Assert (@($ambiguous|Where-Object Rule -eq MOUNT_PRIORITY_UNKNOWN).Count -eq 1) 'Ambiguous mount priority was silently resolved.'
Assert (@($ambiguous|Where-Object RuntimeProven).Count -eq 0) 'Static analysis claimed runtime proof.'
$ref=[pscustomobject]@{Target='pal/content/a.uasset';Kind='Class';Member='Missing';Required=$true}
$vanilla=Resource 'pal/content/consumer.uasset' Vanilla @('Consumer') @($ref)
$broken=@(Get-PMMResourceFindings @($r1,$vanilla) @() $false $true)
Assert (@($broken|Where-Object Rule -eq REFERENCE_MEMBER_MISSING).Count -eq 1) 'Vanilla reverse dependency was missed.'
$r1.ReaderStatus='Partial'
$partial=@(Get-PMMResourceFindings @($r1,$vanilla) @() $false $true)
Assert (@($partial|Where-Object Rule -eq REFERENCE_MEMBER_MISSING).Count -eq 0) 'Opaque target became a proven missing member.'
$ref.Target='pal/content/optional.uasset';$ref.Required=$false
$optional=@(Get-PMMResourceFindings @($vanilla) @() $false $true)
Assert (@($optional|Where-Object Classification -eq StructuralIncompatibility).Count -eq 0) 'Optional reference became a definite incompatibility.'
$doc=[pscustomobject]@{Exports=@([pscustomobject]@{'$type'='UAssetAPI.ExportTypes.RawExport';ObjectName='Opaque'});Imports=@([pscustomobject]@{ClassName='Package';ObjectName='/Game/Pal/Missing'})}
$parsed=ConvertTo-PMMResourceEvidence $doc 'Pal/Content/Test.uasset' Test ('a'*64)
Assert ($parsed.ReaderStatus -eq 'Partial') 'Raw export status lost.'
Assert ($parsed.References[0].Target -eq 'pal/content/pal/missing.uasset') 'Package reference normalized incorrectly.'
$mod=[pscustomobject]@{Name='Mod.pak';Hash=('a'*64)}
$origin=[pscustomobject]@{Provider='Nexus';IdentityStatus='UserLinked';FileId='10';ModId='123';Variant='Main'}
$response=[pscustomobject]@{files=@([pscustomobject]@{file_id=12;category_name='MAIN';version='2.0';file_name='Main.zip'});file_updates=@([pscustomobject]@{old_file_id=10;new_file_id=11},[pscustomobject]@{old_file_id=11;new_file_id=12})}
$update=Resolve-PMMUpdateResult $mod $origin $response
Assert ($update.Status -eq 'UPDATE_AVAILABLE' -and $update.Candidate.FileId -eq '12') 'Nexus successor chain failed.'
Assert (-not$update.CompatibilityProven) 'Update age became compatibility proof.'
$response.file_updates+=,[pscustomobject]@{old_file_id=10;new_file_id=13}
Assert ((Resolve-PMMUpdateResult $mod $origin $response).Status -eq 'VARIANT_AMBIGUOUS') 'Ambiguous Nexus variant accepted.'
$gitOrigin=[pscustomobject]@{Provider='GitHub';IdentityStatus='UserLinked';Repository='owner/repo';ReleaseTag='v1.0';AssetName='Main.zip';Variant='Main'}
$releases=@([pscustomobject]@{tag_name='v1.0';published_at='2026-01-01';draft=$false;prerelease=$false;assets=@();body='old'},[pscustomobject]@{tag_name='v2.0';published_at='2026-02-01';draft=$false;prerelease=$false;assets=@([pscustomobject]@{id=2;name='Other.zip';browser_download_url='https://github.com/owner/repo/releases/download/v2.0/Other.zip'});body='new'})
Assert ((Resolve-PMMUpdateResult $mod $gitOrigin $releases).Status -eq 'NO_KNOWN_UPDATE') 'Different GitHub variant accepted.'
$releases[1].assets[0].name='Main.zip'
Assert ((Resolve-PMMUpdateResult $mod $gitOrigin $releases).Status -eq 'UPDATE_AVAILABLE') 'Exact GitHub variant update missed.'
$options=New-PMMDeepAnalysisOptions;$options.CheckUpdates=$false
Assert (-not$options.AutomaticSolution -and -not$options.AllowGame -and $options.MaxCandidates -eq 6) 'Unsafe option defaults.'
$report=Invoke-PMMDeepAnalysis $options
Assert ($report.Status -eq 'Complete' -and -not$report.Coverage.RuntimeTested) 'Empty library analysis failed.'
Assert (Test-Path -LiteralPath (Join-Path (Get-PMMAnalysisPath $report.Id) 'report.html')) 'HTML report missing.'
$case=New-PMMCaseFromDeepAnalysis $report.Id
$again=New-PMMCaseFromDeepAnalysis $report.Id
Assert ($case.CaseId -eq $again.CaseId) 'Duplicate case for identical findings.'
$s=New-PMMRepairSession $case.CaseId $options
Reject {Assert-PMMRepairAuthorization $s.Id $case.CaseId $s.EvidenceRevision Deploy} 'Default deploy permission granted.'
$attempt=Add-PMMRepairAttempt $s.Id Repair @{x=1} Blocked 'Reader missing'
$repeat=Add-PMMRepairAttempt $s.Id Repair @{x=1} Blocked 'Reader missing'
Assert ($attempt.Fingerprint -eq $repeat.Fingerprint -and (Get-PMMRepairSession $s.Id).Attempts.Count -eq 1) 'Equivalent repair attempts duplicated.'
$run=New-PMMTestRun $s.Id @('a'*64)
Reject {Update-PMMTestRun $run Menu old '2000-01-01'} 'An old log was accepted.'
$run=Update-PMMTestRun $run ProcessStarted pid ([DateTime]::UtcNow.ToString('o'))
Assert ($run.State -eq 'ProcessStarted' -and -not$run.FunctionsVerified) 'Process alive became game success.'
$run=Update-PMMTestRun $run Timeout timeout ([DateTime]::UtcNow.ToString('o'))
Assert ($run.State -eq 'Timeout' -and -not$run.FailureSignature) 'Timeout became crash.'
$sets=@(Get-PMMIsolationSubsets @('A','B','C') @{A=@('B')})
Assert ($sets.Count -gt 0) 'No isolation subsets.'
foreach($set in $sets){Assert (-not('A' -in $set.Mods) -or 'B' -in $set.Mods) 'Isolation broke dependency closure.';Assert ($set.PatchPolicy -eq 'RebuildForExactSubset') 'Isolation reused full-set patch.'}
Stop-PMMRepairSession $s.Id|Out-Null
Reject {Assert-PMMRepairAuthorization $s.Id $case.CaseId $s.EvidenceRevision Research} 'Cancelled session retained authorization.'
Add-PMMCaseEvidenceRevision $case.CaseId @{Kind='Changed'}|Out-Null
Reject {Assert-PMMRepairAuthorization $s.Id $case.CaseId $s.EvidenceRevision Research} 'Stale revision accepted.'
Assert (-not(Get-PMMRuntimeCapabilities).Launch) 'Unproven game isolation was enabled.'
if($ProbeAgent){$connection=Test-PMMAppServerConnection;Assert $connection.ProtocolVerified 'App Server handshake failed.';$connection|ConvertTo-Json -Compress}
Write-Output ('PASS deep133: '+$script:checks+' assertions; '+$fixture)
