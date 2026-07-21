$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$modulePath = Join-Path $repoRoot 'windows\modules\codex.ps1'
$source = Get-Content -LiteralPath $modulePath -Raw

if ($source -notmatch "Set-CodexMcpSetting 'openaiDeveloperDocs' 'startup_timeout_sec' '30'") {
    throw 'openaiDeveloperDocs MCP startup timeout must be hardened'
}

if ($source -notmatch "Set-CodexMcpSetting 'microsoft-learn' 'startup_timeout_sec' '30'") {
    throw 'Microsoft Learn MCP startup timeout must be hardened'
}

if ($source -notmatch "Set-CodexMcpSetting 'context7' 'startup_timeout_sec' '30'") {
    throw 'context7 MCP startup timeout must be hardened'
}

if ($source -notmatch "Set-CodexMcpSetting 'fetch' 'default_tools_approval_mode'.*CodexFetchMcpApprovalMode") {
    throw 'fetch MCP approval mode must be configurable and default to prompt'
}

if ($source -notmatch "Set-CodexMcpSetting 'microsoft-learn' 'default_tools_approval_mode'.*CodexMicrosoftLearnMcpApprovalMode") {
    throw 'Microsoft Learn MCP approval mode must be configurable and default to writes'
}

if ($source -notmatch "Set-CodexMcpSetting 'github' 'default_tools_approval_mode'.*CodexGithubMcpApprovalMode") {
    throw 'GitHub MCP approval mode must be configurable and default to writes'
}

if ($source -notmatch "Set-CodexMcpSetting 'serena' 'default_tools_approval_mode'.*CodexSerenaMcpApprovalMode") {
    throw 'Serena MCP approval mode must be configurable and default to writes'
}

if ($source -notmatch "Set-CodexMcpSetting 'playwright' 'default_tools_approval_mode'.*CodexPlaywrightMcpApprovalMode") {
    throw 'Playwright MCP approval mode must be configurable and default to prompt'
}

if (-not $source.Contains('$line -match ''^\s*\[''')) {
    throw 'MCP setting updater must stop at nested TOML tables'
}

Write-Host 'codex MCP hardening tests passed'
