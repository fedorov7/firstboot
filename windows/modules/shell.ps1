Write-Step "Configuring PowerShell shell environment..."

# Winget tools
Install-WingetPackage -Id 'JanDeDobbeleer.OhMyPosh' -Name 'oh-my-posh'
Install-WingetPackage -Id 'ajeetdsouza.zoxide' -Name 'zoxide'

# PowerShell modules
Install-PSModule 'posh-git'
Install-PSModule 'Terminal-Icons'
Install-PSModule 'PSFzf'

function Resolve-CurrentUserCurrentHostProfilePath {
    param(
        [object]$ProfileObject = $PROFILE,
        [string]$DocumentsPath = [Environment]::GetFolderPath('MyDocuments'),
        [string]$UserProfilePath = $env:USERPROFILE,
        [string]$PowerShellEdition = $PSVersionTable.PSEdition
    )

    if ($null -ne $ProfileObject) {
        $currentHostProperty = $ProfileObject.PSObject.Properties['CurrentUserCurrentHost']
        if ($null -ne $currentHostProperty -and -not [string]::IsNullOrWhiteSpace([string]$currentHostProperty.Value)) {
            return [string]$currentHostProperty.Value
        }

        if ($ProfileObject -is [string] -and -not [string]::IsNullOrWhiteSpace([string]$ProfileObject)) {
            return [string]$ProfileObject
        }
    }

    if ([string]::IsNullOrWhiteSpace($DocumentsPath)) {
        if ([string]::IsNullOrWhiteSpace($UserProfilePath)) {
            throw 'Unable to resolve PowerShell profile path: PROFILE, DocumentsPath, and USERPROFILE are empty.'
        }
        $DocumentsPath = Join-Path $UserProfilePath 'Documents'
    }

    $profileRootName = if ($PowerShellEdition -eq 'Core') { 'PowerShell' } else { 'WindowsPowerShell' }
    Join-Path (Join-Path $DocumentsPath $profileRootName) 'Microsoft.PowerShell_profile.ps1'
}

function Remove-UnsafeOhMyPoshProfileInit {
    $profileTargets = @(
        @{ Scope = 'AllUsersAllHosts';     Path = $PROFILE.AllUsersAllHosts }
        @{ Scope = 'AllUsersCurrentHost';  Path = $PROFILE.AllUsersCurrentHost }
        @{ Scope = 'CurrentUserAllHosts';  Path = $PROFILE.CurrentUserAllHosts }
    )

    foreach ($target in $profileTargets) {
        $profilePath = $target.Path
        if ([string]::IsNullOrWhiteSpace($profilePath) -or -not (Test-Path $profilePath)) {
            continue
        }

        $lines = @(Get-Content -LiteralPath $profilePath)
        $filteredLines = @(
            $lines | Where-Object {
                $_ -notmatch '^\s*oh-my-posh\s+init\s+\S+.*\|\s*Invoke-Expression\s*$'
            }
        )

        if ($filteredLines.Count -eq $lines.Count) {
            Write-Skip "No unsafe oh-my-posh init in $($target.Scope) profile"
            continue
        }

        $backupPath = "$profilePath.backup.$(Get-Date -Format 'yyyyMMdd-HHmmss')"
        Copy-Item -LiteralPath $profilePath -Destination $backupPath -Force
        Set-Content -LiteralPath $profilePath -Value $filteredLines -Encoding utf8
        Write-Ok "Removed unsafe oh-my-posh init from $($target.Scope) profile"
    }
}

Remove-UnsafeOhMyPoshProfileInit

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
    $terminalConfig = Get-Content $terminalSettings -Raw | ConvertFrom-Json -Depth 100
    $terminalChanged = $false
    if (-not $terminalConfig.profiles.defaults) {
        $terminalConfig.profiles | Add-Member -MemberType NoteProperty -Name defaults -Value ([pscustomobject]@{})
        $terminalChanged = $true
    }
    if (-not $terminalConfig.profiles.defaults.font) {
        $terminalConfig.profiles.defaults | Add-Member -MemberType NoteProperty -Name font -Value ([pscustomobject]@{})
        $terminalChanged = $true
    }
    if ($terminalConfig.profiles.defaults.font.PSObject.Properties['face']) {
        if ($terminalConfig.profiles.defaults.font.face -ne 'CaskaydiaCove Nerd Font Mono') {
            $terminalConfig.profiles.defaults.font.face = 'CaskaydiaCove Nerd Font Mono'
            $terminalChanged = $true
        }
    } else {
        $terminalConfig.profiles.defaults.font | Add-Member -MemberType NoteProperty -Name face -Value 'CaskaydiaCove Nerd Font Mono'
        $terminalChanged = $true
    }
    if ($terminalConfig.profiles.defaults.font.PSObject.Properties['size']) {
        if ($terminalConfig.profiles.defaults.font.size -ne 11) {
            $terminalConfig.profiles.defaults.font.size = 11
            $terminalChanged = $true
        }
    } else {
        $terminalConfig.profiles.defaults.font | Add-Member -MemberType NoteProperty -Name size -Value 11
        $terminalChanged = $true
    }

    foreach ($profile in $terminalConfig.profiles.list) {
        if ($profile.name -eq 'Windows PowerShell' -and $profile.PSObject.Properties['font']) {
            $profile.PSObject.Properties.Remove('font')
            $terminalChanged = $true
        }
    }

    if ($terminalChanged) {
        $terminalBackup = "$terminalSettings.backup.$(Get-Date -Format 'yyyyMMdd-HHmmss')"
        Copy-Item -Path $terminalSettings -Destination $terminalBackup -Force
        Write-Ok "Windows Terminal settings backed up to $terminalBackup"

        $terminalConfig | ConvertTo-Json -Depth 100 | Set-Content -Path $terminalSettings -Encoding utf8
        Write-Ok "Windows Terminal font defaults set to CaskaydiaCove Nerd Font Mono"
    } else {
        Write-Skip "Windows Terminal font defaults already configured"
    }
} else {
    Write-Skip "Windows Terminal settings.json not found"
}

# Deploy PowerShell profile
$currentUserCurrentHostProfile = Resolve-CurrentUserCurrentHostProfilePath
$profileDir = Split-Path -Path $currentUserCurrentHostProfile -Parent
if (-not (Test-Path -LiteralPath $profileDir)) { New-Item -ItemType Directory -Path $profileDir -Force | Out-Null }
if (Test-Path -LiteralPath $currentUserCurrentHostProfile) {
    $backupPath = "$currentUserCurrentHostProfile.backup.$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    Copy-Item -LiteralPath $currentUserCurrentHostProfile -Destination $backupPath -Force
    Write-Ok "Existing profile backed up to $backupPath"
}
$profileSource = Join-Path $ScriptRoot 'files\profile.ps1'
Copy-Item -Path $profileSource -Destination $currentUserCurrentHostProfile -Force
Write-Ok "PowerShell profile deployed to $currentUserCurrentHostProfile"
