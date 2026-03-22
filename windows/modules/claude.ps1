Write-Step "Setting up Claude CLI..."

# Ensure npm is available
if (-not (Test-CommandExists npm)) {
    Initialize-Fnm
    if (-not (Test-CommandExists npm)) {
        Write-Warn "npm not available. Run nodejs module first."
        return
    }
}

# Install Claude CLI
if (-not (Test-CommandExists claude)) {
    Write-Step "Installing Claude CLI..."
    npm install -g @anthropic-ai/claude-code
    Write-Ok "Claude CLI installed"
} else {
    Write-Skip "Claude CLI already installed"
}

# ── Settings ──
$claudeDir = Join-Path $env:USERPROFILE '.claude'
if (-not (Test-Path $claudeDir)) { New-Item -ItemType Directory -Path $claudeDir -Force | Out-Null }

$settingsSource = Join-Path $ScriptRoot '..\roles\claude\files\settings.json'
$settingsDest = Join-Path $claudeDir 'settings.json'
if (Test-Path $settingsSource) {
    if (Test-Path $settingsDest) {
        $backupPath = "$settingsDest.backup.$(Get-Date -Format 'yyyyMMdd-HHmmss')"
        Copy-Item $settingsDest $backupPath
        Write-Ok "Existing settings backed up to $backupPath"
    }
    Copy-Item -Path $settingsSource -Destination $settingsDest -Force
    Write-Ok "Claude settings.json deployed"
} else {
    Write-Warn "settings.json source not found at $settingsSource"
}

# ── MCP Servers ──
$claudeJson = Join-Path $env:USERPROFILE '.claude.json'
$claudeConfig = if (Test-Path $claudeJson) {
    (Get-Content $claudeJson -Raw | ConvertFrom-Json)
} else { $null }
$mcpServers = if ($claudeConfig -and $claudeConfig.mcpServers) {
    $claudeConfig.mcpServers.PSObject.Properties.Name
} else { @() }

# context7
if ('context7' -notin $mcpServers) {
    claude mcp add --scope user context7 -- npx -y @upstash/context7-mcp
    Write-Ok "MCP context7 added"
} else { Write-Skip "MCP context7 already configured" }

# memory
$memoryDir = Join-Path $env:USERPROFILE '.local\share\claude'
if (-not (Test-Path $memoryDir)) { New-Item -ItemType Directory -Path $memoryDir -Force | Out-Null }
$memoryFile = Join-Path $memoryDir 'memory.jsonl'
if ('memory' -notin $mcpServers) {
    claude mcp add --scope user memory -e "MEMORY_FILE_PATH=$memoryFile" -- npx -y @modelcontextprotocol/server-memory
    Write-Ok "MCP memory added"
} else { Write-Skip "MCP memory already configured" }

# fetch
if ((Test-CommandExists uvx) -and ('fetch' -notin $mcpServers)) {
    claude mcp add --scope user fetch -- uvx mcp-server-fetch
    Write-Ok "MCP fetch added"
} elseif ('fetch' -in $mcpServers) { Write-Skip "MCP fetch already configured" }

# sequential-thinking
if ('sequential-thinking' -notin $mcpServers) {
    claude mcp add --scope user sequential-thinking -- npx -y @modelcontextprotocol/server-sequential-thinking
    Write-Ok "MCP sequential-thinking added"
} else { Write-Skip "MCP sequential-thinking already configured" }

# github (conditional)
if ($GithubToken -and ('github' -notin $mcpServers)) {
    claude mcp add --scope user github -e "GITHUB_PERSONAL_ACCESS_TOKEN=$GithubToken" -- npx -y @modelcontextprotocol/server-github
    Write-Ok "MCP github added"
} elseif ('github' -in $mcpServers) { Write-Skip "MCP github already configured" }

# Remove obsolete MCPs
foreach ($obsolete in @('sentry', 'playwright')) {
    if ($obsolete -in $mcpServers) {
        claude mcp remove --scope user $obsolete
        Write-Ok "Removed obsolete MCP: $obsolete"
    }
}

# ── Plugin Marketplaces ──
$marketplaces = @(
    @{ Name = 'claude-plugins-official'; Source = 'anthropics/claude-plugins-official' }
    @{ Name = 'superpowers-dev';         Source = 'https://github.com/obra/superpowers' }
    @{ Name = 'fullstack-dev-skills';    Source = 'https://github.com/Jeffallan/claude-skills' }
)

foreach ($mp in $marketplaces) {
    $mpDir = Join-Path $claudeDir "plugins\marketplaces\$($mp.Name)"
    if (-not (Test-Path $mpDir)) {
        Write-Step "Adding marketplace: $($mp.Name)..."
        claude plugin marketplace add $mp.Source
        Write-Ok "Marketplace $($mp.Name) added"
    } else {
        Write-Skip "Marketplace $($mp.Name) already installed"
    }
}

# ── Enable Plugins ──
$plugins = @(
    'superpowers@claude-plugins-official'
    'context-engineering-fundamentals@context-engineering-marketplace'
    'agent-architecture@context-engineering-marketplace'
    'agent-evaluation@context-engineering-marketplace'
    'agent-development@context-engineering-marketplace'
    'cognitive-architecture@context-engineering-marketplace'
    'fullstack-dev-skills@fullstack-dev-skills'
    'clangd-lsp@claude-plugins-official'
    'pyright-lsp@claude-plugins-official'
)

foreach ($plugin in $plugins) {
    $result = claude plugin enable $plugin 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Ok "Plugin $plugin enabled"
    } elseif ($result -match 'already enabled') {
        Write-Skip "Plugin $plugin already enabled"
    } else {
        Write-Warn "Failed to enable plugin $plugin : $result"
    }
}
