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

function Set-CodexMcpSetting {
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string]$Key,
        [Parameter(Mandatory)][string]$Value
    )
    if (-not (Test-CodexMcpConfigured $Name)) { return }

    $lines = @()
    if (Test-Path $script:ConfigToml) {
        $lines = @(Get-Content -LiteralPath $script:ConfigToml)
    }

    $section = "[mcp_servers.$Name]"
    $startIndex = [array]::IndexOf($lines, $section)
    if ($startIndex -ge 0) {
        $endIndex = $lines.Count
        for ($i = $startIndex + 1; $i -lt $lines.Count; $i++) {
            if ($lines[$i] -match '^\s*\[') {
                $endIndex = $i
                break
            }
        }
        if ($lines[$startIndex..($endIndex - 1)] -contains "$Key = $Value") {
            Write-Skip "MCP $Name $Key already set"
            return
        }
    }

    $result = New-Object System.Collections.Generic.List[string]
    $inSection = $false
    $seen = $false

    foreach ($line in $lines) {
        if ($line -eq $section) {
            $inSection = $true
            $result.Add($line)
            continue
        }

        if ($inSection -and $line -match '^\s*\[') {
            if (-not $seen) {
                $result.Add("$Key = $Value")
                $seen = $true
            }
            $inSection = $false
        }

        if ($inSection -and $line -match "^$([regex]::Escape($Key)) = ") {
            if (-not $seen) {
                $result.Add("$Key = $Value")
                $seen = $true
            }
            continue
        }

        $result.Add($line)
    }

    if ($inSection -and -not $seen) {
        $result.Add("$Key = $Value")
    }

    Set-Content -LiteralPath $script:ConfigToml -Value $result -Encoding utf8
    Write-Ok "MCP $Name $Key = $Value"
}

function Set-CodexTopLevelSetting {
    param(
        [Parameter(Mandatory)][string]$Key,
        [Parameter(Mandatory)][string]$Value
    )

    if (-not (Test-Path $script:ConfigToml)) {
        New-Item -ItemType File -Path $script:ConfigToml -Force | Out-Null
    }

    $lines = @(Get-Content -LiteralPath $script:ConfigToml)
    $result = New-Object System.Collections.Generic.List[string]
    $seen = $false
    $inTopLevel = $true

    foreach ($line in $lines) {
        if ($inTopLevel -and $line -match '^\s*\[') {
            if (-not $seen) {
                $result.Add("$Key = $Value")
                $seen = $true
            }
            $inTopLevel = $false
        }

        if ($inTopLevel -and $line -match "^\s*$([regex]::Escape($Key))\s*=") {
            if (-not $seen) {
                $result.Add("$Key = $Value")
                $seen = $true
            }
            continue
        }

        $result.Add($line)
    }

    if (-not $seen) {
        $result.Add("$Key = $Value")
    }

    $current = if (Test-Path $script:ConfigToml) { Get-Content -LiteralPath $script:ConfigToml -Raw } else { '' }
    $next = ($result -join [Environment]::NewLine) + [Environment]::NewLine
    if ($current -eq $next) {
        Write-Skip "Codex $Key already set"
        return
    }

    Set-Content -LiteralPath $script:ConfigToml -Value $result -Encoding utf8
    Write-Ok "Codex $Key = $Value"
}

function Set-CodexTableSetting {
    param(
        [Parameter(Mandatory)][string]$Table,
        [Parameter(Mandatory)][string]$Key,
        [Parameter(Mandatory)][string]$Value
    )

    if (-not (Test-Path $script:ConfigToml)) {
        New-Item -ItemType File -Path $script:ConfigToml -Force | Out-Null
    }

    $lines = @(Get-Content -LiteralPath $script:ConfigToml)
    $section = "[$Table]"
    $result = New-Object System.Collections.Generic.List[string]
    $inSection = $false
    $sectionSeen = $false
    $settingSeen = $false

    foreach ($line in $lines) {
        if ($line -eq $section) {
            $sectionSeen = $true
            $inSection = $true
            $result.Add($line)
            continue
        }

        if ($inSection -and $line -match '^\s*\[') {
            if (-not $settingSeen) {
                $result.Add("$Key = $Value")
                $settingSeen = $true
            }
            $inSection = $false
        }

        if ($inSection -and $line -match "^\s*$([regex]::Escape($Key))\s*=") {
            if (-not $settingSeen) {
                $result.Add("$Key = $Value")
                $settingSeen = $true
            }
            continue
        }

        $result.Add($line)
    }

    if ($inSection -and -not $settingSeen) {
        $result.Add("$Key = $Value")
        $settingSeen = $true
    }

    if (-not $sectionSeen) {
        if ($result.Count -gt 0 -and -not [string]::IsNullOrWhiteSpace($result[$result.Count - 1])) {
            $result.Add('')
        }
        $result.Add($section)
        $result.Add("$Key = $Value")
    }

    $current = if (Test-Path $script:ConfigToml) { Get-Content -LiteralPath $script:ConfigToml -Raw } else { '' }
    $next = ($result -join [Environment]::NewLine) + [Environment]::NewLine
    if ($current -eq $next) {
        Write-Skip "Codex $Table.$Key already set"
        return
    }

    Set-Content -LiteralPath $script:ConfigToml -Value $result -Encoding utf8
    Write-Ok "Codex $Table.$Key = $Value"
}

function Add-CodexPrefixRuleIfMissing {
    param(
        [Parameter(Mandatory)][string]$Pattern,
        [Parameter(Mandatory)][string]$Rule
    )

    if (-not (Test-Path $script:CodexDefaultRules)) {
        New-Item -ItemType File -Path $script:CodexDefaultRules -Force | Out-Null
    }

    $source = Get-Content -LiteralPath $script:CodexDefaultRules -Raw
    if ($source -and $source.Contains("pattern = $Pattern")) {
        Write-Skip "Codex rule already present: $Pattern"
        return
    }

    if (-not [string]::IsNullOrWhiteSpace($source)) {
        Add-Content -LiteralPath $script:CodexDefaultRules -Value ''
    }
    Add-Content -LiteralPath $script:CodexDefaultRules -Value $Rule
    Write-Ok "Codex rule added: $Pattern"
}

function Remove-CodexPrefixAllowRulesByPattern {
    param(
        [Parameter(Mandatory)][string]$Pattern,
        [switch]$Quiet
    )

    if (-not (Test-Path $script:CodexDefaultRules)) {
        return
    }

    $source = Get-Content -LiteralPath $script:CodexDefaultRules -Raw
    if ([string]::IsNullOrWhiteSpace($source)) {
        return
    }

    $escapedPattern = [regex]::Escape($Pattern)
    $ruleRegex = [regex]::new(
        "(?ms)(?:^|\r?\n)prefix_rule\((?:(?!^\s*prefix_rule\().)*?pattern\s*=\s*$escapedPattern(?:(?!^\s*prefix_rule\().)*?decision\s*=\s*""allow""(?:(?!^\s*prefix_rule\().)*?\)\s*"
    )
    $updated = $ruleRegex.Replace($source, [Environment]::NewLine)
    $updated = [regex]::Replace($updated, "(\r?\n){3,}", [Environment]::NewLine + [Environment]::NewLine).Trim() + [Environment]::NewLine

    if ($updated -eq $source) {
        if (-not $Quiet) {
            Write-Skip "Unsafe Codex allow rule absent: $Pattern"
        }
        return
    }

    Set-Content -LiteralPath $script:CodexDefaultRules -Value $updated -NoNewline -Encoding utf8
    Write-Ok "Removed unsafe Codex allow rule: $Pattern"
}

function Remove-CodexUnsafeShellWrapperRules {
    foreach ($pattern in @('["pwsh"]', '["wsl", "bash", "-lc"]', '["wsl", "-e", "bash"]')) {
        Remove-CodexPrefixAllowRulesByPattern $pattern
    }
}

function Remove-CodexUnsafeSystemMutatorRules {
    foreach ($pattern in @(
        '["winget"]',
        '["git", "push"]',
        '["git", "reset", "--hard"]',
        '["git", "clean"]',
        '["git", "restore"]',
        '["git", "checkout", "--"]',
        '["git", "rebase"]',
        '["scoop"]',
        '["choco"]',
        '["rustup"]',
        '["cargo", "install"]',
        '["uv", "tool", "install"]',
        '["uv", "tool", "upgrade"]',
        '["npm", "install", "-g"]',
        '["npm", "install", "--global"]',
        '["python", "-m", "pip", "install"]',
        '["py", "-m", "pip", "install"]',
        '["wsl", "--update"]',
        '["wsl", "--install"]',
        '["wsl", "--shutdown"]',
        '["Set-ExecutionPolicy"]',
        '["Set-ItemProperty"]',
        '["New-ItemProperty"]',
        '["Remove-ItemProperty"]',
        '["reg"]',
        '["netsh"]',
        '["sc"]',
        '["Start-Process"]',
        '["Set-Service"]',
        '["New-Service"]',
        '["Remove-Service"]',
        '["Enable-WindowsOptionalFeature"]',
        '["Disable-WindowsOptionalFeature"]',
        '["dism"]',
        '["bcdedit"]'
    )) {
        Remove-CodexPrefixAllowRulesByPattern -Pattern $pattern -Quiet
    }
}

function Set-CodexPermissionsExample {
    $content = @'
# Example only. Copy selected settings to ~/.codex/config.toml when needed.
model = "gpt-5.6-sol"
model_reasoning_effort = "high"
service_tier = "default"
sandbox_mode = "workspace-write"
approval_policy = "on-request"
approvals_reviewer = "user"
check_for_update_on_startup = true

[agents]
max_threads = 4
max_depth = 1
job_max_runtime_seconds = 1800

[apps._default]
default_tools_approval_mode = "writes"
destructive_enabled = false
open_world_enabled = false
approvals_reviewer = "user"

[windows]
sandbox = "elevated"
sandbox_private_desktop = true

[sandbox_workspace_write]
writable_roots = [
  "C:\\Users\\Administrator\\projects\\example"
]
'@

    if ((Test-Path $script:CodexPermissionsExample) -and (Get-Content -LiteralPath $script:CodexPermissionsExample -Raw) -eq $content) {
        Write-Skip "Codex permissions example already current"
        return
    }

    Set-Content -LiteralPath $script:CodexPermissionsExample -Value $content -NoNewline -Encoding utf8
    Write-Ok "Codex permissions example updated"
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

function Sync-CodexRepoPathSkill {
    param(
        [Parameter(Mandatory)][string]$Namespace,
        [Parameter(Mandatory)][string]$Repo,
        [Parameter(Mandatory)][string]$SourceDirName,
        [Parameter(Mandatory)][string]$SkillPath,
        [Parameter(Mandatory)][string]$SkillName
    )

    $sourceDir = Join-Path $script:SkillSourceRoot $SourceDirName
    if (-not (Test-Path (Join-Path $sourceDir '.git'))) {
        Write-Step "Cloning $Namespace skill source..."
        git clone $Repo $sourceDir
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to clone $Namespace skill source from $Repo"
        }
        Write-Ok "$Namespace skill source cloned"
    } else {
        git -C $sourceDir pull --ff-only 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to update $Namespace skill source in $sourceDir"
        }
        Write-Skip "$Namespace skill source already cloned, updated"
    }

    $sourceSkill = Join-Path $sourceDir $SkillPath
    if (-not (Test-Path (Join-Path $sourceSkill 'SKILL.md'))) {
        throw "Selected $Namespace skill '$SkillName' was not found at $sourceSkill."
    }

    $namespaceDir = Join-Path $script:AgentsSkillsDir $Namespace
    if (-not (Test-Path $namespaceDir)) {
        New-Item -ItemType Directory -Path $namespaceDir -Force | Out-Null
    }

    Get-ChildItem $namespaceDir -Force | ForEach-Object {
        if ($_.Name -ne $SkillName) {
            Remove-Item -LiteralPath $_.FullName -Recurse -Force
            Write-Ok "Removed stale $Namespace skill: $($_.Name)"
        }
    }

    $destSkill = Join-Path $namespaceDir $SkillName
    $shouldCreateLink = $true
    if (Test-Path $destSkill) {
        $destItem = Get-Item -LiteralPath $destSkill -Force
        $destTargets = @($destItem.Target)
        if ($destItem.LinkType -eq 'SymbolicLink' -and $sourceSkill -in $destTargets) {
            Write-Skip "$Namespace skill already present: $SkillName"
            $shouldCreateLink = $false
        } else {
            Remove-Item -LiteralPath $destSkill -Recurse -Force
            Write-Ok "Removed stale $Namespace skill entry: $SkillName"
        }
    }

    if ($shouldCreateLink) {
        New-Item -ItemType SymbolicLink -Path $destSkill -Target $sourceSkill -Force | Out-Null
        Write-Ok "$Namespace skill symlinked: $SkillName"
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
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to install Codex CLI"
    }
    Write-Ok "Codex CLI installed"
} elseif ($CodexUpdateEnabled) {
    Write-Step "Updating Codex CLI..."
    npm install -g @openai/codex
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to update Codex CLI"
    }
    Write-Ok "Codex CLI updated"
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
$codexRulesDir = Join-Path $codexDir 'rules'
$script:CodexDefaultRules = Join-Path $codexRulesDir 'default.rules'
$script:CodexPermissionsExample = Join-Path $codexDir 'config.permissions.example.toml'
if (-not (Test-Path $codexRulesDir)) {
    New-Item -ItemType Directory -Path $codexRulesDir -Force | Out-Null
}

Set-CodexTopLevelSetting 'sandbox_mode' "`"$CodexSandboxMode`""
Set-CodexTopLevelSetting 'approval_policy' "`"$CodexApprovalPolicy`""
$codexCheckForUpdateOnStartup = $CodexCheckForUpdateOnStartup.ToString().ToLowerInvariant()
$codexWindowsSandboxPrivateDesktop = $CodexWindowsSandboxPrivateDesktop.ToString().ToLowerInvariant()
$codexAppsDestructiveEnabled = $CodexAppsDestructiveEnabled.ToString().ToLowerInvariant()
$codexAppsOpenWorldEnabled = $CodexAppsOpenWorldEnabled.ToString().ToLowerInvariant()
Set-CodexTopLevelSetting 'model' "`"$CodexModel`""
Set-CodexTopLevelSetting 'model_reasoning_effort' "`"$CodexModelReasoningEffort`""
Set-CodexTopLevelSetting 'service_tier' "`"$CodexServiceTier`""
Set-CodexTopLevelSetting 'approvals_reviewer' "`"$CodexApprovalsReviewer`""
Set-CodexTopLevelSetting 'check_for_update_on_startup' $codexCheckForUpdateOnStartup
Set-CodexTableSetting 'agents' 'max_threads' $CodexAgentsMaxThreads
Set-CodexTableSetting 'agents' 'max_depth' $CodexAgentsMaxDepth
Set-CodexTableSetting 'agents' 'job_max_runtime_seconds' $CodexAgentsJobMaxRuntimeSeconds
Set-CodexTableSetting 'apps._default' 'default_tools_approval_mode' "`"$CodexAppsDefaultToolsApprovalMode`""
Set-CodexTableSetting 'apps._default' 'destructive_enabled' $codexAppsDestructiveEnabled
Set-CodexTableSetting 'apps._default' 'open_world_enabled' $codexAppsOpenWorldEnabled
Set-CodexTableSetting 'apps._default' 'approvals_reviewer' "`"$CodexApprovalsReviewer`""
Set-CodexTableSetting 'windows' 'sandbox' "`"$CodexWindowsSandbox`""
Set-CodexTableSetting 'windows' 'sandbox_private_desktop' $codexWindowsSandboxPrivateDesktop

Remove-CodexUnsafeShellWrapperRules
Remove-CodexUnsafeSystemMutatorRules

Add-CodexPrefixRuleIfMissing '["git"]' @'
prefix_rule(
    pattern = ["git"],
    decision = "allow",
    justification = "Allow local Git workflows in trusted workspaces without repeated prompts",
    match = ["git status --short"],
    not_match = ["git-lfs status"],
)
'@
Add-CodexPrefixRuleIfMissing '["git", "push"]' @'
prefix_rule(
    pattern = ["git", "push"],
    decision = "prompt",
    justification = "Prompt before publishing commits to a remote repository",
    match = ["git push"],
)
'@
Add-CodexPrefixRuleIfMissing '["git", "reset", "--hard"]' @'
prefix_rule(
    pattern = ["git", "reset", "--hard"],
    decision = "prompt",
    justification = "Prompt before discarding tracked workspace changes",
    match = ["git reset --hard HEAD"],
)
'@
Add-CodexPrefixRuleIfMissing '["git", "clean"]' @'
prefix_rule(
    pattern = ["git", "clean"],
    decision = "prompt",
    justification = "Prompt before deleting untracked workspace files",
    match = ["git clean -fd"],
)
'@
Add-CodexPrefixRuleIfMissing '["git", "restore"]' @'
prefix_rule(
    pattern = ["git", "restore"],
    decision = "prompt",
    justification = "Prompt before restoring files and discarding local edits",
    match = ["git restore README.md"],
)
'@
Add-CodexPrefixRuleIfMissing '["git", "checkout", "--"]' @'
prefix_rule(
    pattern = ["git", "checkout", "--"],
    decision = "prompt",
    justification = "Prompt before checkout restores files and discards local edits",
    match = ["git checkout -- README.md"],
)
'@
Add-CodexPrefixRuleIfMissing '["git", "rebase"]' @'
prefix_rule(
    pattern = ["git", "rebase"],
    decision = "prompt",
    justification = "Prompt before rewriting local history",
    match = ["git rebase main"],
)
'@
Add-CodexPrefixRuleIfMissing '["rg"]' @'
prefix_rule(
    pattern = ["rg"],
    decision = "allow",
    justification = "Allow ripgrep workspace searches without repeated prompts",
)
'@
Add-CodexPrefixRuleIfMissing '["fd"]' @'
prefix_rule(
    pattern = ["fd"],
    decision = "allow",
    justification = "Allow fd workspace file discovery without repeated prompts",
)
'@
Add-CodexPrefixRuleIfMissing '["bat"]' @'
prefix_rule(
    pattern = ["bat"],
    decision = "allow",
    justification = "Allow bat workspace file viewing without repeated prompts",
)
'@
Add-CodexPrefixRuleIfMissing '["eza"]' @'
prefix_rule(
    pattern = ["eza"],
    decision = "allow",
    justification = "Allow eza workspace directory listing without repeated prompts",
)
'@
Add-CodexPrefixRuleIfMissing '["delta"]' @'
prefix_rule(
    pattern = ["delta"],
    decision = "allow",
    justification = "Allow delta diff viewing without repeated prompts",
)
'@
Add-CodexPrefixRuleIfMissing '["difft"]' @'
prefix_rule(
    pattern = ["difft"],
    decision = "allow",
    justification = "Allow difftastic diff viewing without repeated prompts",
)
'@
Add-CodexPrefixRuleIfMissing '["difftastic"]' @'
prefix_rule(
    pattern = ["difftastic"],
    decision = "allow",
    justification = "Allow difftastic diff viewing without repeated prompts",
)
'@
Add-CodexPrefixRuleIfMissing '["just"]' @'
prefix_rule(
    pattern = ["just"],
    decision = "allow",
    justification = "Allow project Justfile workflows in trusted workspaces without repeated prompts",
)
'@
Add-CodexPrefixRuleIfMissing '["uv", "run"]' @'
prefix_rule(
    pattern = ["uv", "run"],
    decision = "allow",
    justification = "Allow uv run project commands in trusted workspaces without repeated prompts",
    match = ["uv run python -m pytest"],
    not_match = ["uvx ruff"],
)
'@
Add-CodexPrefixRuleIfMissing '["Get-Content"]' @'
prefix_rule(
    pattern = ["Get-Content"],
    decision = "allow",
    justification = "Allow PowerShell workspace file reads without repeated prompts",
    match = ["Get-Content README.md"],
    not_match = ["pwsh -Command Get-Content README.md"],
)
'@
Add-CodexPrefixRuleIfMissing '["Select-String"]' @'
prefix_rule(
    pattern = ["Select-String"],
    decision = "allow",
    justification = "Allow PowerShell workspace text searches without repeated prompts",
)
'@
Add-CodexPrefixRuleIfMissing '["Get-ChildItem"]' @'
prefix_rule(
    pattern = ["Get-ChildItem"],
    decision = "allow",
    justification = "Allow PowerShell workspace directory listing without repeated prompts",
)
'@
Add-CodexPrefixRuleIfMissing '["Get-Item"]' @'
prefix_rule(
    pattern = ["Get-Item"],
    decision = "allow",
    justification = "Allow PowerShell workspace file metadata inspection without repeated prompts",
)
'@
Add-CodexPrefixRuleIfMissing '["Test-Path"]' @'
prefix_rule(
    pattern = ["Test-Path"],
    decision = "allow",
    justification = "Allow PowerShell workspace path checks without repeated prompts",
)
'@
Add-CodexPrefixRuleIfMissing '["Resolve-Path"]' @'
prefix_rule(
    pattern = ["Resolve-Path"],
    decision = "allow",
    justification = "Allow PowerShell workspace path resolution without repeated prompts",
)
'@
Add-CodexPrefixRuleIfMissing '["Get-Location"]' @'
prefix_rule(
    pattern = ["Get-Location"],
    decision = "allow",
    justification = "Allow PowerShell current directory checks without repeated prompts",
)
'@
Add-CodexPrefixRuleIfMissing '["Get-FileHash"]' @'
prefix_rule(
    pattern = ["Get-FileHash"],
    decision = "allow",
    justification = "Allow PowerShell workspace file hash inspection without repeated prompts",
)
'@
Add-CodexPrefixRuleIfMissing '["Select-Object"]' @'
prefix_rule(
    pattern = ["Select-Object"],
    decision = "allow",
    justification = "Allow PowerShell pipeline projection without repeated prompts",
)
'@
Add-CodexPrefixRuleIfMissing '["Sort-Object"]' @'
prefix_rule(
    pattern = ["Sort-Object"],
    decision = "allow",
    justification = "Allow PowerShell pipeline sorting without repeated prompts",
)
'@
Add-CodexPrefixRuleIfMissing '["Measure-Object"]' @'
prefix_rule(
    pattern = ["Measure-Object"],
    decision = "allow",
    justification = "Allow PowerShell pipeline measurement without repeated prompts",
)
'@
Add-CodexPrefixRuleIfMissing '["Compare-Object"]' @'
prefix_rule(
    pattern = ["Compare-Object"],
    decision = "allow",
    justification = "Allow PowerShell object comparison without repeated prompts",
)
'@
Add-CodexPrefixRuleIfMissing '["Format-Table"]' @'
prefix_rule(
    pattern = ["Format-Table"],
    decision = "allow",
    justification = "Allow PowerShell table formatting without repeated prompts",
)
'@
Add-CodexPrefixRuleIfMissing '["Format-List"]' @'
prefix_rule(
    pattern = ["Format-List"],
    decision = "allow",
    justification = "Allow PowerShell list formatting without repeated prompts",
)
'@
Add-CodexPrefixRuleIfMissing '["Out-String"]' @'
prefix_rule(
    pattern = ["Out-String"],
    decision = "allow",
    justification = "Allow PowerShell output string conversion without repeated prompts",
)
'@

Add-CodexPrefixRuleIfMissing '["winget"]' @'
prefix_rule(
    pattern = ["winget"],
    decision = "prompt",
    justification = "Prompt before package installs, upgrades, or source changes with winget",
    match = ["winget install Microsoft.PowerShell"],
)
'@
Add-CodexPrefixRuleIfMissing '["scoop"]' @'
prefix_rule(
    pattern = ["scoop"],
    decision = "prompt",
    justification = "Prompt before package installs, upgrades, or bucket changes with Scoop",
    match = ["scoop install ripgrep"],
)
'@
Add-CodexPrefixRuleIfMissing '["choco"]' @'
prefix_rule(
    pattern = ["choco"],
    decision = "prompt",
    justification = "Prompt before package installs or upgrades with Chocolatey",
    match = ["choco install git"],
)
'@
Add-CodexPrefixRuleIfMissing '["rustup"]' @'
prefix_rule(
    pattern = ["rustup"],
    decision = "prompt",
    justification = "Prompt before modifying Rust toolchains or global components",
    match = ["rustup update stable"],
)
'@
Add-CodexPrefixRuleIfMissing '["cargo", "install"]' @'
prefix_rule(
    pattern = ["cargo", "install"],
    decision = "prompt",
    justification = "Prompt before installing or replacing global Cargo binaries",
    match = ["cargo install cargo-nextest"],
)
'@
Add-CodexPrefixRuleIfMissing '["uv", "tool", "install"]' @'
prefix_rule(
    pattern = ["uv", "tool", "install"],
    decision = "prompt",
    justification = "Prompt before installing global uv tools",
    match = ["uv tool install ruff"],
)
'@
Add-CodexPrefixRuleIfMissing '["uv", "tool", "upgrade"]' @'
prefix_rule(
    pattern = ["uv", "tool", "upgrade"],
    decision = "prompt",
    justification = "Prompt before upgrading global uv tools",
    match = ["uv tool upgrade ruff"],
)
'@
Add-CodexPrefixRuleIfMissing '["npm", "install", "-g"]' @'
prefix_rule(
    pattern = ["npm", "install", "-g"],
    decision = "prompt",
    justification = "Prompt before installing or replacing global npm packages",
    match = ["npm install -g @openai/codex"],
)
'@
Add-CodexPrefixRuleIfMissing '["npm", "install", "--global"]' @'
prefix_rule(
    pattern = ["npm", "install", "--global"],
    decision = "prompt",
    justification = "Prompt before installing or replacing global npm packages",
    match = ["npm install --global @openai/codex"],
)
'@
Add-CodexPrefixRuleIfMissing '["python", "-m", "pip", "install"]' @'
prefix_rule(
    pattern = ["python", "-m", "pip", "install"],
    decision = "prompt",
    justification = "Prompt before installing packages into the active Python environment",
    match = ["python -m pip install pytest"],
)
'@
Add-CodexPrefixRuleIfMissing '["py", "-m", "pip", "install"]' @'
prefix_rule(
    pattern = ["py", "-m", "pip", "install"],
    decision = "prompt",
    justification = "Prompt before installing packages into the active Python environment",
    match = ["py -m pip install pytest"],
)
'@
Add-CodexPrefixRuleIfMissing '["wsl", "--update"]' @'
prefix_rule(
    pattern = ["wsl", "--update"],
    decision = "prompt",
    justification = "Prompt before updating WSL system components",
    match = ["wsl --update"],
)
'@
Add-CodexPrefixRuleIfMissing '["wsl", "--install"]' @'
prefix_rule(
    pattern = ["wsl", "--install"],
    decision = "prompt",
    justification = "Prompt before installing WSL distributions or platform components",
    match = ["wsl --install -d Ubuntu"],
)
'@
Add-CodexPrefixRuleIfMissing '["wsl", "--shutdown"]' @'
prefix_rule(
    pattern = ["wsl", "--shutdown"],
    decision = "prompt",
    justification = "Prompt before stopping all WSL distributions",
    match = ["wsl --shutdown"],
)
'@
Add-CodexPrefixRuleIfMissing '["Set-ExecutionPolicy"]' @'
prefix_rule(
    pattern = ["Set-ExecutionPolicy"],
    decision = "prompt",
    justification = "Prompt before changing PowerShell execution policy",
    match = ["Set-ExecutionPolicy RemoteSigned -Scope CurrentUser"],
)
'@
Add-CodexPrefixRuleIfMissing '["Set-ItemProperty"]' @'
prefix_rule(
    pattern = ["Set-ItemProperty"],
    decision = "prompt",
    justification = "Prompt before changing registry or provider-backed settings",
    match = ["Set-ItemProperty HKCU:\\Software\\Example Name Value"],
)
'@
Add-CodexPrefixRuleIfMissing '["New-ItemProperty"]' @'
prefix_rule(
    pattern = ["New-ItemProperty"],
    decision = "prompt",
    justification = "Prompt before creating registry or provider-backed settings",
    match = ["New-ItemProperty HKCU:\\Software\\Example Name Value"],
)
'@
Add-CodexPrefixRuleIfMissing '["Remove-ItemProperty"]' @'
prefix_rule(
    pattern = ["Remove-ItemProperty"],
    decision = "prompt",
    justification = "Prompt before deleting registry or provider-backed settings",
    match = ["Remove-ItemProperty HKCU:\\Software\\Example Name"],
)
'@
Add-CodexPrefixRuleIfMissing '["reg"]' @'
prefix_rule(
    pattern = ["reg"],
    decision = "prompt",
    justification = "Prompt before direct registry changes with reg.exe",
    match = ["reg add HKCU\\Software\\Example /v Name /t REG_SZ /d Value"],
)
'@
Add-CodexPrefixRuleIfMissing '["netsh"]' @'
prefix_rule(
    pattern = ["netsh"],
    decision = "prompt",
    justification = "Prompt before changing Windows network configuration",
    match = ["netsh interface show interface"],
)
'@
Add-CodexPrefixRuleIfMissing '["sc"]' @'
prefix_rule(
    pattern = ["sc"],
    decision = "prompt",
    justification = "Prompt before changing Windows services with sc.exe",
    match = ["sc query ssh-agent"],
)
'@
Add-CodexPrefixRuleIfMissing '["Start-Process"]' @'
prefix_rule(
    pattern = ["Start-Process"],
    decision = "prompt",
    justification = "Prompt before launching external programs outside the current tool sandbox",
    match = ["Start-Process notepad"],
)
'@
Add-CodexPrefixRuleIfMissing '["Set-Service"]' @'
prefix_rule(
    pattern = ["Set-Service"],
    decision = "prompt",
    justification = "Prompt before changing Windows service configuration",
    match = ["Set-Service ssh-agent -StartupType Automatic"],
)
'@
Add-CodexPrefixRuleIfMissing '["New-Service"]' @'
prefix_rule(
    pattern = ["New-Service"],
    decision = "prompt",
    justification = "Prompt before creating Windows services",
    match = ["New-Service example C:\\example.exe"],
)
'@
Add-CodexPrefixRuleIfMissing '["Remove-Service"]' @'
prefix_rule(
    pattern = ["Remove-Service"],
    decision = "prompt",
    justification = "Prompt before removing Windows services",
    match = ["Remove-Service example"],
)
'@
Add-CodexPrefixRuleIfMissing '["Enable-WindowsOptionalFeature"]' @'
prefix_rule(
    pattern = ["Enable-WindowsOptionalFeature"],
    decision = "prompt",
    justification = "Prompt before enabling Windows optional features",
    match = ["Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux"],
)
'@
Add-CodexPrefixRuleIfMissing '["Disable-WindowsOptionalFeature"]' @'
prefix_rule(
    pattern = ["Disable-WindowsOptionalFeature"],
    decision = "prompt",
    justification = "Prompt before disabling Windows optional features",
    match = ["Disable-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux"],
)
'@
Add-CodexPrefixRuleIfMissing '["dism"]' @'
prefix_rule(
    pattern = ["dism"],
    decision = "prompt",
    justification = "Prompt before changing Windows features or images with DISM",
    match = ["dism /online /get-features"],
)
'@
Add-CodexPrefixRuleIfMissing '["bcdedit"]' @'
prefix_rule(
    pattern = ["bcdedit"],
    decision = "prompt",
    justification = "Prompt before changing Windows boot configuration",
    match = ["bcdedit /enum"],
)
'@

Add-CodexPrefixRuleIfMissing '["probe-rs"]' @'
prefix_rule(
    pattern = ["probe-rs"],
    decision = "allow",
    justification = "Allow probe-rs hardware workflows outside sandbox",
)
'@
Add-CodexPrefixRuleIfMissing '["openocd"]' @'
prefix_rule(
    pattern = ["openocd"],
    decision = "allow",
    justification = "Allow OpenOCD hardware workflows outside sandbox",
)
'@
Add-CodexPrefixRuleIfMissing '["dfu-util"]' @'
prefix_rule(
    pattern = ["dfu-util"],
    decision = "allow",
    justification = "Allow DFU hardware workflows outside sandbox",
)
'@
Add-CodexPrefixRuleIfMissing '["picocom"]' @'
prefix_rule(
    pattern = ["picocom"],
    decision = "allow",
    justification = "Allow serial console hardware workflows outside sandbox",
)
'@
Add-CodexPrefixRuleIfMissing '["stty"]' @'
prefix_rule(
    pattern = ["stty"],
    decision = "allow",
    justification = "Allow serial TTY configuration outside sandbox",
)
'@
Add-CodexPrefixRuleIfMissing '["st-flash"]' @'
prefix_rule(
    pattern = ["st-flash"],
    decision = "allow",
    justification = "Allow ST-Link flashing workflows outside sandbox",
)
'@
Add-CodexPrefixRuleIfMissing '["st-info"]' @'
prefix_rule(
    pattern = ["st-info"],
    decision = "allow",
    justification = "Allow ST-Link probe inspection outside sandbox",
)
'@
Add-CodexPrefixRuleIfMissing '["st-util"]' @'
prefix_rule(
    pattern = ["st-util"],
    decision = "allow",
    justification = "Allow ST-Link debug server workflows outside sandbox",
)
'@
Set-CodexPermissionsExample

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

Set-CodexMcpSetting 'context7' 'startup_timeout_sec' '30'
Set-CodexMcpSetting 'openaiDeveloperDocs' 'startup_timeout_sec' '30'
Set-CodexMcpSetting 'fetch' 'default_tools_approval_mode' "`"$CodexFetchMcpApprovalMode`""
Set-CodexMcpSetting 'github' 'default_tools_approval_mode' "`"$CodexGithubMcpApprovalMode`""
Set-CodexMcpSetting 'serena' 'default_tools_approval_mode' "`"$CodexSerenaMcpApprovalMode`""

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
            if ($LASTEXITCODE -eq 0) {
                Write-Ok "Skill $skill installed"
            } else {
                Write-Warn "Curated skill not installed: $skill"
            }
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

if ($CodexTimesFmSkillEnabled) {
    Sync-CodexRepoPathSkill `
        -Namespace 'timesfm' `
        -Repo $CodexTimesFmSkillRepo `
        -SourceDirName 'timesfm' `
        -SkillPath $CodexTimesFmSkillPath `
        -SkillName 'timesfm-forecasting'
}
