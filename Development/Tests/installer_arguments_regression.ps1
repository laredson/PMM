$ErrorActionPreference='Stop'
Set-StrictMode -Version 2.0
$repo=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
. (Join-Path $repo 'PMM\Modules\MCP\MCP.Process.ps1')
. (Join-Path $repo 'PMM\Modules\Unreal\Unreal.Install.ps1')
$missing=Join-Path $repo ('Development\TestResults\missing installer '+[guid]::NewGuid().ToString('N')+'.msi')
$line=ConvertTo-PMMInstallerCommandLine @('/i',$missing,'/qn','/norestart')
if($line -ne ('/i "'+$missing+'" /qn /norestart')){throw 'Incorrect MSI command line.'}
$p=Start-Process (Join-Path $env:SystemRoot 'System32\msiexec.exe') -ArgumentList $line -PassThru
$handle=$p.Handle
try{
    if(-not $p.WaitForExit(15000)){throw 'MSI argument test timed out.'}
    if($p.ExitCode -ne 1619){throw ('Expected missing package 1619, got '+$p.ExitCode)}
}finally{$p.Dispose()}
Write-Output 'INSTALLER_ARGUMENTS_OK: real MSI parser accepts path with spaces; nonexistent package, nothing installed.'
