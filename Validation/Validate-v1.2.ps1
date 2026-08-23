param([switch]$Quiet)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $PSScriptRoot
$Failures = @()

function Add-Failure([string]$Message) {
    $script:Failures += $Message
    Write-Output ("[FAIL] " + $Message)
}

function Add-Pass([string]$Message) {
    if (-not $Quiet) { Write-Output ("[PASS] " + $Message) }
}

function Read-JsonFile([string]$RelativePath) {
    $path = Join-Path $Root $RelativePath
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        Add-Failure ("Missing JSON file: " + $RelativePath)
        return $null
    }
    try {
        return (Get-Content -LiteralPath $path -Raw | ConvertFrom-Json)
    }
    catch {
        Add-Failure ("Invalid JSON: " + $RelativePath + " :: " + $_.Exception.Message)
        return $null
    }
}

function Get-Sha256([string]$RelativePath) {
    $path = Join-Path $Root $RelativePath
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { return $null }
    return (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Test-PE64([string]$RelativePath) {
    $path = Join-Path $Root $RelativePath
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        Add-Failure ("Missing executable: " + $RelativePath)
        return
    }
    try {
        [byte[]]$bytes = [IO.File]::ReadAllBytes($path)
        if ($bytes.Length -lt 256 -or $bytes[0] -ne 0x4d -or $bytes[1] -ne 0x5a) {
            Add-Failure ("Not a PE executable: " + $RelativePath)
            return
        }
        $peOffset = [BitConverter]::ToInt32($bytes, 0x3c)
        if ($peOffset -lt 0 -or ($peOffset + 6) -gt $bytes.Length) {
            Add-Failure ("Invalid PE header: " + $RelativePath)
            return
        }
        if ($bytes[$peOffset] -ne 0x50 -or $bytes[$peOffset + 1] -ne 0x45) {
            Add-Failure ("Missing PE signature: " + $RelativePath)
            return
        }
        $machine = [BitConverter]::ToUInt16($bytes, $peOffset + 4)
        if ($machine -ne 0x8664) {
            Add-Failure ("Executable is not Windows x64: " + $RelativePath + " machine=0x" + $machine.ToString('x4'))
            return
        }
        Add-Pass ($RelativePath + ' is Windows x64')
    }
    catch {
        Add-Failure ("Could not inspect PE executable " + $RelativePath + " :: " + $_.Exception.Message)
    }
}

Write-Output 'PMM v1.2 repository/package validation'
Write-Output ('Root: ' + $Root)

# The old v1.1 repository nested the application under /PMM. v1.2 is deliberately flat.
if (Test-Path -LiteralPath (Join-Path $Root 'PMM') -PathType Container) {
    Add-Failure 'Legacy duplicate top-level PMM/ directory is present. The v1.2 repository must be flat.'
} else {
    Add-Pass 'No duplicate PMM/ directory'
}

$requiredDirs = @('.github','Core','Docs','Documentation','Host','Knowledge','Legacy','Mappings','Runner','Runtime','Tools','UI','Validation')
foreach ($rel in $requiredDirs) {
    if (-not (Test-Path -LiteralPath (Join-Path $Root $rel) -PathType Container)) {
        Add-Failure ('Missing required directory: ' + $rel)
    }
}

$requiredFiles = @(
    'PMM.exe','PMMRuntime.exe','Start.cmd','Setup-Dependencies.ps1',
    'BUILD_ID.txt','VERSION.txt','RELEASE_MANIFEST.json','SHA256SUMS.txt',
    'Runner/routes.json','Runtime/runtime-contract.json','UI/native-shell.json',
    'Knowledge/package-rules.json','Host/main.go','Runtime/main.go',
    'LICENSE','nexuslicense.txt'
)
foreach ($rel in $requiredFiles) {
    if (-not (Test-Path -LiteralPath (Join-Path $Root $rel) -PathType Leaf)) {
        Add-Failure ('Missing required file: ' + $rel)
    }
}

# Public source repository must never contain user/game PAK payloads.
$paks = @(Get-ChildItem -LiteralPath $Root -Filter '*.pak' -File -Recurse -ErrorAction SilentlyContinue)
if ($paks.Count -gt 0) {
    foreach ($pak in $paks) { Add-Failure ('PAK must not be committed: ' + $pak.FullName) }
} else {
    Add-Pass 'No PAK files committed'
}

$manifest = Read-JsonFile 'RELEASE_MANIFEST.json'
$routes = Read-JsonFile 'Runner/routes.json'
$runtimeContract = Read-JsonFile 'Runtime/runtime-contract.json'
$packageRules = Read-JsonFile 'Knowledge/package-rules.json'
$nativeShell = Read-JsonFile 'UI/native-shell.json'

# Parse every external Knowledge JSON file: Knowledge is authoritative editable data, not compiled state.
$knowledgeJson = @(Get-ChildItem -LiteralPath (Join-Path $Root 'Knowledge') -Filter '*.json' -File -ErrorAction SilentlyContinue)
foreach ($file in $knowledgeJson) {
    try {
        $null = Get-Content -LiteralPath $file.FullName -Raw | ConvertFrom-Json
    }
    catch {
        Add-Failure ('Invalid Knowledge JSON: ' + $file.Name + ' :: ' + $_.Exception.Message)
    }
}
if ($knowledgeJson.Count -gt 0) { Add-Pass ('Knowledge JSON parsed: ' + $knowledgeJson.Count) }

$buildId = ''
$version = ''
try { $buildId = (Get-Content -LiteralPath (Join-Path $Root 'BUILD_ID.txt') -Raw).Trim() } catch {}
try { $version = (Get-Content -LiteralPath (Join-Path $Root 'VERSION.txt') -Raw).Trim() } catch {}

if ($null -ne $manifest) {
    if ([string]$manifest.schema -ne 'PMM_RELEASE_MANIFEST_V1') { Add-Failure 'Unexpected RELEASE_MANIFEST schema.' }
    if ([string]$manifest.buildId -ne $buildId) { Add-Failure ('BUILD_ID mismatch: file=' + $buildId + ' manifest=' + [string]$manifest.buildId) }
    if ($version -ne ('v' + [string]$manifest.version)) { Add-Failure ('VERSION mismatch: file=' + $version + ' manifest=v' + [string]$manifest.version) }
    if ([string]$manifest.host.executable -ne 'PMM.exe') { Add-Failure 'Manifest host executable is not PMM.exe.' }
    if ([string]$manifest.runtime.executable -ne 'PMMRuntime.exe') { Add-Failure 'Manifest runtime executable is not PMMRuntime.exe.' }
    if ([bool]$manifest.host.normalStartUsesPowerShell) { Add-Failure 'Manifest says normal Host startup uses PowerShell.' }
    if ([bool]$manifest.runtime.requiresPowerShellFullLanguage) { Add-Failure 'Manifest says PMMRuntime requires PowerShell FullLanguage.' }
    if ([bool]$manifest.fullLanguageCompatibility.hostRequiresFullLanguage) { Add-Failure 'Manifest says PMM Host requires FullLanguage.' }
    if ([bool]$manifest.fullLanguageCompatibility.runtimeRequiresFullLanguage) { Add-Failure 'Manifest says PMM Runtime requires FullLanguage.' }
    if ([bool]$manifest.fullLanguageCompatibility.startupDependencyPathRequiresFullLanguage) { Add-Failure 'Manifest says startup dependency path requires FullLanguage.' }

    $hostHash = Get-Sha256 'PMM.exe'
    $runtimeHash = Get-Sha256 'PMMRuntime.exe'
    if ($hostHash -and $hostHash -ne ([string]$manifest.host.sha256).ToLowerInvariant()) { Add-Failure 'PMM.exe hash does not match RELEASE_MANIFEST.' }
    if ($runtimeHash -and $runtimeHash -ne ([string]$manifest.runtime.sha256).ToLowerInvariant()) { Add-Failure 'PMMRuntime.exe hash does not match RELEASE_MANIFEST.' }
}

if ($null -ne $routes) {
    if ([string]$routes.schema -ne 'PMM_HOST_ROUTES_V1') { Add-Failure 'Unexpected Host route schema.' }
    $startRoute = $routes.routes.start
    if ($null -eq $startRoute) {
        Add-Failure 'Runner/routes.json has no start route.'
    } else {
        if ([string]$startRoute.kind -ne 'native') { Add-Failure 'Normal start route is not native.' }
        if ([string]$startRoute.executable -ne 'PMMRuntime.exe') { Add-Failure 'Normal start route does not target PMMRuntime.exe.' }
        $routeArgs = @($startRoute.arguments)
        if ($routeArgs.Count -lt 1 -or [string]$routeArgs[0] -ne 'start') { Add-Failure 'Normal start route does not call PMMRuntime.exe start.' }
    }
}

if ($null -ne $runtimeContract) {
    if ([string]$runtimeContract.schema -ne 'PMM_RUNTIME_CONTRACT_V1') { Add-Failure 'Unexpected Runtime contract schema.' }
    if ([bool]$runtimeContract.policy.requires_powershell_full_language) { Add-Failure 'Runtime contract requires FullLanguage.' }
    if ([bool]$runtimeContract.policy.bypasses_windows_application_control) { Add-Failure 'Runtime contract claims an application-control bypass.' }
    if ([bool]$runtimeContract.startup.powershell_required) { Add-Failure 'Runtime contract requires PowerShell for normal startup.' }
}

if ($null -ne $nativeShell) {
    if ([string]$nativeShell.title -notmatch 'Palworld Manager Merger') { Add-Failure 'Native UI configuration has an unexpected title.' }
}

# Protect the already runtime-tested Ribunny/Luny package-choice knowledge rule.
if ($null -ne $packageRules) {
    if ([string]$packageRules.schema -ne 'PMM_PACKAGE_RULES_V1') { Add-Failure 'Unexpected package-rules schema.' }
    $rule = @($packageRules.rules | Where-Object { [string]$_.id -eq 'nexus-palworld-4935-ribbuny-pelt-v1' }) | Select-Object -First 1
    if ($null -eq $rule) {
        Add-Failure 'Runtime-tested Ribunny package-choice rule is missing.'
    } else {
        $members = @($rule.members)
        foreach ($member in @('pelt1-luny_P.pak','pelt1-ribunny_P.pak','pelt1-ribunny-shine_P.pak')) {
            if ($members -notcontains $member) { Add-Failure ('Ribunny rule member missing: ' + $member) }
        }
        $luny = @($rule.choices | Where-Object { [string]$_.id -eq 'luny' }) | Select-Object -First 1
        $ribunny = @($rule.choices | Where-Object { [string]$_.id -eq 'ribunny-shine' }) | Select-Object -First 1
        if ($null -eq $luny -or [string]$luny.label -ne 'Luny') { Add-Failure 'Ribunny rule Luny choice is missing/changed.' }
        if ($null -eq $ribunny -or [string]$ribunny.label -ne 'Ribunny + Shine') { Add-Failure 'Ribunny + Shine choice is missing/changed.' }
    }
}

# The public bootstrap is now only a CLM-safe delegate. The old v1.1 SmokeTest incorrectly
# required the implementation itself to remain inside this script.
$setupPath = Join-Path $Root 'Setup-Dependencies.ps1'
if (Test-Path -LiteralPath $setupPath -PathType Leaf) {
    $setup = Get-Content -LiteralPath $setupPath -Raw
    foreach ($marker in @('PMMRuntime.exe','dependencies','ensure')) {
        if ($setup -notmatch [regex]::Escape($marker)) { Add-Failure ('Setup wrapper marker missing: ' + $marker) }
    }
    foreach ($forbidden in @('System.Collections.Generic','Add-Type','ExpectedRepakSha256','Repair-OodleIfUnexpected','Test-RuntimeInventory')) {
        if ($setup -match [regex]::Escape($forbidden)) { Add-Failure ('Legacy FullLanguage dependency implementation leaked back into public Setup wrapper: ' + $forbidden) }
    }
}

Test-PE64 'PMM.exe'
Test-PE64 'PMMRuntime.exe'

if ($Failures.Count -gt 0) {
    Write-Output ''
    Write-Output ('PMM_V12_VALIDATION_FAILED count=' + $Failures.Count)
    foreach ($failure in $Failures) { Write-Output (' - ' + $failure) }
    exit 1
}

Write-Output ''
Write-Output 'PMM_V12_VALIDATION_OK'
Write-Output ('BUILD_ID=' + $buildId)
Write-Output ('VERSION=' + $version)
Write-Output 'FULLLANGUAGE_INDEPENDENT_STARTUP=PASS'
Write-Output 'RIBBUNNY_PACKAGE_RULE=PASS'
exit 0
