Set-StrictMode -Version 2;$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'v133_workers_regression.ps1')
$before=$script:checks
# Exercise the real candidate publishing/packing contract with a bounded synthetic merger.
# The real DataTable semantic merger has its separate cooked-content regression.
$script:fixturePlan=[pscustomobject]@{Assets=@([pscustomobject]@{Mode='BinaryAuto';Asset='Pal/Content/Fixture.bin';AssetKey='fixture';Providers=@('Fixture.pak')});Rows=@()}
function Assert-PMMEngineReady{}
function Assert-PMMPlanMatchesLibrary($Mods){return $script:fixturePlan}
function Build-PMMAutoAsset($Asset,$Mods,$Transaction,$Output){[IO.File]::WriteAllText((Join-Path $Output 'Fixture.bin'),'candidate fixture')}
function Get-PMMBuildAssetEvidence($Plan,$Directory){return @()}
function Get-PMMDeploymentSuppressions($Mods,$Plan){return @()}
function Get-PMMEffectivePatchOrderSignature($Assets,$Mods,$Rows){return 'fixture-order'}
function Get-PMMMappingsPath {return (Join-Path $Script:Root 'Resources/Metadata/VERSION.txt')}
$selected=Get-PMMSelectedPatchName
$currentRoot=Join-PMMPath 'Builds' 'Current';[void][IO.Directory]::CreateDirectory($currentRoot)
$sentinel=Join-Path $currentRoot 'zzzzzzzzzz_PMM_Merge_existing_P.pak'
Copy-Item -LiteralPath $originalPak -Destination $sentinel
$sentinelHash=Get-Sha256 $sentinel
$target=Join-Path (Get-PMMRepairSessionRoot $s.Id) 'merge-candidate'
$message=Build-PMMMerge -CandidateDirectory $target
$outputs=@(Get-ChildItem -LiteralPath $target -File -Filter *.pak)
Assert ($outputs.Count -eq 1 -and (Test-Pak $outputs[0].FullName)) 'Candidate build did not produce a valid container.'
Assert ((Get-PMMSelectedPatchName) -ceq $selected -and (Get-Sha256 $sentinel) -ceq $sentinelHash) 'Candidate build changed selection or moved the current patch.'
Reject {Build-PMMMerge -CandidateDirectory $target} 'Candidate replay overwrote the previous output.'
Reject {Build-PMMMerge -CandidateDirectory (Join-Path $fixture 'outside-workspace')} 'Candidate output escaped the workspace.'
$patch=[pscustomobject]@{Name='existing';PatchedMods=@();SourceSignature='fixture';Hash=('a'*64)}
$script:selectionCalls=0
function Set-PMMSelectedPatchName([string]$Name){$script:selectionCalls++}
function Get-PMMPatchContentSignature($Patch){return 'fixture'}
function Get-PMMPatchDeploymentSuppressions($Mods,$Patch,$Plan){return @()}
$plan=[pscustomobject]@{DeploymentSuppressions=@()}
Set-PMMPlanEquivalentPatch $plan $patch @() -NoPatchSelection|Out-Null
Assert ($script:selectionCalls -eq 0) 'Candidate analysis selected a reusable patch.'
Set-PMMPlanEquivalentPatch $plan $patch @()|Out-Null
Assert ($script:selectionCalls -eq 1) 'Normal merge selection behavior regressed.'
Write-Output ('PASS candidate133: '+($script:checks-$before)+' candidate publication checks.')
