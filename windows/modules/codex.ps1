Write-Step "Setting up Codex CLI..."

# Ensure npm is available
if (-not (Test-CommandExists npm)) {
    Initialize-Fnm
    if (-not (Test-CommandExists npm)) {
        Write-Warn "npm not available. Run nodejs module first."
        return
    }
}

# Install Codex CLI
$codexInstalled = npm ls -g @openai/codex 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Step "Installing Codex CLI..."
    npm install -g @openai/codex
    Write-Ok "Codex CLI installed"
} else {
    Write-Skip "Codex CLI already installed"
}

# ── MCP Servers ──
$codexDir = Join-Path $env:USERPROFILE '.codex'
$configToml = Join-Path $codexDir 'config.toml'
$configContent = if (Test-Path $configToml) { Get-Content $configToml -Raw } else { '' }

# context7
if ($configContent -notmatch '\[mcp_servers\.context7\]') {
    Write-Step "Adding MCP: context7..."
    codex mcp add context7 -- npx -y @upstash/context7-mcp
    Write-Ok "MCP context7 added"
} else { Write-Skip "MCP context7 already configured" }

# memory
$memoryDir = Join-Path $env:USERPROFILE '.local\share\codex'
if (-not (Test-Path $memoryDir)) { New-Item -ItemType Directory -Path $memoryDir -Force | Out-Null }
$memoryFile = Join-Path $memoryDir 'memory.jsonl'
if ($configContent -notmatch '\[mcp_servers\.memory\]') {
    Write-Step "Adding MCP: memory..."
    codex mcp add memory --env "MEMORY_FILE_PATH=$memoryFile" -- npx -y @modelcontextprotocol/server-memory
    Write-Ok "MCP memory added"
} else { Write-Skip "MCP memory already configured" }

# fetch (requires uv/uvx)
if ((Test-CommandExists uvx) -and ($configContent -notmatch '\[mcp_servers\.fetch\]')) {
    Write-Step "Adding MCP: fetch..."
    codex mcp add fetch -- uvx mcp-server-fetch
    Write-Ok "MCP fetch added"
} elseif ($configContent -match '\[mcp_servers\.fetch\]') {
    Write-Skip "MCP fetch already configured"
}

# sequential-thinking
if ($configContent -notmatch '\[mcp_servers\.sequential-thinking\]') {
    Write-Step "Adding MCP: sequential-thinking..."
    codex mcp add sequential-thinking -- npx -y @modelcontextprotocol/server-sequential-thinking
    Write-Ok "MCP sequential-thinking added"
} else { Write-Skip "MCP sequential-thinking already configured" }

# github (conditional)
if ($GithubToken -and ($configContent -notmatch '\[mcp_servers\.github\]')) {
    Write-Step "Adding MCP: github..."
    codex mcp add github --env "GITHUB_PERSONAL_ACCESS_TOKEN=$GithubToken" -- npx -y @modelcontextprotocol/server-github
    Write-Ok "MCP github added"
} elseif ($configContent -match '\[mcp_servers\.github\]') {
    Write-Skip "MCP github already configured"
}

# Remove obsolete MCPs
foreach ($obsolete in @('playwright', 'sentry')) {
    if ($configContent -match "\[mcp_servers\.$obsolete\]") {
        codex mcp remove $obsolete
        Write-Ok "Removed obsolete MCP: $obsolete"
    }
}

# ── Skills: curated (pdf, doc) ──
$skillInstaller = Join-Path $codexDir 'skills\.system\skill-installer\scripts\install-skill-from-github.py'
if (Test-Path $skillInstaller) {
    foreach ($skill in @('pdf', 'doc')) {
        $skillDir = Join-Path $codexDir "skills\$skill"
        if (-not (Test-Path $skillDir)) {
            Write-Step "Installing curated skill: $skill..."
            python $skillInstaller --repo openai/skills --path "skills/.curated/$skill"
            Write-Ok "Skill $skill installed"
        } else {
            Write-Skip "Skill $skill already installed"
        }
    }
} else {
    Write-Warn "Codex skill installer not found. Run 'codex' once to bootstrap, then re-run this module."
}

# ── Skills: superpowers (clone + symlink) ──
$superpowersDir = Join-Path $codexDir 'superpowers'
if (-not (Test-Path (Join-Path $superpowersDir '.git'))) {
    Write-Step "Cloning superpowers skills..."
    git clone https://github.com/obra/superpowers.git $superpowersDir
    Write-Ok "Superpowers cloned"
} else {
    git -C $superpowersDir pull --ff-only 2>&1 | Out-Null
    Write-Skip "Superpowers already cloned, updated"
}

$agentsSkillsDir = Join-Path $env:USERPROFILE '.agents\skills'
if (-not (Test-Path $agentsSkillsDir)) { New-Item -ItemType Directory -Path $agentsSkillsDir -Force | Out-Null }

$spLink = Join-Path $agentsSkillsDir 'superpowers'
$spTarget = Join-Path $superpowersDir 'skills'
if (-not (Test-Path $spLink)) {
    New-Item -ItemType SymbolicLink -Path $spLink -Target $spTarget -Force | Out-Null
    Write-Ok "Superpowers skills symlinked"
} else { Write-Skip "Superpowers symlink exists" }

# ── Skills: claude-skills (clone + symlink) ──
$claudeSkillsDir = Join-Path $codexDir 'claude-skills'
if (-not (Test-Path (Join-Path $claudeSkillsDir '.git'))) {
    Write-Step "Cloning claude-skills..."
    git clone https://github.com/Jeffallan/claude-skills.git $claudeSkillsDir
    Write-Ok "Claude-skills cloned"
} else {
    git -C $claudeSkillsDir pull --ff-only 2>&1 | Out-Null
    Write-Skip "Claude-skills already cloned, updated"
}

$csLink = Join-Path $agentsSkillsDir 'claude-skills'
$csTarget = Join-Path $claudeSkillsDir 'skills'
if (-not (Test-Path $csLink)) {
    New-Item -ItemType SymbolicLink -Path $csLink -Target $csTarget -Force | Out-Null
    Write-Ok "Claude-skills symlinked"
} else { Write-Skip "Claude-skills symlink exists" }
