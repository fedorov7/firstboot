$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$bootstrapPath = Join-Path $repoRoot 'windows\bootstrap.ps1'
$source = Get-Content -LiteralPath $bootstrapPath -Raw

$allModulesMatch = [regex]::Match($source, '(?s)\$AllModules = @\((.*?)\)')
if (-not $allModulesMatch.Success) {
    throw 'Windows module registry block not found'
}

$allModulesBlock = $allModulesMatch.Groups[1].Value
if ($allModulesBlock -notmatch "'claude'") {
    throw 'claude must remain a known Windows module'
}

$defaultModulesMatch = [regex]::Match($source, '(?s)if \(\[string\]::IsNullOrWhiteSpace\(\$Modules\)\) \{\s*\$SelectedModules = @\((.*?)\)\s*\}')
if (-not $defaultModulesMatch.Success) {
    throw 'Default Windows module selection block not found'
}

$defaultModulesBlock = $defaultModulesMatch.Groups[1].Value
if ($defaultModulesBlock -match "'claude'") {
    throw 'claude must remain an explicit opt-in Windows module'
}

if ($source -notmatch '\[bool\]\$ForceNeovimCleanup\s*=\s*\$false') {
    throw 'Windows Neovim cleanup must be opt-in by default'
}

if ($source -notmatch '\[switch\]\$PreserveNeovimState') {
    throw 'Windows bootstrap must expose PreserveNeovimState as an opt-out'
}

Write-Host 'claude optional module tests passed'
