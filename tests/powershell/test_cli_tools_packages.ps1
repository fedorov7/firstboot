$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$modulePath = Join-Path $repoRoot 'windows\modules\cli_tools.ps1'
$source = Get-Content -LiteralPath $modulePath -Raw

if ($source -match "Watchexec\.Watchexec") {
    throw 'watchexec is not available in the winget source and must not use Watchexec.Watchexec'
}

if ($source -notmatch "Id\s*=\s*'XAMPPRocky\.Tokei'") {
    throw 'tokei must use the winget package id XAMPPRocky.Tokei'
}

if ($source -notmatch "Install-CargoBinary\s+-Command\s+'watchexec'\s+-Package\s+'watchexec-cli'\s+-InstallArgs\s+@\('--locked'\)") {
    throw 'watchexec must be installed via cargo as watchexec-cli with --locked'
}

Write-Host 'cli tools package tests passed'
