<#
.SYNOPSIS
    Firstboot provisioning for Windows 11.
.DESCRIPTION
    Installs development tools and configures the environment for systems
    programming (C++, Rust, Lua, Python) and ML work with Codex support.
    Claude is available as an explicit opt-in module.
.PARAMETER Modules
    Comma-separated list of modules to run. If omitted, the default workstation
    modules run in order; optional modules such as claude must be selected explicitly.
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
    Remove Neovim config/data/state/cache before cloning AstroNvim. Enabled by default.
.PARAMETER PreserveNeovimState
    Preserve existing Neovim config/data/state/cache unless stale non-git config blocks cloning.
.PARAMETER WindowsDeveloperModeEnabled
    Enable Windows Developer Mode registry settings. Disabled by default.
.PARAMETER DevDrivePath
    Optional Dev Drive volume path to query or trust, for example D:.
.PARAMETER DevDriveTrustEnabled
    Trust the selected Dev Drive. Disabled by default and requires DevDrivePath.
.PARAMETER WslInstallEnabled
    Install WSL with the selected distribution. Disabled by default.
.PARAMETER WslDistribution
    WSL distribution to install when WslInstallEnabled is passed.
.PARAMETER WslConfigEnabled
    Manage the user .wslconfig file. Disabled by default.
.PARAMETER WslMemory
    Optional WSL2 memory limit, for example 16GB.
.PARAMETER WslProcessors
    Optional WSL2 virtual processor count. Zero keeps the WSL default.
.PARAMETER WslSwap
    Optional WSL2 swap size, for example 8GB or 0.
.PARAMETER WslNetworkingMode
    Optional WSL2 networking mode: none, nat, mirrored, or virtioproxy.
.PARAMETER WslAutoMemoryReclaim
    WSL experimental autoMemoryReclaim value used when WslConfigEnabled is passed.
.PARAMETER WslSparseVhdEnabled
    Enable sparse VHD for newly created WSL distributions when WslConfigEnabled is passed.
.PARAMETER WindowsSudoEnabled
    Enable Sudo for Windows. Disabled by default.
.PARAMETER WindowsSudoMode
    Sudo for Windows mode: forceNewWindow, disableInput, or normal.
.PARAMETER CodexMcpPruneUnmanaged
    Remove Codex MCP servers outside the configured allowlist.
.PARAMETER CodexSandboxMode
    Codex sandbox mode for shell/file operations (default: workspace-write).
.PARAMETER CodexApprovalPolicy
    Codex approval policy for shell/file operations (default: on-request).
.PARAMETER CodexApprovalsReviewer
    Reviewer for eligible Codex approval prompts (default: user).
.PARAMETER CodexWindowsSandbox
    Native Windows Codex sandbox mode (default: elevated).
.PARAMETER CodexWindowsSandboxPrivateDesktop
    Use a private desktop for native Windows sandboxed processes.
.PARAMETER CodexCheckForUpdateOnStartup
    Let Codex check for CLI updates at startup.
.PARAMETER CodexModel
    Codex model used by default for new work (default: gpt-5.6-sol).
.PARAMETER CodexModelReasoningEffort
    Codex reasoning effort (default: high; reserve max for explicit hard tasks).
.PARAMETER CodexServiceTier
    Codex service tier (default: default).
.PARAMETER CodexAgentsMaxThreads
    Concurrent Codex agent thread cap (default: 4).
.PARAMETER CodexAgentsMaxDepth
    Maximum sub-agent nesting depth (default: 1).
.PARAMETER CodexAgentsJobMaxRuntimeSeconds
    Maximum runtime for spawned agent jobs (default: 1800).
.PARAMETER CodexAppsDefaultToolsApprovalMode
    Default approval mode for ChatGPT app tools (default: writes).
.PARAMETER CodexAppsDestructiveEnabled
    Allow destructive ChatGPT app tools by default. Disabled by default.
.PARAMETER CodexAppsOpenWorldEnabled
    Allow open-world ChatGPT app tools by default. Disabled by default.
.PARAMETER CodexFetchMcpApprovalMode
    Approval mode for fetch MCP tools (default: prompt).
.PARAMETER CodexGithubMcpApprovalMode
    Approval mode for GitHub MCP tools (default: writes).
.PARAMETER CodexSerenaMcpApprovalMode
    Approval mode for Serena MCP tools (default: writes).
.PARAMETER CodexMicrosoftLearnMcpApprovalMode
    Approval mode for Microsoft Learn MCP tools (default: writes).
.PARAMETER CodexPlaywrightMcpApprovalMode
    Approval mode for Playwright MCP tools (default: prompt).
.PARAMETER CodexPlaywrightMcpEnabled
    Enable Playwright MCP browser automation. Disabled by default.
.PARAMETER CodexPruneDisabledOptionalMcp
    Remove optional Codex MCP servers managed by this script when their enable switch is off.
.PARAMETER CodexProfilesEnabled
    Create lean/deep Codex CLI profile files. Enabled by default.
.PARAMETER CodexLeanProfileModel
    Model used by the lean Codex profile and fast exploration agents.
.PARAMETER CodexLeanProfileReasoningEffort
    Reasoning effort used by the lean Codex profile and fast exploration agents.
.PARAMETER CodexCustomAgentsEnabled
    Create curated Codex custom agents for exploration, review, and docs research.
.PARAMETER CodexCustomAgents
    Comma-separated allowlist of curated custom agents to create.
.PARAMETER CodexUpdateEnabled
    Update the Codex CLI package during provisioning. Disabled by default.
.PARAMETER CodexTimesFmSkillEnabled
    Install the TimesFM forecasting skill from google-research/timesfm.
.PARAMETER MlEnvironmentPath
    Path for the reusable Windows ML Python virtual environment.
.PARAMETER MlPythonVersion
    Python version used for the reusable Windows ML environment.
.PARAMETER MlPythonPackages
    Comma-separated Python packages installed into the ML environment.
.PARAMETER MlTimesFmEnabled
    Install TimesFM runtime packages into the ML environment.
.EXAMPLE
    .\bootstrap.ps1
    .\bootstrap.ps1 -Modules shell,rust
    .\bootstrap.ps1 -Modules claude
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
    [bool]$ForceNeovimCleanup = $true,
    [switch]$PreserveNeovimState,
    [switch]$WindowsDeveloperModeEnabled,
    [string]$DevDrivePath = "",
    [switch]$DevDriveTrustEnabled,
    [switch]$WslInstallEnabled,
    [string]$WslDistribution = "Ubuntu",
    [switch]$WslConfigEnabled,
    [string]$WslMemory = "",
    [int]$WslProcessors = 0,
    [string]$WslSwap = "",
    [string]$WslNetworkingMode = "",
    [string]$WslAutoMemoryReclaim = "gradual",
    [switch]$WslSparseVhdEnabled,
    [switch]$WindowsSudoEnabled,
    [string]$WindowsSudoMode = "forceNewWindow",
    [string]$CodexMcpAllowlist = "context7,openaiDeveloperDocs,microsoft-learn,memory,fetch,sequential-thinking",
    [switch]$CodexMcpPruneUnmanaged,
    [switch]$CodexGithubMcpEnabled,
    [string]$CodexGithubTokenEnvVar = "GITHUB_PERSONAL_ACCESS_TOKEN",
    [switch]$CodexSerenaEnabled,
    [switch]$CodexPlaywrightMcpEnabled,
    [string]$CodexSandboxMode = "workspace-write",
    [string]$CodexApprovalPolicy = "on-request",
    [string]$CodexApprovalsReviewer = "user",
    [string]$CodexWindowsSandbox = "elevated",
    [bool]$CodexWindowsSandboxPrivateDesktop = $true,
    [bool]$CodexCheckForUpdateOnStartup = $true,
    [string]$CodexModel = "gpt-5.6-sol",
    [string]$CodexModelReasoningEffort = "high",
    [string]$CodexServiceTier = "default",
    [int]$CodexAgentsMaxThreads = 4,
    [int]$CodexAgentsMaxDepth = 1,
    [int]$CodexAgentsJobMaxRuntimeSeconds = 1800,
    [string]$CodexAppsDefaultToolsApprovalMode = "writes",
    [bool]$CodexAppsDestructiveEnabled = $false,
    [bool]$CodexAppsOpenWorldEnabled = $false,
    [string]$CodexFetchMcpApprovalMode = "prompt",
    [string]$CodexMicrosoftLearnMcpApprovalMode = "writes",
    [string]$CodexGithubMcpApprovalMode = "writes",
    [string]$CodexSerenaMcpApprovalMode = "writes",
    [string]$CodexPlaywrightMcpApprovalMode = "prompt",
    [bool]$CodexPruneDisabledOptionalMcp = $true,
    [bool]$CodexProfilesEnabled = $true,
    [string]$CodexLeanProfileModel = "gpt-5.6-terra",
    [string]$CodexLeanProfileReasoningEffort = "medium",
    [bool]$CodexCustomAgentsEnabled = $true,
    [string]$CodexCustomAgents = "explorer-terra,reviewer-deep,docs-researcher",
    [switch]$CodexUpdateEnabled,
    [string]$CodexCuratedSkills = "cli-creator,jupyter-notebook,pdf,playwright,security-best-practices,winui-app",
    [string]$CodexSuperpowersSkills = "systematic-debugging,verification-before-completion,using-superpowers,test-driven-development,writing-plans,executing-plans,receiving-code-review,requesting-code-review,brainstorming,writing-skills,dispatching-parallel-agents",
    [string]$CodexKarpathySkills = "karpathy-guidelines",
    [string]$CodexClaudeSkills = "code-reviewer,cpp-pro,rust-engineer,python-pro,pandas-pro,ml-pipeline,fine-tuning-expert,database-optimizer,sql-pro,mcp-developer,debugging-wizard,test-master,api-designer,architecture-designer,cli-developer,code-documenter,devops-engineer,legacy-modernizer,secure-code-guardian,security-reviewer,spec-miner,the-fool",
    [switch]$CodexTimesFmSkillEnabled,
    [string]$CodexTimesFmSkillRepo = "https://github.com/google-research/timesfm.git",
    [string]$CodexTimesFmSkillPath = "timesfm-forecasting",
    [string]$MlPythonVersion = "3.12",
    [string]$MlEnvironmentPath = "",
    [string]$MlPythonPackages = "numpy,pandas,polars,duckdb,scikit-learn,matplotlib,seaborn,jupyterlab,ipykernel,ipywidgets,mlflow,optuna,xgboost,pyarrow,tqdm",
    [switch]$MlTimesFmEnabled,
    [string]$MlTimesFmBackend = "torch-cpu"
)

$ErrorActionPreference = 'Stop'
$ScriptRoot = $PSScriptRoot

if ($PreserveNeovimState) {
    $ForceNeovimCleanup = $false
}

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

function Test-IsAdministrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]::new($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Assert-AdministratorForSelectedModules {
    param([Parameter(Mandatory)][string[]]$SelectedModules)

    $NonAdminModules = @(
        'codex'
        'claude'
    )

    if (Test-IsAdministrator) {
        return
    }

    $adminModules = @($SelectedModules | Where-Object { $_ -notin $NonAdminModules })
    if ($adminModules.Count -eq 0) {
        return
    }

    throw "Run PowerShell as Administrator for modules: $($adminModules -join ', '). Non-admin module runs are limited to: $($NonAdminModules -join ', ')."
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
        [string]$Package = $Command,
        [string[]]$InstallArgs = @()
    )
    if (Test-CommandExists $Command) {
        Write-Skip "$Command already available"
        return
    }
    if (-not (Test-CommandExists cargo)) {
        Write-Warn "cargo not available. Run rust module first to install $Package."
        return
    }
    $installArgsText = if ($InstallArgs.Count -gt 0) { " $($InstallArgs -join ' ')" } else { '' }
    Write-Step "Installing $Package via cargo$installArgsText..."
    cargo install $Package @InstallArgs
    if ($LASTEXITCODE -ne 0) {
        throw "cargo install $Package returned exit code $LASTEXITCODE"
    }
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
    if ($LASTEXITCODE -ne 0) {
        throw "uv tool install $Package returned exit code $LASTEXITCODE"
    }
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
    'dev_settings'
    'dev_drive'
    'wsl'
    'sudo'
    'shell'
    'ssh'
    'neovim'
    'nodejs'
    'python'
    'rust'
    'cpp'
    'lua'
    'ml'
    'cli_tools'
    'codex'
    'claude'
)

if ([string]::IsNullOrWhiteSpace($Modules)) {
    $SelectedModules = @(
        'base'
        'dev_settings'
        'shell'
        'ssh'
        'neovim'
        'nodejs'
        'python'
        'rust'
        'cpp'
        'lua'
        'ml'
        'cli_tools'
        'codex'
    )
} else {
    $SelectedModules = $Modules -split ',' | ForEach-Object { $_.Trim() }
}

Assert-AdministratorForSelectedModules -SelectedModules $SelectedModules

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
