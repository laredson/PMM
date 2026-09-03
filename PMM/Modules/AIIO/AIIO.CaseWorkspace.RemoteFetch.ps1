<# AIIO remote-fetch capability.
   A work order declares a URL; PMM owns storage, progress, hashing and evidence.
   No work order should depend on PMM Temp paths or on side effects from another action. #>

if(-not $Script:PMMAIIORemoteFetchInstalled){
  $Script:PMMAIIORemoteBaseAction=${function:Invoke-PMMAIIOCaseAction}
  $Script:PMMAIIORemoteBaseHandoff=${function:New-PMMAIIOCaseHandoff}
  $Script:PMMAIIORemoteFetchInstalled=$true
}

function Get-PMMAIIOSafeRemoteFileName([string]$Url,[string]$Requested=''){
  $name=$Requested
  if([string]::IsNullOrWhiteSpace($name)){
    try{$name=[Uri]::UnescapeDataString([IO.Path]::GetFileName(([Uri]$Url).AbsolutePath))}catch{$name='download.bin'}
  }
  $name=[IO.Path]::GetFileName([string]$name)
  if([string]::IsNullOrWhiteSpace($name)){$name='download.bin'}
  foreach($ch in [IO.Path]::GetInvalidFileNameChars()){$name=$name.Replace([string]$ch,'_')}
  return $name
}

function Invoke-PMMAIIOFetchLink([string]$Id,$Raw,[string]$Evidence){
  $case=Get-PMMAIIOCase $Id
  if(-not[bool](Get-PMMAIIOActionValue $case 'TrustedInbound' $false)){throw 'Network retrieval requires an explicitly trusted inbound file.'}

  $url=[string](Get-PMMAIIOActionValue $Raw 'url' '')
  if(-not$url){$url=[string](Get-PMMAIIOActionValue $Raw 'link' '')}
  if([string]::IsNullOrWhiteSpace($url)){throw 'fetch_link requires url.'}
  $uri=$null
  try{$uri=[Uri]$url}catch{throw 'fetch_link url is invalid.'}
  if($uri.Scheme -notin @('http','https')){throw 'fetch_link only supports http/https URLs.'}

  $fileName=Get-PMMAIIOSafeRemoteFileName $url ([string](Get-PMMAIIOActionValue $Raw 'fileName' ''))
  New-Item -ItemType Directory -Force -Path $Evidence|Out-Null
  $target=Join-Path $Evidence $fileName
  $expected=([string](Get-PMMAIIOActionValue $Raw 'expectedSha256' '')).Trim().ToLowerInvariant()
  $maxRaw=Get-PMMAIIOActionValue $Raw 'maximumExpectedBytes' $null
  [int64]$maxBytes=0
  if($null -ne $maxRaw){try{$maxBytes=[int64]$maxRaw}catch{$maxBytes=0}}

  $request=[System.Net.HttpWebRequest]::Create($uri)
  $request.Method='GET'
  $request.AllowAutoRedirect=$true
  $request.UserAgent='Palworld-Manager-Merger-AIIO/1.3.1'
  $response=$null;$input=$null;$output=$null
  try{
    $response=$request.GetResponse()
    [int64]$total=$response.ContentLength
    if($maxBytes -gt 0 -and $total -gt $maxBytes){throw ('Remote file exceeds requested maximum size: '+$total+' bytes.')}
    $input=$response.GetResponseStream()
    $output=[IO.File]::Open($target,[IO.FileMode]::Create,[IO.FileAccess]::Write,[IO.FileShare]::None)
    $buffer=New-Object byte[] 1048576
    [int64]$received=0
    while(($read=$input.Read($buffer,0,$buffer.Length)) -gt 0){
      $output.Write($buffer,0,$read);$received+=$read
      if($maxBytes -gt 0 -and $received -gt $maxBytes){throw ('Remote file exceeded requested maximum size while downloading: '+$received+' bytes.')}
      if($total -gt 0){
        $pct=[Math]::Min(99,[Math]::Max(0,[int][Math]::Floor(100.0*$received/$total)))
        Set-PMMAIIOCaseProgress $Id $pct 100 ('Downloading '+$fileName+' - '+([Math]::Round($received/1MB,1))+' / '+([Math]::Round($total/1MB,1))+' MiB')
      }else{
        Set-PMMAIIOCaseProgress $Id 0 100 ('Downloading '+$fileName+' - '+([Math]::Round($received/1MB,1))+' MiB') -Indeterminate
      }
    }
  }catch{
    try{if($output){$output.Dispose()}}catch{};try{if($input){$input.Dispose()}}catch{};try{if($response){$response.Dispose()}}catch{}
    Remove-Item -LiteralPath $target -Force -ErrorAction SilentlyContinue
    throw
  }finally{
    try{if($output){$output.Dispose()}}catch{};try{if($input){$input.Dispose()}}catch{};try{if($response){$response.Dispose()}}catch{}
  }

  if(-not(Test-Path -LiteralPath $target -PathType Leaf)){throw 'Remote download did not produce a file.'}
  $info=Get-Item -LiteralPath $target
  $sha=(Get-Sha256 $target).ToLowerInvariant()
  if($expected -and $sha -ne $expected){Remove-Item -LiteralPath $target -Force -ErrorAction SilentlyContinue;throw ('Remote file SHA256 mismatch. Got '+$sha+', expected '+$expected+'.')}
  $meta=Join-Path $Evidence 'download.json'
  Write-PMMAIIOCaseJson $meta ([ordered]@{Schema='PMM_AIIO_REMOTE_FETCH_V1';Url=$url;FileName=$fileName;Size=[int64]$info.Length;Sha256=$sha;Utc=[DateTime]::UtcNow.ToString('o')}) 12
  Set-PMMAIIOCaseProgress $Id 100 100 ('Downloaded '+$fileName+' ('+([Math]::Round($info.Length/1MB,1))+' MiB)') -Completed
  return [pscustomobject]@{Summary=('Downloaded '+$fileName+' from link');Artifacts=@($target,$meta)}
}

function Invoke-PMMAIIOCaseAction([string]$Id,$Action){
  $name=([string](Get-PMMAIIOActionValue $Action 'Action' '')).ToLowerInvariant()
  if($name -in @('fetch_link','fetch_url','download_link','include_link')){
    $raw=Get-PMMAIIOActionValue $Action 'Original' $null
    $actionId=[string](Get-PMMAIIOActionValue $Action 'Id' ([guid]::NewGuid().ToString('N')))
    $root=Join-Path (Get-PMMAIIOCaseEvidencePath $Id) $actionId
    return (Invoke-PMMAIIOFetchLink $Id $raw $root)
  }
  return (& $Script:PMMAIIORemoteBaseAction $Id $Action)
}

function New-PMMAIIOCaseHandoff([string]$Id,[int]$FromStep=0){
  $result=& $Script:PMMAIIORemoteBaseHandoff $Id $FromStep
  $zip=[string]$result.ZipPath
  if(-not(Test-Path -LiteralPath $zip -PathType Leaf)){return $result}
  Add-Type -AssemblyName System.IO.Compression.FileSystem
  $archive=[IO.Compression.ZipFile]::Open($zip,[IO.Compression.ZipArchiveMode]::Update)
  try{
    $old=$archive.GetEntry('capabilities.json');if($old){$old.Delete()}
    $entry=$archive.CreateEntry('capabilities.json',[IO.Compression.CompressionLevel]::Optimal)
    $writer=[IO.StreamWriter]::new($entry.Open(),[Text.UTF8Encoding]::new($false))
    try{
      $cap=[ordered]@{Schema='PMM_AIIO_CASE_CAPABILITIES_V3';WorkOrderSchema=$Script:PMMAIIOWorkOrderSchema;Actions=@('ensure_game_reference','include_game_reference_family','query_game_reference','include_log','include_mod_full','include_mod_family','include_file','fetch_link','run_program','run_command');Transports=@('AUTO','MANUAL_ZIP','AGENT_SERVER','GIT','NEXUS','LINK')}
      $writer.Write(($cap|ConvertTo-Json -Depth 20))
    }finally{$writer.Dispose()}
  }finally{$archive.Dispose()}
  return $result
}
