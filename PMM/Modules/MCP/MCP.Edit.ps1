
function Get-PMMMCPAssetCandidate([string]$CaseId,[string]$Id){
    [void](Get-PMMMCPCase $CaseId)
    if($Id -cnotmatch '^[a-f0-9]{32}$'){throw 'Invalid candidate ID.'}
    $dir=Resolve-PMMMCPPath (Get-PMMMCPRoot) ('Candidates\'+$CaseId+'\'+$Id)
    return $dir
}
function Get-PMMMCPFamilyRoot($Family){
    if($Family.PSObject.Properties.Name -contains 'SourceRoot'){return $Family.SourceRoot}
    return (Resolve-PMMMCPPath $Script:Root 'Workspace\GameReference\current\cooked')
}
function Assert-PMMMCPAssetCandidate($Manifest,[string]$CaseId,[string]$Id,[string]$Dir){
    if($Manifest.schema -ne 'PMM_STRUCTURED_ASSET_CANDIDATE_V1' -or $Manifest.caseId -cne $CaseId -or $Manifest.candidateId -cne $Id){throw 'Candidate ownership mismatch.'}
    if(@($Manifest.files).Count -eq 0 -or @($Manifest.edits).Count -eq 0){throw 'Empty candidate.'}
    foreach($file in $Manifest.files){
        $path=Resolve-PMMMCPPath (Join-Path $Dir 'cooked') $file.path
        if(-not(Test-Path $path) -or (Get-Item $path).Length -ne $file.bytes -or (Get-FileHash $path).Hash -ine $file.sha256){throw 'Candidate file integrity failed.'}
    }
    foreach($source in $Manifest.sources){
        $current=Get-PMMMCPVerifiedFamily $source.logicalPath $CaseId
        $expected=@($source.parts|ForEach-Object{$_.RelativePath+'|'+$_.Sha256}|Sort-Object)
        $actual=@($current.Parts|ForEach-Object{$_.RelativePath+'|'+$_.Sha256}|Sort-Object)
        if(($expected -join ';') -cne ($actual -join ';')){throw 'Candidate source no longer matches the current game.'}
    }
}
function Edit-PMMMCPAsset($Arguments){
    if($Arguments.path.Length -gt 1024 -or $Arguments.expected.Length -gt 64 -or $Arguments.value.Length -gt 64){throw 'Edit argument exceeds limit.'}
    if($Arguments.expected -ceq $Arguments.value){throw 'No-op edits do not create candidates.'}
    $family=Get-PMMMCPVerifiedFamily $Arguments.logicalPath $Arguments.caseId
    $id=[guid]::NewGuid().ToString('N')
    if($Arguments.PSObject.Properties.Name -contains 'candidateId'){$id=$Arguments.candidateId}
    $dir=Get-PMMMCPAssetCandidate $Arguments.caseId $id
    $manifestPath=Join-Path $dir 'candidate.json'
    if(Test-Path $manifestPath){
        $m=Read-PMMMCPJson $manifestPath
        Assert-PMMMCPAssetCandidate $m $Arguments.caseId $id $dir
        if($m.edits.Count -ge 64){throw 'Candidate edit limit reached.'}
    }else{
        $m=[pscustomobject]@{schema='PMM_STRUCTURED_ASSET_CANDIDATE_V1';caseId=$Arguments.caseId;candidateId=$id;sources=@();files=@();edits=@();status='EDITED';runtime='UNPROVEN';deployed=$false}
    }
    $cooked=Resolve-PMMMCPPath $dir 'cooked'
    $header=Resolve-PMMMCPPath $cooked $family.Asset
    if(-not(Test-Path $header)){
        $sourceRoot=Get-PMMMCPFamilyRoot $family
        foreach($p in $family.Parts){
            $from=Resolve-PMMMCPPath $sourceRoot $p.RelativePath;$to=Resolve-PMMMCPPath $cooked $p.RelativePath
            [void][IO.Directory]::CreateDirectory((Split-Path $to -Parent));Copy-Item -LiteralPath $from -Destination $to
        }
        $m.sources+=@{logicalPath=$family.Asset;parts=@($family.Parts)}
    }
    $stage=Resolve-PMMMCPPath $dir ('edits\'+[guid]::NewGuid().ToString('N'))
    [void][IO.Directory]::CreateDirectory($stage)
    $request=Join-Path $stage 'request.json'
    Write-PMMAIIOJsonAtomic $request @{path=$Arguments.path;expected=$Arguments.expected;value=$Arguments.value} 5
    $output=Join-Path $stage ([IO.Path]::GetFileName($header))
    $tool=Resolve-PMMMCPPath $Script:Root 'Engine\AssetTools\PMM.AssetTools.dll'
    Invoke-PMMBoundedProcess (Get-PMMMCPDotnet) @($tool,$header,(Join-Path $Script:Root 'Resources\Mappings\Mappings.usmap'),$request,$output) $stage 60 | Out-Null
    foreach($ext in @('.uasset','.uexp','.ubulk','.uptnl')){
        $part=[IO.Path]::ChangeExtension($output,$ext)
        if(Test-Path $part){Copy-Item -LiteralPath $part -Destination ([IO.Path]::ChangeExtension($header,$ext)) -Force}
    }
    $m.edits+=@{logicalPath=$family.Asset;path=$Arguments.path;expected=$Arguments.expected;value=$Arguments.value}
    $m.files=@(foreach($f in Get-ChildItem $cooked -File -Recurse){@{path=$f.FullName.Substring($cooked.Length+1).Replace('\','/');bytes=$f.Length;sha256=(Get-FileHash $f.FullName).Hash.ToLowerInvariant()}})
    if((($m.files|ForEach-Object{[long]$_.bytes}|Measure-Object -Sum).Sum) -gt 64MB){throw 'Candidate exceeds 64 MiB.'}
    $m.status='EDITED'
    Write-PMMAIIOJsonAtomic $manifestPath $m 20
    return @{candidateId=$id;status='EDITED';runtime='UNPROVEN';edits=$m.edits.Count;nextTool='pmm_candidate_build'}
}
function Build-PMMMCPAssetCandidate($Arguments){
    $dir=Get-PMMMCPAssetCandidate $Arguments.caseId $Arguments.candidateId
    $m=Read-PMMMCPJson (Join-Path $dir 'candidate.json')
    Assert-PMMMCPAssetCandidate $m $Arguments.caseId $Arguments.candidateId $dir
    $pak=Join-Path $dir ('PMM_'+$Arguments.candidateId.Substring(0,8)+'_P.pak')
    $temp=Join-Path $dir ('build-'+[guid]::NewGuid().ToString('N')+'.pak')
    $repak=Join-Path $Script:Root 'Engine\repak.exe'
    Invoke-PMMBoundedProcess $repak @('pack',(Join-Path $dir 'cooked'),$temp) $dir 120 | Out-Null
    $r=Invoke-PMMBoundedProcess $repak @('list',$temp) $dir 60
    $actual=@(Get-Content $r.stdout|Where-Object{$_}|Sort-Object)
    $expected=@($m.files|ForEach-Object{$_.path}|Sort-Object)
    if(($actual -join ';') -cne ($expected -join ';')){throw 'PAK entries do not match the candidate.'}
    $check=Join-Path $dir ('readback-'+[guid]::NewGuid().ToString('N'))
    [void][IO.Directory]::CreateDirectory($check)
    Invoke-PMMBoundedProcess $repak @('unpack',$temp,'--output',$check,'--quiet') $dir 120 -DataDirectory $check | Out-Null
    foreach($file in $m.files){
        $part=Resolve-PMMMCPPath $check $file.path
        if(-not(Test-Path $part) -or (Get-Item $part).Length -ne $file.bytes -or (Get-FileHash $part).Hash -ine $file.sha256){throw 'PAK readback hash mismatch.'}
    }
    Move-Item -LiteralPath $temp -Destination $pak -Force
    $m.status='CANDIDATE_BUILT'
    $m|Add-Member -NotePropertyName pakFile -NotePropertyValue ([IO.Path]::GetFileName($pak)) -Force
    $m|Add-Member -NotePropertyName pakSha256 -NotePropertyValue ((Get-FileHash $pak).Hash.ToLowerInvariant()) -Force
    Write-PMMAIIOJsonAtomic (Join-Path $dir 'candidate.json') $m 20
    return @{candidateId=$Arguments.candidateId;status=$m.status;pakFile=$m.pakFile;sha256=$m.pakSha256;runtime='UNPROVEN';deployed=$false}
}
function Get-PMMMCPAssetCandidates([string]$CaseId){
    [void](Get-PMMMCPCase $CaseId)
    $root=Resolve-PMMMCPPath (Get-PMMMCPRoot) ('Candidates\'+$CaseId)
    if(-not(Test-Path $root)){return @()}
    return @(foreach($dir in Get-ChildItem $root -Directory|Sort-Object LastWriteTime -Descending|Select-Object -First 30){
        $p=Join-Path $dir.FullName 'candidate.json';if(-not(Test-Path $p)){continue}
        $m=Read-PMMMCPJson $p
        $status=$m.status
        try{Assert-PMMMCPAssetCandidate $m $CaseId $dir.Name $dir.FullName
            if($status -eq 'CANDIDATE_BUILT' -and (Get-FileHash (Resolve-PMMMCPPath $dir.FullName $m.pakFile)).Hash -ine $m.pakSha256){$status='INTEGRITY_FAILED'}
        }catch{$status='INTEGRITY_FAILED'}
        @{candidateId=$dir.Name;status=$status;runtime='UNPROVEN';deployed=$false}
    })
}
