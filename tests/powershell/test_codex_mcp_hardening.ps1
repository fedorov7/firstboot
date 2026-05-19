$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$modulePath = Join-Path $repoRoot 'windows\modules\codex.ps1'
$source = Get-Content -LiteralPath $modulePath -Raw

if ($source -notmatch "Set-CodexMcpSetting 'openaiDeveloperDocs' 'startup_timeout_sec' '30'") {
    throw 'openaiDeveloperDocs MCP startup timeout must be hardened'
}

if ($source -notmatch "Set-CodexMcpSetting 'context7' 'startup_timeout_sec' '30'") {
    throw 'context7 MCP startup timeout must be hardened'
}

if ($source -notmatch "Set-CodexMcpSetting 'fetch' 'default_tools_approval_mode' '""prompt""'") {
    throw 'fetch MCP must require approval prompts by default'
}

Write-Host 'codex MCP hardening tests passed'
