param([string]$Repository=([IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))),[string]$PackageName='')
Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem,System.IO.Compression
$app=Join-Path $Repository 'PMM'
$output=Join-Path $Repository 'Development\Releases'
[void][IO.Directory]::CreateDirectory($output)
$stage=Join-Path $Repository ('Development\TestResults\BasePackage-'+[guid]::NewGuid().ToString('N')+'\PMM')
[void][IO.Directory]::CreateDirectory($stage)
$expected=@{}
foreach($line in Get-Content (Join-Path $app 'Resources\Metadata\SHA256SUMS.txt')){
    if($line -notmatch '^([a-f0-9]{64})  (.+)$'){throw 'Invalid checksum inventory.'}
    $hash=$Matches[1];$relative=$Matches[2]
    if($relative -notmatch '^(PMM\.exe|(?:Engine|Modules|Resources|CKL|Documentation)/.+)$' -or $relative -match '(^|/)(Workspace|\.git|\.codex|\.\.)(/|$)' -or $relative -match '[:\\]' -or [IO.Path]::GetExtension($relative) -in @('.pak','.ucas','.utoc','.uasset','.uexp','.ubulk')){throw ('Unexpected public package member: '+$relative)}
    $source=Join-Path $app $relative;$target=Join-Path $stage $relative
    if((Get-FileHash $source).Hash -ine $hash){throw ('Source checksum mismatch: '+$relative)}
    [void][IO.Directory]::CreateDirectory((Split-Path $target -Parent))
    Copy-Item -LiteralPath $source -Destination $target
    if((Get-FileHash $target).Hash -ine $hash){throw ('Staged checksum mismatch: '+$relative)}
    $expected[$relative]=$hash
}
$inventory='Resources/Metadata/SHA256SUMS.txt'
Copy-Item (Join-Path $app $inventory) (Join-Path $stage $inventory)
$expected[$inventory]=(Get-FileHash (Join-Path $stage $inventory)).Hash.ToLowerInvariant()
if(-not $PackageName){$PackageName='PMM-1.3.1-MCP-0.5.0-BASE-'+[DateTime]::Now.ToString('yyyyMMdd-HHmmss')+'.zip'}
if($PackageName -notmatch '^[A-Za-z0-9._-]+\.zip$'){throw 'Invalid package filename.'}
$zip=Join-Path $output $PackageName
if(Test-Path -LiteralPath $zip){throw 'Output ZIP already exists.'}
$archive=[IO.Compression.ZipFile]::Open($zip,[IO.Compression.ZipArchiveMode]::Create)
try{
    foreach($relative in @($expected.Keys|Sort-Object)){
        $entry=$archive.CreateEntry(('PMM/'+$relative),[IO.Compression.CompressionLevel]::Optimal)
        $inputStream=[IO.File]::OpenRead((Join-Path $stage $relative));$outputStream=$entry.Open()
        try{$inputStream.CopyTo($outputStream)}finally{$outputStream.Dispose();$inputStream.Dispose()}
    }
}finally{$archive.Dispose()}
$archive=[IO.Compression.ZipFile]::OpenRead($zip)
try{
    $count=0
    foreach($entry in $archive.Entries){
        if($entry.FullName.EndsWith('/')){continue}
        if(-not $entry.FullName.StartsWith('PMM/')){throw 'Unexpected ZIP root.'}
        $relative=$entry.FullName.Substring(4)
        if(-not $expected.ContainsKey($relative)){throw ('Unexpected ZIP entry: '+$entry.FullName)}
        $stream=$entry.Open();$sha=[Security.Cryptography.SHA256]::Create()
        try{$hash=([BitConverter]::ToString($sha.ComputeHash($stream))).Replace('-','').ToLowerInvariant()}finally{$sha.Dispose();$stream.Dispose()}
        if($hash -cne $expected[$relative]){throw 'Compressed member checksum mismatch.'}
        $count++
    }
    if($count -ne $expected.Count){throw 'Incomplete ZIP.'}
}finally{$archive.Dispose()}
$native=(& (Join-Path $stage 'Engine\PMMRuntime.exe') dependencies status | Out-String)|ConvertFrom-Json
if($LASTEXITCODE -ne 0 -or -not $native.ready){throw 'Packaged runtime dependency verification failed.'}
$hash=(Get-FileHash $zip).Hash.ToLowerInvariant()
[IO.File]::WriteAllText($zip+'.sha256',($hash+'  '+[IO.Path]::GetFileName($zip)+[char]10),[Text.UTF8Encoding]::new($false))
$result=@{zip=$zip;sha256=$hash;bytes=(Get-Item $zip).Length;files=$count;staging=$stage;nativeDependenciesReady=$native.ready;workspaceIncluded=$false;unrealEnabledByDefault=$false;unrealRealValidation='NOT_VERIFIED'}
[IO.File]::WriteAllText($zip+'.validation.json',($result|ConvertTo-Json -Depth 6),[Text.UTF8Encoding]::new($false))
$result|ConvertTo-Json -Depth 6
