param([ValidateSet('en','es')][string]$Language='en')
& (Join-Path $PSScriptRoot 'v132_bootstrap_regression.ps1') -Language $Language -AssertionScript 'v133_ui_assertions.ps1'
