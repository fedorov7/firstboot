$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$bootstrapSource = Get-Content -LiteralPath (Join-Path $repoRoot 'windows\bootstrap.ps1') -Raw
$modulePath = Join-Path $repoRoot 'windows\modules\sudo.ps1'

if (-not (Test-Path -LiteralPath $modulePath)) {
    throw 'windows/modules/sudo.ps1 must exist'
}

$moduleSource = Get-Content -LiteralPath $modulePath -Raw

if ($bootstrapSource -notmatch "'sudo'") {
    throw 'Windows bootstrap module registry must include sudo'
}

$defaultSelectionMatch = [regex]::Match($bootstrapSource, 'if \(\[string\]::IsNullOrWhiteSpace\(\$Modules\)\) \{(?<body>[\s\S]*?)\} else \{')
if (-not $defaultSelectionMatch.Success) {
    throw 'Windows bootstrap default module selection block was not found'
}

if ($defaultSelectionMatch.Groups['body'].Value -match "'sudo'") {
    throw 'sudo must remain opt-in and must not be part of the default module set'
}

if ($bootstrapSource -notmatch '\[switch\]\$WindowsSudoEnabled') {
    throw 'Windows bootstrap must expose WindowsSudoEnabled as an opt-in switch'
}

if ($bootstrapSource -notmatch '\[string\]\$WindowsSudoMode = "forceNewWindow"') {
    throw 'Windows bootstrap must default WindowsSudoMode to forceNewWindow'
}

if ($moduleSource -notmatch 'WindowsSudoEnabled') {
    throw 'sudo configuration must be guarded by WindowsSudoEnabled'
}

if (-not $moduleSource.Contains("@('config', '--enable', `$WindowsSudoMode)")) {
    throw 'sudo module must configure sudo with the selected mode'
}

if ($moduleSource -notmatch 'forceNewWindow' -or $moduleSource -notmatch 'disableInput' -or $moduleSource -notmatch 'normal') {
    throw 'sudo module must validate supported sudo modes'
}

Write-Host 'windows sudo tests passed'
