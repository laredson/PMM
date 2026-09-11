
function Get-PMMMCPArchiveIndex {
    $pak=Get-PMMGameReferencePak
    if(-not $pak){throw 'Configure the Palworld installation in PMM first.'}
    $pak=Resolve-PMMMCPPath $pak
    $info=Get-Item $pak
    $identity=$pak+'|'+$info.Length+'|'+$info.LastWriteTimeUtc.Ticks
    $sha=[Security.Cryptography.SHA256]::Create()
    try{$key=([BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($identity)))).Replace('-','').ToLowerInvariant()}finally{$sha.Dispose()}
    $dir=Resolve-PMMMCPPath (Get-PMMMCPRoot) ('ArchiveIndex\'+$key)
    [void][IO.Directory]::CreateDirectory($dir)
    $index=Join-Path $dir 'entries.txt'
    if(-not(Test-Path $index)){
        $r=Invoke-PMMBoundedProcess -Executable (Join-Path $Script:Root 'Engine\repak.exe') -Arguments @('list',$pak) -Directory $dir -TimeoutSeconds 60 -OutputLimitBytes 67108864
        $lines=@(Get-Content $r.stdout | Where-Object{$_ -match '^Pal/Content/.+\.(uasset|uexp|ubulk|uptnl)$'} | Sort-Object -Unique)
        if($lines.Count -gt 500000){throw 'Archive index entry limit exceeded.'}
        foreach($line in $lines){if($line -match '(^|/)[.][.]?(/|$)|[:\\]|[\x00-\x1f]'){throw 'Unsafe archive index entry.'}}
        [IO.File]::WriteAllLines($index,$lines,[Text.UTF8Encoding]::new($false))
    }
    if((Get-Item $index).Length -gt 64MB){throw 'Archive index exceeds limit.'}
    return @{key=$key;pak=$pak;entries=@([IO.File]::ReadAllLines($index));directory=$dir;identity=$identity}
}
function Search-PMMMCPArchive($Arguments){
    $index=Get-PMMMCPArchiveIndex
    $offset=0;$limit=40
    if($Arguments.PSObject.Properties.Name -contains 'offset'){$offset=$Arguments.offset}
    if($Arguments.PSObject.Properties.Name -contains 'limit'){$limit=$Arguments.limit}
    $rows=@($index.entries|Where-Object{$_ -match '\.uasset$' -and $_.IndexOf($Arguments.query,[StringComparison]::OrdinalIgnoreCase) -ge 0})
    return @{source='configured-game-pak-index';identity=$index.key;total=$rows.Count;offset=$offset;nextOffset=$(if($offset+$limit -lt $rows.Count){$offset+$limit}else{$null});assets=@($rows|Select-Object -Skip $offset -First $limit);nextTool='pmm_asset_prepare'}
}
function Prepare-PMMMCPArchiveFamily($Arguments){
    [void](Get-PMMMCPCase $Arguments.caseId)
    $index=Get-PMMMCPArchiveIndex
    $logical=$Arguments.logicalPath
    if($logical -cnotmatch '^Pal/Content/.+\.uasset$' -or $index.entries -cnotcontains $logical){throw 'Exact .uasset path not present in configured game archive.'}
    $rel=$logical.Substring(0,$logical.Length-7)
    $paths=@($index.entries|Where-Object{$_ -in @(($rel+'.uasset'),($rel+'.uexp'),($rel+'.ubulk'),($rel+'.uptnl'))})
    if($paths.Count -lt 1 -or $paths.Count -gt 4){throw 'Invalid family selection; extraction refused.'}
    $sha=[Security.Cryptography.SHA256]::Create();try{$assetKey=([BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($logical)))).Replace('-','').ToLowerInvariant()}finally{$sha.Dispose()}
    $dir=Resolve-PMMMCPPath (Get-PMMMCPRoot) ('ArchiveFamilies\'+$index.key+'\'+$assetKey)
    [void][IO.Directory]::CreateDirectory($dir)
    $header=Resolve-PMMMCPPath $dir $logical
    $proof=$header+'.proof.json'
    if(Test-Path $proof){
        $family=Read-PMMMCPJson $proof
        if($family.Asset -cne $logical -or $family.ArchiveKey -cne $index.key -or @($family.Parts).Count -ne $paths.Count){throw 'Prepared family identity mismatch.'}
        if((@($family.Parts|ForEach-Object{$_.RelativePath}|Sort-Object) -join ';') -cne (@($paths|Sort-Object) -join ';')){throw 'Prepared family membership mismatch.'}
        $family.SourceRoot=$dir
        foreach($p in $family.Parts){$f=Resolve-PMMMCPPath $dir $p.RelativePath;if(-not(Test-Path $f) -or (Get-FileHash $f).Hash -ine $p.Sha256){throw 'Prepared archive family changed; remove the corrupt cache through PMM before retrying.'}}
        return $family
    }
    $args=@('unpack',$index.pak,'--output',$dir,'--force','--quiet')
    foreach($p in $paths){$args+=@('--include',$p)}
    Invoke-PMMBoundedProcess -Executable (Join-Path $Script:Root 'Engine\repak.exe') -Arguments $args -Directory $index.directory -TimeoutSeconds 60 -DataDirectory $dir | Out-Null
    $parts=@();[long]$bytes=0
    foreach($p in $paths){
        $f=Resolve-PMMMCPPath $dir $p;$size=(Get-Item $f).Length;$bytes+=$size
        if($bytes -gt 64MB){throw 'Family exceeds 64 MiB inspection limit.'}
        $parts+=@{RelativePath=$p;Size=$size;Sha256=(Get-FileHash $f).Hash.ToLowerInvariant()}
    }
    $now=Get-Item $index.pak
    if(($index.pak+'|'+$now.Length+'|'+$now.LastWriteTimeUtc.Ticks) -cne $index.identity){throw 'Game archive changed during extraction.'}
    $family=@{Asset=$logical;Parts=$parts;Bytes=$bytes;ArchiveKey=$index.key;SourceRoot=$dir}
    Write-PMMAIIOJsonAtomic $proof $family 12
    return [pscustomobject]$family
}
