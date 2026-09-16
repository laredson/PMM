# Restore downloaded packages only. Never executes installers or overwrites differences.
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$Archive,
    [Parameter(Mandatory=$true)][ValidatePattern('^[a-fA-F0-9]{64}$')][string]$ExpectedSha256,
    [string]$PmmRoot=([IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))),
    [switch]$VerifyOnly
)
Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.IO.Compression,System.IO.Compression.FileSystem
function Get-StreamHash($Stream){
    $sha=[Security.Cryptography.SHA256]::Create()
    try{return ([BitConverter]::ToString($sha.ComputeHash($Stream))).Replace('-','').ToLowerInvariant()}finally{$sha.Dispose()}
}
function Get-LocalHash([string]$Path){
    $s=[IO.File]::OpenRead($Path);try{return Get-StreamHash $s}finally{$s.Dispose()}
}
function Assert-NoLink([string]$Path){
    $p=[IO.Path]::GetFullPath($Path)
    while($p){
        if(Test-Path -LiteralPath $p){
            if(((Get-Item -LiteralPath $p -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0){throw ('Links are not allowed: '+$p)}
        }
        $parent=[IO.Directory]::GetParent($p);if($null -eq $parent){break};$p=$parent.FullName
    }
}
function Resolve-PackagePath([string]$Root,[string]$Relative){
    if($Relative -notmatch '^Wwise-(2021\.1\.11|Unreal-2021\.1\.11)/' -or $Relative -match '[\\:\x00-\x1f]' -or $Relative.Length -gt 240){throw 'Invalid package path'}
    foreach($part in $Relative.Split('/')){
        if(-not $part -or $part -in @('.','..') -or $part -match '[. ]$' -or $part -match '^(?i:CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])(?:\.|$)'){throw 'Unsafe package path'}
    }
    $full=[IO.Path]::GetFullPath((Join-Path $Root $Relative))
    if(-not $full.StartsWith($Root.TrimEnd('\','/')+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)){throw 'Path escapes destination'}
    Assert-NoLink $full
    return $full
}
$Archive=[IO.Path]::GetFullPath($Archive);Assert-NoLink $Archive
# Hold a read-only handle so the checked ZIP cannot be replaced during verification/copy.
$inputFile=[IO.File]::Open($Archive,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::Read)
$zip=$null
try{
    if((Get-StreamHash $inputFile) -ine $ExpectedSha256){throw 'Archive SHA-256 mismatch'}
    $inputFile.Position=0
    $zip=[IO.Compression.ZipArchive]::new($inputFile,[IO.Compression.ZipArchiveMode]::Read,$true)
    if($zip.Entries.Count -gt 201){throw 'Too many entries'}
    $index=$zip.GetEntry('OFFLINE_INVENTORY.json')
    if(-not $index -or $index.Length -gt 1048576){throw 'Missing or oversized inventory'}
    $reader=[IO.StreamReader]::new($index.Open())
    try{$inventory=$reader.ReadToEnd()|ConvertFrom-Json}finally{$reader.Dispose()}
    if($inventory.schema -ne 'PMM_OFFLINE_BACKUP_V1'){throw 'Unsupported backup schema'}
    $expected=@{}
    $root=[IO.Path]::GetFullPath((Join-Path $PmmRoot 'Workspace\Dependencies\Offline'))
    Assert-NoLink $root
    [long]$total=0
    foreach($f in $inventory.files){
        $relative=[string]$f.path
        $null=Resolve-PackagePath $root $relative
        if($expected.ContainsKey($relative) -or [string]$f.sha256 -notmatch '^[a-f0-9]{64}$' -or [long]$f.bytes -lt 0){throw 'Invalid inventory entry'}
        $total+=[long]$f.bytes;if($total -gt 2147483648){throw 'Expanded backup exceeds 2 GiB'}
        $expected[$relative]=$f
    }
    if(-not $expected.Count -or $zip.Entries.Count -ne $expected.Count+1){throw 'Archive/inventory count mismatch'}
    $seen=@{}
    # Validate the complete payload and existing destination before writing anything.
    foreach($entry in $zip.Entries){
        $name=$entry.FullName
        if($seen.ContainsKey($name)){throw 'Duplicate ZIP entry'};$seen[$name]=$true
        if($name -eq 'OFFLINE_INVENTORY.json'){continue}
        if(-not $expected.ContainsKey($name)){throw 'Unexpected ZIP entry'}
        if((($entry.ExternalAttributes -shr 16) -band 0xF000) -eq 0xA000){throw 'Symbolic links are not allowed'}
        $f=$expected[$name]
        if($entry.Length -ne [long]$f.bytes){throw 'File size mismatch'}
        $s=$entry.Open();try{$hash=Get-StreamHash $s}finally{$s.Dispose()}
        if($hash -cne [string]$f.sha256){throw ('File SHA-256 mismatch: '+$name)}
        $dest=Resolve-PackagePath $root $name
        if(Test-Path -LiteralPath $dest){
            if(-not(Test-Path -LiteralPath $dest -PathType Leaf) -or (Get-LocalHash $dest) -cne $hash){throw ('Existing file differs; nothing overwritten: '+$name)}
        }
    }
    $copied=0;$reused=0
    if(-not $VerifyOnly){
        foreach($entry in $zip.Entries){
            if($entry.FullName -eq 'OFFLINE_INVENTORY.json'){continue}
            $dest=Resolve-PackagePath $root $entry.FullName
            if(Test-Path -LiteralPath $dest){
                if((Get-LocalHash $dest) -cne [string]$expected[$entry.FullName].sha256){throw 'Destination changed during restore'}
                $reused++;continue
            }
            [void][IO.Directory]::CreateDirectory((Split-Path $dest -Parent))
            Assert-NoLink $dest
            $output=[IO.File]::Open($dest,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
            $source=$entry.Open()
            try{$source.CopyTo($output)}finally{$source.Dispose();$output.Dispose()}
            if((Get-LocalHash $dest) -cne [string]$expected[$entry.FullName].sha256){throw 'Restored file verification failed'}
            $copied++
        }
    }
    [pscustomobject]@{status=if($VerifyOnly){'VERIFIED'}else{'RESTORED'};files=$expected.Count;bytes=$total;copied=$copied;reused=$reused;destination=$root;installersExecuted=$false}
}finally{
    if($zip){$zip.Dispose()}
    $inputFile.Dispose()
}
