. (Join-Path $PSScriptRoot '../Shared/Mappings.ps1')
. (Join-Path $PSScriptRoot '../Cases/CaseService.ps1')


. (Join-Path $PSScriptRoot '../Unreal/Dependencies.Service.ps1')
. (Join-Path $PSScriptRoot 'MCP.Archive.ps1')
. (Join-Path $PSScriptRoot '..\Unreal\Unreal.Service.ps1')
. (Join-Path $PSScriptRoot '..\Unreal\Unreal.Candidate.ps1')
. (Join-Path $PSScriptRoot 'MCP.Process.ps1')
. (Join-Path $PSScriptRoot 'MCP.Asset.ps1')
. (Join-Path $PSScriptRoot 'MCP.Edit.ps1')
. (Join-Path $PSScriptRoot 'MCP.Reference.ps1')
. (Join-Path $PSScriptRoot 'MCP.Exchange.ps1')
# PMM's local capability boundary. No client-supplied commands or absolute paths.
function Resolve-PMMMCPPath([string]$Base,[string]$Relative='') {
    $basePath=[IO.Path]::GetFullPath($Base).TrimEnd('\','/')
    if($Relative) {
        if($Relative.Length -gt 512 -or $Relative -match '[:\x00-\x1f]' -or [IO.Path]::IsPathRooted($Relative)){throw 'Invalid relative path.'}
        foreach($segment in $Relative.Replace('\','/').Split('/')){
            if(-not $segment -or $segment -in @('.','..') -or $segment -match '[. ]$|[<>|?*"]' -or $segment -match '^(?i:CON|PRN|AUX|NUL|COM[0-9]|LPT[0-9])(\.|$)'){throw 'Unsafe path segment.'}
        }
    }
    $target=$basePath
    if($Relative){$target=[IO.Path]::GetFullPath((Join-Path $basePath $Relative))}
    if($target -ne $basePath -and -not $target.StartsWith($basePath+'\',[StringComparison]::OrdinalIgnoreCase)){throw 'Path escaped PMM scope.'}
    # Check every existing ancestor, including ancestors of the installation.
    $cursor=$target
    while($cursor){
        if(Test-Path -LiteralPath $cursor){
            $item=Get-Item -LiteralPath $cursor -Force
            if(($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0){throw 'Links and junctions are not allowed in MCP paths.'}
        }
        $parent=[IO.Path]::GetDirectoryName($cursor)
        if($parent -eq $cursor){break};$cursor=$parent
    }
    return $target
}
function Get-PMMMCPRoot { return (Resolve-PMMMCPPath $Script:Root 'Workspace\MCP') }
function Read-PMMMCPJson([string]$Path,[long]$Limit=1048576) {
    $safe=Resolve-PMMMCPPath $Path
    if((Get-Item -LiteralPath $safe).Length -gt $Limit){throw 'JSON exceeds the size limit.'}
    return (Get-Content -LiteralPath $safe -Raw -Encoding UTF8 | ConvertFrom-Json)
}
function Get-PMMMCPEnabled {
    $path=Resolve-PMMMCPPath (Get-PMMMCPRoot) 'settings.json'
    if(-not(Test-Path -LiteralPath $path -PathType Leaf)){return $false}
    $settings=Read-PMMMCPJson $path
    return (@($settings.PSObject.Properties | ForEach-Object { $_.Name }) -contains 'enabled' -and $settings.enabled -is [bool] -and $settings.enabled)
}
function Set-PMMMCPEnabled([bool]$Enabled) {
    $path=Resolve-PMMMCPPath (Get-PMMMCPRoot) 'settings.json'
    Write-PMMAIIOJsonAtomic $path ([ordered]@{schema='PMM_MCP_SETTINGS_V1';enabled=$Enabled}) 5
}
function Get-PMMMCPCase([string]$CaseId) {
    if(-not(Test-PMMAIIOCaseId $CaseId)){throw 'Invalid case ID.'}
    $path=Resolve-PMMMCPPath $Script:Root ('Workspace\AIIO\Cases\'+$CaseId+'\case.json')
    if(-not(Test-Path -LiteralPath $path -PathType Leaf)){throw 'Case not found.'}
    $case=Read-PMMMCPJson $path

    if(Get-Command Get-PMMCaseVisibleVersion -ErrorAction SilentlyContinue){$case=Get-PMMCaseVisibleVersion $case;if(-not$case){throw 'Case evidence publication is not complete.'}}
    if($case.Schema -ne $Script:PMMAIIOCaseSchema -or $case.CaseId -cne $CaseId){throw 'Invalid case identity.'}
    return $case
}
function ConvertTo-PMMMCPCase($Case) {
    # Deliberate projection: no local provider paths, logs, saves or arbitrary evidence.
    $request=$null
    if($Case.Transport -eq 'MCP' -and $Case.NextAction -eq 'WAIT_FOR_MCP' -and @($Case.PSObject.Properties | ForEach-Object {$_.Name}) -contains 'MCPRequest'){
        $r=$Case.MCPRequest
        if($r -and $r.publishedStep -eq $Case.CurrentStep -and $r.title -ceq $Case.Title -and $r.description -ceq $Case.Description -and $r.type -ceq $Case.Type){
            $request=[ordered]@{requestId=$r.requestId;sourceStep=$r.sourceStep;state='AVAILABLE';publishedUtc=$r.publishedUtc}
        }
    }
    $mods=@();if($Case.PSObject.Properties.Name -contains 'References' -and $Case.References){$mods=@($Case.References.Mods|Select-Object -First 32|ForEach-Object{@{name=$_.Name;sha256=$_.Sha256;mode=$_.Mode}})}
    return [ordered]@{evidenceRevision=[string](Get-PMMCaseValue $Case 'CurrentEvidenceRevision' '');referencedMods=$mods;caseId=$Case.CaseId;title=$Case.Title;type=$Case.Type;description=$Case.Description;transport=$Case.Transport;mcpRequest=$request;aiReply=(Get-PMMMCPReplyView $Case);status=$Case.Status;nextAction=$Case.NextAction;updatedUtc=$Case.UpdatedUtc}
}
function Get-PMMMCPArtifactDir([string]$CaseId) {
    [void](Get-PMMMCPCase $CaseId)
    return (Resolve-PMMMCPPath (Get-PMMMCPRoot) ('Artifacts\'+$CaseId))
}
function Get-PMMMCPUsage([string]$Dir) {
    [long]$bytes=0;[int]$count=0
    if(Test-Path -LiteralPath $Dir){
        foreach($file in Get-ChildItem -LiteralPath $Dir -Force){
            [void](Resolve-PMMMCPPath $Dir $file.Name)
            if($file.PSIsContainer){throw 'Unexpected directory in artifact storage.'}
            $bytes+=$file.Length;$count++
        }
    }
    return @{bytes=$bytes;count=$count}
}
function New-PMMMCPArtifact([string]$CaseId,[string]$Extension,[byte[]]$Bytes) {
    $dir=Get-PMMMCPArtifactDir $CaseId
    $usage=Get-PMMMCPUsage $dir
    if($Bytes.Length -gt 64MB -or $usage.bytes+$Bytes.Length -gt 128MB -or $usage.count -ge 256){throw 'Case artifact quota exceeded (128 MiB / 256 files).'}
    $name=[guid]::NewGuid().ToString('N')+$Extension
    $path=Resolve-PMMMCPPath $dir $name
    [void][IO.Directory]::CreateDirectory($dir)
    $stream=[IO.File]::Open($path,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
    try{$stream.Write($Bytes,0,$Bytes.Length)}finally{$stream.Dispose()}
    return [ordered]@{artifactId=$name;bytes=$Bytes.Length;sha256=(Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant();state='STAGED_UNTRUSTED';runtime='UNPROVEN'}
}
function Get-PMMMCPArtifactPath([string]$CaseId,[string]$ArtifactId) {
    if($ArtifactId -cnotmatch '^[a-f0-9]{32}\.(txt|md|json|png|zip|uasset|uexp|ubulk|uptnl)$'){throw 'Invalid artifact ID.'}
    return (Resolve-PMMMCPPath (Get-PMMMCPArtifactDir $CaseId) $ArtifactId)
}
function Get-PMMMCPReferenceFamilies {
    foreach($rel in @('Workspace\State\config.json','Workspace\GameReference\current.json','Workspace\GameReference\current\index\families.jsonl','Resources\Mappings\Mappings.usmap')){
        $p=Resolve-PMMMCPPath $Script:Root $rel
        if(-not(Test-Path -LiteralPath $p -PathType Leaf)){throw 'Call pmm_reference_prepare, poll pmm_reference_status until Current, then retry this query.'}
        if($rel.EndsWith('.jsonl') -and (Get-Item -LiteralPath $p).Length -gt 64MB){throw 'Reference index exceeds MCP limit.'}
    }
    [void](Get-PMMAIIOGameReferenceProof -RequireCurrent)
    return @(Get-PMMGameReferenceFamilies)
}
function Get-PMMMCPTools {
    $str=@{type='string';minLength=1;maxLength=256}
    $case=@{type='string';pattern='^AICASE-[0-9]{8}-[0-9]{6}-[a-f0-9]{8}$';maxLength=32}
    $defs=@(
        @('pmm_desktop_pair','Verify a PMM-generated installation pairing code. Does not grant folder access or authenticate an account.',@{nonce=$str},@('nonce'),$false),
        @('pmm_desktop_case_link','Record receipt, research or waiting for plan approval for a Desktop request. Supply a real thread ID only when available.',@{caseId=$case;requestId=$str;token=$str;threadId=@{type='string';pattern='^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$'};phase=@{type='string';enum=@('RECEIVED','RESEARCHING','AWAITING_APPROVAL')}},@('caseId','requestId','token','phase'),$false),
        @('pmm_connection_check','Confirm a user-created case connection challenge. Does not grant permissions.',@{caseId=$case;nonce=$str},@('caseId','nonce'),$false),
        @('pmm_dependencies_status','Detect optional modding components. Detection is not project verification.',@{},@(),$true),
        @('pmm_dependency_install','Request an official catalog component. PMM asks the user unless automatic installation was authorized. Cannot grant consent.',@{caseId=$case;component=@{type='string';enum=@('all','chatgpt','unreal','visualstudio','windowssdk','dotnet6','wwise','wwiseintegration','kit')}},@('caseId','component'),$false),
        @('pmm_dependency_job','Read installation progress; WAITING_EXTERNAL means official launcher steps remain.',@{caseId=$case;jobId=$str},@('caseId','jobId'),$true),
        @('pmm_dependency_cancel','Cancel an installation request owned by this case.',@{caseId=$case;jobId=$str},@('caseId','jobId'),$false),

        @('pmm_archive_search','Search the complete configured game PAK index, including assets outside hydrated Game Reference. Paginated; does not extract the game.',@{query=$str;offset=@{type='integer';minimum=0;maximum=500000};limit=@{type='integer';minimum=1;maximum=100}},@('query'),$true),
        @('pmm_asset_prepare','Extract one exact asset family from the configured game archive into bounded PMM cache. Then use pmm_asset_inspect.',@{caseId=$case;logicalPath=@{type='string';minLength=1;maxLength=512}},@('caseId','logicalPath'),$false),

        @('pmm_unreal_status','Detect optional Unreal prerequisites and case-project verification. Base PMM tools work without Unreal.',@{caseId=$case},@(),$true),
        @('pmm_unreal_prepare','Prepare pinned kit, compile and verify the isolated case project using installed dependencies.',@{caseId=$case},@('caseId'),$false),
        @('pmm_unreal_texture','Import a staged PNG, duplicate a registered texture template or configure its allowed properties.',@{caseId=$case;operation=@{type='string';enum=@('import_texture','duplicate','configure')};assetName=@{type='string';pattern='^[A-Za-z][A-Za-z0-9_]{0,47}$';maxLength=48};sourceArtifactId=$str;templateId=@{type='string';pattern='^[A-Za-z][A-Za-z0-9_]{0,47}$';maxLength=48};srgb=@{type='boolean'};filter=@{type='string';enum=@('default','nearest','bilinear','trilinear')}},@('caseId','operation','assetName'),$false),
        @('pmm_unreal_cook','Cook PMM-authored textures for Windows and validate an inactive candidate; never deploy.',@{caseId=$case},@('caseId'),$false),
        @('pmm_unreal_job','Read job result or wait up to 20 seconds for progress.',@{caseId=$case;jobId=$str;waitSeconds=@{type='integer';minimum=0;maximum=20}},@('caseId','jobId'),$true),
        @('pmm_unreal_cancel','Cancel one case-owned Unreal job.',@{caseId=$case;jobId=$str},@('caseId','jobId'),$false),
        @('pmm_unreal_candidates','List generated candidates and their current integrity, separate from game runtime proof.',@{caseId=$case},@('caseId'),$true),

        @('pmm_asset_edit','For a case with evidenceRevision, include that exact value from pmm_case_get. Edit one parsed numeric or boolean property on an isolated copy. JSON pointer and expected JSON scalar are required. Rejects opaque exports; never deploys.',@{caseId=$case;logicalPath=@{type='string';minLength=1;maxLength=512};path=@{type='string';minLength=1;maxLength=1024};expected=@{type='string';minLength=1;maxLength=64};value=@{type='string';minLength=1;maxLength=64};evidenceRevision=@{type='string';pattern='^EV-[a-f0-9]{64}$'};candidateId=@{type='string';pattern='^[a-f0-9]{32}$'}},@('caseId','logicalPath','path','expected','value'),$false),
        @('pmm_candidate_build','Build a PAK from verified structured edits. Re-read packed files and verify hashes. Does not prove game behavior or deploy.',@{caseId=$case;candidateId=@{type='string';pattern='^[a-f0-9]{32}$'}},@('caseId','candidateId'),$false),
        @('pmm_candidates_list','List structured candidates and their integrity state for this case.',@{caseId=$case},@('caseId'),$true),
        @('pmm_asset_inspect','Read cooked asset properties or DataTable values without Unreal. Use query to find named properties; paginate with nextOffset. Source is hash-verified current reference.',@{caseId=$case;logicalPath=@{type='string';minLength=1;maxLength=512};mode=@{type='string';enum=@('properties','datatable')};query=@{type='string';maxLength=128};offset=@{type='integer';minimum=0;maximum=250000};limit=@{type='integer';minimum=1;maximum=100}},@('caseId','logicalPath'),$true),

        @('pmm_reference_prepare','Prepare or refresh the configured Palworld Vanilla reference automatically. Reuses a current reference or running job. No user button required. Then poll pmm_reference_status and continue searching.',@{},@(),$false),
        @('pmm_reference_status','Read reference preparation progress. Use waitSeconds=20 while RUNNING, then continue research when Current.',@{waitSeconds=@{type='integer';minimum=0;maximum=20}},@(),$true),

        @('pmm_request_claim','Claim a published request for ten minutes; returns a private lease token.',@{caseId=$case;requestId=$str},@('caseId','requestId'),$false),
        @('pmm_request_progress','Report visible progress and renew the current lease.',@{caseId=$case;requestId=$str;token=$str;message=@{type='string';minLength=1;maxLength=2000}},@('caseId','requestId','token','message'),$false),
        @('pmm_request_complete','Return an inert response to PMM. Never claims that a mod is built or tested.',@{caseId=$case;requestId=$str;token=$str;message=@{type='string';minLength=1;maxLength=2000};response=@{type='string';minLength=1;maxLength=32000};status=@{type='string';enum=@('RESPONSE_RECEIVED','NEEDS_INPUT','FAILED','BLOCKED','CANDIDATE_BUILT')}},@('caseId','requestId','token','message','response','status'),$false),

        @('pmm_status','Read bridge capabilities and installed PMM tool availability.',@{},@(),$true),
        @('pmm_cases_list','List PMM AIIO case summaries (no provider paths).',@{offset=@{type='integer';minimum=0;maximum=10000}},@(),$true),
        @('pmm_case_get','Read one case summary.',@{caseId=$case},@('caseId'),$true),
        @('pmm_case_create','Create an inactive PMM AIIO case visible in AI & Help.',@{title=$str;description=@{type='string';minLength=1;maxLength=16000};type=@{type='string';enum=@('NEW_MOD','FIX_MOD','COMPATIBILITY','UNDEFINED')}},@('title','description','type'),$false),
        @('pmm_artifacts_list','List staged artifacts for a case.',@{caseId=$case},@('caseId'),$true),
        @('pmm_artifact_put','Stage up to 4 MiB as inert data. ZIPs are not extracted; scripts and binaries are rejected. No import, build or deploy.',@{caseId=$case;extension=@{type='string';enum=@('.txt','.md','.json','.png','.zip','.uasset','.uexp','.ubulk','.uptnl')};base64=@{type='string';minLength=1;maxLength=5592408}},@('caseId','extension','base64'),$false),
        @('pmm_artifact_read','Read at most 64 KiB from a staged artifact; repeat with the returned nextOffset.',@{caseId=$case;artifactId=$str;offset=@{type='integer';minimum=0;maximum=134217728}},@('caseId','artifactId'),$true),
        @('pmm_reference_search','Search current hydrated Game Reference. If unavailable call pmm_reference_prepare and poll status; no user action is needed.',@{query=$str},@('query'),$true),
        @('pmm_reference_export','Copy one current, hash-verified hydrated Vanilla family into this case. Maximum 64 MiB. Does not extract the full game.',@{caseId=$case;logicalPath=@{type='string';minLength=1;maxLength=512}},@('caseId','logicalPath'),$false)
    )
    foreach($d in $defs){
        [pscustomobject]@{name=$d[0];description=$d[1];inputSchema=@{type='object';properties=$d[2];required=@($d[3]);additionalProperties=$false};annotations=@{readOnlyHint=$d[4];destructiveHint=$false;openWorldHint=$false}}
    }
}
function Assert-PMMMCPArguments($Definition,$Arguments) {
    if($null -eq $Arguments){$Arguments=[pscustomobject]@{}}
    if($Arguments -isnot [pscustomobject]){throw 'Arguments must be an object.'}
    $schema=$Definition.inputSchema
    foreach($name in @($Arguments.PSObject.Properties | ForEach-Object { $_.Name })){if(-not $schema.properties.ContainsKey($name)){throw ('Unknown argument: '+$name)}}
    foreach($name in $schema.required){if(@($Arguments.PSObject.Properties | ForEach-Object { $_.Name }) -cnotcontains $name){throw ('Missing argument: '+$name)}}
    foreach($prop in $Arguments.PSObject.Properties){
        $rule=$schema.properties[$prop.Name];$v=$prop.Value
        if($rule.type -eq 'string'){
            if($v -isnot [string] -or ($rule.ContainsKey('minLength') -and $v.Length -lt $rule.minLength) -or ($rule.ContainsKey('maxLength') -and $v.Length -gt $rule.maxLength)){throw ('Invalid string: '+$prop.Name)}
            if($rule.ContainsKey('enum') -and $rule.enum -cnotcontains $v){throw ('Invalid option: '+$prop.Name)}
            if($rule.ContainsKey('pattern') -and $v -cnotmatch $rule.pattern){throw ('Invalid format: '+$prop.Name)}
        }elseif($rule.type -eq 'boolean'){if($v -isnot [bool]){throw 'Boolean argument required.'}}elseif($rule.type -eq 'integer'){
            if(($v -isnot [int] -and $v -isnot [long]) -or $v -lt $rule.minimum -or $v -gt $rule.maximum){throw ('Invalid integer: '+$prop.Name)}
        }
    }
}
function Invoke-PMMMCPTool([string]$Name,$Arguments) {
    if(-not(Get-PMMMCPEnabled)){throw 'MCP is disabled. Enable it in PMM AI Settings.'}
    $definition=@(Get-PMMMCPTools | Where-Object name -CEQ $Name)
    if($definition.Count -ne 1){throw 'Unknown tool.'}
    if($null -eq $Arguments){$Arguments=[pscustomobject]@{}}
    Assert-PMMMCPArguments $definition[0] $Arguments
    if((Get-Variable PMMMCPScopeCase -Scope Script -ErrorAction SilentlyContinue) -and $Script:PMMMCPScopeCase){
        if($Name -eq 'pmm_case_create'){throw 'Case creation is not available in a scoped client.'}
        if(@($Arguments.PSObject.Properties | ForEach-Object {$_.Name}) -contains 'caseId' -and $Arguments.caseId -cne $Script:PMMMCPScopeCase){throw 'This client is scoped to another case.'}
        if($Name -eq 'pmm_cases_list'){return @{cases=@((ConvertTo-PMMMCPCase (Get-PMMMCPCase $Script:PMMMCPScopeCase)));nextOffset=$null}}
    }
    if($Name -eq 'pmm_dependencies_status'){return @{components=@(Get-PMMDependencyCatalog);policy=(Get-PMMDependencyPolicy).mode}}
    if($Name -eq 'pmm_dependency_install'){Write-PMMMCPAudit $Name 'REQUESTED';return (Request-PMMDependencyInstall $Arguments.component $Arguments.caseId)}
    if($Name -eq 'pmm_dependency_job'){return (Get-PMMDependencyJob $Arguments.jobId $Arguments.caseId)}
    if($Name -eq 'pmm_dependency_cancel'){[void](Get-PMMDependencyJob $Arguments.jobId $Arguments.caseId);return (Cancel-PMMDependencyInstall $Arguments.jobId)}

    if($Name -eq 'pmm_desktop_pair'){return (Confirm-PMMDesktopBinding $Arguments)}
    if($Name -eq 'pmm_desktop_case_link'){return (Set-PMMDesktopCaseLink $Arguments)}
    if($Name -eq 'pmm_connection_check'){return (Confirm-PMMDesktopConnection $Arguments)}
    if($Name -eq 'pmm_reference_prepare'){Write-PMMMCPAudit $Name 'STARTED';try{return (Start-PMMMCPReference)}finally{Write-PMMMCPAudit $Name 'FINISHED_ATTEMPT'}}
    if($Name -eq 'pmm_reference_status'){
        $wait=0
        if(@($Arguments.PSObject.Properties | ForEach-Object {$_.Name}) -contains 'waitSeconds'){$wait=[int]$Arguments.waitSeconds}
        $deadline=[DateTime]::UtcNow.AddSeconds($wait)
        do{
            $reference=Get-PMMMCPReferenceStatus
            if($reference.status -ne 'RUNNING' -or [DateTime]::UtcNow -ge $deadline){return $reference}
            Start-Sleep -Milliseconds 500
            if(-not(Get-PMMMCPEnabled)){throw 'MCP is disabled.'}
        }while($true)
    }

    if($Name -eq 'pmm_unreal_status'){
        $s=Get-PMMUnrealStatus
        if(@($Arguments.PSObject.Properties|ForEach-Object{$_.Name}) -contains 'caseId'){
            $e=Get-PMMUnrealEnvironment;$p=Join-Path (Get-PMMUnrealProject $Arguments.caseId) 'verified.json'
            if(Test-Path $p){$v=Read-PMMMCPJson $p;$s.verified=($v.engineRoot -ieq $e.engineRoot -and $v.engineVersion -eq $e.engineVersion -and $v.kitCommit -eq $e.kitCommit)}
        }
        return $s
    }
    if($Name -eq 'pmm_unreal_prepare'){return (Start-PMMUnrealJob 'prepare' $Arguments)}
    if($Name -eq 'pmm_unreal_texture'){
        $fields=@($Arguments.PSObject.Properties|ForEach-Object{$_.Name})
        $allowed=@('caseId','operation','assetName')
        switch($Arguments.operation){
            'import_texture' {$allowed+='sourceArtifactId';if($fields -notcontains 'sourceArtifactId'){throw 'sourceArtifactId required'}}
            'duplicate' {$allowed+='templateId';if($fields -notcontains 'templateId'){throw 'templateId required'}}
            'configure' {$allowed+=@('srgb','filter');if($fields -notcontains 'srgb' -and $fields -notcontains 'filter'){throw 'Provide srgb or filter'}}
        }
        foreach($field in $fields){if($field -notin $allowed){throw 'Argument not applicable to this operation.'}}
        return (Start-PMMUnrealJob $Arguments.operation $Arguments)
    }
    if($Name -eq 'pmm_unreal_cook'){return (Start-PMMUnrealJob 'cook' $Arguments)}
    if($Name -eq 'pmm_unreal_job'){return (Get-PMMUnrealJob $Arguments)}
    if($Name -eq 'pmm_unreal_cancel'){$p=Get-PMMUnrealJobPath $Arguments.caseId $Arguments.jobId;[IO.File]::WriteAllText((Join-Path $p 'cancel'),'cancel');return @{status='CANCEL_REQUESTED'}}
    if($Name -eq 'pmm_unreal_candidates'){return @{candidates=@(Get-PMMUnrealCandidates $Arguments.caseId)}}
    # Serialize bridge clients. UI only shares new cases/artifacts; MCP never edits existing case state.
    $lockPath=Resolve-PMMMCPPath (Get-PMMMCPRoot) 'bridge.lock'
    $lock=Enter-PMMMCPFileLock $lockPath
    try{
        Write-PMMMCPAudit $Name 'STARTED'
        if($Name -in @('pmm_request_claim','pmm_request_progress','pmm_request_complete')){return (Invoke-PMMMCPExchangeTool $Name $Arguments)}
        switch -CaseSensitive ($Name){
            'pmm_asset_edit' {return (Edit-PMMMCPAsset $Arguments)}
            'pmm_candidate_build' {return (Build-PMMMCPAssetCandidate $Arguments)}
            'pmm_candidates_list' {return @{candidates=@(Get-PMMMCPAssetCandidates $Arguments.caseId)}}
            'pmm_asset_inspect' {return (Invoke-PMMMCPAssetInspect $Arguments)}
            'pmm_archive_search' {return (Search-PMMMCPArchive $Arguments)}
            'pmm_asset_prepare' {$f=Prepare-PMMMCPArchiveFamily $Arguments;return @{logicalPath=$f.Asset;bytes=$f.Bytes;prepared=$true;nextTool='pmm_asset_inspect'}}
            'pmm_status' {
                $toolchain=@()
                foreach($pair in @(@('repak','Engine\repak.exe'),@('AssetReader','Engine\AssetReader\PMM.AssetReader.dll'),@('dotnet','Engine\dotnet\dotnet.exe'))){
                    $p=Resolve-PMMMCPPath $Script:Root $pair[1]
                    $installed=Test-Path -LiteralPath $p -PathType Leaf
                    if(-not $installed -and $pair[0] -eq 'dotnet'){
                        $runtimeRoot=Resolve-PMMMCPPath $Script:Root 'Engine\dotnet'
                        if(Test-Path -LiteralPath $runtimeRoot -PathType Container){
                            foreach($version in @(Get-ChildItem -LiteralPath $runtimeRoot -Directory)){
                                if($version.Name -match '^\d+\.\d+\.\d+$'){
                                    $candidate=Resolve-PMMMCPPath $runtimeRoot ($version.Name+'\dotnet.exe')
                                    if(Test-Path -LiteralPath $candidate -PathType Leaf){$installed=$true;break}
                                }
                            }
                        }
                    }
                    $toolchain+=@{name=$pair[0];installed=$installed}
                }
                return @{game='Palworld';reference=(Get-PMMMCPReferenceStatus);capabilities=@{prepareReference='pmm_reference_prepare';referenceProgress='pmm_reference_status';search='pmm_reference_search';export='pmm_reference_export';inspect='pmm_asset_inspect';archiveSearch='pmm_archive_search';prepareAsset='pmm_asset_prepare';edit='pmm_asset_edit';build='pmm_candidate_build';candidates='pmm_candidates_list';unrealEditor='pmm_unreal_status'};bridgeVersion='0.5.0';transport='stdio';enabled=$true;toolchain=$toolchain;scope='PMM cases, MCP artifacts, hydrated Vanilla reference';unrealEditorAdapter=(Get-PMMUnrealStatus);deployment='PMM user interface only'}
            }
            'pmm_cases_list' {
                $offset=0;if(@($Arguments.PSObject.Properties | ForEach-Object { $_.Name }) -contains 'offset'){$offset=$Arguments.offset}
                $root=Resolve-PMMMCPPath $Script:Root 'Workspace\AIIO\Cases'
                $rows=@()
                if(Test-Path -LiteralPath $root){
                    foreach($dir in @(Get-ChildItem -LiteralPath $root -Directory | Sort-Object Name | Select-Object -Skip $offset -First 51)){
                        $c=Get-PMMMCPCase $dir.Name
                        $rows+=,(ConvertTo-PMMMCPCase $c)
                    }
                }
                return @{cases=@($rows | Select-Object -First 50);nextOffset=$(if($rows.Count -gt 50){$offset+50}else{$null})}
            }
            'pmm_case_get' {return (ConvertTo-PMMMCPCase (Get-PMMMCPCase $Arguments.caseId))}
            'pmm_case_create' {
                $caseRoot=Resolve-PMMMCPPath $Script:Root 'Workspace\AIIO\Cases'
                if(@(Get-ChildItem -LiteralPath $caseRoot -Directory -ErrorAction SilentlyContinue).Count -ge 1000){throw 'Case quota exceeded.'}
                $c=New-PMMAIIOCase -Title $Arguments.title -Type $Arguments.type -Description $Arguments.description -Transport MCP
                return (ConvertTo-PMMMCPCase $c)
            }
            'pmm_artifacts_list' {
                $dir=Get-PMMMCPArtifactDir $Arguments.caseId;$rows=@()
                if(Test-Path -LiteralPath $dir){
                    foreach($file in Get-ChildItem -LiteralPath $dir -File){
                        [void](Get-PMMMCPArtifactPath $Arguments.caseId $file.Name)
                        $rows+=@{artifactId=$file.Name;bytes=$file.Length;state='STAGED_UNTRUSTED'}
                    }
                }
                return @{artifacts=$rows}
            }
            'pmm_artifact_put' {
                $bytes=[Convert]::FromBase64String($Arguments.base64)
                if($bytes.Length -gt 4MB){throw 'Upload exceeds 4 MiB.'}
                return (New-PMMMCPArtifact $Arguments.caseId $Arguments.extension $bytes)
            }
            'pmm_artifact_read' {
                $path=Get-PMMMCPArtifactPath $Arguments.caseId $Arguments.artifactId
                $offset=0;if(@($Arguments.PSObject.Properties | ForEach-Object { $_.Name }) -contains 'offset'){$offset=$Arguments.offset}
                $stream=[IO.File]::Open($path,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::Read)
                try{
                    if($stream.Length -gt 128MB -or $offset -gt $stream.Length){throw 'Offset or artifact size outside bounds.'}
                    [void]$stream.Seek($offset,[IO.SeekOrigin]::Begin)
                    $buffer=New-Object byte[] 65536;$read=$stream.Read($buffer,0,$buffer.Length)
                    return @{base64=[Convert]::ToBase64String($buffer,0,$read);offset=$offset;nextOffset=$offset+$read;eof=($offset+$read -eq $stream.Length);totalBytes=$stream.Length}
                }finally{$stream.Dispose()}
            }
            'pmm_reference_search' {
                $families=@(Get-PMMMCPReferenceFamilies)
                $rows=@($families | Where-Object {([string]$_.Asset).IndexOf($Arguments.query,[StringComparison]::OrdinalIgnoreCase) -ge 0} | Select-Object -First 50 | ForEach-Object {@{logicalPath=$_.Asset;bytes=$_.Bytes}})
                return @{families=$rows;limit=50;scope='current hydrated reference'}
            }
            'pmm_reference_export' {
                [void](Get-PMMMCPCase $Arguments.caseId)
                $cooked=Resolve-PMMMCPPath $Script:Root 'Workspace\GameReference\current\cooked'
                [void](Resolve-PMMMCPPath $cooked $Arguments.logicalPath)
                if([IO.Path]::GetExtension($Arguments.logicalPath) -cne '.uasset'){throw 'An exact .uasset logical path is required.'}
                $matches=@(Get-PMMMCPReferenceFamilies | Where-Object { $_.Asset -ceq $Arguments.logicalPath })
                if($matches.Count -ne 1){throw 'Exact hydrated family not found.'}
                $parts=@($matches[0].Parts)
                if($parts.Count -lt 1 -or $parts.Count -gt 4){throw 'Invalid family parts.'}
                $stem=$Arguments.logicalPath.Substring(0,$Arguments.logicalPath.Length-7)
                $prepared=@();[long]$total=0;$seen=@{}
                foreach($part in $parts){
                    $rel=[string]$part.RelativePath;$ext=[IO.Path]::GetExtension($rel)
                    if($ext -cnotin @('.uasset','.uexp','.ubulk','.uptnl') -or $rel -cne ($stem+$ext) -or $seen.ContainsKey($ext)){throw 'Invalid family topology.'}
                    $seen[$ext]=$true;$p=Resolve-PMMMCPPath $cooked $rel
                    $size=(Get-Item -LiteralPath $p).Length;$total+=$size
                    if($size -ne [long]$part.Size -or $total -gt 64MB){throw 'Family exceeds budget or has changed.'}
                    $prepared+=@{path=$p;extension=$ext;logicalPath=$rel;sha256=[string]$part.Sha256}
                }
                if(-not $seen.ContainsKey('.uasset')){throw 'Missing family header.'}
                $usage=Get-PMMMCPUsage (Get-PMMMCPArtifactDir $Arguments.caseId)
                if($usage.bytes+$total -gt 128MB -or $usage.count+$parts.Count -gt 256){throw 'Case artifact quota exceeded.'}
                # Read and hash the exact bytes that will be exposed, before committing any part.
                foreach($part in $prepared){
                    $part.bytes=[IO.File]::ReadAllBytes($part.path)
                    $hash=[Security.Cryptography.SHA256]::Create()
                    try{$actual=([BitConverter]::ToString($hash.ComputeHash($part.bytes))).Replace('-','').ToLowerInvariant()}finally{$hash.Dispose()}
                    if($actual -cne $part.sha256){throw 'Reference bytes failed SHA-256 verification.'}
                }
                $artifacts=@()
                foreach($part in $prepared){
                    $artifact=New-PMMMCPArtifact $Arguments.caseId $part.extension $part.bytes
                    $artifact.logicalPath=$part.logicalPath;$artifact.state='VANILLA_EVIDENCE'
                    $artifacts+=,$artifact
                }
                return @{artifacts=$artifacts;runtime='UNPROVEN'}
            }
        }
    }finally{try{Write-PMMMCPAudit $Name 'FINISHED_ATTEMPT'}finally{$lock.Dispose()}}
}


function Write-PMMMCPAudit([string]$Tool,[string]$Outcome) {
    $path=Resolve-PMMMCPPath (Get-PMMMCPRoot) 'audit.jsonl'
    if((Test-Path -LiteralPath $path) -and (Get-Item -LiteralPath $path).Length -ge 1MB){
        $previous=Resolve-PMMMCPPath (Get-PMMMCPRoot) 'audit.previous.jsonl'
        Move-Item -LiteralPath $path -Destination $previous -Force
    }
    # Never log request bodies, file contents, model text or local game paths.
    $record=@{utc=[DateTime]::UtcNow.ToString('o');tool=$Tool;outcome=$Outcome}
    [IO.File]::AppendAllText($path,($record | ConvertTo-Json -Compress)+[Environment]::NewLine,[Text.UTF8Encoding]::new($false))
}


function Enter-PMMMCPFileLock([string]$Path,[int]$TimeoutSeconds=300){
    $watch=[Diagnostics.Stopwatch]::StartNew()
    while($true){
        try{return [IO.File]::Open($Path,[IO.FileMode]::OpenOrCreate,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)}
        catch [IO.IOException]{
            if(($_.Exception.HResult -band 65535) -notin @(32,33)){throw}
            if($watch.Elapsed.TotalSeconds -ge $TimeoutSeconds){throw 'PMM is busy with another bounded operation. Retry after it finishes.'}
            Start-Sleep -Milliseconds 50
        }
    }
}

function Get-PMMMCPMappingsPath {
  $path=Get-PMMMappingsPath;$root=[IO.Path]::GetFullPath($Script:Root).TrimEnd('\','/')+'\'
  if(-not$path.StartsWith($root,[StringComparison]::OrdinalIgnoreCase)){throw 'Mappings must remain inside PMM.'}
  return (Resolve-PMMMCPPath $Script:Root $path.Substring($root.Length))
}
