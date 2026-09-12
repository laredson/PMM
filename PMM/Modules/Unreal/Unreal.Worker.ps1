
param([string]$Root,[string]$JobId)
Set-StrictMode -Version 2.0
# Load the utility module from this host, not an inherited PowerShell 7 module path.
Import-Module (Join-Path $PSHOME 'Modules\Microsoft.PowerShell.Utility\Microsoft.PowerShell.Utility.psd1') -ErrorAction Stop
$ErrorActionPreference='Stop'
$Script:Root=[IO.Path]::GetFullPath($Root)
. (Join-Path $Root 'Modules\MCP\MCP.Service.ps1')
$Script:PMMPaths=[ordered]@{App=$Root;Workspace=(Join-Path $Root 'Workspace');State=(Join-Path $Root 'Workspace\State');Cache=(Join-Path $Root 'Workspace\Cache');AIIO=(Join-Path $Root 'Workspace\AIIO');AIIOSessions=(Join-Path $Root 'Workspace\AIIO\Sessions');Mods=(Join-Path $Root 'Workspace\Mods');GameReference=(Join-Path $Root 'Workspace\GameReference')}
foreach($module in @('Shared\Paths.ps1','Shared\Persistence.ps1','Library\LibraryService.ps1','Knowledge/Knowledge.Service.ps1','Tools/Tools.Service.ps1','Operations\ModuleRuntime.ps1')){
    . (Join-Path $Root ('Modules\'+$module))|Out-Null
}

. (Join-Path $Root 'Modules\AIIO\AIIO.SessionService.ps1')
. (Join-Path $Root 'Modules\AIIO\AIIO.CaseWorkspaceService.ps1')
. (Join-Path $Root 'Modules\Unreal\Unreal.Service.ps1')
. (Join-Path $Root 'Modules\Unreal\Unreal.Files.ps1')
. (Join-Path $Root 'Modules\Unreal\Unreal.Candidate.ps1')
if($JobId -cnotmatch '^[a-f0-9]{32}$'){throw 'Invalid job ID'}
$job=Resolve-PMMMCPPath (Get-PMMUnrealRoot) ('Jobs\'+$JobId)
$request=Read-PMMMCPJson (Join-Path $job 'request.json')
$cancel=Resolve-PMMMCPPath $job 'cancel'
$lock=$null;$globalOperationLock=$null;$moduleLease=$null
function Report([string]$Text){Write-PMMAIIOJsonAtomic (Join-Path $job 'status.json') @{status='RUNNING';message=$Text;verified=$false} 8}
try{
    Initialize-PMMModuleRuntime -Root $Root|Out-Null
    Report 'Waiting for the PMM operation slot...'
    $globalOperationLock=Enter-PMMToolBackgroundLock -CancelPath $cancel
    $moduleLease=Start-PMMModuleOperation ('Unreal:'+[string]$request.operation)
    Assert-PMMCaseResponseRevision $request.caseId ([string](Get-PMMCaseValue $request 'EvidenceRevisionId' ''))|Out-Null
    if(-not(Get-PMMMCPEnabled)){throw 'MCP disabled'}
    $e=Get-PMMUnrealEnvironment
    if(-not $e.enabled -or -not $e.readyToPrepare){throw 'Unreal environment unavailable.'}
    $project=Get-PMMUnrealProject $request.caseId
    [void][IO.Directory]::CreateDirectory($project)
    $lock=[IO.File]::Open((Join-Path $project 'operation.lock'),[IO.FileMode]::OpenOrCreate,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)
    $uproject=Resolve-PMMMCPPath $project 'Pal.uproject'
    $editor=Resolve-PMMMCPPath $e.engineRoot 'Engine\Binaries\Win64\UnrealEditor-Cmd.exe'
    if($request.operation -eq 'prepare'){
        Report 'Preparing pinned Palworld kit and local dependencies...'
        $binding=Join-Path $project 'project.json'
        if(Test-Path $uproject){
            if(-not(Test-Path $binding)){throw 'Existing project has no PMM ownership record.'}
            $old=Read-PMMMCPJson $binding
            if($old.caseId -cne $request.caseId -or $old.kitCommit -ne $e.kitCommit){throw 'Project ownership or kit revision mismatch.'}
        }else{
            $zip=Get-PMMUnrealKitArchive $cancel
            Expand-PMMUnrealKit $zip $project
            Write-PMMUnrealJson $binding @{caseId=$request.caseId;kitCommit=$e.kitCommit;kitSha256=(Get-FileHash $zip).Hash.ToLowerInvariant()}
        }
        Install-PMMUnrealWwise $e $project $job $cancel
        $p=Read-PMMMCPJson $uproject
        $plugins=@($p.Plugins|Where-Object{$_.Name -notin @('PythonScriptPlugin','EditorScriptingUtilities')})
        $plugins+=@(@{Name='PythonScriptPlugin';Enabled=$true},@{Name='EditorScriptingUtilities';Enabled=$true})
        $p.Plugins=$plugins;Write-PMMUnrealJson $uproject $p
        $config=Join-Path $project 'Config\DefaultGame.ini'
        $settings=[char]10+'[/Script/UnrealEd.ProjectPackagingSettings]'+[char]10+'bUseIoStore=False'+[char]10+'bUsePakFile=True'+[char]10
        if(-not([IO.File]::ReadAllText($config).Contains($settings))){[IO.File]::AppendAllText($config,$settings,[Text.UTF8Encoding]::new($false))}
        Report 'Compiling the isolated Palworld editor project...'
        $ubt=Resolve-PMMMCPPath $e.engineRoot 'Engine\Binaries\DotNET\UnrealBuildTool\UnrealBuildTool.dll'
        $dotnet=Join-Path $env:ProgramFiles 'dotnet\dotnet.exe'
        Invoke-PMMBoundedProcess $dotnet @($ubt,'PalEditor','Win64','Development',('-Project='+$uproject),'-NoHotReloadFromIDE','-Compiler=VisualStudio2022',('-CompilerVersion='+$e.msvc),('-ToolchainVersion='+$e.msvc)) $job 3600 $cancel | Out-Null
    }else{
        $v=Read-PMMMCPJson (Join-Path $project 'verified.json')
        if($v.kitCommit -ne $e.kitCommit -or $v.engineRoot -ine $e.engineRoot -or $v.engineVersion -ne $e.engineVersion){throw 'Project verification stale.'}
    }
    if($request.operation -eq 'cook'){
        $registry=Read-PMMMCPJson (Join-Path $project 'Saved\PMM\assets.json')
        foreach($entry in $registry.PSObject.Properties){
            $assetFile=Resolve-PMMMCPPath $project ('Content\PMM\'+$entry.Name+'.uasset')
            if((Get-FileHash $assetFile).Hash -ine $entry.Value.assetSha256){throw 'Registered editor asset changed outside PMM.'}
        }
        Report 'Cooking only PMM-authored content for Windows...'
        Invoke-PMMBoundedProcess $editor @($uproject,'-run=cook','-targetplatform=Windows',('-CookDir='+ (Join-Path $project 'Content\PMM')),'-unattended','-nop4','-nosplash','-NoSound','-UTF8Output') $job 3600 $cancel | Out-Null
        $candidate=New-PMMUnrealCandidate $request.caseId $JobId $project $e $cancel
        [void]@(Sync-PMMGeneratedCandidateLibrary $request.caseId)
        Write-PMMAIIOJsonAtomic (Join-Path $job 'status.json') @{status='COMPLETE';message='Cooked candidate validated; no game deployment.';verified=$true;candidate=$candidate} 12
    }else{
        $payload=@{operation=$request.operation}
        foreach($a in $request.arguments.PSObject.Properties){if($a.Name -ne 'caseId'){$payload[$a.Name]=$a.Value}}
        if($request.operation -in @('prepare','import_texture')){
            $assetName=if($request.operation -eq 'prepare'){'PMMProbe'}else{$request.arguments.assetName}
            if($assetName -cnotmatch '^[A-Za-z][A-Za-z0-9_]{0,47}$'){throw 'Invalid texture name.'}
            $source=Resolve-PMMMCPPath $project ('SourceData\'+$assetName+'.png')
            [void][IO.Directory]::CreateDirectory((Split-Path $source -Parent))
            if($request.operation -eq 'prepare'){
                [IO.File]::WriteAllBytes($source,[Convert]::FromBase64String('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGNgaPj/HwAEggJ/59habAAAAABJRU5ErkJggg=='))
                $existing=Join-Path $project 'Saved\PMM\assets.json'
                if(Test-Path $existing){$registry=Read-PMMMCPJson $existing;$registry.PSObject.Properties.Remove('PMMProbe');Write-PMMUnrealJson $existing $registry}
                foreach($ext in @('.uasset','.uexp','.ubulk')){$probe=Resolve-PMMMCPPath $project ('Content\PMM\PMMProbe'+$ext);if(Test-Path $probe){Remove-Item -LiteralPath $probe}}
            }else{
                $sourceArtifact=Get-PMMMCPArtifactPath $request.caseId $request.arguments.sourceArtifactId
                if([IO.Path]::GetExtension($sourceArtifact) -ne '.png' -or (Get-Item $sourceArtifact).Length -gt 4MB){throw 'Texture input must be a staged PNG of at most 4 MiB.'}
                $bytes=[IO.File]::ReadAllBytes($sourceArtifact)
                if($bytes.Length -lt 24 -or [BitConverter]::ToString($bytes[0..7]) -ne '89-50-4E-47-0D-0A-1A-0A'){throw 'Invalid PNG signature.'}
                $width=[Net.IPAddress]::NetworkToHostOrder([BitConverter]::ToInt32($bytes,16));$height=[Net.IPAddress]::NetworkToHostOrder([BitConverter]::ToInt32($bytes,20))
                if($width -lt 1 -or $height -lt 1 -or $width -gt 4096 -or $height -gt 4096){throw 'Texture dimensions must be between 1 and 4096.'}
                if((Test-Path $source) -and (Get-FileHash $source).Hash -ine (Get-FileHash $sourceArtifact).Hash){throw 'A different source asset already exists.'}
                Copy-Item -LiteralPath $sourceArtifact -Destination $source
            }
            $payload.assetName=$assetName;$payload.sourceSha256=(Get-FileHash $source).Hash.ToLowerInvariant()
        }
        $work=Resolve-PMMMCPPath $project 'Saved\PMM';[void][IO.Directory]::CreateDirectory($work)
        Write-PMMUnrealJson (Join-Path $work 'request.json') $payload
        $response=Join-Path $work 'response.json';if(Test-Path $response){Remove-Item -LiteralPath $response}
        $script=Resolve-PMMMCPPath $Root 'Modules\Unreal\editor_bridge.py'
        Report 'Running the PMM editor operation with Unreal embedded Python...'
        Invoke-PMMBoundedProcess $editor @($uproject,'-unattended','-nop4','-nosplash','-NullRHI','-NoSound','-run=pythonscript',('-script='+$script),'-UTF8Output') $job 600 $cancel | Out-Null
        $r=Read-PMMMCPJson $response
        if(-not $r.success){throw $r.error}
        Write-PMMUnrealJson (Join-Path $project 'verified.json') @{engineRoot=$e.engineRoot;engineVersion=$e.engineVersion;kitCommit=$e.kitCommit;verifiedUtc=[DateTime]::UtcNow.ToString('o');probe='texture-import';runtime='UNPROVEN'}
        Write-PMMAIIOJsonAtomic (Join-Path $job 'status.json') @{status='COMPLETE';message='Unreal editor operation verified.';verified=$true;result=$r;runtime='UNPROVEN'} 12
    }
}catch{
    $failureMessage=$_.Exception.Message
    $state=if(Test-Path $cancel){'CANCELLED'}else{'FAILED'}
    try{Register-PMMKnowledgeCandidate -CaseId $request.caseId -CandidateId ('unreal-attempt-'+$JobId) -EvidenceRevisionId ([string](Get-PMMCaseValue $request 'EvidenceRevisionId' '')) -TechnicalStatus Rejected -Objective ([string]$request.operation) -Outcome $state|Out-Null}catch{}
    Write-PMMAIIOJsonAtomic (Join-Path $job 'status.json') @{status=$state;message=$failureMessage;verified=$false} 12
}finally{if($moduleLease){Complete-PMMModuleOperation $moduleLease.Id};if($globalOperationLock){$globalOperationLock.Dispose()};if($lock){$lock.Dispose()}}
