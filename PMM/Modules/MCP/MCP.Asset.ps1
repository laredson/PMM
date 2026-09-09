
function Get-PMMMCPVerifiedFamily([string]$LogicalPath,[string]$CaseId) {
    $all=@();try{$all=@(Get-PMMMCPReferenceFamilies)}catch{if(-not $CaseId){throw}}
    $family=@($all | Where-Object { $_.Asset -ieq $LogicalPath })
    if($family.Count -ne 1){return (Prepare-PMMMCPArchiveFamily ([pscustomobject]@{caseId=$CaseId;logicalPath=$LogicalPath}))}
    $family=$family[0]
    if($family.Bytes -gt 64MB){throw 'Asset family exceeds 64 MiB inspection limit.'}
    $root=Resolve-PMMMCPPath $Script:Root 'Workspace\GameReference\current\cooked'
    foreach($part in $family.Parts){
        $p=Resolve-PMMMCPPath $root $part.RelativePath
        if(-not(Test-Path $p) -or (Get-Item $p).Length -ne $part.Size -or (Get-FileHash $p -Algorithm SHA256).Hash -ine $part.Sha256){throw 'Reference part missing or changed; prepare current reference again.'}
    }
    return $family
}
function Invoke-PMMMCPAssetInspect($Arguments) {
    [void](Get-PMMMCPCase $Arguments.caseId)
    $family=Get-PMMMCPVerifiedFamily $Arguments.logicalPath $Arguments.caseId
    $mode='properties';$query='';$offset=0;$limit=40
    foreach($p in $Arguments.PSObject.Properties){switch($p.Name){mode{$mode=$p.Value}query{$query=$p.Value}offset{$offset=[int]$p.Value}limit{$limit=[int]$p.Value}}}
    $reader=Resolve-PMMMCPPath $Script:Root 'Engine\AssetReader\PMM.AssetReader.dll'
    $mapping=Resolve-PMMMCPPath $Script:Root 'Resources\Mappings\Mappings.usmap'
    $mappingHash=(Get-FileHash $mapping).Hash.ToLowerInvariant()
    $readerIdentity=(@(Get-ChildItem (Split-Path $reader -Parent) -File -Filter *.dll | Sort-Object Name | ForEach-Object{$_.Name+":"+(Get-FileHash $_.FullName).Hash}) -join "|")
    $signature=($mode+'|UE5_1|'+$mappingHash+'|'+$readerIdentity+'|'+(@($family.Parts|ForEach-Object{$_.RelativePath+'|'+$_.Sha256}) -join '|'))
    $sha=[Security.Cryptography.SHA256]::Create()
    try{$key=([BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($signature)))).Replace('-','').ToLowerInvariant()}finally{$sha.Dispose()}
    $dir=Resolve-PMMMCPPath (Get-PMMMCPRoot) ('Inspection\'+$key)
    [void][IO.Directory]::CreateDirectory($dir)
    $document=Resolve-PMMMCPPath $dir 'document.json'
    $records=Resolve-PMMMCPPath $dir 'records.jsonl'
    $cached=Test-Path $records
    if(-not $cached){
        $sourceRoot=if($family.PSObject.Properties.Name -contains 'SourceRoot'){$family.SourceRoot}else{Resolve-PMMMCPPath $Script:Root 'Workspace\GameReference\current\cooked'}
        foreach($part in $family.Parts){
            $source=Resolve-PMMMCPPath $sourceRoot $part.RelativePath
            $target=Resolve-PMMMCPPath $dir ([IO.Path]::GetFileName($part.RelativePath))
            Copy-Item -LiteralPath $source -Destination $target
            if((Get-FileHash $target).Hash -ine $part.Sha256){throw 'Family changed while preparing inspection.'}
        }
        $header=Resolve-PMMMCPPath $dir ([IO.Path]::GetFileName($family.Asset))
        $verb=if($mode -eq 'datatable'){'export-datatable'}else{'export-json'}
        Invoke-PMMBoundedProcess (Get-PMMMCPDotnet) @($reader,$verb,'--asset',$header,'--output',$document,'--mappings',$mapping,'--engine','UE5_1') $dir 60 | Out-Null
        $data=Read-PMMMCPJson $document 33554432
        $writer=[IO.StreamWriter]::new($records+'.tmp',$false,[Text.UTF8Encoding]::new($false))
        $counter=@{value=0}
        function Write-InspectionLeaves($Value,[string]$Path,[string]$Context,[int]$Depth){
            if($Depth -gt 64){throw 'Asset JSON nesting exceeds inspection limit.'}
            if($Value -is [pscustomobject]){
                $names=@($Value.PSObject.Properties|ForEach-Object{$_.Name})
                if($names -contains 'Name' -and $Value.Name -is [string]){$Context=$Value.Name}
                if($names -contains 'name' -and $Value.name -is [string]){$Context=$Value.name}
                foreach($prop in $Value.PSObject.Properties){Write-InspectionLeaves $prop.Value ($Path+'/'+$prop.Name.Replace('~','~0').Replace('/','~1')) $Context ($Depth+1)}
            }elseif($Value -is [array]){
                for($i=0;$i -lt $Value.Count;$i++){Write-InspectionLeaves $Value[$i] ($Path+'/'+$i) $Context ($Depth+1)}
            }else{
                $counter.value++;if($counter.value -gt 250000){throw 'Asset has too many values for inspection.'}
                $row=@{path=$Path;name=$Context;value=$Value}|ConvertTo-Json -Compress -Depth 5
                $writer.WriteLine($row)
            }
        }
        try{Write-InspectionLeaves $data '' '' 0}finally{$writer.Dispose()}
        Move-Item -LiteralPath ($records+'.tmp') -Destination $records -Force
    }
    $page=[Collections.Generic.List[object]]::new();$total=0;$pageBytes=0
    foreach($line in [IO.File]::ReadLines($records)){
        if($query -and $line.IndexOf($query,[StringComparison]::OrdinalIgnoreCase) -lt 0){continue}
        if($total -ge $offset -and $page.Count -lt $limit -and $pageBytes -lt 24000){
            $row=$line|ConvertFrom-Json
            if($row.value -is [string] -and $row.value.Length -gt 4096){$row.value=$row.value.Substring(0,4096);$row|Add-Member -NotePropertyName truncated -NotePropertyValue $true}
            $page.Add($row);$pageBytes+=($row|ConvertTo-Json -Compress).Length
        }
        $total++
    }
    $opaque=@()
    if($mode -eq 'properties'){
        $inspection=Read-PMMMCPJson $document 33554432
        if($inspection.PSObject.Properties.Name -contains 'Exports'){
            $opaque=@($inspection.Exports|Where-Object{$_.'$type' -like '*RawExport*'}|ForEach-Object{$_.ObjectName})
        }
    }
    $coverage=@{opaqueExports=$opaque;complete=($opaque.Count -eq 0);note='Only serialized values are inspected; inherited defaults and native game code are not included.'}
    return [ordered]@{logicalPath=$family.Asset;mode=$mode;coverage=$coverage;engine='UE5_1';mappingsSha256=$mappingHash;sourceParts=@($family.Parts|ForEach-Object{@{path=$_.RelativePath;sha256=$_.Sha256}});cached=$cached;query=$query;offset=$offset;total=$total;nextOffset=$(if($offset+$page.Count -lt $total){$offset+$page.Count}else{$null});values=$page.ToArray();runtime='UNPROVEN'}
}
