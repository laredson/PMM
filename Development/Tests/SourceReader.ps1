<# Source-aware structural tests for the modular WPF shell. No code is executed. #>
function Read-PMMTestSource {
  param([Parameter(Mandatory=$true)][string]$Path,[Parameter(Mandatory=$true)][string]$AppRoot)
  $root=[IO.Path]::GetFullPath($AppRoot).TrimEnd('\','/')
  $active=[Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
  function Read-PMMTestSourcePart([string]$File) {
    $full=[IO.Path]::GetFullPath($File)
    if(-not$full.StartsWith($root+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)){throw 'Test source escaped the app root.'}
    if(-not$active.Add($full)){throw ('Cyclic test source include: '+$full)}
    try{
      $text=[IO.File]::ReadAllText($full)
      $pattern="(?m)^[ \t]*\.\s+\(Join-Path\s+\`$Script:Root\s+'(?<relative>Modules[\\/](?:Presentation|Workflow)[\\/][A-Za-z0-9_.-]+\.ps1)'\)[ \t]*\r?$"
      $matches=[regex]::Matches($text,$pattern)
      for($i=$matches.Count-1;$i -ge 0;$i--){
        $match=$matches[$i]
        $included=Read-PMMTestSourcePart (Join-Path $root $match.Groups['relative'].Value)
        $text=$text.Remove($match.Index,$match.Length).Insert($match.Index,$included.TrimEnd([char]13,[char]10))
      }
      return $text
    }finally{[void]$active.Remove($full)}
  }
  return (Read-PMMTestSourcePart $Path)
}
