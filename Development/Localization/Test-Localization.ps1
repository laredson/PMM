param([string]$Language='zh-CN')
$ErrorActionPreference='Stop'
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$loc=Join-Path $root 'PMM\Resources\Localization'
$en=Get-Content (Join-Path $loc 'en.json') -Raw -Encoding UTF8|ConvertFrom-Json -AsHashtable
$target=Get-Content (Join-Path $loc ($Language+'.json')) -Raw -Encoding UTF8|ConvertFrom-Json -AsHashtable
$targetMap=$target['strings']
$missing=@();$empty=@();$placeholder=@();$residue=@()
foreach($keyValue in $en['strings'].GetEnumerator()){
  $key=[string]$keyValue.Key
  if(-not$targetMap.ContainsKey($key)){$missing+=$key;continue}
  $value=[string]$targetMap[$key];if([string]::IsNullOrWhiteSpace($value)){$empty+=$key}
  $a=@([regex]::Matches($key,'\{[^{}]+\}')|ForEach-Object{$_.Value}|Sort-Object);$b=@([regex]::Matches($value,'\{[^{}]+\}')|ForEach-Object{$_.Value}|Sort-Object)
  if(($a -join '|') -cne ($b -join '|')){$placeholder+=$key}
  if($value -match 'PMMTERM|PMMTOKEN|__PMM|\bTERM\d+\b'){$residue+=$key}
}
if($missing.Count -or $empty.Count -or $placeholder.Count -or $residue.Count){throw ('Localization validation failed. missing='+$missing.Count+' empty='+$empty.Count+' placeholders='+$placeholder.Count+' residue='+$residue.Count)}
$critical=@{'+ New case'='+ 新建案例';'Projects'='项目';'Cases'='案例';'Mod Creation'='模组创建';'Help'='帮助';'Research cases'='研究案例';'Optional tools and AI clients'='可选工具与 AI 客户端';'Installations and status'='安装与状态';'Change permissions'='更改权限'}
if($Language -eq 'zh-CN'){foreach($k in $critical.Keys){if($targetMap[$k] -cne $critical[$k]){throw ('Critical translation mismatch: '+$k)}}}
[xml](Get-Content (Join-Path $root 'PMM\Resources\UI\MainWindow.zh-CN.xaml') -Raw -Encoding UTF8)|Out-Null
Write-Host ('Localization '+$Language+' OK: '+$targetMap.Count+' strings')
