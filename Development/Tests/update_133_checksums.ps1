param([string]$Repository=([IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))))
Set-StrictMode -Version 2;$ErrorActionPreference='Stop'
$app=Join-Path $Repository 'PMM';$inventory=Join-Path $app 'Resources/Metadata/SHA256SUMS.txt'
$paths=[Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
foreach($line in Get-Content -LiteralPath $inventory){
  if($line -notmatch '^[a-f0-9]{64}  (.+)$'){throw 'Invalid existing inventory.'}
  [void]$paths.Add($matches[1])
}
foreach($file in Get-ChildItem -LiteralPath (Join-Path $app 'Modules') -Recurse -File|Where-Object{$_.Extension -in @('.ps1','.json')}){
  [void]$paths.Add($file.FullName.Substring($app.Length+1).Replace('\','/'))
}
foreach($leaf in @('DEEP_ANALYSIS.en.md','DEEP_ANALYSIS.es.md','ReleaseNotes-1.3.3.md','ReleaseNotes-1.3.4.md')){[void]$paths.Add('Documentation/'+$leaf)}
[void]$paths.Add('Resources/Mappings/Historical/Palworld-1.0.3.usmap')
$ordered=[string[]]@($paths);[Array]::Sort($ordered,[StringComparer]::Ordinal)
$lines=@(foreach($relative in $ordered){
  if($relative -match '(^|/)(Workspace|TestResults|ExternalFiles|\.\.)(/|$)' -or $relative -match '[:\\]' -or $relative -eq 'Resources/Metadata/SHA256SUMS.txt'){throw 'Unsafe inventory entry.'}
  $path=Join-Path $app $relative
  if(-not(Test-Path -LiteralPath $path -PathType Leaf)){throw ('Missing public file: '+$relative)}
  (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()+'  '+$relative
})
[IO.File]::WriteAllText($inventory,($lines -join [Environment]::NewLine)+[Environment]::NewLine,[Text.UTF8Encoding]::new($false))
'Updated public checksums: '+$lines.Count
