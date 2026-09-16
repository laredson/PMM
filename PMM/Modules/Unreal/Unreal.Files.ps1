
function Copy-PMMUnrealTree([string]$Source,[string]$Destination) {
    $Source=Resolve-PMMMCPPath $Source;$Destination=Resolve-PMMMCPPath $Destination
    [long]$bytes=0
    foreach($f in Get-ChildItem -LiteralPath $Source -Recurse -File){
        $rel=$f.FullName.Substring($Source.Length).TrimStart('\')
        $from=Resolve-PMMMCPPath $Source $rel;$to=Resolve-PMMMCPPath $Destination $rel
        $bytes+=$f.Length;if($bytes -gt 2GB){throw 'Dependency copy exceeds 2 GiB.'}
        [void][IO.Directory]::CreateDirectory((Split-Path $to -Parent))
        Copy-Item -LiteralPath $from -Destination $to
    }
}
function Expand-PMMUnrealKit([string]$Zip,[string]$Destination) {
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $archive=[IO.Compression.ZipFile]::OpenRead($Zip)
    try{
        [long]$bytes=0;$prefix='PalworldModdingKit-'+(Get-PMMUnrealProfile).kitCommit+'/'
        foreach($entry in $archive.Entries){
            if(-not $entry.FullName.StartsWith($prefix)){throw 'Unexpected kit archive root.'}
            $relative=$entry.FullName.Substring($prefix.Length).TrimEnd('/')
            if(-not $relative){continue}
            if((($entry.ExternalAttributes -shr 16) -band 0xF000) -eq 0xA000){throw 'Kit symlinks are not allowed.'}
            $out=Resolve-PMMMCPPath $Destination $relative
            $bytes+=$entry.Length;if($bytes -gt 1GB){throw 'Kit extracted size exceeds 1 GiB.'}
            if($entry.FullName.EndsWith('/')){[void][IO.Directory]::CreateDirectory($out);continue}
            [void][IO.Directory]::CreateDirectory((Split-Path $out -Parent))
            [IO.Compression.ZipFileExtensions]::ExtractToFile($entry,$out,$false)
        }
    }finally{$archive.Dispose()}
}
function Get-PMMUnrealKitArchive([string]$Cancel = '') {
    $profile=Get-PMMUnrealProfile
    $dir=Resolve-PMMMCPPath (Get-PMMUnrealRoot) 'Downloads';[void][IO.Directory]::CreateDirectory($dir)
    $zip=Resolve-PMMMCPPath $dir ($profile.kitCommit+'.zip')
    if(-not(Test-Path $zip)){
        $uri=[uri]$profile.kitUrl
        if($uri.Scheme -ne 'https' -or $uri.Host -ne 'codeload.github.com' -or $uri.AbsolutePath -ne ('/localcc/PalworldModdingKit/zip/'+$profile.kitCommit)){throw 'Unapproved kit download URL.'}
        $client=[Net.WebClient]::new()
        try{
            $task=$client.DownloadFileTaskAsync($uri,$zip+'.download')
            $watch=[Diagnostics.Stopwatch]::StartNew()
            while(-not $task.Wait(250)){
                if(($Cancel -and (Test-Path $Cancel)) -or -not(Get-PMMMCPEnabled) -or -not(Get-PMMUnrealSettings).enabled){$client.CancelAsync();throw 'Unreal preparation cancelled or disabled.'}
                if($watch.Elapsed.TotalSeconds -gt 180 -or ((Test-Path ($zip+'.download')) -and (Get-Item ($zip+'.download')).Length -gt 64MB)){ $client.CancelAsync();throw 'Kit download limit exceeded.'}
            }
            if((Get-FileHash ($zip+'.download')).Hash -ine $profile.kitSha256){throw 'Kit checksum does not match pinned revision.'}
            Move-Item -LiteralPath ($zip+'.download') -Destination $zip
        }finally{$client.Dispose()}
    }
    if((Get-FileHash $zip).Hash -ine $profile.kitSha256){throw 'Cached kit checksum mismatch.'}
    return $zip
}
function Install-PMMUnrealWwise($Environment,[string]$Project,[string]$Job,[string]$Cancel) {
    $source=Resolve-PMMMCPPath $Environment.wwiseIntegration
    if(Test-Path $source -PathType Leaf){
        if([IO.Path]::GetFileName($source) -ne 'Unreal.5.0.tar.xz'){throw 'Select the official Unreal.5.0.tar.xz integration archive.'}
        $tar=Join-Path $env:SystemRoot 'System32\tar.exe';$temp=Resolve-PMMMCPPath $Job 'Wwise'
        [void][IO.Directory]::CreateDirectory($temp)
        # Windows bsdtar can lack an XZ filter. UE already ships Python with lzma.
        $python=Resolve-PMMMCPPath $Environment.engineRoot 'Engine\Binaries\ThirdParty\Python3\Win64\python.exe'
        if(-not(Test-Path -LiteralPath $python)){throw 'Unreal embedded Python is missing.'}
        $decoder=Resolve-PMMMCPPath $Script:Root 'Modules\Unreal\decompress_wwise.py'
        $decoded=Resolve-PMMMCPPath $Job ('wwise-'+[guid]::NewGuid().ToString('N')+'.tar')
        Invoke-PMMBoundedProcess $python @('-I',$decoder,$source,$decoded) $Job 120 $Cancel | Out-Null
        $source=$decoded
        $list=Invoke-PMMBoundedProcess $tar @('-tf',$source) $Job 60 $Cancel
        foreach($line in Get-Content $list.stdout){
            $relative=$line.TrimEnd('/');while($relative.StartsWith('./')){$relative=$relative.Substring(2)}
            if($relative){[void](Resolve-PMMMCPPath $temp $relative)}
        }
        $details=Invoke-PMMBoundedProcess $tar @('-tvf',$source) $Job 60 $Cancel
        foreach($line in Get-Content $details.stdout){if($line -and $line[0] -notin @('-','d')){throw 'Links or special entries in Wwise archive are not allowed.'}}
        Invoke-PMMBoundedProcess $tar @('-xf',$source,'-C',$temp) $Job 180 $Cancel | Out-Null
        $plugins=@(Get-ChildItem $temp -Recurse -Filter Wwise.uplugin -File)
        if($plugins.Count -ne 1){throw 'Offline integration must contain one Wwise plugin.'}
        $source=$plugins[0].DirectoryName
    }
    $plugin=Read-PMMMCPJson (Join-Path $source 'Wwise.uplugin')
    if($plugin.VersionName -notmatch '^2021\.1\.11'){throw 'Wwise integration version must be 2021.1.11.'}
    $dest=Resolve-PMMMCPPath $Project 'Plugins\Wwise'
    Copy-PMMUnrealTree $source $dest
    $plugin.EngineVersion='5.1'
    [IO.File]::WriteAllText((Join-Path $dest 'Wwise.uplugin'),($plugin|ConvertTo-Json -Depth 30),[Text.UTF8Encoding]::new($false))
    foreach($part in @('include','Win32_vc170','x64_vc170')){
        Copy-PMMUnrealTree (Resolve-PMMMCPPath $Environment.wwiseSdk $part) (Join-Path $dest ('ThirdParty\'+$part))
        if($part -ne 'include'){Copy-PMMUnrealTree (Resolve-PMMMCPPath $Environment.wwiseSdk $part) (Join-Path $dest ('ThirdParty\'+$part.Replace('vc170','vc160')))}
    }
}
function Write-PMMUnrealJson([string]$Path,$Value) {
    [void][IO.Directory]::CreateDirectory((Split-Path $Path -Parent))
    [IO.File]::WriteAllText($Path,($Value|ConvertTo-Json -Depth 40),[Text.UTF8Encoding]::new($false))
}
