Write-Step "Setting up Codex CLI..."

function Get-CodexConfigContent {
    if (Test-Path $script:ConfigToml) {
        return Get-Content $script:ConfigToml -Raw
    }
    return ''
}

function ConvertTo-CodexTomlBoolean {
    param([Parameter(Mandatory)][object]$Value)

    if ($Value -is [System.Management.Automation.SwitchParameter]) {
        return $Value.IsPresent.ToString().ToLowerInvariant()
    }
    if ($Value -is [bool]) {
        return $Value.ToString().ToLowerInvariant()
    }
    if ($Value -is [int]) {
        if ($Value -eq 1) { return 'true' }
        if ($Value -eq 0) { return 'false' }
    }

    $text = $Value.ToString().Trim().ToLowerInvariant()
    if ($text -in @('true', '1')) { return 'true' }
    if ($text -in @('false', '0')) { return 'false' }

    throw "Cannot convert '$Value' to a TOML Boolean. Use true/false or 1/0."
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

function Remove-CodexMcpIfConfigured {
    param([Parameter(Mandatory)][string]$Name)
    if (-not (Test-CodexMcpConfigured $Name)) {
        Write-Skip "MCP $Name already absent"
        return
    }

    Remove-CodexMcp $Name
    Write-Ok "Removed disabled optional MCP: $Name"
}

function Remove-CodexIncompatibleFetchMcp {
    if (-not (Test-CodexMcpConfigured 'fetch')) {
        return
    }

    $lines = @(Get-Content -LiteralPath $script:ConfigToml)
    $fetchBlock = New-Object System.Collections.Generic.List[string]
    $inSection = $false
    foreach ($line in $lines) {
        if ($line -match '^\s*\[mcp_servers\.fetch\]\s*(?:#.*)?$') {
            $inSection = $true
        } elseif ($inSection -and $line -match '^\s*\[') {
            break
        }
        if ($inSection) {
            $fetchBlock.Add($line)
        }
    }

    $fetchText = $fetchBlock -join "`n"
    if ($fetchText.Contains('mcp-server-fetch') -and -not $fetchText.Contains('mcp<2')) {
        Remove-CodexMcp 'fetch'
        Write-Ok 'Removed incompatible fetch MCP dependency resolution'
    }
}

function Test-CodexConfigContent {
    param([Parameter(Mandatory)][string]$Content)

    $validationFile = Join-Path ([IO.Path]::GetTempPath()) ("codex-config-" + [guid]::NewGuid().ToString('N') + '.toml')
    try {
        Set-Content -LiteralPath $validationFile -Value $Content -NoNewline -Encoding utf8
        python -c 'import pathlib, sys, tomllib; tomllib.loads(pathlib.Path(sys.argv[1]).read_text(encoding="utf-8-sig"))' $validationFile
        return $LASTEXITCODE -eq 0
    } finally {
        Remove-Item -LiteralPath $validationFile -Force -ErrorAction SilentlyContinue
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

    $next = ($result -join [Environment]::NewLine) + [Environment]::NewLine
    if (-not (Test-CodexConfigContent $next)) {
        throw "Refusing invalid Codex config update for mcp_servers.$Name.$Key"
    }

    Set-Content -LiteralPath $script:ConfigToml -Value $next -NoNewline -Encoding utf8
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

    if (-not (Test-CodexConfigContent $next)) {
        throw "Refusing invalid Codex config update for $Key"
    }

    Set-Content -LiteralPath $script:ConfigToml -Value $next -NoNewline -Encoding utf8
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

    if (-not (Test-CodexConfigContent $next)) {
        throw "Refusing invalid Codex config update for $Table.$Key"
    }

    Set-Content -LiteralPath $script:ConfigToml -Value $next -NoNewline -Encoding utf8
    Write-Ok "Codex $Table.$Key = $Value"
}

function Remove-CodexLegacyAgentsTable {
    if (-not (Test-Path $script:ConfigToml)) {
        return
    }

    $source = Get-Content -LiteralPath $script:ConfigToml -Raw
    $updated = [regex]::Replace(
        $source,
        '(?m)^\[agents\]\r?\n(?=(?:(?!^\[).*(?:\r?\n|$))*(?:max_threads|max_depth|job_max_runtime_seconds|interrupt_message)\s*=)(?:(?!^\[).*(?:\r?\n|$))*',
        ''
    )

    if ($updated -eq $source) {
        Write-Skip 'Legacy Codex agents table absent'
        return
    }

    Set-Content -LiteralPath $script:ConfigToml -Value $updated -NoNewline -Encoding utf8
    Write-Ok 'Removed legacy Codex agents table'
}

function Remove-CodexMisplacedTopLevelSettings {
    if (-not (Test-Path $script:ConfigToml)) {
        return
    }

    $result = New-Object System.Collections.Generic.List[string]
    $section = ''
    $changed = $false

    foreach ($line in @(Get-Content -LiteralPath $script:ConfigToml)) {
        if ($line -match '^\s*\[') {
            $section = $line.Trim()
        }

        if ($section -match '^\[(notice\.model_migrations|tui|tui\.model_availability_nux)\]$' -and
            $line -match '^(model|model_reasoning_effort|service_tier|sandbox_mode|approval_policy|approvals_reviewer|check_for_update_on_startup|startup_timeout_sec)\s*=') {
            $changed = $true
            continue
        }

        $result.Add($line)
    }

    if (-not $changed) {
        Write-Skip 'Misplaced Codex top-level settings absent'
        return
    }

    Set-Content -LiteralPath $script:ConfigToml -Value $result -Encoding utf8
    Write-Ok 'Removed misplaced Codex top-level settings'
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
    $escapedPattern = [regex]::Escape($Pattern)
    if ($source -and [regex]::IsMatch($source, "pattern\s*=\s*$escapedPattern")) {
        Write-Skip "Codex rule already present: $Pattern"
        return
    }

    if (-not [string]::IsNullOrWhiteSpace($source)) {
        Add-Content -LiteralPath $script:CodexDefaultRules -Value ''
    }
    Add-Content -LiteralPath $script:CodexDefaultRules -Value $Rule
    Write-Ok "Codex rule added: $Pattern"
}

function Initialize-CodexDefaultRules {
    $script:CodexRulesDestination = $script:CodexDefaultRules
    $rulesDir = Split-Path -Parent $script:CodexRulesDestination
    if (Test-Path -LiteralPath $script:CodexRulesDestination) {
        $backupDir = Join-Path $rulesDir 'backups'
        New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
        $backupPath = Join-Path $backupDir ("default.rules.{0}.bak" -f [guid]::NewGuid())
        Copy-Item -LiteralPath $script:CodexRulesDestination -Destination $backupPath
        Write-Ok "Backed up previous Codex default rules to $backupPath"
    }
    $script:CodexDefaultRules = Join-Path $rulesDir (".default.rules.{0}.tmp" -f [guid]::NewGuid())
    Set-Content -LiteralPath $script:CodexDefaultRules -Value '# Managed by firstboot. Rebuilt from the current rules on every run.' -Encoding utf8
}

function Complete-CodexDefaultRules {
    & codex execpolicy check --rules $script:CodexDefaultRules -- git status | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Remove-Item -LiteralPath $script:CodexDefaultRules -Force
        $script:CodexDefaultRules = $script:CodexRulesDestination
        throw 'Generated Codex rules are invalid; original file preserved'
    }
    Move-Item -LiteralPath $script:CodexDefaultRules -Destination $script:CodexRulesDestination -Force
    $script:CodexDefaultRules = $script:CodexRulesDestination
}

function Remove-CodexPrefixRulesByPattern {
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
        "(?ms)(?:^|\r?\n)prefix_rule\((?:(?!^\s*prefix_rule\().)*?pattern\s*=\s*$escapedPattern(?:(?!^\s*prefix_rule\().)*?\)\s*"
    )
    $updated = $ruleRegex.Replace($source, [Environment]::NewLine)
    $updated = [regex]::Replace($updated, "(\r?\n){3,}", [Environment]::NewLine + [Environment]::NewLine).Trim() + [Environment]::NewLine

    if ($updated -eq $source) {
        if (-not $Quiet) {
            Write-Skip "Codex rule absent: $Pattern"
        }
        return
    }

    Set-Content -LiteralPath $script:CodexDefaultRules -Value $updated -NoNewline -Encoding utf8
    Write-Ok "Removed Codex rule: $Pattern"
}

function Set-CodexPrefixRule {
    param(
        [Parameter(Mandatory)][string]$Pattern,
        [Parameter(Mandatory)][string]$Rule
    )

    $source = if (Test-Path $script:CodexDefaultRules) {
        Get-Content -LiteralPath $script:CodexDefaultRules -Raw
    } else {
        ''
    }
    $normalizedSource = $source -replace "`r`n", "`n"
    $normalizedRule = $Rule.Trim() -replace "`r`n", "`n"
    $escapedPattern = [regex]::Escape($Pattern)
    $matchingCount = [regex]::Matches($source, "pattern\s*=\s*$escapedPattern\s*,").Count
    if ($matchingCount -eq 1 -and $normalizedSource.Contains($normalizedRule)) {
        Write-Skip "Codex rule already current: $Pattern"
        return
    }

    Remove-CodexPrefixRulesByPattern -Pattern $Pattern -Quiet
    Add-CodexPrefixRuleIfMissing -Pattern $Pattern -Rule $Rule
}

function Add-CodexGitAllowRule {
    param(
        [Parameter(Mandatory)][string]$Pattern,
        [Parameter(Mandatory)][string]$Justification,
        [Parameter(Mandatory)][string]$Example
    )

    Set-CodexPrefixRule $Pattern @"
prefix_rule(
    pattern = $Pattern,
    decision = "allow",
    justification = "$Justification",
    match = ["$Example"],
)
"@
}

function Set-CodexAllowRule {
    param(
        [Parameter(Mandatory)][string]$Pattern,
        [Parameter(Mandatory)][string]$Justification,
        [string]$Example = ''
    )

    $matchLine = ''
    if (-not [string]::IsNullOrWhiteSpace($Example)) {
        $matchLine = "    match = [`"$Example`"],`n"
    }

    Set-CodexPrefixRule $Pattern @"
prefix_rule(
    pattern = $Pattern,
    decision = "allow",
    justification = "$Justification",
$matchLine)
"@
}

function Set-CodexPermissionsExample {
    $content = @'
# Example only. Copy selected settings to ~/.codex/config.toml when needed.
model = "gpt-5.6-terra"
model_reasoning_effort = "medium"
model_verbosity = "low"
service_tier = "default"
sandbox_mode = "workspace-write"
approval_policy = "on-request"
approvals_reviewer = "user"
check_for_update_on_startup = true

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

function Set-CodexManagedFile {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Content,
        [Parameter(Mandatory)][string]$Description
    )

    $directory = Split-Path -Parent $Path
    if (-not (Test-Path $directory)) {
        New-Item -ItemType Directory -Path $directory -Force | Out-Null
    }

    if ((Test-Path $Path) -and (Get-Content -LiteralPath $Path -Raw) -eq $Content) {
        Write-Skip "$Description already current"
        return
    }

    Set-Content -LiteralPath $Path -Value $Content -NoNewline -Encoding utf8
    Write-Ok "$Description updated"
}

function Remove-CodexManagedFileIfPresent {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Description
    )

    if (-not (Test-Path $Path)) {
        Write-Skip "$Description already absent"
        return
    }

    Remove-Item -LiteralPath $Path -Force
    Write-Ok "$Description removed"
}

function Normalize-CodexText {
    param([string]$Text)
    return (($Text -replace "`r`n", "`n").TrimEnd())
}

function Test-CodexDirectoryCurrent {
    param(
        [Parameter(Mandatory)][string]$Source,
        [Parameter(Mandatory)][string]$Target
    )

    if (-not (Test-Path -LiteralPath $Target)) {
        return $false
    }

    $sourceRoot = (Resolve-Path -LiteralPath $Source).Path
    $targetRoot = (Resolve-Path -LiteralPath $Target).Path
    $sourceFiles = @(Get-ChildItem -LiteralPath $sourceRoot -Recurse -File)
    $targetFiles = @(Get-ChildItem -LiteralPath $targetRoot -Recurse -File)

    if ($sourceFiles.Count -ne $targetFiles.Count) {
        return $false
    }

    foreach ($sourceFile in $sourceFiles) {
        $relativePath = [System.IO.Path]::GetRelativePath($sourceRoot, $sourceFile.FullName)
        $targetFile = Join-Path $targetRoot $relativePath

        if (-not (Test-Path -LiteralPath $targetFile)) {
            return $false
        }

        $sourceHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $sourceFile.FullName).Hash
        $targetHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $targetFile).Hash
        if ($sourceHash -ne $targetHash) {
            return $false
        }
    }

    return $true
}

function Set-CodexProfileFiles {
    if (-not $CodexProfilesEnabled) {
        Remove-CodexManagedFileIfPresent -Path (Join-Path $codexDir 'lean.config.toml') -Description 'Codex lean profile'
        Remove-CodexManagedFileIfPresent -Path (Join-Path $codexDir 'deep.config.toml') -Description 'Codex deep profile'
        return
    }

    $leanProfile = @"
# Managed by firstboot. Use with: codex --profile lean
model = "$CodexLeanProfileModel"
model_reasoning_effort = "$CodexLeanProfileReasoningEffort"
model_verbosity = "$CodexLeanProfileVerbosity"
service_tier = "$CodexServiceTier"
sandbox_mode = "$CodexSandboxMode"
approval_policy = "$CodexApprovalPolicy"
approvals_reviewer = "$CodexApprovalsReviewer"
web_search = "cached"
"@

    $profileMcpServers = ConvertTo-NameList $CodexMcpAllowlist
    $deepMcpOverrides = @((ConvertTo-NameList $CodexMcpDefaultDisabledServers) | Where-Object {
        $_ -in $profileMcpServers -and ($_ -ne 'fetch' -or (Test-CommandExists uvx))
    } | ForEach-Object {
        "[mcp_servers.$_]`nenabled = true"
    }) -join "`n`n"

    $deepProfile = @"
# Managed by firstboot. Use with: codex --profile deep
model = "$CodexDeepProfileModel"
model_reasoning_effort = "$CodexDeepProfileReasoningEffort"
model_verbosity = "$CodexDeepProfileVerbosity"
service_tier = "$CodexServiceTier"
sandbox_mode = "$CodexSandboxMode"
approval_policy = "$CodexApprovalPolicy"
approvals_reviewer = "$CodexApprovalsReviewer"

[apps._default]
default_tools_approval_mode = "$CodexAppsDefaultToolsApprovalMode"
destructive_enabled = false
open_world_enabled = false
approvals_reviewer = "$CodexApprovalsReviewer"

$deepMcpOverrides
"@

    Set-CodexManagedFile -Path (Join-Path $codexDir 'lean.config.toml') -Content $leanProfile -Description 'Codex lean profile'
    Set-CodexManagedFile -Path (Join-Path $codexDir 'deep.config.toml') -Content $deepProfile -Description 'Codex deep profile'
}

function New-CodexCustomAgentContent {
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string]$Description,
        [Parameter(Mandatory)][string]$Model,
        [Parameter(Mandatory)][string]$ReasoningEffort,
        [Parameter(Mandatory)][string]$SandboxMode,
        [Parameter(Mandatory)][string]$Instructions,
        [Parameter(Mandatory)][string]$Nicknames
    )

    @"
# Managed by firstboot.
name = "$Name"
description = "$Description"
model = "$Model"
model_reasoning_effort = "$ReasoningEffort"
sandbox_mode = "$SandboxMode"
nickname_candidates = [$Nicknames]

developer_instructions = '''
$Instructions
'''
"@
}

function Set-CodexCustomAgentFiles {
    $managedAgents = @('explorer-terra', 'reviewer-deep', 'docs-researcher', 'tester-terra', 'architect-deep', 'knowledge-curator', 'improvement-researcher')
    $selectedAgents = if ($CodexCustomAgentsEnabled) { ConvertTo-NameList $CodexCustomAgents } else { @() }

    foreach ($agent in $managedAgents) {
        if ($agent -notin $selectedAgents) {
            Remove-CodexManagedFileIfPresent -Path (Join-Path $script:CodexAgentsDir "$agent.toml") -Description "Codex custom agent $agent"
        }
    }

    if (-not $CodexCustomAgentsEnabled) {
        return
    }

    foreach ($agent in $selectedAgents) {
        $content = $null
        switch ($agent) {
            'explorer-terra' {
                $content = New-CodexCustomAgentContent `
                    -Name 'explorer-terra' `
                    -Description 'Fast read-only repository exploration and large-file evidence gathering.' `
                    -Model $CodexLeanProfileModel `
                    -ReasoningEffort $CodexLeanProfileReasoningEffort `
                    -SandboxMode 'read-only' `
                    -Nicknames '"Scout", "Mapper", "Triage"' `
                    -Instructions @'
You are a read-only exploration agent. Inspect files, logs, docs, and command output. Do not edit files. Return only decision-relevant findings with file paths, commands used, and uncertainty where evidence is incomplete.
'@
                break
            }
            'reviewer-deep' {
                $content = New-CodexCustomAgentContent `
                    -Name 'reviewer-deep' `
                    -Description 'High-reasoning code review focused on bugs, regressions, security risks, and test gaps.' `
                    -Model $CodexDeepProfileModel `
                    -ReasoningEffort $CodexDeepProfileReasoningEffort `
                    -SandboxMode 'read-only' `
                    -Nicknames '"Reviewer", "Auditor", "Skeptic"' `
                    -Instructions @'
You are a read-only review agent. Prioritize concrete bugs, behavioral regressions, security risks, and missing tests. Cite exact files and lines when possible. Avoid style-only findings unless they block maintainability or correctness.
'@
                break
            }
            'docs-researcher' {
                $content = New-CodexCustomAgentContent `
                    -Name 'docs-researcher' `
                    -Description 'Targeted documentation research for current APIs, SDKs, frameworks, and platform behavior.' `
                    -Model $CodexLeanProfileModel `
                    -ReasoningEffort $CodexLeanProfileReasoningEffort `
                    -SandboxMode 'read-only' `
                    -Nicknames '"Researcher", "Librarian", "Verifier"' `
                    -Instructions @'
You are a documentation research agent. Prefer official docs and configured documentation MCP servers. Return concise guidance with source links, version assumptions, and any gaps that need verification before implementation.
'@
                break
            }
            'tester-terra' {
                $content = New-CodexCustomAgentContent `
                    -Name 'tester-terra' `
                    -Description 'Fast build, lint, typecheck, and test runner that reports focused failures without editing source.' `
                    -Model $CodexLeanProfileModel `
                    -ReasoningEffort $CodexLeanProfileReasoningEffort `
                    -SandboxMode 'workspace-write' `
                    -Nicknames '"Runner", "Verifier", "Harness"' `
                    -Instructions @'
You are a verification agent. Run focused build, lint, typecheck, and test commands requested by the parent thread. You may create normal build/test artifacts in the workspace, but do not edit source files. Return commands, exit codes, concise failure summaries, and likely next investigation targets.
'@
                break
            }
            'architect-deep' {
                $content = New-CodexCustomAgentContent `
                    -Name 'architect-deep' `
                    -Description 'High-reasoning architecture and migration analyst for ambiguous cross-module design decisions.' `
                    -Model $CodexDeepProfileModel `
                    -ReasoningEffort $CodexDeepProfileReasoningEffort `
                    -SandboxMode 'read-only' `
                    -Nicknames '"Architect", "Planner", "Strategist"' `
                    -Instructions @'
You are a read-only architecture agent. Analyze constraints, coupling, data flow, rollout risk, and tradeoffs. Do not edit files. Return a concise recommendation, alternatives rejected, and concrete files or interfaces that constrain the design.
'@
                break
            }
            'knowledge-curator' {
                $content = New-CodexCustomAgentContent `
                    -Name 'knowledge-curator' `
                    -Description 'Read-only project knowledge curator that proposes durable skills or documentation after non-trivial work.' `
                    -Model $CodexLeanProfileModel `
                    -ReasoningEffort $CodexLeanProfileReasoningEffort `
                    -SandboxMode 'read-only' `
                    -Nicknames '"Curator", "Archivist", "Analyst"' `
                    -Instructions @'
You are a read-only knowledge-curation agent. Inspect recent diffs, command results, failure modes, and successful fixes. Do not edit files or create skills. Return only reusable, evidence-backed knowledge-capture candidates using this format:
Candidate: short title
Evidence: files, commands, errors, or artifacts that prove this was useful
Reuse Trigger: when future Codex sessions should remember this
Recommended Target: skill, AGENTS.md, README, or no action
Draft Guidance: 3-6 lines of reusable instruction
'@
                break
            }
            'improvement-researcher' {
                $content = New-CodexCustomAgentContent `
                    -Name 'improvement-researcher' `
                    -Description 'Read-only external improvement researcher for tooling, process, skills, MCP, and agent workflow updates.' `
                    -Model $CodexLeanProfileModel `
                    -ReasoningEffort $CodexLeanProfileReasoningEffort `
                    -SandboxMode 'read-only' `
                    -Nicknames '"Researcher", "Scout", "Optimizer"' `
                    -Instructions @'
You are a read-only improvement research agent. Search current external information when requested: official docs, primary repositories, release notes, and credible technical posts when primary sources are insufficient. Do not edit files, install tools, change configuration, or create skills. Return ranked, evidence-backed improvement proposals using this format:
Finding: short title
Source: link or exact source name
Why It Matters: concrete benefit
Fit For This Repo: how it maps to current firstboot scripts, skills, agents, or docs
Risk Or Cost: security, maintenance, runtime, token, or compatibility concern
Suggested Next Step: adopt, test, document, defer, or reject
'@
                break
            }
            default {
                Write-Warn "Unknown Codex custom agent requested: $agent"
            }
        }

        if ($content) {
            Set-CodexManagedFile -Path (Join-Path $script:CodexAgentsDir "$agent.toml") -Content $content -Description "Codex custom agent $agent"
        }
    }
}

function Set-CodexAgentTeamworkSkill {
    $sourceSkill = Join-Path $script:RepoRoot 'codex\skills\codex-agent-teamwork'
    $targetSkill = Join-Path $script:CodexSkillsDir 'codex-agent-teamwork'

    if (-not $CodexAgentTeamworkSkillEnabled) {
        if (Test-Path $targetSkill) {
            Remove-Item -LiteralPath $targetSkill -Recurse -Force
            Write-Ok "Codex agent teamwork skill removed"
        } else {
            Write-Skip "Codex agent teamwork skill already absent"
        }
        return
    }

    if (-not (Test-Path (Join-Path $sourceSkill 'SKILL.md'))) {
        Write-Warn "Codex agent teamwork skill source not found: $sourceSkill"
        return
    }

    if (Test-CodexDirectoryCurrent -Source $sourceSkill -Target $targetSkill) {
        Write-Skip "Codex agent teamwork skill already current"
        return
    }

    if (Test-Path $targetSkill) {
        Remove-Item -LiteralPath $targetSkill -Recurse -Force
    }
    New-Item -ItemType Directory -Path $script:CodexSkillsDir -Force | Out-Null
    Copy-Item -LiteralPath $sourceSkill -Destination $script:CodexSkillsDir -Recurse -Force
    Write-Ok "Codex agent teamwork skill installed"
}

function Set-CodexGlobalAgentsGuidance {
    $path = Join-Path $codexDir 'AGENTS.md'
    $begin = '<!-- BEGIN FIRSTBOOT CODEX AGENT TEAMWORK -->'
    $end = '<!-- END FIRSTBOOT CODEX AGENT TEAMWORK -->'
    $block = @'
## Firstboot Agent Teamwork

Use $codex-agent-teamwork for non-trivial development, debugging, review, architecture, docs research, and multi-file changes.
Do not spawn subagents for simple one-file edits, direct questions, or mechanical fixes.
Prefer explorer-terra, docs-researcher, and tester-terra for read-heavy or verification work.
Use reviewer-deep and architect-deep only when high reasoning materially improves correctness.
Use knowledge-curator only near the end of non-trivial work when a reusable workflow, command, or debugging path may be worth saving.
Use improvement-researcher only when the task explicitly asks for external improvement research, tooling/process updates, useful skills, MCP servers, or agent workflow tuning.
Start with at most one subagent. Add a second only for independent verification or research, and a third only for high-risk work with a separate domain. Keep max_depth = 1 and wait for all subagents before integrating results.

## Scope and completion

Routine authorized development includes git add and ordinary commit, SSH diagnostics and file transfer, editing tracked files, compiling, installing utilities, and running debuggers/analysis tools. Use the configured allow rules without repeated confirmation; prefer workdir over git -C and direct tool commands over opaque shell wrappers.
Review the complete action before execution: deletion, rebase/reset/clean, commit --amend anywhere in the arguments, forced push, rsync --delete, remote destructive SSH commands, disk formatting, and removal of system services or features need explicit scope/authorization. Prefix rules cannot inspect remote shell strings, later flags, hooks, debugger commands, or build scripts; do not use those forms to bypass review. WSL command execution is authorized; creation/import or deletion of distributions and virtual machines requires explicit authorization. Inspect the full WSL argument list because prefix rules do not cover every reordered option. SSH/WSL/PowerShell tools are trusted execution paths, not guarantees that all their operations are safe. Keep credentials out of rules and command lines.

For answer, review, diagnose, or plan requests, inspect only the minimum relevant files, logs, and docs; report evidence and do not edit unless asked.
For change, build, or fix requests, make only the requested in-scope local change and run the smallest relevant non-destructive validation.
Do not add features, dependencies, refactors, configuration changes, documentation, or tests outside the acceptance criteria. Ask only when a concrete action exceeds the existing authorization, changes the target or side effects, is destructive outside the agreed scope, or incurs unapproved cost. Stop when the acceptance criteria and required validation pass.
'@
    $managedBlock = "$begin`n$block`n$end"
    $source = if (Test-Path $path) { Get-Content -LiteralPath $path -Raw } else { '' }
    $pattern = "(?ms)(?:^|\r?\n)$([regex]::Escape($begin))\r?\n.*?\r?\n$([regex]::Escape($end))(?:\r?\n|$)"

    if (-not $CodexGlobalAgentsGuidanceEnabled) {
        if ([regex]::IsMatch($source, $pattern)) {
            $updated = [regex]::Replace($source, $pattern, [Environment]::NewLine).Trim() + [Environment]::NewLine
            Set-Content -LiteralPath $path -Value $updated -NoNewline -Encoding utf8
            Write-Ok "Codex global AGENTS.md teamwork guidance removed"
        } else {
            Write-Skip "Codex global AGENTS.md teamwork guidance already absent"
        }
        return
    }

    $updatedContent = if ([regex]::IsMatch($source, $pattern)) {
        [regex]::Replace($source, $pattern, [Environment]::NewLine + $managedBlock + [Environment]::NewLine)
    } elseif ([string]::IsNullOrWhiteSpace($source)) {
        "# Global Codex Guidance`n`n$managedBlock`n"
    } else {
        $source.TrimEnd() + [Environment]::NewLine + [Environment]::NewLine + $managedBlock + [Environment]::NewLine
    }

    if ((Normalize-CodexText $source) -eq (Normalize-CodexText $updatedContent)) {
        Write-Skip "Codex global AGENTS.md teamwork guidance already current"
        return
    }

    Set-Content -LiteralPath $path -Value $updatedContent -NoNewline -Encoding utf8
    Write-Ok "Codex global AGENTS.md teamwork guidance updated"
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
$script:RepoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$codexDir = Join-Path $env:USERPROFILE '.codex'
$script:ConfigToml = Join-Path $codexDir 'config.toml'
if (-not (Test-Path $codexDir)) {
    New-Item -ItemType Directory -Path $codexDir -Force | Out-Null
}
$codexRulesDir = Join-Path $codexDir 'rules'
$script:CodexDefaultRules = Join-Path $codexRulesDir 'default.rules'
$script:CodexPermissionsExample = Join-Path $codexDir 'config.permissions.example.toml'
$script:CodexAgentsDir = Join-Path $codexDir 'agents'
$script:CodexSkillsDir = Join-Path $codexDir 'skills'
if (-not (Test-Path $codexRulesDir)) {
    New-Item -ItemType Directory -Path $codexRulesDir -Force | Out-Null
}
Initialize-CodexDefaultRules
if (-not (Test-Path $script:CodexAgentsDir)) {
    New-Item -ItemType Directory -Path $script:CodexAgentsDir -Force | Out-Null
}
if (-not (Test-Path $script:CodexSkillsDir)) {
    New-Item -ItemType Directory -Path $script:CodexSkillsDir -Force | Out-Null
}

Set-CodexTopLevelSetting 'sandbox_mode' "`"$CodexSandboxMode`""
Set-CodexTopLevelSetting 'approval_policy' "`"$CodexApprovalPolicy`""
$codexCheckForUpdateOnStartupToml = ConvertTo-CodexTomlBoolean $CodexCheckForUpdateOnStartup
$codexWindowsSandboxPrivateDesktopToml = ConvertTo-CodexTomlBoolean $CodexWindowsSandboxPrivateDesktop
$codexAppsDestructiveEnabledToml = ConvertTo-CodexTomlBoolean $CodexAppsDestructiveEnabled
$codexAppsOpenWorldEnabledToml = ConvertTo-CodexTomlBoolean $CodexAppsOpenWorldEnabled
Set-CodexTopLevelSetting 'model' "`"$CodexModel`""
Set-CodexTopLevelSetting 'model_reasoning_effort' "`"$CodexModelReasoningEffort`""
Set-CodexTopLevelSetting 'model_verbosity' "`"$CodexModelVerbosity`""
Set-CodexTopLevelSetting 'service_tier' "`"$CodexServiceTier`""
Set-CodexTopLevelSetting 'approvals_reviewer' "`"$CodexApprovalsReviewer`""
Set-CodexTopLevelSetting 'check_for_update_on_startup' $codexCheckForUpdateOnStartupToml
Remove-CodexLegacyAgentsTable
Remove-CodexMisplacedTopLevelSettings
Set-CodexTableSetting 'apps._default' 'default_tools_approval_mode' "`"$CodexAppsDefaultToolsApprovalMode`""
Set-CodexTableSetting 'apps._default' 'destructive_enabled' $codexAppsDestructiveEnabledToml
Set-CodexTableSetting 'apps._default' 'open_world_enabled' $codexAppsOpenWorldEnabledToml
Set-CodexTableSetting 'apps._default' 'approvals_reviewer' "`"$CodexApprovalsReviewer`""
Set-CodexTableSetting 'windows' 'sandbox' "`"$CodexWindowsSandbox`""
Set-CodexTableSetting 'windows' 'sandbox_private_desktop' $codexWindowsSandboxPrivateDesktopToml

codex mcp list 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) {
    throw 'Generated Codex config failed runtime validation; refusing to continue'
}


Add-CodexGitAllowRule '["git", "status"]' `
    'Allow read-only Git status checks without repeated prompts' `
    'git status --short'
Add-CodexGitAllowRule '["git", "ls-files"]' `
    'Allow read-only Git index listing without repeated prompts' `
    'git ls-files'
Add-CodexGitAllowRule '["git", "ls-tree"]' `
    'Allow read-only Git tree inspection without repeated prompts' `
    'git ls-tree -r HEAD'
Add-CodexGitAllowRule '["git", "rev-parse"]' `
    'Allow read-only Git revision parsing without repeated prompts' `
    'git rev-parse --show-toplevel'
Add-CodexGitAllowRule '["git", "merge-base"]' `
    'Allow read-only Git merge-base calculations without repeated prompts' `
    'git merge-base HEAD main'
Add-CodexGitAllowRule '["git", "remote", "get-url"]' `
    'Allow read-only Git remote URL lookup without repeated prompts' `
    'git remote get-url origin'
Add-CodexGitAllowRule '["git", "branch", "--list"]' `
    'Allow read-only Git branch listing without repeated prompts' `
    'git branch --list'
Add-CodexGitAllowRule '["git", "branch", "--show-current"]' `
    'Allow read-only current branch lookup without repeated prompts' `
    'git branch --show-current'
Add-CodexGitAllowRule '["git", "tag", "--list"]' `
    'Allow read-only Git tag listing without repeated prompts' `
    'git tag --list'
Add-CodexGitAllowRule '["git", "describe"]' `
    'Allow read-only Git describe lookups without repeated prompts' `
    'git describe --tags --always'
Add-CodexGitAllowRule '["git", "add"]' `
    'Allow staging workspace changes without deleting files or rewriting history' `
    'git add README.md'
Add-CodexGitAllowRule '["git", "diff"]' `
    'Allow Git diff inspection without repeated prompts' `
    'git diff -- README.md'
Add-CodexGitAllowRule '["git", "log"]' `
    'Allow Git history inspection without repeated prompts' `
    'git log --oneline -5'
Add-CodexGitAllowRule '["git", "show"]' `
    'Allow Git object inspection without repeated prompts' `
    'git show --stat HEAD'
Add-CodexGitAllowRule '["git", "grep"]' `
    'Allow Git-backed source searches without repeated prompts' `
    'git grep TODO'
Add-CodexGitAllowRule '["git", "blame"]' `
    'Allow Git blame inspection without repeated prompts' `
    'git blame README.md'
Add-CodexGitAllowRule '["git", "config", "--get"]' `
    'Allow Git configuration reads without repeated prompts' `
    'git config --get user.email'
Add-CodexGitAllowRule '["git", "config", "--global", "--get"]' `
    'Allow global Git configuration reads without repeated prompts' `
    'git config --global --get user.email'
Add-CodexGitAllowRule '["git", "config", "--list"]' `
    'Allow Git configuration listing without repeated prompts' `
    'git config --list'
Add-CodexGitAllowRule '["git", "fetch"]' `
    'Allow fetching remote Git metadata without repeated prompts' `
    'git fetch --all --prune'
Add-CodexGitAllowRule '["git", "pull"]' `
    'Allow fast-forward Git pulls in trusted workspaces without repeated prompts' `
    'git pull --ff-only'
Add-CodexGitAllowRule '["git", "commit"]' `
    'Allow creating local Git commits without repeated prompts' `
    'git commit -m update'
Add-CodexGitAllowRule '["git", "push"]' `
    'Allow publishing explicitly prepared Git commits without repeated prompts' `
    'git push'
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
Add-CodexPrefixRuleIfMissing '["git", "reset"]' @'
prefix_rule(
    pattern = ["git", "reset"],
    decision = "prompt",
    justification = "Prompt before moving HEAD or discarding tracked workspace changes",
    match = ["git reset --hard HEAD"],
)
'@
Add-CodexPrefixRuleIfMissing '["git", "commit", "--amend"]' @'
prefix_rule(
    pattern = ["git", "commit", "--amend"],
    decision = "prompt",
    justification = "Prompt before amending commits and rewriting history",
    match = ["git commit --amend"],
)
'@
Add-CodexPrefixRuleIfMissing '["git", "branch", "-D"]' @'
prefix_rule(
    pattern = ["git", "branch", "-D"],
    decision = "prompt",
    justification = "Prompt before deleting branch refs",
    match = ["git branch -D old-branch"],
)
'@
Add-CodexPrefixRuleIfMissing '["git", "branch", "-d"]' @'
prefix_rule(
    pattern = ["git", "branch", "-d"],
    decision = "prompt",
    justification = "Prompt before deleting branch refs",
    match = ["git branch -d old-branch"],
)
'@
Add-CodexPrefixRuleIfMissing '["git", "tag", "-d"]' @'
prefix_rule(
    pattern = ["git", "tag", "-d"],
    decision = "prompt",
    justification = "Prompt before deleting tag refs",
    match = ["git tag -d v1.0.0"],
)
'@
Add-CodexPrefixRuleIfMissing '["git", "checkout", "-f"]' @'
prefix_rule(
    pattern = ["git", "checkout", "-f"],
    decision = "prompt",
    justification = "Prompt before forced checkout discards local edits",
    match = ["git checkout -f main"],
)
'@
Add-CodexPrefixRuleIfMissing '["git", "switch", "-C"]' @'
prefix_rule(
    pattern = ["git", "switch", "-C"],
    decision = "prompt",
    justification = "Prompt before resetting an existing branch with switch -C",
    match = ["git switch -C topic HEAD~1"],
)
'@
Add-CodexPrefixRuleIfMissing '["git", "switch", "--discard-changes"]' @'
prefix_rule(
    pattern = ["git", "switch", "--discard-changes"],
    decision = "prompt",
    justification = "Prompt before switching branches and discarding local edits",
    match = ["git switch --discard-changes main"],
)
'@
Add-CodexPrefixRuleIfMissing '["git", "rm"]' @'
prefix_rule(
    pattern = ["git", "rm"],
    decision = "prompt",
    justification = "Prompt before removing tracked files",
    match = ["git rm old.txt"],
)
'@
Add-CodexPrefixRuleIfMissing '["git", "stash", "drop"]' @'
prefix_rule(
    pattern = ["git", "stash", "drop"],
    decision = "prompt",
    justification = "Prompt before deleting stashed changes",
    match = ["git stash drop stash@{0}"],
)
'@
Add-CodexPrefixRuleIfMissing '["git", "stash", "clear"]' @'
prefix_rule(
    pattern = ["git", "stash", "clear"],
    decision = "prompt",
    justification = "Prompt before deleting all stashed changes",
    match = ["git stash clear"],
)
'@
Add-CodexPrefixRuleIfMissing '["git", "reflog", "expire"]' @'
prefix_rule(
    pattern = ["git", "reflog", "expire"],
    decision = "prompt",
    justification = "Prompt before expiring reflog history",
    match = ["git reflog expire --expire=now --all"],
)
'@
Add-CodexPrefixRuleIfMissing '["git", "gc", "--prune"]' @'
prefix_rule(
    pattern = ["git", "gc", "--prune"],
    decision = "prompt",
    justification = "Prompt before pruning unreachable Git objects",
    match = ["git gc --prune"],
)
'@
Add-CodexPrefixRuleIfMissing '["git", "gc", "--prune=now"]' @'
prefix_rule(
    pattern = ["git", "gc", "--prune=now"],
    decision = "prompt",
    justification = "Prompt before pruning unreachable Git objects immediately",
    match = ["git gc --prune=now"],
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
Add-CodexPrefixRuleIfMissing '["make"]' @'
prefix_rule(
    pattern = ["make"],
    decision = "allow",
    justification = "Allow Makefile workflows in trusted workspaces without repeated prompts",
    match = ["make test"],
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
Add-CodexPrefixRuleIfMissing '["cmake", "--build"]' @'
prefix_rule(
    pattern = ["cmake", "--build"],
    decision = "allow",
    justification = "Allow trusted CMake workspace builds without repeated prompts",
    match = ["cmake --build --preset=dev-win64 --target format-check -j 4"],
)
'@
Add-CodexPrefixRuleIfMissing '["ctest"]' @'
prefix_rule(
    pattern = ["ctest"],
    decision = "allow",
    justification = "Allow trusted CTest workspace test runs without repeated prompts",
    match = ["ctest --preset=dev-win64 --output-on-failure"],
)
'@
Add-CodexPrefixRuleIfMissing '["ninja"]' @'
prefix_rule(
    pattern = ["ninja"],
    decision = "allow",
    justification = "Allow trusted Ninja workspace builds without repeated prompts",
    match = ["ninja -C build"],
)
'@
Add-CodexPrefixRuleIfMissing '["meson", "compile"]' @'
prefix_rule(
    pattern = ["meson", "compile"],
    decision = "allow",
    justification = "Allow trusted Meson workspace builds without repeated prompts",
    match = ["meson compile -C build"],
)
'@
Add-CodexPrefixRuleIfMissing '["meson", "test"]' @'
prefix_rule(
    pattern = ["meson", "test"],
    decision = "allow",
    justification = "Allow trusted Meson workspace test runs without repeated prompts",
    match = ["meson test -C build"],
)
'@
Add-CodexPrefixRuleIfMissing '["cargo", "build"]' @'
prefix_rule(
    pattern = ["cargo", "build"],
    decision = "allow",
    justification = "Allow trusted Cargo workspace builds without repeated prompts",
    match = ["cargo build --all-targets"],
)
'@
Add-CodexPrefixRuleIfMissing '["cargo", "check"]' @'
prefix_rule(
    pattern = ["cargo", "check"],
    decision = "allow",
    justification = "Allow trusted Cargo workspace checks without repeated prompts",
    match = ["cargo check --all-targets"],
)
'@
Add-CodexPrefixRuleIfMissing '["cargo", "test"]' @'
prefix_rule(
    pattern = ["cargo", "test"],
    decision = "allow",
    justification = "Allow trusted Cargo workspace tests without repeated prompts",
    match = ["cargo test"],
)
'@
Add-CodexPrefixRuleIfMissing '["cargo", "clippy"]' @'
prefix_rule(
    pattern = ["cargo", "clippy"],
    decision = "allow",
    justification = "Allow trusted Cargo clippy checks without repeated prompts",
    match = ["cargo clippy --all-targets --all-features -- -D warnings"],
)
'@
Add-CodexPrefixRuleIfMissing '["cargo", "nextest"]' @'
prefix_rule(
    pattern = ["cargo", "nextest"],
    decision = "allow",
    justification = "Allow trusted Cargo nextest runs without repeated prompts",
    match = ["cargo nextest run"],
)
'@
Add-CodexPrefixRuleIfMissing '["python", "-m", "pytest"]' @'
prefix_rule(
    pattern = ["python", "-m", "pytest"],
    decision = "allow",
    justification = "Allow trusted Python pytest runs without repeated prompts",
    match = ["python -m pytest"],
)
'@
Add-CodexPrefixRuleIfMissing '["py", "-m", "pytest"]' @'
prefix_rule(
    pattern = ["py", "-m", "pytest"],
    decision = "allow",
    justification = "Allow trusted Windows Python launcher pytest runs without repeated prompts",
    match = ["py -m pytest"],
)
'@
Add-CodexPrefixRuleIfMissing '["pytest"]' @'
prefix_rule(
    pattern = ["pytest"],
    decision = "allow",
    justification = "Allow trusted pytest runs without repeated prompts",
    match = ["pytest tests"],
)
'@
Add-CodexPrefixRuleIfMissing '["npm", "test"]' @'
prefix_rule(
    pattern = ["npm", "test"],
    decision = "allow",
    justification = "Allow trusted npm test scripts without repeated prompts",
    match = ["npm test"],
)
'@
Add-CodexPrefixRuleIfMissing '["npm", "run", "test"]' @'
prefix_rule(
    pattern = ["npm", "run", "test"],
    decision = "allow",
    justification = "Allow trusted npm run test scripts without repeated prompts",
    match = ["npm run test"],
)
'@
Add-CodexPrefixRuleIfMissing '["npm", "run", "build"]' @'
prefix_rule(
    pattern = ["npm", "run", "build"],
    decision = "allow",
    justification = "Allow trusted npm run build scripts without repeated prompts",
    match = ["npm run build"],
)
'@
Add-CodexPrefixRuleIfMissing '["npm", "run", "lint"]' @'
prefix_rule(
    pattern = ["npm", "run", "lint"],
    decision = "allow",
    justification = "Allow trusted npm run lint scripts without repeated prompts",
    match = ["npm run lint"],
)
'@
Set-CodexAllowRule '["cmake"]' `
    'Allow trusted CMake configure/build workflows without repeated prompts' `
    'cmake --preset=dev-win64'
Set-CodexAllowRule '["cargo", "audit"]' `
    'Allow trusted Cargo security audits without repeated prompts' `
    'cargo audit'
Set-CodexAllowRule '["cargo", "deny"]' `
    'Allow trusted Cargo policy checks without repeated prompts' `
    'cargo deny check'
Set-CodexAllowRule '["uv", "sync"]' `
    'Allow uv dependency synchronization in trusted workspaces without repeated prompts' `
    'uv sync'
Set-CodexAllowRule '["uv", "pip", "install"]' `
    'Allow uv pip installs in trusted workspaces without repeated prompts' `
    'uv pip install -r requirements.txt'
Set-CodexAllowRule '["uv", "tool", "run"]' `
    'Allow uv tool run workflows without repeated prompts' `
    'uv tool run ruff check .'
Set-CodexAllowRule '["uvx"]' `
    'Allow ephemeral uvx tool execution for trusted development workflows without repeated prompts' `
    'uvx ruff check .'
Set-CodexAllowRule '["npm", "install"]' `
    'Allow npm dependency installs in trusted workspaces without repeated prompts' `
    'npm install'
Set-CodexAllowRule '["npm", "ci"]' `
    'Allow npm clean dependency installs in trusted workspaces without repeated prompts' `
    'npm ci'
Set-CodexAllowRule '["npm", "--prefix"]' `
    'Allow npm --prefix workspace workflows without repeated prompts' `
    'npm --prefix apps/windows-desktop run test'
Set-CodexAllowRule '["npm", "run", "tauri"]' `
    'Allow Tauri npm workflows without repeated prompts' `
    'npm run tauri build'
Set-CodexAllowRule '["pnpm", "install"]' `
    'Allow pnpm dependency installs in trusted workspaces without repeated prompts' `
    'pnpm install'
Set-CodexAllowRule '["pnpm", "test"]' `
    'Allow pnpm tests in trusted workspaces without repeated prompts' `
    'pnpm test'
Set-CodexAllowRule '["pnpm", "run"]' `
    'Allow pnpm run scripts in trusted workspaces without repeated prompts' `
    'pnpm run build'
Set-CodexAllowRule '["pnpm", "exec"]' `
    'Allow pnpm exec tools in trusted workspaces without repeated prompts' `
    'pnpm exec tsc --noEmit'
Set-CodexAllowRule '["yarn", "install"]' `
    'Allow Yarn dependency installs in trusted workspaces without repeated prompts' `
    'yarn install'
Set-CodexAllowRule '["yarn", "test"]' `
    'Allow Yarn tests in trusted workspaces without repeated prompts' `
    'yarn test'
Set-CodexAllowRule '["yarn", "run"]' `
    'Allow Yarn run scripts in trusted workspaces without repeated prompts' `
    'yarn run build'
Set-CodexAllowRule '["bun", "install"]' `
    'Allow Bun dependency installs in trusted workspaces without repeated prompts' `
    'bun install'
Set-CodexAllowRule '["bun", "test"]' `
    'Allow Bun tests in trusted workspaces without repeated prompts' `
    'bun test'
Set-CodexAllowRule '["bun", "run"]' `
    'Allow Bun run scripts in trusted workspaces without repeated prompts' `
    'bun run build'
Set-CodexAllowRule '["dotnet", "restore"]' `
    'Allow .NET restore in trusted workspaces without repeated prompts' `
    'dotnet restore'
Set-CodexAllowRule '["dotnet", "build"]' `
    'Allow .NET builds in trusted workspaces without repeated prompts' `
    'dotnet build'
Set-CodexAllowRule '["dotnet", "test"]' `
    'Allow .NET tests in trusted workspaces without repeated prompts' `
    'dotnet test'
Set-CodexAllowRule '["dotnet", "run"]' `
    'Allow .NET run workflows in trusted workspaces without repeated prompts' `
    'dotnet run --project app.csproj'
Set-CodexAllowRule '["go", "test"]' `
    'Allow Go tests in trusted workspaces without repeated prompts' `
    'go test ./...'
Set-CodexAllowRule '["go", "build"]' `
    'Allow Go builds in trusted workspaces without repeated prompts' `
    'go build ./...'
Set-CodexAllowRule '["go", "run"]' `
    'Allow Go run workflows in trusted workspaces without repeated prompts' `
    'go run ./cmd/app'
Set-CodexAllowRule '["ruff"]' `
    'Allow Ruff checks and formatting in trusted workspaces without repeated prompts' `
    'ruff check .'
Set-CodexAllowRule '["python", "-m", "ruff"]' `
    'Allow Ruff via Python module in trusted workspaces without repeated prompts' `
    'python -m ruff check .'
Set-CodexAllowRule '["py", "-m", "ruff"]' `
    'Allow Ruff via Windows Python launcher in trusted workspaces without repeated prompts' `
    'py -m ruff check .'
Set-CodexAllowRule '["mypy"]' `
    'Allow mypy type checks in trusted workspaces without repeated prompts' `
    'mypy .'
Set-CodexAllowRule '["python", "-m", "mypy"]' `
    'Allow mypy via Python module in trusted workspaces without repeated prompts' `
    'python -m mypy .'
Set-CodexAllowRule '["py", "-m", "mypy"]' `
    'Allow mypy via Windows Python launcher in trusted workspaces without repeated prompts' `
    'py -m mypy .'
Set-CodexAllowRule '["pyright"]' `
    'Allow Pyright type checks in trusted workspaces without repeated prompts' `
    'pyright'
Set-CodexAllowRule '["tox"]' `
    'Allow tox verification in trusted workspaces without repeated prompts' `
    'tox'
Set-CodexAllowRule '["nox"]' `
    'Allow nox verification in trusted workspaces without repeated prompts' `
    'nox'
Set-CodexAllowRule '["pre-commit"]' `
    'Allow pre-commit hooks in trusted workspaces without repeated prompts' `
    'pre-commit run --all-files'
Set-CodexAllowRule '["gitleaks"]' `
    'Allow local secret scans in trusted workspaces without repeated prompts' `
    'gitleaks git --source . --redact'
Set-CodexAllowRule '["trivy"]' `
    'Allow local vulnerability scans in trusted workspaces without repeated prompts' `
    'trivy fs .'
Set-CodexAllowRule '["ansible-playbook"]' `
    'Allow Ansible provisioning and dry-run workflows without repeated prompts' `
    'ansible-playbook site.yml --syntax-check'
Set-CodexAllowRule '["lua"]' `
    'Allow Lua scripts in trusted development workflows without repeated prompts' `
    'lua tests/run.lua'
Set-CodexAllowRule '["luajit"]' `
    'Allow LuaJIT scripts in trusted development workflows without repeated prompts' `
    'luajit tests/run.lua'
Set-CodexAllowRule '["busted"]' `
    'Allow Lua busted tests in trusted workspaces without repeated prompts' `
    'busted'
Set-CodexAllowRule '["stylua"]' `
    'Allow Lua formatting in trusted workspaces without repeated prompts' `
    'stylua .'
Add-CodexPrefixRuleIfMissing '["west", "build"]' @'
prefix_rule(
    pattern = ["west", "build"],
    decision = "allow",
    justification = "Allow trusted Zephyr workspace builds without repeated prompts",
    match = ["west build -b mik32_evb"],
)
'@
Add-CodexPrefixRuleIfMissing '["west", "flash"]' @'
prefix_rule(
    pattern = ["west", "flash"],
    decision = "allow",
    justification = "Allow explicitly requested Zephyr hardware flashing without repeated prompts",
    match = ["west flash -d build"],
)
'@
Set-CodexPrefixRule '["Set-Item", "Env:\\VCPKG_ROOT"]' @'
prefix_rule(
    pattern = ["Set-Item", "Env:\\VCPKG_ROOT"],
    decision = "allow",
    justification = "Allow process-local VCPKG_ROOT overrides before trusted build commands",
)
'@
Set-CodexPrefixRule '["Set-Item", "-Path", "Env:\\VCPKG_ROOT"]' @'
prefix_rule(
    pattern = ["Set-Item", "-Path", "Env:\\VCPKG_ROOT"],
    decision = "allow",
    justification = "Allow explicit process-local VCPKG_ROOT overrides before trusted build commands",
)
'@
Set-CodexPrefixRule '["Set-Item", "Env:\\PROTOC"]' @'
prefix_rule(
    pattern = ["Set-Item", "Env:\\PROTOC"],
    decision = "allow",
    justification = "Allow process-local PROTOC overrides before trusted build commands",
)
'@
Set-CodexPrefixRule '["Set-Item", "-Path", "Env:\\PROTOC"]' @'
prefix_rule(
    pattern = ["Set-Item", "-Path", "Env:\\PROTOC"],
    decision = "allow",
    justification = "Allow explicit process-local PROTOC overrides before trusted build commands",
)
'@
$algotraderDevBuildPattern = '["C:\\Program Files\\PowerShell\\7\\pwsh.exe", "-NoProfile", "-Command", "$env:VCPKG_ROOT=''D:/trading/algotrader/vcpkg''; cmake --build --preset=dev-win64"]'
Set-CodexPrefixRule $algotraderDevBuildPattern @"
prefix_rule(
    pattern = $algotraderDevBuildPattern,
    decision = "allow",
    justification = "Allow known algotrader VCPKG_ROOT PowerShell build wrapper without repeated prompts",
)
"@
$algotraderDevBuildAndTestPattern = '["C:\\Program Files\\PowerShell\\7\\pwsh.exe", "-NoProfile", "-Command", "$env:VCPKG_ROOT=''D:/trading/algotrader/vcpkg''; cmake --build --preset=dev-win64; if($LASTEXITCODE -ne 0){ exit $LASTEXITCODE }; ctest --preset=dev-win64 --output-on-failure; exit $LASTEXITCODE"]'
Set-CodexPrefixRule $algotraderDevBuildAndTestPattern @"
prefix_rule(
    pattern = $algotraderDevBuildAndTestPattern,
    decision = "allow",
    justification = "Allow known algotrader VCPKG_ROOT PowerShell build and CTest wrapper without repeated prompts",
)
"@
$algotraderConfigureAndBuildPattern = '["C:\\Program Files\\PowerShell\\7\\pwsh.exe", "-Command", "$env:VCPKG_ROOT=''D:/trading/algotrader/vcpkg''; cmake --preset=dev-win64; if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }; cmake --build --preset=dev-win64 --target algotrader_test algotrader_exe format-check"]'
Set-CodexPrefixRule $algotraderConfigureAndBuildPattern @"
prefix_rule(
    pattern = $algotraderConfigureAndBuildPattern,
    decision = "allow",
    justification = "Allow known algotrader VCPKG_ROOT PowerShell configure and build wrapper without repeated prompts",
)
"@
$algotraderReleaseTargetPattern = '["C:\\Program Files\\PowerShell\\7\\pwsh.exe", "-NoProfile", "-Command", "$env:VCPKG_ROOT=''D:/trading/algotrader/vcpkg''; cmake --build build/windows-release --config Release --target quik_cpp_plugin_lua_host_test -j 4"]'
Set-CodexPrefixRule $algotraderReleaseTargetPattern @"
prefix_rule(
    pattern = $algotraderReleaseTargetPattern,
    decision = "allow",
    justification = "Allow known algotrader VCPKG_ROOT PowerShell release target wrapper without repeated prompts",
)
"@
Set-CodexAllowRule '["D:\\trading\\algotrader\\run.ps1"]' `
    'Allow the algotrader project runner in trusted local development without repeated prompts'
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
Set-CodexAllowRule '["Get-Process"]' `
    'Allow PowerShell process inspection without repeated prompts' `
    'Get-Process'
Set-CodexAllowRule '["Get-Service"]' `
    'Allow PowerShell service inspection without repeated prompts' `
    'Get-Service'
Set-CodexAllowRule '["Get-PSDrive"]' `
    'Allow PowerShell drive inspection without repeated prompts' `
    'Get-PSDrive'
Set-CodexAllowRule '["Get-ComputerInfo"]' `
    'Allow PowerShell computer information inspection without repeated prompts' `
    'Get-ComputerInfo'
Set-CodexAllowRule '["Get-CimInstance"]' `
    'Allow CIM system inspection without repeated prompts' `
    'Get-CimInstance Win32_OperatingSystem'
Set-CodexAllowRule '["Get-WmiObject"]' `
    'Allow WMI system inspection without repeated prompts' `
    'Get-WmiObject Win32_OperatingSystem'
Set-CodexAllowRule '["Get-Module"]' `
    'Allow PowerShell module inspection without repeated prompts' `
    'Get-Module -ListAvailable'
Set-CodexAllowRule '["Get-PSRepository"]' `
    'Allow PowerShell repository inspection without repeated prompts' `
    'Get-PSRepository'
Set-CodexAllowRule '["Find-Module"]' `
    'Allow PowerShell module discovery without repeated prompts' `
    'Find-Module PSReadLine'
Set-CodexAllowRule '["Get-Package"]' `
    'Allow PowerShell package inspection without repeated prompts' `
    'Get-Package'
Set-CodexAllowRule '["Get-AppxPackage"]' `
    'Allow AppX package inspection without repeated prompts' `
    'Get-AppxPackage'
Set-CodexAllowRule '["Get-AppxProvisionedPackage"]' `
    'Allow provisioned AppX package inspection without repeated prompts' `
    'Get-AppxProvisionedPackage -Online'

Set-CodexPrefixRule '["winget"]' @'
prefix_rule(
    pattern = ["winget"],
    decision = "allow",
    justification = "Allow winget installs and upgrades for trusted workstation provisioning without repeated prompts",
    match = ["winget install Microsoft.PowerShell"],
)
'@
Set-CodexPrefixRule '["scoop"]' @'
prefix_rule(
    pattern = ["scoop"],
    decision = "allow",
    justification = "Allow Scoop installs and upgrades for trusted workstation provisioning without repeated prompts",
    match = ["scoop install ripgrep"],
)
'@
Set-CodexPrefixRule '["choco"]' @'
prefix_rule(
    pattern = ["choco"],
    decision = "allow",
    justification = "Allow Chocolatey installs and upgrades for trusted workstation provisioning without repeated prompts",
    match = ["choco install git"],
)
'@
Set-CodexPrefixRule '["rustup"]' @'
prefix_rule(
    pattern = ["rustup"],
    decision = "allow",
    justification = "Allow Rust toolchain updates for trusted development setup without repeated prompts",
    match = ["rustup update stable"],
)
'@
Set-CodexPrefixRule '["cargo", "install"]' @'
prefix_rule(
    pattern = ["cargo", "install"],
    decision = "allow",
    justification = "Allow global Cargo tool installs for trusted development setup without repeated prompts",
    match = ["cargo install cargo-nextest"],
)
'@
Set-CodexPrefixRule '["uv", "tool", "install"]' @'
prefix_rule(
    pattern = ["uv", "tool", "install"],
    decision = "allow",
    justification = "Allow global uv tool installs for trusted development setup without repeated prompts",
    match = ["uv tool install ruff"],
)
'@
Set-CodexPrefixRule '["uv", "tool", "upgrade"]' @'
prefix_rule(
    pattern = ["uv", "tool", "upgrade"],
    decision = "allow",
    justification = "Allow global uv tool upgrades for trusted development setup without repeated prompts",
    match = ["uv tool upgrade ruff"],
)
'@
Set-CodexPrefixRule '["npm", "install", "-g"]' @'
prefix_rule(
    pattern = ["npm", "install", "-g"],
    decision = "allow",
    justification = "Allow global npm installs for trusted development setup without repeated prompts",
    match = ["npm install -g @openai/codex"],
)
'@
Set-CodexPrefixRule '["npm", "install", "--global"]' @'
prefix_rule(
    pattern = ["npm", "install", "--global"],
    decision = "allow",
    justification = "Allow global npm installs for trusted development setup without repeated prompts",
    match = ["npm install --global @openai/codex"],
)
'@
Set-CodexPrefixRule '["python", "-m", "pip", "install"]' @'
prefix_rule(
    pattern = ["python", "-m", "pip", "install"],
    decision = "allow",
    justification = "Allow Python package installs in trusted development environments without repeated prompts",
    match = ["python -m pip install pytest"],
)
'@
Set-CodexPrefixRule '["py", "-m", "pip", "install"]' @'
prefix_rule(
    pattern = ["py", "-m", "pip", "install"],
    decision = "allow",
    justification = "Allow Windows Python launcher package installs in trusted development environments without repeated prompts",
    match = ["py -m pip install pytest"],
)
'@
Set-CodexPrefixRule '["wsl", "--update"]' @'
prefix_rule(
    pattern = ["wsl", "--update"],
    decision = "allow",
    justification = "Allow WSL platform updates for trusted workstation maintenance without repeated prompts",
    match = ["wsl --update"],
)
'@
Set-CodexPrefixRule '["wsl", "--install"]' @'
prefix_rule(
    pattern = ["wsl", "--install"],
    decision = "prompt",
    justification = "Review creation of a WSL distribution",
    match = ["wsl --install -d Ubuntu"],
)
'@
Set-CodexPrefixRule '["wsl", "--shutdown"]' @'
prefix_rule(
    pattern = ["wsl", "--shutdown"],
    decision = "allow",
    justification = "Allow WSL shutdown during trusted workstation maintenance without repeated prompts",
    match = ["wsl --shutdown"],
)
'@
Set-CodexPrefixRule '["Set-ExecutionPolicy"]' @'
prefix_rule(
    pattern = ["Set-ExecutionPolicy"],
    decision = "allow",
    justification = "Allow PowerShell execution policy changes during trusted provisioning without repeated prompts",
    match = ["Set-ExecutionPolicy RemoteSigned -Scope CurrentUser"],
)
'@
Set-CodexPrefixRule '["Set-ItemProperty"]' @'
prefix_rule(
    pattern = ["Set-ItemProperty"],
    decision = "allow",
    justification = "Allow registry and provider-backed setting changes during trusted provisioning without repeated prompts",
)
'@
Set-CodexPrefixRule '["New-ItemProperty"]' @'
prefix_rule(
    pattern = ["New-ItemProperty"],
    decision = "allow",
    justification = "Allow registry and provider-backed setting creation during trusted provisioning without repeated prompts",
)
'@
Set-CodexPrefixRule '["Remove-ItemProperty"]' @'
prefix_rule(
    pattern = ["Remove-ItemProperty"],
    decision = "prompt",
    justification = "Review destructive system removal before execution",
)
'@
Set-CodexPrefixRule '["reg"]' @'
prefix_rule(
    pattern = ["reg"],
    decision = "allow",
    justification = "Allow direct registry operations during trusted provisioning without repeated prompts",
)
'@
Set-CodexPrefixRule '["netsh"]' @'
prefix_rule(
    pattern = ["netsh"],
    decision = "allow",
    justification = "Allow Windows network configuration during trusted provisioning without repeated prompts",
    match = ["netsh interface show interface"],
)
'@
Set-CodexPrefixRule '["sc"]' @'
prefix_rule(
    pattern = ["sc"],
    decision = "allow",
    justification = "Allow Windows service operations with sc.exe during trusted provisioning without repeated prompts",
    match = ["sc query ssh-agent"],
)
'@
Set-CodexPrefixRule '["Start-Process"]' @'
prefix_rule(
    pattern = ["Start-Process"],
    decision = "allow",
    justification = "Allow launching external programs during trusted provisioning without repeated prompts",
    match = ["Start-Process notepad"],
)
'@
Set-CodexPrefixRule '["Set-Service"]' @'
prefix_rule(
    pattern = ["Set-Service"],
    decision = "allow",
    justification = "Allow Windows service configuration during trusted provisioning without repeated prompts",
    match = ["Set-Service ssh-agent -StartupType Automatic"],
)
'@
Set-CodexPrefixRule '["New-Service"]' @'
prefix_rule(
    pattern = ["New-Service"],
    decision = "allow",
    justification = "Allow Windows service creation during trusted provisioning without repeated prompts",
)
'@
Set-CodexPrefixRule '["Remove-Service"]' @'
prefix_rule(
    pattern = ["Remove-Service"],
    decision = "prompt",
    justification = "Review destructive system removal before execution",
    match = ["Remove-Service example"],
)
'@
Set-CodexPrefixRule '["Enable-WindowsOptionalFeature"]' @'
prefix_rule(
    pattern = ["Enable-WindowsOptionalFeature"],
    decision = "allow",
    justification = "Allow enabling Windows optional features during trusted provisioning without repeated prompts",
    match = ["Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux"],
)
'@
Set-CodexPrefixRule '["Disable-WindowsOptionalFeature"]' @'
prefix_rule(
    pattern = ["Disable-WindowsOptionalFeature"],
    decision = "prompt",
    justification = "Review destructive system removal before execution",
    match = ["Disable-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux"],
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

# Trusted development, remote diagnostics, and ordinary file edits.
Set-CodexAllowRule '["ssh"]' `
    'Allow authorized development, diagnostics, and file editing without repeated prompts'
Set-CodexAllowRule '["sshpass"]' `
    'Allow authorized development, diagnostics, and file editing without repeated prompts'
Set-CodexAllowRule '["scp"]' `
    'Allow authorized development, diagnostics, and file editing without repeated prompts'
Set-CodexAllowRule '["sftp"]' `
    'Allow authorized development, diagnostics, and file editing without repeated prompts'
Set-CodexAllowRule '["rsync"]' `
    'Allow authorized development, diagnostics, and file editing without repeated prompts'
Set-CodexAllowRule '["gdb"]' `
    'Allow authorized development, diagnostics, and file editing without repeated prompts'
Set-CodexAllowRule '["lldb"]' `
    'Allow authorized development, diagnostics, and file editing without repeated prompts'
Set-CodexAllowRule '["valgrind"]' `
    'Allow authorized development, diagnostics, and file editing without repeated prompts'
Set-CodexAllowRule '["objdump"]' `
    'Allow authorized development, diagnostics, and file editing without repeated prompts'
Set-CodexAllowRule '["llvm-objdump"]' `
    'Allow authorized development, diagnostics, and file editing without repeated prompts'
Set-CodexAllowRule '["nm"]' `
    'Allow authorized development, diagnostics, and file editing without repeated prompts'
Set-CodexAllowRule '["file"]' `
    'Allow authorized development, diagnostics, and file editing without repeated prompts'
Set-CodexAllowRule '["strings"]' `
    'Allow authorized development, diagnostics, and file editing without repeated prompts'
Set-CodexAllowRule '["xxd"]' `
    'Allow authorized development, diagnostics, and file editing without repeated prompts'
Set-CodexAllowRule '["cdb"]' `
    'Allow authorized development, diagnostics, and file editing without repeated prompts'
Set-CodexAllowRule '["windbg"]' `
    'Allow authorized development, diagnostics, and file editing without repeated prompts'
Set-CodexAllowRule '["dumpbin"]' `
    'Allow authorized development, diagnostics, and file editing without repeated prompts'
Set-CodexAllowRule '["llvm-readelf"]' `
    'Allow authorized development, diagnostics, and file editing without repeated prompts'
Set-CodexAllowRule '["cl"]' `
    'Allow authorized development, diagnostics, and file editing without repeated prompts'
Set-CodexAllowRule '["clang"]' `
    'Allow authorized development, diagnostics, and file editing without repeated prompts'
Set-CodexAllowRule '["clang++"]' `
    'Allow authorized development, diagnostics, and file editing without repeated prompts'
Set-CodexAllowRule '["clang-cl"]' `
    'Allow authorized development, diagnostics, and file editing without repeated prompts'
Set-CodexAllowRule '["link"]' `
    'Allow authorized development, diagnostics, and file editing without repeated prompts'
Set-CodexAllowRule '["lib"]' `
    'Allow authorized development, diagnostics, and file editing without repeated prompts'
Set-CodexAllowRule '["msbuild"]' `
    'Allow authorized development, diagnostics, and file editing without repeated prompts'
Set-CodexAllowRule '["MSBuild"]' `
    'Allow authorized development, diagnostics, and file editing without repeated prompts'
Set-CodexAllowRule '["Copy-Item"]' `
    'Allow authorized development, diagnostics, and file editing without repeated prompts'
Set-CodexAllowRule '["Move-Item"]' `
    'Allow authorized development, diagnostics, and file editing without repeated prompts'
Set-CodexAllowRule '["Rename-Item"]' `
    'Allow authorized development, diagnostics, and file editing without repeated prompts'
Set-CodexAllowRule '["New-Item"]' `
    'Allow authorized development, diagnostics, and file editing without repeated prompts'
Set-CodexAllowRule '["Set-Content"]' `
    'Allow authorized development, diagnostics, and file editing without repeated prompts'
Set-CodexAllowRule '["Add-Content"]' `
    'Allow authorized development, diagnostics, and file editing without repeated prompts'
Set-CodexAllowRule '["Out-File"]' `
    'Allow authorized development, diagnostics, and file editing without repeated prompts'
Set-CodexAllowRule '["Set-Location"]' `
    'Allow authorized development, diagnostics, and file editing without repeated prompts'
Set-CodexAllowRule '["Install-Module"]' `
    'Allow authorized development, diagnostics, and file editing without repeated prompts'
Set-CodexAllowRule '["Install-PSResource"]' `
    'Allow authorized development, diagnostics, and file editing without repeated prompts'
Set-CodexAllowRule '["dotnet", "tool", "install"]' `
    'Allow authorized development, diagnostics, and file editing without repeated prompts'

# Dangerous removals override otherwise trusted setup tools.
Set-CodexPrefixRule '["rm"]' @'
prefix_rule(
    pattern = ["rm"],
    decision = "prompt",
)
'@
Set-CodexPrefixRule '["rmdir"]' @'
prefix_rule(
    pattern = ["rmdir"],
    decision = "prompt",
)
'@
Set-CodexPrefixRule '["del"]' @'
prefix_rule(
    pattern = ["del"],
    decision = "prompt",
)
'@
Set-CodexPrefixRule '["erase"]' @'
prefix_rule(
    pattern = ["erase"],
    decision = "prompt",
)
'@
Set-CodexPrefixRule '["Remove-Item"]' @'
prefix_rule(
    pattern = ["Remove-Item"],
    decision = "prompt",
)
'@
Set-CodexPrefixRule '["Clear-Disk"]' @'
prefix_rule(
    pattern = ["Clear-Disk"],
    decision = "prompt",
)
'@
Set-CodexPrefixRule '["Initialize-Disk"]' @'
prefix_rule(
    pattern = ["Initialize-Disk"],
    decision = "prompt",
)
'@
Set-CodexPrefixRule '["Format-Volume"]' @'
prefix_rule(
    pattern = ["Format-Volume"],
    decision = "prompt",
)
'@
Set-CodexPrefixRule '["Remove-Partition"]' @'
prefix_rule(
    pattern = ["Remove-Partition"],
    decision = "prompt",
)
'@
Set-CodexPrefixRule '["diskpart"]' @'
prefix_rule(
    pattern = ["diskpart"],
    decision = "prompt",
)
'@
Set-CodexPrefixRule '["format"]' @'
prefix_rule(
    pattern = ["format"],
    decision = "prompt",
)
'@
Set-CodexPrefixRule '["shutdown"]' @'
prefix_rule(
    pattern = ["shutdown"],
    decision = "prompt",
)
'@
Set-CodexPrefixRule '[["reg", "reg.exe"], "delete"]' @'
prefix_rule(
    pattern = [["reg", "reg.exe"], "delete"],
    decision = "prompt",
)
'@
Set-CodexPrefixRule '[["sc", "sc.exe"], "delete"]' @'
prefix_rule(
    pattern = [["sc", "sc.exe"], "delete"],
    decision = "prompt",
)
'@
Set-CodexPrefixRule '["wsl", "--unregister"]' @'
prefix_rule(
    pattern = ["wsl", "--unregister"],
    decision = "prompt",
)
'@
Set-CodexPrefixRule '[["winget", "scoop", "choco"], "uninstall"]' @'
prefix_rule(
    pattern = [["winget", "scoop", "choco"], "uninstall"],
    decision = "prompt",
)
'@
Set-CodexPrefixRule '["dism", "/online", "/disable-feature"]' @'
prefix_rule(
    pattern = ["dism", "/online", "/disable-feature"],
    decision = "prompt",
)
'@
Set-CodexPrefixRule '["dism", "/Online", "/Disable-Feature"]' @'
prefix_rule(
    pattern = ["dism", "/Online", "/Disable-Feature"],
    decision = "prompt",
)
'@
# WSL command execution is an explicitly trusted development workflow.
Set-CodexAllowRule '["wsl"]' `
    'Allow commands, builds, diagnostics, and shell execution inside WSL'
Set-CodexAllowRule '["wsl.exe"]' `
    'Allow commands, builds, diagnostics, and shell execution inside WSL'
Set-CodexPrefixRule '[["wsl", "wsl.exe"], ["--install", "--import", "--import-in-place", "--unregister"]]' @'
prefix_rule(
    pattern = [["wsl", "wsl.exe"], ["--install", "--import", "--import-in-place", "--unregister"]],
    decision = "prompt",
)
'@
Set-CodexPrefixRule '[["New-VM", "Remove-VM"]]' @'
prefix_rule(
    pattern = [["New-VM", "Remove-VM"]],
    decision = "prompt",
)
'@
Set-CodexAllowRule '["ssh.exe"]' `
    'Allow the explicit Windows executable name for trusted development tools'
Set-CodexAllowRule '["scp.exe"]' `
    'Allow the explicit Windows executable name for trusted development tools'
Set-CodexAllowRule '["sftp.exe"]' `
    'Allow the explicit Windows executable name for trusted development tools'
Set-CodexAllowRule '["gdb.exe"]' `
    'Allow the explicit Windows executable name for trusted development tools'
Set-CodexAllowRule '["lldb.exe"]' `
    'Allow the explicit Windows executable name for trusted development tools'
Set-CodexAllowRule '["cdb.exe"]' `
    'Allow the explicit Windows executable name for trusted development tools'
Set-CodexAllowRule '["windbg.exe"]' `
    'Allow the explicit Windows executable name for trusted development tools'
Set-CodexAllowRule '["dumpbin.exe"]' `
    'Allow the explicit Windows executable name for trusted development tools'
Set-CodexAllowRule '["cl.exe"]' `
    'Allow the explicit Windows executable name for trusted development tools'
Set-CodexAllowRule '["msbuild.exe"]' `
    'Allow the explicit Windows executable name for trusted development tools'
Set-CodexPrefixRule '["git", "push", ["--force", "-f", "--force-with-lease"]]' @'
prefix_rule(
    pattern = ["git", "push", ["--force", "-f", "--force-with-lease"]],
    decision = "prompt",
)
'@
Set-CodexPrefixRule '["rsync", "--delete"]' @'
prefix_rule(
    pattern = ["rsync", "--delete"],
    decision = "prompt",
)
'@
Set-CodexPrefixRule '["sshpass", "-p"]' @'
prefix_rule(
    pattern = ["sshpass", "-p"],
    decision = "prompt",
)
'@
Set-CodexPrefixRule '[["bcdedit", "bcdedit.exe"], ["/enum", "/ENUM"]]' @'
prefix_rule(
    pattern = [["bcdedit", "bcdedit.exe"], ["/enum", "/ENUM"]],
    decision = "allow",
)
'@
Set-CodexPrefixRule '[["bcdedit", "bcdedit.exe"], ["/set", "/delete", "/deletevalue", "/import", "/create", "/createstore", "/default", "/bootsequence", "/displayorder"]]' @'
prefix_rule(
    pattern = [["bcdedit", "bcdedit.exe"], ["/set", "/delete", "/deletevalue", "/import", "/create", "/createstore", "/default", "/bootsequence", "/displayorder"]],
    decision = "prompt",
)
'@
Set-CodexPrefixRule '[["dism", "dism.exe"], ["/online", "/Online"], ["/get-features", "/Get-Features", "/get-packages", "/Get-Packages", "/get-capabilities", "/Get-Capabilities", "/enable-feature", "/Enable-Feature", "/add-capability", "/Add-Capability"]]' @'
prefix_rule(
    pattern = [["dism", "dism.exe"], ["/online", "/Online"], ["/get-features", "/Get-Features", "/get-packages", "/Get-Packages", "/get-capabilities", "/Get-Capabilities", "/enable-feature", "/Enable-Feature", "/add-capability", "/Add-Capability"]],
    decision = "allow",
)
'@
Set-CodexPrefixRule '[["dism", "dism.exe"], ["/apply-image", "/Apply-Image", "/apply-ffu", "/Apply-FFU", "/delete-image", "/Delete-Image"]]' @'
prefix_rule(
    pattern = [["dism", "dism.exe"], ["/apply-image", "/Apply-Image", "/apply-ffu", "/Apply-FFU", "/delete-image", "/Delete-Image"]],
    decision = "prompt",
)
'@
Complete-CodexDefaultRules
Set-CodexPermissionsExample
Set-CodexProfileFiles
Set-CodexCustomAgentFiles

$desiredMcpServers = ConvertTo-NameList $CodexMcpAllowlist
if ($CodexGithubMcpEnabled) {
    $desiredMcpServers += 'github'
}
if ($CodexSerenaEnabled) {
    $desiredMcpServers += 'serena'
}
if ($CodexPlaywrightMcpEnabled) {
    $desiredMcpServers += 'playwright'
}
$desiredMcpServers = @($desiredMcpServers | Select-Object -Unique)

if ($CodexPruneDisabledOptionalMcp -and -not $CodexMcpPruneUnmanaged) {
    if (-not $CodexGithubMcpEnabled -and 'github' -notin $desiredMcpServers) {
        Remove-CodexMcpIfConfigured 'github'
    }
    if (-not $CodexSerenaEnabled -and 'serena' -notin $desiredMcpServers) {
        Remove-CodexMcpIfConfigured 'serena'
    }
    if (-not $CodexPlaywrightMcpEnabled -and 'playwright' -notin $desiredMcpServers) {
        Remove-CodexMcpIfConfigured 'playwright'
    }
}

if (-not [string]::IsNullOrWhiteSpace($GithubToken)) {
    Write-Warn "GithubToken is not written to Codex MCP config. Export $CodexGithubTokenEnvVar before launching Codex."
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

if ('microsoft-learn' -in $desiredMcpServers) {
    Add-CodexMcpIfMissing 'microsoft-learn' { codex mcp add microsoft-learn --url https://learn.microsoft.com/api/mcp }
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
        Remove-CodexIncompatibleFetchMcp
        Add-CodexMcpIfMissing 'fetch' { codex mcp add fetch -- uvx --with 'mcp<2' mcp-server-fetch }
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

if ('playwright' -in $desiredMcpServers) {
    Add-CodexMcpIfMissing 'playwright' { codex mcp add playwright -- npx -y '@playwright/mcp@latest' }
}

Set-CodexMcpSetting 'context7' 'startup_timeout_sec' '30'
Set-CodexMcpSetting 'openaiDeveloperDocs' 'startup_timeout_sec' '30'
Set-CodexMcpSetting 'microsoft-learn' 'startup_timeout_sec' '30'
Set-CodexMcpSetting 'fetch' 'startup_timeout_sec' '30'
Set-CodexMcpSetting 'fetch' 'default_tools_approval_mode' "`"$CodexFetchMcpApprovalMode`""
foreach ($server in (ConvertTo-NameList $CodexMcpDefaultDisabledServers)) {
    Set-CodexMcpSetting $server 'enabled' 'false'
}
Set-CodexMcpSetting 'microsoft-learn' 'default_tools_approval_mode' "`"$CodexMicrosoftLearnMcpApprovalMode`""
Set-CodexMcpSetting 'github' 'default_tools_approval_mode' "`"$CodexGithubMcpApprovalMode`""
Set-CodexMcpSetting 'serena' 'default_tools_approval_mode' "`"$CodexSerenaMcpApprovalMode`""
Set-CodexMcpSetting 'playwright' 'startup_timeout_sec' '30'
Set-CodexMcpSetting 'playwright' 'default_tools_approval_mode' "`"$CodexPlaywrightMcpApprovalMode`""

# Skills
Set-CodexAgentTeamworkSkill
Set-CodexGlobalAgentsGuidance

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
