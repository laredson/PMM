
Set-StrictMode -Version 2;$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'v133_agent_routing_protocol.ps1')
$before=$script:checks
$turnCount=$script:protocolTurns
$script:readCalls=0
function Invoke-PMMAppServerRequest($Client,[string]$Method,$Parameters,[int]$TimeoutSeconds=40){
  if($Method -eq 'initialize'){return @{}}
  if($Method -ne 'thread/read'){throw ('History refresh attempted '+$Method)}
  $script:readCalls++
  return @{thread=@{turns=@(@{id='historic-turn';items=@(
    @{id='user';type='userMessage';content=@(@{type='text';text='Publish an updated AUAT'})},
    @{id='assistant';type='agentMessage';text='Choose an updated mod or a Fix Lab recipe.'},
    @{id='tool';type='mcpToolCall';server='pmm';tool='pmm_case_get';result=@{caseId=$s.CaseId}},
    @{id='private';type='reasoning';text='PRIVATE_REASONING_FIXTURE'}
  )})}}
}
Sync-PMMCaseChat $s.CaseId|Out-Null
$folder=Join-Path (Get-PMMAIIOCasePath $s.CaseId) 'Chat'
$count=@(Get-ChildItem -LiteralPath $folder -Filter '*.json').Count
Sync-PMMCaseChat $s.CaseId|Out-Null
Assert ($script:readCalls -eq 2 -and $script:protocolTurns -eq $turnCount) 'Refresh started inference.'
Assert (@(Get-ChildItem -LiteralPath $folder -Filter '*.json').Count -eq $count) 'Repeated refresh duplicated public messages.'
$text=Get-PMMCaseChatText $s.CaseId
Assert ($text -match 'Publish an updated AUAT' -and $text -match 'pmm_case_get' -and $text -notmatch 'PRIVATE_REASONING_FIXTURE') 'Public journal omitted tools or exposed private reasoning.'
Stop-PMMRepairSession $s.Id|Out-Null
Reject {New-PMMChatPrompt $s.Id 'Run again'} 'A revoked session accepted another prompt.'
Assert ((Get-PMMCaseChatText $s.CaseId) -match 'Publish an updated AUAT') 'Cancellation erased the conversation.'
Write-Output ('PASS conversation history: '+($script:checks-$before)+' refresh, deduplication and cancellation checks.')
