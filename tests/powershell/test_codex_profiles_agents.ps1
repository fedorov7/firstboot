$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$windowsBootstrapSource = Get-Content -LiteralPath (Join-Path $repoRoot 'windows\bootstrap.ps1') -Raw
$windowsCodexSource = Get-Content -LiteralPath (Join-Path $repoRoot 'windows\modules\codex.ps1') -Raw
$linuxRoleSource = Get-Content -LiteralPath (Join-Path $repoRoot 'roles\codex\tasks\main.yml') -Raw
$macosBootstrapSource = Get-Content -LiteralPath (Join-Path $repoRoot 'macos\bootstrap.sh') -Raw
$macosCodexSource = Get-Content -LiteralPath (Join-Path $repoRoot 'macos\modules\codex.sh') -Raw

foreach ($expected in @(
    '[bool]$CodexProfilesEnabled = $true',
    '[string]$CodexLeanProfileModel = "gpt-5.6-terra"',
    '[string]$CodexLeanProfileReasoningEffort = "medium"',
    '[bool]$CodexCustomAgentsEnabled = $true',
    '[string]$CodexCustomAgents = "explorer-terra,reviewer-deep,docs-researcher,tester-terra,architect-deep,knowledge-curator"',
    '[bool]$CodexPruneDisabledOptionalMcp = $true'
)) {
    if (-not $windowsBootstrapSource.Contains($expected)) {
        throw "Windows bootstrap must expose Codex profile/agent default: $expected"
    }
}

foreach ($expected in @(
    'Set-CodexProfileFiles',
    'Set-CodexManagedFile -Path (Join-Path $codexDir ''lean.config.toml'')',
    'Set-CodexManagedFile -Path (Join-Path $codexDir ''deep.config.toml'')',
    'Set-CodexCustomAgentFiles',
    "explorer-terra",
    "reviewer-deep",
    "docs-researcher",
    "tester-terra",
    "architect-deep",
    "knowledge-curator",
    "Candidate: short title",
    '$CodexPruneDisabledOptionalMcp',
    "Remove-CodexMcpIfConfigured 'playwright'"
)) {
    if (-not $windowsCodexSource.Contains($expected)) {
        throw "Windows Codex module must manage profiles, custom agents, and disabled optional MCP: $expected"
    }
}

foreach ($expected in @(
    'codex_profiles_enabled: true',
    'codex_lean_profile_model: gpt-5.6-terra',
    'codex_lean_profile_reasoning_effort: medium',
    'codex_custom_agents_enabled: true',
    'codex_custom_agents:',
    '- explorer-terra',
    '- reviewer-deep',
    '- docs-researcher',
    '- tester-terra',
    '- architect-deep',
    '- knowledge-curator',
    'codex_prune_disabled_optional_mcp: true'
)) {
    if (-not $linuxRoleSource.Contains($expected) -and -not (Get-Content -LiteralPath (Join-Path $repoRoot 'group_vars\all.yml') -Raw).Contains($expected)) {
        throw "Linux defaults must expose Codex profile/agent default: $expected"
    }
}

foreach ($expected in @(
    'Create Codex CLI profile files',
    '{{ user_home }}/.codex/{{ item.name }}.config.toml',
    'Create Codex custom agents',
    '{{ user_home }}/.codex/agents/{{ item.name }}.toml',
    'explorer-terra',
    'reviewer-deep',
    'docs-researcher',
    'tester-terra',
    'architect-deep',
    'knowledge-curator',
    'Candidate: short title',
    'Remove disabled optional Codex MCP servers'
)) {
    if (-not $linuxRoleSource.Contains($expected)) {
        throw "Linux Codex role must manage profiles, custom agents, and disabled optional MCP: $expected"
    }
}

foreach ($expected in @(
    'CODEX_PROFILES_ENABLED="${CODEX_PROFILES_ENABLED:-1}"',
    'CODEX_LEAN_PROFILE_MODEL="${CODEX_LEAN_PROFILE_MODEL:-gpt-5.6-terra}"',
    'CODEX_LEAN_PROFILE_REASONING_EFFORT="${CODEX_LEAN_PROFILE_REASONING_EFFORT:-medium}"',
    'CODEX_CUSTOM_AGENTS_ENABLED="${CODEX_CUSTOM_AGENTS_ENABLED:-1}"',
    'CODEX_CUSTOM_AGENTS="${CODEX_CUSTOM_AGENTS:-explorer-terra,reviewer-deep,docs-researcher,tester-terra,architect-deep,knowledge-curator}"',
    'CODEX_PRUNE_DISABLED_OPTIONAL_MCP="${CODEX_PRUNE_DISABLED_OPTIONAL_MCP:-1}"'
)) {
    if (-not $macosBootstrapSource.Contains($expected)) {
        throw "macOS bootstrap must expose Codex profile/agent default: $expected"
    }
}

foreach ($expected in @(
    'ensure_codex_profile_files',
    'lean.config.toml',
    'deep.config.toml',
    'ensure_codex_custom_agent_files',
    'explorer-terra',
    'reviewer-deep',
    'docs-researcher',
    'tester-terra',
    'architect-deep',
    'knowledge-curator',
    'Candidate: short title',
    'CODEX_PRUNE_DISABLED_OPTIONAL_MCP'
)) {
    if (-not $macosCodexSource.Contains($expected)) {
        throw "macOS Codex module must manage profiles, custom agents, and disabled optional MCP: $expected"
    }
}

Write-Host 'codex profiles and agents tests passed'
