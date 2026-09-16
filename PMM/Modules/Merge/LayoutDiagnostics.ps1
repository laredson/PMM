# Read-only explanation after every merge proof rejects a cooked family.
# Export names describe layout drift; they never authorize a merge or prove mod intent.
function Get-PMMCookedLayoutSummary([string]$HeaderPath) {
  $document=Get-Content -LiteralPath (Get-PMMSemanticJsonCached $HeaderPath) -Raw -Encoding UTF8|ConvertFrom-Json
  $exports=@($document.Exports)
  return [pscustomobject]@{ExportCount=$exports.Count;ExportNames=@($exports|ForEach-Object{[string]$_.ObjectName});OpaqueExports=@($exports|Where-Object{[string]$_.'$type' -like '*RawExport*'}).Count}
}
function Get-PMMCookedLayoutDiagnostic($Vanilla,[array]$ProviderRecords) {
  $current=Get-PMMCookedLayoutSummary ([string]$Vanilla.HeaderPath)
  $providers=@(foreach($record in $ProviderRecords){
    $summary=Get-PMMCookedLayoutSummary ([string]$record.Export.HeaderPath)
    [pscustomobject]@{Name=[string]$record.Mod.Name;ExportCount=$summary.ExportCount;OpaqueExports=$summary.OpaqueExports;CurrentOnlyExports=@($current.ExportNames|Where-Object{$_ -cnotin $summary.ExportNames});ProviderOnlyExports=@($summary.ExportNames|Where-Object{$_ -cnotin $current.ExportNames})}
  })
  $changed=@($providers|Where-Object{$_.ExportCount -ne $current.ExportCount -or $_.CurrentOnlyExports.Count -or $_.ProviderOnlyExports.Count})
  $partial=($current.OpaqueExports -gt 0 -or @($providers|Where-Object{$_.OpaqueExports -gt 0}).Count -gt 0)
  $reason=''
  if($changed.Count){
    $details=@($changed|ForEach-Object{$names=@($_.CurrentOnlyExports|Select-Object -First 6) -join ', ';$text=$_.Name+': '+$_.ExportCount+' exports';if($names){$text+='; current-game-only exports: '+$names};$text}) -join ' | '
    $reason='Cooked layout differs from the current game ('+$current.ExportCount+' exports). '+$details+'. A previous merge cannot be reused without proving preservation of the current game changes.'
  }
  if($partial){$reason+=' Semantic decoding is partial (opaque exports retained); whole-asset rewriting is not validated.'}
  return [pscustomobject]@{Schema='PMM_COOKED_LAYOUT_DIAGNOSTIC_V1';Current=$current;Providers=$providers;LayoutDiffers=($changed.Count -gt 0);SemanticReadability=$(if($partial){'Partial'}else{'Decoded'});AuthorizesMerge=$false;Reason=$reason.Trim()}
}
