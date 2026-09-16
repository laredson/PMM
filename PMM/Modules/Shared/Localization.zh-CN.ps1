if(-not(Get-Command Get-PMMLocalizedText -ErrorAction SilentlyContinue)){. (Join-Path $PSScriptRoot 'Localization.ps1')}
function Get-PMMChineseText([string]$English){return Get-PMMLocalizedText $English 'zh-CN'}
