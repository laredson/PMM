param([string]$BaselinePath='Development/TestResults/Reader132/baseline/PMM.AssetReader.dll',[string]$CandidatePath='Development/TestResults/Reader132/candidate/PMM.AssetReader.dll')
Set-StrictMode -Version 2;$ErrorActionPreference='Stop'
$repo=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$out=Join-Path $repo 'Development/TestResults/Reader132/evidence';[void][IO.Directory]::CreateDirectory($out)
$dotnet=Join-Path $repo 'PMM/Engine/dotnet/8.0.30/dotnet.exe';$map=Join-Path $repo 'PMM/Resources/Mappings/Mappings.usmap'
$shipped=Join-Path $repo 'PMM/Engine/AssetReader/PMM.AssetReader.dll'
foreach($name in @('RushRoarLeatherDrop_v2_P','FasterMounts4xAllWorkSuitabilitiesLevel10_P','EasyBreeding_P','NoCollisionFarmsAndExped_P')){
  $pak=Join-Path $repo ('PMM/Workspace/Mods/'+$name+'/'+$name+'.pak')
  if(-not(Test-Path $pak)){throw ('Local fixture missing: '+$name)}
  & (Join-Path $repo 'PMM/Engine/repak.exe') unpack $pak --output (Join-Path $out $name) --force --quiet
  if($LASTEXITCODE){throw 'Fixture extraction failed'}
}
$assets=@(Get-ChildItem -LiteralPath $out -Recurse -Filter '*.uasset' -File|Select-Object -ExpandProperty FullName)
$assets+=Join-Path $repo 'PMM/Workspace/GameReference/current/cooked/Pal/Content/Pal/DataTable/Character/DT_PalMonsterParameter_Common.uasset'
$checks=0;$reports=@()
foreach($asset in $assets){
  $results=@()
  foreach($reader in @($shipped,$BaselinePath,$CandidatePath)){
    $file=Join-Path $out ('export-'+[guid]::NewGuid().ToString('N')+'.json')
    $result=& $dotnet $reader export-json --asset $asset --output $file --mappings $map --engine UE5_1
    if($LASTEXITCODE){throw ('export-json failed for '+$asset)}
    $results+=,[pscustomobject]@{Hash=(Get-FileHash $file).Hash;Result=($result|ConvertFrom-Json)}
  }
  if($results[0].Hash -ne $results[1].Hash -or $results[0].Hash -ne $results[2].Hash){throw ('Source parity failure: '+$asset)};$checks++
  $reports+=[pscustomobject]@{Asset=$asset;ExactJsonParity=$true;Readability=$results[2].Result.semanticReadability;ReadErrors=$results[2].Result.readErrors}
  if($asset -match 'DT_PalMonsterParameter_Common'){
    $tableResults=@()
    foreach($reader in @($shipped,$BaselinePath,$CandidatePath)){
      $tableFile=Join-Path $out ('table-'+[guid]::NewGuid().ToString('N')+'.json')
      # Avoid NativeCommandError stopping PS 5.1 before ExitCode can be inspected.
      $saved=$ErrorActionPreference;$ErrorActionPreference='Continue'
      try{$run=@(& $dotnet $reader export-datatable --asset $asset --output $tableFile --mappings $map --engine UE5_1 2>&1);$exit=$LASTEXITCODE}finally{$ErrorActionPreference=$saved}
      $tableResults+=,[pscustomobject]@{Exit=$exit;Hash=$(if(Test-Path $tableFile){(Get-FileHash $tableFile).Hash}else{''});Text=($run -join "`n")}
    }
    if($tableResults[0].Exit -ne $tableResults[1].Exit -or $tableResults[0].Exit -ne $tableResults[2].Exit -or $tableResults[0].Hash -ne $tableResults[1].Hash -or $tableResults[0].Hash -ne $tableResults[2].Hash){throw 'DataTable source parity failed'};$checks++
    if($asset -like '*GameReference*'){
      if($tableResults[2].Text -notmatch 'schema index 90' -or $tableResults[2].Text -notmatch 'PalCharacterParameterDatabaseRow'){throw 'Current-game mapping error is not actionable'};$checks++
    }
  }
}
$reports|ConvertTo-Json -Depth 8|Set-Content (Join-Path $out 'parity.json') -Encoding UTF8
'PASS reader132: '+$checks+' comparisons, '+$assets.Count+' real cooked families; exact shipped/baseline/candidate semantic output parity and explicit current-game diagnostics.'
