$ErrorActionPreference = 'Stop'

function Assert-Equal {
    param(
        [Parameter(Mandatory)][string]$Expected,
        [Parameter(Mandatory)][string]$Actual,
        [Parameter(Mandatory)][string]$Message
    )

    if ($Expected -ne $Actual) {
        throw "$Message`nExpected: <$Expected>`nActual:   <$Actual>"
    }
}

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$modulePath = Join-Path $repoRoot 'windows\modules\shell.ps1'
$source = Get-Content -LiteralPath $modulePath -Raw
$tokens = $null
$parseErrors = $null
$ast = [System.Management.Automation.Language.Parser]::ParseInput($source, [ref]$tokens, [ref]$parseErrors)

if ($parseErrors.Count -gt 0) {
    throw "Failed to parse shell.ps1: $($parseErrors[0].Message)"
}

$functionAst = $ast.Find(
    {
        param($node)
        $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
            $node.Name -eq 'Resolve-CurrentUserCurrentHostProfilePath'
    },
    $true
)

if ($null -eq $functionAst) {
    throw 'Resolve-CurrentUserCurrentHostProfilePath function not found in shell.ps1'
}

. ([scriptblock]::Create($functionAst.Extent.Text))

$profileObject = [pscustomobject]@{
    CurrentUserCurrentHost = 'C:\Users\me\Documents\PowerShell\Microsoft.PowerShell_profile.ps1'
}
Assert-Equal `
    -Expected 'C:\Users\me\Documents\PowerShell\Microsoft.PowerShell_profile.ps1' `
    -Actual (Resolve-CurrentUserCurrentHostProfilePath -ProfileObject $profileObject -DocumentsPath 'C:\fallback' -UserProfilePath 'C:\Users\fallback' -PowerShellEdition 'Desktop') `
    -Message 'Uses CurrentUserCurrentHost when PowerShell exposes it'

Assert-Equal `
    -Expected 'D:\Profiles\Microsoft.PowerShell_profile.ps1' `
    -Actual (Resolve-CurrentUserCurrentHostProfilePath -ProfileObject 'D:\Profiles\Microsoft.PowerShell_profile.ps1' -DocumentsPath 'C:\fallback' -UserProfilePath 'C:\Users\fallback' -PowerShellEdition 'Core') `
    -Message 'Falls back to scalar PROFILE value when host-specific property is missing'

Assert-Equal `
    -Expected 'C:\Users\me\Documents\PowerShell\Microsoft.PowerShell_profile.ps1' `
    -Actual (Resolve-CurrentUserCurrentHostProfilePath -ProfileObject $null -DocumentsPath 'C:\Users\me\Documents' -UserProfilePath 'C:\Users\me' -PowerShellEdition 'Core') `
    -Message 'Builds PowerShell 7 profile path when PROFILE is unavailable'

Assert-Equal `
    -Expected 'C:\Users\me\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1' `
    -Actual (Resolve-CurrentUserCurrentHostProfilePath -ProfileObject $null -DocumentsPath '' -UserProfilePath 'C:\Users\me' -PowerShellEdition 'Desktop') `
    -Message 'Builds Windows PowerShell profile path when Documents must be inferred'

Write-Host 'shell profile path tests passed'
