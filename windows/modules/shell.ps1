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
