$Script:PMMChineseStrings = $null
function Get-PMMChineseText([string]$English) {
  if ([string]::IsNullOrWhiteSpace($English)) { return $English }
  if ($null -eq $Script:PMMChineseStrings) {
    $Script:PMMChineseStrings = @{}
    try {
      $path = Join-Path $Script:Root 'Resources\UI\strings.zh-CN.json'
      if (Test-Path -LiteralPath $path -PathType Leaf) {
        $obj = Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json
        foreach ($prop in $obj.PSObject.Properties) { $Script:PMMChineseStrings[[string]$prop.Name] = [string]$prop.Value }
      }
    } catch {}
  }
  if ($Script:PMMChineseStrings.ContainsKey($English)) { return [string]$Script:PMMChineseStrings[$English] }
  return $English
}
