$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$bootstrapSource = Get-Content -LiteralPath (Join-Path $repoRoot 'windows\bootstrap.ps1') -Raw
$modulePath = Join-Path $repoRoot 'windows\modules\dev_drive.ps1'

if (-not (Test-Path -LiteralPath $modulePath)) {
    throw 'windows/modules/dev_drive.ps1 must exist'
}

$moduleSource = Get-Content -LiteralPath $modulePath -Raw

if ($bootstrapSource -notmatch "'dev_drive'") {
    throw 'Windows bootstrap module registry must include dev_drive'
}

$defaultSelectionMatch = [regex]::Match($bootstrapSource, 'if \(\[string\]::IsNullOrWhiteSpace\(\$Modules\)\) \{(?<body>[\s\S]*?)\} else \{')
if (-not $defaultSelectionMatch.Success) {
    throw 'Windows bootstrap default module selection block was not found'
}

if ($defaultSelectionMatch.Groups['body'].Value -match "'dev_drive'") {
    throw 'dev_drive must remain opt-in and must not be part of the default module set'
}

if ($bootstrapSource -notmatch '\[string\]\$DevDrivePath = ""') {
    throw 'Windows bootstrap must expose DevDrivePath parameter'
}

if ($bootstrapSource -notmatch '\[switch\]\$DevDriveTrustEnabled') {
    throw 'Windows bootstrap must expose DevDriveTrustEnabled opt-in switch'
}

if ($moduleSource -notmatch "@\('devdrv', 'query'") {
    throw 'dev_drive module must query Dev Drive status'
}

if ($moduleSource -notmatch "@\('devdrv', 'trust'") {
    throw 'dev_drive module must support trusting a Dev Drive'
}

if ($moduleSource -notmatch 'DevDriveTrustEnabled') {
    throw 'Dev Drive trust must be guarded by DevDriveTrustEnabled'
}

if ($moduleSource -match 'format ') {
    throw 'dev_drive module must not format or create drives'
}

Write-Host 'windows dev drive tests passed'
