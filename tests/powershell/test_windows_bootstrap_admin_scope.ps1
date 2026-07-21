$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$bootstrapSource = Get-Content -LiteralPath (Join-Path $repoRoot 'windows\bootstrap.ps1') -Raw

if ($bootstrapSource -match '(?m)^#Requires\s+-RunAsAdministrator') {
    throw 'Windows bootstrap must not require Administrator before parsing module selection'
}

foreach ($expected in @(
    'function Assert-AdministratorForSelectedModules',
    '$NonAdminModules = @(',
    "'codex'",
    "'claude'",
    'Assert-AdministratorForSelectedModules -SelectedModules $SelectedModules'
)) {
    if (-not $bootstrapSource.Contains($expected)) {
        throw "Windows bootstrap must scope Administrator requirement after module selection: $expected"
    }
}

Write-Host 'windows bootstrap admin scope tests passed'
