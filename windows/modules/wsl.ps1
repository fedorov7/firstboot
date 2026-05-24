Write-Step "Inspecting WSL configuration..."

function Set-WslConfigValue {
    param(
        [Parameter(Mandatory)][AllowEmptyCollection()][string[]]$Lines,
        [Parameter(Mandatory)][string]$Section,
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string]$Value
    )

    $sectionPattern = "^\s*\[$([regex]::Escape($Section))\]\s*$"
    $keyPattern = "^\s*$([regex]::Escape($Name))\s*="
    $sectionIndex = -1

    for ($i = 0; $i -lt $Lines.Count; $i++) {
        if ($Lines[$i] -match $sectionPattern) {
            $sectionIndex = $i
            break
        }
    }

    if ($sectionIndex -lt 0) {
        if ($Lines.Count -gt 0 -and -not [string]::IsNullOrWhiteSpace($Lines[$Lines.Count - 1])) {
            $Lines += ''
        }
        $Lines += "[$Section]"
        $Lines += "$Name=$Value"
        return ,$Lines
    }

    $nextSectionIndex = $Lines.Count
    for ($i = $sectionIndex + 1; $i -lt $Lines.Count; $i++) {
        if ($Lines[$i] -match '^\s*\[[^\]]+\]\s*$') {
            $nextSectionIndex = $i
            break
        }
    }

    for ($i = $sectionIndex + 1; $i -lt $nextSectionIndex; $i++) {
        if ($Lines[$i] -match $keyPattern) {
            $Lines[$i] = "$Name=$Value"
            return ,$Lines
        }
    }

    if ($nextSectionIndex -eq $Lines.Count) {
        $Lines += "$Name=$Value"
        return ,$Lines
    }

    $before = if ($nextSectionIndex -gt 0) { $Lines[0..($nextSectionIndex - 1)] } else { @() }
    $after = $Lines[$nextSectionIndex..($Lines.Count - 1)]
    return ,(@($before) + "$Name=$Value" + @($after))
}

function Set-WslGlobalConfig {
    $allowedNetworkingModes = @('none', 'nat', 'mirrored', 'virtioproxy')
    if (-not [string]::IsNullOrWhiteSpace($WslNetworkingMode) -and $allowedNetworkingModes -notcontains $WslNetworkingMode) {
        throw "Unsupported WslNetworkingMode '$WslNetworkingMode'. Supported modes: $($allowedNetworkingModes -join ', ')"
    }

    $allowedAutoMemoryReclaim = @('disabled', 'gradual', 'dropCache')
    if (-not [string]::IsNullOrWhiteSpace($WslAutoMemoryReclaim) -and $allowedAutoMemoryReclaim -notcontains $WslAutoMemoryReclaim) {
        throw "Unsupported WslAutoMemoryReclaim '$WslAutoMemoryReclaim'. Supported values: $($allowedAutoMemoryReclaim -join ', ')"
    }

    $configPath = Join-Path $env:USERPROFILE '.wslconfig'
    $oldContent = if (Test-Path -LiteralPath $configPath) {
        Get-Content -LiteralPath $configPath -Raw
    } else {
        ''
    }
    $lines = if (Test-Path -LiteralPath $configPath) {
        @(Get-Content -LiteralPath $configPath)
    } else {
        @()
    }

    if (-not [string]::IsNullOrWhiteSpace($WslMemory)) {
        $lines = Set-WslConfigValue -Lines $lines -Section 'wsl2' -Name 'memory' -Value $WslMemory
    }
    if ($WslProcessors -gt 0) {
        $lines = Set-WslConfigValue -Lines $lines -Section 'wsl2' -Name 'processors' -Value $WslProcessors
    }
    if (-not [string]::IsNullOrWhiteSpace($WslSwap)) {
        $lines = Set-WslConfigValue -Lines $lines -Section 'wsl2' -Name 'swap' -Value $WslSwap
    }
    if (-not [string]::IsNullOrWhiteSpace($WslNetworkingMode)) {
        $lines = Set-WslConfigValue -Lines $lines -Section 'wsl2' -Name 'networkingMode' -Value $WslNetworkingMode
    }
    if (-not [string]::IsNullOrWhiteSpace($WslAutoMemoryReclaim)) {
        $lines = Set-WslConfigValue -Lines $lines -Section 'experimental' -Name 'autoMemoryReclaim' -Value $WslAutoMemoryReclaim
    }
    if ($WslSparseVhdEnabled) {
        $lines = Set-WslConfigValue -Lines $lines -Section 'experimental' -Name 'sparseVhd' -Value 'true'
    }

    $newContent = ($lines | ForEach-Object { $_.TrimEnd() }) -join [Environment]::NewLine
    if ($newContent.Length -gt 0) {
        $newContent += [Environment]::NewLine
    }

    if ($oldContent -eq $newContent) {
        Write-Skip ".wslconfig already up to date"
        return
    }

    if (Test-Path -LiteralPath $configPath) {
        $backupPath = "$configPath.backup.$(Get-Date -Format 'yyyyMMdd-HHmmss')"
        Copy-Item -LiteralPath $configPath -Destination $backupPath -Force
        Write-Ok ".wslconfig backed up to $backupPath"
    }

    Set-Content -LiteralPath $configPath -Value $newContent -Encoding utf8 -NoNewline
    Write-Ok ".wslconfig updated at $configPath"
    Write-Warn "Run 'wsl --shutdown' after closing WSL sessions for .wslconfig changes to take effect."
}

function Invoke-WslCommand {
    param(
        [Parameter(Mandatory)][string[]]$Arguments,
        [switch]$Required
    )

    if (-not (Test-CommandExists wsl)) {
        $message = "wsl.exe not found. Install WSL support or run this module with -WslInstallEnabled."
        if ($Required) {
            throw $message
        }
        Write-Warn $message
        return $false
    }

    $output = & wsl @Arguments 2>&1
    $exitCode = $LASTEXITCODE
    if ($output) {
        $output | ForEach-Object { Write-Host "   $_" }
    }

    if ($exitCode -ne 0) {
        $message = "wsl $($Arguments -join ' ') returned exit code $exitCode"
        if ($Required) {
            throw $message
        }
        Write-Warn $message
        return $false
    }

    return $true
}

Invoke-WslCommand -Arguments @('--status') | Out-Null
Invoke-WslCommand -Arguments @('--list', '--verbose') | Out-Null

if ($WslConfigEnabled) {
    Set-WslGlobalConfig
} else {
    Write-Skip "WSL global .wslconfig management disabled by default; pass -WslConfigEnabled to enable it"
}

if (-not $WslInstallEnabled) {
    Write-Skip "WSL installation disabled by default; pass -WslInstallEnabled to install $WslDistribution"
    return
}

Invoke-WslCommand -Arguments @('--list', '--online') | Out-Null
Invoke-WslCommand -Arguments @('--install', '--distribution', $WslDistribution, '--no-launch') -Required | Out-Null
Write-Warn "A restart may be required before the WSL distribution is usable."
