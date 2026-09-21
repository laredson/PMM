param([Parameter(Mandatory=$true)][string]$Uri)
$ErrorActionPreference='Stop'
if([string]::IsNullOrWhiteSpace($Uri) -or $Uri.Length -gt 4096){exit 2}
$value=$null
if(-not[Uri]::TryCreate($Uri,[UriKind]::Absolute,[ref]$value) -or $value.Scheme -ne 'nxm' -or $value.Host -ne 'palworld' -or $value.AbsolutePath -notmatch '^/mods/(\d+)/files/(\d+)$'){exit 3}
$modId=$matches[1];$fileId=$matches[2];$query=@{}
foreach($pair in $value.Query.TrimStart('?').Split('&')){$parts=$pair.Split('=',2);if($parts.Count -eq 2){if($query.ContainsKey($parts[0])){exit 4};$query[$parts[0]]=[Uri]::UnescapeDataString($parts[1])}}
if([string]$query.key -notmatch '^[A-Za-z0-9_-]{8,512}$' -or [string]$query.expires -notmatch '^\d{9,13}$'){exit 4}
$expires=[long]$query.expires;if($expires -gt 9999999999){$expires=[long]($expires/1000)}
$now=[DateTimeOffset]::UtcNow.ToUnixTimeSeconds();if($expires -lt $now -or $expires -gt ($now+86400)){exit 5}
$planPath=Join-Path ([IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))) 'Workspace\State\update-plan.json'
if(-not(Test-Path $planPath)){exit 6}
try{$plan=Get-Content $planPath -Raw|ConvertFrom-Json;$pending=@($plan.Results|Where-Object{$_.Status -eq 'UPDATE_AVAILABLE' -and [string]$_.Origin.ModId -eq $modId -and [string]$_.Candidate.FileId -eq $fileId});if($pending.Count -ne 1){exit 6}}catch{exit 6}
$record=[ordered]@{Schema='PMM_NXM_REQUEST_V1';Game='palworld';ModId=$modId;FileId=$fileId;Key=[string]$query.key;Expires=$expires;ReceivedUtc=[DateTime]::UtcNow.ToString('o')}
$json=$record|ConvertTo-Json -Compress;$encrypted=ConvertFrom-SecureString (ConvertTo-SecureString $json -AsPlainText -Force)
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'));$queue=Join-Path $root 'Workspace\State\IncomingNxm';[void][IO.Directory]::CreateDirectory($queue)
foreach($existing in @(Get-ChildItem $queue -Filter *.nxmq -File -ErrorAction SilentlyContinue)){
  try{$secure=ConvertTo-SecureString ([IO.File]::ReadAllText($existing.FullName));$h=[Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure);try{$prior=[Runtime.InteropServices.Marshal]::PtrToStringBSTR($h)|ConvertFrom-Json}finally{[Runtime.InteropServices.Marshal]::ZeroFreeBSTR($h)};if($prior.ModId -eq $modId -and $prior.FileId -eq $fileId -and $prior.Expires -eq $expires){exit 0}}catch{}
}
$name=([DateTime]::UtcNow.ToString('yyyyMMddHHmmssfff')+'-'+[Guid]::NewGuid().ToString('N')+'.nxmq');$target=Join-Path $queue $name;$temp=$target+'.tmp'
[IO.File]::WriteAllText($temp,$encrypted,[Text.UTF8Encoding]::new($false));[IO.File]::Move($temp,$target)
$exe=Join-Path $root 'PMM.exe'
if((Test-Path $exe) -and -not@(Get-Process PMM -ErrorAction SilentlyContinue).Count){Start-Process -FilePath $exe -WorkingDirectory $root}