$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$bootstrapSource = Get-Content -LiteralPath (Join-Path $repoRoot 'windows\bootstrap.ps1') -Raw
$modulePath = Join-Path $repoRoot 'windows\modules\dev_settings.ps1'
$sshSource = Get-Content -LiteralPath (Join-Path $repoRoot 'windows\modules\ssh.ps1') -Raw

if (-not (Test-Path -LiteralPath $modulePath)) {
    throw 'windows/modules/dev_settings.ps1 must exist'
}

$moduleSource = Get-Content -LiteralPath $modulePath -Raw

if ($bootstrapSource -notmatch "'dev_settings'") {
    throw 'Windows bootstrap default modules must include dev_settings'
}

if ($bootstrapSource -notmatch '\[switch\]\$WindowsDeveloperModeEnabled') {
    throw 'Windows bootstrap must expose WindowsDeveloperModeEnabled as an opt-in switch'
}

if ($moduleSource -notmatch 'LongPathsEnabled') {
    throw 'dev_settings must configure Windows long path support'
}

if ($moduleSource -notmatch 'HideFileExt') {
    throw 'dev_settings must configure Explorer to show file extensions'
}

if ($moduleSource -notmatch 'Hidden') {
    throw 'dev_settings must configure Explorer hidden-file visibility'
}

if ($moduleSource -notmatch 'AllowDevelopmentWithoutDevLicense') {
    throw 'dev_settings must support optional Windows Developer Mode'
}

if ($moduleSource -notmatch 'WindowsDeveloperModeEnabled') {
    throw 'Windows Developer Mode must be guarded by the opt-in switch'
}

if ($sshSource -notmatch "Key = 'core\.fsmonitor';\s+Value = 'true'") {
    throw 'global git config must enable built-in fsmonitor'
}

if ($sshSource -notmatch "Key = 'core\.untrackedCache';\s+Value = 'true'") {
    throw 'global git config must enable untracked cache'
}

Write-Host 'windows dev settings tests passed'
