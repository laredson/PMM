
function New-PMMUnrealCandidate([string]$CaseId,[string]$JobId,[string]$Project,$Environment,[string]$Cancel) {
    $registry=Read-PMMMCPJson (Join-Path $Project 'Saved\PMM\assets.json')
    $names=@($registry.PSObject.Properties|ForEach-Object{$_.Name}|Where-Object{$_ -ne 'PMMProbe'})
    if(-not $names.Count){throw 'Create at least one user asset before cooking a candidate.'}
    $candidate=Resolve-PMMMCPPath $Script:Root ('Workspace\AIIO\Cases\'+$CaseId+'\generated\'+$JobId)
    $tree=Resolve-PMMMCPPath $candidate 'cooked'
    [void][IO.Directory]::CreateDirectory($tree)
    $cooked=Resolve-PMMMCPPath $Project 'Saved\Cooked\Windows\Pal\Content\PMM'
    if(-not(Test-Path $cooked)){throw 'No legacy Windows cooked assets at expected path.'}
    $records=[Collections.Generic.List[object]]::new();$sources=[Collections.Generic.List[object]]::new();[long]$bytes=0
    foreach($name in $names){
        if($name -cnotmatch '^[A-Za-z][A-Za-z0-9_]{0,47}$'){throw 'Invalid registered asset.'}
        $data=$registry.$name
        if($data.sourceName -cnotmatch '^[A-Za-z][A-Za-z0-9_]{0,47}$' -or $data.sourceSha256 -cnotmatch '^[a-f0-9]{64}$'){throw 'Invalid authored source identity.'}
        $png=Resolve-PMMMCPPath $Project ('SourceData\'+$data.sourceName+'.png')
        if((Get-FileHash $png).Hash -ine $data.sourceSha256){throw 'Authored source PNG changed.'}
        $sourceRel='sources/'+$data.sourceSha256+'.png';$sourceCopy=Resolve-PMMMCPPath $candidate $sourceRel
        [void][IO.Directory]::CreateDirectory((Split-Path $sourceCopy -Parent))
        Copy-Item -LiteralPath $png -Destination $sourceCopy -Force
        $sources.Add(@{asset=$name;sourceSha256=$data.sourceSha256;sourcePath=$sourceRel;recipe=$data.recipe;properties=$data.properties;editorAssetSha256=$data.assetSha256})
        if(-not(Test-Path (Join-Path $cooked ($name+'.uasset')))){throw ('Cooked asset missing: '+$name)}
        foreach($ext in @('.uasset','.uexp','.ubulk','.uptnl')){
            $from=Resolve-PMMMCPPath $cooked ($name+$ext)
            if(-not(Test-Path $from)){continue}
            $bytes+=(Get-Item $from).Length;if($bytes -gt 128MB){throw 'Candidate exceeds 128 MiB.'}
            $rel='Pal/Content/PMM/'+$name+$ext;$to=Resolve-PMMMCPPath $tree $rel
            [void][IO.Directory]::CreateDirectory((Split-Path $to -Parent))
            Copy-Item -LiteralPath $from -Destination $to
            $records.Add(@{path=$rel;sha256=(Get-FileHash $to).Hash.ToLowerInvariant();bytes=(Get-Item $to).Length})
        }
        $probe=Resolve-PMMMCPPath $tree ('Pal/Content/PMM/'+$name+'.uasset')
        Invoke-PMMBoundedProcess (Get-PMMMCPDotnet) @((Join-Path $Script:Root 'Engine\AssetReader\PMM.AssetReader.dll'),'probe','--asset',$probe,'--mappings',(Get-PMMMappingsPath),'--engine','UE5_1') $candidate 60 $Cancel | Out-Null
    }
    $pak=Resolve-PMMMCPPath $candidate ('PMM_'+$JobId.Substring(0,8)+'_P.pak')
    $repak=Resolve-PMMMCPPath $Script:Root 'Engine\repak.exe'
    Invoke-PMMBoundedProcess $repak @('pack',$tree,$pak) $candidate 120 $Cancel | Out-Null
    $listing=Invoke-PMMBoundedProcess $repak @('list',$pak) $candidate 60 $Cancel
    $actual=@(Get-Content $listing.stdout|Where-Object{$_}|Sort-Object)
    $expected=@($records|ForEach-Object{$_.path}|Sort-Object)
    if(($actual -join '|') -cne ($expected -join '|')){throw 'PAK entry validation failed.'}
    $manifest=@{schema='PMM_GENERATED_MOD_CANDIDATE_V1';caseId=$CaseId;candidateId=$JobId;origin='unreal-authored';recipeScriptSha256=(Get-FileHash (Join-Path $Script:Root 'Modules\Unreal\editor_bridge.py')).Hash.ToLowerInvariant();sourceFamilies=@();generatedSources=$sources.ToArray();files=$records.ToArray();engineVersion=$Environment.engineVersion;kitCommit=$Environment.kitCommit;pakFile=[IO.Path]::GetFileName($pak);pakSha256=(Get-FileHash $pak).Hash.ToLowerInvariant();status='VALIDATED_CANDIDATE';runtime='UNPROVEN';deployed=$false;createdUtc=[DateTime]::UtcNow.ToString('o')}
    Write-PMMUnrealJson (Join-Path $candidate 'candidate.json') $manifest
    return @{candidateId=$JobId;status='VALIDATED_CANDIDATE';runtime='UNPROVEN';pakSha256=$manifest.pakSha256;files=$records.Count}
}
function Get-PMMUnrealCandidates([string]$CaseId) {
    [void](Get-PMMMCPCase $CaseId)
    $base=Resolve-PMMMCPPath $Script:Root ('Workspace\AIIO\Cases\'+$CaseId+'\generated')
    if(-not(Test-Path $base)){return @()}
    $rows=@()
    foreach($d in @(Get-ChildItem $base -Directory | Sort-Object LastWriteTime -Descending | Select-Object -First 20)){
        $p=Resolve-PMMMCPPath $base ($d.Name+'\candidate.json')
        if(Test-Path $p){
            $m=Read-PMMMCPJson $p
            if($m.schema -ne 'PMM_GENERATED_MOD_CANDIDATE_V1' -or $m.caseId -cne $CaseId -or $m.candidateId -cne $d.Name){throw 'Invalid generated candidate identity.'}
            $pak=Resolve-PMMMCPPath $d.FullName $m.pakFile
            $integrity=(Test-Path $pak) -and (Get-FileHash $pak).Hash -ieq $m.pakSha256
            if($integrity){
                foreach($f in @($m.files)){
                    $file=Resolve-PMMMCPPath (Join-Path $d.FullName 'cooked') $f.path
                    if(-not(Test-Path $file) -or (Get-Item $file).Length -ne $f.bytes -or (Get-FileHash $file).Hash -ine $f.sha256){$integrity=$false;break}
                }
                foreach($s in @($m.generatedSources)){
                    $png=Resolve-PMMMCPPath $d.FullName $s.sourcePath
                    if(-not(Test-Path $png) -or (Get-FileHash $png).Hash -ine $s.sourceSha256){$integrity=$false;break}
                }
            }
            $rows+=@{candidateId=$m.candidateId;status=$(if($integrity){$m.status}else{'INTEGRITY_FAILED'});pakFile=$m.pakFile;runtime='UNPROVEN'}
        }
    }
    return @($rows)
}
