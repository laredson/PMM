. (Join-Path $PSScriptRoot 'Persistence.ps1')
# User-selected mappings are local data; bundled dependencies remain independently verifiable.
function Get-PMMBundledMappingsPath {return (Join-Path $Script:Root 'Resources/Mappings/Mappings.usmap')}
function Get-PMMMappingsSelectionPath {return (Join-Path $Script:Root 'Workspace/State/mappings-selection.json')}
function Get-PMMMappingsPath {
  $selection=Get-PMMMappingsSelectionPath
  if(-not(Test-Path -LiteralPath $selection -PathType Leaf)){return (Get-PMMBundledMappingsPath)}
  $document=Get-Content -LiteralPath $selection -Raw -Encoding UTF8|ConvertFrom-Json
  if([string]$document.Schema -cne 'PMM_MAPPINGS_SELECTION_V1'){throw 'Invalid local mappings selection. Select mappings again in Settings.'}
  if([string]$document.Mode -eq 'Bundled'){return (Get-PMMBundledMappingsPath)}
  if([string]$document.Mode -ne 'Local' -or [string]$document.Sha256 -cnotmatch '^[a-f0-9]{64}$'){throw 'Invalid local mappings identity.'}
  $path=Join-Path $Script:Root ('Workspace/Mappings/'+[string]$document.Sha256+'.usmap')
  if(-not(Test-Path -LiteralPath $path -PathType Leaf)){throw 'Selected local mappings are missing. Import the file again in Settings.'}
  return $path
}
function Import-PMMLocalMappings([string]$SourceFile='') {
  # The caller holds the shared processing lock. Selection is the atomic commit;
  # cancellation or failed validation cannot replace the previous selection.
  $selection=[ordered]@{Schema='PMM_MAPPINGS_SELECTION_V1';Mode='Bundled';Sha256='';ImportedUtc=[DateTime]::UtcNow.ToString('o')}
  if($SourceFile){
    if([IO.Path]::GetExtension($SourceFile) -ine '.usmap'){throw 'Select an extracted .usmap file.'}
    $info=Get-Item -LiteralPath $SourceFile -ErrorAction Stop
    if($info.Length -lt 16 -or $info.Length -gt 128MB){throw 'Mappings must be between 16 bytes and 128 MiB.'}
    $input=[IO.File]::OpenRead($info.FullName)
    try{
      if($input.ReadByte() -ne 0xC4 -or $input.ReadByte() -ne 0x30){throw 'The file is not a usmap mapping.'}
      $input.Position=0;$sha=[Security.Cryptography.SHA256]::Create()
      try{$hash=[BitConverter]::ToString($sha.ComputeHash($input)).Replace('-','').ToLowerInvariant()}finally{$sha.Dispose()}
      $folder=Join-Path $Script:Root 'Workspace/Mappings';[void][IO.Directory]::CreateDirectory($folder)
      $destination=Join-Path $folder ($hash+'.usmap');$temp=Join-Path $folder ([guid]::NewGuid().ToString('N')+'.tmp')
      try{
        if(-not(Test-Path -LiteralPath $destination -PathType Leaf)){
          $input.Position=0;$output=[IO.File]::Open($temp,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
          try{$input.CopyTo($output);$output.Flush($true)}finally{$output.Dispose()}
          if((Get-Sha256 $temp) -ne $hash){throw 'Mapping bytes changed during import.'}
          [IO.File]::Move($temp,$destination)
        }
        if((Get-Sha256 $destination) -ne $hash){throw 'Stored mapping bytes changed; selection was not updated.'}
      }finally{if(Test-Path -LiteralPath $temp){Remove-Item -LiteralPath $temp -Force}}
      $selection.Mode='Local';$selection.Sha256=$hash
    }finally{$input.Dispose()}
  }
  Write-PMMJsonAtomic -Path (Get-PMMMappingsSelectionPath) -Value $selection -Depth 5
  return [pscustomobject]$selection
}
