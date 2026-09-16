# DataTable migration keeps the current cooked family as the byte anchor.
# Only a bundled, exact-input schema-evolution rule may project away a newly
# introduced field for delta calculation; its original bytes remain untouched.
function Get-PMMDataTableLayoutTransfer($Group,$Vanilla,[array]$Records) {
  $doc=Get-PMMProductionRecipeDocument;if(-not$doc){return $null}
  foreach($recipe in @($doc.recipes)){
    if([string]$recipe.asset -ine [string]$Group.Asset -or -not$recipe.PSObject.Properties['currentLayoutTransfer']){continue}
    $rule=$recipe.currentLayoutTransfer
    if([string]$rule.schema -cne 'PMM_DATATABLE_CURRENT_LAYOUT_TRANSFER_V1' -or [string]$rule.mappingsSha256 -cne (Get-Sha256 (Get-PMMMappingsPath))){continue}
    $expected=@($recipe.providers|ForEach-Object{[string]$_.pakSha256}|Sort-Object)
    $actual=@($Records|ForEach-Object{[string]$_.Mod.Hash}|Sort-Object)
    if(($expected -join '|') -cne ($actual -join '|')){continue}
    $why='';if(-not(Test-PMMRecipeFamilyExact $Vanilla $rule.vanilla ([ref]$why))){continue}
    $ok=$true
    foreach($pin in @($recipe.providers)){
      $record=@($Records|Where-Object{[string]$_.Mod.Hash -ceq [string]$pin.pakSha256})
      if($record.Count -ne 1 -or (Get-Sha256 ([string]$record[0].Mod.Path)) -cne [string]$pin.pakSha256 -or -not(Test-PMMRecipeFamilyExact $record[0].Export $pin.family ([ref]$why))){$ok=$false;break}
    }
    if($ok){return $rule}
  }
  return $null
}
function New-PMMDataTableCurrentProjection([string]$VanillaMap,[array]$Maps,$Rule,[string]$Path) {
  $current=Get-Content -LiteralPath $VanillaMap -Raw -Encoding UTF8|ConvertFrom-Json
  $preserve=@($Rule.preserveCurrentOnlyProperties)
  if(-not$preserve.Count){throw 'Layout transfer has no declared current-only fields.'}
  foreach($row in @($current.rows)){
    foreach($name in $preserve){if(@($row.properties|Where-Object{[string]$_.name -ceq [string]$name}).Count -ne 1){throw 'Current-only property is not unique in every row.'}}
    $row.properties=@($row.properties|Where-Object{[string]$_.name -cnotin $preserve})
  }
  foreach($map in $Maps){
    $provider=Get-Content -LiteralPath ([string]$map.Map) -Raw -Encoding UTF8|ConvertFrom-Json
    if((@($current.rows.id) -join '|') -cne (@($provider.rows.id) -join '|')){throw 'Layout transfer cannot align the exact row occurrence sequence.'}
    for($i=0;$i -lt $current.rows.Count;$i++){
      if((@($current.rows[$i].properties.name) -join '|') -cne (@($provider.rows[$i].properties.name) -join '|')){throw 'Layout transfer found undeclared property additions/deletions.'}
    }
  }
  Write-PMMJsonAtomic -Path $Path -Value $current -Depth 30
  return $Path
}
function Assert-PMMDataTableAnchorPreservesCurrent([string]$VanillaMap,[string]$AnchorMap) {
  $current=Get-Content -LiteralPath $VanillaMap -Raw -Encoding UTF8|ConvertFrom-Json
  $anchor=Get-Content -LiteralPath $AnchorMap -Raw -Encoding UTF8|ConvertFrom-Json
  $byId=@{};$occurrences=@{}
  foreach($row in @($anchor.rows)){
    $id=[string]$row.id;if(-not$occurrences.ContainsKey($id)){$occurrences[$id]=0};$occurrences[$id]++
    $byId[$id+'|'+$occurrences[$id]]=@{};foreach($property in @($row.properties)){$byId[$id+'|'+$occurrences[$id]][[string]$property.name]=$true}
  }
  $occurrences=@{}
  foreach($row in @($current.rows)){
    $id=[string]$row.id;if(-not$occurrences.ContainsKey($id)){$occurrences[$id]=0};$occurrences[$id]++;$key=$id+'|'+$occurrences[$id]
    if(-not$byId.ContainsKey($key)){throw ('Selected cooked base omits a current-game row: '+$id+'. A proven current-layout transfer is required.')}
    foreach($property in @($row.properties)){if(-not$byId[$key].ContainsKey([string]$property.name)){throw ('Selected cooked base omits current-game property '+[string]$property.name+' in '+$id+'. A proven current-layout transfer is required.')}}
  }
}

function Get-PMMTableBytesHash([byte[]]$Bytes){$sha=[Security.Cryptography.SHA256]::Create();try{return ([BitConverter]::ToString($sha.ComputeHash($Bytes)).Replace('-','').ToLowerInvariant())}finally{$sha.Dispose()}}
function Set-PMMTableHeaderPayloadSize([byte[]]$Header,[int]$OldSize,[int]$NewSize,$Rule){
  foreach($pair in @(@([int]$Rule.headerOffsets.bulkDataStart,[long]($Header.Length+$OldSize-4),[long]($Header.Length+$NewSize-4)),@([int]$Rule.headerOffsets.exportSerialSize,[long]($OldSize-4),[long]($NewSize-4)))){
    if([BitConverter]::ToInt64($Header,$pair[0]) -ne $pair[1]){throw 'Cooked header bookkeeping was not proven.'}
    [Array]::Copy([BitConverter]::GetBytes([long]$pair[2]),0,$Header,$pair[0],8)
  }
}
function Get-PMMTableRowStarts($Map,[byte[]]$Bytes,[int]$Properties){
  $starts=@(foreach($row in $Map.rows){
    if($row.properties.Count -ne $Properties){throw 'Unexpected property count in pinned table.'}
    $start=[int](($row.properties|Measure-Object offset -Minimum).Minimum)-22
    if($start -lt 14 -or $start+22 -gt $Bytes.Length -or [BitConverter]::ToUInt16($Bytes,$start+8) -ne (0x180+($Properties -shl 9))){throw 'Unproven unversioned row header layout.'}
    $start
  })
  if($starts[0] -ne 14 -or [BitConverter]::ToInt32($Bytes,10) -ne $Map.rows.Count -or [BitConverter]::ToUInt32($Bytes,$Bytes.Length-4) -ne 0x9e2a83c1L){throw 'Unproven cooked table framing.'}
  return ,@($starts+@($Bytes.Length-4))
}
function New-PMMDataTableMigratedInputs($Vanilla,[array]$Maps,$Rule,[string]$Root){
  [void][IO.Directory]::CreateDirectory($Root)
  $currentMapPath=Get-PMMDataTableMapCached $Vanilla.HeaderPath
  $current=Get-Content -LiteralPath $currentMapPath -Raw -Encoding UTF8|ConvertFrom-Json
  $recovery=$Rule.baselineRecovery
  $source=@($Maps|Where-Object{[string]$_.Record.Mod.Hash -ceq [string]$recovery.providerPakSha256})
  if($source.Count -ne 1){throw 'Historical baseline recovery source is ambiguous.'}
  $old=Get-Content -LiteralPath $source[0].Map -Raw -Encoding UTF8|ConvertFrom-Json
  $oldBytes=[IO.File]::ReadAllBytes([IO.Path]::ChangeExtension($source[0].Record.Export.HeaderPath,'.uexp'))
  $oldHeader=[IO.File]::ReadAllBytes($source[0].Record.Export.HeaderPath)
  $oldStarts=Get-PMMTableRowStarts $old $oldBytes 90
  $indices=@(for($i=0;$i -lt $old.rows.Count;$i++){if($old.rows[$i].id -ceq $recovery.row){$i}})
  if($indices.Count -ne 1){throw 'Historical recovery row is not unique.'}
  $i=$indices[0];$properties=$old.rows[$i].properties;$indices=@(for($j=0;$j -lt $properties.Count;$j++){if($properties[$j].name -ceq $recovery.property){$j}})
  if($indices.Count -ne 1){throw 'Historical recovery property is not unique.'}
  $j=$indices[0];$offset=[int]$properties[$j].offset;$mask=$oldStarts[$i]+10+[int][Math]::Floor($j/8);$bit=1 -shl ($j%8)
  if($properties[$j].valueKind -ne 'i32' -or $recovery.historicalValue -ne 0 -or ($oldBytes[$mask] -band $bit) -ne 0 -or [BitConverter]::ToInt32($oldBytes,$offset) -ne $recovery.expectedValue){throw 'Historical reverse delta was not proven.'}
  $oldBytes[$mask]=$oldBytes[$mask] -bor $bit
  $recovered=[byte[]]::new($oldBytes.Length-4);[Array]::Copy($oldBytes,0,$recovered,0,$offset);[Array]::Copy($oldBytes,$offset+4,$recovered,$offset,$oldBytes.Length-$offset-4)
  Set-PMMTableHeaderPayloadSize $oldHeader $oldBytes.Length $recovered.Length $Rule
  if((Get-PMMTableBytesHash $recovered) -cne $Rule.historicalBaseline.uexp.sha256 -or (Get-PMMTableBytesHash $oldHeader) -cne $Rule.historicalBaseline.uasset.sha256){throw 'Recovered historical baseline does not match both original hashes.'}
  $historicalPath=Join-Path $Root 'historical.uasset';[IO.File]::WriteAllBytes($historicalPath,$oldHeader);[IO.File]::WriteAllBytes([IO.Path]::ChangeExtension($historicalPath,'.uexp'),$recovered)
  $historicalMapPath=Get-PMMDataTableMapCached $historicalPath;$historical=Get-Content -LiteralPath $historicalMapPath -Raw -Encoding UTF8|ConvertFrom-Json
  $projectedPath=New-PMMDataTableCurrentProjection $currentMapPath $Maps $Rule (Join-Path $Root 'current-map.json')
  $currentProjected=Get-Content -LiteralPath $projectedPath -Raw -Encoding UTF8|ConvertFrom-Json
  if((@($historical.rows.id) -join '|') -cne (@($current.rows.id) -join '|')){throw 'Historical/current row sequence differs.'}
  $materialize=@{};$normalized=[Collections.Generic.List[object]]::new()
  foreach($entry in $Maps){
    $provider=Get-Content -LiteralPath $entry.Map -Raw -Encoding UTF8|ConvertFrom-Json
    $intent=Get-Content -LiteralPath $projectedPath -Raw -Encoding UTF8|ConvertFrom-Json
    for($i=0;$i -lt $current.rows.Count;$i++){
      for($j=0;$j -lt 90;$j++){
        $before=$historical.rows[$i].properties[$j];$mod=$provider.rows[$i].properties[$j];$now=$intent.rows[$i].properties[$j]
        if($before.name -cne $mod.name -or $now.name -cne $mod.name -or $before.type -cne $mod.type -or $now.type -cne $mod.type){throw ('Historical semantic schema alignment failed at row '+$i+', property '+$j+': '+$before.name+'/'+$mod.name+'/'+$now.name+' types '+$before.type+'/'+$mod.type+'/'+$now.type+' kinds '+$now.valueKind+'/'+$mod.valueKind)}
        if($before.value -cne $mod.value){
          $now.value=$mod.value;$now.valueKind=$mod.valueKind;$now.supportedScalar=$mod.supportedScalar
          if($mod.supportedScalar -and $mod.valueKind -in @('i32','f32')){$materialize[$i.ToString()+'|'+$j]=$true}
        }
      }
    }
    $path=Join-Path $Root ('intent-'+$normalized.Count+'.json');Write-PMMJsonAtomic -Path $path -Value $intent -Depth 30
    $normalized.Add([pscustomobject]@{Record=$entry.Record;Map=$path})
  }
  $bytes=[IO.File]::ReadAllBytes([IO.Path]::ChangeExtension($Vanilla.HeaderPath,'.uexp'));$starts=Get-PMMTableRowStarts $current $bytes 91
  $stream=[IO.MemoryStream]::new();$inserted=0
  try{
    $stream.Write($bytes,0,14)
    for($i=0;$i -lt $current.rows.Count;$i++){
      $start=$starts[$i];$end=$starts[$i+1];$row=$current.rows[$i];$header=[byte[]]::new(22);[Array]::Copy($bytes,$start,$header,0,22)
      $body=[IO.MemoryStream]::new();$cursor=$start+22
      try{
        for($j=0;$j -lt 91;$j++){
          $prop=$row.properties[$j];$mask=10+[int][Math]::Floor($j/8);$bit=1 -shl ($j%8);$zero=($header[$mask] -band $bit) -ne 0
          if([int]$prop.offset -ne $cursor){throw 'Property offset does not align with the raw row cursor.'}
          if($zero){
            if($materialize.ContainsKey($i.ToString()+'|'+$j)){
              if($prop.valueKind -notin @('i32','f32') -or [double]$prop.value -ne 0){throw 'Only proven zero 32-bit scalars can be materialized.'}
              $header[$mask]=$header[$mask] -band (0xff -bxor $bit);$body.Write(([byte[]]::new(4)),0,4);$inserted++
            }
          }else{
            $next=$end
            if($j+1 -lt 91){$next=[int]$row.properties[$j+1].offset}
            if($next -lt $cursor -or $next -gt $end){throw 'Property byte span escapes the row.'}
            $body.Write($bytes,$cursor,$next-$cursor);$cursor=$next
          }
        }
        if($cursor -ne $end){throw 'Row contains unaccounted bytes.'}
        $stream.Write($header,0,22);$body.Position=0;$body.CopyTo($stream)
      }finally{$body.Dispose()}
    }
    $stream.Write($bytes,$bytes.Length-4,4);$result=$stream.ToArray()
  }finally{$stream.Dispose()}
  $header=[IO.File]::ReadAllBytes($Vanilla.HeaderPath);Set-PMMTableHeaderPayloadSize $header $bytes.Length $result.Length $Rule
  $basePath=Join-Path $Root 'current-expanded.uasset';[IO.File]::WriteAllBytes($basePath,$header);[IO.File]::WriteAllBytes([IO.Path]::ChangeExtension($basePath,'.uexp'),$result)
  $expandedMap=Get-PMMDataTableMapCached $basePath;$expanded=Get-Content -LiteralPath $expandedMap -Raw -Encoding UTF8|ConvertFrom-Json
  for($i=0;$i -lt $current.rows.Count;$i++){
    if($expanded.rows[$i].id -cne $current.rows[$i].id -or $expanded.rows[$i].properties.Count -ne 91){throw 'Materialization changed row topology.'}
    for($j=0;$j -lt 91;$j++){if($expanded.rows[$i].properties[$j].value -cne $current.rows[$i].properties[$j].value){throw 'Zero materialization changed a property value.'}}
    $expanded.rows[$i].properties=@($expanded.rows[$i].properties|Where-Object{$_.name -cnotin @($Rule.preserveCurrentOnlyProperties)})
  }
  $baseMap=Join-Path $Root 'expanded-map.json';Write-PMMJsonAtomic -Path $baseMap -Value $expanded -Depth 30
  Write-PMMJsonAtomic -Path (Join-Path $Root 'proof.json') -Value ([ordered]@{RuleId=$Rule.id;HistoricalMap=$historicalMapPath;CurrentMap=$currentMapPath;MaterializedScalars=$inserted;BytesAdded=($result.Length-$bytes.Length);RuntimeProven=$false}) -Depth 10
  return [pscustomobject]@{VanillaMap=$projectedPath;BaseMap=$baseMap;BaseExport=[pscustomobject]@{HeaderPath=$basePath};Maps=$normalized.ToArray()}
}
