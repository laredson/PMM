function New-PMMAuatUpgrade {
 param([string]$SourcePak,[string]$GamePak,[string]$OutputDirectory,$Recipe)
 $expected='b6af99dfd1d597b9a04458c884aacb5d09f8c3f30ca77f819d67d9a87e183f40'
 if((Get-Sha256 $SourcePak) -cne $expected){throw 'AUAT V1 source hash is not recognized.'}
 if(-not$Recipe -or $Recipe.id -ne 'fixlab-auat-v1-to-v1-1-pw104'){throw 'AUAT recipe metadata missing.'}
 $mapping=Get-PMMMappingsPath;$legacy=Join-Path $Script:Root 'Resources/Mappings/Historical/Palworld-1.0.3.usmap'
 if((Get-Sha256 $mapping) -cne $Recipe.target.knownMappingsSha256){throw 'AUAT 1.1 requires Mapping104. Select the 1.0.4 mapping in Settings.'}
 if((Get-Sha256 $legacy) -cne $Recipe.implementation.legacyMappingsSha256){throw 'Historical donor mappings are missing or changed.'}
 $gameIdentity=Get-Item -LiteralPath $GamePak;$stamp=[string]$gameIdentity.Length+'|'+$gameIdentity.LastWriteTimeUtc.Ticks
 $stage=Join-Path $OutputDirectory ('attempt-'+[guid]::NewGuid().ToString('N'));[void][IO.Directory]::CreateDirectory($stage)
 $logical='Pal/Content/Pal/Blueprint/System/BP_PalGameSetting.uasset'
 $table='Pal/Content/Pal/DataTable/Technology/DT_TechnologyRecipeUnlock_Common.uasset'
 $donor=Export-PakAssetFamilyExact $SourcePak $logical (Join-Path $stage 'donor')
 $current=Export-PakAssetFamilyExact $GamePak $logical (Join-Path $stage 'current')
 $technology=Export-PakAssetFamilyExact $GamePak $table (Join-Path $stage 'current')
 foreach($part in $Recipe.implementation.currentFamilyHashes.PSObject.Properties){
  if((Get-Sha256 (Get-PMMSafePakOutputPath (Join-Path $stage 'current') $part.Name)) -cne $part.Value){throw ('Game family differs from validated 1.0.4: '+$part.Name)}
 }
 $cooked=Join-Path $stage 'cooked';$output=Get-PMMSafePakOutputPath $cooked $logical
 $dotnet=Get-PMMDotnetHostPath
 if(-not$dotnet -or -not(Test-Path -LiteralPath $dotnet)){throw 'PMM .NET runtime is missing. Repair dependencies in Settings.'}
 $tool=Join-Path $Script:Root 'Engine/AssetTools/PMM.AssetTools.dll'
 $messages=@(& $dotnet $tool 'auat-upgrade' $current.HeaderPath $mapping $donor.HeaderPath $legacy $technology.HeaderPath $output 2>&1)
 if($LASTEXITCODE){throw ('AUAT rebuild failed: '+($messages -join ' '))}
 $proof=($messages -join [Environment]::NewLine)|ConvertFrom-Json
 if($proof.status -ne 'STRUCTURAL_PASS' -or $proof.technologies -ne 588){throw 'Unexpected AUAT proof.'}
 $pak=Join-Path $stage 'AutoUnlockAllTechnology_v1.1_P.pak';Pack-Pak $cooked $pak|Out-Null
 if(-not(Test-Pak $pak)){throw 'AUAT PAK verification failed.'}
 $readback=Export-PakAssetFamilyExact $pak $logical (Join-Path $stage 'readback')
 foreach($relative in $readback.Files){if((Get-Sha256 (Join-Path $cooked $relative)) -cne (Get-Sha256 (Join-Path $readback.Root $relative))){throw 'AUAT PAK readback mismatch.'}}
 $after=Get-Item -LiteralPath $GamePak
 if(([string]$after.Length+'|'+$after.LastWriteTimeUtc.Ticks) -cne $stamp -or (Get-Sha256 $SourcePak) -cne $expected){throw 'An input changed during build; candidate was not published.'}
 $manifest=[ordered]@{Schema='PMM_AUAT_UPGRADE_V1';RecipeId=$Recipe.id;Version='1.1';GameVersion='1.0.4';SourceSha256=$expected;MappingsSha256=(Get-Sha256 $mapping);CurrentFamilyHashes=$Recipe.implementation.currentFamilyHashes;OutputPath=$pak;OutputSha256=(Get-Sha256 $pak);StructuralValidation=$proof;RuntimeValidation='UNPROVEN';Deployed=$false;BuiltUtc=[DateTime]::UtcNow.ToString('o')}
 $report=Join-Path $stage 'build-report.json';Write-PMMJsonAtomic -Path $report -Value $manifest -Depth 12
 return [pscustomobject]@{OutputPath=$pak;ReportPath=$report;Mode='auat-property-upgrade';Validation='Structural PASS: exact source, current 1.0.4 families, 588 technologies, lossless serialization and PAK readback. Game test required.'}
}
function Invoke-PMMAuatFixLabBuild($Job,$Recipe,[string]$VariantId) {
 if($VariantId -ne 'auat-v1-1'){throw 'Unknown AUAT variant.'}
 $sources=@($Job.Analysis.PakInventory|Where-Object{$_.Sha256 -ceq 'b6af99dfd1d597b9a04458c884aacb5d09f8c3f30ca77f819d67d9a87e183f40'})
 if($sources.Count -ne 1){throw 'Exactly one known AUAT V1 PAK is required.'}
 $game=Join-Path (Get-PMMConfig).GamePath 'Pal/Content/Paks/Pal-Windows.pak'
 return (New-PMMAuatUpgrade $sources[0].Path $game (Join-Path (Get-PMMFixLabJobPath $Job.JobId) 'Output') $Recipe)
}
