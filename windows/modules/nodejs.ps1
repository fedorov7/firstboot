Write-Step "Setting up Node.js via fnm..."

Install-WingetPackage -Id 'Schniz.fnm' -Name 'fnm'

# Refresh PATH so fnm is available
Refresh-Path

# Initialize fnm in current session
Initialize-Fnm

if (Test-CommandExists fnm) {
    $installed = fnm list 2>&1
    if ($installed -notmatch 'lts-latest|v\d+\.\d+\.\d+') {
        Write-Step "Installing Node.js $NodeVersion..."
        fnm install $NodeVersion
        fnm default $NodeVersion
        Write-Ok "Node.js $NodeVersion installed and set as default"
    } else {
        Write-Skip "Node.js already installed via fnm"
    }
    # Re-initialize to pick up the installed version
    Initialize-Fnm
} else {
    Write-Warn "fnm not found in PATH after install — restart shell and re-run"
}

# Warn about system Node.js
$systemNode = winget list --id OpenJS.NodeJS --exact 2>&1
if ($systemNode -match 'OpenJS.NodeJS') {
    Write-Warn "System Node.js detected via winget. Consider removing it to avoid conflicts with fnm."
}
