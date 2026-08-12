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
    'improvement-researcher',
    'Knowledge Capture',
    'Improvement Research',
    'Recommended Target: skill, AGENTS.md, README, or no action',
    'Suggested Next Step: adopt, test, document, defer, or reject',
    'Do not delegate simple tasks',
    'Start with at most one subagent.'
)) {
    if (-not $skillSource.Contains($expected)) {
        throw "codex-agent-teamwork skill must document: $expected"
    }
}

foreach ($expected in @(
    '[bool]$CodexAgentTeamworkSkillEnabled = $true',
    '[bool]$CodexGlobalAgentsGuidanceEnabled = $true',
    '[string]$CodexCustomAgents = "explorer-terra,reviewer-deep,docs-researcher,tester-terra,architect-deep,knowledge-curator,improvement-researcher"'
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
    'improvement-researcher',
    'sandbox_mode = "$SandboxMode"',
    '-SandboxMode ''read-only''',
    'Candidate: short title',
    'Finding: short title',
    'Suggested Next Step: adopt, test, document, defer, or reject',
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
    '- knowledge-curator',
    '- improvement-researcher'
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
    'improvement-researcher',
    'Candidate: short title',
    'Finding: short title',
    'Suggested Next Step: adopt, test, document, defer, or reject',
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
    'CODEX_CUSTOM_AGENTS="${CODEX_CUSTOM_AGENTS:-explorer-terra,reviewer-deep,docs-researcher,tester-terra,architect-deep,knowledge-curator,improvement-researcher}"'
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
    'improvement-researcher',
    'Candidate: short title',
    'Finding: short title',
    'Suggested Next Step: adopt, test, document, defer, or reject',
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
    'improvement-researcher',
    'knowledge capture',
    'improvement research',
    'global AGENTS.md'
)) {
    if (-not $readmeSource.Contains($expected)) {
        throw "README must document agent teamwork: $expected"
    }
}

Write-Host 'codex agent teamwork tests passed'
