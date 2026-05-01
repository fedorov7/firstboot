$ErrorActionPreference = 'Stop'

function Assert-Equal {
    param(
        [Parameter(Mandatory)][object]$Expected,
        [Parameter(Mandatory)][object]$Actual,
        [Parameter(Mandatory)][string]$Message
    )

    if ($Expected -ne $Actual) {
        throw "$Message`nExpected: <$Expected>`nActual:   <$Actual>"
    }
}

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$modulePath = Join-Path $repoRoot 'windows\modules\ssh.ps1'
$source = Get-Content -LiteralPath $modulePath -Raw
$tokens = $null
$parseErrors = $null
$ast = [System.Management.Automation.Language.Parser]::ParseInput($source, [ref]$tokens, [ref]$parseErrors)

if ($parseErrors.Count -gt 0) {
    throw "Failed to parse ssh.ps1: $($parseErrors[0].Message)"
}

$functionAst = $ast.Find(
    {
        param($node)
        $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
            $node.Name -eq 'Get-FirstbootGitConfigEntries'
    },
    $true
)

if ($null -eq $functionAst) {
    throw 'Get-FirstbootGitConfigEntries function not found in ssh.ps1'
}

. ([scriptblock]::Create($functionAst.Extent.Text))

$entries = @(Get-FirstbootGitConfigEntries -GitUserName 'Your Name' -UserEmail 'you@example.com')

if ($entries.Count -lt 10) {
    throw "Expected a full git config entry list, got $($entries.Count)"
}

foreach ($entry in $entries) {
    if ($entry.Key.Length -lt 3 -or $entry.Key -notmatch '\.') {
        throw "Invalid git config key shape: <$($entry.Key)>"
    }
    if ([string]::IsNullOrWhiteSpace([string]$entry.Value)) {
        throw "Git config value is empty for key <$($entry.Key)>"
    }
}

Assert-Equal -Expected 'user.name' -Actual $entries[0].Key -Message 'First entry key is user.name'
Assert-Equal -Expected 'Your Name' -Actual $entries[0].Value -Message 'First entry value uses GitUserName'
Assert-Equal -Expected 'user.email' -Actual $entries[1].Key -Message 'Second entry key is user.email'
Assert-Equal -Expected 'you@example.com' -Actual $entries[1].Value -Message 'Second entry value uses UserEmail'

Write-Host 'ssh git config entry tests passed'
