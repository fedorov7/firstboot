#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Firstboot provisioning for Windows 11.
.DESCRIPTION
    Installs development tools and configures the environment for systems
    programming (C++, Python, Rust) with AI agent support (Claude, Codex).
.PARAMETER Modules
    Comma-separated list of modules to run. If omitted, all modules run in order.
.PARAMETER UserEmail
    Email for git config and SSH key comment.
.PARAMETER GitUserName
    Name for git config.
.PARAMETER NodeVersion
    Node.js version for fnm (default: lts-latest).
.PARAMETER AstroNvimRepo
    Git URL for Neovim config.
.PARAMETER GithubToken
    Optional GitHub PAT for MCP github server.
.PARAMETER ForceNeovimCleanup
    Remove Neovim config/data/state/cache before cloning AstroNvim.
.PARAMETER CodexMcpPruneUnmanaged
    Remove Codex MCP servers outside the configured allowlist.
.EXAMPLE
    .\bootstrap.ps1
    .\bootstrap.ps1 -Modules shell,rust,claude
    .\bootstrap.ps1 -UserEmail "user@example.com" -GitUserName "Name"
#>
[CmdletBinding()]
param(
    [string]$Modules,
    [string]$UserEmail = "your-email@example.com",
    [string]$GitUserName = "Your Name",
    [string]$NodeVersion = "lts-latest",
    [string]$AstroNvimRepo = "https://github.com/fedorov7/astronvim-config-v4.git",
    [string]$GithubToken = "",
    [switch]$ForceNeovimCleanup,
    [string]$CodexMcpAllowlist = "context7,openaiDeveloperDocs,memory,fetch,sequential-thinking",
    [switch]$CodexMcpPruneUnmanaged,
    [switch]$CodexGithubMcpEnabled,
    [string]$CodexGithubTokenEnvVar = "GITHUB_PERSONAL_ACCESS_TOKEN",
    [switch]$CodexSerenaEnabled,
    [string]$CodexCuratedSkills = "pdf,doc",
    [string]$CodexSuperpowersSkills = "systematic-debugging,verification-before-completion,using-superpowers,test-driven-development,writing-plans,executing-plans,receiving-code-review,requesting-code-review,brainstorming,writing-skills",
    [string]$CodexKarpathySkills = "karpathy-guidelines",
    [string]$CodexClaudeSkills = "code-reviewer,cpp-pro,debugging-wizard,embedded-systems,security-reviewer,test-master,api-designer,architecture-designer,cli-developer,code-documenter,devops-engineer,legacy-modernizer,python-pro,secure-code-guardian,spec-miner,the-fool"
)

$ErrorActionPreference = 'Stop'
$ScriptRoot = $PSScriptRoot

# ── Helper Functions ──

function Write-Step {
    param([string]$Message)
    Write-Host ":: $Message" -ForegroundColor Cyan
}

function Write-Ok {
    param([string]$Message)
    Write-Host "   OK: $Message" -ForegroundColor Green
}

function Write-Skip {
    param([string]$Message)
    Write-Host "   SKIP: $Message" -ForegroundColor Yellow
}

function Write-Warn {
    param([string]$Message)
    Write-Host "   WARN: $Message" -ForegroundColor DarkYellow
}

function Test-CommandExists {
    param([string]$Name)
    $null -ne (Get-Command $Name -ErrorAction SilentlyContinue)
}

function ConvertTo-NameList {
    param([string]$Value)
    if ([string]::IsNullOrWhiteSpace($Value)) {
        return @()
    }
    return @($Value -split ',' | ForEach-Object { $_.Trim() } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
}

function Install-WingetPackage {
    param(
        [Parameter(Mandatory)][string]$Id,
        [string]$Name = $Id
    )
    $listOutput = winget list --id $Id --exact --accept-source-agreements --disable-interactivity 2>&1
    if ($listOutput -match [regex]::Escape($Id)) {
        Write-Skip "$Name already installed"
        return
    }
    Write-Step "Installing $Name..."
    winget install --id $Id --exact --accept-source-agreements --disable-interactivity --accept-package-agreements
    if ($LASTEXITCODE -ne 0) {
        throw "winget install $Id returned exit code $LASTEXITCODE"
    }
    Write-Ok "$Name installed"
}

function Install-PSModule {
    param([Parameter(Mandatory)][string]$Name)
    if (Get-Module -ListAvailable $Name -ErrorAction SilentlyContinue) {
        Write-Skip "PS module $Name already installed"
        return
    }
    Write-Step "Installing PS module $Name..."
    Install-Module -Name $Name -Force -AllowClobber -Scope CurrentUser
    Write-Ok "PS module $Name installed"
}

function Initialize-Fnm {
    if (Test-CommandExists fnm) {
        $fnmEnv = fnm env --use-on-cd --shell powershell 2>$null | Out-String
        if (-not [string]::IsNullOrWhiteSpace($fnmEnv)) {
            Invoke-Expression $fnmEnv
        }
    }
}

function Install-CargoBinary {
    param(
        [Parameter(Mandatory)][string]$Command,
        [string]$Package = $Command
    )
    if (Test-CommandExists $Command) {
        Write-Skip "$Command already available"
        return
    }
    if (-not (Test-CommandExists cargo)) {
        Write-Warn "cargo not available. Run rust module first to install $Package."
        return
    }
    Write-Step "Installing $Package via cargo..."
    cargo install $Package
    Write-Ok "$Package installed"
}

function Install-UvTool {
    param(
        [Parameter(Mandatory)][string]$Command,
        [string]$Package = $Command
    )
    if (Test-CommandExists $Command) {
        Write-Skip "$Command already available"
        return
    }
    if (-not (Test-CommandExists uv)) {
        Write-Warn "uv not available. Run python module first to install $Package."
        return
    }
    Write-Step "Installing $Package via uv tool..."
    uv tool install $Package
    Write-Ok "$Package installed"
}

function Refresh-Path {
    $env:Path = [System.Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + `
                [System.Environment]::GetEnvironmentVariable('Path', 'User')
    $cargoPath = Join-Path $env:USERPROFILE '.cargo\bin'
    if ((Test-Path $cargoPath) -and ($env:Path -notmatch [regex]::Escape($cargoPath))) {
        $env:Path = "$cargoPath;$env:Path"
    }
}

# ── Module Execution ──

$AllModules = @(
    'base'
    'shell'
    'ssh'
    'neovim'
    'nodejs'
    'python'
    'rust'
    'cpp'
    'cli_tools'
    'codex'
    'claude'
)

if ([string]::IsNullOrWhiteSpace($Modules)) {
    $SelectedModules = $AllModules
} else {
    $SelectedModules = $Modules -split ',' | ForEach-Object { $_.Trim() }
}

foreach ($mod in $SelectedModules) {
    $modulePath = Join-Path $ScriptRoot "modules\$mod.ps1"
    if (-not (Test-Path $modulePath)) {
        Write-Warn "Module not found: $modulePath"
        continue
    }
    Write-Host ""
    Write-Host "═══ Module: $mod ═══" -ForegroundColor Magenta
    . $modulePath

    # After nodejs, initialize fnm for downstream modules
    if ($mod -eq 'nodejs') {
        Initialize-Fnm
    }
}

Write-Host ""
Write-Host "═══ Bootstrap complete ═══" -ForegroundColor Green
