$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$modulePath = Join-Path $repoRoot 'windows\modules\codex.ps1'
$source = Get-Content -LiteralPath $modulePath -Raw

if ($source -notmatch 'Add-CodexPrefixRuleIfMissing ''\["probe-rs", "list"\]''') {
    throw 'Codex module must add probe-rs read-only prefix rule'
}

if ($source -notmatch 'Add-CodexPrefixRuleIfMissing ''\["openocd", "--version"\]''') {
    throw 'Codex module must add openocd version prefix rule'
}

if ($source -notmatch 'Add-CodexPrefixRuleIfMissing ''\["dfu-util", "-l"\]''') {
    throw 'Codex module must add dfu-util list prefix rule'
}

if ($source -notmatch 'sandbox_mode = "workspace-write"') {
    throw 'Codex module must create a sandbox permissions example'
}

Write-Host 'codex rules tests passed'
