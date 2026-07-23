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

if (-not $source.Contains('$escapedPattern = [regex]::Escape($Pattern)') -or
    $source -notmatch '\[regex\]::IsMatch\(\$source, "pattern\\s\*=\\s\*\$escapedPattern"\)') {
    throw 'Codex prefix rule detection must use escaped regex matching for TOML array patterns'
}

if ($source.Contains("Add-CodexPrefixRuleIfMissing '[""git""]'")) {
    throw 'Windows Codex module must not broadly allow every git command'
}

foreach ($pattern in @(
    '["git", "status"]',
    '["git", "ls-files"]',
    '["git", "ls-tree"]',
    '["git", "rev-parse"]',
    '["git", "merge-base"]',
    '["git", "remote", "get-url"]',
    '["git", "branch", "--list"]',
    '["git", "branch", "--show-current"]',
    '["git", "tag", "--list"]',
    '["git", "describe"]',
    '["git", "add"]'
)) {
    if (-not $source.Contains("Add-CodexGitAllowRule '$pattern'")) {
        throw "Windows Codex module must allow safe git workflow: $pattern"
    }
}

foreach ($pattern in @(
    '["git", "diff"]',
    '["git", "log"]',
    '["git", "show"]',
    '["git", "grep"]',
    '["git", "blame"]',
    '["git", "config", "--get"]',
    '["git", "config", "--global", "--get"]',
    '["git", "config", "--list"]'
)) {
    if ($source.Contains("Add-CodexGitAllowRule '$pattern'")) {
        throw "Windows Codex module must not allow output-capable git command: $pattern"
    }
}

foreach ($pattern in @('rg', 'fd', 'bat', 'eza', 'delta', 'difft', 'difftastic', 'just')) {
    if (-not $source.Contains("Add-CodexPrefixRuleIfMissing '[""$pattern""]'")) {
        throw "Windows Codex module must allow trusted workspace tool: $pattern"
    }
}
if (-not $source.Contains('Add-CodexPrefixRuleIfMissing ''["uv", "run"]''')) {
    throw 'Windows Codex module must allow trusted workspace tool: uv run'
}

foreach ($pattern in @(
    '["cmake", "--build"]',
    '["ctest"]',
    '["ninja"]',
    '["meson", "compile"]',
    '["meson", "test"]',
    '["cargo", "build"]',
    '["cargo", "check"]',
    '["cargo", "test"]',
    '["cargo", "clippy"]',
    '["cargo", "nextest"]',
    '["python", "-m", "pytest"]',
    '["py", "-m", "pytest"]',
    '["pytest"]',
    '["npm", "test"]',
    '["npm", "run", "test"]',
    '["npm", "run", "build"]',
    '["npm", "run", "lint"]'
)) {
    if (-not $source.Contains("Add-CodexPrefixRuleIfMissing '$pattern'")) {
        throw "Windows Codex module must allow trusted build/test command: $pattern"
    }
}

foreach ($pattern in @(
    '["Set-Item", "Env:\\VCPKG_ROOT"]',
    '["Set-Item", "-Path", "Env:\\VCPKG_ROOT"]',
    '["Set-Item", "Env:\\PROTOC"]',
    '["Set-Item", "-Path", "Env:\\PROTOC"]'
)) {
    if (-not ($source.Contains("Add-CodexPrefixRuleIfMissing '$pattern'") -or $source.Contains("Set-CodexPrefixRule '$pattern'"))) {
        throw "Windows Codex module must allow trusted process-local build environment command: $pattern"
    }
}

if ($source -match 'match = \["Set-Item .*Env:') {
    throw 'Windows Codex build environment rules must not use path-heavy match examples that break execpolicy parsing'
}

foreach ($pattern in @(
    '["winget"]',
    '["git", "push"]',
    '["git", "reset", "--hard"]',
    '["git", "clean"]',
    '["git", "restore"]',
    '["git", "checkout", "--"]',
    '["git", "rebase"]',
    '["git", "reset"]',
    '["git", "commit", "--amend"]',
    '["git", "branch", "-D"]',
    '["git", "branch", "-d"]',
    '["git", "tag", "-d"]',
    '["git", "checkout", "-f"]',
    '["git", "switch", "-C"]',
    '["git", "switch", "--discard-changes"]',
    '["git", "rm"]',
    '["git", "stash", "drop"]',
    '["git", "stash", "clear"]',
    '["git", "reflog", "expire"]',
    '["git", "gc", "--prune"]',
    '["git", "gc", "--prune=now"]',
    '["scoop"]',
    '["choco"]',
    '["rustup"]',
    '["cargo", "install"]',
    '["uv", "tool", "install"]',
    '["uv", "tool", "upgrade"]',
    '["npm", "install", "-g"]',
    '["npm", "install", "--global"]',
    '["python", "-m", "pip", "install"]',
    '["py", "-m", "pip", "install"]',
    '["wsl", "--update"]',
    '["Set-ExecutionPolicy"]',
    '["Set-ItemProperty"]',
    '["New-ItemProperty"]',
    '["reg"]',
    '["netsh"]',
    '["sc"]'
)) {
    if (-not $source.Contains("Add-CodexPrefixRuleIfMissing '$pattern'")) {
        throw "Windows Codex module must prompt for privileged/system tool: $pattern"
    }
}

if ($source.Contains("Add-CodexPrefixRuleIfMissing '[""pwsh""]'")) {
    throw 'Windows Codex module must not broadly allow pwsh shell wrappers'
}

if (-not $source.Contains('Remove-CodexUnsafeShellWrapperRules')) {
    throw 'Windows Codex module must remove legacy unsafe shell wrapper rules'
}

if (-not $source.Contains('Remove-CodexMismatchedGitGcPruneRule')) {
    throw 'Windows Codex module must migrate legacy mismatched git gc --prune rules'
}

foreach ($codexSource in @($source, $linuxRoleSource, $macosCodexSource)) {
    if (-not $codexSource.Contains('match = ["git gc --prune"]')) {
        throw 'Codex git gc --prune prompt example must match its prefix tokens'
    }
    if (-not $codexSource.Contains('match = ["git gc --prune=now"]')) {
        throw 'Codex git gc --prune=now prompt example must match its prefix tokens'
    }
}

foreach ($badBooleanTomlAssignment in @(
    '$codexCheckForUpdateOnStartup =',
    '$codexWindowsSandboxPrivateDesktop =',
    '$codexAppsDestructiveEnabled =',
    '$codexAppsOpenWorldEnabled ='
)) {
    if ($source.Contains($badBooleanTomlAssignment)) {
        throw "Windows Codex module must not assign TOML strings back into typed Boolean parameters: $badBooleanTomlAssignment"
    }
}

if (-not $source.Contains('function ConvertTo-CodexTomlBoolean')) {
    throw 'Windows Codex module must convert Boolean-like values to TOML booleans without mutating typed parameters'
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

if (-not $bootstrapSource.Contains('[string]$CodexMcpAllowlist = "context7,openaiDeveloperDocs,microsoft-learn,memory,fetch,sequential-thinking"')) {
    throw 'Windows bootstrap must include Microsoft Learn in the default Codex MCP allowlist'
}

if ($bootstrapSource -notmatch '\[switch\]\$CodexPlaywrightMcpEnabled') {
    throw 'Windows bootstrap must expose opt-in Playwright MCP'
}

if ($source.Contains('[System.Environment]::SetEnvironmentVariable($CodexGithubTokenEnvVar, $GithubToken') -or
    $source.Contains('Set-Item -Path "Env:\$CodexGithubTokenEnvVar" -Value $GithubToken')) {
    throw 'Windows Codex module must not persist or copy legacy GithubToken values'
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

foreach ($expected in @(
    '[string]$CodexModel = "gpt-5.6-sol"',
    '[string]$CodexModelReasoningEffort = "high"',
    '[string]$CodexServiceTier = "default"',
    '[string]$CodexAppsDefaultToolsApprovalMode = "writes"',
    '[string]$CodexMicrosoftLearnMcpApprovalMode = "writes"',
    '[string]$CodexPlaywrightMcpApprovalMode = "prompt"'
)) {
    if (-not $bootstrapSource.Contains($expected)) {
        throw "Windows bootstrap must expose Codex default: $expected"
    }
}

foreach ($removedDefault in @(
    '[int]$CodexAgentsMaxThreads',
    '[int]$CodexAgentsMaxDepth',
    '[int]$CodexAgentsJobMaxRuntimeSeconds'
)) {
    if ($bootstrapSource.Contains($removedDefault)) {
        throw "Windows bootstrap must not expose removed Codex agents setting: $removedDefault"
    }
}

foreach ($expectedSkill in @(
    'cli-creator',
    'jupyter-notebook',
    'playwright',
    'security-best-practices',
    'winui-app',
    'dispatching-parallel-agents',
    'database-optimizer',
    'sql-pro',
    'mcp-developer'
)) {
    if (-not $bootstrapSource.Contains($expectedSkill)) {
        throw "Windows bootstrap must include Codex skill default: $expectedSkill"
    }
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

if ($source -notmatch 'Set-CodexTopLevelSetting ''model'' "`"\$CodexModel`""') {
    throw 'Codex module must apply model from CodexModel to config.toml'
}

if ($source -notmatch 'Set-CodexTopLevelSetting ''model_reasoning_effort'' "`"\$CodexModelReasoningEffort`""') {
    throw 'Codex module must apply model_reasoning_effort from CodexModelReasoningEffort to config.toml'
}

if ($source -notmatch 'Set-CodexTopLevelSetting ''service_tier'' "`"\$CodexServiceTier`""') {
    throw 'Codex module must apply service_tier from CodexServiceTier to config.toml'
}

if ($source -notmatch 'Set-CodexTopLevelSetting ''approvals_reviewer'' "`"\$CodexApprovalsReviewer`""') {
    throw 'Codex module must apply approvals_reviewer from CodexApprovalsReviewer to config.toml'
}

if ($source -notmatch 'Set-CodexTopLevelSetting ''check_for_update_on_startup'' \$codexCheckForUpdateOnStartupToml') {
    throw 'Codex module must apply check_for_update_on_startup to config.toml'
}

if ($source -notmatch 'Set-CodexTableSetting ''windows'' ''sandbox'' "`"\$CodexWindowsSandbox`""') {
    throw 'Codex module must apply the native Windows sandbox mode'
}

if ($source -notmatch 'Set-CodexTableSetting ''windows'' ''sandbox_private_desktop'' \$codexWindowsSandboxPrivateDesktopToml') {
    throw 'Codex module must apply the native Windows private desktop setting'
}

foreach ($removedSetting in @(
    "Set-CodexTableSetting 'agents' 'max_threads'",
    "Set-CodexTableSetting 'agents' 'max_depth'",
    "Set-CodexTableSetting 'agents' 'job_max_runtime_seconds'"
)) {
    if ($source.Contains($removedSetting)) {
        throw "Codex module must not write removed agent limit setting: $removedSetting"
    }
}

if (-not $source.Contains('Remove-CodexLegacyAgentsTable')) {
    throw 'Codex module must clean legacy managed [agents] table from config.toml'
}

if (-not $source.Contains('Remove-CodexMisplacedTopLevelSettings')) {
    throw 'Codex module must clean invalid top-level keys from Codex-owned tables'
}

if (-not $source.Contains("Set-CodexTableSetting 'apps._default' 'default_tools_approval_mode'")) {
    throw 'Codex module must configure default app approval mode'
}

if (-not $source.Contains("Set-CodexTableSetting 'apps._default' 'destructive_enabled' `$codexAppsDestructiveEnabledToml")) {
    throw 'Codex module must keep destructive app tools disabled by default'
}

if (-not $source.Contains("Set-CodexTableSetting 'apps._default' 'open_world_enabled' `$codexAppsOpenWorldEnabledToml")) {
    throw 'Codex module must keep open-world app tools disabled by default'
}

if (-not $source.Contains('codex mcp add microsoft-learn --url https://learn.microsoft.com/api/mcp')) {
    throw 'Windows Codex module must configure Microsoft Learn MCP'
}

if (-not $source.Contains("codex mcp add playwright -- npx -y '@playwright/mcp@latest'")) {
    throw 'Windows Codex module must configure opt-in Playwright MCP'
}

if (-not $source.Contains('$lines[$i] -match ''^\s*\[''')) {
    throw 'Codex MCP setting updater must stop at any TOML table, including nested MCP tables'
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

if (-not $linuxRoleSource.Contains('codex_playwright_mcp_enabled | default(false)')) {
    throw 'Linux Codex role must expose opt-in Playwright MCP'
}

if (-not $linuxRoleSource.Contains('codex mcp add microsoft-learn --url https://learn.microsoft.com/api/mcp')) {
    throw 'Linux Codex role must configure Microsoft Learn MCP'
}

if (-not $linuxRoleSource.Contains('codex mcp add playwright -- npx -y @playwright/mcp@latest')) {
    throw 'Linux Codex role must configure opt-in Playwright MCP'
}

if ($linuxRoleSource.Contains('pattern = ["pwsh"]')) {
    throw 'Linux Codex role must not broadly allow pwsh shell wrappers'
}

if ($linuxRoleSource.Contains('pattern = ["git"],')) {
    throw 'Linux Codex role must not broadly allow every git command'
}

foreach ($pattern in @(
    'pattern = ["git", "status"]',
    'pattern = ["git", "ls-files"]',
    'pattern = ["git", "ls-tree"]',
    'pattern = ["git", "rev-parse"]',
    'pattern = ["git", "merge-base"]',
    'pattern = ["git", "remote", "get-url"]',
    'pattern = ["git", "branch", "--list"]',
    'pattern = ["git", "branch", "--show-current"]',
    'pattern = ["git", "tag", "--list"]',
    'pattern = ["git", "describe"]',
    'pattern = ["git", "add"]'
)) {
    if (-not $linuxRoleSource.Contains($pattern)) {
        throw "Linux Codex role must allow safe git workflow: $pattern"
    }
}

foreach ($pattern in @(
    'pattern = ["git", "diff"]',
    'pattern = ["git", "log"]',
    'pattern = ["git", "show"]',
    'pattern = ["git", "grep"]',
    'pattern = ["git", "blame"]',
    'pattern = ["git", "config", "--get"]',
    'pattern = ["git", "config", "--global", "--get"]',
    'pattern = ["git", "config", "--list"]'
)) {
    if ($linuxRoleSource.Contains($pattern)) {
        throw "Linux Codex role must not allow output-capable git command: $pattern"
    }
}

foreach ($pattern in @('rg', 'fd', 'bat', 'eza', 'delta', 'difft', 'difftastic', 'just')) {
    if (-not $linuxRoleSource.Contains("pattern = [""$pattern""]")) {
        throw "Linux Codex role must allow trusted workspace tool: $pattern"
    }
}
if (-not $linuxRoleSource.Contains('pattern = ["uv", "run"]')) {
    throw 'Linux Codex role must allow trusted workspace tool: uv run'
}

foreach ($pattern in @(
    'pattern = ["cmake", "--build"]',
    'pattern = ["ctest"]',
    'pattern = ["ninja"]',
    'pattern = ["meson", "compile"]',
    'pattern = ["meson", "test"]',
    'pattern = ["cargo", "build"]',
    'pattern = ["cargo", "check"]',
    'pattern = ["cargo", "test"]',
    'pattern = ["cargo", "clippy"]',
    'pattern = ["cargo", "nextest"]',
    'pattern = ["python", "-m", "pytest"]',
    'pattern = ["python3", "-m", "pytest"]',
    'pattern = ["pytest"]',
    'pattern = ["npm", "test"]',
    'pattern = ["npm", "run", "test"]',
    'pattern = ["npm", "run", "build"]',
    'pattern = ["npm", "run", "lint"]'
)) {
    if (-not $linuxRoleSource.Contains($pattern)) {
        throw "Linux Codex role must allow trusted build/test command: $pattern"
    }
}

foreach ($pattern in @(
    'pattern = ["sudo"]',
    'pattern = ["git", "push"]',
    'pattern = ["git", "reset", "--hard"]',
    'pattern = ["git", "reset"]',
    'pattern = ["git", "clean"]',
    'pattern = ["git", "restore"]',
    'pattern = ["git", "checkout", "--"]',
    'pattern = ["git", "rebase"]',
    'pattern = ["git", "commit", "--amend"]',
    'pattern = ["git", "branch", "-D"]',
    'pattern = ["git", "branch", "-d"]',
    'pattern = ["git", "tag", "-d"]',
    'pattern = ["git", "checkout", "-f"]',
    'pattern = ["git", "switch", "-C"]',
    'pattern = ["git", "switch", "--discard-changes"]',
    'pattern = ["git", "rm"]',
    'pattern = ["git", "stash", "drop"]',
    'pattern = ["git", "stash", "clear"]',
    'pattern = ["git", "reflog", "expire"]',
    'pattern = ["git", "gc", "--prune"]',
    'pattern = ["git", "gc", "--prune=now"]',
    'pattern = ["apt"]',
    'pattern = ["apt-get"]',
    'pattern = ["pacman"]',
    'pattern = ["dnf"]',
    'pattern = ["yay"]',
    'pattern = ["brew", "install"]',
    'pattern = ["brew", "upgrade"]',
    'pattern = ["cargo", "install"]',
    'pattern = ["uv", "tool", "install"]',
    'pattern = ["npm", "install", "-g"]'
)) {
    if (-not $linuxRoleSource.Contains($pattern)) {
        throw "Linux Codex role must prompt for privileged/system tool: $pattern"
    }
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

if (-not $macosBootstrapSource.Contains('CODEX_MCP_ALLOWLIST="${CODEX_MCP_ALLOWLIST:-context7,openaiDeveloperDocs,microsoft-learn,memory,fetch,sequential-thinking}"')) {
    throw 'macOS bootstrap must include Microsoft Learn in the default Codex MCP allowlist'
}

if (-not $macosBootstrapSource.Contains('CODEX_PLAYWRIGHT_MCP_ENABLED="${CODEX_PLAYWRIGHT_MCP_ENABLED:-0}"')) {
    throw 'macOS bootstrap must expose opt-in Playwright MCP'
}

if ($macosBootstrapSource -notmatch 'CODEX_CHECK_FOR_UPDATE_ON_STARTUP="\$\{CODEX_CHECK_FOR_UPDATE_ON_STARTUP:-1\}"') {
    throw 'macOS bootstrap must default CODEX_CHECK_FOR_UPDATE_ON_STARTUP to true'
}

if ($macosBootstrapSource -notmatch 'CODEX_UPDATE_ENABLED="\$\{CODEX_UPDATE_ENABLED:-0\}"') {
    throw 'macOS bootstrap must expose opt-in Codex CLI updates'
}

foreach ($expected in @(
    'CODEX_MODEL="${CODEX_MODEL:-gpt-5.6-sol}"',
    'CODEX_MODEL_REASONING_EFFORT="${CODEX_MODEL_REASONING_EFFORT:-high}"',
    'CODEX_SERVICE_TIER="${CODEX_SERVICE_TIER:-default}"',
    'CODEX_APPS_DEFAULT_TOOLS_APPROVAL_MODE="${CODEX_APPS_DEFAULT_TOOLS_APPROVAL_MODE:-writes}"',
    'CODEX_MICROSOFT_LEARN_MCP_APPROVAL_MODE="${CODEX_MICROSOFT_LEARN_MCP_APPROVAL_MODE:-writes}"',
    'CODEX_PLAYWRIGHT_MCP_APPROVAL_MODE="${CODEX_PLAYWRIGHT_MCP_APPROVAL_MODE:-prompt}"'
)) {
    if (-not $macosBootstrapSource.Contains($expected)) {
        throw "macOS bootstrap must expose Codex default: $expected"
    }
}

foreach ($removedDefault in @(
    'CODEX_AGENTS_MAX_THREADS',
    'CODEX_AGENTS_MAX_DEPTH',
    'CODEX_AGENTS_JOB_MAX_RUNTIME_SECONDS'
)) {
    if ($macosBootstrapSource.Contains($removedDefault)) {
        throw "macOS bootstrap must not expose removed Codex agents setting: $removedDefault"
    }
}

if (-not $macosCodexSource.Contains('upsert_codex_top_level_setting sandbox_mode "\"$CODEX_SANDBOX_MODE\""')) {
    throw 'macOS Codex module must apply sandbox mode to config.toml'
}

if (-not $macosCodexSource.Contains('upsert_codex_top_level_setting model "\"$CODEX_MODEL\""')) {
    throw 'macOS Codex module must apply Codex model to config.toml'
}

if (-not $macosCodexSource.Contains('remove_codex_legacy_agents_table')) {
    throw 'macOS Codex module must clean legacy managed [agents] table from config.toml'
}

if (-not $macosCodexSource.Contains('remove_codex_misplaced_top_level_settings')) {
    throw 'macOS Codex module must clean invalid top-level keys from Codex-owned tables'
}

if (-not $macosCodexSource.Contains('upsert_codex_table_setting apps._default default_tools_approval_mode "\"$CODEX_APPS_DEFAULT_TOOLS_APPROVAL_MODE\""')) {
    throw 'macOS Codex module must apply default app approval mode'
}

if (-not $macosCodexSource.Contains('codex mcp add microsoft-learn --url https://learn.microsoft.com/api/mcp')) {
    throw 'macOS Codex module must configure Microsoft Learn MCP'
}

if (-not $macosCodexSource.Contains('codex mcp add playwright -- npx -y @playwright/mcp@latest')) {
    throw 'macOS Codex module must configure opt-in Playwright MCP'
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

if ($macosCodexSource.Contains("ensure_codex_prefix_rule '[""git""]'")) {
    throw 'macOS Codex module must not broadly allow every git command'
}

foreach ($pattern in @(
    '["git", "status"]',
    '["git", "ls-files"]',
    '["git", "ls-tree"]',
    '["git", "rev-parse"]',
    '["git", "merge-base"]',
    '["git", "remote", "get-url"]',
    '["git", "branch", "--list"]',
    '["git", "branch", "--show-current"]',
    '["git", "tag", "--list"]',
    '["git", "describe"]',
    '["git", "add"]'
)) {
    if (-not $macosCodexSource.Contains("ensure_codex_git_allow_rule '$pattern'")) {
        throw "macOS Codex module must allow safe git workflow: $pattern"
    }
}

foreach ($pattern in @(
    '["git", "diff"]',
    '["git", "log"]',
    '["git", "show"]',
    '["git", "grep"]',
    '["git", "blame"]',
    '["git", "config", "--get"]',
    '["git", "config", "--global", "--get"]',
    '["git", "config", "--list"]'
)) {
    if ($macosCodexSource.Contains("ensure_codex_git_allow_rule '$pattern'")) {
        throw "macOS Codex module must not allow output-capable git command: $pattern"
    }
}

foreach ($pattern in @('rg', 'fd', 'bat', 'eza', 'delta', 'difft', 'difftastic', 'just')) {
    if (-not $macosCodexSource.Contains("ensure_codex_prefix_rule '[""$pattern""]'")) {
        throw "macOS Codex module must allow trusted workspace tool: $pattern"
    }
}
if (-not $macosCodexSource.Contains('ensure_codex_prefix_rule ''["uv", "run"]''')) {
    throw 'macOS Codex module must allow trusted workspace tool: uv run'
}

foreach ($pattern in @(
    '["cmake", "--build"]',
    '["ctest"]',
    '["ninja"]',
    '["meson", "compile"]',
    '["meson", "test"]',
    '["cargo", "build"]',
    '["cargo", "check"]',
    '["cargo", "test"]',
    '["cargo", "clippy"]',
    '["cargo", "nextest"]',
    '["python", "-m", "pytest"]',
    '["python3", "-m", "pytest"]',
    '["pytest"]',
    '["npm", "test"]',
    '["npm", "run", "test"]',
    '["npm", "run", "build"]',
    '["npm", "run", "lint"]'
)) {
    if (-not $macosCodexSource.Contains("ensure_codex_prefix_rule '$pattern'")) {
        throw "macOS Codex module must allow trusted build/test command: $pattern"
    }
}

foreach ($pattern in @(
    '["sudo"]',
    '["git", "push"]',
    '["git", "reset", "--hard"]',
    '["git", "reset"]',
    '["git", "clean"]',
    '["git", "restore"]',
    '["git", "checkout", "--"]',
    '["git", "rebase"]',
    '["git", "commit", "--amend"]',
    '["git", "branch", "-D"]',
    '["git", "branch", "-d"]',
    '["git", "tag", "-d"]',
    '["git", "checkout", "-f"]',
    '["git", "switch", "-C"]',
    '["git", "switch", "--discard-changes"]',
    '["git", "rm"]',
    '["git", "stash", "drop"]',
    '["git", "stash", "clear"]',
    '["git", "reflog", "expire"]',
    '["git", "gc", "--prune"]',
    '["git", "gc", "--prune=now"]',
    '["brew", "install"]',
    '["brew", "upgrade"]',
    '["cargo", "install"]',
    '["uv", "tool", "install"]',
    '["npm", "install", "-g"]'
)) {
    if (-not $macosCodexSource.Contains("ensure_codex_prefix_rule '$pattern'")) {
        throw "macOS Codex module must prompt for privileged/system tool: $pattern"
    }
}

Write-Host 'codex rules tests passed'
