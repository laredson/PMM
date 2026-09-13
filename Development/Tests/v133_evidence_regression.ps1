Set-StrictMode -Version 2;$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'v133_analysis_regression.ps1')
. (Join-Path $Script:Root 'Modules/Analysis/MCP.Analysis.ps1')
$before=$script:checks
Assert ((Get-PMMAnalysisHash @{a=1;b=2}) -eq (Get-PMMAnalysisHash ([ordered]@{b=2;a=1}))) 'Equivalent object order changed evidence identity.'
$document=[pscustomobject]@{Imports=@(
  [pscustomobject]@{ObjectName='/Game/Pal/Test';ClassName='Package';OuterIndex=0},
  [pscustomobject]@{ObjectName='Test_C';ClassName='BlueprintGeneratedClass';OuterIndex=-1}
);Exports=@([pscustomobject]@{'$type'='NormalExport';ObjectName='Consumer';Data=@()})}
$resource=ConvertTo-PMMResourceEvidence $document 'Pal/Content/Consumer.uasset' Mod ('a'*64)
Assert (@($resource.References|Where-Object{$_.Member -eq 'Test_C' -and $_.Target -eq 'pal/content/pal/test.uasset'}).Count -eq 1) 'Serialized import outer-chain was not resolved.'
$partial=$document|ConvertTo-Json -Depth 12|ConvertFrom-Json;$partial.Exports[0].'$type'='RawExport'
Assert ((ConvertTo-PMMResourceEvidence $partial 'Pal/Content/Consumer.uasset' Mod ('a'*64)).ReaderStatus -eq 'Partial') 'Raw cooked data was treated as fully interpreted.'
Add-Type -AssemblyName System.IO.Compression.FileSystem,System.IO.Compression
$archive=Join-Path $fixture 'origin.zip'
$zip=[IO.Compression.ZipFile]::Open($archive,[IO.Compression.ZipArchiveMode]::Create)
$entry=$zip.CreateEntry('subfolder/source.pak')
$bytes=[Text.Encoding]::UTF8.GetBytes('fixture pak bytes')
$stream=$entry.Open();try{$stream.Write($bytes,0,$bytes.Length)}finally{$stream.Dispose();$zip.Dispose()}
$pak=Join-Path $fixture 'source.pak';[IO.File]::WriteAllBytes($pak,$bytes);$hash=Get-Sha256 $pak
$proof=Get-PMMArchiveContentProof $archive $hash
Assert ($proof -and $proof.Content.Sha256 -ceq $hash) 'Archive content identity was not proven.'
Assert (-not(Get-PMMArchiveContentProof $archive ('0'*64))) 'Filename-only origin was accepted.'
$report=Invoke-PMMDeepAnalysis $options
$case=New-PMMCaseFromDeepAnalysis $report.Id @($report.Findings[0].Id)
$s=New-PMMRepairSession $case.CaseId $options
Assert ((Assert-PMMReportCase $case.CaseId $report.Id).Id -eq $report.Id) 'Current report rejected.'
$path=Join-Path (Get-PMMAnalysisPath $report.Id) 'report.json'
$original=[IO.File]::ReadAllBytes($path);[IO.File]::AppendAllText($path,' ')
Reject {Assert-PMMReportCase $case.CaseId $report.Id} 'Tampered report was accepted.'
Reject {Assert-PMMRepairAuthorization $s.Id $case.CaseId $s.EvidenceRevision Research} 'Tampered evidence retained mutation permission.'
[IO.File]::WriteAllBytes($path,$original)
$s.Options.MaxCandidates=1;$s.Authorization.Build=$true;Save-PMMRepairSession $s
$one=Register-PMMRepairCandidate $s.Id ('a'*64) first
$again=Register-PMMRepairCandidate $s.Id ('a'*64) duplicate
Assert ($one.CandidateId -eq $again.CandidateId) 'Equivalent candidate was repeated.'
Reject {Register-PMMRepairCandidate $s.Id ('b'*64) second} 'Candidate limit was exceeded.'
$stale=Get-PMMRepairSession $s.Id
Stop-PMMRepairSession $s.Id|Out-Null
$stale.Revoked=$false;$stale.Status='Researching';Save-PMMRepairSession $stale
Assert (Get-PMMRepairSession $s.Id).Revoked 'A stale worker undid cancellation.'
$bad=New-PMMDeepAnalysisOptions;$bad.AllowGame=$true
Reject {New-PMMRepairSession $case.CaseId $bad} 'An unverified runtime adapter could be enabled through a forged request.'
Write-Output ('PASS evidence133: '+($script:checks-$before)+' additional evidence/origin/session checks.')
