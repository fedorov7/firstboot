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

foreach ($pattern in @('git', 'rg', 'fd', 'bat', 'eza', 'delta', 'difft', 'difftastic', 'just')) {
    if (-not $source.Contains("Add-CodexPrefixRuleIfMissing '[""$pattern""]'")) {
        throw "Windows Codex module must allow trusted workspace tool: $pattern"
    }
}
if (-not $source.Contains('Add-CodexPrefixRuleIfMissing ''["uv", "run"]''')) {
    throw 'Windows Codex module must allow trusted workspace tool: uv run'
}

if ($source.Contains("Add-CodexPrefixRuleIfMissing '[""pwsh""]'")) {
    throw 'Windows Codex module must not broadly allow pwsh shell wrappers'
}

if (-not $source.Contains('Remove-CodexUnsafeShellWrapperRules')) {
    throw 'Windows Codex module must remove legacy unsafe shell wrapper rules'
}

foreach ($unsafePattern in @('["pwsh"]', '["wsl", "bash", "-lc"]', '["wsl", "-e", "bash"]')) {
    if (-not $source.Contains($unsafePattern)) {
        throw "Windows Codex module must know how to remove unsafe shell wrapper rule: $unsafePattern"
    }
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

if ($bootstrapSource -notmatch '\[string\]\$CodexApprovalsReviewer = "user"') {
    throw 'Windows bootstrap must default CodexApprovalsReviewer to user'
}

if ($bootstrapSource -notmatch '\[string\]\$CodexWindowsSandbox = "elevated"') {
    throw 'Windows bootstrap must default CodexWindowsSandbox to elevated'
}

if ($bootstrapSource -notmatch '\[bool\]\$CodexWindowsSandboxPrivateDesktop = \$true') {
    throw 'Windows bootstrap must default CodexWindowsSandboxPrivateDesktop to true'
}

if ($bootstrapSource -notmatch '\[bool\]\$CodexCheckForUpdateOnStartup = \$true') {
    throw 'Windows bootstrap must default CodexCheckForUpdateOnStartup to true'
}

if ($bootstrapSource -notmatch '\[switch\]\$CodexUpdateEnabled') {
    throw 'Windows bootstrap must expose an opt-in CodexUpdateEnabled switch'
}

if ($source -notmatch 'Set-CodexTopLevelSetting ''sandbox_mode'' "`"\$CodexSandboxMode`""') {
    throw 'Codex module must apply workspace-write sandbox mode to config.toml'
}

if ($source -notmatch 'Set-CodexTopLevelSetting ''approval_policy'' "`"\$CodexApprovalPolicy`""') {
    throw 'Codex module must apply approval_policy from CodexApprovalPolicy to config.toml'
}

if ($source -notmatch 'Set-CodexTopLevelSetting ''approvals_reviewer'' "`"\$CodexApprovalsReviewer`""') {
    throw 'Codex module must apply approvals_reviewer from CodexApprovalsReviewer to config.toml'
}

if ($source -notmatch 'Set-CodexTopLevelSetting ''check_for_update_on_startup'' \$codexCheckForUpdateOnStartup') {
    throw 'Codex module must apply check_for_update_on_startup to config.toml'
}

if ($source -notmatch 'Set-CodexTableSetting ''windows'' ''sandbox'' "`"\$CodexWindowsSandbox`""') {
    throw 'Codex module must apply the native Windows sandbox mode'
}

if ($source -notmatch 'Set-CodexTableSetting ''windows'' ''sandbox_private_desktop'' \$codexWindowsSandboxPrivateDesktop') {
    throw 'Codex module must apply the native Windows private desktop setting'
}

if (-not $source.Contains('match = [')) {
    throw 'Codex prefix rules should include inline match examples for rule validation'
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

if (-not $linuxRoleSource.Contains("codex_approvals_reviewer | default(''user'')")) {
    throw 'Linux Codex role must default approvals_reviewer to user'
}

if (-not $linuxRoleSource.Contains('codex_check_for_update_on_startup | default(true)')) {
    throw 'Linux Codex role must default check_for_update_on_startup to true'
}

if (-not $linuxRoleSource.Contains('codex_update_enabled | default(false)')) {
    throw 'Linux Codex role must expose opt-in Codex CLI updates'
}

if ($linuxRoleSource.Contains('pattern = ["pwsh"]')) {
    throw 'Linux Codex role must not broadly allow pwsh shell wrappers'
}

foreach ($pattern in @('git', 'rg', 'fd', 'bat', 'eza', 'delta', 'difft', 'difftastic', 'just')) {
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

if ($macosBootstrapSource -notmatch 'CODEX_APPROVALS_REVIEWER="\$\{CODEX_APPROVALS_REVIEWER:-user\}"') {
    throw 'macOS bootstrap must default CODEX_APPROVALS_REVIEWER to user'
}

if ($macosBootstrapSource -notmatch 'CODEX_CHECK_FOR_UPDATE_ON_STARTUP="\$\{CODEX_CHECK_FOR_UPDATE_ON_STARTUP:-1\}"') {
    throw 'macOS bootstrap must default CODEX_CHECK_FOR_UPDATE_ON_STARTUP to true'
}

if ($macosBootstrapSource -notmatch 'CODEX_UPDATE_ENABLED="\$\{CODEX_UPDATE_ENABLED:-0\}"') {
    throw 'macOS bootstrap must expose opt-in Codex CLI updates'
}

if (-not $macosCodexSource.Contains('upsert_codex_top_level_setting sandbox_mode "\"$CODEX_SANDBOX_MODE\""')) {
    throw 'macOS Codex module must apply sandbox mode to config.toml'
}

if (-not $macosCodexSource.Contains('upsert_codex_top_level_setting approval_policy "\"$CODEX_APPROVAL_POLICY\""')) {
    throw 'macOS Codex module must apply approval policy to config.toml'
}

if (-not $macosCodexSource.Contains('upsert_codex_top_level_setting approvals_reviewer "\"$CODEX_APPROVALS_REVIEWER\""')) {
    throw 'macOS Codex module must apply approvals_reviewer to config.toml'
}

if (-not $macosCodexSource.Contains('upsert_codex_top_level_setting check_for_update_on_startup "$(toml_bool "$CODEX_CHECK_FOR_UPDATE_ON_STARTUP")"')) {
    throw 'macOS Codex module must apply check_for_update_on_startup to config.toml'
}

if (-not $macosCodexSource.Contains('remove_codex_unsafe_shell_wrapper_rules')) {
    throw 'macOS Codex module must remove legacy unsafe shell wrapper rules'
}

if ($macosCodexSource.Contains("ensure_codex_prefix_rule '[""pwsh""]'")) {
    throw 'macOS Codex module must not broadly allow pwsh shell wrappers'
}

foreach ($pattern in @('git', 'rg', 'fd', 'bat', 'eza', 'delta', 'difft', 'difftastic', 'just')) {
    if (-not $macosCodexSource.Contains("ensure_codex_prefix_rule '[""$pattern""]'")) {
        throw "macOS Codex module must allow trusted workspace tool: $pattern"
    }
}
if (-not $macosCodexSource.Contains('ensure_codex_prefix_rule ''["uv", "run"]''')) {
    throw 'macOS Codex module must allow trusted workspace tool: uv run'
}

Write-Host 'codex rules tests passed'
