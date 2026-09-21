Set-StrictMode -Version 2
function Get-PMMNexusCredentialPath { Join-PMMPath 'State' 'nexus-credential.txt' }
function Get-PMMNexusAccountPath { Join-PMMPath 'State' 'nexus-account.json' }
function ConvertFrom-PMMSecureString([Security.SecureString]$Value) {
  if(-not$Value){return ''}
  $handle=[Runtime.InteropServices.Marshal]::SecureStringToBSTR($Value)
  try{return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($handle)}
  finally{[Runtime.InteropServices.Marshal]::ZeroFreeBSTR($handle)}
}
function Get-PMMNexusCredential {
  $path=Get-PMMNexusCredentialPath
  if(-not(Test-Path $path -PathType Leaf)){return ''}
  try{return ConvertFrom-PMMSecureString (ConvertTo-SecureString ([IO.File]::ReadAllText($path)))}
  catch{throw 'NEXUS_CREDENTIAL_UNREADABLE'}
}
function Set-PMMNexusCredential([Security.SecureString]$Key) {
  if(-not$Key){throw 'A Nexus API key is required.'}
  $plain=ConvertFrom-PMMSecureString $Key
  if($plain.Length -lt 20 -or $plain.Length -gt 256){throw 'The Nexus API key has an invalid length.'}
  $path=Get-PMMNexusCredentialPath
  [void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($path))
  $temp=$path+'.'+[Guid]::NewGuid().ToString('N')+'.tmp'
  try{
    [IO.File]::WriteAllText($temp,(ConvertFrom-SecureString $Key),[Text.UTF8Encoding]::new($false))
    if(Test-Path $path){[IO.File]::Replace($temp,$path,[NullString]::Value,$true)}else{[IO.File]::Move($temp,$path)}
  }finally{if(Test-Path $temp){Remove-Item $temp -Force}}
}
function Disconnect-PMMNexusAccount {
  foreach($path in @((Get-PMMNexusCredentialPath),(Get-PMMNexusAccountPath))){if(Test-Path $path){Remove-Item $path -Force}}
}
function Get-PMMNexusHeaders {
  $key=[Environment]::GetEnvironmentVariable('PMM_NEXUS_API_KEY')
  if(-not$key){$key=Get-PMMNexusCredential}
  if(-not$key){throw 'AUTHENTICATION_REQUIRED'}
  @{'Accept'='application/json';'User-Agent'='PMM/1.5.0.1';'Application-Name'='PMM';'Application-Version'='1.5.0.1';'apikey'=$key}
}
function Get-PMMNexusFailureCode($Exception) {
  $response=Get-PMMAnalysisValue $Exception 'Response' $null
  if(-not$response){return 'NEXUS_UNAVAILABLE'}
  switch([int](Get-PMMAnalysisValue $response 'StatusCode' 0)){401{'NEXUS_UNAUTHORIZED'}403{'NEXUS_FORBIDDEN'}429{'NEXUS_RATE_LIMITED'}default{'NEXUS_UNAVAILABLE'}}
}
function Invoke-PMMNexusRequest([string]$Path,[hashtable]$Query) {
  if($Path -notmatch '^/[A-Za-z0-9_./-]+$' -or $Path.Contains('..')){throw 'Invalid Nexus API path.'}
  $backoffPath=Join-PMMPath 'State' 'nexus-backoff.json'
  if(Test-Path $backoffPath){try{$backoff=Read-PMMJsonFile $backoffPath -Schema PMM_NEXUS_BACKOFF_V1;if([DateTime]$backoff.RetryUtc -gt [DateTime]::UtcNow){throw 'NEXUS_RATE_LIMITED'}}catch{if($_.Exception.Message -eq 'NEXUS_RATE_LIMITED'){throw}}}
  $uri='https://api.nexusmods.com/v1'+$Path
  if($Query){$pairs=@();foreach($name in @($Query.Keys|Sort-Object)){$pairs+=([Uri]::EscapeDataString($name)+'='+[Uri]::EscapeDataString([string]$Query[$name]))};$uri+='?'+($pairs -join '&')}
  $cacheable=(-not$Query -and $Path -notmatch 'download_link|users/validate');$cache=''
  if($cacheable){$root=Join-PMMPath 'Cache' 'Nexus';[void][IO.Directory]::CreateDirectory($root);$cache=Join-Path $root ((Get-PMMAnalysisHash $Path)+'.json');if(Test-Path $cache){try{$saved=Read-PMMJsonFile $cache -Schema PMM_NEXUS_CACHE_V1;if(([DateTime]$saved.ExpiresUtc) -gt [DateTime]::UtcNow){return $saved.Value}}catch{}}}
  try{
    $response=Invoke-WebRequest -UseBasicParsing -Uri $uri -Headers (Get-PMMNexusHeaders) -Method Get -TimeoutSec 30 -ErrorAction Stop
    Write-PMMJsonAtomic (Join-PMMPath 'State' 'nexus-limits.json') ([ordered]@{Schema='PMM_NEXUS_LIMITS_V1';HourlyRemaining=[string]$response.Headers['x-rl-hourly-remaining'];DailyRemaining=[string]$response.Headers['x-rl-daily-remaining'];ObservedUtc=[DateTime]::UtcNow.ToString('o')})
    $value=if($response.Content){$response.Content|ConvertFrom-Json}else{$null}
    if($cacheable){Write-PMMJsonAtomic $cache ([ordered]@{Schema='PMM_NEXUS_CACHE_V1';CreatedUtc=[DateTime]::UtcNow.ToString('o');ExpiresUtc=[DateTime]::UtcNow.AddMinutes(10).ToString('o');Value=$value}) -Depth 30}
    return $value
  }catch{
    $code=Get-PMMNexusFailureCode $_.Exception
    if($code -eq 'NEXUS_RATE_LIMITED'){Write-PMMJsonAtomic $backoffPath ([ordered]@{Schema='PMM_NEXUS_BACKOFF_V1';RetryUtc=[DateTime]::UtcNow.AddMinutes(1).ToString('o')})}
    if($code -eq 'NEXUS_UNAVAILABLE' -and $cache -and (Test-Path $cache)){try{$saved=Read-PMMJsonFile $cache -Schema PMM_NEXUS_CACHE_V1;if(([DateTime]$saved.CreatedUtc) -gt [DateTime]::UtcNow.AddHours(-24)){return $saved.Value}}catch{}}
    throw [InvalidOperationException]::new($code)
  }
}
function Connect-PMMNexusAccount([Security.SecureString]$Key) {
  Set-PMMNexusCredential $Key
  try{
    $user=Invoke-PMMNexusRequest '/users/validate.json'
    $account=[ordered]@{Schema='PMM_NEXUS_ACCOUNT_V1';UserId=[string](Get-PMMAnalysisValue $user 'user_id' '');Name=[string](Get-PMMAnalysisValue $user 'name' '');IsPremium=[bool](Get-PMMAnalysisValue $user 'is_premium' $false);IsSupporter=[bool](Get-PMMAnalysisValue $user 'is_supporter' $false);ValidatedUtc=[DateTime]::UtcNow.ToString('o')}
    Write-PMMJsonAtomic (Get-PMMNexusAccountPath) $account
    [pscustomobject]$account
  }catch{Disconnect-PMMNexusAccount;throw}
}
function Get-PMMNexusAccount {
  $path=Get-PMMNexusAccountPath
  if(Test-Path $path){try{return Read-PMMJsonFile $path -Schema PMM_NEXUS_ACCOUNT_V1}catch{}}
  $null
}
function Get-PMMNexusLimits {
  $path=Join-PMMPath 'State' 'nexus-limits.json'
  if(Test-Path $path){try{return Read-PMMJsonFile $path -Schema PMM_NEXUS_LIMITS_V1}catch{}}
  $null
}
function Get-PMMNexusSsoRegistration {
  [pscustomobject]@{Available=$false;Reason='PMM must be registered with Nexus before public SSO can be enabled.'}
}
function ConvertFrom-PMMNexusModUrl([string]$Url) {
  $uri=$null
  if(-not[Uri]::TryCreate($Url,[UriKind]::Absolute,[ref]$uri) -or $uri.Scheme -ne 'https' -or $uri.Host -notin @('www.nexusmods.com','nexusmods.com')){throw 'Only Nexus Mods HTTPS URLs are accepted.'}
  if($uri.AbsolutePath -notmatch '^/palworld/mods/(\d+)/?$'){throw 'The URL must point to a Palworld mod.'}
  $modId=$matches[1];$fileId=''
  foreach($pair in $uri.Query.TrimStart('?').Split('&')){$parts=$pair.Split('=',2);if($parts.Count -eq 2 -and $parts[0] -eq 'file_id' -and $parts[1] -match '^\d+$'){$fileId=$parts[1]}}
  [pscustomobject]@{Game='palworld';ModId=$modId;FileId=$fileId;SourceUrl=('https://www.nexusmods.com/palworld/mods/'+$modId)}
}
function ConvertFrom-PMMNxmUri([string]$Value) {
  if([string]::IsNullOrWhiteSpace($Value) -or $Value.Length -gt 4096){throw 'Invalid NXM request.'}
  $uri=$null
  if(-not[Uri]::TryCreate($Value,[UriKind]::Absolute,[ref]$uri) -or $uri.Scheme -ne 'nxm' -or $uri.Host -ne 'palworld' -or $uri.AbsolutePath -notmatch '^/mods/(\d+)/files/(\d+)$'){throw 'The NXM request is not for Palworld.'}
  $modId=$matches[1];$fileId=$matches[2];$values=@{}
  foreach($pair in $uri.Query.TrimStart('?').Split('&')){$parts=$pair.Split('=',2);if($parts.Count -eq 2){if($values.ContainsKey($parts[0])){throw 'The NXM request repeats a query field.'};$values[$parts[0]]=[Uri]::UnescapeDataString($parts[1])}}
  if([string]$values.key -notmatch '^[A-Za-z0-9_-]{8,512}$' -or [string]$values.expires -notmatch '^\d{9,13}$'){throw 'The NXM request lacks a valid key or expiry.'}
  $expires=[long]$values.expires;if($expires -gt 9999999999){$expires=[long]($expires/1000)}
  $now=[DateTimeOffset]::UtcNow.ToUnixTimeSeconds();if($expires -lt $now -or $expires -gt ($now+86400)){throw 'The NXM request is expired.'}
  [pscustomobject]@{Schema='PMM_NXM_REQUEST_V1';Game='palworld';ModId=$modId;FileId=$fileId;Key=[string]$values.key;Expires=$expires;ReceivedUtc=[DateTime]::UtcNow.ToString('o')}
}
function Protect-PMMNxmRequest($Request) { ConvertFrom-SecureString (ConvertTo-SecureString (($Request|ConvertTo-Json -Compress)) -AsPlainText -Force) }
function Unprotect-PMMNxmRequest([string]$Encrypted) {
  $request=(ConvertFrom-PMMSecureString (ConvertTo-SecureString $Encrypted))|ConvertFrom-Json
  if($request.Schema -ne 'PMM_NXM_REQUEST_V1'){throw 'Unsupported NXM request.'}
  $request
}
function Get-PMMNexusDownloadLinks([string]$ModId,[string]$FileId,$NxmRequest) {
  if($ModId -notmatch '^\d+$' -or $FileId -notmatch '^\d+$'){throw 'Invalid Nexus file identity.'}
  $query=$null
  if($NxmRequest){
    if([string]$NxmRequest.ModId -ne $ModId -or [string]$NxmRequest.FileId -ne $FileId -or [long]$NxmRequest.Expires -lt [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()){throw 'The NXM request does not match the pending update.'}
    $query=@{key=[string]$NxmRequest.Key;expires=[string]$NxmRequest.Expires}
  }
  @(Invoke-PMMNexusRequest ('/games/palworld/mods/'+$ModId+'/files/'+$FileId+'/download_link.json') $query)
}

function Get-PMMNxmHandlerState {
  $key='Registry::HKEY_CURRENT_USER\Software\Classes\nxm\shell\open\command'
  $current='';if(Test-Path $key){$current=[string](Get-Item $key).GetValue('')}
  $handler=Join-Path $Script:Root 'Modules\Analysis\Nxm.Handler.ps1'
  [pscustomobject]@{Enabled=($current -and $current.IndexOf($handler,[StringComparison]::OrdinalIgnoreCase) -ge 0);CurrentCommand=$current;ExpectedHandler=$handler}
}
function Enable-PMMNxmHandler {
  $state=Get-PMMNxmHandlerState;if($state.Enabled){return $state}
  $backup=Join-PMMPath 'State' 'nxm-handler-backup.json'
  Write-PMMJsonAtomic $backup ([ordered]@{Schema='PMM_NXM_HANDLER_BACKUP_V1';PreviousCommand=$state.CurrentCommand;SavedUtc=[DateTime]::UtcNow.ToString('o')})
  $key='Registry::HKEY_CURRENT_USER\Software\Classes\nxm';[void](New-Item $key -Force);Set-Item -Path $key -Value 'URL:NXM Protocol';Set-ItemProperty $key 'URL Protocol' ''
  $commandKey=Join-Path $key 'shell\open\command';[void](New-Item $commandKey -Force)
  $powershell=Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe';$handler=Join-Path $Script:Root 'Modules\Analysis\Nxm.Handler.ps1'
  Set-Item -Path $commandKey -Value ('"'+$powershell+'" -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "'+$handler+'" "%1"')
  Get-PMMNxmHandlerState
}
function Disable-PMMNxmHandler {
  $state=Get-PMMNxmHandlerState;if(-not$state.Enabled){return $state}
  $backup=Join-PMMPath 'State' 'nxm-handler-backup.json';$previous=''
  if(Test-Path $backup){try{$previous=[string](Read-PMMJsonFile $backup -Schema PMM_NXM_HANDLER_BACKUP_V1).PreviousCommand}catch{}}
  $commandKey='Registry::HKEY_CURRENT_USER\Software\Classes\nxm\shell\open\command'
  if($previous){[void](New-Item $commandKey -Force);Set-Item -Path $commandKey -Value $previous}else{Remove-Item 'Registry::HKEY_CURRENT_USER\Software\Classes\nxm' -Recurse -Force}
  if(Test-Path $backup){Remove-Item $backup -Force};Get-PMMNxmHandlerState
}
function Test-PMMNxmQueueMatch([string]$ModId,[string]$FileId) {
  $root=Join-PMMPath 'State' 'IncomingNxm';if(-not(Test-Path $root)){return $false}
  foreach($file in @(Get-ChildItem $root -Filter *.nxmq -File -ErrorAction SilentlyContinue)){
    try{$request=Unprotect-PMMNxmRequest ([IO.File]::ReadAllText($file.FullName));if([string]$request.ModId -eq $ModId -and [string]$request.FileId -eq $FileId -and [long]$request.Expires -ge [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()){return $true}}catch{}
  }
  return $false
}
function Receive-PMMNxmQueue([string]$ModId='',[string]$FileId='') {
  $root=Join-PMMPath 'State' 'IncomingNxm';if(-not(Test-Path $root)){return @()}
  $result=[Collections.Generic.List[object]]::new()
  foreach($file in @(Get-ChildItem $root -Filter *.nxmq -File|Sort-Object Name)){
    $consume=$false
    try{$request=Unprotect-PMMNxmRequest ([IO.File]::ReadAllText($file.FullName));$consume=((-not$ModId -or $request.ModId -eq $ModId) -and (-not$FileId -or $request.FileId -eq $FileId));if($consume -and [long]$request.Expires -ge [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()){$result.Add($request)}}catch{$consume=$true;Write-PMMLog ('Discarded an unreadable encrypted NXM queue record: '+$file.Name)}finally{if($consume){Remove-Item $file.FullName -Force}}
  }
  $result.ToArray()
}