$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$modulePath = Join-Path $repoRoot 'windows\modules\codex.ps1'
$source = Get-Content -LiteralPath $modulePath -Raw

$tokens = $null
$errors = $null
$ast = [System.Management.Automation.Language.Parser]::ParseInput($source, [ref]$tokens, [ref]$errors)
if ($errors) {
    throw ($errors | ForEach-Object { $_.Message } | Out-String)
}

$functionAst = $ast.Find({
    param($node)
    $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
        $node.Name -eq 'ConvertTo-CodexTomlBoolean'
}, $true)

if (-not $functionAst) {
    throw 'ConvertTo-CodexTomlBoolean must exist'
}

Invoke-Expression $functionAst.Extent.Text

$cases = @(
    @{ Input = $true; Expected = 'true' }
    @{ Input = $false; Expected = 'false' }
    @{ Input = 'true'; Expected = 'true' }
    @{ Input = 'false'; Expected = 'false' }
    @{ Input = 1; Expected = 'true' }
    @{ Input = 0; Expected = 'false' }
)

foreach ($case in $cases) {
    $actual = ConvertTo-CodexTomlBoolean $case.Input
    if ($actual -ne $case.Expected) {
        throw "Expected '$($case.Input)' to become '$($case.Expected)', got '$actual'"
    }
}

$threw = $false
try {
    ConvertTo-CodexTomlBoolean 'System.String' | Out-Null
} catch {
    $threw = $true
}
if (-not $threw) {
    throw 'Invalid Boolean-like strings must be rejected'
}

Write-Host 'codex TOML boolean tests passed'
