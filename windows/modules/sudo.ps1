Write-Step "Configuring Sudo for Windows..."

$allowedSudoModes = @('forceNewWindow', 'disableInput', 'normal')
if ($allowedSudoModes -notcontains $WindowsSudoMode) {
    throw "Unsupported WindowsSudoMode '$WindowsSudoMode'. Supported modes: $($allowedSudoModes -join ', ')"
}

function Invoke-WindowsSudoCommand {
    param(
        [Parameter(Mandatory)][string[]]$Arguments,
        [switch]$Required
    )

    if (-not (Test-CommandExists sudo)) {
        $message = "sudo.exe not found. Sudo for Windows requires Windows 11 version 24H2 or newer."
        if ($Required) {
            throw $message
        }
        Write-Warn $message
        return $false
    }

    $output = & sudo @Arguments 2>&1
    $exitCode = $LASTEXITCODE
    if ($output) {
        $output | ForEach-Object { Write-Host "   $_" }
    }

    if ($exitCode -ne 0) {
        $message = "sudo $($Arguments -join ' ') returned exit code $exitCode"
        if ($Required) {
            throw $message
        }
        Write-Warn $message
        return $false
    }

    return $true
}

if (-not $WindowsSudoEnabled) {
    Write-Skip "Sudo for Windows disabled by default; pass -WindowsSudoEnabled to enable it"
    return
}

if ($WindowsSudoMode -ne 'forceNewWindow') {
    Write-Warn "Sudo mode '$WindowsSudoMode' has higher security risk than forceNewWindow."
}

Invoke-WindowsSudoCommand -Arguments @('config', '--enable', $WindowsSudoMode) -Required | Out-Null
Write-Ok "Sudo for Windows enabled in $WindowsSudoMode mode"
