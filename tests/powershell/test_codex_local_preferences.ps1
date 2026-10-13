$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$source = Get-Content (Join-Path $repoRoot 'windows/modules/codex.ps1') -Raw
$tokens = $null
$errors = $null
$ast = [System.Management.Automation.Language.Parser]::ParseInput($source, [ref]$tokens, [ref]$errors)
if ($errors) { throw ($errors | Out-String) }
foreach ($node in $ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $false)) {
    Invoke-Expression $node.Extent.Text
}
function Write-Step {}
function Write-Ok {}
function Write-Skip {}

$temp = Join-Path ([IO.Path]::GetTempPath()) ('codex-preferences-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory $temp | Out-Null
try {
    $script:ConfigToml = Join-Path $temp 'config.toml'
    $original = @'
model = "gpt-6-astra"
approval_policy = "never"
default_permissions = ":workspace"
[apps._default]
default_tools_approval_mode = "auto"
destructive_enabled = true
[windows]
sandbox = "elevated"
[agents]
max_concurrent_threads_per_session = 3
[mcp_servers.fetch]
enabled = true
default_tools_approval_mode = "auto"
'@
    Set-Content $script:ConfigToml $original -NoNewline
    $script:CodexExplicitParameters = @{}
    Set-CodexUserDefaults
    if ((Get-Content $script:ConfigToml -Raw) -cne $original) { throw 'Rerun changed existing user preferences' }

    $script:CodexDefaultRules = Join-Path $temp 'default.rules'
    $rules = 'prefix_rule(pattern = ["custom-tool"], decision = "allow")'
    Set-Content $script:CodexDefaultRules $rules -NoNewline
    $rulesGuard = $ast.EndBlock.Statements | Where-Object {
        $_ -is [System.Management.Automation.Language.IfStatementAst] -and
        $_.Extent.Text.Contains('Initialize-CodexDefaultRules')
    }
    if (-not $rulesGuard) { throw 'Existing rules must be guarded against replacement' }
    Invoke-Expression $rulesGuard.Extent.Text
    if ((Get-Content $script:CodexDefaultRules -Raw) -cne $rules) { throw 'Existing command rules changed' }

    foreach ($statement in $ast.EndBlock.Statements) {
        $text = $statement.Extent.Text
        if ($text.StartsWith('$configureMcpServers =') -or
            ($statement -is [System.Management.Automation.Language.IfStatementAst] -and
             ($text.StartsWith('if ($configureMcpServers)') -or $text.Contains('Set-CodexMcpSetting')))) {
            Invoke-Expression $text
        }
    }
    if ((Get-Content $script:ConfigToml -Raw) -cne $original) { throw 'Rerun changed MCP configuration' }

    $script:CodexExplicitParameters = @{ CodexModel = 'gpt-6.1-sol' }
    $CodexModel = 'gpt-6.1-sol'
    Set-CodexUserDefaults
    $updated = Get-Content $script:ConfigToml -Raw
    if ($updated -notmatch 'model = "gpt-6.1-sol"' -or $updated -match 'sandbox_mode' -or $updated -notmatch 'approval_policy = "never"') {
        throw 'Explicit model override changed permissions or failed to apply'
    }

    $codexDir = $temp
    $CodexProfilesEnabled = $true
    $CodexLeanProfileModel = 'gpt-6-luna'
    $CodexLeanProfileReasoningEffort = 'high'
    $CodexLeanProfileVerbosity = 'low'
    $CodexDeepProfileModel = 'gpt-6.1-sol'
    $CodexDeepProfileReasoningEffort = 'high'
    $CodexDeepProfileVerbosity = 'medium'
    Set-CodexProfileFiles
    foreach ($name in 'lean', 'deep') {
        $profile = Get-Content (Join-Path $temp "$name.config.toml") -Raw
        if ($profile -match 'sandbox|approval|apps\.|mcp_servers|web_search|service_tier') { throw "$name profile overrides user autonomy or tools" }
        if (-not (Test-CodexConfigContent $profile)) { throw "$name profile is invalid TOML" }
    }

    $bootstrapAst = [System.Management.Automation.Language.Parser]::ParseFile(
        (Join-Path $repoRoot 'windows/bootstrap.ps1'), [ref]$tokens, [ref]$errors)
    if ($errors) { throw ($errors | Out-String) }
    foreach ($parameter in $bootstrapAst.ParamBlock.Parameters) {
        $name = $parameter.Name.VariablePath.UserPath
        if ($name -like 'Codex*' -and $parameter.DefaultValue) {
            Set-Variable -Name $name -Value $parameter.DefaultValue.SafeGetValue()
        }
    }
    $script:ConfigToml = Join-Path $temp 'fresh.toml'
    $script:CodexExplicitParameters = @{}
    Set-CodexUserDefaults
    $fresh = Get-Content $script:ConfigToml -Raw
    if (-not (Test-CodexConfigContent $fresh) -or $fresh -notmatch 'model = "gpt-6.1-sol"' -or
        $fresh -notmatch 'approval_policy = "on-request"' -or $fresh -notmatch 'sandbox_mode = "workspace-write"') {
        throw 'Fresh installation defaults are invalid'
    }
    Write-Host 'Codex local preference preservation tests passed'
} finally {
    # Only this test's uniquely named temporary directory is removed.
    if ((Split-Path $temp -Leaf) -notlike 'codex-preferences-*') { throw 'Unexpected temporary path' }
    Remove-Item -LiteralPath $temp -Recurse -Force
}
