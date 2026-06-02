$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$modulePath = Join-Path $repoRoot 'windows\modules\codex.ps1'
$source = Get-Content -LiteralPath $modulePath -Raw
$bootstrapSource = Get-Content -LiteralPath (Join-Path $repoRoot 'windows\bootstrap.ps1') -Raw
$linuxRoleSource = Get-Content -LiteralPath (Join-Path $repoRoot 'roles\codex\tasks\main.yml') -Raw
$macosBootstrapSource = Get-Content -LiteralPath (Join-Path $repoRoot 'macos\bootstrap.sh') -Raw
$macosCodexSource = Get-Content -LiteralPath (Join-Path $repoRoot 'macos\modules\codex.sh') -Raw

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

if ($source.Contains('-like "*pattern = $Pattern*"')) {
    throw 'Codex prefix rule detection must not use wildcard matching for TOML array patterns'
}

if (-not $source.Contains('$source.Contains("pattern = $Pattern")')) {
    throw 'Codex prefix rule detection must use literal matching for TOML array patterns'
}

foreach ($pattern in @('git', 'rg', 'fd', 'bat', 'eza', 'delta', 'difft', 'difftastic', 'just', 'pwsh')) {
    if (-not $source.Contains("Add-CodexPrefixRuleIfMissing '[""$pattern""]'")) {
        throw "Windows Codex module must allow trusted workspace tool: $pattern"
    }
}
if (-not $source.Contains('Add-CodexPrefixRuleIfMissing ''["uv", "run"]''')) {
    throw 'Windows Codex module must allow trusted workspace tool: uv run'
}

foreach ($pattern in @(
    'Get-Content',
    'Select-String',
    'Get-ChildItem',
    'Get-Item',
    'Test-Path',
    'Resolve-Path',
    'Get-Location',
    'Get-FileHash',
    'Select-Object',
    'Sort-Object',
    'Measure-Object',
    'Compare-Object',
    'Format-Table',
    'Format-List',
    'Out-String'
)) {
    if (-not $source.Contains("Add-CodexPrefixRuleIfMissing '[""$pattern""]'")) {
        throw "Windows Codex module must allow trusted PowerShell read/output command: $pattern"
    }
}

if ($source -notmatch 'sandbox_mode = "workspace-write"') {
    throw 'Codex module must create a sandbox permissions example'
}

if ($bootstrapSource -notmatch '\[string\]\$CodexSandboxMode = "workspace-write"') {
    throw 'Windows bootstrap must default CodexSandboxMode to workspace-write'
}

if ($bootstrapSource -notmatch '\[string\]\$CodexApprovalPolicy = "on-request"') {
    throw 'Windows bootstrap must default CodexApprovalPolicy to on-request'
}

if ($source -notmatch 'Set-CodexTopLevelSetting ''sandbox_mode'' "`"\$CodexSandboxMode`""') {
    throw 'Codex module must apply workspace-write sandbox mode to config.toml'
}

if ($source -notmatch 'Set-CodexTopLevelSetting ''approval_policy'' "`"\$CodexApprovalPolicy`""') {
    throw 'Codex module must apply approval_policy from CodexApprovalPolicy to config.toml'
}

if ($source -notmatch 'approval_policy = "on-request"') {
    throw 'Codex permissions example must use approval_policy = "on-request"'
}

if ($linuxRoleSource -notmatch 'Set Codex workspace access defaults') {
    throw 'Linux Codex role must apply workspace access defaults to config.toml'
}

if ($linuxRoleSource -notmatch 'codex_approval_policy \| default\(''on-request''\)') {
    throw 'Linux Codex role must default approval_policy to on-request'
}

foreach ($pattern in @('git', 'rg', 'fd', 'bat', 'eza', 'delta', 'difft', 'difftastic', 'just', 'pwsh')) {
    if (-not $linuxRoleSource.Contains("pattern = [""$pattern""]")) {
        throw "Linux Codex role must allow trusted workspace tool: $pattern"
    }
}
if (-not $linuxRoleSource.Contains('pattern = ["uv", "run"]')) {
    throw 'Linux Codex role must allow trusted workspace tool: uv run'
}

if ($macosBootstrapSource -notmatch 'CODEX_SANDBOX_MODE="\$\{CODEX_SANDBOX_MODE:-workspace-write\}"') {
    throw 'macOS bootstrap must default CODEX_SANDBOX_MODE to workspace-write'
}

if ($macosBootstrapSource -notmatch 'CODEX_APPROVAL_POLICY="\$\{CODEX_APPROVAL_POLICY:-on-request\}"') {
    throw 'macOS bootstrap must default CODEX_APPROVAL_POLICY to on-request'
}

if (-not $macosCodexSource.Contains('upsert_codex_top_level_setting sandbox_mode "\"$CODEX_SANDBOX_MODE\""')) {
    throw 'macOS Codex module must apply sandbox mode to config.toml'
}

if (-not $macosCodexSource.Contains('upsert_codex_top_level_setting approval_policy "\"$CODEX_APPROVAL_POLICY\""')) {
    throw 'macOS Codex module must apply approval policy to config.toml'
}

foreach ($pattern in @('git', 'rg', 'fd', 'bat', 'eza', 'delta', 'difft', 'difftastic', 'just', 'pwsh')) {
    if (-not $macosCodexSource.Contains("ensure_codex_prefix_rule '[""$pattern""]'")) {
        throw "macOS Codex module must allow trusted workspace tool: $pattern"
    }
}
if (-not $macosCodexSource.Contains('ensure_codex_prefix_rule ''["uv", "run"]''')) {
    throw 'macOS Codex module must allow trusted workspace tool: uv run'
}

Write-Host 'codex rules tests passed'
