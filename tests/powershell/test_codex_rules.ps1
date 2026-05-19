$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$modulePath = Join-Path $repoRoot 'windows\modules\codex.ps1'
$source = Get-Content -LiteralPath $modulePath -Raw

if ($source -notmatch 'Add-CodexPrefixRuleIfMissing ''\["probe-rs"\]''') {
    throw 'Codex module must add probe-rs hardware prefix rule'
}

if ($source -notmatch 'Add-CodexPrefixRuleIfMissing ''\["openocd"\]''') {
    throw 'Codex module must add openocd hardware prefix rule'
}

if ($source -notmatch 'Add-CodexPrefixRuleIfMissing ''\["dfu-util"\]''') {
    throw 'Codex module must add dfu-util hardware prefix rule'
}

if ($source -notmatch 'Add-CodexPrefixRuleIfMissing ''\["stty"\]''') {
    throw 'Codex module must add stty serial prefix rule'
}

if ($source -notmatch 'sandbox_mode = "workspace-write"') {
    throw 'Codex module must create a sandbox permissions example'
}

Write-Host 'codex rules tests passed'
