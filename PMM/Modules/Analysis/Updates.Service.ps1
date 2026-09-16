function Get-PMMModOriginPath([string]$Hash) {
  if($Hash -notmatch '^[a-f0-9]{64}$'){throw 'A full source SHA256 is required.'}
  return (Join-PMMPath 'State' ('ModOrigins/'+$Hash+'.json'))
}
function Get-PMMModOrigin($Mod) {
  $path=Get-PMMModOriginPath $Mod.Hash
  if(Test-Path -LiteralPath $path){return (Read-PMMJsonFile $path -Schema PMM_MOD_ORIGIN_V1)}
  $source='';$meta=Join-Path ([IO.Path]::GetDirectoryName($Mod.Path)) 'metadata.json'
  if(Test-Path -LiteralPath $meta){try{$source=[string](Get-PMMAnalysisValue (Read-PMMJsonFile $meta) 'Source' '')}catch{}}
  $origin=[pscustomobject]@{Schema='PMM_MOD_ORIGIN_V1';LocalSha256=$Mod.Hash;Name=$Mod.Name;Provider='Unknown';SourceUrl='';Game='palworld';ModId='';FileId='';Repository='';ReleaseTag='';AssetName='';Variant='';Version='';IdentityStatus='Unknown';ArchivePath=$source;ArchiveSha256='';ArchiveMd5='';LocalContents=@();UpdatedUtc=[DateTime]::UtcNow.ToString('o')}
  if(Test-Path -LiteralPath $meta){
    $metadata=Read-PMMJsonFile $meta
    if((Get-PMMAnalysisValue $metadata ContentSha256 '') -ceq $Mod.Hash -and (Get-PMMAnalysisValue $metadata ArchiveSha256 '') -match '^[a-f0-9]{64}$' -and (Get-PMMAnalysisValue $metadata ArchiveMd5 '') -match '^[a-f0-9]{32}$'){
      $origin.ArchiveSha256=$metadata.ArchiveSha256;$origin.ArchiveMd5=$metadata.ArchiveMd5
      $origin.LocalContents=@(@{Path=$metadata.ContentPath;Sha256=$Mod.Hash;Proof='ImportSnapshot'})
    }
  }
  # MD5 identifies downloaded archives with Nexus, not arbitrary extracted PAKs.
  if($source -and [IO.Path]::GetExtension($source) -in @('.zip','.7z','.rar') -and (Test-Path -LiteralPath $source -PathType Leaf)){
    $proof=Get-PMMArchiveContentProof $source $Mod.Hash
    if($proof){$origin.ArchiveSha256=$proof.ArchiveSha256;$origin.ArchiveMd5=$proof.ArchiveMd5;$origin.LocalContents=@($proof.Content)}
  }
  Write-PMMJsonAtomic $path $origin -Schema PMM_MOD_ORIGIN_V1
  return $origin
}
function Set-PMMModOrigin($Mod,$Origin) {
  if((Get-Sha256 $Mod.Path) -cne $Mod.Hash){throw 'The mod changed while its origin was being linked.'}
  if($Origin.Provider -notin @('Nexus','GitHub')){throw 'Unsupported update provider.'}
  if($Origin.Provider -eq 'Nexus' -and ($Origin.ModId -notmatch '^\d+$' -or $Origin.FileId -notmatch '^\d+$')){throw 'Nexus requires exact mod and file identifiers.'}
  if($Origin.Provider -eq 'GitHub' -and ($Origin.Repository -notmatch '^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$' -or -not$Origin.AssetName -or -not$Origin.ReleaseTag)){throw 'GitHub requires repository, installed release tag and exact variant asset name.'}
  $Origin.LocalSha256=$Mod.Hash;$Origin.IdentityStatus='UserLinked'
  Write-PMMJsonAtomic (Get-PMMModOriginPath $Mod.Hash) $Origin -Schema PMM_MOD_ORIGIN_V1
}
function Get-PMMUpdateHeaders([string]$Provider) {
  $headers=@{'User-Agent'='PMM/1.3.3';Accept='application/json'}
  if($Provider -eq 'Nexus'){
    $key=[Environment]::GetEnvironmentVariable('PMM_NEXUS_API_KEY')
    $secretPath=Join-PMMPath 'State' 'nexus-credential.txt'
    if(-not$key -and (Test-Path -LiteralPath $secretPath)){
      $secret=ConvertTo-SecureString ([IO.File]::ReadAllText($secretPath))
      $handle=[Runtime.InteropServices.Marshal]::SecureStringToBSTR($secret)
      try{$key=[Runtime.InteropServices.Marshal]::PtrToStringBSTR($handle)}finally{[Runtime.InteropServices.Marshal]::ZeroFreeBSTR($handle)}
    }
    if(-not$key){throw 'AUTHENTICATION_REQUIRED'}
    $headers['apikey']=$key;$headers['Application-Name']='PMM';$headers['Application-Version']='1.3.3'
  }
  return $headers
}
function Set-PMMNexusCredential([Security.SecureString]$Key) {
  $encrypted=ConvertFrom-SecureString $Key
  $path=Join-PMMPath 'State' 'nexus-credential.txt'
  [IO.File]::WriteAllText($path,$encrypted,[Text.UTF8Encoding]::new($false))
}
function Invoke-PMMUpdateRequest([string]$Url,[string]$Provider) {
  $uri=[Uri]$Url
  if($uri.Scheme -ne 'https' -or $uri.Host -notin @('api.nexusmods.com','api.github.com')){throw 'Unrecognized metadata endpoint.'}
  return (Invoke-RestMethod -Uri $uri -Headers (Get-PMMUpdateHeaders $Provider) -Method Get -TimeoutSec 25 -ErrorAction Stop)
}
function Resolve-PMMNexusOrigin($Mod,$Origin) {
  if($Origin.IdentityStatus -ne 'Unknown' -or -not$Origin.ArchiveMd5){return $Origin}
  $proof=Get-PMMArchiveContentProof $Origin.ArchivePath $Mod.Hash
  $captured=@($Origin.LocalContents|Where-Object{(Get-PMMAnalysisValue $_ Proof '') -eq 'ImportSnapshot' -and $_.Sha256 -ceq $Mod.Hash})
  if(-not$captured.Count -and (-not$proof -or $proof.ArchiveSha256 -cne $Origin.ArchiveSha256)){return $Origin}
  $matches=@(Invoke-PMMUpdateRequest ('https://api.nexusmods.com/v1/games/palworld/mods/md5_search/'+$Origin.ArchiveMd5+'.json') Nexus)
  if($matches.Count -ne 1){return $Origin}
  $match=$matches[0];$file=$match.file_details
  $Origin.Provider='Nexus';$Origin.ModId=[string]$match.mod.mod_id;$Origin.FileId=[string]$file.file_id
  $Origin.Version=[string]$file.version;$Origin.Variant=[string]$file.name;$Origin.SourceUrl='https://www.nexusmods.com/palworld/mods/'+$Origin.ModId
  # Exact inner bytes and the archive hash bind this PAK to the provider result.
  $Origin.IdentityStatus='ArchiveHashMatched'
  Write-PMMJsonAtomic (Get-PMMModOriginPath $Mod.Hash) $Origin -Schema PMM_MOD_ORIGIN_V1
  return $Origin
}
function New-PMMUpdateResult($Mod,$Origin,[string]$Status,[string]$Message,$Candidate=$null) {
  return [pscustomobject]@{Schema='PMM_MOD_UPDATE_V1';LocalSha256=$Mod.Hash;Mod=$Mod.Name;Origin=$Origin;Status=$Status;Message=$Message;Candidate=$Candidate;CheckedUtc=[DateTime]::UtcNow.ToString('o');CompatibilityProven=$false;RequirementsStatus='ReviewRequired';RequirementsEvidence=$(if($Candidate){[string]$Candidate.Changes}else{''})}
}
function Resolve-PMMUpdateResult($Mod,$Origin,$Response) {
  if($Origin.IdentityStatus -eq 'Unknown'){return (New-PMMUpdateResult $Mod $Origin UNKNOWN 'Identify the installed archive and variant before comparing versions.')}
  if($Origin.Provider -eq 'Nexus'){
    $files=@($Response.files);$id=[string]$Origin.FileId;$seen=@{};$changed=$false
    while($true){
      if($seen.ContainsKey($id)){return (New-PMMUpdateResult $Mod $Origin UNKNOWN 'The provider update chain contains a cycle.')}
      $seen[$id]=$true
      $next=@($Response.file_updates|Where-Object{[string]$_.old_file_id -eq $id}|Select-Object -ExpandProperty new_file_id -Unique)
      if($next.Count -gt 1){return (New-PMMUpdateResult $Mod $Origin VARIANT_AMBIGUOUS 'Several successors exist for the installed variant.')}
      if($next.Count -eq 0){break};$id=[string]$next[0];$changed=$true
    }
    if(-not$changed){return (New-PMMUpdateResult $Mod $Origin NO_KNOWN_UPDATE 'No newer file is linked to this installed variant.')}
    $file=@($files|Where-Object{[string]$_.file_id -eq $id})
    if($file.Count -ne 1 -or [string]$file[0].category_name -in @('DELETED','ARCHIVED')){return (New-PMMUpdateResult $Mod $Origin UNAVAILABLE 'The linked successor is unavailable.')}
    $candidate=[pscustomobject]@{Provider='Nexus';FileId=$id;Version=[string]$file[0].version;AssetName=[string]$file[0].file_name;Url=('https://www.nexusmods.com/palworld/mods/'+$Origin.ModId+'?tab=files&file_id='+$id);Sha256='';Changes=[string](Get-PMMAnalysisValue $file[0] 'changelog_html' '');Variant=$Origin.Variant}
    return (New-PMMUpdateResult $Mod $Origin UPDATE_AVAILABLE 'The author linked a newer file to the installed variant. Compatibility still needs validation.' $candidate)
  }
  if($Origin.Provider -eq 'GitHub'){
    $releases=@($Response|Where-Object{-not$_.draft -and -not$_.prerelease})
    $current=@($releases|Where-Object{[string]$_.tag_name -ceq $Origin.ReleaseTag})
    if($current.Count -ne 1){return (New-PMMUpdateResult $Mod $Origin UNKNOWN 'The installed release was not found in the fetched release history.')}
    $installedVersion=$null
    if(-not[version]::TryParse(([string]$Origin.ReleaseTag -replace '^v',''),[ref]$installedVersion)){return (New-PMMUpdateResult $Mod $Origin UNKNOWN 'The release version cannot be compared reliably.')}
    $eligible=@(foreach($release in $releases){$version=$null;if([version]::TryParse(([string]$release.tag_name -replace '^v',''),[ref]$version) -and $version -gt $installedVersion -and [DateTime]$release.published_at -gt [DateTime]$current[0].published_at){$assets=@($release.assets|Where-Object{[string]$_.name -ceq $Origin.AssetName});if($assets.Count -eq 1){[pscustomobject]@{Release=$release;Asset=$assets[0];Version=$version}}}})
    if(-not$eligible.Count){return (New-PMMUpdateResult $Mod $Origin NO_KNOWN_UPDATE 'No newer stable release with the exact variant asset was found.')}
    $selected=@($eligible|Sort-Object Version -Descending)[0];$digest=[string](Get-PMMAnalysisValue $selected.Asset digest '')
    $candidate=[pscustomobject]@{Provider='GitHub';FileId=[string]$selected.Asset.id;Version=[string]$selected.Release.tag_name;AssetName=[string]$selected.Asset.name;Url=[string]$selected.Asset.browser_download_url;Sha256=$(if($digest -match '^sha256:([a-f0-9]{64})$'){$matches[1]}else{''});Changes=[string]$selected.Release.body;Variant=$Origin.Variant}
    return (New-PMMUpdateResult $Mod $Origin UPDATE_AVAILABLE 'A newer stable release contains the same variant. Compatibility still needs validation.' $candidate)
  }
  return (New-PMMUpdateResult $Mod $Origin UNKNOWN 'No supported update source is linked.')
}
function Find-PMMModUpdate($Mod) {
  $origin=$null
  try{
    $origin=Get-PMMModOrigin $Mod
    if($origin.IdentityStatus -eq 'Unknown' -and $origin.ArchiveMd5){$origin=Resolve-PMMNexusOrigin $Mod $origin}
    if($origin.IdentityStatus -eq 'Unknown'){return (New-PMMUpdateResult $Mod $origin UNKNOWN 'Link the exact source and variant; file names alone do not identify updates.')}
    $url=if($origin.Provider -eq 'Nexus'){'https://api.nexusmods.com/v1/games/palworld/mods/'+$origin.ModId+'/files.json'}else{'https://api.github.com/repos/'+$origin.Repository+'/releases?per_page=100'}
    return (Resolve-PMMUpdateResult $Mod $origin (Invoke-PMMUpdateRequest $url $origin.Provider))
  }catch{
    $status=if($_.Exception.Message -eq 'AUTHENTICATION_REQUIRED'){'AUTHENTICATION_REQUIRED'}elseif((Get-PMMAnalysisValue $_.Exception Response $null) -and [int]$_.Exception.Response.StatusCode -in @(403,429)){'PROVIDER_LIMIT'}else{'UNAVAILABLE'}
    return (New-PMMUpdateResult $Mod $origin $status 'The update source could not be checked. Review connection, authentication or provider limits.')
  }
}
function Save-PMMUpdateDownload($Update,[string]$CaseId,[string]$EvidenceRevision,[string]$AuthorizationId) {
  Assert-PMMRepairAuthorization $AuthorizationId $CaseId $EvidenceRevision 'Download'|Out-Null
  if($Update.Status -ne 'UPDATE_AVAILABLE'){throw 'No verified variant successor was selected.'}
  $mod=Find-PMMLibraryMod $Update.Mod
  if(-not$mod -or (Get-Sha256 $mod.Path) -ne $Update.LocalSha256){throw 'The installed source changed; analyze again.'}
  $url=$Update.Candidate.Url
  if($Update.Candidate.Provider -eq 'Nexus'){
    $links=@(Invoke-PMMUpdateRequest ('https://api.nexusmods.com/v1/games/palworld/mods/'+$Update.Origin.ModId+'/files/'+$Update.Candidate.FileId+'/download_link.json') Nexus)
    if(-not$links.Count){throw 'Download requires action on the provider website.'};$url=[string]$links[0].URI
  }
  $uri=[Uri]$url
  if($uri.Scheme -ne 'https' -or ($uri.Host -notmatch '(^|\.)nexusmods\.com$|(^|\.)github\.com$|(^|\.)githubusercontent\.com$')){throw 'Download host is not a supported provider.'}
  $root=Join-Path (Get-PMMRepairSessionRoot $AuthorizationId) 'Downloads'
  [void][IO.Directory]::CreateDirectory($root)
  $leaf=[IO.Path]::GetFileName([string]$Update.Candidate.AssetName)
  if($leaf -notmatch '\.(zip|7z|rar|pak)$'){throw 'This update format needs an import adapter.'}
  $path=Join-Path $root ($Update.Candidate.FileId+'-'+$leaf)
  if([string]$Update.Candidate.FileId -notmatch '^\d+$'){throw 'Provider file identity must be numeric.'}
  $part=$path+'.part';$ownedDownload=$false
  try{
    Receive-PMMUpdateBytes $uri $part $AuthorizationId
    $ownedDownload=$true
    $hash=Get-Sha256 $part
    if($Update.Candidate.Sha256 -and $hash -ne $Update.Candidate.Sha256){throw 'Provider archive checksum mismatch.'}
    if([IO.File]::Exists($path)){if((Get-Sha256 $path) -ne $hash){throw 'An existing staged update has different bytes.'};[IO.File]::Delete($part)}else{[IO.File]::Move($part,$path)}
    $record=[pscustomobject]@{Schema='PMM_STAGED_UPDATE_V1';CaseId=$CaseId;EvidenceRevision=$EvidenceRevision;OriginalSha256=$Update.LocalSha256;Path=$path;Sha256=$hash;Update=$Update;Status='STAGED_REANALYSIS_REQUIRED';Applied=$false}
    Write-PMMJsonAtomic ($path+'.json') $record;return $record
  }finally{if($ownedDownload -and [IO.File]::Exists($part)){[IO.File]::Delete($part)}}
}
