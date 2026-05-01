$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$bootstrapPath = Join-Path $repoRoot 'windows\bootstrap.ps1'
$rustModulePath = Join-Path $repoRoot 'windows\modules\rust.ps1'

$bootstrapSource = Get-Content -LiteralPath $bootstrapPath -Raw
$rustSource = Get-Content -LiteralPath $rustModulePath -Raw

if ($bootstrapSource -notmatch '\[string\[\]\]\$InstallArgs') {
    throw 'Install-CargoBinary must accept string[] InstallArgs for package-specific cargo install flags'
}

if ($bootstrapSource -notmatch 'cargo install \$Package @InstallArgs') {
    throw 'Install-CargoBinary must forward InstallArgs to cargo install'
}

if ($rustSource -notmatch "Command\s*=\s*'cargo-nextest'[\s\S]*?Package\s*=\s*'cargo-nextest'[\s\S]*?InstallArgs\s*=\s*@\('--locked'\)") {
    throw 'cargo-nextest must be installed with --locked'
}

Write-Host 'rust cargo tool tests passed'
