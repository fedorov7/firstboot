Write-Step "Setting up Codex CLI..."

function Get-CodexConfigContent {
    if (Test-Path $script:ConfigToml) {
        return Get-Content $script:ConfigToml -Raw
    }
    return ''
}

function Test-CodexMcpConfigured {
    param([Parameter(Mandatory)][string]$Name)
    (Get-CodexConfigContent) -match "\[mcp_servers\.$([regex]::Escape($Name))\]"
}

function Add-CodexMcpIfMissing {
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][scriptblock]$ScriptBlock
    )
    if (Test-CodexMcpConfigured $Name) {
        Write-Skip "MCP $Name already configured"
        return
    }
    Write-Step "Adding MCP: $Name..."
    & $ScriptBlock
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to add Codex MCP server: $Name"
    }
    Write-Ok "MCP $Name added"
}

function Remove-CodexMcp {
    param([Parameter(Mandatory)][string]$Name)
    codex mcp remove $Name
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to remove Codex MCP server: $Name"
    }
}

function Sync-CodexSkillNamespace {
    param(
        [Parameter(Mandatory)][string]$Namespace,
        [Parameter(Mandatory)][string]$Repo,
        [Parameter(Mandatory)][string]$SourceDirName,
        [Parameter(Mandatory)][string[]]$Skills
    )

    $namespaceDir = Join-Path $script:AgentsSkillsDir $Namespace
    if (Test-Path $namespaceDir) {
        $namespaceItem = Get-Item -LiteralPath $namespaceDir -Force
        if (-not $namespaceItem.PSIsContainer) {
            Remove-Item -LiteralPath $namespaceDir -Recurse -Force
            Write-Ok "Removed incompatible $Namespace skill namespace"
        }
    }
    if (-not (Test-Path $namespaceDir)) {
        New-Item -ItemType Directory -Path $namespaceDir -Force | Out-Null
    }

    Get-ChildItem $namespaceDir -Force | ForEach-Object {
        if ($_.Name -notin $Skills) {
            Remove-Item -LiteralPath $_.FullName -Recurse -Force
            Write-Ok "Removed stale $Namespace skill: $($_.Name)"
        }
    }

    if ($Skills.Count -eq 0) {
        Write-Skip "$Namespace skill allowlist is empty"
        return
    }

    $sourceDir = Join-Path $script:SkillSourceRoot $SourceDirName
    if (-not (Test-Path (Join-Path $sourceDir '.git'))) {
        Write-Step "Cloning $Namespace skills..."
        git clone $Repo $sourceDir
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to clone $Namespace skills from $Repo"
        }
        Write-Ok "$Namespace skills cloned"
    } else {
        git -C $sourceDir pull --ff-only 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to update $Namespace skills in $sourceDir"
        }
        Write-Skip "$Namespace skills already cloned, updated"
    }

    foreach ($skill in $Skills) {
        $sourceSkill = Join-Path $sourceDir "skills\$skill"
        if (-not (Test-Path $sourceSkill)) {
            throw "Selected $Namespace skill '$skill' was not found in $sourceDir."
        }

        $destSkill = Join-Path $namespaceDir $skill
        $shouldCreateLink = $true
        if (Test-Path $destSkill) {
            $destItem = Get-Item -LiteralPath $destSkill -Force
            $destTargets = @($destItem.Target)
            if ($destItem.LinkType -eq 'SymbolicLink' -and $sourceSkill -in $destTargets) {
                Write-Skip "$Namespace skill already present: $skill"
                $shouldCreateLink = $false
            } else {
                Remove-Item -LiteralPath $destSkill -Recurse -Force
                Write-Ok "Removed stale $Namespace skill entry: $skill"
            }
        }

        if ($shouldCreateLink) {
            New-Item -ItemType SymbolicLink -Path $destSkill -Target $sourceSkill -Force | Out-Null
            Write-Ok "$Namespace skill symlinked: $skill"
        }
    }
}

# Ensure npm is available from the configured fnm-managed Node.js.
Initialize-Fnm
if (Test-CommandExists fnm) {
    fnm use $NodeVersion 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Warn "Node.js $NodeVersion is not available via fnm. Run nodejs module first."
        return
    }
    Initialize-Fnm
}

if (-not (Test-CommandExists npm)) {
    Write-Warn "npm not available. Run nodejs module first."
    return
}

# Install Codex CLI into the selected Node.js prefix.
$codexInstalled = npm ls -g @openai/codex 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Step "Installing Codex CLI..."
    npm install -g @openai/codex
    Write-Ok "Codex CLI installed"
} else {
    Write-Skip "Codex CLI already installed"
}

if (-not (Test-CommandExists codex)) {
    Write-Warn "codex not found in PATH after npm install. Restart shell and re-run this module."
    return
}

# MCP servers
$codexDir = Join-Path $env:USERPROFILE '.codex'
$script:ConfigToml = Join-Path $codexDir 'config.toml'
if (-not (Test-Path $codexDir)) {
    New-Item -ItemType Directory -Path $codexDir -Force | Out-Null
}

$desiredMcpServers = ConvertTo-NameList $CodexMcpAllowlist
if ($CodexGithubMcpEnabled -or -not [string]::IsNullOrWhiteSpace($GithubToken)) {
    $desiredMcpServers += 'github'
}
if ($CodexSerenaEnabled) {
    $desiredMcpServers += 'serena'
}
$desiredMcpServers = @($desiredMcpServers | Select-Object -Unique)

if (-not [string]::IsNullOrWhiteSpace($GithubToken)) {
    [System.Environment]::SetEnvironmentVariable($CodexGithubTokenEnvVar, $GithubToken, 'User')
    Set-Item -Path "Env:\$CodexGithubTokenEnvVar" -Value $GithubToken
}

$configContent = Get-CodexConfigContent
$existingMcpServers = @([regex]::Matches($configContent, '(?m)^\[mcp_servers\.([^.\]]+)\]\s*$') | ForEach-Object { $_.Groups[1].Value } | Select-Object -Unique)

if ($CodexMcpPruneUnmanaged) {
    foreach ($server in $existingMcpServers) {
        if ($server -notin $desiredMcpServers) {
            Remove-CodexMcp $server
            Write-Ok "Removed unmanaged MCP: $server"
        }
    }
}

$configContent = Get-CodexConfigContent
if ('github' -in $desiredMcpServers -and $configContent -match '@modelcontextprotocol/server-github') {
    Remove-CodexMcp 'github'
    Write-Ok "Removed archived GitHub MCP"
}

$context7Block = [regex]::Match($configContent, '(?ms)^\[mcp_servers\.context7\].*?(?=^\[mcp_servers\.|\z)').Value
if ('context7' -in $desiredMcpServers -and $context7Block -match '@upstash/context7-mcp' -and $context7Block -match '--api-key') {
    Remove-CodexMcp 'context7'
    Write-Ok "Removed context7 MCP with inline API key"
}

if ('context7' -in $desiredMcpServers) {
    Add-CodexMcpIfMissing 'context7' { codex mcp add context7 -- npx -y @upstash/context7-mcp }
}

if ('openaiDeveloperDocs' -in $desiredMcpServers) {
    Add-CodexMcpIfMissing 'openaiDeveloperDocs' { codex mcp add openaiDeveloperDocs --url https://developers.openai.com/mcp }
}

if ('memory' -in $desiredMcpServers) {
    $memoryDir = Join-Path $env:USERPROFILE '.local\share\codex'
    if (-not (Test-Path $memoryDir)) { New-Item -ItemType Directory -Path $memoryDir -Force | Out-Null }
    $memoryFile = Join-Path $memoryDir 'memory.jsonl'
    Add-CodexMcpIfMissing 'memory' {
        codex mcp add memory --env "MEMORY_FILE_PATH=$memoryFile" -- npx -y @modelcontextprotocol/server-memory
    }
}

if ('fetch' -in $desiredMcpServers) {
    if (Test-CommandExists uvx) {
        Add-CodexMcpIfMissing 'fetch' { codex mcp add fetch -- uvx mcp-server-fetch }
    } else {
        Write-Warn "uvx not available. Run python module first to enable fetch MCP."
    }
}

if ('sequential-thinking' -in $desiredMcpServers) {
    Add-CodexMcpIfMissing 'sequential-thinking' {
        codex mcp add sequential-thinking -- npx -y @modelcontextprotocol/server-sequential-thinking
    }
}

if ('github' -in $desiredMcpServers) {
    Add-CodexMcpIfMissing 'github' {
        codex mcp add github --url https://api.githubcopilot.com/mcp/ --bearer-token-env-var $CodexGithubTokenEnvVar
    }
}

if ('serena' -in $desiredMcpServers) {
    if (Test-CommandExists uvx) {
        Add-CodexMcpIfMissing 'serena' {
            codex mcp add serena -- uvx --from git+https://github.com/oraios/serena serena start-mcp-server --project-from-cwd --context=codex
        }
    } else {
        Write-Warn "uvx not available. Run python module first to enable Serena MCP."
    }
}

# Skills
$script:SkillSourceRoot = Join-Path $env:USERPROFILE '.local\share\codex\skill-sources'
$script:AgentsSkillsDir = Join-Path $env:USERPROFILE '.agents\skills'
New-Item -ItemType Directory -Path $script:SkillSourceRoot -Force | Out-Null
New-Item -ItemType Directory -Path $script:AgentsSkillsDir -Force | Out-Null

$curatedSkills = ConvertTo-NameList $CodexCuratedSkills
$legacyCuratedSkills = @(
    'api-designer', 'architecture-designer', 'cli-developer', 'code-documenter',
    'code-reviewer', 'cpp-pro', 'debugging-wizard', 'doc', 'embedded-systems',
    'fullstack-guardian', 'legacy-modernizer', 'pandas-pro', 'pdf', 'python-pro',
    'rust-engineer', 'secure-code-guardian', 'security-reviewer', 'spec-miner',
    'test-master', 'the-fool'
)
foreach ($skill in $legacyCuratedSkills) {
    $skillDir = Join-Path $codexDir "skills\$skill"
    if ($skill -notin $curatedSkills -and (Test-Path $skillDir)) {
        Remove-Item -LiteralPath $skillDir -Recurse -Force
        Write-Ok "Removed obsolete curated skill: $skill"
    }
}

$skillInstaller = Join-Path $codexDir 'skills\.system\skill-installer\scripts\install-skill-from-github.py'
if (Test-Path $skillInstaller) {
    foreach ($skill in $curatedSkills) {
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

Sync-CodexSkillNamespace `
    -Namespace 'superpowers' `
    -Repo 'https://github.com/obra/superpowers.git' `
    -SourceDirName 'superpowers' `
    -Skills (ConvertTo-NameList $CodexSuperpowersSkills)

Sync-CodexSkillNamespace `
    -Namespace 'claude-skills' `
    -Repo 'https://github.com/Jeffallan/claude-skills.git' `
    -SourceDirName 'claude-skills' `
    -Skills (ConvertTo-NameList $CodexClaudeSkills)

Sync-CodexSkillNamespace `
    -Namespace 'karpathy-skills' `
    -Repo 'https://github.com/forrestchang/andrej-karpathy-skills.git' `
    -SourceDirName 'karpathy-skills' `
    -Skills (ConvertTo-NameList $CodexKarpathySkills)
