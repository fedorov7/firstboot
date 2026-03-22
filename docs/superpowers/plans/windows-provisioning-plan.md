# Windows 11 PowerShell Provisioning — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create a set of PowerShell scripts in `windows/` that provision a Windows 11 machine for systems programming, mirroring the existing Ansible roles for Arch Linux.

**Architecture:** A single `bootstrap.ps1` entry point defines helper functions and config variables, then dot-sources individual module scripts from `windows/modules/`. Each module is idempotent and can be run independently. Dotfiles live in `windows/files/`.

**Tech Stack:** PowerShell 7+, winget, fnm, oh-my-posh, PSReadLine

**Spec:** `docs/superpowers/specs/windows-provisioning-design.md`

---

### Task 1: Create bootstrap.ps1 with helper functions

**Files:**
- Create: `windows/bootstrap.ps1`

This is the foundation — all modules depend on the helpers defined here.

- [ ] **Step 1: Create directory structure**

```bash
mkdir -p windows/modules windows/files
```

- [ ] **Step 2: Write bootstrap.ps1**

```powershell
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
```

- [ ] **Step 3: Verify syntax**

Open PowerShell and run:
```powershell
pwsh -NoProfile -Command "& { $null = [System.Management.Automation.Language.Parser]::ParseFile('windows\bootstrap.ps1', [ref]$null, [ref]$null) }"
```

- [ ] **Step 4: Commit**

```bash
git add windows/bootstrap.ps1
git commit -m "feat(windows): add bootstrap.ps1 with helper functions and module orchestration"
```

---

### Task 2: Create PowerShell profile and oh-my-posh theme

**Files:**
- Create: `windows/files/profile.ps1`
- Create: `windows/files/oh-my-posh.json`

- [ ] **Step 1: Write profile.ps1**

Use the guarded profile from the spec — every tool init wrapped in `Get-Command`/`Get-Module` checks. See spec section "PowerShell Profile (files/profile.ps1)" for the complete content.

- [ ] **Step 2: Write oh-my-posh.json**

Lean theme similar to p10k: left = path + git, right = status + execution time + language versions.

```json
{
  "$schema": "https://raw.githubusercontent.com/JanDeDobbeleer/oh-my-posh/main/themes/schema.json",
  "version": 2,
  "final_space": true,
  "console_title_template": "{{ .Folder }}",
  "blocks": [
    {
      "type": "prompt",
      "alignment": "left",
      "segments": [
        {
          "type": "path",
          "style": "plain",
          "foreground": "blue",
          "template": "{{ .Path }}",
          "properties": {
            "style": "full"
          }
        },
        {
          "type": "git",
          "style": "plain",
          "foreground": "green",
          "template": " {{ .HEAD }}{{ if .Working.Changed }} *{{ end }}{{ if .Staging.Changed }} +{{ end }}"
        }
      ]
    },
    {
      "type": "rprompt",
      "segments": [
        {
          "type": "status",
          "style": "plain",
          "foreground": "red",
          "template": "{{ if gt .Code 0 }}{{ .Code }}{{ end }}"
        },
        {
          "type": "executiontime",
          "style": "plain",
          "foreground": "yellow",
          "template": " {{ .FormattedMs }}",
          "properties": {
            "threshold": 2000
          }
        },
        {
          "type": "node",
          "style": "plain",
          "foreground": "green",
          "template": " {{ .Full }}"
        },
        {
          "type": "python",
          "style": "plain",
          "foreground": "yellow",
          "template": " {{ .Full }}"
        },
        {
          "type": "rust",
          "style": "plain",
          "foreground": "red",
          "template": " {{ .Full }}"
        }
      ]
    },
    {
      "type": "prompt",
      "alignment": "left",
      "newline": true,
      "segments": [
        {
          "type": "text",
          "style": "plain",
          "foreground": "magenta",
          "template": "❯"
        }
      ]
    }
  ]
}
```

- [ ] **Step 3: Commit**

```bash
git add windows/files/
git commit -m "feat(windows): add PowerShell profile and oh-my-posh lean theme"
```

---

### Task 3: Create base.ps1 module

**Files:**
- Create: `windows/modules/base.ps1`

- [ ] **Step 1: Write base.ps1**

Loop over all base winget package IDs from the spec (ripgrep, fd, bat, fzf, jq, yq, eza, duf, 7zip, Everything, PowerToys, Git, GitHub CLI) calling `Install-WingetPackage` for each.

```powershell
Write-Step "Installing base packages..."

$basePackages = @(
    @{ Id = 'BurntSushi.ripgrep.MSVC'; Name = 'ripgrep' }
    @{ Id = 'sharkdp.fd';              Name = 'fd' }
    @{ Id = 'sharkdp.bat';             Name = 'bat' }
    @{ Id = 'junegunn.fzf';            Name = 'fzf' }
    @{ Id = 'jqlang.jq';               Name = 'jq' }
    @{ Id = 'MikeFarah.yq';            Name = 'yq' }
    @{ Id = 'eza-community.eza';        Name = 'eza' }
    @{ Id = 'muesli.duf';              Name = 'duf' }
    @{ Id = '7zip.7zip';               Name = '7-Zip' }
    @{ Id = 'voidtools.Everything';     Name = 'Everything' }
    @{ Id = 'Microsoft.PowerToys';      Name = 'PowerToys' }
    @{ Id = 'Git.Git';                 Name = 'Git for Windows' }
    @{ Id = 'GitHub.cli';              Name = 'GitHub CLI' }
)

foreach ($pkg in $basePackages) {
    Install-WingetPackage -Id $pkg.Id -Name $pkg.Name
}
```

- [ ] **Step 2: Commit**

```bash
git add windows/modules/base.ps1
git commit -m "feat(windows): add base.ps1 — core winget packages"
```

---

### Task 4: Create shell.ps1 module

**Files:**
- Create: `windows/modules/shell.ps1`

- [ ] **Step 1: Write shell.ps1**

1. `Install-WingetPackage` for oh-my-posh and zoxide
2. `Install-PSModule` for PSReadLine, posh-git, Terminal-Icons, PSFzf
3. Deploy oh-my-posh.json to `$env:USERPROFILE\.config\oh-my-posh.json` (create dir if needed)
4. Deploy profile.ps1 to `$PROFILE.CurrentUserCurrentHost` (backup existing first)

```powershell
Write-Step "Configuring PowerShell shell environment..."

# Winget tools
Install-WingetPackage -Id 'JanDeDobbeleer.OhMyPosh' -Name 'oh-my-posh'
Install-WingetPackage -Id 'ajeetdsouza.zoxide' -Name 'zoxide'

# PowerShell modules
Install-PSModule 'posh-git'
Install-PSModule 'Terminal-Icons'
Install-PSModule 'PSFzf'

# Update PSReadLine to latest (ships with PS but may be outdated)
$currentPSRL = (Get-Module PSReadLine -ListAvailable | Sort-Object Version -Descending | Select-Object -First 1).Version
if ($currentPSRL -lt [version]'2.3.0') {
    Write-Step "Updating PSReadLine..."
    Install-Module PSReadLine -Force -AllowClobber -Scope CurrentUser -AllowPrerelease
    Write-Ok "PSReadLine updated"
} else {
    Write-Skip "PSReadLine $currentPSRL is recent enough"
}

# Deploy oh-my-posh theme
$ompConfigDir = Join-Path $env:USERPROFILE '.config'
if (-not (Test-Path $ompConfigDir)) { New-Item -ItemType Directory -Path $ompConfigDir -Force | Out-Null }
$ompSource = Join-Path $ScriptRoot 'files\oh-my-posh.json'
$ompDest = Join-Path $ompConfigDir 'oh-my-posh.json'
Copy-Item -Path $ompSource -Destination $ompDest -Force
Write-Ok "oh-my-posh theme deployed to $ompDest"

# Deploy PowerShell profile
$profileDir = Split-Path $PROFILE.CurrentUserCurrentHost
if (-not (Test-Path $profileDir)) { New-Item -ItemType Directory -Path $profileDir -Force | Out-Null }
if (Test-Path $PROFILE.CurrentUserCurrentHost) {
    $backupPath = "$($PROFILE.CurrentUserCurrentHost).backup.$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    Copy-Item $PROFILE.CurrentUserCurrentHost $backupPath
    Write-Ok "Existing profile backed up to $backupPath"
}
$profileSource = Join-Path $ScriptRoot 'files\profile.ps1'
Copy-Item -Path $profileSource -Destination $PROFILE.CurrentUserCurrentHost -Force
Write-Ok "PowerShell profile deployed to $($PROFILE.CurrentUserCurrentHost)"
```

- [ ] **Step 2: Commit**

```bash
git add windows/modules/shell.ps1
git commit -m "feat(windows): add shell.ps1 — oh-my-posh, PSReadLine, modules, profile"
```

---

### Task 5: Create ssh.ps1 module

**Files:**
- Create: `windows/modules/ssh.ps1`

- [ ] **Step 1: Write ssh.ps1**

1. Enable and start `ssh-agent` Windows service (requires admin)
2. Generate ed25519 key if not present via `ssh-keygen`
3. Display public key
4. Configure git globally — full list from spec including difftastic config

```powershell
Write-Step "Configuring SSH and Git..."

# Enable ssh-agent service
$sshAgent = Get-Service ssh-agent -ErrorAction SilentlyContinue
if ($sshAgent) {
    if ($sshAgent.StartType -ne 'Automatic') {
        Set-Service ssh-agent -StartupType Automatic
        Write-Ok "ssh-agent set to Automatic start"
    }
    if ($sshAgent.Status -ne 'Running') {
        Start-Service ssh-agent
        Write-Ok "ssh-agent started"
    } else {
        Write-Skip "ssh-agent already running"
    }
} else {
    Write-Warn "ssh-agent service not found — ensure OpenSSH Client is installed"
}

# Generate SSH key
$sshDir = Join-Path $env:USERPROFILE '.ssh'
if (-not (Test-Path $sshDir)) {
    New-Item -ItemType Directory -Path $sshDir -Force | Out-Null
}
$sshKey = Join-Path $sshDir 'id_ed25519'
if (-not (Test-Path $sshKey)) {
    ssh-keygen -t ed25519 -C $UserEmail -f $sshKey -N ([string]::Empty)
    Write-Ok "SSH key generated"
    Write-Host ""
    Write-Host "Add this public key to GitHub:" -ForegroundColor Yellow
    Get-Content "$sshKey.pub"
    Write-Host ""
} else {
    Write-Skip "SSH key already exists"
    Get-Content "$sshKey.pub"
}

# Git config
$gitConfig = @(
    @('user.name',                          $GitUserName)
    @('user.email',                         $UserEmail)
    @('core.editor',                        'nvim')
    @('core.pager',                         'delta')
    @('interactive.diffFilter',             'delta --color-only --features=interactive')
    @('delta.navigate',                     'true')
    @('diff.external',                      'difft')
    @('diff.tool',                          'difftastic')
    @('difftool.difftastic.cmd',            'difft "$LOCAL" "$REMOTE"')
    @('difftool.prompt',                    'false')
    @('diff.algorithm',                     'histogram')
    @('merge.conflictstyle',                'zdiff3')
    @('init.defaultBranch',                 'main')
    @('pull.rebase',                        'true')
    @('push.autoSetupRemote',               'true')
)

foreach ($entry in $gitConfig) {
    $current = git config --global $entry[0] 2>$null
    if ($current -ne $entry[1]) {
        git config --global $entry[0] $entry[1]
        Write-Ok "git config $($entry[0]) = $($entry[1])"
    } else {
        Write-Skip "git config $($entry[0]) already set"
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add windows/modules/ssh.ps1
git commit -m "feat(windows): add ssh.ps1 — OpenSSH agent, keygen, git config"
```

---

### Task 6: Create neovim.ps1 module

**Files:**
- Create: `windows/modules/neovim.ps1`

- [ ] **Step 1: Write neovim.ps1**

1. `Install-WingetPackage Neovim.Neovim`
2. Clone or update AstroNvim config to `$env:LOCALAPPDATA\nvim`

```powershell
Write-Step "Setting up Neovim..."

Install-WingetPackage -Id 'Neovim.Neovim' -Name 'Neovim'

$nvimConfig = Join-Path $env:LOCALAPPDATA 'nvim'
if (-not (Test-Path $nvimConfig)) {
    Write-Step "Cloning AstroNvim config..."
    git clone $AstroNvimRepo $nvimConfig
    Write-Ok "AstroNvim config cloned to $nvimConfig"
} elseif (Test-Path (Join-Path $nvimConfig '.git')) {
    Write-Step "Updating AstroNvim config..."
    git -C $nvimConfig pull --ff-only
    Write-Ok "AstroNvim config updated"
} else {
    Write-Warn "$nvimConfig exists but is not a git repo — skipping"
}
```

- [ ] **Step 2: Commit**

```bash
git add windows/modules/neovim.ps1
git commit -m "feat(windows): add neovim.ps1 — Neovim + AstroNvim config"
```

---

### Task 7: Create nodejs.ps1 module

**Files:**
- Create: `windows/modules/nodejs.ps1`

- [ ] **Step 1: Write nodejs.ps1**

1. `Install-WingetPackage Schniz.fnm`
2. Initialize fnm into session
3. Install LTS + set default
4. Warn if system Node.js detected

```powershell
Write-Step "Setting up Node.js via fnm..."

Install-WingetPackage -Id 'Schniz.fnm' -Name 'fnm'

# Refresh PATH so fnm is available
Refresh-Path

# Initialize fnm in current session
Initialize-Fnm

if (Test-CommandExists fnm) {
    $installed = fnm list 2>&1
    if ($installed -notmatch 'lts-latest|v\d+\.\d+\.\d+') {
        Write-Step "Installing Node.js $NodeVersion..."
        fnm install $NodeVersion
        fnm default $NodeVersion
        Write-Ok "Node.js $NodeVersion installed and set as default"
    } else {
        Write-Skip "Node.js already installed via fnm"
    }
    # Re-initialize to pick up the installed version
    Initialize-Fnm
} else {
    Write-Warn "fnm not found in PATH after install — restart shell and re-run"
}

# Warn about system Node.js
$systemNode = winget list --id OpenJS.NodeJS --exact 2>&1
if ($systemNode -match 'OpenJS.NodeJS') {
    Write-Warn "System Node.js detected via winget. Consider removing it to avoid conflicts with fnm."
}
```

- [ ] **Step 2: Commit**

```bash
git add windows/modules/nodejs.ps1
git commit -m "feat(windows): add nodejs.ps1 — fnm + Node.js LTS"
```

---

### Task 8: Create python.ps1 module

**Files:**
- Create: `windows/modules/python.ps1`

- [ ] **Step 1: Write python.ps1**

```powershell
Write-Step "Setting up Python via uv..."

Install-WingetPackage -Id 'astral-sh.uv' -Name 'uv'
Install-WingetPackage -Id 'astral-sh.ruff' -Name 'ruff'

Refresh-Path

if (Test-CommandExists uv) {
    # Install Python 3.12
    $pyVersions = uv python list --installed 2>&1
    if ($pyVersions -notmatch '3\.12') {
        Write-Step "Installing Python 3.12 via uv..."
        uv python install 3.12
        Write-Ok "Python 3.12 installed"
    } else {
        Write-Skip "Python 3.12 already installed"
    }

    # Install global tools
    $uvTools = @('pyright', 'mypy', 'black', 'pytest')
    foreach ($tool in $uvTools) {
        if (-not (Test-CommandExists $tool)) {
            Write-Step "Installing $tool via uv tool..."
            uv tool install $tool
            Write-Ok "$tool installed"
        } else {
            Write-Skip "$tool already available"
        }
    }
} else {
    Write-Warn "uv not found in PATH after install — restart shell and re-run"
}
```

- [ ] **Step 2: Commit**

```bash
git add windows/modules/python.ps1
git commit -m "feat(windows): add python.ps1 — uv, ruff, Python 3.12, dev tools"
```

---

### Task 9: Create rust.ps1 module

**Files:**
- Create: `windows/modules/rust.ps1`

- [ ] **Step 1: Write rust.ps1**

```powershell
Write-Step "Setting up Rust..."

Install-WingetPackage -Id 'Rustlang.Rustup' -Name 'rustup'

Refresh-Path

if (Test-CommandExists rustup) {
    # Set stable as default
    $default = rustup default 2>&1
    if ($default -notmatch 'stable') {
        rustup default stable
        Write-Ok "Rust stable set as default"
    } else {
        Write-Skip "Rust stable already default"
    }

    # Install components
    $installed = rustup component list --installed 2>&1
    $components = @('rust-analyzer', 'clippy', 'rustfmt')
    foreach ($comp in $components) {
        if ($installed -notmatch $comp) {
            rustup component add $comp
            Write-Ok "Component $comp installed"
        } else {
            Write-Skip "Component $comp already installed"
        }
    }

    # Install sccache
    if (-not (Test-CommandExists sccache)) {
        Write-Step "Installing sccache..."
        cargo install sccache
        Write-Ok "sccache installed"
    } else {
        Write-Skip "sccache already installed"
    }
} else {
    Write-Warn "rustup not found in PATH after install — restart shell and re-run"
}
```

- [ ] **Step 2: Commit**

```bash
git add windows/modules/rust.ps1
git commit -m "feat(windows): add rust.ps1 — rustup, stable toolchain, components, sccache"
```

---

### Task 10: Create cpp.ps1 module

**Files:**
- Create: `windows/modules/cpp.ps1`

- [ ] **Step 1: Write cpp.ps1**

1. Check VS Build Tools via vswhere
2. Install CMake, Ninja, LLVM, meson, WinDbg, Sysinternals via winget
3. Clone and bootstrap vcpkg

```powershell
Write-Step "Setting up C++ toolchain..."

# Check VS Build Tools
$vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
if (Test-Path $vswhere) {
    $vsInstalls = & $vswhere -products * -requires Microsoft.VisualStudio.Workload.VCTools -format json | ConvertFrom-Json
    if ($vsInstalls.Count -gt 0) {
        Write-Ok "VS Build Tools found: $($vsInstalls[0].installationPath)"
    } else {
        Write-Warn "VS Build Tools installed but C++ workload not found. Install 'Desktop development with C++' workload."
    }
} else {
    Write-Warn "Visual Studio Installer not found — VS Build Tools may not be installed"
}

# Build system tools
Install-WingetPackage -Id 'Kitware.CMake' -Name 'CMake'
Install-WingetPackage -Id 'Ninja-build.Ninja' -Name 'Ninja'
Install-WingetPackage -Id 'LLVM.LLVM' -Name 'LLVM (clang, clangd, clang-format)'
Install-WingetPackage -Id 'mesonbuild.meson' -Name 'Meson'

# Debugging tools
Install-WingetPackage -Id 'Microsoft.WinDbg' -Name 'WinDbg'
Install-WingetPackage -Id 'Microsoft.Sysinternals.Suite' -Name 'Sysinternals Suite'

# vcpkg
$vcpkgRoot = Join-Path $env:USERPROFILE 'vcpkg'
if (-not (Test-Path (Join-Path $vcpkgRoot '.git'))) {
    Write-Step "Cloning vcpkg..."
    git clone https://github.com/microsoft/vcpkg.git $vcpkgRoot
    & (Join-Path $vcpkgRoot 'bootstrap-vcpkg.bat') -disableMetrics
    Write-Ok "vcpkg cloned and bootstrapped at $vcpkgRoot"
} else {
    Write-Step "Updating vcpkg..."
    git -C $vcpkgRoot pull --ff-only
    Write-Ok "vcpkg updated"
}

# Set VCPKG_ROOT if not set
if (-not $env:VCPKG_ROOT) {
    [System.Environment]::SetEnvironmentVariable('VCPKG_ROOT', $vcpkgRoot, 'User')
    $env:VCPKG_ROOT = $vcpkgRoot
    Write-Ok "VCPKG_ROOT set to $vcpkgRoot"
}
```

- [ ] **Step 2: Commit**

```bash
git add windows/modules/cpp.ps1
git commit -m "feat(windows): add cpp.ps1 — VS Build Tools check, CMake, LLVM, vcpkg, WinDbg, Sysinternals"
```

---

### Task 11: Create cli_tools.ps1 module

**Files:**
- Create: `windows/modules/cli_tools.ps1`

- [ ] **Step 1: Write cli_tools.ps1**

```powershell
Write-Step "Installing CLI tools..."

$cliPackages = @(
    @{ Id = 'dandavison.delta';       Name = 'delta' }
    @{ Id = 'sharkdp.hyperfine';      Name = 'hyperfine' }
    @{ Id = 'Casey.Just';             Name = 'just' }
    @{ Id = 'Watchexec.Watchexec';    Name = 'watchexec' }
    @{ Id = 'XAMPPRocky.tokei';       Name = 'tokei' }
    @{ Id = 'JesseDuffield.lazygit';  Name = 'lazygit' }
    @{ Id = 'bootandy.dust';          Name = 'dust' }
    @{ Id = 'Wilfred.difftastic';     Name = 'difftastic' }
)

foreach ($pkg in $cliPackages) {
    Install-WingetPackage -Id $pkg.Id -Name $pkg.Name
}
```

- [ ] **Step 2: Commit**

```bash
git add windows/modules/cli_tools.ps1
git commit -m "feat(windows): add cli_tools.ps1 — delta, lazygit, difftastic, and more"
```

---

### Task 12: Create codex.ps1 module

**Files:**
- Create: `windows/modules/codex.ps1`

Reference: `roles/codex/tasks/main.yml` for MCP server configuration and skill installation patterns.

- [ ] **Step 1: Write codex.ps1**

1. Verify npm available, initialize fnm if needed
2. Install `@openai/codex` globally
3. Read existing `config.toml`, add MCP servers if missing
4. Install curated skills (pdf, doc) via Python installer
5. Clone and symlink superpowers and claude-skills

```powershell
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
```

- [ ] **Step 2: Commit**

```bash
git add windows/modules/codex.ps1
git commit -m "feat(windows): add codex.ps1 — Codex CLI, MCP servers, skills"
```

---

### Task 13: Create claude.ps1 module

**Files:**
- Create: `windows/modules/claude.ps1`

Reference: `roles/claude/tasks/main.yml` and `roles/claude/files/settings.json` for MCP and plugin configuration.

- [ ] **Step 1: Write claude.ps1**

1. Verify npm available, initialize fnm if needed
2. Install `@anthropic-ai/claude-code` globally
3. Deploy settings.json from `roles/claude/files/settings.json`
4. Add MCP servers via `claude mcp add --scope user`
5. Add plugin marketplaces and enable plugins

```powershell
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
```

- [ ] **Step 2: Commit**

```bash
git add windows/modules/claude.ps1
git commit -m "feat(windows): add claude.ps1 — Claude CLI, settings, MCP, marketplaces, plugins"
```

---

### Task 14: Update README.md

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Add Windows section to README**

Add a section after the existing Linux quick start covering:
- Windows prerequisites (Windows 11, PowerShell 7+, Administrator)
- Quick start: `.\bootstrap.ps1`
- Running specific modules: `.\bootstrap.ps1 -Modules shell,rust,claude`
- Configuration overrides: `-UserEmail`, `-GitUserName`, etc.
- What gets installed (summary table)

- [ ] **Step 2: Commit**

```bash
git add README.md
git commit -m "docs: add Windows 11 provisioning section to README"
```
