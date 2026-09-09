param([string]$Root=([IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))),[switch]$Enable,[switch]$Disable)
Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
if($Enable -and $Disable){throw 'Choose Enable or Disable.'}
$Script:Root=$Root
. (Join-Path $PSScriptRoot 'MCP.Service.ps1')
. (Join-Path $Root 'Modules\AIIO\AIIO.SessionService.ps1')
if($Enable){Set-PMMMCPEnabled $true}
if($Disable){Set-PMMMCPEnabled $false}
$dir=Get-PMMMCPRoot
[void][IO.Directory]::CreateDirectory($dir)
$server=(Resolve-PMMMCPPath $Root 'Modules\MCP\Start-PMMMCP.ps1').Replace('\','/')
$command=(Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe').Replace('\','/')
$arguments=@('-NoLogo','-NoProfile','-NonInteractive','-ExecutionPolicy','Bypass','-File',$server)
$config=[ordered]@{mcpServers=@{pmm=@{command=$command;args=$arguments}}}
Write-PMMAIIOJsonAtomic (Resolve-PMMMCPPath $dir 'mcp-config.json') $config 8
# JSON strings are also valid TOML basic strings.
$argJson=ConvertTo-Json -InputObject $arguments -Compress
$commandJson=ConvertTo-Json -InputObject $command -Compress
$toml="[mcp_servers.pmm]"+[Environment]::NewLine+"command = "+$commandJson+[Environment]::NewLine+"args = "+$argJson+[Environment]::NewLine+"startup_timeout_sec = 30"+[Environment]::NewLine+"tool_timeout_sec = 120"+[Environment]::NewLine
[IO.File]::WriteAllText((Resolve-PMMMCPPath $dir 'codex-mcp.toml'),$toml,[Text.UTF8Encoding]::new($false))
Write-Output $dir

