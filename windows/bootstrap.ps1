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
    [string]$GithubToken = ""
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
        Write-Warn "winget install $Id returned exit code $LASTEXITCODE"
    } else {
        Write-Ok "$Name installed"
    }
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
        fnm env --use-on-cd --shell powershell | Out-String | Invoke-Expression
    }
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
