<# Shared durable JSON storage. Compatible with Windows PowerShell 5.1. #>
function Get-PMMStorageMutexName([string]$Path) {
  $sha=[Security.Cryptography.SHA256]::Create()
  try{$bytes=$sha.ComputeHash([Text.Encoding]::UTF8.GetBytes([IO.Path]::GetFullPath($Path).ToLowerInvariant()));return ('Local\PMM.Storage.'+([BitConverter]::ToString($bytes).Replace('-','')))}finally{$sha.Dispose()}
}

function Assert-PMMJsonValue($Value,[string]$Schema='', [scriptblock]$Validate=$null) {
  if($null -eq $Value){throw 'A persistent JSON document cannot be null.'}
  if($Schema){
    $actual=if($Value -is [Collections.IDictionary]){$Value['Schema']}elseif($Value.PSObject.Properties.Name -contains 'Schema'){$Value.Schema}else{''}
    if([string]$actual -cne $Schema){throw "Unexpected persistent document schema; expected $Schema."}
  }
  if($Validate -and -not (& $Validate $Value)){throw 'Persistent document validation failed.'}
}

function Write-PMMJsonAtomic {
  param([Parameter(Mandatory=$true)][string]$Path,[Parameter(Mandatory=$true)][AllowEmptyCollection()]$Value,[int]$Depth=30,[string]$Schema='', [scriptblock]$Validate=$null)
  Assert-PMMJsonValue $Value $Schema $Validate
  $json=if($Value -is [array] -and $Value.Count -eq 0){'[]'}else{ConvertTo-Json -InputObject $Value -Depth $Depth}
  # An empty array is valid JSON; PowerShell otherwise enumerates it to null.
  $roundTrip=ConvertFrom-Json -InputObject $json
  if($json.Trim() -ne '[]'){Assert-PMMJsonValue $roundTrip $Schema $Validate}
  $full=[IO.Path]::GetFullPath($Path);$parent=[IO.Path]::GetDirectoryName($full)
  [void][IO.Directory]::CreateDirectory($parent)
  $mutex=[Threading.Mutex]::new($false,(Get-PMMStorageMutexName $full));$owned=$false
  $temp=$full+'.'+[guid]::NewGuid().ToString('N')+'.tmp'
  try{
    try{$owned=$mutex.WaitOne(15000)}catch [Threading.AbandonedMutexException]{$owned=$true}
    if(-not$owned){throw 'Timed out waiting for persistent storage writer.'}
    $bytes=[Text.UTF8Encoding]::new($false).GetBytes($json)
    $stream=[IO.File]::Open($temp,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
    try{$stream.Write($bytes,0,$bytes.Length);$stream.Flush($true)}finally{$stream.Dispose()}
    if([IO.File]::Exists($full)){
      # Same-directory replacement is atomic. Never fall back to delete + move.
      [IO.File]::Replace($temp,$full,($full+'.bak'),$true)
    }else{[IO.File]::Move($temp,$full)}
  }finally{
    if([IO.File]::Exists($temp)){[IO.File]::Delete($temp)}
    if($owned){$mutex.ReleaseMutex()};$mutex.Dispose()
  }
}

function Read-PMMJsonFile {
  param([Parameter(Mandatory=$true)][string]$Path,[string]$Schema='',[scriptblock]$Validate=$null,[switch]$RecoverBackup)
  try{
    $raw=[IO.File]::ReadAllText($Path)
    if($raw -match '^\[\s*\]$' -and -not$Schema -and -not$Validate){return ,@()}
    $value=ConvertFrom-Json -InputObject $raw
    Assert-PMMJsonValue $value $Schema $Validate
    return ,$value
  }catch{
    if(-not$RecoverBackup -or -not[IO.File]::Exists($Path+'.bak')){throw}
    $raw=[IO.File]::ReadAllText($Path+'.bak')
    $value=if($raw -match '^\[\s*\]$'){@()}else{ConvertFrom-Json -InputObject $raw}
    if($raw -notmatch '^\[\s*\]$'){Assert-PMMJsonValue $value $Schema $Validate}
    if([IO.File]::Exists($Path)){[IO.File]::Copy($Path,($Path+'.corrupt.'+[guid]::NewGuid().ToString('N')))}
    Write-PMMJsonAtomic -Path $Path -Value $value -Schema $Schema -Validate $Validate
    return ,$value
  }
}

function Update-PMMJsonSchema {
  param([string]$Path,[string]$Schema,[int]$TargetVersion,[hashtable]$Migrations)
  $value=Read-PMMJsonFile -Path $Path -Schema $Schema
  if(-not($value.PSObject.Properties.Name -contains 'SchemaVersion')){throw 'SchemaVersion is required for a migration.'}
  $version=[int]$value.SchemaVersion
  if($version -gt $TargetVersion){throw 'This document requires a newer PMM version.'}
  while($version -lt $TargetVersion){
    if(-not$Migrations.ContainsKey($version)){throw "Missing migration from schema version $version."}
    $value=& $Migrations[$version] $value
    if([int]$value.SchemaVersion -ne ($version+1)){throw 'A migration must advance exactly one schema version.'}
    Assert-PMMJsonValue $value $Schema
    $version++
  }
  Write-PMMJsonAtomic -Path $Path -Value $value -Schema $Schema
  return $value
}
