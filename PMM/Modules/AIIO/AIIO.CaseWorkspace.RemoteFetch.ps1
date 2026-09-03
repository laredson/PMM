<# AIIO remote-fetch capability.
   A work order declares a URL; PMM owns storage, progress, hashing and evidence.
   Work orders never depend on PMM Temp paths. For private GitHub sources PMM
   prefers an existing local checkout and reads the requested ref without
   changing that checkout's branch or working tree. #>

$remoteFetchInstalled=$false
try{
  $existing=Get-Variable -Name PMMAIIORemoteFetchInstalled -Scope Script -ErrorAction Stop
  $remoteFetchInstalled=[bool]$existing.Value
}catch{}
if(-not$remoteFetchInstalled){
  if(-not(Get-Command Invoke-PMMAIIOCaseAction -ErrorAction SilentlyContinue)){throw 'RemoteFetch base action service is unavailable.'}
  if(-not(Get-Command New-PMMAIIOCaseHandoff -ErrorAction SilentlyContinue)){throw 'RemoteFetch base handoff service is unavailable.'}
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

function Get-PMMAIIOGitExecutable {
  $cmd=Get-Command git.exe -ErrorAction SilentlyContinue;if($cmd){return [string]$cmd.Source}
  $cmd=Get-Command git -ErrorAction SilentlyContinue;if($cmd){return [string]$cmd.Source}
  $candidates=[Collections.Generic.List[string]]::new()
  if($env:ProgramFiles){$candidates.Add((Join-Path $env:ProgramFiles 'Git\cmd\git.exe'))}
  $pf86='';try{$pf86=[string]${env:ProgramFiles(x86)}}catch{}
  if($pf86){$candidates.Add((Join-Path $pf86 'Git\cmd\git.exe'))}
  if($env:LOCALAPPDATA){
    $desktopRoot=Join-Path $env:LOCALAPPDATA 'GitHubDesktop'
    foreach($app in @(Get-ChildItem -LiteralPath $desktopRoot -Directory -Filter 'app-*' -ErrorAction SilentlyContinue|Sort-Object LastWriteTime -Descending)){
      $candidates.Add((Join-Path $app.FullName 'resources\app\git\cmd\git.exe'))
      $candidates.Add((Join-Path $app.FullName 'resources\app\git\mingw64\bin\git.exe'))
    }
  }
  foreach($candidate in $candidates){if(Test-Path -LiteralPath $candidate -PathType Leaf){return [string]$candidate}}
  return ''
}

function Invoke-PMMAIIOGit([string]$Git,[array]$Arguments){
  $oldPrompt=$env:GIT_TERMINAL_PROMPT;$env:GIT_TERMINAL_PROMPT='0'
  try{
    $text=@(& $Git @Arguments 2>&1);$code=$LASTEXITCODE
    if($code-ne0){throw (($text|ForEach-Object{[string]$_}) -join [Environment]::NewLine)}
    return @($text)
  }finally{
    if($null-eq$oldPrompt){Remove-Item Env:GIT_TERMINAL_PROMPT -ErrorAction SilentlyContinue}else{$env:GIT_TERMINAL_PROMPT=$oldPrompt}
  }
}

function Get-PMMAIIOGitHubRawDescriptor([Uri]$Uri){
  if(-not$Uri -or $Uri.Host -ine 'raw.githubusercontent.com'){return $null}
  $parts=@($Uri.AbsolutePath.Trim('/') -split '/');if($parts.Count-lt4){return $null}
  $owner=[Uri]::UnescapeDataString([string]$parts[0]);$repo=[Uri]::UnescapeDataString([string]$parts[1]);$ref=[Uri]::UnescapeDataString([string]$parts[2])
  $path=(@($parts[3..($parts.Count-1)]|ForEach-Object{[Uri]::UnescapeDataString([string]$_)}) -join '/')
  if(-not$owner -or -not$repo -or -not$ref -or -not$path){return $null}
  return [pscustomobject]@{Owner=$owner;Repo=$repo;Ref=$ref;Path=$path;RepositoryUrl=('https://github.com/'+$owner+'/'+$repo+'.git')}
}

function Normalize-PMMAIIOGitRemote([string]$Remote){
  $v=([string]$Remote).Trim().Replace('\','/').ToLowerInvariant()
  if($v.EndsWith('.git')){$v=$v.Substring(0,$v.Length-4)}
  $v=$v -replace '^git@github\.com:','https://github.com/'
  $v=$v -replace '^ssh://git@github\.com/','https://github.com/'
  return $v.TrimEnd('/')
}

function Test-PMMAIIOLocalRepository([string]$Git,[string]$Path,$Desc){
  if([string]::IsNullOrWhiteSpace($Path) -or -not(Test-Path -LiteralPath (Join-Path $Path '.git'))){return $false}
  try{
    $remote=@(Invoke-PMMAIIOGit $Git @('-C',$Path,'config','--get','remote.origin.url')|Select-Object -First 1)
    if($remote.Count-eq0){return $false}
    $want=Normalize-PMMAIIOGitRemote ('https://github.com/'+$Desc.Owner+'/'+$Desc.Repo)
    return ((Normalize-PMMAIIOGitRemote ([string]$remote[0])) -eq $want)
  }catch{return $false}
}

function Find-PMMAIIOLocalGitHubRepository([string]$Git,$Desc){
  $candidates=[Collections.Generic.List[string]]::new()
  try{
    $app=[IO.Path]::GetFullPath((Get-PMMPath 'App'))
    $repoRoot=Split-Path -Parent $app
    $container=Split-Path -Parent $repoRoot
    if($container){$candidates.Add((Join-Path $container ([string]$Desc.Repo)))}
  }catch{}
  if($HOME){
    $candidates.Add((Join-Path $HOME ('Documents\GitHub\'+[string]$Desc.Repo)))
    $candidates.Add((Join-Path $HOME ('source\repos\'+[string]$Desc.Repo)))
  }
  if($env:USERPROFILE){
    $candidates.Add((Join-Path $env:USERPROFILE ('Documents\GitHub\'+[string]$Desc.Repo)))
    if($env:OneDrive){$candidates.Add((Join-Path $env:OneDrive ('Documents\GitHub\'+[string]$Desc.Repo)))}
  }
  $seen=[Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
  foreach($candidate in $candidates){
    if([string]::IsNullOrWhiteSpace($candidate)){continue}
    try{$full=[IO.Path]::GetFullPath($candidate)}catch{continue}
    if(-not$seen.Add($full)){continue}
    if(Test-PMMAIIOLocalRepository $Git $full $Desc){return $full}
  }
  return ''
}

function Export-PMMAIIOLocalGitFile([string]$Git,[string]$Repo,$Desc,[string]$Target){
  Add-Type -AssemblyName System.IO.Compression.FileSystem
  $tmp=Join-PMMPath 'Temp' ('AIIO\GitArchive\'+[guid]::NewGuid().ToString('N'))
  New-Item -ItemType Directory -Force -Path $tmp|Out-Null
  $zip=Join-Path $tmp 'one.zip'
  try{
    $refs=@([string]$Desc.Ref,('origin/'+[string]$Desc.Ref),('refs/heads/'+[string]$Desc.Ref),('refs/remotes/origin/'+[string]$Desc.Ref))
    $ok=$false;$last=''
    foreach($ref in $refs){
      try{
        if(Test-Path -LiteralPath $zip){Remove-Item -LiteralPath $zip -Force}
        [void](Invoke-PMMAIIOGit $Git @('-C',$Repo,'archive','--format=zip',('--output='+$zip),$ref,'--',[string]$Desc.Path))
        if(Test-Path -LiteralPath $zip -PathType Leaf){$ok=$true;break}
      }catch{$last=$_.Exception.Message}
    }
    if(-not$ok){
      try{
        [void](Invoke-PMMAIIOGit $Git @('-C',$Repo,'fetch','--depth','1','origin',[string]$Desc.Ref))
        [void](Invoke-PMMAIIOGit $Git @('-C',$Repo,'archive','--format=zip',('--output='+$zip),'FETCH_HEAD','--',[string]$Desc.Path))
        $ok=(Test-Path -LiteralPath $zip -PathType Leaf)
      }catch{$last=$_.Exception.Message}
    }
    if(-not$ok){throw ('Local repository found, but ref/path could not be read: '+$last)}
    $archive=[IO.Compression.ZipFile]::OpenRead($zip)
    try{
      $entry=$archive.Entries|Where-Object{([string]$_.FullName).Replace('\','/') -ceq ([string]$Desc.Path).Replace('\','/')}|Select-Object -First 1
      if(-not$entry){throw ('Git archive did not contain requested path: '+$Desc.Path)}
      $parent=Split-Path -Parent $Target;if($parent){New-Item -ItemType Directory -Force -Path $parent|Out-Null}
      $input=$entry.Open();$output=[IO.File]::Open($Target,[IO.FileMode]::Create,[IO.FileAccess]::Write,[IO.FileShare]::None)
      try{$input.CopyTo($output)}finally{$output.Dispose();$input.Dispose()}
    }finally{$archive.Dispose()}
    return $true
  }finally{Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue}
}

function Copy-PMMAIIOPrivateGitHubRaw([string]$Id,[Uri]$Uri,[string]$Target,[string]$FileName){
  $desc=Get-PMMAIIOGitHubRawDescriptor $Uri;if(-not$desc){return $false}
  $git=Get-PMMAIIOGitExecutable
  if([string]::IsNullOrWhiteSpace($git)){throw 'GitHub source may be private, but PMM could not find git.exe.'}

  $local=Find-PMMAIIOLocalGitHubRepository $git $desc
  if($local){
    Set-PMMAIIOCaseProgress $Id 0 100 ('Reading '+$desc.Owner+'/'+$desc.Repo+' from local Git checkout...') -Indeterminate
    [void](Export-PMMAIIOLocalGitFile $git $local $desc $Target)
    Set-PMMAIIOCaseProgress $Id 99 100 ('Collected '+$FileName+' from local Git checkout.')
    return $true
  }

  $safe=(($desc.Owner+'_'+$desc.Repo+'_'+$desc.Ref)-replace'[^A-Za-z0-9._-]','_')
  $cacheRoot=Join-PMMPath 'Temp' 'AIIO\GitFetch';New-Item -ItemType Directory -Force -Path $cacheRoot|Out-Null
  $repoRoot=Join-Path $cacheRoot $safe
  Set-PMMAIIOCaseProgress $Id 0 100 ('Private GitHub source. Trying authenticated Git transport for '+$desc.Owner+'/'+$desc.Repo+'...') -Indeterminate
  if(-not(Test-Path -LiteralPath (Join-Path $repoRoot '.git') -PathType Container)){
    if(Test-Path -LiteralPath $repoRoot){Remove-Item -LiteralPath $repoRoot -Recurse -Force -ErrorAction SilentlyContinue}
    try{[void](Invoke-PMMAIIOGit $git @('clone','--depth','1','--single-branch','--branch',[string]$desc.Ref,[string]$desc.RepositoryUrl,[string]$repoRoot))}
    catch{throw ('Private GitHub repository '+$desc.Owner+'/'+$desc.Repo+' is not available locally and authenticated Git access failed. Clone it once with GitHub Desktop or configure Git credentials. Details: '+$_.Exception.Message)}
  }
  [void](Export-PMMAIIOLocalGitFile $git $repoRoot $desc $Target)
  Set-PMMAIIOCaseProgress $Id 99 100 ('Collected '+$FileName+' through Git transport.')
  return $true
}

function Invoke-PMMAIIOFetchLink([string]$Id,$Raw,[string]$Evidence){
  $case=Get-PMMAIIOCase $Id
  if(-not[bool](Get-PMMAIIOActionValue $case 'TrustedInbound' $false)){throw 'Network retrieval requires an explicitly trusted inbound file.'}
  $url=[string](Get-PMMAIIOActionValue $Raw 'url' '');if(-not$url){$url=[string](Get-PMMAIIOActionValue $Raw 'link' '')}
  if([string]::IsNullOrWhiteSpace($url)){throw 'fetch_link requires url.'}
  try{$uri=[Uri]$url}catch{throw 'fetch_link url is invalid.'};if($uri.Scheme-notin@('http','https')){throw 'fetch_link only supports http/https URLs.'}
  $fileName=Get-PMMAIIOSafeRemoteFileName $url ([string](Get-PMMAIIOActionValue $Raw 'fileName' ''))
  New-Item -ItemType Directory -Force -Path $Evidence|Out-Null;$target=Join-Path $Evidence $fileName
  $expected=([string](Get-PMMAIIOActionValue $Raw 'expectedSha256' '')).Trim().ToLowerInvariant();[int64]$maxBytes=0
  $maxRaw=Get-PMMAIIOActionValue $Raw 'maximumExpectedBytes' $null;if($null-ne$maxRaw){try{$maxBytes=[int64]$maxRaw}catch{$maxBytes=0}}

  $request=[System.Net.HttpWebRequest]::Create($uri);$request.Method='GET';$request.AllowAutoRedirect=$true;$request.UserAgent='Palworld-Manager-Merger-AIIO/1.3.1'
  $response=$null;$input=$null;$output=$null;$downloaded=$false;$httpError=$null
  try{
    try{
      $response=$request.GetResponse();[int64]$total=$response.ContentLength
      if($maxBytes-gt0 -and $total-gt$maxBytes){throw ('Remote file exceeds requested maximum size: '+$total+' bytes.')}
      $input=$response.GetResponseStream();$output=[IO.File]::Open($target,[IO.FileMode]::Create,[IO.FileAccess]::Write,[IO.FileShare]::None)
      $buffer=New-Object byte[] 1048576;[int64]$received=0
      while(($read=$input.Read($buffer,0,$buffer.Length))-gt0){
        $output.Write($buffer,0,$read);$received+=$read
        if($maxBytes-gt0 -and $received-gt$maxBytes){throw ('Remote file exceeded requested maximum size while downloading: '+$received+' bytes.')}
        if($total-gt0){$pct=[Math]::Min(99,[Math]::Max(0,[int][Math]::Floor(100.0*$received/$total)));Set-PMMAIIOCaseProgress $Id $pct 100 ('Downloading '+$fileName+' - '+([Math]::Round($received/1MB,1))+' / '+([Math]::Round($total/1MB,1))+' MiB')}
        else{Set-PMMAIIOCaseProgress $Id 0 100 ('Downloading '+$fileName+' - '+([Math]::Round($received/1MB,1))+' MiB') -Indeterminate}
      }
      $downloaded=$true
    }catch{$httpError=$_.Exception}
    finally{
      try{if($output){$output.Dispose()}}catch{};$output=$null
      try{if($input){$input.Dispose()}}catch{};$input=$null
      try{if($response){$response.Dispose()}}catch{};$response=$null
    }
    if(-not$downloaded){
      Remove-Item -LiteralPath $target -Force -ErrorAction SilentlyContinue
      $gitFallback=Copy-PMMAIIOPrivateGitHubRaw $Id $uri $target $fileName
      if(-not$gitFallback){throw $httpError};$downloaded=$true
    }
  }catch{Remove-Item -LiteralPath $target -Force -ErrorAction SilentlyContinue;throw}

  if(-not(Test-Path -LiteralPath $target -PathType Leaf)){throw 'Remote download did not produce a file.'}
  $info=Get-Item -LiteralPath $target;if($maxBytes-gt0 -and [int64]$info.Length-gt$maxBytes){Remove-Item -LiteralPath $target -Force -ErrorAction SilentlyContinue;throw ('Remote file exceeds requested maximum size: '+$info.Length+' bytes.')}
  $sha=(Get-Sha256 $target).ToLowerInvariant();if($expected -and $sha-ne$expected){Remove-Item -LiteralPath $target -Force -ErrorAction SilentlyContinue;throw ('Remote file SHA256 mismatch. Got '+$sha+', expected '+$expected+'.')}
  $meta=Join-Path $Evidence 'download.json';Write-PMMAIIOCaseJson $meta ([ordered]@{Schema='PMM_AIIO_REMOTE_FETCH_V1';Url=$url;FileName=$fileName;Size=[int64]$info.Length;Sha256=$sha;Utc=[DateTime]::UtcNow.ToString('o')}) 12
  Set-PMMAIIOCaseProgress $Id 100 100 ('Collected '+$fileName+' ('+([Math]::Round($info.Length/1MB,1))+' MiB)') -Completed
  return [pscustomobject]@{Summary=('Collected '+$fileName+' from link/source');Artifacts=@($target,$meta)}
}

function Invoke-PMMAIIOCaseAction([string]$Id,$Action){
  $name=([string](Get-PMMAIIOActionValue $Action 'Action' '')).ToLowerInvariant()
  if($name-in@('fetch_link','fetch_url','download_link','include_link')){
    $raw=Get-PMMAIIOActionValue $Action 'Original' $null;$actionId=[string](Get-PMMAIIOActionValue $Action 'Id' ([guid]::NewGuid().ToString('N')))
    return (Invoke-PMMAIIOFetchLink $Id $raw (Join-Path (Get-PMMAIIOCaseEvidencePath $Id) $actionId))
  }
  return (& $Script:PMMAIIORemoteBaseAction $Id $Action)
}

function New-PMMAIIOCaseHandoff([string]$Id,[int]$FromStep=0){
  $result=& $Script:PMMAIIORemoteBaseHandoff $Id $FromStep;$zip=[string]$result.ZipPath;if(-not(Test-Path -LiteralPath $zip -PathType Leaf)){return$result}
  Add-Type -AssemblyName System.IO.Compression.FileSystem;$archive=[IO.Compression.ZipFile]::Open($zip,[IO.Compression.ZipArchiveMode]::Update)
  try{
    $old=$archive.GetEntry('capabilities.json');if($old){$old.Delete()};$entry=$archive.CreateEntry('capabilities.json',[IO.Compression.CompressionLevel]::Optimal);$writer=[IO.StreamWriter]::new($entry.Open(),[Text.UTF8Encoding]::new($false))
    try{$writer.Write(([ordered]@{Schema='PMM_AIIO_CASE_CAPABILITIES_V3';WorkOrderSchema=$Script:PMMAIIOWorkOrderSchema;Actions=@('ensure_game_reference','include_game_reference_family','query_game_reference','include_log','include_mod_full','include_mod_family','include_file','fetch_link','run_program','run_command');Transports=@('AUTO','MANUAL_ZIP','AGENT_SERVER','GIT','NEXUS','LINK')}|ConvertTo-Json -Depth 20))}finally{$writer.Dispose()}
  }finally{$archive.Dispose()};return$result
}
