$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$bootstrapSource = Get-Content -LiteralPath (Join-Path $repoRoot 'windows\bootstrap.ps1') -Raw
$modulePath = Join-Path $repoRoot 'windows\modules\wsl.ps1'

if (-not (Test-Path -LiteralPath $modulePath)) {
    throw 'windows/modules/wsl.ps1 must exist'
}

$moduleSource = Get-Content -LiteralPath $modulePath -Raw

if ($bootstrapSource -notmatch "'wsl'") {
    throw 'Windows bootstrap module registry must include wsl'
}

$defaultSelectionMatch = [regex]::Match($bootstrapSource, 'if \(\[string\]::IsNullOrWhiteSpace\(\$Modules\)\) \{(?<body>[\s\S]*?)\} else \{')
if (-not $defaultSelectionMatch.Success) {
    throw 'Windows bootstrap default module selection block was not found'
}

if ($defaultSelectionMatch.Groups['body'].Value -match "'wsl'") {
    throw 'wsl must remain opt-in and must not be part of the default module set'
}

if ($bootstrapSource -notmatch '\[switch\]\$WslInstallEnabled') {
    throw 'Windows bootstrap must expose WslInstallEnabled as an opt-in switch'
}

if ($bootstrapSource -notmatch '\[string\]\$WslDistribution = "Ubuntu"') {
    throw 'Windows bootstrap must default WslDistribution to Ubuntu'
}

if ($bootstrapSource -notmatch '\[switch\]\$WslConfigEnabled') {
    throw 'Windows bootstrap must expose WslConfigEnabled as an opt-in switch'
}

if ($bootstrapSource -notmatch '\[string\]\$WslMemory = ""') {
    throw 'Windows bootstrap must expose optional WslMemory without a hard-coded limit'
}

if ($bootstrapSource -notmatch '\[int\]\$WslProcessors = 0') {
    throw 'Windows bootstrap must expose optional WslProcessors without a hard-coded limit'
}

if ($bootstrapSource -notmatch '\[string\]\$WslSwap = ""') {
    throw 'Windows bootstrap must expose optional WslSwap without a hard-coded limit'
}

if ($bootstrapSource -notmatch '\[string\]\$WslNetworkingMode = ""') {
    throw 'Windows bootstrap must expose optional WslNetworkingMode without forcing mirrored networking'
}

if ($bootstrapSource -notmatch '\[string\]\$WslAutoMemoryReclaim = "gradual"') {
    throw 'Windows bootstrap must default WslAutoMemoryReclaim to gradual when config is enabled'
}

if ($bootstrapSource -notmatch '\[switch\]\$WslSparseVhdEnabled') {
    throw 'Windows bootstrap must expose sparse VHD as an explicit switch'
}

if ($moduleSource -notmatch "@\('--status'\)") {
    throw 'wsl module must inspect WSL status'
}

if ($moduleSource -notmatch "@\('--list', '--online'\)") {
    throw 'wsl module must show online distributions before install'
}

if (-not $moduleSource.Contains("@('--install', '--distribution', `$WslDistribution, '--no-launch')")) {
    throw 'wsl module must install the selected distribution without launching it'
}

if ($moduleSource -notmatch 'WslInstallEnabled') {
    throw 'WSL install must be guarded by WslInstallEnabled'
}

if ($moduleSource -notmatch 'WslConfigEnabled') {
    throw 'WSL global config changes must be guarded by WslConfigEnabled'
}

if ($moduleSource -notmatch '\.wslconfig') {
    throw 'wsl module must manage the user .wslconfig file'
}

if ($moduleSource -notmatch 'Set-WslConfigValue') {
    throw 'wsl module must update .wslconfig values without replacing the whole file blindly'
}

if ($moduleSource -notmatch 'memory' -or $moduleSource -notmatch 'processors' -or $moduleSource -notmatch 'swap') {
    throw 'wsl module must support WSL2 memory, processors, and swap settings'
}

if ($moduleSource -notmatch 'networkingMode') {
    throw 'wsl module must support optional WSL2 networkingMode setting'
}

if ($moduleSource -notmatch 'autoMemoryReclaim' -or $moduleSource -notmatch 'sparseVhd') {
    throw 'wsl module must support experimental autoMemoryReclaim and sparseVhd settings'
}

if ($moduleSource -notmatch 'wsl --shutdown') {
    throw 'wsl module must warn that wsl --shutdown is required for config changes to take effect'
}

Write-Host 'windows wsl tests passed'
