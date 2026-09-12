param([string]$Repository=([IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))))
Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
$root=Join-Path $Repository 'PMM'
$path=Join-Path $root 'Resources\Metadata\SHA256SUMS.txt'
$names=[Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
foreach($line in Get-Content $path){if($line -match '^[a-f0-9]{64}  (.+)$'){[void]$names.Add($Matches[1])}else{throw 'Invalid checksum line.'}}
foreach($dir in @('Modules','Resources\Unreal')){
    foreach($file in Get-ChildItem (Join-Path $root $dir) -Recurse -File){
        if($file.Extension -notin @('.ps1','.py','.json')){throw ('Unexpected file in runtime module: '+$file.FullName)}
        [void]$names.Add($file.FullName.Substring($root.Length+1).Replace('\','/'))
    }
}
foreach($name in @('Resources/UI/PMMArtwork.png')){[void]$names.Add($name)}
foreach($file in Get-ChildItem (Join-Path $root 'Engine/AssetTools') -File){
    if($file.Extension -notin @('.dll','.json')){throw 'Unexpected AssetTools distribution file.'}
    [void]$names.Add('Engine/AssetTools/'+$file.Name)
}
foreach($doc in @('WORKBENCH.md','MCP_BRIDGE.md','UNREAL_SETUP.md','UNREAL_SETUP.es.md','UNREAL_SETUP.en.md')){[void]$names.Add('Documentation/'+$doc)}
$lines=@(foreach($name in @($names|Sort-Object)){
    if($name -match '(^|/)(Workspace|\.codex|\.git)(/|$)' -or $name -match '(^|/)\.\.(/|$)' -or [IO.Path]::IsPathRooted($name)){throw 'Unsafe public inventory entry.'}
    $file=Join-Path $root $name
    ((Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash.ToLowerInvariant()+'  '+$name)
})
# Preserve the packaged inventory's byte convention; .gitattributes disables normalization.
$newLine=[Environment]::NewLine
[IO.File]::WriteAllText($path,(($lines -join $newLine)+$newLine),[Text.UTF8Encoding]::new($false))
Write-Output ('CHECKSUMS_UPDATED: '+$lines.Count+' public files.')
