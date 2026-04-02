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

# Patch Windows Terminal font defaults without overwriting user settings
$terminalSettings = Join-Path $env:LOCALAPPDATA 'Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json'
if (Test-Path $terminalSettings) {
    $terminalBackup = "$terminalSettings.backup.$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    Copy-Item -Path $terminalSettings -Destination $terminalBackup -Force
    Write-Ok "Windows Terminal settings backed up to $terminalBackup"

    $terminalConfig = Get-Content $terminalSettings -Raw | ConvertFrom-Json -Depth 100
    if (-not $terminalConfig.profiles.defaults) {
        $terminalConfig.profiles | Add-Member -MemberType NoteProperty -Name defaults -Value ([pscustomobject]@{})
    }
    if (-not $terminalConfig.profiles.defaults.font) {
        $terminalConfig.profiles.defaults | Add-Member -MemberType NoteProperty -Name font -Value ([pscustomobject]@{})
    }
    if ($terminalConfig.profiles.defaults.font.PSObject.Properties['face']) {
        $terminalConfig.profiles.defaults.font.face = 'CaskaydiaCove Nerd Font Mono'
    } else {
        $terminalConfig.profiles.defaults.font | Add-Member -MemberType NoteProperty -Name face -Value 'CaskaydiaCove Nerd Font Mono'
    }
    if ($terminalConfig.profiles.defaults.font.PSObject.Properties['size']) {
        $terminalConfig.profiles.defaults.font.size = 11
    } else {
        $terminalConfig.profiles.defaults.font | Add-Member -MemberType NoteProperty -Name size -Value 11
    }

    foreach ($profile in $terminalConfig.profiles.list) {
        if ($profile.name -eq 'Windows PowerShell' -and $profile.PSObject.Properties['font']) {
            $profile.PSObject.Properties.Remove('font')
        }
    }

    $terminalConfig | ConvertTo-Json -Depth 100 | Set-Content -Path $terminalSettings -Encoding utf8
    Write-Ok "Windows Terminal font defaults set to CaskaydiaCove Nerd Font Mono"
} else {
    Write-Skip "Windows Terminal settings.json not found"
}

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
