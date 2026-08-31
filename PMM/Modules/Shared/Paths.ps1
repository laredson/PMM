<# Central path contract for the portable PMM application. #>
function Initialize-PMMPaths([string]$Root) {
  $appRoot=[IO.Path]::GetFullPath($Root)
  $Script:Root=$appRoot
  $Script:PMMPaths=[ordered]@{
    App=$appRoot
    Engine=Join-Path $appRoot 'Engine'
    Modules=Join-Path $appRoot 'Modules'
    Resources=Join-Path $appRoot 'Resources'
    Metadata=Join-Path $appRoot 'Resources\Metadata'
    UI=Join-Path $appRoot 'Resources\UI'
    Mappings=Join-Path $appRoot 'Resources\Mappings'
    BundledThemes=Join-Path $appRoot 'Resources\Themes'
    CKL=Join-Path $appRoot 'CKL'
    CKLStable=Join-Path $appRoot 'CKL\Stable'
    CKLExperimental=Join-Path $appRoot 'CKL\Experimental'
    CKLCatalog=Join-Path $appRoot 'CKL\Catalog'
    CKLFixLab=Join-Path $appRoot 'CKL\FixLab'
    CKLFixLabStable=Join-Path $appRoot 'CKL\FixLab\Stable'
    CKLFixLabExperimental=Join-Path $appRoot 'CKL\FixLab\Experimental'
    CKLFixLabCases=Join-Path $appRoot 'CKL\FixLab\Cases'
    Workspace=Join-Path $appRoot 'Workspace'
    State=Join-Path $appRoot 'Workspace\State'
    Cache=Join-Path $appRoot 'Workspace\Cache'
    Temp=Join-Path $appRoot 'Workspace\Temp'
    Mods=Join-Path $appRoot 'Workspace\Mods'
    Builds=Join-Path $appRoot 'Workspace\Builds'
    Saves=Join-Path $appRoot 'Workspace\Saves'
    Review=Join-Path $appRoot 'Workspace\Review'
    Handoffs=Join-Path $appRoot 'Workspace\Handoffs'
    AIIO=Join-Path $appRoot 'Workspace\AIIO'
    AIIOSessions=Join-Path $appRoot 'Workspace\AIIO\Sessions'
    AIIOInbox=Join-Path $appRoot 'Workspace\AIIO\Inbox'
    AIIOOutbox=Join-Path $appRoot 'Workspace\AIIO\Outbox'
    AIIODiagnostics=Join-Path $appRoot 'Workspace\AIIO\Diagnostics'
    AIIOArtifacts=Join-Path $appRoot 'Workspace\AIIO\Artifacts'
    AIIODevelopment=Join-Path $appRoot 'Workspace\AIIO\Development'
    Logs=Join-Path $appRoot 'Workspace\Logs'
    GameReference=Join-Path $appRoot 'Workspace\GameReference'
    ManualSolutions=Join-Path $appRoot 'Workspace\ManualSolutions'
    KnowledgeContributions=Join-Path $appRoot 'Workspace\KnowledgeContributions'
    Themes=Join-Path $appRoot 'Workspace\Themes'
    ThemeDrafts=Join-Path $appRoot 'Workspace\Themes\Drafts'
    ThemeHandoffs=Join-Path $appRoot 'Workspace\Handoffs\Themes'
    Sounds=Join-Path $appRoot 'Workspace\Sounds'
    Validation=Join-Path $appRoot 'Workspace\Validation'
    ValidationEvents=Join-Path $appRoot 'Workspace\Validation\Events'
    ValidationFeedback=Join-Path $appRoot 'Workspace\Validation\Feedback'
    SaveActivity=Join-Path $appRoot 'Workspace\State\SaveActivity'
    FixLab=Join-Path $appRoot 'Workspace\FixLab'
    FixLabJobs=Join-Path $appRoot 'Workspace\FixLab\Jobs'
    FixLabCache=Join-Path $appRoot 'Workspace\FixLab\Cache'
    FixLabHandoffs=Join-Path $appRoot 'Workspace\FixLab\Handoffs'
  }
  foreach($key in @('Workspace','State','Cache','Temp','Mods','Builds','Saves','Review','Handoffs','AIIO','AIIOSessions','AIIOInbox','AIIOOutbox','AIIODiagnostics','AIIOArtifacts','AIIODevelopment','Logs','GameReference','ManualSolutions','KnowledgeContributions','Themes','ThemeDrafts','ThemeHandoffs','Sounds','Validation','ValidationEvents','ValidationFeedback','SaveActivity','FixLab','FixLabJobs','FixLabCache','FixLabHandoffs')){
    $p=[string]$Script:PMMPaths[$key]
    if(-not(Test-Path -LiteralPath $p -PathType Container)){New-Item -ItemType Directory -Force -Path $p|Out-Null}
  }
  Move-PMMLegacyWorkspaceIfPresent
  return $Script:PMMPaths
}
function Get-PMMPath([string]$Key) {
  if(-not $Script:PMMPaths){Initialize-PMMPaths $Script:Root|Out-Null}
  if(-not $Script:PMMPaths.Contains($Key)){throw "Unknown PMM path key: $Key"}
  return [string]$Script:PMMPaths[$Key]
}
function Join-PMMPath([string]$Key,[string]$Child='') { $base=Get-PMMPath $Key; if([string]::IsNullOrWhiteSpace($Child)){return $base}; return (Join-Path $base $Child) }

function Move-PMMLegacyDirectoryContents([string]$Source,[string]$Destination) {
  if(-not(Test-Path -LiteralPath $Source -PathType Container)){return}
  if(-not(Test-Path -LiteralPath $Destination -PathType Container)){New-Item -ItemType Directory -Force -Path $Destination|Out-Null}
  foreach($item in @(Get-ChildItem -LiteralPath $Source -Force -ErrorAction SilentlyContinue)){
    $dest=Join-Path $Destination $item.Name
    if(Test-Path -LiteralPath $dest){continue}
    try{Move-Item -LiteralPath $item.FullName -Destination $dest -Force -ErrorAction Stop}catch{}
  }
  try{if(@(Get-ChildItem -LiteralPath $Source -Force -ErrorAction SilentlyContinue).Count -eq 0){Remove-Item -LiteralPath $Source -Force -ErrorAction SilentlyContinue}}catch{}
}
function Move-PMMLegacyWorkspaceIfPresent {
  $root=Get-PMMPath 'App'
  foreach($pair in @(
    @('Mods','Mods'),@('Builds','Builds'),@('Saves','Saves'),@('Cache','Cache'),@('Logs','Logs'),@('AI_HANDOFFS','Handoffs')
  )){Move-PMMLegacyDirectoryContents (Join-Path $root $pair[0]) (Get-PMMPath $pair[1])}
  $data=Join-Path $root 'Data'
  if(Test-Path -LiteralPath $data -PathType Container){
    foreach($pair in @(@('Review','Review'),@('ManualSolutions','ManualSolutions'),@('GameReference','GameReference'),@('KnowledgeContributions','KnowledgeContributions'))){Move-PMMLegacyDirectoryContents (Join-Path $data $pair[0]) (Get-PMMPath $pair[1])}
    foreach($name in @('config.json','merge-plan.json','last-scan.json','mod-priorities.json','pending-removals.json','deployment-state.json')){
      $src=Join-Path $data $name;$dst=Join-PMMPath 'State' $name
      if((Test-Path -LiteralPath $src -PathType Leaf) -and -not(Test-Path -LiteralPath $dst)){try{Move-Item -LiteralPath $src -Destination $dst -Force -ErrorAction Stop}catch{}}
    }
  }
}

function Get-PMMRuntimePath { Join-PMMPath 'Engine' 'PMMRuntime.exe' }
function Get-PMMRepakExecutablePath { Join-PMMPath 'Engine' 'repak.exe' }
function Get-PMMMappingsPath { Join-PMMPath 'Mappings' 'Mappings.usmap' }
function Get-PMMMetadataPath([string]$Name) { Join-PMMPath 'Metadata' $Name }
function Get-PMMCKLStablePath([string]$Name) { Join-PMMPath 'CKLStable' $Name }
function Get-PMMCKLExperimentalPath([string]$Name) { Join-PMMPath 'CKLExperimental' $Name }
