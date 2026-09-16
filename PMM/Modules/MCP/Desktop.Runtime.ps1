# Desktop routing metadata only. Never reads account cookies or starts an AI request.
function Get-PMMDesktopPackages {
    $processes=@(Get-Process -Name ChatGPT,Codex -ErrorAction SilentlyContinue)
    foreach($p in @(Get-AppxPackage -ErrorAction Stop | Where-Object {
        $_.Name -in @('OpenAI.ChatGPT-Desktop','OpenAI.Codex') -and $_.Publisher -eq 'CN=50BDFD77-8903-4850-9FFE-6E8522F64D5B'
    })){
        # AppX projections differ across Windows/PowerShell hosts. A partial projection
        # is not a usable Desktop installation and must fail closed under StrictMode.
        $installLocation=if($p.PSObject.Properties['InstallLocation']){[string]$p.InstallLocation}else{''}
        $packageFullName=if($p.PSObject.Properties['PackageFullName']){[string]$p.PackageFullName}else{''}
        $packageFamilyName=if($p.PSObject.Properties['PackageFamilyName']){[string]$p.PackageFamilyName}else{''}
        if([string]::IsNullOrWhiteSpace($installLocation) -or [string]::IsNullOrWhiteSpace($packageFullName) -or [string]::IsNullOrWhiteSpace($packageFamilyName)){continue}
        try{$manifest=Get-AppxPackageManifest -Package $packageFullName}catch{continue}
        if(-not$manifest){continue}
        $protocols=@($manifest.SelectNodes('//*[local-name()="Protocol"]')|ForEach-Object{$_.Name})
        $running=@($processes|Where-Object{try{$_.Path -and $_.Path.StartsWith($installLocation.TrimEnd('\')+'\',[StringComparison]::OrdinalIgnoreCase)}catch{$false}})
        $version=if($p.PSObject.Properties['Version']){[string]$p.Version}else{''}
        $appId=''
        try{$appId=[string]@($manifest.Package.Applications.Application)[0].Id}catch{}
        [pscustomobject]@{Name=[string]$p.Name;Version=$version;InstallLocation=$installLocation;PackageFullName=$packageFullName;PackageFamilyName=$packageFamilyName;AppId=$appId;SupportsLocalChats=($protocols -contains 'codex');Running=($running.Count -gt 0)}
    }
}
function Select-PMMDesktopPackage([array]$Packages,[string]$Destination) {
    # Both brands can live in the unified Desktop host. Never fall back to the legacy logged-out app.
    $modern=@($Packages|Where-Object SupportsLocalChats)
    $active=@($modern|Where-Object Running)
    if($active.Count -eq 1){return $active[0]}
    if($active.Count -gt 1){throw 'More than one compatible Desktop installation is running. Close the unused installation and retry.'}
    $preferred=@($modern|Where-Object{if($Destination -eq 'CODEX_DESKTOP'){$_.Name -eq 'OpenAI.Codex'}else{$_.Name -eq 'OpenAI.ChatGPT-Desktop'}})
    if($preferred.Count -eq 1){return $preferred[0]}
    if($modern.Count -eq 1){return $modern[0]}
    if($modern.Count -gt 1){throw 'Multiple Desktop installations found; open the intended installation first.'}
    return $null
}
function Get-PMMChatGPTDesktop([string]$Destination='CODEX_DESKTOP') {
    return (Select-PMMDesktopPackage @(Get-PMMDesktopPackages) $Destination)
}
function Invoke-PMMDesktopUri([string]$Link,$App) {
    if(-not $App -or -not $App.SupportsLocalChats){throw 'No compatible Desktop installation is available. The legacy ChatGPT application was not opened.'}
    $uri=[Uri]$Link
    if($uri.Scheme -ne 'codex' -or $uri.Host -notin @('threads','new','launch','settings')){throw 'Unsupported Desktop link.'}
    # Target the selected package, independent of the Windows default protocol handler.
    Add-Type -AssemblyName System.Runtime.WindowsRuntime
    $null=[Windows.System.Launcher,Windows.System,ContentType=WindowsRuntime]
    $options=[Windows.System.LauncherOptions,Windows.System,ContentType=WindowsRuntime]::new()
    $options.TargetApplicationPackageFamilyName=$App.PackageFamilyName
    $operation=[Windows.System.Launcher]::LaunchUriAsync($uri,$options)
    $asTask=[System.WindowsRuntimeSystemExtensions].GetMethods()|Where-Object{$_.Name -eq 'AsTask' -and $_.IsGenericMethod -and $_.GetParameters().Count -eq 1 -and $_.GetParameters()[0].ParameterType.Name -eq ('IAsyncOperation'+[char]96+'1')}|Select-Object -First 1
    $task=$asTask.MakeGenericMethod([bool]).Invoke($null,@($operation))
    if(-not $task.Wait(10000)){throw 'Desktop activation timed out. Check the existing window before retrying.'}
    if(-not $task.Result){throw 'Windows could not activate the selected Desktop installation.'}
    return $true
}
function Open-PMMChatGPTDesktop([string]$Destination='CODEX_DESKTOP') {
    [void](Invoke-PMMDesktopUri 'codex://launch' (Get-PMMChatGPTDesktop $Destination))
}
function Open-PMMDesktopLink([string]$Link,[string]$Destination='CODEX_DESKTOP') {
    return (Invoke-PMMDesktopUri $Link (Get-PMMChatGPTDesktop $Destination))
}
function Get-PMMDesktopModes($App) {
    # Discover the installed route schema, not a model's self-reported capabilities.
    # Unknown layouts fail closed; no implicit Codex/Work execution.
    if(-not$App){return @()}
    $archive=Join-Path $App.InstallLocation 'app/resources/app.asar'
    if(-not(Test-Path -LiteralPath $archive)){return @()}
    $identity=$archive+'|'+(Get-Item -LiteralPath $archive).LastWriteTimeUtc.Ticks
    if((Get-Variable PMMDesktopModesCache -Scope Script -ErrorAction SilentlyContinue) -and $Script:PMMDesktopModesCache.Key -eq $identity){return @($Script:PMMDesktopModesCache.Modes)}
    $modes=@();$stream=[IO.File]::OpenRead($archive);$reader=[IO.BinaryReader]::new($stream)
    try{
        [void]$reader.ReadUInt32();$headerSize=$reader.ReadUInt32();[void]$reader.ReadUInt32();$jsonSize=$reader.ReadUInt32()
        if($jsonSize -gt 16MB -or $headerSize -lt $jsonSize){return @()}
        $header=[Text.Encoding]::UTF8.GetString($reader.ReadBytes($jsonSize))|ConvertFrom-Json
        if(-not$header.files.PSObject.Properties['.vite']){return @()}
        $files=$header.files.'.vite'.files.build.files
        foreach($file in $files.PSObject.Properties){
            $v=$file.Value
            if($file.Name -notlike '*.js' -or -not$v.PSObject.Properties['offset'] -or $v.size -gt 32MB){continue}
            [void]$stream.Seek((8L+$headerSize+[long]$v.offset),[IO.SeekOrigin]::Begin)
            $text=[Text.Encoding]::UTF8.GetString($reader.ReadBytes([int]$v.size))
            $match=[regex]::Match($text,'codexAppMode:\w+\(\[(?<values>[^\]]{1,256})\]\)\.optional\(\)')
            if($match.Success){
                $modes=@([regex]::Matches($match.Groups['values'].Value,'[\x60"''](?<mode>[a-z][a-z0-9_-]{0,40})[\x60"'']')|ForEach-Object{$_.Groups['mode'].Value}|Select-Object -Unique)
                break
            }
        }
    }catch{$modes=@()}finally{$reader.Dispose()}
    $Script:PMMDesktopModesCache=@{Key=$identity;Modes=$modes}
    return @($modes)
}
function Get-PMMCaseDesktopMode($Case) {
    if($Case -and $Case.PSObject.Properties['DesktopMode'] -and $Case.DesktopMode -match '^[a-z][a-z0-9_-]{0,40}$'){return [string]$Case.DesktopMode}
    return 'chat'
}
function Get-PMMCaseDesktopSendMode($Case) {
    if($Case -and $Case.PSObject.Properties['DesktopSendMode'] -and $Case.DesktopSendMode -eq 'SEND'){return 'SEND'}
    return 'DRAFT'
}
