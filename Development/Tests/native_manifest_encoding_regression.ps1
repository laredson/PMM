param([string]$Root=([IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))))
Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
function Assert-PMMNativeManifestEncoding([byte[]]$Bytes) {
    if($Bytes.Length -ge 3 -and $Bytes[0] -eq 0xEF -and $Bytes[1] -eq 0xBB -and $Bytes[2] -eq 0xBF){
        throw 'RELEASE_MANIFEST.json must be UTF-8 without BOM: the native runtime rejects it.'
    }
    $text=[Text.UTF8Encoding]::new($false,$true).GetString($Bytes)
    $manifest=$text | ConvertFrom-Json
    if($manifest.schema -ne 'PMM_RELEASE_MANIFEST_V1'){throw 'Unexpected manifest schema.'}
}
$path=Join-Path $Root 'PMM\Resources\Metadata\RELEASE_MANIFEST.json'
$bytes=[IO.File]::ReadAllBytes($path)
Assert-PMMNativeManifestEncoding $bytes
$invalid=[byte[]](@(0xEF,0xBB,0xBF)+@($bytes))
$rejected=$false
try{Assert-PMMNativeManifestEncoding $invalid}catch{
    if($_.Exception.Message -notmatch 'without BOM'){throw}
    $rejected=$true
}
if(-not $rejected){throw 'Regression guard accepted the BOM fixture.'}
$lines=@(Get-Content (Join-Path $Root 'PMM\Resources\Metadata\SHA256SUMS.txt') | Where-Object {$_ -match '  Resources/Metadata/RELEASE_MANIFEST\.json$'})
if($lines.Count -ne 1 -or $lines[0].Substring(0,64) -cne (Get-FileHash $path -Algorithm SHA256).Hash.ToLowerInvariant()){throw 'Manifest checksum mismatch.'}
Write-Output 'NATIVE_MANIFEST_ENCODING_OK: valid UTF-8 JSON, no BOM, BOM fixture rejected, checksum matches.'

