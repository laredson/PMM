param([switch]$ProbeInstalled)
Set-StrictMode -Version 2;$ErrorActionPreference='Stop'
$repo=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'));$Script:Root=Join-Path $repo 'PMM'
. (Join-Path $Script:Root 'Modules/MCP/Desktop.Runtime.ps1')
. (Join-Path $Script:Root 'Modules/MCP/Desktop.Binding.ps1')
$checks=0;function Assert($ok,$why){if(-not$ok){throw $why};$script:checks++}
$old=[pscustomobject]@{Name='OpenAI.ChatGPT-Desktop';SupportsLocalChats=$false;Running=$true}
$new=[pscustomobject]@{Name='OpenAI.Codex';SupportsLocalChats=$true;Running=$true}
foreach($client in @('CHATGPT','CODEX_DESKTOP')){Assert ((Select-PMMDesktopPackage @($old,$new) $client).Name -eq 'OpenAI.Codex') 'Selected the logged-out legacy package.'}
Assert ($null -eq (Select-PMMDesktopPackage @($old) 'CHATGPT')) 'Legacy app must not be a silent fallback.'
$ambiguous=$false;try{Select-PMMDesktopPackage @($new,$new) 'CHATGPT'|Out-Null}catch{$ambiguous=$true};Assert $ambiguous 'Ambiguous running hosts were not blocked.'
Assert ((Get-PMMCaseDesktopMode ([pscustomobject]@{})) -eq 'chat') 'New and legacy requests must default to Chat.'
$link=New-PMMDesktopLink 'a & b'
Assert ($link.Contains('mode=chat&') -and $link.Contains('a%20%26%20b')) 'Default mode or prompt escaping is wrong.'
foreach($mode in @('chat','work','codex')){Assert ((New-PMMDesktopLink 'test' '' $mode).Contains('mode='+$mode+'&')) 'Mode lost in Desktop URI.'}
$id='01a09877-71f4-77e2-8261-930f91a85d6b'
Assert ((New-PMMDesktopLink '' $id) -ceq ('codex://threads/'+$id)) 'Open conversation created a new chat.'
$invalid=$false;try{New-PMMDesktopLink '' '' 'chat&mode=work'|Out-Null}catch{$invalid=$true};Assert $invalid 'Mode injection accepted.'
Assert ((Get-PMMCaseDesktopSendMode ([pscustomobject]@{})) -eq 'DRAFT') 'Automatic sending enabled without a user choice.'
$script:Activated=$null
function Get-PMMChatGPTDesktop([string]$Destination){return [pscustomobject]@{Destination=$Destination;SupportsLocalChats=$true;PackageFamilyName='fixture'}}
function Invoke-PMMDesktopUri([string]$Link,$App){$Script:Activated=$App;return $true}
[void](Open-PMMDesktopLink $link 'CODEX_DESKTOP')
Assert ($script:Activated.Destination -ceq 'CODEX_DESKTOP') 'Open ignored destination (1.3.3 regression).'
if($ProbeInstalled){
 . (Join-Path $Script:Root 'Modules/MCP/Desktop.Runtime.ps1')
 $app=Get-PMMChatGPTDesktop
 $modes=@(Get-PMMDesktopModes $app)
 Assert ($app.Running -and $modes -contains 'chat') 'Installed active host does not expose Chat.'
 'Metadata only: '+$app.Name+' '+$app.Version+' modes='+($modes -join ',')
}
'PASS Desktop routing: '+$checks+' assertions; no inference started.'
