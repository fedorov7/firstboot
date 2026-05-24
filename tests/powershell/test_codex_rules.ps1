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

if ($source -notmatch 'sandbox_mode = "workspace-write"') {
    throw 'Codex module must create a sandbox permissions example'
}

if ($bootstrapSource -notmatch '\[string\]\$CodexSandboxMode = "workspace-write"') {
    throw 'Windows bootstrap must default CodexSandboxMode to workspace-write'
}

if ($bootstrapSource -notmatch '\[string\]\$CodexApprovalPolicy = "never"') {
    throw 'Windows bootstrap must default CodexApprovalPolicy to never'
}

if ($source -notmatch 'Set-CodexTopLevelSetting ''sandbox_mode'' "`"\$CodexSandboxMode`""') {
    throw 'Codex module must apply workspace-write sandbox mode to config.toml'
}

if ($source -notmatch 'Set-CodexTopLevelSetting ''approval_policy'' "`"\$CodexApprovalPolicy`""') {
    throw 'Codex module must apply approval_policy = "never" to config.toml'
}

if ($source -notmatch 'approval_policy = "never"') {
    throw 'Codex permissions example must use approval_policy = "never"'
}

if ($linuxRoleSource -notmatch 'Set Codex workspace access defaults') {
    throw 'Linux Codex role must apply workspace access defaults to config.toml'
}

if ($linuxRoleSource -notmatch 'codex_approval_policy \| default\(''never''\)') {
    throw 'Linux Codex role must default approval_policy to never'
}

if ($macosBootstrapSource -notmatch 'CODEX_SANDBOX_MODE="\$\{CODEX_SANDBOX_MODE:-workspace-write\}"') {
    throw 'macOS bootstrap must default CODEX_SANDBOX_MODE to workspace-write'
}

if ($macosBootstrapSource -notmatch 'CODEX_APPROVAL_POLICY="\$\{CODEX_APPROVAL_POLICY:-never\}"') {
    throw 'macOS bootstrap must default CODEX_APPROVAL_POLICY to never'
}

if (-not $macosCodexSource.Contains('upsert_codex_top_level_setting sandbox_mode "\"$CODEX_SANDBOX_MODE\""')) {
    throw 'macOS Codex module must apply sandbox mode to config.toml'
}

if (-not $macosCodexSource.Contains('upsert_codex_top_level_setting approval_policy "\"$CODEX_APPROVAL_POLICY\""')) {
    throw 'macOS Codex module must apply approval policy to config.toml'
}

Write-Host 'codex rules tests passed'
