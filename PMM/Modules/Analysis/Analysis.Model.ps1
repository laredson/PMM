# Versioned, inert evidence used by UI, workers and MCP.
function Get-PMMAnalysisValue($Object,[string]$Name,$Default=$null) {
  if($null -eq $Object){return $Default}
  if($Object -is [Collections.IDictionary]){if($Object.Contains($Name)){return $Object[$Name]}}
  elseif($Object.PSObject.Properties.Name -contains $Name){return $Object.$Name}
  return $Default
}
function Get-PMMAnalysisHash($Value) {
  $json=ConvertTo-PMMAnalysisCanonicalJson $Value
  $sha=[Security.Cryptography.SHA256]::Create()
  try{return [BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($json))).Replace('-','').ToLowerInvariant()}finally{$sha.Dispose()}
}
function Get-PMMAnalysisRoot {return (Join-PMMPath 'Workspace' 'DeepAnalysis')}
function Get-PMMAnalysisPath([string]$Id) {
  if($Id -notmatch '^DA-[a-f0-9]{32}$'){throw 'Invalid analysis identifier.'}
  return (Join-Path (Get-PMMAnalysisRoot) $Id)
}
function New-PMMDeepAnalysisOptions {
  return [pscustomobject]@{Schema='PMM_DEEP_OPTIONS_V1';CheckUpdates=$true;IncludePatch=$true;AutomaticSolution=$false;AllowDeploy=$false;AllowGame=$false;TestWorld=$false;Isolate=$false;AllowDependencies=$false;PublishRemote=$false;MaxActiveMinutes=40;MaxCandidates=6;MaxTestRuns=12;MaxDiskGiB=10;MaxSemanticFamilies=1000}
}
function New-PMMAnalysisFinding {
  param([string]$Rule,[string[]]$Mods=@(),[string]$Resource='',[string]$Severity='Info',[string]$Confidence='Indeterminate',[string]$Classification='Indeterminate',[string]$Message='',[string]$Action='',[array]$Evidence=@(),[string[]]$Limitations=@())
  return [pscustomobject]@{Id=('F-'+(Get-PMMAnalysisHash @($Rule,@($Mods|Sort-Object),$Resource,$Message)));Rule=$Rule;Mods=@($Mods|Sort-Object -Unique);Resource=$Resource;Severity=$Severity;Confidence=$Confidence;Classification=$Classification;Message=$Message;Action=$Action;Evidence=@($Evidence);Limitations=@($Limitations);RuntimeProven=$false}
}
function ConvertTo-PMMResourcePath([string]$Path) {
  $p=$Path.Replace('\','/').Trim()
  if($p.StartsWith('/Game/')){$p='Pal/Content/'+$p.Substring(6)}
  if($p -match '^(.+)\.([^/\.]+)$' -and [IO.Path]::GetExtension($p) -notin @('.uasset','.umap','.uexp','.ubulk')){$p=$matches[1]}
  if($p -notmatch '\.(uasset|umap)$'){$p+='.uasset'}
  return $p.ToLowerInvariant()
}
function Get-PMMEffectiveResources {
  param([array]$Resources,[bool]$PriorityVerified=$false)
  foreach($group in @($Resources|Group-Object LogicalPath)){
    $mods=@($group.Group|Where-Object{$_.Provider -ne 'Vanilla'})
    $choices=@(if($mods.Count){$mods}else{@($group.Group)})
    $hashes=@($choices|Select-Object -ExpandProperty Hash -Unique)
    $resolved=($choices.Count -eq 1 -or $hashes.Count -eq 1 -or $PriorityVerified)
    $winner=if($resolved){@($choices|Sort-Object Priority -Descending)[0]}else{$null}
    [pscustomobject]@{LogicalPath=$group.Name;Resolved=$resolved;Winner=$winner;Providers=$choices;Reason=$(if($resolved){'Unique, identical or verified mount priority'}else{'Actual mount priority has not been verified'})}
  }
}
function Get-PMMResourceFindings {
  param([array]$Resources,[string[]]$KnownPaths=@(),[bool]$PriorityVerified=$false,[bool]$IndexComplete=$false)
  $effective=@{};foreach($row in @(Get-PMMEffectiveResources $Resources $PriorityVerified)){$effective[$row.LogicalPath]=$row}
  $known=[Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
  foreach($path in $KnownPaths){[void]$known.Add($path)}
  foreach($key in $effective.Keys){[void]$known.Add($key)}
  foreach($row in $effective.Values){
    if(-not$row.Resolved){
      New-PMMAnalysisFinding -Rule 'MOUNT_PRIORITY_UNKNOWN' -Mods @($row.Providers|ForEach-Object{$_.Provider}) -Resource $row.LogicalPath -Message 'Several different providers replace this resource; its actual winner is not proven.' -Action 'Verify the deployment and mount order.'
    }
    $sources=@(if($row.Resolved){$row.Winner}else{$row.Providers})
    foreach($source in $sources){
      if($source.ReaderStatus -ne 'Complete'){
        New-PMMAnalysisFinding -Rule 'READER_COVERAGE' -Mods @($source.Provider) -Resource $source.LogicalPath -Message 'Part of this resource could not be interpreted.' -Action 'Prepare current mappings or request a reader capability.' -Limitations @($source.ReaderStatus)
      }
      foreach($reference in @($source.References)){
        $target=$reference.Target
        if(-not$target -or $target -like '/script/*' -or $target -like '/engine/*'){continue}
        if(-not$known.Contains($target)){
          $proven=($IndexComplete -and $row.Resolved -and $reference.Required)
          New-PMMAnalysisFinding -Rule 'REFERENCE_TARGET_MISSING' -Mods @($source.Provider) -Resource $source.LogicalPath -Severity $(if($proven){'High'}else{'Info'}) -Confidence $(if($proven){'High'}else{'Low'}) -Classification $(if($proven){'StructuralIncompatibility'}else{'Suspected'}) -Message ('Reference target absent from the indexed configuration: '+$target) -Action 'Check the required package or dependency.' -Evidence @($reference) -Limitations $(if($proven){@('Runtime cause remains unproven.')}else{@('Optional/dynamic reference, ambiguous winner or incomplete index.')})
          continue
        }
        if($reference.Member -and $effective.ContainsKey($target)){
          $destination=$effective[$target]
          if($destination.Resolved -and $row.Resolved -and ($destination.Winner.ReaderStatus -eq 'Complete' -or ($reference.Kind -eq 'Class' -and (Get-PMMAnalysisValue $destination.Winner DefinitionsComplete $false)) -or ($reference.Kind -eq 'Row' -and (Get-PMMAnalysisValue $destination.Winner RowsComplete $false)))){
            $members=if($reference.Kind -eq 'Row'){@($destination.Winner.Rows)}else{@($destination.Winner.Definitions)}
            if(-not$reference.Required -and $reference.Member -notin $members){
              New-PMMAnalysisFinding -Rule 'OPTIONAL_MEMBER_MISSING' -Mods @($source.Provider,$destination.Winner.Provider) -Resource $source.LogicalPath -Severity Medium -Confidence Medium -Classification Suspected -Message ('Referenced '+$reference.Kind+' '+$reference.Member+' was not found in '+$target) -Action 'Check intended behavior and optional lookup handling.' -Evidence @($reference)
            }
            if($reference.Required -and $reference.Member -notin $members){
              New-PMMAnalysisFinding -Rule 'REFERENCE_MEMBER_MISSING' -Mods @($source.Provider,$destination.Winner.Provider) -Resource $source.LogicalPath -Severity High -Confidence High -Classification StructuralIncompatibility -Message ('Required '+$reference.Kind+' '+$reference.Member+' is absent from '+$target) -Action 'Restore the referenced member or adapt the referring resource.' -Evidence @($reference,@{TargetHash=$destination.Winner.Hash}) -Limitations @('Structural evidence does not prove that this caused a reported crash.')
            }
          }
        }
      }
    }
    $vanilla=@($Resources|Where-Object{$_.LogicalPath -eq $row.LogicalPath -and $_.Provider -eq 'Vanilla'})
    if($vanilla.Count -eq 1 -and ($vanilla[0].ReaderStatus -eq 'Complete' -or (Get-PMMAnalysisValue $vanilla[0] DefinitionsComplete $false))){
      foreach($source in @($row.Providers|Where-Object{$_.Provider -ne 'Vanilla' -and ($_.ReaderStatus -eq 'Complete' -or (Get-PMMAnalysisValue $_ DefinitionsComplete $false))})){
        $lost=@($vanilla[0].Definitions|Where-Object{$_ -notin $source.Definitions})
        $rowsLost=@(if(($vanilla[0].ReaderStatus -eq 'Complete' -or (Get-PMMAnalysisValue $vanilla[0] RowsComplete $false)) -and ($source.ReaderStatus -eq 'Complete' -or (Get-PMMAnalysisValue $source RowsComplete $false))){$vanilla[0].Rows|Where-Object{$_ -notin $source.Rows}})
        if($lost.Count -or $rowsLost.Count){
          New-PMMAnalysisFinding -Rule 'CURRENT_STRUCTURE_REMOVED' -Mods @($source.Provider) -Resource $source.LogicalPath -Severity Medium -Confidence Medium -Classification Suspected -Message 'This replacement omits definitions or table rows present in the installed game.' -Action 'Check whether the removal is intentional and examine reverse dependencies.' -Evidence @(@{Definitions=$lost;Rows=$rowsLost}) -Limitations @('Intentional removals are possible; this alone is not a defect or crash cause.')
        }
      }
    }
  }
}
function Read-PMMDeepAnalysis([string]$Id) {
  return (Read-PMMJsonFile (Join-Path (Get-PMMAnalysisPath $Id) 'report.json') -Schema PMM_DEEP_REPORT_V1)
}
function Export-PMMDeepAnalysis([string]$Id) {
  $report=Read-PMMDeepAnalysis $Id
  $encode={param($s)[Net.WebUtility]::HtmlEncode([string]$s)}
  $rows=@(foreach($f in $report.Findings){'<tr><td>'+(& $encode $f.Severity)+'</td><td>'+(& $encode $f.Confidence)+'</td><td>'+(& $encode ($f.Mods -join ', '))+'</td><td>'+(& $encode $f.Resource)+'</td><td>'+(& $encode $f.Message)+'</td><td>'+(& $encode $f.Action)+'<details><summary>Evidence / Evidencia</summary><pre>'+(& $encode ($f.Evidence|ConvertTo-Json -Depth 20))+'</pre><p>'+(& $encode ($f.Limitations -join '; '))+'</p><p>'+(& $encode $f.Classification)+'</p></details></td></tr>'})
  $html='<!doctype html><html><head><meta charset="utf-8"><title>PMM Deep analysis</title><style>body{font:16px system-ui;margin:2rem;background:#101d2a;color:#e9f0f6}table{border-collapse:collapse;width:100%}td,th{padding:.6rem;border:1px solid #496074;text-align:left}input{padding:.6rem;width:40%}</style></head><body><h1>PMM Deep analysis</h1><p>'+(& $encode $report.Summary)+'</p><p>Coverage: '+(& $encode ($report.Coverage|ConvertTo-Json -Compress))+'</p><p>Findings are not proof of a crash cause. / Los hallazgos no prueban la causa de un crash.</p><input id="filter" aria-label="Filter / Filtrar" placeholder="Filter / Filtrar"><table><thead><tr><th>Severity</th><th>Confidence</th><th>Mods</th><th>Resource</th><th>Finding</th><th>Next action</th></tr></thead><tbody>'+($rows -join '')+'</tbody></table><script>document.getElementById("filter").addEventListener("input",function(){var q=this.value.toLowerCase();document.querySelectorAll("tbody tr").forEach(function(r){r.hidden=!r.textContent.toLowerCase().includes(q)})})</script></body></html>'
  $path=Join-Path (Get-PMMAnalysisPath $Id) 'report.html'
  [IO.File]::WriteAllText($path,$html,[Text.UTF8Encoding]::new($false));return $path
}

function ConvertTo-PMMAnalysisCanonicalJson($Value) {
  if($null -eq $Value){return 'null'}
  if($Value -is [string] -or $Value -is [ValueType]){return (ConvertTo-Json -InputObject $Value -Compress)}
  if($Value -is [Collections.IDictionary]){
    $keys=[string[]]@($Value.Keys);[Array]::Sort($keys,[StringComparer]::Ordinal)
    return ('{'+(@(foreach($key in $keys){(ConvertTo-Json -InputObject $key -Compress)+':'+(ConvertTo-PMMAnalysisCanonicalJson $Value[$key])}) -join ',')+'}')
  }
  if($Value -is [Collections.IEnumerable]){return ('['+(@(foreach($item in $Value){ConvertTo-PMMAnalysisCanonicalJson $item}) -join ',')+']')}
  $keys=[string[]]@($Value.PSObject.Properties.Name);[Array]::Sort($keys,[StringComparer]::Ordinal)
  return ('{'+(@(foreach($key in $keys){(ConvertTo-Json -InputObject $key -Compress)+':'+(ConvertTo-PMMAnalysisCanonicalJson $Value.$key)}) -join ',')+'}')
}
function Assert-PMMDeepOptions($Options) {
  if($Options.Schema -cne 'PMM_DEEP_OPTIONS_V1'){throw 'Unsupported analysis options.'}
  foreach($field in @('CheckUpdates','IncludePatch','AutomaticSolution','AllowDeploy','AllowGame','TestWorld','Isolate','AllowDependencies','PublishRemote')){
    if($Options.$field -isnot [bool]){throw ('Option must be boolean: '+$field)}
  }
  foreach($field in @('MaxActiveMinutes','MaxCandidates','MaxTestRuns','MaxDiskGiB','MaxSemanticFamilies')){
    $n=0
    if(-not[int]::TryParse([string]$Options.$field,[ref]$n) -or $n -lt 1 -or $n -gt 10000){throw ('Invalid bounded limit: '+$field)}
  }
  if($Options.AllowDeploy -or $Options.AllowGame -or $Options.TestWorld -or $Options.Isolate){throw 'Game automation is awaiting a validated isolation adapter. Its permissions cannot be enabled yet.'}
  if($Options.PublishRemote){throw 'Remote publication requires a separately configured receiver; only local exchange is available.'}
}
