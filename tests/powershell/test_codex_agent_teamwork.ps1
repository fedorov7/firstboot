$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$skillPath = Join-Path $repoRoot 'codex\skills\codex-agent-teamwork\SKILL.md'
$windowsBootstrapSource = Get-Content -LiteralPath (Join-Path $repoRoot 'windows\bootstrap.ps1') -Raw
$windowsCodexSource = Get-Content -LiteralPath (Join-Path $repoRoot 'windows\modules\codex.ps1') -Raw
$linuxDefaultsSource = Get-Content -LiteralPath (Join-Path $repoRoot 'group_vars\all.yml') -Raw
$linuxRoleSource = Get-Content -LiteralPath (Join-Path $repoRoot 'roles\codex\tasks\main.yml') -Raw
$macosBootstrapSource = Get-Content -LiteralPath (Join-Path $repoRoot 'macos\bootstrap.sh') -Raw
$macosCodexSource = Get-Content -LiteralPath (Join-Path $repoRoot 'macos\modules\codex.sh') -Raw
$readmeSource = Get-Content -LiteralPath (Join-Path $repoRoot 'README.md') -Raw

if (-not (Test-Path $skillPath)) {
    throw 'Repository must include the managed codex-agent-teamwork skill'
}

$skillSource = Get-Content -LiteralPath $skillPath -Raw
foreach ($expected in @(
    'name: codex-agent-teamwork',
    'explorer-terra',
    'docs-researcher',
    'tester-terra',
    'reviewer-deep',
    'architect-deep',
    'knowledge-curator',
    'Knowledge Capture',
    'Recommended Target: skill, AGENTS.md, README, or no action',
    'Do not delegate simple tasks',
    'Use no more than three subagents by default'
)) {
    if (-not $skillSource.Contains($expected)) {
        throw "codex-agent-teamwork skill must document: $expected"
    }
}

foreach ($expected in @(
    '[bool]$CodexAgentTeamworkSkillEnabled = $true',
    '[bool]$CodexGlobalAgentsGuidanceEnabled = $true',
    '[string]$CodexCustomAgents = "explorer-terra,reviewer-deep,docs-researcher,tester-terra,architect-deep,knowledge-curator"'
)) {
    if (-not $windowsBootstrapSource.Contains($expected)) {
        throw "Windows bootstrap must expose agent teamwork default: $expected"
    }
}

foreach ($expected in @(
    'Set-CodexAgentTeamworkSkill',
    'Set-CodexGlobalAgentsGuidance',
    'Test-CodexDirectoryCurrent',
    'tester-terra',
    'architect-deep',
    'knowledge-curator',
    'sandbox_mode = "$SandboxMode"',
    '-SandboxMode ''read-only''',
    'Candidate: short title',
    'workspace-write',
    'Use $codex-agent-teamwork for non-trivial development'
)) {
    if (-not $windowsCodexSource.Contains($expected)) {
        throw "Windows Codex module must manage agent teamwork: $expected"
    }
}

foreach ($expected in @(
    'codex_agent_teamwork_skill_enabled: true',
    'codex_global_agents_guidance_enabled: true',
    '- tester-terra',
    '- architect-deep',
    '- knowledge-curator'
)) {
    if (-not $linuxDefaultsSource.Contains($expected)) {
        throw "Linux defaults must expose agent teamwork default: $expected"
    }
}

foreach ($expected in @(
    'Install managed Codex agent teamwork skill',
    'Set Codex global AGENTS.md teamwork guidance',
    'tester-terra',
    'architect-deep',
    'knowledge-curator',
    'Candidate: short title',
    'sandbox_mode = "{{ item.sandbox_mode }}"',
    'Use $codex-agent-teamwork for non-trivial development'
)) {
    if (-not $linuxRoleSource.Contains($expected)) {
        throw "Linux Codex role must manage agent teamwork: $expected"
    }
}

foreach ($expected in @(
    'CODEX_AGENT_TEAMWORK_SKILL_ENABLED="${CODEX_AGENT_TEAMWORK_SKILL_ENABLED:-1}"',
    'CODEX_GLOBAL_AGENTS_GUIDANCE_ENABLED="${CODEX_GLOBAL_AGENTS_GUIDANCE_ENABLED:-1}"',
    'CODEX_CUSTOM_AGENTS="${CODEX_CUSTOM_AGENTS:-explorer-terra,reviewer-deep,docs-researcher,tester-terra,architect-deep,knowledge-curator}"'
)) {
    if (-not $macosBootstrapSource.Contains($expected)) {
        throw "macOS bootstrap must expose agent teamwork default: $expected"
    }
}

foreach ($expected in @(
    'ensure_codex_agent_teamwork_skill',
    'ensure_codex_global_agents_guidance',
    'diff -qr "$source_skill" "$target_skill"',
    'tester-terra',
    'architect-deep',
    'knowledge-curator',
    'Candidate: short title',
    'sandbox_mode = "$sandbox_mode"',
    'Use $codex-agent-teamwork for non-trivial development'
)) {
    if (-not $macosCodexSource.Contains($expected)) {
        throw "macOS Codex module must manage agent teamwork: $expected"
    }
}

foreach ($expected in @(
    'codex-agent-teamwork',
    'tester-terra',
    'architect-deep',
    'knowledge-curator',
    'knowledge capture',
    'global AGENTS.md'
)) {
    if (-not $readmeSource.Contains($expected)) {
        throw "README must document agent teamwork: $expected"
    }
}

Write-Host 'codex agent teamwork tests passed'
